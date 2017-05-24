#
# Copyright  (c) 2001,2002  Oracle Corporation All rights reserved 
#
#  $Id: Emc.pm,v 1.49 2003/02/06 00:50:38 ajdsouza Exp $ 
#
#
#
# NAME  
#	 Emc.pm
#
# DESC 
#	 emc symmetrix specific subroutines
#
#
# FUNCTIONS
#
# sub generateDiskId( $ );  generate a edisk key for emc disks
# sub parsesymoutput;    parse the results of sympd to build a hash list
# sub getDiskinfo( $ );	 return emc disk information from the list		
#
# NOTES
#
#
# MODIFIED	(MM/DD/YY)
# ajdsouza	10/01/01 - Created
#

package Monitor::Storage::Emc;

require v5.6.1;

use strict;
use warnings;
use Monitor::Utilities;

#-------------------------------------------------
# subs defined 
#------------------------------------------------

sub generateDiskId( $ );
sub parsesymoutput;
sub getDiskinfo( $ );
				   
#---------------------------------------------
# Variables with Global scope
#---------------------------------------------
						   
my %emcdevices; # Array of references to sym disk devices


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
sub generateDiskId( $ ){
    
    my $diskref = $_[0];
    my $emcref;
    my $symid;
    my $deviceid;
    my $port;
    
    warn "WARN: Disk name passed is NULL to get EMC Disk Information \n" 
	and return unless $diskref->{nameinstance};
    
    # Ensure that symmpd is executed only ony once per run
    parsesymoutput() if not keys %emcdevices;
    
    warn "WARN: EMC Symmetrix information NA , check EMC symcli configuration \n" 
	and return if not keys %emcdevices;
    
    # Get the emc hash has which corresponds to this disk device
    # Check based on inode
    $emcref = $emcdevices{inode}{$diskref->{inode}} 
    if $diskref->{inode} and $emcdevices{inode}{$diskref->{inode}};
       
    # If a emc device cannot be got on inode 
    # Check if scsi serial number has emc symid, deviceid in it
    if ( not $emcref ){
	
	# Parse the symid and deviceid from the scsi serial number
	($symid,$deviceid,$port)  = 
	    ( $diskref->{sq_serial_no} =~ /^\s*(......)(...)(...).*/i )
	    if $diskref->{sq_serial_no};

	# Search of the emc hash on symid and deviceid parsed from scsi serial#
	for ( keys %{$emcdevices{deviceid}} ){
	    
	    # break this search if symid or deviceid is NA
	    last unless $symid and $deviceid;

	    # if found break 
	    $emcref = $emcdevices{deviceid}{$_} and last
	    if $_ =~ /$symid$deviceid/i;	
	    
	}

    }
 
    warn "WARN: EMC Symmetrix information NA for $diskref->{nameinstance} \n"
	unless $emcref;
    
    # Form the diskkey from emc symid and device id if found
    $diskref->{disk_key} = 
	"$emcref->{vendor}-$emcref->{storage_system_id}-$emcref->{storage_disk_device_id}"
	and return
	if $emcref and $emcref->{storage_system_id} and $emcref->{storage_disk_device_id};
    
    # Form a diskkey from the symid and deviceid parsed from the serial number
    $diskref->{disk_key} = "$diskref->{vendor}-$symid-$deviceid"
	if $symid and $deviceid;
    
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
sub getDiskinfo( $ ){
    
    my $diskref = $_[0];
    my $emcref;
    
    warn "WARN: Disk name passed is NULL to get EMC Disk Information \n" 
	and return unless $diskref->{nameinstance};
    
    # Ensure that symmpd is executed only ony once per run
    parsesymoutput() if not keys %emcdevices;
    
    warn "WARN: EMC Symmetrix information NA , check EMC symcli configuration \n" 
	and return if not keys %emcdevices;
    
    # Get the emc has which corresponds to this disk device
    # Check in inode
    $emcref = $emcdevices{inode}{$diskref->{inode}} 
    if $diskref->{inode} and $emcdevices{inode}{$diskref->{inode}};

    # If a emc device cannot be got on inode 
    # Check if scsi serial number has emc symid, deviceid in it
    if ( not $emcref ){
	
	# Parse the symid and deviceid from the scsi serial number
	my ($symid,$deviceid,$port)  = 
	    ( $diskref->{sq_serial_no} =~ /^\s*(......)(...)(...).*/i )
	    if $diskref->{sq_serial_no};

	# Search of the emc hash on symid and deviceid parsed from scsi serial#
	for ( keys %{$emcdevices{deviceid}} ){
	    
	    # break this search if symid or deviceid is NA
	    last unless $symid and $deviceid;
	    
	    # if found break 
	    $emcref = $emcdevices{deviceid}{$_} and last
		if $_ =~ /$symid$deviceid/i;	
	    
	}
		
    }
    
    warn "WARN: EMC Symmetrix information NA for $diskref->{nameinstance} \n"
	and return if not $emcref;
    
    # Copy the values from the story hash if the proposed field is valid 
    # and current field is invalid or different from the proposed field, 
    # take proposed field
    for ( keys %{$emcref} ){

	next unless $emcref->{$_};
	
	# If its the same value skip
	next if $diskref->{$_} and $diskref->{$_} eq $emcref->{$_};
	
	# Append for these values
	$diskref->{$_} .= " $emcref->{$_}" and next if $diskref->{$_} and $_ =~ /^(configuration|device_status)/;
	
	$diskref->{$_} = $emcref->{$_};  
	
	}
    
}


#------------------------------------------------------------------------------------
# FUNCTION : parsesymoutput
#
#
# DESC
# parse syminfo to build a reference to a list of emc disk devices
#
# ARGUMENTS:
#
#------------------------------------------------------------------------------------
sub parsesymoutput{
    
    # sym discovery takes a while on hosts with emc storage > 1.5 TB
    for ( runSystemCmd("runcmd syminfo",600) )
    {
	
	my %emcdevice;
	
	chomp;
	
	s/^\s+|\s+$//g;
	
	next unless $_;

	(	      
		      
		      $emcdevice{vendor},
		      $emcdevice{product},
		      $emcdevice{storage_system_id},
		      $emcdevice{capacity},	       
		      $emcdevice{storage_device_name},	
		      $emcdevice{storage_disk_device_id},
		      $emcdevice{device_status},
		      $emcdevice{configuration},
		      $emcdevice{storage_spindles}
		      
		      ) = split /\s*\|\s*/;
	
	#leave out veritas volume manager devices on solaris
	next if
	    $^O =~ /solaris/i and  
	    $emcdevice{storage_device_name} and  
	    $emcdevice{storage_device_name} =~ m|/dev/vx/|;

	# reset storage_capacity if its invalid
	$emcdevice{capacity} = 0 
	    unless  
	    $emcdevice{capacity} and 
	    $emcdevice{capacity} =~ /\d+/;  	
	
	# Generate a unique key for the external storage system
	$emcdevice{storage_system_key} = 
	    "$emcdevice{vendor}-$emcdevice{product}-$emcdevice{storage_system_id}";
	
	# Get the inode for the device and save the device information in a hash
	# with inode for the device as key
	$emcdevice{storage_inode} = getinode($emcdevice{storage_device_name}) 
	    if $emcdevice{storage_device_name};
	
	# Store the reference to the hash in a 
	$emcdevices{inode}{$emcdevice{storage_inode}} = \%emcdevice if $emcdevice{storage_inode};	
	
	$emcdevices{deviceid}{"$emcdevice{storage_system_id}$emcdevice{storage_disk_device_id}"} = \%emcdevice 
	    if $emcdevice{storage_system_id} and $emcdevice{storage_disk_device_id};
	
    }
    
}


1;
