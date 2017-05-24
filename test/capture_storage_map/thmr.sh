#!/bin/sh 

if [ "$1" != "" ]; then
  EM_STORAGE_TEST_NAME=$1;export EM_STORAGE_TEST_NAME
fi

PERL5LIB=${PERL5LIB}:$SRCHOME/emagent/sysman/admin/scripts:$SRCHOME/perl/lib:$SRCHOME/perl/lib/site_perl;export PERL5LIB
EMAGENT_PERL_TRACE_LEVEL=0; export EMAGENT_PERL_TRACE_LEVEL
EMAGENT_PERL_TRACE_DIR=$SRCHOME/emagent/sysman/log; export EMAGENT_PERL_TRACE_DIR
EM_TARGET_GUID=`hostname`;export EM_TARGET_GUID
EM_TARGET_NAME=`hostname`;export EM_TARGET_NAME

EM_STORAGE_RMODE=REGRESSION;export EM_STORAGE_RMODE
EM_STORAGE_PRINT_TOPOLOGY=YES; export EM_STORAGE_PRINT_TOPOLOGY
EM_AGENT_STATE=${SRCHOME}/emagent;export EM_AGENT_STATE
EM_STORAGE_TEST_DAT_DIR=${SRCHOME}/emagent/test/src/emd/tvmac;export EM_STORAGE_TEST_DAT_DIR
EM_STORAGE_TEST_GOLD_DIR=${SRCHOME}/emagent/test/log/emd/tvmac;export EM_STORAGE_TEST_GOLD_DIR
EM_STORAGE_TEST_LOG_DIR=${T_WORK};export EM_STORAGE_TEST_LOG_DIR
CFGFILE=tvmacs.cfg

end_test()
{
  echo ''
  echo REM --------------------------- END storage regression test ${EM_STORAGE_TEST_NAME} ------------------------------
}


echo REM --------------------------- Start storage regression test ${EM_STORAGE_TEST_NAME} ------------------------------
echo ''

# <test_name>.dat directory
if [ ! -d ${EM_STORAGE_TEST_DAT_DIR} ]; then
  echo
  echo "REM Aborting test ${EM_STORAGE_TEST_NAME}, Test Data directory  ${EM_STORAGE_TEST_DAT_DIR} is not present , this directory with captured files should be available";
  end_test;
  exit 1;
fi

# <test_name>.log directory
if [ ! -d ${EM_STORAGE_TEST_GOLD_DIR} ]; then
  echo
  echo "REM Aborting test ${EM_STORAGE_TEST_NAME}, Gold directory  ${EM_STORAGE_TEST_GOLD_DIR} is not present , this directory to diff with captured godl file  should be available";
  end_test;
  exit 1;
fi

# Log directory to log the concatenated results of this test
if [ ! -d ${EM_STORAGE_TEST_LOG_DIR} ]; then
  mkdir -m 755 -p ${EM_STORAGE_TEST_LOG_DIR}
fi

if [ ! -d  ${EM_STORAGE_TEST_LOG_DIR} ];
then
  echo
  echo "REM Aborting test ${EM_STORAGE_TEST_NAME}, Log directory  ${EM_STORAGE_TEST_LOG_DIR}/storage is not present ";
  end_test;
  exit 1;
fi

# Execute the metrics
echo
echo REM Executing metrics from captured files 
echo

ESTDOUT=${EM_STORAGE_TEST_LOG_DIR}/${EM_STORAGE_TEST_NAME}.log
ESTDERR=${EM_STORAGE_TEST_LOG_DIR}/${EM_STORAGE_TEST_NAME}.err

:> ${ESTDOUT}
:> ${ESTDERR}

METRIC_LIST="data keys alias issues"

for METRIC in ${METRIC_LIST}
do
  echo REM -------------- Metric: storage_reporting_${METRIC} -------------------->>  ${ESTDOUT} 2>>${ESTDERR}
  $SRCHOME/perl/bin/perl $SRCHOME/emagent/sysman/admin/scripts/storage_report_metrics.pl ${METRIC} >> ${ESTDOUT} 2>>${ESTDERR}
done

# Diff the result file with the test file
echo
echo REM To view results : cat ${ESTDOUT}
echo REM To view errors : cat ${ESTDERR}
echo

if [ "${EM_STORAGE_TEST_NAME}" != "" ]; then
 echo REM --------------------------------------------------------------------------
 echo REM diffing between ${EM_STORAGE_TEST_LOG_DIR}/${EM_STORAGE_TEST_NAME}.log ${EM_STORAGE_TEST_GOLD_DIR}/${EM_STORAGE_TEST_NAME}.log
 echo
 diff ${EM_STORAGE_TEST_LOG_DIR}/${EM_STORAGE_TEST_NAME}.log ${EM_STORAGE_TEST_GOLD_DIR}/${EM_STORAGE_TEST_NAME}.log
else
  echo  REM Check file ${EM_STORAGE_TEST_DAT_DIR}/${CFGFILE} for the testname and diff with the test gold file in  ${EM_STORAGE_TEST_GOLD_DIR} to compare results
fi

end_test;

exit 0;
