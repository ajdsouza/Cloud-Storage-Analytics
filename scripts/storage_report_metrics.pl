#!/usr/local/bin/perl
#
# $Header: storage_report_metrics.pl 18-mar-2005.10:18:21 ajdsouza Exp $
#
# Copyright (c) 2004, 2005, Oracle. All rights reserved.  
#
# NAME
# storage_report_metrics.pl - <one-line expansion of the name>
#
# DESCRIPTION
# Collect metrics for all storage layers and build the storage layout
# analyze the storage layout
# instrument the data and keys metrics for the layout
#
# NOTES
# Things to do
#
# A hash to reach elements in the same order as they were created
#
# A key_value identifies an entity on the OS eg. DISK
# An key_value can have multiple instances on the OS eg. BLOCK AND RAW, PHYSICAL
# AND LOGICAL
# Each instance of an key_value may have one or more paths on the OS
# Two different key_values may refer to the smae physical entity eg. MULTIPATHED
# DISKS
# key_values for the same physical entity will have the same global_unique_id
# global_unique_ids are required in raw metrics only for the lower most entities
# in the storage layout , ie for DISKS the global unique id for higher level
# metrics will be generated
#
# -------------------------------------------------------------------------------
# Sequence of execution
# This should be kept up to date when changes are mode to code
#--------------------------------------------------------------------------------
#
# 1. fninit - initialization - prepare logging directories
#
# execute fngsm if the metric requested is a data metric
# 2. fngsm - generate storage metrics and cache them to file
#     2.1 fncrsm - collect raw storage metrics
#          -> @alldata
#          execute raw metric functions get the results as array to @amhrff
#          2.1.1 fnvrawd  - validate the raw data
#                @amhrff -> @amhrff
#
#          2.1.2 fnprawd - prepare the raw dtaa for further processing
#                @amhrff -> @amhrff
#                strip leading/trailing blanks
#                append storage layer to key_value, parent_key_value
#                append storage_layer to parent/child key criteria     
#                remove trailing/leading spaces in data
#                 append storage_layer to kv, pkv
#
#          push the data in @amhrff to @alldata
#
#     2.2 fndrmtf - dump raw metrics to file on disk
#         @allldata ->
#         dump the raw data to a file on disk
#
#     2.3 fnblds - build quick look up data structures
#         @alldata -> %storage_data
#         build the kv index %iekv
#         If a parent key_valus is defined push it to the %iekv index as
#          {$iekv{kv}}->{pkvs}{parent_key_value}=1
#         if the child/parent key criteria are defined push it to the %iekv
#          index as @{$iekv{kv}->{parent_key_criteria}}
#         for entities with os_identifier build the %ieosp index
#          %isosp{key_value}{kv}{osid}=%iekv{kv}
#          %ieosp{os_identifier}{osid}{kv} = %iekv{kv}
#         build the list %storage_data{data} add entities in %iekv
#
#     2.4 fnpcsm - process the collected storage metrics
#         @alldata , %storage_data -> %storage_data
#
#          2.4.1 fnmpcrcr - mark parent keys based on parent|child key defined
#                          defined for the record
#                @alldata -> @alldata
#
#                get the parent based on parent/child key criteria
#                add kv of the parent entity to child node 
#                {$iekv{kv}}->{pkvs}{parent_key_value}=1
#
#         2.4.2  fnmpcros - generate parent child relationship between os visible
#                          entities in different storage_layers
#                lookup the index %ieosp{os_identifier} to get the os_identifiers 
#                 and the key_values
#                build the look up lists 
#                 list of os_identifiers for a key_value @{%iekv{kv}->{ospid}}
#                 list of kvs for a ospid %ieosp{ospid}{ospid}{kv}=1
#                instrument the alias metrics in structure %storage_data{alias}
#                 the alias metric maps os path to osid
#                if a osid has kvs in different storage layers 
#                 refer $config{slh} to identify the parent entity and child entity
#                if a osid has kvs in the same storage layers
#                 refer $config{seh} to identify the parent and child entity
#                push the kv of the parent as to 
#                 {$iekv{kv}}->{pkvs}{parent_key_value}=1
#
#         2.4.3  fncabk  - collate and build the key_value, parent_key_value list
#                for each kv in %iekv 
#                 look up the %iekv{kv}->{pkvs} hash structure
#                   keep track of child kv in %iekv{kv}->{cnlist}{ckv}=1
#                   keep track of parent kv in %iekv{kv}->{pnlist}{pkv}=1
#
#
#         identify the top nodes %tpnds - nodes with no parents no keys 
#          %iekv{kv}->{pnlist} == 0
#         identify the bottom nodes %btmnds- nodes with no children keys 
#          %iekv{kv}->{cnlist} == 0
#         traverse tree depth first post order and compute guid for each entity 
#          - function fnnpguid
#         traverse tree depth first post order and mark container entities 
#          - dnnpmce
#         traverse tree depth first post order and mark virtual entities 
#          - dnnpmve
#         traverse tree depth first post order and mark unallocated entities 
#          - dnnpmue
#         traverse tree depth first post order and generate query flag for 
#          entities - dnnpgqf
#         traverse tree breadth first and cimpute size for entities - dnnpcsz
#         traverse tree depth first post order and compute free size for 
#          entities - dnnpcfsz
#         traverse tree depth first post order and compute raw size for 
#          entities - dnnpcrsz
#
#     2.5 fncfcsi - check for consistency issues in processed data
#         %storage_data ->
#
#     2.6 fngkvpkm - instrument the keys metrics ( key_value, parent_key_value)
#                    from the %iekv{kv}->{pkvs} hash structure
#         %storage_data->%storage_data
#
#         build the list %storage_data{keys} for each parent_key_value in %iekv
#        , the %iekv{kv}->{pkvs} hash gives the pkv for each kv,
#         ensure that  parent child relation is instrumented only once in the key
#          using index %icpkh as %icpkh{kv}{pkv}=1
#         for nodes with no pkv add an entry to %storage_data{keys} with kv as
#         pkv
#
#     2.7 fncsmtf - cache all the metrics (data, keys, alias, issues) to files 
#                   on disk
#         %storage_data ->
#
#
# 3. fndsmff - display the data for the requested metric from the cached 
#              file on disk
#    'metric_name'->
#
#
# check for error messages and log them as em_warnings
#
# 4. restore_stderr
#
# b)  N'ary tree traversal routines
#    fntrdf    - traverse nary tree depth first pre|post order with closed loop
#                 check and closed loop opening
#
#                c) fnbrclp   - open closed loop by breaking the relationship 
#                   between the current  node and the last node on the stack
#                   \%current_node , $traverse_tag, \%traverse_stack
#
#                   get the last node in the stack, the last node will have the 
#                    max index value in the stack traversal hash array
#                   break the closed loop
#                    clean up of the current node from the traverse lists of
#                     last node in the traverse stack
#                   delete the previous node in the stack from the opposite 
#                    traverse list of the current node
#                   remove the node and the last node in the stack from each 
#                    others {pkvs} lists
#
# c) fntrdfpo  - traverse nary tree depth first post order
#    invoke fntrdf with 'postorder' flag.
# d) fntrdfpr  - traverse nary tree depth first pre order
#    invoke fntrdf with 'preorder' flag.
# e) fntrbf    - traverse nary tree breadth first pre order
#
#
# -------------------------------------------------------------------------------
#
#    MODIFIED   (MM/DD/YY)
#    ajdsouza    03/15/05 - bug fix for 3848194
#                            no repeat child gids in parent gid
#                            no cyclic parent child relationship between
#                             immediate entities
#                            add function to eliminate closed loops
#                           document sequence of execution
#    ajdsouza    03/03/05 - fix the unallocated bug for entities with only
#                           virtual parents
#    ajdsouza    02/16/05 - fix bug related to null gid for disk solstice
#                           entities
#    ajdsouza    02/02/05 - group query flag functions
#    ajdsouza    12/16/04 - Use only alloted partitions for disks
#    ajdsouza    11/16/04 -
#    ajdsouza    11/11/04 -
#    ajdsouza    09/28/04 - Add validation of raw data, veritas bug fixes
#    ajdsouza    09/07/04 -
#    ajdsouza    08/13/04 -
#    ajdsouza    08/03/04 - Fixed bug with nfs_server
#    ajdsouza    07/27/04 -
#    ajdsouza    07/19/04 - Use the agentstatedir for caching, pretty
#                           indentation
#    ajdsouza    07/14/04 - Fix closed loop for cached filesystems
#    ajdsouza    06/29/04 - Bug fix on line 113
#    ajdsouza    06/25/04 - storage reporting sources
#    ajdsouza    06/21/04 - Creation
#

use strict;
use warnings;
use File::Spec::Functions;
use File::Basename;
use File::Path;
use Data::Dumper;
use storage::Register; # This will ensure locale is set before execution begins
# In case of failure in compiling the storage modules, perl will end the script
# chances fo script executing in the locale provided by the OS env variables is
# reduced
use locale;
require "emd_common.pl";

$Data::Dumper::Indent = 2;

my %config;
my $smddr;
my %stgcls;

# Keep the keys continuous and starting with 1, this count is used to eliminate
# the last | and insert the first em_result=
$stgcls{data} = 
 { 
   1=>'key_value', 
   2=>'global_unique_id', 
   3=>'name',
   4=>'storage_layer', 
   5=>'em_query_flag', 
   6=>'entity_type', 
   7=>'rawsizeb', 
   8=>'sizeb', 
   9=>'usedb', 
   10=>'freeb', 
   11=>'a1', 
   12=>'a2', 
   13=>'a3', 
   14=>'a4', 
   15=>'a5', 
   16=>'a6', 
   17=>'a7',
   18=>'a8' 
 };

$stgcls{keys} = 
 { 
   1=>'key_value', 
   2=>'parent_key_value' 
 };

$stgcls{issues} = 
 { 
   1=>'type', 
   2=>'message_counter', 
   3=>'message_nls_id', 
   4=>'message_params', 
   5=>'action_nls_id', 
   6=>'action_params' 
 };

$stgcls{alias} = 
 { 
   1=>'key_value', 
   2=>'value' ,
   3=>'filetype' 
 };

my %mcpf = 
 (
   key_value => '%25s', 
   storage_layer => '%18s', 
   entity_type => '%18s', 
   rawsizeb => '%15u', 
   sizeb => '%15u', 
   usedb => '%15u',
   freeb => '%15u',
   global_unique_id => '%30s',
   name => '%20s',
   parent_key_value => '%25s',
   os_identifier => '%20s',
   filetype => '%10s',
   start => '%7s',
   end => '%7s'
 );

$config{slh} = 
 {
   LOCAL_FILESYSTEM => 4,
   NFS=> 3,
   VOLUME_MANAGER => 2,
   OS_DISK => 1
 };

$config{seh}{LOCAL_FILESYSTEM} = 
 {
# file and directory are at the same level, they should reside on mountpoint
   File => 2,
   Directory => 2,
   Mountpoint => 1
 };

$config{seh}{NFS} = 
 {
# file and directory are at the same level, they should reside on mountpoint
   File => 2,
   Directory => 2,
   Mountpoint => 1
 };

my %scm;

# Add a os strign later on
$scm{OS_DISK} = 
 {
   a1 => 'vendor',
   a2 => 'product',
   a3 => 'os_identifier',
   a4 => 'filetype'
 };

$scm{VOLUME_MANAGER} = 
 {
   a1 => 'vendor',
   a2 => 'product',
   a3 => 'os_identifier',
   a4 => 'disk_group',
   a5 => 'configuration',
   a6 => 'filetype'
 };

$scm{LOCAL_FILESYSTEM} = 
 {
   a1 => 'filesystem_type',
   a2 => 'filesystem',
   a3 => 'mountpoint'
 };

$scm{NFS} = 
 {
   a1 => 'vendor',
   a2 => 'nfs_server',
   a3 => 'filesystem',
   a4 => 'mountpoint',
   a5 => 'nfs_server_ip_address',
   a6 => 'nfs_mount_privilege',
   a7 => 'nfs_server_net_interface_address',
   a8 => 'nfs_exported_filesystem'
 };

