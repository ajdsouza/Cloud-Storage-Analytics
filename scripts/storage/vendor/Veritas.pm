#
# Copyright (c) 2001, 2005, Oracle. All rights reserved.  
#
#  $Id: Veritas.pm 24-feb-2005.17:10:06 ajdsouza Exp $ 
#
#
# NAME  
#   Veritas.pm
#
# DESC 
#  Veritas Volume Manager specific subroutines to get volume information 
#
#
# FUNCTIONS
#
# get_metrics;
#
#
# NOTES
#
#
# MODIFIED  (MM/DD/YY)
# ajdsouza      02/24/05 - use vxdisk to get the os disk name
# ajdsouza      02/07/05 - qualify error messages to be loaded to rep with ERROR:
# ajdsouza      11/01/04 - change command run_vxprint to execute_vxprint
# ajdsouza      09/28/04 - add start and end to disk slices,get size for diskgroup
# ajdsouza      08/18/04 - 
# ajdsouza      08/09/04 - 
# ajdsouza      06/25/04 - storage reporting sources 
# ajdsouza      04/14/04 -
# ajdsouza      04/08/04 - storage reporting modules
# ajdsouza      04/17/02 - Changes to meet GIT requirements
#                          Added sub get_metrics
# ajdsouza      04/08/02 - Simplified the keys for diskslice, volume disks
#                          so key length < 128 (9i requirement)
#                          Append a unique counter $i to the entity name
# ajdsouza      10/01/01 - Created
#
#

package storage::vendor::Veritas;

require v5.6.1;
use strict;
use warnings;
use locale;
use File::Basename;
use File::Spec::Functions;
use File::Path;
use Data::Dumper;
$Data::Dumper::Indent = 2;

#-------------------------------------------------
# Variables in package scope
#------------------------------------------------

$storage::Register::config{vm}{veritas}{fieldchoices}{dg}{name}=[qw(name)];
$storage::Register::config{vm}{veritas}{fieldchoices}{dm}{name}=[qw(name)];
$storage::Register::config{vm}{veritas}{fieldchoices}{dm}{device}=[qw(device)];
$storage::Register::config{vm}{veritas}{fieldchoices}{dm}{size}=[qw(publen)];
$storage::Register::config{vm}{veritas}{fieldchoices}{dm}{state}=[qw(state)];
$storage::Register::config{vm}{veritas}{fieldchoices}{v}{name}=[qw(name)];
$storage::Register::config{vm}{veritas}{fieldchoices}{v}{type}=[qw(usetype utype)];
$storage::Register::config{vm}{veritas}{fieldchoices}{v}{size}=[qw(length)];
$storage::Register::config{vm}{veritas}{fieldchoices}{v}{state}=[qw(state)];
$storage::Register::config{vm}{veritas}{fieldchoices}{sd}{name}=[qw(name)];
$storage::Register::config{vm}{veritas}{fieldchoices}{sd}{mirrorname}=[qw(plex)];
$storage::Register::config{vm}{veritas}{fieldchoices}{sd}{disk}=[qw(disk)];
$storage::Register::config{vm}{veritas}{fieldchoices}{sd}{device}=[qw(device)];
$storage::Register::config{vm}{veritas}{fieldchoices}{sd}{size}=[qw(length)];
$storage::Register::config{vm}{veritas}{fieldchoices}{sd}{state}=[qw(mode)];
$storage::Register::config{vm}{veritas}{fieldchoices}{sd}{start}=[qw(diskoffs)];
$storage::Register::config{vm}{veritas}{fieldchoices}{sd}{lngth}=[qw(length)];
$storage::Register::config{vm}{veritas}{fieldchoices}{pl}{name}=[qw(name)];
$storage::Register::config{vm}{veritas}{fieldchoices}{pl}{volume}=[qw(volume)];
$storage::Register::config{vm}{veritas}{fieldchoices}{pl}{size}=[qw(length)];
$storage::Register::config{vm}{veritas}{fieldchoices}{pl}{layout}=[qw(layout)];
$storage::Register::config{vm}{veritas}{fieldchoices}{pl}{stripeconfig}=[qw(ncol/wid)];

