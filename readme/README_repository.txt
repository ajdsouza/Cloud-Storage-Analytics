#
# Copyright  (c) 2001,2002  Oracle Corporation All rights reserved 
#
#  $Id: README_repository.txt,v 1.5 2003/11/18 22:58:21 ajdsouza Exp $ 
#
# MODIFIED	(MM/DD/YY)
# ajdsouza	11/17/03 - Created
#
#
#


List of files for stormon repository schema
-------------------------------------------
stormon/repository/maintenance/cr_tbs,sql
stormon/repository/maintenance/cr_stormon_user.sql
stormon/repository/maintenance/drop_stormon_schema.sql
stormon/repository/maintenance/cr_stormon_schema_size.sql
stormon/repository/maintenance/cr_stormon_mozart_schema.sql
stormon/repository/storage_summary_load.sql
stormon/repository/storage_summary_db_9i.sql
stormon/repository/storage_summary_analysis.sql


Steps to install stormon schema
-------------------------------

1. As dba execute stormon/repository/maintenance/cr_tbs				

   -- Creates the tablespaces for holding stormon schema
   -- You can edit this file to change the location of the datfiles on your host.

2. As dba execute cr_stormon_user					
	
   -- Creates the stormon oem(9i) user <storage_rep> who is the owner of the stormon schema and the stormon mozart(em4.0) user <stormon_mozart> who owns the
     mozart master tables.

   -- You can edit this file to modify the username and password for the stormon oem user or the stormon mozart user.										   

3. As stormon user <storage_rep> execute cr_stormon_schema_size			

   -- Creates the stormon schema in the stormon oem(9i) user <storage_rep>
   
   -- Edit this file to define the database links to fetch the target list and stormon job data.

4. As stormon mozart user <storage_mozart> execute cr_stormon_mozart_schema	

   -- Creates the stormon schema for stormon mozart(em4.0) user <stormon_mozart>


Steps to schedule stormon repository DBMS jobs
----------------------------------------------
1. As the stormon owner execte the procedure storage_summary.submitjobs as follows.

 SQL>  EXEC STORAGE_SUMMARY.SUBMITJOB


Steps to stop the stormon DBMS jobs
----------------------------------------
1. As the stormon user execute the following

 SQL>  EXEC STORAGE_SUMMARY.CLEANJOB


Refreshing the master tables
----------------------------
stormon relies on the target master , and job execution information from the em9i and the mozart repositories.
The tables that are populated from the 9i and mozart repositories are.

    1.	    mgmt_targets		  -  from mgmt_targets in oem 9i
    2.	    mgmt_mozart_targets		  -  from mgmt_targets in mozart ( em4.0)
    3.	    node_target_map		  -  from 9i
    4.	    mozart_node_target_map	  -  from mozart
    5.	    smp_vdj_job_per_target	  -  from 9i
    6.	    mozart_smp_vdj_job_per_target -  from mozart

The following views in the stormon schema are based on these tables.

    - mgmt_targets_view
    - active_stormon_target_view
    - stormon_summary_status_view
    - merged_node_target_view
    - mgmt_targets_new
    - mgmt_targets_to_be_migrated
    - smp_view_targets

Migrating data to mozart
------------------------
Historically the stormon jobs have been scheduled using the optional monitoring framework in 9i. As mozart gets deployed stormon jobs will be scheduled to mozart.
The stormon history data from 9i jobs will be migrated to the mozart target_guid.

Procedures for refreshing the master tables and migrating data
--------------------------------------------------------------

STORAGE_SUMMARY_DB.REFRESH_TARGETS	      - Refreshes the target data from the oem 9i repository
STORAGE_SUMMARY_DB.REFRESH_MOZART_TARGETS     - Refresh the targets data in stormon from the mozart repository.
STORAGE_SUMMARY_DB.MIGRATE_TARGETS	      - Migrates the 9i data to mozart
STORAGE_SUMMARY_DB.MERGE_TARGETS	      - Creates a merged master for 9i and the mozart targets
STORAGE_SUMMARY_DB.REFRESH_DC_LOB_GROUPS      - Refreshes the group configuration information in the stormon repository.

All the above procedures are executed periodically by STORAGE_SUMMARY.REFRESH_MASTERS.




