#
# Copyright  (c) 2001,2002  Oracle Corporation All rights reserved 
#
#  $Id: Storage.pm,v 1.47 2003/10/09 20:56:02 ajdsouza Exp $ 
#
#
# NAME  
#	 Storage.pm
#
# DESC 
#	 Register and invoke the subroutines 
#
#
# FUNCTIONS
# sub generateDiskId(\%)
# getDiskVendorData(\%)
# AUTOLOADER
#
# NOTES
#
#
# MODIFIED	(MM/DD/YY)
# ajdsouza	04/16/02 - Created
#
#

package Monitor::Storage;

require v5.6.1;

use Exporter;

use strict;
use warnings;

use Monitor::Utilities;
use Monitor::OS::App;
use Monitor::OS::Filesystem;
use Monitor::OS::Veritas;
use Monitor::Storage::Emc;
use Monitor::Storage::Sun;
use Monitor::Storage::Hitachi;
use Monitor::OS::Solaris;
use Monitor::OS::Linux;
use Monitor::OS::Hpux;

our @ISA = qw(Exporter);
our @EXPORT = qw( apps files volumes swraid disks getDiskVendorData generateDiskId getNFSFilesystemMetrics );

#-----------------------------------------------------------------------------------------
# Global package variable to hold sub name
our $AUTOLOAD;

# Global package variable to cache the list of all filesystems so can be used by other modules
# outside of Filesystem. This global is populated by Filesystem.pm
our @filesystemarray;

# Global package variable to cache the list of nfs filesystems
our @NFSFilesystems;

#-----------------------------------------------------------------------------------------
# Register subs to be invoked by sub name, OS and Vendor 
#
# eg $subRegister {getVeritasVolumes}{solaris}	= \&Monitor::Veritas::getVolumes;
# eg $subRegister {getlistdisks}{linux}		= \&Monitor::Linux::getDisks;
#
#-----------------------------------------------------------------------------------------

my %subRegister; 

$subRegister {getSwraidDisks}{solaris}			= \&Monitor::OS::Solaris::getSolarisSwraid;
$subRegister {getSwraidDisks}{linux}			= \&Monitor::OS::Linux::getLinuxSwraid;

$subRegister {getlistdisks}{solaris}			= \&Monitor::OS::Solaris::listsolarisdisks;
$subRegister {getlistdisks}{linux}			= \&Monitor::OS::Linux::listlinuxdisks;
$subRegister {getlistdisks}{hpux}			= \&Monitor::OS::Hpux::listhpuxdisks;

$subRegister {getVolumes}{solaris}			= \&Monitor::OS::Solaris::getVolumeMetrics;
$subRegister {getVolumes}{linux}			= \&Monitor::OS::Linux::getVolumeMetrics;
$subRegister {getVolumes}{hpux}				= \&Monitor::OS::Hpux::getVolumeMetrics;

$subRegister {getFilesystemMetrics}{solaris}		= \&Monitor::OS::Filesystem::allFilesystems;
$subRegister {getFilesystemMetrics}{linux}		= \&Monitor::OS::Filesystem::allFilesystems;
$subRegister {getFilesystemMetrics}{hpux}		= \&Monitor::OS::Filesystem::allFilesystems;

$subRegister {getApplicationMetrics}{solaris}		= \&Monitor::OS::App::getApplicationMetrics;
$subRegister {getApplicationMetrics}{linux}		= \&Monitor::OS::App::getApplicationMetrics;
$subRegister {getApplicationMetrics}{hpux}		= \&Monitor::OS::App::getApplicationMetrics;

$subRegister {getLocalFilesystemMetrics}{solaris}	= \&Monitor::OS::Filesystem::localFilesystems;
$subRegister {getLocalFilesystemMetrics}{linux}		= \&Monitor::OS::Filesystem::localFilesystems;
$subRegister {getLocalFilesystemMetrics}{hpux}		= \&Monitor::OS::Filesystem::localFilesystems;

$subRegister {getNFSFilesystemMetrics}{solaris}		= \&Monitor::OS::Filesystem::getNFSFilesystems;
$subRegister {getNFSFilesystemMetrics}{linux}		= \&Monitor::OS::Filesystem::getNFSFilesystems;
$subRegister {getNFSFilesystemMetrics}{hpux}		= \&Monitor::OS::Filesystem::getNFSFilesystems;

$subRegister {getFilesystems}{solaris}		= \&Monitor::OS::Solaris::getFilesystems;
$subRegister {getFilesystems}{linux}		= \&Monitor::OS::Linux::getFilesystems;
$subRegister {getFilesystems}{hpux}			= \&Monitor::OS::Hpux::getFilesystems;

$subRegister {runShowmount}{solaris}		= \&Monitor::OS::Solaris::runShowmount;
$subRegister {runShowmount}{linux}		= \&Monitor::OS::Linux::runShowmount;
$subRegister {runShowmount}{hpux}		= \&Monitor::OS::Hpux::runShowmount;

$subRegister {getEmcDiskData}{solaris}			= \&Monitor::Storage::Emc::getDiskinfo;
$subRegister {getEmcDiskData}{hpux}			= \&Monitor::Storage::Emc::getDiskinfo;
$subRegister {getSunDiskData}{solaris}			= \&Monitor::Storage::Sun::getDiskinfo;
$subRegister {getHitachiDiskData}{solaris}		= \&Monitor::Storage::Hitachi::getDiskinfo;