# vxprint options for each volume entity
$storage::Register::config{vm}{veritas}{vxflag}{sd}='s';
$storage::Register::config{vm}{veritas}{vxflag}{dm}='d';
$storage::Register::config{vm}{veritas}{vxflag}{pl}='p';
$storage::Register::config{vm}{veritas}{vxflag}{v}='v';

# property lines to be parsed from vxprint -m
$storage::Register::config{vm}{veritas}{properties}{sd}='^(sd |dm_offset|dm_name|len)';
$storage::Register::config{vm}{veritas}{properties}{dm}='^(dm |da_name|device_tag|reserve|spare)';

# field choices for properties from vxprint -m
$storage::Register::config{vm}{veritas}{pchoices}{sd}{start}=
 { 1 => 'dm_offset'};
$storage::Register::config{vm}{veritas}{pchoices}{sd}{lngth}=
 { 1 => 'len' };
$storage::Register::config{vm}{veritas}{pchoices}{sd}{diskname}=
 { 1 => 'dm_name' };

$storage::Register::config{vm}{veritas}{pchoices}{dm}{device}=
 { 1 => 'da_name',
   2 => 'device_tag' };

$storage::Register::config{vm}{veritas}{pchoices}{dm}{spare}=
 { 1 => 'spare'};
$storage::Register::config{vm}{veritas}{pchoices}{dm}{reserve}=
 { 2 => 'reserve'};

#Some veritas constants
$storage::Register::config{vm}{veritas}{constants}{sectorsize}=512;

#------------------------------------------------------------------------
# static variables 
#------------------------------------------------------------------------
my %propindex;  # variables to cache the hash of properties

#------------------------------------------------------------------------
# subs defined
#------------------------------------------------------------------------
sub svvfpos;
sub svvcprop($);
sub svvrfprop($$$\%);
sub get_metrics;

#-------------------------------------------------------------------------
# FUNCTION : svvfpos
#
#
# DESC
# Returns the has of field positions in vol, dm, sd  and dg records
#
# ARGUMENTS:
#
#--------------------------------------------------------------------------
sub svvfpos
{

  my $diskgroup;

  for ( storage::Register::run_system_command("nmhs execute_vxprint -t -G -d -v -s -p -Q",120) )
  {

    chomp;

    s/^\s+|\s+$//g;

    my @cols = split;

    # Check if we are interested in this record type
    next unless $storage::Register::config{vm}{veritas}{fieldchoices}{lc $cols[0]};

    # Implies the record types have been filled in
    # so actual data starts, so skip
    last if exists $storage::Register::config{vm}{veritas}{fieldpos} 
     and $storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]};

    # Search and find the actual field position for each field
    for my $field ( keys %{$storage::Register::config{vm}{veritas}{fieldchoices}{lc $cols[0]}} )
    {
      # Search for each possible title
      for my $title( @{$storage::Register::config{vm}{veritas}{fieldchoices}{lc $cols[0]}{$field}} )
      {

        # Search position in the list of columns
        my $i =0;

        for my $val( @cols)
        {

          $storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{$field}=$i 
           and last if $title =~ /^$val$/i;          
          $i++;
        }
        
        last if exists $storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]} 
         and exists $storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{$field};
      }
    }
    
    # We have covered all the record types here
    last if $storage::Register::config{vm}{veritas}{fieldpos} and 
     keys %{$storage::Register::config{vm}{veritas}{fieldpos}} == 
      keys %{$storage::Register::config{vm}{veritas}{fieldchoices}};
  }
  
  return 1;
  
}

