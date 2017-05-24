#
# Copyright  (c) 2001,2002  Oracle Corporation All rights reserved 
#
#  $Id: Linux.pm,v 1.70 2003/04/21 17:57:46 ajdsouza Exp $ 
#
#
# NAME  
#	 Linux.pm
#
# DESC 
#	Linux OS specific subroutines 
#
#
#
# FUNCTIONS
#
#
# NOTES
#
#
# MODIFIED	(MM/DD/YY)
# vswamida	04/21/02	Created	
#				
#
#
#
#

package Monitor::OS::Linux;

require v5.6.1;

use strict;
use warnings;
use Monitor::Utilities;
use Monitor::Storage;

#------------------------------------------------
# subs declared
#-----------------------------------------------
sub getVolumeManager;
sub getVolumeMetrics;
sub generateKeys(\%);
sub listlinuxdisks;
sub getLinuxSwraid;
sub getFilesystems;
sub runShowmount ($);


#-------------------------------------------------
# Variables in package scope
#------------------------------------------------

# Hash variables for holding config information
my %config;

# candidate fields for choosing unique key for disks
$config{key}{emc}="sq_serial_no";
$config{key}{hitachi}="sq_hitachi_serial";
$config{key}{symbios}="sq_vendorspecific sq_vpd_pagecode_83";
$config{key}{default}="sq_vendorspecific sq_serial_no ide_serial_no ida_unique_id cciss_unique_id";

# Order of choice from among candidates for a field
$config{fields}{vendor}=[qw(sq_vendor ide_vendor ida_vendor cciss_vendor)];
$config{fields}{product}=[qw(sq_product ide_product ida_product cciss_product)];
$config{fields}{configuration}=[qw(ida_faulttolmode cciss_faulttolmode)];
$config{fields}{storage_disk_device_id}=[qw(sq_serial_no ide_serial_no ida_unique_id cciss_unique_id)];
$config{fields}{capacity}=[qw(sq_capacity ide_capacity ida_capacity cciss_capacity)];
$config{fields}{nsectors}=[qw(ida_sectors cciss_sectors)];

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

#-------------------------------------------------
# Information about the disk drivers
#-------------------------------------------------
# These are the major number mappings
# Taken from /usr/include/linux/major.h
$config{majors}{3} = 'ide';
$config{majors}{22} = 'ide';
$config{majors}{33} = 'ide';
$config{majors}{56} = 'ide';
$config{majors}{57} = 'ide';
$config{majors}{88} = 'ide';
$config{majors}{89} = 'ide';
$config{majors}{90} = 'ide';
$config{majors}{91} = 'ide';

# Mylex raid controller
# I haven't run into one of these yet
# and it will have to be developed when 
# we see one.
$config{majors}{48} = 'dac';

$config{majors}{8} = 'sd';
$config{majors}{65} = 'sd';
$config{majors}{66} = 'sd';
$config{majors}{67} = 'sd';
$config{majors}{68} = 'sd';
$config{majors}{69} = 'sd';
$config{majors}{70} = 'sd';
$config{majors}{71} = 'sd';

$config{majors}{72} = 'ida';
$config{majors}{73} = 'ida';
$config{majors}{74} = 'ida';
$config{majors}{75} = 'ida';
$config{majors}{76} = 'ida';
$config{majors}{77} = 'ida';
$config{majors}{78} = 'ida';
$config{majors}{79} = 'ida';

$config{majors}{104} = 'ciss';
$config{majors}{105} = 'ciss';
$config{majors}{106} = 'ciss';
$config{majors}{107} = 'ciss';
$config{majors}{108} = 'ciss';
$config{majors}{109} = 'ciss';
$config{majors}{110} = 'ciss';
$config{majors}{111} = 'ciss';

### IDE Driver
# Regexp to identify disk in /proc/partitions
$config{driver}{ide}{DISK} = "hd([a-z]+)\\b";
# Regexp to identify partition
$config{driver}{ide}{PARTITION} = "hd([a-z]+)\\d+\\b";
# List of Major numbers for the driver
# C program to query disk drive
$config{driver}{ide}{diskinfocmd} = 'ideinfo';
# Important fields generated by the C program
$config{driver}{ide}{diskinfofields} = "ide_serial_no|ide_model|ide_capacity";

