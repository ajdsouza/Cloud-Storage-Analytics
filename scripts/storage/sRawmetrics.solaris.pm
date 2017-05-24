#
# Copyright (c) 2001, 2005, Oracle. All rights reserved.  
#
#  $Id: sRawmetrics.pm 04-mar-2005.17:37:57 ajdsouza Exp $
#
#
# NAME
#  sRawmetrics.pm
#
# DESC
# Solaris OS specific subroutines to get disk device information
#
#
# FUNCTIONS
#
#
# NOTES
#
#
# MODIFIED      (MM/DD/YY)
# ajdsouza      03/02/05 - fix os_identifier related bug for disk partitions
# ajdsouza      02/22/05 - moved OSD absolute_path config variable
#                          from sUtilities.pm
# ajdsouza      02/07/05 - qualified msgs to go to the rep with ERROR:
# ajdsouza      02/02/05 - Add directory to filesystem if the filesystem is a directory
#                          mountpoint
# ajdsouza      01/20/05 - add a new record for the disk
# ajdsouza      11/30/04 - 
# ajdsouza      09/28/04 - disk solstice related changes
# ajdsouza      08/05/04 - Split nfs filesystem to server and filesystem, check for format before spliting
# ajdsouza      07/16/04 - Add EMDW to env path
# ajdsouza      06/30/04 - Skip processing the record from nmhs get_solaris_disks with there is a warn or error
# ajdsouza      06/25/04 - storage reporting sources 
# ajdsouza      04/12/04 - 
# ajdsouza      04/08/04 - storage perl modules 
# ajdsouza      04/16/02 - Changes to meet GIT requirements
# ajdsouza      10/01/01 - Created
#
#
#

# Initialize the environment variables at compile time
BEGIN
{
    
  $ENV{PATH} = 
   "/usr/xpg4/bin:/bin:/usr/bin:/usr/sbin:/etc:/sbin:/usr/opt/SUNWmd/sbin";

  $ENV{PATH} =
   "$ENV{ORACLE_HOME}/emdw/bin:$ENV{ORACLE_HOME}/bin:$ENV{ORACLE_HOME}/emagent/bin:$ENV{PATH}"
     if $ENV{ORACLE_HOME};

}

package storage::sRawmetrics;

require v5.6.1;

use strict;
use warnings;
use locale;
use File::Basename;
use File::Spec::Functions;
use File::Path;
use Cwd;
use URI::file;
use storage::sUtilities;
use Data::Dumper;
$Data::Dumper::Indent = 2;

#------------------------------------------------
# Global package variable to hold sub name

our $AUTOLOAD;

#------------------------------------------------
# subs declared
#-----------------------------------------------
sub get_disk_metrics;
sub get_virtualization_layer_metrics ( );
sub get_veritas_volume_metrics();
sub get_solaris_swraid;
sub get_filesystem_metrics ( );
sub cacheLogicalPhysicalMap;
sub getLogicalName( $ );
sub runShowmount ( $ );

#-------------------------------------------------
# Variables in package scope
#------------------------------------------------
# Variable for logical to physical map for all disk slices
my %logicallist;

#------------------------------------------------------------------------------------
# Static Configuration
#------------------------------------------------------------------------------------

# candidate fields for choosing unique key for disks
$storage::Register::config{key}{emc}=
"sq_serial_no deviceid";
$storage::Register::config{key}{'emc-symmetrix'}=
"sq_serial_no deviceid";
$storage::Register::config{key}{hitachi}=
"sq_hitachi_serial deviceid";
$storage::Register::config{key}{symbios}=
"sq_vendorspecific sq_vpd_pagecode_83 deviceid";
$storage::Register::config{key}{default}=
"sq_vendorspecific deviceid sq_serial_no";

# Order of choice from among candidates for a field
$storage::Register::config{fields}{vendor}=[qw(scsivendor sq_vendor)];
$storage::Register::config{fields}{product}=
[qw(scsiproduct sq_product)];
$storage::Register::config{fields}{storage_disk_device_id}=
[qw(scsiserial sq_serial_no)];
$storage::Register::config{fields}{capacity}=[qw(sq_capacity)];

# order of choice only if field is null or not defined
$storage::Register::config{nullfields}{name}=
 [qw(logical_name physical_name nameinstance)];

# List of fields to be common for each slice of a disk
$storage::Register::config{diskfields}{PARTITION}=
 [qw(disk_key vendor product storage_system_id 
      storage_spindles storage_system_key 
       storage_disk_device_id device_status)];

# List of fields common or slices representing disks
$storage::Register::config{diskfields}{DISK}=
 [qw(disk_key slice_key vendor product capacity storage_system_id 
      storage_spindles storage_system_key 
       storage_disk_device_id device_status)];

# scsi inquiry fields we are interested in
$storage::Register::config{scsiinqfields}= 
 "sq_vendor|sq_product|sq_revision|sq_serial_no|sq_capacity|sq_hitachi|sq_vendorspecific|sq_vpd_pagecode_83";

# Metadisk configuration for solaris
$storage::Register::config{solaris}{solstice}{metadevices}{dir}='/dev/md';
$storage::Register::config{solaris}{solstice}{metadevices}{blocksize}=512;
$storage::Register::config{solaris}{solstice}{metadevices}{dirs_ignore}= '\.|\.\.';

# Do not go below this directory when getting the source file in a symbolic link
# /dev/rdsk this is prefered over physical path /devices/ for soalris
# /dev/md for metadevices
$storage::Register::config{lowest_symbolic_directory} = '/dev/rdsk/c\d+t\d+d\d+|/dev/dsk/c\d+t\d+d\d+|/dev/md';

# Directory for disk devices
$storage::Register::config{disk_directory}{block}='/dev/dsk';
$storage::Register::config{disk_directory}{raw}='/dev/rdsk';

#Versions supported
$storage::Register::config{osversions}="5.7|5.8|5.9";

#--------------------------------------------------------
# Filesystem metric specific configuration
#--------------------------------------------------------
# Filesystem commands tend to hang due to rpc
# to ensure atleast ufs and vxfs are instrumented in such a case
# exceute the ufs and vxfs commands exclusively than those that may involve rpc's
# The commands to execute for getting filesystems
$storage::Register::config{filesystem}{command}{ufs}   = "df -P -F ufs";
$storage::Register::config{filesystem}{command}{vxfs}  = "df -P -F vxfs";

# df shows swap filesystems only as "swap". `swap -l` shows a list of
# filesystems that are used for swap space.
$storage::Register::config{filesystem}{command}{swap}  = "swap -l";

# The commands to execute for getting all Local filesystems
$storage::Register::config{filesystem}{command}{local} = "df -P -l";

# the local and nfs filesystems are got in two seperate calls
# to avoid nfs rpc hangs from intefering local filesystems
$storage::Register::config{filesystem}{command}{nfs}   = "df -P -F nfs";

# Filesystems to skip, need not instrument metrics for these filesystems
$storage::Register::config{filesystem}{skipfilesystems} = 
  "mvfs|proc|fd|mntfs|tmpfs|cachefs|shm|cdfs|hsfs|lofs";


