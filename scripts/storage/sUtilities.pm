#
# Copyright (c) 2001, 2005, Oracle. All rights reserved.  
#
#  $Id: sUtilities.pm 02-mar-2005.16:20:34 ajdsouza Exp $ 
#
#
# NAME  
#   sUtilities.pm
#
# DESC 
#   utility subroutines 
#
#
# FUNCTIONS
# run_system_command( @ )   - Call a system command and time it out if necessary
# get_file_type($)
# get_device_id($)
# get_os_identifier_for_os_path( $ )
# get_source_link_file($;$)
# get_os_storage_entity_path ( $ )
# get_mount_privilege($)
# get_server_identifier( $ );
#
# NOTES
#
#
# MODIFIED  (MM/DD/YY)
# ajdsouza   03/02/05 - fixed bug for get_source_link_file to check before
#                        appending file_seperator to the begining
# ajdsouza   02/10/05 - fixed file_seperator bug in get_source_link_file 
# ajdsouza   02/06/05 - qualify error messages to be loaded to rep with ERROR:
# ajdsouza   01/26/05 - check if the cached filesystem exists
# ajdsouza   12/03/04 - get IP address using sockets
#                       moved this file from branch /main/unix
# ajdsouza   09/29/04 - 
# ajdsouza   09/09/04 - 
# ajdsouza   08/18/04 - Cached filesystem to device id comparison
# ajdsouza   08/11/04 - 
# ajdsouza   08/06/04 - 
# ajdsouza   07/20/04 - use perl call for null device
# ajdsouza   07/14/04 - Removed debug print line 
# ajdsouza   06/25/04 - storage reporting sources 
# ajdsouza   05/18/04 - Storage reporting perl modules 
# ajdsouza   04/14/04 - 
# ajdsouza   04/14/04 - UNix based common functions 
# ajdsouza   04/09/04 - 
# ajdsouza   04/08/04 - storage perl modules 
# ajdsouza   04/16/02 - Changes for GIT requiements
# vswamida   04/05/02 - getlistswraid returns null for Solaris now; getalldiskslices calls 
#                       listlinuxdiskpartitions.
# ajdsouza  04/04/02 - require v5.6.1
# ajdsouza  04/02/02 - Added the printList, print9IEMList, printEMDList functions
# vswamida  04/02/02 - getalldiskslices now returns null for Linux
# ajdsouza  04/02/02 - Uncommented use stormon_app
# vswamida  03/22/02 - Added stormon_linux
# ajdsouza  10/01/01 - Created
#
#

package storage::sUtilities;

require v5.6.1;

use strict;
use warnings;
use locale;
use File::Basename;
use File::Spec::Functions;
use storage::Utilities;

BEGIN
{

 use POSIX qw(locale_h);

 my $clocale='C';

 for ( qw ( LC_ALL LC_COLLATE LC_CTYPE LC_TIME LC_NUMERIC LC_MESSAGES LC_MONETARY LANG LANGUAGE ) )
 {
   $ENV{$_}=$clocale;
 }

 setlocale(LC_ALL,$clocale) or warn " Failed to set locale to $clocale \n ";

}

#-----------------------------------------------------------------------------------------
# Global package variable to hold sub name
our $AUTOLOAD;

#-------------------------------------------------------------------
# Variables with package scope
#-------------------------------------------------------------------
#------------------------------------------------------------------------------------
# Static Configuration
#------------------------------------------------------------------------------------

#Ping command pattern by OS
$storage::Register::config{ping}{command}{solaris} = 'ping -s -t<TTL> <TARGET> 64 <NUMPACKETS>';
$storage::Register::config{ping}{command}{linux} = 'ping <TARGET> -s64 -c<NUMPACKETS> -t<TTL>';
$storage::Register::config{ping}{command}{hpux} = 'ping -t<TTL> <TARGET> 64 <NUMPACKETS>';
$storage::Register::config{ping}{command}{windows} = 'ping -l64 -i<TTL> -n<NUMPACKETS> <TARGET>';
$storage::Register::config{ping}{num_of_packets}=2;
$storage::Register::config{ping}{time_to_live}=20;