# Validation
my %vcflds;    # common layer specific validation 
my %vsflds;    # storage field validation
my %veflds;    # entity type specific validation

# common fields to be validated
%vcflds = 
 ( 
  storage_layer=>'[\S]+', 
  entity_type=>'[\S]+', 
  name=>'[\S]+', 
  key_value=>'[\S]+', 
  sizeb => '^\d+$'
 );

# os_disk specific fields to be validated
$vsflds{os_disk} = 
 { 
   disk_key=>'[\S]+'
 };

# disk entity type specific fields to be validated
$veflds{os_disk}{disk}= 
 {
   global_unique_id=>'[\S]+'
 };

# partition entity type specific fields to be validated
$veflds{os_disk}{'disk partition'}= 
 {
   start=>'[\S]+',
   end=>'[\S]+'
 };

# volume manager specific fields to be validated
$vsflds{volume_manager} = 
 { 
   vendor=>'[\S]+'
 };

# subdisk entity type specific fields to be validated
$veflds{volume_manager}{'sub disk'}= 
 {
   start=>'[\S]+'
 };

$veflds{volume_manager}{'physical entity'}= 
 {
   start=>'[\S]+'
 };

# local_filesystem specific fields to be validated
$vsflds{local_filesystem} = 
 { 
   filesystem=>'[\S]+'
 };

$veflds{local_filesystem}{mountpoint}= 
 {
   mountpoint=>'[\S]+'
 };

# nfs specific fields to be validated
$vsflds{nfs} = 
 { 
   filesystem=>'[\S]+',
   nfs_server=>'[\S]+'
 };

$veflds{nfs}{filesystem}= 
 {
   mountpoint=>'[\S]+',
   global_unique_id=>'[\S]+'
 };

# Rules for counting size and raw size
my %rfcsz;
my %rfcrsz;

# rules for adding size to get used for the storage entity lower in the layout
$rfcsz{volume_manager}{diskgroup}{volume_manager}{'vm disk'}='INCLUDE';
$rfcsz{volume_manager}{'volume group'}{volume_manager}{'physical volume'}='INCLUDE';
$rfcsz{volume_manager}{'diskset'}{volume_manager}{'device'}='INCLUDE';

# rules for adding raw to get rawsize for the storage entity higher in the layout
$rfcrsz{volume_manager}{diskgroup}{volume_manager}{'vm disk'}='INCLUDE';
$rfcrsz{volume_manager}{'volume group'}{volume_manager}{'physical volume'}='INCLUDE';
$rfcrsz{volume_manager}{'diskset'}{volume_manager}{'device'}='INCLUDE';

#List of container entities
$config{container}{volume_manager}{'diskgroup'}=1;
$config{container}{volume_manager}{'volume group'}=1;
$config{container}{volume_manager}{'diskset'}=1;

# list of names for spares
$config{backup_entities} = 'hot\s*spare|spare|backup|stand\s*by|reserve';

# configuration for identifying virtual devices 
# virtual devices are present to complete the storage topology, but are 
# not used in storage calculations

# child/parent associations where parent has no explicit boundry on the child
$config{is_p_excl_boundry_on_child}{LOCAL_FILESYSTEM}{mountpoint}{LOCAL_FILESYSTEM}{directory}='N';
$config{is_p_excl_boundry_on_child}{NFS}{mountpoint}{LOCAL_FILESYSTEM}{directory}='N';
$config{is_p_excl_boundry_on_child}{NFS}{mountpoint}{NFS}{directory}='N';
# child/parent associations where size of parent is by default factored into the
# size/used of the child
$config{is_parent_size_in_child}{LOCAL_FILESYSTEM}{mountpoint}{LOCAL_FILESYSTEM}{file}='Y';
$config{is_parent_size_in_child}{NFS}{mountpoint}{LOCAL_FILESYSTEM}{file}='Y';
$config{is_parent_size_in_child}{NFS}{mountpoint}{NFS}{file}='Y';

# entities where unallocated entities can be considered to be virtual
$config{virtual_entity}{OS_DISK}{'disk partition'}=1;
$config{virtual_entity}{VOLUME_MANAGER}{volume_partition}=1;

# entities which can have partial free space
$config{can_have_partial_free_space}{OS_DISK}{disk}=1;
$config{can_have_partial_free_space}{VOLUME_MANAGER}{'vm disk'}=1;
$config{can_have_partial_free_space}{VOLUME_MANAGER}{'physical volume'}=1;
$config{can_have_partial_free_space}{VOLUME_MANAGER}{'device'}=1;

# child and parent node tags
# oppsite tags
$config{optg}{cnlst}='pnlst';
$config{optg}{pnlst}='cnlst';


# Variables for keeping look up indexes
my %iekv;      # index all storage entities on key vale
my %iguid;     # index entities on global uid
my %ieosp;     # index entities with os_identifer
my %tpnds;     # list of top nodes
my %btmnds;    # list of bottom nodes
my %indnthsh;  # has to keep track of indentation while printing the tree

#-----------------------------------------------------------------------------------------------------------
# Declare subs
#-----------------------------------------------------------------------------------------------------------
sub fninit ( );       # initialization - prepare logging directories
sub fndrmtf ( $\@ );  # dump the raw collected metrics to a file on disk
sub fnprnd ( $ );     # print node data
sub fnnpprnd ( $$$ ); # print node during traversal
sub fnnpgguid ( $$ ); # generate guid for entity during traversal
sub fnnpmce( $ );     # mark container entities
sub fnnpmue( $ );     # mark unalocated entities
sub fnnpmve( $ );     # mark virtual entities
sub fnnpmse( $ );     # mark spare entities
sub fnnpmbe( $ );     # mark botton entities
sub fnnpmte( $ );     # mark top entities
sub fnnpgqf( $ );     # generate query flag for entity
sub fnnpcsz ( \% );   # populate size for entity
sub fnnpcfsz ( $ );   # calculate free size for entity
sub fnnpcrsz ( $ );   # calculate raw size for entity
sub fntrdf( $$$\&;\% );# traverse nary tree depth first in order
sub fntrdfpo ( $$\&;\% ); # traverse nary tree depth first post order
sub fntrdfpr ( $$\&;\% ); # traverse nary tree depth first pre order
sub fntrbf ( \%$\& ); # traverse tree breadth first
sub fnvrawd ( \@ );   # validate raw data
sub fnprawd ( \@ );   # prepare the raw data for processing processing
sub fnmpcrcr( \@ );     # mark parent key values based on key criteria
sub fnmpcros( \% );     # generate parent child rel for entities with os_identifier
sub fnbrclp( \%$\% );    # check for closed loops
sub fncabk( \% );     # collate and build parent keys for all entities
sub fncrsm( \@ );     # collect the raw storage metrics
sub fnblds( \@\% );   # build look up data structures for collected metrics
sub fnpcsm( \@\% );     # process the collected metrics
sub fncfcsi ( \% );   # check for consistency issues
sub fngkvpkm( \% );   # instrument the keys metrics ( key_value, parent_key_value)
sub fncsmtf( \% );    # cache the processed metrics to file on disk
sub fngsm ( );        # generate storage metrics
sub fndsmff( $ );     # display processed metrics from file
sub restore_stderr();
sub exit_fail();

#----------------------------------------------------------------------------
# SIGNAL handler for die and warn to Log error and warning messages
#----------------------------------------------------------------------------
# die will exit the program with a warn message
sub handle_error 
{ 
   my ( $message ) = @_; 
   my $mtype;

   chomp $message; 

   $message =~ s/^\s+|\s+$// 
    if $message;

   return unless $message;

   # log the message to the log file
   EMD_PERL_WARN("STORAGE_REPORTS:$message"); 

   # should the message be loaded to the repository
   return 1 
    unless $message =~ /^ERROR\s*:/i;

   # log only errors to the em respository, ignore debug and trace messages
   ( $mtype, $message ) = ( $message =~ /^(ERROR)\s*:\s*(.+)/i )
     if $message =~ /^ERROR\s*:/i;

   $message =~ s/^\s+|\s+$// 
    if $message;

   # nmhs has :: between error and message , so remove the extra :
   $message =~ s/^:+// 
    if $message;

   storage::Register::log_error_message($message)
    if $mtype
     and $mtype =~ /ERROR/i
      and $message;

   return 1;

}

$SIG{'__DIE__'} = sub {  handle_error( @_ ); exit_fail() };
$SIG{'__WARN__'} = sub { handle_error( @_)};


#--------------------------------------------------------------------------------
# FUNCTION : fninit
#
# DESC 
# Perform the initialization steps
# Prepare the directory for logging
#
# ARGUMENTS
#
#--------------------------------------------------------------------------------
sub fninit ( )
{

  # Directory for creating the nmhs<metric>.txt files
  # diractory pattern emagent_state/storage/<target_name>
  $smddr = get_agentstatetarget_dir() 
   or warn "ERROR:Failed to get target name directory to cache metrics for target on host \n"
    and return;

  # Save the STDERR before redirecting it to logfile
  open(OLDERR,">&STDERR");

  # If there is an error opening a log file, redirect stderr to null
  #open(STDERR,"> $devnull");

}
#--------------------------------------------------------------------------------
# TRAVERSAL ROUTINES
#--------------------------------------------------------------------------------

# dump the raw data to the raw file, useful for debugging
sub fndrmtf ( $\@ )
{
    
  my ( $file_name,$array_ref ) = @_;
  
  my %columns = 
   ( 
     1=>'key_value',
     2=>'storage_layer',
     3=>'entity_type',
     4=>'rawsizeb',
     5=>'sizeb',
     6=>'usedb',
     7=>'freeb',
     8=>'global_unique_id',
     9=>'name',
     10=>'parent_key_value',
     11=>'os_identifier',
     12=>'start',
     13=>'end'
   );

  my @all_rows;

  warn "Failed to dump raw data , invalid arguments\n"
   and return 
    unless ( $file_name and $array_ref );

  warn "Failed to dump raw data ,the second arg should be an array \n" 
   and return
    unless ref($array_ref) =~ /ARRAY/i;

  for my $metric_ref ( @$array_ref )
  {
  
    my $row_to_file = ''; 

    for my $order ( sort { $a <=> $b } keys %columns )
    {  
      
      my $column = $columns{$order};

      warn "print format is not defined for $column\n"
       and next
        unless $mcpf{$column};

      $row_to_file = sprintf("%s$mcpf{$column}",$row_to_file,$metric_ref->{$column})
       and next 
        if  $metric_ref->{$column};
      
      $row_to_file = sprintf("%s$mcpf{$column}",$row_to_file,0)
       and next 
        if $mcpf{$column} =~ /u/;
  
      $row_to_file = sprintf("%s$mcpf{$column}",$row_to_file,'-');
      
    }
    
    push @all_rows,$row_to_file;
  
  }
  
  my $raw_metrics_file = catfile($smddr,$file_name);
  
  stat($raw_metrics_file);
  
  open(FH,'>',$raw_metrics_file) 
   or 
    warn "Failed to open the file $raw_metrics_file to dump raw metrics while generating storage metrics\n" 
     and return;

  # Print the metric data
  for my $row ( sort @all_rows )
  {
    print FH "$row\n";
  }

  close(FH) or 
   warn "Failed to close the file $raw_metrics_file while generating metrics \n" 
    and return 1;
  
  return 1;
    
}


sub fnprnd ( $ )
{
  
  my ( $node ) = @_;
  
  my %columns = 
   ( 
     1=>'storage_layer',
     2=>'entity_type',
     3=>'name',
     4=>'key_value',
     5=>'sizeb',
     6=>'usedb',
     7=>'freeb',
     8=>'em_query_flag'
   );
  my %prefix = ( sizeb=>'(s', usedb=>'u', freeb=>'f');
  my %suffix = ();
  
  for my $order ( sort { $a <=> $b } keys %columns ) 
  {  
  
    my $column = $columns{$order};

    next unless defined $node->{$column};
    
    print " $prefix{$column}$node->{$column}$suffix{$column}" 
     and next if $prefix{$column} 
      and $suffix{$column};  
    
    print " $prefix{$column}$node->{$column}" 
     and next if $prefix{$column};  

    print " $node->{$column}$suffix{$column}" 
     and next if $suffix{$column};  

    print " $node->{$column}";  
  }

  print " ) ";

}

