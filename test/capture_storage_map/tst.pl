#!/usr/local/bin/perl
# 
# $Header: storage_report_metrics.pl 15-jul-2004.17:28:11 ajdsouza Exp $
#
# Copyright (c) 2004, Oracle. All rights reserved.  
#
#    NAME
#      storage_report_metrics.pl - <one-line expansion of the name>
#
#    DESCRIPTION
#	 Collect metrics for all storage layers and build the storage layout
#        analyze the storage layout
#        instrument the data and keys metrics for the layout
#
#    NOTES
# Things to do
#
# A hash to reach elements in the same order as they were created
#
#
# A key_value identifies an entity on the OS eg. DISK
# An key_value can have multiple instances on the OS eg. BLOCK AND RAW, PHYSICAL AND LOGICAL
# Each instance of an key_value may have one or more paths on the OS
# Two different key_values may refer to the smae physical entity eg. MULTIPATHED DISKS
# key_values for the same physical entity will have the same global_unique_id
# global_unique_ids are required in raw metrics only for the lower most entities in the storage layout , ie for DISKS
# the global unique id for higher level metrics will be generated
#
#    MODIFIED   (MM/DD/YY)
#    ajdsouza    07/14/04 - Fix closed loop for cached filesystems
#    ajdsouza    06/29/04 - Bug fix on line 113
#    ajdsouza    06/25/04 - storage reporting sources 
#    ajdsouza    06/21/04 - Creation
#


BEGIN
    {
	
	#----------------------------------------------------------------------------
	# Save the stderr to restore at the end
	#----------------------------------------------------------------------------
	my $logfile = 'storage_log.txt';
	
	open(OLDERR,">&STDERR") or die "Failed to open STDERR ";
	
	stat($logfile);
	
	# If file exists and not writable
	die "Failed to  write to Log file $logfile " if -e $logfile  and not -w _;
	
	# The database job and host job are excuted at different times in a day
	# check for logfile older than 2days if it exists to make sure its previous
	# the weeks file    
	open(STDERR,"> $logfile") or die "Failed to open Log $logfile "; 
	
    }

use strict;
use warnings;
use storage::Register;

my %storage_columns;
my %storage_layer_hierarchy;
my %storage_entity_hierarchy;

# Keep the keys continuous and starting with 1, this count is used to eliminate the last | and insert the first em_result=
$storage_columns{data} = { 1=>'key_value', 2=>'global_unique_id', 3=>'name' ,4=>'storage_layer', 5=>'em_query_flag', 6=>'entity_type', 7=>'rawsizeb', 8=>'sizeb', 9=>'usedb', 10=>'freeb', 11=>'a1', 12=>'a2', 13=>'a3', 14=>'a4', 15=>'a5', 16=>'a6', 17=>'a7' };
$storage_columns{keys} = { 1=>'key_value', 2=>'parent_key_value' };
$storage_columns{issues} = { 1=>'type', 2=>'message' };
$storage_columns{alias} = { 1=>'key_value', 2=>'value' };

my %metric_column_print_format = (
				  key_value => '%25s', 
				  storage_layer => '%18s', 
				  entity_type => '%18s', 
				  rawsizeb => '%4u', 
				  sizeb => '%4u', 
				  usedb => '%4u',
				  freeb => '%4u',
				  global_unique_id => '%30s',
				  name => '%20s',
				  parent_key_value => '%25s',
				  os_identifier => '%20s',
				  start => '%7u',
				  end => '%7u'
				 );

%storage_layer_hierarchy = (
			    LOCAL_FILESYSTEM => 4,
			    NFS=> 3,
			    VOLUME_MANAGER => 2,
			    OS_DISK => 1);

$storage_entity_hierarchy{LOCAL_FILESYSTEM} = {
			    File => 1,
			    Mountpoint => 2};

my $metric_name = 'data';
my %storage_column_map;

# Add a os strign later on
$storage_column_map{OS_DISK} = {
				a1 => 'vendor',
				a2 => 'product',
				a3 => 'os_identifier'
			       };

$storage_column_map{VOLUME_MANAGER} = {
				       a1 => 'vendor',
				       a2 => 'product',
				       a3 => 'os_identifier',
				       a4 => 'disk_group',
				       a5 => 'configuration'
				      };

$storage_column_map{LOCAL_FILESYSTEM} = {
					 a1 => 'filesystem_type',
					 a2 => 'filesystem',
					 a3 => 'mountpoint'
					};

$storage_column_map{NFS} = {
			    a1 => 'vendor',
			    a2 => 'nfs_srver',
			    a3 => 'filesystem',
			    a4 => 'mountpoint',
			    a5 => 'nfs_server_ip_address',
			    a6 => 'mount_privilege',
			    a7 => 'nfs_server_net_interface_address'			
			   };


my %index_entity_key_value;
my %top_nodes;
my %bottom_nodes;
my %index_global_unique_id;
my %index_indent;
my %index_entities_with_os_path;
my %indent_hash;