#-------------------------------------------------------------------------
# FUNCTION : svvcprop
#
#
# DESC
# get properties using vxprint -m option  for a type, return the 
# populated hash
#
# ARGUMENTS:
# dis_group name
#--------------------------------------------------------------------------
sub svvcprop($)
{

  my ( $disk_group) = @_;
  my $propindex_ref = \%propindex;

  for my $type ( keys %{$storage::Register::config{vm}{veritas}{pchoices}} )
  {
 
    my $type_name;

    warn "Failed in svvcprop, vxprint -m flag for $type is not found \n"
     and return
      unless $storage::Register::config{vm}{veritas}{vxflag}{$type};

    warn "Failed in svvcprop, vxprint -m properties filter for $type is not found \n"
     and return
      unless $storage::Register::config{vm}{veritas}{properties}{$type};

    my $i=0;
    my %proph =
     map { $i++; $i => $_ }
      split/\n/,
       `vxprint -g $disk_group -m -$storage::Register::config{vm}{veritas}{vxflag}{$type}`;

    for my $key1 ( sort {$a <=> $b} keys %proph )
    {
      my $val = $proph{$key1};

      chomp $val;

      $val =~ s/^\s+|\s+$//g;

      next unless $val;

      # only the properties we are interested in
      next unless $val =~
       /^$storage::Register::config{vm}{veritas}{properties}{$type}/i;

      ($type_name) = ( $val =~ /^$type\s+(.*)$/)
        and next
         if ( $val =~ /^$type /i );

      warn "Failed to get the $type name\n"
       and next
        unless $type_name;

      my ( $prop,$value) =
       ( $val =~ /^(.*)=(.*)$/ );

      $prop =~ s/^\s+|\s+$//g if $prop;
      $value =~ s/^\s+|\s+$//g if $value;

      next unless
       ( $prop and defined $value );

      # is there an error in parsing properties
      # this property for this type_name has already been read
      # before
      warn "Failed reading veritas -m properties for $type\n"
       and next
        if $propindex_ref->{$type}{$disk_group}{$type_name}{$prop};

      $propindex_ref->{$type}{$disk_group}{$type_name}{$prop}=$value;

    }

  }

  return 1;

}

#-------------------------------------------------------------------------
# FUNCTION : svvrfprop
#
#
# DESC
# read the required properties cached frmo vxprint -m
#
# ARGUMENTS:
# type
# diskgroup
# name
# ref to the metric hash
#--------------------------------------------------------------------------
sub svvrfprop($$$\%)
{

 my ( $type, $disk_group, $typename, $mhref ) = @_;

 return 1
  unless $storage::Register::config{vm}{veritas}{pchoices}{$type};

 for my $field
 (
  keys %{$storage::Register::config{vm}{veritas}{pchoices}{$type}}
 )
 {
   # only if this field is not yet instrumented
   # take it from the property hash
   next if $mhref->{$field};

   next unless
    $storage::Register::config{vm}{veritas}{pchoices}{$type}{$field}
     and ref($storage::Register::config{vm}{veritas}{pchoices}{$type}{$field}) =~ /HASH/i;

   for my $forder
   ( 
     sort { $a <=> $b }
     keys %{$storage::Register::config{vm}{veritas}{pchoices}{$type}{$field}}
   )
   {
     next unless
      $storage::Register::config{vm}{veritas}{pchoices}{$type}{$field}{$forder};

     my $pfield =
      $storage::Register::config{vm}{veritas}{pchoices}{$type}{$field}{$forder};

     $mhref->{$field} =
      $propindex{$type}{$disk_group}{$typename}{$pfield}
       and last
        if $propindex{$type}
         and $propindex{$type}{$disk_group}
          and $propindex{$type}{$disk_group}{$typename}
           and defined $propindex{$type}{$disk_group}{$typename}{$pfield};
   }

 }
  
 return 1;

}

