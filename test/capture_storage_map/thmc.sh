#!/bin/sh  

# for debugging
#set -x

if [ "$1" != "" ]; then
  EM_STORAGE_TEST_NAME=$1;export EM_STORAGE_TEST_NAME
fi

echo
echo REM ----------------- Begin capture results for test ${EM_STORAGE_TEST_NAME} ------------------;
echo

PERL5LIB=${PERL5LIB}:$SRCHOME/emagent/sysman/admin/scripts:$SRCHOME/perl/lib:$SRCHOME/perl/lib/site_perl;export PERL5LIB
EMAGENT_PERL_TRACE_LEVEL=0; export EMAGENT_PERL_TRACE_LEVEL
EMAGENT_PERL_TRACE_DIR==$SRCHOME/emagent/sysman/log; export EMAGENT_PERL_TRACE_DIR
EM_AGENT_STATE=${SRCHOME}/emagent;export EM_AGENT_STATE
EM_TARGET_GUID=`hostname`;export EM_TARGET_GUID
EM_TARGET_NAME=`hostname`;export EM_TARGET_NAME

EM_STORAGE_RMODE=CAPTURE;export EM_STORAGE_RMODE
EM_STORAGE_PRINT_TOPOLOGY=YES; export EM_STORAGE_PRINT_TOPOLOGY
EM_STORAGE_TEST_DAT_DIR=${SRCHOME}/emagent/test/src/emd/tvmac;export EM_STORAGE_TEST_DAT_DIR
EM_STORAGE_TEST_GOLD_DIR=${SRCHOME}/emagent/test/log/emd/tvmac;export EM_STORAGE_TEST_GOLD_DIR
CFGFILE=tvmacs.cfg

# <test_name>.dat directory
if [ ! -d ${EM_STORAGE_TEST_DAT_DIR} ]; then
  mkdir -m 755 -p ${EM_STORAGE_TEST_DAT_DIR}
fi
# <test_name>.log directory
if [ ! -d ${EM_STORAGE_TEST_GOLD_DIR} ]; then
  mkdir -m 755 -p ${EM_STORAGE_TEST_GOLD_DIR}
fi

# <test_name>.dat directory
if [ ! -d ${EM_STORAGE_TEST_DAT_DIR} ]; then
  echo
  echo "REM Aborting test ${EM_STORAGE_TEST_NAME}, Test Data directory  ${EM_STORAGE_TEST_DAT_DIR} is not present , this directory to capture files should be available";
  exit 1;
fi

# <test_name>.log directory
if [ ! -d ${EM_STORAGE_TEST_GOLD_DIR} ]; then
  echo
  echo "REM Aborting test ${EM_STORAGE_TEST_NAME}, Gold directory  ${EM_STORAGE_TEST_GOLD_DIR} is not present , this directory to capture gold file should be available";
  exit 1;
fi


# If the old dat file exists delete it
if [ "$EM_STORAGE_TEST_NAME" != "" ]; then


  EM_STORAGE_TEST_DAT_FILE=${EM_STORAGE_TEST_DAT_DIR}/${EM_STORAGE_TEST_NAME}.dat;

  if [ -f ${EM_STORAGE_TEST_DAT_FILE} ]; then
  
    echo "REM !!! File $EM_STORAGE_TEST_DAT_FILE already EXISTS,do you want to CLEAN UP File and proceed ?"
    read  DELETE_FILE
    if [ ${DELETE_FILE} != y ]; then
     echo REM Aborting this test capture, restart with a different test name
     exit 1
    fi

    echo
    echo REM Deleting old file ${EM_STORAGE_TEST_DAT_FILE}
    echo
    rm ${EM_STORAGE_TEST_DAT_FILE}

  fi

fi

# Get an description for the test
echo
echo Provide a verbose description for the test
echo
read EM_STORAGE_TEST_DESCRIPTION
export EM_STORAGE_TEST_DESCRIPTION

# Executiong the metrics for capture
echo
echo REM Executing metrics for capture 
echo

ESTDOUT=${EM_STORAGE_TEST_GOLD_DIR}/${EM_STORAGE_TEST_NAME}.log
ESTDERR=${EM_STORAGE_TEST_GOLD_DIR}/${EM_STORAGE_TEST_NAME}.err

:> ${ESTDOUT}
:> ${ESTDERR}

METRIC_LIST="data keys alias issues"

for METRIC in ${METRIC_LIST}
do
  echo REM -------------- Metric: storage_reporting_${METRIC} -------------------->>  ${ESTDOUT} 2>>${ESTDERR}
  $SRCHOME/perl/bin/perl $SRCHOME/emagent/sysman/admin/scripts/storage_report_metrics.pl ${METRIC} >> ${ESTDOUT} 2>>${ESTDERR}
done

# Verify the capture
echo
echo REM To view results : cat ${ESTDOUT}
echo REM To view errors : cat ${ESTDERR}
cat ${ESTDERR}
echo

if [ "${EM_STORAGE_TEST_NAME}" != "" ]; then
    echo REM !! Test file captured to ${EM_STORAGE_TEST_DAT_FILE} 
else
  echo  REM Check file ${EM_STORAGE_TEST_DAT_DIR}/${CFGFILE} for the testname and test directory of results
fi

exit 0;
