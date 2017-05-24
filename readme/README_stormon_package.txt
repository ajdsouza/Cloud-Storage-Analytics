#
# Copyright  (c) 2001,2002  Oracle Corporation All rights reserved 
#
#  $Id: README_stormon_package.txt,v 1.3 2003/11/18 22:38:17 ajdsouza Exp $ 
#
# MODIFIED	(MM/DD/YY)
# ajdsouza	11/18/03 - Created
#
#
#


Directory structure
-------------------

The following is the directory structure of the stormon package

stormon_package 
    |
    |/bin			-   scripts, binary executables
    |/bin/c-source		-   c sources
    |	
    |/Monitor			-   perl modules
    |/Monitor/OS		-   perl modules
    |/Monitor/Storage		-   perl modules
    |
    |/repository		-   pl/sql packages for the repository
    |/repository/maintenance	-   sql scripts to create stormon schema
    |
    |/em_4_0_jobs		-   sql and xml files for creating and scheduling the stormon job in em4.0
    |		
    |/readme			-   readme files



Steps to set up stormon
-----------------------

1. Build stormon install package 
   - see below

2. Set up the stormon repository
   - refer to readme/README_repository.txt
 
3. Set up the stormon job in em4.0 
   -- See below   
   -- Refer to the FAQ for scheduling stormon jobs readme/EM40_DEPLOYMENT_FAQ.txt 

---------------------------------------------------------------------------------------------------------------

1. BUILD THE STORMON INSTALL PACKAGE

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

1. edit the following files to make sure they point to the right directories in your environment

   stormon_package/bin/stormon		 - $logdirs variable should point to your log directory 
   stormon_package/Monitor/Upload.pm	 - $ENV{ORACLE_HOME} to point to the appropriate ORACLE_HOME directory
   stormon_package/Monitor/Utilities.pm	 - %ENVIRONMENT should point to the correct search directories in your environment
   stormon_package/bin/c-source/runcmd.c - patharray variable points to the correct location of secure executables in your enviroment

2. Execute ./configure in stormom_package/bin/c-source.
   This step creates a make file to build the binaries.

3. Execute make (GNU make) in stormom_package/bin/c-source.
   This step builds and copies the binary executables to stormom_package/bin


PACKAGING
------------
1. Runtime directory structure 

stormon_package 
    |
    |/bin			-   scripts, binary executables
    |	
    |/Monitor			-   perl modules
    |/Monitor/OS		-   perl modules
    |/Monitor/Storage		-   perl modules


2. Directory contents

	stormon_package/bin		- Scripts ,binary executables
	
		COMMON  - stormon,teststdout,testload,runcmd,scsiinq stormon_root.sh
		SOLARIS ONLY - kdisks,kdisks64,run_vxprint,syminfo
		LINUX ONLY -  ideinfo,idainfo,ccissinfo,mdinfo,run_raw,run_sfdisk,run_pvdisplay

	- perl modules directory
	stormon_package/Monitor			Storage.pm, Utilities.pm, Upload.pm
	stormon_package/Monitor/OS		App.pm Solaris.pm Linux.pm Hpux.pm Veritas.pm Filesystem.pm
	stormon_package/Monitor/Storage		Emc.pm Hitachi.pm Sun.pm
					
set the PERL5LIB environment variable to this directory. This will ensure the runtime perl will look up libraries in this directory.

2. Move the scripts, binary executables and perl modules into these directories.

3. On installation As superuser execute the script stormon_root.sh in stormom_package/bin. 
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
  

For Linux
---------
	NONE


---------------------------------------------------------------------------------------------------------------

3. TO SET UP THE STORMON JOB IN THE EM 4.0 JOB SYSTEM

List of files for em 4.0
------------------------
stormon_package/em_4_0_jobs/stormon_jobs.sql	-  package to submit stormon jobs
						   Edit this file to change the repository credentials for your environment
stormon_package/em_4_0_jobs/StormonHostJob.xml	-  File to create the stormon host job type
						-  Edit this file to change the directory for the stormon script for your environment
stormon_package/em_4_0_jobs/StormonDbJob.xml	-  File to create the stormon database job type
						   Edit this file to change the directory for the stormon script for your environment
Utilites required : 
------------------
emutil	 - To register the new job type with em
sqlplus  - To create the job submission package

Setup steps
-----------
1. Register the stormon host and database job types with the stormon repository as follows

   - To register the stormon host job type
   $ emutil register jobtype StormonHostJob.xml sysman <rep passwd> <rep host> <rep port> <rep sid>

   - To register the stormon database job type
   $ emutil register jobtype StormonDbJob.xml sysman <rep passwd> <rep host> <rep port> <rep sid>

2. Compile the stormon job submission PL/SQL packages as below
   - Login to the em repository through sqlplus. Log in as the admin user sysman.
   $sqlplus sysman/<sysman password>

   - To compile the job submission package execute stormon_jobs.sql.
   SQL>@stormon_jobs.sql

3. Refer to readme/EM40_DEPLOYMENT_FAQ.txt for scheduling stormon jobs in EM4.0

---------------------------------------------------------------------------------------------------------------
