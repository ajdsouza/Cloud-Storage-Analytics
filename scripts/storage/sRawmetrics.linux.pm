#
# Copyright (c) 2001, 2005, Oracle. All rights reserved.  
#
#  $Id: sRawmetrics.pm 18-mar-2005.11:03:01 ajdsouza Exp $
#
#
# NAME
#   sRawmetrics.pm
#
# DESC
#  Linux OS specific storage subroutines
#
#
#
# NOTES
#
#
# MODIFIED  (MM/DD/YY)
# ajdsouza      03/18/05 - 
# ajdsouza      03/03/05 - fix bug is getLinuxSwraid 
#                          save all records in lookup partition hash
# ajdsouza      02/10/05 - fix linux lvm issues
# ajdsouza      02/06/05 - qualify error messages to be loaded to rep with ERROR:
# ajdsouza      12/14/04 - add validations and checks for proc kernel state processing
# ajdsouza      11/24/04 -
# ajdsouza      11/09/04 -
# ajdsouza      09/28/04 -
# ajdsouza      09/07/04 -
# ajdsouza      08/13/04 -
# ajdsouza      08/05/04 - Split nfs filesystem to server and filesystem, check for format before spliting
#                          disks
# ajdsouza      07/27/04 - Fix bug for cdrom check
# ajdsou        07/14/04 - add emdw/bin to path
# ajdsouza      07/07/04 Bug fix line# 47 , remove extra (
# ajdsouza      04/12/04 add oracle_home/bin to the path
# ajdsouza      04/08/04 storage perl modules 
# ajdsouza      04/21/02 Created
#

# Initialize the environment variables at compile time
BEGIN
{
  $ENV{PATH} = "/bin:/usr/sbin:/sbin:/usr/bin:/etc";

  $ENV{PATH} =
   "$ENV{ORACLE_HOME}/bin:$ENV{ORACLE_HOME}/emagent/bin:$ENV{PATH}"
     if $ENV{ORACLE_HOME};

}

package storage::sRawmetrics;

require v5.6.1;

use strict;
use warnings;
use locale;
use storage::sUtilities;
use Data::Dumper;
$Data::Dumper::Indent = 2;

#-----------------------------------------------------------------------------------------
# Global package variable to hold sub name
our $AUTOLOAD;


#------------------------------------------------
# subs declared
#-----------------------------------------------
sub get_disk_metrics;
sub get_virtualization_layer_metrics();
sub lvmMetrics();
sub getLinuxSwraid;
sub get_filesystem_metrics ( );
sub runShowmount ($);

#-------------------------------------------------
# Variables in package scope
#------------------------------------------------

#------------------------------------------------------------------------------------
# Static Configuration
#------------------------------------------------------------------------------------

# directory for devices
$storage::Register::config{disk_directory}{block}='/dev';
$storage::Register::config{disk_directory}{raw}='/dev';

# Do not go below this directory when getting the source file in a symbolic link
# /dev/rdsk this is prefered over physical path /devices/ for soalris
# /dev/md for metadevices
$storage::Register::config{lowest_symbolic_directory} = '^/dev';

# candidate fields for choosing unique key for disks
$storage::Register::config{key}{emc}="sq_serial_no";
$storage::Register::config{key}{hitachi}="sq_hitachi_serial";
$storage::Register::config{key}{symbios}="sq_vendorspecific sq_vpd_pagecode_83";
$storage::Register::config{key}{default}=
"sq_vendorspecific sq_serial_no ide_serial_no ida_unique_id cciss_unique_id";

# Order of choice from among candidates for a field
$storage::Register::config{DISK}{fields}{vendor}=
{1=>'sq_vendor', 2=>'ide_vendor', 3=>'ida_vendor', 4=>'cciss_vendor'};
$storage::Register::config{DISK}{fields}{product}=
{1=>'sq_product', 2=>'ide_product', 3=>'ida_product', 4=>'cciss_product'};
$storage::Register::config{DISK}{fields}{configuration}=
{1=>'ida_faulttolmode',2=>'cciss_faulttolmode'};
$storage::Register::config{DISK}{fields}{storage_disk_device_id}=
{1=>'sq_serial_no',2=>'ide_serial_no',3=>'ida_unique_id',4=>'cciss_unique_id'};
$storage::Register::config{DISK}{fields}{sizeb}=
{1=>'sq_capacity',2=>'ide_capacity',3=>'ida_capacity', 4=>'cciss_capacity', 5=>'geom_size', 6=>'getsize_size'};
$storage::Register::config{DISK}{fields}{nsectors}=
{1=>'ida_sectors', 2=>'cciss_sectors', 3=>'geom_sectors'};

$storage::Register::config{PARTITION}{fields}{sizeb}=
{ 1=>'getsize_size'};


# List of fields to be common for each slice of a disk
$storage::Register::config{diskfields}{PARTITION}=
    [qw(disk_key vendor product storage_system_id 
        configuration storage_spindles storage_system_key 
        storage_disk_device_id device_status)];
# List of fields common or slices representing disks
$storage::Register::config{diskfields}{DISK}=
    [qw(disk_key vendor product storage_system_id 
        configuration storage_spindles storage_system_key 
        storage_disk_device_id device_status 
        slice_key sizeb start end nsectors)];

#-------------------------------------------------
# Information about the disk drivers
#-------------------------------------------------
# These are the major number mappings
# refer /usr/include/linux/major.h
$storage::Register::config{disk_drivers} = [ qw ( ide sd ida ciss ramdisk ) ];
$storage::Register::config{majors}{ide} = '3|22|33|34|56|57|88|89|90|91';
$storage::Register::config{majors}{sd} = '8|65|66|67|68|69|70|71|128|129|130|131|132|133|134|135';
$storage::Register::config{majors}{ida} = '72|73|74|75|76|77|78|79';
$storage::Register::config{majors}{ciss} = '104|105|106|107|108|109|110|111';
$storage::Register::config{majors}{ram} = '1';

# Mylex raid controller
# I haven't run into one of these yet
# and it will have to be developed when 
# we see one.
$storage::Register::config{majors}{dac} = '48';
$storage::Register::config{majors}{md} = '9';
$storage::Register::config{majors}{ataraid} = '114';
$storage::Register::config{majors}{lvm} = '58';
$storage::Register::config{majors}{lvm_driver} = '199';
$storage::Register::config{majors}{'lvm-char'} = '109';
$storage::Register::config{majors}{'veritas-dmp'} = '201';
$storage::Register::config{majors}{'veritas-dmp'} = '201';

### IDE Driver
# Regexp to identify disk in /proc/partitions
$storage::Register::config{driver}{ide}{DISK} = "hd([a-z]+)\\b";
# Regexp to identify partition
$storage::Register::config{driver}{ide}{PARTITION} = "hd([a-z]+)\\d+\\b";
# List of Major numbers for the driver
# C program to query disk drive
$storage::Register::config{driver}{ide}{diskinfocmd} = 'nmhs ideinfo';
# Important fields generated by the C program
$storage::Register::config{driver}{ide}{diskinfofields} = 
"ide_serial_no|ide_model|ide_capacity";