### SCSI Driver
#  Check scsi disk naming for sd , file sd.c
$config{driver}{sd}{DISK} = "sd([a-z]+)\\b";
$config{driver}{sd}{PARTITION} = "sd([a-z]+)\\d+\\b";
$config{driver}{sd}{diskinfocmd} = 'scsiinq';
$config{driver}{sd}{diskinfofields} = "sq_vendor|sq_product|sq_revision|sq_serial_no|sq_capacity|sq_device_type|sq_hitachi|sq_vendorspecific|sq_vpd_pagecode_83";

### Compaq Smart RAID Controller
$config{driver}{ida}{DISK} = "ida\\/c\\d+d\\d+\\b";
$config{driver}{ida}{PARTITION} = "ida\\/c\\d+d\\d+p\\d+\\b";
$config{driver}{ida}{diskinfocmd} = 'idainfo';
$config{driver}{ida}{diskinfofields} = "ida_capacity|ida_faulttolmode|ida_vendor|ida_product|ida_unique_id|ida_sectors|ida_cylinders";

### Compaq CISS Driver
$config{driver}{ciss}{DISK} = "cciss\\/c\\d+d\\d+\\b";
$config{driver}{ciss}{PARTITION} = "cciss\\/c\\d+d\\d+p\\d+\\b";
$config{driver}{ciss}{diskinfocmd} = 'ccissinfo';
$config{driver}{ciss}{diskinfofields} = "cciss_vendor|cciss_product|cciss_unique_id|cciss_capacity|cciss_sectors|cciss_cylinders|cciss_blocksize|cciss_faulttolmode";


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

#------------------------------------------------------
# Definitions for Linux Partition Types
# 
# The partition id is returned by sfdisk
#------------------------------------------------------
# Derived from fdisk source code i386_sys_types.c
my %parttype;