$storage::Register::config{ping}{results_pattern}{solaris} = '[\d]{1,3}\.[\d]{1,3}\.[\d]{1,3}\.[\d]{1,3}';
$storage::Register::config{ping}{results_pattern}{linux} = '[\d]{1,3}\.[\d]{1,3}\.[\d]{1,3}\.[\d]{1,3}';
$storage::Register::config{ping}{results_pattern}{hpux} = '[\d]{1,3}\.[\d]{1,3}\.[\d]{1,3}\.[\d]{1,3}';
$storage::Register::config{ping}{results_pattern}{windows} = '[\d]{1,3}\.[\d]{1,3}\.[\d]{1,3}\.[\d]{1,3}';

$storage::Register::config{ping}{results_pattern_regex}{solaris} = '([\d]{1,3}\.[\d]{1,3}\.[\d]{1,3}\.[\d]{1,3})';
$storage::Register::config{ping}{results_pattern_regex}{linux} = '([\d]{1,3}\.[\d]{1,3}\.[\d]{1,3}\.[\d]{1,3})';
$storage::Register::config{ping}{results_pattern_regex}{hpux} = '([\d]{1,3}\.[\d]{1,3}\.[\d]{1,3}\.[\d]{1,3})';
$storage::Register::config{ping}{results_pattern_regex}{windows} = '([\d]{1,3}\.[\d]{1,3}\.[\d]{1,3}\.[\d]{1,3})';

#Arp command pattern by OS
$storage::Register::config{arp}{command}{solaris} = 'arp <TARGET>';
$storage::Register::config{arp}{command}{linux} = 'arp <TARGET>';
$storage::Register::config{arp}{command}{hpux} = 'arp <TARGET>';
$storage::Register::config{arp}{command}{windows} = 'arp <TARGET>';

$storage::Register::config{arp}{results_pattern}{solaris} = '.{1,2}:.{1,2}:.{1,2}:.{1,2}:.{1,2}:';
$storage::Register::config{arp}{results_pattern}{linux} = '.{1,2}:.{1,2}:.{1,2}:.{1,2}:.{1,2}:';
$storage::Register::config{arp}{results_pattern}{hpux} = '.{1,2}:.{1,2}:.{1,2}:.{1,2}:.{1,2}:';
$storage::Register::config{arp}{results_pattern}{windows} = '.{1,2}:.{1,2}:.{1,2}:.{1,2}:.{1,2}:';

$storage::Register::config{arp}{results_pattern_regex}{solaris} = '(.{1,2}:.{1,2}:.{1,2}:.{1,2}:.{1,2}:.{1,2})';
$storage::Register::config{arp}{results_pattern_regex}{linux} = '(.{1,2}:.{1,2}:.{1,2}:.{1,2}:.{1,2}:.{1,2})';
$storage::Register::config{arp}{results_pattern_regex}{hpux} = '(.{1,2}:.{1,2}:.{1,2}:.{1,2}:.{1,2}:.{1,2})';
$storage::Register::config{arp}{results_pattern_regex}{windows} = '(.{1,2}:.{1,2}:.{1,2}:.{1,2}:.{1,2}:.{1,2})';
#------------------------------------------------------------------------------------
# exports
#---------------------------------------------------------------------------------------
# No exports

#-----------------------------------------------------------------------------------------
# subs declared
#-----------------------------------------------------------------------------------------
sub run_system_command( @ );
sub get_device_id( $ );
sub get_os_identifier_for_os_path( $ );
sub get_source_link_file( $;$ );
sub get_file_type( $ );
sub get_os_storage_entity_path ( $ );
sub get_mount_privilege( $ );
sub get_server_identifier( $ );