#------------------------------------------------------------------------------------
# FUNCTION : get_disk_metrics
#
#
# DESC
# return a array of hashes listing all disks and their configuration 
#
# ARGUMENTS:
#
# TODO 
# For NOMINORS move diskpath to physical path if no physicalpath, flag status as no minor
# nodes
#------------------------------------------------------------------------------------
sub get_disk_metrics
{
  
  # arrays to store disks, disk controllers and hash of disk configuration
  my %disks; 
  my @slices;
  my %disklist;
  my $version;
  my $isalist;
  
  # Get the OS version
  chomp ($version = run_system_command("uname -r"));
  
  # Check if OS version is supported
  warn "ERROR:OS version $version currently not supported \n" 
   and return 
    if $version !~ /($storage::Register::config{osversions})/i;
  
  # Disover all disks and process the results
  # ON large hosts kdisks takes a while to execute
  for ( run_system_command("nmhs get_solaris_disks",600) )
  {
 
    my %devinfo;
    
    chomp;
    
    s/^\s+|\s+$//g;
    
    next unless $_;
    
    next if $_ =~ /^(WARN:|error::)/;
   
    (
     $devinfo{record_type},
     $devinfo{driver},
     $devinfo{instance},
     $devinfo{vendor},
     $devinfo{product},
     $devinfo{revision},
     $devinfo{scsivendor},
     $devinfo{scsiproduct},
     $devinfo{scsiserial},
     $devinfo{disktype},
     $devinfo{controllertype},# Disk controller
     $devinfo{deviceidtype},
     $devinfo{deviceid},
     $devinfo{disksize},
     $devinfo{formatstatus},
     $devinfo{nsectors},
     $devinfo{whole_disk_physical_name},
     $devinfo{physical_name},
     $devinfo{filetype},
     $devinfo{partition},
     $devinfo{capacity},
     $devinfo{start},
     $devinfo{end}, 
     $devinfo{partitiontype}
    ) = split /\s*\|\s*/;
     
    # Build the name,instance string as name@instance
    $devinfo{nameinstance} = "$devinfo{driver}\@$devinfo{instance}";
    
    # reset the invalid/UNKNOWN number fields
    for ( qw ( partition end start nsectors ) )
    {
      # sometimes $devinfo{$} = 0 is a valid value, so check only 
      # for its existance
      $devinfo{$_} = -1 
       unless exists $devinfo{$_} 
        and $devinfo{$_} =~ /\d+/;
    }
     
    $devinfo{start} = "P$devinfo{partition}" 
     if defined $devinfo{partition} 
      and not $devinfo{start};

    $devinfo{start} = "S" unless $devinfo{start};
  
    $devinfo{end} = ($devinfo{start}+$devinfo{nsectors}) 
     if $devinfo{start} and $devinfo{nsectors}
      and $devinfo{start} =~ /^\d+$/ 
       and $devinfo{nsectors} =~ /^\d+$/;
  
    $devinfo{end} = "$devinfo{start}_$devinfo{nsectors}" 
     if $devinfo{start} 
      and $devinfo{nsectors} and not $devinfo{end};

    $devinfo{end} = $devinfo{nsectors} 
     if $devinfo{nsectors} and 
      not $devinfo{end};

    $devinfo{end} = "P$devinfo{partition}" 
     if defined $devinfo{partition} 
      and not  $devinfo{end};

    $devinfo{end} =  "E" unless $devinfo{end};
   
    # Rest these values to 0 if they are invalid
    for ( qw ( disksize capacity ) )
    {
      $devinfo{$_} = 0 
       unless exists $devinfo{$_} 
        and $devinfo{$_} =~ /^\d+$/;
    } 
    
    # Deduce the type of slice, if it represents the whole disk or a slice
    $devinfo{type} = 'DISK' 
     if $devinfo{formatstatus}
      and $devinfo{formatstatus} =~ /UNFORMATTED/i;
    
    $devinfo{type} = 'PARTITION' unless $devinfo{type};
    
    # The disk must have a physical name on the OS
    if ( $devinfo{type} =~ /DISK/i )
    {
      warn "ERROR:Physical name is not available for the disk device $devinfo{nameinstance}\n" 
        unless $devinfo{physical_name};
    }
    
    if ( $devinfo{physical_name} )
    {
      # Logical name for the disk, ignore if logical name is not found
      $devinfo{logical_name} = getLogicalName($devinfo{physical_name});
      $devinfo{name} = $devinfo{logical_name} 
       if $devinfo{logical_name};
      
      # Get filetype if its not defined or unknown
      $devinfo{filetype} = storage::Register::get_file_type($devinfo{physical_name}) 
       unless $devinfo{filetype} 
        and $devinfo{filetype} !~ /UNKNOWN/i;       
    }
    
    # Keep an list indexed on nameinstance and type
    push @{$disklist{$devinfo{nameinstance}}{$devinfo{type}}}, \%devinfo;
    
    # Lists of disk slices to be instrumentated
    push @slices,\%devinfo;       
 
  }
  
  #------------------------------------------------------------
  # Pick the disk record , build the disk index
  #------------------------------------------------------------
  # Check if a disk record exists for each id, else create one
  # If more than one exist then chose the best one for prcessing
  # disk specific information
  for my $key ( keys %disklist )
  {

    # A disk has been selected for this key  
    next if $disks{$key};

    # 1st choice - an unformatted disk, there is already a disk record
    for my $diskref( @{$disklist{$key}{DISK}} )
    {
      $disks{$key} = $diskref and last;
    }

    next if $disks{$key};

    # 2nd choice take a copy of the backup partition  
    # slice 2 has higher preference over the other backup partitions
    for my $diskref
    ( 
      grep 
      { 
        $_ if $_->{filetype} 
         and $_->{partitiontype} 
          and $_->{filetype} =~ /CHARACTER/ and 
           $_->{partitiontype} =~ /BACKUP/i 
       } 
       sort { return -1 if $a->{partition} and $a->{partition} == 2; return 1;} 
        @{$disklist{$key}{PARTITION}} 
    )
    {

     my %diskrec = %$diskref;
     
     $diskrec{type} = 'DISK';
     $diskrec{capacity} = $diskrec{disksize}
      if $diskrec{disksize};
          
     # Push this disk slice on to the list
     push @slices, \%diskrec;
     
     # Keep an list indexed on nameinstance and type
     push @{$disklist{$diskrec{nameinstance}}{$diskrec{type}}}, \%diskrec;
     
     $disks{$key} = \%diskrec and last;
   
    }
      
    next if $disks{$key};

    # 3rd choice , take a copy of a character partition 
    # slice 2 has preference
    for my $diskref
    ( 
      grep 
      { 
        $_ if $_->{filetype} and $_->{filetype} =~ /CHARACTER/ 
      } 
       sort { return -1 if $a->{partition} and $a->{partition} == 2; return 1;} 
        @{$disklist{$key}{PARTITION}} 
    )
    {
     my %diskrec = %$diskref;
     
     $diskrec{type} = 'DISK';
     $diskrec{capacity} = $diskrec{disksize}
      if $diskrec{disksize};
     $diskrec{start} = 1;
     $diskrec{end} = $diskrec{nsectors};
          
     # Push this disk slice on to the list
     push @slices, \%diskrec;
     
     # Keep an list indexed on nameinstance and type
     push @{$disklist{$diskrec{nameinstance}}{$diskrec{type}}}, \%diskrec;
     
     $disks{$key} = \%diskrec and last;
   
    }
      
    next if $disks{$key};    
            
    warn "No disk available for $key \n" and next;

  }
  
  #---------------------------------------------
  # Processing for records in the disk index
  #---------------------------------------------

  #---------------------------------------------
  # SCSI inquiry
  #--------------------------------------------
  for my $key ( keys %disks )
  {
 
    # inquiry only for CHAR scsi disks
    # Take a chance on UNKNOWN disks and PSEUDO disks, sometimes their
    # controllers cant be identified accurately
    next unless $disks{$key}->{disktype} =~ /DISK_SCSI|DISK_UNKNOWN/i;

    # Cant do a scsi inquiry without the os path
    next unless $disks{$key}->{physical_name};

    #-------------------------------------------- 
    # Manufacture a name for disks without the slice
    #--------------------------------------------
    # The disk name should be without partition number or letter
    undef $disks{$key}->{name}
     if $disks{$key}->{name};

    # 1st choice cndntn 
    # eg. c0t0d0 from c0t0d0s2
    ( $disks{$key}->{name} ) = 
     ( $disks{$key}->{logical_name} =~ /(c\d+t\d+d\d+)/i )
      if $disks{$key}->{logical_name}
       and $disks{$key}->{logical_name} =~ /c\d+t\d+d\d+/i;

    # 2nd choice logical name for pseudo device without slice alphabet
    # eg emcpower0 from emcpower0a
    ( $disks{$key}->{name} ) = 
     ( $disks{$key}->{logical_name} =~ /([^\/]+)\D$/i )
      if not $disks{$key}->{name}  
       and $disks{$key}->{logical_name}
        and $disks{$key}->{logical_name} =~ /([^\/]+)\D$/i;

    # 3rd choice physical name for the disk node
    # take the physical name 
    # eg sd@0
    $disks{$key}->{name} = $disks{whole_disk_physical_name}
      if $disks{whole_disk_physical_name}
       and $disks{$key}->{name};   

    # execute scsi inquiry
    for 
    ( 
     run_system_command
      ("nmhs execute_scsi_inquiry $disks{$key}->{physical_name}",120) 
    )
    {
     
     chomp;
     
     s/^\s+|\s+$//g;
     
     # Skip the scsi fields of no intrest to us
     next unless $_ =~ /^($storage::Register::config{scsiinqfields})/i; 
     
     my ($name,$value) = ( /^\s*(.*)::\s*(.*)/ );
     
     # Regexp is greedy, trailing nulls will be part of value
     $value =~ s/\s+$//g;
     $disks{$key}->{$name} = $value;
     
    }
    
    # Rest these values to 0 if they are invalid
    for ( qw ( sq_capacity ) )
    {
     $disks{$key}->{$_} = 0 
      unless exists $disks{$key}->{$_} 
       and $disks{$key}->{$_} =~ /^\d+$/;
    }
 
  }
  
  #----------------------------------------------------
  # Validate fields for disks
  #----------------------------------------------------
  for my $key ( keys %disks )
  {
 
    # validate the data from config fields
    for my $field( keys %{$storage::Register::config{fields}} )
    {
        
        for ( @{$storage::Register::config{fields}{$field}} )
        {
     
          # If the proposed field is valid and current field is invalid
          # or different from the proposed field, take proposed field
          $disks{$key}->{$field} = $disks{$key}->{$_} 
           if $disks{$key}->{$_} 
            and ( not $disks{$key}->{$field} 
             or $disks{$key}->{$field} ne $disks{$key}->{$_} );  
        }
        
    }
    
    #---------------------------------------------
    # Get vendor data for disks
    #---------------------------------------------
    storage::Utilities::getDiskVendorData(%{$disks{$key}});
     
    #---------------------------------------------
    # Device status for disks
    #---------------------------------------------
    # If disk size is invalid set status as offline
    $disks{$key}->{device_status} .= " DISK_OFFLINE" if 
     not $disks{$key}->{capacity} 
      or $disks{$key}->{capacity} !~ /^\d+$/; 
    
    # Save format status in device status
    $disks{$key}->{device_status} .= 
     " $disks{$key}->{formatstatus}" 
      if $disks{$key}->{formatstatus};
 
 }
  
  #----------------------------------------------
  # Generate keys for disks
  #----------------------------------------------
  generateKeys(\%disks)
   or warn "Failed to generate uniquely identifying disk_keys\n"
    and return;
  

  #----------------------------------------------
  # Create slice keys and validate null fields
  # for disk records
  #----------------------------------------------
  for my $key ( keys %disks )
  {
  
    # Get a reference to the disk for this key
    my $diskref = $disks{$key}; 
    
    # Generate a slicekey for the disk
    $diskref->{slice_key}  =  "$diskref->{disk_key}";
    
    # validate the data from NULL config fields for the disk record
    if ( $storage::Register::config{nullfields} )
    {
      for my $field( keys %{$storage::Register::config{nullfields}} )
      {
        # the field is already defined
        next if $diskref->{$field};

        for ( @{$storage::Register::config{nullfields}{$field}} )
        {

          # If the proposed field is valid and current field is invalid
          $diskref->{$field} = $diskref->{$_} and last 
           if $diskref->{$_} 
            and not $diskref->{$field};  

        }

      }

    }

  }

  #----------------------------------------------
  # Create slice keys for partitions using disk 
  # keys in disk records
  #----------------------------------------------
  for my $key ( keys %disklist )
  {
    # This is an error that should be handled
    warn "No disk for $key \n" 
     and next 
      unless $disks{$key};
    
    # Get a reference to the disk for this key
    my $diskref = $disks{$key}; 
    
    # Get the DISK and PARTITION types for this key
    for my $type ( keys %{$disklist{$key}} )
    {

      # go thru each slice and copy values from the disk
      for my $ref ( @{$disklist{$key}{$type}} ) 
      { 

        # If its a different record from the disk record
        next if $ref eq $diskref;
         
        # Copy the common fields between disk record and current 
        # record
        for ( @{$storage::Register::config{diskfields}{$type}} )
        {
          $ref->{$_} = $diskref->{$_} if $diskref->{$_};
        }
         
        # validate the data from NULL config fields in the current record
        if ( $storage::Register::config{nullfields} )
        {
          for my $field( keys %{$storage::Register::config{nullfields}} )
          {
              for ( @{$storage::Register::config{nullfields}{$field}} )
              {
              # If the proposed field is valid and current field is invalid
               $ref->{$field} = $ref->{$_} and last if $ref->{$_} 
                and not $ref->{$field};  
              }
          }
        }
        
        # Generate a slicekey for each slice
        $ref->{slice_key}  =  "$diskref->{disk_key}-$ref->{partition}" 
         if $type =~ /PARTITION/i;  
          
      }
     
    }
 
  }
  
  #----------------------------------------------
  # Copy the required fields for all records
  #----------------------------------------------
  for my $entity_ref ( @slices )
  {

    $entity_ref->{key_value} = $entity_ref->{slice_key};

    $entity_ref->{storage_layer} = 'OS_DISK ';

    $entity_ref->{entity_type} = 'Disk Partition' 
     if $entity_ref->{type} =~ /PARTITION/i; ;

    $entity_ref->{entity_type} = 'Disk' 
     if $entity_ref->{type} =~ /DISK/i;
  
    $entity_ref->{sizeb} = $entity_ref->{capacity} 
     unless $entity_ref->{sizeb};

    $entity_ref->{os_identifier} = $entity_ref->{logical_name} 
     if not $entity_ref->{os_identifier}
      and $entity_ref->{logical_name};

    $entity_ref->{os_identifier} = $entity_ref->{physical_name} 
     if not $entity_ref->{os_identifier}
      and $entity_ref->{physical_name};

    # a while disk has no is_identifier on solaris
    # its used only thru its slices
    if ( $entity_ref->{entity_type} =~ /^Disk$/i )
    {
      undef $entity_ref->{os_identifier}
       unless 
       (
        $entity_ref->{formatstatus}
          and $entity_ref->{formatstatus} =~ /UNFORMATTED/i
       );
    }

    $entity_ref->{global_unique_id} = $entity_ref->{disk_key} 
     if $entity_ref->{type} =~ /^DISK$/i;
  
    push @{$entity_ref->{parent_entity_criteria}}, 
     { entity_type => 'Disk Partition', 
       disk_key => $entity_ref->{disk_key} } 
        if $entity_ref->{entity_type} =~ /^DISK$/i;

  }
  
  return \@slices;
  
}


