#!/bin/sh
#
# Copyright  (c) 2001,2002  Oracle Corporation All rights reserved 
#
#  $Id: stormon_root.sh,v 1.17 2002/12/06 19:16:18 vswamida Exp $ 
#
#
# NAME  
#	 stormon_root.sh
#
# DESC 
# 	Set the suid and execute permission for binary executables
#	This script should be executed as super user
#
# FUNCTIONS
#
#
# NOTES
#
#
# MODIFIED	(MM/DD/YY)
# ajdsouza	10/01/01 - Created
#

# List of files that need permissions set
FILELIST="stormon runcmd syminfo run_vxprint kdisks kdisks64 scsiinq ideinfo idainfo ccissinfo mdinfo run_raw run_sfdisk run_pvdisplay testload teststdout"

# Grant execute privilege for all scripts
for file in $FILELIST
do
        if [ -r "$file" ];
        then
                chmod 755 $file;
        fi
done

# Grant suid privilege for the following script
chown root runcmd
chmod u+s runcmd

exit
