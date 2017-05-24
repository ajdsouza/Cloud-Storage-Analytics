#
# Copyright  (c) 2001,2002  Oracle Corporation All rights reserved 
#
#  $Id: README9i.txt,v 1.26 2003/03/18 01:43:59 ajdsouza Exp $ 
#
# MODIFIED	(MM/DD/YY)
# ajdsouza	10/03/02 - Symapi changes
# ajdsouza	10/01/01 - Created
#
#
#

NOTE
----

1. Operating systems currently supported are Solaris , Linux and HPUX
2. For solaris versions 2.7 and higher(64 bit) an extra executable kdisks64 is required to be built in addition
to the executables built on 2.6.
3. The platform supported for Linux is Intel x86, with Redhat and SuSE distributions
 

BUILD ENVIRONMENT 
-----------------

For SOLARIS 
-----------

1. EMC symapi version 4.3 is required to be installed.

   Specifically, the following files are required to be present:
	/usr/include/symapi.h
	/usr/lib/libsymapi43.so 
	(
	/usr/lib/libsymapi43.so is the Symapi V4.3 /usr/lib/libsymapi.so renamed,
	rename /usr/lib/libsymapi.so to /usr/lib/libsymapi43.so)
   
2. Solaris native compiler (the one which is used to build the kernel) is required for
   building the executables.  It must be located under /usr/bin or /opt/SUNWspro/bin.
   (Use symbolic link if compiler is not in these directories)

3. The gnu c compiler , gcc is required.



For LINUX
---------

1. Linux kernel 2.2.x or higher
2. The gnu c compiler , gcc 
3. The following linux header files are should be in the standard location (/usr/include)
        linux/cciss_ioctl.h
        linux/raid/md_u.h
        linux/hdreg.h
4. The linux kernel sources must be installed ( to access the following header files):
	drivers/block/ida_ioctl.h
	drivers/block/ida_cmd.h	


BUILD STEPS
-----------

1.CVS directory structure on software.us.oracle.com for storage monitoring sources.     

	$CVSROOT/git/oem/storage		- perl Scripts , shell scripts
	$CVSROOT/git/oem/storage/c-source	- C sources and autoconf files
	$CVSROOT/git/perl-addon/Monitor		- perl modules

2. Checkout the sources tagged storage_blessed in these directories from cvs.

3. Execute ./configure in git/oem/storage/c-source.
   This step creates a make file to build the binaries.

4. Execute make (GNU make) in git/oem/storage/c-source.
   This step builds and copies the binary executables to git/oem/storage


PACKAGING
------------
1. Runtime directory structure 

	/usr/local/git/oem/storage		- Scripts ,binary executables
	
		COMMON  - stormon,teststdout,testload,runcmd,scsiinq

		SOLARIS ONLY - kdisks,kdisks64,run_vxprint,syminfo
		LINUX ONLY -  ideinfo,idainfo,ccissinfo,mdinfo,run_raw,run_sfdisk,run_pvdisplay

	/usr/local/git/perl-addon/Monitor	- perl modules directory structure

2. Move the scripts, binary executables and perl modules into these directories.

3. As superuser execute the script stormon_root.sh in /usr/local/git/oem/storage. 
  - This sets the appropriate execute privilege on all scripts and executables 
  - It sets the root/suid privlege for executable runcmd.


RUNTIME REQUIREMENTS
--------------------

For Solaris 
-----------
1. EMC SYMCLI V4.3 is required to be installed if EMC specific disk information
   is required to be obtained. 

   Specifically the following files from EMC SYMCLI V4.3 are required to be present
   - /var/symapi/config/symapi_licenses.dat
     /var/symapi/config/symapi_licenses.dat is the license file whose contents should be 
      the appropriate valid license for use of EMC SYMCLI.

   - /usr/lib/libsymapi43.so  
   ( /usr/lib/libsymapi43.so is the SYMCLI V4.3 /usr/lib/libsymapi.so renamed 
   Rename /usr/lib/libsymapi.so from EMC SYMCLI V4.3 to /usr/lib/libsymapi43.so )
  
  EMC SYMCLI V 4.3 can be downloaded from 
  http://software.us.oracle.com/software/EMC/Solutions_Enabler/v4.3/Solaris/v4.3/UNIX/	  

  The license keys for the /var/symapi/config/symapi_licenses.dat file can be obtained from
  http://software.us.oracle.com/software/EMC/Solutions_Enabler/v4.3/


For Linux
---------
	NONE


