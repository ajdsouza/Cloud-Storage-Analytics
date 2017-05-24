#
# Copyright  (c) 2001,2002  Oracle Corporation All rights reserved 
#
#  $Id: Hpux.pm,v 1.26 2003/03/12 23:42:19 ajdsouza Exp $ 
#
#
# NAME  
#	 Hpux.pm
#
# DESC 
#	HPUX OS specific subroutines 
#
#
# FUNCTIONS
#
# getVolumeManager - returns the type of volume managers installed.
# getVolumeMetrics - returns metrics on the volumes
# getHostDiskData ( $ ) - gathers vendor, model, and serial info from a disk
# listhpuxdisks - lists disk info from the system
# getFilesystems - lists filesystems
# hplvmMetrics;
#
#
# NOTES
#
#
# MODIFIED	(MM/DD/YY)
# vswamida	04/17/02 - Support Additional metrics for LVs and support PVs
# vswamida  04/16/02 - Added basic support for HPLVM LVs and VGs
# vswamida	04/08/02 - Created
#
#
#

package Monitor::OS::Hpux;

require v5.6.1;

use strict;
use warnings;
use Monitor::Utilities;

sub getVolumeManager;
sub getVolumeMetrics;
sub generateKeys( \% );
sub listhpuxdisks;
sub getFilesystems;
sub runShowmount ( $ );
sub hplvmMetrics;

#-------------------------------------------------
# Variables in package scope
#------------------------------------------------
# List of disk keys.  Keys are compared to this list to detect duplicate keys.
my %diskkeylist;

# Hash variables for holding config information
my %config;

# candidate fields for choosing unique key for disks
$config{key}{emc}="sq_serial_no deviceid";
$config{key}{hitachi}="sq_hitachi_serial deviceid";
$config{key}{symbios}="sq_vendorspecific sq_vpd_pagecode_83 deviceid";
$config{key}{default}="sq_serial_no sq_vendorspecific";

# Order of choice from among candidates for a field
$config{fields}{vendor}=[qw(sq_vendor io_vendor)];
$config{fields}{product}=[qw(sq_product io_product)];
$config{fields}{storage_disk_device_id}=[qw(sq_serial_no)];
$config{fields}{capacity}=[qw(sq_capacity)];

# order of choice only if field is null or not defined
$config{nullfields}{logical_name}=[qw(physical_name nameinstance)];

# List of fields common or slices representing disks
$config{diskfields}{DISK}=
    [qw(disk_key slice_key vendor product capacity storage_system_id 
        configuration storage_spindles storage_system_key 
        storage_disk_device_id device_status)];

### SCSI Driver
$config{driver}{sdisk}{diskinfocmd} = 'scsiinq';
$config{driver}{sdisk}{diskinfofields} = "sq_vendor|sq_product|sq_revision|sq_serial_no|sq_capacity|sq_device_type|sq_hitachi|sq_vendorspecific|sq_vpd_pagecode_83";


#--------------------------------------------------------
# Filesystem metric specific configuration
#--------------------------------------------------------
# Filesystem commands tend to hang due to rpc
# to ensure atleast ufs and vxfs are instrumented in such a case
# exceute the ufs and vxfs commands exclusively than those that may involve rpc's
# The commands to execute for getting filesystems
$config{filesystem}{command}{ufs}   = "df -P -F hfs";
$config{filesystem}{command}{vxfs}  = "df -P -F vxfs";

# Hpux_swapinfo is a custom C program
$config{filesystem}{command}{swap}  = "hpux_swapinfo";
# The commands to execute for getting all Local filesystems
$config{filesystem}{command}{local} = "df -P -l";
# the local and nfs filesystems are got in two seperate calls
# to avoid nfs rpc hangs from intefering local filesystems
$config{filesystem}{command}{nfs}   = "df -P -F nfs";

# NFS equivalent filetypes
$config{filesystem}{nfsfstypes} = "nfs3";

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

    # Hash array for {executable , VENDOR } map
    my %path;

    # Check for volume manager - Other volume managers on Linux not yet supported
    %path = (
	     '/etc/lvmtab'=>'HPLVM'
	     );
    
    foreach my $file (keys(%path))
    {
	return $path{$file} if -e $file ;
    }
	warn "DEBUG : No volume managers installed \n"
    	and return;

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

	@vendorvolumes = hplvmMetrics() if /HPLVM/i;	
	
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

	if ( $diskkeylist{$disks{$key}->{disk_key}} ) {
		my $oldkey = $diskkeylist{$disks{$key}->{disk_key}};

		warn "DEBUG: Duplicate disk_key found for $disks{$oldkey}->{logical_name} and $disks{$key}->{logical_name}\n";

		delete $diskkeylist{$disks{$key}->{disk_key}};
	
		# Get hostname for disk key
		my $hostname = runSystemCmd("hostname");
		chomp $hostname;

		# Set the disk key for the Existing Disk
		$disks{$oldkey}->{disk_key} = "$hostname-$disks{$oldkey}->{vendor}-$disks{$oldkey}->{nameinstance}";
		$diskkeylist{$disks{$oldkey}->{disk_key}} = $oldkey;

		$disks{$key}->{disk_key} = "$hostname-$disks{$key}->{vendor}-$disks{$key}->{nameinstance}";
	} 

	$diskkeylist{$disks{$key}->{disk_key}} = $key;
    }
    
}