### SCSI Driver
#  Check scsi disk naming for sd , file sd.c
$storage::Register::config{driver}{sd}{DISK} = "sd([a-z]+)\\b";
$storage::Register::config{driver}{sd}{PARTITION} = "sd([a-z]+)\\d+\\b";
$storage::Register::config{driver}{sd}{diskinfocmd} = 'nmhs execute_scsi_inquiry';
$storage::Register::config{driver}{sd}{diskinfofields} = 
"sq_vendor|sq_product|sq_revision|sq_serial_no|sq_capacity|sq_device_type|sq_hitachi|sq_vendorspecific|sq_vpd_pagecode_83";

### Compaq Smart RAID Controller
$storage::Register::config{driver}{ida}{DISK} = "ida\\/c\\d+d\\d+\\b";
$storage::Register::config{driver}{ida}{PARTITION} = "ida\\/c\\d+d\\d+p\\d+\\b";
$storage::Register::config{driver}{ida}{diskinfocmd} = 'nmhs idainfo';
$storage::Register::config{driver}{ida}{diskinfofields} = 
"ida_capacity|ida_faulttolmode|ida_vendor|ida_product|ida_unique_id|ida_sectors|ida_cylinders";

### Compaq CISS Driver
$storage::Register::config{driver}{ciss}{DISK} = "cciss\\/c\\d+d\\d+\\b";
$storage::Register::config{driver}{ciss}{PARTITION} = "cciss\\/c\\d+d\\d+p\\d+\\b";
$storage::Register::config{driver}{ciss}{diskinfocmd} = 'nmhs execute_ccissinfo';
$storage::Register::config{driver}{ciss}{diskinfofields} = 
"cciss_vendor|cciss_product|cciss_unique_id|cciss_capacity|cciss_sectors|cciss_cylinders|cciss_blocksize|cciss_faulttolmode";

### ramdisk
$storage::Register::config{driver}{ram}{DISK} = "ram\\b";
$storage::Register::config{driver}{ram}{diskinfocmd} = '';
$storage::Register::config{driver}{ram}{diskinfofields} = "";


#------------------------------------------------------
# Definitions for LVM Status and Access fields
#------------------------------------------------------
# Taken from tools/lib/lvm.h in the LVM source code
my %lvmdefs;
$lvmdefs{vgstatus}{VG_ACTIVE} = 0x01;
$lvmdefs{vgstatus}{VG_EXPORTED} = 0x02;
$lvmdefs{vgstatus}{VG_EXTENDABLE} = 0x04;

$lvmdefs{vgaccess}{VG_READ} = 0x01;
$lvmdefs{vgaccess}{VG_WRITE} = 0x02;
$lvmdefs{vgaccess}{VG_CLUSTERED} = 0x04;
$lvmdefs{vgaccess}{VG_SHARED} = 0x08;

$lvmdefs{lvstatus}{LV_ACTIVE} = 0x01;
$lvmdefs{lvstatus}{LV_SPINDOWN} = 0x02;

$lvmdefs{lvaccess}{LV_READ} = 0x01;
$lvmdefs{lvaccess}{LV_WRITE} = 0x02;
$lvmdefs{lvaccess}{LV_SNAPSHOT} = 0x04;
$lvmdefs{lvaccess}{LV_SNAPSHOT_ORG} = 0x08;

#--------------------------------------------------------
# Filesystem metric specific configuration
#--------------------------------------------------------
# Filesystem commands tend to hang due to rpc
# to ensure atleast ufs and vxfs are instrumented in such a case
#   exceute the ext2, ext3 and reiserfs commands exclusively than those that may involve rpc's
#
# '-T' option displays the filesystem type
#
# The commands to execute for getting filesystems
$storage::Register::config{filesystem}{command}{ext2}  = "df -P -T -t ext2";
$storage::Register::config{filesystem}{command}{ext3}  = "df -P -T -t ext3";
$storage::Register::config{filesystem}{command}{reiserfs}  = "df -P -T -t reiserfs";
# The commands to execute for getting all Local filesystems
$storage::Register::config{filesystem}{command}{local} = "df -P -T -l";
# the local and nfs filesystems are got in two seperate calls
# to avoid nfs rpc hangs from intefering local filesystems
$storage::Register::config{filesystem}{command}{nfs}   = "df -P -T -t nfs";
# df shows swap filesystems only as "swap". `swapon -s` shows a list of
# filesystems that are used for swap space.
$storage::Register::config{filesystem}{command}{swap}  = "swapon -s";

# Filesystems to skip, need not instrument metrics for these filesystems
$storage::Register::config{filesystem}{skipfilesystems} = "mvfs|proc|fd|mntfs|tmpfs|cachefs|shm|cdfs|hsfs|lofs";


