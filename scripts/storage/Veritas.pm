#
# Copyright  (c) 2001,2002  Oracle Corporation All rights reserved 
#
#  $Id: Veritas.pm,v 1.63 2003/10/02 23:08:20 ajdsouza Exp $ 
#
#
# NAME  
#	 Veritas.pm
#
# DESC 
#	Veritas Volume Manager specific subroutines to get volume information 
#
#
# FUNCTIONS
#
# veritasMetrics;
# getrawvolumepath($);
#
#
# NOTES
#
#
# MODIFIED	(MM/DD/YY)
# ajdsouza	04/17/02 - Changes to meet GIT requirements
#			   Added sub veritasMetrics
# ajdsouza	04/08/02 - Simplified the keys for diskslice, volume disks
#			   so key length < 128 (9i requirement)
#			   Append a unique counter $i to the entity name
# ajdsouza	10/01/01 - Created
#
#

package Monitor::OS::Veritas;

require v5.6.1;
use strict;
use warnings;
use File::Basename;
use Monitor::Storage;
use Monitor::Utilities;

#-------------------------------------------------
# Variables in package scope
#------------------------------------------------
# Variable for holding the field positions from vxprint
my %config;

$config{fieldchoices}{dg}{name}=[qw(name)];
$config{fieldchoices}{dm}{name}=[qw(name)];
$config{fieldchoices}{dm}{device}=[qw(device)];
$config{fieldchoices}{dm}{size}=[qw(publen)];
$config{fieldchoices}{dm}{state}=[qw(state)];
$config{fieldchoices}{v}{name}=[qw(name)];
$config{fieldchoices}{v}{type}=[qw(usetype utype)];
$config{fieldchoices}{v}{size}=[qw(length)];
$config{fieldchoices}{v}{state}=[qw(state)];
$config{fieldchoices}{sd}{name}=[qw(name)];
$config{fieldchoices}{sd}{mirrorname}=[qw(plex)];
$config{fieldchoices}{sd}{disk}=[qw(disk)];
$config{fieldchoices}{sd}{device}=[qw(device)];
$config{fieldchoices}{sd}{size}=[qw(length)];
$config{fieldchoices}{sd}{state}=[qw(mode)];
$config{fieldchoices}{pl}{name}=[qw(name)];
$config{fieldchoices}{pl}{volume}=[qw(volume)];
$config{fieldchoices}{pl}{size}=[qw(length)];
$config{fieldchoices}{pl}{layout}=[qw(layout)];
$config{fieldchoices}{pl}{stripeconfig}=[qw(ncol/wid)];

$config{property}{v}{title_element_type_flag} = 'v';
$config{property}{v}{title_row} = 0;
$config{property}{v}{title_column} = 0;
$config{property}{v}{properties} = 'nvollayer|layered';

$config{property}{s}{title_element_type_flag} = 's';
$config{property}{s}{title_row} = 0;
$config{property}{s}{title_column} = 0;
$config{property}{s}{properties} = 'da_name|subvolume';

#------------------------------------------------------------------------
# subs defined
#------------------------------------------------------------------------
sub getrawvolumepath( $ );
sub veritasFieldPositions;
sub veritasMetrics;

