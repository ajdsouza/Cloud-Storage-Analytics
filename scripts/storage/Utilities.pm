#
# Copyright (c) 2001, 2005, Oracle. All rights reserved.  
#
#  $Id: Utilities.pm 06-feb-2005.20:45:44 ajdsouza Exp $ 
#
#
# NAME  
#   Utilities.pm
#
# DESC 
#   utility subroutines 
#
#
# NOTES
#
# MODIFIED  (MM/DD/YY)
# ajdsouza 02/02/05 - fix bug in bulding param list, null check added
# ajdsouza 01/26/05 - log_message to keep message_counter instead of message 
#                     text
# ajdsouza 12/02/04 - add sub get_agentstatetarget_dir 
# ajdsouza 11/18/04 - Use id for nls messages in log_message
# ajdsouza 09/29/04 - 
# ajdsouza 09/07/04 - add namespace for nls messages,index message to make 
#                     sure uniqueness
# ajdsouza 08/13/04 - 
# ajdsouza 08/06/04 - 
# ajdsouza 07/27/04 - 
# ajdsouza 06/25/04 - storage reporting sources 
# ajdsouza 04/09/04 - 
# ajdsouza 04/08/04 - storage perl modules 
# ajdsouza  04/16/02 - Changes for GIT requiements
# vswamida   04/05/02 - getlistswraid returns null for Solaris now; 
#                       getalldiskslices calls listlinuxdiskpartitions.
# ajdsouza   04/04/02 - require v5.6.1
# ajdsouza  04/02/02 - Added the printList, print9IEMList, printEMDList functions
# vswamida  04/02/02 - getalldiskslices now returns null for Linux
# ajdsouza  04/02/02 - Uncommented use stormon_app
# vswamida  03/22/02 - Added stormon_linux
# ajdsouza  10/01/01 - Created
#
#

package storage::Utilities;

require v5.6.1;

use Exporter;
use strict;
use warnings;
use locale;
use Cwd;
use File::Basename;
use File::Spec::Functions;
use File::Path;
use Socket;
use IO::Socket;
use Sys::Hostname;

#-----------------------------------------------------------------------------------------
# Global package variable to hold sub name
our $AUTOLOAD;

#------------------------------------------------------------------------------------
# exports
#---------------------------------------------------------------------------------------
our @ISA = qw(Exporter);
our @EXPORT = qw( 
                  get_agentstate_dir 
                  get_target_name
                  get_agentstatetarget_dir 
                  get_file_seperator 
                );


#-------------------------------------------------
# Variables in package scope
#------------------------------------------------

#-----------------------------------------------------------------------------------------
# subs declared
#-----------------------------------------------------------------------------------------
sub generateDiskId(\%);
sub generateKeys(\%);
sub checkKeys(\%);
sub getDiskVendorData(\%);
sub open_tcp_socket( $$ );
sub get_ip_address ( $ );
sub get_file_seperator();
sub get_absolute_path_start();
sub get_agentstate_dir ();
sub get_target_name ( );
sub get_target_id ( );
sub get_agentstatetarget_dir ();
sub log_message( $$;$$ );
sub log_error_message( $ );
sub get_messages ();
sub get_error_messages ();

#-----------------------------------------------------------------------------------------
# FUNCTION : getDiskVendorData
#
# DESC 
# Gets disk configuration information from the external storage system
# The disk information is attached to the disk hash
# - storage system vendor
# - storage system product
# - storage system id
# - device id of the lun in the external storage system
# - configuration of the disk in the external storage system
#
# ARGUMENTS
# hash reference to the disk data
#
#-----------------------------------------------------------------------------------------
sub getDiskVendorData(\%)
{
  
  my $diskref = $_[0];
  
  warn " Vendor information not found for $diskref->{nameinstance}\n" 
   and return 
    if not exists $diskref->{vendor};
  
  warn " Product information not found for $diskref->{nameinstance}\n" 
   and return
    if not exists $diskref->{product};

  # Vendor = EMC / SYMETRIX
  storage::Register::getEmcDiskData($diskref) 
   and return 1
    if  $diskref->{vendor} =~ /EMC/i;
  
  # Vendor = SUN / T300
  storage::Register::getSunDiskData($diskref) 
   and return 1
    if  $diskref->{vendor} =~ /SUN/i and $diskref->{product} =~ /T300/i;
  
  # Vendor = HITACHI / *
  storage::Register::getHitachiDiskData($diskref) 
   and return 1
    if $diskref->{vendor} =~ /HITACHI/i;
  
}

