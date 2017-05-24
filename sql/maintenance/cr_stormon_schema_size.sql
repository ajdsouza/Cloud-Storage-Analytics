--  
--
-- Copyright  (c) 2001,2002  Oracle Corporation All rights reserved 
--
--
--
-- $Id: cr_stormon_schema_size.sql,v 1.59 2004/02/11 00:04:26 ajdsouza Exp $ 
--
--
-- NAME  
--	 cr_stormon_schema.sql
--
-- DESC 
--  Storage monitoring schema
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



-------------------------------------------------------------------------------
-- CREATE THE DATABASE LINKS FOR FETCHING 
--  9I MASTER DATA  		- oemdtc
--  MOZART MASTER DATA		- mozartdb
--  EPM DATA			- package_db
-------------------------------------------------------------------------------
-- DB LINK TO THE mozat database for refreshing mozart masters
-- The test em mozart system
--CREATE SHARED DATABASE LINK mozartdb CONNECT TO sysman IDENTIFIED BY sysman40t  AUTHENTICATED BY sysman IDENTIFIED BY sysman40t USING '(DESCRIPTION = (ADDRESS_LIST = (ADDRESS = (PROTOCOL = TCP)(HOST = git-tst.us.oracle.com)(PORT = 1521)))(CONNECT_DATA = (SID = aoemt)(GLOBAL_NAME = aoemt_git-tst)(SERVER = dedicated)))'
/
-- The pilot em mozart system
CREATE SHARED DATABASE LINK mozartdb CONNECT TO storemon IDENTIFIED BY storemon  AUTHENTICATED BY storemon IDENTIFIED BY storemon USING '(DESCRIPTION = (ADDRESS_LIST = (ADDRESS = (PROTOCOL = TCP)(HOST = aoemp-dbs01.oracle.com)(PORT = 1521)))(CONNECT_DATA = (SID = aoemp)(GLOBAL_NAME = aoemp_dbs01)(SERVER = dedicated)))'
/

-- DB link to the 9i-isis table to refresh 9i masters
CREATE SHARED DATABASE LINK oemdtc CONNECT TO rep_health IDENTIFIED BY rep_health AUTHENTICATED BY rep_health IDENTIFIED BY rep_health USING '(DESCRIPTION = (ADDRESS_LIST = (ADDRESS = (PROTOCOL = TCP)(HOST = gitmon2.us.oracle.com)(PORT = 1521)))(CONNECT_DATA = (SID = emorap)(GLOBAL_NAME = emorap_gitmon2)(SERVER = dedicated)))'
/

-- The patcher database for the epm version
CREATE SHARED DATABASE LINK package_db CONNECT TO stormon IDENTIFIED BY erfgtyu5  AUTHENTICATED BY stormon IDENTIFIED BY erfgtyu5 USING '(DESCRIPTION = (ADDRESS_LIST = (ADDRESS = (PROTOCOL = TCP)(HOST = gitprod1.us.oracle.com)(PORT = 1522)))(CONNECT_DATA = (SID = projap)(GLOBAL_NAME = projap_gitprod1)(SERVER = dedicated)))'
/


CREATE TABLE MGMT_CURRENT_METRICS (
	TARGET_GUID		VARCHAR2(256) 	NOT NULL,
	METRIC_GUID		NUMBER 		NOT NULL,
	COLLECTION_TIMESTAMP	DATE 		NOT NULL,
	KEY_VALUE		VARCHAR2(256),
	VALUE			VARCHAR2(2000),
	STRING_VALUE		VARCHAR2(2000)
)
PCTFREE 5 PCTUSED 60 TABLESPACE data_storage STORAGE ( INITIAL 1000M ) MONITORING
/
CREATE UNIQUE INDEX mgmt_current_metrics_idx1 ON mgmt_current_metrics(target_guid,metric_guid,key_value) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 600M ) COMPUTE STATISTICS
/
ALTER INDEX mgmt_current_metrics_idx1 MONITORING USAGE 
/     
  

-- I tried the  32K size, its gives the ORA-1467 Sort key too long error when used in sql queries, so keep it below the Oracle sort record size ~= block size
CREATE TYPE stringTable AS TABLE OF VARCHAR2(5000)
/
CREATE TYPE numberTable AS TABLE OF NUMBER 
/
CREATE TYPE dateTable AS TABLE OF DATE
/

CREATE TYPE summaryObject AS OBJECT (
	rowcount			INTEGER,
	name				VARCHAR2(128),	
	id				VARCHAR2(256),	
	timestamp			DATE,		-- Timestamp for the summaryObject
	collection_timestamp		DATE,		-- Max collection timestamp of the metrics of this summaryobject
	hostcount			INTEGER,	-- No of targets in this summary
	actual_targets			INTEGER,	-- No of targets counted in this summary
	issues				INTEGER,	-- No. of issues , or No. of hosts with issues in a group summary
	warnings			INTEGER,	-- No. od warnings , or No. of hosts with warnings in a group summary
	summaryflag			VARCHAR2(1),	-- Flag indicating if this summary is a place holder Y/N
	application_rawsize		NUMBER(16),		-- Non Oracle DB applications
	application_size		NUMBER(16),
	application_used		NUMBER(16),
	application_free		NUMBER(16),
	oracle_database_rawsize		NUMBER(16),		-- Oracle DB's
	oracle_database_size		NUMBER(16),
	oracle_database_used		NUMBER(16),
	oracle_database_free		NUMBER(16),
	local_filesystem_rawsize	NUMBER(16),		-- Local Filesystems
	local_filesystem_size		NUMBER(16),
	local_filesystem_used		NUMBER(16),		
	local_filesystem_free		NUMBER(16),
	nfs_exclusive_size		NUMBER(16),		-- NFS exclusive
	nfs_exclusive_used		NUMBER(16),		
	nfs_exclusive_free		NUMBER(16),
	nfs_shared_size			NUMBER(16),		-- NFS shared
	nfs_shared_used			NUMBER(16),
	nfs_shared_free			NUMBER(16),
	volumemanager_rawsize		NUMBER(16),		-- VM
	volumemanager_size		NUMBER(16),
	volumemanager_used		NUMBER(16),
	volumemanager_free		NUMBER(16),
	swraid_rawsize			NUMBER(16),		-- swraid
	swraid_size			NUMBER(16),
	swraid_used			NUMBER(16),
	swraid_free			NUMBER(16),
	disk_backup_rawsize		NUMBER(16),		-- Disk Backup
	disk_backup_size		NUMBER(16),	
	disk_backup_used		NUMBER(16),
	disk_backup_free		NUMBER(16),
	disk_rawsize			NUMBER(16),		-- Disk
	disk_size			NUMBER(16),
	disk_used			NUMBER(16),	
	disk_free			NUMBER(16),		
	rawsize				NUMBER(16),		-- Disk + NFS storage
	sizeb				NUMBER(16),
	used				NUMBER(16),
	free				NUMBER(16),
	vendor_emc_size			NUMBER(16),		-- Storage by vendor
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
/

CREATE TYPE storageSummaryTable AS TABLE OF summaryObject
/



-------------------------------------------------------------------------------
-- Table to cache the values of dblink tables
-- This is done for performance as dblink tables cannot be used in autonomous transactions
--
-- Tables cache
--
--	mgmt_metrics from perlscript addmetrics ( local table at storagedb )
--	mgmt_targets from mgmt_targets_new@oemdtc ( view at oemdtc )
--	node_target_map	from node_target_map@oemdtc ( view at oemdtc )
--	smp_vdt_job_per_target from smp_vdt_job_per_targe@oemdtc ( table at oemdtc )
--
-------------------------------------------------------------------------------

CREATE TABLE mgmt_metrics (
	target_type		VARCHAR2(64) 	NOT NULL,
	metric_name		VARCHAR2(128) 	NOT NULL,
	metric_guid		NUMBER 		NOT NULL,
	metric_column		VARCHAR2(64) 	NOT NULL,
	column_label		VARCHAR2(256)
)
PCTFREE 5 PCTUSED 70 TABLESPACE data_storage STORAGE ( INITIAL 20M ) MONITORING
/
ALTER TABLE mgmt_metrics ADD CONSTRAINT pk_mgmt_metrics PRIMARY KEY ( metric_guid ) 
/
ALTER INDEX pk_mgmt_metrics MONITORING USAGE 
/                                                                                                                                                         
CREATE UNIQUE INDEX mgmt_metrics_idx2 ON mgmt_metrics ( metric_name, metric_column ) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 5M ) COMPUTE STATISTICS
/
ALTER INDEX mgmt_metrics_idx2 MONITORING USAGE 
/   

CREATE TABLE mgmt_targets (
	target_id		VARCHAR2(256)	NOT NULL,
	target_name		VARCHAR2(255)	NOT NULL,
	target_type		VARCHAR2(255),
	tz			NUMBER,
	hosted			NUMBER,
	location		VARCHAR2(255),
	datacenter		VARCHAR2(255),
	support_group		VARCHAR2(255),
	escalation_group	VARCHAR2(255),
	owner			VARCHAR2(255),
	business_owner 		VARCHAR2(255),
	ip_address		VARCHAR2(255),
	make			VARCHAR2(255),
	model			VARCHAR2(255),
	operating_system	VARCHAR2(255)
)
PCTFREE 5 PCTUSED 70 TABLESPACE data_storage STORAGE( INITIAL 20M ) MONITORING
/
CREATE UNIQUE INDEX mgmt_targets_idx1 ON mgmt_targets(target_id) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 5M ) COMPUTE STATISTICS
/
ALTER INDEX mgmt_targets_idx1 MONITORING USAGE 
/                                                                                                                                                                        
CREATE UNIQUE INDEX mgmt_targets_idx2 ON mgmt_targets(target_name,target_type) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 8M ) COMPUTE STATISTICS
/                                                                                                                                                      
ALTER INDEX mgmt_targets_idx2 MONITORING USAGE 
/        