# print the node as part of the storage layout tree
# with indentation
sub fnnpprnd ( $$$ )
{

  my ($node, $tvtag , $stack_ref) = @_;

  warn "Storage entity passed for generating global unique id is not a reference\n"
   and return
    unless ref($node);

  #top or bottom node, not a os entity node, 
  #print it as root of the layout
  print "   +\n" 
   and return 1 
    if defined $node->{NODE_TYPE};

  # How deep is the node
  my $indent = keys %{$stack_ref};

  for ( 1..$indent )
  {
    next unless $_ < $indent;

    print "|  " 
     and next 
      if $indnthsh{$_};

    print "   ";

  }

  if ( $node->{storage_layer} )
  {
    print "|--->";

    fnprnd($node);

    print "\n";
  }

  return 1 
   if defined $node->{$tvtag} 
    and $node->{$tvtag} 
     and keys %{$node->{$tvtag}};
  
  for ( 1..$indent )
  {

    print "|  " 
     and next 
      if $indnthsh{$_};

    print "   ";

  }    
  
  print "\n";
  
  return 1;
    
}


# generate global_unique_id for each entity
sub fnnpgguid ($$) 
{
  
  my ($node, $tvtag ) = @_;
  my %cgidix;
  
  warn "ERROR:Storage entity passed for generating global unique id is not a reference\n"
   and return
    unless ref($node);

  #top or bottom node, not a os entity node, do not process
  return 1 if defined $node->{NODE_TYPE};

  warn "ERROR:Reference passed for generating global unique id not an storage entity \n" 
   and return 
     unless $node->{key_value};

  warn "ERROR:No storage layer defined for $node->{key_value}\n" 
   and return 
     unless $node->{storage_layer};

  warn "ERROR:Traverse direction is unknown\n" 
   and return 
    unless $tvtag =~ /cnlst|pnlst/;

  return 1 if $node->{global_unique_id};
  
  # if the node has  children, build the gids by
  # appending the gids from the children
  if
  (
    defined $node->{cnlst} 
     and $node->{cnlst} 
      and keys %{$node->{cnlst}} 
  )
  {

    for my $kv (  keys %{$node->{cnlst}} )
    {

      next
       if defined $iekv{$kv}->{em_query_flag}
        and $iekv{$kv}->{em_query_flag} =~ /CONTAINER/i;

      warn "ERROR:Global unique ID is null for $kv while generating gid for $node->{key_value}\n"
       and return
        unless $iekv{$kv}->{global_unique_id};

      # the index on child gids ensures that child gids are not repeated
      # to build gid for the parent
      $cgidix{$iekv{$kv}->{global_unique_id}} = 1

    }

    # sort the child gids alphabetically
    for my $gid ( sort { $a cmp $b } keys %cgidix )
    {

      # the first time , global_unique_id = global_unique_id of child, subsequent
      # child nodes are appended with a _
      $node->{global_unique_id} = $gid
       and next 
        unless $node->{global_unique_id};

      $node->{global_unique_id} .= "_$gid";

    }

  }

  if ( not $node->{global_unique_id} )
  {

    my $target_guid = get_target_id() 
     or warn "ERROR:Failed to get the target_id for generating a global unique id for $node->{key_value}\n"
      and return;

    $node->{global_unique_id} = "$target_guid\_$node->{key_value}"  
      if $target_guid;

  }

  if ( $node->{global_unique_id} )
  {
    $node->{global_unique_id} .= "_S$node->{start}" if $node->{start};
  
    $node->{global_unique_id} .= "_E$node->{end}" if $node->{end};
  }

  return 1 if $node->{global_unique_id};

  warn "ERROR:Failed to generate a global unique id for $node->{name} \n" 
   and return 
    if $node->{name};

  warn "ERROR:Failed to generate a global unique id for $node->{key_value} \n"
   and return;

}

  
# If top most in a layer then TOP
# if bottom in a layer then BOTTOM
# if intermediate then INTERMEDIATE
# if container then CONTAINER
# if not allocaed then UNALLOCATED  
# Flag spares too

# mark container entities
sub fnnpmce ($)
{
  
  my ($node) = @_;
 
  warn "Storage entity passed for generating query flag is not a reference\n"
   and return
    unless ref($node);

  #top or bottom node, not a os entity node, do not process
  return 1 if defined $node->{NODE_TYPE};

  warn "Storage entity reference passed for generating query flag has no key_value\n" 
   and return 
    unless $node->{key_value};

  warn "No storage layer defined for $node->{key_value}\n" 
   and return 
    unless $node->{storage_layer}; 

  # it is a container node
  return 1 
   unless  $config{container}{lc $node->{storage_layer}}
    and $config{container}{lc $node->{storage_layer}}{lc $node->{entity_type}};

  # A container node
  $node->{query_flag}{CONTAINER} = 1;
  # a container is also a virtual node
  $node->{query_flag}{VIRTUAL} = 1;

  delete $node->{query_flag}{UNALLOCATED};
  delete $node->{query_flag}{BOTTOM};
  delete $node->{query_flag}{TOP};

  return 1;

}


# mark unallocated entities
sub fnnpmue ($)
{
  
  my ($node) = @_;
  
  warn "Storage entity passed for generating query flag is not a reference\n"
   and return
    unless ref($node);

  #top or bottom node, not a os entity node, do not process
  return 1 
   if defined $node->{NODE_TYPE};

  warn "Storage entity reference passed for generating query flag has no key_value\n" 
   and return 
    unless $node->{key_value};

  warn "No storage layer defined for $node->{key_value}\n" 
   and return 
    unless $node->{storage_layer};

  # if the entity has parent nodes other than containers and virtual 
  # it is allocated
  if
  (
    defined $node->{pnlst} 
     and $node->{pnlst} 
      and keys %{$node->{pnlst}}
  )
  {

    # the node is allocated if the parent node is other than a container
    for my $key ( keys %{$node->{pnlst}} )
    {
      # no query flags so parent not a container, child node is allocated
      return 1
       unless $iekv{$key}->{query_flag}
        and keys %{$iekv{$key}->{query_flag}};

      # the parent is container node , go to the next parent
      next 
       if $iekv{$key}->{query_flag}
        and $iekv{$key}->{query_flag}{CONTAINER};

      # the parent is virtual node , go to the next parent
      next 
       if $iekv{$key}->{query_flag}
        and $iekv{$key}->{query_flag}{VIRTUAL};

      # this parent entity is not a container, so the child entity is 
      # allocated
      return 1;

    }

  }

  # No parent nodes and not a container
  $node->{query_flag}{UNALLOCATED} = 1;


  # check for any other query flags which are conditional on the 
  # entity being unallocated
  return 1 
   unless
   (
    $node->{possible_query_flag}
     and $node->{possible_query_flag}{for}
      and $node->{possible_query_flag}{for}{UNALLOCATED}
       and ref($node->{possible_query_flag}{for}{UNALLOCATED}) =~ /HASH/i
        and keys %{$node->{possible_query_flag}{for}{UNALLOCATED}}
   );
 
  # tick the conditional query flags that depend on 
  # entity being unallocated
  for my $qflg ( keys %{$node->{possible_query_flag}{for}{UNALLOCATED}} )
  {  
    $node->{query_flag}{uc $qflg} = 1;
  }

  return 1;

}

# Mark virtual entities ( Neither TOP, BOTTOM, INTERMEDIATE or CONTAINER )
#( these entities are required to display topology but be left out when 
#calculating storage numbers )
sub fnnpmve ($)
{
  
  my ($node) = @_;
  
  warn "Storage entity passed for generating query flag is not a reference\n"
   and return
    unless ref($node);

  #top or bottom node, not an os entity node, do not process
  return 1
   if defined $node->{NODE_TYPE};

  warn "Storage entity reference passed for generating query flag has no key_value\n" 
   and return
    unless $node->{key_value};

  warn "No storage layer defined for $node->{key_value}\n" 
   and return
    unless $node->{storage_layer};

  # the parent has child nodes
  if
  (
    defined $node->{cnlst}
     and $node->{cnlst}
      and keys %{$node->{cnlst}}
  )
  {

    for my $key ( keys %{$node->{cnlst}} )
    {

      my $ei = $iekv{$key};

      # if a child is virtual the parent is  marked virtual
      if ( $ei->{query_flag} and $ei->{query_flag}{VIRTUAL} )
      {
        $node->{query_flag}{VIRTUAL}=1;

        return 1;
      }

      # if the parent does not have a explicit boundry on the child that can be 
      # identified,- ( Default has explicit boundry )
      if
      (
       $config{is_p_excl_boundry_on_child}{$ei->{storage_layer}}
        and $config{is_p_excl_boundry_on_child}{$ei->{storage_layer}}{lc $ei->{entity_type}}
         and $config{is_p_excl_boundry_on_child}{$ei->{storage_layer}}{lc $ei->{entity_type}}{$node->{storage_layer}}
          and $config{is_p_excl_boundry_on_child}{$ei->{storage_layer}}{lc $ei->{entity_type}}{$node->{storage_layer}}{lc $node->{entity_type}}
           and $config{is_p_excl_boundry_on_child}{$ei->{storage_layer}}{lc $ei->{entity_type}}{$node->{storage_layer}}{lc $node->{entity_type}} =~ /^N$/i
      )
      {
        # Does the parent without explicit boundry represent the whole child 
        #- ( Default represents whole child )
        $node->{query_flag}{VIRTUAL}=1
         if $config{represents_whole_child}{$ei->{storage_layer}}
          and $config{represents_whole_child}{$ei->{storage_layer}}{lc $ei->{entity_type}}
           and $config{represents_whole_child}{$ei->{storage_layer}}{lc $ei->{entity_type}}{$node->{storage_layer}}
            and $config{represents_whole_child}{$ei->{storage_layer}}{lc $ei->{entity_type}}{$node->{storage_layer}}{lc $node->{entity_type}}
             and $config{represents_whole_child}{$ei->{storage_layer}}{lc $ei->{entity_type}}{$node->{storage_layer}}{lc $node->{entity_type}} =~ /^N$/i;

        return 1;
      }

      # the parent has an explicit boundry on the child which can be identified 
      # ( Default )
      # the parent size is already factored in the size/used space of the child 
      # - ( Default Not Factored )
      if
      (
       $config{is_parent_size_in_child}
        and $config{is_parent_size_in_child}{$ei->{storage_layer}}
         and $config{is_parent_size_in_child}{$ei->{storage_layer}}{lc $ei->{entity_type}}
          and $config{is_parent_size_in_child}{$ei->{storage_layer}}{lc $ei->{entity_type}}{$node->{storage_layer}}
           and $config{is_parent_size_in_child}{$ei->{storage_layer}}{lc $ei->{entity_type}}{$node->{storage_layer}}{lc $node->{entity_type}}
            and $config{is_parent_size_in_child}{$ei->{storage_layer}}{lc $ei->{entity_type}}{$node->{storage_layer}}{lc $node->{entity_type}} =~ /^Y$/i
      )
      {
         $node->{query_flag}{VIRTUAL}=1;

         return 1;

      }

      # the parent has an explicit boundry on the child which can be identified
      # ( Default )
      # the parent size is not factored in the size/used space of the child - 
      # ( Default is Not Factored )
      # the unallocated entity of this type can be a virtual entity
      # mark this as a possibility , the mark_unalloacted function will check 
      # this and mark it 
      # virtual if its found to be unalloacted
      if 
      ( 
        $config{virtual_entity}{$node->{storage_layer}}
         and $config{virtual_entity}{$node->{storage_layer}}{lc $node->{entity_type}}
      )
      {
          $node->{possible_query_flag}{for}{UNALLOCATED}{VIRTUAL}=1;
      }

    }

  }

  return 1;

}


