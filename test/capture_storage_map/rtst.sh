#!/bin/sh

CURDIR=`pwd`
if [ "${CURDIR}" = "" ]; then
 CURDIR=.
fi

if [ ! -d ${CURDIR}/srchome ]; then
 echo Directory  ${CURDIR}/srchome is required
 exit 1
fi

SRCHOME=${CURDIR}/srchome;export SRCHOME
ORACLE_HOME=${SRCHOME};export ORACLE_HOME
T_WORK=${SRCHOME}/work;export T_WORK

if [ "$1" = "" ]; then
  echo
  echo "Usage ./rtst.sh <shell script to execute>"
  exit 1
fi

RETVAL= ${CURDIR}/$1 $2 $3 $4 $5

exit ${RETVAL}