#-----------------------------------------------------------------------------------------------------------
# Declare subs
#-----------------------------------------------------------------------------------------------------------
sub dump_raw_metrics_to_file ( $\@ );
sub print_node_data ( $ );
sub np_print_node_in_tree_layout ( $$$ );
sub np_mark_node_indent ( $$$ );
sub np_generate_global_unique_id ( $$ );
sub np_generate_query_flag ( $ );
sub traverse_tree_before_processing_node ( $$\&;\@ );
sub traverse_tree_after_processing_node ( $$\&;\@ );
sub mark_parent_key_values_based_on_key_criteria ( \@ );
sub collect_raw_storage_metrics( \% );
sub generate_parent_child_relationship_for_os_visible_storage_entities( \% );
sub collate_and_build_the_keys_table_for_all_entities( \% );
sub process_collected_storage_metrics( \% );
sub cache_storage_metrics_to_file( \% );
sub generate_storage_metrics ( );
sub display_metrics_from_file( $ );

#-----------------------------------------------------------------------------------------------------------
# TRAVERSAL ROUTINES
#-----------------------------------------------------------------------------------------------------------

sub dump_raw_metrics_to_file ( $\@ )
    {
	
	my ( $file_name,$array_ref ) = @_;
	
	return 1 unless $file_name or $array_ref;

        open(FH,'>',$file_name) or die "Failed to open the file $file_name to dump raw metrics while generating storage metrics\n";
                
	for my $metric_ref ( @$array_ref )
	    {
		
		for my $column ( qw ( key_value storage_layer entity_type rawsizeb sizeb usedb freeb global_unique_id name parent_key_value os_identifier start end ) )
		    {	
			
			printf FH "$metric_column_print_format{$column}",$metric_ref->{$column}/1000000000 and next if $column =~ /sizeb|usedb|free/ and $metric_ref->{$column} and $metric_ref->{$column} =~ /\d+/;
			printf FH "$metric_column_print_format{$column}","$metric_ref->{$column}" and next if  $metric_ref->{$column};
			
			printf FH "$metric_column_print_format{$column}",0 and next if $metric_column_print_format{$column} =~ /u/;
			printf FH "$metric_column_print_format{$column}","-";
			
		    }
		
                print FH "\n";
		
	    }
	
        close(FH) or warn "Failed to close the file $file_name while generating metrics \n" and return 1;

	return 1;
	
    }


sub print_node_data ( $ )
    {
	
	my ( $node ) = @_;
	
	my %prefix = ( sizeb=>'(s', usedb=>'u', freeb=>'f');
	my %suffix = ();
	
	for ( qw ( storage_layer entity_type name key_value sizeb usedb freeb ) )
	    {	
		
		next unless defined $node->{$_};
		
		print " $prefix{$_}$node->{$_}$suffix{$_}" and next if $prefix{$_} and $suffix{$_};	
		
		print " $prefix{$_}$node->{$_}" and next if $prefix{$_};	
		print " $node->{$_}$suffix{$_}" and next if $suffix{$_};	
		print " $node->{$_}";	
	    }
	
	print " ) ";
	
    }

sub np_print_node_in_tree_layout ( $$$ )
    {
	
	my ($node, $traverse_tag , $stack_ref) = @_;
	
	my $indent = @$stack_ref;
	
	for ( 1..$indent )
	    {
		print "|  " and next if $_ < $indent and $indent_hash{$_} and $indent_hash{$_} > 0;
		print "   " and next if $_ < $indent;	
	    }
	
	print "|--->" if $node and $node->{storage_layer};
	
	print_node_data $node if $node and $node->{storage_layer};
	
	print "\n" if $node and $node->{storage_layer};
	
	return 1 if defined $node->{$traverse_tag} and $node->{$traverse_tag} and keys %{$node->{$traverse_tag}};
	
	for ( 1..$indent )
	    {
		print "|  " and next if $_ < $indent and $indent_hash{$_} and $indent_hash{$_} > 0;
		print "   " and next if $_ < $indent;	
	    }		
	
	print "\n";
	
	return 1;
	
    }


sub np_mark_node_indent ( $$$ )
    {
	
	my ( $node, $traverse_tag, $stack_ref ) = @_;
	
	my $indent = @$stack_ref;
	
	warn "Traverse direction is unknown\n" and return unless $traverse_tag =~ /child_node_list|parent_node_list/;
	
	$node->{"$traverse_tag._indent"} = $indent;

	push @{ $index_indent{$traverse_tag}{$indent} }, $node;
	
	return 1;
	
    }


# Keep the peer to peer horizontal relationship between entities which have the same global unique id
#next unless  $index_entity_key_value{$key_value}->{global_unique_id};

#push @{$index_global_unique_id{$index_entity_key_value{$key_value}->{global_unique_id}}} , $index_entity_key_value{$key_value};

