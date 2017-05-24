#
# Copyright  (c) 2001,2002  Oracle Corporation All rights reserved 
#
#  $Id: Solaris.pm,v 1.126 2003/03/13 18:07:35 ajdsouza Exp $ 
#
#
# NAME  
#	 Solaris.pm
#
# DESC 
#	Solaris OS specific subroutines to get disk device information 
#
#
# FUNCTIONS
#
#  sub checkKeys(\%);
#  sub generateKeys(\%);
#  listsolarisdisks;
#  getLogicalName($);
#  cacheLogicalPhysicalMap;
#  getVolumeMetrics;
#  getVolumeManager;
#  getFilesystems;
#  getSolarisSwraid;
#  runShowmount($);
#
#
# NOTES
#
#
# MODIFIED	(MM/DD/YY)
# ajdsouza	04/16/02 - Changes to meet GIT requirements
# ajdsouza	10/01/01 - Created
#
#
#


package Monitor::OS::Solaris;

require v5.6.1;

use strict;
use warnings;
use Monitor::Utilities;
use Monitor::Storage;
use File::Basename;
use URI::file;

#------------------------------------------------
# subs declared
#-----------------------------------------------
sub checkKeys(\%);
sub generateKeys(\%);
sub listsolarisdisks;
sub cacheLogicalPhysicalMap;
sub getLogicalName( $ );
sub getVolumeMetrics;
sub getVolumeManager;
sub getFilesystems;
sub getSolarisSwraid;
sub runShowmount ( $ );

#-------------------------------------------------
# Variables in package scope
#------------------------------------------------
# Variable for logical to physical map for all disk slices
my %logicallist;

# Hash variables for holding config information
my %config;

# candidate fields for choosing unique key for disks
$config{key}{emc}="sq_serial_no deviceid";
$config{key}{hitachi}="sq_hitachi_serial deviceid";
$config{key}{symbios}="sq_vendorspecific sq_vpd_pagecode_83 deviceid";
$config{key}{default}="sq_vendorspecific deviceid sq_serial_no";

# Order of choice from among candidates for a field
$config{fields}{vendor}=[qw(scsivendor sq_vendor)];
$config{fields}{product}=[qw(scsiproduct sq_product)];
$config{fields}{storage_disk_device_id}=[qw(scsiserial sq_serial_no)];
$config{fields}{capacity}=[qw(sq_capacity)];

# order of choice only if field is null or not defined
$config{nullfields}{logical_name}=[qw(physical_name nameinstance)];

# List of fields to be common for each slice of a disk
$config{diskfields}{PARTITION}=
    [qw(disk_key vendor product storage_system_id 
	configuration storage_spindles storage_system_key 
	storage_disk_device_id device_status)];
# List of fields common or slices representing disks
$config{diskfields}{DISK}=
    [qw(disk_key slice_key vendor product capacity storage_system_id 
	configuration storage_spindles storage_system_key 
	storage_disk_device_id device_status)];

# scsi inquiry fields we are interested in
$config{scsiinqfields}=
    "sq_vendor|sq_product|sq_revision|sq_serial_no|sq_capacity|sq_hitachi|sq_vendorspecific|sq_vpd_pagecode_83";

#Versions supported
$config{osversions}="5.6|5.7|5.8|5.9";

#--------------------------------------------------------
# Filesystem metric specific configuration
#--------------------------------------------------------
# Filesystem commands tend to hang due to rpc
# to ensure atleast ufs and vxfs are instrumented in such a case
# exceute the ufs and vxfs commands exclusively than those that may involve rpc's
# The commands to execute for getting filesystems
$config{filesystem}{command}{ufs}   = "df -P -F ufs";
$config{filesystem}{command}{vxfs}  = "df -P -F vxfs";
# df shows swap filesystems only as "swap". `swap -l` shows a list of
# filesystems that are used for swap space.
$config{filesystem}{command}{swap}  = "swap -l";
# The commands to execute for getting all Local filesystems
$config{filesystem}{command}{local} = "df -P -l";
# the local and nfs filesystems are got in two seperate calls
# to avoid nfs rpc hangs from intefering local filesystems
$config{filesystem}{command}{nfs}   = "df -P -F nfs";