#--------------------------------------------------------------------------------
# FUNCTION : get_virtualization_layer_metrics
#
# DESC 
# return a array of hashes for all storage virtualization layers 
# deployed on the host software raid, volume manager etc.
#
# ARGUMENTS
#
#----------------------------------------------------------------------------------
sub get_virtualization_layer_metrics ( )
{
 my @results;
 
 for my $function_pointer 
 ( 
  \&get_veritas_volume_metrics, \&get_solaris_swraid 
 ) 
 {

  my $results_ref = $function_pointer->();

  next unless $results_ref and @{$results_ref};

  push @results,@{$results_ref};

 }
 
 return [()] unless @results;
 
 return \@results;
 
}

#------------------------------------------------------------------------------
# FUNCTION : getVolumeMetrics
#
# DESC 
# return a array of hashes for all volume manager metrics  
#
# ARGUMENTS
#
#-------------------------------------------------------------------------------
sub get_veritas_volume_metrics ( ) 
{
 
 my @path =  qw(
         /usr/sbin/vxprint
         /usr/bin/vxprint
         /etc/vxprint
        );
 
 warn "Veritas VM not installed \n" and return [()] 
  unless grep { -e $_ } @path;
 
 return  storage::vendor::Veritas::get_metrics() or return; 
 
}