#-----------------------------------------------------------------------------------------
# FUNCTION : generateDiskId
#
# DESC 
# Generates a unique ID for the disk to be held in the disk_key hash
#
# ARGUMENTS
# hash reference to the disk data
#
#-----------------------------------------------------------------------------------------
sub generateDiskId(\%)
{
  
  my $diskref = $_[0];
  
  warn " Vendor information not found for $diskref->{nameinstance}\n" 
   and return 
    if not exists $diskref->{vendor};
  
  warn " Product information not found for $diskref->{nameinstance}\n" 
   and return 
    if not exists $diskref->{product};
  
  # Vendor = EMC / SYMETRIX
  storage::Register::generateEmcDiskId($diskref) 
   and return 1 
    if  $diskref->{vendor} =~ /EMC/i;
  
  # Vendor = SUN / T300
  storage::Register::generateSunDiskId($diskref) 
   and return 1 
    if  $diskref->{vendor} =~ /SUN/i 
     and $diskref->{product} =~ /T300/i;
  
  # Vendor = HITACHI / *
  storage::Register::generateHitachiDiskId($diskref) 
   and return 1
    if $diskref->{vendor} =~ /HITACHI/i; 
  
}

#-----------------------------------------------------------------
# FUNCTIONS : generateKeys 
#
#
# DESC : Generate a key for each disk to consistently 
# identify the disk
#
# ARGUMENTS :
#  referece to a hash of disk hashes
#
#
#-----------------------------------------------------------------
sub generateKeys(\%)
{
  
  my ( $disk_ref ) = @_;

  warn "The reference for the disk data is not a Hash, Hash expected\n"
   and return
    unless ref($disk_ref) =~ /HASH/i;

  my %disks = %$disk_ref;
  
  for my $key( keys %disks )
  {
    
    my @values;
    
    # Call vendor specifc sub to generate the disk_key
    storage::Utilities::generateDiskId(%{$disks{$key}});
    
    # If disk_key succesfully generated skip to the next disk
    next if $disks{$key}->{disk_key};
    
    # Genrate the key from the canadidate fields in the config information
    if ( 
         $disks{$key}->{vendor} and 
          $disks{$key}->{product} and 
           $storage::Register::config{key}{lc "$disks{$key}->{vendor}-$disks{$key}->{product}"} 
    )
    {
      @values = split /\s+/,$storage::Register::config{key}{lc "$disks{$key}->{vendor}-$disks{$key}->{product}"};
    }
    elsif ( $disks{$key}->{vendor} and $storage::Register::config{key}{lc $disks{$key}->{vendor}} )
    {
      @values = split /\s+/,$storage::Register::config{key}{lc $disks{$key}->{vendor}};
    }
    else
    {
            
      @values = split /\s+/,$storage::Register::config{key}{default};
    }
    
    # Generate the key from the list of candiate fields
    for ( @values )
    {

      $disks{$key}->{keytype} = $_ and $disks{$key}->{disk_key} = "$disks{$key}->{vendor}-$disks{$key}->{$_}" and last if $disks{$key}->{$_};
      
    }
    
    if ( not $disks{$key}->{disk_key} )
    {

      storage::Register::log_message('ERROR_INST_NO_GID','ACTION_INST_RESOLV_ISSUE',$disks{$key})
       or warn "Failed to log message for no global unique id\n"
        and return;

      # If diskkey is still not generated , generate one from the target_id, 
      # nameinstance  or key_value , These are not global but are local to the host
      $disks{$key}->{disk_key} = storage::Register::get_target_id() 
       or warn "ERROR:Failed to get an target id for the host \n"
        and return; 
    
      $disks{$key}->{disk_key} = "$disks{$key}->{disk_key}_$disks{$key}->{nameinstance}" 
       and next 
        if $disks{$key}->{nameinstance};

      $disks{$key}->{disk_key} = "$disks{$key}->{disk_key}_$disks{$key}->{key_value}" 
       and next 
        if $disks{$key}->{key_value};
    }


  }
  
  return 1;

}