$parttype{"0"} = "Empty";
$parttype{"1"} = "FAT12";
$parttype{"2"} = "XENIX root";
$parttype{"3"} = "XENIX usr";
$parttype{"4"} = "FAT16 <32M";
$parttype{"5"} = "Extended";
$parttype{"6"} = "FAT16";
$parttype{"7"} = "HPFS/NTFS";
$parttype{"8"} = "AIX";
$parttype{"9"} = "AIX bootable";
$parttype{"a"} = "OS/2 Boot Manager";
$parttype{"b"} = "Win95 FAT32";
$parttype{"c"} = "Win95 FAT32 LBA";
$parttype{"e"} = "Win95 FAT16 LBA";
$parttype{"f"} = "Win95 Ext'd LBA";
$parttype{"10"} = "OPUS";
$parttype{"11"} = "Hidden FAT12";
$parttype{"12"} = "Compaq diagnostics";
$parttype{"14"} = "Hidden FAT16 <32M";
$parttype{"16"} = "Hidden FAT16";
$parttype{"17"} = "Hidden HPFS/NTFS";
$parttype{"18"} = "AST SmartSleep";
$parttype{"1b"} = "Hidden Win95 FAT32";
$parttype{"1c"} = "Hidden Win95 FAT32 LBA";
$parttype{"1e"} = "Hidden Win95 FAT16 LBA";
$parttype{"24"} = "NEC DOS";
$parttype{"39"} = "Plan 9";
$parttype{"3c"} = "PartitionMagic recovery";
$parttype{"40"} = "Venix 80286";
$parttype{"41"} = "PPC PReP Boot";
$parttype{"42"} = "SFS";
$parttype{"4d"} = "QNX4.x";
$parttype{"4e"} = "QNX4.x 2nd part";
$parttype{"4f"} = "QNX4.x 3rd part";
$parttype{"50"} = "OnTrack DM";
$parttype{"51"} = "OnTrack DM6 Aux1";
$parttype{"52"} = "CP/M";
$parttype{"53"} = "OnTrack DM6 Aux3";
$parttype{"54"} = "OnTrackDM6";
$parttype{"55"} = "EZ-Drive";
$parttype{"56"} = "Golden Bow";
$parttype{"5c"} = "Priam Edisk";
$parttype{"61"} = "SpeedStor";
$parttype{"63"} = "GNU HURD or SysV";
$parttype{"64"} = "Novell Netware 286";
$parttype{"65"} = "Novell Netware 386";
$parttype{"70"} = "DiskSecure Multi-Boot";
$parttype{"75"} = "PC/IX";
$parttype{"80"} = "Old Minix";
$parttype{"81"} = "Minix / old Linux"; 
$parttype{"82"} = "Linux swap";
$parttype{"83"} = "Linux";
$parttype{"84"} = "OS/2 hidden C: drive";
$parttype{"85"} = "Linux extended";
$parttype{"86"} = "NTFS volume set";
$parttype{"87"} = "NTFS volume set";
$parttype{"8e"} = "Linux LVM";
$parttype{"93"} = "Amoeba";
$parttype{"94"} = "Amoeba BBT";
$parttype{"9f"} = "BSD/OS";
$parttype{"a0"} = "IBM Thinkpad hibernation";
$parttype{"a5"} = "FreeBSD";
$parttype{"a6"} = "OpenBSD";
$parttype{"a7"} = "NeXTSTEP";
$parttype{"a8"} = "Darwin UFS";
$parttype{"a9"} = "NetBSD";
$parttype{"ab"} = "Darwin boot";
$parttype{"b7"} = "BSDI fs";
$parttype{"b8"} = "BSDI swap";
$parttype{"bb"} = "Boot Wizard hidden";
$parttype{"be"} = "Solaris boot";
$parttype{"c1"} = "DRDOS/sec FAT-12";
$parttype{"c4"} = "DRDOS/sec FAT-16 < 32M";
$parttype{"c6"} = "DRDOS/sec FAT-16";
$parttype{"c7"} = "Syrinx";
$parttype{"da"} = "Non-FS data";
$parttype{"db"} = "CP/M / CTOS / ...";
$parttype{"de"} = "Dell Utility";
$parttype{"df"} = "BootIt";
$parttype{"e1"} = "DOS access";
$parttype{"e3"} = "DOS";
$parttype{"e4"} = "SpeedStor";
$parttype{"eb"} = "BeOS fs";
$parttype{"ee"} = "EFI GPT";
$parttype{"ef"} = "EFI FAT-12";
$parttype{"f0"} = "Linux/PA-RISC boot";
$parttype{"f1"} = "SpeedStor";
$parttype{"f4"} = "SpeedStor";
$parttype{"f2"} = "DOS secondary";
$parttype{"fd"} = "Linux raid autodetect";
$parttype{"fe"} = "LANstep";
$parttype{"ff"} = "BBT";

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
$config{filesystem}{command}{ext2}  = "df -P -T -t ext2";
$config{filesystem}{command}{ext3}  = "df -P -T -t ext3";
$config{filesystem}{command}{reiserfs}  = "df -P -T -t reiserfs";
# The commands to execute for getting all Local filesystems
$config{filesystem}{command}{local} = "df -P -T -l";
# the local and nfs filesystems are got in two seperate calls
# to avoid nfs rpc hangs from intefering local filesystems
$config{filesystem}{command}{nfs}   = "df -P -T -t nfs";
# df shows swap filesystems only as "swap". `swapon -s` shows a list of
# filesystems that are used for swap space.
$config{filesystem}{command}{swap}  = "swapon -s";

# Filesystems to skip, need not instrument metrics for these filesystems
$config{filesystem}{skipfilesystems} = "mvfs|proc|fd|mntfs|tmpfs|cachefs|shm|cdfs|hsfs|lofs";


#-----------------------------------------------------------------------------------------
# FUNCTION : getVolumeManager
#
# DESC 
# return identifier string for the  volume manager installed
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
	         '/sbin/lvmdiskscan'=>'LVM',
	     	 '/usr/sbin/lvmdiskscan'=>'LVM'
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
	
	@vendorvolumes = lvmMetrics() if /LVM/i;	
	
	push @volumemetrics,@vendorvolumes;
    }
    
    return @volumemetrics;
    
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

            $disks{$key}->{keytype} = $_ 
                and $disks{$key}->{disk_key} = "$disks{$key}->{vendor}-$disks{$key}->{$_}"
                and last 
                if $disks{$key}->{$_};        
        }
        
        # If diskkey is still not generated then take nameinstance as disk key
        $disks{$key}->{disk_key} = "DISKKEY-$disks{$key}->{nameinstance}" 
        unless $disks{$key}->{disk_key};

    }
    
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