CREATE TABLE node_target_map (
	node_name	 	VARCHAR2(255) NOT NULL,
	target_name		VARCHAR2(255) NOT NULL,
	target_type		VARCHAR2(255) NOT NULL,
	agent_status		VARCHAR2(4),
	agent_state		VARCHAR2(4),
	agent_version		VARCHAR2(64),
	tns_address		VARCHAR2(4000),
	tz			NUMBER
)
PCTFREE 5 PCTUSED 70 TABLESPACE data_storage STORAGE( INITIAL 20M ) MONITORING
/
CREATE UNIQUE INDEX node_target_map_idx1 ON node_target_map(node_name,target_name,target_type) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 8M ) COMPUTE STATISTICS
/
ALTER INDEX node_target_map_idx1 MONITORING USAGE 
/    

CREATE TABLE SMP_VDJ_JOB_PER_TARGET (
	target_name		VARCHAR2(255),
	job_name		VARCHAR2(64),
	target_type		VARCHAR2(255),
	node_name		VARCHAR2(255),
	deliver_time		DATE,
	start_time		DATE,
	finish_time		DATE,
	next_exec_time 		DATE,
	occur_time		DATE,
	time_zone		NUMBER,
	status			VARCHAR2(256)
)
PCTFREE 5 PCTUSED 70 TABLESPACE data_storage STORAGE( INITIAL 20M ) MONITORING
/
CREATE INDEX smp_vdj_job_per_target_idx1 ON smp_vdj_job_per_target(target_name,target_type) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 8M ) COMPUTE STATISTICS
/
ALTER INDEX smp_vdj_job_per_target_idx1 MONITORING USAGE 
/

----------------------------------------------------------------------------
--  Schema for caching the master data from job scheduled in em
--
----------------------------------------------------------------------------
CREATE TABLE mozart_mgmt_targets (
	target_id		VARCHAR2(256)	NOT NULL,
	target_name		VARCHAR2(255)	NOT NULL,
	target_type		VARCHAR2(255),
	tz			NUMBER,
	hosted			NUMBER,
	location		VARCHAR2(255),
	datacenter		VARCHAR2(255),
	support_group		VARCHAR2(255),
	escalation_group	VARCHAR2(255),
	owner			VARCHAR2(255),
	business_owner 		VARCHAR2(255),
	ip_address		VARCHAR2(255),
	make			VARCHAR2(255),
	model			VARCHAR2(255),
	operating_system	VARCHAR2(255)
)
PCTFREE 5 PCTUSED 70 TABLESPACE data_storage STORAGE( INITIAL 20M ) MONITORING
/
CREATE UNIQUE INDEX mozart_mgmt_targets_idx1 ON mozart_mgmt_targets(target_id) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 5M ) COMPUTE STATISTICS
/
ALTER INDEX mozart_mgmt_targets_idx1 MONITORING USAGE 
/                                                                                                                                                  
CREATE UNIQUE INDEX mozart_mgmt_targets_idx2 ON mozart_mgmt_targets(target_name,target_type) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 8M ) COMPUTE STATISTICS
/
ALTER INDEX mozart_mgmt_targets_idx2 MONITORING USAGE 
/

CREATE TABLE mozart_node_target_map (
	node_name	 	VARCHAR2(255) NOT NULL,
	target_name		VARCHAR2(255) NOT NULL,
	target_type		VARCHAR2(255) NOT NULL,
	agent_status		VARCHAR2(4),
	agent_state		VARCHAR2(4),
	agent_version		VARCHAR2(64),
	tns_address		VARCHAR2(4000),
	tz			NUMBER
)
PCTFREE 5 PCTUSED 70 TABLESPACE data_storage STORAGE( INITIAL 20M ) MONITORING
/
CREATE UNIQUE INDEX mozart_node_target_map_idx1 ON mozart_node_target_map(node_name,target_name,target_type) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 8M ) COMPUTE STATISTICS
/
ALTER INDEX mozart_node_target_map_idx1 MONITORING USAGE
/


CREATE TABLE mozart_smp_vdj_job_per_target (
	target_name		VARCHAR2(255),
	job_name		VARCHAR2(64),
	target_type		VARCHAR2(255),
	node_name		VARCHAR2(255),
	deliver_time		DATE,
	start_time		DATE,
	finish_time		DATE,
	next_exec_time 		DATE,
	occur_time		DATE,
	time_zone		NUMBER,
	status			VARCHAR2(256)
)
PCTFREE 5 PCTUSED 70 TABLESPACE data_storage STORAGE( INITIAL 20M ) MONITORING
/
CREATE INDEX mozart_smp_vdj_job_idx1 ON mozart_smp_vdj_job_per_target(target_name,target_type) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 8M ) COMPUTE STATISTICS
/
ALTER INDEX mozart_smp_vdj_job_idx1 MONITORING USAGE
/


-------------------------------------------------------------------------------------------------
CREATE TABLE mgmt_migrated_targets
(
	original_target_id	VARCHAR2(256)   , -- GIT target ID
	mozart_target_id	VARCHAR2(256)   NOT NULL, -- MOZART target ID
	target_name		VARCHAR2(255)   NOT NULL,
	migrated_on		DATE DEFAULT SYSDATE,
	status			VARCHAR2(25),
	CONSTRAINT mgmt_migrated_targets_pk PRIMARY KEY 
	( 		
		mozart_target_id
	)
)
ORGANIZATION INDEX TABLESPACE index_storage INITRANS 3 STORAGE ( INITIAL 30M ) MONITORING
/

-- Table to hold the merged 9i and mozart targets, this can be made a materialized view 
CREATE TABLE mgmt_targets_merged (
	target_id		VARCHAR2(256)	NOT NULL,
	target_name		VARCHAR2(255)	NOT NULL,
	target_type		VARCHAR2(255),
	tz			NUMBER,
	hosted			NUMBER,
	location		VARCHAR2(255),
	datacenter		VARCHAR2(255),
	support_group		VARCHAR2(255),
	escalation_group	VARCHAR2(255),
	owner			VARCHAR2(255),
	business_owner 		VARCHAR2(255),
	ip_address		VARCHAR2(255),
	make			VARCHAR2(255),
	model			VARCHAR2(255),
	operating_system	VARCHAR2(255)
)
PCTFREE 5 PCTUSED 70 TABLESPACE data_storage STORAGE( INITIAL 20M ) MONITORING
/
CREATE UNIQUE INDEX mgmt_targets_merged_idx1 ON mgmt_targets_merged(target_id) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 5M ) COMPUTE STATISTICS
/
ALTER INDEX mgmt_targets_merged_idx1 MONITORING USAGE 
/
CREATE UNIQUE INDEX mgmt_targets_merged_idx2 ON mgmt_targets_merged(target_name,target_type) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 8M ) COMPUTE STATISTICS
/
ALTER INDEX mgmt_targets_merged_idx2 MONITORING USAGE 
/

-- Table to hold the status of the metrics collected
CREATE TABLE stormon_load_status (
	node_id				VARCHAR2(256)	NOT NULL,	-- Target_id of the host the target is on
	target_name			VARCHAR2(255)	NOT NULL,	-- Target name of the target with the collection
	target_type			VARCHAR2(255)	NOT NULL,	-- Target type of the target with the collection
	timestamp			TIMESTAMP WITH TIME ZONE,	-- Timestamp of insertion
	max_collection_timestamp	TIMESTAMP WITH TIME ZONE,	
	min_collection_timestamp	TIMESTAMP WITH TIME ZONE
)
PCTFREE 5 PCTUSED 70 TABLESPACE data_storage STORAGE( INITIAL 20M ) MONITORING
/
CREATE UNIQUE INDEX stormon_load_status_idx1 ON stormon_load_status( node_id, target_name, target_type ) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 8M ) COMPUTE STATISTICS
/
ALTER INDEX stormon_load_status_idx1 MONITORING USAGE 
/                                                                                                                                                    
CREATE UNIQUE INDEX stormon_load_status_idx2 ON stormon_load_status(target_name,target_type) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 7M ) COMPUTE STATISTICS
/
ALTER INDEX stormon_load_status_idx2 MONITORING USAGE 
/ 


-------------------------------------------------------------------------------------------------
CREATE TABLE storage_summaryobject OF summaryObject PCTFREE 5 PCTUSED 70 TABLESPACE data_storage STORAGE( INITIAL 15M ) MONITORING
/
CREATE UNIQUE INDEX storage_summaryObject_idx1 ON storage_summaryObject(id) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 4M ) COMPUTE STATISTICS
/
ALTER INDEX storage_summaryobject_idx1 MONITORING USAGE 
/
 