#-----------------------------------------------------------------------------
# FUNCTION : get_solaris_swraid
#
# DESC
# Return an array of hashes containing information on the metadisks
# and subdisks that are managed by the Solstice Disk Suite.
#
# ARGUMENTS
#
#----------------------------------------------------------------------------
sub get_solaris_swraid
{

  # Get the list of metadevices in dsk and rdsk
  # directories under a directory
  sub get_metadevices( $ )
  {
     my ( $dir ) = @_;
     my %devs;

     stat $dir;

     warn "Directory to check for metadevices $dir does not exit\n"
      and return 
       unless ( -e $dir and -d $dir);

     for my $diskdir ( qw ( dsk rdsk ) )
     {

       my $mdir = catfile($dir,$diskdir);
     
       stat $mdir;

       next 
        unless ( -e $mdir and -d $mdir);
  
       opendir(MDIR,$mdir) 
        or warn "ERROR:Failed to open Solaris Disk Solstics metadirectory $mdir\n"
         and return;
    
       my @metadevs = readdir(MDIR);
  
       close(MDIR);
    
       for my $mdev ( @metadevs )
       {
         $mdev =~ s/^\s+|\s+$//g;
    
         next if
          $mdev =~ /^($storage::Register::config{solaris}{solstice}{metadevices}{dirs_ignore})$/;
          my $metapath = catfile($mdir,$mdev);

          stat $metapath;
  
          next unless -e $metapath ;

          next if -d $metapath ;

          $devs{$mdev}{$diskdir}=$metapath;

       }

     }
 
     return \%devs; 

  }


  #Parse the results of metahs -i
  #and push metric hash refs to the list array
  sub parse_hotspares ( $$ )
  {

    my ( $mdsaref,$diskset ) = @_;

    # return if first argument is not a list ref
    warn "metadisk reference passed is not a list to get hot spares for $diskset\n"
     and return 
      unless ref($mdsaref) =~ /ARRAY/i;

    my $cmd;
    $cmd = "nmhs execute_metahs -i" 
     if $diskset =~ /none/i;

    $cmd = "nmhs execute_metahs -i -s $diskset" 
     if not $cmd
      and $diskset !~ /none/i;

    warn "A valid diskset is required for getting the hot spares for SUN Disk Solstics\n"
     and return
      unless $cmd;

    # keeps track of the entity the current line from
    # metahs provides
    my $running_entity;

    for my $rslt 
     ( storage::Register::run_system_command($cmd) )
    {
      chomp $rslt;

      $rslt =~ s/^\s+|\s+$//g;

      next unless $rslt;

      # The following rows from metahs start with disk devices
      if ( $rslt =~ /^Device/i )
      {
        $running_entity = 'Device';
        next;
      }
   
      # Skip all non device rows
      next unless $running_entity 
       and $running_entity =~ /Device/i;

      # This is the line for the name of 
      # each hot spare pool
      # hsp001: 3 hot spares
      next if $rslt =~ /:.+hot\s+spare/i;

      # Get the device name and size from
      # c2t5d0s0   Available    204800 blocks
      my ($device,$sizeb) = 
       ( $rslt =~ /^([^\s]+)\s+[^\s]+\s+(\d+)/ );

      $device =~ s/^\s+|\s+$//;

      next unless $device;
      
      #initialize size
      $sizeb = 0 unless $sizeb;

      $sizeb = $sizeb * 
       $storage::Register::config{solaris}{solstice}{metadevices}{blocksize}
        if $sizeb 
         and $rslt =~ /block/i;

      my $diskpath = catfile('/dev/rdsk/',$device);

      my $ftype = storage::Register::get_file_type($diskpath) 
        or next; 

      next unless $ftype =~ /_CHARACTERSPECIAL/i;

      # this device is already instrumented
      if ( $storage::Register::config{solaris}{solstice}{metadevices}{subdisks}{$diskpath} )
      {
        my $sdindxref = 
         $storage::Register::config{solaris}{solstice}{metadevices}{subdisks}{$diskpath};

        $sdindxref->{configuration} = 'Hot Spare';

        $sdindxref->{sizeb} = $sizeb 
         if $sizeb 
          and not $sdindxref->{sizeb};
      
        next 
      }

      my %diskref =
      (
       storage_layer=>'VOLUME_MANAGER',
       vendor=>'SUN',
       product=>'Solaris Disk Solstice',
       entity_type => 'Sub Disk',
       configuration => 'Hot Spare',
       os_identifier => $diskpath,
       key_value => $diskpath,
       sizeb => $sizeb,
       disk_group => $diskset,
       name => $device,
       start => 0
      );

      # Keep an index of the instrumented sub disks
      $storage::Register::config{solaris}{solstice}{metadevices}{subdisks}{$diskpath}=
       \%diskref;

      push @{$mdsaref},\%diskref;

    }

    return 1;

  }

  #Parse the results of metastat
  #and push metric hash refs to the list array
  sub parse_metastat ( $$$ )
  {

    my ( $mdsaref,$mdref,$cmd ) = @_;
    my @disks;

    # return if first argument is not a list ref
    warn "metadisk reference passed for $cmd is not a list\n"
     and return 
      unless ref($mdsaref) =~ /ARRAY/i;

    # return if second argument is not a hash ref
    warn "metadisk reference passed for $cmd is not a hash\n"
     and return 
      unless ref($mdref) =~ /HASH/i;

    # The following fields have to have values 
    for my $valdf ( qw ( md_name disk_group ) )
    {
     warn "ERROR:Data structure for metadisk $cmd does not have data $valdf \n"
      and return 
       unless $mdref->{$valdf};
    }

    # get the name for the metadisk 
    $mdref->{name} = $mdref->{md_name}
     if $mdref->{disk_group} =~ /none/i;

    $mdref->{name} = "$mdref->{disk_group}/$mdref->{md_name}"
     unless $mdref->{name};

    warn "ERROR:Failed to find a name for the metadevice\n"
     and return 
      unless $mdref->{name};
 
    $mdref->{key_value} = $mdref->{name};

    # The mdname whose output the current line of
    # metastat would provide
    my $running_entity = 'Meta device';
    my $running_name = $mdref->{name};

    for my $rslt ( storage::Register::run_system_command($cmd) )
    {
      chomp $rslt;

      $rslt =~ s/^\s+|\s+$//g;

      next unless $rslt;

      #Check if the metastat output has switched to a 
      #child meta device
      #metastat for a mirror gives output for
      #submirror metadisks too
      if 
      ( 
       $mdref->{child_entity_criteria} 
        and @{$mdref->{child_entity_criteria}}
      )
      {
        for my $cldref ( @{$mdref->{child_entity_criteria}} )
        {
           next unless ref($cldref) =~ /HASH/i;
           next unless $cldref->{name};
           # if it is metastat information for a child 
           # submirror metadisk no more info left to pickup, 
           # end
           if ( $rslt =~ /^$cldref->{name}\s*:/i )
           {
             $running_name = $cldref->{name};
             last;
           } 
        }
        last unless $running_name =~ /^$mdref->{name}$/;
           
      }

      # a sub disk header
      # Device     Start Block  Dbase   Reloc
      if ( $rslt =~ /device.*start.*block/i )
      {
       $running_entity = 'Sub Disk';
       next;
      }
      # a logging device record
      # c0t1d0s1: Logging device for d5
      elsif ( $rslt =~ /Logging\s*device/i )
      {
       $running_entity = 'Logging device';
       next;
      }
      # a hot spare header
      # hsp002: 3 hot spares
      elsif ( $rslt =~ /^[^\s]+\s*:.*hot\s+spare/i )
      {
       last;
      }
      # List of drives
      elsif ( $rslt =~ /Device\s+Relocation\s+Information/i )
      {
        last;
      }

      # get subdisks if running entity is disks
      if ( $running_entity =~ /^Sub Disk$/i )
      {
        # Should be of type
        # c0t1d0s3          0     No      Yes
        next unless $rslt =~ /^[^\s]+\s+[^\s]+\s+/;

        # ignore likes like Stripe 2:
        next if $rslt =~ /^stripe.*:/;

        my ( $diskname ) = 
        ( $rslt =~ /^([^\s]+)\s+/ );

        $diskname =~ s/^\s+|\s+$//;

        my $diskpath = catfile('/dev/rdsk',$diskname);
        my $ftype = storage::Register::get_file_type($diskpath) or next;
         
        next unless $ftype =~ /_CHARACTERSPECIAL/i;

        my $diskref = 
         {
          storage_layer => 'VOLUME_MANAGER',
          vendor => 'SUN',
          product => 'Solaris Disk Solstice',
          entity_type => 'Sub Disk',
          disk_group => $mdref->{disk_group},
          name => $diskpath,
          os_identifier => $diskpath,
          key_value => $diskpath,
          sizeb => 0,
          start => 0
         };

         push @{$diskref->{parent_entity_criteria}},
          {
            storage_layer => 'VOLUME_MANAGER',
            vendor => 'SUN',
            product => 'Solaris Disk Solstice',
            entity_type => 'Meta device',
            disk_group =>  $mdref->{disk_group},
            name => $mdref->{name}
          };

         #maintain an index of meta sub disks
         $storage::Register::config{solaris}{solstice}{metadevices}{subdisks}{$diskpath} 
          = $diskref;
 
         push @disks,$diskref;

         next;
      }

      # get the configuration
      if ( $rslt =~ /^$mdref->{name}\s*:/i )
      {
        next if $mdref->{configuration};

        ( $mdref->{configuration}) = 
         ( $rslt =~ /^$mdref->{name}\s*:(.+)$/ );

        $mdref->{configuration} =~ s/^\s+|\s+$//g;

        next unless $mdref->{configuration};

        if ( $mdref->{configuration} =~  /submirror\s+of/i )
        {
          my ( $parent_meta )= 
           ( $mdref->{configuration} =~ /Submirror\s+of\s*(.+)/i );

          $parent_meta =~ s/^\s+|\s+$//g;

          next unless $parent_meta;

          push @{$mdref->{parent_entity_criteria}}, 
          {  
           storage_layer => 'VOLUME_MANAGER',
           vendor => 'SUN',
           product => 'Solaris Disk Solstice',
           entity_type => 'Meta device',
           disk_group => $mdref->{disk_group},
           name => $parent_meta
          }

        }

        next;
      }

      # get the size
      if ( $rslt =~ /^size\s*:/i )
      {
        next if $mdref->{sizeb};

        ($mdref->{sizeb}) = ( $rslt =~ /^.+:\s*(\d+)/ );

        $mdref->{sizeb} = $mdref->{sizeb} * 
         $storage::Register::config{solaris}{solstice}{metadevices}{blocksize}
          if $mdref->{sizeb} 
           and $rslt =~ /block/i;

        next;
      }

      if ( $rslt =~ /^submirror.*:/i ) 
      {
        my ( $mirror ) = ( $rslt =~ /^[^:]*:(.+)/ );
  
        $mirror =~ s/^\s+|\s+$//;

        warn "ERROR:Failed to find the mirror name from $rslt\n"
         and return
          unless $mirror;

        push @{$mdref->{child_entity_criteria}}, 
        {  
          storage_layer => 'VOLUME_MANAGER',
          vendor => 'SUN',
          product => 'Solaris Disk Solstice',
          entity_type => 'Meta device',
          disk_group => $mdref->{disk_group},
          name => $mirror
        };

        next;

      }
 
    }

    # Validate sizeb for metadisk, take the
    # value if its present and sizeb is null
    $mdref->{sizeb} = $mdref->{vtoc_sizeb}
     if $mdref->{vtoc_sizeb};

    $mdref->{sizeb} = $mdref->{geom_sizeb}
     if not $mdref->{sizeb} 
      and $mdref->{geom_sizeb};

    # Push the instrumented metadisk raw and block
    for my $type ( qw ( dsk rdsk ) )
    {
      next unless $mdref->{$type};

      $mdref->{os_identifier} = $mdref->{$type};
      $mdref->{filetype} = 
       storage::Register::get_file_type($mdref->{os_identifier}) 
        or return;

      my %mdmetrics = %$mdref;

      push @{$mdsaref},\%mdmetrics;
    }

    # Push all the instrumented subdisks
    push @{$mdsaref},@disks if @disks;

    return 1;

  }

  my %metadevices;
  my %cfgmds;
  my @mdisk_metric_list;
  # Read all the meta devices in the meta directories

  my $metadir = $storage::Register::config{solaris}{solstice}{metadevices}{dir};
  
  stat $metadir;
  
  warn "No Solaris Disk Solstice Metadevices \n"
   and return [()] 
    unless ( -e $metadir and -d $metadir);
  
  $metadevices{none}=get_metadevices($metadir)
   or 
   (
     warn "No metadevices in directory $metadir\n"
      and $metadevices{none} = 0
   );

  opendir(DIR,$metadir) 
   or warn "ERROR:Failed to open the meta directory $metadir\n"
    and return;
  
  my @metadirs = readdir(DIR);
  
  close(DIR);
  
  for my $fh ( @metadirs )
  {
     $fh =~ s/^\s+|\s+$//g;
  
     next if
      $fh =~ 
       /^($storage::Register::config{solaris}{solstice}{metadevices}{dirs_ignore})$/;
  
     next if $fh =~ /^(dsk|rdsk)$/;

     my $mdir = catfile($metadir,$fh);
  
     stat $mdir;
     
     next unless -d $mdir;
   
     $metadevices{$fh}=get_metadevices($mdir)
      or 
      (
       warn "No metadevices in directory $mdir\n"
        and $metadevices{$fh} = 0
      );

  }

  for my $ds ( keys %metadevices )
  {  

     next 
      unless 
      (
        $metadevices{$ds}
         and ref($metadevices{$ds}) =~ /HASH/i
          and keys %{$metadevices{$ds}}
      );

     for my $mds ( keys %{$metadevices{$ds}} )
     {
       warn "Failed to get path for meta device $mds in diskset $ds\n" 
        and next 
         unless $metadevices{$ds}{$mds}{rdsk};

       # Get the size of the char metadevice
       my $ftype = 
        storage::Register::get_file_type($metadevices{$ds}{$mds}{rdsk}) 
         or next;

       next unless $ftype =~ /_CHARACTERSPECIAL/i;

       my %ismetadevice;

       for my $rslt 
       ( 
        storage::Register::run_system_command
        (
         "nmhs get_metadisk_info $metadevices{$ds}{$mds}{rdsk}"
        ) 
       )
       { 
         chomp $rslt;

         $rslt =~ s/^\s+|\s+$//g;

         next unless $rslt; 

         last if $rslt =~ /error/i;
       
         last if $rslt =~ /ENXIO/i;

         next unless $rslt =~ /^.+:\s*(\d+)/;

         my ( $key,$value ) = ( $rslt =~ /^(.+)\s*:\s*(\d+)/ );

         undef  %ismetadevice
          and warn "Failed to get key, value from $rslt\n"
           and last
            unless $key and $value =~ /\d+/;

         $ismetadevice{$key} = $value;

       } 

       # No size so no metadevice configured
       next unless 
         ( $ismetadevice{geom_sizeb} or $ismetadevice{vtoc_sizeb} );

       $ismetadevice{vtoc_sizeb} *= 
        $storage::Register::config{solaris}{solstice}{metadevices}{blocksize}
         if $ismetadevice{vtoc_sizeb};

       # It has a valid size so its an configured 
       # metadevice
       $cfgmds{$ds}{$mds}= 
       { 
         storage_layer=>'VOLUME_MANAGER',
         vendor=>'SUN',
         product=>'Solaris Disk Solstice',
         entity_type=>'Meta device',
         disk_group => $ds,
         md_name => $mds,
         rdsk => $metadevices{$ds}{$mds}{rdsk},
         dsk => $metadevices{$ds}{$mds}{dsk}
       };

       # Copy values from nmhs get_metadisk_info
       for my $key ( keys %ismetadevice )
       {
         $cfgmds{$ds}{$mds}->{$key} = $ismetadevice{$key};
       }
                           
     }
     
  }

  # Execute metastat for each of the configured disks to get all
  # info
  for my $diskset ( keys %cfgmds )
  {

    # instrument metrics for disksets
    if ( $diskset !~ /none/i )
    {

      my %hdiskset = 
       (
         storage_layer=>'VOLUME_MANAGER',
         vendor=>'SUN',
         product=>'Solaris Disk Solstice',
         entity_type=>'diskset',
         disk_group => $diskset,
         name => $diskset,
         key_value => $diskset,
         sizeb => 0
       );
      
      push @{$hdiskset{child_entity_criteria}},
       {
         storage_layer => 'VOLUME_MANAGER',
         vendor => 'SUN',
         product => 'Solaris Disk Solstice',
         disk_group => $diskset
       };

      push @mdisk_metric_list,\%hdiskset;

    }

    for my $metadisk ( keys %{$cfgmds{$diskset}} )
    {

      my $ref = $cfgmds{$diskset}{$metadisk};

      warn "refference to $diskset $metadisk in configured metadevices is not a hash\n"
       and return
        unless ref($ref) =~ /HASH/i;

      # instrument metrics for metadisks, subdisks 
      if ( $diskset =~ /^none$/ )
      {
        parse_metastat(\@mdisk_metric_list,$ref,"nmhs execute_metastat $metadisk") 
         or return;
      }
      else
      {
        parse_metastat(\@mdisk_metric_list,$ref,"nmhs execute_metastat -s $diskset $metadisk")
         or return;
      }

    }
 
    # instrument metrics for hot spares
    parse_hotspares(\@mdisk_metric_list,$diskset) 
     or return;
  }

  return [()] 
   if not @mdisk_metric_list;

  return \@mdisk_metric_list;

}