# If part of another - partition, subdisk, file then put the start and end blocks
sub np_generate_global_unique_id ($$) 
    {
	
	my ($node, $traverse_tag ) = @_;
	
	warn "Traverse direction is unknown\n" and return unless $traverse_tag =~ /child_node_list|parent_node_list/;
	
	return 1 if $node->{global_unique_id};
	
	return 1 unless $node->{storage_layer};
	
	if ( defined $node->{child_node_list} and $node->{child_node_list} and keys %{$node->{child_node_list}} ) 
	    {
		
		for my $key_value ( sort {$index_entity_key_value{$a}->{global_unique_id} cmp $index_entity_key_value{$b}->{global_unique_id}}  keys %{$node->{child_node_list}} )
		    {
			
			next if defined $index_entity_key_value{$key_value}->{em_query_flag} and $index_entity_key_value{$key_value}->{em_query_flag} =~ /CONTAINER/i;
			
			warn "Global unique ID is null for $key_value while generating gid for $node->{key_value}" and return unless $index_entity_key_value{$key_value}->{global_unique_id};
			
			$node->{global_unique_id} .= "_$index_entity_key_value{$key_value}->{global_unique_id}";
			
		    }
	    }
	
	$node->{global_unique_id} .= "_S$node->{start}" if $node->{start};
	
	$node->{global_unique_id} .= "_E$node->{end}" if $node->{end};
	
	$node->{global_unique_id} = "$node->{target_guid}_$node->{key_value}" unless defined $node->{global_unique_id} and $node->{global_unique_id};
	
	return 1;
	
    }


# Generate the query flags for each entity node
sub np_generate_query_flag ($) 
    {
	
	my ($node) = @_;
	my %query_flag;
	
	# If top most in a layer then TOP
	# if bottom in a layer then BOTTOM
	# if intermediate then INTERMEDIATE
	# if container then CONTAINER
	# if not allocaed then UNALLOCATED
	
	# Flag spares too
	
	return 1 unless $node->{storage_layer};
	
	$query_flag{UNALLOCATED} = 1 , $query_flag{TOP} = 1 unless defined $node->{parent_node_list} and $node->{parent_node_list} and grep !/CONTAINER/, map{ $index_entity_key_value{$_}->{em_query_flag} if defined $index_entity_key_value{$_}->{em_query_flag}} keys %{$node->{parent_node_list}};    
	
	$query_flag{BOTTOM} = 1 unless defined $node->{child_node_list} and $node->{child_node_list} and grep !/CONTAINER/, map{ $index_entity_key_value{$_}->{em_query_flag} if defined $index_entity_key_value{$_}->{em_query_flag} } keys %{$node->{child_node_list}};
	
	if ( defined $node->{parent_node_list} and $node->{parent_node_list} and keys %{$node->{parent_node_list}} ) 
	    {
		
		for my $key_value ( keys %{$node->{parent_node_list}} )
		    {
			
			next if defined $index_entity_key_value{$key_value}->{em_query_flag} and $index_entity_key_value{$key_value}->{em_query_flag} =~ /CONTAINER/;
			
			# ATLEAST one parent from another storage layer
			$query_flag{TOP} = 1 if $index_entity_key_value{$key_value}->{storage_layer} ne $node->{storage_layer};

			last if $query_flag{TOP} and $query_flag{TOP} == 1;
		    }
	    }
	
	if ( defined $node->{child_node_list} and $node->{child_node_list} and keys %{$node->{child_node_list}} ) 
	    {
		
		for my $key_value ( keys %{$node->{child_node_list}} )
		    {
			
			next if defined $index_entity_key_value{$key_value}->{em_query_flag} and $index_entity_key_value{$key_value}->{em_query_flag} =~ /CONTAINER/;
			
			# Atleast one child from another storage layer
			$query_flag{BOTTOM} = 1 if $index_entity_key_value{$key_value}->{storage_layer} ne $node->{storage_layer};

			last if $query_flag{BOTTOM} and $query_flag{BOTTOM} == 1;
		    }
	    }
	
	$query_flag{CONTAINER} = 1 , delete $query_flag{UNALLOCATED} , delete $query_flag{BOTTOM}, delete $query_flag{TOP} if $node->{entity_type} =~ /disk\s*group|disk\s*set|volume\s*group/i;
	
	$query_flag{INTERMEDIATE} = 1 unless defined $query_flag{BOTTOM} or defined $query_flag{TOP};
	
	for my $flag ( sort keys %query_flag )
	    {
	
		$node->{em_query_flag} .= "_$flag" unless defined $node->{em_query_flag} and $node->{em_query_flag} =~ /$flag/;
		
	    }
	
	if ( $node->{em_query_flag} =~ /CONTAINER/ )
	    {
	
		for ( @{$node->{parent_node_list}} , @{$node->{child_node_list}} )
		    {
			generate_query_flag $_ or return;
		    }
	    }
	
	return 1;
	
    }