# Filesystems to skip, need not instrument metrics for these filesystems
$config{filesystem}{skipfilesystems} = "mvfs|proc|fd|mntfs|tmpfs|cachefs|shm|cdfs|hsfs|lofs";

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
sub checkKeys(\%){
    
    my %count;
    my %list;
 
    my %disks = %{$_[0]};   
    
    for my $key( keys %disks ){
	# Take a count of the keys
	if ( $disks{$key}->{diskkey} ){
	    
	    $count{$disks{$key}->{keytype}}{$disks{$key}->{diskkey}}++;
	    push @{$list{$disks{$key}->{diskkey}}},$disks{$key};
	    
	}
    }


    for my $key ( keys %list ){
	
	my %keycheck;
	
	for my $disk ( @{$list{$key}} ){
	    
	    # Check if controller repeats for the same key
	    $keycheck{$disk->{controller}}++ if $disk->{controller};
	    
	    print " Controller repeats for $key \n" and last 
		if $keycheck{$disk->{controller}} and  
		$keycheck{$disk->{controller}} > 1;
	    
	    # check if 2 pseudos repeat for the same key
	    $keycheck{pseudo}++ if $disk->{diskpath} =~ /\/devices\/pseudo/i;
	    
	    print "pseudos repeat for $key \n" and last 
		if $keycheck{pseudo} and $keycheck{pseudo} > 1;
	    
	}
	
	# check if a pseudo exists if key count > 1
	print "Multipathed without pseudo parent/layered driver \n" 
	    if @{$list{$key}} > 1 and grep /\/devices\/pseudo/i, @{$list{$key}};
	
    }
    

    for my $type ( keys %count){
	
	print "$type\n";
	
	for ( keys %{$count{$type}} ){
	    
	    print "\t$_ - $count{$type}{$_} \n";
	    
	    for my $disk ( @{$list{$_}} )
	    {
		print "\t\t $disk->{diskpath} \n";
	    }
	    
	}
	
    }
    
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
sub generateKeys(\%){
    
    my %disks = %{$_[0]};
    
    for my $key( keys %disks ){
	
	my @values;
	
	# Call vendor specifc sub to generate the disk_key
	Monitor::Storage::generateDiskId($disks{$key});
	
	# If disk_key succesfully generated skip to the next disk
	next if $disks{$key}->{disk_key};
	
	# Genrate the key from the canadidate fields in the config information		
	if ( $config{key}{lc "$disks{$key}->{vendor}-$disks{$key}->{product}"} ){
	    @values = split /\s+/,$config{key}{lc "$disks{$key}->{vendor}-$disks{$key}->{product}"};
	}
	elsif ( $config{key}{lc $disks{$key}->{vendor}} ){
	    @values = split /\s+/,$config{key}{lc $disks{$key}->{vendor}};
	}
	else{
	    @values = split /\s+/,$config{key}{default};
	}
	
	# Generate the key from the list of candiate fields
	for ( @values ){

	    # If the device id type is DEVID_NONE|DEVID_ENCAP then skip the device id
	    next if $_ =~ /devid/i and $disks{$key}->{deviceidtype} =~ /DEVID_NONE|DEVID_ENCAP/i;
	    
	    $disks{$key}->{keytype} = $_ 
		and $disks{$key}->{disk_key} = "$disks{$key}->{vendor}-$disks{$key}->{$_}"
		and last 
		if $disks{$key}->{$_};	
	}
	
	# If diskkey is still not generated then take diskpath as disk key
	$disks{$key}->{disk_key} = "DISKKEY-$disks{$key}->{diskpath}" 
	unless $disks{$key}->{disk_key};

    }
    
}


#------------------------------------------------------------------------------------
# FUNCTION : listsolarisdisks
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
sub listsolarisdisks{
    
# arrays to store disks, disk controllers and hash of disk configuration
    my %disks; 
    my @slices;
    my %disklist;
    my $discoverdisks = 'kdisks';
    my $version;
    my $isalist;
    
    # Get the OS version
    chomp ($version = runSystemCmd("uname -r"));
    
    # Check if OS version is supported
    warn "WARN: OS version $version currently not supported \n" and return 
	if $version !~ /($config{osversions})/i;
    
    #Get the list of architecures supported
    chomp ($isalist = runSystemCmd("isalist"));
    
    #Check if the  kernel data type is 64 bit, chose kdisks64
    $discoverdisks = 'kdisks64' if $version >= 5.7 and $isalist =~ /sparcv9/i;
    
    # Local placeholder variables for parsed values, these values are not used in the hash
    my ( $recordtype,$driver,$instance,$volumelabel,$asciilabel,$target,$lun,$scsitarget,
	 $scsilun,$class,$devidhint, $controller,$controllerdriver,$controllernum,
	 $controllertype,$blocksize,$nblocks,$mediatype,$naltcylinders,$nsectorspertrack,
	 $nphysicalcylinders,$diskrpm,$nodename,$majornumber,$minornumber,$nodeclass,
	 $nodetype,$clone );

    # Disover all disks and process the results
    # ON large hosts kdisks takes a while to execute
    for ( runSystemCmd("runcmd $discoverdisks",600) ){
	
	my %devinfo;
	
	chomp;
	
	s/^\s+|\s+$//g;
	
	next unless $_;

	(
	 $recordtype,
	 $devinfo{pseudo},
	 $driver,
	 $instance,
	 $target,#target
	 $devinfo{diskpath},
	 $volumelabel,#volume label
	 $asciilabel, # ascii volume label
	 $lun,#lun
	 $devinfo{vendor},
	 $devinfo{product},
	 $scsitarget,#scsitarget
	 $scsilun,#scsilun
	 $devinfo{disktype},
	 $class,#class
	 $devinfo{scsivendor},
	 $devinfo{scsiproduct},
	 $devinfo{scsirevision},
	 $devinfo{scsiserial},
	 $devinfo{deviceidtype},
	 $devidhint,#deviceid hint
	 $devinfo{deviceid},
	 $devinfo{configurationnamevalues},
	 $controller,# Disk controller
	 $controllerdriver,#controllerdriver
	 $controllernum,#controllernum
	 $controllertype,#controllertype
	 $blocksize,#blocksize
	 $nblocks, #no of blocks on the disk
	 $devinfo{disksize},
	 $mediatype,#mediatype
	 $devinfo{formatstatus},
	 $devinfo{ndatacylinders},
	 $naltcylinders,#naltcylinders
	 $nsectorspertrack,#nsectorspertrack
	 $nphysicalcylinders,#nphysicalcylinders
	 $diskrpm,#diskrpm
	 $devinfo{physical_name},
	 $nodename,#nodename
	 $majornumber,#majornumber
	 $minornumber,#minornumber
	 $nodetype, #nodetype
	 $nodeclass,#nodeclass
	 $clone,#clone
	 $devinfo{filetype},
	 $devinfo{partition},
	 $devinfo{capacity},
	 $devinfo{partitionstart},
	 $devinfo{nsectors},
	 $devinfo{sectorsize},
	 $devinfo{partitiontype}
	 ) = split /\s*\|\s*/; 
	
	# Skip CDROM    
	next if $controllertype =~ /CDROM/i or $nodetype =~ /DDI_NT_CD_/i;
	
	# If no minor nodes then indicate that in status
	$devinfo{device_status} = "NO_MINOR_NODES" if $recordtype =~ /NO_MINOR/i;
	
	# Build the name,instance string as name@instance
	$devinfo{nameinstance} = "$driver\@$instance";
	
	# reset the invalid/UNKNOWN number fields
	for ( qw ( partition nsectors partitionstart sectorsize) ){
	    
	    # sometimes $devinfo{$} = 0 is a valid value, so check only for its existance
	    $devinfo{$_} = -1 unless exists $devinfo{$_} and $devinfo{$_} =~ /\d+/;
	    
	}

	# Rest these values to 0 if they are invalid
	for ( qw ( disksize capacity ) ){
	    
	    $devinfo{$_} = 0 unless exists $devinfo{$_} and $devinfo{$_} =~ /\d+/;
	    
	}	
	
	# Deduce the type of slice, if it represents the whole disk or a slice
	$devinfo{type} = 'DISK'	if 
	    $devinfo{partitiontype} =~ /BACKUP/i or 
	    $recordtype =~ /NO_MINOR/i or
	    $devinfo{formatstatus} =~ /UNFORMATTED/i;
	
	$devinfo{type} = 'PARTITION' unless $devinfo{type};
	
	# Use the devicepath as physical_name for a disk if physical name is undefined
	$devinfo{physical_name} = $devinfo{diskpath}
	if 
	    not	$devinfo{physical_name}	and 
	    $devinfo{diskpath} and 
	    $devinfo{type} =~ /DISK/i;
	
	# Get the inode for the disk, 
	$devinfo{inode}  =  getinode($devinfo{physical_name}) if $devinfo{physical_name};
	
	# Logical name for the disk, ignore if logical name is not found
	$devinfo{logical_name} = getLogicalName($devinfo{physical_name}) if $devinfo{physical_name}; 
	
	# Get filetype if its not defined or unknown
	$devinfo{filetype} = getfiletype($devinfo{physical_name}) unless 
	    $devinfo{filetype} and 
	    $devinfo{filetype} !~ /UNKNOWN/i;       
	
	# Keep an list indexed on nameinstance and type
	push @{$disklist{$devinfo{nameinstance}}{$devinfo{type}}}, \%devinfo;
	
	# Generate a unique key for each row before pushing it, here its the array count
	$devinfo{key} = @slices;
	
	# Lits of disk slices to be instrumentated
	push @slices,\%devinfo;       
	
    }

    #------------------------------------------------------------
    # GET THE DISK RECORD
    #------------------------------------------------------------
    # Check if a disk record exists for each id, else create one
    # If more than one exist then chose the best one for prcessing
    # disk specific information
    for my $key ( keys %disklist ){
		
	# First choice PARTITION 2 IS BACKUP take partition 2 if it is a disk
	for my $diskref( grep{ $_ if $_->{filetype} and $_->{partition} and $_->{filetype} =~ /CHARACTER/ and $_->{partition} == 2 } @{$disklist{$key}{DISK}} ){
	    
	    $disks{$key} = $diskref and last;
	    
	}
	
 	next if $disks{$key};

	# 2nd chance UNFORMATTED DISKS ,check if this is a unformatted disk with diskpath = physical_name
	for my $diskref( grep{ $_ if 
				   $_->{formatstatus} and 
				   $_->{filetype} and 
				   $_->{filetype} =~ /CHARACTER/ and 
				   $_->{formatstatus} =~ /UNFORMATTED/i } @{$disklist{$key}{DISK}} ) {
	    
	    $disks{$key} = $diskref and last;
	    
	}	

	# 3rd choice take a copy of partition 2 if its a slice and use it to be the disk record
	for my $diskref( grep{ $_ if $_->{filetype} and $_->{partition} and $_->{filetype} =~ /CHARACTER/ and $_->{partition} == 2 } @{$disklist{$key}{PARTITION}} ){
	    
	    my %diskrec = %$diskref;
	    
	    $diskrec{type} = 'DISK';
	    $diskrec{capacity} = $diskrec{disksize};
	    
	    # Get the sector size of the Disk from any of the disk records
	    for my $ref( @{$disklist{$key}{DISK}} ){
		
		$diskrec{partitionstart} = $ref->{partitionstart} and $diskrec{nsectors} = $ref->{nsectors} and last;
		
	    }

	    # Push this disk slice on to the list
	    push @slices, \%diskrec;

	    # Keep an list indexed on nameinstance and type
	    push @{$disklist{$diskrec{nameinstance}}{$diskrec{type}}}, \%diskrec;

	    $disks{$key} = \%diskrec and last;
	    
	}

 	next if $disks{$key};
	
	# Third chance ,check if this is a disk with no minor nodes
	for my $diskref( grep{ $_ if $_->{device_status} and $_->{device_status} =~ /NO_MINOR_NODES/ } @{$disklist{$key}{DISK}} ){
	    
	    $disks{$key} = $diskref and last;
	    
	}
	

	# 4th chance ,Take any of the other CHARACTER slices that represent a disk
	for my $diskref( grep{ $_ if $_->{filetype} and $_->{filetype} =~ /CHARACTER/ } @{$disklist{$key}{DISK}} ){
	    
	    $disks{$key} = $diskref and last;
	    
	}
	
	warn "DEBUG: No disk available for $key \n" and next;

   } 
    
    #---------------------------------------------
    # SCSI INQUIRY
    #--------------------------------------------
    for my $key ( keys %disks ){
	
	# inquiry only for CHAR scsi disks
	# Take a chance on UNKNOWN disks and PSEUDO disks, sometimes their
	# controllers cant be identified accurately
	next unless
	    $disks{$key}->{disktype} =~ /DISK_SCSI|DISK_UNKNOWN/i or
	    $disks{$key}->{pseudo} =~ /PSEUDO/i;
	
	for ( runSystemCmd("runcmd scsiinq $disks{$key}->{diskpath}",120) ){
	    
	    chomp;
	    
	    s/^\s+|\s+$//g;
	    
	    # Skip the scsi fields of no intrest to us
	    next unless $_ =~ /^($config{scsiinqfields})/i;	
	    
	    my($name,$value) = ( /^\s*(.*)::\s*(.*)/ );
	    
	    # Regexp is greedy, trailing nulls will be part of value
	    $value =~ s/\s+$//g;	    	    
	    
	    $disks{$key}->{$name} = $value;
	    
	}
	
	# Rest these values to 0 if they are invalid
	for ( qw ( sq_capacity ) ){
	    
	    $disks{$key}->{$_} = 0 unless exists $disks{$key}->{$_} and $disks{$key}->{$_} =~ /\d+/;
	    
	}
	
    }   
    
    #----------------------------------------------------
    # VALIDATE DISK FIELDS
    #----------------------------------------------------
    for my $key ( keys %disks ){
	
	# validate the data from config fields
	for my $field( keys %{$config{fields}} ){
	    
	    for ( @{$config{fields}{$field}} ){
		
		# If the proposed field is valid and current field is invalid
		# or different from the proposed field, take proposed field
		$disks{$key}->{$field} = $disks{$key}->{$_} 
		if $disks{$key}->{$_}
		and (
		     not $disks{$key}->{$field}
		     or $disks{$key}->{$field} ne $disks{$key}->{$_}
		     );		
	    }
	    
	}

	#---------------------------------------------
	# CONFIGURATION
	#---------------------------------------------
	# Reformat the configuration data, we are only interested in 
	# layered driver configuration at the moment
	# config values are prop=value with a -- separator	
	map{ $disks{$key}->{configuration} = 'LAYERED_DISK' if $_ =~ /layered_driver/i  } 
	split/--/,$disks{$key}->{configurationnamevalues};

	#---------------------------------------------
	# GET VENDOR DATA
	#---------------------------------------------
	Monitor::Storage::getDiskVendorData($disks{$key});

	#---------------------------------------------
	# DEVICE STATUS
	#---------------------------------------------
	# If disk size is invalid set status as offline
	$disks{$key}->{device_status} .= " DISK_OFFLINE"
	    if
	    not $disks{$key}->{capacity} or 
	    $disks{$key}->{capacity} !~ /\d+/;	
	
	# Save format status in device status
	$disks{$key}->{device_status} .= " $disks{$key}->{formatstatus}" 
	    if
	    $disks{$key}->{formatstatus};
	
    }   
    

    #----------------------------------------------
    # GENERATE KEYS
    #----------------------------------------------
    generateKeys(%disks);
 
    for my $key ( keys %disklist ){
	       	
	# This is an error that should be handled
	warn "DEBUG: No disk for $key \n" and next unless $disks{$key};
	
	# Get a reference to the disk for this key
	my $diskref = $disks{$key}; 

	# Generate a slicekey for the disk
	$diskref->{slice_key}  =  "$diskref->{disk_key}";
	
	# validate the data from NULL config fields for the disk record
	for my $field( keys %{$config{nullfields}} ){
	    
	    for ( @{$config{nullfields}{$field}} ){
		
		# If the proposed field is valid and current field is invalid
		$diskref->{$field} = $diskref->{$_} and last if $diskref->{$_} and not $diskref->{$field};		
	    }
	}
	
	# Get the DISK and PARTITION types for this key
	for my $type( keys %{$disklist{$key}} ){	   
	    
	    # Go thru each slice and copy values from the disk
	    for my $ref ( @{$disklist{$key}{$type}} ) {	       	
						
		# If its a different record from the disk record
		if ( $ref ne $diskref ){
		    
		    # Copy the common fields between disk record and current record
		    for ( @{$config{diskfields}{$type}} ){
			
			$ref->{$_} = $diskref->{$_} if $diskref->{$_};
			
		    }
		    
		}
		
		# validate the data from NULL config fields in the current record
		for my $field( keys %{$config{nullfields}} ){
		    
		    for ( @{$config{nullfields}{$field}} ){
			
			# If the proposed field is valid and current field is invalid
			$ref->{$field} = $ref->{$_} and last if $ref->{$_} and not $ref->{$field};		
		    }
		}

		# Generate a slicekey for each slice
		$ref->{slice_key}  =  "$diskref->{disk_key}-$ref->{partition}" if $type =~ /PARTITION/i;		

		# Generate a key based on slice_key
		# Concatenate slicekey with the array count saved earlier, max key size < 128
		$ref->{key} = substr($ref->{slice_key},0,120).'-'.$ref->{key};		 
		
	    }
	    
	}
	
    }
       
    return @slices;
    
}


#------------------------------------------------------------------------------------
# FUNCTION : getLogicalName
#
#
# DESC
# Return the logical path for disk or slice
#
# ARGUMENTS:
#	physical path
#
#------------------------------------------------------------------------------------
sub getLogicalName( $ ){
    
    my ($physicalname) = @_;
    
    $physicalname = "/devices$physicalname" 
	if $physicalname !~ m|^/devices|i;
      		  
    cacheLogicalPhysicalMap if not keys %logicallist;
    
    warn "DEBUG: Logical name for $physicalname not found\n" 
	and return unless $logicallist{$physicalname};
    
    return $logicallist{$physicalname};
    
}

#------------------------------------------------------------------------------------
# FUNCTION : cacheLogicalPhysicalMap
#
#
# DESC
#
# The function caches a hash mapping logical and physical paths in the first run
# subsequent runs refer to the cache
#
#
# ARGUMENTS:
#
#------------------------------------------------------------------------------------
sub cacheLogicalPhysicalMap{
    
    # Cache the logical to physical mapping for the 
    # first run
    return if  keys %logicallist; 
        
    for my $devicedir( qw( /dev/rdsk/ /dev/dsk/ ) ){
	
	opendir(DIR, $devicedir) 
	    or warn "WARN: cannot opendir $devicedir: $!";
	
	for my $device ( readdir DIR ) {
	    
	    $device =~ s/^\s+|\s+$//g;	    
	    
	    next unless $device;

	    next if not -l "$devicedir$device";
	    
	    # The rook link of a disk device is the physical path 

	    my $physicalpath = getRootLink("$devicedir$device");
			    	    
	    $logicallist{$physicalpath} = "$devicedir$device" 
		if $physicalpath;
	    
	}
	
	closedir DIR;
    }
}
    
    
#-----------------------------------------------------------------------------------------
# FUNCTION : getvolumemanager
#
# DESC 
# return array of identifier strings for the  volume managers installed on the host
#
# ARGUMENTS
#
#-----------------------------------------------------------------------------------------
sub getVolumeManager{
    
    my %vm;
    
    # Hash array for {executable , VENDOR } map
    # Check for Veritas volume manager - Other volume 
    # managers on Solaris not yet supported
    my %path = ( 
		 '/usr/sbin/vxprint'=>'VERITAS',
		 '/usr/bin/vxprint'=>'VERITAS',
		 '/etc/vxprint'=>'VERITAS'
		 );
    
    for ( keys %path ) {
	
	$vm{$path{$_}} = 1 if  -e $_  ;
    }
    
    warn "DEBUG: No volume managers installed \n" 
	and return if not keys %vm;
    
    return wantarray ? keys %vm : (keys %vm)[0];
    
}


#-----------------------------------------------------------------------------------------
# FUNCTION : getVolumeMetrics
#
# DESC 
# return a array of hashes for all volume manager metrics  
#
# ARGUMENTS
#
#-----------------------------------------------------------------------------------------
sub getVolumeMetrics{
    
    my @volumemetrics;
    
    for ( getVolumeManager ){
	
	my @vendorvolumes;
	
	@vendorvolumes = Monitor::Storage::getVeritasVolumes() if /VERITAS/i;	
	
	push @volumemetrics,@vendorvolumes;
    }
    
    return @volumemetrics;
    
}

#-----------------------------------------------------------------------------------------
# FUNCTION : getFilesystems
#
# DESC 
# Return a hash of hashes with filesystem information for a host
# Hash keys filesystem type and mount point
#
# ARGUMENTS
#
#-----------------------------------------------------------------------------------------
sub getFilesystems
{
    
    my %fstypelist;
    my %fsarray;
    my %count;
    my %filesystemslisted;
    
    # Use the Xopen df , as it supports the portable format
    
    # -P df information in portable format, Gives out in block size of 512 bytes
    # Build a hash of the filesystem information on keys filesystem type
    # and mount point
    # Execute command twice, bug in df leaves out some nfs file systems
    # the first time
    my @dummy = runSystemCmd("df -P -a",120);
    
    # build the mount point to fstype hash
    # df -n done after df -P , as df -P discovers all filesystems 
    # and then -n gives the complete list
    # THis is a workaround for a bug on solaris , where df -n 
    # leaves out some nfs filesystems if executed first
    if ( not keys %fstypelist ) {
	
	for my $fsdata ( runSystemCmd("df -n",120,3) ) {
	    
	    chomp $fsdata;
	    
	    $fsdata =~ s/\s+//g;
	    
	    next unless $fsdata;
	    	    
	    my ($mt,$type) = split /\s*:\s*/,$fsdata;
	    
	    $fstypelist{$mt} = $type;
	    
	}
	
    }
    

    # Execute the command for each fstype to instrument the metrics 
    for my $fstype ( keys %{$config{filesystem}{command}} ){
	
	for ( runSystemCmd($config{filesystem}{command}{$fstype},120,2) ){
	    
	    chomp;
	    
	    s/^\s+|\s+$//g;
	    
	    next unless $_;
	    
	    # Skip heading
	    # Skip all 'swap' partitions. We will collect swap information below.
	    next if /^(Filesystem|swapfile)/i;
	    
	    my %fsinfo = ();
	    
	    my @columns = split;

	    # If command used is /usr/xpg4/bin/df -P
	    if ( $config{filesystem}{command}{$fstype} =~ /df/ )
	    {
		$fsinfo{filesystem} = $columns[0];
		$fsinfo{size}       = $columns[1];
		$fsinfo{used}       = $columns[2];
		$fsinfo{free}       = $columns[3];	     
		$fsinfo{mountpoint} = $columns[5];

	    }# If command used is swap -l
	    elsif ( $config{filesystem}{command}{$fstype} =~ /swap/ ) {

		# If swap based on a file then ignore, filesystems based on local filesystems are not counted
		# Check if the swap filesystem is a special device
		# next if $columns[1] =~ /-/ ;

		$fsinfo{filesystem} = $columns[0];
		$fsinfo{size}       = $columns[3];
		$fsinfo{used}       = $columns[3];
		$fsinfo{free}       = 0;	     
		$fsinfo{mountpoint} = "/tmp";		
	    }
	    else 
	    {
		warn "DEBUG: Unrecognized command  $config{fileystem}{command}{$fstype} \n" and next;
	    }

	    # Validate the filesystem and mountpoint
	    warn "DEBUG: Filesystem / Mountpoint not available for $fstype \n" and next 
		unless	$fsinfo{filesystem} and	$fsinfo{mountpoint};	    	    

	    # Get the filesystem type for this filesystem
	    # if the command is for swap then take that to be the filesystem and not tmpfs
	    # Get it from the mountpoint to filesystem type map, else get it from the
	    # filesystem type of the command
	    if ( $fstype =~ /swap/i ) {
		$fsinfo{fstype} = $fstype; 
	    }
	    elsif ( $fstypelist{$fsinfo{mountpoint}} ){
		$fsinfo{fstype} = $fstypelist{$fsinfo{mountpoint}};
	    }
	    else {
		$fsinfo{fstype} = $fstype;
	    }
	    
	    # Skip if this filesystem has already been instrumented
	    # Skip if filesystem type is in the list of filesystems to be ignored  
	    next 
		if exists $filesystemslisted{$fsinfo{filesystem}}{$fsinfo{mountpoint}} or
		( $config{filesystem}{skipfilesystems} and 
		  $fsinfo{fstype} =~ /^($config{filesystem}{skipfilesystems})$/i
		  );
	    	    
	    # Get the bytes from blocks
	    $fsinfo{size} = $fsinfo{size} * 512;
	    $fsinfo{used} = $fsinfo{used} * 512;
	    $fsinfo{free} = $fsinfo{free} * 512;	     
	    
	    # NFS special , get nfs_server name from filesystem
	    $fsinfo{nfs_server} = (split /\s*:\s*/,$fsinfo{filesystem})[0] 
		if $fsinfo{fstype} =~ /nfs/i; 
	    
	    # Keep a count on mountpoint needed to generate a unique index
	    $count{$fsinfo{mountpoint}}++;
	    
	    # Push the instrumented metrics to the hash array
	    $fsarray{$fstypelist{$fsinfo{mountpoint}}}{"$fsinfo{mountpoint}-$count{$fsinfo{mountpoint}}"} = 
		\%fsinfo;

	    # Keep an hash of the filesytems, monutpoints instrumented
	    $filesystemslisted{$fsinfo{filesystem}}{$fsinfo{mountpoint}}=1;
	    
	    
	}
	
    }
    
    return %fsarray;
    
} 

#-----------------------------------------------------------------------------------------
# FUNCTION : getSolarisSwraid
#
# DESC
# Return an array of hashes containing information on the metadisks
# and subdisks that are managed by the Solstice Disk Suite.
#
# ARGUMENTS
#
#-----------------------------------------------------------------------------------------

sub getSolarisSwraid
{
	my @mds;
	my $md;
	my $lastmdref;
	my %diskpath;

	# Config for possible raw and block paths for metas and disks
	$diskpath{mdpath} = [ qw( /dev/md/dsk/ /dev/md/rdsk/ ) ];
	$diskpath{diskpath} = [ qw( /dev/dsk/ /dev/rdsk/) ];

	warn "DEBUG: Disksuite Software RAID not installed.\n" and return 
	    if not runSystemCmd("pkginfo SUNWmdg");
	
	for (runSystemCmd("metastat")) {
	    
	    chomp;
	    
	    # Skip Blank Lines
	    next unless $_;

	    my %mdobj;	    	    

	    # Metadisk entries start with 'd'
	    if (/^[dc]/) {
		
		my $pathtype;

		# When the metadisk starts with a 'c' is under /dev/dsk
		# Otherwise it is under /dev/md/dsk/
		if (/^c/) {
		    $pathtype  = "diskpath"; 
		} else {
		    $pathtype = "mdpath"; 
		}
		
		for my $path ( @{$diskpath{$pathtype}} ){

		    my %mdobj;
		    
		    ($md,$mdobj{configuration}) = split(/\s*:\s*/);
		    
		    $mdobj{name} = "$path$md";
		    $mdobj{type} = 'DISK'; 
		    $mdobj{vendor} = 'SUN_DISKSUITE';
		    
		    $mdobj{filetype} = getfiletype($mdobj{name});
		    $mdobj{inode} = getinode($mdobj{name});
		    
		    # Size is set to Zero for now.  The size is listed further
		    # down the output and will be recorded later.
		    $mdobj{size} = 0;
		    
		    # Block and char meta will have the same diskkey
		    $mdobj{diskkey} = $md;
		    # Assuming no partitions slice and diskkeys are the same for metas
		    $mdobj{slicekey} = $mdobj{diskkey};

		    $mdobj{key} = substr($mdobj{name},0,120).'-'.@mds;
		    
		    $lastmdref = \%mdobj;

		    push @mds,\%mdobj;

		}

		next;
	    }
	    
	    # Hot Spare Entries - not required to push it into the array as a metric
	    # ONly used to keep track of the hot spare subdisks
	    # No path or name for hot spares in disksuite
	    if (/^h/) {

		($md,$mdobj{configuration}) = split(/\s*:\s*/);

		# Hot spares do not have a path, so we just use the md name for the 'name' field
		$mdobj{name} = $md;

		$mdobj{type} = 'HOTSPARE';
		$mdobj{vendor} = 'SUN_DISKSUITE';
		$mdobj{key} = substr($md,0,120).'-'.@mds;
		$lastmdref = \%mdobj;
		# NO need to push a hot spare disk for now, keep track of it to mark 
		# subdisks used in hot spares
		# push @mds,\%mdobj;
		next;
	    }
	    
	    # The top-level entries are the metadisks and they do not have leading spaces.
	    # below the Metadisk name, entries start with one or more spaces.  We strip those here.
	    s/^\s*//;
	    
	    # The size is sometimes given twice, so I take the second one because it is larger.
	    if (/^size/i) {
		#    Size: 786432 blocks
		my ($size) = /^\D*(\d+).*$/g;

		my $bytes = $size * 512;

		# Use the $lastmdref  to refer to the metadisks to which this size pertains
		# use diskkey to get both the raw and char meta devices
		for my $diskref ( grep{ $_ if $_->{diskkey} =~ /^$lastmdref->{diskkey}$/i} @mds ){
		    $diskref->{size} = $bytes if $bytes > $diskref->{size};
		}

		next;
	    }
	    
	    # disks (subdisks) begin with 'c'
	    if (/^c/) {

		my ($disk) = /^(\w+)\s/g;

		$mdobj{name} = "/dev/rdsk/$disk";
		$mdobj{type} = 'SUBDISK';
		$mdobj{vendor} = 'SUN_DISKSUITE';
		$mdobj{filetype} = getfiletype($mdobj{name});
		$mdobj{inode} = getinode($mdobj{name});
	
		# if the parent is a not a hotspare we get the diskkey of the parent metadisk
		# Otherwise, just return the name of the hot spare
		if ( $lastmdref->{type} =~ /HOTSPARE/i ) { 
		    
		    $mdobj{configuration} = 'HOTSPARE'; 
		    $mdobj{parent} = $lastmdref->{name};	    

		} else {

		    $mdobj{parent} = $lastmdref->{diskkey};

		}

		# Each subdsk is a slice
		$mdobj{slicekey} = $mdobj{name};		
		# This is a place holder, take it to be same as diskkey
		$mdobj{diskkey} = $mdobj{name};

		$mdobj{key} = substr($mdobj{name},0,120).'-'.@mds;
		push @mds,\%mdobj;
		next;
	    }
	}
	return @mds;
}

#------------------------------------------------------------------------------------
# FUNCTION : runShowmount
#
#
# DESC
# run showmount 
#
# ARGUMENTS:
#
#------------------------------------------------------------------------------------
sub runShowmount ( $ )
{
	return runSystemCmd("showmount -a $_[0]",120);
}


1;
#-----------------------------------------------------------------
