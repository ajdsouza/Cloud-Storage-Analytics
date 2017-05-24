#!/bin/sh

PERL5LIB=$SRCHOME/emagent/sysman/admin/scripts:$SRCHOME/perl/lib:$SRCHOME/perl/lib/site_perl;export PERL5LIB
EMAGENT_PERL_TRACE_LEVEL=0; export EMAGENT_PERL_TRACE_LEVEL
EMAGENT_PERL_TRACE_DIR=$SRCHOME/emdw/sysman/log; export EMAGENT_PERL_TRACE_DIR
#EM_TARGET_GUID=`hostname`;export EM_TARGET_GUID

end_test()
{
  echo ''
  echo REM --------------------------- END storage regression test ${TEST_NAME} ------------------------------
}


TEST_NAME=$1;

echo REM --------------------------- Start storage regression test ${TEST_NAME} ------------------------------
echo ''

if [ "$TEST_NAME" == "" ]; then
  echo 'REM Usage: thmr.tst <test_mame>';
  end_test;
  exit 1;
fi


EM_STORAGE_SHOW_ALL_MSGS_STDOUT=YES; export EM_STORAGE_SHOW_ALL_MSGS_STDOUT
EM_STORAGE_RMODE=REGRESSION;export EM_STORAGE_RMODE
EM_STORAGE_TEST_DEPOT=${HOME}/stormon/test;export EM_STORAGE_TEST_DEPOT
EM_STORAGE_TEST_SUBDIR=${TEST_NAME};export EM_STORAGE_TEST_SUBDIR
EM_AGENT_STATE=`pwd`;export EM_AGENT_STATE
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

if [ ! -d  ${EM_STORAGE_TEST_DEPOT}/${EM_STORAGE_TEST_SUBDIR} ];
then
  echo
  echo "ERROR: Aborting test ${TEST_NAME}, Test directory  ${EM_STORAGE_TEST_DEPOT}/${EM_STORAGE_TEST_SUBDIR} is not present , this directory with captured files should be available";
  end_test;
  exit 1;
fi


echo
echo REM Executing metrics from captured files in ${EM_STORAGE_TEST_DEPOT}/${EM_STORAGE_TEST_SUBDIR}
echo

echo -------------- Metric: storage_reporting_data -------------------->  ${EM_AGENT_STATE}/storage/stdout.txt
$SRCHOME/perl/bin/perl $SRCHOME/emdw/sysman/admin/scripts/storage_report_metrics.pl data >> ${EM_AGENT_STATE}/storage/stdout.txt
echo -------------- Metric: storage_reporting_keys -------------------- >>  ${EM_AGENT_STATE}/storage/stdout.txt
$SRCHOME/perl/bin/perl $SRCHOME/emdw/sysman/admin/scripts/storage_report_metrics.pl keys >> ${EM_AGENT_STATE}/storage/stdout.txt
echo -------------- Metric: storage_reporting_alias -------------------->>  ${EM_AGENT_STATE}/storage/stdout.txt
$SRCHOME/perl/bin/perl $SRCHOME/emdw/sysman/admin/scripts/storage_report_metrics.pl issues >> ${EM_AGENT_STATE}/storage/stdout.txt
echo -------------- Metric: storage_reporting_issues -------------------->>  ${EM_AGENT_STATE}/storage/stdout.txt
$SRCHOME/perl/bin/perl $SRCHOME/emdw/sysman/admin/scripts/storage_report_metrics.pl alias >> ${EM_AGENT_STATE}/storage/stdout.txt


for FILE in $RESULT_FILE_LIST
do
  echo
  echo REM checking file $FILE ;
  echo
  diff ${EM_AGENT_STATE}/storage/${FILE} ${EM_STORAGE_TEST_DEPOT}/${EM_STORAGE_TEST_SUBDIR}/storage

done

end_test;
exit 0;