#-------------------------------------------------------------------------
# FUNCTION : get_metrics
#
#
# DESC
# Return an array of hashes for all veritas disks, diskslices,volumes 
#
# ARGUMENTS:
#
#--------------------------------------------------------------------------
sub get_metrics
{
  my @veritasarray;
  my %nodevlist;
  
  # Get the field positions in the vxprint cli output
  ( 
   svvfpos() or 
    warn "ERROR:Failed to get the field and title positions from vxprint \n" 
    and return 
  ) 
  # We have covered all the record types here
  unless 
  (
    $storage::Register::config{vm}{veritas}{fieldpos}
     and keys %{$storage::Register::config{vm}{veritas}{fieldpos}} ==
       keys %{$storage::Register::config{vm}{veritas}{fieldchoices}}
  );
  
     # We have covered all the record types here

  warn "ERROR:Failed to read all the required field positions from veritas vxprint \n"
   and return unless
   (
      $storage::Register::config{vm}{veritas}{fieldpos}
       and keys %{$storage::Register::config{vm}{veritas}{fieldpos}} ==
        keys %{$storage::Register::config{vm}{veritas}{fieldchoices}}
   );
 

  # Check if we have got all the field positions for vxprint
  for my $rectype ( keys %{$storage::Register::config{vm}{veritas}{fieldchoices}} )
  {  
    
    for my $field ( keys %{$storage::Register::config{vm}{veritas}{fieldchoices}{$rectype}} )
    {
      
      warn "ERROR:Field $field for $rectype not found in vxprint \n" 
       and return 
        unless $storage::Register::config{vm}{veritas}{fieldpos}{$rectype} 
         and $storage::Register::config{vm}{veritas}{fieldpos}{$rectype}{$field};
      
     }
    
  }
  
  
  for ( storage::Register::run_system_command("nmhs execute_vxprint -G -t -q",120) )
  {
    
    chomp;
    
    my @cols = split;
    
    for ( @cols )
    {
      s/^\s+|\s+$//g;
    }
    
    my %disk_group;
    
    $disk_group{vendor}           = 'VERITAS';
    $disk_group{product}          = 'Volume Manager';
    $disk_group{storage_layer}    = 'VOLUME_MANAGER';
    $disk_group{entity_type}      = 'Diskgroup';
    $disk_group{sizeb}            = 0;
    
    # read the diskgroup name
    $disk_group{name} = $cols[$storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{name}]
     if $storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{name}
      and $cols[$storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{name}];

    warn "ERROR:Unable to read the name for the Veritas disk group \n" 
     and return unless $disk_group{name};

    $disk_group{key_value}      = "veritas_vm_dg_$disk_group{name}";
    
    # All entities in the volume manager that have this diskgroup belong to this diskgroup
    push @{$disk_group{child_entity_criteria}},
     {
      vendor           => 'VERITAS',
      product          => 'Volume Manager',
      disk_group       => $disk_group{name}
     };
    
    push @veritasarray, \%disk_group;
    
    # Cache the required properties for this diskgroup
    svvcprop($disk_group{name})
     or warn "Failed to cache the volume entity properties\n"
      and return;

    # Query for each flag to keep the order of fetch intact  
    # disks, volumes, subdisks, plexes
    my @veritas_records = 
     storage::Register::run_system_command("nmhs execute_vxprint -t -q -d -p -s -v  -g $disk_group{name}",120);
    
    # Loop thru the output of vxprint in the sort order, sort will sort 
    # lexical ascending by default, that works fine for this case
    # go theu rows in the order disks, plexes, subdisks, volumes
    # Require to maintain this order as plex records
  
    for (  sort {$a cmp $b} @veritas_records  )
    {
      
      chomp;    
      
      my @cols = split;
      
      for ( @cols )
      {
        s/^\s+|\s+$//g;
      }
      
      warn " Unsupported element $cols[0] \n" 
       and return 
        unless $cols[0] =~ /^(sd|v|dm|pl)$/i;
      
      # Skip layered volumes and sub disks - made up of
      # volumes in a RAID10 configuration
      
      if ( $cols[0] =~ /sd/i )
      {
        # record format
        # sd disk01-04  test-P02 disk01 960 2048  0  c4t3d16  ENA
        
        # If NODEVICE or slice from a nodev disk then skip 
        #sd c0t0d0-01    swapvol-01   c0t0d0   6285599  2095200  0         -        NDEV
        
        my %disk_slice;

        # Initialize the disk_group fields
        $disk_slice{entity_type}   = 'Sub Disk';
        $disk_slice{disk_group}   = $disk_group{name};
        $disk_slice{vendor}       = $disk_group{vendor};
        $disk_slice{product}      = $disk_group{product};
        $disk_slice{storage_layer}= $disk_group{storage_layer};
        
        #initialize numeric fields - mozart req.
        $disk_slice{sizeb}     = 0;    
        $disk_slice{sizeb}     = 
         $cols[$storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{size}] * 
          $storage::Register::config{vm}{veritas}{constants}{sectorsize} 
           if $storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{size} 
            and $cols[$storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{size}] 
             and $cols[$storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{size}] =~ /^\s*\d+\s*$/;
        
        # Get the name of the disk in the disk_group of which this is a slice
        $disk_slice{diskname}  = $cols[$storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{disk}] 
         if $cols[$storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{disk}];    

        $disk_slice{name}      = $cols[$storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{name}];
        $disk_slice{status}    = $cols[$storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{state}];
        $disk_slice{mirrorname}= $cols[$storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{mirrorname}];
        
        # Do no instrument a diskslice with NODEV status
        next 
         if $disk_slice{status} =~ /NDEV/i 
          or $nodevlist{$disk_slice{diskname}};      
        
        # get the start and end sectors for the disk slice
        $disk_slice{start}      = $cols[$storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{start}]
         if defined $cols[$storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{start}];
        $disk_slice{lngth}      = $cols[$storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{lngth}]
         if defined $cols[$storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{lngth}];


        # Read properties here for fields which may be null
        svvrfprop('sd',$disk_group{name},$disk_slice{name},%disk_slice)
         or warn "ERROR:Failed to read the properties for Volume Manager sd $disk_slice{name}\n"
          and return;

        # The end metric column is instrumented from start abd lngth
        $disk_slice{end} = $disk_slice{start} + $disk_slice{lngth}
         if defined $disk_slice{start}
          and defined $disk_slice{lngth}
           and $disk_slice{start} =~ /^\s*\d+\s*$/
            and $disk_slice{lngth} =~ /^\s*\d+\s*$/;
        
        $disk_slice{end} = $disk_slice{lngth}
         if defined $disk_slice{lngth} 
          and not $disk_slice{end};
        
        # Disks used by the subdisk
        push @{$disk_slice{child_entity_criteria}},
         {
          vendor           => 'VERITAS',
          product          => 'Volume Manager',
          entity_type => 'VM Disk', 
          disk_group => $disk_slice{disk_group}, 
          name=> $disk_slice{diskname} 
         };
        # layered volmes used by the subdisk
        push @{$disk_slice{child_entity_criteria}},
         {
          vendor           => 'VERITAS',
          product          => 'Volume Manager',
          entity_type => 'Volume', 
          disk_group => $disk_slice{disk_group}, 
          name=> $disk_slice{diskname} 
         };
        # Plex using the subdisk
        push @{$disk_slice{parent_entity_criteria}},
         {
          vendor           => 'VERITAS',
          product          => 'Volume Manager',
          entity_type => 'Plex', 
          disk_group => $disk_slice{disk_group}, 
          name=> $disk_slice{mirrorname} 
         };
        
        $disk_slice{key_value}          = "veritas_vm_sd_$disk_slice{disk_group}d_$disk_slice{name}";    
        
        push @veritasarray,\%disk_slice;
        
      }
      elsif ( $cols[0] =~ /pl/i )
      {
        
        my %plex;
        
        $plex{entity_type}  = 'Plex';
        $plex{disk_group}       = $disk_group{name};
        $plex{vendor}           = $disk_group{vendor};
        $plex{product}       = $disk_group{product};
        $plex{storage_layer}   = $disk_group{storage_layer};
        
        $plex{name}             = $cols[$storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{name}];
        $plex{volume}           = $cols[$storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{volume}];
        
        $plex{layout}           = $cols[$storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{layout}];
        $plex{stripeconfig}     = $cols[$storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{stripeconfig}];
        $plex{sizeb}          = 0;        
        $plex{sizeb}           = 
         $cols[$storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{size}] * 
          $storage::Register::config{vm}{veritas}{constants}{sectorsize} 
           if $storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{size} 
            and $cols[$storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{size}] 
             and $cols[$storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{size}] =~ /^\s*\d+\s*$/;
        
       # Read properties here for fields which may be null
       svvrfprop('pl',$disk_group{name},$plex{name},%plex)
        or warn "ERROR:Failed to read the properties for Volume Manager pl $plex{name}\n"
         and return;

        # Subdisks used by the plex
        push @{$plex{child_entity_criteria}},
        {
         vendor           => 'VERITAS',
         product          => 'Volume Manager',
         entity_type => 'Sub Disk', 
         disk_group => $plex{disk_group}, 
         mirrorname=> $plex{name} 
        };
       
        # volumes using this plex
        push @{$plex{parent_entity_criteria}},
        {  
         vendor           => 'VERITAS',
         product          => 'Volume Manager',
         entity_type => 'Volume', 
         disk_group => $plex{disk_group}, 
         name=> $plex{volume} 
        };
        
        $plex{key_value} = "veritas_vm_pl_$plex{disk_group}_$plex{name}";
        
        push @veritasarray,\%plex;
        
        # Plex information is used to map the subdisk to a volume, plex is not collected as a metric
        next;
    
      }
      elsif ( $cols[0] =~ /v/i )
      {
        
        # record format
        # v  test  - ENABLED  ACTIVE   2048     fsgen     - 
        
        my %volume;
        
        # Initialize the disk_group fields
        $volume{entity_type}  = 'Volume';
        $volume{disk_group}     = $disk_group{name};
        $volume{vendor}         = $disk_group{vendor};
        $volume{product}       = $disk_group{product};
        $volume{storage_layer}   = $disk_group{storage_layer};
    
        $volume{name}  = $cols[$storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{name}];
        $volume{key_value} = "veritas_vm_v_$volume{disk_group}_$volume{name}";
        
        #initialize numeric fields - mozart req.
        $volume{sizeb}  = 0;        
        $volume{sizeb}   = 
         $cols[$storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{size}] * 
          $storage::Register::config{vm}{veritas}{constants}{sectorsize} 
           if $storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{size} 
            and $cols[$storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{size}] 
             and $cols[$storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{size}] =~ /^\s*\d+\s*$/;
        
        $volume{utype} = $cols[$storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{type}];
        $volume{status} = $cols[$storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{state}];
        
        # Read properties here for fields which may be null
        svvrfprop('v',$disk_group{name},$volume{name},%volume)
         or warn "ERROR:Failed to read the properties for volume $volume{name}\n"
          and return;

        # plexes used by the volume
        push @{$volume{child_entity_criteria}},
        {
          vendor           => 'VERITAS',
          product          => 'Volume Manager',
          entity_type      => 'Plex', 
          disk_group       => $volume{disk_group}, 
          volume           => $volume{name} 
        };

        # layered volume, subdisks using the volume
        push @{$volume{parent_entity_criteria}},
        {
          vendor           => 'VERITAS',
          product          => 'Volume Manager',
          entity_type => 'Sub Disk', 
          disk_group => $volume{disk_group}, 
          diskname=> $volume{name} 
        };
        
        # sometimes a volume may be created without an os path
        # so push a record here before checking on the paths
        push @veritasarray,\%volume;
       
        #--------------------------------------------------------------
        # Add a record for each possible path of the volume
        #---------------------------------------------------------------
        for my $path( ( "/dev/vx/dsk/$volume{disk_group}/$volume{name}", 
            "/dev/vx/rdsk/$volume{disk_group}/$volume{name}", 
            "/dev/vx/dsk/$volume{name}", 
            "/dev/vx/rdsk/$volume{name}" ) ) 
        {
          
          # Skip if the path is not accessible
          warn "Volume $path does not exist / inaccessible \n" 
           and next unless -e $path;
          
          my %newvol = %volume;
          
          $newvol{os_identifier} = $path;
          
          push @veritasarray,\%newvol;
          
        }
        
      }
      # this id disk dm
      elsif ( $cols[0] =~ /dm/i )
      {
        
        # If NODEVICE then keep the list of disks and skip 
        # dm c0t0d0       -            -        -        -        NODEVICE
        # vxprint goes top down so disk media are listed before subdsks
        
        my %disk;
        
        # Initialize the disk_group fields
        $disk{entity_type}  = 'VM Disk';
        $disk{disk_group}       = $disk_group{name};
        $disk{vendor}           = $disk_group{vendor};
        $disk{product}       = $disk_group{product};
        $disk{storage_layer}   = $disk_group{storage_layer};
        
        #initialize numeric fields - mozart req.
        $disk{sizeb}  = 0;  
        $disk{sizeb}   = 
         $cols[$storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{size}] * 
          $storage::Register::config{vm}{veritas}{constants}{sectorsize} 
           if $storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{size} 
            and $cols[$storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{size}] 
             and $cols[$storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{size}] =~ /^\s*\d+\s*$/;
        
        #Record format
        #dm disk01       c4t3d16s2    sliced   2879     17672640 - 
        $disk{name}   = $cols[$storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{name}];
        
        # veritas can be configured to have different naming scheme for 
        # disks than c#t#d#
        # vxdisk list will give the actually device name on the OS
        for my $dsk ( storage::Register::run_system_command("nmhs execute_vxdisk $disk{name}" ) )
        { 
          chomp $dsk;  

          $dsk =~ s/\s+//; 
 
          next 
           unless $dsk =~ /^Device:/i;

          next 
           unless $dsk =~ /device:(.+)/i;

          ($disk{device}) =
           ( $dsk =~ /device:(.+)/i);

           last;
        }

        $disk{device}   = $cols[$storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{device}]
         unless $disk{device};

        $disk{status}   = $cols[$storage::Register::config{vm}{veritas}{fieldpos}{lc $cols[0]}{state}];
        
        $nodevlist{$disk{device}} = 1, $nodevlist{$disk{name}} = 1 
         and next 
          if $disk{status} =~ /NODEVICE/i ;
        
        # Read properties here for fields which may be null
        svvrfprop('dm',$disk_group{name},$disk{name},%disk)
         or warn "ERROR:Failed to read the properties for Volume Manager dm $disk{name}\n"
          and return;

        # read the configuration of the disk
        # we are interested in spare or reserved
        $disk{configuration} = 'SPARE'
         if $disk{spare}
           and $disk{spare} =~ /on/i;

        $disk{configuration} = 'RESERVED'
         if $disk{reserved}
           and $disk{reserved} =~ /on/i;
        
        $disk{os_identifier} = 
         catfile($storage::Register::config{disk_directory}{raw},$disk{device});
        
        # Subdisks using the disk
        push @{$disk{parent_entity_criteria}},
        {
         vendor          => 'VERITAS',
         product         => 'Volume Manager',
         entity_type     => 'Sub Disk', 
         disk_group      => $disk{disk_group}, 
         diskname        => $disk{name} 
        };    
        
        $disk{key_value} = "veritas_vm_dm_$disk{disk_group}_$disk{name}";

        push @veritasarray,\%disk;
        
        # Update the size of the disk group as sum of the sizes of all disks in it
        # and it belongs to a diskgroup
        $disk_group{sizeb} += $disk{sizeb}
         if $disk{sizeb}; 
        
      }      
      else
      {
        next;
      }
      
    }  
    
  }
  
  return \@veritasarray;
  
}

1;