# mark spare entities
sub fnnpmse ($)
{
  
  my ($node) = @_;
  
  warn "Storage entity passed for generating query flag is not a reference\n"
   and return
    unless ref($node);

  #top or bottom node, not a os entity node, do not process
  return 1 if defined $node->{NODE_TYPE};

  warn "Storage entity reference passed for generating query flag has no key_value\n" 
   and return 
    unless $node->{key_value};

  warn "No storage layer defined for $node->{key_value}\n" 
   and return 
    unless $node->{storage_layer};

  return 1
   unless 
   (
    $node->{configuration}
     and $node->{configuration} =~ /$config{backup_entities}/i
   );

  # Spare node has configuration spare, hotspare etc in it
  $node->{query_flag}{SPARE} = 1;
  delete $node->{query_flag}{UNALLOCATED}
   if $node->{query_flag}{UNALLOCATED};

  return 1;

}


# Mark bottom entities
sub fnnpmbe ($)
{
  
  my ($node) = @_;
  
  warn "Storage entity passed for generating query flag is not a reference\n"
   and return
    unless ref($node);

  #top or bottom node, not a os entity node, do not process
  return 1 if defined $node->{NODE_TYPE};

  warn "Storage entity reference passed for generating query flag has no key_value\n" 
   and return 
    unless $node->{key_value};

  warn "No storage layer defined for $node->{key_value}\n" 
   and return 
    unless $node->{storage_layer};

  # container and virtual nodes are nither top/bottom/intermediate
  # they are not to be part of summary computation
  return 1
   if 
   (
     $node->{query_flag}
     and
     ( 
       $node->{query_flag}{VIRTUAL}
        or $node->{query_flag}{CONTAINER}
     )
   );

  # No child nodes and not a container
  if
  (
    defined $node->{cnlst}
     and $node->{cnlst}
      and keys %{$node->{cnlst}}
  )
  {
    
    # if child nodes are in another layer set query_flag to BOTTOM
    for my $key ( keys %{$node->{cnlst}} )
    {

      # skip container entities in another layer
      next 
       if defined $iekv{$key}->{query_flag} 
        and $iekv{$key}->{query_flag}{CONTAINER};

      # skip virtual entities in another layer
      next 
       if defined $iekv{$key}->{query_flag} 
        and $iekv{$key}->{query_flag}{VIRTUAL};

     # if the child node is in a different storage_layer set query_flag to 
     #_BOTTOM_
      $node->{query_flag}{BOTTOM} = 1
       if $iekv{$key}->{storage_layer} ne
        $node->{storage_layer};

      return 1 if $node->{query_flag}{BOTTOM};

    }

    # all child nodes are in the same layer
    # if its a the bottom layer will have no child nodes which are other 
    # than containers
    for my $key ( keys %{$node->{cnlst}} )
    {

      # no query flags, so this child is not a container, and the 
      # parent node is not bottom
      return 1
       unless $iekv{$key}->{query_flag}
        and keys %{$iekv{$key}->{query_flag}};

      # the child is container node , go to the next child node
      next 
       if $iekv{$key}->{query_flag}
        and $iekv{$key}->{query_flag}{CONTAINER};

      # the child is virtual node , go to the next child node
      next 
       if $iekv{$key}->{query_flag}
        and $iekv{$key}->{query_flag}{VIRTUAL};

      # this child entity is not a container, so the parent entity is 
      # not bottom
      return 1;

    }

    # no child nodes which are other than containers
    $node->{query_flag}{BOTTOM} = 1;

  }
  else
  # no child nodes
  {
    $node->{query_flag}{BOTTOM} = 1; 
  }
  
  return 1;

}


# Mark top entities
sub fnnpmte ($)
{
  
  my ($node) = @_;
  
  warn "Storage entity passed for generating query flag is not a reference\n"
   and return
    unless ref($node);

  #top or bottom node, not an os entity node, do not process
  return 1 if defined $node->{NODE_TYPE};

  warn "Storage entity reference passed for generating query flag has no key_value\n" 
   and return 
    unless $node->{key_value};

  warn "No storage layer defined for $node->{key_value}\n" 
   and return 
    unless $node->{storage_layer};
;
  # container and virtual nodes are nither top/bottom/intermediate
  # they are not to be part of summary computation
  return 1
   if
   (
     $node->{query_flag}
     and
     (
       $node->{query_flag}{VIRTUAL}
        or $node->{query_flag}{CONTAINER}
     )
   );


  # No parent nodes other than container and virtual
  if
  (
    defined $node->{pnlst}
     and $node->{pnlst}
      and keys %{$node->{pnlst}}
  )
  {

    # if parent nodes are in another layer set query_flag to TOP
    for my $key ( keys %{$node->{pnlst}} )
    {

      # the node is a container, skip to the nex parent node
      next 
       if defined $iekv{$key}->{query_flag}
        and $iekv{$key}->{query_flag}{CONTAINER};

      # the parent is virtual node , go to the next parent node
      next 
       if $iekv{$key}->{query_flag}
        and $iekv{$key}->{query_flag}{VIRTUAL};

      # if the parent node is in a different storage_layer set query_flag to _TOP_
      $node->{query_flag}{TOP} = 1
       if $iekv{$key}->{storage_layer} ne
	$node->{storage_layer};

      return 1 if $node->{query_flag}{TOP};

    }

    # all parent nodes are in the same layer
    # if its a the top layer , it will have no parent nodes other than container 
    # and virtual entities
    for my $key ( keys %{$node->{pnlst}} )
    {

      # this parent node has no query_flags so its nither a container or virtual
      # node and the child node is not a top node
      return 1
       unless $iekv{$key}->{query_flag}
        and keys %{$iekv{$key}->{query_flag}};

      # the parent is container node , go to the next parent node
      next 
       if $iekv{$key}->{query_flag}
        and $iekv{$key}->{query_flag}{CONTAINER};

      # the parent is virtual node , go to the next parent node
      next 
       if $iekv{$key}->{query_flag}
        and $iekv{$key}->{query_flag}{VIRTUAL};

      # this parent entity is nither a container nor virtual, so the parent 
      # entity is not top
      return 1;

    }

    # no parent nodes which are other than containers
    $node->{query_flag}{TOP} = 1;

  }
  else
  # no parent nodes
  {
    $node->{query_flag}{TOP} = 1; 
  }

  return 1; 

}


# generate the em_query_flag from the query_flag hash
sub fnnpgqf( $ )
{

  my ($node) = @_;
  
  warn "Storage entity passed for generating query flag is not a reference\n"
   and return
    unless ref($node);

  #top or bottom node, not a os entity node, do not process
  return 1 if defined $node->{NODE_TYPE};

  warn "Storage entity reference passed for generating query flag has no key_value\n" 
   and return 
    unless $node->{key_value};

  warn "No storage layer defined for $node->{key_value}\n" 
   and return 
    unless $node->{storage_layer};

  fnnpmse( $node ) or return;
  fnnpmbe( $node ) or return;
  fnnpmte( $node ) or return;

  # for virtual nodes, no top, intermediate flags
  if ( $node->{query_flag}{VIRTUAL} )
  {
   delete $node->{query_flag}{TOP};
   delete $node->{query_flag}{INTERMEDIATE};
  }

  # Intermediate if neither top , bottom or virtual
  $node->{query_flag}{INTERMEDIATE} = 1 
   unless 
   (
     $node->{query_flag}{BOTTOM} 
      or $node->{query_flag}{TOP}
       or $node->{query_flag}{VIRTUAL}
   );

  # Create the flag string
  for my $flag ( sort keys %{$node->{query_flag}} )
  {
    $node->{em_query_flag} .= "_$flag" 
     unless 
     (
      defined $node->{em_query_flag} 
       and $node->{em_query_flag} =~ /$flag/
     );    
  }

  # add the extra _ at the end
  $node->{em_query_flag} .= "_"
   if $node->{em_query_flag}; 
 
  return 1;

}

# populate the sizeb for a node where sizeb is null
sub fnnpcsz (\%) 
{

   my ($node) = @_;

  #top or bottom node, not a os entity node, do not process
  return 1 
   if defined $node->{NODE_TYPE};

  warn "ERROR:Reference passed for populating size not an storage entity \n" 
   and return 
     unless $node->{key_value};

  warn "ERROR:No storage layer defined for $node->{key_value}\n" 
   and return 
     unless $node->{storage_layer};

   # Initialize these values before computation
   for my $field ( qw ( sizeb ) )
   {
     $node->{$field} = 0 
      unless 
      (
        defined $node->{$field}
         and  $node->{$field} =~ /^\d+$/
      );
   }

   # If free space is already computed then return
   return 1 
    if $node->{sizeb} > 0;

   # The the current node has child nodes, ie the node below this in 
   # the storage topology
   if
   (
    defined $node->{cnlst}
     and $node->{cnlst}
      and ref ( $node->{cnlst} ) =~ /HASH/i
       and keys %{$node->{cnlst}}
   )
   {

     my $child_sizeb = 0;
     my %hash_global_unique_id;

     # Go thru each parent node, ie the node on top of current node 
     # in the storage topology
     for my $kv ( keys %{$node->{cnlst}} )
     {

        my $cndref = $iekv{$kv};

        # skip container children
        next 
         if defined $cndref->{em_query_flag} 
          and $cndref->{em_query_flag} 
           =~ /CONTAINER/;

        # If Global Unique ID is null then its a processing issue, add the size
        warn "ERROR:Global unique ID not found for $cndref->{name} \n" 
         and return
          unless $cndref->{global_unique_id};

        # we require a valid size
        next 
         unless 
         (
          defined $cndref->{sizeb}
           and $cndref->{sizeb} =~ /^\d+$/
         );

        # if global unique id is he same take the size of the child
        $node->{sizeb} = $cndref->{sizeb}
         and return 1
          if $node->{global_unique_id} =~ /^$cndref->{global_unique_id}$/
           and defined $cndref->{sizeb} 
            and $cndref->{sizeb} =~ /^\d+$/;

        # This child entity has already been added
        next if $cndref->{global_unique_id} 
         and $hash_global_unique_id{$cndref->{global_unique_id}};

        # if there rules of calculating size
        # count the child size only if rules indicate to be included
        if 
        (
         $rfcsz{lc $node->{storage_layer}}
          and $rfcsz{lc $node->{storage_layer}}{lc $node->{entity_type}}
           and $rfcsz{lc $node->{storage_layer}}{lc $node->{entity_type}}
             {lc $cndref->{storage_layer}}           
             and $rfcsz{lc $node->{storage_layer}}{lc $node->{entity_type}}
               {lc $cndref->{storage_layer}}{lc $cndref->{entity_type}}
        )
        {
         next unless 
          $rfcsz{lc $node->{storage_layer}}{lc $node->{entity_type}}
            {lc $cndref->{storage_layer}}
             {lc $cndref->{entity_type}} =~ /INCLUDE/i;
        }

        # Keep an running total of the sizeb and usedb for the parent nodes 
        $child_sizeb +=  $cndref->{sizeb} 
         if $cndref->{sizeb} 
          and $cndref->{sizeb} =~ /^\d+$/;

        # Keep a record that this global unique if has been added
        $hash_global_unique_id{$cndref->{global_unique_id}} = 1 
         if $cndref->{global_unique_id};
     }

     $node->{sizeb} = $child_sizeb
      if defined $child_sizeb
       and $child_sizeb =~ /^\d+$/;

   }
   
   return 1;

}


