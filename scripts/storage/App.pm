#
# Copyright  (c) 2001,2002  Oracle Corporation All rights reserved 
#
#  $Id: App.pm,v 1.30 2003/10/03 01:39:10 ajdsouza Exp $ 
#
#
# NAME  
#	 App.pm
#
# DESC 
#  	Subroutine for getting application specific metrics for a Oracle DB
#
#
# FUNCTIONS
# getApplicationMetrics()
# getOracleDBMetrics()	
#
#
# NOTES
#		This script works for 8i,9i databases
#	        Target Adress expected to be in the standard format
#		(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=dlsun1170)(PORT=1531))(CONNECT_DATA=(SID=emd)))
#
#
# MODIFIED	(MM/DD/YY)
# ajdsouza	04/11/02 - Use DBI instead of Oraperl
#			   To be in line with GIT requirements
# ajdsouza	10/03/02 - Modified to be integrated with stormon
# pshivasw      02/22/02 - Creation
#
#
# NOTE: 
#

package Monitor::OS::App;

require v5.6.1;
use strict;
use warnings;

#---------------------------------------------------------------------------------------
# Execute at compile time before libraries are compiled
BEGIN{
# Set Oracle_home for DBI
    $ENV{ORACLE_HOME}="/usr/local/git/oracle"; 
}
#----------------------------------------------------------------------------------------
use DBI;
use Monitor::Utilities;
#-----------------------------------------------------------------------------------------
# subs declared
sub getApplicationMetrics;
sub getOracleDBMetrics;

# DB connection timeout and retry values in secs
my $db_timeout  = 10;   #timeout secs
my $db_retry    = 3;    #number of retries
my $db_waittime = 60;   #wait time before retry

#-----------------------------------------------------------------------------------------
# FUNCTION : getApplicationMetrics
#
# DESC 
# return a array of hashes for all Application metrics  
#
# ARGUMENTS
#
#-----------------------------------------------------------------------------------------
sub getApplicationMetrics{
    
    return getOracleDBMetrics;
    
}


#--------------------------------------------------------------------------
# FUNCTION : getOracleDBMetrics
#
#
# DESC
# Returns array of hashes which contains tablespace details
#
#
# ARGUMENTS
#
#--------------------------------------------------------------------------

