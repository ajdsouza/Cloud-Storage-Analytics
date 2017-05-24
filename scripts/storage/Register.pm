#
# Copyright (c) 2001, 2005, Oracle. All rights reserved.  
#
#  $Id: Register.pm 07-feb-2005.00:28:45 ajdsouza Exp $ 
#
#
# NAME  
#	 Register.pm
#
# DESC 
#	 Register and invoke the subroutines 
#
#
# FUNCTIONS
# AUTOLOADER
#
# NOTES
#
#
# MODIFIED	(MM/DD/YY)
# ajdsouza 02/07/05 - qualify error messages to be loaded to rep with ERROR:
# ajdsouza 01/26/05 - log_message to keep message_counter instead of 
#                     message text
# ajdsouza 12/02/04 - Run in test mode using 0 byte file
# ajdsouza 11/15/04 - Add id to nls message structure message_list
# ajdsouza 10/28/04 - 
# ajdsouza 09/07/04 - Use fallback osd,platform generic and platform neutral
#                     for function calls
#                     add ability to run script in capture and regression test mode
# ajdsouza 08/17/04 - 
# ajdsouza 08/11/04 - 
# ajdsouza 07/27/04 - 
# ajdsouza 06/25/04 - storage reporting sources 
# ajdsouza 04/09/04 - 
# ajdsouza 04/08/04 - storage perl modules 
#
#
package storage::Register;

require v5.6.1;

use Exporter;
use strict;
use warnings;
use locale;
use File::Spec::Functions;
use File::Path;
use Data::Dumper;
use storage::Utilities;
use storage::vendor::Veritas;
use storage::vendor::Emc;
use storage::vendor::Hitachi;
eval "use storage::sRawmetrics; 1" or warn "ERROR:Storage module is not ported to platform $^O , OS interface library storage::sRawmetrics.pm not found\n";

our @ISA = qw(Exporter);
our @EXPORT = qw( get_os_storage_entity_identifier 
                  get_agentstate_dir 
                  get_target_name 
                  get_target_id 
                  get_agentstatetarget_dir
                  log_message 
                  log_error_message 
                );

BEGIN
{
  # Check if the execution mode is regression or capture
  $storage::Register::run_mode = $ENV{EM_STORAGE_RMODE}
   if $ENV{EM_STORAGE_RMODE}
    and not $storage::Register::run_mode;

  # Get the complete path of the file based on the mangled function name
  # is the test(name) sub directory provided by the environment variable
  $storage::Register::test_name = $ENV{EM_STORAGE_TEST_NAME}
   if $ENV{EM_STORAGE_TEST_NAME}
     and not $storage::Register::test_name;

  # if the test desc is provided by the env
  $storage::Register::test_desc = $ENV{EM_STORAGE_TEST_DESCRIPTION}
   if $ENV{EM_STORAGE_TEST_DESCRIPTION}
    and not $storage::Register::test_desc;

  $storage::Register::test_desc = "No description"
   unless $storage::Register::test_desc; 

  # in the test environment take the test ddirectory be be under
  # srchome
   if 
   ( 
     $ENV{SRCHOME}
      and not $storage::Register::test_directory
   )
   {
     $storage::Register::test_directory = $ENV{SRCHOME};
     for my $dir ( qw ( emagent test src emd tvmac ) )
     {
       $storage::Register::test_directory =
        catfile($storage::Register::test_directory,$dir);
     }

     # If its not a valid directory do not take it
     stat $storage::Register::test_directory;

     undef $storage::Register::test_directory
      unless 
      (
       -e $storage::Register::test_directory
        and -d $storage::Register::test_directory
      );

   }

  # default the test_directory to agent_state_dir if its null
  (
   $storage::Register::test_directory = get_agentstate_dir() 
    or warn " Failed to get directory to cache storage metrics on host \n"
     and return
   )
   unless $storage::Register::test_directory;
 
  # If the regression mode is not provided in the env, check
  # if the 0 byte file nmhsr.lck exists in test_directory
  # take care of portability issue when concatenating the directory path
  if ( not $storage::Register::run_mode )
  {

   my $checkrmodefile = catfile($storage::Register::test_directory,'nmhsr.lck');
  
   stat $checkrmodefile;

   $storage::Register::run_mode = 'REGRESSION'
    if -e $checkrmodefile;

  }


}

