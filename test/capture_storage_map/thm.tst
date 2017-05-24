#!/bin/sh

PERL5LIB=$SRCHOME/emagent/sysman/admin/scripts:$SRCHOME/perl/lib:$SRCHOME/perl/lib/site_perl;export PERL5LIB
EMAGENT_PERL_TRACE_LEVEL=0; export EMAGENT_PERL_TRACE_LEVEL
EMAGENT_PERL_TRACE_DIR=$SRCHOME/emdw/sysman/log; export EMAGENT_PERL_TRACE_DIR

EM_STORAGE_EXECUTION_MODE='TEST'; export EM_STORAGE_EXECUTION_MODE
#EM_TARGET_GUID='staca31';export EM_TARGET_GUID

#rm storage/nmhs*

$SRCHOME/perl/bin/perl $SRCHOME/emdw/sysman/admin/scripts/storage_report_metrics.pl $1

