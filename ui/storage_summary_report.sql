--  
--
-- Copyright  (c) 2001,2002  Oracle Corporation All rights reserved 
--
--
--
-- $Id: storage_summary_report.sql,v 1.13 2003/10/25 01:51:00 ajdsouza Exp $ 
--
--
-- NAME  
--	 storage_summary_report.sql
--
-- DESC 
--  Creates the views for executing storage reports
--
--
-- FUNCTIONS
--
--
-- NOTES
--
--
-- MODIFIED	(MM/DD/YY)
-- ajdsouza	07/10/02 	- Created

DROP SYNONYM storage_summary
/
DROP SYNONYM storage_summary_db
/
DROP TYPE issueTable
/
DROP TYPE issueObject
/
DROP TYPE storageTable 
/
DROP TYPE storageObject 
/
DROP TYPE titleObject 
/
DROP SYNONYM storage_detail 
/
DROP SYNONYM stormon_share
/
DROP SYNONYM stormon_share_history
/
DROP SYNONYM storage_log
/
DROP SYNONYM storage_summaryObject_History 
/
DROP SYNONYM storage_history_17weeks
/
DROP SYNONYM storage_history_12months
/
DROP SYNONYM storage_history_30days
/
DROP SYNONYM storage_history_52weeks
/
DROP SYNONYM storage_hostdetail 
/
DROP SYNONYM mgmt_targets
/
DROP SYNONYM storage_warnings_view
/
DROP SYNONYM storage_groupissues_view
/
DROP SYNONYM storage_dc_lob_summary_view
/
DROP SYNONYM storage_target_dc_lob
/
DROP SYNONYM stormonGroupId
/
DROP TYPE detailTable 
/
DROP TYPE detailObject
/
DROP TABLE stormon_group_hosts
/
DROP SEQUENCE stormonHostGroupIdSequence
/
DROP TABLE stormon_group_list
/
DROP TABLE stormon_group_summary
/
DROP TYPE storageSummaryTable 
/
DROP TYPE summaryObject
/
-------------------------------------------

DROP TABLE stormon_temp_results
/

DROP SYNONYM storage_oracledb_view
/

DROP SYNONYM storage_localfs_view
/

DROP SYNONYM storage_nfs_view
/

DROP SYNONYM storage_nfs_shared_view
/

DROP SYNONYM storage_volume_view
/

DROP SYNONYM storage_swraid_view
/

DROP SYNONYM storage_disk_view
/

DROP SYNONYM storage_issues_view
/

DROP SYNONYM storage_summaryObject 
/

DROP SYNONYM storage_summaryObject_view
/

DROP SYNONYM stormon_history_day_view
/

DROP SYNONYM stormon_history_week_view
/

DROP SYNONYM stormon_hostdetail_view 
/

DROP SYNONYM stormon_group_table
/

DROP SYNONYM stormon_group_of_groups_table
/

DROP SYNONYM stormon_host_groups
/

DROP SYNONYM stormon_group_reports_type
/

DROP SYNONYM mgmt_targets_view
/

DROP TYPE stringTable 
/

DROP TYPE intTable
/

DROP TYPE numberTable 
/

DROP TYPE dateTable 
/

ALTER SESSION CLOSE DATABASE LINK storagedb
/

DROP DATABASE LINK storagedb
/

----------------------------------

------------------------------
-- PRODUCTION DATABASE LINK
------------------------------
CREATE SHARED DATABASE LINK storagedb CONNECT TO stormon_test IDENTIFIED BY stormon_test  AUTHENTICATED BY stormon_test IDENTIFIED BY stormon_test USING '(DESCRIPTION = (ADDRESS_LIST = (ADDRESS = (PROTOCOL = TCP)(HOST = rmsun11.us.oracle.com)(PORT = 1521)))(CONNECT_DATA = (SID = emap)(GLOBAL_NAME = emap_rmsun11)(SERVER = dedicated)))'
------------------------------
-- DEVELOPMENT DATABASE LINK
------------------------------
--CREATE SHARED DATABASE LINK storagedb CONNECT TO stormon_test IDENTIFIED BY stormon_test AUTHENTICATED BY stormon_test IDENTIFIED BY stormon_test USING '(DESCRIPTION = (ADDRESS_LIST = (ADDRESS = (PROTOCOL = TCP)(HOST = eagle1-pc.us.oracle.com)(PORT = 1521))) (CONNECT_DATA = (SID = iasem)))'
--CREATE SHARED DATABASE LINK storagedb CONNECT TO stormon_test IDENTIFIED BY stormon_test AUTHENTICATED BY stormon_test IDENTIFIED BY stormon_test USING '(DESCRIPTION = (ADDRESS_LIST = (ADDRESS = (PROTOCOL = TCP)(HOST = usunrat24.us.oracle.com)(PORT = 1521))) (CONNECT_DATA = (SID = ora901)))'
/
--------------------------------------------------

-- Table of Dates
CREATE TYPE dateTable AS TABLE OF DATE
/

-- Table of integers
CREATE TYPE intTable AS TABLE OF INTEGER
/

-- Type numberTable is table of numbers
CREATE TYPE numberTable AS TABLE OF NUMBER(16)
/

CREATE TYPE stringTable AS TABLE OF VARCHAR2(32767)
/

CREATE SYNONYM mgmt_targets_view FOR mgmt_targets_view@storagedb
/

--CREATE SYNONYM stormonGroupId FOR stormonGroupId@storagedb
--/