#-----------------------------------------------------------------
# FUNCTIONS : checkKeys
# (For future use)
#
# DESC : Check if keys pass a few checks,
#
# ARGUMENTS :
#  reference to a hash of disk hashes
#
#-----------------------------------------------------------------
sub checkKeys(\%)
{

  my %count;
  my %list;

  my %disks = %{$_[0]};

  for my $key( keys %disks )
  {
    # Take a count of the keys
    if ( $disks{$key}->{diskkey} )
    {
      $count{$disks{$key}->{keytype}}{$disks{$key}->{diskkey}}++;
      push @{$list{$disks{$key}->{diskkey}}},$disks{$key};
    }
  }


  for my $key ( keys %list )
  {

    my %keycheck;

    for my $disk ( @{$list{$key}} )
    {

      # Check if controller repeats for the same key
      $keycheck{$disk->{controller}}++ if $disk->{controller};

      warn " Controller repeats for $key \n" and last 
       if $keycheck{$disk->{controller}} and $keycheck{$disk->{controller}} > 1;

      # check if 2 pseudos repeat for the same key
      $keycheck{pseudo}++ if $disk->{diskpath} =~ /\/devices\/pseudo/i;

      warn "pseudos repeat for $key \n" and last 
       if $keycheck{pseudo} and $keycheck{pseudo} > 1;

    }

    # check if a pseudo exists if key count > 1
    warn "Multipathed without pseudo parent/layered driver \n" 
     if @{$list{$key}} > 1 and grep /\/devices\/pseudo/i, @{$list{$key}};

  }


  for my $type ( keys %count)
  {

    print "$type\n";

    for ( keys %{$count{$type}} )
    {

      print "\t$_ - $count{$type}{$_} \n";

      for my $disk ( @{$list{$_}} )
      {
         warn "\t\t $disk->{diskpath} \n";
      }

    }

  }

}

#---------------------------------------------------------------------------------------
# FUNCTION :    open_tcp_socket
#
# DESC
# Create and return a tcp socket handle
#
# ARGUMENTS
# Hostname and port number
#---------------------------------------------------------------------------------------
sub open_tcp_socket( $$ )
{
  my ($host,$port) = @_;
  
  my $socket = IO::Socket::INET->new
      (
       PeerAddr => $host,
       PeerPort => $port,
       Proto    => "tcp",
       Type     => SOCK_STREAM,
       Timeout  => 2
      ) or return;
  
  return $socket;
}


#---------------------------------------------------------------------------------------
# FUNCTION :    get_ip_address
#
# DESC
# return an internet protocol adddress of form \d+.\d+.\d+.\d+
#
# ARGUMENTS
# Hostname 
#---------------------------------------------------------------------------------------
sub get_ip_address( $ )
{
  my ($host) = @_;
  
  my $opq_address = inet_aton($host);

  return unless $opq_address;

  my $ip_address =  inet_ntoa($opq_address);

  return $ip_address;

}

#-----------------------------------------------------------------------------------------
# FUNCTION : get_absolute_path_start
#
# DESC 
# return the begin file path pattern or root directory
#
# ARGUMENTS
#
#-----------------------------------------------------------------------------------------
sub get_absolute_path_start ()
{

  return $storage::Register::abs_path_start
   if $storage::Register::abs_path_start;
 
  return $storage::Register::abs_path_start
   if $storage::Register::abs_path_start;

   $storage::Register::abs_path_start =
    rootdir();
 
  return $storage::Register::abs_path_start
   if $storage::Register::abs_path_start;

   return;

}