CREATE TABLE storage_summaryobject_history OF summaryObject  PCTFREE 5 PCTUSED 70 TABLESPACE data_storage STORAGE ( INITIAL 15M ) MONITORING
/
CREATE INDEX storage_history_idx1 ON storage_summaryObject_history(id) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 5M ) COMPUTE STATISTICS
/
ALTER INDEX storage_history_idx1 MONITORING USAGE 
/ 

CREATE TABLE storage_history_30days OF summaryObject PCTFREE 5 PCTUSED 70 TABLESPACE data_storage  STORAGE( INITIAL 100M ) MONITORING
/
CREATE UNIQUE INDEX storage_history_30days_idx1 ON storage_history_30days(id,collection_timestamp) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 10M ) COMPUTE STATISTICS
/
ALTER INDEX storage_history_30days_idx1 MONITORING USAGE 
/

CREATE TABLE storage_history_52weeks OF summaryObject  PCTFREE 5 PCTUSED 70  TABLESPACE data_storage STORAGE( INITIAL 100M ) MONITORING
/
CREATE UNIQUE INDEX storage_history_52weeks_idx1 ON storage_history_52weeks(id,collection_timestamp) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 10M ) COMPUTE STATISTICS
/
ALTER INDEX storage_history_52weeks_idx1 MONITORING USAGE 
/

CREATE TABLE storage_log (
				target_id	VARCHAR2(256)	NOT NULL,
				timestamp	DATE		NOT NULL,
				type		VARCHAR2(128)	NOT NULL,
				location	VARCHAR2(128),
				message		VARCHAR2(2048)
			)
PCTFREE 5 PCTUSED 70 TABLESPACE data_storage STORAGE( INITIAL 6M ) MONITORING
/
CREATE INDEX storage_log_idx1 ON storage_log ( target_id, type ) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 3M ) COMPUTE STATISTICS
/
ALTER INDEX storage_log_idx1 MONITORING USAGE 
/ 

-- 10 rows per target * 2000 Targets * 24 cycles per day * 7 days = 3360000 Rows
CREATE TABLE storage_statistics (
				job_name	VARCHAR2(256),
				timestamp	DATE		NOT NULL,
--				id		RAW(16)		NOT NULL,
				id		VARCHAR2(256)	NOT NULL,
				name		VARCHAR2(128),
				message		VARCHAR2(2048),
				time_seconds	NUMBER
			)
PCTFREE 5 PCTUSED 70 TABLESPACE data_storage STORAGE( INITIAL 250M ) MONITORING
/
CREATE INDEX storage_statistics_idx1 ON storage_statistics ( job_name, timestamp, id ) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 100M ) COMPUTE STATISTICS 
/
ALTER INDEX storage_statistics_idx1 MONITORING USAGE 
/  


CREATE TABLE storage_lock_table(dummy	NUMBER(1)) TABLESPACE data_storage 
/

-----------------------------------------------------
-- GROUPING TABLES
-----------------------------------------------------
-- Master table for target groups

CREATE SEQUENCE stormonGroupId START WITH 10000 
/

CREATE TABLE stormon_group_table(
	id	  		VARCHAR2(256) NOT NULL,		-- Id for the group
	type			VARCHAR2(256) NOT NULL,		-- REPORTING_DATA_CENTER, REPORTING_LOB, REPORTING_CUSTOMER, SHARED_STORAGE
	name			VARCHAR2(256) NOT NULL,		-- Group name	
	host_count		INTEGER
)
PCTFREE 5 PCTUSED 70 TABLESPACE data_storage STORAGE( INITIAL 10M ) MONITORING
/
CREATE UNIQUE INDEX stormon_group_table_idx1 ON stormon_group_table(id) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 3M ) COMPUTE STATISTICS
/
ALTER INDEX stormon_group_table_idx1 MONITORING USAGE 
/                                                                                                                                                      
CREATE UNIQUE INDEX stormon_group_table_idx2 ON stormon_group_table(type,name) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 3M ) COMPUTE STATISTICS
/
ALTER INDEX stormon_group_table_idx2 MONITORING USAGE 
/ 
CREATE UNIQUE INDEX stormon_group_table_idx3 ON stormon_group_table(id,type,name) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 3M ) COMPUTE STATISTICS
/                                                                                                                                               
ALTER INDEX stormon_group_table_idx3 MONITORING USAGE 
/    

-- Group Id to group id table
CREATE TABLE stormon_group_of_groups_table(
	parent_id  		VARCHAR2(256) NOT NULL,	-- Parent group id
	child_id		VARCHAR2(256) NOT NULL	-- Child group id
)
PCTFREE 5 PCTUSED 70 TABLESPACE data_storage STORAGE( INITIAL 10M ) MONITORING
/
CREATE UNIQUE INDEX stormon_group_of_groups_idx1 ON stormon_group_of_groups_table(parent_id, child_id) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 3M ) COMPUTE STATISTICS
/
ALTER INDEX stormon_group_of_groups_idx1 MONITORING USAGE 
/

-- Group id to targets table
CREATE TABLE stormon_host_groups(
	group_id	VARCHAR2(256),		-- Id for the group
	target_id	VARCHAR2(256)		-- Target id for the host
)
PCTFREE 5 PCTUSED 70 TABLESPACE data_storage STORAGE( INITIAL 3M ) MONITORING
/
CREATE UNIQUE INDEX stormon_host_groups_idx1 ON stormon_host_groups(group_id,target_id) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 3M ) COMPUTE STATISTICS
/
ALTER INDEX stormon_host_groups_idx1 MONITORING USAGE
/

CREATE UNIQUE INDEX stormon_host_groups_idx2 ON stormon_host_groups(target_id, group_id ) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 3M ) COMPUTE STATISTICS     
/
ALTER INDEX stormon_host_groups_idx1 MONITORING USAGE
/


-- Index on stormon_host_groups
CREATE OR REPLACE TRIGGER stormon_group_trg1 BEFORE DELETE OR UPDATE OF ID ON stormon_group_table
FOR EACH ROW
DECLARE
	l_dummy		NUMBER;
BEGIN
	
	IF DELETING THEN

		DELETE FROM stormon_group_of_groups_table WHERE parent_id = :old.id;
		DELETE FROM stormon_group_of_groups_table WHERE child_id = :old.id;
		DELETE FROM stormon_host_groups WHERE group_id = :old.id;

		--UPDATE storage_summaryObject SET id = 'ARCHIVED_'||SYSDATE||'_'||id WHERE id = :old.id;
		--UPDATE storage_summaryObject_history SET id = 'ARCHIVED_'||SYSDATE||'_'||id WHERE id = :old.id;
		--UPDATE storage_history_30days SET id = 'ARCHIVED_'||SYSDATE||'_'||id WHERE id = :old.id;
		--UPDATE storage_history_52weeks SET id = 'ARCHIVED_'||SYSDATE||'_'||id WHERE id = :old.id;

	ELSE

		UPDATE stormon_group_of_groups_table SET parent_id = :new.id WHERE parent_id = :old.id;
		UPDATE stormon_group_of_groups_table SET child_id = :new.id WHERE child_id = :old.id;
		UPDATE stormon_host_groups SET group_id = :new.id WHERE group_id = :old.id;

		--UPDATE storage_summaryObject SET id = :new.id WHERE id = :old.id;
		--UPDATE storage_summaryObject_history SET id = :new.id WHERE id = :old.id;
		--UPDATE storage_history_30days SET id = :new.id WHERE id = :old.id;
		--UPDATE storage_history_52weeks SET id = :new.id WHERE id = :old.id;

	END IF;	

END;
/

--ALTER TRIGGER stormon_group_trg1 DISABLE
--/

--DROP TRIGGER stormon_group_trg1
--/

-------------------------------------------
-- SCHEMA FOR DETAILED REPORTS OF TARGETS
-------------------------------------------
CREATE TABLE storage_application_table
(
	target_id	VARCHAR2(256),
	parentkey	VARCHAR2(2000),
	keyvalue	VARCHAR2(2000),
	type		VARCHAR2(50),
	appname		VARCHAR2(50),
	appid		VARCHAR2(50),	
	dbid		VARCHAR2(50),
	grouping_id	INTEGER,
	tablespace	VARCHAR2(256),
	filename	VARCHAR2(256),	
	rawsizeb	NUMBER(16),
	sizeb		NUMBER(16),
	usedb		NUMBER(16),
	freeb		NUMBER(16),
	backup		VARCHAR2(1)
)
PCTFREE 5 PCTUSED 70 TABLESPACE data_storage STORAGE( INITIAL 80M ) MONITORING
/
CREATE INDEX storage_application_table_idx1 ON storage_application_table(target_id) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 10M ) COMPUTE STATISTICS
/
ALTER INDEX storage_application_table_idx1 MONITORING USAGE
/

CREATE TABLE storage_localfs_table
(
	target_id	VARCHAR2(256),
	keyvalue	VARCHAR2(2000),
	type		VARCHAR2(50),
	filesystem	VARCHAR2(2000),
	mountpoint	VARCHAR2(2000),	
	rawsizeb	NUMBER(16),
	sizeb		NUMBER(16),
	usedb		NUMBER(16),
	freeb		NUMBER(16),
	backup		VARCHAR2(1)
) 
PCTFREE 5 PCTUSED 70 TABLESPACE data_storage STORAGE( INITIAL 80M ) MONITORING
/
CREATE INDEX storage_localfs_table_idx1 ON storage_localfs_table(target_id) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 10M ) COMPUTE STATISTICS
/
ALTER INDEX storage_localfs_table_idx1 MONITORING USAGE 
/

