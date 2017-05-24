#!/bin/sh

RES=`cd srchome/emagent/bin;
chown root nmhs*;
chmod ugo+rx nmhs*;
chmod u+s nmhs*
chmod ugo-s nmhs.solaris56.exe`

ls -l srchome/emagent/bin

exit 0;
