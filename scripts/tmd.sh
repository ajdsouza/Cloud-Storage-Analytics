#!/bin/sh

PERL5LIB=${PERL5LIB}:$SRCHOME/emagent/sysman/admin/scripts:$SRCHOME/perl/lib:$SRCHOME/perl/lib/site_perl;export PERL5LIB
EMAGENT_PERL_TRACE_LEVEL=0; export EMAGENT_PERL_TRACE_LEVEL
EMAGENT_PERL_TRACE_DIR=$SRCHOME/emagent/sysman/log; export EMAGENT_PERL_TRACE_DIR

SRCHOME=/scratch/ajdsouza/view_storage/ajdsouza_db1021;export SRCHOME

EMSTATE=${SRCHOME}/emagent;export EMSTATE

EM_TARGET_PASSWORD=manager;export EM_TARGET_PASSWORD
EM_TARGET_USERNAME=system;export EM_TARGET_USERNAME
EM_TARGET_ADDRESS="(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=stbdq16)(PORT=15091))(CONNECT_DATA=(SID=${ORACLE_SID})))";export EM_TARGET_ADDRESS

ARGLIST="db_datafiles db_controlfiles db_redologs"

for val in ${ARGLIST}
do

echo REM executing storage metrics live from $SRCHOME/emagent/sysman/admin/scripts
$SRCHOME/perl/bin/perl $SRCHOME/emdb/sysman/admin/scripts/oracle_db_files.pl  db_datafiles <<AA
EM_TARGET_PASSWORD=manager
EM_TARGET_USERNAME=system
EM_TARGET_ADDRESS="(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=stbdq16)(PORT=15091))(CONNECT_DATA=(SID=db1021)))"
AA

done

