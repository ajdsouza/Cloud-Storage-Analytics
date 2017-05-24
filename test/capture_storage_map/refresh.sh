#!/bin/sh 

# for debugging
#set -x

if [ "$1" != "" ]; then
  COPY_FILES=$1
fi

if [ "$2" != "" ]; then
  OSD_FILES_ONLY=$2
fi
 
#List of files and directories to be refreshed from ade
LIST_OF_DIRS="srchome srchome/emagent/bin srchome/emagent/storage srchome/emagent/sysman/admin/scripts/storage srchome/emagent/test/src/emd/tvmac srchome/emagent/test/log/emd/tvmac srchome/work"
LIST_OF_FILES="emagent/bin/nmhs emagent/sysman/admin/scripts/storage_report_metrics.pl emagent/sysman/admin/scripts/emd_common.pl emagent/sysman/admin/scripts/storage/sRawmetrics.pm emagent/sysman/admin/scripts/storage/Register.pm emagent/sysman/admin/scripts/storage/sUtilities.pm emagent/sysman/admin/scripts/storage/Utilities.pm emagent/sysman/admin/scripts/storage/vendor/Emc.pm emagent/sysman/admin/scripts/storage/vendor/Veritas.pm emagent/sysman/admin/scripts/storage/vendor/Hitachi.pm"
LIST_OF_OSD_FILES="emagent/sysman/admin/scripts/storage/sRawmetrics.pm emagent/bin/nmhs"

# Get the os version and name
OS=`uname`

if [ "${OS}" = "SunOS" ]; then
 OSNAME="solaris"
 VERSION=`uname -a|grep '5\.6'`
 if [ "${VERSION}" != "" ]; then
   VERSION="56"
 else
   VERSION=""
 fi
elif [ "${OS}" = "Linux" ]; then
 OSNAME="linux"
fi

# Check if destination directories exist make them
for DIR in ${LIST_OF_DIRS} 
do
  if [ ! -d ${DIR} ]; then
    mkdir -m 755 -p ${DIR}
  fi

  if [ ! -d ${DIR} ]; then
    echo 'Directory  ${DIR} does not exist'
    exit 1;
  fi
done


# Check for SRCHOME
if [ "${SRCHOME}" = "" ]; then
  echo SRCHOME is not defined
  exit 1;
fi

if [ ! -d ${SRCHOME} ]; then
  echo Directory SRCHOME ${SRCHOME} does not exist
  exit 1;
fi

if [ ! -r ${SRCHOME} ]; then
  echo Directory SRCHOME ${SRCHOME} is not readable
  exit 1;
fi

# Copy files if flag says so
if [ "${COPY_FILES}" = "Y" ]; then

   # Copy only the OSD files
   if  [ "${OSD_FILES_ONLY}" = "Y" ]; then
     LIST_OF_FILES=${LIST_OF_OSD_FILES}
   fi

   if [ "${OSNAME}" = "SunOS" -a "${VERSION}" = "56" ]; then
    echo
    echo Important !!, For version 5.6 use dummy perlscript nmhs.solaris56.exe instead of nmhs.solaris.exe
    echo
    echo Important !!, remember to add 5.6 support for srchome/emagent/sysman/admin/scripts/storage/sRawmetrics.pm
   fi

   for FILE in ${LIST_OF_FILES} 
   do

     if  [ ${FILE} = "emagent/sysman/admin/scripts/storage/sRawmetrics.pm" ]; then
      DEST_FILE=emagent/sysman/admin/scripts/storage/sRawmetrics.${OSNAME}.pm
     elif [ ${FILE} = "emagent/bin/nmhs" ]; then
      DEST_FILE=emagent/bin/nmhs.${OSNAME}.exe
     else
      DEST_FILE=${FILE}
     fi

     if [ ! -f ${SRCHOME}/${FILE} ]; then
       exit 1;
     fi

     cp -f ${SRCHOME}/${FILE} srchome/${DEST_FILE}

   done

fi

exit 0;
