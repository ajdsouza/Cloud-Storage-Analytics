#!/bin/sh

PERL5LIB=$SRCHOME/emdw/sysman/admin/scripts:$SRCHOME/perl/lib:$SRCHOME/perl/lib/site_perl;export PERL5LIB

EM_TARGET_ADDRESS="(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=$HOSTNAME.us.oracle.com)(Port=15091))(CONNECT_DATA=(SID=$ORACLE_SID)))"; export EM_TARGET_ADDRESS

$SRCHOME/perl/bin/perl $SRCHOME/emdb/sysman/admin/scripts/oracle_db_files.pl $1 <<EOF
__BeginProp__
EM_TARGET_USERNAME=system
EM_TARGET_PASSWORD=manager
__EndProp__
EOF;