# Traverse the tree based on the start and tag passed 
# first traverse the nodes and then perform the function on the current node
sub traverse_tree_before_processing_node( $$\&;\@ )
    {
	
	my ($node, $traverse_tag, $node_processing_function_pointer,$stack_ref) = @_;
	
	push @$stack_ref,$node;
	
	my $indent = @$stack_ref;
	
	if ( defined $node->{$traverse_tag} and $node->{$traverse_tag} and keys %{$node->{$traverse_tag}} )
	    {
		
		my $node_count = keys %{$node->{$traverse_tag}} or pop @$stack_ref  and  warn "No $traverse_tag at node $node->{storage_layer} $node->{entity_type} $node->{key_value}\n" and return;
		
		for my $i ( 1..$node_count )
		    {
			
			my $key_value = (keys %{$node->{$traverse_tag}})[$i-1];
			
			my $next_node = $index_entity_key_value{$key_value};
			
			next unless $next_node;
			
			bless $next_node;
			
			$indent_hash{$indent+1} = $node_count-$i;
			
			traverse_tree_before_processing_node($next_node, $traverse_tag, &$node_processing_function_pointer,@$stack_ref) or  pop @$stack_ref and return; 
			
		    }
	    }
	
	$node_processing_function_pointer->($node, $traverse_tag, @$stack_ref) or pop @$stack_ref and return;
	
	pop @$stack_ref;
	
	return 1; 
    }



# Traverse the tree based on the start and tag passed
sub traverse_tree_after_processing_node( $$\&;\@ )
    {

	my ($node, $traverse_tag, $node_processing_function_pointer,$stack_ref) = @_;
	
	push @$stack_ref,$node;    
	
	my $indent = @$stack_ref;    
	
	$node_processing_function_pointer->($node, $traverse_tag, \@$stack_ref ) or pop @$stack_ref and return;
	
	pop @$stack_ref and return 1 unless defined $node->{$traverse_tag} and $node->{$traverse_tag} and keys %{$node->{$traverse_tag}};
	
	my $node_count = keys %{$node->{$traverse_tag}} or pop @$stack_ref and warn "No $traverse_tag at node $node->{storage_layer} $node->{entity_type} $node->{key_value}\n" and return;
	
	for my $i ( 1..$node_count )
	    {
		
		my $key_value = (keys %{$node->{$traverse_tag}})[$i-1];
		
		my $next_node = $index_entity_key_value{$key_value};
		
		next unless $next_node;
		
		bless $next_node;
		
		$indent_hash{$indent+1} = $node_count-$i;
		
		traverse_tree_after_processing_node($next_node, $traverse_tag, &$node_processing_function_pointer,@$stack_ref) or pop @$stack_ref and return; 
		
	    }
	
	pop @$stack_ref;
	
	return 1; 
    }

#--------------------------------------------------------------------------------------------------------------

#-----------------------------------------------------------------------------------------
# FUNCTION :  mark_parent_key_values_based_on_key_criteria
#
# DESC 
# Mark the parent_key_values for entities based on any parent or child key criteria defined
# Returns a reference to an array of pointers to disk metric data as required by EM
#
# ARGUMENTS
# array of the pointer to the metric hashes generated fro OEM 9I
#
#-----------------------------------------------------------------------------------------
sub mark_parent_key_values_based_on_key_criteria ( \@ )
    {
	
	my ( $storage_entities_ref ) = @_;
	
	# Mark the parent_key_values for entities based on any parent or child key criteria defined
	for my $entity_ref ( @{$storage_entities_ref} ) 
	    {
		
		# build the child to parent hash for the entity if the parent_key criteria is defined 
		if ( $entity_ref->{parent_entity_criteria} and @{$entity_ref->{parent_entity_criteria}} ) 
		    {
			
			for my $parent_entity_criteria_ref ( @{$entity_ref->{parent_entity_criteria}} ) 
			    {
				
				next unless keys %{$parent_entity_criteria_ref};
				
				for my $mdref ( @{$storage_entities_ref} )
				    {
					
					next if $entity_ref->{list_of_parent_key_values} and @{$entity_ref->{list_of_parent_key_values}} and grep { $_ eq $mdref->{key_value} } @{$entity_ref->{list_of_parent_key_values}};
					
					my @values = map { 'FAILED_PARENT_CHILD_ENTITY_CRITERIA' unless $mdref->{$_} and $mdref->{$_} eq $parent_entity_criteria_ref->{$_}} keys %{$parent_entity_criteria_ref};
					
					next if grep /FAILED_PARENT_CHILD_ENTITY_CRITERIA/,@values;
					
					push @{$entity_ref->{list_of_parent_key_values}},$mdref->{key_value};
				    }
			    }
		    }
		
		
		# build the parent to child hash for the entity if the child_key criteria is defined 	
		if ( $entity_ref->{child_entity_criteria} and keys %{$entity_ref->{child_entity_criteria}} ) 
		    {
			
			for my $child_entity_criteria_ref ( @{$entity_ref->{child_entity_criteria}} ) 
			    {
				
				next unless keys %{$child_entity_criteria_ref};
		
				for my $mdref ( @{$storage_entities_ref} )
				    {
										
					next if $mdref->{list_of_parent_key_values} and @{$mdref->{list_of_parent_key_values}} and grep { $_ eq $entity_ref->{key_value} } @{$mdref->{list_of_parent_key_values}};
					
					my @values = map { 'FAILED_PARENT_CHILD_ENTITY_CRITERIA' unless $mdref->{$_} and $mdref->{$_} eq $child_entity_criteria_ref->{$_}} keys %{$child_entity_criteria_ref};
					
					next if grep /FAILED_PARENT_CHILD_ENTITY_CRITERIA/,@values;		    		    
					
					push @{$mdref->{list_of_parent_key_values}},$entity_ref->{key_value};
				    }
			    }
		    }
		
	    }
	
	my @list_of_entities =  @{$storage_entities_ref};
	
	# For each child entity, add a child entity row for each parent , mark the child rows parent_key_value to the key_value of the parent
	for my $entity_ref ( @list_of_entities )
	    {
	
		next unless $entity_ref->{list_of_parent_key_values} and @{$entity_ref->{list_of_parent_key_values}};
	
		for my $parent_key_value ( @{$entity_ref->{list_of_parent_key_values}} )
		    {
			
			my %entity_hash = %{$entity_ref};
			
			$entity_hash{parent_key_value} = $parent_key_value;
			
			push @{$storage_entities_ref}, \%entity_hash;
			
		    }		
	    }
	
	return  $storage_entities_ref;
	
    }



