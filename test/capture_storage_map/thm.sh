#!/bin/sh

PERL5LIB=${PERL5LIB}:$SRCHOME/emagent/sysman/admin/scripts:$SRCHOME/perl/lib:$SRCHOME/perl/lib/site_perl;export PERL5LIB
EMAGENT_PERL_TRACE_LEVEL=0; export EMAGENT_PERL_TRACE_LEVEL
EMAGENT_PERL_TRACE_DIR=$SRCHOME/emagent/sysman/log; export EMAGENT_PERL_TRACE_DIR
EM_STORAGE_PRINT_TOPOLOGY=YES; export EM_STORAGE_PRINT_TOPOLOGY

EM_AGENT_STATE=${SRCHOME}/emagent;export EM_AGENT_STATE
EM_TARGET_GUID=`hostname`;export EM_TARGET_GUID
EM_TARGET_NAME=`hostname`;export EM_TARGET_NAME

echo REM executing storage metrics live from $SRCHOME/emagent/sysman/admin/scripts
$SRCHOME/perl/bin/perl $SRCHOME/emagent/sysman/admin/scripts/storage_report_metrics.pl $1

exit 0;
