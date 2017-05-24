#
# Copyright  (c) 2001,2002  Oracle Corporation All rights reserved 
#
#  $Id: Upload.pm,v 1.49 2003/10/10 00:38:58 ajdsouza Exp $ 
#
#
# NAME  
#	 Upload.pm
#
# DESC 
#  	Load metrics from the target host to the 9I Repository	
#
# FUNCTIONS
#
# loadMetric($$)   -  Collect the metric data for the metric name passed and load it into the repository
# loadData(\%\@) -  Function Loads data into the mgmt_current_metric Table in 9IEM Repository
#
#
# NOTES
#
#
# MODIFIED	(MM/DD/YY)
# ajdsouza	04/22/02 - Change script file names to lower case
# ajdsouza	04/11/02 - Use DBI from Oraperl
# ajdsouza	04/10/02 - Created from stormon_upload9i.pl - to meet GIT standards
# ajdsouza	04/09/02 - Commit after delete and insert
#			   For DBs delete on key_value
#			   Reformat error messages
# ajdsouza	04/04/02 - For databases get node_name from smp_view_targets
# ajdsouza	04/01/02 - Created
#
#
#

package Monitor::Upload;

require v5.6.1;
use strict;
use warnings;
use Monitor::Utilities;
use Monitor::Storage;

#-------------------------------------------------------------------------
# Have BEGIN before use so its executed at compile time 
# before use DBI

BEGIN{
# Set Oracle_home for DBI
    $ENV{ORACLE_HOME}="/usr/local/git/oracle"; 
}

#------------------------------------------------------------------------
use DBI;
#------------------------------------------------------------------------
our @ISA = qw(Exporter);
our @EXPORT = qw(loadMetric);

#-------------------------------------------------------------------------
#  Declare subs
sub loadData( \%\@ );
sub loadMetric;

#--------------------------------------------------------------------------
# FUNCTION : loadMetric
# 
#
# DESC
# Collect and load the metric data and load into the repository 
#
# ARGUMENTS
#
#--------------------------------------------------------------------------

# Hash of metrics to be collected for a target type
# Get metrics from top down, So all entities at a higher level are accounted
# for (INtegrity check in PL/SQL)
# This is assuming that space is generally added to the system than the other 
# way about
# 
my %metrics = (
	       oracle_sysman_node        => [
					     qw(
						storage_filesystems
						storage_volume_layers
						storage_swraid
						disk_devices					
						)
					     ],
	       oracle_sysman_database => [
					  qw(storage_applications)
					  ]
	       );

# Hash of functions to be executed to collect a metric
my %metricscript = (
		    storage_applications => \&apps,
		    storage_filesystems => \&files,
		    storage_volume_layers => \&volumes,
		    storage_swraid => \&swraid,
		    disk_devices => \&disks
		    );

# Repository DB connection timeout and retry values in secs
my $rep_db_timeout  = 10;   #timeout secs
my $rep_db_retry    = 3;    #number of retries
my $rep_db_waittime = 60;   #wait time before retry

# Field and row seperators in the metric buffer
my $row_seperator = '!!!';
my $field_seperator = '~~'; 
my $sql_buffer_size = 32000;

