SELECT 
 ROWNUM, a.name, a.id, a.type, a.timestamp , a.collection_timestamp 
FROM ( 
SELECT 'TOTAL' name, 
	NULL id, 'HOST' type, 
	SYSDATE timestamp, 
	MAX(a.collection_timestamp) collection_timestamp
	FROM storage_summaryObject_view a, 
	(
		SELECT target_id id FROM mgmt_targets_view a WHERE ( LOWER(a.target_name) LIKE '%gitmon%' ) 
		UNION 
		SELECT	a.id 
		FROM	stormon_group_table a 
		WHERE	type = 'SHARED_GROUP' 
		AND NOT EXISTS 
		( 
			SELECT	1 
			FROM	(
				SELECT	target_id
				FROM	mgmt_targets_view 
				MINUS
				SELECT	target_id
				FROM	mgmt_targets_view
				WHERE	LOWER(target_name) LIKE '%gitmon%'				
				) c,
				stormon_host_groups b 
			WHERE	b.group_id = a.id
		)
	) b 
WHERE a.id = b.id AND a.summaryFlag = 'Y' ) a 
/



DELETE FROM PLAN_TABLE
/

EXPLAIN PLAN SET STATEMENT_ID = '1' FOR
		SELECT	 /*+ no_merge */a.id 
		FROM	stormon_group_table a 
		WHERE	type = 'SHARED_GROUP' 
		AND NOT EXISTS 
		( 
			SELECT	 /*+ no_merge */ 1 
			FROM	stormon_host_groups b 
			WHERE	b.group_id = a.id 
			AND	b.target_id NOT IN 
						(
							SELECT	target_id id 
							FROM	mgmt_targets_view a 
							WHERE	( LOWER(a.target_name) LIKE '%gitmon%' )
						)
		)
/

@$HOME/tmp/utlxpls

---------------

DELETE FROM PLAN_TABLE
/

EXPLAIN PLAN SET STATEMENT_ID = '1' FOR
		SELECT	/*+ FIRST_ROWS */a.id 
		FROM	stormon_group_table a 
		WHERE	type = 'SHARED_GROUP' 
		AND NOT EXISTS 
		( 
			SELECT	/*+ FIRST_ROWS */1 
			FROM	stormon_host_groups b 
			WHERE	b.group_id = a.id
			AND	b.target_id NOT IN 
						(
							SELECT	target_id id 
							FROM	mgmt_targets_view a 
							WHERE	a.target_name LIKE '%gitmon%'
						)
		)
/

@$HOME/tmp/utlxpls

---------------

DELETE FROM PLAN_TABLE
/

EXPLAIN PLAN SET STATEMENT_ID = '1' FOR
		SELECT	/*+ DRIVING_SITE(a)*/a.id 
		FROM	stormon_group_table a 
		WHERE	type = 'SHARED_GROUP' 
		AND NOT EXISTS 
		( 
			SELECT	1 
			FROM	(
				SELECT	target_id
				FROM	mgmt_targets_view 
				MINUS
				SELECT	target_id
				FROM	mgmt_targets_view
				WHERE	LOWER(target_name) LIKE '%gitmon%'				
				) c,
				stormon_host_groups b 
			WHERE	b.group_id = a.id
			AND	b.target_id = c.target_id
		)
/	

@$HOME/tmp/utlxpls

----------------------------

DELETE FROM PLAN_TABLE
/

EXPLAIN PLAN SET STATEMENT_ID = '1' FOR
		SELECT	/*+ USE_NL(a) */a.id 
		FROM	stormon_group_table a 
		WHERE	type = 'SHARED_GROUP' 
		AND NOT EXISTS 
		(
			SELECT	/*+ FIRST_ROWS */1 
			FROM	stormon_host_groups b				
			WHERE	b.group_id = a.id
			AND	NOT EXISTS 
			(
                                        SELECT  target_id 
                                        FROM    mgmt_targets_view c 
                                        WHERE   LOWER(c.target_name) LIKE '%gitmon%' 
					AND	b.target_id = c.target_id
			) 
		)		
/

@$HOME/tmp/utlxpls

----------------------------

DELETE FROM PLAN_TABLE
/

EXPLAIN PLAN SET STATEMENT_ID = '1' FOR
SELECT  COUNT(*) FROM stormon_temp_filesystem a 
WHERE	LOWER(NVL(type,'X')) != 'nfs'	
AND	linkinode IS NOT NULL
AND	EXISTS
	(
		SELECT	1
		FROM	stormon_temp_filesystem b
  		WHERE	NVL(mounttype,'x') != 'BASE'	 -- Cached from a non base filesystem
  		AND	mountpointid IS NOT NULL
  		AND	b.sizeb >= a.sizeb		 -- The cached filesystem should be smaller or equal to the size of the mointpoint
 		AND	a.linkinode != b.linkinode
		AND	b.mountpointid = SUBSTR(a.linkinode,1,INSTR(a.linkinode,'-')-1)
	)
/

@$HOME/tmp/utlxpls

----------------------------

DELETE FROM PLAN_TABLE
/

EXPLAIN PLAN SET STATEMENT_ID = '1' FOR
SELECT	DISTINCT a.diskkey
FROM	storage_disk_table a
WHERE	a.diskkey IN
		(
			SELECT	b.diskkey
			FROM	stormon_temp_disk b
			WHERE	target_id = '23654'
			AND	status NOT LIKE '%DISK_OFFLINE%' 
			AND	status != 'NA'
		)
	AND a.target_id != '23654'
	AND EXISTS (
			SELECT 'x'
			FROM	storage_summaryObject
			WHERE	id = a.target_id
			AND	summaryFlag = 'Y'
		)	
	AND status NOT LIKE '%DISK_OFFLINE%' 
	AND status != 'NA';

@$HOME/tmp/utlxpls
---------------------------
DELETE FROM PLAN_TABLE
/

EXPLAIN PLAN SET STATEMENT_ID = '1' FOR	
			SELECT	DISTINCT target_id,
				keyvalue,
				type,
				diskgroup,					
				STORAGE_SUMMARY_DB.CONCATLIST(CURSOR( SELECT path FROM stormon_temp_volume WHERE type = a.type AND keyvalue = a.keyvalue ORDER BY rowcount)),
				FIRST_VALUE(rawsizeb) OVER ( PARTITION BY type, keyvalue ORDER BY rawsizeb DESC NULLS LAST ),
				FIRST_VALUE(sizeb) OVER ( PARTITION BY type, keyvalue ORDER BY sizeb DESC NULLS LAST ),
				FIRST_VALUE(usedb) OVER ( PARTITION BY type, keyvalue ORDER BY sizeb DESC NULLS LAST ),
				FIRST_VALUE(freeb) OVER ( PARTITION BY type, keyvalue ORDER BY sizeb DESC NULLS LAST ),				
				FIRST_VALUE(configuration) OVER (PARTITION BY type, keyvalue ORDER BY LENGTH(configuration) DESC NULLS LAST ),
				FIRST_VALUE(freetype) OVER (PARTITION BY type, keyvalue ORDER BY LENGTH(freetype) DESC NULLS LAST ),
				FIRST_VALUE(backup) OVER (PARTITION BY type, keyvalue ORDER BY LENGTH(backup) DESC NULLS LAST )
			FROM	stormon_temp_volume a;

@$HOME/tmp/utlxpls
---------------------------
DELETE FROM PLAN_TABLE
/

EXPLAIN PLAN SET STATEMENT_ID = '1' FOR	
			SELECT	DISTINCT target_id,
				keyvalue,
				type,
				STORAGE_SUMMARY_DB.CONCATLIST(CURSOR( SELECT filesystem FROM stormon_temp_filesystem WHERE keyvalue = a.keyvalue ORDER BY rowcount)) ,
				STORAGE_SUMMARY_DB.CONCATLIST(CURSOR( SELECT mountpoint FROM stormon_temp_filesystem WHERE keyvalue = a.keyvalue ORDER BY rowcount)) ,
				FIRST_VALUE(rawsizeb) OVER ( PARTITION BY keyvalue ORDER BY rawsizeb DESC NULLS LAST ) ,
				FIRST_VALUE(sizeb) OVER ( PARTITION BY keyvalue ORDER BY sizeb DESC NULLS LAST ) ,
				FIRST_VALUE(usedb) OVER ( PARTITION BY keyvalue ORDER BY sizeb DESC NULLS LAST ) ,
				FIRST_VALUE(freeb) OVER ( PARTITION BY keyvalue ORDER BY sizeb DESC NULLS LAST ) ,
				FIRST_VALUE(backup) OVER ( PARTITION BY keyvalue ORDER BY DECODE(backup,'Y',2,1) DESC NULLS LAST )
			FROM	stormon_temp_filesystem a
			WHERE	type != 'nfs';

@$HOME/tmp/utlxpls
----------------------------------------------------------------------
DELETE FROM PLAN_TABLE
/

EXPLAIN PLAN SET STATEMENT_ID = '1' FOR	
UPDATE	stormon_temp_filesystem a
SET	( rawsizeb, sizeb, usedb,freeb, backup ) = 
(
			SELECT	DISTINCT 
				FIRST_VALUE(rawsizeb) OVER ( PARTITION BY keyvalue ORDER BY rawsizeb DESC NULLS LAST ) ,
				FIRST_VALUE(sizeb) OVER ( PARTITION BY keyvalue ORDER BY sizeb DESC NULLS LAST ) ,
				FIRST_VALUE(usedb) OVER ( PARTITION BY keyvalue ORDER BY sizeb DESC NULLS LAST ) ,
				FIRST_VALUE(freeb) OVER ( PARTITION BY keyvalue ORDER BY sizeb DESC NULLS LAST ) ,
				FIRST_VALUE(backup) OVER ( ORDER BY DECODE(backup,'Y',2,1) DESC NULLS LAST )
			FROM	stormon_temp_filesystem b
			WHERE	a.type = b.type
			AND	a.keyvalue = b.keyvalue
)
WHERE	type != 'nfs'
/	

@$HOME/tmp/utlxpls
----------------------------------------------------------------------

SELECT	DISTINCT target_id,
	keyvalue,
	type,
	STORAGE_SUMMARY_DB.CONCATLIST(CURSOR( SELECT filesystem FROM stormon_temp_filesystem WHERE keyvalue = a.keyvalue ORDER BY rowcount)) ,
	STORAGE_SUMMARY_DB.CONCATLIST(CURSOR( SELECT mountpoint FROM stormon_temp_filesystem WHERE keyvalue = a.keyvalue ORDER BY rowcount)) ,
	rawsizeb, 
	sizeb, 
	usedb,
	freeb, 
	backup
FROM	stormon_temp_filesystem a
WHERE	type != 'nfs';

SELECT	DISTINCT target_id,
	keyvalue,
	type,
	rawsizeb, 
	sizeb, 
	usedb,
	freeb, 
	backup
FROM	stormon_temp_filesystem a
WHERE	type != 'nfs';
-------------------------------------------------------------------

ALTER SESSION SET OPTIMIZER_MODE=ALL_ROWS
/
ALTER SESSION SET OPTIMIZER_GOAL=FIRST_ROWS
/
ALTER SESSION SET OPTIMIZER_INDEX_COST_ADJ=10
/
ALTER SESSION SET HASH_JOIN_ENABLED=FALSE
/


REFRESH MGMT_TARGETS FROM 9I
REFRESH MGMT_TARGETS FROM MOZART

PERFORM MIGRATION OF 9I TO MOZART ( this will add the new mozart targets )

BUILD THE NEW MGMT_TARGETS

DELETE THE GROUPS WITH TARGETS NOT IN MGMT_TARGETS

DELETE THE SUMMARIES WITH ID NOT IN THE NEW TARGETS OR STORMON_HOST_GROUPS

REBUILD THE GROUPS
	DELETE THOSE GROUPS WHICH ARE NOT REQUIRED ANYMORE ???



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


DECLARE
l_list_of_tables	stringTable := stringTAble(
					'STORMON_HOST_GROUPS',
					'STORMON_GROUP_TABLE',
					'MGMT_TARGETS_MERGED');

l_count			INTEGER;

BEGIN

	FOR i IN l_list_of_tables.FIRST..l_list_of_tables.LAST LOOP
	
		EXECUTE IMMEDIATE ' SELECT COUNT(*) FROM '||l_list_of_tables(i) INTO l_count;

		DBMS_OUTPUT.PUT_LINE(' Count for table '||l_list_of_tables(i)||' is '||l_count);

	END LOOP;
END;
/



---------------
DELETE FROM PLAN_TABLE
/

EXPLAIN PLAN SET STATEMENT_ID = '1' FOR
SELECT  /*+ DRIVING_SITE(a)*/a.id 
FROM ( 
SELECT  /*+ DRIVING_SITE(a)*/'TOTAL' name, NULL id 
FROM storage_summaryObject_view a, (SELECT  /*+ DRIVING_SITE(a)*/target_id id FROM mgmt_targets_view a WHERE ( LOWER(a.target_name) LIKE '%gitmon1%' ) UNION SELECT  /*+ DRIVING_SITE(a)*/a.id FROM stormon_group_table a WHERE type = 'SHARED_GROUP' AND NOT EXISTS ( SELECT 1 FROM ( SELECT target_id FROM mgmt_targets_view MINUS SELECT target_id id FROM mgmt_targets_view a WHERE ( LOWER(a.target_name) LIKE '%gitmon1%' ) ) c, stormon_host_groups b WHERE b.group_id = a.id AND b.target_id = c.target_id ) ) b WHERE a.id = b.id AND a.summaryFlag = 'Y' ) a 
/

@$HOME/tmp/utlxpls



