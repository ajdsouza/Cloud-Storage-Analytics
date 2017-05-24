#!/usr/local/git/perl/bin/perl
#
# Copyright  (c) 2001,2002  Oracle Corporation All rights reserved 
#
#  $Id: update_dc.pl,v 1.28 2003/04/22 04:29:18 ajdsouza Exp $ 
#
#
# NAME  
#	 update_dc
#
# DESC 
#	Sample program , ADD ERROR HANDLING AND TEST IT BEFORE USE
#  	Update datacenter and LOB information in the master table	
#
# FUNCTIONS
#
#
#
# NOTES
#
#
# MODIFIED	(MM/DD/YY)
# ajdsouza	08/02/02 - Created
#
#
#

require v5.6.1;
use strict;
use warnings;

#-------------------------------------------------------------------------
# Have BEGIN before use so its executed at compile time 
# before use DBI

BEGIN{
# Set Oracle_home for DBI if no ORACLE_HOME has been defined
    %ENV = ();
#    $ENV{ORACLE_HOME}="/usr/local/git/oracle" unless $ENV{ORACLE_HOME}; 
}

#------------------------------------------------------------------------
use DBI;
#------------------------------------------------------------------------

#------------------------------------------------------------------------
# Subs defined
sub updatelob;
#-----------------------------------------------------------------------


#--------------------------------------------------------------
# Subnet mapping file
#--------------------------------------------------------------
my $subnetfile = 'subnets.txt';
#---------------------------------------------------------------------------
# Subnet to datacenter map, for some known subnets, read the others from the
# subnet file 
# This will be appended to the list found in subnets.txt
#---------------------------------------------------------------------------	
my %datacentersubnet = (
			"130.35" => "HQ",
			"139.185" => "HQ",
			"148.87" => "HQ",
			"138.1" => "RMDC",
			"138.2" => "RMDC",
			"138.3" => "UK",
			"144.20" => "AUSTIN",
			"141.146" => "AUSTIN"
			);


#---------------------------------------------------------------------------
# Connection credentials to master database , to read the mgmt_targets Table
# and Update storage_targets_lob_dc table
#---------------------------------------------------------------------------
my $master;

if ( $ARGV[0] and $ARGV[0] =~ /production/i )
{
	# Production database
	$master ="(DESCRIPTION = (ADDRESS_LIST =(ADDRESS = (PROTOCOL = TCP)(Host = rmsun11.us.oracle.com)(Port = 1521)))(CONNECT_DATA = (SID = emap)(SERVER = DEDICATED)))";

}else{
	# Development database
	$master = "(DESCRIPTION = (ADDRESS_LIST = (ADDRESS = (PROTOCOL = TCP)(HOST = eagle1-pc.us.oracle.com)(PORT = 1521)))(CONNECT_DATA =(SID = iasem)))";

}

my $master_un = "storage_rep";
my $master_pw = "storage_rep";

#---------------------------------------------------------------------------
# Connection credentials to ISIS for LOB information
#---------------------------------------------------------------------------
my $isis = "(DESCRIPTION = (ADDRESS_LIST = (ADDRESS = (PROTOCOL = TCP)(HOST = gitprod1.us.oracle.com)(PORT = 1521)))(CONNECT_DATA =(SID = osiris)))";
my $isis_un = "snathan_us";
my $isis_pw = "osiris";