#------------------------------------------------------------------------------------------
# FUNCTION : run_system_command($;$$)
#
# DESC 
# Run a system command , retry n times if it times out
#
# ARGUMENTS
# command to be executed
# timeout in seconds, default 30
# no of tries , default 2. 
#----------------------------------------------------------------------------------------
# hash of list of exit status by command indicating failure , all other exit status for that
# command are construed to be success
my %exitstatuslist;
$exitstatuslist{df}=[];
$exitstatuslist{arp}=[];

sub run_system_command( @ )
{
    
  my ($cmd,$timeout,$tries) = @_;
  my $devnull =  File::Spec->devnull();
    
  $devnull = '/dev/null' unless $devnull;
    
  warn "No command to execute!" 
   and return 
    if not $cmd;
    
  # Disable timeout if nothing was passed as an argument.  
  # (setting alarm to 0 disables it)
  $timeout = 30 if not $timeout;
    
  # Set the number of times to try running the command.
  $tries = 2 if not $tries;
    
  my ( $kid, $FH );
  my @value;
   
  for (1..$tries)
  {
    my $timedout=0;

    warn " Retrying $cmd , Count $_  \n" if $_ > 1;
  
    # Kill process and set error if command times out
    local $SIG{ALRM} = sub 
    { 
      alarm 0;   #reset the alarm
      kill ("KILL", $kid) if $kid; 
      warn " $cmd timed out \n" and $timedout = 1;
    };
  
    eval 
    {
    
      # Set the timeout
      #$timedout=0;
      alarm $timeout;
    
      # return if error during forking of the command
      # discard stderr capture stdout only
      open(OLDERR,">&STDERR") or warn "Failed to open STDERR when executing OS command $cmd\n";
      open(STDERR,"> $devnull");
      $kid = open $FH, "$cmd |";
    
      # Restore STDERR
      close(STDERR);
      open(STDERR,">&OLDERR") or warn "Failed to restore STDERR when executing OS command $cmd\n";
      close(OLDERR);
    
      warn "ERROR:Failed to execute $cmd: $!\n" 
       and return 
        if not $kid;
    
      @value = <$FH> if $FH;
      close $FH;
      alarm 0;  #reset the alarm
    
    };
  
    # Reset the alarm
    alarm 0;
  
    # If timeout error 
    # the signal handler for timeout (ALRM) will set $timedout to 1
    # or
    # if the eval block died then $@ is set to error
    # indicating the die for the eval block
    # $@ is set ONLY if the eval block dies
    next if $timedout or $@;
    
    # If the OS command executed thru open and has set a error then
    # $? is set AFTER close, $! and $^E may or may not be set
    # log error and return
    # $? is 16 bytes , first 8 bytes gives the exit status
    # next 8 bytes indicate the mode of failure
    # Error only if exit status = 1
    # 0 or any other value construed to be a success value
    # df returns values other than 1 to indicate differnt failures
    # ignore these failures for df
  
    my $cmd0 = (split /\s+/,$cmd)[0];
  
    if (
        (
         exists $exitstatuslist{$cmd0} and 
         grep{1 if $?>>8 == $_ }@{$exitstatuslist{$cmd0}}
        )
        or
        (
         not exists $exitstatuslist{$cmd0} and $? >> 8 == 1 
        )
      )
    {
      # Our c executables set the error string in case of error
      if ( @value and $value[0] =~ /error::/i )
      {
        #seperate error messages for the command line error and the
        #error logged from perl
        #ensures command line error is logged once
        warn "$value[0] \n";
        warn "Failed executing $cmd\n";
      }
      else
      {
        warn "ERROR:Failed executing $cmd, $! $^E $? \n";
      }
      
      return;
    }
  
    # Return array or flat structure depending on type of return 
    # placeholder    
    return wantarray ? @value : join("",@value);
  
  }
    
  return;
}

