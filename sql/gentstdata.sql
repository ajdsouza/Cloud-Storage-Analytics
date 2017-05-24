SET SERVEROUT ON SIZE 1000000;

DROP TYPE tempobj
/

DROP TYPE hostobj
/

DROP DATABASE LINK storagedb
/

CREATE DATABASE LINK storagedb CONNECT TO storage_rep IDENTIFIED BY storage_rep USING 'emap_gitmon1.us.oracle.com'
/

CREATE TYPE tempobj AS OBJECT
(
	keyvalue	VARCHAR2(300),	
	type		VARCHAR2(128),
	filename	VARCHAR2(128),
	rawsizeb	NUMBER,
	sizeb		NUMBER,
	usedb		NUMBER,
	freeb		NUMBER,
	vendor		VARCHAR2(128),
	configuration	VARCHAR2(128)
)
/

CREATE TYPE hostObj AS OBJECT
(
	ID		NUMBER,		
	TYPE		VARCHAR2(256),	
	NAME		VARCHAR2(256),
	RAWSIZEB	NUMBER,
	SIZEB		NUMBER,
	USEDB		NUMBER,
	FREEB		NUMBER
)
/

CREATE TABLE temp_storage_detail AS SELECT * FROM storage_detail@storagedb
/

CREATE TABLE temp_keys AS
SELECT
        a.target_guid target_id,
        a.string_value slice_key,
        b.string_value filename 
FROM
        mgmt_current_metrics_frozen@storagedb a,
        mgmt_current_metrics_frozen@storagedb b
WHERE
        a.key_value = b.key_value
        AND a.target_guid = b.target_guid
        AND a.metric_guid = 1522
        AND b.metric_guid = 1506
/


WHENEVER SQLERROR EXIT ROLLBACK;

DELETE FROM storage_summaryObject
/

INSERT INTO storage_summaryObject
	SELECT
	summaryObject(
        name,
        id,
        timestamp,
        flag,
	issues,
        application_rawsize,
        application_size,
        application_free,
        oracle_database_rawsize,
        oracle_database_size,
        oracle_database_free,
        local_filesystem_rawsize,
        local_filesystem_size,
        local_filesystem_free,
        nfs_exclusive_size,
        nfs_exclusive_free,
        nfs_shared_size,                      
        nfs_shared_free,                       
        volumemanager_rawsize,
        volumemanager_size,
        volumemanager_free,
        swraid_rawsize,
        swraid_size,
        swraid_free,
        disk_rawsize,
        disk_size,
	disk_backup_rawsize,
	disk_backup_size,
        disk_free,
        rawsize,
        sizeb,
        free,
        vendor_emc_size,
        vendor_emc_rawsize,
        vendor_sun_size,
        vendor_sun_rawsize,
        vendor_hp_size,
        vendor_hp_rawsize,
        vendor_hitachi_size,
        vendor_hitachi_rawsize,
        vendor_others_size,
        vendor_others_rawsize,
        vendor_nfs_netapp_size,
        vendor_nfs_emc_size,
        vendor_nfs_sun_size,
        vendor_nfs_others_size
	)
	FROM storage_summaryobject@storagedb
/

DELETE FROM storage_summaryObject_history
/

INSERT INTO storage_summaryObject_history
	SELECT
	summaryObject
	(
        name,
        id,
        timestamp,
        flag,
	issues,
        application_rawsize,
        application_size,
        application_free,
        oracle_database_rawsize,
        oracle_database_size,
        oracle_database_free,
        local_filesystem_rawsize,
        local_filesystem_size,
        local_filesystem_free,
        nfs_exclusive_size,
        nfs_exclusive_free,
        nfs_shared_size,                      
        nfs_shared_free,                       
        volumemanager_rawsize,
        volumemanager_size,
        volumemanager_free,
        swraid_rawsize,
        swraid_size,
        swraid_free,
        disk_rawsize,
        disk_size,
	disk_backup_rawsize,
	disk_backup_size,
        disk_free,
        rawsize,
        sizeb,
        free,
        vendor_emc_size,
        vendor_emc_rawsize,
        vendor_sun_size,
        vendor_sun_rawsize,
       	vendor_hp_size,
        vendor_hp_rawsize,
        vendor_hitachi_size,
        vendor_hitachi_rawsize,
        vendor_others_size,
        vendor_others_rawsize,
        vendor_nfs_netapp_size,
        vendor_nfs_emc_size,
        vendor_nfs_sun_size,
        vendor_nfs_others_size
	)
	FROM storage_summaryobject_history@storagedb
/

DELETE FROM STORAGE_HOSTDETAIL
/

DELETE FROM STORAGE_DETAIL
/

DECLARE

TYPE vrec IS TABLE OF tempobj;

lrec vrec;

CURSOR C1 IS
SELECT	
	ID,	
	TYPE,	
	NAME,
	RAWSIZEB,
	SIZEB,
	USEDB,
	FREEB,
	ROWID rd
FROM	storage_hostdetail@storagedb;
	
BEGIN