sub loadMetric
{
	
    my $dbh;
    my %rows;
    my %loadparam;
    my %dbh;

    #--------------------------------------------------------------------------
    # Check for repository Connection Credentials 
    #---------------------------------------------------------------------------
    warn "ERROR:Repository connection credentials not passed in %ENV \n" and return unless $ENV{UPLOAD_DB_USER} and $ENV{UPLOAD_DB_PASSWORD} and $ENV{UPLOAD_DB_TNS};

    #--------------------------------------------------------------------------
    # check Target Credentials 
    #--------------------------------------------------------------------------   
    warn "ERROR: Target credentials not passed in %ENV \n" and return unless $ENV{EM_TARGET_NAME} and  $ENV{EM_TARGET_TYPE};

    warn "ERROR: Unsupported target_type $ENV{EM_TARGET_TYPE} for $ENV{EM_TARGET_NAME}\n" and return if  $ENV{EM_TARGET_TYPE} !~ /oracle_sysman_node|oracle_sysman_database/i;

    $loadparam{target} = $ENV{EM_TARGET_NAME};
    $loadparam{type}   = $ENV{EM_TARGET_TYPE};
	       	   	   
    #---------------------------------------------------------------------------
    # set environment to print in 9I format
    #---------------------------------------------------------------------------
    $ENV{'EMD_PRINT_ENV'}= '9I';
    
    #---------------------------------------------------------------------------
    # Get the local collection timestamp for these metrics
    # Format local time as mm:dd:yyyy hh24:mi:ss
    #---------------------------------------------------------------------------
    my ($sec,$min,$hr,$daymon,$mon,$yr,@args)= localtime(time);
    $mon += 1;
    $yr += 1900;
    
    $loadparam{ts} = sprintf("%02d:%02d:%d %02d:%02d:%02d" , $mon , $daymon, $yr, $hr, $min, $sec);
    
    
    #-----------------------------------------------------------------------------
    # Execute script for each metric for a target
    #-----------------------------------------------------------------------------        
    for my $metricname ( @{$metrics{$ENV{EM_TARGET_TYPE}}} ){
	
	warn "\nDEBUG:\t\t Collecting  Metric $metricname \n\n";
	$rows{$metricname} 	=  [&{$metricscript{$metricname}}];
	
    }

    #---------------------------------------------------------------------------
    # Connect to the Respository Database
    #---------------------------------------------------------------------------
    warn "\nDEBUG:\t\t Connecting to the repository to upload the collected metrics for target $ENV{EM_TARGET_NAME}\n\n";
    %dbh = dbconnect($ENV{UPLOAD_DB_USER},$ENV{UPLOAD_DB_PASSWORD},$ENV{UPLOAD_DB_TNS},$rep_db_timeout,$rep_db_retry,$rep_db_waittime) 
	or 
	warn "\nERROR: Failed to get a connection to the repository. aborting job \n" 
	and return;
    
    %loadparam = ( %loadparam , %dbh );
    
    #----------------------------------------------------------------------------
    # Load metric data into the repository
    #----------------------------------------------------------------------------
    warn "\nDEBUG:\t\tLoading metric data to the repository \n\n";
    
    for my $metricname ( @{$metrics{$ENV{EM_TARGET_TYPE}}} ) {
	
	$loadparam{metric} = $metricname;
	
	warn "\nDEBUG:\t\tLoading metric $loadparam{metric} \n\n";
	
	loadData( %loadparam ,@{$rows{$metricname}}) or 
	    $dbh{dbh}->rollback and $dbh{dbh}->disconnect and 
	    warn "\nERROR: LOAD FAILED for $metricname  Rolling Back and aborting the load at TIMESTAMP=$loadparam{ts}\n" and return;
	
	#----------------------------------------------------------------------------
	# Commit all the transaction for this load
	#----------------------------------------------------------------------------
	$dbh{dbh}->commit 
	    or $dbh{dbh}->rollback and $dbh{dbh}->disconnect and 
	    warn "ERROR:COMMIT FAILED for $metricname aborting the load at TIMESTAMP=$loadparam{ts} \n" and return;       	
	
    }
        
    # Disconnect from the database 
    $dbh{dbh}->disconnect;
    
}



#-----------------------------------------------------------------------------
#
# FUNCTION  : loaddata
#
# DESC
# Function Loads data into the mgmt_current_metric Table in 9IEM Repository
#
#
# ARGUMENTS
#
# Hash containing 
# 	DB Login Identifier
# 	Metric Timestamp
# 	Target Name
# 	TArget Type
# 	Metric NAme
# Listof rows to be loaded formatted as (metric_column,key,value)
#
#-----------------------------------------------------------------------------