SELECT   /*+ DRIVING_SITE(a)*/ summaryObject( a.name,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
FROM ( 
	SELECT /*+ DRIVING_SITE(a)*/ 'TOTAL' name
	FROM storage_summaryObject_view a, 
	      (
		SELECT /*+ DRIVING_SITE(a)*/ target_id id FROM 
		mgmt_targets_view a WHERE ( LOWER(a.target_name) LIKE '%gitmon1%' ) 
		UNION 
		SELECT /*+ DRIVING_SITE(a)*/ a.id 
		FROM stormon_group_table a 
		WHERE type = 'SHARED_GROUP' 
		AND NOT EXISTS ( 
			SELECT /*+ DRIVING_SITE(b)*/ 1 
			FROM 
				(
				SELECT /*+ DRIVING_SITE(a)*/ target_id 
				FROM 	mgmt_targets_view a 
				MINUS 
				SELECT /*+ DRIVING_SITE(a)*/ target_id id 
				FROM mgmt_targets_view a 
				WHERE ( LOWER(a.target_name) LIKE '%gitmon1%' ) 
				) c, 
				stormon_host_groups b 
			WHERE b.group_id = a.id 
			AND b.target_id = c.target_id 
		) 
	) b 
	WHERE a.id = b.id 
	AND a.summaryFlag = 'Y' ) a 
/


CREATE OR REPLACE PACKAGE test_pass_obj AS

	TYPE obj_rec IS RECORD ( x VARCHAR2(10));

	TYPE obj_tab IS TABLE OF obj_rec INDEX BY BINARY_INTEGER;
	
	PROCEDURE checks ( v_sumobjects OUT test_pass_obj.obj_tab );

END test_pass_obj;
/

CREATE OR REPLACE PACKAGE BODY test_pass_obj AS

	PROCEDURE checks ( v_sumobjects OUT test_pass_obj.obj_tab ) IS
	
		k	storageSummaryTable;

	BEGIN

		DBMS_OUTPUT.PUT_LINE('Check');
		
		SELECT	summaryObject(
ROWCOUNT,
NAME,
ID,
TIMESTAMP,
COLLECTION_TIMESTAMP,
HOSTCOUNT,
ACTUAL_TARGETS,
ISSUES,
WARNINGS,
SUMMARYFLAG,
APPLICATION_RAWSIZE,
APPLICATION_SIZE,
APPLICATION_USED,
APPLICATION_FREE,
ORACLE_DATABASE_RAWSIZE,
ORACLE_DATABASE_SIZE,
ORACLE_DATABASE_USED,
ORACLE_DATABASE_FREE,
LOCAL_FILESYSTEM_RAWSIZE,
LOCAL_FILESYSTEM_SIZE,
LOCAL_FILESYSTEM_USED,
LOCAL_FILESYSTEM_FREE,
NFS_EXCLUSIVE_SIZE,
NFS_EXCLUSIVE_USED,
NFS_EXCLUSIVE_FREE,
NFS_SHARED_SIZE,
NFS_SHARED_USED,
NFS_SHARED_FREE,
VOLUMEMANAGER_RAWSIZE,
VOLUMEMANAGER_SIZE,
VOLUMEMANAGER_USED,
VOLUMEMANAGER_FREE,
SWRAID_RAWSIZE,
SWRAID_SIZE,
SWRAID_USED,
SWRAID_FREE,
DISK_BACKUP_RAWSIZE,
DISK_BACKUP_SIZE,
DISK_BACKUP_USED,
DISK_BACKUP_FREE,
DISK_RAWSIZE,
DISK_SIZE,
DISK_USED,
DISK_FREE,
RAWSIZE,
SIZEB,
USED,
FREE,
VENDOR_EMC_SIZE,
VENDOR_EMC_RAWSIZE,
VENDOR_SUN_SIZE,
VENDOR_SUN_RAWSIZE,
VENDOR_HP_SIZE,
VENDOR_HP_RAWSIZE,
VENDOR_HITACHI_SIZE,
VENDOR_HITACHI_RAWSIZE,
VENDOR_OTHERS_SIZE,
VENDOR_OTHERS_RAWSIZE,
VENDOR_NFS_NETAPP_SIZE,
VENDOR_NFS_EMC_SIZE,
VENDOR_NFS_SUN_SIZE,
VENDOR_NFS_OTHERS_SIZE
) 
		BULK COLLECT INTO k
		FROM	storage_summaryObject
		WHERE	name like '%gitmon%';

	END checks;
	

END test_pass_obj;
/


DECLARE

	TYPE summary_rec IS RECORD (
	rowcount			intTable,
	name				stringTable,	
	id				stringTable,
	type				stringTable,	
	timestamp			dateTable,	-- Timestamp for the summaryObject
	collection_timestamp		dateTable,	-- Max collection timestamp of the metrics of this summaryobject
	hostcount			intTable,	-- No of targets in this summary
	actual_targets			intTable,	-- No of targets counted in this summary
	issues				intTable,	-- No of issues , or hosts which failed summary computation
	notcollected			intTable,	-- N, of hosts for which storage metrics have never been collected
	warnings			intTable,	-- No. od warnings , or No. of hosts with warnings in a group summary
	summaryflag			stringTable,	-- Flag indicating if this summary is a place holder Y/N
	application_rawsize		numberTable,		-- Non Oracle DB applications
	application_size		numberTable,
	application_used		numberTable,
	application_free		numberTable,
	oracle_database_rawsize		numberTable,		-- Oracle DB's
	oracle_database_size		numberTable,
	oracle_database_used		numberTable,
	oracle_database_free		numberTable,
	local_filesystem_rawsize	numberTable,		-- Local Filesystems
	local_filesystem_size		numberTable,
	local_filesystem_used		numberTable,		
	local_filesystem_free		numberTable,
	nfs_exclusive_size		numberTable,		-- NFS exclusive
	nfs_exclusive_used		numberTable,		
	nfs_exclusive_free		numberTable,
	nfs_shared_size			numberTable,		-- NFS shared
	nfs_shared_used			numberTable,
	nfs_shared_free			numberTable,
	volumemanager_rawsize		numberTable,		-- VM
	volumemanager_size		numberTable,
	volumemanager_used		numberTable,
	volumemanager_free		numberTable,
	swraid_rawsize			numberTable,		-- swraid
	swraid_size			numberTable,
	swraid_used			numberTable,
	swraid_free			numberTable,
	disk_backup_rawsize		numberTable,		-- Disk Backup
	disk_backup_size		numberTable,	
	disk_backup_used		numberTable,
	disk_backup_free		numberTable,
	disk_rawsize			numberTable,		-- Disk
	disk_size			numberTable,
	disk_used			numberTable,	
	disk_free			numberTable,		
	rawsize				numberTable,		-- Disk + NFS storage
	sizeb				numberTable,
	used				numberTable,
	free				numberTable,
	vendor_emc_size			numberTable,		-- Storage by vendor
	vendor_emc_rawsize		numberTable,
	vendor_sun_size			numberTable,
	vendor_sun_rawsize		numberTable,
	vendor_hp_size			numberTable,	
	vendor_hp_rawsize		numberTable,
	vendor_hitachi_size		numberTable,
	vendor_hitachi_rawsize		numberTable,
	vendor_others_size		numberTable,
	vendor_others_rawsize		numberTable,
	vendor_nfs_netapp_size		numberTable,
	vendor_nfs_emc_size		numberTable,
	vendor_nfs_sun_size		numberTable,	
	vendor_nfs_others_size		numberTable
	);

	l_1		summary_rec;
	

BEGIN

--	INSERT INTO stormon_temp_results
	SELECT   /*+ DRIVING_SITE(a)*/ 
	null,
	a.name,
	null,
	null,	
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,	
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null
BULK COLLECT INTO 
	l_1.rowcount,
	l_1.name,
	l_1.id,
	l_1.type,
	l_1.timestamp,
	l_1.collection_timestamp,
	l_1.hostcount,
	l_1.actual_targets,
	l_1.issues,
	l_1.notcollected,
	l_1.warnings,
	l_1.summaryflag,
	l_1.application_rawsize,
	l_1.application_size,
	l_1.application_used,
	l_1.application_free,
	l_1.oracle_database_rawsize,
	l_1.oracle_database_size,
	l_1.oracle_database_used,
	l_1.oracle_database_free,
	l_1.local_filesystem_rawsize,
	l_1.local_filesystem_size,
	l_1.local_filesystem_used,
	l_1.local_filesystem_free,
	l_1.nfs_exclusive_size,
	l_1.nfs_exclusive_used,
	l_1.nfs_exclusive_free,
	l_1.nfs_shared_size,
	l_1.nfs_shared_used,
	l_1.nfs_shared_free,
	l_1.volumemanager_rawsize,
	l_1.volumemanager_size,
	l_1.volumemanager_used,
	l_1.volumemanager_free,
	l_1.swraid_rawsize,
	l_1.swraid_size,
	l_1.swraid_used,
	l_1.swraid_free,
	l_1.disk_backup_rawsize,
	l_1.disk_backup_size,
	l_1.disk_backup_used,
	l_1.disk_backup_free,
	l_1.disk_rawsize,
	l_1.disk_size,
	l_1.disk_used,
	l_1.disk_free,
	l_1.rawsize,
	l_1.sizeb,
	l_1.used,
	l_1.free,
	l_1.vendor_emc_size,
	l_1.vendor_emc_rawsize,
	l_1.vendor_sun_size,
	l_1.vendor_sun_rawsize,
	l_1.vendor_hp_size,
	l_1.vendor_hp_rawsize,
	l_1.vendor_hitachi_size,
	l_1.vendor_hitachi_rawsize,
	l_1.vendor_others_size,
	l_1.vendor_others_rawsize,
	l_1.vendor_nfs_netapp_size,
	l_1.vendor_nfs_emc_size,
	l_1.vendor_nfs_sun_size,
	l_1.vendor_nfs_others_size
FROM ( 
	SELECT /*+ DRIVING_SITE(a)*/ name
	FROM storage_summaryObject_view a, 
	      (
		SELECT /*+ DRIVING_SITE(a)*/ target_id id FROM 
		mgmt_targets_view a WHERE ( LOWER(a.target_name) LIKE '%oraclebol%' ) 
		UNION 
		SELECT /*+ DRIVING_SITE(a)*/ a.id 
		FROM stormon_group_table a 
		WHERE type = 'SHARED_GROUP' 
		AND NOT EXISTS ( 
			SELECT /*+ DRIVING_SITE(b)*/ 1 
			FROM 
				(
				SELECT /*+ DRIVING_SITE(a)*/ target_id 
				FROM 	mgmt_targets_view a 
				MINUS 
				SELECT /*+ DRIVING_SITE(a)*/ target_id id 
				FROM mgmt_targets_view a 
				WHERE ( LOWER(a.target_name) LIKE '%oraclebol%' ) 
				) c, 
				stormon_host_groups b 
			WHERE b.group_id = a.id 
			AND b.target_id = c.target_id 
		) 
	) b 
	WHERE a.id = b.id 
	AND a.summaryFlag = 'Y' 
) a;

	IF l_1.name IS NOT NULL AND l_1.name.EXISTS(1) THEN

		FORALL i IN l_1.name.FIRST..l_1.name.LAST
			INSERT INTO stormon_temp_results
			VALUES(
	l_1.rowcount(i),
	l_1.name(i),
	l_1.id(i),
	l_1.type(i),
	l_1.timestamp(i),
	l_1.collection_timestamp(i),
	l_1.hostcount(i),
	l_1.actual_targets(i),
	l_1.issues(i),
	l_1.notcollected(i),
	l_1.warnings(i),
	l_1.summaryflag(i),
	l_1.application_rawsize(i),
	l_1.application_size(i),
	l_1.application_used(i),
	l_1.application_free(i),
	l_1.oracle_database_rawsize(i),
	l_1.oracle_database_size(i),
	l_1.oracle_database_used(i),
	l_1.oracle_database_free(i),
	l_1.local_filesystem_rawsize(i),
	l_1.local_filesystem_size(i),
	l_1.local_filesystem_used(i),
	l_1.local_filesystem_free(i),
	l_1.nfs_exclusive_size(i),
	l_1.nfs_exclusive_used(i),
	l_1.nfs_exclusive_free(i),
	l_1.nfs_shared_size(i),
	l_1.nfs_shared_used(i),
	l_1.nfs_shared_free(i),
	l_1.volumemanager_rawsize(i),
	l_1.volumemanager_size(i),
	l_1.volumemanager_used(i),
	l_1.volumemanager_free(i),
	l_1.swraid_rawsize(i),
	l_1.swraid_size(i),
	l_1.swraid_used(i),
	l_1.swraid_free(i),
	l_1.disk_backup_rawsize(i),
	l_1.disk_backup_size(i),
	l_1.disk_backup_used(i),
	l_1.disk_backup_free(i),
	l_1.disk_rawsize(i),
	l_1.disk_size(i),
	l_1.disk_used(i),
	l_1.disk_free(i),
	l_1.rawsize(i),
	l_1.sizeb(i),
	l_1.used(i),
	l_1.free(i),
	l_1.vendor_emc_size(i),
	l_1.vendor_emc_rawsize(i),
	l_1.vendor_sun_size(i),
	l_1.vendor_sun_rawsize(i),
	l_1.vendor_hp_size(i),
	l_1.vendor_hp_rawsize(i),
	l_1.vendor_hitachi_size(i),
	l_1.vendor_hitachi_rawsize(i),
	l_1.vendor_others_size(i),
	l_1.vendor_others_rawsize(i),
	l_1.vendor_nfs_netapp_size(i),
	l_1.vendor_nfs_emc_size(i),
	l_1.vendor_nfs_sun_size(i),
	l_1.vendor_nfs_others_size(i)
	);			

	END IF;
	
END;
/


---------------------


DECLARE


	l_1		summaryObject;
	

BEGIN

	DELETE FROM stormon_temp_results;

	SELECT   /*+ DRIVING_SITE(a)*/ 
	null,
	a.name,
	null,
	null,	
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,	
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null
INTO 
	l_1.rowcount,
	l_1.name,
	l_1.id,
	l_1.type,
	l_1.timestamp,
	l_1.collection_timestamp,
	l_1.hostcount,
	l_1.actual_targets,
	l_1.issues,
	l_1.notcollected,
	l_1.warnings,
	l_1.summaryflag,
	l_1.application_rawsize,
	l_1.application_size,
	l_1.application_used,
	l_1.application_free,
	l_1.oracle_database_rawsize,
	l_1.oracle_database_size,
	l_1.oracle_database_used,
	l_1.oracle_database_free,
	l_1.local_filesystem_rawsize,
	l_1.local_filesystem_size,
	l_1.local_filesystem_used,
	l_1.local_filesystem_free,
	l_1.nfs_exclusive_size,
	l_1.nfs_exclusive_used,
	l_1.nfs_exclusive_free,
	l_1.nfs_shared_size,
	l_1.nfs_shared_used,
	l_1.nfs_shared_free,
	l_1.volumemanager_rawsize,
	l_1.volumemanager_size,
	l_1.volumemanager_used,
	l_1.volumemanager_free,
	l_1.swraid_rawsize,
	l_1.swraid_size,
	l_1.swraid_used,
	l_1.swraid_free,
	l_1.disk_backup_rawsize,
	l_1.disk_backup_size,
	l_1.disk_backup_used,
	l_1.disk_backup_free,
	l_1.disk_rawsize,
	l_1.disk_size,
	l_1.disk_used,
	l_1.disk_free,
	l_1.rawsize,
	l_1.sizeb,
	l_1.used,
	l_1.free,
	l_1.vendor_emc_size,
	l_1.vendor_emc_rawsize,
	l_1.vendor_sun_size,
	l_1.vendor_sun_rawsize,
	l_1.vendor_hp_size,
	l_1.vendor_hp_rawsize,
	l_1.vendor_hitachi_size,
	l_1.vendor_hitachi_rawsize,
	l_1.vendor_others_size,
	l_1.vendor_others_rawsize,
	l_1.vendor_nfs_netapp_size,
	l_1.vendor_nfs_emc_size,
	l_1.vendor_nfs_sun_size,
	l_1.vendor_nfs_others_size
FROM ( 
	SELECT /*+ DRIVING_SITE(a)*/ name
	FROM storage_summaryObject_view a, 
	      (
		SELECT /*+ DRIVING_SITE(a)*/ target_id id FROM 
		mgmt_targets_view a WHERE ( LOWER(a.target_name) LIKE '%oraclebol%' ) 
		UNION 
		SELECT /*+ DRIVING_SITE(a)*/ a.id 
		FROM stormon_group_table a 
		WHERE type = 'SHARED_GROUP' 
		AND NOT EXISTS ( 
			SELECT /*+ DRIVING_SITE(b)*/ 1 
			FROM 
				(
				SELECT /*+ DRIVING_SITE(a)*/ target_id 
				FROM 	mgmt_targets_view a 
				MINUS 
				SELECT /*+ DRIVING_SITE(a)*/ target_id id 
				FROM mgmt_targets_view a 
				WHERE ( LOWER(a.target_name) LIKE '%oraclebol%' ) 
				) c, 
				stormon_host_groups b 
			WHERE b.group_id = a.id 
			AND b.target_id = c.target_id 
		) 
	) b 
	WHERE a.id = b.id 
	AND a.summaryFlag = 'Y' 
) a
WHERE ROWNUM=1;


	INSERT INTO stormon_temp_results
	VALUES(
	l_1.rowcount,
	l_1.name,
	l_1.id,
	l_1.type,
	l_1.timestamp,
	l_1.collection_timestamp,
	l_1.hostcount,
	l_1.actual_targets,
	l_1.issues,
	l_1.notcollected,
	l_1.warnings,
	l_1.summaryflag,
	l_1.application_rawsize,
	l_1.application_size,
	l_1.application_used,
	l_1.application_free,
	l_1.oracle_database_rawsize,
	l_1.oracle_database_size,
	l_1.oracle_database_used,
	l_1.oracle_database_free,
	l_1.local_filesystem_rawsize,
	l_1.local_filesystem_size,
	l_1.local_filesystem_used,
	l_1.local_filesystem_free,
	l_1.nfs_exclusive_size,
	l_1.nfs_exclusive_used,
	l_1.nfs_exclusive_free,
	l_1.nfs_shared_size,
	l_1.nfs_shared_used,
	l_1.nfs_shared_free,
	l_1.volumemanager_rawsize,
	l_1.volumemanager_size,
	l_1.volumemanager_used,
	l_1.volumemanager_free,
	l_1.swraid_rawsize,
	l_1.swraid_size,
	l_1.swraid_used,
	l_1.swraid_free,
	l_1.disk_backup_rawsize,
	l_1.disk_backup_size,
	l_1.disk_backup_used,
	l_1.disk_backup_free,
	l_1.disk_rawsize,
	l_1.disk_size,
	l_1.disk_used,
	l_1.disk_free,
	l_1.rawsize,
	l_1.sizeb,
	l_1.used,
	l_1.free,
	l_1.vendor_emc_size,
	l_1.vendor_emc_rawsize,
	l_1.vendor_sun_size,
	l_1.vendor_sun_rawsize,
	l_1.vendor_hp_size,
	l_1.vendor_hp_rawsize,
	l_1.vendor_hitachi_size,
	l_1.vendor_hitachi_rawsize,
	l_1.vendor_others_size,
	l_1.vendor_others_rawsize,
	l_1.vendor_nfs_netapp_size,
	l_1.vendor_nfs_emc_size,
	l_1.vendor_nfs_sun_size,
	l_1.vendor_nfs_others_size
	);			

END;
/


DECLARE
        type s is record ( k storage_summaryobject_view.id%TYPE);
        t storage_summaryobject_view%rowtype;
        type j is table of storage_summaryobject_view%rowtype;
        l_j     j;
BEGIN
        SELECT  *
        INTO    t
        FROM    storage_summaryObject_view
        WHERE   name like '%gitmon%'
	AND ROWNUM = 1;
END;
/


DECLARE
       
        t storage_summaryobject_view%rowtype;
        type j is table of storage_summaryobject_view%rowtype;
        l_j     j;
BEGIN
        SELECT  *
        BULK COLLECT INTO l_j
        FROM    storage_summaryObject_view
        WHERE   name like '%gitmon%'
	AND	ROWNUM = 1;
END;
/


DECLARE

	TYPE intTable IS TABLE OF INTEGER;	

	TYPE summary_table IS RECORD (
	name				stringTable,	
	id				stringTable,
	type				stringTable,	
	timestamp			dateTable,	-- Timestamp for the summaryObject
	collection_timestamp		dateTable,	-- Max collection timestamp of the metrics of this summaryobject
	hostcount			intTable,	-- No of targets in this summary
	actual_targets			intTable,	-- No of targets counted in this summary
	issues				intTable,	-- No of issues , or hosts which failed summary computation
	warnings			intTable,	-- No. od warnings , or No. of hosts with warnings in a group summary
	summaryflag			stringTable,	-- Flag indicating if this summary is a place holder Y/N
	application_rawsize		numberTable,		-- Non Oracle DB applications
	application_size		numberTable,
	application_used		numberTable,
	application_free		numberTable,
	oracle_database_rawsize		numberTable,		-- Oracle DB's
	oracle_database_size		numberTable,
	oracle_database_used		numberTable,
	oracle_database_free		numberTable,
	local_filesystem_rawsize	numberTable,		-- Local Filesystems
	local_filesystem_size		numberTable,
	local_filesystem_used		numberTable,		
	local_filesystem_free		numberTable,
	nfs_exclusive_size		numberTable,		-- NFS exclusive
	nfs_exclusive_used		numberTable,		
	nfs_exclusive_free		numberTable,
	nfs_shared_size			numberTable,		-- NFS shared
	nfs_shared_used			numberTable,
	nfs_shared_free			numberTable,
	volumemanager_rawsize		numberTable,		-- VM
	volumemanager_size		numberTable,
	volumemanager_used		numberTable,
	volumemanager_free		numberTable,
	swraid_rawsize			numberTable,		-- swraid
	swraid_size			numberTable,
	swraid_used			numberTable,
	swraid_free			numberTable,
	disk_backup_rawsize		numberTable,		-- Disk Backup
	disk_backup_size		numberTable,	
	disk_backup_used		numberTable,
	disk_backup_free		numberTable,
	disk_rawsize			numberTable,		-- Disk
	disk_size			numberTable,
	disk_used			numberTable,	
	disk_free			numberTable,		
	rawsize				numberTable,		-- Disk + NFS storage
	sizeb				numberTable,
	used				numberTable,
	free				numberTable,
	vendor_emc_size			numberTable,		-- Storage by vendor
	vendor_emc_rawsize		numberTable,
	vendor_sun_size			numberTable,
	vendor_sun_rawsize		numberTable,
	vendor_hp_size			numberTable,	
	vendor_hp_rawsize		numberTable,
	vendor_hitachi_size		numberTable,
	vendor_hitachi_rawsize		numberTable,
	vendor_others_size		numberTable,
	vendor_others_rawsize		numberTable,
	vendor_nfs_netapp_size		numberTable,
	vendor_nfs_emc_size		numberTable,
	vendor_nfs_sun_size		numberTable,	
	vendor_nfs_others_size		numberTable
	);

	l_all_summaries		 	summary_table;

BEGIN

EXECUTE IMMEDIATE
'SELECT	/*+ DRIVING_SITE(a)*/a.name,
	a.id,
	a.type,		-- a.type,
	a.timestamp		,			-- timestamp
	a.collection_timestamp	,			-- collection_timestamp
	a.hostcount	,			-- hostcount
	a.actual_targets	,	-- actual_targets
	a.issues		,	-- issues
	a.warnings	,		-- warnings
	a.summaryFlag     	,		-- summaryFlag
	a.application_rawsize	,
	a.application_size	,
	a.application_used	,
	a.application_free	,
	a.oracle_database_rawsize	,
	a.oracle_database_size	,
	a.oracle_database_used	,
	a.oracle_database_free	,
	a.local_filesystem_rawsize,
	a.local_filesystem_size	,
	a.local_filesystem_used	,
	a.local_filesystem_free	,
	a.nfs_exclusive_size	,
	a.nfs_exclusive_used	,
	a.nfs_exclusive_free	,
	a.nfs_shared_size	,
	a.nfs_shared_used	,
	a.nfs_shared_free	,
	a.volumemanager_rawsize	,
	a.volumemanager_size	,
	a.volumemanager_used	,
	a.volumemanager_free	,
	a.swraid_rawsize	,
	a.swraid_size	,
	a.swraid_used	,
	a.swraid_free	,
	a.disk_backup_rawsize	,
	a.disk_backup_size	,
	a.disk_backup_used	,
	a.disk_backup_free	,
	a.disk_rawsize	,
	a.disk_size	,
	a.disk_used	,
	a.disk_free	,
	a.rawsize		,
	a.sizeb		,
	a.used		,
	a.free		,
	a.vendor_emc_size	,
	a.vendor_emc_rawsize	,
	a.vendor_sun_size	,
	a.vendor_sun_rawsize	,
	a.vendor_hp_size	,
	a.vendor_hp_rawsize	,
	a.vendor_hitachi_size	,
	a.vendor_hitachi_rawsize	,
	a.vendor_others_size	,
	a.vendor_others_rawsize	,
	a.vendor_nfs_netapp_size	,
	a.vendor_nfs_emc_size	,
	a.vendor_nfs_sun_size	,
	a.vendor_nfs_others_size
FROM	storage_summaryObject_view a, 
	(SELECT   /*+ DRIVING_SITE(a)*/ b.target_id
		id
	FROM	stormon_host_groups b,
		stormon_group_table a
	WHERE	b.group_id = a.id
	AND	a.type = ''REPORTING_ALL''
	AND	 1 = 1 
	) b
WHERE	a.id = b.id 
ORDER BY 
SIZEB DESC' BULK COLLECT INTO 		
			l_all_summaries.name,
			l_all_summaries.id,
			l_all_summaries.type,
			l_all_summaries.timestamp,
			l_all_summaries.collection_timestamp,
			l_all_summaries.hostcount,
			l_all_summaries.actual_targets,
			l_all_summaries.issues,
			l_all_summaries.warnings,
			l_all_summaries.summaryflag,
			l_all_summaries.application_rawsize,
			l_all_summaries.application_size,
			l_all_summaries.application_used,
			l_all_summaries.application_free,
			l_all_summaries.oracle_database_rawsize,
			l_all_summaries.oracle_database_size,
			l_all_summaries.oracle_database_used,
			l_all_summaries.oracle_database_free,
			l_all_summaries.local_filesystem_rawsize,
			l_all_summaries.local_filesystem_size,
			l_all_summaries.local_filesystem_used,
			l_all_summaries.local_filesystem_free,
			l_all_summaries.nfs_exclusive_size,
			l_all_summaries.nfs_exclusive_used,
			l_all_summaries.nfs_exclusive_free,
			l_all_summaries.nfs_shared_size,
			l_all_summaries.nfs_shared_used,
			l_all_summaries.nfs_shared_free,
			l_all_summaries.volumemanager_rawsize,
			l_all_summaries.volumemanager_size,
			l_all_summaries.volumemanager_used,
			l_all_summaries.volumemanager_free,
			l_all_summaries.swraid_rawsize,
			l_all_summaries.swraid_size,
			l_all_summaries.swraid_used,
			l_all_summaries.swraid_free,
			l_all_summaries.disk_backup_rawsize,
			l_all_summaries.disk_backup_size,
			l_all_summaries.disk_backup_used,
			l_all_summaries.disk_backup_free,
			l_all_summaries.disk_rawsize,
			l_all_summaries.disk_size,
			l_all_summaries.disk_used,
			l_all_summaries.disk_free,
			l_all_summaries.rawsize,
			l_all_summaries.sizeb,
			l_all_summaries.used,
			l_all_summaries.free,
			l_all_summaries.vendor_emc_size,
			l_all_summaries.vendor_emc_rawsize,
			l_all_summaries.vendor_sun_size,
			l_all_summaries.vendor_sun_rawsize,
			l_all_summaries.vendor_hp_size,
			l_all_summaries.vendor_hp_rawsize,
			l_all_summaries.vendor_hitachi_size,
			l_all_summaries.vendor_hitachi_rawsize,
			l_all_summaries.vendor_others_size,
			l_all_summaries.vendor_others_rawsize,
			l_all_summaries.vendor_nfs_netapp_size,
			l_all_summaries.vendor_nfs_emc_size,
			l_all_summaries.vendor_nfs_sun_size,
			l_all_summaries.vendor_nfs_others_size;

END;
/
	
----------------------------------------
-- ONLY THE CURSOR

DECLARE


	TYPE intTable IS TABLE OF INTEGER;	

	TYPE summary_table IS RECORD (
	name				stringTable,	
	id				stringTable,
	type				stringTable,	
	timestamp			dateTable,	-- Timestamp for the summaryObject
	collection_timestamp		dateTable,	-- Max collection timestamp of the metrics of this summaryobject
	hostcount			intTable,	-- No of targets in this summary
	actual_targets			intTable,	-- No of targets counted in this summary
	issues				intTable,	-- No of issues , or hosts which failed summary computation
	warnings			intTable,	-- No. od warnings , or No. of hosts with warnings in a group summary
	summaryflag			stringTable,	-- Flag indicating if this summary is a place holder Y/N
	application_rawsize		numberTable,		-- Non Oracle DB applications
	application_size		numberTable,
	application_used		numberTable,
	application_free		numberTable,
	oracle_database_rawsize		numberTable,		-- Oracle DB's
	oracle_database_size		numberTable,
	oracle_database_used		numberTable,
	oracle_database_free		numberTable,
	local_filesystem_rawsize	numberTable,		-- Local Filesystems
	local_filesystem_size		numberTable,
	local_filesystem_used		numberTable,		
	local_filesystem_free		numberTable,
	nfs_exclusive_size		numberTable,		-- NFS exclusive
	nfs_exclusive_used		numberTable,		
	nfs_exclusive_free		numberTable,
	nfs_shared_size			numberTable,		-- NFS shared
	nfs_shared_used			numberTable,
	nfs_shared_free			numberTable,
	volumemanager_rawsize		numberTable,		-- VM
	volumemanager_size		numberTable,
	volumemanager_used		numberTable,
	volumemanager_free		numberTable,
	swraid_rawsize			numberTable,		-- swraid
	swraid_size			numberTable,
	swraid_used			numberTable,
	swraid_free			numberTable,
	disk_backup_rawsize		numberTable,		-- Disk Backup
	disk_backup_size		numberTable,	
	disk_backup_used		numberTable,
	disk_backup_free		numberTable,
	disk_rawsize			numberTable,		-- Disk
	disk_size			numberTable,
	disk_used			numberTable,	
	disk_free			numberTable,		
	rawsize				numberTable,		-- Disk + NFS storage
	sizeb				numberTable,
	used				numberTable,
	free				numberTable,
	vendor_emc_size			numberTable,		-- Storage by vendor
	vendor_emc_rawsize		numberTable,
	vendor_sun_size			numberTable,
	vendor_sun_rawsize		numberTable,
	vendor_hp_size			numberTable,	
	vendor_hp_rawsize		numberTable,
	vendor_hitachi_size		numberTable,
	vendor_hitachi_rawsize		numberTable,
	vendor_others_size		numberTable,
	vendor_others_rawsize		numberTable,
	vendor_nfs_netapp_size		numberTable,
	vendor_nfs_emc_size		numberTable,
	vendor_nfs_sun_size		numberTable,	
	vendor_nfs_others_size		numberTable
	);

	l_all_summaries		 	summary_table;

	l_cursor	sys_refcursor;

BEGIN

DELETE FROM stormon_temp_results;

OPEN l_cursor FOR 
'
SELECT /*+ DRIVING_SITE(a)*/ a.name,
						a.id,
						a.type,						-- a.type,
						a.timestamp		,			-- timestamp
						a.collection_timestamp	,			-- collection_timestamp
						a.hostcount		,			-- hostcount
						a.actual_targets		,		-- actual_targets
						a.issues			,		-- issues
						a.warnings		,			-- warnings
						a.summaryFlag     	,			-- summaryFlag
						a.application_rawsize	,
						a.application_size	,
						a.application_used	,
						a.application_free	,
						a.oracle_database_rawsize	,
						a.oracle_database_size	,
						a.oracle_database_used	,
						a.oracle_database_free	,
						a.local_filesystem_rawsize,
						a.local_filesystem_size	,
						a.local_filesystem_used	,
						a.local_filesystem_free	,
						a.nfs_exclusive_size	,
						a.nfs_exclusive_used	,
						a.nfs_exclusive_free	,
						a.nfs_shared_size		,
						a.nfs_shared_used		,
						a.nfs_shared_free		,
						a.volumemanager_rawsize	,
						a.volumemanager_size	,
						a.volumemanager_used	,
						a.volumemanager_free	,
						a.swraid_rawsize		,
						a.swraid_size		,
						a.swraid_used		,
						a.swraid_free		,
						a.disk_backup_rawsize	,
						a.disk_backup_size	,
						a.disk_backup_used	,
						a.disk_backup_free	,
						a.disk_rawsize		,
						a.disk_size		,
						a.disk_used		,
						a.disk_free		,
						a.rawsize			,
						a.sizeb			,
						a.used			,
						a.free			,
						a.vendor_emc_size		,
						a.vendor_emc_rawsize	,
						a.vendor_sun_size		,
						a.vendor_sun_rawsize	,
						a.vendor_hp_size		,
						a.vendor_hp_rawsize	,
						a.vendor_hitachi_size	,
						a.vendor_hitachi_rawsize	,
						a.vendor_others_size	,
						a.vendor_others_rawsize	,
						a.vendor_nfs_netapp_size	,
						a.vendor_nfs_emc_size	,
						a.vendor_nfs_sun_size	,
						a.vendor_nfs_others_size
FROM ( 
	SELECT /*+ DRIVING_SITE(a)*/ 
	 ''TOTAL''			name,						
					NULL				id,	
					''HOST''			type,
					SYSDATE				timestamp,		-- timestamp
					MAX(a.collection_timestamp)	collection_timestamp,	-- collection_timestamp
					NULL				hostcount,		-- hostcount
					NULL				actual_targets,		-- actual_targets
					NULL				issues,			-- issues
					NULL				notcollected,		-- not collected
					NULL				warnings,		-- warnings
					''N''     			summaryflag,		-- summaryFlag
					SUM(a.application_rawsize)	application_rawsize,
					SUM(a.application_size)		application_size,
					SUM(a.application_used)		application_used,
					SUM(a.application_free)		application_free,
					SUM(a.oracle_database_rawsize)	oracle_database_rawsize,
					SUM(a.oracle_database_size)	oracle_database_size,
					SUM(a.oracle_database_used)	oracle_database_used,
					SUM(a.oracle_database_free)	oracle_database_free,
					SUM(a.local_filesystem_rawsize)	local_filesystem_rawsize,
					SUM(a.local_filesystem_size)	local_filesystem_size,
					SUM(a.local_filesystem_used)	local_filesystem_used,
					SUM(a.local_filesystem_free)	local_filesystem_free,
					SUM(a.nfs_exclusive_size)	nfs_exclusive_size,
					SUM(a.nfs_exclusive_used)	nfs_exclusive_used,
					SUM(a.nfs_exclusive_free)	nfs_exclusive_free,
					SUM(a.nfs_shared_size	)	nfs_shared_size,
					SUM(a.nfs_shared_used	)	nfs_shared_used,
					SUM(a.nfs_shared_free	)	nfs_shared_free,
					SUM(a.volumemanager_rawsize)	volumemanager_rawsize,
					SUM(a.volumemanager_size)	volumemanager_size,
					SUM(a.volumemanager_used)	volumemanager_used,
					SUM(a.volumemanager_free)	volumemanager_free,
					SUM(a.swraid_rawsize	)	swraid_rawsize,
					SUM(a.swraid_size	)	swraid_size,
					SUM(a.swraid_used	)	swraid_used,
					SUM(a.swraid_free	)	swraid_free,
					SUM(a.disk_backup_rawsize)	disk_backup_rawsize,
					SUM(a.disk_backup_size)		disk_backup_size,
					SUM(a.disk_backup_used)		disk_backup_used,
					SUM(a.disk_backup_free)		disk_backup_free,
					SUM(a.disk_rawsize	)	disk_rawsize,
					SUM(a.disk_size	)		disk_size,
					SUM(a.disk_used	)		disk_used,
					SUM(a.disk_free	)		disk_free,
					SUM(a.rawsize		)	rawsize,
					SUM(a.sizeb		)	sizeb,
					SUM(a.used		)	used,
					SUM(a.free		)	free,
					SUM(a.vendor_emc_size	)	vendor_emc_size,
					SUM(a.vendor_emc_rawsize)	vendor_emc_rawsize,
					SUM(a.vendor_sun_size	)	vendor_sun_size,
					SUM(a.vendor_sun_rawsize)	vendor_sun_rawsize,
					SUM(a.vendor_hp_size	)	vendor_hp_size,
					SUM(a.vendor_hp_rawsize)	vendor_hp_rawsize,
					SUM(a.vendor_hitachi_size)	vendor_hitachi_size,
					SUM(a.vendor_hitachi_rawsize)	vendor_hitachi_rawsize,
					SUM(a.vendor_others_size)	vendor_others_size,
					SUM(a.vendor_others_rawsize)	vendor_others_rawsize,
					SUM(a.vendor_nfs_netapp_size)	vendor_nfs_netapp_size,
					SUM(a.vendor_nfs_emc_size)	vendor_nfs_emc_size,
					SUM(a.vendor_nfs_sun_size)	vendor_nfs_sun_size,
					SUM(a.vendor_nfs_others_size)	vendor_nfs_others_size				
FROM storage_summaryObject_view a, 
	(
		SELECT /*+ DRIVING_SITE(a)*/ target_id id 
		FROM	mgmt_targets_view a 
		WHERE	( LOWER(a.target_name) LIKE ''%gitmon%'' ) 
		UNION 
		SELECT /*+ DRIVING_SITE(a)*/ a.id 
		FROM	stormon_group_table a 
		WHERE	type = ''SHARED_GROUP'' 
		AND	NOT EXISTS ( 
				SELECT /*+ DRIVING_SITE(b)*/ 1 
				FROM ( 
					SELECT /*+ DRIVING_SITE(a)*/ target_id 
					FROM	mgmt_targets_view a 
					MINUS 
					SELECT /*+ DRIVING_SITE(a)*/ target_id id 
					FROM	mgmt_targets_view a 
					WHERE ( LOWER(a.target_name) LIKE ''%gitmon%'' ) 
				) c, 
				stormon_host_groups b 
				WHERE b.group_id = a.id 
				AND b.target_id = c.target_id 
		) 
	) b 
 WHERE a.id = b.id AND a.summaryFlag = ''Y'' 
) a 
';

FETCH l_cursor BULK COLLECT INTO 			
			l_all_summaries.name,
			l_all_summaries.id,
			l_all_summaries.type,
			l_all_summaries.timestamp,
			l_all_summaries.collection_timestamp,
			l_all_summaries.hostcount,
			l_all_summaries.actual_targets,
			l_all_summaries.issues,
			l_all_summaries.warnings,
			l_all_summaries.summaryflag,
			l_all_summaries.application_rawsize,
			l_all_summaries.application_size,
			l_all_summaries.application_used,
			l_all_summaries.application_free,
			l_all_summaries.oracle_database_rawsize,
			l_all_summaries.oracle_database_size,
			l_all_summaries.oracle_database_used,
			l_all_summaries.oracle_database_free,
			l_all_summaries.local_filesystem_rawsize,
			l_all_summaries.local_filesystem_size,
			l_all_summaries.local_filesystem_used,
			l_all_summaries.local_filesystem_free,
			l_all_summaries.nfs_exclusive_size,
			l_all_summaries.nfs_exclusive_used,
			l_all_summaries.nfs_exclusive_free,
			l_all_summaries.nfs_shared_size,
			l_all_summaries.nfs_shared_used,
			l_all_summaries.nfs_shared_free,
			l_all_summaries.volumemanager_rawsize,
			l_all_summaries.volumemanager_size,
			l_all_summaries.volumemanager_used,
			l_all_summaries.volumemanager_free,
			l_all_summaries.swraid_rawsize,
			l_all_summaries.swraid_size,
			l_all_summaries.swraid_used,
			l_all_summaries.swraid_free,
			l_all_summaries.disk_backup_rawsize,
			l_all_summaries.disk_backup_size,
			l_all_summaries.disk_backup_used,
			l_all_summaries.disk_backup_free,
			l_all_summaries.disk_rawsize,
			l_all_summaries.disk_size,
			l_all_summaries.disk_used,
			l_all_summaries.disk_free,
			l_all_summaries.rawsize,
			l_all_summaries.sizeb,
			l_all_summaries.used,
			l_all_summaries.free,
			l_all_summaries.vendor_emc_size,
			l_all_summaries.vendor_emc_rawsize,
			l_all_summaries.vendor_sun_size,
			l_all_summaries.vendor_sun_rawsize,
			l_all_summaries.vendor_hp_size,
			l_all_summaries.vendor_hp_rawsize,
			l_all_summaries.vendor_hitachi_size,
			l_all_summaries.vendor_hitachi_rawsize,
			l_all_summaries.vendor_others_size,
			l_all_summaries.vendor_others_rawsize,
			l_all_summaries.vendor_nfs_netapp_size,
			l_all_summaries.vendor_nfs_emc_size,
			l_all_summaries.vendor_nfs_sun_size,
			l_all_summaries.vendor_nfs_others_size;


	IF l_all_summaries.name IS NULL OR NOT l_all_summaries.name.EXISTS(1) THEN

		RETURN;
		
	END IF;


	FORALL i IN l_all_summaries.name.FIRST..l_all_summaries.name.LAST
	INSERT INTO stormon_temp_results 
		VALUES(
			'DETAIL',
			l_all_summaries.name(i),
			l_all_summaries.id(i),
			l_all_summaries.type(i),
			l_all_summaries.timestamp(i),
			l_all_summaries.collection_timestamp(i),
			l_all_summaries.hostcount(i),
			l_all_summaries.actual_targets(i),
			l_all_summaries.issues(i),
			l_all_summaries.hostcount(i)-(l_all_summaries.actual_targets(i)+l_all_summaries.issues(i)),
			l_all_summaries.warnings(i),
			l_all_summaries.summaryflag(i),
			l_all_summaries.application_rawsize(i),
			l_all_summaries.application_size(i),
			l_all_summaries.application_used(i),
			l_all_summaries.application_free(i),
			l_all_summaries.oracle_database_rawsize(i),
			l_all_summaries.oracle_database_size(i),
			l_all_summaries.oracle_database_used(i),
			l_all_summaries.oracle_database_free(i),
			l_all_summaries.local_filesystem_rawsize(i),
			l_all_summaries.local_filesystem_size(i),
			l_all_summaries.local_filesystem_used(i),
			l_all_summaries.local_filesystem_free(i),
			l_all_summaries.nfs_exclusive_size(i),
			l_all_summaries.nfs_exclusive_used(i),
			l_all_summaries.nfs_exclusive_free(i),
			l_all_summaries.nfs_shared_size(i),
			l_all_summaries.nfs_shared_used(i),
			l_all_summaries.nfs_shared_free(i),
			l_all_summaries.volumemanager_rawsize(i),
			l_all_summaries.volumemanager_size(i),
			l_all_summaries.volumemanager_used(i),
			l_all_summaries.volumemanager_free(i),
			l_all_summaries.swraid_rawsize(i),
			l_all_summaries.swraid_size(i),
			l_all_summaries.swraid_used(i),
			l_all_summaries.swraid_free(i),
			l_all_summaries.disk_backup_rawsize(i),
			l_all_summaries.disk_backup_size(i),
			l_all_summaries.disk_backup_used(i),
			l_all_summaries.disk_backup_free(i),
			l_all_summaries.disk_rawsize(i),
			l_all_summaries.disk_size(i),
			l_all_summaries.disk_used(i),
			l_all_summaries.disk_free(i),
			l_all_summaries.rawsize(i),
			l_all_summaries.sizeb(i),
			l_all_summaries.used(i),
			l_all_summaries.free(i),
			l_all_summaries.vendor_emc_size(i),
			l_all_summaries.vendor_emc_rawsize(i),
			l_all_summaries.vendor_sun_size(i),
			l_all_summaries.vendor_sun_rawsize(i),
			l_all_summaries.vendor_hp_size(i),
			l_all_summaries.vendor_hp_rawsize(i),
			l_all_summaries.vendor_hitachi_size(i),
			l_all_summaries.vendor_hitachi_rawsize(i),
			l_all_summaries.vendor_others_size(i),
			l_all_summaries.vendor_others_rawsize(i),
			l_all_summaries.vendor_nfs_netapp_size(i),
			l_all_summaries.vendor_nfs_emc_size(i),
			l_all_summaries.vendor_nfs_sun_size(i),
			l_all_summaries.vendor_nfs_others_size(i)
		);

END;
/
	
---------------------------------------------------
-- executing the ui directly from sql

DECLARE
k       WWPRO_API_PROVIDER.portlet_runtime_record;
BEGIN
/*        STORAGE.CLASSICAL_DRILL_DOWN(
		k,
		'MAIN_TAB_DATACENTER',
		'FALSE',
		'ALL',
		'REPORTING_DATACENTER',
		'PIE',
		'REPORTING_DATACENTER',
		'HOST_DETAILS',
		'ALL_HOSTS');

*/
        STORAGE.CLASSICAL_DRILL_DOWN(
		k,
		'MAIN_TAB_HOSTLOOKUP',
		'TRUE',
		'gitmon',
		'HOST',
		'PIE',
		'HOST',
		'SUMMARY',
		'ALL_HOSTS');

END;
/

-- Multiply rows in table 2 raised to 7 times ( 128 times)
BEGIN
	FOR I in 1..7 loop
		INSERT INTO stormon_temp_results
		SELECT * FROM stormon_temp_results;
	END LOOP;
END;
/

SELECT COUNT(*) FROM stormon_temp_results
/
SELECT NAME, SUM(sizeb)/COUNT(*) FROM stormon_temp_results GROUP BY name
/
SELECT NAME FROM stormon_temp_results WHERE NAME NOT LIKE '%oraclebol.com%'
/
SELECT	DISTINCT b.name, a.NAME 
FROM	stormon_temp_results a, stormon_group_table b, stormon_host_groups c
WHERE	a.id = c.target_id
AND	a.type = 'HOST'
AND	b.id = c.group_id
AND	b.name = 'ADC'
/


----------------------- Temporary tables --------------------------------------
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

------------------------ Shared tables ---------------------------------------

DROP TABLE stormon_temp_shared_app
/
DROP TABLE stormon_temp_shared_fs
/
DROP TABLE stormon_temp_shared_volume
/
DROP TABLE stormon_temp_shared_swraid
/
DROP TABLE stormon_temp_shared_disk
/

-------Combination shared tables -----------------------------

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


------------------------  Temporary Tables -------------------------------------

CREATE GLOBAL TEMPORARY TABLE stormon_temp_disk (
	rowcount		INTEGER,	
	target_id		VARCHAR2(256), 	 /* is RAW(16) in git3       */
	targetname		VARCHAR2(256),	-- Target name
	keyvalue		VARCHAR2(256), 	/* is varchar2(256) in git3 */
	collection_timestamp	DATE,
	rawsizeb		NUMBER(16),
	sizeb			NUMBER(16),
	usedb			NUMBER(16),
	freeb			NUMBER(16),
	storagevendor		VARCHAR2(100),
	storageproduct		VARCHAR2(100),
	storageconfig		VARCHAR2(256),
 	type			VARCHAR2(50),	-- DISK,SLICE,SUBDISK
	filetype		VARCHAR2(50),	-- BLOCK OR CHARACTER
	linkinode		VARCHAR2(100),	
	diskkey			VARCHAR2(256),
	path			VARCHAR2(256),	-- OS Path
	status			VARCHAR2(100),	-- Formatted or unformatted,OFFLINE
	parent			VARCHAR2(256),	-- SWRAID parent
	backup			VARCHAR2(1),	-- Y/N flag for backup elements
	freetype		VARCHAR2(50)	
)
ON COMMIT PRESERVE ROWS
/
-- Index on disk key ?

CREATE GLOBAL TEMPORARY TABLE stormon_temp_swraid (
	rowcount		INTEGER,	
	target_id		VARCHAR2(256), 	 /* is RAW(16) in git3       */
	targetname		VARCHAR2(256),	-- Target name
	keyvalue		VARCHAR2(256), 	/* is varchar2(256) in git3 */
	collection_timestamp	DATE,
	rawsizeb		NUMBER(16),
	sizeb			NUMBER(16),
	usedb			NUMBER(16),
	freeb			NUMBER(16),
	storagevendor		VARCHAR2(100),
	storageproduct		VARCHAR2(100),
	storageconfig		VARCHAR2(256),
 	type			VARCHAR2(50),	-- DISK,SLICE,SUBDISK
	filetype		VARCHAR2(50),	-- BLOCK OR CHARACTER
	linkinode		VARCHAR2(100),	
	diskkey			VARCHAR2(256),
	path			VARCHAR2(256),	-- OS Path
	status			VARCHAR2(100),	-- Formatted or unformatted,OFFLINE
	parent			VARCHAR2(256),	-- SWRAID parent
	backup			VARCHAR2(1),	-- Y/N flag for backup elements
	freetype		VARCHAR2(50)	
)
ON COMMIT PRESERVE ROWS
/

CREATE GLOBAL TEMPORARY TABLE stormon_temp_volume (
	rowcount		INTEGER,
  	target_id		VARCHAR2(256), /* is RAW(16) in git3       */
	targetname		VARCHAR2(256),	-- Target name
  	keyvalue		VARCHAR2(256), /* is varchar2(256) in git3 */
	collection_timestamp	DATE,
	type			VARCHAR2(50),	-- VOLUME, DISK, DISKSLICE
	name			VARCHAR2(256),
	diskgroup		VARCHAR2(256),
	rawsizeb		NUMBER(16),
	sizeb			NUMBER(16),
	usedb			NUMBER(16),
	freeb			NUMBER(16),
	path			VARCHAR2(256),
	linkinode		VARCHAR2(20),
	filetype		VARCHAR2(50),
	configuration		VARCHAR2(256),
	diskname		VARCHAR2(256),
	backup			VARCHAR2(1),
	freetype		VARCHAR2(25)
)
ON COMMIT PRESERVE ROWS
/
CREATE INDEX stormon_temp_vol_idx1 on stormon_Temp_volume(type, keyvalue)
/

CREATE GLOBAL TEMPORARY TABLE stormon_temp_filesystem(
	rowcount		INTEGER,
  	target_id		VARCHAR2(256),        /* is RAW(16) in git3       */
	targetname		VARCHAR2(256),	-- Target name
  	keyvalue		VARCHAR2(256), /* is varchar2(256) in git3 */
	collection_timestamp	DATE,
	type			VARCHAR2(50),
	filesystem		VARCHAR2(256),
	linkinode		VARCHAR2(128),
	rawsizeb		NUMBER(16),
	sizeb			NUMBER(16),
	usedb			NUMBER(16),
	freeb			NUMBER(16),
	mountpoint		VARCHAR2(256),
	mountpointid		VARCHAR2(128),
	mounttype		VARCHAR2(25),
	privilege		VARCHAR2(256),
	server			VARCHAR2(256),
	vendor			VARCHAR2(256),
	nfscount		NUMBER(16),
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
	targetname		VARCHAR2(256),	-- Target name
	parentkey       	VARCHAR2(2000),
  	keyvalue		VARCHAR2(256), /* is varchar2(256) in git3 */
	collection_timestamp	DATE,
	type			VARCHAR2(20),
	appname			VARCHAR2(50),
	appid			VARCHAR2(50),
	filename		VARCHAR2(256),
	filetype		VARCHAR2(256),
	linkinode		VARCHAR2(20),
	rawsizeb		NUMBER(16),
	sizeb			NUMBER(16),
	usedb			NUMBER(16),
	freeb			NUMBER(16),
	tablespace		VARCHAR2(256),
	backup			VARCHAR2(1)
)
ON COMMIT PRESERVE ROWS
/


-------------------- Shared tables -----------------------------------------

CREATE GLOBAL TEMPORARY TABLE stormon_temp_shared_disk (
	rowcount		INTEGER,	
	target_id		VARCHAR2(256), 	 /* is RAW(16) in git3       */
	targetname		VARCHAR2(256),	-- Target name
	keyvalue		VARCHAR2(256), 	/* is varchar2(256) in git3 */
	collection_timestamp	DATE,
	rawsizeb		NUMBER(16),
	sizeb			NUMBER(16),
	usedb			NUMBER(16),
	freeb			NUMBER(16),
	storagevendor		VARCHAR2(100),
	storageproduct		VARCHAR2(100),
	storageconfig		VARCHAR2(256),
 	type			VARCHAR2(50),	-- DISK,SLICE,SUBDISK
	filetype		VARCHAR2(50),	-- BLOCK OR CHARACTER
	linkinode		VARCHAR2(100),	
	diskkey			VARCHAR2(256),
	path			VARCHAR2(256),	-- OS Path
	status			VARCHAR2(100),	-- Formatted or unformatted,OFFLINE
	parent			VARCHAR2(256),	-- SWRAID parent
	backup			VARCHAR2(1),	-- Y/N flag for backup elements
	freetype		VARCHAR2(50)	
)
ON COMMIT PRESERVE ROWS
/
-- Index on disk key ?

CREATE GLOBAL TEMPORARY TABLE stormon_temp_shared_swraid (
	rowcount		INTEGER,	
	target_id		VARCHAR2(256), 	 /* is RAW(16) in git3       */
	targetname		VARCHAR2(256),	-- Target name
	keyvalue		VARCHAR2(256), 	/* is varchar2(256) in git3 */
	collection_timestamp	DATE,
	rawsizeb		NUMBER(16),
	sizeb			NUMBER(16),
	usedb			NUMBER(16),
	freeb			NUMBER(16),
	storagevendor		VARCHAR2(100),
	storageproduct		VARCHAR2(100),
	storageconfig		VARCHAR2(256),
 	type			VARCHAR2(50),	-- DISK,SLICE,SUBDISK
	filetype		VARCHAR2(50),	-- BLOCK OR CHARACTER
	linkinode		VARCHAR2(100),	
	diskkey			VARCHAR2(256),
	path			VARCHAR2(256),	-- OS Path
	status			VARCHAR2(100),	-- Formatted or unformatted,OFFLINE
	parent			VARCHAR2(256),	-- SWRAID parent
	backup			VARCHAR2(1),	-- Y/N flag for backup elements
	freetype		VARCHAR2(50)	
)
ON COMMIT PRESERVE ROWS
/

CREATE GLOBAL TEMPORARY TABLE stormon_temp_shared_volume (
	rowcount		INTEGER,
  	target_id		VARCHAR2(256), /* is RAW(16) in git3       */
	targetname		VARCHAR2(256),	-- Target name
  	keyvalue		VARCHAR2(256), /* is varchar2(256) in git3 */
	collection_timestamp	DATE,
	type			VARCHAR2(50),	-- VOLUME, DISK, DISKSLICE
	name			VARCHAR2(256),
	diskgroup		VARCHAR2(256),
	rawsizeb		NUMBER(16),
	sizeb			NUMBER(16),
	usedb			NUMBER(16),
	freeb			NUMBER(16),
	path			VARCHAR2(256),
	linkinode		VARCHAR2(20),
	filetype		VARCHAR2(50),
	configuration		VARCHAR2(256),
	diskname		VARCHAR2(256),
	backup			VARCHAR2(1),
	freetype		VARCHAR2(25)
)
ON COMMIT PRESERVE ROWS
/


CREATE GLOBAL TEMPORARY TABLE stormon_temp_shared_fs(
	rowcount		INTEGER,
  	target_id		VARCHAR2(256),        /* is RAW(16) in git3       */
	targetname		VARCHAR2(256),	-- Target name
  	keyvalue		VARCHAR2(256), /* is varchar2(256) in git3 */
	collection_timestamp	DATE,
	type			VARCHAR2(50),
	filesystem		VARCHAR2(256),
	linkinode		VARCHAR2(128),
	rawsizeb		NUMBER(16),
	sizeb			NUMBER(16),
	usedb			NUMBER(16),
	freeb			NUMBER(16),
	mountpoint		VARCHAR2(256),
	mountpointid		VARCHAR2(128),
	mounttype		VARCHAR2(25),
	privilege		VARCHAR2(256),
	server			VARCHAR2(256),
	vendor			VARCHAR2(256),
	nfscount		NUMBER(16),
	backup			VARCHAR2(1)
)
ON COMMIT PRESERVE ROWS
/

CREATE GLOBAL TEMPORARY TABLE stormon_temp_shared_app(
	rowcount		INTEGER,
  	target_id		VARCHAR2(256), /* is RAW(16) in git3       */  	
	targetname		VARCHAR2(256),	-- Target name
	parentkey       	VARCHAR2(2000),
  	keyvalue		VARCHAR2(256), /* is varchar2(256) in git3 */
	collection_timestamp	DATE,
	type			VARCHAR2(20),
	appname			VARCHAR2(50),
	appid			VARCHAR2(50),
	filename		VARCHAR2(256),
	filetype		VARCHAR2(256),
	linkinode		VARCHAR2(20),
	rawsizeb		NUMBER(16),
	sizeb			NUMBER(16),
	usedb			NUMBER(16),
	freeb			NUMBER(16),
	tablespace		VARCHAR2(256),
	backup			VARCHAR2(1)
)
ON COMMIT PRESERVE ROWS
/

---------------- Combination shared tables -------------------------------------------

CREATE GLOBAL TEMPORARY TABLE stormon_temp_comb_disk (
	rowcount		INTEGER,	
	target_id		VARCHAR2(256), 	 /* is RAW(16) in git3       */
	targetname		VARCHAR2(256),	-- Target name
	keyvalue		VARCHAR2(256), 	/* is varchar2(256) in git3 */
	collection_timestamp	DATE,
	rawsizeb		NUMBER(16),
	sizeb			NUMBER(16),
	usedb			NUMBER(16),
	freeb			NUMBER(16),
	storagevendor		VARCHAR2(100),
	storageproduct		VARCHAR2(100),
	storageconfig		VARCHAR2(256),
 	type			VARCHAR2(50),	-- DISK,SLICE,SUBDISK
	filetype		VARCHAR2(50),	-- BLOCK OR CHARACTER
	linkinode		VARCHAR2(100),	
	diskkey			VARCHAR2(256),
	path			VARCHAR2(256),	-- OS Path
	status			VARCHAR2(100),	-- Formatted or unformatted,OFFLINE
	parent			VARCHAR2(256),	-- SWRAID parent
	backup			VARCHAR2(1),	-- Y/N flag for backup elements
	freetype		VARCHAR2(50)	
)
ON COMMIT PRESERVE ROWS
/
-- Index on disk key ?

CREATE GLOBAL TEMPORARY TABLE stormon_temp_comb_swraid (
	rowcount		INTEGER,	
	target_id		VARCHAR2(256), 	 /* is RAW(16) in git3       */
	targetname		VARCHAR2(256),	-- Target name
	keyvalue		VARCHAR2(256), 	/* is varchar2(256) in git3 */
	collection_timestamp	DATE,
	rawsizeb		NUMBER(16),
	sizeb			NUMBER(16),
	usedb			NUMBER(16),
	freeb			NUMBER(16),
	storagevendor		VARCHAR2(100),
	storageproduct		VARCHAR2(100),
	storageconfig		VARCHAR2(256),
 	type			VARCHAR2(50),	-- DISK,SLICE,SUBDISK
	filetype		VARCHAR2(50),	-- BLOCK OR CHARACTER
	linkinode		VARCHAR2(100),	
	diskkey			VARCHAR2(256),
	path			VARCHAR2(256),	-- OS Path
	status			VARCHAR2(100),	-- Formatted or unformatted,OFFLINE
	parent			VARCHAR2(256),	-- SWRAID parent
	backup			VARCHAR2(1),	-- Y/N flag for backup elements
	freetype		VARCHAR2(50)	
)
ON COMMIT PRESERVE ROWS
/

CREATE GLOBAL TEMPORARY TABLE stormon_temp_comb_volume (
	rowcount		INTEGER,
  	target_id		VARCHAR2(256), /* is RAW(16) in git3       */
	targetname		VARCHAR2(256),	-- Target name
  	keyvalue		VARCHAR2(256), /* is varchar2(256) in git3 */
	collection_timestamp	DATE,
	type			VARCHAR2(50),	-- VOLUME, DISK, DISKSLICE
	name			VARCHAR2(256),
	diskgroup		VARCHAR2(256),
	rawsizeb		NUMBER(16),
	sizeb			NUMBER(16),
	usedb			NUMBER(16),
	freeb			NUMBER(16),
	path			VARCHAR2(256),
	linkinode		VARCHAR2(20),
	filetype		VARCHAR2(50),
	configuration		VARCHAR2(256),
	diskname		VARCHAR2(256),
	backup			VARCHAR2(1),
	freetype		VARCHAR2(25)
)
ON COMMIT PRESERVE ROWS
/


CREATE GLOBAL TEMPORARY TABLE stormon_temp_comb_filesystem(
	rowcount		INTEGER,
  	target_id		VARCHAR2(256),        /* is RAW(16) in git3       */
	targetname		VARCHAR2(256),	-- Target name
  	keyvalue		VARCHAR2(256), /* is varchar2(256) in git3 */
	collection_timestamp	DATE,
	type			VARCHAR2(50),
	filesystem		VARCHAR2(256),
	linkinode		VARCHAR2(128),
	rawsizeb		NUMBER(16),
	sizeb			NUMBER(16),
	usedb			NUMBER(16),
	freeb			NUMBER(16),
	mountpoint		VARCHAR2(256),
	mountpointid		VARCHAR2(128),
	mounttype		VARCHAR2(25),
	privilege		VARCHAR2(256),
	server			VARCHAR2(256),
	vendor			VARCHAR2(256),
	nfscount		NUMBER(16),
	backup			VARCHAR2(1)
)
ON COMMIT PRESERVE ROWS
/

CREATE GLOBAL TEMPORARY TABLE stormon_temp_comb_app(
	rowcount		INTEGER,
  	target_id		VARCHAR2(256), /* is RAW(16) in git3       */  	
	targetname		VARCHAR2(256),	-- Target name
	parentkey       	VARCHAR2(2000),
  	keyvalue		VARCHAR2(256), /* is varchar2(256) in git3 */
	collection_timestamp	DATE,
	type			VARCHAR2(20),
	appname			VARCHAR2(50),
	appid			VARCHAR2(50),
	filename		VARCHAR2(256),
	filetype		VARCHAR2(256),
	linkinode		VARCHAR2(20),
	rawsizeb		NUMBER(16),
	sizeb			NUMBER(16),
	usedb			NUMBER(16),
	freeb			NUMBER(16),
	tablespace		VARCHAR2(256),
	backup			VARCHAR2(1)
)
ON COMMIT PRESERVE ROWS
/



UPDATE storage_summaryObject SET collection_timestamp=collection_timestamp-1 WHERE id = '23654'
/
COMMIT
/

EXEC storage_summary.calcstoragesummary('agsidbs1.us.oracle.com','23654');







-- Update the collection timestamps
DECLARE
--	l_list_of_targets 	stringtable := stringtable('auohsaskj01.oracleoutsourcing.com',	'auohscabo03.oracleoutsourcing.com','auohscart01.oracleoutsourcing.com','auohscrnr01.oracleoutsourcing.com','auohsmcdt01.oracleoutsourcing.com','auohssbcc01.oracleoutsourcing.com','auohstrzt02.oracleoutsourcing.com');

	l_list_of_targets 	stringtable := stringtable( 'auohsunoc01.oracle.com', 'auohsunoc02.oracle.com', 'auohsunoc03.oracle.com', 'auohsunoc04.oracle.com', 'auohsunoc09.oracle.com', 'auohsunoc14.oracle.com');
	v_targetid	stormon_temp_disk.target_id%TYPE;
BEGIN
	FOR i IN l_list_of_targets.FIRST..l_list_of_targets.LAST LOOP

		SELECT	target_id
		INTO	v_targetid
		FROM	mgmt_targets_view
		WHERE	target_name = l_list_of_targets(i);

		DBMS_OUTPUT.PUT(l_list_of_targets(i)||' = ');

		EXECUTE IMMEDIATE ' UPDATE STORAGE_SUMMARYOBJECT SET collection_timestamp=collection_timestamp-1 WHERE id = :1' USING v_targetid;
		DBMS_OUTPUT.PUT(SQL%ROWCOUNT);	
	
		DBMS_OUTPUT.NEW_LINE;
		COMMIT;

	END LOOP;
END;
/





	
DROP DATABASE LINK storagedb
/

CREATE SHARED DATABASE LINK storagedb CONNECT TO stormon_test IDENTIFIED BY stormon_test  AUTHENTICATED BY stormon_test IDENTIFIED BY stormon_test USING '(DESCRIPTION = (ADDRESS_LIST = (ADDRESS = (PROTOCOL = TCP)(HOST = rmsun11.us.oracle.com)(PORT = 1521)))(CONNECT_DATA = (SID = emap)(GLOBAL_NAME = emap_rmsun11)(SERVER = dedicated)))'
/

-- Refresh the metrics
DECLARE
--	l_list_of_targets 	stringtable := stringtable( 'auohsunoc01.oracle.com', 'auohsunoc02.oracle.com', 'auohsunoc03.oracle.com', 'auohsunoc04.oracle.com', 'auohsunoc09.oracle.com', 'auohsunoc14.oracle.com');
--	l_list_of_targets	stringTable := stringtable('convergent.oraclebol.com','bymo1.oraclebol.com','apprd112.oraclebol.com','chemconnect.oraclebol.com','alphasmart.oraclebol.com');

	l_list_of_targets	stringTable := stringtable('suncal01.us.oracle.com','web137.oracle.com');

--	l_list_of_targets 	stringtable := stringtable( 'auohsaskj01.oracleoutsourcing.com', 'auohscabo03.oracleoutsourcing.com', 'auohscart01.oracleoutsourcing.com', 'auohscrnr01.oracleoutsourcing.com', 'auohsmcdt01.oracleoutsourcing.com', 'auohssbcc01.oracleoutsourcing.com', 'auohstrzt02.oracleoutsourcing.com');

	v_targetid	stormon_temp_disk.target_id%TYPE;
BEGIN
	FOR i IN l_list_of_targets.FIRST..l_list_of_targets.LAST LOOP

		SELECT	target_id
		INTO	v_targetid
		FROM	mgmt_targets_view
		WHERE	target_name = l_list_of_targets(i);

		DBMS_OUTPUT.PUT(l_list_of_targets(i)||' = ');

		DELETE FROM MGMT_CURRENT_METRICS WHERE target_guid = v_targetid;
		DBMS_OUTPUT.PUT(SQL%ROWCOUNT||' / ');

		INSERT INTO MGMT_CURRENT_METRICS SELECT * FROM MGMT_CURRENT_METRICS@storagedb WHERE target_guid = v_targetid;
		DBMS_OUTPUT.PUT(SQL%ROWCOUNT);

		DBMS_OUTPUT.NEW_LINE;
		COMMIT;

	END LOOP;
END;
/

DROP DATABASE LINK storagedb
/


---------------- Calculate storage summary for a group of hosts

DECLARE
--	l_list_of_targets 	stringtable := stringtable( 'auohsunoc01.oracle.com', 'auohsunoc02.oracle.com', 'auohsunoc03.oracle.com', 'auohsunoc04.oracle.com', 'auohsunoc09.oracle.com', 'auohsunoc14.oracle.com');

--	l_list_of_targets 	stringtable := stringtable( 'auohsaskj01.oracleoutsourcing.com', 'auohscabo03.oracleoutsourcing.com', 'auohscart01.oracleoutsourcing.com', 'auohscrnr01.oracleoutsourcing.com', 'auohsmcdt01.oracleoutsourcing.com', 'auohssbcc01.oracleoutsourcing.com', 'auohstrzt02.oracleoutsourcing.com');

	l_list_of_targets	stringTable := stringtable('bymo1.oraclebol.com','apprd112.oraclebol.com','chemconnect.oraclebol.com','alphasmart.oraclebol.com');

	v_targetid	stormon_temp_disk.target_id%TYPE;
BEGIN
	FOR i IN l_list_of_targets.FIRST..l_list_of_targets.LAST LOOP

		SELECT	target_id
		INTO	v_targetid
		FROM	mgmt_targets_view
		WHERE	target_name = l_list_of_targets(i);

		DBMS_OUTPUT.PUT_LINE(l_list_of_targets(i));
		
		STORAGE_SUMMARY.CALCSTORAGESUMMARY(l_list_of_targets(i),v_targetid);
		
		DBMS_OUTPUT.PUT_LINE('------------------------------------------');

	END LOOP;
END;
/

SELECT name, summaryflag, timestamp, sizeb from storage_summaryobject_view where type = 'HOST' and name IN ( 'auohsunoc01.oracle.com', 'auohsunoc02.oracle.com', 'auohsunoc03.oracle.com', 'auohsunoc04.oracle.com', 'auohsunoc09.oracle.com', 'auohsunoc14.oracle.com')
/


-- Load data into the temp tables for a host

	DECLARE
		v_targetid	stormon_temp_disk.target_id%TYPE;
		v_targetname	stormon_temp_disk.targetname%TYPE	:= 'bymo1.oraclebol.com';
	BEGIN		

		SELECT	target_id
		INTO	v_targetid
		FROM	mgmt_targets_view
		WHERE	target_name = v_targetname;

			DELETE FROM stormon_temp_disk;
			DELETE FROM stormon_temp_swraid;
			DELETE FROM stormon_temp_volume;
			DELETE FROM stormon_temp_filesystem;
			DELETE FROM stormon_temp_app;

			-- Collection Table of Applications data for a target
		 	 STORAGE_SUMMARY_DB.GETSTORAGEAPPCOLLECTION(v_targetid,v_targetname);
			-- Collection Table of Filesystem data for a target
		 	STORAGE_SUMMARY_DB.GETSTORAGEFILESYSTEMCOLLECTION(v_targetid,v_targetname);
			-- Collection Table of Volume manager data for a target
			STORAGE_SUMMARY_DB.GETSTORAGEVOLUMECOLLECTION(v_targetid,v_targetname);
			-- Collection Table of swraid data for a target
		 	STORAGE_SUMMARY_DB.GETSTORAGESWRAIDCOLLECTION(v_targetid,v_targetname);
			-- Collection Table of disk device data for a target
		 	STORAGE_SUMMARY_DB.GETSTORAGEDISKCOLLECTION(v_targetid,v_targetname);
		
		EXCEPTION
			WHEN OTHERS THEN
				RAISE_APPLICATION_ERROR(-20101,'Failed fetching the collected storage metrics ',TRUE);
		END;
/			


DECLARE

	l_table_list	stringTable := stringTable(
				'stormon_temp_app','stormon_temp_filesystem','stormon_temp_volume','stormon_temp_swraid','stormon_temp_disk');

	l_magnitude	INTEGER:= 10;	
	l_loop_size	INTEGER;
	
	l_count		INTEGER;
BEGIN

	l_loop_size := ROUND(CEIL(LOG(2,l_magnitude)));	

	FOR j IN l_table_list.FIRST..l_table_list.LAST LOOP
		EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM  '||l_table_list(j) INTO l_count;
		DBMS_OUTPUT.PUT_LINE(l_table_list(j)||' =  '||l_count);
	END LOOP;

	FOR i IN 1..l_loop_size LOOP
		FOR j IN l_table_list.FIRST..l_table_list.LAST LOOP
			EXECUTE IMMEDIATE 'INSERT INTO '||l_table_list(j)||' SELECT * FROM '||l_table_list(j);
		END LOOP;
	END LOOP;

	FOR j IN l_table_list.FIRST..l_table_list.LAST LOOP
		EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM  '||l_table_list(j) INTO l_count;
		DBMS_OUTPUT.PUT_LINE(l_table_list(j)||' =  '||l_count);
	END LOOP;
	
END;	
/	


DROP DATABASE LINK storagedb
/

CREATE SHARED DATABASE LINK storagedb CONNECT TO stormon_test IDENTIFIED BY stormon_test  AUTHENTICATED BY stormon_test IDENTIFIED BY stormon_test USING '(DESCRIPTION = (ADDRESS_LIST = (ADDRESS = (PROTOCOL = TCP)(HOST = rmsun11.us.oracle.com)(PORT = 1521)))(CONNECT_DATA = (SID = emap)(GLOBAL_NAME = emap_rmsun11)(SERVER = dedicated)))'
/

SELECT name, summaryflag, sizeb, used, free from storage_summaryObject_view where type = 'HOST' and name in (
                                                        'auohsaskj01.oracleoutsourcing.com',
                                                        'auohscabo03.oracleoutsourcing.com',
                                                        'auohscart01.oracleoutsourcing.com',
                                                        'auohscrnr01.oracleoutsourcing.com',
                                                        'auohsmcdt01.oracleoutsourcing.com',
                                                        'auohssbcc01.oracleoutsourcing.com',
                                                        'auohstrzt02.oracleoutsourcing.com')
MINUS
SELECT name, summaryflag, sizeb, used, free from storage_summaryObject_view@storagedb where type = 'HOST' and name in (
                                                        'auohsaskj01.oracleoutsourcing.com',
                                                        'auohscabo03.oracleoutsourcing.com',
                                                        'auohscart01.oracleoutsourcing.com',
                                                        'auohscrnr01.oracleoutsourcing.com',
                                                        'auohsmcdt01.oracleoutsourcing.com',
                                                        'auohssbcc01.oracleoutsourcing.com',
                                                        'auohstrzt02.oracleoutsourcing.com')
/


SELECT name, summaryflag, sizeb, used, free from storage_summaryObject_view@storagedb where type = 'HOST' and name in (
                                                        'auohsaskj01.oracleoutsourcing.com',
                                                        'auohscabo03.oracleoutsourcing.com',
                                                        'auohscart01.oracleoutsourcing.com',
                                                        'auohscrnr01.oracleoutsourcing.com',
                                                        'auohsmcdt01.oracleoutsourcing.com',
                                                        'auohssbcc01.oracleoutsourcing.com',
                                                        'auohstrzt02.oracleoutsourcing.com')
MINUS
SELECT name, summaryflag, sizeb, used, free from storage_summaryObject_view where type = 'HOST' and name in (
                                                        'auohsaskj01.oracleoutsourcing.com',
                                                        'auohscabo03.oracleoutsourcing.com',
                                                        'auohscart01.oracleoutsourcing.com',
                                                        'auohscrnr01.oracleoutsourcing.com',
                                                        'auohsmcdt01.oracleoutsourcing.com',
                                                        'auohssbcc01.oracleoutsourcing.com',
                                                        'auohstrzt02.oracleoutsourcing.com')
/

DROP DATABASE LINK storagedb
/






                        SELECT  oem_target_name
                        FROM    (
                                        SELECT  target_id,
                                                oem_target_name,
                                                MAX(collection_timestamp) collection_timestamp
                                        FROM    stormon_temp_app
                                        GROUP BY
                                                target_id,
                                                oem_target_name
                                ) a
                        -- The database target does not have a job scheduled
                        WHERE   NOT EXISTS
                        (
                                SELECT  1
                                FROM    stormon_active_targets_view b
                                WHERE   b.target_type = 'oracle_sysman_database'
                                AND     b.node_id = a.target_id
                                AND     b.target_name = a.oem_target_name
                        )
                        -- Collection timestamp of the database should be less than c_metric_time_range from the other host metrics
                        -- Collection timestamp is in the timezone of the target
                        AND     a.collection_timestamp <
                        (
                                SELECT  MAX(b.collection_timestamp) -  1
                                FROM
                                (
                                        SELECT  collection_timestamp collection_timestamp
                                        FROM    stormon_temp_filesystem
                                        UNION
                                        SELECT  collection_timestamp collection_timestamp
                                        FROM    stormon_temp_volume
                                        UNION
                                        SELECT  collection_timestamp collection_timestamp
                                        FROM    stormon_temp_swraid
                                        UNION
                                        SELECT  collection_timestamp collection_timestamp
                                        FROM    stormon_temp_disk
                                ) b
                        )
/



--------------------------------------------------------------------
-- View all the hosts that share nfs with a given host
SELECT  target,
        filesystem,
        DECODE(a.other_target_id,'DEDICATED','DEDICATED','SHARED') mounttype,
        NVL(b.target_name,a.other_target_id) other_mounts
FROM    (
SELECT  d.target_id,
        d.target_name target,
        a.filesystem,
        NVL(c.target_id,'DEDICATED')  other_target_id
FROM    storage_nfs_table a,
        storage_nfs_table c,
        mgmt_targets_view d
WHERE   c.filesystem(+) = a.filesystem
AND     c.target_id(+) != '19609'
AND     a.target_id = '19609'
AND     a.target_id = d.target_id
) a,
mgmt_targets_view b
WHERE   a.target_id != a.other_target_id
AND     b.target_id(+) = a.other_target_id
ORDER BY
        DECODE(a.other_target_id,'DEDICATED',1,2) ,
        filesystem
/

-------------------------------------------------------------------------

INSERT INTO stormon_temp_filesystem(
	rowcount		,
  	target_id		,        /* is RAW(16) in git3       */
	targetname		,	-- Target name
  	keyvalue		, /* is varchar2 in git3 */
	collection_timestamp	,
	type			,
	filesystem		,
	linkinode		,
	rawsizeb		,
	sizeb			,
	usedb			,
	freeb			,
	mountpoint		,
	mountpointid		,
	mounttype		,
	privilege		,
	server			,
	vendor			,
	nfscount		,
	backup			
)
SELECT	rownum,											-- rownum
	'24584',										-- target_id
	'name',										-- targetname
	DECODE(LOWER(e.string_value),'nfs',a.string_value,NVL(j.string_value,a.string_value)),	-- keyvalue , linkinode for localfs and filesystem for nfs filesystems
	a.collection_timestamp,									-- collection_timestamp
	e.string_value,										-- type
	a.string_value,										-- filesystem
	j.string_value,										-- linkinode
	0,											-- rawsizeb
	b.value,										-- sizeb
	c.value,										-- usedb
	d.value,										-- freeb
	h.string_value,										-- mountpoint
	-- The metrics loads the filesystemid-fileinode for mountpoint, we are interested only in the filesystem ID
	-- The metrics need to be altered for this after taking into account the effects of NFS
	SUBSTR(k.string_value,1,INSTR(k.string_value,'-')-1),					-- mountpoint filesystem id
	m.string_value,										-- mounttype , EXCLSUIVE OR SHARED for nfs, this is computed
	l.string_value,										-- privilege
	f.string_value,										-- server
	g.string_value,										-- vendor
	i.value,										-- nfscount
	'N'											-- backup	 
FROM	mgmt_current_metrics a,
	mgmt_current_metrics b,
	mgmt_current_metrics c,
	mgmt_current_metrics d,
	mgmt_current_metrics e,
	mgmt_current_metrics f,
	mgmt_current_metrics g,
	mgmt_current_metrics h,
	mgmt_current_metrics i,
	mgmt_current_metrics j,
	mgmt_current_metrics k,
	mgmt_current_metrics l,
	mgmt_current_metrics m
WHERE  	a.target_guid = '24584'
AND 	b.target_guid = a.target_guid
AND 	c.target_guid = a.target_guid
AND 	d.target_guid = a.target_guid
AND 	e.target_guid = a.target_guid
AND 	f.target_guid = a.target_guid
AND 	g.target_guid = a.target_guid
AND 	h.target_guid = a.target_guid
AND	i.target_guid = a.target_guid
AND	j.target_guid = a.target_guid
AND	k.target_guid = a.target_guid
AND	l.target_guid = a.target_guid
AND	m.target_guid(+) = a.target_guid
AND 	b.key_value   = a.key_value
AND 	c.key_value   = a.key_value
AND 	d.key_value   = a.key_value
AND 	e.key_value   = a.key_value
AND 	f.key_value   = a.key_value
AND 	g.key_value   = a.key_value
AND 	h.key_value   = a.key_value
AND	i.key_value   = a.key_value
AND	j.key_value   = a.key_value
AND	k.key_value   = a.key_value
AND	l.key_value   = a.key_value
AND	m.key_value(+)   = a.key_value
AND 	a.metric_guid = '3052'
AND 	b.metric_guid = '3055'
AND 	c.metric_guid = '3056'
AND 	d.metric_guid = '3057'
AND 	e.metric_guid = '3051'
AND 	f.metric_guid = '3058'
AND 	g.metric_guid = '3059'
AND 	h.metric_guid = '3054'
AND 	i.metric_guid = '3063'
AND	j.metric_guid = '3053'
AND	k.metric_guid = '6610'
AND	l.metric_guid = '3062'
AND	m.metric_guid(+) = '14118'
;


select job_name, TO_CHAR(start_time,'DD-MON HH24:MI') start_time, TO_CHAR(finish_time,'DD-MON HH24:MI') finish_time , status , COUNT(*)
from smp_vdj_job_per_target
where job_name like 'STORAGE%'
group by job_name,TO_CHAR(start_time,'DD-MON HH24:MI'),TO_CHAR(finish_time,'DD-MON HH24:MI'), status
order by start_time asc
/

select target_name, node_name ,
TO_CHAR(start_time,'DD-MON HH24:MI') starttime,
TO_CHAR(finish_time,'DD-MON HH24:MI') finishtime ,
(finish_time-start_time)*24*60 duration , status
from smp_vdj_job_per_target where job_name like 'STORAGE%' and TO_CHAR(start_time,'DD-MON HH24:MI') = '31-OCT 06:01' ORDER BY (finish_time-start_time)
/

SELECT c.target_name, c.starttime, c.finishtime, c.duration, NVL(TO_CHAR(MIN(COLLECTION_TIMEStamp),'DD-MON HH24:MI'),'Collection_failed') min_col_time , max(collection_timestamp) max_col_time
from mgmt_current_metrics a,
(
select b.target_id,a.target_name, node_name ,
TO_CHAR(start_time,'DD-MON HH24:MI') starttime,
TO_CHAR(finish_time,'DD-MON HH24:MI') finishtime ,
TO_CHAR(ROUND((finish_time-start_time)*24*60)) duration , status
from smp_vdj_job_per_target a,
	mgmt_targets_view b
where job_name like 'STORAGE%' 
and TO_CHAR(start_time,'DD-MON HH24:MI') = '31-OCT 06:01' 
and TO_CHAR(finish_time,'DD-MON HH24:MI') = '31-OCT 06:03' 
and a.target_name = b.target_name
) c
where a.target_guid(+) = c.target_id
group by c.target_name, c.starttime, c.finishtime, c.duration
/

----------------------------------------

Check for outsourcing hosts

Hosts not in thelist

adctls08
adctls15
auohsther01
auohsther02
auohsther03


-- Status of these hosts for outsourcing

COLUMN summary_status FORMAT a15 HEADING 'Summary Status';
COLUMN summary_stale_status FORMAT a15 HEADING 'Summary Status';
COLUMN summary_time FORMAT a20 HEADING 'Summary Time(PST)';
COLUMN starttime FORMAT a20 HEADING 'Job start Time(PST)';
COLUMN duration FORMAT a20 HEADING 'Job duration(Secs)' WRAP;
COLUMN job_name FORMAT a30 HEADING 'Job Name';
COLUMN status FORMAT a20 HEADING 'Job Status';

SELECT	d.target_name,	
	DECODE(a.summaryflag,'Y','Summarized','I','Issues','N','Not collected',a.summaryflag) summary_status,
	DECODE(SIGN((c.start_time-(8/24)) - (a.collection_timestamp-(d.tz/24)-(8/24))),'1','Stale Summary',NULL) summary_stale_status,
--	TO_CHAR(a.collection_timestamp,'DD-MON-YY HH24:MI') summary_time,
	TO_CHAR(a.collection_timestamp-(d.tz/24)-(8/24),'DD-MON HH24:MI') summary_time,
	TO_CHAR(c.start_time-(8/24),'DD-MON-YY HH24:MI') starttime,
--	TO_CHAR(c.finish_time-(8/24),'DD-MON-YY HH24:MI') finishtime,
	TO_CHAR(ROUND((c.finish_time-c.start_time)*24*60*60)) duration ,
	TO_CHAR(c.status) status,
	c.job_name
FROM	storage_summaryObject a,
	(
		SELECT	*
		FROM	smp_vdj_job_per_target c
		WHERE 	c.status(+) NOT IN ('11','14','15')
		AND c.job_name(+) LIKE 'STORAGE%'
	)c,
	mgmt_targets_view d
WHERE	d.target_id = a.id(+)
AND	d.target_name IN
(
'adcinf01.oracle.com',
'adcinf13.oracle.com',
'adcinf15.oracle.com',
'alnr1s.oraclebol.com',
'alphasmart.oraclebol.com',
'apprd112.oraclebol.com',
'apprd117.oraclebol.com',
'aptst008-sj.oraclebol.com',
'aucsdshr02.oracle.com',
'aucsmshr02.oracle.com',
'auohsacec01.oracleoutsourcing.com',
'auohsaffn01.oracleoutsourcing.com',
'auohsagen02.oracleoutsourcing.com',
'auohsalin01.oracleoutsourcing.com',
'auohsalle01.oracleoutsourcing.com',
'auohsalph01.oracleoutsourcing.com',
'auohsanhg01.oracleoutsourcing.com',
'auohsanhg04.oracleoutsourcing.com',
'auohsaskj01.oracleoutsourcing.com',
'auohsbcrd15.oracleoutsourcing.com',
'auohscabo01.oracleoutsourcing.com',
'auohscabo02.oracleoutsourcing.com',
'auohscabo03.oracleoutsourcing.com',
'auohscart01.oracleoutsourcing.com',
'auohsccom01.oracleoutsourcing.com',
'auohscenp01.oracleoutsourcing.com',
'auohscere01.oracleoutsourcing.com',
'auohscerv01.oracleoutsourcing.com',
'auohscgit01.oracle.com',
'auohscgit03.oracle.com',
'auohschia01.oracleoutsourcing.com',
'auohsclib01.oracleoutsourcing.com',
'auohscowa01.oracle.com',
'auohscowa03.oracle.com',
'auohscowa04.oracle.com',
'auohscowa05.oracle.com',
'auohscowa06.oracle.com',
'auohscpus01.oracleoutsourcing.com',
'auohscrnr01.oracleoutsourcing.com',
'auohscrnr02.oracleoutsourcing.com',
'auohscsas01.oracleoutsourcing.com',
'auohsdain01.oracleoutsourcing.com',
'auohsdana01.oracleoutsourcing.com',
'auohsdrgn01.oracleoutsourcing.com',
'auohsecfc02.oracleoutsourcing.com',
'auohsedus03.oracleoutsourcing.com',
'auohsedus05.oracleoutsourcing.com',
'auohsempx01.oracleoutsourcing.com',
'auohsestr04.oracle.com',
'auohsfcmp01.oracleoutsourcing.com',
'auohsfedh01.oracleoutsourcing.com',
'auohsfedh02.oracleoutsourcing.com',
'auohsffit02.oracleoutsourcing.com',
'auohsffit05.oracleoutsourcing.com',
'auohsgeph01.oracleoutsourcing.com',
'auohsggtu01.us.oracle.com',
'auohsgpda14.oracleoutsourcing.com',
'auohsgpda18.oracleoutsourcing.com',
'auohsgtdi03.oracleoutsourcing.com',
'auohsgtdi04.oracleoutsourcing.com',
'auohshano13.oracleoutsourcing.com',
'auohshano14.oracleoutsourcing.com',
'auohshano18.oracleoutsourcing.com',
'auohshoop01.oracleoutsourcing.com',
'auohsiftt03.oracleoutsourcing.com',
'auohsinds02.oracle.com',
'auohsinfp04.oracle.com',
'auohsinfp05.oracle.com',
'auohsinfp06.oracle.com',
'auohsinfp07.oracle.com',
'auohsinfp08.oracle.com',
'auohsinfp09.oracle.com',
'auohsinfp12.oracle.com',
'auohsinfp13.oracle.com',
'auohsinfp14.oracle.com',
'auohsinfp15.oracle.com',
'auohsinfp16.oracle.com',
'auohsinfp17.oracle.com',
'auohsinfp19.oracle.com',
'auohsitst09.oracleoutsourcing.com',
'auohsjohn10.oracleoutsourcing.com',
'auohsjohn12.oracleoutsourcing.com',
'auohskerr01.oracleoutsourcing.com',
'auohskoco01.oracleoutsourcing.com',
'auohslaur01.oracleoutsourcing.com',
'auohslsfr01.oracleoutsourcing.com',
'auohsmata02.oracleoutsourcing.com',
'auohsmcdt01.oracleoutsourcing.com',
'auohsmcom01.oracleoutsourcing.com',
'auohsmdcy01.oracleoutsourcing.com',
'auohsmedu01.oracleoutsourcing.com',
'auohsmint02.oracleoutsourcing.com',
'auohsmint09.oracleoutsourcing.com',
'auohsmsdh04.oracleoutsourcing.com',
'auohsmsdh06.oracleoutsourcing.com',
'auohsnasa01.oracleoutsourcing.com',
'auohsnasa02.oracleoutsourcing.com',
'auohsnasa06.oracleoutsourcing.com',
'auohsnuan01.oracleoutsourcing.com',
'auohsogio01.oracleoutsourcing.com',
'auohsredh18.oracleoutsourcing.com',
'auohsrnds02.oracleoutsourcing.com',
'auohsrnds06.oracleoutsourcing.com',
'auohssbcc01.oracleoutsourcing.com',
'auohssgds08.oracleoutsourcing.com',
'auohssgds09.oracleoutsourcing.com',
'auohssgds10.oracleoutsourcing.com',
'auohssgds19.oracleoutsourcing.com',
'auohssgds27.oracleoutsourcing.com',
'auohssibg01.us.oracle.com',
'auohssoco01.oracleoutsourcing.com',
'auohssoco02.oracleoutsourcing.com',
'auohssron02.oracleoutsourcing.com',
'auohstest03.oracleoutsourcing.com',
'auohstosh03.oracleoutsourcing.com',
'auohstosh04.oracleoutsourcing.com',
'auohstrzt01.oracleoutsourcing.com',
'auohstrzt02.oracleoutsourcing.com',
'auohstula01.oracleoutsourcing.com',
'auohstula03.oracleoutsourcing.com',
'auohsunoc01.oracle.com',
'auohsunoc02.oracle.com',
'auohsunoc03.oracle.com',
'auohsunoc04.oracle.com',
'auohsunoc06.oracle.com',
'auohsunoc09.oracle.com',
'auohsunoc11.oracle.com',
'auohsunoc14.oracle.com',
'auohsunoc16.oracle.com',
'auohsunoc23.oracle.com',
'auohsunoc24.oracle.com',
'auohsunoc25.oracle.com',
'auohsunoc26.oracle.com',
'auohsunoc55.oracle.com',
'auohsutsc01.oracleoutsourcing.com',
'auohsutsc02.oracleoutsourcing.com',
'auohsvssa01.oracleoutsourcing.com',
'auohsysix01.oracleoutsourcing.com',
'auohsysix02.oracleoutsourcing.com',
'bcrd2.oraclebol.com',
'bcrd3.oraclebol.com',
'bymo1.oraclebol.com',
'cattech.oraclebol.com',
'ceres.oraclebol.com',
'chemconnect.oraclebol.com',
'cigna2.oraclebol.com',
'cigna.oraclebol.com',
'convergent.oraclebol.com',
'fusa.oraclebol.com',
'infr008.oraclebol.com',
'infr012.oraclebol.com',
'johnihaas.oraclebol.com',
'montreal.oraclebol.com',
'rmohscgit05.oracle.com',
'rmohscgit10.oracle.com',
'rmohscgit11.oracle.com',
'rmohscgit12.oracle.com',
'rmohscgit13.oracle.com',
'rmohscgit14.oracle.com',
'rmohssgds09.oracle.com',
'rmohssgds10.oracle.com',
'rmohssgds11.oracle.com',
'rmohssgds12.oracle.com',
'rmohssgds13.oracle.com',
'rmohssgds14.oracle.com',
'rmohssgds15.oracle.com',
'rmohssgds16.oracle.com',
'rmohssgds17.oracle.com',
'rmohssgds18.oracle.com',
'tosh1.oraclebol.com',
'vizcomm.oraclebol.com',
'xshdb002-v.oracleexchange.com',
'xshdb012-v.oracleexchange.com',
'xshmt009-v.oracleexchange.com',
'xshmt010-v.oracleexchange.com',
'xshmt011-v.oracleexchange.com',
'xshmt012-v.oracleexchange.com'
)
--AND  a.id = b.target_guid(+)
AND d.target_name = c.node_name(+)
ORDER BY
DECODE(job_name,NULL,1,0) ASC,
a.summaryflag,
DECODE(SIGN(c.start_time - (a.collection_timestamp-(d.tz/24))),'1','Stale Summary',NULL),
a.collection_timestamp DESC
/



-- Status of these hosts for outsourcing
SET LINESIZE 120
SET PAGESIZE 80
SET FEEDBACK ON
SET ECHO OFF
SET TERMOUT OFF

-- Spread of the currently scheduled jobs
COLUMN count_all FORMAT 9999 HEADING 'Total stormon|jobs scheduled';
COLUMN count_1 FORMAT 9999 HEADING 'No execution in|the last 24 Hours';
COLUMN count_2 FORMAT 9999 HEADING 'May have |timed out';
COLUMN count_3 FORMAT 9999 HEADING 'May have failed|to execute';


COLUMN target_name FORMAT a30;
COLUMN summary_status FORMAT a15 HEADING 'Summary Status';
COLUMN summary_stale_status FORMAT a15 HEADING 'Summary Status';
COLUMN summary_time FORMAT a12 HEADING 'Summary Time';
COLUMN starttime FORMAT a12 HEADING 'Job Time';
COLUMN duration FORMAT a10 HEADING 'Job (Secs)' WRAP;
COLUMN job_name FORMAT a30 HEADING 'Job Name';
COLUMN status FORMAT a45 HEADING 'Job Status';
COLUMN pst FORMAT a15 HEADING 'PST';

BREAK ON REPORT;
COMPUTE SUM OF count_all count_1 count_2 count_3 ON REPORT;

COMPUTE NUMBER OF STATUS ON STATUS;
BREAK ON status SKIP 2;

SPOOL $HOME/tmp/failed_collection.lis

SELECT	start_time,
	count_all,
	count_1,
	count_2,
	count_3
FROM (
	SELECT	TO_CHAR(start_time-(8/24),'HH24:MI') start_time, 
		COUNT(*) count_all,
		SUM( CASE WHEN SIGN(start_time-(8/24)-((SYSDATE+((7-8)/24))-(1.5))) = -1 THEN
			 	1		
			ELSE
				0
			END
		) count_1,
		SUM ( CASE WHEN SIGN(((last_collection_timestamp-start_time)*24*60*60)-1119) = 1 THEN
				1
			ELSE
				0
			END
		) count_2,
		SUM ( CASE WHEN SIGN(((last_collection_timestamp-start_time)*24*60*60)-2) = -1 THEN
				1
			ELSE
				0
			END
		) count_3
	FROM	stormon_active_targets_view a,
		mgmt_targets_view b
	WHERE	a.node_id = b.target_id
	GROUP BY
		TO_CHAR(start_time-(8/24),'HH24:MI')
	)
WHERE	( count_1 + count_2 + count_3 ) > 0
ORDER BY 
	( ( count_1 + count_2 + count_3 ) / count_all ) DESC
/


SELECT	
	( 
	CASE WHEN start_time IS NULL THEN
		'Job not scheduled'
	WHEN SIGN(start_time-(8/24)-((SYSDATE+((7-8)/24))-(1.5))) = -1 THEN
		'Job has not executed in the last 24 Hours'		
	WHEN SIGN(((finish_time-start_time)*24*60*60)-1119) = 1 THEN
		'Job may have timed out'
	WHEN SIGN(((finish_time-start_time)*24*60*60)-2) = -1 THEN
		'Job may have failed to execute'
	ELSE
		'This host is fine'
	END	) status,
	SUBSTR(target_name,1,30) target_name,				
	TO_CHAR(collection_timestamp-(tz/24)-(8/24),'DD-MON HH24:MI') summary_time,
	TO_CHAR(start_time-(8/24),'DD-MON HH24:MI') starttime,
	TO_CHAR(ROUND((finish_time-start_time)*24*60*60)) duration
FROM	(
	SELECT	d.target_name,
		a.summaryflag,
		c.start_time,
		a.collection_timestamp,
		d.tz,
		c.last_collection_timestamp finish_time,
		c.status,
		c.job_name
	FROM	storage_summaryObject a,
	(
		SELECT	*
		FROM	stormon_active_targets_view 
	)c,
	mgmt_targets_view d	
	WHERE	d.target_id = a.id(+)
	AND	d.target_id = c.node_id(+)
	AND	UPPER(d.operating_system) NOT LIKE '%HPUX%'
	AND	UPPER(d.operating_system) NOT LIKE '%WINDOW%'
	)
WHERE	start_time IS NULL						-- Either no job has been scheduled or NO job has executed in the last 24 hours
OR	start_time-(8/24) < ((SYSDATE+((7-8)/24))-(1.5))  	-- Convert start_time from gmt to MST
OR	(
		-- If a job has executed, and the summary is not valid or stale ( older than last collection timestamp by a day )
		(
			NVL(summaryflag,'x') != 'Y'		
			OR ((start_time-(8/24)) - (collection_timestamp-(tz/24)-(8/24))) > 1
			-- NO need to check if collection_timestamp is older than a day			
		)
		AND -- either it timed out or it failed to execute for some reason
		(
			((finish_time-start_time)*24*60*60) > 1119		-- It timed out
			OR ((finish_time-start_time)*24*60*60) < 2		-- Invalid login and password
		)			
	)
ORDER BY
1;

SPOOL OFF;

CLEAR BREAKS;
CLEAR COLUMNS;
CLEAR COMPUTES;

@setts

ed $HOME/tmp/failed_collection.lis


--- SQL TO CHECK THE JOB STATUS

11/5/03
--------------------------------------------------------------
EXEC STORAGE_SUMMARY.CLEANJOB;

DELETE FROM mozart_smp_vdj_job_per_target
/
ALTER TABLE mozart_smp_vdj_job_per_target MODIFY status VARCHAR2(256)
/

DELETE FROM smp_vdj_job_per_target
/ 
ALTER TABLE smp_vdj_job_per_target MODIFY status VARCHAR2(256)
/ 

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


@storage_summary_db_9i

EXEC STORAGE_SUMMARY_DB.REFRESH_TARGETS

EXEC STORAGE_SUMMARY_DB.REFRESH_MOZART_TARGETS

EXEC STORAGE_SUMMARY_DB.MIGRATE_TARGETS

EXEC STORAGE_SUMMARY.COMPUTE_DC_LOB_GROUPS


------------------------------------------------------------------------
--11/06/03

ALTER TABLE mgmt_migrated_targets ADD 
(
	status 	VARCHAR2(25)
)
/

--------------------------------------------------------------------------
-- 11/07/03

DROP VIEW stormon_summary_status_view
/
	
CREATE OR REPLACE VIEW stormon_summary_status_view
(
	target_id,
	target_name,
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
SELECT	d.target_id,
	d.target_name,
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
		CASE WHEN c.start_time IS NULL THEN
			'FAILED-stormon Job not scheduled'
		WHEN (( SYSDATE-(8/24) - c.start_time) >= 1.5 )  THEN
			'FAILED-stormon Job has not executed in the last 24 Hours'		
		WHEN  (  
			((c.last_collection_timestamp-c.start_time)*24*60*60) >= 1119 AND
			(
				a.collection_timestamp IS NULL OR	
				( c.start_time - ( a.collection_timestamp-(tz/24)) ) > 1
			)					
		) THEN
			'FAILED-Job has have timed out'
		WHEN  (
			((c.last_collection_timestamp-c.start_time)*24*60*60) < 2 AND
			(
				a.collection_timestamp IS NULL OR	
				( c.start_time - ( a.collection_timestamp-(tz/24)) ) > 1
			)
		) THEN
			'FAILED-Job Failed to execute'
		WHEN (
			NVL(summaryflag,'X') != 'Y' OR
			a.collection_timestamp IS NULL OR
			( c.start_time - (a.collection_timestamp-(tz/24)) ) > 1.5
		) THEN
				'FAILED-Failed in summary computatiom'
		WHEN (	
			a.collection_timestamp IS NOT NULL AND
			(
				(
					c.last_collection_timestamp IS NOT NULL AND
					a.collection_timestamp-(tz/24) > c.last_collection_timestamp
				)
				OR 
				(
					c.last_collection_timestamp IS NULL AND
					a.collection_timestamp-(tz/24) > c.start_time
				)
			)
		) THEN
			'FAILED-Summary timestamp is later than collection!'	
		ELSE
			'Successfuly Summarized Jobs'
		END	
	) status
FROM	storage_summaryObject a,
	stormon_active_targets_view c,
	mgmt_targets_view d,
	(
		SELECT	DISTINCT host,
			FIRST_VALUE(version) OVER ( PARTITION BY host, package ORDER BY timestamp DESC ) epm_version	
		FROM	patcher.log@package_db
		WHERE	package = 'stormon'
	) e	
WHERE	d.target_id = a.id(+)
AND	d.target_id = c.node_id(+)
AND	SUBSTR(d.target_name,1,INSTRB(d.target_name,'.')) = e.host(+)
AND	UPPER(d.operating_system) NOT LIKE '%HPUX%'
AND	UPPER(d.operating_system) NOT LIKE '%WINDOW%'
/
----------------------------------
11/10/03

DROP TABLE stormon_load_status
/ 

CREATE TABLE stormon_load_status (
	node_id				VARCHAR2(256)	NOT NULL,	-- Target_id of the host the target is on
	target_name			VARCHAR2(255)	NOT NULL,	-- Target name of the target with the collection
	target_type			VARCHAR2(255)	NOT NULL,	-- Target type of the target with the collection
	timestamp			TIMESTAMP WITH TIME ZONE,	-- Timestamp of insertion
	max_collection_timestamp	TIMESTAMP WITH TIME ZONE,	
	min_collection_timestamp	TIMESTAMP WITH TIME ZONE
)
PCTFREE 5 PCTUSED 70 TABLESPACE data_storage STORAGE( INITIAL 20M )
/
CREATE UNIQUE INDEX stormon_load_status_idx1 ON stormon_load_status( node_id, target_name, target_type ) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 8M )
/
CREATE UNIQUE INDEX stormon_load_status_idx2 ON stormon_load_status(target_name,target_type) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 7M )
/
 