$subRegister {generateEmcDiskId}{solaris}		= \&Monitor::Storage::Emc::generateDiskId;
$subRegister {generateEmcDiskId}{hpux}		= \&Monitor::Storage::Emc::generateDiskId;
$subRegister {generateSunDiskId}{solaris}		= \&Monitor::Storage::Sun::generateDiskId;
$subRegister {generateHitachiDiskId}{solaris}		= \&Monitor::Storage::Hitachi::generateDiskId;

$subRegister {getVeritasVolumes}{solaris}		= \&Monitor::OS::Veritas::veritasMetrics;
$subRegister {getVeritasVolumes}{hpux}			= \&Monitor::OS::Veritas::veritasMetrics;
$subRegister {getLvmMetrics}{hpux}			= \&Monitor::OS::Hpux::hpuxlvmMetrics;


#----------------------------------------------------------------------------------------
# List of metics by metric name 

my %metrics;

$metrics{storage_applications} =  [ qw(type name id file inode filetype size used 
				       free shared oracle_database_tablespace oem_target_name) ];

$metrics{storage_filesystems} = [ qw (fstype filesystem inode mountpoint mountpointinode mount_options
				      size used free mounttype nfs_server nfs_volume nfs_vendor
				      nfs_product nfs_privilege nfs_exclusive ) ];

$metrics{storage_volume_layers} = [ qw (vendor type name diskgroup size config 
					volumename diskname filetype path inode state) ];

$metrics{storage_swraid} = [ qw(type vendor filetype name parent inode size diskkey 
				slicekey configuration) ];

$metrics{disk_devices}	 = [ qw (type filetype nameinstance logical_name inode capacity
				 vendor product configuration storage_system_id 
				 storage_disk_device_id storage_system_key storage_spindles 
				 partitionstart nsectors device_status slice_key disk_key
				 ) ];

# Functions to be invoked for applications, filesystems, volumes, swraid 
# and disks 
my %function = (
		storage_applications => \&getApplicationMetrics,
		storage_filesystems => \&getFilesystemMetrics,
		storage_volume_layers => \&getVolumes,
		storage_swraid => \&getSwraidDisks,
		disk_devices => \&getlistdisks
		);


#-----------------------------------------------------------------------------------------
# Functons to print the metrics at different levels  applications, filesystems, 
# volumes, swraid and disks Consolidation to one function TBD

sub apps{
    
    my @results =  &{$function{storage_applications}};
    return printList('storage_applications', @{$metrics{storage_applications}},@results);
    
}

sub files{
    
    my @results =  &{$function{storage_filesystems}};
    return printList('storage_filesystems', @{$metrics{storage_filesystems}},@results);
    
}

sub volumes{
 
    my @results = &{$function{storage_volume_layers}};
    return printList('storage_volume_layers', @{$metrics{storage_volume_layers}},@results);
 
}

sub swraid{
 
    my @results = &{$function{storage_swraid}};
    return printList('storage_swraid', @{$metrics{storage_swraid}},@results);
 
}

sub disks{
    
    my @results =  &{$function{disk_devices}};
    return printList('disk_devices', @{$metrics{disk_devices}},@results);
 
}

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
sub getDiskVendorData(\%){
    
    my $diskref = $_[0];
    
    warn "DEBUG: Vendor and product information not found for $diskref->{name} $diskref->{instance}\n" 
	and return
	if not exists $diskref->{vendor} or not exists $diskref->{product};

    # Vendor = EMC / SYMETRIX
    getEmcDiskData($diskref) and return
       	if  $diskref->{vendor} =~ /EMC/i;
    
    # Vendor = SUN / T300
    getSunDiskData($diskref) and return   
	if  $diskref->{vendor} =~ /SUN/i 
	and $diskref->{product} =~ /T300/i;
    
    # Vendor = HITACHI / *
    getHitachiDiskData($diskref) and return   
	if  $diskref->{vendor} =~ /HITACHI/i; 
    
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
sub generateDiskId(\%){
    
    my $diskref = $_[0];
    
    warn "DEBUG: Vendor and product information not found for $diskref->{name} $diskref->{instance}\n" 
	and return
	if not exists $diskref->{vendor} or not exists $diskref->{product};
    
    # Vendor = EMC / SYMETRIX
    generateEmcDiskId($diskref) and return
       	if  $diskref->{vendor} =~ /EMC/i;
    
    # Vendor = SUN / T300
    generateSunDiskId($diskref) and return
	if  $diskref->{vendor} =~ /SUN/i 
	and $diskref->{product} =~ /T300/i;
    
    # Vendor = HITACHI / *
    generateHitachiDiskId($diskref) and return
	if  $diskref->{vendor} =~ /HITACHI/i; 
    
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
sub AUTOLOAD{
			
    my $sub = $AUTOLOAD;
		
    $sub =~ s/.*:://;	
		
    warn "DEBUG : $sub not available for $^O \n" and return 
	unless $subRegister{$sub}{$^O};
		
    warn "ERROR: No such function $sub for $^O \n" and return 
	unless defined &{$subRegister{$sub}{$^O}};
    
    return &{$subRegister{$sub}{$^O}}(@_);
}



1; #Returning a true value at the end of the module