# Generate the free sizeb for each entity
sub fnnpcfsz ($) 
{
    
  my ($node) = @_;
      
  #top or bottom node, not a os entity node, do not process
  return 1 
   if defined $node->{NODE_TYPE};

  warn "Reference passed for calculating free size not an storage entity \n" 
   and return 
     unless $node->{key_value};

  warn "No storage layer defined for $node->{key_value}\n" 
   and return 
     unless $node->{storage_layer};

   # Initialize these values before computation
   for my $field ( qw ( sizeb usedb freeb rawsizeb ) )
   {
     $node->{$field} = 0 
      unless 
      (
        defined $node->{$field}
         and  $node->{$field} =~ /^\d+$/
      );
   }

   # If free space is already computed then return
   return 1
    if $node->{freeb} > 0;

   # For a spare entity all its space is marked as used
   $node->{usedb} = $node->{sizeb}
    if $node->{em_query_flag}
     and $node->{em_query_flag} =~ /_SPARE_/i;

   # if used space is already computed then compute free space and return
   if ( $node->{usedb} > 0  and $node->{usedb} <= $node->{sizeb} )
   {
     $node->{freeb} = $node->{sizeb}-$node->{usedb};
     return 1;
   }

   # If the current node is a virtual node all space should be free
   if ( $node->{em_query_flag} =~ /_VIRTUAL_/i )
   {
     $node->{freeb} = $node->{sizeb};
     $node->{usedb}= 0;
     return 1;
   }

   # If the current node is unallocated 
   # set free=size and used = 0
   if ( $node->{em_query_flag} =~ /_UNALLOCATED_/i )
   {
     $node->{freeb} = $node->{sizeb};
     $node->{usedb}= 0;
     return 1;
   }

   # compute free space for allocated entities

   # set used=size and freeb = 0
   # if the allocated current node cannot have partially free space
   if 
   ( 
     not $config{can_have_partial_free_space}
      or not $config{can_have_partial_free_space}{$node->{storage_layer}}
       or not $config{can_have_partial_free_space}{$node->{storage_layer}}{lc $node->{entity_type}}  
   )
   {
     $node->{usedb} = $node->{sizeb};
     $node->{freeb}= 0;
     return 1;
   }

   # The the current node has parent nodes, ie the node on top of this in 
   # the storage topology
   if 
   ( 
    defined $node->{pnlst} 
     and $node->{pnlst} 
      and ref($node->{pnlst}) =~ /HASH/i
       and keys %{$node->{pnlst}} 
   ) 
   {
  
     my $parent_sizeb = 0;
     my $parent_usedb = 0;
     my %hash_global_unique_id;

     # Go thru each parent node, ie the node on top of current node 
     # in the storage topology
     for my $kv ( keys %{$node->{pnlst}} )
     {
     
        my $pndref = $iekv{$kv};

        # containers and virtual entities are not part of the storage
        # calculation they are used fro mapping purposes only
        next 
         if defined $pndref->{em_query_flag} 
          and $pndref->{em_query_flag} 
           =~ /CONTAINER|VIRTUAL/;


        # If Global Unique ID is null then its a processing issue, add the size
        warn "ERROR:Global unique ID not found for $pndref->{name} \n" 
          unless $pndref->{global_unique_id};

        # This entity has already been added
        next if $pndref->{global_unique_id} 
         and $hash_global_unique_id{$pndref->{global_unique_id}};

        # if there rules of calculating size
        # count the parent size only if rules indicate to be included
        if 
        (
         $rfcsz{lc $node->{storage_layer}}
          and $rfcsz{lc $node->{storage_layer}}{lc $node->{entity_type}}
           and $rfcsz{lc $node->{storage_layer}}{lc $node->{entity_type}}
             {lc $pndref->{storage_layer}}           
             and $rfcsz{lc $node->{storage_layer}}{lc $node->{entity_type}}
               {lc $pndref->{storage_layer}}{lc $pndref->{entity_type}}
        )
        {
         next unless 
          $rfcsz{lc $node->{storage_layer}}{lc $node->{entity_type}}
            {lc $pndref->{storage_layer}}
             {lc $pndref->{entity_type}} =~ /INCLUDE/i;
        }
        
        # Layer specific checks

        # Keep an running total of the sizeb and usedb for the parent nodes 
        $parent_sizeb +=  $pndref->{sizeb} 
         if $pndref->{sizeb} 
          and $pndref->{sizeb} =~ /^\d+$/;

        $parent_usedb +=  $pndref->{usedb} 
         if $pndref->{usedb} 
          and $pndref->{usedb} =~ /^\d+$/;

        # Keep a record that this global unique if has been added
        $hash_global_unique_id{$pndref->{global_unique_id}} = 1 
         if $pndref->{global_unique_id};
     }

     # if size of parents is > size of entity
     # set free to 0 and all space as used
     (
      $node->{freeb} = 0 ,
       $node->{usedb} = $node->{sizeb}
     )
      and return 1 
        if $node->{sizeb} 
         and $parent_sizeb >= $node->{sizeb};

     $node->{freeb} = $node->{sizeb}-$parent_sizeb; 
     $node->{usedb} = $node->{sizeb}-$node->{freeb}; 

   }
   else
   # the no parents case , ie no storage entities on top of this
   {
     #initialize before we start calculating the size of the parents
     $node->{usedb} = 0, $node->{freeb} = $node->{sizeb};
   } 
   
   return 1;

}


# Generate the raw sizeb for each entity
sub fnnpcrsz ($) 
{
    
   my ($node) = @_;
   
   # Flag spares too
   
  warn "Storage entity passed for calculating raw size is not a reference\n"
   and return
    unless ref($node);

  #top or bottom node, not a os entity node, do not process
  return 1 if defined $node->{NODE_TYPE};

  warn "Reference passed for calculating raw size is not an storage entity \n" 
   and return 
     unless $node->{key_value};

  warn "No storage layer defined for $node->{key_value}\n" 
   and return 
     unless $node->{storage_layer};

   # Initialize these values before computation
   for my $field ( qw ( sizeb usedb freeb rawsizeb ) )
   {
     $node->{$field} = 0 
      unless 
      (
        defined $node->{$field}
         and  $node->{$field} =~ /^\d+$/
      );
   }

   # If free space is already computed then return
   return 1 if $node->{rawsizeb} > 0;

   # initialize before computation
   $node->{rawsizeb} = $node->{sizeb};

  # if the current nodes has child nodes, nodes which are lower in the storage 
  # layout
   if (
       defined $node->{cnlst}
        and $node->{cnlst}
         and keys %{$node->{cnlst}}
   )
   {

     my $child_rawsizeb = 0;
     my %hash_global_unique_id;

     # Go thru each child node, nodes which are lower in the storage layout
     for my $kv ( keys %{$node->{cnlst}} )
     {

        my $cndref = $iekv{$kv}; 

        next 
         if defined $cndref->{em_query_flag} and 
          $cndref->{em_query_flag} =~ /CONTAINER/;

         # If Global Unique ID is null log a processing issue, add the rawsize
        warn "ERROR:Global unique ID not found for $cndref->{name} \n"
         unless $cndref->{global_unique_id};

        # This entity has already been added
        next if $cndref->{global_unique_id} and
          $hash_global_unique_id{$cndref->{global_unique_id}};

        # if there rules of calculating rawsize
        # count the child rawsize only if rules indicate to be included
        if
        (
         $rfcrsz{lc $node->{storage_layer}}
          and $rfcrsz{lc $node->{storage_layer}}{lc $node->{entity_type}}
           and $rfcrsz{lc $node->{storage_layer}}{lc $node->{entity_type}}
             {lc $cndref->{storage_layer}}
             and $rfcrsz{lc $node->{storage_layer}}{lc $node->{entity_type}}
               {lc $cndref->{storage_layer}}
                {lc $cndref->{entity_type}}
        )
        {
         next unless
          $rfcrsz{lc $node->{storage_layer}}{lc $node->{entity_type}}
            {lc $cndref->{storage_layer}}
             {lc $cndref->{entity_type}} =~ /INCLUDE/i;
        }

        # Keep a running total of the rawsizes of the children
        $child_rawsizeb +=  $cndref->{rawsizeb} 
         if $cndref->{rawsizeb} 
          and $cndref->{rawsizeb} =~ /^\d+$/;

        # Keep a record that this global unique if has been added
        $hash_global_unique_id{$cndref->{global_unique_id}} = 1
         if $cndref->{global_unique_id};

     }

     return 1
      if $child_rawsizeb
       and $child_rawsizeb <= $node->{sizeb};

     $node->{rawsizeb} = $child_rawsizeb;

   }

   return 1;

}



# open closed loop by breaking the relationship between the current node 
# and the last node on the stack
sub fnbrclp(\%$\%)
{

  my ( $node, $tvtag, $stack_ref ) = @_;

  # get the last node in the stack, 
  # the last node will have the max index value
  my $depth = keys %{$stack_ref};

  warn "Failed to get the depth of the stack , while trying to break a closed loop\n"
   and return 
    unless $depth;

  warn "Failed to get $depth storage entity on the stack , while trying to break a closed loop\n"
   and return 
    unless $stack_ref->{$depth};

  my $prvnd = $stack_ref->{$depth};

  # break the closed loop
  # clean up the current node from the traverse lists of 
  # last node in the traverse stack
  delete $prvnd->{$tvtag}{$node->{key_value}}
   if $prvnd->{$tvtag}
    and $prvnd->{$tvtag}{$node->{key_value}};

  # clear the last node in the stack from the current nodes
  # traverse list in the opposite direction
  warn "Failed to get the tag name to traverse in opposite direction from $tvtag, while trying to break closed loop\n"
   and return
    unless $config{optg}{$tvtag};

  delete $node->{$config{optg}{$tvtag}}{$prvnd->{key_value}}
   if $node->{$config{optg}{$tvtag}}
    and $node->{$config{optg}{$tvtag}}{$prvnd->{key_value}};

  # remove the node and the last node in the stack from
  # each others {pkvs} lists
  delete $node->{pkvs}{$prvnd->{key_value}}
   if $node->{pkvs}
    and $node->{pkvs}{$prvnd->{key_value}};

  delete $prvnd->{pkvs}{$node->{key_value}}
   if $prvnd->{pkvs}
    and $prvnd->{pkvs}{$node->{key_value}};

  return 1;

}


# Check for closed loops in the tree
my %clpstk;

# Traverse the tree based on the start and tag passed
# and the specified order
sub fntrdf( $$$\&;\% )
{

  my ($order,$node, $tvtag, $fnptr,$stack_ref) = @_;

  # This is a closed loop, the stack keeps track of the node 
  # pointers already traversed
  if ( $clpstk{$tvtag}{$node} )
  {
    warn "Node $node->{storage_layer} $node->{entity_type} $node->{key_value} is in a closed loop when traversing $tvtag\n ";
    fnbrclp(%$node,$tvtag,%$stack_ref) or return;
    return 1;
  }

  # the depth of the tree at any point 
  # is the size of the stack
  my $depth = keys %{$stack_ref};
  $depth +=1;
  $stack_ref->{$depth}=$node;

  # keep an index of the node pointer , for closed loop check
  $clpstk{$tvtag}{$node}=1;

  # preorder processing
  if ( $order =~ /preorder/i)
  {
    # Execute the function to execute before traversing down the tree
    if ( not $fnptr->($node, $tvtag, \%$stack_ref ) )
    {
      delete $stack_ref->{$depth};
      delete $clpstk{$tvtag}{$node};
      return;
    };
  }

  # traverse each child node specified by the traverse_tag
  if ( defined $node->{$tvtag} 
        and $node->{$tvtag}
         and ref($node->{$tvtag}) =~ /HASH/i
          and keys %{$node->{$tvtag}}
  )
  {

    # List of keys from this node to traverse in the direction
    # specified by traverse tag
    my @kvs = sort keys %{$node->{$tvtag}};

    # count of nodes to travserse from this node
    my $node_count = @kvs;

    for my $i ( 1..$node_count )
    {

      my $kv = $kvs[$i-1];

      next unless $kv;

      warn "Failed to find the storage entity $kv in the indexed list\n"
       and return
        unless $iekv{$kv};

      my $next_node = $iekv{$kv};

      next unless $next_node;

      bless $next_node;

      # keeps track of the pending children at any 
      # depth in the layout
      $indnthsh{$depth+1} = $node_count-$i;

      if 
      ( 
        not 
         fntrdf
         (
          $order,
          $next_node,
          $tvtag,
          &$fnptr,
          %$stack_ref
         )
      )
      {
        # unwind the stack and the closed loop index
        delete $stack_ref->{$depth};
        delete $clpstk{$tvtag}{$node};
        return;
      }

    }

 }

  # postorder processing
  if ( $order =~ /postorder/i)
  {
    # Execute the function to execute before traversing down the tree
   if ( not  $fnptr->($node, $tvtag, \%$stack_ref ) )
   {
      delete $stack_ref->{$depth};
      delete $clpstk{$tvtag}{$node};
print "FAILED\n";
      return;
    }

  }

  # unwind the stack and the closed loop index
  delete $stack_ref->{$depth};
  delete $clpstk{$tvtag}{$node};

  return 1;

}