DECLARE

	l_hosttable 	stringTable;
	v_targetid	mgmt_targets_view.target_id%TYPE;
	v_targetname	mgmt_targets_view.target_name%TYPE;

BEGIN		

	-- List of hosts which are monitored as targets
	l_hosttable 		:= STORAGE_SUMMARY_DB.GETHOSTLIST;

	FOR i IN l_hostTable.FIRST..l_hostTable.LAST LOOP
--	FOR i IN l_hostTable.FIRST..100 LOOP

		DBMS_OUTPUT.PUT_LINE(v_targetid ||' = '|| l_hostTable(i));

		v_targetid := STORAGE_SUMMARY_DB.GETTARGETID(l_hostTable(i));	

		DELETE FROM stormon_load_status WHERE node_id = v_targetid;

		INSERT INTO stormon_load_status(
		node_id,	-- Target_id of the host the target is on
		target_name,	-- Target name of the target with the collection
		target_type,	-- Target type of the target with the collection
		timestamp,	-- Timestamp of insertion
		max_collection_timestamp,	
		min_collection_timestamp
		)
		SELECT	a.target_guid,
			b.target_name,
			b.target_type,
			SYSTIMESTAMP,
			TO_TIMESTAMP_TZ( TO_CHAR(MIN(collection_timestamp),'DD-MON-YYYY HH24:MI:SS ')||SIGN(b.tz)*FLOOR((ABS(b.tz)*60)/60)||':'||MOD((ABS(b.tz)*60),60) ,' DD-MON-YYYY HH24:MI:SS TZH:TZM' ),
			TO_TIMESTAMP_TZ( TO_CHAR(MAX(collection_timestamp),'DD-MON-YYYY HH24:MI:SS ')||SIGN(b.tz)*FLOOR((ABS(b.tz)*60)/60)||':'||MOD((ABS(b.tz)*60),60) ,' DD-MON-YYYY HH24:MI:SS TZH:TZM' ) 
		FROM	mgmt_current_metrics a,
			mgmt_targets_view b,
			mgmt_metrics c
		WHERE	a.target_guid = b.target_id
		AND	a.metric_guid = c.metric_guid
		AND	c.metric_name IN ('disk_devices','storage_filesystems','storage_summary','storage_swraid','storage_volume_layers')
		AND	b.target_id = v_targetid
		GROUP BY
			a.target_guid,
			b.target_name,
			b.target_type,
			b.tz;

		
		INSERT INTO stormon_load_status(
		node_id,	-- Target_id of the host the target is on
		target_name,	-- Target name of the target with the collection
		target_type,	-- Target type of the target with the collection
		timestamp,	-- Timestamp of insertion
		max_collection_timestamp,
		min_collection_timestamp
		)
		SELECT	a.target_guid,
			a.string_value,
			'oracle_sysman_database',
			SYSTIMESTAMP,
			TO_TIMESTAMP_TZ( TO_CHAR(MIN(collection_timestamp),'DD-MON-YYYY HH24:MI:SS ')||SIGN(b.tz)*FLOOR((ABS(b.tz)*60)/60)||':'||MOD((ABS(b.tz)*60),60) ,' DD-MON-YYYY HH24:MI:SS TZH:TZM' ),
			TO_TIMESTAMP_TZ( TO_CHAR(MAX(collection_timestamp),'DD-MON-YYYY HH24:MI:SS ')||SIGN(b.tz)*FLOOR((ABS(b.tz)*60)/60)||':'||MOD((ABS(b.tz)*60),60) ,' DD-MON-YYYY HH24:MI:SS TZH:TZM' )
		FROM	mgmt_current_metrics a,
			mgmt_targets_view b,
			mgmt_metrics c
		WHERE	a.target_guid = b.target_id
		AND	a.metric_guid = c.metric_guid
		AND	c.metric_column IN ('storage_applications_oem_target_name')
		AND	b.target_id = v_targetid
		GROUP BY
			a.target_guid,
			string_value,
			b.tz;

		COMMIT;

	END LOOP;