#---------------------------------------------------------------------------
# FUNCTION : updatelob
#
# DESC	   : 
#	Update LOB and data centre information for datacenter
#
# ARGS:
#	-    
#---------------------------------------------------------------------------
sub updatelob{
    
    #------------------------------------------------------------------------------
    # Local Varables
    #------------------------------------------------------------------------------	
    my %hosts;
    my %loadparam;
    my %datacenter;
    my %ip;
    my %lob;
    my $sql;
    my $checksql;
    my $delsql;
    my $sth;
    my $checksth;
    my $delsth;
    my $ref;
    my $procedurestoph;
    my $procedurestarth;
    
    my %dbattribs = (
		     AutoCommit => 0,
		     PrintError => 1,
		     RaiseError => 0
		     );
    #--------------------------------------------------------------------------------
    # Connect to the master db to get the list of targets
    #--------------------------------------------------------------------------------
    
    $loadparam{dbh} = DBI->connect("dbi:Oracle:$master",
				   $master_un,
				   $master_pw
				   ,\%dbattribs) or 
				   die 
				   " Failed to Connect to the master Database $master";
    
    # All column names in hashes should be in lower case
    $loadparam{dbh}->{FetchHashKeyName} = 'NAME_lc';

    #--------------------------------------------------------------------------------
    # FETCH THE LIST OF HOST NAMES FROM MGMT_TARGETS
    #--------------------------------------------------------------------------------
    warn "DEBUG: Fetching target names \n";
    
    $sql = "SELECT LOWER(TRIM(' ' FROM TARGET_NAME)) NAME , TARGET_ID FROM MGMT_TARGETS WHERE TARGET_TYPE = 'oracle_sysman_node' ";
    
    $sth = $loadparam{dbh}->prepare($sql) or 
	warn "ERROR: Failed preparing $sql \n" and
	return;
    
    $sth->execute or 
	warn "ERROR: Failed executing $sql \n" and
	return;
    
    $ref = $sth->fetchall_hashref('name');
    
    warn "ERROR : Failed fetching $sql :: ".$sth->errstr."\n" and 
	return if $sth->err;
    
    warn "ERROR : Target names NOT FOUND \n" and
	return unless $sth->rows and $ref;   
    
    my %lst = %{$ref};
    
    %hosts = map{ lc $_ => $lst{$_}->{target_id} } keys %lst;
    
    warn "DEBUG: No. of Target names fetched from master database = ".$sth->rows."\n";
    
    $sth->finish or 
	warn "ERROR: Failed finishing $sql \n" and
	return;
    
    # Disconnect from the datacenter database 
    $loadparam{dbh}->disconnect or 
	warn "ERROR: Failed disconnecting from database $master \n" and	
	return;
    
    #----------------------------------------------
    # GET THE DATACENTER FOR EACH HOST
    #----------------------------------------------

    #--------------------------------------------------------------------------------
    # Execute /usr/sbin/ping -s <hostname> 56 1 ,for each host to get its subnet from its IP
    #--------------------------------------------------------------------------------
    # initialize a hash of targets from the List of datacenter fetched, set default status for
    # each host to be datacenter Unknown
    warn "DEBUG: Pinging to get the IP address , to get the datacenter for each target \n";
    
    %datacenter = map { $_ => 'UNKNOWN'} keys %hosts;
    %ip = map { $_ => 'UNKNOWN'} keys %hosts;
    
    for my $targetname ( keys %hosts ){
	
	my $ipaddress;
	
	# Fetch the ping results, by grepping lines with ecmp_seq
	# for solaris
	for ( grep {/icmp_seq/i } `/usr/sbin/ping -s $targetname 56 1` ){
	    
	    # for linux
	    #for ( grep {/icmp_seq/i } `/usr/sbin/ping -s56 -c1 $targetname ` ){	    
	    
	    chomp;
	    
	    s/^\s+|\s+$//g;
	    
	    #-------------------------------------------------------------------------------
	    # PARSE IP address from ping results
	    #
	    # Read the subnet using regexp from the ping results as below
	    #72 bytes from dlsun1170.us.oracle.com (130.35.248.148): icmp_seq=1. time=0. ms		    
	    #-------------------------------------------------------------------------------
	    ($ipaddress) = /^.*\(([\d,\.]+).*$/;

	    warn "ERROR: Failed to get the IP address for $targetname, from ping results $_ " 
		and next
		unless $ipaddress;
	    
	    # Save the ip address for each target
	    $ip{$targetname} = $ipaddress;
	    
	    # Update the host hash with the datacenter based on the IP address or subnet
	    $datacenter{$targetname} = $datacentersubnet{$ipaddress} and 
		next if $datacentersubnet{$ipaddress};	    		   	    
	    
	    # Check at each subnet level if it maps to a datacenter
	    $ipaddress =~ s/\.\d+$//;
	    $datacenter{$targetname} = $datacentersubnet{$ipaddress} and 
		next if $datacentersubnet{$ipaddress};
	    
	    # Check at each subnet level if it maps to a datacenter
	    $ipaddress =~ s/\.\d+$//;
	    $datacenter{$targetname} = $datacentersubnet{$ipaddress} and 
		next if $datacentersubnet{$ipaddress};
	    
	    warn "ERROR: Datacenter not available for $targetname, $ip{$targetname} \n" 
		and next;

	}
	
    }
    
    
    #---------------------------------------------------------
    # FETCH HOST TO LOB MAPPING FROM ISIS_HARDWARE_ASSETS
    #---------------------------------------------------------
    
    #----------------------------------------------------------------------------
    # Connect to the ISIS database to fetch the LOB for each host in the list
    #----------------------------------------------------------------------------
    
    warn "DEBUG : Fetching the Targetname Lob List from  ISIS_HARDWARE_ASSETS in isis database\n";
    
    $loadparam{dbh} = DBI->connect("dbi:Oracle:$isis",
				   $isis_un,
				   $isis_pw
				   ,\%dbattribs) or 
				   die " Failed to Connect to the ISIS Database $isis";
    
    # All column names in hashes shoule be in lower case
    $loadparam{dbh}->{FetchHashKeyName} = 'NAME_lc';
    
    #----------------------------------------------------------------------------
    # Fetch the hostname to LOB map ISIS_HARDWARE_ASSETS
    #----------------------------------------------------------------------------		

    $sql = "SELECT LOWER(LTRIM(RTRIM(HOSTNAME))) HOSTNAME, UPPER(ESCALATION_GROUP) LOB FROM ISIS_HARDWARE_ASSETS";    
    
    $sth = $loadparam{dbh}->prepare($sql) or 
	warn "ERROR: Failed preparing $sql \n" and
	return;
        
    $sth->execute or 
	warn "ERROR: Failed executing $sql \n" and
	return;	
    
    $ref = $sth->fetchall_hashref('hostname');
    
    warn "ERROR : Failed fetching $sql :: ".$sth->errstr."\n" and 
	return if $sth->err;
    
    warn "ERROR : Hostname ,Lob list not found in ISIS_HARDWARE_ASSETS in isis database\n" and 
	return unless $sth->rows and $ref;   

    #Save the hostname, Lob map    
    my %isisdata = map { $_ => $ref->{$_}->{lob} } keys %{$ref};

    $sth->finish or 
	warn "ERROR: Failed finishing $sql \n" and
	return ;
    
    # Disconnect from the database 
    $loadparam{dbh}->disconnect or 
	warn "ERROR: Failed disconnectiong from ISIS database $isis " and
	return;
    
    # Initialze the LOB hash with names of datacenter from the host list set LOB unknown by default
    %lob = map{$_ => 'UNKNOWN'} keys %hosts;
    
    # Fetch the LOB for each host and update the hash LOB list
    for ( keys %hosts ){	
	
	#s/^\s+|\s+$//g;
	
	# Split target_name into host and domain names	
	my ( $name, $domain) = (/^([^\.]*)(.*)$/);
            	       	
	$lob{$_} = $isisdata{$_} and next if  $isisdata{$_};
	$lob{$_} = $isisdata{$name} and next if  $isisdata{$name};

 	warn  "ERROR: Lob NOT FOUND in ISIS_HARDWARE_ASSETS for $_ \n" and 
	    next;
    }
     
    warn "DEBUG : Target ,Datacenter ,Lob mapping List \n";
    for ( keys %datacenter ){
	
	printf "DEBUG: %-40.40s  %-15.15s  %-20.20s  %-40.40s  %-15.15s\n",$_,$hosts{$_},$datacenter{$_},$lob{$_},$ip{$_};
    }
   
    #----------------------------------------------------------------------------------------
    # UPDATE THE LOB , DATACENTER INFORMATION TO MASTER TABLE STORAGE_TARGET_DC_LOB
    # DELETE AND INSERT ONE HOST AT A TIME
    #----------------------------------------------------------------------------------------

    #----------------------------------------------------------------------------
    # Connect to the Master database to Update LOB AND datacenter for each host
    #---------------------------------------------------------------------------- 
    $loadparam{dbh} = DBI->connect("dbi:Oracle:$master",
				   $master_un,
				   $master_pw
				   ,\%dbattribs) or 
				   die 
				   " Failed to Connect to the Master Database $master";
    
    #-----------------------------------------------------------------------------------------
    # STOP THE STORAGE_SUMMARY COMPUTATION JOB WHEN UPDATING THE STORAGE_TARGET_DC_LOB TABLE
    #-----------------------------------------------------------------------------------------
    warn "DEBUG: Stopping storage computation job , executing STORAGE_SUMMARY.CLEANJOB \n";
    
    $procedurestoph = $loadparam{dbh}->prepare( "BEGIN STORAGE_SUMMARY.CLEANJOB; END;" ) or 
	warn "ERROR: Failed PREPARING BLOCK TO STOP STORAGE_SUMMARY.CLEANJOB !!\n" and
	return;
    
    $procedurestoph->execute or
	warn "ERROR: Failed EXECUTING BLOCK TO STOP STORAGE_SUMMARY.CLEANJOB !!\n" and
	return;
    
    $procedurestoph->finish or 
	warn "ERROR: Failed FINISHING BLOCK TO STOP STORAGE_SUMMARY.CLEANJOB !!\n" and
	return ;
    
    #---------------------------------------------------------------------------------------
    # Update the LOB and Data centre information in the master table STORAGE_TARGET_DC_LOB
    #---------------------------------------------------------------------------------------

    warn "DEBUG: Updating the table STORAGE_TARGET_DC_LOB with the target, datacenter, lov information \n";
    
    # Connection credentials to master database , to Update master table
    # STORAGE_TARGET_DC_LOB
    # TARGET_ID					    VARCHAR2(256) NOT NULL
    # TARGET_NAME				    VARCHAR2(256) NOT NULL
    # TARGET_DATACENTER				    VARCHAR2(256) NOT NULL
    # TARGET_LOB				    VARCHAR2(256) NOT NULL
    # IPADDRESS					    VARCHAR2(256)

    # Check sql, check if record exists
    $checksql = "SELECT 1 FROM STORAGE_TARGET_DC_LOB WHERE UPPER(TARGET_ID) = UPPER(:1)";
    $checksth = $loadparam{dbh}->prepare($checksql) or 
	warn "ERROR: Failed preparing  $checksql !!\n" and
	return;

    # Delete for each row as you insert in the master tables
    $delsql = "DELETE FROM STORAGE_TARGET_DC_LOB WHERE UPPER(TARGET_ID) = UPPER(:1)";    
    $delsth = $loadparam{dbh}->prepare($delsql) or 
	warn "ERROR: Failed preparing  $delsql !!\n" and
	return;
    
    # Insert the new set of rows into the master table
    $sql = "INSERT INTO STORAGE_TARGET_DC_LOB( TARGET_ID ,TARGET_NAME, TARGET_DATACENTER, TARGET_LOB, IPADDRESS ) 
		VALUES (:1,:2,:3,:4,:5)";    
    $sth = $loadparam{dbh}->prepare($sql) or 
	warn "ERROR: Failed preparing  $sql !!\n" and
	return;
    
    # Update the LOB and datacenter information for each host
    for ( keys %hosts ){
	
	warn "ERROR: Row for $_ Not inserted to storage_target_dc_lob , required value is NULL \n" and 
	    next unless $_ and 
	    $hosts{$_} and 
	    $datacenter{$_} and 
	    $lob{$_};
	
	# If IP is unknown then insert a row only if one does not exist
	if  ( $ip{$_} =~ /UNKNOWN/ )
	{	
	    
	    $checksth->execute($hosts{$_}) or 
		warn "ERROR: Failed executing $checksql for $_ \n" 
		and return; 
	    
	    my $checkref = $checksth->fetchrow_arrayref;
	    
	    warn "ERROR: Failed checking if row exists for $_ ".$checksth->errstr."\n" and 
		return 	if not $checkref and 
		$checksth->err;
	    
	    my $rowcnt =  $checksth->rows;	    
	    
	    warn "DEBUG: Skipping inserting row for target $_ with UNKNOWN IP, a row already exists \n" 
		#and $checksth->finish 
		and next if $checksth->rows;
	    
#	    $checksth->finish or 
#	        warn "ERROR: Failed finishing $checksql for $_!!\n" and	
#		return;
	}
	
	# Delete the row for this target if it exists     
	$delsth->execute($hosts{$_}) or 
	    warn "ERROR: Failed deleting $delsql for $_!!\n" and
	    return;
	
	# Insert the row for this target
	$sth->execute($hosts{$_},$_,$datacenter{$_},$lob{$_},$ip{$_}) or 
	    warn "ERROR: Failed executing $sql for $_ $datacenter{$_} $lob{$_} !!\n" and
	    return ;
	
    }

    $checksth->finish or 
	warn "ERROR: Failed finishing $checksql!!\n" and	
	return;        
    $delsth->finish or 
	warn "ERROR: Failed FINISHING $delsql !!\n" and
	return ;
    $sth->finish or 
	warn "ERROR: Failed FINISHING $sql !!\n" and
	return ;
    
    $loadparam{dbh}->commit or 
	$loadparam{dbh}->rollback and 
	die " COMMIT FAILED  TO THE MASTER DATABSE , All rows deleted/inserted to storage_target_dc_lob rolled back";    
    
    #---------------------------------------------------------------------------------------------------
    # RESTART STORAGE_SUMMARY COMPUTATION JOB
    #---------------------------------------------------------------------------------------------------
    warn "DEBUG: Starting the storage summary computation job, executing  STORAGE_SUMMARY.SUBMITJOB \n";
    
    $procedurestoph = $loadparam{dbh}->prepare( "BEGIN STORAGE_SUMMARY.CLEANJOB;  STORAGE_SUMMARY.SUBMITJOB; END;" ) or 
	warn "ERROR: Failed PREPARING BLOCK TO START STORAGE_SUMMARY.SUBMITJOB , Some groups may not have summaries without this !!\n" and
	return;

    $procedurestoph->execute or
	warn "ERROR: Failed EXECUTING BLOCK TO START STORAGE_SUMMARY.SUBMITJOB , Some groups may not have summaries without this !!\n" and
	return;
    
    $procedurestoph->finish or 
	warn "ERROR: Failed FINISHING BLOCK TO START STORAGE_SUMMARY.SUBMITJOB !!\n" and
	return ;
    
    $loadparam{dbh}->disconnect or 
	warn "ERROR: Failed while disconnection from Maaster database $master !!\n" and
	return;
    
}


#-------------------------------------------------------------------
#  READ THE SUBNET TO DATACENTER MAP FROM THE text file subnets.txt
#  Expected format 
#  DC:
#  subnet1
#  subnet2
#-------------------------------------------------------------------
my $fh;
my $dc;

open($fh,$subnetfile) or die "ERROR: Cannot find Subnet configuration file $subnetfile \n";

while ( <$fh>){

    chomp;
    
    s/^\s+|\s+$//g;
    
    next unless $_;
    
    next if $_ =~ /^\#/;
    
    ($dc) = ($_ =~ /^(.+):$/) and next if $_ =~ /^.+:$/;	
    
    die "ERROR: Datacentre not available ,check file $subnetfile \n" unless $dc;
    
    my ($subnet) = /^([\d,\.]+).*$/;
    
    die "ERROR: Subnet not available from $_, check file $subnetfile \n" unless $subnet;
    
    $subnet =~ s/\.0+$//;
    $subnet =~ s/\.0+$//;
    
    die "ERROR: Subnet not available from $_ , check file $subnetfile \n" unless $subnet;
    
    $datacentersubnet{$subnet} = uc $dc;
}

updatelob();


