#!/bin/sh

PERL5LIB=$SRCHOME/emagent/sysman/admin/scripts:$SRCHOME/perl/lib:$SRCHOME/perl/lib/site_perl;export PERL5LIB
EMAGENT_PERL_TRACE_LEVEL=0; export EMAGENT_PERL_TRACE_LEVEL
EMAGENT_PERL_TRACE_DIR=$SRCHOME/emdw/sysman/log; export EMAGENT_PERL_TRACE_DIR
#EM_TARGET_GUID=`hostname`;export EM_TARGET_GUID

EM_STORAGE_SHOW_ALL_MSGS_STDOUT=YES; export EM_STORAGE_SHOW_ALL_MSGS_STDOUT
EM_STORAGE_RMODE=CAPTURE;export EM_STORAGE_RMODE
EM_STORAGE_TEST_DEPOT=${HOME}/stormon/test;export EM_STORAGE_TEST_DEPOT
EM_STORAGE_TEST_SUBDIR=staca31_test1;export EM_STORAGE_TEST_SUBDIR
EM_AGENT_STATE=${EM_STORAGE_TEST_DEPOT}/${EM_STORAGE_TEST_SUBDIR};export EM_AGENT_STATE
RESULT_FILE_LIST="stdout.txt nmhsdata.txt nmhskeys.txt nmhsissu.txt nmhsalia.txt nmhsrmet.log nmhsfcsh.txt"


if [ -e ${EM_AGENT_STATE}/storage ]; then
  echo
  echo REM Deleting old files from ${EM_AGENT_STATE}/storage
  echo
  for FILE in $RESULT_FILE_LIST
  do
    if [ -e ${EM_AGENT_STATE}/storage/${FILE} ]; then
      rm ${EM_AGENT_STATE}/storage/${FILE}
    fi
  done
fi

if [ -e ${EM_STORAGE_TEST_DEPOT}/${EM_STORAGE_TEST_SUBDIR} ]; then
  echo
  echo REM Deleting old files from  ${EM_STORAGE_TEST_DEPOT}/${EM_STORAGE_TEST_SUBDIR}
  echo
  for FILE in ${EM_STORAGE_TEST_DEPOT}/${EM_STORAGE_TEST_SUBDIR}/* ];
  do
    if [ -f ${FILE} ]; then
      rm ${FILE}
    fi
  done
fi

mkdir -m 755 -p ${EM_AGENT_STATE}/storage
mkdir -m 755 -p ${EM_STORAGE_TEST_DEPOT}/${EM_STORAGE_TEST_SUBDIR}

echo
echo REM Executing metrics for capture
echo

echo -------------- Metric: storage_reporting_data -------------------->  ${EM_AGENT_STATE}/storage/stdout.txt
$SRCHOME/perl/bin/perl $SRCHOME/emdw/sysman/admin/scripts/storage_report_metrics.pl data >> ${EM_AGENT_STATE}/storage/stdout.txt
echo -------------- Metric: storage_reporting_keys -------------------- >>  ${EM_AGENT_STATE}/storage/stdout.txt
$SRCHOME/perl/bin/perl $SRCHOME/emdw/sysman/admin/scripts/storage_report_metrics.pl keys >> ${EM_AGENT_STATE}/storage/stdout.txt
echo -------------- Metric: storage_reporting_alias -------------------->>  ${EM_AGENT_STATE}/storage/stdout.txt
$SRCHOME/perl/bin/perl $SRCHOME/emdw/sysman/admin/scripts/storage_report_metrics.pl issues >> ${EM_AGENT_STATE}/storage/stdout.txt
echo -------------- Metric: storage_reporting_issues -------------------->>  ${EM_AGENT_STATE}/storage/stdout.txt
$SRCHOME/perl/bin/perl $SRCHOME/emdw/sysman/admin/scripts/storage_report_metrics.pl alias >> ${EM_AGENT_STATE}/storage/stdout.txt

echo
echo REM !! Test files captured to directory ${EM_STORAGE_TEST_DEPOT}/${EM_STORAGE_TEST_SUBDIR} 
echo
echo REM To view results : cat ${EM_AGENT_STATE}/storage/stdout.txt 
echo