#-----------------------------------------------------------------------------------------
# FUNCTION : get_disk_metrics
#
# DESC 
# return a pointer to a array of references to hashes for all volume manager metrics  
#
# ARGUMENTS
#
#-----------------------------------------------------------------------------------------
sub get_disk_metrics
{
  
  my %disks;    # Hash of disks
  my %disklist;    # Hash of disks and partitions
  my %rawdisks;    # Hash of raw disks
  my %pt;      # Partition Table from sfdisk
  my @diskdevices;  # Array of hashes of disks and partitions
  my @rows;
  
  # Values parsed from /proc/partitions
  my ( $major, $minor, $kblocks , $name);
  
  # Get hash listing of the raw devices
  %rawdisks = getRawDevs();
  
  # Open and read /proc/partitions
  warn "ERROR:Unable to open /proc/partitions." 
   and return 
    unless open (FILEHANDLE, "</proc/partitions");
  
  @rows = <FILEHANDLE>;
  close (FILEHANDLE);
  
  #--------------------------------------------------------------
  # PARSE /proc/partitions AND BUILD LIST OF DISKS AND PARTITIONS
  #--------------------------------------------------------------
  foreach my $reslt (@rows) 
  {
    
    chomp $reslt;
  
    # Skip Blank Lines
    next unless $reslt;
    
    $reslt =~ s/^\s+|\s+$//g;

    # Skip Blank Lines
    next unless $reslt;

    # skip title
    next if $reslt =~ /major|minor|blocks/i;
   
    my %devinfo;    # Hash of disk information
    
    # reach the major, minor, size and name from /proc/partitions
    ( $major, $minor, $kblocks, $name ) =  split /\s+/,$reslt;
    
    $major =~ s/^\s+|\s+$//g;
    $minor =~ s/^\s+|\s+$//g;
    $kblocks =~ s/^\s+|\s+$//g;
    $name =~ s/^\s+|\s+$//g;

    # Validate name
    warn "Failed to read the required disk data from /proc/partitions record $reslt\n" 
     and return
      unless $major and $name;

    # ram disks not suported
    next if $major =~ /^($storage::Register::config{majors}{ram})$/;

    # Using major number pick the right driver for the disk device
    for my $drv ( @{$storage::Register::config{disk_drivers}} )
    {
      next unless $major =~ /^($storage::Register::config{majors}{$drv})$/;
      $devinfo{driver} = $drv and last;
    }
    
    warn "driver with major# $major used for disk device /dev/$name is not a supported disk, skipping disk\n" 
     and next
      unless $devinfo{driver};

    # Common attributes for Disks and Partitions
    $devinfo{name} = "/dev/$name";
        
    # Check if the device is a cdrom drive
    # (This does not handle systems with multiple cdrom drives -
    # I'll look into that later.)
    my $cdrom = storage::sUtilities::get_source_link_file('/dev/cdrom');
    next if $cdrom and $cdrom eq $devinfo{name};
    
    $devinfo{filetype} = get_file_type($devinfo{name})
     or warn "Failed to get the file type for disk $devinfo{name}, skipping disk \n"
      and next;
    
    warn "Disk block size is invalid $kblocks for disk device $devinfo{name} \n"
     and $kblocks = 0
      unless $kblocks =~ /^\d+$/;
    
    $devinfo{sizeb} = $kblocks * 1024;
    $devinfo{major} = "$major";
    $devinfo{minor} = "$minor";
    ( $devinfo{nameinstance} ) = ( $name =~ /([^\d]+)/ );  # eg. sda, sdb, hdb etc.

    warn "Failed to glean the disk instance for disk $name , skipping disk\n" 
     and next
      unless $devinfo{nameinstance};

    # check for disk/partition
    if 
    ( 
      $storage::Register::config{driver}{$devinfo{driver}}{DISK}
       and $name =~ /^$storage::Register::config{driver}{$devinfo{driver}}{DISK}$/ 
    ) 
    {
      
      $devinfo{type} = 'DISK';
      $devinfo{partition} = 0;
      
    } 
    elsif 
    (
      $storage::Register::config{driver}{$devinfo{driver}}{PARTITION}
       and $name =~ /^$storage::Register::config{driver}{$devinfo{driver}}{PARTITION}$/ 
    )  
    {
      
      $devinfo{type} = 'PARTITION';
      
      # Pick the last digits to be the partition number
      ( $devinfo{partition} ) = ( $name =~ /.*\D(\d+)$/); 
      
      warn " Failed to read the partition number for $devinfo{name} using regexp\n" 
       unless exists $devinfo{partition} 
        and $devinfo{partition} =~ /^\d+$/;

    }
    else
    {
      
      # The device name doesn't match either the disk or partition.
      warn " Unable to match disk or partition for $name.\n" and next;

    }
    
    # indexed look up for the Disk Hashes so we can query for serial, vendor, etc. later
    $disks{$devinfo{nameinstance}} = \%devinfo 
     if $devinfo{type} eq 'DISK';
    
    # Keep an list indexed on nameinstance and type
    push @{$disklist{$devinfo{type}}{$devinfo{nameinstance}}}, \%devinfo;
    
    push @diskdevices, \%devinfo;

  }


  #----------------------------------------------------
  # get disk geometry CHS using getgeom
  #----------------------------------------------------
  for my $dref ( values %disks )
  {

    foreach my $rgeom (run_system_command("nmhs getgeom $dref->{name}")) 
    {
      chomp $rgeom;
      
      # Skip Blank Lines
      next unless $rgeom;

      # Remove all white space
      $rgeom =~ s/\s+//g;
  
      # Skip Blank Lines
      next unless $rgeom;

      warn "Failed to read the output from nmhs getgeom for disk $dref->{name} , $rgeom\n" 
       and next 
        unless $rgeom =~ /^([^:]+):(.+)$/;

      my ($name, $value) = ( $rgeom =~ /^([^:]+):(.+)$/ );

      warn "No data to be read for getgeom $rgeom for disk $dref->{name} \n"
       and next
        unless $name and $value;

      # regexp is greedy
      $name =~ s/^\s+|\s+$//g;
      $value =~ s/^\s+|\s+$//g;

      $dref->{"geom_$name"} = $value;

    }

  }

  #----------------------------------------------------
  # get partition table for each disk usining sfdisk
  #----------------------------------------------------
  for my $dref ( values %disks )
  {
    #---------------------------------------------------
    # Get the partition table from sfdisk
    # Store the start sector, size and type id in a hash
    #
    # unit: sectors
    #
    #/dev/sda1 : start=       63, size=   96327, Id=83, bootable
    #/dev/sda2 : start=    96390, size= 4096575, Id=83
    #/dev/sda3 : start=  4192965, size= 4690980, Id=83
    #/dev/sda4 : start=        0, size=       0, Id= 0
    #
    #When error 
    #read: Input/output error
    #
    #sfdisk: read error on /dev/sdc - cannot read sector 0
    #/dev/sdc: unrecognized partition
    #No partitions found
    #---------------------------------------------------
    foreach my $rsfd (run_system_command("nmhs execute_sfdisk -d $dref->{name}")) 
    {
      
      chomp $rsfd;
      
      # Skip Blank Lines
      next unless $rsfd;

      # Remove all white space
      $rsfd =~ s/\s+//g;
  
      # Skip Blank Lines
      next unless $rsfd;
      
      # Skip Header
      next if $rsfd =~ /^unit:|^#part/i;
  
      # Skip the partitions if there is an error reading this disk
      last if 
       $rsfd =~ /error|unrecognized|cannot|read error|unrecognized\s+partition|cannot\s+read|No\s+partition|denied|permission/i;
      
      warn "Skipping disk record format not recognized $rsfd\n" 
       and next
        unless $rsfd =~ /^([^:]+):(.+)$/;

      my ($pt_name, $pt_info) = (  $rsfd =~ /^([^:]+):(.+)$/ );

      warn "No info to be gleaned from sfdisk disk record $rsfd for $dref->{name} \n" 
       and next 
        unless $pt_info;

      $pt_name =~ s/^\s+|\s+$//g;

      foreach my $property (split(/,/, $pt_info))
      {
        next unless $property;

        my ($param, $value) = ( $property =~ /([^=]+)=(.*)/);

        $param =~ s/^\s+|\s+$//g
         if $param;
        $value =~ s/^\s+|\s+$//g
         if $value;

        next unless $param;

        $value = 1 unless $value;

        $pt{$pt_name}{lc($param)} = lc($value);

      }

    }
     
    #----------------------------------------------------
    # Processing for records in the partition index
    #----------------------------------------------------
    # Process partitions
    for my $pref ( @{$disklist{PARTITION}{$dref->{nameinstance}}}  )
    {

      $pref->{start} = $pt{$pref->{name}}{start} 
       if $pref->{name} 
         and $pt{$pref->{name}}{start};

      $pref->{start} = "P$pref->{partition}"
       if defined $pref->{partition}
         and not $pref->{start};
      $pref->{start} = "S" 
       unless $pref->{start};

      $pref->{nsectors} = $pt{$pref->{name}}{size} 
       if $pref->{name} 
         and $pt{$pref->{name}}{size};

      $pref->{end} = ($pref->{start}+$pref->{nsectors}) 
       if $pref->{start}
        and $pref->{nsectors}
         and $pref->{start} =~ /^\d+$/
          and $pref->{nsectors} =~ /^\d+$/;

      $pref->{end} = "$pref->{start}_$pref->{nsectors}" 
       if $pref->{start} 
        and $pref->{nsectors} 
         and not $pref->{end};

      $pref->{end} = $pref->{nsectors} 
       if $pref->{nsectors} 
        and not $pref->{end};

      $pref->{end} = "P$pref->{partition}" 
       if defined $pref->{partition} 
        and not  $pref->{end};

      $pref->{end} = "E" 
       unless $pref->{end};

    }

  }

  # add raw devices for the disks and partitions
  for my $dref ( map { @{$_} if $_ } ( values %{$disklist{DISK}} , values %{$disklist{PARTITION}} ) )
  {

    # get the size using getsize for each disk and partition
    foreach my $rgsz (run_system_command("nmhs getsize $dref->{name}"))
    {
      chomp $rgsz;
      
      # Skip Blank Lines
      next unless $rgsz;

      # Remove all white space
      $rgsz =~ s/\s+//g;
  
      # Skip Blank Lines
      next unless $rgsz;

      warn "Failed to read the output from nmhs getsize for disk $dref->{name} , $rgsz\n" 
       and next
        unless $rgsz =~ /^([^:]+):(.+)$/;

      my ($name, $value) = ( $rgsz =~ /^([^:]+):(.+)$/ );

      warn "No data to be read for getsize $rgsz for disk $dref->{name} \n"
       and next
        unless $name and $value;

      # regexp is greedy
      $name =~ s/^\s+|\s+$//g;
      $value =~ s/^\s+|\s+$//g;

      $dref->{"getsize_$name"} = $value;

    }



    # Check to see if there is a related raw device and process if so
    if ($rawdisks{$dref->{major}}{$dref->{minor}}) 
    {
      
      my %rawdevinfo = %{$dref};
      
      $rawdevinfo{name} = $rawdisks{$major}{$minor}{path}; 
      $rawdevinfo{filetype} =  get_file_type($rawdevinfo{name});
      
      push @{$disklist{$rawdevinfo{type}}{$rawdevinfo{nameinstance}}}, 
       \%rawdevinfo;

      push @diskdevices, \%rawdevinfo;
      
    }

  }

  #----------------------------------------------------
  # Call diskinfo programs for each disk
  #----------------------------------------------------
  for my $dref ( values %disks )
  {
    
    my $driver = $dref->{driver}; 
    
    # Go to the next disk if we don't have a diskinfo command to execute
    warn "Failed to find the command to get disk information for disk $dref->{name} with driver $driver \n"
     and next 
      unless $storage::Register::config{driver}{$driver}{diskinfocmd};
    
    for 
    ( 
     run_system_command
     (
      "$storage::Register::config{driver}{$driver}{diskinfocmd} $dref->{name}"
     )
    )
    {
      
      chomp;

      next unless $_;      

      s/^\s+|\s+$//g;
  
      next unless $_;      

      # Skip the fields of no interest to us
      next unless $_ =~ 
       /^($storage::Register::config{driver}{$driver}{diskinfofields})/i;
      
      my($name,$value) = ( /^\s*(.*)::\s*(.*)/ );
      
      # Regexp is greedy, trailing nulls will be part of value
      $value =~ s/\s+$//g;
      
      $dref->{$name} = $value;
      
    }
    
    # Disk Technology Specific instructions 
    # The Vendor and Product are separted by a space.
    ($dref->{ide_vendor},$dref->{ide_product}) = 
     (  
       $dref->{ide_model} =~
        m/^\s*([^\s]*)\s+(.+)/
     )
      if $driver =~ /ide/i
       and $dref->{ide_model};

  } 
  
  
  #----------------------------------------------------
  # Validate data fields for the disk
  #----------------------------------------------------
  for my $dref ( values %disks )
  {
    
    # validate the data from config fields
    for my $field( keys %{$storage::Register::config{DISK}{fields}} )
    {
      # pick fields in ascending order 
      for my $porder ( sort { $a <=> $b } keys %{$storage::Register::config{DISK}{fields}{$field}} )
      {
        
        my $pfld = $storage::Register::config{DISK}{fields}{$field}->{$porder};

        # If the proposed field is valid and current field is invalid
        # or different from the proposed field, take proposed field
        $dref->{$field} = $dref->{$pfld} 
         if $dref->{$pfld} 
         and 
          (   
           not $dref->{$field} 
            or $dref->{$field} ne $dref->{$pfld} 
          );

      }
      
    }
    
    #---------------------------------------------
    #  Get vendor data for disks
    #---------------------------------------------
    storage::Utilities::getDiskVendorData(%{$dref});
  
    #---------------------------------------------
    # Device status for disks
    #---------------------------------------------
    # If disk size is invalid set status as offline
    $dref->{device_status} .= " DISK_OFFLINE" 
     if not $dref->{sizeb} 
      or $dref->{sizeb} !~ /^\d+$/;
    
  }
  
  #----------------------------------------------
  # Generate keys for disks
  #----------------------------------------------
  generateKeys( \%disks )
   or warn "Failed to generate uniquely identifying disk_keys\n"
    and return;
  
  #----------------------------------------------
  # Create slice keys and validate null fields
  # for disk records
  #----------------------------------------------
  for my $dref ( values %disks )
  {

    # Generate a slicekey for the disk
    $dref->{slice_key}  =  "$dref->{disk_key}";

    # validate the data from NULL config fields for the disk record
    if ( $storage::Register::config{nullfields} )
    {
      for my $field( keys %{$storage::Register::config{nullfields}} )
      {
        for ( @{$storage::Register::config{nullfields}{$field}} )
        {
          # If the proposed field is valid and current field is invalid
           $dref->{$field} = $dref->{$_} and
            last if $dref->{$_}
             and not $dref->{$field};
        }
      }
    }

  }

  #----------------------------------------------
  # Create slice keys for partitions using disk
  # keys in disk records
  #----------------------------------------------
  for my $diskref ( values %disks )
  {
    
    # This is an error that should be handled
    warn "No nameinstance for disk $diskref->{name}\n" 
     and next 
      unless $diskref->{nameinstance};

    #----------------------------------------------------------------
    # if there is more than one disk for the name instance copy the 
    # common fields
    #----------------------------------------------------------------
    for my $dref( @{$disklist{DISK}{$diskref->{nameinstance}}} )
    {
      
        # skip if its the same record as in diskref
        next if $dref eq $diskref;
          
        # Copy the common fields between disk record and current record
        for ( @{$storage::Register::config{diskfields}{DISK}} )
        {
          $dref->{$_} = $diskref->{$_} if $diskref->{$_};
        }

    }

    #----------------------------------------------------------------    
    # copy the common fields to each slice of this disk
    #----------------------------------------------------------------
    for my $pref( @{$disklist{PARTITION}{$diskref->{nameinstance}}} )
    {
      
        # If its a different record from the disk record
        next if $pref eq $diskref;
          
        # Copy the common fields between disk record and current record
        for ( @{$storage::Register::config{diskfields}{PARTITION}} )
        {
          $pref->{$_} = $diskref->{$_} if $diskref->{$_};
        }

	# validate the data from config fields
	for my $field( keys %{$storage::Register::config{PARTITION}{fields}} )
	{
	  # pick fields in ascending order 
	  for my $porder ( sort { $a <=> $b } keys %{$storage::Register::config{PARTITION}{fields}{$field}} )
	  {
        
	    my $pfld = $storage::Register::config{PARTITION}{fields}{$field}->{$porder};

	    # If the proposed field is valid and current field is invalid
	    # or different from the proposed field, take proposed field
	    $pref->{$field} = $pref->{$pfld} 
	     if $pref->{$pfld} 
	      and 
	      (   
	       not $pref->{$field} 
	       or $pref->{$field} ne $pref->{$pfld} 
	      );

	  }
      
	}
          
        # validate the data from NULL config fields in the current record
        if ( $storage::Register::config{nullfields} )
        {
          for my $field( keys %{$storage::Register::config{nullfields}} )
          {
            for ( @{$storage::Register::config{nullfields}{$field}} )
            {
              
              # If the proposed field is valid and current field is invalid
              $pref->{$field} = $pref->{$_} 
               and last 
                if $pref->{$_} 
                 and not $pref->{$field};
            }
          }
        }
        
        # Generate a slicekey for each slice
        $pref->{slice_key}  =  "$diskref->{disk_key}-$pref->{partition}";

    }
    
  }
  
  #----------------------------------------------
  # Copy the required fields for all records
  #----------------------------------------------
  for my $entity_ref ( @diskdevices )
  {
    
    $entity_ref->{key_value} = $entity_ref->{slice_key};    

    $entity_ref->{storage_layer} = 'OS_DISK';

    $entity_ref->{entity_type} = 'Disk Partition' 
     if $entity_ref->{type} =~ /PARTITION/i; ;

    $entity_ref->{entity_type} = 'Disk' 
     if $entity_ref->{type} =~ /^DISK$/i;

    $entity_ref->{os_identifier} = $entity_ref->{name};
    
    $entity_ref->{global_unique_id} = $entity_ref->{disk_key} 
     if $entity_ref->{type} =~ /^DISK$/i;
    
    push @{$entity_ref->{parent_entity_criteria}}, 
    { 
      entity_type => 'Disk Partition', 
      disk_key => $entity_ref->{disk_key} 
    } 
     if $entity_ref->{entity_type} =~ /^DISK$/i;

  }
   
  return \@diskdevices;
  
}