#-------------------------------------------------------------------------
# FUNCTION : veritasFieldPositions
#
#
# DESC
# Returns the has of field positions in vol, dm, sd  and dg records
#
# ARGUMENTS:
#
#--------------------------------------------------------------------------
sub veritasFieldPositions{

    my $diskgroup;

    for ( runSystemCmd("runcmd run_vxprint -t -G -d -v -s -p -Q",120) ){
	
        chomp;
        
        s/^\s+|\s+$//g;
	
        my @cols = split;       
	
	# Check if we are interested in this record type
	next unless $config{fieldchoices}{lc $cols[0]};  

        # Implies the record types have been filled in
        # so actual data starts, so skip
        last if exists $config{fieldpos} and $config{fieldpos}{lc $cols[0]};
	
        # Search and find the actual field position for each field
        for my $field ( keys %{$config{fieldchoices}{lc $cols[0]}} ){	    
	    
	    # Search for each possible title
	    for my $title( @{$config{fieldchoices}{lc $cols[0]}{$field}} ){
		
		# Search position in the list of columns        
		my $i =0;
		for my $val( @cols){
		    
		    $config{fieldpos}{lc $cols[0]}{$field}=$i
			and last 
			if $title =~ /^$val$/i;
		    
		    $i++;
		}       
		
		last if exists $config{fieldpos}{lc $cols[0]} and 
		    exists $config{fieldpos}{lc $cols[0]}{$field};      
	    }
	}       
	
        # We have covered all the record types here
        last 
	    if $config{fieldpos} and  
	    keys %{$config{fieldpos}} == keys %{$config{fieldchoices}};
    }
    

    # Get a diskgroup to get the properties for
    for ( runSystemCmd("runcmd run_vxprint -G -t -q",120) ){
	
	chomp;
	
	$diskgroup = (split)[1];
	
	$diskgroup =~ s/^\s+|\s+$//g and last;

    }

    warn "ERROR: No diskgroup fonud for getting property titles \n" and return unless $diskgroup;

    # Get the names of the property titles for the volume elements , get the row and property numbers to look for from the config hash   
    for my $element_type ( keys %{$config{property}} ) {
	
	my @results =  runSystemCmd("runcmd run_vxprint -m -$config{property}{$element_type}{title_element_type_flag} -g $diskgroup",120);
	
	# Read the title row if it exists
	warn "ERROR: Failed to get the properites for volume element $element_type \n" and return unless @results and $results[$config{property}{$element_type}{title_row}];

	chomp ( my $title_row = $results[$config{property}{$element_type}{title_row}] );
        
        $title_row =~ s/^\s+|\s+$//g;
	
	warn "ERROR: Title row is blank for volume element $element_type \n" and return unless $title_row;
	
	# Read the title column if it exists and save it in the configuration hash
        my @cols = split /\s/, $title_row;
	
	warn "ERROR: Failed to get the property title value for volume element $element_type from $title_row \n" and return unless @cols and $cols[$config{property}{$element_type}{title_row}];
	
	$config{property_title}{$element_type} = $cols[$config{property}{$element_type}{title_column}];
	
    }    

    return 1;

}