#------------------------------------------------------------------------------------------
# FUNCTION : get_os_identifier_for_os_path
#
# DESC 
# Return tru if the file exists 
#
# ARGUMENTS
# File or device name
#
#-----------------------------------------------------------------------------------------
sub does_file_exist( $ )
{
 
    my ( $fname ) = @_;

    warn "Filename is null \n" 
     and return 
      unless $fname;
    
    stat $fname;

    return unless -e $fname;

    return 1;
}

#------------------------------------------------------------------------------------------
# FUNCTION : get_os_identifier_for_os_path
#
# DESC 
# Get the mountpoint device id , filesystem inode to uniquely identify a file 
# stat returns the inode# of the source file for symbolic links
# 
#
# ARGUMENTS
# File or device name
#
#-----------------------------------------------------------------------------------------
sub get_os_identifier_for_os_path( $ )
{

    my ( $fname ) = @_;

    warn "Filename is null \n" 
     and return 
      unless $fname;
  
    warn "File $fname does not exist / inaccessible \n" 
     and return 
      unless does_file_exist($fname);
    
    my @stats = stat $fname;
    
    warn "stat failed for $fname \n" 
     and return 
      if not $stats[0] 
       or not $stats[1] ;
    
    return "$stats[0]-$stats[1]";
}


#------------------------------------------------------------------------------------------
# FUNCTION : get_source_link_file
#
# DESC 
# Move down all links and return the absolute path of the root link
#
# ARGUMENTS
# absolute Filename
# flag to ignore the lowest symbolic link template
#
#-----------------------------------------------------------------------------------------
sub get_source_link_file($;$)
{
  
  my ( $abs_file, $ignore_flag ) = @_;
  
  warn "Filename is null \n" 
   and return 
    unless $abs_file;
  
  warn "File $abs_file is inaccessible\n" 
   and return 
    unless -e $abs_file;
  
  my $file = $abs_file;

  while ( -l $file )
  {

    last if not $ignore_flag and 
     $storage::Register::config{lowest_symbolic_directory} and 
      $file =~ /$storage::Register::config{lowest_symbolic_directory}/i;
    
    my $linkfile = readlink $file;
    
    # Link file has absolute path
    my $absolute_path_start = get_absolute_path_start();
    $file = $linkfile and next 
     if $linkfile =~ /^$absolute_path_start/ ;
    
    # process the link file with an relative path
    #
    # Break up the link file and source file into dirs.
    my $file_seperator = get_file_seperator()
     or warn "ERROR:Unable to get the file seperator\n" 
      and return;
    
    my @linkdirs = split /$file_seperator/,$linkfile;
    my $filedir = dirname $file;
    my @filedirs = split /$file_seperator/,$filedir;
    
    # while link dirs are relative with a .. 
    # move down on the file dirs (remove last element) and 
    # move up ( remove first element) of link dirs
    while ( $linkdirs[0] =~ /^\.\./ )
    {
      shift @linkdirs;
      pop @filedirs;
    }

    # With no more relative paths join the two
    # paths to get the absolute path
    $file = join($file_seperator,@filedirs,@linkdirs);

    # if file seperator is similar to the absolute path begining
    # it should be appended as split on file_seperator will pluck it out
    $file = "$file_seperator$file"
     if $file
      and $file_seperator =~ /^$absolute_path_start/
       and $file !~ /^$absolute_path_start/;

    warn "ERROR:Link File $file for $abs_file is inaccessible\n" 
     and return $abs_file
      unless -e $file;

  }
  
  return $file;
  
}  


#------------------------------------------------------------------------------------
# FUNCTION : get_file_type
#
#
# DESC
# Return the file type for a special file as _CHARACTERSPECIAL or _BLOCKSPECIAL
# For regular files returns _REGULAR and directories as _DIRECTORY, others UNKNOWN
#
# ARGUMENTS:
# file or device name
#
#------------------------------------------------------------------------------------
sub get_file_type($)
{
  
  my $file_type;

  my ( $fname ) = @_;

  warn " Filename is null \n" and return unless $fname;
  
  warn " File $fname does not exist / inaccessible \n" and return unless does_file_exist($fname);
  
  my @stats = stat $fname;
  
  $file_type = 'FIFO_SOCKET_TTY' if -p _ or -S _  or -t _;
  
  # Block or Character
  $file_type .= '_CHARACTERSPECIAL' if -c _;
  $file_type .= '_BLOCKSPECIAL' if -b _;
  
  # Regular or special
  $file_type .= '_REGULAR' if -f _;
  $file_type .= '_DIRECTORY' if -d _;
  
  return $file_type;

}