#-----------------------------------------------------------------------------------------
# FUNCTION : get_file_seperator
#
# DESC 
# return the file seperator based on the OS
#
# ARGUMENTS
#
#-----------------------------------------------------------------------------------------
sub get_file_seperator ()
{

  return $storage::Register::file_seperator
   if $storage::Register::file_seperator;
 
  return $storage::Register::file_seperator
   if $storage::Register::file_seperator;

  # use the perl File module to figure out the seperator
  my $agent_state_dir = get_agentstate_dir() or return;

  my $temp_path = catfile($agent_state_dir,"file_sep");
  
  # This is to take care of \ characters in the pattern match
  # WIndows always has \ in the path 
  $agent_state_dir =~ s/\\/\\\\/g;

  ( $storage::Register::file_seperator ) = 
   ( $temp_path =~ /$agent_state_dir(.+)file_sep/ );

  return $storage::Register::file_seperator
   if $storage::Register::file_seperator;
  
  my $length = length($agent_state_dir);

  $temp_path = substr($temp_path,$length);

  ( $storage::Register::file_seperator ) = 
   ( $temp_path =~ /(.+)file_sep/  );

  return $storage::Register::file_seperator
   if $storage::Register::file_seperator;

   return;

}


#-----------------------------------------------------------------------------------------
# FUNCTION : get_agentstate_dir
#
# DESC 
# Get an directory to cache data on the host target
#
# ARGUMENTS
#
#-----------------------------------------------------------------------------------------
sub get_agentstate_dir ()
{

  return $storage::Register::agent_state_dir 
   if $storage::Register::agent_state_dir;

  my $devnull =  File::Spec->devnull();

  $storage::Register::agent_state_dir = $ENV{EM_AGENT_STATE} 
   if $ENV{EM_AGENT_STATE};

  stat($storage::Register::agent_state_dir) 
   if $storage::Register::agent_state_dir;

  $storage::Register::agent_state_dir = Cwd::abs_path() 
   unless $storage::Register::agent_state_dir 
    and -e $storage::Register::agent_state_dir 
     and -d $storage::Register::agent_state_dir;

  # Create the storage directory if one does not exit
  $storage::Register::agent_state_dir = 
   catfile($storage::Register::agent_state_dir,'storage');

  stat($storage::Register::agent_state_dir);
  
  mkpath($storage::Register::agent_state_dir,0,0777) 
   unless -e $storage::Register::agent_state_dir;

  stat($storage::Register::agent_state_dir);

  $storage::Register::agent_state_dir = Cwd::abs_path() 
   unless $storage::Register::agent_state_dir 
    and -e $storage::Register::agent_state_dir 
     and -d $storage::Register::agent_state_dir 
      and -w $storage::Register::agent_state_dir;

  return $storage::Register::agent_state_dir;

}

#-----------------------------------------------------------------------------------------
# FUNCTION : get_target_name
#
# DESC 
# Get name for the host target
#
# ARGUMENTS
#
#-----------------------------------------------------------------------------------------
sub get_target_name ( )
{

  return $storage::Register::em_target_name 
   if $storage::Register::em_target_name;

  # Read the target_guid passed in the env variable EM_TARGET_NAME
  $storage::Register::em_target_name = $ENV{EM_TARGET_NAME} 
   if $ENV{EM_TARGET_NAME};
  
  return $storage::Register::em_target_name
   if $storage::Register::em_target_name;

  $storage::Register::em_target_name = hostname;
  
  $storage::Register::em_target_name = "local_unknownhostname"
    unless $storage::Register::em_target_name;

  return $storage::Register::em_target_name;

}

#-----------------------------------------------------------------------------------------
# FUNCTION : get_target_id
#
# DESC 
# Get an id for the host target
#
# ARGUMENTS
#
#-----------------------------------------------------------------------------------------
sub get_target_id ( )
{

  return $storage::Register::em_target_id if $storage::Register::em_target_id;

  # Read the target_guid passed in the env variable EM_TARGET_GUID
  $storage::Register::em_target_id = $ENV{EM_TARGET_GUID} if $ENV{EM_TARGET_GUID};
  
  if ( not  $storage::Register::em_target_id )
  {
    $storage::Register::em_target_id = hostname;
  
    $storage::Register::em_target_id = "local_${^O}_$storage::Register::em_target_id" 
      if $storage::Register::em_target_id;
  
    if ( not $storage::Register::em_target_id )
    {

      $storage::Register::em_target_id = "local_unknownhostname";

      storage::Register::log_message('ERROR_INST_NO_TARGET_ID','ACTION_INST_CHECK_AGENT_LOG')
       or warn "Failed to log message for no target id\n"
        and return;

    }

  }

  return $storage::Register::em_target_id;

}