END;
/


--	SELECT	JOBS
--	FROM	stormon_active_targets_view
--	WHERE	node_id matches
--	AND	target_name matches
--	AND	target_type matches
--	AND	timestamp IN GMT >= ( start_time + sufficient window for job computation ) ( what if timestamp is after start_time , but is working on old metrics of last load, ie new load has not been commited yet)
--	AND 	min_collection_timestamp IN GMT < start_time

--	SELECT	JOBS
--	FROM	stormon_active_targets_view
--	WHERE	node_id matches
--	AND	target_name matches
--	AND	target_type matches
--	AND 	min_collection_timestamp IN GMT >= start_time
--	AND	it has an issue ( This data is newer than the collection ts of the host )


CREATE OR REPLACE VIEW stormon_summary_status_view
(
	target_id,
	target_name,
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
SELECT	

SELECT  DISTINCT
	FIRST_VALUE(a.node_id) OVER( PARTITION BY a.node_id ORDER BY a.priority DESC ) node_id,
	FIRST_VALUE(a.node_name) OVER( PARTITION BY a.node_id ORDER BY a.priority DESC ) node_name,
--	a.target_name,
--	a.target_type,
	FIRST_VALUE(a.start_time) OVER ( PARTITION BY a.node_id ORDER BY a.priority DESC ) start_time,
	FIRST_VALUE(a.last_collection_timestamp) OVER ( PARTITION BY a.node_id ORDER BY a.priority DESC ) finish_time,
	FIRST_VALUE(a.stormon_status) OVER( PARTITION BY a.node_id ORDER BY a.priority DESC ) stormon_status, 
--	a.job_name, 
--	a.collection_timestamp,
--	a.min_collection_timestamp,
--	a.max_collection_timestamp,
        e.epm_version
--	,a.priority
FROM    (
SELECT  d.target_id 			node_id,
	d.target_name			node_name,
	d.target_name			target_name,
	d.target_type			target_type,
	NULL 				start_time,
	NULL				last_collection_timestamp,	
	'stormon Job not scheduled' 	stormon_status,
	NULL 				job_name,
	NULL 				status,
	NULL				collection_timestamp,
	NULL				min_collection_timestamp,
	NULL				max_collection_timestamp,
	1				priority
FROM    mgmt_targets_view d,
        stormon_active_targets_view c
WHERE   d.target_id = c.node_id(+)
AND     c.start_time IS NULL
UNION
SELECT  d.target_id,
	d.target_name,
	c.target_name,
	c.target_type,
	c.start_time,
	c.last_collection_timestamp,	
	'stormon Job has not executed in the last 24 Hours' stormon_status,
	c.job_name,
	c.status,
	NULL,
	NULL,
	NULL,
	2
FROM    mgmt_targets_view d,
        stormon_active_targets_view c
WHERE   d.target_id = c.node_id
AND     (( SYSDATE-(8/24) - c.start_time) >= 1.5 )
UNION
SELECT 	d.target_id,
	d.target_name,
	c.target_name,
	c.target_type,
	c.start_time,
	c.last_collection_timestamp,
	'Job executed , But No Metrics ' stormon_status,
	c.job_name,
	c.status,
	NULL,
	f.min_collection_timestamp,
	f.max_collection_timestamp,
	3
FROM    mgmt_targets_view d,
        stormon_active_targets_view c,
        stormon_load_status f
WHERE   d.target_id = c.node_id
AND     c.node_id = f.node_id(+)
AND     c.target_name = f.target_name(+)
AND     c.target_type = f.target_type(+)
AND     c.start_time < f.timestamp(+)
AND     f.min_collection_timestamp IS NULL
UNION
SELECT  d.target_id,
	d.target_name,
	c.target_name,
	c.target_type,
	c.start_time,
	c.last_collection_timestamp,
	'Job executed , But No Metrics ' stormon_status,
	c.job_name,
	c.status,
	NULL,
	f.min_collection_timestamp,
	f.max_collection_timestamp,
	3
FROM    mgmt_targets_view d,
        stormon_active_targets_view c,
        stormon_load_status f
WHERE   d.target_id = c.node_id
AND     c.node_id = f.node_id
AND     c.target_name = f.target_name
AND     c.target_type = f.target_type
AND     c.start_time < f.timestamp
AND     c.start_time > f.min_collection_timestamp
UNION
SELECT  a.id,
	a.name,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	a.collection_timestamp,
	f.min_collection_timestamp,
	f.max_collection_timestamp,
	4
FROM    storage_summaryobject_view a,
        (
                SELECT  node_id,
                        MAX(min_collection_timestamp) min_collection_timestamp,
                        MIN(max_collection_timestamp) max_collection_timestamp
                FROM    stormon_load_status
                GROUP BY
                        node_id
        ) f
WHERE   a.id = f.node_id
AND     a.type = 'HOST'
AND     a.collection_timestamp < f.max_collection_timestamp
) a,
(
        SELECT  DISTINCT host,
                FIRST_VALUE(version) OVER ( PARTITION BY host, package ORDER BY timestamp DESC ) epm_version
        FROM    patcher.log@package_db
        WHERE   package = 'stormon'
) e
WHERE   SUBSTR(a.node_name,1,INSTRB(a.node_name,'.')-1) = e.host(+)
/

DROP DATABASE LINK package_db
/
-- The patcher database for the epm version
CREATE SHARED DATABASE LINK package_db CONNECT TO stormon IDENTIFIED BY erfgtyu5  AUTHENTICATED BY stormon IDENTIFIED BY erfgtyu5 USING '(DESCRIPTION = (ADDRESS_LIST = (ADDRESS = (PROTOCOL = TCP)(HOST = gitprod1.us.oracle.com)(PORT = 1522)))(CONNECT_DATA = (SID = projap)(GLOBAL_NAME = projap_gitprod1)(SERVER = dedicated)))'
/


--------------------- 
-- 11/11/03

DROP VIEW merged_node_target_map_view
/ 

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
		CASE WHEN c.start_time IS NULL THEN
			'FAILED-stormon Job not scheduled'
		WHEN (( CAST ( SYS_EXTRACT_UTC(systimestamp) AS DATE ) - c.start_time ) >= 1.5 )  THEN
			'FAILED-stormon Job has not executed in the last 24 Hours'		
		WHEN  ( 
			( 			
			-- A case of no data in loaded after 12 hous of job execution			
				( ( CAST ( SYS_EXTRACT_UTC(systimestamp) AS DATE ) - c.start_time ) >= .5 ) 
			AND	c.last_collection_timestamp IS NOT NULL	
			AND	f.timestamp IS NULL
			)
			OR
			(
			-- There is a record in stormon_load_status an hour after the job start BUT
			-- the collection timestamp is lesser than the start time
				c.last_collection_timestamp IS NOT NULL
			AND	( ( CAST ( SYS_EXTRACT_UTC(f.timestamp) AS DATE ) ) - c.start_time ) > ( 1/24)
			AND	CAST ( SYS_EXTRACT_UTC(f.min_collection_timestamp) AS DATE ) < c.start_time
			)				
		) THEN
			'FAILED - Job scheduled , but no metrics have been loaded to the repository'
		WHEN (
				f.max_collection_timestamp IS NOT NULL
			AND	a.collection_timestamp IS NULL 
			OR	a.collection_timestamp < f.max_collection_timestamp 
		) THEN
				'FAILED-Metrics have been uploaded but summary computation has failed'
		ELSE
			'Successfuly Summarized Jobs'
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
                        MAX(min_collection_timestamp) min_collection_timestamp,
                        MIN(max_collection_timestamp) max_collection_timestamp
                FROM    stormon_load_status
                GROUP BY
                        node_id
        ) g