#------------------------------------------------------------------------------
# FUNCTION : get_filesystem_metrics
#
#
# DESC
# Returns a array of hashes of filesystem metrics
#
# ARGUMENTS:
#
#
#-----------------------------------------------------------------------------
sub get_filesystem_metrics ( )
{
 return \@storage::Register::filesystemarray 
  if @storage::Register::filesystemarray;

 my %fstypelist;
 my %fsarray;
 
 # Use the Xopen df , as it supports the portable format
 
 # -P df information in portable format, Gives out in block size of 512 bytes
 # Build a hash of the filesystem information on keys filesystem type
 # and mount point
 # Execute command twice, bug in df leaves out some nfs file systems
 # the first time
 my @dummy = run_system_command("df -P -a",120);
 
 # build the mount point to fstype hash
 # df -n done after df -P , as df -P discovers all filesystems
 # and then -n gives the complete list
 # THis is a workaround for a bug on solaris , where df -n 
 # leaves out some nfs filesystems if executed first
 if ( not keys %fstypelist ) 
 {
  
  for my $fsdata ( run_system_command("df -n",120,3) ) 
  {
   
   chomp $fsdata;
   
   $fsdata =~ s/\s+//g;
   
   next unless $fsdata;
   
   my ($mt,$type) = split /\s*:\s*/,$fsdata;
   
   $fstypelist{$mt} = $type;
   
  }
  
 }
 
 
 # Execute the command for each fstype to instrument the metrics
 for my $fstype ( keys %{$storage::Register::config{filesystem}{command}} )
 {
  
  for 
  ( 
    run_system_command
    (
     $storage::Register::config{filesystem}{command}{$fstype},120,2
    ) 
  )
  {
   
   chomp;
   
   s/^\s+|\s+$//g;
   
   next unless $_;
   
   # Skip heading
   # Skip all 'swap' partitions. We will collect swap information below.
   next if /^(Filesystem|swapfile)/i;
   
   my %fsinfo = ();
   
   my @columns = split;
   
   # If command used is /usr/xpg4/bin/df -P
   if 
   ( 
     $storage::Register::config{filesystem}{command}{$fstype} 
      =~ /df/ 
   )
   {
    $fsinfo{filesystem} = $columns[0];
    $fsinfo{size}       = $columns[1];
    $fsinfo{used}       = $columns[2];
    $fsinfo{free}       = $columns[3]; 
    $fsinfo{mountpoint} = $columns[5];
    
   }# If command used is swap -l
   elsif ( $storage::Register::config{filesystem}{command}{$fstype} =~ /swap/ )
   {
    
    # If swap based on a file then ignore, filesystems based on local 
    # filesystems are not counted
    # Check if the swap filesystem is a special device
    # next if $columns[1] =~ /-/ ;
    
    $fsinfo{filesystem} = $columns[0];
    $fsinfo{size}       = $columns[3];
    $fsinfo{used}       = $columns[3];
    $fsinfo{free}       = 0;       
   }
   else
   {
    warn "ERROR:Unrecognized command  $storage::Register::config{filesystem}{command}{$fstype} \n" 
     and next;
   }
   
   # Validate the filesystem and mountpoint
   warn "Filesystem  not available for $fstype \n" and next 
    unless $fsinfo{filesystem}; 
   
   # Get the filesystem type for this filesystem
   # if the command is for swap then take that to be the filesystem and not tmpfs
   # Get it from the mountpoint to filesystem type map, else get it from the
   # filesystem type of the command
   if ( $fstype =~ /swap/i )
   {
    $fsinfo{fstype} = $fstype;
   }
   elsif ( $fsinfo{mountpoint} and $fstypelist{$fsinfo{mountpoint}} )
   {
    $fsinfo{fstype} = $fstypelist{$fsinfo{mountpoint}};
   }
   else 
   {
    $fsinfo{fstype} = $fstype;
   }
   
   # Skip if this filesystem has already been instrumented
   # Skip if filesystem type is in the list of filesystems to be ignored  
   next if exists $storage::Register::config{filesystem}{skipfilesystems} and 
    $fsinfo{fstype} =~ 
     /^($storage::Register::config{filesystem}{skipfilesystems})$/i;
   
   # Get the bytes from blocks
   $fsinfo{size} = $fsinfo{size} * 512;
   $fsinfo{used} = $fsinfo{used} * 512;
   $fsinfo{free} = $fsinfo{free} * 512; 
   
   # NFS special , get nfs_server name from filesystem
   ( $fsinfo{nfs_server}, $fsinfo{nfs_exported_filesystem} ) = 
    ( $fsinfo{filesystem} =~ /^\s*([^:]*)\s*:\s*(.+)\s*$/ ) 
     if $fsinfo{fstype} eq 'nfs' 
      and  $fsinfo{filesystem} =~ /^([^:]*):(.+)$/;
      
   # Push the instrumented metrics to the hash array
   push @{$fsarray{$fsinfo{fstype}}},\%fsinfo;      
   
  }
  
 }
 
 my %nfsservers;
 
 # For each file system type
 for my $fstype( keys %fsarray )
 {
     
   #-------------------------------------------------------
   # Build the nfs server list and server information
   #-------------------------------------------------------
   if ( $fstype eq 'nfs' )
   {
  
     # build Unique list of nfs servers for fstype = nfs, 
     # filesystem for nfs is server:filesystem
     %nfsservers = map{ $_->{nfs_server} => 1 
      if $_->{nfs_server} } @{$fsarray{$fstype}};
     
     #Get the vendor product for each of the nfs server , build a
     #hash of hashes for nfs configuration
     map
     {
      my %reslt = storage::sUtilities::get_server_identifier($_); 
      $nfsservers{$_} = \%reslt;
     } 
      keys %nfsservers;
   
   }
  
  #------------------------------------------------------
  # Loop and push each file system metrics
  #------------------------------------------------------
  for my $fsref ( @{$fsarray{$fstype}} )
  {
   
   my %nfs;
   my %mountpoint;
   my %filesystem;
   
   # Get the nfs(vendor,product,server) hash if filesystem nfs
   
   $fsref->{nfs_mount_privilege} = 
    storage::sUtilities::get_mount_privilege($fsref->{mountpoint}) 
     if $fsref->{mountpoint} 
      and $fsref->{fstype} eq 'nfs';
   
   $fsref->{nfs_server_net_interface_address} = 
    $nfsservers{$fsref->{nfs_server}}->{nfs_server_net_interface_address} 
     if $fsref->{fstype} eq 'nfs' 
      and $fsref->{nfs_server} 
       and $nfsservers{$fsref->{nfs_server}} 
        and $nfsservers{$fsref->{nfs_server}}->{nfs_server_net_interface_address};

   $fsref->{nfs_server_ip_address} = 
    $nfsservers{$fsref->{nfs_server}}->{nfs_server_ip_address} 
     if $fsref->{fstype} eq 'nfs' 
      and $fsref->{nfs_server} 
       and $nfsservers{$fsref->{nfs_server}} 
        and $nfsservers{$fsref->{nfs_server}}->{nfs_server_ip_address};
   
   # Create the mozart metrics that are required
   
   # The mountpoint storage entity if there is a mountpoint
   if ( $fsref->{mountpoint} )
   {
    
    $mountpoint{storage_layer} = 'LOCAL_FILESYSTEM';
    $mountpoint{entity_type} = 'Mountpoint';
    $mountpoint{key_value} = $fsref->{mountpoint};
    $mountpoint{os_identifier} = $fsref->{mountpoint};
    $mountpoint{sizeb} = $fsref->{size};
    $mountpoint{usedb} = $fsref->{used};
    $mountpoint{freeb} = $fsref->{free};
    $mountpoint{filesystem_type} = $fsref->{fstype};
    $mountpoint{filesystem} = $fsref->{filesystem};
    $mountpoint{mountpoint} = $fsref->{mountpoint}; 
    $mountpoint{name} = $fsref->{mountpoint};
 
    # Extra metric columns for NFS
    if ( $fsref->{fstype} eq 'nfs' )
    {

      $mountpoint{storage_layer} = 'NFS';

      # Copy all the nfs_fields
      for my $nfskey ( keys %{$fsref} )
      {
        next
         unless $nfskey =~ /^nfs_/;

        next
         unless  $fsref->{$nfskey};

        $mountpoint{$nfskey} = $fsref->{$nfskey};

      }

    }

    push @storage::Register::filesystemarray,\%mountpoint;
    
   }
   
   $filesystem{key_value} = $fsref->{filesystem};
   $filesystem{sizeb} = $fsref->{size};
   $filesystem{usedb} = $fsref->{size};
   $filesystem{filesystem_type} = $fsref->{fstype};
   $filesystem{filesystem} = $fsref->{filesystem};
   $filesystem{name} = $fsref->{filesystem};
   # OS identifier only if the filesystem is present on the os, 
   # This will leave out remote filesystems like NFS
   $filesystem{os_identifier} = $fsref->{filesystem} 
    if $fsref->{fstype} ne 'nfs'
     and -e $fsref->{filesystem};
   $filesystem{mountpoint} = $fsref->{mountpoint}  
    if $fsref->{mountpoint};
   
   # Who are its parents
   # The current mountpoint
   # Since these are OS entities any other cached filesystem mounts 
   # or filesystem based swap will be discovered by the analysis 
   # program
   # There is no need to define the parent key criteria for these
   $filesystem{parent_key_value} = $mountpoint{key_value} 
    if $fsref->{mountpoint} 
     and $mountpoint{mountpoint};   

   $filesystem{storage_layer} = 'LOCAL_FILESYSTEM';
   $filesystem{entity_type} = 'Filesystem';

   # If the filesystem is a regular file or directory not a block device then its a file
   my $fs_file_type = storage::Register::get_file_type( $filesystem{os_identifier} )
     if $filesystem{os_identifier};

   $filesystem{entity_type} = 'File'
    if $fs_file_type
     and $fs_file_type =~ /_REGULAR/i;
   
   $filesystem{entity_type} = 'Directory'
    if $fs_file_type
     and $fs_file_type =~ /_DIRECTORY/i;

   # Extra metric columns for NFS
   if  ( $fsref->{fstype} eq 'nfs' )
   {

     $filesystem{storage_layer} = 'NFS';
     $filesystem{entity_type} = 'Filesystem';
 
     # copy all the nfs_ fields
     for my $nfskey ( keys %{$fsref} )
     {
       next
        unless $nfskey =~ /^nfs_/;
 
       next
        unless  $fsref->{$nfskey};
 
       $filesystem{$nfskey} = $fsref->{$nfskey};
 
     }

     # Generate a default global unique id for the server based on the
     # server identification obtained
     # if post processing cannot find a matching server this can be used

     if ( $filesystem{nfs_server_net_interface_address} )
     {
      $filesystem{global_unique_id} =
       "$filesystem{nfs_server_net_interface_address}::$filesystem{filesystem}";
     }
     elsif ( $filesystem{nfs_server_ip_address} )
     {
      $filesystem{global_unique_id} =
       "$filesystem{nfs_server_ip_address}::$filesystem{filesystem}";
     }
     elsif ( $filesystem{nfs_server} )
     {
      $filesystem{global_unique_id} =
       "$filesystem{nfs_server}::$filesystem{filesystem}";
     }
     else
     {
      my $target_id =  get_target_id();

      $filesystem{global_unique_id} =
       "no_gid::$target_id::$filesystem{filesystem}"
        if $target_id;
     }
   
     $filesystem{global_unique_id} =
      "no_targetid::$filesystem{filesystem}"
        unless $filesystem{global_unique_id};

   }

   push @storage::Register::filesystemarray,\%filesystem;
   
  }

 }

 return \@storage::Register::filesystemarray;
 
}

