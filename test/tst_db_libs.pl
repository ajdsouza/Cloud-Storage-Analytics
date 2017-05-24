#!/usr/local/git/perl/bin/perl
#
# Copyright  (c) 2001,2002  Oracle Corporation All rights reserved 
#
#  $Id: tst_db_libs.pl,v 1.1 2003/04/23 20:20:02 ajdsouza Exp $ 
#
#
# NAME  
#	 tst_db_libs.ppl
#
# DESC 	
#      Test script to get the list of Oracle files required to connect to the db
#
#	To get the list of files to be packaged
#
#	For Linux
#	strace -o file.out ./tst_db_libs.pl
#	grep "/usr/local/git/oracle" file.out|grep open|grep -vi ENOENT|sort|uniq
#
#	For Solaris
#	truss -o file.out ./tst_db_libs.pl
#	grep "/usr/local/git/oracle" file.out|grep open|grep -vi ENOENT|sort|uniq
#
# FUNCTIONS
#
#
#
# NOTES
#

require v5.6.1;
use strict;
use warnings;

#-------------------------------------------------------------------------
BEGIN{    
    %ENV = ();
    $ENV{ORACLE_HOME}="/usr/local/git/oracle" ; 
}

#------------------------------------------------------------------------
use DBI;
#------------------------------------------------------------------------

my %usage = (
		solaris	=> '
	truss -o file.out ./tst_db_libs.pl
	grep "/usr/local/git/oracle" file.out|grep open|grep -vi ENOENT|sort|uniq',
		linux	=> ' 
	strace -o file.out ./tst_db_libs.pl
	grep "/usr/local/git/oracle" file.out|grep open|grep -vi ENOENT|sort|uniq'
	);

warn "Not supported on $^o \n" and exit unless $usage{$^O};

print " Usage  : 
	Point /usr/local/git/oracle to a standard ORACLE_HOME installation before executing the following commands \n $usage{$^O}\n" ;

my @databases = (  
		  {
			hostname => 'eagle1-pc.us.oracle.com',
			version => "Oracle9i Enterprise Edition Release 9.0.1.4.0 - Production",
			name => "iasem_eagle1-pc",	
			username => "system", 
			password=> "manager",
			address=> "(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=TCP)(Host=eagle1-pc.us.oracle.com)(Port=1521)))(CONNECT_DATA=(SID=iasem)))"
		       },
		   {
		       hostname => 'sm2sun01.us.oracle.com',
		       version => 'Oracle9i Enterprise Edition Release 9.0.1.3.0 - Production',
		       name=>"smmdev_sm2sun01",
		       username=>"OEMADM",
		       password=>"oemv22",
		       address=>"(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL = TCP)(HOST = sm2sun01.us.oracle.com)(PORT = 1522)))(CONNECT_DATA = (SID = smmdev)(SERVER = DEDICATED)))"
		       },
		   {
		       hostname => 'rmsun11.us.oracle.com',
		       version => 'Oracle9i Enterprise Edition Release 9.0.1.0.0 - Production',
		       name=>"emap_rmsun11",
		       username=>"OEMADM",
		       password=>"oemv22",
		       address=>"(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL = TCP)(HOST = rmsun11.us.oracle.com)(PORT = 1521)))(CONNECT_DATA = (SID = emap)(SERVER = DEDICATED)))"
		       },
		   {
		       hostname => 'lothar.us.oracle.com',
		       name=>"db1_lothar",
		       username=>"system",
		       password=>"manager",
		       address=>"(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL = TCP)(HOST = lothar.us.oracle.com)(PORT = 1521)))(CONNECT_DATA = (SID = db1)(SERVER = DEDICATED)))"
		       },
		   {
		       hostname => 'lothar.us.oracle.com',
		       name=>"db3_lothar",
		       username=>"system",
		       password=>"manager",
		       address=>"(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL = TCP)(HOST = lothar.us.oracle.com)(PORT = 1521)))(CONNECT_DATA = (SID = db3)(SERVER = DEDICATED)))"
		       },
		   {
		       hostname => 'dbs10.us.oracle.com',
		       version => 'Oracle7 Server Release 7.3.4.3.0 - Production',
		       name=>"oasisap_dbs10",
		       username=>"oemadm",
		       password=>"oemv22",
		       address=>"(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL = TCP)(HOST = dbs10.us.oracle.com)(PORT = 1521)))(CONNECT_DATA = (SID = oasisap)(SERVER = DEDICATED)))"
		       },
		   {
		       hostname => 'dbs11-c.us.oracle.com',
		       version => 'Oracle9i Enterprise Edition Release 9.2.0.2.0 - 64bit Production',
		       name=>"ifsap_dbs11",
		       username=>"oemadm",
		       password=>"oemv22",
		       address=>"(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL = TCP)(HOST = dbs11.us.oracle.com)(PORT = 1521)))(CONNECT_DATA = (SID = ifsap)(SERVER = DEDICATED)))"
		       }

		   );

#------------------------------------------------------------------------------
# Local Varables
#------------------------------------------------------------------------------	
my %loadparam;
my %hosts;
my $sth;
my $ref;

my %dbattribs = (
		 AutoCommit => 0,
		 PrintError => 1,
		 RaiseError => 0
		 );


# Connect to each database and check the version
foreach ( @databases )
{

	print " ************************************************************************************\n";

	my %dbinfo = %$_;

	print " Database  = $dbinfo{address} \n";
#--------------------------------------------------------------------------------
# Connect to the db to get the database versions
#--------------------------------------------------------------------------------

	$loadparam{dbh} = DBI->connect("dbi:Oracle:$dbinfo{address}",
			       $dbinfo{username},
			       $dbinfo{password}
			       ,\%dbattribs) or 
    	warn "ERROR: Failed to Connect to the Database \n" and next;

# All column names in hashes should be in lower case
$loadparam{dbh}->{FetchHashKeyName} = 'NAME_lc';

#--------------------------------------------------------------------------------
# FETCH THE LIST OF HOST NAMES FROM MGMT_TARGETS
#--------------------------------------------------------------------------------

my @queries = (
	"SELECT 'Version' key, version value FROM PRODUCT_COMPONENT_VERSION WHERE UPPER(PRODUCT) LIKE 'ORACLE%' ",
	"SELECT parameter key, value FROM nls_database_parameters WHERE parameter = 'NLS_CHARACTERSET' "
	);

foreach my $sql ( @queries ) {

$sth = $loadparam{dbh}->prepare($sql) or 
    $sth->finish and
    $loadparam{dbh}->disconnect and
    warn "ERROR: Failed to prepare $sql \n"
	and next;

$sth->execute or 
    $sth->finish and
    $loadparam{dbh}->disconnect and
    warn "ERROR: Failed executing $sql  \n" 
	and next;

$ref = $sth->fetchall_hashref('key') or
    $sth->finish and
    $loadparam{dbh}->disconnect and
    warn "ERROR: Failed executing $sql \n"
	and next;

$sth->finish and
    $loadparam{dbh}->disconnect and   
    warn  "ERROR: $sql fetch :: ".$sth->errstr." \n"
	and next
    if $sth->err;

$sth->finish and
    $loadparam{dbh}->disconnect and 
    warn  "ERROR: Version name NOT FOUND \n" and
	next
    unless $sth->rows and 
    $ref;   

my %lst = %{$ref};


foreach( keys %lst ){

	print "Database $_  = $lst{$_}->{value} \n";

}

$sth->finish or
	warn "ERROR: Failed Finishinf the query $sql \n"
	and next;
}

$loadparam{dbh}->disconnect or 
	warn "ERROR: Failed disconnecting \n"
	and next;

 }