WHERE   d.node_id = a.id(+)
AND     d.node_id = c.node_id(+)
AND     d.node_id = f.node_id(+)
AND     d.node_id = g.node_id
AND     d.target_name = c.target_name(+)
AND     d.target_name = f.target_name(+)
AND     d.target_type = c.target_type(+)
AND     d.target_type=  f.target_type(+)
AND     d.host = e.host(+)
AND	a.type(+) = 'HOST'
/

----------------
SET ECHO OFF;
SET FEEDBACK OFF;

SPOOL $HOME/tmp/monitoring.sql

BEGIN
FOR rec IN (
        SELECT TABLE_NAME FROM USER_TABLES
	WHERE TEMPORARY = 'N'
        UNION
        SELECT TABLE_NAME FROM USER_OBJECT_TABLES
) LOOP
        DBMS_OUTPUT.PUT_LINE('ALTER TABLE '||rec.table_name||' MONITORING'||CHR(10)||'/');
END LOOP;
FOR rec IN (
        SELECT INDEX_NAME FROM USER_INDEXES
) LOOP
        DBMS_OUTPUT.PUT_LINE('ALTER INDEX '||LOWER(rec.index_name)||' MONITORING USAGE '||CHR(10)||'/');
END LOOP;
END;
/

SPOOL OFF;