#-----------------------------------------------------------------------------------------
# FUNCTION : get_virtualization_layer_metrics
#
# DESC 
# return a array of hashes for all storage virtualization layers deployed on the host
# software raid, volume manager etc.
#
# ARGUMENTS
#
#-----------------------------------------------------------------------------------------
sub get_virtualization_layer_metrics ( )
{
   my @results;

   for my $function_pointer ( \&lvmMetrics, \&getLinuxSwraid ) 
   {

     my $results_ref = $function_pointer->();

     next unless $results_ref and @{$results_ref};

     push @results,@{$results_ref};

   }

   return [()] unless @results;

   return \@results;

}

#-----------------------------------------------------------------------------------------
# FUNCTION : lvmMetrics
#
# DESC 
# Returns an array with Hash Tables of each LVM Volume Logical Volumes
#
# ARGUMENTS
# none
#
# NOTES
# Linux LVM doesn't support mirroring - Only RAID 0 and Concat
#-----------------------------------------------------------------------------------------
sub lvmMetrics()
{
  my @lvmarray;
  my %rawdevs;
  my @path =  qw(
           /sbin/lvmdiskscan
           /usr/sbin/lvmdiskscan
          );
  
  warn " No LVM installed \n" 
   and return [()] 
    unless grep { -e $_ } @path;
  
  # Get list of raw devices  
  %rawdevs = getRawDevs();
  
  # Get the list of volumes      
  warn "ERROR:Unable to open /proc/lvm/VGs\n" 
   and return 
    if does_file_exist("/proc/lvm/VGs")
     and not opendir (PROCVGS,"/proc/lvm/VGs/");
  
  for my $vgname( readdir(PROCVGS) )
  {
    
    # VOLUME GROUP
    # A record for the volume group , parent of all the entities in the volume group
    my %volume_group;

    next if $vgname =~ /\.|\.\./; # Skip the directory and parent entries
    
    chomp $vgname;
    
    $volume_group{vendor} = 'Linux';
    $volume_group{product} = 'LVM';
    $volume_group{storage_layer} = 'VOLUME_MANAGER';
    $volume_group{entity_type} = 'Volume Group';
    $volume_group{name} = $vgname;
    $volume_group{key_value} = "linux_lvm_vg_$volume_group{name}";
    $volume_group{sizeb} = 0;
    
    # all entities belonging to the volume
    push @{$volume_group{child_entity_criteria}} ,
    { 
     volume_group => $volume_group{name},
     product => $volume_group{product}
    };
    
    push @lvmarray,\%volume_group;
  
    next if not opendir (PROCPVS,"/proc/lvm/VGs/$volume_group{name}/PVs");
    
    for my $pvname ( readdir(PROCPVS) )
    {
      my %physical_volume;

      next if $pvname =~ /\.|\.\./; # Skip the directory and parent entries
      
      # PHYSICAL VOLUME OR DISK
      $physical_volume{vendor} = 'Linux';
      $physical_volume{product} = 'LVM';
      $physical_volume{storage_layer} = 'VOLUME_MANAGER';
      $physical_volume{entity_type} = 'Physical Volume';
      $physical_volume{name} = $pvname;          # only the name eg lvol1 etc.
      $physical_volume{os_identifier} = "/dev/$physical_volume{name}";     # the path on the os to the block device
      $physical_volume{volume_group} = $volume_group{name};
      $physical_volume{key_value} = "linux_lvm_pv_$volume_group{name}_$physical_volume{name}";
      
      # physical entities on the physical volume
      push @{$physical_volume{parent_entity_criteria}}, 
      { 
       entity_type  => 'Physical Entity', 
       volume_group => $volume_group{name} , 
       product => $volume_group{product},
       disk_name    => $physical_volume{name} 
      };
      
      # Get the subdisk information      

      # keep track of contiguous chunks of PE of PV allocated to a LV
      # used as start metric for the PE
      my $pe_count = 0;   

      for my $perecord ( run_system_command("nmhs execute_pvdisplay -v $physical_volume{os_identifier}") ) 
      {

        chomp $perecord;
        
        $perecord =~ s/^\s+|\s+$//g;  
        
        next unless $perecord;
        
        # Skip title information and extent listings (which start with a number)
        next if $perecord =~ /^---|^\d+/;
   

        # Get the Physical Extent Size
        if ( $perecord =~ /PE\s+Size/i)
        {
          ( $physical_volume{pesize} ) = ( $perecord =~ /PE\s+Size[^\d]*(\d+)/i )
            if $perecord =~ /PE\s+Size[^\d]*(\d+)/i;

          #$physical_volume{pesize} = 4096 
	  $physical_volume{pesize} = 0
	    unless $physical_volume{pesize};

          $physical_volume{pesize_factor} = 1024
           if $perecord =~ /kb/i;

          $physical_volume{pesize_factor} = 1024*1024
           if $perecord =~ /mb/i;

	  $physical_volume{pesize_factor} = 1024*1024*1024
           if $perecord =~ /gb/i;

          $physical_volume{pesize_factor} = 1024
           unless $physical_volume{pesize_factor};

          $physical_volume{pesize} *= $physical_volume{pesize_factor};

          next;
        }
        
        # Get the Total PEs
        ( $physical_volume{petotal} ) = ( $perecord =~ /Total\s+PE[^\d]*(\d+)/i )
         and next
          if $perecord =~  /Total\s+PE[^\d]*\d+/i;

         # Get the Free PEs
        ( $physical_volume{pefree} ) = ( $perecord =~ /Free\s+PE[^\d]*(\d+)/i )
         and next
          if $perecord =~  /Free\s+PE[^\d]*\d+/i;

        # Get the Allocated PE
        ( $physical_volume{peallocated} ) = ( $perecord =~ /Allocated\s+PE[^\d]*(\d+)/i )
         and next
          if $perecord =~  /Allocated\s+PE[^\d]*\d+/i;       

        # Get the UUID
        ( $physical_volume{uuid} ) = ( $perecord =~ /UUID\s*(.+)/i )
         and next
          if $perecord =~  /UUID\s*.+/i;      

        # Get the Status
        ( $physical_volume{status} ) = map { uc $_ } ( $perecord =~ /PV\s+Status\s+(.+)/i )
         and next
          if $perecord =~  /PV\s+Status\s+.+/i;

        # if pe record begind with the volume path, it gives information about PE
        if ( $perecord =~ /^\/dev/)
        {

          my %disk_slice; # Hash of SubDisks
          # PHYSICAL ENTITY
          $disk_slice{vendor} = 'Linux';
          $disk_slice{product} = 'LVM';
          $disk_slice{storage_layer} = 'VOLUME_MANAGER';
          $disk_slice{entity_type} = 'Physical Entity';
          $disk_slice{volume_group} = $volume_group{name};
          $disk_slice{sizeb} = 0;
	  
	  # increment the pe counter, keeps track of the contiguus pes allocated 
	  # from a pv to a volume
          $pe_count++;
          $disk_slice{start} = $pe_count;
	  
          # LV Name                   LE of LV  PE for LV
          # /dev/vg1/lvol1            50        49
          ($disk_slice{volume_name},$disk_slice{le},$disk_slice{pe}) = split /\s+/,$perecord;
          
          #initialize the pe valus if its not obtained in the last step
          $disk_slice{pe} = 1 
	    unless $disk_slice{pe};
          $disk_slice{le} = $disk_slice{pe}
	    unless $disk_slice{le};

          $disk_slice{name} = 
           "$volume_group{name}_$physical_volume{name}_$disk_slice{start}";
          
          # Calculate the Subdisk size by multiplying
          # The # of physical extents by the 
          # physical extent size.
          
          # to be reassessed, this does not give the size of the entity
          $disk_slice{sizeb} = $disk_slice{pe} * $physical_volume{pesize};
          $disk_slice{status} = $physical_volume{status};        
          $disk_slice{key_value} = "linux_lvm_pe_$volume_group{name}_$physical_volume{name}_$disk_slice{start}";
          $disk_slice{disk_name} = $physical_volume{name};
          
          # Physical volumes used by the physical entity
          push @{$disk_slice{child_entity_criteria}},
          { 
           entity_type => 'Physical Volume', 
           volume_group => $volume_group{name}, 
	   product => $volume_group{product},	   
           name=> $disk_slice{disk_name} 
          };

          # Volumes using the physical entity
          push @{$disk_slice{parent_entity_criteria}},
          { 
           entity_type => 'Volume', 
           volume_group => $volume_group{name}, 
	   product => $volume_group{product},	   
           os_identifier => $disk_slice{volume_name} 
          };
          
          push @lvmarray,\%disk_slice;

        }

      }
      
      $physical_volume{sizeb} = $physical_volume{petotal} * $physical_volume{pesize};
      
      push @lvmarray, \%physical_volume;
      
      # Update the size of the volume group as sum of all disks
      $volume_group{sizeb} += $physical_volume{sizeb} 
       if $physical_volume{sizeb};
      
    }
    
    closedir (PROCPVS);
    
    ### Get Logical Volumes
    next if not opendir (PROCLVS,"/proc/lvm/VGs/$volume_group{name}/LVs");
    
    for my $vname ( readdir(PROCLVS) )
    {

      my %logical_volume;

      next if $vname =~ /\.|\.\./;
      
      # LOGICAL VOLUME
      $logical_volume{vendor} = 'Linux';
      $logical_volume{product} = 'LVM';
      $logical_volume{storage_layer} = 'VOLUME_MANAGER';
      $logical_volume{entity_type} = 'Logical Volume';
      $logical_volume{name} = $vname;
      $logical_volume{os_identifier} = "/dev/$volume_group{name}/$logical_volume{name}";
      $logical_volume{volume_group} = $volume_group{name};
      $logical_volume{key_value} = "linux_lvm_v_$volume_group{name}_$logical_volume{name}";

      open (PROCLV,"</proc/lvm/VGs/$volume_group{name}/LVs/$logical_volume{name}")
       or next;
      
      for my $vrecord ( <PROCLV> )
      {
        
        chomp $vrecord;
        
        $vrecord =~ s/\s+//g;
        
        # The device field is like
        # device:  58:02
        # so I use '\w*' to match exactly 'device'
        my ($name, $value) = ( $vrecord =~ /([^:]*):(.*)/ )
	 if $vrecord =~ /[^:]*:.*/;

        $logical_volume{$name} = $value 
	 if $name;

      }

      close (PROCLV);
      
      # The device field is major:minor, i.e. 58:09
      ( $logical_volume{major},$logical_volume{minor} ) = 
       split(/:/,$logical_volume{device})
        if $logical_volume{device}
         and $logical_volume{device} =~ /:/;

      # Remove leading zeros, so we can compare with minor from 'raw'
      $logical_volume{minor} =~ s/^0*// 
       if $logical_volume{minor};

      $logical_volume{minor} = '0'
       unless $logical_volume{minor};

      $logical_volume{size} *= 512 
       if $logical_volume{size}
        and $logical_volume{size} =~ /\d+/;

      $logical_volume{sizeb} = $logical_volume{size}
       if $logical_volume{size};

      $logical_volume{sizeb} = 0
       unless $logical_volume{sizeb};
      
      # LVM only supports striping and concatenation.
      # $logical_volume{stripes} is only present for striped volumes, so we can
      # assume CONCAT if $logical_volume{stripes} doesn't exist.
      # If this changes, we'll have to change this line.
      $logical_volume{configuration} .= "$logical_volume{stripes} stripes "
       if $logical_volume{stripes};

      $logical_volume{configuration} = "$logical_volume{configuration} - $logical_volume{stripesize} KB" 
       if $logical_volume{stripesize};

      $logical_volume{configuration} = 'CONCAT'
       unless $logical_volume{configuration};
      
      if 
      (
        $logical_volume{status} 
         and $lvmdefs{lvstatus}
          and $lvmdefs{lvstatus}{LV_ACTIVE}
      ) 
      {
        $logical_volume{status} = "ACTIVE";

        $logical_volume{status} = "$logical_volume{status}_READ"    
         if ($logical_volume{access} and $lvmdefs{lvaccess}{LV_READ});

        $logical_volume{status} = "$logical_volume{status}_WRITE"   
         if ($logical_volume{access} and $lvmdefs{lvaccess}{LV_WRITE});
      }
      else
      {
        $logical_volume{status} = "NOT_ACTIVE";
      }
      
      # Physical entities used by the volume
      push @{$logical_volume{child_entity_criteria}}, 
      { 
       volume_group => $volume_group{name}, 
       product => $volume_group{product},
       entity_type => 'Physical Entity', 
       volume_name => $logical_volume{os_identifier} 
      };
      
      if 
      ( 
        defined $logical_volume{major}
         and defined $logical_volume{minor}
          and $rawdevs{$logical_volume{major}}{$logical_volume{minor}}
      ) 
      {
        
        my %raw_logical_volume = %logical_volume;
        
        $raw_logical_volume{os_identifier} = 
         $rawdevs{$logical_volume{major}}{$logical_volume{minor}}{path};
        
        push @lvmarray, \%raw_logical_volume;
      }
      
      push @lvmarray,\%logical_volume;

    }
    
    closedir (PROCLVS);
    
  }
  
  closedir(PROCVGS);

  return \@lvmarray;
}