#-----------------------------------------------------------------------------------------
# Global package variable to hold sub name
our $AUTOLOAD;

# global to hold all config infomation
our %config;

# Global package variables for REGRESSION or CAPTURE mode execution
# to cache the execution mode REGRESSION or CAPTURE 
# test(name) directory 
# parent directory for location of test files
# counter for function invocation
our $run_mode;
our $test_directory;
our $test_desc;
our $test_name;
our %regression_fn_count;
our $read_fn_results_ref;
our %write_fn_results;

# Global to indicate the metric being excuted data|keys|alias|issu
our $metric_name;

# Global package variable to cache the list of all filesystems so can be used by other modules
# outside of Filesystem. This global is populated by Filesystem.pm
our @filesystemarray;

# Global package variable to cache the mount privileges by mountpoint
our %mount_privilege;

# Global package variable to cache the sat device id to the mountpoint
our %mountpoint_id_index;

# Global package variable to indentify the host target 
our $em_target_id;
our $em_target_name;

# Global package variable to hold execution earnigns and errors 
our %error_stack;

# Global package variable to log storage issues 
our @logged_messages;
our %logged_message_index;

# Global package variable to hold all nls strings
our %message_list;

# Global package variable to cache values on the host 
our $agent_state_dir;
our $agent_state_target_dir;

# Global package variable to cache file seperator
our $file_seperator;

# Global package variable to cache absolute path start
our $abs_path_start;
#-----------------------------------------------------------------------------------------
# List of NLS messages for issues
#
# nls id format nls_st<e|a>_<xxxxx>
#
#-----------------------------------------------------------------------------------------
$message_list{ERROR_INST_PROCESSING} =
 {
   message => 'Instrumentation Error - Failed to instrument storage metrics for the host'
 };

$message_list{ERROR_INST_MAPPING} =
 {
   message => 'Instrumentation Error - Failed to map storage entity {0}, this may result in inaccuracies in the storage report',
   message_params => 
   { 
     1=> [ ( 'entity_type,type' , 'name' ) ] 
   }
 };

$message_list{ERROR_INST_INVALID_SIZE} =
 {
   message => 'Instrumentation Error - There is an error in the size, used and free byte values instrumented for storage entity {0}',
   message_params => 
   { 
     1=> [ ( 'entity_type,type' , 'name' ) ]
   }
 };

$message_list{ERROR_INST_NO_GID} =
 {
   message => 'Instrumentation Error - Failed to generate a globally unique identifier for {0}, this may result in inaccuracies in shared storage computation',
   message_params => 
   {
     1=> [ ( 'storage_layer,type', 'name' ) ]
   }
 };

$message_list{ERROR_INST_NO_TARGET_ID} =
 {
   message => 'Instrumentation Error - Failed to fetch the hostname or EM target_guid for the host target'
 };

$message_list{ACTION_INST_CHECK_AGENT_LOG}=
 {
   message => 'Check the error log for the detailed error message'
 };

$message_list{ACTION_INST_RESOLV_ISSUE} =
 {
   message => 'The following steps may help resolve this issue (a) Check the metric collection error log for detailed error message (b) Check for stale storage configuration on the host (c) Refresh storage metrics for this host. Contact Oracle Support if the issue persists'
 };
#------------------------------------------------------------------------------
# Register those subs where invoked sub names are not present in 
# storage perl modules sRawmetrics, sUtilities and Utilities.pm
#
#-------------------------------------------------------------------------------

my %subRegister;

$subRegister {getEmcDiskData}			= \&storage::vendor::Emc::getDiskinfo;
$subRegister {getSunDiskData}			= \&storage::vendor::Sun::getDiskinfo;
$subRegister {getHitachiDiskData}		= \&storage::vendor::Hitachi::getDiskinfo;

$subRegister {generateEmcDiskId}		= \&storage::vendor::Emc::generateDiskId;
$subRegister {generateSunDiskId}		= \&storage::vendor::Sun::generateDiskId;
$subRegister {generateHitachiDiskId}		= \&storage::vendor::Hitachi::generateDiskId;