@setts



-----------------
-- Monitoring status
SELECT TABLE_NAME, NUM_ROWS,BLOCKS,AVG_SPACE,SAMPLE_SIZE,LAST_ANALYZED,MONITORING FROM USER_TABLES
/
SELECT INDEX_NAME "NAME", NUM_ROWS, DISTINCT_KEYS "DISTINCT" ,LEAF_BLOCKS, CLUSTERING_FACTOR "CF", BLEVEL "LEVEL", AVG_LEAF_BLOCKS_PER_KEY "ALFBPKEY", SAMPLE_SIZE,LAST_ANALYZED FROM USER_INDEXES
/
SELECT COLUMN_NAME, NUM_DISTINCT, NUM_NULLS, NUM_BUCKETS, DENSITY FROM USER_TAB_COL_STATISTICS ORDER BY COLUMN_NAME
/
SELECT * FROM USER_TAB_MODIFICATIONS
/

DECLARE

	v_object_list		DBMS_STATS.ObjectTab;	
	l_list_of_tables	stringTable;

BEGIN


-- 	Need privilege to do this
--	DBMS_STATS.FLUSH_DATABASE_MONITORING_INFO;
--
--	DBMS_STATS PROCEDURES DO A COMMIT ON THEIR OWN
--	
	 DBMS_STATS.GATHER_SCHEMA_STATS(
			'storage_rep',			-- Schema to analyze (NULL means current schema). 
			DBMS_STATS.AUTO_SAMPLE_SIZE,	-- Percentage of rows to estimate
			FALSE,				-- Whether or not to use random block sampling instead of random row sampling
			'FOR ALL COLUMNS SIZE AUTO',	-- method_opt
			DBMS_STATS.DEFAULT_DEGREE,	-- Degree of parallelism. NULL means use the table default value specified by the DEGREE clause in the CREATE TABLE or ALTER TABLE statemen
			'DEFAULT',			-- Granularity of statistics to collect (only pertinent if the table is partitioned).
			TRUE,				-- Gather statistics on the indexes as well.
			NULL,				-- User stat table identifier describing where to save the current statistics. 
			NULL,				-- Identifier (optional) to associate with these statistics within stattab.
			'GATHER AUTO',			-- Further specification of which objects to gather statistics for
			v_object_list, 			-- List of objects found to be stale or empty.
			NULL				-- Schema containing stattab (if different than ownname). 
			);

	IF v_object_list IS NOT NULL AND v_object_list.EXISTS(1) THEN
	
		FOR i IN v_object_list.FIRST..v_object_list.LAST LOOP

			DBMS_OUTPUT.PUT_LINE(' Gathered statistics with GATHER AUTO for table '||v_object_list(i).objname);

		END LOOP;	

	END IF;

	SELECT	TABLE_NAME BULK COLLECT INTO l_list_of_tables FROM USER_TAB_MODIFICATIONS;

	IF l_list_of_tables IS NOT NULL AND l_list_of_tables.EXISTS(1) THEN

		FOR i IN l_list_of_tables.FIRST..l_list_of_tables.LAST LOOP

			DBMS_STATS.GATHER_TABLE_STATS(
					'STORAGE_REP',			-- Schema of table to analyze
					UPPER(l_list_of_tables(i)),	-- Name of table.
					NULL,				-- Name of partition
					DBMS_STATS.AUTO_SAMPLE_SIZE,	-- Percentage of rows to estimate (NULL means compute)
					FALSE,				-- Whether or not to use random block sampling instead of random row sampling
					'FOR ALL COLUMNS SIZE AUTO',	-- method_opt
					DBMS_STATS.DEFAULT_DEGREE,	-- Degree of parallelism. NULL means use the table default value specified by the DEGREE clause in table DDL
					'DEFAULT',			-- Granularity of statistics to collec
					TRUE);				-- Gather statistics on the indexes for this table.			

		END LOOP;

		FOR i IN l_list_of_tables.FIRST..l_list_of_tables.LAST LOOP

			DBMS_OUTPUT.PUT_LINE(' Table in USER_TAB_MODIFICATIONS , gathered statistics for '||l_list_of_tables(i));			

		END LOOP;

	END IF;