#-----------------------------------------------------------------------------------------
# FUNCTION : get_agentstatetarget_dir
#
# DESC 
# Get the target name specific directory to cache data on the host target
#
# ARGUMENTS
#
#-----------------------------------------------------------------------------------------
sub get_agentstatetarget_dir ()
{

  return $storage::Register::agent_state_target_dir 
   if $storage::Register::agent_state_target_dir;

  # get the agent state dir
  # aim is to create a target_anme dir undert em_agent_state_dir/storage
  my $agent_state_dir = get_agentstate_dir() or
   warn "Failed to get the agent state dir to cache metrics on host \n"
    and return;
   
  my $target_name = get_target_name()
    or warn "Failed to get the target_name for the target\n";
  
  # append target_name to the agent_state_dir
  # use agent_state_dir as dump dest if cannot create dir with target_name
  if ( $target_name )
  {
   
    # remove blank spaces in target_name
    $target_name =~ s/\s+//g;

    # for portability use only 8 digits
    $target_name = substr($target_name,0,8);

    $storage::Register::agent_state_target_dir = 
     catfile($agent_state_dir,$target_name);

    stat $storage::Register::agent_state_target_dir;

    mkpath($storage::Register::agent_state_target_dir,0,0777) 
     unless -e $storage::Register::agent_state_target_dir;
 
    stat $storage::Register::agent_state_target_dir;

    $storage::Register::agent_state_target_dir = $agent_state_dir
     unless -e $storage::Register::agent_state_target_dir
      and -d $storage::Register::agent_state_target_dir
       and -w $storage::Register::agent_state_target_dir;

  }
  else
  {
    $storage::Register::agent_state_target_dir = $agent_state_dir;
  }

  return $storage::Register::agent_state_target_dir;

}