#Traverse the tree post order
sub fntrdfpo( $$\&;\% )
{
  my ($node, $tvtag, $fnptr,$stack_ref) = @_;

  return fntrdf('postorder',$node, $tvtag, &$fnptr,%$stack_ref);
}

#Traverse the tree pre order
sub fntrdfpr( $$\&;\% )
{
  my ($node, $tvtag, $fnptr,$stack_ref) = @_;

  return fntrdf('preorder',$node, $tvtag, &$fnptr,%$stack_ref);
}



# Traverse tree breadth first
sub fntrbf( \%$\& )
{

  my ($node, $tvtag, $fnptr) = @_;

  my %trvstak;
  my @queue;

  # initialize the queue
  push @queue, $node;

  # while there are nodes in the queue
  while ( ( my $nnode = shift @queue)  )
  {

     # If the node has been processed skip it
     next 
      if $trvstak{$tvtag}{$nnode};

     # invoke the function on the nnode
     if ( not $fnptr->($nnode,$tvtag) )
     {
       warn "Failed executing the function in fntrbf for node \n";
       return;
     }

     # keep track of the processed nodes
     $trvstak{$tvtag}{$nnode}=1;

     # if the nnode has children push them to the queue
     next 
      unless
      (
       $nnode
#        and ref($nnode) =~ /HASH/i
         and $nnode->{$tvtag}
          and ref($nnode->{$tvtag}) =~ /HASH/i
           and keys %{$nnode->{$tvtag}}
      );

     # push each child node to the queue
     for my $ckv ( keys %{$nnode->{$tvtag}} )
     {
       next unless $ckv;

       warn "Failed to find the $tvtag key_value $ckv in iekv for node \n"
        and return 
         unless $iekv{$ckv}; 

       my $cnd = $iekv{$ckv};

       warn "The $tvtag node key_value $ckv is not a hash in iekv for node \n"
        and return 
         unless 
         (
          $cnd
       #    and ref($cnd) =~ /HASH/i
           and keys %{$cnd}
         );

      push @queue,$cnd;

     }
 
  }

  return 1;

}

#--------------------------------------------------------------------------------
# Validate the collected raw metrics from the perl modules
sub fnvrawd ( \@ )
{

 my ( $mlref ) = @_;

 # Perform validation of the fields between metic record and validation list
 sub fnvmfld ( \%\% )
 {
   my ( $tref,$fref) = @_;

   # Make sure the arguments passed are refs to hashes
   warn "Failed in fnvmfld, hash ref expected for first argument \n"
    unless
    (
      $tref and ref($tref) =~ /HASH/i
    );

   warn "Failed in fnvmfld, hash ref expected for second argument \n"
    unless
    (
      $fref and ref($fref) =~ /HASH/i
    );

   # validate each field in the validate has list
   for my $field ( keys %{$fref} )
   {
     # The field should be present
     warn "ERROR:Metric column $field not instrumented\n"
      and return
       unless defined $tref->{$field};
     
     # data type check not required
     next unless $fref->{$field};

     # perform data type check
     warn "ERROR:Metric column $field is not of $fref->{$field} type\n"
      and return
       unless $tref->{$field} =~ /$fref->{$field}/;

   }

   return 1

 }

 warn "Failed in validate_raw_data, array ref expected for argument\n"
  and return
   unless ref($mlref) =~ /ARRAY/i;

 for my $mhref ( @{$mlref} )
 {

   warn "Failed in validate_raw_data, expected hash ref of metrics in each array element\n"
    and return
     unless ref($mhref) =~ /HASH/i;

   # Remove any spaces at the begining and end for each value
   for my $fkey ( keys %{$mhref} )
   {
     next unless $mhref->{$fkey};

     $mhref->{$fkey} =~ s/^\s+|\s+$//g;
   }

   # perform common validations
   fnvmfld(%{$mhref},%vcflds)
    or return;

   # perform storage layer specific validations
   (
    fnvmfld
    (
     %{$mhref},
     %{$vsflds{lc $mhref->{storage_layer}}}
    )
     or return
   )
    if $mhref->{storage_layer}
     and $vsflds{lc $mhref->{storage_layer}}
      and ref($vsflds{lc $mhref->{storage_layer}}) =~ /HASH/i;

   # perform entity type specific validations
   (
    fnvmfld
    (
     %{$mhref},
     %{$veflds{lc $mhref->{storage_layer}}{lc $mhref->{entity_type}}}
    )
     or return
   )
    if $mhref->{storage_layer}
     and $mhref->{entity_type}
      and $veflds{lc $mhref->{storage_layer}}{lc $mhref->{entity_type}}
       and
        ref($veflds{lc $mhref->{storage_layer}}{lc $mhref->{entity_type}})
         =~ /HASH/i;

 }

 return 1;

}

# prepare the raw dtaa for further processing
# strip leading/trailing blanks
# append stoage layer to key_value, parent_key_value
# append storage_layer to parent/child key criteria
sub fnprawd ( \@ )
{
  my ( $stgeref ) = @_;

  # process the collected metrics
  # appent key_value and parent_key_value with storage_layer
  # remove trailing and leading spaces from all entities
  for my $mhdref ( @{$stgeref} ) 
  {

    # remove trailing and leading spaces from all entity data
    for my $hash_key ( keys %$mhdref  )
    {

       next unless $mhdref->{$hash_key};

       $mhdref->{$hash_key} =~ s/^\s+|\s+$//g;

       $mhdref->{$hash_key} =~ s/^-+$//g;  

       # replace blank spaces in entity type with -
       $mhdref->{$hash_key} =~ s/-/ /g 
        if $hash_key =~ /entity_type/i;

    }

    # ERROR If there is NO key_value
    warn "key_value cannot be null for an instrumented mertic\n" 
     and return 
      unless $mhdref->{key_value};

    # The key value is specific to a layer, so append it with the storage_layer
    # wherever it is refered
    $mhdref->{key_value} =
     "$mhdref->{storage_layer}_$mhdref->{key_value}";

    # the instrumented parent_key_value always refers to 
    # entities within the storage layer
    # prepend storage_layer to parent_key_value
    $mhdref->{parent_key_value} = 
     "$mhdref->{storage_layer}_$mhdref->{parent_key_value}" 
      if $mhdref->{parent_key_value};

    # append the key_values defined in the parent and chld_key_criteria with
    # the storage_layer
    for my $hshk ( qw ( parent_entity_criteria child_entity_criteria ) )
    {

      next 
       unless $mhdref->{$hshk};

      next 
       unless ref($mhdref->{$hshk}) =~ /ARRAY/i;

      # update key_value in each criteria
      for my $crt ( @{$mhdref->{$hshk}} )
      {

        next 
         unless ref($crt) =~ /HASH/i;

        # append the storage layer to criteria if its not
        # in there yet
        $crt->{storage_layer} = $mhdref->{storage_layer}
         unless $crt->{storage_layer};

        # update criteria if it has a key_value
        next
         unless $crt->{key_value};

        # append storage_layer from criteria
        $crt->{key_value} =
         "$crt->{storage_layer}_$crt->{key_value}"
          and next
           if $crt->{storage_layer};

        # append storage_layer from the metrics hash 
        $crt->{key_value} =
         "$mhdref->{storage_layer}_$crt->{key_value}"
          if $mhdref->{storage_layer};

      }

    }

  }

  return 1;
}


# Collect all the data
sub fncrsm( \@ ) 
{
    
  my ( $amdr ) = @_;
  
  warn "Failed to collect raw data ,the first arg should be an array \n" 
   and return
    unless ref($amdr) =~ /ARRAY/i;

  # Get List of functions to execute in the top down order, store this order as
  # the hierarchy for storage layers here
  # Loop thru them and execute them and store the results in the array
  # Process the array
  
  my $amhrff;  
  my %lsmf = 
  ( 
    3 => \&storage::Register::get_disk_metrics , 
    2 => \&storage::Register::get_virtualization_layer_metrics, 
    1 => \&storage::Register::get_filesystem_metrics 
  );

  my %tsmf = 
  ( 
    3 => 'storage::Register::get_disk_metrics' , 
    2 => 'storage::Register::get_virtualization_layer_metrics', 
    1 => 'storage::Register::get_filesystem_metrics' 
  );

  for my $fnordr ( sort {$a cmp $b}  keys %lsmf )
  {
    # How to handle stdout    
    $amhrff = $lsmf{$fnordr}->() 
     or warn "Failed to execute function $tsmf{$fnordr}\n" 
      and return;

# print Dumper($amhrff);   

    # Validate the collected raw data
    fnvrawd(@$amhrff) 
     or warn "Failed to validate data from $tsmf{$fnordr}\n"
      and return;

    fnprawd( @$amhrff ) 
     or warn "Failed to prepare raw data from $tsmf{$fnordr}\n"
      and return;

    push @{$amdr}, @$amhrff
     if $amhrff 
      and @$amhrff;
  }

  return 1;

}


# index <key_value><os_identifier>=ref
# index <os_identifier><key_value>=ref
# index <key_value>=ref
# index <key_value>->{pkvs}{parent_key_value}=1
# Build the quick look up hash indexes , datastructures with references
sub fnblds( \@\% )
{

  my ( $alldata_ref,$sdref ) = @_;

  warn "Failed to build the lookup data structure ,the first arg should be an array \n" 
   and return
    unless ref($alldata_ref) =~ /ARRAY/i;

  warn "Failed to build the lookup data structure ,the second argument should be a hash \n" 
   and return
    unless ref($sdref) =~ /HASH/i;

  # build the required indexes for fast look up
  for my $eref ( @{$alldata_ref} )
  {

    # index <key_value>=ref
    $iekv{$eref->{key_value}} = $eref 
      unless $iekv{$eref->{key_value}};

    # keep an array of all parent_key_values on the iekv index
    $iekv{$eref->{key_value}}->{pkvs}{$eref->{parent_key_value}}=1
      if $eref->{parent_key_value};

    # keep an array of all parent/child key criterias on the iekv index
    push @{$iekv{$eref->{key_value}}->{parent_key_criteria}},
     @{$eref->{parent_key_criteria}}
      if $eref->{parent_key_criteria}
       and $eref != $iekv{$eref->{key_value}};

    push @{$iekv{$eref->{key_value}}->{child_key_criteria}},
     @{$eref->{child_key_criteria}}
      if $eref->{child_key_criteria}
       and $eref != $iekv{$eref->{key_value}};

    # keep an index of entities with os identifier
    #
    # index <key_value><os_identifier>=ref
    # index <os_identifier><key_value>=ref
    #
    # What about entities that cannot be recognized on the OS but can be 
    # shared across Layers, like what ??? - Disks on a windows NT box !!
    #
    $ieosp{key_value}{$eref->{key_value}}{$eref->{os_identifier}} = 
     $iekv{$eref->{key_value}}, 
      $ieosp{os_identifier}{$eref->{os_identifier}}{$eref->{key_value}} = 
       $iekv{$eref->{key_value}}
        if $eref->{os_identifier};

    # build the storage_data{data} array to instrument data metrics
    push @{$sdref->{data}}, $eref 
     if $iekv{$eref->{key_value}} == $eref;

  }

  return 1;

}


