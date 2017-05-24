#
# Copyright  (c) 2001,2002  Oracle Corporation All rights reserved 
#
#  $Id: README_stormon_mozart.txt,v 1.2 2003/11/18 20:18:51 ajdsouza Exp $ 
#
# MODIFIED	(MM/DD/YY)
# ajdsouza	05/01/03 - Created
#
#
#
Contents of stormon_mozart.tar.gz:
--------------------------------
stormon_jobs.sql	-  package to submit stormon jobs
StormonHostJob.xml	-  File to create the stormon host job type
StormonDbJob.xml	-  File to create the stormon database job type


Setting up the stormon jobs in Mozart
-----------------------------------------------

Utilites required : 
------------------
emutil	 - To register the new job type with em
sqlplus  - To create the job submission package


Setup steps
-----------
1. Extract all files from stormon_mozart.tar.gz
   $ gzip -d stormon_mozart.tar.gz
   $ tar -xvf stormon_mozart.tar

2. Register the stormon host and database job types with the stormon repository as follows

   - To register the stormon host job type
   $ emutil register jobtype StormonHostJob.xml sysman <rep passwd> <rep host> <rep port> <rep sid>

   - To register the stormon database job type
   $ emutil register jobtype StormonDbJob.xml sysman <rep passwd> <rep host> <rep port> <rep sid>

3. Compile the stormon job submission PL/SQL packages as below
   - Login to the em repository through sqlplus. Log in as the admin user sysman.
   $sqlplus sysman/<sysman password>

   - To compile the job submission package execute stormon_jobs.sql.
   SQL>@stormon_jobs.sql


 