sub collect_raw_storage_metrics( \% ) 
    {
	
	my ( $storage_data_ref ) = @_;
	
	# Get List of functions to execute in the top down order, store this order as the hierarchy for storage layers here
	# Loop thru them and execute them and store the results in the array
	# Process the array
	
	my $array_of_metrics_hash_refs_from_function;	
	my %list_of_storage_metric_functions = ( 3=> \&storage::Register::get_disk_metrics , 2 => \&storage::Register::get_virtualization_layer_metrics, 1 => \&storage::Register::get_filesystem_metrics );
	my @all_metric_data;

	for my $function_order ( sort {$a cmp $b}  keys %list_of_storage_metric_functions )
	    {
		# How to handle stdout		
		$array_of_metrics_hash_refs_from_function = $list_of_storage_metric_functions{$function_order}->() or warn "Failed to execute function at $function_order" and return;
		
		mark_parent_key_values_based_on_key_criteria( @$array_of_metrics_hash_refs_from_function ) or warn "Failed to mark the parent_key_values for metric $function_order" and return;
	
		push @all_metric_data, @$array_of_metrics_hash_refs_from_function if $array_of_metrics_hash_refs_from_function and @$array_of_metrics_hash_refs_from_function;
	    }
	
	dump_raw_metrics_to_file 'storage_raw_metrics_dump.log',@all_metric_data or return;
	
	for my $metric_hash_data_ref ( @all_metric_data )
	    {
		
		for my $key_value ( keys %$metric_hash_data_ref  )
		    {
			
			next unless $metric_hash_data_ref->{$key_value};
			
			$metric_hash_data_ref->{$key_value} =~ s/^\s+|\s+$//g;
			
			$metric_hash_data_ref->{$key_value} =~ s/^-+$//g;	
			
			$metric_hash_data_ref->{$key_value} =~ s/-/ /g if $key_value =~ /etity_type/i;
			
		    }
		
		# ERROR If there is NO entry in key master for node
		die "key_value cannot be null in key map " and exit unless $metric_hash_data_ref->{key_value};
		
		$metric_hash_data_ref->{key_value} = "$metric_hash_data_ref->{storage_layer}_$metric_hash_data_ref->{key_value}";
		$metric_hash_data_ref->{parent_key_value} = "$metric_hash_data_ref->{storage_layer}_$metric_hash_data_ref->{parent_key_value}" if $metric_hash_data_ref->{parent_key_value};
		
		# What about entities that cannot be recognized on the OS but can be shared across Layers, like what ??? - Disks on a windows NT box !!
		#
		# index <key_value><os_identifier>=ref
		# index <os_identifier><key_value>=ref
		$index_entities_with_os_path{key_value}{$metric_hash_data_ref->{key_value}}{$metric_hash_data_ref->{os_identifier}} = $metric_hash_data_ref,$index_entities_with_os_path{os_identifier}{$metric_hash_data_ref->{os_identifier}}{$metric_hash_data_ref->{key_value}} = $metric_hash_data_ref if $metric_hash_data_ref->{os_identifier};
		
		# index <key_value>=ref
		$index_entity_key_value{$metric_hash_data_ref->{key_value}} = $metric_hash_data_ref unless $index_entity_key_value{$metric_hash_data_ref->{key_value}};

		# storage @<key_value>,<parent_key_value>
		push @{$index_entity_key_value{$metric_hash_data_ref->{key_value}}->{parent_keys}}, $metric_hash_data_ref->{parent_key_value} if $metric_hash_data_ref->{parent_key_value};
		
		# storage @data,ref
		push @{$storage_data_ref->{data}}, $metric_hash_data_ref if $index_entity_key_value{$metric_hash_data_ref->{key_value}} == $metric_hash_data_ref;
	
	    }
	
	return 1;
	
    }