#---------------------------------------------------------------------------------------
# FUNCTION :    log_message
#
# DESC
# Build the list of issue messages to be instrumented for the issues metric
#
# ARGUMENTS
# message nls id, ref to the hash of the instrumented row for which the error occured
#---------------------------------------------------------------------------------------
sub log_message ( $$;$$ )
{
   
  # Build the coma seperated list of parameters for a nlsid and a hashref
  sub get_message_params($;$)
  {

    my ( $message_nls_id,$hash_ref ) = @_;
    my $message_param_list;

    # Read the parameters passed for the message nlsid 
    # The list of possible params is coma seperated for each placeholder number
    # parameters are read from the hash for the storage entity
  
    # If the message has message params to be replaced
    return 
     unless
     ( 
      $storage::Register::message_list{$message_nls_id}
       and $storage::Register::message_list{$message_nls_id}->{message_params}
        and keys %{$storage::Register::message_list{$message_nls_id}->{message_params}}
     );

    # Get parameters for each position
    for my $parameter_no 
    ( 
      keys %{$storage::Register::message_list{$message_nls_id}->{message_params}} 
    )
    {
 
      my $param;

      # Proceed if the parameter values are valid
      if (  $storage::Register::message_list{$message_nls_id}->{message_params}->{$parameter_no} )
      {

        # Pick the parameter values from the metric hash passed
        if ( $hash_ref and keys %{$hash_ref} )
        {
  
          # Get the list of possible params for this placeholder number
          my $parameters = 
           $storage::Register::message_list{$message_nls_id}->{message_params}->{$parameter_no};
         
          if (  ref($parameters) =~ /ARRAY/i )
          {
    
            for my $parameter ( @{$parameters} )
            { 
               # Split the param fields
               my @fields = split/,/,$parameter;
          
               # Pick the right param value for message placeholder
               for my $field ( @fields )
               {
          
                 $field =~ s/^\s+|\s+$//g;
          
                 next unless $hash_ref->{$field};

                 $param .=  "$hash_ref->{$field} "
                  and last 
                   if $param and $hash_ref->{$field};

                 $param =  "$hash_ref->{$field} "
                  and last;
          
               }
      
            }
  
          }
  
        }

       }
      
      $param =~ s/^\s+|\s+$//g;

      $message_param_list = "$message_param_list,$param" 
       and next 
        if $message_param_list 
         and $param;

      $message_param_list = "$message_param_list," 
       and next 
        if $message_param_list;

      $message_param_list = $param 
       and next if $param;

      $message_param_list = ',';
 
    }
  
    return $message_param_list;
 
  }

  # begin function
  my ( $message_nls_id,$action_nls_id,$hash_ref,$type) = @_;

  my $message_param_list;
  my $action_param_list;
  my $message_counter;

  warn "Require a message id for issue and action while logging issues\n"
   and return 
    unless $message_nls_id or $action_nls_id;

  # All nls ids are Upper case 
  $message_nls_id = uc $message_nls_id;
  $action_nls_id = uc $action_nls_id if $action_nls_id;

  # Type is required
  $type = 'ERROR' unless $type;

  for  my $nls_id ( ( $message_nls_id , $action_nls_id ) )
  {

    warn "Unsupprted message id $nls_id while logging issues\n" 
     and return
      unless $storage::Register::message_list{$nls_id};

  }

  # Get the list of parameters for message nlsid
  $message_param_list = get_message_params($message_nls_id,$hash_ref);

  # Read the parameters passed for the message 
  # The list of possible params is coma seperated for each placeholder number
  # parameters are read from the hash for the storage entity

  # Do not Log message if an identical message has already been logged
  my $msg_index = "$message_nls_id-$message_param_list" if $message_param_list;
  $msg_index = "$message_nls_id" unless $msg_index;

  return 1 
   if $storage::Register::logged_message_index{$msg_index};

  # Build a coma seperated action param list for acton nlsid
  $action_param_list = get_message_params($action_nls_id,$hash_ref);

  # Index the message and push it to the message list
  $storage::Register::logged_message_index{$msg_index}=1;

  # keep a count of the messages
  $message_counter = @storage::Register::logged_messages;
  $message_counter +=1;

  push @storage::Register::logged_messages,
   {
    type=>$type,
    message_counter=>$message_counter,
    message_nls_id=>$message_nls_id,
    message_params=>$message_param_list,
    action_nls_id=>$action_nls_id,
    action_params=>$action_param_list
   };

  return 1;

}

#---------------------------------------------------------------------------------------
# FUNCTION :    log_error_message
#
# DESC
# Build the list of error messages encountered during executing of the script
#
# ARGUMENTS
# error message
#---------------------------------------------------------------------------------------
sub log_error_message ( $ )
{

  my ( $message ) = @_;

  # Log a message only once
  return 1
    if $storage::Register::error_stack{$message};

  $storage::Register::error_stack{$message}=1;

  # maintain the serial order of the messages
  my $no_of_messages = keys %storage::Register::error_stack;

  $storage::Register::error_stack{$message}=$no_of_messages;

  return 1;

}
  
#-------------------------------------------------------------------------------
# FUNCTION :    get_messages
#
# DESC
# return a pointer to the list of issue messages 
#
# ARGUMENTS
#
#------------------------------------------------------------------------------
sub get_messages ()
{
  return \@storage::Register::logged_messages;
}

#-------------------------------------------------------------------------------
# FUNCTION :    get_error_messages
#
# DESC
# return a pointer to the list of error messages 
#
# ARGUMENTS
#
#------------------------------------------------------------------------------
sub get_error_messages ()
{
  # Retrun a pointer to an anonymous list of sorted error messages
  # sorted in the same serial order they were logged
  return 
  [
   sort 
   { 
     $storage::Register::error_stack{$a} <=> $storage::Register::error_stack{$b} 
   } 
    keys %storage::Register::error_stack
  ];

}

#-----------------------------------------------------------------------------
# FUNCTION : AUTOLOAD
#
# DESC 
# If sub is not defined here then pass an error message
#
# ARGUMENTS
# Args to be passed to the sub
#
#----------------------------------------------------------------------------
sub AUTOLOAD
{
    
  my $sub = $AUTOLOAD;
    
  warn "Invoked subroutine $sub is not found \n" and return;

}

1; #Returning a true value at the end of the module
