#
# Copyright  (c) 2001,2002  Oracle Corporation All rights reserved 
#
#  $Id: Hitachi.pm,v 1.10 2002/11/18 06:32:44 ajdsouza Exp $ 
#
#
# NAME  
#	 Hitachi.pm
#
# DESC 
#	HItachi Storage subroutines 
#
#
# FUNCTIONS
# sub generateDiskId( \% );
# sub getDiskinfo( \% ); 
#
# NOTES
#
#
# MODIFIED	(MM/DD/YY)
# ajdsouza       09/23/02
#
#

package Monitor::Storage::Hitachi;

require v5.6.1;

use strict;
use warnings;
use Monitor::Utilities;

#-----------------------------------------------
# subs defined 
#------------------------------------------------
sub generateDiskId( \% );
sub getDiskinfo( \% ); 
   
#---------------------------------------------
# Variables with Global scope
#---------------------------------------------
my %hitachiconfig;

# Hitachi models with a port identifuer in their LUN
$hitachiconfig{models}{withport}="0350|0400|0401|0450|0410|04";

#-----------------------------------------------------------------
# FUNCTIONS : generateDiskId
#
# DESC : Generate a id for a disk to consistently 
# identify the disk
#
#   HITACHI SPECIAL
#
#    For hitachi 12 bytes from offset 36 give the serial number
#    The serial number is in HEX
#    This is to be inteprested as 
#    4 bytes - Model
#    4 bytes  - Array serial number
#    1 byte - Port Id
#    3 Bytes - Device ID
#    If same disk is mounted on two controllers, multipathed 
#    the port number would change
#    So take serial number to be array serial number + device id
#
# ARGUMENTS :
#  referece to a hash of disk information
#
#-----------------------------------------------------------------
sub generateDiskId( \% ){
    
    my $diskref = $_[0];
    
    warn "ERROR: Disk name passed is NULL to generate Hitachi Disk Key \n" 
	and return unless $diskref->{nameinstance};    
    
    warn "ERROR: hitachi serial no is NULL to generate Hitachi Disk Key \n" 
	and return if not $diskref->{sq_hitachi_serial_no};
    
    my ($model,$arrayid,$port,$deviceid)  = 
	( $diskref->{sq_hitachi_serial_no} =~ /^\s*(....)(....)(.)(...).*/i );
    
    $diskref->{disk_key} = "$diskref->{vendor}-$model-$arrayid-$deviceid" and return
	if $model =~/^\s*($hitachiconfig{models}{withport})/i;
    
    $diskref->{disk_key} = "$diskref->{vendor}-$model-$arrayid-$port-$deviceid";
    
}

#------------------------------------------------------------------------------------
# FUNCTION : getDiskinfo
#
#
# DESC
# Add to the hash Hitachi storage system specific disk information  
#
#
# ARGUMENTS:
# Reference to a Hash for the disk with the logical name of the disk
#
#------------------------------------------------------------------------------------
sub getDiskinfo( \% ){
    
    my $diskref = $_[0];
    
    warn "ERROR: Disk name passed is NULL to get Hitachi Disk Information \n" 
	and return unless $diskref->{nameinstance};

    warn "ERROR: hitachi serial no is NULL to get Hitachi Disk Information \n" 
	and return unless $diskref->{sq_hitachi_serial_no};
      
    (
     $diskref->{product},
     $diskref->{storage_system_id},
     $diskref->{storage_port},
     $diskref->{storage_disk_device_id}
     )  
	=( $diskref->{sq_hitachi_serial_no} =~ /^\s*(....)(....)(.)(...).*/i );
    
    # Add the port to the device id, if its a model with a port number in LUN
    $diskref->{storage_disk_device_id} = "$diskref->{storage_port}$diskref->{storage_disk_device_id}" 
	if $diskref->{product} !~/^\s*($hitachiconfig{models}{withport})/i;
    
    # Generate a unique key for the external storage system
    $diskref->{storage_system_key} = 
	"$diskref->{vendor}-$diskref->{product}-$diskref->{storage_system_id}"; 

}


1;