#-------------------------------------------------------------------------------
# FUNCTION : setup_test_directories
#
# DESC 
# initialize the testname or subdirectory for capturing or regressing the test 
# files if the name is passed in the environment read it from the test cfg file
# if no name can be got run in normal mode
#
# initialize the test location directory
# read it from the enviromnent
# use the agent state directory if not set in env
#
# Creates the directories if they are not present
#
# return an error if directories cant be setup
#
# ARGUMENTS
#
#-------------------------------------------------------------------------------
sub setup_test_directories()
{

  my $tcfgfile = 'tvmacs.cfg';   # Name of the test config file

  # Get the agent cache directory for storage
  warn " Failed to get directory for test files on host \n"
   and return
    unless $storage::Register::test_directory;

  stat($storage::Register::test_directory);

  warn "Test directory $storage::Register::test_directory is not present \n" 
   and return 
    unless
    (
     -e $storage::Register::test_directory 
      and -d $storage::Register::test_directory 
       and -w $storage::Register::test_directory
    );

  # If no test name is defined read the testname from the config test file 
  # pick test name based on target name passed from the em agent
  if ( not $storage::Register::test_name )
  {

    my $target_name = get_target_name() 
     or warn "Failed to get the target_name for the target\n";
 
    if ( $target_name and $target_name !~ /unknown/i )
    {
      # path to the config test file
      my $testfilepath = catfile($storage::Register::test_directory,$tcfgfile);
     
      stat($testfilepath);
    
      # read from the config test file if one exists
      if ( -e $testfilepath  and -r $testfilepath )
      {
    
         # Open the file for reading
         open(FH,"$testfilepath") or
          warn "Failed to open the test configuration file $testfilepath for reading\n"
           and return;
      
           
         # Read each line and prepare it for printing
         while ( <FH> )
         {
           my $tstcfgr = $_;
    
           chomp($tstcfgr);
      
           # each row should be of format target_name:test_name
           $tstcfgr =~ s/^\s+|\s+$//g;
    
           # ignore comments
           next if $tstcfgr =~ /^#/;

           next unless $tstcfgr =~ /^.+\s*:\s*.+/;
    
           my ( $tname, $tstname) =
            ( $tstcfgr =~ /^(.+)\s*:\s*(.+)/ );
         
           $tname   =~ s/^\s+|\s+$//g; 
           $tstname =~ s/^\s+|\s+$//g; 
    
           next unless $tname;
    
           $tstname = 'none' unless $tstname;
    
           # If the target name matches a target name in the file 
           # pick that test name
           $storage::Register::test_name = $tstname
            and last
             if $tname =~ /^$target_name$/;
    
         }
      
         close(FH) or 
          warn "Failed to close the test configuration file $testfilepath\n";
         
      }

    }

  }

  # change spaces to _ from the test directory name
  $storage::Register::test_name =~ s/\s+/_/g
   if $storage::Register::test_name;

  $storage::Register::test_name = 'none'
   unless $storage::Register::test_name;

  return 1;

}