#-----------------------------------------------------------------------------------------
# FUNCTION : getLinuxSwraid
#
# DESC 
# Returns an array with Hash Tables of each SW Raid device
#
# ARGUMENTS
#
#-----------------------------------------------------------------------------------------
sub getLinuxSwraid 
{
  
  my %procpart;
  my %rawdevs;
  
  my @rows;
  my @mdlist;
  my @mds;
  
  # Get list of raw devices
  %rawdevs = getRawDevs();
  
  #Open and read /proc/partitions
  warn "ERROR:Unable to open /proc/partitions \n"
   and return 
    if does_file_exist("/proc/partitions")
     and not open (FILEHANDLE, "</proc/partitions");

  @rows = <FILEHANDLE>;
  close (FILEHANDLE);
    
  # Build a hash of names and sizes from /proc/partitions
  foreach my $reslt (@rows)
  {
    chomp $reslt;

    next unless $reslt;
    
    $reslt =~ s/^\s+|\s+$//g;

    # Skip Blank Lines
    next unless $reslt;

    # skip title
    next if $reslt =~ /major|minor|blocks/i;

    my ($major,$minor,$kblocks,$name) = split /\s+/,$reslt;
    
   # Validate name
    warn "ERROR:Failed to read the required md data from /proc/partitions record $reslt\n"
     and return
      unless $major and $name;

    # keep the proc table indexed on major, minor number in hash
    # datastucture
    # ioctl on md will give major and minor numbers for the disk
    # this hash is a look up to the name and size based on 
    # major/minor number
    $procpart{$major}{$minor}{name} = $name;
    $procpart{$major}{$minor}{kblocks} = $kblocks;

    # keep the list of md devices only
    # those which have a major number of type md
    next
      unless $major =~ /^($storage::Register::config{majors}{md})$/;

    # Build a list of md devices
    push @mdlist,$name;

  }

  warn "No MetaDisks configured \n" 
   and return [()] 
    unless @mdlist;
  
  # Go thru the list of md devices and get their details
  foreach my $md (@mdlist) 
  {
    foreach (run_system_command("nmhs execute_mdinfo /dev/$md"))
    {
      my %mdinfo;
      
      $mdinfo{storage_layer} = 'VOLUME_MANAGER';
      $mdinfo{vendor} = 'Linux_Software_Raid';
      $mdinfo{product} = 'mdadm';
      
      chomp;
      
      foreach (split(/\|/))
      {
        my ($param, $value) = /(.*)=(.*)/g;
        $mdinfo{$param} = $value;
      }
      
      if ($mdinfo{type} eq 'DISK')
      {
        $mdinfo{entity_type} = 'array';
        $mdinfo{name} = "/dev/$md";
        $mdinfo{key_value} = "linux_md_array_$md";
        $mdinfo{os_identifier} = $mdinfo{name};    
        $mdinfo{chunksize} /= 1024;
        $mdinfo{configuration} = "RAID$mdinfo{level}_$mdinfo{chunksize}kbchunks";
      }
      
      if ($mdinfo{type} eq 'SUBDISK')
      {
        my $diskname = $procpart{$mdinfo{major}}{$mdinfo{minor}}{name};
        
        $mdinfo{entity_type} = 'device';
        $mdinfo{name} = "/dev/$diskname";
        $mdinfo{key_value} = "linux_md_device_$mdinfo{name}";
        $mdinfo{os_identifier} = $mdinfo{name};
        
        # Arrays using the device
        push @{$mdinfo{parent_entity_criteria}} , 
        { 
          entity_type=>'array',  
          key_value=>"linux_md_array_$md" 
        };
        
      }
      
      # $mdinfo{size} is not always reliable for RAID 0
      # So we overwrite it here
      $mdinfo{sizeb} = 
       $procpart{$mdinfo{major}}{$mdinfo{minor}}{kblocks} * 1024;
      
      # Check to see if there is a related raw device and add the os_identifer 
      # for the raw device for the disk
      if 
      (
        $rawdevs{$mdinfo{major}}{$mdinfo{minor}} 
         and $mdinfo{type} eq 'DISK'
      ) 
      {
        my %rawmdinfo = %mdinfo;
        
        $rawmdinfo{name} = $rawdevs{$mdinfo{major}}{$mdinfo{minor}}{path};
        $mdinfo{os_identifier} = $rawmdinfo{name};
        
        push @mds, \%rawmdinfo;
      }
      
      push @mds,\%mdinfo;
    }
  }
  
  return \@mds;
  
}