CREATE TABLE storage_nfs_table
(
	target_id	VARCHAR2(256),
	keyvalue	VARCHAR2(2000),
	type		VARCHAR2(50),
	filesystem	VARCHAR2(2000),
	mountpoint	VARCHAR2(2000),	
	rawsizeb	NUMBER(16),
	sizeb		NUMBER(16),
	usedb		NUMBER(16),
	freeb		NUMBER(16),
	vendor		VARCHAR2(256),
	server		VARCHAR2(256),
	mounttype	VARCHAR2(256),
	nfscount	NUMBER(16),
	privilege	VARCHAR2(256)
) 
PCTFREE 5 PCTUSED 70 TABLESPACE data_storage STORAGE( INITIAL 90M ) MONITORING
/
CREATE INDEX storage_nfs_table_idx1 ON storage_nfs_table(target_id) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 12M ) COMPUTE STATISTICS
/
ALTER INDEX storage_nfs_table_idx1 MONITORING USAGE 
/

CREATE TABLE storage_volume_table
(
	target_id	VARCHAR2(256),
	keyvalue	VARCHAR2(2000),
	type		VARCHAR2(50),
	diskgroup	VARCHAR2(256),
	path		VARCHAR2(2000),
	rawsizeb	NUMBER(16),
	sizeb		NUMBER(16),
	usedb		NUMBER(16),
	freeb		NUMBER(16),
	configuration	VARCHAR2(256),	
	freetype	VARCHAR2(50),
	backup		VARCHAR2(1)
)
PCTFREE 5 PCTUSED 70 TABLESPACE data_storage STORAGE( INITIAL 80M ) MONITORING
/
CREATE INDEX  storage_volume_table_idx1 ON  storage_volume_table(target_id) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 10M ) COMPUTE STATISTICS
/
ALTER INDEX storage_volume_table_idx1 MONITORING USAGE 
/ 


CREATE TABLE storage_swraid_table
(
	target_id	VARCHAR2(256),
	keyvalue	VARCHAR2(2000),
	diskkey		VARCHAR2(2000),
	type		VARCHAR2(50),
	path		VARCHAR2(2000),
	rawsizeb	NUMBER(16),
	sizeb		NUMBER(16),
	usedb		NUMBER(16),
	freeb		NUMBER(16),
	configuration	VARCHAR2(256),	
	freetype	VARCHAR2(50),
	backup		VARCHAR2(1),
	parent		VARCHAR2(2000)
)
PCTFREE 5 PCTUSED 70 TABLESPACE data_storage STORAGE( INITIAL 80M ) MONITORING
/
CREATE INDEX storage_swraid_table_idx1 ON storage_swraid_table(target_id) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 10M ) COMPUTE STATISTICS
/
ALTER INDEX storage_swraid_table_idx1 MONITORING USAGE 
/

CREATE TABLE storage_disk_table
(
	target_id	VARCHAR2(256),
	keyvalue	VARCHAR2(2000),
	diskkey		VARCHAR2(2000),
	type		VARCHAR2(50),
	path		VARCHAR2(2000),
	rawsizeb	NUMBER(16),
	sizeb		NUMBER(16),
	usedb		NUMBER(16),
	freeb		NUMBER(16),
	configuration	VARCHAR2(256),	
	freetype	VARCHAR2(50),
	backup		VARCHAR2(1),
	vendor		VARCHAR2(200),
	product		VARCHAR2(200),
	status		VARCHAR2(1000)
)
PCTFREE 5 PCTUSED 70 TABLESPACE data_storage STORAGE( INITIAL 90M ) MONITORING
/
CREATE INDEX storage_disk_table_idx1 ON storage_disk_table(target_id) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 10M ) COMPUTE STATISTICS
/
ALTER INDEX storage_disk_table_idx1 MONITORING USAGE 
/
-----------------------------------------------
-- REPORTING VIEWS
-----------------------------------------------

---------------------------------------------------------------------------------
-- mgmt_targets_new
-- a view on mgmt_targets, for querying for dev database
---------------------------------------------------------------------------------
CREATE OR REPLACE VIEW 	mgmt_targets_new
(
	target_id		,
	target_name		,
	target_type		,
	tz			,
	hosted			,
	location		,
	datacenter		,
	support_group		,
	escalation_group	,
	owner			,
	business_owner 		,
	ip_address		,
	make			,
	model			,
	operating_system	
)
AS 
SELECT	target_id		,
	target_name		,
	target_type		,
	tz			,
	hosted			,
	location		,
	datacenter		,
	support_group		,
	escalation_group	,
	owner			,
	business_owner 		,
	ip_address		,
	make			,
	model			,
	operating_system	
FROM	mgmt_targets
/


---------------------------------------------------------------------------------
-- MGMT_TARGETS_merged_view
-- The updated list of targets with the target_id of the migrated targets
---------------------------------------------------------------------------------
CREATE OR REPLACE VIEW mgmt_targets_merged_view
	(
	target_id,	
	target_name,													   
	target_type,														    
	tz,															
	hosted,  
	location,														    
	datacenter,														    
	support_group,														    
	escalation_group,													    
	owner,															    
	business_owner, 													    
	ip_address,														    
	make,														    
	model,															    
	operating_system
	)
AS
SELECT	target_id,	
	target_name,													   
	target_type,														    
	tz,															
	hosted,  
	location,														    
	datacenter,														    
	support_group,														    
	escalation_group,													    
	owner,															    
	business_owner, 													    
	ip_address,														    
	make,														    
	model,															    
	operating_system		
FROM	mgmt_targets a
WHERE
NOT EXISTS (
		SELECT	1
		FROM	mgmt_migrated_targets b
		WHERE	b.original_target_id = a.target_id
		OR	b.target_name = a.target_name
--
-- This is a modified mgmt_targets_merged_view, it checks based on target_name, 
-- This change is done as in the GIT master the target_id for some target_names has changed so the target_name will show twice once in each list
--
--		AND	b.original_target_id IS NOT NULL
	)
UNION
SELECT	target_id,	
	target_name,													   
	target_type,														    
	tz,															
	hosted,  
	location,														    
	datacenter,														    
	support_group,														    
	escalation_group,													    
	owner,															    
	business_owner, 													    
	ip_address,														    
	make,														    
	model,															    
	operating_system
FROM	mozart_mgmt_targets a
WHERE	EXISTS (
		SELECT	1
		FROM	mgmt_migrated_targets b
		WHERE	mozart_target_id = a.target_id
	)
/

-----------------------------------------------------
-- VIEWS FOR LIST OF TARGETS MGMT_TARGETS_VIEW
-----------------------------------------------------
CREATE OR REPLACE VIEW mgmt_targets_view
(
	target_id,
	target_name,
	target_type,														    
	tz,															
	hosted,  
	location,														    
	datacenter,														    
	support_group,														    
	escalation_group,													    
	owner,															    
	business_owner, 													    
	ip_address,														    
	make,														    
	model,															    
	operating_system
)
AS
SELECT  target_id,
	target_name,
	target_type,														    
	tz,															
	hosted,  
	location,														    
	datacenter,														    
	support_group,														    
	escalation_group,													    
	owner,															    
	business_owner, 													    
	ip_address,														    
	make,														    
	model,															    
	operating_system
FROM	mgmt_targets_merged
WHERE	target_type = 'oracle_sysman_node'
/


-------------------------------------------------------------------------
--  MGMT_TARGETS_TO_BE_MIGRATED
--
--  The targets to be migrated should
--  1. be selected from mozart_mgmt_targets
--  2. should exist in mgmt_current_metrics - implying that their
--     data is being pumped into raw tables
--  3. should not exist in mgmt_migrated_targets - we need to migrate
--     a target only once!
-------------------------------------------------------------------------
CREATE OR REPLACE VIEW mgmt_targets_to_be_migrated
	(
	original_target_id,
	mozart_target_id,
	target_name,
	target_type			
	)
AS
SELECT	targets.target_id,
	mozart.target_id,
	mozart.target_name,
	mozart.target_type
FROM	mozart_mgmt_targets mozart,
	mgmt_targets_view targets
WHERE	mozart.target_name = targets.target_name(+)
-- the mozart target is being collected
AND 	EXISTS 
	(
		SELECT	target_guid 
		FROM	mgmt_current_metrics a
		WHERE	a.target_guid = mozart.target_id
	)
-- not in the migrated targets
AND 	NOT EXISTS 
	( 
		SELECT	original_target_id
		FROM	mgmt_migrated_targets 
		WHERE	mozart_target_id = mozart.target_id
	)
/


-----------------------------------------------------
-- VIEWS FOR NODE-TARGET MAP SMP_VIEW_TARGETS
-----------------------------------------------------
CREATE OR REPLACE VIEW smp_view_targets
(
	node_name,
	target_name,
	target_type,
	agent_status,
	agent_state,
	agent_version,
	tns_address,
	tz
)
AS
SELECT	node_name,
	target_name,
	target_type,
	agent_status,
	agent_state,
	agent_version,
	tns_address,
	tz
FROM    node_target_map
/