#-------------------------------------------------------------------------------
# FUNCTION : getLogicalName
#
#
# DESC
# Return the logical path for disk or slice
#
# ARGUMENTS:
# physical path
#
#------------------------------------------------------------------------------
sub getLogicalName( $ )
{
 
 my ($physicalname) = @_;
 
 $physicalname = "/devices$physicalname" 
  if $physicalname !~ m|^/devices|i;
 
 cacheLogicalPhysicalMap if not keys %logicallist;
 
 warn "Logical name for $physicalname not found\n" 
  and return 
   unless $logicallist{$physicalname};
 
 return $logicallist{$physicalname};
 
}

#-----------------------------------------------------------------------------
# FUNCTION : cacheLogicalPhysicalMap
#
#
# DESC
#
# The function caches a hash mapping logical and physical paths in the first 
# run subsequent runs refer to the cache
#
#
# ARGUMENTS:
#
#-------------------------------------------------------------------------------
sub cacheLogicalPhysicalMap
{
 
 # Cache the logical to physical mapping for the 
 # first run
 return if  keys %logicallist; 
 
 for my $devicedir( qw( /dev/rdsk/ /dev/dsk/ ) )
 {
  
  opendir(DIR, $devicedir) 
   or warn "ERROR:cannot opendir $devicedir: $!";
  
  for my $device ( readdir DIR ) 
  {
   
   $device =~ s/^\s+|\s+$//g;     
   
   next unless $device;
   
   next if not -l "$devicedir$device";
   
   # The rook link of a disk device is the physical path 
   
   my $physicalpath = 
    storage::sUtilities::get_source_link_file
     ("$devicedir$device",'ignore_template');
   
   $logicallist{$physicalpath} = "$devicedir$device" 
    if $physicalpath;
   
  }
  
  closedir DIR;

 }

}


#-------------------------------------------------------------------------------
# FUNCTION : runShowmount
#
#
# DESC
# run showmount 
#
# ARGUMENTS:
#
#------------------------------------------------------------------------------
sub runShowmount ( $ )
{
 return run_system_command("showmount -a $_[0]",120);
}


#-----------------------------------------------------------------------------
# FUNCTION : AUTOLOAD
#
# DESC 
# If sub is not defined here then look for it in sUtilities.pm
#
# ARGUMENTS
# Args to be passed to the sub
#
#----------------------------------------------------------------------------
sub AUTOLOAD
{
  my ( @args ) = @_;

  my $sub = $AUTOLOAD;

  $sub =~ s/.*:://;

  my $sub_path = "storage::sUtilities::$sub";

  my $sub_ref = \&$sub_path;

  return &$sub_ref(@args);

}


1;
#-----------------------------------------------------------------