#-------------------------------------------------------------------------------
# FUNCTION :  get_fn_results($)
#
# DESC     : 
# return the captured results for a function call
#
# ARGS     :
#  $  - mangled interface name
#
#-------------------------------------------------------------------------------
sub get_fn_results($)
{
     
  my ( $interface_name) = @_;

  $interface_name =~ s/\s+//;

  warn "Interface name expected as arg in get_fn_results\n"
   and return
    unless $interface_name;

  $interface_name  =~ s/\./_dt_/g;
   
   if 
   ( 
    not $read_fn_results_ref
     or ref($read_fn_results_ref) !~ /HASH/i
      or not keys %{$read_fn_results_ref} 
   )
   {

     my $test_file = catfile($storage::Register::test_directory,"$storage::Register::test_name.dat");

     stat($test_file);

     warn "File $test_file for captured regression test data is not accessible\n"
      and return
       unless -e $test_file and -r $test_file;

     $read_fn_results_ref = do "$test_file"
      or warn "Failed to reach the captured data from file $test_file\n"
       and return; 
  
     warn "Failed to read the captured test results from file $test_file\n"
      and return 
       unless 
      (
       $read_fn_results_ref
        and ref($read_fn_results_ref) =~ /HASH/i
         and keys %{$read_fn_results_ref}
      );

   }

   warn "No interfaces saved for metric $storage::Register::metric_name, ".
    "Failed to find the interface name $interface_name in test $storage::Register::test_name\n"
     and return 
      unless $read_fn_results_ref->{$storage::Register::metric_name};

   warn "Failed to find the interface name $interface_name in test $storage::Register::test_name\n"
    and return 
     unless $read_fn_results_ref->{$storage::Register::metric_name}{$interface_name};

   my $fnresults = $read_fn_results_ref->{$storage::Register::metric_name}{$interface_name};

   my $VAR1;

   eval $fnresults
    or warn "Failed to eval results for interface $interface_name , $fnresults\n"
     and return;

   return $VAR1;

}


#-------------------------------------------------------------------------------
# FUNCTION :  save_fn_results($$)
#
# DESC     : 
# Save the test results for a function call
#
# ARGS     :
#  $  - mangled interface name
#  $  - ref or scalar results
#
#-------------------------------------------------------------------------------
sub save_fn_results($$)
{

  my ( $interface_name, $fn_results) = @_;

  $interface_name =~ s/\s+//;

  warn "Interface name expected as arg in save_fn_results\n"
   and return
    unless $interface_name;

  $interface_name  =~ s/\./_dt_/g;

  #-----------------------------------------------------------------------------
  # Read the saved function result hash, if the metri is keys|alias|issues
  # and the mode is capture
  #-----------------------------------------------------------------------------
  # Use the existing functions for the issues, keys and alias metrics
  if 
  ( 
    $storage::Register::metric_name !~ /data/  
     and not keys %storage::Register::write_fn_results
  )
  {

    # Read the test results if the earlier results exist in file
    my $test_file = 
     catfile($storage::Register::test_directory,"$storage::Register::test_name.dat");

    stat($test_file);

    warn "File $test_file for captured regression test data is not accessible\n"
     and return
      unless -e $test_file and -r $test_file;

    $read_fn_results_ref = do "$test_file"
     or warn "Failed to reach the captured data from file $test_file\n"
      and return;
   
    warn "Failed to read the captured functions results from file $test_file\n" 
     and return
      unless $read_fn_results_ref 
       and ref($read_fn_results_ref ) =~ /HASH/i;

    %storage::Register::write_fn_results =
     %{$read_fn_results_ref};

  }

  return 1 
   if $storage::Register::write_fn_results{$storage::Register::metric_name}{$interface_name};

  my $dumped_results = Dumper($fn_results)
   or warn "Failed to save results for function $interface_name\n"
    and return;

  $storage::Register::write_fn_results{$storage::Register::metric_name}{$interface_name} = $dumped_results;

  return 1;

}

#-------------------------------------------------------------------------------
# FUNCTION :  save_results_to_file()
#
# DESC     : 
# Save all the test results to <testfile>.dat 
#
# ARGS     :
#
#-------------------------------------------------------------------------------
sub save_results_to_file()
{
  warn "No results captured for test $storage::Register::test_name\n"
   and return 
    unless 
     keys %storage::Register::write_fn_results;

  my $target_name = get_target_name() 
   or warn "Failed to get the target_name for the target\n"
    and return;

  $storage::Register::test_desc = 
   "$target_name-$storage::Register::test_desc"
     if $target_name;

  save_fn_results('desc',$storage::Register::test_desc)
   or warn "Failed to save the description for test $storage::Register::test_name\n"
    and return;
 
  $Data::Dumper::Indent = 2;
  my $thewholestrg = Dumper(\%storage::Register::write_fn_results)
   or warn "Failed to save the results for test $storage::Register::test_name\n"
    and return;

  my $test_file = 
    catfile($storage::Register::test_directory,"$storage::Register::test_name.dat");

  stat($test_file);

  warn "File $test_file for captured regression test data is not accessible\n"
    and return
     if -e $test_file and not -w $test_file;

  open(FH,">$test_file")
   or warn " Failed to open file $test_file for capturing test results \n"
    and return;

  print FH $thewholestrg;

  close(FH);

  return 1;

}