-----------------------------------------------------
-- VIEW FOR the 9I AND MOZART MERGED NODE_TARGET_MAP
-----------------------------------------------------
CREATE OR REPLACE VIEW merged_node_target_map_view
(
	node_name,
	target_name,
	target_type,
	agent_status,
	agent_state,
	agent_version,
	tns_address,
	tz
)
AS
SELECT	b.node_name,
	b.target_name,
	b.target_type,
	b.agent_status,
	b.agent_state,
	b.agent_version,
	b.tns_address,
	b.tz
FROM	node_target_map b	
WHERE	NOT EXISTS (
		SELECT	1
		FROM	mgmt_migrated_targets c
		WHERE	b.node_name = c.target_name	
	)
UNION
SELECT	b.node_name,
	b.target_name,
	b.target_type,
	b.agent_status,
	b.agent_state,
	b.agent_version,
	b.tns_address,
	b.tz
FROM	mozart_node_target_map b
WHERE	EXISTS (
		SELECT	1
		FROM	mgmt_migrated_targets c
		WHERE	b.node_name = c.target_name
	)
/

--------------------------------------------------------------
-- VIEW FOR 9I AND MOZART MERGED JOB STATUS 
--------------------------------------------------------------
CREATE OR REPLACE VIEW stormon_active_targets_view
	(
		node_id,
		node_name,
		target_name,
		target_type,
		job_name,
		start_time,			-- in GMT
		last_collection_timestamp,	-- in GMT
		next_execution_time,		-- in GMT
		status				-- Will have only the COMPLETED and SCHEDULED jobs
	)
AS
SELECT	c.target_id,
	c.target_name,
	a.target_name,
	a.target_type,
	a.job_name,
	a.start_time,
	a.finish_time,
	a.next_exec_time,
	a.status
FROM	mgmt_targets_view c,
	node_target_map b,
	smp_vdj_job_per_target a
WHERE	b.target_name = a.target_name
AND	b.target_type = a.target_type
AND	c.target_name = b.node_name
AND 	a.job_name LIKE 'STORAGE%'
AND	a.status IN ('COMPLETED','SCHEDULED') 
AND	NOT EXISTS (
		SELECT	1
		FROM	mgmt_migrated_targets b
		WHERE	b.target_name = c.target_name	
	)
UNION
SELECT	c.target_id,
	c.target_name,
	a.target_name,
	a.target_type,
	a.job_name,
	a.start_time,
	a.finish_time,
	a.next_exec_time,
	a.status
FROM	mgmt_targets_view c,
	mozart_node_target_map b,
	mozart_smp_vdj_job_per_target a
WHERE	b.target_name = a.target_name
AND	b.target_type = a.target_type
AND	c.target_name = b.node_name
AND	a.status IN ('COMPLETED','SCHEDULED') 
AND	EXISTS (
		SELECT	1
		FROM	mgmt_migrated_targets b
		WHERE	b.target_name = c.target_name
	)
/

----------------------------------------------
-- 	STORAGE_ORACLEDB_VIEW
----------------------------------------------

CREATE OR REPLACE VIEW storage_oracledb_view
(
	target_id,
	keyvalue,
	type,
	appname,
	appid,
	tablespace,
	filename,
	rawsizeb,
	sizeb,
	usedb,
	freeb,
	backup
)
AS
SELECT	target_id,
	keyvalue,
	type,
	appname,
	appid,
	tablespace,
	filename,
	rawsizeb,
	sizeb,
	usedb,
	freeb,
	backup
FROM	storage_application_table
UNION
SELECT	id,
	NULL,
	NULL,
	NULL,
	'Total',
	NULL,
	NULL,
	oracle_database_rawsize,
	oracle_database_size,
	oracle_database_used,
	oracle_database_free,
	NULL
FROM	storage_summaryObject
WHERE	oracle_database_size > 0
/


----------------------------------------------
-- 	STORAGE_LOCALFS_VIEW
----------------------------------------------
CREATE OR REPLACE VIEW storage_localfs_view
(
	target_id,
	keyvalue,
	type,
	filesystem,
	mountpoint,
	rawsizeb,
	sizeb,
	usedb,
	freeb,
	backup
)
AS
SELECT	target_id,
	keyvalue,
	type,
	filesystem,
	mountpoint,
	rawsizeb,
	sizeb,
	usedb,
	freeb,
	backup
FROM	storage_localfs_table
UNION
SELECT	id,
	NULL,
	NULL,
	'Total',
	NULL,
	local_filesystem_size,
	local_filesystem_size,
	local_filesystem_used,
	local_filesystem_free,
	NULL	
FROM	storage_summaryObject
WHERE	local_filesystem_size > 0
/
		
----------------------------------------------
-- 	STORAGE_NFS_VIEW 
-- 	For exclusive mounts
----------------------------------------------
CREATE OR REPLACE VIEW storage_nfs_view 
(
	target_id,
	keyvalue,
	type,
	filesystem,
	mountpoint,
	rawsizeb,
	sizeb,
	usedb,
	freeb,
	vendor,
	server,		
	mounttype,
	nfscount,
	privilege
)
AS
SELECT	target_id,
	keyvalue,
	type,
	filesystem,
	mountpoint,
	rawsizeb,
	sizeb,
	usedb,
	freeb,
	vendor,
	server,
	mounttype,
	nfscount,
	privilege	
FROM	storage_nfs_table
WHERE	mounttype = 'EXCLUSIVE'
UNION
SELECT	id,
	NULL,
	NULL,
	'Total',
	NULL,
	nfs_exclusive_size,
	nfs_exclusive_size,
	nfs_exclusive_used,
	nfs_exclusive_free,
	NULL,	
	NULL,
	NULL,
	NULL,
	NULL	
FROM	storage_summaryObject
WHERE	nfs_exclusive_size > 0
/

----------------------------------------------
-- 	STORAGE_NFS_SHARED_VIEW 
-- 	For exclusive mounts
----------------------------------------------
CREATE OR REPLACE VIEW storage_nfs_shared_view 
(
	target_id,
	keyvalue,
	type,
	filesystem,
	mountpoint,
	rawsizeb,
	sizeb,
	usedb,
	freeb,
	vendor,
	server,		
	mounttype,
	nfscount,
	privilege
)
AS
SELECT	target_id,
	keyvalue,
	type,
	filesystem,
	mountpoint,
	rawsizeb,
	sizeb,
	usedb,
	freeb,
	vendor,
	server,
	mounttype,
	nfscount,
	privilege	
FROM	storage_nfs_table
WHERE	mounttype = 'SHARED'
UNION
SELECT	id,
	NULL,
	NULL,
	'Total',
	NULL,
	nfs_shared_size,
	nfs_shared_size,
	nfs_shared_used,
	nfs_shared_free,
	NULL,	
	NULL,
	NULL,
	NULL,
	NULL	
FROM	storage_summaryObject
WHERE	nfs_shared_size > 0
/


----------------------------------------------
-- 	STORAGE_VOLUME_VIEW
----------------------------------------------
CREATE OR REPLACE VIEW storage_volume_view 
(
	target_id,
	keyvalue,
	type,
	diskgroup,
	path,
	rawsizeb,
	sizeb,
	usedb,
	freeb,
	configuration,	
	freetype,
	backup
)
AS
SELECT	target_id,
	keyvalue,
	DECODE(type,'DISK','DISK/PARTITION',type) type,
	diskgroup,
	path,
	rawsizeb,
	sizeb,
	usedb,
	freeb,
	configuration,	
	freetype,
	backup
FROM	storage_volume_table
WHERE	type != 'DISKSLICE'
UNION
SELECT	id,
	NULL,
	NULL,
	NULL,
	'Total',
	volumemanager_rawsize,
	volumemanager_size,
	volumemanager_used,
	volumemanager_free,
	NULL,
	NULL,
	NULL	
FROM	storage_summaryObject
WHERE	volumemanager_size > 0
/

----------------------------------------------
-- 	STORAGE_SWRAID_VIEW
----------------------------------------------

CREATE OR REPLACE VIEW storage_swraid_view
(
	target_id,
	keyvalue,
	diskkey,
	type,
	path,
	rawsizeb,
	sizeb,
	usedb,
	freeb,
	configuration,
	freetype,
	backup,
	parent
)
AS
SELECT	target_id,
	keyvalue,
	diskkey,
	type,
	path,
	rawsizeb,
	sizeb,
	usedb,
	freeb,
	configuration,
	freetype,
	backup,
	parent
FROM	storage_swraid_Table
UNION
SELECT	id,
	NULL,
	NULL,
	NULL,
	'Total',
	swraid_rawsize,
	swraid_size,
	swraid_used,
	swraid_free,
	NULL,
	NULL,
	NULL,
	NULL
FROM	storage_summaryObject
WHERE	swraid_size > 0
/

----------------------------------------------
-- 	STORAGE_DISK_VIEW
----------------------------------------------

CREATE OR REPLACE VIEW storage_disk_view
(
	target_id,
	keyvalue,
	diskkey,
	type,
	path,
	rawsizeb,
	sizeb,
	usedb,
	freeb,
	configuration,
	freetype,
	backup,
	vendor,
	product,
	status
)
AS
SELECT	target_id,
	keyvalue,
	diskkey,
	type,
	path,
	rawsizeb,
	sizeb,
	usedb,
	freeb,
	configuration,
	freetype,
	backup,
	vendor,
	product,
	status
FROM	storage_disk_Table
UNION
SELECT	id,
	NULL,
	NULL,
	NULL,
	'Total',
	disk_rawsize,
	disk_size,
	disk_used,
	disk_free,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL
FROM	storage_summaryObject
WHERE	disk_size > 0
/

------------------------------------------------
-- VIEWS FOR ISSUES AND WARNINGS
------------------------------------------------

CREATE OR REPLACE VIEW storage_issues_view
(	
	id,
	target_name,
	type,
	timestamp,
	message
)
AS
SELECT	a.target_id,	
	NVL(b.target_name,'Host Id '||a.target_id),
	a.type,
	a.timestamp,
	a.message
FROM	mgmt_targets_view b,
	storage_log a
WHERE	b.target_id = a.target_id
/

------------------------------------------------
-- VIEWS FOR STORAGE JOB STATISTICS
------------------------------------------------
CREATE OR REPLACE VIEW storage_stats_view
(
	job_name,
	timestamp,
	id,
	name,
	message,
	time_seconds
)
AS
SELECT	job_name,
	timestamp,
--	UTL_RAW.CAST_TO_VARCHAR2(id),
	id,
	name,
	message,
	time_seconds
FROM	storage_statistics
/

-----------------------------------------------------
-- VIEWS FOR HOST DETAILS STORMON_HOSTDETAIL_VIEW
-----------------------------------------------------
CREATE OR REPLACE VIEW stormon_hostdetail_view
(
id,
type,
name,
rawsizeb,
sizeb,
usedb,
freeb
)
AS
(
SELECT	id,
	'_TOTAL',
	'Total Storage ( Except NFS Shared)',
	rawsize,
	sizeb,
	used,
	free
FROM	storage_summaryobject
UNION
SELECT	id,
	'_DISKS',
	'All Disks',
	disk_rawsize,
	disk_size,
	disk_used,
	disk_free
FROM	storage_summaryobject
UNION
SELECT	id,
	'_BACKUP_DISKS',
	'Disks Used For Backup',
	disk_backup_rawsize,
	disk_backup_size,
	disk_backup_used,
	disk_backup_free
FROM	storage_summaryobject
UNION
SELECT	id,
	'_SWRAID',
	'Software Raid Manager',
	swraid_rawsize,
	swraid_size,
	swraid_used,
	swraid_free
FROM	storage_summaryobject
UNION
SELECT	id,
	'_VOLUME_MANAGER',
	'Volume Manager',
	volumemanager_rawsize,
	volumemanager_size,
	volumemanager_used,
	volumemanager_free
FROM	storage_summaryobject
UNION
SELECT	id,
	'_LOCAL_FILESYSTEM',
	'Local Filesystems',
	local_filesystem_rawsize,
	local_filesystem_size,
	local_filesystem_used,
	local_filesystem_free
FROM	storage_summaryobject
UNION
SELECT	id,
	'NFS_SHARED',
	'NFS Shared ( With other Hosts )',
	nfs_shared_size,
	nfs_shared_size,
	nfs_shared_used,
	nfs_shared_free
FROM	storage_summaryobject
UNION
SELECT	id,
	'NFS_EXCLUSIVE',
	'NFS Dedicated',
	nfs_exclusive_size,
	nfs_exclusive_size,
	nfs_exclusive_used,
	nfs_exclusive_free
FROM	storage_summaryobject
UNION
SELECT	id,
	'_ALL_DATABASES',
	'Oracle Database',
	oracle_database_rawsize,
	oracle_database_size,
	oracle_database_used,
	oracle_database_free
FROM	storage_summaryobject
)
/



-----------------------------------------------------
-- VIEWS FOR HISTORY STORMON_HISTORY_DAY_VIEW
-----------------------------------------------------
CREATE OR REPLACE VIEW stormon_history_day_view
AS
SELECT	*
FROM	storage_history_30days
ORDER BY collection_timestamp DESC
/


-----------------------------------------------------
-- VIEWS FOR HISTORY STORMON_HISTORY_WEEK_VIEW
-----------------------------------------------------
CREATE OR REPLACE VIEW stormon_history_week_view
AS
SELECT	*
FROM	storage_history_52weeks
ORDER BY collection_timestamp DESC
/

---------------------------------------------------------
-- SCHEMA FOR GROUP, TARGET SUMMARY REPORTS
---------------------------------------------------------
CREATE OR REPLACE VIEW storage_summaryObject_view
AS
SELECT	a.id,
	a.name,
	a.type,
	a.hostcount,
	NVL(b.timestamp,SYSDATE) 		timestamp		,	-- timestamp
	NVL(b.collection_timestamp,SYSDATE) 	collection_timestamp	,	-- collection_timestamp
	NVL(b.actual_targets,0)			actual_targets		,	-- actual_targets
	NVL(b.issues,0)				issues			,	-- issues
	NVL(b.warnings,0)			warnings		,	-- warnings
	NVL(b.summaryFlag,'N') 			summaryflag		,	-- summaryFlag
	NVL(b.application_rawsize,0)		application_rawsize	,
	NVL(b.application_size,0)		application_size	,
	NVL(b.application_used,0)		application_used	,
	NVL(b.application_free,0)		application_free	,
	NVL(b.oracle_database_rawsize,0)	oracle_database_rawsize	,
	NVL(b.oracle_database_size,0)		oracle_database_size	,
	NVL(b.oracle_database_used,0)		oracle_database_used	,
	NVL(b.oracle_database_free,0)		oracle_database_free	,
	NVL(b.local_filesystem_rawsize,0)	local_filesystem_rawsize,
	NVL(b.local_filesystem_size,0)		local_filesystem_size	,
	NVL(b.local_filesystem_used,0)		local_filesystem_used	,
	NVL(b.local_filesystem_free,0)		local_filesystem_free	,
	NVL(b.nfs_exclusive_size,0)		nfs_exclusive_size	,
	NVL(b.nfs_exclusive_used,0)		nfs_exclusive_used	,
	NVL(b.nfs_exclusive_free,0)		nfs_exclusive_free	,
	NVL(b.nfs_shared_size,0)		nfs_shared_size		,
	NVL(b.nfs_shared_used,0)		nfs_shared_used		,
	NVL(b.nfs_shared_free,0)		nfs_shared_free		,
	NVL(b.volumemanager_rawsize,0)		volumemanager_rawsize	,
	NVL(b.volumemanager_size,0)		volumemanager_size	,
	NVL(b.volumemanager_used,0)		volumemanager_used	,
	NVL(b.volumemanager_free,0)		volumemanager_free	,
	NVL(b.swraid_rawsize,0)			swraid_rawsize		,
	NVL(b.swraid_size,0)			swraid_size		,
	NVL(b.swraid_used,0)			swraid_used		,
	NVL(b.swraid_free,0)			swraid_free		,
	NVL(b.disk_backup_rawsize,0)		disk_backup_rawsize	,
	NVL(b.disk_backup_size,0)		disk_backup_size	,
	NVL(b.disk_backup_used,0)		disk_backup_used	,
	NVL(b.disk_backup_free,0)		disk_backup_free	,
	NVL(b.disk_rawsize,0)			disk_rawsize		,
	NVL(b.disk_size,0)			disk_size		,
	NVL(b.disk_used,0)			disk_used		,
	NVL(b.disk_free,0)			disk_free		,
	NVL(b.rawsize,0)			rawsize			,
	NVL(b.sizeb,0)				sizeb			,
	NVL(b.used,0)				used			,
	NVL(b.free,0)				free			,
	NVL(b.vendor_emc_size,0)		vendor_emc_size		,
	NVL(b.vendor_emc_rawsize,0)		vendor_emc_rawsize	,
	NVL(b.vendor_sun_size,0)		vendor_sun_size		,
	NVL(b.vendor_sun_rawsize,0)		vendor_sun_rawsize	,
	NVL(b.vendor_hp_size,0)			vendor_hp_size		,
	NVL(b.vendor_hp_rawsize,0)		vendor_hp_rawsize	,
	NVL(b.vendor_hitachi_size,0)		vendor_hitachi_size	,
	NVL(b.vendor_hitachi_rawsize,0)		vendor_hitachi_rawsize	,
	NVL(b.vendor_others_size,0)		vendor_others_size	,
	NVL(b.vendor_others_rawsize,0)		vendor_others_rawsize	,
	NVL(b.vendor_nfs_netapp_size,0)		vendor_nfs_netapp_size	,
	NVL(b.vendor_nfs_emc_size,0)		vendor_nfs_emc_size	,
	NVL(b.vendor_nfs_sun_size,0)		vendor_nfs_sun_size	,
	NVL(b.vendor_nfs_others_size,0)		vendor_nfs_others_size	
FROM	storage_summaryObject b,
	(
		SELECT	target_name	name,
			target_id	id,
			'HOST' 		type,
			1		hostcount
		FROM	mgmt_targets_view
		UNION
		SELECT	name,
			id,
			type,
			host_count 	hostcount
		FROM	stormon_group_table
	) a
WHERE	b.id(+) = a.id
/