EXCEPTION
	WHEN OTHERS THEN
		RAISE_APPLICATION_ERROR(-20101,'Failed in procedure gathering statistics',TRUE);	
END;
/


---------------------------------------
-- The progress of the worst performing steps


select TO_CHAR(timestamp,'DD-MON HH24:MI'), id, time_seconds from storage_statistics where message like '%Time to fetch shared disk keys%'
and id in (
select distinct id
from storage_statistics
where message like '%Time to fetch shared disk keys%' and time_seconds > 100 )
order by
        timestamp asc
/


DECLARE

l_target_name		mgmt_targets_view.target_name%TYPE := 'web137.oracle.com';
l_target_id		mgmt_targets_view.target_id%TYPE;

BEGIN


	-- Is the target name valid
	BEGIN
		SELECT	target_id 
		INTO	l_target_id
		FROM	mgmt_targets_view
		WHERE	target_name = l_target_name
		AND	target_type = 'oracle_sysman_node';
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			RAISE_APPLICATION_ERROR(-20101,'Target name '||l_target_name||' is not found in the list of host targets',TRUE);
		WHEN OTHERS THEN
			RAISE_APPLICATION_ERROR(-20101,'Failed looking up Target name '||l_target_name||' in the list of host targets',TRUE);
	END;

	-- Stop the currently executing jobs
	STORAGE_SUMMARY.CLEANJOB;
	
	-- Calculate the storage summary for the target
	STORAGE_SUMMARY.CALCSTORAGESUMMARY(l_target_name, l_target_id);

	-- Check if there was metric data to compute the summary
	DECLARE
		l_dummy	INTEGER;
	BEGIN
		SELECT	1
		INTO	l_dummy
		FROM	stormon_load_status
		WHERE	node_id = l_target_id
		AND	ROWNUM = 1;

	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			RAISE_APPLICATION_ERROR(-20101,'Failed to compute summary , No metric data has been loaded for target name '||l_target_name,TRUE);
		WHEN OTHERS THEN
			RAISE_APPLICATION_ERROR(-20101,'Failed while performing check if data was loaded for '||l_target_name,TRUE);
	END;

	-- Check if there is a summary computed for the target
	DECLARE
		l_dummy	INTEGER;
	BEGIN
		SELECT	1
		INTO	l_dummy
		FROM	storage_summaryobject_view
		WHERE	id = l_target_id
		AND	type = 'HOST';

	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			RAISE_APPLICATION_ERROR(-20101,'Failed to compute summary for target name '||l_target_name,TRUE);
		WHEN OTHERS THEN
			RAISE_APPLICATION_ERROR(-20101,'Failed while performing check if summary has been computed for '||l_target_name,TRUE);
	END;	


	-- Check if the summary was computed , but there was an issue with that computation
	DECLARE
		l_dummy		INTEGER;
	BEGIN

		SELECT	1
		INTO	l_dummy
		FROM	storage_summaryObject_view a,
			(
				SELECT	node_id,
					MAX(timestamp)		      timestamp,
					MAX(max_collection_timestamp) max_collection_timestamp
				FROM	stormon_load_status
				WHERE	node_id = l_target_id
				GROUP BY
					node_id
			) b
		WHERE	a.id = b.node_id
		AND	a.type = 'HOST'
		AND	NVL(a.summaryflag,'x') != 'Y'
		AND	(
			a.collection_timestamp  >= CAST ( b.max_collection_timestamp AS DATE )
		OR	a.timestamp >= CAST ( b.timestamp AS DATE )
		);

		RAISE_APPLICATION_ERROR(-20101,'Summary computed , but has an issue for target name '||l_target_name,TRUE);

	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			NULL;
		WHEN OTHERS THEN
			IF SQLCODE != -20101 THEN
				RAISE_APPLICATION_ERROR(-20101,'Failed while performing check if summary computed has an issue for '||l_target_name,TRUE);	
			ELSE
				RAISE;
			END IF;
	END;



	-- Check if the summary was not computed, for the current collection in the repository
	DECLARE
		l_dummy		INTEGER;
	BEGIN

		SELECT	1
		INTO	l_dummy
		FROM	storage_summaryObject_view a,
			(
				SELECT	node_id,				
					MAX(max_collection_timestamp) max_collection_timestamp
				FROM	stormon_load_status
				WHERE	node_id = l_target_id
				GROUP BY
					node_id
			) b
		WHERE	a.id = b.node_id
		AND	a.type = 'HOST'	
		AND	a.collection_timestamp  < CAST ( b.max_collection_timestamp AS DATE );

		RAISE_APPLICATION_ERROR(-20101,'Retaining the old summary , as there was an issue with computing summary with the newly loaded data for target name '||l_target_name,TRUE);

	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			NULL;
		WHEN OTHERS THEN
			IF SQLCODE != -20101 THEN
				RAISE_APPLICATION_ERROR(-20101,'Failed while performing check if summary was computed for the newly loaded data for '||l_target_name,TRUE);	
			ELSE
				RAISE;
			END IF;
	END;


	-- Restore the summary cmputation job
	STORAGE_SUMMARY.SUBMITJOB;

EXCEPTION
	WHEN OTHERS THEN
		-- Restore the summary computation job
		STORAGE_SUMMARY.SUBMITJOB;
		RAISE;
		
END;
/
-----------------------------------------------------
-- 11/13/03

DROP TABLE storage_group_lock
/

CREATE TABLE storage_group_lock ( dummy NUMBER(1) ) TABLESPACE data_storage 
/
	
BEGIN

LOCK TABLE storage_group_lock IN EXCLUSIVE MODE;

SAVEPOINT A;
LOCK TABLE storage_group_lock IN EXCLUSIVE MODE;
ROLLBACK TO SAVEPOINT a;

END;
/

DROP TABLE storage_group_lock
/

-- NARA to provide this as sys on emap
grant execute on dbms_lock to storage_rep
/

CREATE TABLE TEST ( A DATE)
/

DECLARE

	lockhandle		VARCHAR2(258);
	
BEGIN


INSERT INTO TEST VALUES(SYSDATE);

DBMS_LOCK.ALLOCATE_UNIQUE ('test_lock', lockhandle);


DBMS_OUTPUT.PUT_LINE('Lock release status '||DBMS_LOCK.RELEASE (lockhandle));

END;
/


DROP TABLE TEST
/


DROP TABLE mgmt_storage_keys
/
CREATE TABLE mgmt_storage_keys(
TARGET_GUID		VARCHAR2(256),
PHYSICAL_OR_VIRTUAL	VARCHAR2(1),
KEY_VALUE		VARCHAR2(256),
PARENT_KEY		VARCHAR2(256)
)
/


DROP TABLE mgmt_storage_usage
/
CREATE TABLE mgmt_storage_usage(
TARGET_GUID		VARCHAR2(256),
KEY_VALUE		VARCHAR2(256),
TYPE			VARCHAR2(128),
ENTITY			VARCHAR2(128),
SIZEB			NUMBER,
USEDB			NUMBER,
FREEB			NUMBER
)
/


--
-- Look at file $HOME/ajdsouza/tmp/mapload for perl script to load file /home/ajdsouza/tmp/mapfile.txt
-- Edit file /home/ajdsouza/tmp/mapfile.txt to load a different mapping configuration
--

SELECT  LPAD(' ',4*LEVEL-1)||' '||KEY_VALUE
FROM     -- Oracle applies the predicate after the connect , for the predicat to have precedence , do a virtual query to do the fileration
        (
                SELECT  *
                FROM    mgmt_storage_keys
                WHERE   PHYSICAL_OR_VIRTUAL = 'Y'
        ) storage_keys
CONNECT BY
        PRIOR key_value = parent_key	
START WITH
        parent_key = key_value
/


SELECT	storage_map,
	key_value,
	physical_or_virtual
FROM	(
	SELECT  physical_or_virtual,
		key_value,
		LPAD(' ', 2*level-1)||SYS_CONNECT_BY_PATH(LOWER(key_value),' / ') storage_map
	FROM    -- Oracle applies the predicate after the connect , for the predicat to have precedence , do a virtual query to do the fileration
		(
                	SELECT  *
	                FROM    mgmt_storage_keys
        	)
	START WITH
        	parent_key IS NULL
	CONNECT BY
        	PRIOR key_value = parent_key
)
WHERE	physical_or_virtual = 'Y'
/

SELECT	a.storage_map,
	a.key_value,
	a.physical_or_virtual,
	b.sizeb,
	b.usedb,
	b.freeb
FROM	(
	SELECT  target_guid,
		physical_or_virtual,
		key_value,
		LPAD(' ', 2*level-1)||SYS_CONNECT_BY_PATH(LOWER(key_value),' / ') storage_map
	FROM    -- Oracle applies the predicate after the connect , for the predicat to have precedence , do a virtual query to do the fileration
		(
                	SELECT  *
	                FROM    mgmt_storage_keys
        	)
	START WITH
        	parent_key IS NULL
	CONNECT BY
        	PRIOR key_value = parent_key
) a,
mgmt_storage_usage b
WHERE	a.physical_or_virtual = 'Y'
AND 	a.target_guid = b.target_guid
AND	a.key_value = b.key_value
/



-- Relationships to handle

--  cardinality  ( Top down , one way )
--	1:1	- eg. A filesystem is on a partition, a partition is on a disk
--	1:N, 	- eg. A disk has n partitions, a volume is related to n disks

--
--  Physical Containment	 -  
--	a is b			- eg. Block and char partitions are the same physical device    
--	a is part of b		- eg. A partition is part of a physical disk
--	a is part of b and c	- eg. A volume may have part of disk a and disk b in it.

-- Cardinality can be seen from the keys in the table - its obvious there,
-- Containment cannot be ?
--
-- eg.
--	Volume v1 is based on one disk a	- Cardinality is 1:1,  But containment is : v1 is a part of a
--	Volume v2 is also based on one disk a   - cardinality is 1:1,  But containment is : v2 is a part of a
--
--
--
-- eg   disk partition p1 is in use
--	p1 is part of disk d1							- Cardinality is 1:1, but containment is : p1 is part of d1
--	disk d1 is multipathed, with disk d2, and  pseudo device psu1		- Cardinality is 1:n, but containment is : d1 is the same as d2 , d1 is the same as psu1

-- Is it important to know containment , why ?
-- The usage data loaded from the host should have already taken care containment in the size, used and free numbers in the usage table 
--
-- The repository need know only the relationship between the physical and virtual levels 
-- 



-- CASE 1 
--
--	A host has a pseudo disk device PSU1
--	Two multipathed disks D1 and D2
--	The key_value for the disk is DK1
--	The disk has 2 partitions with key values P1 and P2
--	There is some unpartitioned space left on the device DK1
--	The partition P1 is free
--	The partiton  P2 is completely Used
--
--	Data to be loaded by the stormon script
--	
--	key_value	Parent 	Entity		Level	Physical
--	P1		-	PARTITION	DISK	Y
--	P2		-	PARTITION	DISK	Y
--	DK1		P1	DISK		DISK	Y
--	DK1		P2	DISK		DISK	Y
--
--	PSU1		DK1	DISK		DISK	N		
--	D1		PSU1	DISK		DISK	N
--	D2		PSU2	DISK		DISK	N

-- The basic usage data for this case will be the following
--
--	KEY_VALUE	SIZEB	USEDB	FREEB	
--	P1		sp1	0	sp1
--	P2		sp2	sp2	0
--	DK1		sdk1	udk1	(sdk1-udk1)
--
--
--  TOTAL DISK SPACE ON THIS HOST IS 	sdk1
--  FREE SPACE IS   			sp1 + ( sdk1 - udk1 )
--  USED SPACE IS 			sdk1 - ( sp1 + ( sdk1 - udk1 ) )

-- The physical map will be
--	P1
--		P1/DK1
--	P2	
--		P2/DK1
--
-- The virtual map for DK1 will be
--	PSU1
--		PSU1/D1
--		PSU1/D2
--



--
--
-- CASE 2
--
--	Host has a Volume V1 
--	Volume V1 is layered on volume V11
--	Volume V11 is mirrored from two plexes PL1 AND PL2
--	Plex PL1 uses disk partitions P1 and P2
--	Plex PL2 uses disk partitions P1 and P3
--	Disk Partition P1 is from DISK with key DK1
--	Disk partiton P2 is also from Disk with partition DK1
--	Disk partiton P3 is from DISK with partition DK
--

--
--	Data to be loaded by the stormon script
--	
--	key_value	Parent 	Entity		Level	Physical
--	V1		-	VOLUME		VOLUME	Y
--	P1		V1	PARTITION	DISK	Y
--	P2		V1	PARTITION	DISK	Y
--	P3		V1	PARTITION	DISK	Y
--	DK1		P1	DISK		DISK	Y
--	DK1		P2	DISK		DISK	Y
--	DK2		P3	DISK		DISK	Y
--
--	V11		V1	LAYWERED_VOL	VOLUME	N
--	PL1		V11	PLEX		VOLUME	N
--	PL2		V11	PLEX		VOLUME	N
--	P1		PL1	PARTITION	VOLUME	N
--	P2		PL1	PARTITION	VOLUME	N
--	P1		PL2	PARTITION	VOLUME	N
--	P3		PL2	PARTITION	VOLUME	N

-- The basic usage data for this case will be the following
--	KEY_VALUE	SIZEB	USEDB	FREEB	
--	V1		sv1	0	sv1
--	P1		sp1	sp1	0
--	P2		sp2	up2	sp2-up2
--	P3		sp3	sp3	0
--	DK1		sdk1	udk1	( sdk1-udk1 )
--
--
--  TOTAL DISK SPACE ON THIS HOST IS 	sdk1
--  FREE SPACE IS 			sv1 + (sp2-up2) + ( sdk1 - udk1)
--  USED SPACE IS 			sdk1 -   ( sv1 + (sp2-up2) + ( sdk1 - udk1) )
--
--
--
--  The physical map will be
--	V1
--		V1/P1
--			V1/P1/DK1
--		V1/P2
--			V1/P2/DK1
--		V1/P3
--			V1/P3/DK2
--
--
-- The virtual map for V1 
--	V1
--		V1/V11
--			V1/V11/PL1
--				V1/V11/PL1/P1
--				V1/V11/PL1/P2				
--			V1/V11/PL2
--				V1/V11/PL2/P1
--				V1/V11/PL2/P3
--
--



--
--
-- CASE 3
--
--
-- Filesystem FS1 is based on partition a disk device DID1
-- DID1 is from disks D1 and D2
--
--
--	Data to be loaded by the stormon script
--	
--	key_value	Parent 	Entity		Level	Physical
--	FS1		-	FILESYSTEM	FS	Y
--	DID1		FS1	DID_DEVICE	DID	Y
--	D1		DID1	DISK		DISK	Y
--	D2		DID1	DISK		DISK	Y
--
--
--
-- The basic usage data for this case will be the following
--	KEY_VALUE	SIZEB	USEDB	FREEB	
--	FS1		sfs1	ufs1	( sfs1 - ufs1)
--	DID1		sdid1	udid1	( sdid1 - udid1 )
--	D1		sd1	ud1	( sd1 - ud1 )
--	D2		sd2	ud2	( sd2 - ud2 )
--  
--  TOTAL DISK SPACE ON THIS HOST IS 	sd1 + sd2
--  FREE SPACE IS 			( sfs1 - ufs1) + ( sdid1 - udid1 ) + ( sd1 - ud1 ) + ( sd2 - ud2 )
--  USED SPACE IS 			sd1 + sd2 - ( ( sfs1 - ufs1) + ( sdid1 - udid1 ) + ( sd1 - ud1 ) + ( sd2 - ud2 ) )
--
--
-- Physical map is
--	FS1
--		FS1/DID1
--			FS/DID1/D1
--			FS/DID1/D2
--
--


--
--
-- CASE 4
--
--
-- Host has a datafile DF1 on the NFS filesystem NFS1.
--
--	Data to be loaded by the stormon script
--	
--	key_value	Parent 	Entity		Level		Physical
--	DF1		-	DATAFILE	ORACLEDB	Y
--	NFS1		DF1	FILESYSTEM	NFS		Y	
--
--
-- The basic usage data for this case will be the following
--	KEY_VALUE	SIZEB	USEDB	FREEB	
--	DF1		sdf1	udf1	( sfd1 - udf1)
--	NFS1		snfs1	unfs1	( snfs1 - unfs1)
--
--  
--  TOTAL DISK SPACE ON THIS HOST IS 	snfs1
--  FREE SPACE IS 			( snfs1 - unfs1) + ( sdf1 - udf1 )
--  USED SPACE IS 			snfs1 -  ( ( snfs1 - unfs1) + ( sdf1 - udf1 ) )
--
--
--
-- Physical map is
--	DF1
--		DF1/SNFS1
--
--
--


DELETE FROM PLAN_TABLE
/

EXPLAIN PLAN SET STATEMENT_ID = '1' FOR
SELECT  a.group_id
FROM    stormon_host_groups a,
	mgmt_targets_view B
WHERE   a.target_id = b.target_id
--AND	b.target_id IS NULL
/

@$HOME/tmp/utlxpls

CREATE UNIQUE INDEX stormon_host_groups_idx2 ON stormon_host_groups(target_id, group_id ) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 3M ) COMPUTE STATISTICS
/

ALTER INDEX stormon_host_groups_idx1 MONITORING USAGE
/


DELETE FROM PLAN_TABLE
/

EXPLAIN PLAN SET STATEMENT_ID = '1' FOR
                DELETE FROM stormon_group_table o
                WHERE	NOT EXISTS
                (
                        SELECT  a.group_id
                        FROM    stormon_host_groups a,
                                mgmt_targets_view B
                        WHERE   a.target_id = b.target_id
			AND	a.group_id = o.id
                )
/

@$HOME/tmp/utlxpls

DROP VIEW mgmt_targets_merged_view
/
DROP VIEW mgmt_targets_new
/

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
		AND	b.original_target_id IS NOT NULL
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

GRANT SELECT ON mgmt_targets_new TO stormon_test
/




SET SERVEROUT ON;

DECLARE
------------------------------------------------------
-- Private package variables
------------------------------------------------------
p_group_query_list		stringTable := stringTable();

l_cursor		sys_refcursor;
l_group_name		stormon_group_table.name%TYPE;
l_group_type		stormon_group_table.type%TYPE;
l_host_count		stormon_group_table.host_count%TYPE;
l_target_cursor		sys_refcursor;

l_target_list		stringTable;
l_group_id		stormon_group_table.id%TYPE;

l_time			INTEGER := 0;