#-----------------------------------------------------------------------------------------
# FUNCTION : listhpuxdisks
#
# DESC 
# return array of hashes containing information about the physical disks
#
# ARGUMENTS
#
#-----------------------------------------------------------------------------------------
sub listhpuxdisks{

	my %disklist;
	my %disks;
	my @diskdevices;

	my ($id, $lun);

	# -F compact, colon separated listing
	# -k read from kernel data structures
	# -C class of device to list
	my @ir = runSystemCmd('ioscan -Fk -C disk');

	foreach (@ir) {
		chomp;

		# Skip CD-ROMs
		next if /CD.*ROM/;

		my %ioscaninfo;

		($ioscaninfo{bustype},
		$ioscaninfo{cdio},
		$ioscaninfo{is_block},
		$ioscaninfo{is_char},
		$ioscaninfo{is_pseudo},
		$ioscaninfo{block_major_no},
		$ioscaninfo{char_major_no},
		$ioscaninfo{minor_no},
		$ioscaninfo{class},
		$ioscaninfo{driver},
		$ioscaninfo{hardware_path},
		$ioscaninfo{identify_bytes},
		$ioscaninfo{instance_no},
		$ioscaninfo{module_path},
		$ioscaninfo{module_name},
		$ioscaninfo{software_state},
		$ioscaninfo{hardware_type},
		$ioscaninfo{description},
		$ioscaninfo{card_instance}) = split(/:/);

		# Take the id and lun from the hardware path
		$_ = $ioscaninfo{hardware_path};
		($id,$lun) = m/(\d+)\.(\d+)$/g;

		# The ioscan description usually has the Vendor and Product information.
		$_ = $ioscaninfo{description};
		($ioscaninfo{io_vendor},$ioscaninfo{io_product}) = m/^(\S*)\s+(.*)$/;

		$ioscaninfo{block_path} = "/dev/dsk/c${ioscaninfo{card_instance}}t${id}d${lun}";
		$ioscaninfo{char_path} = "/dev/rdsk/c${ioscaninfo{card_instance}}t${id}d${lun}";

		# For disk problem on hpshow5
		# Remove for production
		next if $ioscaninfo{char_path} =~ "c1t3d0";

		for ( ($ioscaninfo{block_path}, $ioscaninfo{char_path}) ) {
			my %diskinfo = %ioscaninfo;
			$diskinfo{type} = 'DISK';
			$diskinfo{filetype} = getfiletype($_);
			$diskinfo{nameinstance} = $diskinfo{hardware_path};
			$diskinfo{logical_name} = $_;
			$diskinfo{inode} = getinode($_);
			$diskinfo{key} = @diskdevices;

			push @{$disklist{$diskinfo{nameinstance}}}, \%diskinfo;

			$disks{$diskinfo{nameinstance}} = \%diskinfo if $diskinfo{filetype} =~ /CHARACTER/;

			push @diskdevices,\%diskinfo;
		}
	}

		
	#----------------------------------------------------
	# CALL DISKINFO PROGRAMS FOR EACH DISK
	#----------------------------------------------------
	for my $key ( keys %disks ){
	
		my $type = $disks{$key}->{driver};
	
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
	
	for my $key ( keys %disks ){
		
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
		
		# Go thru each Hardware Path
		for my $ref ( @{$disklist{$key}} ) {                       
		
			# If its a different record from the disk record
			if ( $ref ne $diskref ){
		
			# Copy the common fields between disk record and current record
			for ( @{$config{diskfields}{DISK}} ) {
		
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
		
		# Generate a slicekey for each slice.  Since there are no 'slices', use the disk key
		$ref->{slice_key}  =  $diskref->{disk_key};
		
		# Generate a key based on slice_key
		# Concatenate slicekey with the array count saved earlier, max key size < 128
		$ref->{key} = substr($ref->{slice_key},0,120).'-'.$ref->{key};                 
		
		}
		
	}
	
	return @diskdevices;
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

	    $_ = $fsdata;

	    my ($mt,$fs,$type) = /^(.*)\((.*)\):(\w*)$/g;
	
	    $type = 'nfs' if $type =~ /($config{filesystem}{nfsfstypes})/;

            $fstypelist{$mt} = $type;
            
        }
        
    }
    

    # Execute the command for each fstype to instrument the metrics 
    for my $fstype ( keys %{$config{filesystem}{command}} ){

	# The following is required because df sometimes prints one entry on two lines like:
	# /dev/vg1/lvol1
	#			123345 123  13244  85%  /mnt
	my @fslist;
	# Read the entire output into one string
	my $fs = runSystemCmd($config{filesystem}{command}{$fstype},120,2);
	# Replace newlines followed by white space with one space
	$fs =~ s/\n\s+/ /g;
	@fslist = split("\n",$fs);
        
        for ( @fslist ){
            
            chomp;
            
            s/^\s+|\s+$//g;
            
            next unless $_;
            
            # Skip heading
            # Skip all 'swap' partitions. We will collect swap information below.
            next if /^(Filesystem|swapfile|TYPE|Kb)/i;
            
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

            }
            elsif ( $config{filesystem}{command}{$fstype} =~ /swap/ and $columns[0] =~ /dev/ ) {

                $fsinfo{filesystem} = $columns[0];
		# swapinfo shows sizes in Kb.  Multiply by 2 to convert to blocks.
                $fsinfo{size}       = $columns[1] * 2;
                $fsinfo{used}       = $columns[1] * 2;
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

#-----------------------------------------------------------------------------------------
# FUNCTION : hplvmMetrics
#
# DESC 
# Returns an array with Hash Tables of each LVM Volume Logical Volumes
#
# ARGUMENTS
# none
#-----------------------------------------------------------------------------------------

sub hplvmMetrics
{
    my @hplvmarray = ();

    return if (not -e "/usr/sbin/vgdisplay");

    foreach ( grep (/VG\s+Name/i,runSystemCmd("vgdisplay")) )
    {
	chomp;
	s/^\s+|\s+$//g;
	next unless $_;

    	my %vginfo;	
	($vginfo{name}) = /(\S+)$/g;
	$vginfo{vendor} = 'HPLVM';

	foreach ( runSystemCmd("vgdisplay -v $vginfo{name}") ) {
		chomp;
		next unless $_;

		if (/PV\s+Name/) {
			my %pvinfo;
			my ($name) = /(\S+)$/g;
			$pvinfo{vendor} = 'HPLVM';	
			$pvinfo{type} = 'DISK';	
			$pvinfo{name} = $name;	
			$pvinfo{diskgroup} = $vginfo{name};
			$pvinfo{path} = $name;
			foreach ( runSystemCmd("pvdisplay -v $name") ) {
				chomp;
				s/^\s+|\s+$//g;
				next unless $_;
				# Skip title information and extent listings (which start with a number)
				next if /^---|^\d+/;

				if (/PE\s+Size/i) {
					($pvinfo{pesize}) = /(\S+)$/g;
					$pvinfo{pesize} *= 1048576;
					next;
				}

				($pvinfo{petotal}) = /(\S+)$/g and next if (/Total\s+PE/i);
				($pvinfo{state}) = /(\S+)$/g and next if (/PV\s+Status/i);
				$pvinfo{state} = uc( $pvinfo{state} );
				if (/^\/dev/) {
					my %sd;
					$sd{vendor} = 'HPLVM';
					$sd{type} = 'DISKSLICE';
					($sd{volumename},$sd{le},$sd{pe}) = split;
					$sd{volumename} =~ s/^.*\///;
					$sd{name} = "$pvinfo{name}_$sd{volumename}";
					$sd{diskgroup} = $vginfo{name};
					$sd{size} = $sd{pe} * $pvinfo{pesize};
					$sd{diskname} = $pvinfo{name};
					$sd{state} = $pvinfo{state};
					$sd{key} = substr($sd{name},0,120).'_'.@hplvmarray;
					push @hplvmarray,\%sd;
				}
			}
			$pvinfo{size} = $pvinfo{petotal} * $pvinfo{pesize};
			$pvinfo{filetype} = getfiletype($pvinfo{path});
			$pvinfo{inode} = getinode($pvinfo{path});
			$pvinfo{key} = substr($pvinfo{name},0,120).'_'.@hplvmarray;
			push @hplvmarray, \%pvinfo;
		} elsif (/LV\s+Name/) {
    			my %lvinfo;
			my ($name) = /(\S+)$/g;
			$lvinfo{vendor} = 'HPLVM';	
			$lvinfo{type} = 'VOLUME';	
			$lvinfo{name} = $name;	
			$lvinfo{diskgroup} = $vginfo{name};
			$lvinfo{path} = $name;
			$lvinfo{filetype} = getfiletype($lvinfo{path});
			$lvinfo{inode} = getinode($lvinfo{path});
			foreach ( runSystemCmd("lvdisplay $name") ) {
				chomp;
				s/^\s+|\s+$//g;
				next unless $_;

				if (/LV\s+Size/i) {
					($lvinfo{size}) = /(\S+)$/g;
					$lvinfo{size} *= 1048576;
					next;
				}
				($lvinfo{stripes}) = /(\S+)$/g and next if (/Stripes/i);
				($lvinfo{stripesize}) = /(\S+)$/g and next if (/Stripe\s+Size/i);
			}
			$lvinfo{config} = $lvinfo{stripes} ? "$lvinfo{stripes}stripes-$lvinfo{stripesize}kb" : 'CONCAT';
			$lvinfo{key} = substr($lvinfo{name},0,120).'_'.@hplvmarray;
			push @hplvmarray, \%lvinfo;
		}
	}
   }

   return @hplvmarray;
}

1;
