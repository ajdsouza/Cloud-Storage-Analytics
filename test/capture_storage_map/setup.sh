#!/bin/sh 

# debug
#set -x

LIST_OF_DIRS="srchome srchome/emagent/bin srchome/emagent/storage srchome/emagent/sysman/admin/scripts/storage srchome/emagent/test/src/emd/tvmac srchome/emagent/test/log/emd/tvmac srchome/work"

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


# Check if destination directories exist 
for DIR in ${LIST_OF_DIRS} 
do
  if [ ! -d ${DIR} ]; then
    echo 'Directory  ${DIR} does not exist'
    exit 1
  fi
done


# Link nmhs to the right osd
DIR="srchome/emagent/bin"

if [ ! -f srchome/emagent/bin/nmhs.${OSNAME}${VERSION}.exe ]; then
  echo File srchome/emagent/bin/nmhs.${OSNAME}${VERSION}.exe does not exist
  exit 1;
fi

RES=`cd ${DIR};
rm nmhs;
ln -s nmhs.${OSNAME}${VERSION}.exe nmhs`
echo execute ssuid.sh as super user 


# Link sRawmetrics.pm to the right osd
DIR="srchome/emagent/sysman/admin/scripts/storage"

if [ ! -f srchome/emagent/sysman/admin/scripts/storage/sRawmetrics.${OSNAME}.pm ]; then
  echo File srchome/emagent/sysman/admin/scripts/storage/sRawmetrics.${OSNAME}.pm does not exist
  exit 1;
fi

RES=`cd ${DIR};
rm sRawmetrics.pm;
ln -s sRawmetrics.${OSNAME}.pm sRawmetrics.pm`


#Link to the right perl
# Chose with perl to link to
if [ "${SRCHOME}" != "" -a -f ${SRCHOME}/perl/bin/perl ]; then
  PERL=${SRCHOME}/perl
elif [ -f /usr/local/git/perl/bin/perl ]; then
  PERL="/usr/local/git/perl"
elif [ -f /usr/bin/perl ]; then
  PERL="/usr"
else
  echo Require perl 5.6.1 or higher 
  exit 1
fi

DIR="srchome"
RES=`cd ${DIR};
rm perl;
ln -s ${PERL} perl`

exit 0;

