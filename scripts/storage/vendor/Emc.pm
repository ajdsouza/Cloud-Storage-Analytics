#
# Copyright (c) 2001, 2004, Oracle. All rights reserved.  
#
#  $Id: Emc.pm 18-aug-2004.21:03:24 ajdsouza Exp $ 
#
#
#
# NAME
#   Emc.pm
#
# DESC 
#   emc symmetrix specific subroutines
#
#
# FUNCTIONS
#
# sub generateDiskId( $ );  generate a edisk key for emc disks
# sub parsesymoutput;    parse the results of sympd to build a hash list
# sub getDiskinfo( $ );   return emc disk information from the list    
#
# NOTES
#
#
# MODIFIED  (MM/DD/YY)
# ajdsouza 08/18/04 - override symcli not available
# ajdsouza 08/09/04 - 
# ajdsouza 06/25/04 - storage reporting sources 
# ajdsouza 04/14/04  - 
# ajdsouza 04/08/04 -  storage reporting modules 
# ajdsouza  10/01/01 - Created
#

package storage::vendor::Emc;

require v5.6.1;

use strict;
use warnings;
use locale;

#-------------------------------------------------
# subs defined 
#------------------------------------------------
sub generateDiskId( $ );
sub getDiskinfo( $ );
           
#---------------------------------------------
# Variables with Global scope
#---------------------------------------------


#------------------------------------------------------------------------------------
# FUNCTION : generateDiskId
#
#
# DESC
# Generate a ID for a disk device
#
#
# ARGUMENTS:
# Reference to a Hash for the disk with the name,,inode serial_no of the disk
#
#------------------------------------------------------------------------------------
sub generateDiskId( $ )
{
  my ( $diskref ) = @_;
  
  warn "Disk name passed is NULL to get EMC Disk Information \n" 
   and return 
    unless $diskref->{nameinstance};
  
  getDiskInfo( $diskref ) 
   unless $diskref->{storage_system_id};
    
  warn "Failed to generate a diskkey from vendor information for disk $diskref->{nameinstance}\n"
   and return 
    unless 
    (  
     $diskref->{storage_system_id}
     and $diskref->{storage_disk_device_id}
    );

  $diskref->{vendor}='EMC' 
   unless $diskref->{vendor};

  # Form a diskkey from the symid and deviceid parsed from the serial number
  if ( $diskref->{product} and $diskref->{product} =~ /SYM/i )
  {
   $diskref->{disk_key} = 
    "$diskref->{vendor}-SYMMETRIX-$diskref->{storage_system_id}-$diskref->{storage_disk_device_id}"
  }
  else
  {
   $diskref->{disk_key} = 
    "$diskref->{vendor}-$diskref->{storage_system_id}-$diskref->{storage_disk_device_id}"
  }
  
  return 1;

}

#------------------------------------------------------------------------------------
# FUNCTION : getDiskinfo
#
#
# DESC
# Add to the hash EMC symmetrix specific disk information  
#
#
# ARGUMENTS:
# Reference to a Hash for the disk with the logical name of the disk
#
#------------------------------------------------------------------------------------
sub getDiskinfo( $ )
{
  
  my $diskref = $_[0];
  
  warn "Disk name passed is NULL to get EMC Disk Information \n" 
   and return 
    unless $diskref->{nameinstance};
  
  warn "Disk sequence no is NULL for EMC disk $diskref->{nameinstance}\n" 
   and return 
    unless $diskref->{sq_serial_no};

  # Parse the symid and deviceid from the scsi serial number
  my ($symid,$deviceid,$port)  = 
   ( $diskref->{sq_serial_no} =~ /^\s*(......)(...)(...).*/i );

  warn "Failed to get the EMC system id for disk $diskref->{nameinstance}\n"
   and return 
    unless $symid;

  $deviceid = '000' unless $deviceid;
    
  # Copy values farmed from the sq_serial_no for EMC Symmetrix
  $diskref->{storage_system_id}      = $symid;
  $diskref->{storage_disk_device_id} = $deviceid;
  
  return 1;

}


1;