#-------------------------------------------------------------------------------
# FUNCTION : regression_test
#
# DESC 
# Perform a capture for regression test, or perform a regression_test
# Specified by enironment variables
#
# ARGUMENTS
# sub name
# reference to the sub to be executed
# reference to the list of arguments to the sub
#
#-------------------------------------------------------------------------------
sub regression_test($\&\@)
{

  my ($sub,$sub_ref,$array_ref) = @_;

  my @args = @$array_ref;

  #-----------------------------------------------------------------------------
  # fall thru below this line only for test mode
  # either REGRESSION or CAPTURE
  #-----------------------------------------------------------------------------
  # The test mode validation
  warn "Unknown run mode $storage::Register::run_mode , can be REGRESSION or CAPTURE\n"
   and return
    unless 
    (
     $storage::Register::run_mode
      and $storage::Register::run_mode =~ /REGRESSION|CAPTURE/i
    );

  # There should be a metricname defined at this point
  warn "Metric name for execution not specified, metric name required \n"
   and return
    unless $storage::Register::metric_name;

  # set up the test directories if they are not initialized
  # this should be done once per execution
  if 
  ( 
    not $storage::Register::test_name  
     or not $storage::Register::test_directory
  )
  {
    setup_test_directories() or return;
  }

  # testname is none , skip regression 
  # execute the subroutine and return as in a normal run
  return &$sub_ref(@args) 
   if $storage::Register::test_name =~ /^none$/;
 
  return unless $storage::Register::test_directory;

  stat($storage::Register::test_directory);
 
  return 
   unless
   (
       -e $storage::Register::test_directory
        and -d $storage::Register::test_directory
         and -w $storage::Register::test_directory
   );

  #-----------------------------------------------------------------------------
  # Start Regression or capture
  #-----------------------------------------------------------------------------
  # create a mangled name for capture and regression test mode
  my $function_name = "fn_$sub";

  # Get the file seperator
  $file_seperator = get_file_seperator() or
   warn " Failed to get file seperator for host \n"
    and return;

  # mangle the arguments into a function_name to be saved as a file
  # for non scalar refs, put the ref type and not the address
  # the function counter will take care of opening the right file
  # durign regression
  map 
  { 
    my $element_value = $_;
    my $ref_type = ref($element_value); 

    if ( not $ref_type )
    { 
      $function_name =  "$function_name\_$element_value";
    }
    elsif (  $ref_type =~ /SCALAR/i )
    {
      $function_name = "$function_name\_$$element_value";
    }
    else
    {
      $function_name = "$function_name\_$ref_type";
    }

  } @args if @args;

 
  # Remove these special characters from the file name
  $function_name =~ s/\@/_a_/g;
  $function_name =~ s/\&/_am_/g;
  $function_name =~ s/\*/_as_/g;
  $function_name =~ s/\\/_b_/g;
  $function_name =~ s/\(|\)|{|}|\[|\]/_br_/g;
  $function_name =~ s/\^/_c_/g;
  $function_name =~ s/\$/_d_/g;
  $function_name =~ s/\./_do_/g;
  $function_name =~ s/\!/_e_/g;
  $function_name =~ s/\`/_es_/g;
  $function_name =~ s/\=/_eq_/g;
  $function_name =~ s/$file_seperator/_fs_/g;
  $function_name =~ s/\#/_h_/g;
  $function_name =~ s/\-/_hf_/g;
  $function_name =~ s/\n/_nl_/g;
  $function_name =~ s/\+/_p_/g;
  $function_name =~ s/\|/_pp_/g;
  $function_name =~ s/\s+/_s_/g;
  $function_name =~ s/\~/_t_/g;
  $function_name =~ s/\,/_cm_/g;
  $function_name =~ s/\:/_sc_/g;

  warn "Failed to generate a function signature for sub $sub \n" 
   and return unless $function_name;

  # Appened a count to the storage function name 
  # The same function may be invoked multiple times with
  # different results
  $storage::Register::regression_fn_count{$function_name}=0
   unless $storage::Register::regression_fn_count{$function_name};

  $storage::Register::regression_fn_count{$function_name}++;

  $function_name = "$function_name\_cnt\_$storage::Register::regression_fn_count{$function_name}";

  #------------------------------------------------------------
  # If test regression mode read from stored file and return 
  # results
  #------------------------------------------------------------
  if ( $storage::Register::run_mode =~ /REGRESSION/i )
  {
    
    # no results expected, execute the function and return
    return &$sub_ref(@args) if not defined wantarray;

    my $result_ref = get_fn_results($function_name) 
     or warn "Failed to get captured results for interface $function_name for regression \n"
      and return;

    # results expected is a list
    if ( wantarray )
    {
      return @$result_ref; 
    }
    else
    # result expected is a scalar or 
    # a reference to a list
    {
     my $ref_type = ref($result_ref);

     # if the result read is a reference to a scalar, 
     # return scalar value
     return $$result_ref if $ref_type =~ /SCALAR/i;

     # if result read is a ref to a list , return reference
     return $result_ref;
    }

  }

  #------------------------------------------------------
  # fall thru below this line only If test capture mode
  #------------------------------------------------------

  # no results expected, so nothing to capture, 
  # execute the subroutine and return
  return &$sub_ref(@args) if not defined wantarray;

  #------------------------------------------------------
  # fall thru below this line only If return value is 
  # expected
  #------------------------------------------------------

  # If an list result is expected 
  if ( wantarray )
  {

   my @results_array =  &$sub_ref(@args);

   # Store the results
   save_fn_results($function_name,\@results_array)
    or return;

   # return the results
   return @results_array;
  
  }
  else
  # an scalar result is expected
  # scalar could be an reference to a list
  {

   my $results_ref = &$sub_ref(@args);
   my $store_results_ref = $results_ref;

   # if result is not a ref
   # take a pointer to the scalar
   # to store results
   my $ref_type = ref($results_ref);
   $store_results_ref = \$results_ref unless $ref_type;

   # Store the results
   save_fn_results($function_name,$store_results_ref)
    or return;

   # return the results
   return $results_ref;

  }

}

#-----------------------------------------------------------------------------------------
# FUNCTION : AUTOLOAD
#
# DESC 
# Autoload and execute the sub if sub is registered and defined
#
# ARGUMENTS
# Args to be passed to the sub
#
#-----------------------------------------------------------------------------------------
sub AUTOLOAD
{
    
  my @args = @_;

  my $sub = $AUTOLOAD;
    
  $sub =~ s/.*:://;	
    
  warn "ERROR:Invoked without a subroutine name \n" 
   and return unless $sub;

  # get a ref to the sub if its declared and defined in the register 
  my $sub_ref;
  if  ( $subRegister{$sub} and defined &{$subRegister{$sub}} )
  {
    $sub_ref = $subRegister{$sub};
  }
  else
  # If the sub is not in the register get a pointer thru sRawmetrics
  { 
    my $sub_path = "storage::sRawmetrics::$sub";

    $sub_ref = \&$sub_path;
  }

  # If the sub is not defined return with warn
  warn "ERROR:Function $sub is not found in storage perl modules \n" 
   and return 
    unless $sub_ref;

  # executed this subroutine and return if run mode is either regression or capture
  return &$sub_ref(@args) 
   unless $storage::Register::run_mode;

  #-----------------------------------------------------------
  # fall thru below this line only for test mode
  # either REGRESSION or CAPTURE
  #-----------------------------------------------------------
  return regression_test($sub,&$sub_ref,@args);

}


#End block , invoked when unloading the module

END
{

  # If in capture mode, persist the function
  # call results to a file
  if 
  ( 
   $storage::Register::run_mode
    and $storage::Register::run_mode =~ /CAPTURE/i 
  )
  {
    save_results_to_file() 
     or warn "Failed to persist the captured test results to a file in save_results_to_file\n"
      and return;
  }

}

1; #Returning a true value at the end of the module