# Interlink between the entities across different storage layers that are represented on the OS
sub generate_parent_child_relationship_for_os_visible_storage_entities( \% ) 
    {
	
	my ( $storage_data_ref ) = @_;
	
	# Loop theu the entities which have as os identifier and build a list of entities to an entity_identifier
	#
	# Read from index <os_identifier><key_value>=ref
	for my $os_path( keys %{$index_entities_with_os_path{os_identifier}} )
	    {
	
		for my $key_value( keys %{$index_entities_with_os_path{os_identifier}{$os_path}} )
		    {
			# Be more linient on this return os_path if either of these functions fail
			my $os_storage_entity_name = storage::Register::get_os_storage_entity_path($os_path) or warn "Failed to get the OS storage entity name $os_path" and return;
			
			my $entity_identifier =  storage::Register::get_os_identifier_for_os_path ($os_storage_entity_name) or warn "Failed to get the os identifier for storage entity name $os_storage_entity_name" and return;
							
			# ref->{entity_identifier}=@entity_identifiers
			push @{$index_entity_key_value{$key_value}->{entity_identifier}},$entity_identifier;
			
			# index @<identifier>,ref
			push @{$index_entities_with_os_path{list_of_entities_for_identifier}{$entity_identifier}},$index_entity_key_value{$key_value};
			
			# BUild the alias metric for each os path for a key_value
			# @{storage->{alias}} = ref
			push @{$storage_data_ref->{alias}}, {key_value=>$key_value,value=>$os_path} if $key_value and $os_path;
		    }
	    }
	
	# loop thru the entities which have an os_identifier and find entities in another storage layaer which have the same entitiy identifier
	# Read from <key_value><os_identifier>-ref
	for my $key_value ( keys %{$index_entities_with_os_path{key_value}} )
	    {
		
		# There should be an identifier for this os path
		warn "Failed to find an identifier on the OS for $index_entity_key_value{$key_value}->{os_identifier} "  and return unless @{$index_entity_key_value{$key_value}->{entity_identifier}};
		
		for my $entity_identifier ( @{$index_entity_key_value{$key_value}->{entity_identifier}} )
		    {
			
			# Get all entities with the same identifier as this one
			# build the list storage_data @{parent_key}<child_key_value>,<parent_key_value>
			#
			for my $os_id_storage_data_ref( @{$index_entities_with_os_path{list_of_entities_for_identifier}{$entity_identifier}} )
			    {	
				# The other entity with the same identifier should be in a different storage layer than the $key_value entity
				#next unless $os_id_storage_data_ref->{storage_layer} ne $index_entity_key_value{$key_value}->{storage_layer};
				# Lets map within the os visible entities in a storage layer
				next unless $os_id_storage_data_ref->{key_value} ne $key_value;

				warn "No hierarchy defined for layers " and next unless $storage_layer_hierarchy{$index_entity_key_value{$key_value}->{storage_layer}} and $storage_layer_hierarchy{$os_id_storage_data_ref->{storage_layer}};
				# The parent_key for the entity in the lower storage layer should have a list of key_values of the entity higher storage layers
				# Disk < Volume < Filesystem < File
				push @{$index_entity_key_value{$key_value}->{parent_keys}},$os_id_storage_data_ref->{key_value} and next if $storage_layer_hierarchy{$index_entity_key_value{$key_value}->{storage_layer}} <  $storage_layer_hierarchy{$os_id_storage_data_ref->{storage_layer}};
				
				push @{$index_entity_key_value{$os_id_storage_data_ref->{key_value}}->{parent_keys}},$index_entity_key_value{$key_value}->{key_value} and next if $storage_layer_hierarchy{$index_entity_key_value{$key_value}->{storage_layer}} >  $storage_layer_hierarchy{$os_id_storage_data_ref->{storage_layer}};

				# If the parent and child are in the same layer then
				
				# Do not map within a layer if hierarchy is not defined for both the layers
				next unless $storage_entity_hierarchy{$index_entity_key_value{$key_value}->{storage_layer}}{$index_entity_key_value{$key_value}->{entity_type}} and $storage_entity_hierarchy{$os_id_storage_data_ref->{storage_layer}}{$index_entity_key_value{$key_value}->{entity_type}};
				
				# DO a special check for filesystems which are cached on another filesystem mountpoint
				# The child mountpoint for a filesystem based on another mountpoint should be the mountpoint which has a special file as its filesystem 
				next if $index_entity_key_value{$key_value}->{storage_layer} eq 'LOCAL_FILESYSTEM' and $index_entity_key_value{$key_value}->{entity_type} eq 'File' and $index_entity_key_value{$key_value}->{parent_key_value} and $index_entity_key_value{$key_value}->{parent_key_value} eq $os_id_storage_data_ref->{key_value};

				next if $index_entity_key_value{$key_value}->{storage_layer} eq 'LOCAL_FILESYSTEM' and $os_id_storage_data_ref->{entity_type} eq 'File' and $os_id_storage_data_ref->{parent_key_value} and $os_id_storage_data_ref->{parent_key_value} eq $key_value;

				# If parent key for the lower entity should have the list of key values of the higher entity
				push @{$index_entity_key_value{$key_value}->{parent_keys}},$os_id_storage_data_ref->{key_value} and next if $storage_entity_hierarchy{$index_entity_key_value{$key_value}->{storage_layer}}{$index_entity_key_value{$key_value}->{entity_type}} >  $storage_entity_hierarchy{$os_id_storage_data_ref->{storage_layer}}{$os_id_storage_data_ref->{entity_type}};
				
				push @{$index_entity_key_value{$os_id_storage_data_ref->{key_value}}->{parent_keys}},$index_entity_key_value{$key_value}->{key_value} and next if $storage_entity_hierarchy{$index_entity_key_value{$key_value}->{storage_layer}}{$index_entity_key_value{$key_value}->{entity_type}} < $storage_entity_hierarchy{$os_id_storage_data_ref->{storage_layer}}{$os_id_storage_data_ref->{entity_type}};

				
			       }
			
		    }
	    }
	
	return 1;
	
    }