sub loadData(\%\@)
{
    my $sql;
    my $sth;
    my %metrichash;
    my $rows_deleted = 0;
  #  my $rowsdeleted = 0;
    my %lst;
    my $ref;

    # Validate input
    for ( qw( dbh metric target type ts ) )
    {
	warn " $_ Not defined  " and return 
	    unless ${$_[0]}{$_};
    }
    
    my %loadparam = %{$_[0]};
    my @metricdata  = @{$_[1]};
    
    #-----------------------------------------------------------------------------
    # Get targetid for this targetname, targettype from smp_vdt_target
    #
    # For databases get the node name from smp_view_targets and then fetch target_id
    # from smp_vdt_target
    #-----------------------------------------------------------------------------
    
    if ( $loadparam{type} =~ /oracle_sysman_node/i )
    {
	$sql = "SELECT 	TARGET_ID , TARGET_TYPE 
				FROM 	MGMT_TARGETS 
				WHERE	TARGET_NAME = :1 AND TARGET_TYPE =  :2";
    }	
    elsif ( $loadparam{type} =~ /oracle_sysman_database/i )
    {	
	$sql = "SELECT 	TARGET_ID , TARGET_TYPE 
				FROM 	MGMT_TARGETS 
				WHERE 	TARGET_NAME IN 
                                 ( SELECT NODE_NAME 
				 FROM SMP_VIEW_TARGETS 
				WHERE TARGET_NAME = :1 AND TARGET_TYPE =  :2 )"; 
    }
    else	
    {
	warn "ERROR : Unsupported Targettype $loadparam{type} \n" 
	    and return;
    }
    
    $loadparam{dbh}->{FetchHashKeyName} = 'NAME_lc';
    
    $sth = $loadparam{dbh}->prepare($sql) or return;
	
    $sth->execute($loadparam{target},$loadparam{type}) or return;
 
    $ref = $sth->fetchrow_hashref;

    warn "ERROR : $sql fetch :: ".$sth->errstr." \n" and return if $sth->err;
    
    warn  "ERROR: Targetid NOT FOUND for $loadparam{target} $loadparam{type} \n"  and return
	if not $ref;

    my %target = %{$ref};
        
    $sth->finish or return;
    
    warn "ERROR : Targetid NOT FOUND for $loadparam{target} $loadparam{type} \n" 
	and return 
	unless $target{target_id} and $target{target_type};
    
    
    #--------------------------------------------------------------------------------
    # Build a hashlist of metric_column, metric_guid for this metric from mgmt_targets
    #--------------------------------------------------------------------------------
    
    $sql = "SELECT METRIC_COLUMN, METRIC_GUID FROM MGMT_METRICS WHERE METRIC_NAME = :1 AND TARGET_TYPE = :2";
        
    $sth = $loadparam{dbh}->prepare($sql) or return;
    
    $sth->execute($loadparam{metric},$target{target_type}) or return;

    $ref = $sth->fetchall_hashref('metric_column');

    warn "ERROR : $sql fetch :: ".$sth->errstr."\n" and return if $sth->err;
    
    warn "ERROR : Metric Columns NOT FOUND for $loadparam{metric} \n" 
	and return if not $sth->rows or not $ref;   

    %lst = %{$ref};
       
    warn "DEBUG: Metric Columns fetched for $loadparam{metric} = ".$sth->rows."\n";
    
    %metrichash = map { $_ => $lst{$_}->{metric_guid} } keys %lst;
    
    $sth->finish or return;
    
    #-----------------------------------------------------------------------------------
    # Delete the last uploaded metrics from mgmt_current_metrics and commit the deletion
    #-----------------------------------------------------------------------------------
    # Delete all the data for a metric from mgmt_current_metrics if target_type is host
    
    if ( $loadparam{type} =~ /oracle_sysman_node/i ) {
	
	$sth = $loadparam{dbh}->prepare('
                                 DECLARE
                                     l_count    INTEGER;
                                 BEGIN
                                     l_count := STORAGE_SUMMARY_LOAD.DELETE_HOST_METRICS(?,?,?);
                                     ? := l_count;
                                 END;') or return ;
	
	$sth->bind_param(1,$target{target_id}) or warn "ERROR: Failed to bind the target_id argument for target $loadparam{target} for metric $loadparam{metric}\n" and return;
	$sth->bind_param(2,$target{target_type}) or warn "ERROR: Failed to bind the target_id argument for target $loadparam{target} for metric $loadparam{metric}\n" and return;
	$sth->bind_param(3,$loadparam{metric}) or warn "ERROR: Failed to bind the target_id argument for target $loadparam{target} for metric $loadparam{metric}\n" and return;
	$sth->bind_param_inout(4,\$rows_deleted,1000) or warn "ERROR: Failed to bind the delete_rows argument for target $loadparam{target} for metric $loadparam{metric}\n" and return;
	
    }
    elsif ( $loadparam{type} =~ /oracle_sysman_database/i ) {
	#-----------------------------------------------------------------------------------
	# Delete all data for target_id for current application_id
	#-----------------------------------------------------------------------------------
	# We should also add a cleanup for databases not in the master table
	# It can be done in the repository during computation of summary

	warn "ERROR : metric_guid not found for metric storage_applications_id for target $loadparam{target}\n" and return unless $metrichash{storage_applications_id};
	
	my $applicationid;	
	
	# Get the application ID for this application metric
	for ( @metricdata ) {
	    
	    chomp;
	    
	    my @fields = split /$field_seperator/;
	    
	    $applicationid = $fields[2] and last if $fields[0] =~ /storage_applications_id/i;
	}
	
	warn "ERROR : Unable to obtain the application id for unserting data for target $loadparam{target} for metric $loadparam{metric} \n" and return unless $applicationid;

	$sth = $loadparam{dbh}->prepare('
                                 DECLARE
                                   l_count      INTEGER;
                                 BEGIN
                                    l_count := STORAGE_SUMMARY_LOAD.DELETE_DATABASE_METRICS(?,?,?,?,?);
                                    ? := l_count;
                                 END;') or return ;
	
	$sth->bind_param(1,$target{target_id}) or warn "ERROR: Failed to bind the target_id argument for target $loadparam{target} for metric $loadparam{metric}\n" and return;
	$sth->bind_param(2,$target{target_type}) or warn "ERROR: Failed to bind the target_id argument for target $loadparam{target} for metric $loadparam{metric}\n" and return;
	$sth->bind_param(3,$loadparam{metric}) or warn "ERROR: Failed to bind the target_id argument for target $loadparam{target} for metric $loadparam{metric}\n" and return;
	$sth->bind_param(4,$metrichash{storage_applications_id}) or warn "ERROR: Failed to bind the application_id metric_guid argument for target $loadparam{target} for metric $loadparam{metric}\n" and return;
	$sth->bind_param(5,$applicationid) or warn "ERROR: Failed to bind the application_id value argument for target $loadparam{target} for metric $loadparam{metric}\n" and return;
	$sth->bind_param_inout(6,\$rows_deleted,1000) or warn "ERROR: Failed to bind the delete_rows argument for target $loadparam{target} for metric $loadparam{metric}\n" and return;
		
    }
    else {
	warn "ERROR: Unsupported target_type $loadparam{type} passed for target $loadparam{target} for metric $loadparam{metric}\n" and return;
    }

    $sth->execute or warn "ERROR: Failed to execute the metric insert sql for target $loadparam{target} for metric $loadparam{metric} \n" and return;
    
    $sth->finish or return ;
    
    warn "DEBUG: Rows Deleted from last load for $loadparam{metric} = $rows_deleted \n";


# Format the metric results to pass to PL/SQL for bulk insertion

    my %metric_data_list;
    my $i = 1;

    for my $metric_data ( @metricdata ) {
	
	chomp $metric_data;
	
	my @fields = split /$field_seperator/,$metric_data;
	
	# If the data value is null then keep a place holder there, the row has to anyway be loaded into the rep with a null
	$fields[2]='' unless $fields[2];
	
        #Add a check to return unless there are that many elements
	warn "ERROR : Metric data not properly formed, unable to parse all fields from $metric_data\n" and return unless @fields and @fields > 2;
	
	# strip any trailing and leading blanks
	for ( @fields ){
	    s/^\s+|\s+$//g;
	}
	
	# check if a metric_guid exists for this metric column
	warn "ERROR : metric_guid not found for metric $fields[0] \n" and return unless $metrichash{$fields[0]};
	
	# check if a key_value exists for this metric value
	warn "ERROR : key value not found in metric data $metric_data \n" and return unless $fields[1];	
	
	# form the key_value~~value~~netric_guid string
	my $data_row = "$fields[1]$field_seperator$fields[2]$field_seperator$metrichash{$fields[0]}";	
		
	$i++ if $metric_data_list{$i} and $data_row and  ( ( ( length $metric_data_list{$i} ) + ( length $data_row ) + length $row_seperator ) > $sql_buffer_size );

	# Concatenate he metric data with a !!! as field seperator
	$metric_data_list{$i} .= $row_seperator.$data_row and next if $metric_data_list{$i};
	
	$metric_data_list{$i} = $data_row;
	
    }
    
    warn "DEBUG: The metric buffer will require $i loads to the repository\n" if keys %metric_data_list;
   

    $sth = $loadparam{dbh}->prepare( '
         BEGIN
              STORAGE_SUMMARY_LOAD.LOAD_METRICS(?,?,?,?,?);
         END;' ) or warn "ERROR: Failed inserting the metric data into the reository \n"  and return;

    for ( sort { $a <=> $b } keys %metric_data_list ) {
	
	warn "DEBUG: Loadng metric buffer $_ to the repository\n";
	
	$sth->execute(		      
				      $target{target_id},		      
				      $loadparam{ts},
				      $metric_data_list{$_},
				      $field_seperator,
				      $row_seperator
				      ) or return ;
	
    }
    
    $sth->finish or return ;
    
    warn "DEBUG: Rows Inserted for $loadparam{metric} = ".@metricdata." \n";
    
}
	
1;
