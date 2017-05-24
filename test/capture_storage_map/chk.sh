#!/bin/sh

if [ "$1" != "" ]; then
  EM_STORAGE_TEST_NAME=$1;export EM_STORAGE_TEST_NAME
fi

PERL5LIB=${PERL5LIB}:$SRCHOME/emagent/sysman/admin/scripts:$SRCHOME/perl/lib:$SRCHOME/perl/lib/site_perl;export PERL5LIB
EMAGENT_PERL_TRACE_LEVEL=0; export EMAGENT_PERL_TRACE_LEVEL
EMAGENT_PERL_TRACE_DIR=$SRCHOME/emagent/sysman/log; export EMAGENT_PERL_TRACE_DIR
EM_TARGET_GUID=`hostname`;export EM_TARGET_GUID
EM_TARGET_NAME=`hostname`;export EM_TARGET_NAME
EM_AGENT_STATE=${SRCHOME}/emagent;export EM_AGENT_STATE

#EM_STORAGE_RMODE=CAPTURE;export EM_STORAGE_RMODE

$SRCHOME/perl/bin/perl chk.pl