BEGIN

	------------------------------------
	-- List of dc lob grouping queries
	------------------------------------	
	p_group_query_list.EXTEND(4);
	
	-- Datacenter grouping refresh and cleanup queries
	p_group_query_list(1) := '
		SELECT	''REPORTING_DATACENTER'',
			datacenter, 
			COUNT(*),
			CURSOR (
				SELECT	target_id
				FROM	mgmt_targets_view
				WHERE	datacenter = a.datacenter
			)
		FROM	mgmt_targets_view a
		GROUP BY
			datacenter
		';
	
	-- LOB grouping refresh and cleanup queries
	p_group_query_list(2) := '
		SELECT	''REPORTING_LOB'',
			escalation_group,
			COUNT(*),
			CURSOR (
				SELECT	target_id
				FROM	mgmt_targets_view
				WHERE	escalation_group = a.escalation_group
			)
		FROM	mgmt_targets_view a
		GROUP BY
			escalation_group
		';


	-- DC-LOB grouping refresh and cleanup queries
	p_group_query_list(3) := '
		SELECT	''REPORTING_DATACENTER_LOB'',
			datacenter||''-''||escalation_group,
			COUNT(*),
			CURSOR (
				SELECT	target_id
				FROM	mgmt_targets_view
				WHERE	escalation_group = a.escalation_group
				AND	datacenter = a.datacenter
			)
		FROM	mgmt_targets_view a
		GROUP BY
			escalation_group,
			datacenter
		';

	-- ALL group refresh query, no cleanup query is required for all, nothing can get stale here
	p_group_query_list(4) := '
		SELECT	''REPORTING_ALL'',
			''ALL'',
			COUNT(*),
			CURSOR (
				SELECT	target_id
				FROM	mgmt_targets_view				
			)
		FROM	mgmt_targets_view a					
		GROUP BY
			1		
		';			

	l_time := STORAGE_SUMMARY_DB.GETTIME(l_time);

	-- Delete the log for this procedure
	STORAGE_SUMMARY_DB.DELETELOG('refresh_dc_lob_groups');

	STORAGE_SUMMARY_DB.LOG('refresh_dc_lob_groups','In STORAGE_SUMMAY_DB.refresh_dc_lob_groups');

	-----------------------------------------------------------------------------------------------------------
	-- Delete the groups which have targets that are not in the target master
	-- Deleting a group will delete the group to host mapping from stormon_host_groups with the trigger
	-----------------------------------------------------------------------------------------------------------
	BEGIN
	
		STORAGE_SUMMARY_DB.LOG('refresh_dc_lob_groups','Deleting groups with deleted target_ids');
	
		DELETE FROM stormon_group_table o
		WHERE   NOT EXISTS  
	        (
		        SELECT  a.group_id
		        FROM    stormon_host_groups a,
		                mgmt_targets_view B
		        WHERE   a.target_id = b.target_id
			AND	a.group_id = o.id
	        );

		STORAGE_SUMMARY_DB.PRINTSTMT(' groups deleted from stormon_group_table is '||SQL%ROWCOUNT);

	EXCEPTION
		WHEN OTHERS THEN		    
			RAISE;
	END;

	STORAGE_SUMMARY_DB.LOG_TIME(
			'refresh_dc_lob_groups',
			'refresh_dc_lob_groups',
			'refresh_dc_lob_groups','Time taken to delete groups for invalid hosts from stormon_group_table is ',STORAGE_SUMMARY_DB.GETTIME(l_time));

	-------------------------------------------------------------------------------------------------------------------------------
	-- If a query is defined to clean up the groups of this type then execute this query to clean stale groups
	-- The trigger on stormon_group_table ensures deletion of rows in stormon_-host_groups and stormon_group_of_groups_table
	-------------------------------------------------------------------------------------------------------------------------------
	BEGIN

		STORAGE_SUMMARY_DB.LOG('refresh_dc_lob_groups','Deleting groups with no names for REPORTING_DATACENTER ');

		DELETE	FROM stormon_group_table
		WHERE	type = 'REPORTING_DATACENTER'
		AND	name NOT IN 
			(
				SELECT DISTINCT datacenter
				FROM	mgmt_targets_view a
				WHERE	datacenter IS NOT NULL
			);

		STORAGE_SUMMARY_DB.PRINTSTMT(' Deleted groups for REPORTING_DATACENTER '||SQL%ROWCOUNT);

	EXCEPTION
		WHEN OTHERS THEN
			STORAGE_SUMMARY_DB.PRINTSTMT('Failed to delete groups for  REPORTING_DATACENTER');
			RAISE;
	END;

	BEGIN

		STORAGE_SUMMARY_DB.LOG('refresh_dc_lob_groups','Deleting groups with no names for REPORTING_LOB ');

		DELETE	FROM stormon_group_table
		WHERE	type = 'REPORTING_LOB'
		AND	name NOT IN 
			(
				SELECT DISTINCT escalation_group
				FROM	mgmt_targets_view a
				WHERE	escalation_group IS NOT NULL
			);

		STORAGE_SUMMARY_DB.PRINTSTMT(' Deleted groups for REPORTING_LOB '||SQL%ROWCOUNT);

	EXCEPTION
		WHEN OTHERS THEN
			STORAGE_SUMMARY_DB.PRINTSTMT('Failed to delete groups for REPORTING_LOB');
			RAISE;
	END;

	BEGIN

		STORAGE_SUMMARY_DB.LOG('refresh_dc_lob_groups','Deleting groups with no names for REPORTING_DATACENTER_LOB ');

		DELETE	FROM stormon_group_table
		WHERE	type = 'REPORTING_DATACENTER_LOB'
		AND	name NOT IN 
			(
				SELECT DISTINCT 	datacenter||'-'||escalation_group
				FROM	mgmt_targets_view a
				WHERE	escalation_group IS NOT NULL 
				OR	datacenter IS NOT NULL
			);	
	
		STORAGE_SUMMARY_DB.PRINTSTMT(' Deleted groups for REPORTING_DATACENTER_LOB '||SQL%ROWCOUNT);

	EXCEPTION
		WHEN OTHERS THEN
			STORAGE_SUMMARY_DB.PRINTSTMT('Failed to delete groups for REPORTING_DATACENTER_LOB');
			RAISE;
	END;

	STORAGE_SUMMARY_DB.LOG_TIME(
			'refresh_dc_lob_groups',
			'refresh_dc_lob_groups',
			'refresh_dc_lob_groups','Time taken to delete invalid groups from stormon_group_table is ',STORAGE_SUMMARY_DB.GETTIME(l_time));

	----------------------------------------------------------------------------------
	-- Build the datacenter, LOB groups based on the query passed in
	----------------------------------------------------------------------------------
	FOR i IN p_group_query_list.FIRST..p_group_query_list.LAST 
	LOOP
		----------------------------------------------------------------------------------------
		-- Now insert the new groups of this type if they do not already exist
		----------------------------------------------------------------------------------------
		OPEN l_cursor FOR p_group_query_list(i);

		LOOP
			FETCH l_cursor INTO l_group_type, l_group_name, l_host_count, l_target_cursor;

			EXIT WHEN l_cursor%NOTFOUND;

			FETCH l_target_cursor BULK COLLECT INTO l_target_list;

			IF l_target_list IS NOT NULL AND l_target_list.EXISTS(1) THEN

				l_group_id := STORAGE_SUMMARY_DB.GET_HOST_GROUP_ID(l_target_list,l_group_type,l_group_name);
				
				-- Let the hostrollup job compute the group summary when it needs to, there is no need to do it here
				-- in view of package dependency and transaction integrity
				--STORAGE_SUMMARY.COMPUTE_GROUP_SUMMARY(l_group_id,l_group_name);

			END IF;
		
		END LOOP;

		CLOSE l_cursor;

	END LOOP;

	STORAGE_SUMMARY_DB.LOG_TIME('refresh_dc_lob_groups','refresh_dc_lob_groups','refresh_dc_lob_groups',' Inserted the new groups in ',STORAGE_SUMMARY_DB.GETTIME(l_time));

	---------------------------------------------------------------------------------
	-- Configuration for maintaining the parent , child relationship between groups 
	-- in the stormon_group_of_groups_table
	---------------------------------------------------------------------------------
	----------------------------------------------------------------------------------
	-- Populate the relationship table for the datacenter , Lob relationship
	----------------------------------------------------------------------------------

	-- Delete the previous parent child relationship for the parent and child group types passed in
	BEGIN

		STORAGE_SUMMARY_DB.LOG('refresh_dc_lob_groups','Refreshing groups with for relationship between REPORTING_ALL and  REPORTING_DATACENTER ');
		
		-- deleting the existing groups
		DELETE		FROM	stormon_group_of_groups_table
				WHERE	parent_id IN ( 
							SELECT	id
							FROM	stormon_group_table
							WHERE	type = 'REPORTING_ALL'
				)
				AND	child_id IN (
							SELECT	id
							FROM	stormon_group_table
							WHERE	type = 'REPORTING_DATACENTER'
				);
	
		STORAGE_SUMMARY_DB.PRINTSTMT(' Deleted groups for relationship between REPORTING_ALL and REPORTING_DATACENTER '||SQL%ROWCOUNT);

		-- inserting new groups
		INSERT INTO stormon_group_of_groups_table 			
			SELECT  DISTINCT parent.id,			        
			        child.id			        
			FROM    stormon_group_table child,
		        	stormon_group_table parent
			WHERE   child.type = 'REPORTING_DATACENTER'	
			AND     parent.type = 'REPORTING_ALL'
			AND     parent.name = 'ALL';	

		STORAGE_SUMMARY_DB.PRINTSTMT(' Inserted groups for relationship between REPORTING_ALL and REPORTING_DATACENTER '||SQL%ROWCOUNT);

	EXCEPTION
		WHEN OTHERS THEN
			STORAGE_SUMMARY_DB.PRINTSTMT('Failed to refresh groups for relationship between REPORTING_ALL and REPORTING_DATACENTER ');
			RAISE;
	END;


	-- Delete the previous parent child relationship for the parent and child group types passed in
	BEGIN

		STORAGE_SUMMARY_DB.LOG('refresh_dc_lob_groups','Refreshing groups with for relationship between REPORTING_ALL and  REPORTING_LOB ');

		DELETE		FROM	stormon_group_of_groups_table
				WHERE	parent_id IN ( 
							SELECT	id
							FROM	stormon_group_table
							WHERE	type = 'REPORTING_ALL'
				)
				AND	child_id IN (
							SELECT	id
							FROM	stormon_group_table
							WHERE	type = 'REPORTING_LOB'
				);
	
		STORAGE_SUMMARY_DB.PRINTSTMT(' Deleted groups for relationship between REPORTING_ALL and  REPORTING_LOB '||SQL%ROWCOUNT);

		-- inserting new groups
		INSERT INTO stormon_group_of_groups_table 			
			SELECT  DISTINCT parent.id,			        
			        child.id			        
			FROM    stormon_group_table child,
		        	stormon_group_table parent
			WHERE   child.type = 'REPORTING_LOB'	
			AND     parent.type = 'REPORTING_ALL'
			AND     parent.name = 'ALL';	

		STORAGE_SUMMARY_DB.PRINTSTMT(' Inserted groups for relationship between REPORTING_ALL and REPORTING_LOB '||SQL%ROWCOUNT);

	EXCEPTION
		WHEN OTHERS THEN
			STORAGE_SUMMARY_DB.PRINTSTMT('Failed to refresh groups for relationship between REPORTING_ALL and  REPORTING_LOB ');
			RAISE;
	END;


	-- Delete the previous parent child relationship for the parent and child group types passed in
	BEGIN

		STORAGE_SUMMARY_DB.LOG('refresh_dc_lob_groups','Refreshing groups with for relationship between REPORTING_DATACENTER and  REPORTING_DATACENTER_LOB ');

		DELETE		FROM	stormon_group_of_groups_table
				WHERE	parent_id IN ( 
							SELECT	id
							FROM	stormon_group_table
							WHERE	type = 'REPORTING_DATACENTER'
				)
				AND	child_id IN (
							SELECT	id
							FROM	stormon_group_table
							WHERE	type = 'REPORTING_DATACENTER_LOB'
				);
	
		STORAGE_SUMMARY_DB.PRINTSTMT(' Deleted groups for relationship between REPORTING_DATACENTER and  REPORTING_DATACENTER_LOB '||SQL%ROWCOUNT);

		-- inserting new groups
		INSERT INTO stormon_group_of_groups_table 			
			SELECT  DISTINCT parent.id,			        
			        child.id			        
			FROM    stormon_group_table child,
				(
			                SELECT	DISTINCT datacenter datacenter,
						escalation_group lob,
						datacenter||'-'||escalation_group datacenter_lob
			                FROM    mgmt_targets_view	
		        	) b,	
		        	stormon_group_table parent
			WHERE   child.type = 'REPORTING_DATACENTER_LOB'	
			AND     parent.type = 'REPORTING_DATACENTER'
			AND     parent.name = b.datacenter
			AND	child.name = b.datacenter_lob;	

		STORAGE_SUMMARY_DB.PRINTSTMT(' Inserted groups for relationship between REPORTING_DATACENTER and REPORTING_DATACENTER_LOB '||SQL%ROWCOUNT);

	EXCEPTION
		WHEN OTHERS THEN
			STORAGE_SUMMARY_DB.PRINTSTMT('Failed to refresh groups for relationship between REPORTING_DATACENTER and  REPORTING_DATACENTER_LOB ');
			RAISE;
	END;


	-- Delete the previous parent child relationship for the parent and child group types passed in
	BEGIN

		STORAGE_SUMMARY_DB.LOG('refresh_dc_lob_groups','Refreshing groups with for relationship between REPORTING_LOB and  REPORTING_DATACENTER_LOB ');

		DELETE		FROM	stormon_group_of_groups_table
				WHERE	parent_id IN ( 
							SELECT	id
							FROM	stormon_group_table
							WHERE	type = 'REPORTING_LOB'
				)
				AND	child_id IN (
							SELECT	id
							FROM	stormon_group_table
							WHERE	type = 'REPORTING_DATACENTER_LOB'
				);
	
		STORAGE_SUMMARY_DB.PRINTSTMT(' Deleted groups for relationship between REPORTING_LOB and  REPORTING_DATACENTER_LOB '||SQL%ROWCOUNT);

		-- inserting new groups
		INSERT INTO stormon_group_of_groups_table 			
			SELECT  DISTINCT parent.id,			        
			        child.id			        
			FROM    stormon_group_table child,
				(
			                SELECT	DISTINCT datacenter datacenter,
						escalation_group lob,
						datacenter||'-'||escalation_group datacenter_lob
			                FROM    mgmt_targets_view	
		        	) b,	
		        	stormon_group_table parent
			WHERE   child.type = 'REPORTING_DATACENTER_LOB'	
			AND     parent.type = 'REPORTING_LOB'
			AND     parent.name = b.lob
			AND	child.name = b.datacenter_lob;	

		STORAGE_SUMMARY_DB.PRINTSTMT(' Inserted groups for relationship between REPORTING_LOB and  REPORTING_DATACENTER_LOB '||SQL%ROWCOUNT);

	EXCEPTION
		WHEN OTHERS THEN
			STORAGE_SUMMARY_DB.PRINTSTMT('Failed to Refresh groups for relationship between REPORTING_LOB and  REPORTING_DATACENTER_LOB ');
			RAISE;
	END;


	STORAGE_SUMMARY_DB.LOG_TIME(
			'refresh_dc_lob_groups',
			'refresh_dc_lob_groups',
			'refresh_dc_lob_groups','Time taken to Refresh invalid group relationships from stormon_group_of_groups_table is ',STORAGE_SUMMARY_DB.GETTIME(l_time));


EXCEPTION

	WHEN OTHERS THEN

		RAISE_APPLICATION_ERROR(-20103,'DEBUG : Failed to refresh the dc lob groups ',TRUE);

END;


----------------------Creating the storage reporting views


DROP VIEW mgmt_storage_disk_view
/
DROP VIEW mgmt_storage_swraid_view
/
DROP VIEW mgmt_storage_volume_view 
/
DROP VIEW mgmt_storage_nfs_shared_view 
/
DROP VIEW mgmt_storage_nfs_view 
/
DROP VIEW mgmt_storage_localfs_view
/
DROP VIEW mgmt_storage_oracledb_view
/

----------------------------------------------
-- 	MGMT_STORAGE_ORACLEDB_VIEW
----------------------------------------------

CREATE OR REPLACE VIEW mgmt_storage_oracledb_view
(
	target_id,
	type,
	dbname,
	instance_id,
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
WHERE	type = 'ORACLE_DATABASE'
/


----------------------------------------------
-- 	MGMT_STORAGE_LOCALFS_VIEW
----------------------------------------------
CREATE OR REPLACE VIEW mgmt_storage_localfs_view
(
	target_id,
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
	type,
	filesystem,
	mountpoint,
	rawsizeb,
	sizeb,
	usedb,
	freeb,
	backup
FROM	storage_localfs_table
/
		
----------------------------------------------
-- 	MGMT_STORAGE_NFS_VIEW 
-- 	For exclusive mounts
----------------------------------------------
CREATE OR REPLACE VIEW mgmt_storage_nfs_view 
(
	target_id,
	filesystem,
	mountpoint,
	rawsizeb,
	sizeb,
	usedb,
	freeb,
	vendor,
	server,		
	nfscount,
	privilege
)
AS
SELECT	target_id,
	filesystem,
	mountpoint,
	rawsizeb,
	sizeb,
	usedb,
	freeb,
	vendor,
	server,
	nfscount,
	privilege	
FROM	storage_nfs_table
WHERE	mounttype = 'EXCLUSIVE'
/

----------------------------------------------
-- 	MGMT_STORAGE_NFS_SHARED_VIEW 
-- 	For exclusive mounts
----------------------------------------------
CREATE OR REPLACE VIEW mgmt_storage_nfs_shared_view
(
	target_id,
	filesystem,
	mountpoint,
	rawsizeb,
	sizeb,
	usedb,
	freeb,
	vendor,
	server,		
	nfscount,
	privilege
)
AS
SELECT	target_id,
	filesystem,
	mountpoint,
	rawsizeb,
	sizeb,
	usedb,
	freeb,
	vendor,
	server,
	nfscount,
	privilege	
FROM	storage_nfs_table
WHERE	mounttype = 'SHARED'
/


----------------------------------------------
-- 	MGMT_STORAGE_VOLUME_VIEW
----------------------------------------------
CREATE OR REPLACE VIEW mgmt_storage_volume_view 
(
	target_id,
	vendor,
	type,
	diskgroup,
	used_path,
	block_path,
	character_path,
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
	NULL,
	DECODE(type,'DISK','DISK/PARTITION',type) type,
	diskgroup,
	path,
	NULL,
	NULL,
	rawsizeb,
	sizeb,
	usedb,
	freeb,
	configuration,	
	freetype,
	backup
FROM	storage_volume_table
WHERE	type IN ('VOLUME','DISK')
/

----------------------------------------------
-- 	MGMT_STORAGE_SWRAID_VIEW
----------------------------------------------

CREATE OR REPLACE VIEW mgmt_storage_swraid_view
(
	target_id,
	vendor,
	type,
	used_path,
	block_path,
	character_path,
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
	NULL,
	type,
	path,
	NULL,
	NULL,
	rawsizeb,
	sizeb,
	usedb,
	freeb,
	configuration,
	freetype,
	backup
FROM	storage_swraid_Table
/

----------------------------------------------
-- 	mgmt_storage_disk_view
----------------------------------------------

CREATE OR REPLACE VIEW mgmt_storage_disk_view
(
	target_id,
	type,
	used_path,
	block_path_1,
	character_path_1,
	block_path_2,
	character_path_2,
	pseudo_parent_block_1,
	pseudo_parent_character_1,	
	rawsizeb,
	sizeb,
	usedb,
	freeb,
	configuration,
	freetype,
	backup,
	vendor,
	product,
	status,
	external_storage_system_id,
	external_storage_system_lun_id
)
AS
SELECT	target_id,
	type,
	path,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	rawsizeb,
	sizeb,
	usedb,
	freeb,
	configuration,
	freetype,
	backup,
	vendor,
	product,
	status,
	NULL,
	NULL
FROM	storage_disk_Table
/



-- Metrics to be loaded into the table MGMT_STORAGE_USAGE
-- For a OS DISK

Metrics that are common to any storage layer being instrumented.

Metric Column 		Mandatory	Relevance			Use
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
key_value			YES					A persistant identifier in the namespace of the server . The key_value will identify the the entity being instrumented.

global_unique_id		NO					A globally unique persistant identifier for a disk device. The same value is returned if the disk device is mounted on multiple servers.

type				YES					Refer to table below
sub_type			YES					Refer to table below

									  Layer being instrumented		TYPE			ENTITY	
									  ----------------------------------------------------------------------------------------------------	
									  Physical disk devices			OS_DISK			WHOLE_DISK, DISK_PARTITION, PSEUDO_DISK, 
																	DID_DEVICE
									  Software raid				SOFTWARE_RAID		META_DISK,
									  Volume Manager			VOLUME_MANAGER		VOLUME, PLEX, DISK_SLICE
									  Local Filesystem			FILESYSTEM		FILESYSTEM
									  NFS					FILESYSTEM		NFS
									  Oracle Database			ORACLE_DATABASE		DATAFILE, REDO_LOG_FILE
rawsizeb			YES					
sizeb				YES
usedb				YES
freeb				YES


Additional metrics for the following storage layers

1.	Disk devices
	
	  Metric Column 		Mandatory	Relevance			Use
	  ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	  vendor									
	  product
          configuration
	  device_status
          external_system_id
	  external_system_device_id
	  used_path
	  block_path_1
 	  character_path_1
	  block_path_2
	  character_path_2
	  pseudo_path_block
	  pseudo_path_character
	  
	
2.	Software Raid
	         
	  Metric Column 		Mandatory	Relevance			Use
	  ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------	  
	  vendor
          configuration
	  device_status
	  used_path
	  block_path_1
 	  character_path_1


3.	Volume Manager
	        
	  Metric Column 		Mandatory	Relevance			Use
	  ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	  name
	  vendor
          configuration
	  status
	  used_path
	  block_path_1
 	  character_path_1
	  disk_group
	  

4.	Local Filesystem
       	   	  
	  Metric Column 		Mandatory	Relevance			Use
	  ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	  fs_type
	  filesystem
	  mountpoint
 	  mount_privilege


4.	NFS

	  Metric Column 		Mandatory	Relevance			Use
	  ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	  global_unique_id	  
	  fs_type
	  filesystem
	  mountpoint
	  nfs_server
	  nfs_vendor
          mount_privilege
	  nfs_count



5.	Oracle Database server
          	  
	  Metric Column 		Mandatory	Relevance			Use
	  ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	  db_name
	  instance_id
	  tablespace_name
	  path	  
	  


------------------------------------------

-- Processing errors
select target_id, timestamp, message from storage_log where message like '%20103%' order by timestamp asc;

-- Processing times
SELECT	message, time_seconds , cnt FROM ( SELECT message, AVG(time_seconds) time_seconds , COUNT(*) cnt FROM storage_statistics GROUP BY message ORDER BY 2 DESC ) WHERE ROWNUM < 11
/

SELECT message, time_seconds FROM ( SELECT message, time_seconds FROM storage_statistics WHERE message = 'Summarized' ORDER BY time_seconds DESC ) WHERE ROWNUM < 20
/