# index <key_value><os_identifier>=ref
# index <os_identifier><key_value>=ref
# index <key_value>=ref
# index <os_path>=identifier
# index @<identifier>,ref

# storage @data,ref
# storage @{parent_key}<child_key_value>,<parent_key_value>
# storage @<key_value>,<parent_key_value>

sub collate_and_build_the_keys_table_for_all_entities(\%)
    {
	
	my ( $storage_data_ref ) = @_;
	my %index_child_to_parent_key_hash;
	
	# Loop thru each child key_value in storage @{parent_key}<child_key_value>,<parent_key_value>
	for my $child_key_value ( keys %index_entity_key_value ) 
	    {
		
		# ERROR If there is NO entry in key master for node
		die "key_value cannot be null in key map " and return unless $child_key_value;
		
		# Loop thru List of parents from storage @{parent_keys}<child_key_value>,<parent_key_value>
		for my $parent_key_value ( @{$index_entity_key_value{$child_key_value}->{parent_keys}} )
		    {
			
			# ERROR If there is a parent node and if there is NO entry in key master for parent node
			die " Unable to find the entry in key master for parent node $parent_key_value " and return unless $parent_key_value and defined $index_entity_key_value{$parent_key_value};
			
			# Build the keys array for reporting
			#
			# index {parent_to_child_map}<key_value><parent_key_value>
			# storage @keys,ref {child_key_value, parent_key_value}
			
			# Do not relist the child_key , parent_key again, this is a unique key in the mgmt_storage_report_keys table
			next if $index_child_to_parent_key_hash{$child_key_value} and $index_child_to_parent_key_hash{$child_key_value}{$parent_key_value};
			$index_child_to_parent_key_hash{$child_key_value}{$parent_key_value} = 1;
			
			# The list of keys to be instrumented
			push @{$storage_data_ref->{keys}}, {key_value=>$child_key_value, parent_key_value=>$parent_key_value};
			
			# Keep the parent to child relationship between the parent node and child node for top down traversal
			$index_entity_key_value{$parent_key_value}->{child_node_list}{$child_key_value} = 1;
			
			# Keep the child to parent relationship between the parent node and child node for bottom up traversal
			$index_entity_key_value{$child_key_value}->{parent_node_list}{$parent_key_value} = 1;
			
		    }
		
		# Make sure each key_value has an entry in the list of keys, if it doesnt then it has no parent or its a top enity in the tree
		# For a top entity set the parent_key_value to be the same as key_value. key_value and parent_key_value form the primary key 	
	push @{$storage_data_ref->{keys}}, {key_value=>$child_key_value, parent_key_value=>$child_key_value} unless $index_child_to_parent_key_hash{$child_key_value} and keys %{$index_child_to_parent_key_hash{$child_key_value}};
		
	    }
	
	return 1;
	
    }


sub process_collected_storage_metrics(\%) 
    {
	
	my ( $storage_data_ref ) = @_;
	
	generate_parent_child_relationship_for_os_visible_storage_entities(%$storage_data_ref) or return;
	
	collate_and_build_the_keys_table_for_all_entities(%$storage_data_ref) or return;
	
	# From the node List get the nodes which are the bottom ones, ones with no children	
	for my $node ( values %index_entity_key_value  ) 
	    {
		
		# If there is no parent node then this is a top node
		$top_nodes{child_node_list}{$node->{key_value}} = 1 unless defined $node->{parent_node_list} and $node->{parent_node_list} and keys %{$node->{parent_node_list}};
		
		# If there are no children then this is a bottom node
		$bottom_nodes{parent_node_list}{$node->{key_value}} = 1  unless defined $node->{child_node_list} and $node->{child_node_list} and keys %{$node->{child_node_list}};
		
	    }
	
	traverse_tree_after_processing_node \%top_nodes ,'child_node_list',&np_mark_node_indent or die "Failed to mark child tree indent";
	traverse_tree_after_processing_node \%bottom_nodes ,'parent_node_list',&np_mark_node_indent or die "Failed to mark parent tree indent";
	traverse_tree_before_processing_node \%top_nodes ,'child_node_list',&np_generate_global_unique_id or die "Failed to generate the global unique_id for all nodes in the storage tree";
	traverse_tree_before_processing_node \%top_nodes ,'child_node_list',&np_generate_query_flag or die "Failed to generate the global unique_id for all nodes in the storage tree";
	
	# Print the tree top down
	#traverse_tree_after_processing_node \%top_nodes  ,'child_node_list',&np_print_node_in_tree_layout or die "Failed to print the tree ";
	# Print the tree bottom up 
	#traverse_tree_after_processing_node \%bottom_nodes ,'parent_node_list',&np_print_node_in_tree_layout or die "Failed to mark parent tree indent";
	
	return 1;
	
    }