#------------------------------------------------------------------------------------
# FUNCTION : get_filesystem_metrics
#
#
# DESC
# Returns a array of hashes of filesystem metrics
#
# ARGUMENTS:
#
#
#------------------------------------------------------------------------------------
sub get_filesystem_metrics ( )
{
  
  return \@storage::Register::filesystemarray 
   if @storage::Register::filesystemarray;
  
  my %fsarray;
  
  # -P df information in portable format, Gives out in block size of 512 bytes
  # Build a hash of the filesystem information on keys filesystem type
  # and mount point
  # Execute command twice, bug in df leaves out some nfs file systems
  # the first time
  my @dummy = run_system_command("df -P",120);
  
  # Execute the command for each fstype to instrument the metrics 
  for my $fstype ( keys %{$storage::Register::config{filesystem}{command}} )
  {
    
    for my $reslt ( run_system_command($storage::Register::config{filesystem}{command}{$fstype},120,2) )
    {
      
      chomp $reslt;
      
      next unless $reslt;

      $reslt =~ s/^\s+|\s+$//g;
      
      next unless $reslt;
      
      # Skip heading, 'none' and 'shmfs' filesystems
      next if $reslt =~ /^\s*Filesystem|^none|^shmfs|^Filename/i;
      
      my %fsinfo = ();
      
      my @columns = split /\s+/,$reslt;

      warn "Failed to get the filesystem columns from record $reslt, skipping filesystem\n"
       and next 
         unless @columns;
      
      # If command used is 'df -P'
      if ( $storage::Register::config{filesystem}{command}{$fstype} =~ /df/ )
      {
        $fsinfo{filesystem} = $columns[0];
        $fsinfo{fstype}     = $columns[1];
        $fsinfo{size}       = $columns[2];
        $fsinfo{used}       = $columns[3];
        $fsinfo{free}       = $columns[4];
        $fsinfo{mountpoint} = $columns[6];
        
      }# If command used is swapon -s
      elsif ( $storage::Register::config{filesystem}{command}{$fstype} =~ /swap/ ) 
      {
        
        $fsinfo{filesystem} = $columns[0];
        $fsinfo{fstype}     = "swap";
        $fsinfo{size}       = $columns[2];
        $fsinfo{used}       = $columns[2];
        $fsinfo{free}       = 0;        
      }
      else
      {
        warn " Unrecognized command  $storage::Register::config{filesystem}{command}{$fstype} \n" 
         and next;
      }
      
      # Validate the filesystem and mountpoint
      warn " Filesystem not available for $fstype from record $reslt, skipping filesystem \n" 
       and next 
        unless $fsinfo{filesystem};

      # Skip if filesystem is based on ram
      if ( does_file_exist( $fsinfo{filesystem} ) )
      {
        my $lsfs = storage::sUtilities::get_source_link_file($fsinfo{filesystem});
        warn " Filesystem $fsinfo{filesystem} is based on ram, skipping filesystem \n"
         and next
          if $lsfs and $lsfs =~ /\/dev\/ram/;
      }
      
      # Skip if this filesystem has already been instrumented
      # Skip if filesystem type is in the list of filesystems to be ignored
      next 
       if exists $storage::Register::config{filesystem}{skipfilesystems} 
        and $fsinfo{fstype} =~ /^($storage::Register::config{filesystem}{skipfilesystems})$/i;

      # Get the bytes from blocks
      map {$_ *= 1024} ($fsinfo{size},$fsinfo{used},$fsinfo{free});

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
      %nfsservers = map{$_->{nfs_server} => 1 
       if $_->{nfs_server} } @{$fsarray{$fstype}};
      
      #Get the identifier for each of the nfs server , build a
      #hash of hashes for nfs configuration
      map
       {my %reslt = storage::sUtilities::get_server_identifier($_); 
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
      
      # Get the nfs(mac_adress, and ip address of the nfs
      # server if filesystem nfs
      
      $fsref->{nfs_mount_privilege} = 
       storage::sUtilities::get_mount_privilege($fsref->{mountpoint}) 
        if $fsref->{fstype} eq 'nfs'
         and $fsref->{mountpoint};
      
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
      # OS identifier only if the filesystem is present on the os, This will leave 
      # out remote filesystems like NFS
      $filesystem{os_identifier} = $fsref->{filesystem} 
       if $fsref->{fstype} ne 'nfs' 
         and -e $fsref->{filesystem};
      $filesystem{mountpoint} = $fsref->{mountpoint}  
       if $fsref->{mountpoint};
      
      # Who are its parents
      # The current mountpoint
      # Since these are OS entities any other cached filesystem mounts or 
      # filesystem based swap  will be discovered by the analysis program
      # There is no need to define the parent key criteria for these
      $filesystem{parent_key_value} = $mountpoint{key_value} 
       if $fsref->{mountpoint} 
        and $mountpoint{mountpoint};      

      $filesystem{storage_layer} = 'LOCAL_FILESYSTEM';
      $filesystem{entity_type} = 'Filesystem';
        
      # If the filesystem is a regular file or directory  and not a block device 
      # indicate its type in entity_type 
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
  
  return \@storage::Register::filesystemarray
  
}

#-----------------------------------------------------------------------------------------
# FUNCTION : getRawDevs
#
# DESC 
# returns hash containing information about the raw devices on the system
#
# ARGUMENTS
#
#-----------------------------------------------------------------------------------------
sub getRawDevs
{
  
  my %rawdevs;
  
  #----------------------------------------------------
  # Build a hash listing of the raw devices using 'raw'
  #----------------------------------------------------
  
  foreach (run_system_command("nmhs get_raw_devices -q -a"))
  {

    my ($major,$minor) = /major\s+(\d+),\s+minor\s+(\d+)/g;
    
    ($rawdevs{$major}{$minor}{path}) = /^(.*):/g;
  }
  
  return %rawdevs;
}


#------------------------------------------------------------------------------------
# FUNCTION : runShowmount
#
#
# DESC
# run showmount with --no-headers option
#
# ARGUMENTS:
#
#------------------------------------------------------------------------------------
sub runShowmount ( $ )
{
  return run_system_command("showmount -a --no-headers $_[0]");
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
    
  my $sub_path = "storage::sUtilities::$sub";

  my $sub_ref = \&$sub_path;

  return &$sub_ref(@args);

}


1;