sub getRawDevs {

	my %rawdevs;

        #----------------------------------------------------
        # Build a hash listing of the raw devices using 'raw'
        #----------------------------------------------------

        foreach (runSystemCmd("runcmd run_raw -q -a")) {
                my ($major,$minor) = /major\s+(\d+),\s+minor\s+(\d+)/g;
                ($rawdevs{$major}{$minor}{path}) = /^(.*):/g;
        }

	return %rawdevs;
}

#-----------------------------------------------------------------------------------------
# FUNCTION : listlinuxdisks
#
# DESC 
# return array of hashes containing information about the physical disks
#
# ARGUMENTS
#
#-----------------------------------------------------------------------------------------

sub listlinuxdisks{

	my %disks;		# Hash of disks
	my %disklist;		# Hash of disks and partitions
	my %rawdisks;		# Hash of raw disks
	my %pt;			# Partition Table from sfdisk
	my @diskdevices;	# Array of hashes of disks and partitions
	my $disknameinstance;
	my @rows;

	# Values parsed from /proc/partitions
	my ( $major, $minor, $kblocks , $name);

    	# Get hash listing of the raw devices
	%rawdisks = getRawDevs();

	# Open and read /proc/partitions
	warn "WARN: Unable to open /proc/partitions." and return 
	    unless open (FILEHANDLE, "</proc/partitions");

	@rows = <FILEHANDLE>;
    	close (FILEHANDLE);
    
    	# Get rid of the first two lines (they are heading information)
   	shift @rows;
	shift @rows;

    	#--------------------------------------------------------------
    	# PARSE /proc/partitions AND BUILD LIST OF DISKS AND PARTITIONS
    	#--------------------------------------------------------------
	foreach (@rows) {

		chomp;

            	# Skip Blank Lines
            	next unless $_;

        	s/^\s+|\s+$//g;

		my %devinfo;		# Hash of disk information

		( $major, $minor, $kblocks, $name ) =  split;

		# Unknown major number, so we skip this device
		warn "DEBUG: driver $major used for disk device /dev/$name is not supported \n" and 
		    next 
		    unless $config{majors}{$major}; 

		# Common attributes for Disks and Partitions
		$devinfo{logical_name} = "/dev/$name";


		# Check if the device is a cdrom drive
		# (This does not handle systems with multiple cdrom drives -
		# I'll look into that later.)
		next if (getRootLink('/dev/cdrom') eq $devinfo{logical_name});

		$devinfo{filetype} = getfiletype($devinfo{logical_name});
		$devinfo{inode} = getinode($devinfo{logical_name});

		warn "DEBUG: Disk block size is invalid $kblocks for disk device $devinfo{logical_name} \n" and
		    $kblocks = 0
		    unless $kblocks =~ /\d+/;

		$devinfo{capacity} = $kblocks * 1024;

		my $drivername = $config{majors}{$major};

		if ($name =~ $config{driver}{$drivername}{DISK}) {
		    
		    $devinfo{type} = 'DISK';
		    $devinfo{disktype} = $drivername;
		    $disknameinstance = "$major\@$minor"; 
		    $devinfo{nameinstance} = $disknameinstance;
		    $devinfo{partition} = 0;
		    
		    #---------------------------------------------------
		    # Get the partition table from sfdisk	
		    # Store the start sector, size and type id in a hash
		    # /dev/sdd1 : start=       63, size=35551782, Id=83 
		    #---------------------------------------------------
		    foreach (runSystemCmd("runcmd run_sfdisk -d $devinfo{logical_name}")) {

			chomp;
			
			# Remove all white space
			s/\s+//g;
			
			# Skip Blank Lines
			next unless $_;
			
			# Skip Header
			next if /^unit:|^#part/;
			
			my ($pt_name, $pt_info) = /^(.*):(.*)$/g;
			foreach (split(/,/, $pt_info))
			{
			    my ($param, $value) = /(.*)=(.*)/g;
			    $pt{$pt_name}{lc($param)} = lc($value);
			}
		    }
		    
		} elsif ($name =~ $config{driver}{$drivername}{PARTITION})	{
		    
		    $devinfo{nameinstance} = $disknameinstance;
		    $devinfo{type} = 'PARTITION';
		    
		   ( $devinfo{partition} ) = ( $name =~ /.*\D(\d+)$/); # Pick the last digits to be the partition number
		    
		    warn "DEBUG: Failed to read the partition number for $devinfo{logical_name} using regexp\n" 			
			unless exists $devinfo{partition} and $devinfo{partition} =~ /\d+/;

		    # This can be used later to mark FAT32 and other unmounted disks as 'used'
		    $devinfo{partitiontype} = $parttype{$pt{$devinfo{logical_name}}{id}};
		    $devinfo{partitionstart} = $pt{$devinfo{logical_name}}{start};
		    $devinfo{nsectors} = $pt{$devinfo{logical_name}}{size};
		    
		    # if the partiton type is not 'empty', it is formatted
		    $devinfo{device_status} = $devinfo{partitiontype} =~ /empty/i ? 'UNFORMATTED' : "FORMATTED.$devinfo{partitiontype}"; 
		    
		} else {
		    
		    # The device name doesn't match either the disk or partition.
		    warn "DEBUG: Unable to match disk or partition for $name.\n" and next;
		}
		
		# Check to see if there is a related raw device and process if so
		if ($rawdisks{$major}{$minor}) {

			my %rawdevinfo = %devinfo;
			my $instance = "$major\@$minor";

			$rawdevinfo{logical_name} = $rawdisks{$major}{$minor}{path}; 
			$rawdevinfo{filetype} = getfiletype($rawdevinfo{logical_name});
			$rawdevinfo{inode} = getinode($rawdevinfo{logical_name});
			$rawdevinfo{key} = @diskdevices;

        		push @{$disklist{$rawdevinfo{nameinstance}}{$rawdevinfo{type}}}, \%rawdevinfo;
			push @diskdevices, \%rawdevinfo;

		}

		$devinfo{key} = @diskdevices;

		# Save the Disk Hashes so we can query for serial, vendor, etc. later
		$disks{$devinfo{nameinstance}} = \%devinfo if $devinfo{type} eq 'DISK';

        	# Keep an list indexed on nameinstance and type
        	push @{$disklist{$devinfo{nameinstance}}{$devinfo{type}}}, \%devinfo;

		push @diskdevices, \%devinfo;
    }

    #----------------------------------------------------
    # CALL DISKINFO PROGRAMS FOR EACH DISK
    #----------------------------------------------------
    for my $key ( keys %disks ){

	my $type = $disks{$key}->{disktype}; 

	# Go to the next disk if we don't have a diskinfo command to execute
	next unless $config{driver}{$type}{diskinfocmd};

        for ( runSystemCmd("runcmd $config{driver}{$type}{diskinfocmd} $disks{$key}->{logical_name}") ){ 

            chomp;
            
            s/^\s+|\s+$//g;
            
            # Skip the fields of no interest to us
            next unless $_ =~ /^($config{driver}{$type}{diskinfofields})/i ;        
            
            my($name,$value) = ( /^\s*(.*)::\s*(.*)/ );
        
            # Regexp is greedy, trailing nulls will be part of value
            $value =~ s/\s+$//g;                        
            
            $disks{$key}->{$name} = $value;
            
        }
      
	# Disk Technology Specific instructions 
	if ($type =~ /ide/i) {
		# The Vendor and Product are separted by a space.
		($disks{$key}->{ide_vendor},$disks{$key}->{ide_product}) = split(/ /,$disks{$key}->{ide_model});
	}
    } 

    
    #----------------------------------------------------
    # VALIDATE DATA FIELDS FOR THE DISK
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
       
    return @diskdevices;
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

sub getLinuxSwraid {

	my %procpart;
	my %rawdevs;

	my @rows;
	my @mdlist;
	my @mds;

	# Get list of raw devices
	%rawdevs = getRawDevs();

	#Open and read /proc/partitions
        warn "WARN: Unable to open /proc/partitions." and return
                if (not open (FILEHANDLE, "</proc/partitions"));
   	@rows = <FILEHANDLE>;
	close (FILEHANDLE); 

	# First two lines are heading info
	shift @rows;
	shift @rows;

	# Build a hash of names and sizes from /proc/partitions
	foreach (@rows) 
	{
		chomp;

		s/^\s+|\s+$//g;	

		my ($major,$minor,$kblocks,$name) = split;

		# Build a list of md devices
		push @mdlist,$name if $name =~ /md\d/;

		$procpart{$major}{$minor}{name} = $name;
		$procpart{$major}{$minor}{kblocks} = $kblocks;
	}

	foreach my $md (@mdlist) 
	{
		foreach (runSystemCmd("runcmd mdinfo /dev/$md"))
		{
			my %mdinfo;

			chomp;

			foreach (split(/\|/))
			{
				my ($param, $value) = /(.*)=(.*)/g;
				$mdinfo{$param} = $value;
			}

			if ($mdinfo{type} eq 'DISK')
			{
				$mdinfo{name} = "/dev/$md";
				$mdinfo{chunksize} /= 1024;
				$mdinfo{configuration} = "RAID$mdinfo{level}_$mdinfo{chunksize}kbchunks";
				$mdinfo{diskkey} = $md;
				$mdinfo{slicekey} = $md;
			}

			if ($mdinfo{type} eq 'SUBDISK')
			{
				my $diskname = $procpart{$mdinfo{major}}{$mdinfo{minor}}{name};
				$mdinfo{name} = "/dev/$diskname";
				$mdinfo{parent} = $md;
				$mdinfo{diskkey} = $diskname;
				$mdinfo{slicekey} = $diskname;
			}

			$mdinfo{vendor} = 'Linux_Software_Raid';
			$mdinfo{filetype} = getfiletype($mdinfo{name});
			$mdinfo{inode} = getinode($mdinfo{name});

			# $mdinfo{size} is not always reliable for RAID 0
			# So we overwrite it here
			$mdinfo{size} = $procpart{$mdinfo{major}}{$mdinfo{minor}}{kblocks} * 1024;

	                # Check to see if there is a related raw device and process if so
			# Only record raw devices for DISKS
                	if ($rawdevs{$mdinfo{major}}{$mdinfo{minor}} and $mdinfo{type} eq 'DISK') {
                        	my %rawmdinfo = %mdinfo;

                        	$rawmdinfo{name} = $rawdevs{$mdinfo{major}}{$mdinfo{minor}}{path};
                        	$rawmdinfo{filetype} = getfiletype($rawmdinfo{name});
                        	$rawmdinfo{inode} = getinode($rawmdinfo{name});
				$rawmdinfo{key} = substr($rawmdinfo{name},0,120).'-'.@mds;
                        	push @mds, \%rawmdinfo;
                	}

			$mdinfo{key} = substr($mdinfo{name},0,120).'-'.@mds;
			push @mds,\%mdinfo;
		}
	}
	return @mds;
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
    
    my %fsarray;
    my %count;
    my %filesystemslisted;
    
    # -P df information in portable format, Gives out in block size of 512 bytes
    # Build a hash of the filesystem information on keys filesystem type
    # and mount point
    # Execute command twice, bug in df leaves out some nfs file systems
    # the first time
    my @dummy = runSystemCmd("df -P",120);

    # Execute the command for each fstype to instrument the metrics 
    for my $fstype ( keys %{$config{filesystem}{command}} ){
        
        for ( runSystemCmd($config{filesystem}{command}{$fstype},120,2) ){
            
            chomp;
            
            s/^\s+|\s+$//g;
            
            next unless $_;
            
            # Skip heading, 'none' and 'shmfs' filesystems
            next if /^\s*Filesystem|^none|^shmfs|^Filename/i;
            
            my %fsinfo = ();
            
            my @columns = split;

            # If command used is 'df -P'
            if ( $config{filesystem}{command}{$fstype} =~ /df/ )
            {
                $fsinfo{filesystem} = $columns[0];
                $fsinfo{fstype}     = $columns[1];
                $fsinfo{size}       = $columns[2];
                $fsinfo{used}       = $columns[3];
                $fsinfo{free}       = $columns[4];             
                $fsinfo{mountpoint} = $columns[6];

            }# If command used is swapon -s
            elsif ( $config{filesystem}{command}{$fstype} =~ /swap/ ) {

                $fsinfo{filesystem} = $columns[0];
                $fsinfo{fstype}     = "swap";
                $fsinfo{size}       = $columns[2];
                $fsinfo{used}       = $columns[2];
                $fsinfo{free}       = 0;             
                $fsinfo{mountpoint} = "/tmp";                
            }
            else 
            {
                warn "DEBUG: Unrecognized command  $config{fileystem}{command}{$fstype} \n" and next;
            }

            # Validate the filesystem and mountpoint
            warn "DEBUG: Filesystem / Mountpoint not available for $fstype \n" and next 
                unless        $fsinfo{filesystem} and        $fsinfo{mountpoint};                        
            
            # Skip if this filesystem has already been instrumented
            # Skip if filesystem type is in the list of filesystems to be ignored  
            next 
                if exists $filesystemslisted{$fsinfo{filesystem}}{$fsinfo{mountpoint}} or
                ( $config{filesystem}{skipfilesystems} and 
                  $fsinfo{fstype} =~ /^($config{filesystem}{skipfilesystems})$/i
                  );
                        
            # Get the bytes from blocks
	    map {$_ *= 1024} ($fsinfo{size},$fsinfo{used},$fsinfo{free});
            
            # NFS special , get nfs_server name from filesystem
            $fsinfo{nfs_server} = (split /\s*:\s*/,$fsinfo{filesystem})[0] 
                if $fsinfo{fstype} =~ /nfs/i; 
            
            # Keep a count on mountpoint needed to generate a unique index
            $count{$fsinfo{mountpoint}}++;
            
            # Push the instrumented metrics to the hash array
            $fsarray{$fsinfo{fstype}}{"$fsinfo{mountpoint}-$count{$fsinfo{mountpoint}}"} = 
                \%fsinfo;

            # Keep an hash of the filesytems, mountpoints instrumented
            $filesystemslisted{$fsinfo{filesystem}}{$fsinfo{mountpoint}}=1;
            
        }
        
    }
    
    return %fsarray;
    
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
	return runSystemCmd("showmount -a --no-headers $_[0]");
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

        # Get list of raw devices
        %rawdevs = getRawDevs();
	
	# Get the list of volumes			
        warn "WARN: Unable to open /proc/lvm/VGs\n" and return if not opendir (PROCVGS,"/proc/lvm/VGs/");
	foreach my $vg (readdir(PROCVGS))
	{
		next if /\.|\.\./; # Skip the directory and parent entries

		chomp $vg;

		next if not opendir (PROCPVS,"/proc/lvm/VGs/$vg/PVs");
		foreach (readdir(PROCPVS))
		{
			next if /\.|\.\./; # Skip the directory and parent entries

			my %pv;
			$pv{vendor} = 'LVM';
			$pv{type} = 'DISK';
			$pv{name} = $_;
			$pv{diskgroup} = $vg;
	    		$pv{path} = "/dev/$_";

			# Get the subdisk information
	    		foreach (runSystemCmd("runcmd run_pvdisplay -v $pv{path}")) {
	
				chomp;

				s/^\s+|\s+$//g;	

            			next unless $_;

				# Skip title information and extent listings (which start with a number)
				next if /^---|^\d+/;

				# Get the Physical Extent Size
				if (/PE\s+Size/i) {
					$pv{pesize} = (split)[3];
					$pv{pesize} *= 1024;
					next;
				}

				# Get the Total PEs
				if (/Total\s+PE/i) {
					$pv{petotal} = (split)[2];
					next;
				}

				# Get the Status
				if (/PV\s+Status/i) {
					$pv{state} = uc( (split)[2] );
					next;
				}

				if (/^\/dev/) {
					my %sd; # Hash of SubDisks
					$sd{vendor} = 'LVM';
					$sd{type} = 'DISKSLICE';

   					# LV Name                   LE of LV  PE for LV
   					# /dev/vg1/lvol1            50        49
					($sd{volumename},$sd{le},$sd{pe}) = split;

					# Remove the last '/' and everything before to get vol name
					$sd{volumename} =~ s/^.*\///;

					$sd{name} = "$pv{name}_$sd{volumename}";
					$sd{diskgroup} = $vg;

					# Calculate the Subdisk size by multiplying
					# The # of physical extents by the 
					# physical extent size.
					$sd{size} = $sd{pe} * $pv{pesize};

					$sd{diskname} = $pv{name};
					$sd{state} = $pv{state};

					$sd{key} = substr($sd{name},0,120).'_'.@lvmarray;
					push @lvmarray,\%sd;
				}
			}

			$pv{size} = $pv{petotal} * $pv{pesize};
			$pv{filetype} = getfiletype($pv{path});
			$pv{inode} = getinode($pv{path});
			$pv{key} = substr($pv{name},0,120).'_'.@lvmarray;
			push @lvmarray, \%pv;
		}

		closedir (PROCPVS);

		### Get Logical Volumes
		next if not opendir (PROCLVS,"/proc/lvm/VGs/$vg/LVs");
		foreach (readdir(PROCLVS))
		{
			next if /\.|\.\./;

			my %lvinfo;
			$lvinfo{path} = "/dev/$vg/$_"; 
			next if not open (PROCLV,"</proc/lvm/VGs/$vg/LVs/$_");
			foreach (<PROCLV>) {
				chomp;
            			s/\s+//g;

				# The device field is like
				# device:	58:02
				# so I use '\w*' to match exactly 'device'
				my ($name, $value) = /(\w*):(.*)/g;

				$lvinfo{$name} = $value;
			} 
			close (PROCLV);
			
			# The device field is major:minor, i.e. 58:09
			my ($major,$minor) = split(/:/,$lvinfo{device});
			# Remove leading zeros, so we can compare with minor from 'raw'
			$minor =~ s/^0*//;

			$lvinfo{vendor} = 'LVM';
		 	$lvinfo{type} = 'VOLUME';
			$lvinfo{name} = $_;
			$lvinfo{diskgroup} = $vg;
			$lvinfo{size} *= 512;

			# LVM only supports striping and concatenation.
			# $lvinfo{stripes} is only present for striped volumes, so we can
			# assume CONCAT if $lvinfo{stripes} doesn't exist.
			# If this changes, we'll have to change this line.
			$lvinfo{config} = $lvinfo{stripes} ? "$lvinfo{stripes}stripes-$lvinfo{stripesize}kb" : 'CONCAT';

			$lvinfo{filetype} = getfiletype($lvinfo{path});
			$lvinfo{inode} = getinode($lvinfo{path});
			if ($lvinfo{status} & $lvmdefs{lvstatus}{LV_ACTIVE}) {
				$lvinfo{state} = "ACTIVE";
				$lvinfo{state} = "$lvinfo{state}_READ" 
					if ($lvinfo{access} & $lvmdefs{lvaccess}{LV_READ});
				$lvinfo{state} = "$lvinfo{state}_WRITE" 
					if ($lvinfo{access} & $lvmdefs{lvaccess}{LV_WRITE});
			} else {
				$lvinfo{state} = "NOT_ACTIVE";
			}

                        if ($rawdevs{$major}{$minor}) {
                                my %rawlvinfo = %lvinfo;

                                $rawlvinfo{path} = $rawdevs{$major}{$minor}{path};
                                $rawlvinfo{filetype} = getfiletype($rawlvinfo{path});
                                $rawlvinfo{inode} = getinode($rawlvinfo{path});
                                $rawlvinfo{key} = substr($rawlvinfo{name},0,120).'-'.@lvmarray;
                                push @lvmarray, \%rawlvinfo;
                        }

			$lvinfo{key} = substr($lvinfo{name},0,120).'_'.@lvmarray;
			push @lvmarray,\%lvinfo;
		}
		closedir (PROCLVS);
	}
	return @lvmarray;
}


1;
