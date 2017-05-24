Scripts for capturing storage layout of the target host
-------------------------------------------------------

Description
-----------
The scripts capture the storage layout of the host to a ascii file.
The captured data will be used for regression testing for product development
of EM 10GR2.

Platforms supported
-------------------
- Solaris 2.7 and above 
- Linux

Installation Requirements
-------------------------
1. perl v 5.6.1 or above. The perl executable should be available in directory
   /usr/local/git/perl/bin/perl


Setup Instructions
------------------
1. Untar the package emstmn.tar.
2. Change directory to emstmn
3. Execute ./setup.sh in this directory
   - this will set up the symbolic links to the right versions of files for the OS.

4. As SUPERUSER execute ./ssuid.sh
   - this will set suid privilege for executable srchome/emagent/bin/nmhs


Execution Instructions
----------------------
./rtst.sh thm.sh  
  - to print the storage configuration of the host to STDOUT

./rtst.sh thmc.sh <test_name_to_capture>
  - will capture the storage layout of the host to file
      srchome/emagent/test/src/emd/tvmac/<testname_to_capture>.dat

Security
--------
The scripts require read only access to storage resources on the host.
The use of suid executable is similar to that used with the stormon package, which is
used in GIT for monitoring usage of storage on hosts. All privileged access is 
done thru ONLY one executable srchome/emagent/bin/nmhs. This is the only executable 
which requires suid privilege. This executable source has been approved by Oracle
Security. 