CREATE SYNONYM stormon_group_table FOR stormon_group_table@storagedb
/

CREATE SYNONYM stormon_group_of_groups_table FOR stormon_group_of_groups_table@storagedb
/

CREATE SYNONYM stormon_host_groups FOR stormon_host_groups@storagedb
/

-- To be removed, TBD
--CREATE SYNONYM  stormon_group_reports_type FOR stormon_group_reports_type@storagedb
--/

CREATE SYNONYM storage_summaryObject FOR storage_summaryObject@storagedb
/

CREATE SYNONYM storage_summaryObject_view FOR storage_summaryObject_view@storagedb
/

CREATE SYNONYM stormon_history_day_view FOR stormon_history_day_view@storagedb
/

CREATE SYNONYM stormon_history_week_view FOR stormon_history_week_view@storagedb
/

CREATE SYNONYM stormon_hostdetail_view FOR stormon_hostdetail_view@storagedb
/

CREATE SYNONYM storage_issues_view FOR storage_issues_view@storagedb
/

CREATE SYNONYM storage_oracledb_view FOR storage_oracledb_view@storagedb
/

CREATE SYNONYM storage_localfs_view FOR storage_localfs_view@storagedb
/

CREATE SYNONYM storage_nfs_view FOR storage_nfs_view@storagedb
/

CREATE SYNONYM storage_nfs_shared_view FOR storage_nfs_shared_view@storagedb
/

CREATE SYNONYM storage_volume_view FOR storage_volume_view@storagedb
/

CREATE SYNONYM storage_swraid_view FOR storage_swraid_view@storagedb
/

CREATE SYNONYM storage_disk_view FOR storage_disk_view@storagedb
/

CREATE SYNONYM storage_summary FOR storage_summary@storagedb
/

CREATE GLOBAL TEMPORARY TABLE stormon_temp_results
(
	row_type			VARCHAR2(256),	-- SUMMARY or DETAIL row
	name				VARCHAR2(128),	
	id				VARCHAR2(256),
	type				VARCHAR2(256),	
	timestamp			DATE,		-- Timestamp for the summaryObject
	collection_timestamp		DATE,		-- Max collection timestamp of the metrics of this summaryobject
	hostcount			INTEGER,	-- No of targets in this summary
	actual_targets			INTEGER,	-- No of targets counted in this summary
	issues				INTEGER,	-- No of issues , or hosts which failed summary computation
	notcollected			INTEGER,	-- N, of hosts for which storage metrics have never been collected
	warnings			INTEGER,	-- No. od warnings , or No. of hosts with warnings in a group summary
	summaryflag			VARCHAR2(1),	-- Flag indicating if this summary is a place holder Y/N
	application_rawsize		NUMBER(16),		-- Non Oracle DB applications
	application_size		NUMBER(16),
	application_used		NUMBER(16),
	application_free		NUMBER(16),
	oracle_database_rawsize		NUMBER(16),	-- Oracle DB's
	oracle_database_size		NUMBER(16),
	oracle_database_used		NUMBER(16),
	oracle_database_free		NUMBER(16),
	local_filesystem_rawsize	NUMBER(16),	-- Local Filesystems
	local_filesystem_size		NUMBER(16),
	local_filesystem_used		NUMBER(16),		
	local_filesystem_free		NUMBER(16),
	nfs_exclusive_size		NUMBER(16),	-- NFS exclusive
	nfs_exclusive_used		NUMBER(16),		
	nfs_exclusive_free		NUMBER(16),
	nfs_shared_size			NUMBER(16),	-- NFS shared
	nfs_shared_used			NUMBER(16),
	nfs_shared_free			NUMBER(16),
	volumemanager_rawsize		NUMBER(16),	-- VM
	volumemanager_size		NUMBER(16),
	volumemanager_used		NUMBER(16),
	volumemanager_free		NUMBER(16),
	swraid_rawsize			NUMBER(16),	-- swraid
	swraid_size			NUMBER(16),
	swraid_used			NUMBER(16),
	swraid_free			NUMBER(16),
	disk_backup_rawsize		NUMBER(16),	-- Disk Backup
	disk_backup_size		NUMBER(16),	
	disk_backup_used		NUMBER(16),
	disk_backup_free		NUMBER(16),
	disk_rawsize			NUMBER(16),	-- Disk
	disk_size			NUMBER(16),
	disk_used			NUMBER(16),	
	disk_free			NUMBER(16),		
	rawsize				NUMBER(16),	-- Disk + NFS storage
	sizeb				NUMBER(16),
	used				NUMBER(16),
	free				NUMBER(16),
	vendor_emc_size			NUMBER(16),	-- Storage by vendor
	vendor_emc_rawsize		NUMBER(16),
	vendor_sun_size			NUMBER(16),
	vendor_sun_rawsize		NUMBER(16),
	vendor_hp_size			NUMBER(16),	
	vendor_hp_rawsize		NUMBER(16),
	vendor_hitachi_size		NUMBER(16),
	vendor_hitachi_rawsize		NUMBER(16),
	vendor_others_size		NUMBER(16),
	vendor_others_rawsize		NUMBER(16),
	vendor_nfs_netapp_size		NUMBER(16),
	vendor_nfs_emc_size		NUMBER(16),
	vendor_nfs_sun_size		NUMBER(16),	
	vendor_nfs_others_size		NUMBER(16)
)
ON COMMIT PRESERVE ROWS
/