#--------------------------------------------------------------------------------
# FUNCTION :  fnmpcrcr
#
# DESC 
# Mark the parent_key_values for entities based on any parent or child key 
# criteria defined Returns a reference to an array of pointers to disk metric
# data as required by EM
#
# ARGUMENTS
# array of the pointer to the metric hashes generated fro OEM 9I
#
#--------------------------------------------------------------------------------
# the key_values here should have storage layer factored in them
# Either move this later on after key_value, parent_key_value and key_value in
# criteris are qualified with STORAGE_LAYER
sub fnmpcrcr ( \@ )
{
    
  my ( $stgeref ) = @_;

  # Mark the parent_key_values for entities based on any parent or child key
  # criteria defined
  for my $kv ( keys %iekv ) 
  {

    my $eref = $iekv{$kv};

  # build the child to parent hash for the entity if the parent_key criteria 
  # is defined 
    if ( $eref->{parent_entity_criteria} and @{$eref->{parent_entity_criteria}} )
    {

      for my $pecr ( @{$eref->{parent_entity_criteria}} )
      {

        next unless keys %{$pecr};

        for my $mdref ( @{$stgeref} )
        {

          # an entity cannot be its own child
          next if $mdref == $eref;
          # Add a check for key_value too, parent and child cannot have same
          # key_value
          next 
           if $eref->{key_value}
            and $mdref->{key_value}
             and $eref->{key_value} eq $mdref->{key_value};

          # If the key_value of this mdref entity is already a parent
          # skip to next mdref
          next 
           if $eref->{pkvs}
            and $eref->{pkvs}{$mdref->{key_value}};

          my @values =
           map
           {
            'FAILED_PARENT_CHILD_ENTITY_CRITERIA' 
             unless $mdref->{$_} 
              and $mdref->{$_} eq $pecr->{$_}
           }
            keys %{$pecr};

          next if grep /FAILED_PARENT_CHILD_ENTITY_CRITERIA/,@values;

          $eref->{pkvs}{$mdref->{key_value}}=1;

        }

      }

    }


    # build the parent to child hash for the entity if the child_key criteria is 
    # defined   
    if ( $eref->{child_entity_criteria} and  @{$eref->{child_entity_criteria}} ) 
    {

      for my $cecr ( @{$eref->{child_entity_criteria}} ) 
      {

        next unless keys %{$cecr};

        for my $mdref ( @{$stgeref} )
        {

          # an entity cannot be its own child
          next if $mdref == $eref;
          # Add a check for key_value too, parent and child cannot have same 
          # key_value
          next 
           if $eref->{key_value}
            and $mdref->{key_value}
             and $eref->{key_value} eq $mdref->{key_value};

          # If the key_value of this mdref entity is already a parent
          # skip to next mdref
          next
           if $mdref->{pkvs}
            and $mdref->{pkvs}{$eref->{key_value}};

          my @values = 
           map 
           {
             'FAILED_PARENT_CHILD_ENTITY_CRITERIA' 
              unless $mdref->{$_} 
               and $mdref->{$_} eq $cecr->{$_}
           } 
            keys %{$cecr};

          next if grep /FAILED_PARENT_CHILD_ENTITY_CRITERIA/,@values;

          $mdref->{pkvs}{$eref->{key_value}}=1;
       }
      }
    }
  }

  return 1;

}


# index <os_path>=identifier
# index @<identifier>,ref# storage @data,ref
# storage @{parent_key}<child_key_value>,<parent_key_value>
# storage @<key_value>,<parent_key_value>
# Interlink between the entities across different storage layers that are 
# represented on the OS

sub fnmpcros( \% ) 
{
    
  my ( $sdref ) = @_;
  
  # Loop theu the entities which have as os identifier and build a list of 
  # entities to an ospid
  # Read from index <os_identifier><key_value>=ref
  for my $osid ( keys %{$ieosp{os_identifier}} )
  {
  
    for my $kv ( keys %{$ieosp{os_identifier}{$osid}} )
    { 

      my $ie = $iekv{$kv};

      # Be more linient on this return os_path if either of these functions fail
      my $ospth = storage::Register::get_os_storage_entity_path($osid) or 
        warn "ERROR:Failed to get the OS storage entity name $osid\n" and return;
      
      my $ospid =  storage::Register::get_os_identifier_for_os_path ($ospth) or 
        warn "ERROR:Failed to get the os identifier for storage entity name $ospth\n" and return;

      my $ftype =  storage::Register::get_file_type ($osid) or 
        warn "ERROR:Failed to get the filetype for $osid \n" and return;

      $ie->{filetype} = $ftype 
       if $ie->{os_identifier} 
        and $ie->{os_identifier} eq $osid;

      push @{$ie->{ospid}},$ospid;
      
      # index {ospid}{ospid}{kv}=1
      $ieosp{ospid}{$ospid}{$ie->{key_value}}=1;
      
      # Build the alias metric for each os path for a key_value
      push @{$sdref->{alias}}, {key_value=>$kv,value=>$osid,filetype=>$ftype} 
       if $kv 
        and $osid;

    }

  }
    
  # loop thru the entities which have an os_identifier and find entities in 
  # another storage layaer 
  # which have the same entitiy identifier
  # Read from <key_value><os_identifier>-ref
  for my $kv ( keys %{$ieosp{key_value}} )
  {

    my $ie = $iekv{$kv};

    # There should be an identifier for this os path
    warn "ERROR:Failed to find an identifier on the OS for $ie->{os_identifier}\n"
     and return
      unless @{$ie->{ospid}};

    for my $ospid ( @{$ie->{ospid}} )
    {

      # Get all entities with the same identifier as this one
      # build the list 
      # storage_data @{parent_key}<child_key_value>,<parent_key_value>
      #
      for my $okv ( keys %{$ieosp{ospid}{$ospid}} )
      {

        my $iewosid = $iekv{$okv};

        # The other entity with the same identifier should be in a different 
        # storage layer than the $kv entity
        # next unless $iewosid->{storage_layer} ne $ie->{storage_layer};
        # Lets map within the os visible entities in a storage layer
        next
         unless $iewosid->{key_value} ne $kv;

        warn "No hierarchy defined for layers\n"
         and next
          unless $config{slh}{$ie->{storage_layer}}
           and $config{slh}{$iewosid->{storage_layer}};

        # The parent_key for the entity in the lower storage layer should 
        # have a list of key_values of the entity higher storage layers
        # Disk < Volume < Filesystem < File
        if 
        ( 
          $config{slh}{$ie->{storage_layer}} <
           $config{slh}{$iewosid->{storage_layer}}
        )
	{
          $ie->{pkvs}{$iewosid->{key_value}}=1;
          next;
        }

        if 
        (
          $config{slh}{$ie->{storage_layer}} >
           $config{slh}{$iewosid->{storage_layer}}
        )
	{
          $iekv{$iewosid->{key_value}}->{pkvs}{$ie->{key_value}}=1;
          next;
	}

        # If the parent and child are in the same layer then

        # Do not map within a layer if hierarchy is not defined for both the 
        # layers
        next 
         unless $config{seh}{$ie->{storage_layer}}{$ie->{entity_type}} 
          and $config{seh}{$iewosid->{storage_layer}}{$ie->{entity_type}};

        # check for cyclic dependencies between a immediate parent and child
        # entities skip if a parent child relationship already exists
        # between the entities
        next
         if
          (
            $ie->{parent_key_value}
             and $ie->{parent_key_value} eq $iewosid->{key_value}
          )
          or
          (
            $iewosid->{parent_key_value} 
             and $iewosid->{parent_key_value} eq $kv
          );

        # If parent key for the lower entity should have the list of key values 
        # of the higher entity
          if 
          ( 
            $config{seh}{$ie->{storage_layer}}{$ie->{entity_type}} <
             $config{seh}{$iewosid->{storage_layer}}{$iewosid->{entity_type}}
          )
	  {
            $ie->{pkvs}{$iewosid->{key_value}}=1;
            next;
	  }

          if
          (
            $config{seh}{$ie->{storage_layer}}{$ie->{entity_type}} > 
            $config{seh}{$iewosid->{storage_layer}}{$iewosid->{entity_type}}
          )
	  {
            $iekv{$iewosid->{key_value}}->{pkvs}{$ie->{key_value}}=1;
            next;
          }

      }

    }

  }

    return 1;

}


# collate and build parent keys for all entities
sub fncabk(\%)
{

  my ( $sdref ) = @_;

  # Loop thru each child key_value in 
  # storage @{parent_key}<child_key_value>,<parent_key_value>
  for my $ckv ( keys %iekv )
  {

    # ERROR If there is NO entry in key master for node
    warn "key_value cannot be null in key map\n" 
     and return unless $ckv;

    # Loop thru List of parents from 
    # storage @{pkvs}<child_key_value>,<parent_key_value>
    for my $pkv ( keys %{$iekv{$ckv}->{pkvs}} )
    {

      # ERROR If there is a parent node and if there is NO entry in key master
      # for parent node
      warn "Unable to find the entry in key master for parent node $pkv\n"
       and return unless $pkv 
        and defined $iekv{$pkv};

      # Keep the parent to child relationship between the parent node and child
      # node for top down traversal
      $iekv{$pkv}->{cnlst}{$ckv} = 1;

      # Keep the child to parent relationship between the parent node and child
      # node for bottom up traversal
      $iekv{$ckv}->{pnlst}{$pkv} = 1;

    }

  }

   return 1;

}


sub fnpcsm( \@\% ) 
{

  my ( $stgeref, $sdref ) = @_;

  # mark parent child keys based on parent_key_criteria from raw metrics
  fnmpcrcr(@{$stgeref}) 
   or warn "Failed to mark the parent_key_values based on criteria\n" 
    and return;

  # mark parent child entities based on is identifier
  fnmpcros(%$sdref) 
   or return;

  # collate and build the parent_key_value metric for entities
  fncabk(%$sdref) 
   or return;

  # Identifier for top and bottom nodes so we can skip processing them
  # in np_ functions
  $tpnds{NODE_TYPE}='TOP_NODE';
  $btmnds{NODE_TYPE}='BOTTOM_NODE';

  # From the node List get the nodes which are the bottom ones, ones with no 
  # children  
  for my $node ( values %iekv  )
  {

    # If there is no parent node then this is a top node
    $tpnds{cnlst}{$node->{key_value}} = 1
     unless
     (
      defined $node->{pnlst} 
       and $node->{pnlst} 
        and keys %{$node->{pnlst}}
     );

    # If there are no children then this is a bottom node
    $btmnds{pnlst}{$node->{key_value}} = 1
     unless 
     (
      defined $node->{cnlst} 
       and $node->{cnlst} 
        and keys %{$node->{cnlst}}
     );

  }

  # gid requires gids for all the children first
  # so depth first post order from top
  fntrdfpo(\%tpnds ,'cnlst',&fnnpgguid)
   or warn "ERROR:Failed to generate the global unique_id for all nodes in the storage tree\n"
    and return;
  # no dependency any traverse will do
  fntrdfpo(\%tpnds ,'cnlst',&fnnpmce)
   or warn "ERROR:Failed to mark the container entities in the storage tree\n"
    and return;
  # since a node is virtual is its child is virtual, so depth first post order 
  # from top
  fntrdfpo(\%tpnds ,'cnlst',&fnnpmve)
   or warn "ERROR:Failed to mark the virtual entities in the storage tree\n"
    and return;
  # since a node is unalloacted if it has no parents 
  # ( except containers and virtual )
  # so depth first post order from bottom 
  fntrdfpo(\%btmnds ,'pnlst',&fnnpmue)
   or warn "ERROR:Failed to mark the unallocated entities in the storage tree\n"
    and return;
  # this will also mark, top, botton and spares in the same traverse
  # no preference of traverse
  fntrdfpo(\%tpnds ,'cnlst',&fnnpgqf)
   or warn "ERROR:Failed to mark the top entities in the storage tree\n"
    and return;

  fntrbf(%btmnds ,'pnlst',&fnnpcsz)
   or warn "ERROR:Failed to populate the size for all nodes in the storage tree\n"
    and return;
  fntrdfpo(\%btmnds ,'pnlst',&fnnpcfsz)
   or warn "ERROR:Failed to calculate the free size for all nodes in the storage tree\n"
    and return;
  fntrdfpo(\%tpnds ,'cnlst',&fnnpcrsz)
   or warn "ERROR:Failed to calculate the raw size for all nodes in the storage tree\n"
    and return;

  # Print the tree top down if the env is defined
  if ( $ENV{EM_STORAGE_PRINT_TOPOLOGY} )
  {

    fntrdfpr(\%tpnds  ,'cnlst',&fnnpprnd)
     or die "Failed to print the tree ";
    # Print the tree bottom up 
    fntrdfpr(\%btmnds ,'pnlst',&fnnpprnd)
     or die "Failed to mark parent tree indent";
  }

  return 1;

}