FOR c1_rec IN C1 LOOP
	
	INSERT INTO storage_hostdetail
	VALUES(
	c1_rec.ID,	
	c1_rec.TYPE,	
	c1_rec.NAME,
	c1_rec.RAWSIZEB,
	c1_rec.SIZEB,
	c1_rec.USEDB,
	c1_rec.FREEB	
	);

	EXECUTE IMMEDIATE '
		SELECT
			tempobj(
			NULL,
			TYPE,
			FILENAME,
			RAWSIZEB,
			SIZEB,
			USEDB,
			FREEB,
			VENDOR,
			CONFIGURATION
			)
		FROM	temp_storage_detail
		WHERE	key = :1 '
		BULK COLLECT INTO lrec USING c1_rec.rd;
	
	IF NOT lrec.EXISTS(1) THEN
		GOTO end_loop;
	END IF;
	
	
	FOR i IN lrec.FIRST..lrec.LAST LOOP

		INSERT INTO storage_detail(
		target_id,
		detailtype,		
		backup,
		type,
		filename,
		rawsizeb,
		sizeb,
		usedb,
		freeb,
		vendor,
		configuration)
		VALUES(
		c1_rec.id,
		c1_rec.type,	
		'N',
		lrec(i).type,
		lrec(i).filename,
		lrec(i).rawsizeb,
		lrec(i).sizeb,
		lrec(i).usedb,
		lrec(i).freeb,
		lrec(i).vendor,
		lrec(i).configuration
		);

	END LOOP;

	<<end_loop>>
	NULL;
END LOOP;

END;
/

UPDATE storage_detail a
SET a.keyvalue =
	( 
		SELECT	b.slice_key
		FROM	temp_keys b
		WHERE
		a.filename = b.filename
		AND a.target_id = b.target_id
	)
WHERE
	a.detailtype = '_DISKS'
/

COMMIT;

-- Create Dummy targets that share data

DECLARE

TYPE vrec IS TABLE OF tempobj;
TYPE hrec IS TABLE OF hostObj;

lrec		vrec;
l_hrec		hrec;

-- Size greater than a TB
CURSOR C1 IS
SELECT	
	hostobj(
	TARGET_ID,	
	TYPE,	
	NAME,
	RAWSIZEB,
	SIZEB,
	USEDB,
	FREEB
	)
FROM	storage_hostdetail
WHERE	type = '_DISKS'
	AND sizeb > 1000000000;

l_newid	NUMBER;	

BEGIN

	OPEN C1;
	FETCH C1 BULK COLLECT INTO l_hrec;
	CLOSE C1;

FOR k IN l_hrec.FIRST..l_hrec.LAST LOOP

	-- 3 hosts in common with this one
	FOR j IN 1..3 LOOP
	
		l_newid := l_hrec(k).ID+ (1000000*j);
	
		INSERT INTO storage_hostdetail
		VALUES(
		l_newid,	
		l_hrec(k).TYPE,	
		l_hrec(k).NAME,
		l_hrec(k).RAWSIZEB,
		l_hrec(k).SIZEB,
		l_hrec(k).USEDB,
		l_hrec(k).FREEB	
		);

		EXECUTE IMMEDIATE '
			SELECT
			tempobj(
			KEYVALUE,
			TYPE,
			FILENAME,
			RAWSIZEB,
			SIZEB,
			USEDB,
			FREEB,
			VENDOR,
			CONFIGURATION
			)
		FROM	storage_detail
		WHERE	target_id = :1 
		AND	detailtype = :2'
		BULK COLLECT INTO lrec USING l_hrec(k).id,l_hrec(k).type;
	
		IF NOT lrec.EXISTS(1) THEN

			DBMS_OUTPUT.PUT_LINE('NO DETAILS FOR '||l_hrec(k).id||' '||l_hrec(k).type);
			GOTO end_loop;

		END IF;
	
		DBMS_OUTPUT.PUT_LINE('DETAILS FOR '||l_hrec(k).id||' '||lrec.COUNT);
	
		FOR i IN lrec.FIRST..lrec.LAST LOOP

		INSERT INTO storage_detail(
		target_id,
		detailtype,		
		keyvalue,
		backup,
		type,
		filename,
		rawsizeb,
		sizeb,
		usedb,
		freeb,
		vendor,
		configuration)
		VALUES(
		l_newid,
		l_hrec(k).type,	
		lrec(i).keyvalue,
		'N',
		lrec(i).type,
		lrec(i).filename,
		lrec(i).rawsizeb,
		lrec(i).sizeb,
		lrec(i).usedb,
		lrec(i).freeb,
		lrec(i).vendor,
		lrec(i).configuration
		);

		END LOOP;
		
		COMMIT;

		<<end_loop>>
		NULL;
	END LOOP;

END LOOP;

END;
/

COMMIT;


DROP TABLE temp_keys
/

DROP TYPE hostobj
/

DROP TYPE tempobj
/

DROP TABLE temp_storage_detail
/

DROP DATABASE LINK storagedb
/