#------------------------------------------------------------------------------------------
# FUNCTION : get_device_id
#
# DESC 
# Get the device id to uniquely identify a mountpoint 
#
# ARGUMENTS
# File or device name
#
#-----------------------------------------------------------------------------------------
sub get_device_id($)
{
  my ( $path ) = @_;

  warn " Filename is null \n" and return unless $path;
   
  warn " File $path does not exist / inaccessible \n" 
   and return unless -e $path;
    
  my @stats = stat $path;
    
  warn " stat failed for $path \n" and return 
   if not $stats[0];

  return "$stats[0]";

}

#------------------------------------------------------------------------------------
# FUNCTION : get_os_storage_entity_path
#
#
# DESC Returns the mountpoint for a regular file and the source file
# for a special file with symlink
#
# ARGUMENTS:
# File name
#
#------------------------------------------------------------------------------------
sub get_os_storage_entity_path ( $ )
{
    
  sub get_mountpoint_for_stat_device_id ( $ )
  {

    my ( $stat_device_id ) = @_;
    
    warn "Device ID is null" and return 
     unless $stat_device_id;

    return $storage::Register::mountpoint_id_index{$stat_device_id} 
     if keys %storage::Register::mountpoint_id_index
      and $storage::Register::mountpoint_id_index{$stat_device_id}
       and $stat_device_id eq get_device_id ($storage::Register::mountpoint_id_index{$stat_device_id});

    my $agent_state_target_dir = get_agentstatetarget_dir() or
     warn "ERROR:Failed to get directory to cache mountpoint metrics on host \n"
      and return;

    my $cache_file = catfile($agent_state_target_dir,'nmhsfcsh.txt');

    # Read from the cached file and build the hash
    stat($cache_file);

    if ( -e $cache_file and -r $cache_file )
    {

      if ( not open(CFH,'<',$cache_file) )
      {
        close(CFH) and 
         warn "Failed to open the cache file $cache_file for reading $!\n";
      }
      else
      {
     
        for my $file_record (<CFH>)
        {

          my @values = split/<<</,$file_record;
    
          next unless @values and @values == 2;
    
          map { s/^\s+|\s+$//} @values;
         
          next unless $values[0] and $values[1];
    
          $storage::Register::mountpoint_id_index{$values[0]}=
            $values[1]; 
    
        }
    
        close(CFH) or
         warn "Failed to close the cache file $cache_file after reading \n";

      }
   
    }

    # return the mounpoint from the cached file,
    # checking for the device id of the cached mountpoint will handle stale entries in cached file
    return $storage::Register::mountpoint_id_index{$stat_device_id} 
     if keys %storage::Register::mountpoint_id_index
      and $storage::Register::mountpoint_id_index{$stat_device_id}
       and $stat_device_id eq get_device_id ($storage::Register::mountpoint_id_index{$stat_device_id});

    # mountpoint not found in the cached file
    # instrument a new cached file to get the mountpoint
    %storage::Register::mountpoint_id_index = ();

    storage::Register::get_filesystem_metrics()
     or warn "ERROR:Failed to get the List of filesystems"
      and return;
    
    #----------------------------------------------------------------
    # for each mountpoint maintain a hash of device id to mountpoint
    #----------------------------------------------------------------
    for my $filesystem_ref( @storage::Register::filesystemarray )
    {
      
      next unless $filesystem_ref->{entity_type} =~ /mountpoint/i;            
      
      my $device_id = get_device_id($filesystem_ref->{mountpoint});
      
      $storage::Register::mountpoint_id_index{$device_id} =  $filesystem_ref->{mountpoint};
      
    }

    # Write to the cached file and buld the deviceid-fs hash
    stat($cache_file);
    
    if ( not open(CFH,'>',$cache_file)  )
    {
      close(CFH) 
       and warn "ERROR:Failed to open the cache file $cache_file for writing \n" 
        and return;
    }
    else
    {

      for my $device_id ( keys %storage::Register::mountpoint_id_index )
      {
        next unless $device_id and 
         $storage::Register::mountpoint_id_index{$device_id};
  
        print CFH "$device_id<<<$storage::Register::mountpoint_id_index{$device_id}\n" 
         or warn "Failed to write device id, mountpoint map to cache file $cache_file\n";
      }
      
      close(CFH) or
       warn "Failed to close the cache file $cache_file after writing \n";

    }

    return $storage::Register::mountpoint_id_index{$stat_device_id} 
     if keys %storage::Register::mountpoint_id_index and 
       $storage::Register::mountpoint_id_index{$stat_device_id};

    warn "Failed to return for device id $stat_device_id\n" 
     and return;

  }
  
  my ( $file_name ) = @_;
  
  my $source_file = get_source_link_file($file_name) or 
   warn "ERROR:Failed to check the symbolic links for $file_name" and 
    return;
  
  my $file_type = get_file_type($source_file) or 
   warn "ERROR:Failed to get the file type for file $source_file $file_name" 
    and return;
  
  return $source_file if $file_type 
   and $file_type =~ /SPECIAL/i;
  
  my $mount_point_device_id = get_device_id($source_file) 
   or warn "Failed to get the device id for $source_file ,$file_name \n" 
    and return;
  
  return get_mountpoint_for_stat_device_id($mount_point_device_id) 
   or warn "ERROR:Mount point not found for $file_name";
  
}

#---------------------------------------------------------------------------------------
# FUNCTION :  get_mount_privilege
#
# DESC
# Return a hash array of the filsystem and mount privilege for that filesystem
#
# ARGUMENTS
# mountpoint
#--------------------------------------------------------------------------------------
sub get_mount_privilege($)
  {
    
    warn " Arg null in get_mount_privilege \n" and return unless $_[0];
    
    # Cache the results the first time
    if  ( not keys %storage::Register::mountprivilege )
      {
  
  my %mount_options;
  
  # Execute mount -v twice so it gives a complete 
  # list of mounted filesystems 
  my @dummy = storage::Register::run_system_command("mount -v",120);
  
  for ( storage::Register::run_system_command("mount -v",120) )
    {
      
      chomp;
      
      my @cols = split;
      
      warn " mount option $_ not well formatted, unable to parse values , skipping \n" 
       and next 
        unless @cols > 2;
      
      warn " mount option $_ not well formatted, mountpoint is blank , skipping \n" 
       and next 
        unless $cols[2];
      
      my $mount_point = $cols[2];       
      
      my @options = split /\s+/,$_;
      
      warn " mount option $_ not well formatted, unable to read mount privilege\n" 
       and next  
        unless @options > 5;
      
      $storage::Register::mountprivilege{$mount_point} = 'WRITE' 
       if $options[5] =~ /write|rw/i;
      
      next if $storage::Register::mountprivilege{$mount_point} 
       and $storage::Register::mountprivilege{$mount_point} =~ 'WRITE';
      
      $storage::Register::mountprivilege{$mount_point} = 'READ';
      
    }
  
      }
    
    warn "ERROR:Mount Privilege not found for $_[0] \n" 
     and return unless $storage::Register::mountprivilege{$_[0]};
    
    return $storage::Register::mountprivilege{$_[0]};     
    
  }


#---------------------------------------------------------------------------------------
# FUNCTION :    get_server_identifier
#
# DESC
# Return the description of a given server.  Currently limited to Vendor name and if
# SNMP is active, Product type.
# NOTE: Nfs rpc calls do not provide enough distinguishing information to be a single
# reliable source for determining the vendor of a remote host.  Other checks such as the 
# ones used currently (telnet scan, http banner grab, arp, etc.) would have to be used in
# addition to the rpc calls.  The complexity of developing and maintaining an rpc call
# program did not provide enough added benefit to be worthwhile.
#
# ARGUMENTS
# Hostname
#---------------------------------------------------------------------------------------
# This sub should be deleted Once solaris is taken care of
sub get_server_identifier($)
{
  my $server_name = $_[0];
  my $output;
  my %nfs;
  my $mac_address;
  my $ip_address;
  
  return unless $server_name;

  # Arp
  #
  #isunraa01 (130.35.36.65) at 0:3:ba:5:c7:e4
  #stnfsrr1.us.oracle.com (130.35.38.183) at 2:a0:98:1:12:f6
  #stnfsrr1 (130.35.38.183) at 2:a0:98:1:12:f6
  #stnfsrr1 (130.35.38.183) at 00:00:00:92:a0:98:1:12:f6
  #
  
  # Get the IP address using the generic socket call
  $ip_address = storage::Utilities::get_ip_address($server_name);

  # Use ping is the IP address cannot be obtained thru perl socket calls
  if ( not $ip_address )
  {

    # Ping before performing an arp, ping will populate the routing table with the mac address of the host if the host is in the same subnet        
    my $ping_command = $storage::Register::config{ping}{command}{$^O};
    $ping_command =~ s/<TARGET>/$server_name/;
    $ping_command =~ s/<NUMPACKETS>/$storage::Register::config{ping}{num_of_packets}/;
    $ping_command =~ s/<TTL>/$storage::Register::config{ping}{time_to_live}/;
    
    for my $ping_results ( storage::Register::run_system_command($ping_command,10) )
    {
      chomp $ping_results;
  
      next unless $ping_results =~ /$server_name/i and $ping_results =~ /$storage::Register::config{ping}{results_pattern}{$^O}/;
  
      next if $ping_results =~ /timeout|not\s*found|unreachable|unknown/i;
       
      ( $ip_address) = ( $ping_results =~ m/$storage::Register::config{ping}{results_pattern_regex}{$^O}/ );
  
      last if $ip_address;
    }
  
  }
  
 # Build the arp command ,to get the mac address of the nfs server, the nfs sever should be in the same subnet to get the mac address
  my $arp_command = $storage::Register::config{arp}{command}{$^O};
  $arp_command =~ s/<TARGET>/$server_name/;

  for my $arp_results (storage::Register::run_system_command($arp_command) ) 
  {
  
    chomp $arp_results;
  
    next unless $arp_results =~ /$server_name/i and $arp_results =~ /$storage::Register::config{arp}{results_pattern}{$^O}/;
  
    next if $arp_results =~ /no\s+entry/i;
  
    ( $mac_address ) = ( $arp_results =~ m/$storage::Register::config{arp}{results_pattern_regex}{$^O}/ );
  
    last if  $mac_address;
  
  } 
  
  # The mac adddress is saves if available , nfs server in the same subnet
  $nfs{nfs_server_net_interface_address} = $mac_address if $mac_address;
  
  # Save the IP address if available
  $nfs{nfs_server_ip_address} = $ip_address if $ip_address;
  
  return %nfs;

}

#-----------------------------------------------------------------------------------------
# FUNCTION : AUTOLOAD
#
# DESC 
# If sub is not defined here then look for it in sUtilities.pm
#
# ARGUMENTS
# Args to be passed to the sub
#
#-----------------------------------------------------------------------------------------
sub AUTOLOAD
{
  my ( @args ) = @_;
    
  my $sub = $AUTOLOAD;
    
  $sub =~ s/.*:://;	
    
  my $sub_path = "storage::Utilities::$sub";

  my $sub_ref = \&$sub_path;

  return &$sub_ref(@args);


}

1; #Returning a true value at the end of the module