# check for consistency issues in the procssed metrics
sub fncfcsi(\%)
{
  my ( $sdref ) = @_;
  
  # Check for mapping errors
  # The bottom nodes of higher layers should be parents of lower layer entities
  for my $kv ( keys %{$btmnds{pnlst}} )
  {

    next unless $iekv{$kv}->{em_query_flag} =~ /_BOTTOM/i;

    # If the bottom level entity has child entities then there is no issue 
    next if $iekv{$kv}->{cnlst}
     and keys %{$iekv{$kv}->{cnlst}};

    # OS disks and NFS filesystems will not have children, all others should
    next if $iekv{$kv}->{storage_layer} =~ /^NFS$/i
     and $iekv{$kv}->{entity_type} =~ /^filesystem$/i;

    next if $iekv{$kv}->{storage_layer} =~ /^OS_DISK$/i
     and $iekv{$kv}->{entity_type} =~ /^disk$/i;

    log_message( 'ERROR_INST_MAPPING','ACTION_INST_RESOLV_ISSUE', 
     $iekv{$kv} )
      or warn "Failed to log issue mapping error\n"
       and return;
  }

  # Check for invalid size values
  for my $kv ( keys %iekv )
  {

    next if $iekv{$kv}->{em_query_flag} =~ /_CONTAINER/i;

    next if $iekv{$kv}->{sizeb} >= 0 
     and $iekv{$kv}->{sizeb} >= 
      $iekv{$kv}->{usedb};

    log_message( 'ERROR_INST_INVALID_SIZE','ACTION_INST_RESOLV_ISSUE', 
     $iekv{$kv} ) 
      or warn "Failed to log issue for invalid size\n"
       and return;

  }

  return 1;

}

# instrument the keys metrics ( key_value, parent_key_value)
# from the %iekv{kv}->{pkvs} hash structure
#
sub fngkvpkm(\% )
{
  my ( $sdref ) = @_;
  my %icpkh;

  # Loop thru each child key_value in 
  # storage @{parent_key}<child_key_value>,<parent_key_value>
  for my $ckv ( keys %iekv ) 
  {

    # ERROR If there is NO entry in key master for node
    warn "key_value cannot be null in key map\n" 
     and return unless $ckv;

    # Loop thru List of parents from 
    # storage @{pkvs}<child_key_value>,<parent_key_value>
    for my $pkv ( keys %{$iekv{$ckv}->{pkvs}} )
    {

      # ERROR If there is a parent node and if there is NO entry in key master
      # for parent node
      warn "Unable to find the entry in key master for parent node $pkv\n"
       and return unless $pkv 
        and defined $iekv{$pkv};

      # Build the keys array for reporting
      #
      # index {parent_to_child_map}<key_value><parent_key_value>
      # storage @keys,ref {child_key_value, parent_key_value}

      # Do not relist the child_key , parent_key again, this is a unique key in
      # the mgmt_storage_report_keys table
      next 
       if $icpkh{$ckv}
        and $icpkh{$ckv}{$pkv};

      $icpkh{$ckv}{$pkv} = 1;

      # The list of keys to be instrumented
      push @{$sdref->{keys}}, 
       {key_value=>$ckv, parent_key_value=>$pkv};

    }

  # Make sure each key_value has an entry in the list of keys, if it doesnt then
  # it has no parent or its a top enity in the tree
  # For a top entity set the parent_key_value to be the same as key_value.
  # key_value and parent_key_value form the primary key
  push @{$sdref->{keys}},
   {key_value=>$ckv, parent_key_value=>$ckv}
    unless $icpkh{$ckv}
     and keys %{$icpkh{$ckv}};

  }

  return 1;

}


# write the instrumented storage metrics to file
sub fncsmtf(\%)
{
    
  my ( $sdref ) = @_;
    
  # Get the issues metric list
  $sdref->{issues} = storage::Register::get_messages();

  # Process each metric for writign to the file
  for my $mnm( qw ( data keys issues alias ) )
  {
    
    my @all_rows;
    # Read all the metric data by row into an array
    for my $row ( @{$sdref->{$mnm}} )
    {

      my $row_to_file = ''; 

      for my $clordr ( sort {$a <=> $b} keys %{$stgcls{$mnm}} )
      {
    
        $row_to_file = 
          "$row_to_file$row->{$scm{$row->{storage_layer}}{$stgcls{$mnm}{$clordr}}}|" 
         and next if $row->{storage_layer} 
          and $scm{$row->{storage_layer}}{$stgcls{$mnm}{$clordr}} 
           and $row->{$scm{$row->{storage_layer}}{$stgcls{$mnm}{$clordr}}};
        
        $row_to_file ="$row_to_file$row->{$stgcls{$mnm}{$clordr}}|" 
         and next if $row->{$stgcls{$mnm}{$clordr}};
        
        $row_to_file =  "$row_to_file|" 
         unless $clordr == keys % {$stgcls{$mnm}};;

      }

      push @all_rows,$row_to_file;

    }
  
    # Dump the metrics to the file
    my $flnm = catfile($smddr,'nmhs'.substr($mnm,0,4).'.txt');
    
    stat($flnm);
    
    open(FH,'>',$flnm) 
     or close(FH) 
      and warn "ERROR:Failed to open the mapfile $flnm while generating metrics\n" 
       and return;
    
    # Print the column header
    print FH "columns=";
    
    for my $clordr ( sort {$a <=> $b} keys %{$stgcls{$mnm}} )
    {
      print FH "$stgcls{$mnm}{$clordr}|";
    }
    
    print FH "\n";
    
    # Print the metric data
    for my $row ( sort @all_rows )
    {
       print FH "$row\n";
    }

    close(FH) 
     or warn "Failed to close the file $flnm while generating metrics \n" and return;
  
  }
    
  return 1;
    
}


# generate the storage metrics and cache it to file
sub fngsm() 
{
    
  my %storage_data;
  my @alldata;

  # collect raw metrics
  fncrsm(@alldata) or return;
  
  warn "ERROR:Failed to collected data for analysis and instrumenting storage metrics\n"
   and return 
    unless @alldata;
   
  # dump raw metrics to file
  fndrmtf('nmhsrmet.log',@alldata) or return;

  # build lookup indexes
  fnblds(@alldata,%storage_data) or return;

  # mark parent child relationships
  fnpcsm(@alldata,%storage_data) or return;
 
  # check for consistency issues
  fncfcsi(%storage_data) or return;

  # instrument the keys metric from the processed data
  fngkvpkm(%storage_data) or return;

  # cache the processed metrcs to file
  fncsmtf(%storage_data) or return;
  
  return 1;
}


# display the cached metrics from file
sub fndsmff($)
{
    
   my ( $mnm) = @_;
   
   my $flnm = catfile($smddr,'nmhs'.substr($mnm,0,4).'.txt');
   
   stat($flnm);
   
   # Open the file for reading
   open(FH,"$flnm") or 
    warn "ERROR:Failed to open the cached file $flnm for $mnm while reading metrics\n" 
     and return;
   
   my @cols;
   
   # Read each line and prepare it for printing
   while ( <FH> )
   {
  
     my %row;
     
     chomp;
     
     s/^\s+|\s+$//g;
     
    # read the title row 
     @cols = split /\|/,substr $_ , length('columns=') 
      and next if $_ =~ /^columns=/;
     
     warn "ERROR:Unable to read the field names from file $flnm for metric $mnm\n" 
      and return
       unless @cols;
     
     # get all columns from the data row
     my @values = split /\|/;
     
     @row{ @cols } = @values;
     
     for my $clordr ( sort {$a <=> $b} keys % {$stgcls{$mnm}} )
     {
         
       print "em_result=" if $clordr == 1;      
   
       if  ( $row{$stgcls{$mnm}{$clordr}} )
       {
         print "$row{$stgcls{$mnm}{$clordr}}";
       }
       elsif ( $scm{$mnm}{$stgcls{$mnm}{$clordr}} and 
                   $mcpf{$scm{$mnm}{$stgcls{$mnm}{$clordr}}} and
                       $mcpf{$scm{$mnm}{$stgcls{$mnm}{$clordr}}} =~ /u/
             )
       {
         print "0";
       }
       else
       {
         print "0" if $mcpf{$stgcls{$mnm}{$clordr}} and
          $mcpf{$stgcls{$mnm}{$clordr}} =~ /u/;
       }
   
       print "|" unless $clordr == keys % {$stgcls{$mnm}};
         
     }
  
     print "\n";

   }
   
   close(FH)
    or warn "Failed to close the file $flnm while reading metrics\n";

   return 1;
   
}

#----------------------------------------------------------------------------
# Restore STDERR
#----------------------------------------------------------------------------
sub restore_stderr()
{
  # Close the error log file
  close(STDERR);
  
  # Restore back the stderr fd
  open(STDERR,">&OLDERR");
      
  close(OLDERR);
  
  return 1;
    
}

sub exit_fail()
{
    
  restore_stderr();
    
  my $errmsgrf = storage::Register::get_error_messages();

  exit 1
   unless 
   ( 
     $errmsgrf 
      and ref($errmsgrf) =~ /ARRAY/i 
       and @{$errmsgrf}
   );

  for my $error_message ( @{$errmsgrf} )
  {
      
    chomp $error_message;

    $error_message =~ s/^\s+|\s+$//g;

    next unless $error_message;

    print "em_error=$error_message\n";

  }

  exit 1;
    
}

#---------------------------------------------------
# Begin processing here
#---------------------------------------------------
#initialization - prepare logging directories
fninit();

# Read the metric to be instrumented, the default is data for 
# storage_report_data metric
$storage::Register::metric_name = $ARGV[0] 
 if $ARGV[0];

# remove leading or trailing blanks
$storage::Register::metric_name =~ s/\s//g
 if $storage::Register::metric_name;

# default storage_reportic metric is data for storage_report_data
$storage::Register::metric_name = 'data' 
 unless $storage::Register::metric_name;

warn "ERROR:Unsupported storage_report metric $storage::Register::metric_name\n" 
 and exit_fail() 
  unless $storage::Register::metric_name =~ /^(data|keys|issues|alias)$/;

# The storage_report_data metric will always cache fresh data to the files.
# The keys and issues metrics will read the cached data if it exists , 
# if no cached files exist they will generate all metrics and cache the metrics

my $flnm = 
  catfile($smddr,'nmhs'.substr($storage::Register::metric_name,0,4).'.txt');

stat($flnm);

( 
  fngsm 
   or warn "ERROR:Failed to generate storage metrics for $storage::Register::metric_name\n" 
    and exit_fail() 
) 
if 
( 
  $storage::Register::metric_name =~ /^data$/ 
   or not -e $flnm
);

fndsmff($storage::Register::metric_name) 
 or warn "Failed to read storage metrics for $storage::Register::metric_name from file\n" 
  and exit_fail();

# print the warning and error messages as warnigns to stdout
# this will be logged in table mgmt_current_metric_errors by the em agent
my $errmsgrf = storage::Register::get_error_messages();

if
(
 $errmsgrf
  and ref($errmsgrf) =~ /ARRAY/i 
   and @{$errmsgrf}
)
{

  for my $errmsg ( @{$errmsgrf} )
  {

    chomp $errmsg;

    $errmsg =~ s/^\s+|\s+$//g;

    next unless $errmsg;

    print "em_warning=$errmsg\n";

  }

}

restore_stderr();

exit 0;

END
{
  close(STDOUT);
}