-----------------------------------------------------------------------------------
--
--  View to get the status of storage summaries and job
--
-----------------------------------------------------------------------------------	
CREATE OR REPLACE VIEW stormon_summary_status_view
(
	node_id,
	node_name,
	target_name,
	target_type,
	summaryflag,
	collection_timestamp,
	tz,
	start_time,
	finish_time,
	job_status,
	job_name,
	job_duration,
	epm_version,
	status
)	
AS
SELECT	d.node_id,
	d.node_name,
	d.target_name,
	d.target_type,
	a.summaryflag,
	a.collection_timestamp,
	d.tz,
	c.start_time,
	c.last_collection_timestamp,
	c.status job_status,
	c.job_name,
	ROUND((c.last_collection_timestamp-c.start_time)*24*60*60) duration, 
	e.epm_version,
	( 
		CASE WHEN (
			-- NO job has been scheduled or may be the job has failed, we select only completed and scheduled jobs
				d.target_type = 'oracle_sysman_node'	-- Its a host target
			AND	c.start_time IS NULL 			-- and there is no job for it
		)
		THEN
			'FAILED-stormon Job Missing'
		WHEN (
			-- There is a job and its old
				c.start_time IS NOT NULL							-- There is a job for this target ( host or db)
			AND	( CAST ( SYS_EXTRACT_UTC(systimestamp) AS DATE ) - c.start_time ) >= 1.5 	-- BUt its old
		)  THEN
			'FAILED-stormon Job not executed in Last 24 Hours'		
		WHEN  ( 			  			
			-- 2 hours after job has executed
			-- There is no data in the stormon_load_status table
			-- OR
			-- the timestamp of the collection in stormon_load_statis is lesser than the job execution date
				c.start_time IS NOT NULL							-- Job started
			AND	c.last_collection_timestamp IS NOT NULL						-- JOb completed
			AND	( CAST ( SYS_EXTRACT_UTC(systimestamp) AS DATE ) - c.start_time ) >= (2/24)	-- Its 2 hours since the job executed
			AND	(
					f.timestamp IS NULL								-- No data in stormon_load_status for the target the job was scheduled for
				OR	CAST ( SYS_EXTRACT_UTC(f.min_collection_timestamp) AS DATE ) < c.start_time	-- The timestamp of the collection is lesser than the job start		
			)
		) THEN
			'FAILED-Job Executed , but no metrics loaded'
		WHEN (
				d.target_type = 'oracle_sysman_node'			-- Log one row only for the host job, why log a row for each database target
				AND (
					(-- The new collection exists but cannot be summarized
						g.max_collection_timestamp IS NOT NULL
					AND	CAST ( SYS_EXTRACT_UTC(systimestamp) AS DATE ) - CAST ( SYS_EXTRACT_UTC(g.timestamp) AS DATE ) > ( 2 / ( 24*60))-- Just give that 2 min time window for computing summary after updating stormon_load_status table
					AND	a.collection_timestamp IS NULL 
					OR	a.collection_timestamp <  g.max_collection_timestamp 
					)
					OR	a.summaryFlag = 'I'					-- Or The summary has an issue		
				)
		) THEN
			'FAILED-Metrics loaded , but Summary Computation Failed'
		WHEN 	d.target_type = 'oracle_sysman_node' THEN
			'Successfully Summarized Jobs'	
		ELSE
			'IGNORE'  -- Its a database target , so ignore
		END	
	) status
FROM    (
                SELECT  a.target_id             				node_id,
                        a.target_name           				node_name,
			SUBSTR(a.target_name,1,INSTRB(a.target_name,'.')-1) 	host,
                        b.target_name,
                        b.target_type,
			a.tz
                FROM    mgmt_targets_view a,
                        merged_node_target_map_view b
                WHERE   a.target_name = b.node_name
                AND     b.target_type IN ('oracle_sysman_node','oracle_sysman_database')
                AND     UPPER(a.operating_system) NOT LIKE '%HPUX%'
                AND     UPPER(a.operating_system) NOT LIKE '%WINDOW%'
                AND     a.target_type = 'oracle_sysman_node'
        ) d,
        (
                SELECT  DISTINCT host,
                        FIRST_VALUE(version) OVER ( PARTITION BY host, package ORDER BY timestamp DESC ) epm_version
                FROM    patcher.log@package_db
                WHERE   package = 'stormon'
        ) e,
        storage_summaryObject_view a,
        stormon_active_targets_view c,
        stormon_load_status f,
        (
                SELECT  node_id,
			MAX(timestamp)			timestamp,
                        MAX(min_collection_timestamp) 	min_collection_timestamp,
                        MIN(max_collection_timestamp) 	max_collection_timestamp
                FROM    stormon_load_status
                GROUP BY
                        node_id
        ) g
WHERE   d.node_id = a.id(+)
AND     d.node_id = c.node_id(+)
AND     d.node_id = f.node_id(+)
AND     d.node_id = g.node_id(+)
AND     d.target_name = c.target_name(+)
AND     d.target_name = f.target_name(+)
AND     d.target_type = c.target_type(+)
AND     d.target_type=  f.target_type(+)
AND     d.host = e.host(+)
AND	a.type(+) = 'HOST'
/


-- Remove reference to this table in storage_summary_report and storage.sql TBD
--CREATE TABLE stormon_group_reports_type (
--report_type		VARCHAR2(50),
--parent_type		VARCHAR2(50),
--child_type		VARCHAR2(50)
--)
--/

--INSERT INTO stormon_group_reports_type VALUES('DC_LOB_REPORTS','REPORTING_ALL','REPORTING_DATACENTER')
--/
--INSERT INTO stormon_group_reports_type VALUES('DC_LOB_REPORTS','REPORTING_ALL','REPORTING_LOB')
--/
--INSERT INTO stormon_group_reports_type VALUES('DC_LOB_REPORTS','REPORTING_DATACENTER','REPORTING_DATACENTER_LOB')
--/
--INSERT INTO stormon_group_reports_type VALUES('DC_LOB_REPORTS','REPORTING_LOB','REPORTING_DATACENTER_LOB')
--/

--COMMIT;

GRANT SELECT , INSERT , DELETE , UPDATE ON mgmt_current_metrics TO stormon_mozart
/
GRANT SELECT ON mgmt_metrics TO stormon_mozart
/
GRANT SELECT ON mozart_mgmt_targets TO stormon_mozart
/
GRANT SELECT ON mozart_node_target_map TO stormon_mozart
/
GRANT SELECT ON mozart_smp_vdj_job_per_target TO stormon_mozart
/
-------------------------------------------------------------------------------------------------
--		TEMPORARY TABLES FOR SUMMARY COMPUTATION 
--
--	Cannot monitor statistics on temporary tables
--
-------------------------------------------------------------------------------------------------

CREATE GLOBAL TEMPORARY TABLE stormon_temp_disk (
	rowcount		INTEGER,	
	target_id		VARCHAR2(256), 	 /* is RAW(16) in git3       */
	targetname		VARCHAR2(256),	-- Target name
	keyvalue		VARCHAR2(2000), 	/* is varchar2(256) in git3 */
	collection_timestamp	DATE,
	rawsizeb		NUMBER,
	sizeb			NUMBER,
	usedb			NUMBER,
	freeb			NUMBER,
	storagevendor		VARCHAR2(256),
	storageproduct		VARCHAR2(256),
	storageconfig		VARCHAR2(256),
 	type			VARCHAR2(256),	-- DISK,SLICE,SUBDISK
	filetype		VARCHAR2(256),	-- BLOCK OR CHARACTER
	linkinode		VARCHAR2(256),	
	diskkey			VARCHAR2(2000),
	path			VARCHAR2(256),	-- OS Path
	status			VARCHAR2(2000),	-- Formatted or unformatted,OFFLINE
	parent			VARCHAR2(256),	-- SWRAID parent
	backup			VARCHAR2(1),	-- Y/N flag for backup elements
	freetype		VARCHAR2(2000)	
)
ON COMMIT PRESERVE ROWS
/
CREATE INDEX stormon_temp_disk_idx1 ON stormon_temp_disk(diskkey, keyvalue,type,filetype,linkinode)
/


CREATE GLOBAL TEMPORARY TABLE stormon_temp_swraid (
	rowcount		INTEGER,	
	target_id		VARCHAR2(256), 	 /* is RAW(16) in git3       */
	targetname		VARCHAR2(256),	-- Target name
	keyvalue		VARCHAR2(2000), 	/* is varchar2(256) in git3 */
	collection_timestamp	DATE,
	rawsizeb		NUMBER,
	sizeb			NUMBER,
	usedb			NUMBER,
	freeb			NUMBER,
	storagevendor		VARCHAR2(256),
	storageproduct		VARCHAR2(256),
	storageconfig		VARCHAR2(256),
 	type			VARCHAR2(256),	-- DISK,SLICE,SUBDISK
	filetype		VARCHAR2(256),	-- BLOCK OR CHARACTER
	linkinode		VARCHAR2(256),	
	diskkey			VARCHAR2(2000),
	path			VARCHAR2(256),	-- OS Path
	status			VARCHAR2(256),	-- Formatted or unformatted,OFFLINE
	parent			VARCHAR2(256),	-- SWRAID parent
	backup			VARCHAR2(1),	-- Y/N flag for backup elements
	freetype		VARCHAR2(256)	
)
ON COMMIT PRESERVE ROWS
/
CREATE INDEX stormon_temp_swraid_idx1 ON stormon_temp_swraid(diskkey, keyvalue,type,filetype,linkinode)
/