#-------------------------------------------------------------------------
# FUNCTION : veritasMetrics
#
#
# DESC
# Return an array of hashes for all veritas disks, diskslices,volumes 
#
# ARGUMENTS:
#
#--------------------------------------------------------------------------
sub veritasMetrics{
    
    my @veritasarray;
    
    my %diskgroup;
    my %nodevlist;
    my %list;  # Look up list to get parents for sub disks
    
    ( veritasFieldPositions() or warn "ERROR: Failed to get the field and title positions from vxprint \n" and return ) unless $config{fieldpos} and $config{property_title};
    
    # Check if we have got all the field positions for vxprint
    for my $rectype ( keys %{$config{fieldchoices}} ){
	
	for my $field ( keys %{$config{fieldchoices}{$rectype}} ){
	    
	    warn "WARN: Field $rectype $field not found in vxprint \n"
		and return unless
		$config{fieldpos}{$rectype}
	    and $config{fieldpos}{$rectype}{$field};
	}
    }
    
    # Check if we have got all the property title positions
    for my $element_type ( keys %{$config{property}} ){
		    
	    warn "WARN: property title for element type $element_type not found in vxprint \n"
		and return unless
		$config{property_title} and 
		$config{property_title}{$element_type};	
    }
    

    $diskgroup{vendor} 	= 'VERITAS';
    
    for ( runSystemCmd("runcmd run_vxprint -G -t -q",120) ){
	
	chomp;
	
	$diskgroup{diskgroup} = (split)[1];
	
	$diskgroup{diskgroup} =~ s/^\s+|\s+$//g;
	
	# cache the properties for all volumes and subdisks in this diskgroup in a hash
	my %element_properties;
	
	# Get the properties for all volume and subdisk volume elements in the diskgroup and cache them in the hash
	for my $element_type_flag ( qw ( v s ) ) {
	    
	    my $element_name;
	    
	    # Execute the properties command for the volume element
	    for ( runSystemCmd("runcmd run_vxprint -m -g $diskgroup{diskgroup} -$element_type_flag") ) {
		
		chomp;
		
		s/^\s+|\s+$//;    
		
		next unless $_;
		
		# If the row is the title for the list of properties then read the title value and save it in the hash
		if ( /^$config{property_title}{$element_type_flag}/ ) {
		    
		    my @cols = split;
		    
		    warn "ERROR: Failed to get the property value for volume element $element_type_flag from $_ \n" and return unless @cols and $cols[1];
		    
		    $element_name = $cols[1] and next;		    
		}
		
		#Leave those properties which are not required	    
		next unless $_ =~ /^($config{property}{$element_type_flag}{properties})/;
		
		warn "DEBUG: Volume Element name is null in title row $_ \n" and return unless $element_name;
		
		# Save each property row in a array pointed to by the hash
		push @{$element_properties{$diskgroup{diskgroup}}{$element_type_flag}{$element_name}} ,$_;
		
	    }
	    
	}
		
	# Query for each flag to keep the order of fetch intact	
	# disks, volumes, subdisks, plexes       	    
	my @veritas_records = runSystemCmd("runcmd run_vxprint -t -q -d -p -s -v  -g $diskgroup{diskgroup}",120);
	
	# Loop thru the output of vxprint in the sort order, sort will sort lexical ascending by default, that works fine for this case
	# go theu rows in the order disks, plexes, subdisks, volumes
	# Require to maintain this order as plex records
	
	for (  sort @veritas_records  ) {
	    
	    chomp;		     
	    
	    my @cols = split;
	    
	    for ( @cols ){
		s/^\s+|\s+$//g;
	    }
	    
	    warn "WARN: Unsupported element $cols[0] \n" and return unless $cols[0] =~ /^(sd|v|dm|pl)$/i;
	    
	    # Skip layered volumes and sub disks - made up of
	    # volumes in a RAID10 configuration
	    
	    if ( $cols[0] =~ /sd/i ) {
		# record format
		# sd disk01-04  test-P02 disk01 960 2048  0  c4t3d16  ENA
		
		# If NODEVICE or slice from a nodev disk then skip 
		#sd c0t0d0-01    swapvol-01   c0t0d0   6285599  2095200  0         -        NDEV
		
		my %diskslice;
		
		# Initialize the diskgroup fields
		$diskslice{diskgroup} = $diskgroup{diskgroup};
		$diskslice{vendor}    = $diskgroup{vendor};
		
		#initialize numeric fields - mozart req.
		$diskslice{size}	= 0;    
		$diskslice{size} 	= $cols[$config{fieldpos}{lc $cols[0]}{size}] * 512 
		    if 
		    $config{fieldpos}{lc $cols[0]}{size} and
		    $cols[$config{fieldpos}{lc $cols[0]}{size}] and 
		    $cols[$config{fieldpos}{lc $cols[0]}{size}] !~ /\D/;
		
		next 
		    if $cols[$config{fieldpos}{lc $cols[0]}{state}] =~ /NDEV/i or 
		    $nodevlist{$cols[$config{fieldpos}{lc $cols[0]}{disk}]};	
		
		$diskslice{type}	 	= 'DISKSLICE';
		$diskslice{name} 		= $cols[$config{fieldpos}{lc $cols[0]}{name}];
		$diskslice{state} 		= $cols[$config{fieldpos}{lc $cols[0]}{state}];
		$diskslice{mirrorname} 	= $cols[$config{fieldpos}{lc $cols[0]}{mirrorname}];
		
		#---------------------------------------------------------------------------
		# If disk is blank and subvolume on then sub disk is layered OR
		# disk for subdisk points to the the layered volume
		# then save the layered volume to subdisk reference and skip the subdisk
		#---------------------------------------------------------------------------		 
		warn "ERROR: Failed to get the properties for disk $diskslice{name} \n" and return unless  $element_properties{$diskgroup{diskgroup}}{s}{$diskslice{name}};
		
		my @results = @{$element_properties{$diskgroup{diskgroup}}{s}{$diskslice{name}}};
		
		warn "ERROR: Failed to read the properties list for subdisk $diskslice{name} \n" and return unless @results;
		
		my $subvolume_status = getValue('subvolume',@results) or warn "DEBUG: Could not find the subvolume property for subdisk $diskslice{name}\n";
		my $da_name = getValue('da_name',@results) or warn "DEBUG: Could not find the da_name property for subdisk $diskslice{name} \n";

		push @{$list{LAYERED_SUBDISKS}{$diskslice{diskgroup}}{$cols[$config{fieldpos}{lc $cols[0]}{disk}]}},\%diskslice and
		    next 
		    if  ( 
			  $cols[$config{fieldpos}{lc $cols[0]}{device}] =~ /^-$/ and 
			  $subvolume_status and
			  $subvolume_status =~ /on/i and 
			  not $da_name
			  )
		    # Disk name not in list of disks and in list of layered volumes
		    or (
			not exists $list{DISK}{$diskslice{diskgroup}}{$cols[$config{fieldpos}{lc $cols[0]}{disk}]}       
			and $list{LAYERED_VOLUME}{$diskslice{diskgroup}}{$cols[$config{fieldpos}{lc $cols[0]}{disk}]}
			);		
		
		# Get the name of the disk in the diskgroup of which this is a slice
		$diskslice{diskname}         = $list{DISK}{$diskslice{diskgroup}}{$cols[$config{fieldpos}{lc $cols[0]}{disk}]} 
		if 
		    $cols[$config{fieldpos}{lc $cols[0]}{disk}] and 
		    $list{DISK}{$diskslice{diskgroup}}{$cols[$config{fieldpos}{lc $cols[0]}{disk}]};
		
		#-------------------------------------------------------------------------------
		# If volumename is not obtained  then
		# Keep a list of subdisk references , to update them with the volume information
		# when obtained for the plex record
		#-------------------------------------------------------------------------------
		push @{$list{SUBDISK}{$diskslice{diskgroup}}{$diskslice{mirrorname}}},\%diskslice;
		    
		# generate a unique key by appending the element number of the 
		# veritas array to the name key length < 128 chars		    
		$diskslice{key} = substr($diskslice{name},0,120).'_'.@veritasarray;
		
		push @veritasarray,\%diskslice;
		
	    }
	    elsif ( $cols[0] =~ /pl/i ) {
		
		my %plex;
		
		$plex{diskgroup} = $diskgroup{diskgroup};
		$plex{vendor} = $diskgroup{vendor};
		$plex{layout} = $cols[$config{fieldpos}{lc $cols[0]}{layout}];
		$plex{stripeconfig} = $cols[$config{fieldpos}{lc $cols[0]}{stripeconfig}];
		$plex{size}	= 0;		    
		$plex{size} 	= $cols[$config{fieldpos}{lc $cols[0]}{size}] * 512 
		    if 
		    $config{fieldpos}{lc $cols[0]}{size} and
		    $cols[$config{fieldpos}{lc $cols[0]}{size}] and 
		    $cols[$config{fieldpos}{lc $cols[0]}{size}] !~ /\D/;
		
		# Save the volume name for the plex , plex name to volume mapping
		$list{PLEX}{$diskgroup{diskgroup}}{$cols[$config{fieldpos}{lc $cols[0]}{name}]} = 
		    $cols[$config{fieldpos}{lc $cols[0]}{volume}]
		    if 
		    $cols[$config{fieldpos}{lc $cols[0]}{name}] and  
		    $cols[$config{fieldpos}{lc $cols[0]}{volume}];
		
		push @{$list{VOLUME_PLEX}{$plex{diskgroup}}{$cols[$config{fieldpos}{lc $cols[0]}{volume}]}},
		\%plex 	
		    if 
		    $cols[$config{fieldpos}{lc $cols[0]}{name}];
		
		# Plex information is used to map the subdisk to a volume, plex is not collected as a metric
		next;
		
	    }
	    elsif ( $cols[0] =~ /v/i ) {
		
		# record format
		# v  test  - ENABLED  ACTIVE   2048     fsgen     - 
		
		my %volume;
		
		# Initialize the diskgroup fields
		$volume{diskgroup} = $diskgroup{diskgroup};
		$volume{vendor} = $diskgroup{vendor};
		
		#initialize numeric fields - mozart req.
		$volume{size}	= 0;		    
		$volume{size} 	= $cols[$config{fieldpos}{lc $cols[0]}{size}] * 512 
		    if 
		    $config{fieldpos}{lc $cols[0]}{size} and
		    $cols[$config{fieldpos}{lc $cols[0]}{size}] and 
		    $cols[$config{fieldpos}{lc $cols[0]}{size}] !~ /\D/;
		
		$volume{utype} = $cols[$config{fieldpos}{lc $cols[0]}{type}];
		$volume{type}  = 'VOLUME';
		$volume{name}  = $cols[$config{fieldpos}{lc $cols[0]}{name}];
		$volume{state} = $cols[$config{fieldpos}{lc $cols[0]}{state}];
		
		#------------------------------------------------------------------
		# Update mirror information for Volumes from the volume-plex list
		#------------------------------------------------------------------					    
		
		# If there are plexes for this volume
		if ( $list{VOLUME_PLEX}{$volume{diskgroup}}{$volume{name}} ){
		    
		    # mirror counter
		    my %mirrorcount;
		    
		    # Loop thru each plex, get the count for each size,
		    # some plexes are log  plexes
		    for my $plexref ( @{$list{VOLUME_PLEX}{$volume{diskgroup}}{$volume{name}}} ){
			
			next unless $plexref->{size} and $plexref->{size} =~ /\d+/;
			
			$mirrorcount{$plexref->{size}}++;
			
		    }
		    
		    # Take layout from the largest size plex 
		    for my $plexref ( sort { $b->{size} <=> $a->{size} } 
				      @{$list{VOLUME_PLEX}{$volume{diskgroup}}{$volume{name}}} ){
			
			$volume{config} = $plexref->{layout} and last if
			    $plexref->{layout};			    
		    }
		    
		    # Take mirror count if mirror count is > 1, go top down on size
		    for my $key ( sort { $b <=> $a } keys %mirrorcount ) {
			
			$volume{config} .= " Mirrors=$mirrorcount{$key}" and last if
			    $mirrorcount{$key} > 1;
			
		    }
		    
		    # Take stripe config from largest size plex 
		    for my $plexref ( sort { $b->{size} <=> $a->{size} } 
				      @{$list{VOLUME_PLEX}{$volume{diskgroup}}{$volume{name}}} ){
			
			$volume{config} .= " Stripe=$plexref->{stripeconfig}" and last if
			    $plexref->{stripeconfig} and
			    $plexref->{stripeconfig} !~ /^-$/;			    
		    }
		    
		}
		
		
		#------------------------------------------------------------------------------------
		# LAYERED VOLUME CHECK
		#
		# Check if it is an layered volume, save value and skip, no need to push layered volume 
		# if lower layered volume
		#
		#-----------------------------------------------------------------------------------		    		    
		warn "ERROR:Failed to get the properties for volume $volume{name} \n" and return unless  $element_properties{$diskgroup{diskgroup}}{v}{$volume{name}};
		
		my @results = @{$element_properties{$diskgroup{diskgroup}}{v}{$volume{name}}};
		
		warn "ERROR: Failed to read the properties list for volume $volume{name} \n" and return unless @results;
		
		# if layered = on and nvollayer = 1 then layered volume
		my $layered = getValue('layered',@results) or warn "DEBUG: Could not find the layered property for Volume $volume{name}\n";
		my $nvollayer = getValue('nvollayer',@results) or warn "DEBUG: Could not find the nvollayer property for Volume $volume{name}\n";
		
		# If its a lower layered volume save its name in list for look up for sub disks based 
		# on layered volume skip , layered volumed need not me metered  
		$list{LAYERED_VOLUME}{$volume{diskgroup}}{$cols[$config{fieldpos}{lc $cols[0]}{name}]} = \%volume and 
		    next if 
		    $layered and $layered =~ /on/ and 
		    $nvollayer and $nvollayer == 1;
		
		$volume{config} = "$volume{config} ,LAYERED" if $nvollayer and $nvollayer > 1;
		
		#--------------------------------------------------------------
		# Add a record for each possible path of the volume
		#---------------------------------------------------------------
		for my $path( ( "/dev/vx/dsk/$volume{diskgroup}/$volume{name}", 
				"/dev/vx/rdsk/$volume{diskgroup}/$volume{name}", 
				"/dev/vx/dsk/$volume{name}", 
				"/dev/vx/rdsk/$volume{name}" ) ) {
		    
		    # Skip if the path is not accessible
		    warn "DEBUG: Volume $path does not exist / inaccessible \n" 
			and next unless -e $path;
		    
		    my %newvol = %volume;
		    
		    $newvol{path} = $path;
		    $newvol{inode} 	= getinode($newvol{path});
		    $newvol{filetype}   = getfiletype($newvol{path});
		    
		    # A reference list to update layered volume information
		    push @{$list{VOLUMES}{$newvol{diskgroup}}{$newvol{name}}},\%newvol;
		    
		    # generate a unique key by appending the element number of the 
		    # veritas array to the name
		    # key length < 128 chars
		    
		    $newvol{key} = substr($newvol{name},0,120).'_'.@veritasarray;
		    
		    push @veritasarray,\%newvol;
		    
		}
		
	    }
	    # this id disk dm
	    else {
		
		# If NODEVICE then keep the list of disks and skip 
		#dm c0t0d0       -            -        -        -        NODEVICE
		# vxprint goes top down so disk media are listed before subdsks
		
		my %disk;
		
		# Initialize the diskgroup fields
		$disk{diskgroup} = $diskgroup{diskgroup};
		$disk{vendor}    = $diskgroup{vendor};
		
		#initialize numeric fields - mozart req.
		$disk{size}	= 0;  
		$disk{size} 	= $cols[$config{fieldpos}{lc $cols[0]}{size}] * 512 
		    if 
		    $config{fieldpos}{lc $cols[0]}{size} and
		    $cols[$config{fieldpos}{lc $cols[0]}{size}] and 
		    $cols[$config{fieldpos}{lc $cols[0]}{size}] !~ /\D/;
		
		if ( $cols[$config{fieldpos}{lc $cols[0]}{state}] =~ /NODEVICE/i ){
		    $nodevlist{$cols[$config{fieldpos}{lc $cols[0]}{name}]} = 1;
		    $nodevlist{$cols[$config{fieldpos}{lc $cols[0]}{device}]} = 1;
		    next;
		}
		
		#Record format
		#dm disk01       c4t3d16s2    sliced   2879     17672640 - 
		$disk{type}  	= 'DISK';
		$disk{name} 	= $cols[$config{fieldpos}{lc $cols[0]}{device}];
		$disk{state}        = $cols[$config{fieldpos}{lc $cols[0]}{state}];
		
		# if file cant be accessed on the OS, probably configuration is stale 
		# but do not skip the record, log it in the repository as an issue, 
		# getinode will log a warning to the logfile too
		if ( $^O eq 'solaris' )	{
		    $disk{path} = "/dev/rdsk/$disk{name}";
		    $disk{fileype} = getfiletype($disk{path});
		    $disk{inode} = getinode($disk{path});
		}
		
		# Keep a hash list for lookup for slices, to figure out their parent
		# from name
		$list{DISK}{$disk{diskgroup}}{$cols[$config{fieldpos}{lc $cols[0]}{name}]}
		= $disk{name};
		    
		# generate a unique key by appending the element number of the 
		# veritas array to the name
		# key length < 128 chars
		
		$disk{key} = substr($disk{name},0,120).'_'.@veritasarray;
		
		push @veritasarray,\%disk;
		
	    }	       		
	    
	}	
	
	
	#------------------------------------------------------------------
	# Update configuration from Layered Volumes to top volumes
	#------------------------------------------------------------------	
	for my $volumename( keys %{$list{LAYERED_VOLUME}{$diskgroup{diskgroup}}} ){
	    
	    # to save the configuration of the lower volumes
	    my $configuration;
	    
	    #------------------------------------------------------------
	    # NAVIGATE TO THE TOP MOST VOLUME FOR LAYERED VOLUMES
	    #------------------------------------------------------------
	    # Move up volumes to get the top most volume in case of a layer volume situation
	    # If mirror points to a layered volume (RAID10) need to get the actual Top most Volume
	    while ( $volumename and
		    $list{LAYERED_VOLUME}{$diskgroup{diskgroup}}{$volumename} ){		    
		
		my $plexname;
		
		# Get a reference to the layered volume
		my $volref = $list{LAYERED_VOLUME}{$diskgroup{diskgroup}}{$volumename};
		
		# Save the configuration of the layered volume
		$configuration = "$configuration - $volref->{name}";
		$configuration = "$configuration, $volref->{config}" if $volref->{config};		    	
		
		# Skip if no subdisk is found that uses this layered volume
		warn "DEBUG: No sub disks using layered volume $volref->{name} from mirror $plexname \n" 
		    and last 
		    unless $list{LAYERED_SUBDISKS}{$diskgroup{diskgroup}}{$volumename};
		
		
		# Get the reference to the subdisks which use this layered volume
		for my $layeredsdref ( @{$list{LAYERED_SUBDISKS}{$diskgroup{diskgroup}}{$volumename}} ){
		    
		    # Get the plex name of the subdisk which uses the layered volume and break loop
		    $plexname = $layeredsdref->{mirrorname} and last 
			if $layeredsdref->{mirrorname};	
		    
		}
		
		# If the plex does not point to a volume then log error and break the loop
		warn " DEBUG: NO volume for plex $plexname  $diskgroup{diskgroup} \n" and last
		    unless $plexname and $list{PLEX}{$diskgroup{diskgroup}}{$plexname};	
		
		# Get the volume for this plex check and return to layered volume check
		$volumename =  $list{PLEX}{$diskgroup{diskgroup}}{$plexname};
		
	    }
	    
	    # Warn if the topmost Volume is not in the list of volumes
	    warn "DEBUG: Top volume $diskgroup{diskgroup} $volumename not in list of volumes \n" and next
		unless $list{VOLUMES}{$diskgroup{diskgroup}}{$volumename};
	    
	    # Update the configuration of the topmost volume by appending the configuration of the lower volumes
	    if ( $configuration )
	    {
		
		# Get a reference to the topmost volume
		for my $volref ( @{$list{VOLUMES}{$diskgroup{diskgroup}}{$volumename}} ){
		    
		    # Append the configuration of the lower volumes to the top most volume
		    $volref->{config} .= $configuration;      
		}
		
	    }
	    
	}
	
	#------------------------------------------------------------------
	#   GET THE VOLUME NAME FOR SUBDISKS
	#------------------------------------------------------------------
	# Go thru the list of subdisks to get the volume to which they belong
	for my $mirrorname ( keys %{$list{SUBDISK}{$diskgroup{diskgroup}}} ){
	    
	    # Skip if the mirror name for the subdisk is NOT in the list of mirrors
	    warn "DEBUG: Plex $mirrorname not found in list of plexes \n" and 
		next unless $list{PLEX}{$diskgroup{diskgroup}}{$mirrorname};
	    
	    # Save the mirror name
	    my $plexname = $mirrorname;	    
	    
	    #------------------------------------------------------------
	    # NAVIGATE TO THE TOP MOST VOLUME FOR LAYERD VOLUMES
	    #------------------------------------------------------------
	    if ( $list{LAYERED_VOLUME}{$diskgroup{diskgroup}}{$list{PLEX}{$diskgroup{diskgroup}}{$plexname}} ){
		
		# Move up volumes to get the top most volume in case of a layer volume situation
		# If mirror points to a layered volume (RAID10) need to get the actual Top most Volume
		while ( $list{PLEX}{$diskgroup{diskgroup}}{$plexname} and
			$list{LAYERED_VOLUME}{$diskgroup{diskgroup}}{$list{PLEX}{$diskgroup{diskgroup}}{$plexname}} ){
		    
		    # Get a reference to the layered volume
		    my $volref = $list{LAYERED_VOLUME}{$diskgroup{diskgroup}}{$list{PLEX}{$diskgroup{diskgroup}}{$plexname}};       		    	
		    
		    # Skip if no subdisk is found that uses this layered volume
		    warn "DEBUG: No sub disks using layered volume $volref->{name} from mirror $plexname \n" 
			and last 
			unless $list{LAYERED_SUBDISKS}{$diskgroup{diskgroup}}{$list{PLEX}{$diskgroup{diskgroup}}{$plexname}};
		    
		    # Get the reference to the subdisks which use this layered volume
		    for my $layeredsdref (
					  @{$list{LAYERED_SUBDISKS}{$diskgroup{diskgroup}}
					    {$list{PLEX}{$diskgroup{diskgroup}}{$plexname}}}){
			
			# Get the plex name of the subdisk which uses the layered volume
			$plexname = $layeredsdref->{mirrorname} and last if $layeredsdref->{mirrorname};	
			
		    }
		    
		}
		
	    }
	
	    # Get the list of subdisks which are part of this plex(name)
	    for my $sdref( @{$list{SUBDISK}{$diskgroup{diskgroup}}{$mirrorname}} ){
		
		# Update the volume name for the diskslice from the plex
		$sdref->{volumename} = $list{PLEX}{$diskgroup{diskgroup}}{$plexname} if
		    $list{PLEX}{$diskgroup{diskgroup}}{$plexname};
		
	    }
	    
	}    
	
    }

    return @veritasarray;
    
}
    
#------------------------------------------------------------------------------------
# FUNCTION : getrawvolumepath
#
#
# DESC
# Return the raw volumepath for a veritas volume given the block path
# from /dev/vx/dsk return /dev/vx/rdsk
#
# ARGUMENTS:
# volumepath
#
#------------------------------------------------------------------------------------
sub getrawvolumepath( $ ){
	 
    my ($volumepath) = @_;
	 
    warn "WARN: Volume $volumepath UNKNOWN \n" and return 'UNKNOWN' 
	if getfiletype($volumepath) !~ /BLOCK/i ;
	 
    $volumepath =~ s|/vx/dsk|/vx/rdsk|;
    
    return $volumepath;
    
}

1;
