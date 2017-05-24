--  
--
-- Copyright  (c) 2001,2002  Oracle Corporation All rights reserved 
--
--
--
-- $Id: drop_stormon_schema.sql,v 1.22 2003/11/17 22:36:12 ajdsouza Exp $ 
--
--
-- NAME  
--	 drop_stormon_schema.sql
--
-- DESC 
--  drop Storage monitoring schema
--
--
-- FUNCTIONS
--
--
-- NOTES
--
--
-- MODIFIED	(MM/DD/YY)
-- ajdsouza	07/15/02 	- Created

DROP VIEW storage_warnings_view
/
DROP VIEW storage_groupissues_view
/
DROP VIEW storage_dc_lob_group_view
/
DROP VIEW storage_dc_lob_summary_view
/
DROP VIEW active_stormon_targets
/
DROP VIEW active_stormon_targets
/
DROP TABLE storage_history_17weeks
/
DROP TABLE storage_history_12months
/
DROP TABLE stormon_share_history
/
DROP TABLE stormon_share
/
DROP TABLE stormon_share_table
/
DROP TABLE stormon_share_hosts
/
DROP TABLE storage_detail
/
DROP TABLE storage_hostdetail
/
DROP TABLE diskTable
/
DROP TABLE swraidTable
/
DROP TABLE volumeTable
/
DROP TABLE filesystemTable
/
DROP TABLE applicationTable
/
DROP TABLE storage_target_dc_lob
/
DROP TABLE storage_dc_lob_group_table
/
DROP TABLE stormon_group_reports_type
/ 

DROP TYPE detailTable
/
DROP TYPE detailObject
/
DROP TYPE storageTable
/
DROP TYPE storageObject
/
DROP TYPE linkinodeTable
/
DROP TYPE linkinodeObject
/
DROP TYPE storageApplicationTable
/
DROP TYPE applicationObject
/
DROP TYPE storageFilesystemTable
/
DROP TYPE filesystemObject
/
DROP TYPE storageVolumeTable
/
DROP TYPE volumeObject
/
DROP TYPE storageDiskTable
/
DROP TYPE diskObject
/

DROP FUNCTION concatlist
/

--------------------------------------
EXECUTE STORAGE_SUMMARY.CLEANJOB
/
-- This will break the job if its executing
-- Else package can be dropped only after execution of the
-- the job has been completed

DROP TABLE storage_lock_table
/

DROP PACKAGE STORAGE_SUMMARY
/
DROP PACKAGE STORAGE_SUMMARY_DB
/
DROP PACKAGE STORAGE_SUMMARY_LOAD
/
----------------------- Temporary tables -------------------------
DROP TABLE stormon_temp_app
/
DROP TABLE stormon_temp_filesystem
/
DROP TABLE stormon_temp_volume
/
DROP TABLE stormon_temp_swraid
/
DROP TABLE stormon_temp_disk
/
DROP TABLE stormon_temp_comb_app
/
DROP TABLE stormon_temp_comb_filesystem
/
DROP TABLE stormon_temp_comb_volume
/
DROP TABLE stormon_temp_comb_swraid
/
DROP TABLE stormon_temp_comb_disk
/
------------------------------------------------------------------
DROP VIEW stormon_summary_status_view
/
DROP VIEW storage_summaryObject_view
/
DROP VIEW stormon_active_targets_view
/
DROP VIEW merged_node_target_map_view
/ 
DROP VIEW mgmt_targets_view
/
DROP VIEW smp_view_targets
/
DROP VIEW mgmt_targets_to_be_migrated
/
DROP VIEW mgmt_targets_merged_view
/
DROP VIEW mgmt_targets_new
/
DROP VIEW stormon_history_week_view
/
DROP VIEW stormon_history_day_view
/
DROP VIEW stormon_hostdetail_view
/
DROP VIEW storage_stats_view
/
DROP VIEW storage_issues_view
/
DROP VIEW storage_oracledb_view
/
DROP VIEW storage_nfs_shared_view
/
DROP VIEW storage_nfs_view
/
DROP VIEW storage_localfs_view
/
DROP VIEW storage_volume_view
/
DROP VIEW storage_swraid_view
/
DROP VIEW storage_disk_view
/


DROP SEQUENCE stormonGroupId
/
DROP TABLE stormon_group_table
/
DROP TABLE stormon_group_of_groups_table
/
DROP TABLE stormon_host_groups
/
DROP TABLE storage_statistics
/
DROP TABLE storage_log
/
DROP TABLE storage_summaryObject_history
/
DROP TABLE storage_history_30days
/
DROP TABLE storage_history_52weeks
/
DROP TABLE storage_summaryObject
/
DROP TABLE storage_disk_table
/
DROP TABLE storage_swraid_table
/
DROP TABLE storage_volume_table
/
DROP TABLE storage_nfs_table
/
DROP TABLE storage_localfs_table
/
DROP TABLE storage_application_table
/
DROP TABLE mozart_mgmt_targets
/
DROP TABLE mozart_node_target_map
/
DROP TABLE mozart_smp_vdj_job_per_target
/
DROP TABLE stormon_load_status
/ 
DROP TABLE mgmt_migrated_targets
/
DROP TABLE mgmt_targets_merged
/
DROP TABLE MGMT_METRICS
/
DROP TABLE MGMT_TARGETS
/
DROP TABLE NODE_TARGET_MAP
/
DROP TABLE SMP_VDJ_JOB_PER_TARGET
/

DROP TYPE storageSummaryTable
/
DROP TYPE summaryObject
/
DROP TYPE dateTable
/
DROP TYPE numberTable
/
DROP TYPE stringTable
/

ALTER SESSION CLOSE DATABASE LINK package_db
/
DROP DATABASE LINK package_db
/
ALTER SESSION CLOSE DATABASE LINK oemdtc
/
DROP DATABASE LINK oemdtc
/
ALTER SESSION CLOSE DATABASE LINK mozartdb
/
DROP DATABASE LINK mozartdb
/

SELECT OBJECT_NAME, OBJECT_TYPE FROM USER_OBJECTS
/