CREATE GLOBAL TEMPORARY TABLE stormon_temp_volume (
	rowcount		INTEGER,
  	target_id		VARCHAR2(256), /* is RAW(16) in git3       */
	targetname		VARCHAR2(256),	-- Target name
  	keyvalue		VARCHAR2(2000), /* is varchar2(256) in git3 */
	collection_timestamp	DATE,
	type			VARCHAR2(256),	-- VOLUME, DISK, DISKSLICE
	name			VARCHAR2(256),
	diskgroup		VARCHAR2(256),
	rawsizeb		NUMBER,
	sizeb			NUMBER,
	usedb			NUMBER,
	freeb			NUMBER,
	path			VARCHAR2(256),
	linkinode		VARCHAR2(256),
	filetype		VARCHAR2(256),
	configuration		VARCHAR2(256),
	diskname		VARCHAR2(256),
	backup			VARCHAR2(1),
	freetype		VARCHAR2(2000)
)
ON COMMIT PRESERVE ROWS
/
CREATE INDEX stormon_temp_vol_idx1 ON stormon_temp_volume(type, keyvalue,linkinode)
/


CREATE GLOBAL TEMPORARY TABLE stormon_temp_filesystem(
	rowcount		INTEGER,
  	target_id		VARCHAR2(256),        /* is RAW(16) in git3       */
	targetname		VARCHAR2(256),	-- Target name
  	keyvalue		VARCHAR2(2000), /* is varchar2(256) in git3 */
	collection_timestamp	DATE,
	type			VARCHAR2(256),
	filesystem		VARCHAR2(256),
	linkinode		VARCHAR2(256),
	rawsizeb		NUMBER,
	sizeb			NUMBER,
	usedb			NUMBER,
	freeb			NUMBER,
	mountpoint		VARCHAR2(256),
	mountpointid		VARCHAR2(256),
	mounttype		VARCHAR2(256),
	privilege		VARCHAR2(256),
	server			VARCHAR2(256),
	vendor			VARCHAR2(256),
	nfscount		NUMBER,
	backup			VARCHAR2(1)
)
ON COMMIT PRESERVE ROWS
/
CREATE INDEX stormon_temp_filesystem_idx1 ON stormon_temp_filesystem(keyvalue)
/
CREATE INDEX stormon_temp_filesystem_idx2 ON stormon_temp_filesystem(mountpointid)
/
CREATE INDEX stormon_temp_filesystem_idx3 ON stormon_temp_filesystem(linkinode)
/
CREATE INDEX stormon_temp_filesystem_idx4 ON stormon_temp_filesystem(type)
/


CREATE GLOBAL TEMPORARY TABLE stormon_temp_app(
	rowcount		INTEGER,
  	target_id		VARCHAR2(256), /* is RAW(16) in git3       */  	
	targetname		VARCHAR2(256),	-- Target name for the node
	oem_target_name		VARCHAR2(256),	-- target_name for the database
	parentkey       	VARCHAR2(2000),
  	keyvalue		VARCHAR2(2000), /* is varchar2(256) in git3 */
	collection_timestamp	DATE,
	type			VARCHAR2(256),
	appname			VARCHAR2(256),
	appid			VARCHAR2(256),
	filename		VARCHAR2(256),
	filetype		VARCHAR2(256),
	linkinode		VARCHAR2(256),
	rawsizeb		NUMBER,
	sizeb			NUMBER,
	usedb			NUMBER,
	freeb			NUMBER,
	tablespace		VARCHAR2(256),
	backup			VARCHAR2(1)
)
ON COMMIT PRESERVE ROWS
/
CREATE INDEX stormon_temp_app_idx1 ON stormon_temp_app(appid,keyvalue,linkinode)
/
                                                                                                                                                 

-------------------------------------------------------------------------------------------------
--		TEMPORARY TABLES FOR SHARED STORAGE COMPUTATION
-------------------------------------------------------------------------------------------------

CREATE GLOBAL TEMPORARY TABLE stormon_temp_comb_disk (
	rowcount		INTEGER,	
	target_id		VARCHAR2(256), 	 /* is RAW(16) in git3       */
	targetname		VARCHAR2(256),	-- Target name
	keyvalue		VARCHAR2(2000), 	/* is varchar2(256) in git3 */
	collection_timestamp	DATE,
	rawsizeb		NUMBER,
	sizeb			NUMBER,
	usedb			NUMBER,
	freeb			NUMBER,
	storagevendor		VARCHAR2(256),
	storageproduct		VARCHAR2(256),
	storageconfig		VARCHAR2(256),
 	type			VARCHAR2(256),	-- DISK,SLICE,SUBDISK
	filetype		VARCHAR2(256),	-- BLOCK OR CHARACTER
	linkinode		VARCHAR2(256),	
	diskkey			VARCHAR2(2000),
	path			VARCHAR2(256),	-- OS Path
	status			VARCHAR2(2000),	-- Formatted or unformatted,OFFLINE
	parent			VARCHAR2(256),	-- SWRAID parent
	backup			VARCHAR2(1),	-- Y/N flag for backup elements
	freetype		VARCHAR2(2000)	
)
ON COMMIT PRESERVE ROWS
/
-- Index on disk key ?

CREATE GLOBAL TEMPORARY TABLE stormon_temp_comb_swraid (
	rowcount		INTEGER,	
	target_id		VARCHAR2(256), 	 /* is RAW(16) in git3       */
	targetname		VARCHAR2(256),	-- Target name
	keyvalue		VARCHAR2(2000), 	/* is varchar2(256) in git3 */
	collection_timestamp	DATE,
	rawsizeb		NUMBER,
	sizeb			NUMBER,
	usedb			NUMBER,
	freeb			NUMBER,
	storagevendor		VARCHAR2(256),
	storageproduct		VARCHAR2(256),
	storageconfig		VARCHAR2(256),
 	type			VARCHAR2(256),	-- DISK,SLICE,SUBDISK
	filetype		VARCHAR2(256),	-- BLOCK OR CHARACTER
	linkinode		VARCHAR2(256),	
	diskkey			VARCHAR2(2000),
	path			VARCHAR2(256),	-- OS Path
	status			VARCHAR2(256),	-- Formatted or unformatted,OFFLINE
	parent			VARCHAR2(256),	-- SWRAID parent
	backup			VARCHAR2(1),	-- Y/N flag for backup elements
	freetype		VARCHAR2(256)	
)
ON COMMIT PRESERVE ROWS
/

CREATE GLOBAL TEMPORARY TABLE stormon_temp_comb_volume (
	rowcount		INTEGER,
  	target_id		VARCHAR2(256), /* is RAW(16) in git3       */
	targetname		VARCHAR2(256),	-- Target name
  	keyvalue		VARCHAR2(2000), /* is varchar2(256) in git3 */
	collection_timestamp	DATE,
	type			VARCHAR2(256),	-- VOLUME, DISK, DISKSLICE
	name			VARCHAR2(256),
	diskgroup		VARCHAR2(256),
	rawsizeb		NUMBER,
	sizeb			NUMBER,
	usedb			NUMBER,
	freeb			NUMBER,
	path			VARCHAR2(256),
	linkinode		VARCHAR2(256),
	filetype		VARCHAR2(256),
	configuration		VARCHAR2(256),
	diskname		VARCHAR2(256),
	backup			VARCHAR2(1),
	freetype		VARCHAR2(2000)
)
ON COMMIT PRESERVE ROWS
/


CREATE GLOBAL TEMPORARY TABLE stormon_temp_comb_filesystem(
	rowcount		INTEGER,
  	target_id		VARCHAR2(256),        /* is RAW(16) in git3       */
	targetname		VARCHAR2(256),	-- Target name
  	keyvalue		VARCHAR2(2000), /* is varchar2(256) in git3 */
	collection_timestamp	DATE,
	type			VARCHAR2(256),
	filesystem		VARCHAR2(256),
	linkinode		VARCHAR2(256),
	rawsizeb		NUMBER,
	sizeb			NUMBER,
	usedb			NUMBER,
	freeb			NUMBER,
	mountpoint		VARCHAR2(256),
	mountpointid		VARCHAR2(256),
	mounttype		VARCHAR2(256),
	privilege		VARCHAR2(256),
	server			VARCHAR2(256),
	vendor			VARCHAR2(256),
	nfscount		NUMBER,
	backup			VARCHAR2(1)
)
ON COMMIT PRESERVE ROWS
/

CREATE GLOBAL TEMPORARY TABLE stormon_temp_comb_app(
	rowcount		INTEGER,
  	target_id		VARCHAR2(256), /* is RAW(16) in git3       */  	
	targetname		VARCHAR2(256),	-- Target name for the node
	oem_target_name		VARCHAR2(256),	-- target_name for the database
	parentkey       	VARCHAR2(2000),
  	keyvalue		VARCHAR2(2000), /* is varchar2(256) in git3 */
	collection_timestamp	DATE,
	type			VARCHAR2(256),
	appname			VARCHAR2(256),
	appid			VARCHAR2(256),
	filename		VARCHAR2(256),
	filetype		VARCHAR2(256),
	linkinode		VARCHAR2(256),
	rawsizeb		NUMBER,
	sizeb			NUMBER,
	usedb			NUMBER,
	freeb			NUMBER,
	tablespace		VARCHAR2(256),
	backup			VARCHAR2(1)
)
ON COMMIT PRESERVE ROWS
/

-- Create the storage packages
@$HOME/stormon/repository/storage_summary_load

@$HOME/stormon/repository/storage_summary_db_9i

@$HOME/stormon/repository/storage_summary_analysis

@$HOME/stormon/repository/maintenance/grant_gen