sub getOracleDBMetrics{
		
    # Get the username,password and target database base address from
    # fetchlet environment
    
    warn "ERROR: Target database credentials not available \n" and return 
	unless $ENV{EM_TARGET_USERNAME} and $ENV{EM_TARGET_PASSWORD} and $ENV{EM_TARGET_ADDRESS};
    
    my @databasearray;    
    my %oradb;

    $oradb{type}        = 'ORACLE_DATABASE';

    # This only done as to keep the relationship between the oem db target_name and the DBname and SID
    # The git oem repository does not provide this
    $oradb{oem_target_name} =  $ENV{EM_TARGET_NAME};
    
    #---------------------------------------------------------------------------
    # Get the sid of the current instance connected to
    # by parsing the connect string
    #---------------------------------------------------------------------------
    my ($sid) = ( $ENV{EM_TARGET_ADDRESS} =~ /^.*\(\s*SID\s*=\s*([^\)]+).*$/i );

    warn "ERROR: Failed to read the Oracle Database SID from $ENV{EM_TARGET_ADDRESS} \n" and return unless $sid;

    #-----------------------------------------------------------------------------
    #Connect to the Database
    #-----------------------------------------------------------------------------
    my %dbh;
    my $sql;
    my $sth; 
    my $hashref;
    my $versionsth;
    my $versionsql;
    my $versionref;

    # name is same for all instances of a database, so its common to all nodes of a 
    # OPS or clustered database
    # 
    # 9I paramater for clustered db is cluster_database
    # equivalent 8i parameter is parallel_server
    my %sqlqueries = (
		      6 =>[(  "SELECT NAME FROM V\$DATABASE" )],
		      7 =>[(  "SELECT NAME FROM V\$DATABASE" )],
		      8 =>[(  "SELECT NAME FROM V\$DATABASE",
			      "SELECT DECODE(UPPER(VALUE),'FALSE','NO','YES') shared FROM V\$PARAMETER WHERE NAME IN ('cluster_database','parallel_server')" )],
		      9 =>[(  "SELECT NAME FROM V\$DATABASE",
			      "SELECT DECODE(UPPER(VALUE),'FALSE','NO','YES') shared FROM V\$PARAMETER WHERE NAME IN ('cluster_database','parallel_server')" )]
		      );
       
    warn "DEBUG: Connecting to the target database $ENV{EM_TARGET_NAME} for collection of database metrics for this database target \n";
 
    %dbh = dbconnect($ENV{EM_TARGET_USERNAME},$ENV{EM_TARGET_PASSWORD},$ENV{EM_TARGET_ADDRESS},$db_timeout,$db_retry,$db_waittime) 
	or warn "ERROR: Failed to connect to the target database $ENV{EM_TARGET_NAME} , aborting collection of database metrics for this database target \n" 
	and return;
    
    $dbh{dbh}->{FetchHashKeyName} = 'NAME_lc';

    #---------------------------------------------------------------
    # Fetch the version of the Oracle database
    #---------------------------------------------------------------    
    $versionsql = "SELECT SUBSTR(VERSION,1,INSTRB(VERSION,'.')-1) version FROM PRODUCT_COMPONENT_VERSION WHERE UPPER(PRODUCT) LIKE 'ORACLE%' ";
    
    $versionsth = $dbh{dbh}->prepare($versionsql) or 
	warn "ERROR : preparing $versionsql\n" and 
	$dbh{dbh}->disconnect and 
	return;
    
    $versionsth->execute or 
	warn "ERROR : executing $versionsql\n" and 
	$versionsth->finish and 
	$dbh{dbh}->disconnect and 
	return;
    
    $versionref = $versionsth->fetchrow_hashref or 
	warn "ERROR: fetching $versionsql \n" and 
	$versionsth->finish and 
	$dbh{dbh}->disconnect and 
	return; 
    
    warn "ERROR : $versionsql fetch :: ".$versionsth->errstr." \n" and 
	$versionsth->finish and 
	$dbh{dbh}->disconnect and 
	return if $versionsth->err;
    
    warn "ERROR : $versionsql No rows FOUND \n" and 
	$versionsth->finish and 
	$dbh{dbh}->disconnect and 
	return unless $versionsth->rows and $versionref and $versionref->{version}; 
    
    $versionsth->finish or 
	$dbh{dbh}->disconnect and 
	return;     
    
    $versionref->{version} = 9 unless $versionref->{version} =~ /^(6|7|8|9)$/;
    
    #---------------------------------------------------------------------------------
    # Fetch dbname, cluster flag
    #---------------------------------------------------------------------------------
    for ( @{$sqlqueries{$versionref->{version}}} )
    {	
	
	$sth = $dbh{dbh}->prepare($_) or  
	    warn "ERROR : preparing $_\n" and 
	    $dbh{dbh}->disconnect and 
	    return;
	
	$sth->execute or 
	    warn "ERROR : executing $_\n" and 
	    $sth->finish and 
	    $dbh{dbh}->disconnect and 
	    return;
	
	$hashref = $sth->fetchrow_hashref or 
	    warn "ERROR: fetching $_ \n" and
	    $sth->finish and
	    $dbh{dbh}->disconnect and 
	    return;
	
	warn "ERROR : $_ fetch :: ".$sth->errstr." \n" and  
	    $sth->finish and 
	    $dbh{dbh}->disconnect and 
	    return if $sth->err;
	
	warn "ERROR : $_ No rows FOUND \n" and  
	    $sth->finish and 
	    $dbh{dbh}->disconnect and 
	    return unless $sth->rows and $hashref; 

	%oradb = (%oradb,%{$hashref});
	
	$sth->finish or  
	    $dbh{dbh}->disconnect and 
	    return;
    }  

    # DBNAME and SID uniqely identifies a instance of the Oracle DB on a target, take that 
    # as the application id for a oracle database
    # We could use the oem target_name for this, but that makes it oem9i specific
    $oradb{id} = "$oradb{name}-$sid";

    #--------------------------------------------------------------------------------
    # Fetch Tablespace data
    #--------------------------------------------------------------------------------
    $sql = '
	SELECT    a.tablespace_name oracle_database_tablespace,
	          b.file_name file_name,
                  b.bytes sizeb,
                  free
	FROM (
	      SELECT tablespace_name, 
	             file_id, 
	             SUM( bytes) free
	      FROM  dba_free_space 
	      GROUP BY
	      tablespace_name, 
	      file_id
	      ) a,
	      (
	       SELECT   file_id, 
	                file_name, 
	                bytes
	       FROM     dba_data_files
	       ) b
	WHERE a.file_id = b.file_id';
    
    $sth = $dbh{dbh}->prepare($sql) or 
	warn "ERROR : preparing $sql \n" and 
	$dbh{dbh}->disconnect and 
	return;
    
    $sth->execute or 
	warn "ERROR : executing $sql \n" and 
	$sth->finish and
	$dbh{dbh}->disconnect and 
	return;
    
    my %filelist;

    while ( my $tablespaceref = $sth->fetchrow_hashref )
    {
	
	my %dbinfo = %oradb;
	
	# If the file is already instrumented then skip
	next if exists $filelist{$tablespaceref->{file_name}};

	# save the list of files instrumented
	$filelist{$tablespaceref->{file_name}} = 1;

	$dbinfo{oracle_database_tablespace}     = $tablespaceref->{oracle_database_tablespace};
	$dbinfo{file}                           = $tablespaceref->{file_name};
	$dbinfo{size} 				= $tablespaceref->{sizeb};
	$dbinfo{free} 				= $tablespaceref->{free};
	$dbinfo{used} 				= $dbinfo{size} - $dbinfo{free};
	$dbinfo{inode} 				= getinode($dbinfo{file}) if $dbinfo{file};
	# Check if the filesystem is based on another filesystem, the filesystem has to be a regular file or directory
	$dbinfo{filetype} = 'FILESYSTEM_BASED' 
	    if 
	    $dbinfo{file} and 
	    -e $dbinfo{file} and 
	    ( -f $dbinfo{file} or -d $dbinfo{file} );
	
	# Generate a unique key for each row < 128 dbid, dbfilename, array count should generate a unique key
	$dbinfo{key}				= substr("$dbinfo{id}-$dbinfo{file}",0,120).'-'.@databasearray;
	
	push @databasearray ,\%dbinfo;
    }
    
    warn "ERROR : $sql fetch :: ".$sth->errstr." \n" and  
	$sth->finish and
	$dbh{dbh}->disconnect and 
	return if $sth->err;
    
    warn "ERROR : $sql No Rows Found \n" and 
	$sth->finish and
	$dbh{dbh}->disconnect and 
	return unless $sth->rows;
    
    $sth->finish or 
	$dbh{dbh}->disconnect and 
	return;
    
    $dbh{dbh}->disconnect or return;
    
    return @databasearray;
    
}


1;#Return True