sub cache_storage_metrics_to_file(\%)
    {
	
	my ( $storage_data_ref ) = @_;
	
	for my $metric_name( qw ( data keys issues alias ) )
	    {
		
		open(FH,'>',"storage_host_$metric_name") or die "Failed to open the mapfile storage_host_$metric_name while generating metrics\n";
		
		print FH "columns=";
		
		for my $column_order ( sort {$a <=> $b} keys %{$storage_columns{$metric_name}} )
		    {
			print FH "$storage_columns{$metric_name}{$column_order}|";
		    }
		
		print FH "\n";
		
		close(FH) and next unless $storage_data_ref->{$metric_name};
		
		for my $row ( @{$storage_data_ref->{$metric_name}} )
		    {
			
			for my $column_order ( sort {$a <=> $b} keys %{$storage_columns{$metric_name}} )
			    {
				
				print FH "$row->{$storage_column_map{$row->{storage_layer}}{$storage_columns{$metric_name}{$column_order}}}|" and next if $row->{storage_layer} and $storage_column_map{$row->{storage_layer}}{$storage_columns{$metric_name}{$column_order}} and $row->{$storage_column_map{$row->{storage_layer}}{$storage_columns{$metric_name}{$column_order}}};
				
				print FH "$row->{$storage_columns{$metric_name}{$column_order}}|" and next if $row->{$storage_columns{$metric_name}{$column_order}};
				
				print FH "|" unless $column_order == keys % {$storage_columns{$metric_name}};;
			    }
			
			print FH "\n";
		    }
		
		close(FH) or warn "Failed to close the file storage_host_$metric_name while generating metrics \n" and return;
	
	    }
	
	return 1;
	
    }


sub generate_storage_metrics() 
    {
	
	my %storage_data;
	
	collect_raw_storage_metrics(%storage_data) or return;
	
	process_collected_storage_metrics(%storage_data) or return;
	
	cache_storage_metrics_to_file(%storage_data) or return;
	
	return 1;
    }



sub display_metrics_from_file($)
    {
	
	my ( $metric_name) = @_;
	
	open(FH,"storage_host_$metric_name") or die "Failed to open the mapfile for storage_host_$metric_name while reading metrics\n";
	
	my @columns;
	my @data;
	
	while ( <FH> )
	    {
		
		my %row;
		
		chomp;
	
		s/^\s+|\s+$//g;
		
		@columns = split /\|/,substr $_ , length('columns=') and next if $_ =~ /^columns=/;
		
		my @values = split /\|/;
		
		@row{ @columns } = @values;
		
		push @data,\%row;    
	    }
	
	close(FH) or warn "Failed to close the file storage_host_$metric_name while reading metrics\n";
	
	for my $row ( @data )
	    {
		
		for my $column_order ( sort {$a <=> $b} keys % {$storage_columns{$metric_name}} )
		    {

			print "em_result=" if $column_order == 1;	    
			print "$row->{$storage_columns{$metric_name}{$column_order}}" if $row->{$storage_columns{$metric_name}{$column_order}};
			print "|" unless $column_order == keys % {$storage_columns{$metric_name}};
			
		    }
		
		print "\n";
	    }
	
	return 1;
	
    }

print " ARGV[0] \n";

warn " ARGV[0] :os_entity \n";
#----------------------------------------------------------------------------
# Restore STDERR
#----------------------------------------------------------------------------
close(STDERR);

open(STDERR,">&OLDERR") or warn " Failed to restore STDERR \n";

close(OLDERR);

exit 0;

# Read the metric to be instrumented, the default is data for storage_report_data metric
$metric_name = $ARGV[0] if $ARGV[0];

# remove leading or trailing blanks
$metric_name =~ s/\s//g;

# default storage_reportic metric is data for storage_report_data
$metric_name = 'data' unless $metric_name;

die "Unsupported storage_report metric $metric_name" unless $metric_name =~ /^(data|keys|issues|alias)$/;

# The storage_report_data metric will always cache fresh data to the files.
# The keys and issues metrics will read the cached data if it exists , if no cached files exist they will generate all metrics and cache the metrics

generate_storage_metrics or die " Failed to generate storage metrics for $metric_name"  if $metric_name =~ /^data$/ or not -e "storage_host_$metric_name";

display_metrics_from_file($metric_name) or die "Failed to read storage metrics for $metric_name from file";

#----------------------------------------------------------------------------
# Restore STDERR
#----------------------------------------------------------------------------
close(STDERR);

open(STDERR,">&OLDERR") or warn " Failed to restore STDERR \n";

close(OLDERR);

exit 0;
