
DROP TABLE storage_summary_temp 
/
DROP TABLE storage_summary_history 
/
DROP TYPE summaryObject_temp
/
DROP TABLE storage_hostdetail_temp
/
DROP TABLE storage_detail_temp
/

CREATE TYPE summaryObject_temp AS OBJECT (
	name				VARCHAR2(128),
	id				VARCHAR2(128),
	timestamp			DATE,
	flag				VARCHAR2(1),
	issues				VARCHAR2(1),
	application_rawsize		NUMBER,
	application_size		NUMBER,
	application_free		NUMBER,
	oracle_database_rawsize		NUMBER,
	oracle_database_size		NUMBER,
	oracle_database_free		NUMBER,
	local_filesystem_rawsize	NUMBER,
	local_filesystem_size		NUMBER,
	local_filesystem_free		NUMBER,
	nfs_exclusive_size		NUMBER,
	nfs_exclusive_free		NUMBER,
	nfs_shared_size			NUMBER,
	nfs_shared_free			NUMBER,
	volumemanager_rawsize		NUMBER,
	volumemanager_size		NUMBER,
	volumemanager_free		NUMBER,
	swraid_rawsize			NUMBER,
	swraid_size			NUMBER,
	swraid_free			NUMBER,
	disk_rawsize			NUMBER,
	disk_size			NUMBER,
	disk_free			NUMBER,
	rawsize				NUMBER,
	sizeb				NUMBER,
	free				NUMBER,
	vendor_emc_size			NUMBER,
	vendor_emc_rawsize		NUMBER,
	vendor_sun_size			NUMBER,
	vendor_sun_rawsize		NUMBER,
	vendor_others_size		NUMBER,
	vendor_others_rawsize		NUMBER,
	vendor_nfs_netapp_size		NUMBER,
	vendor_nfs_emc_size		NUMBER,
	vendor_nfs_sun_size		NUMBER,
	vendor_nfs_others_size		NUMBER
)
/

CREATE TABLE storage_summary_temp OF summaryObject_temp
/
CREATE TABLE storage_summary_history OF summaryObject_temp
/
CREATE TABLE storage_hostdetail_temp AS SELECT * FROM storage_hostdetail WHERE 1 = 2
/
CREATE TABLE storage_detail_temp AS SELECT * FROM storage_detail WHERE 1 = 2
/

DECLARE

	CURSOR c1 IS 
	SELECT 
		ROWID,ID,TYPE,NAME,RAWSIZEB,SIZEB,USEDB,FREEB
	FROM	storage_hostdetail;

	l_newrowid	ROWID;

BEGIN

	FOR c1_rec IN c1 LOOP
		INSERT INTO storage_hostdetail_temp
		VALUES(c1_rec.ID,c1_rec.TYPE,c1_rec.NAME,c1_rec.RAWSIZEB,c1_rec.SIZEB,c1_rec.USEDB,c1_Rec.FREEB) RETURNING ROWID INTO l_newrowid;
			
		INSERT INTO storage_detail_temp
		SELECT
			l_newrowid,
			id,
			type,
			filename,
			rawsizeb,
			sizeb,
			usedb,        
			freeb,
			appName,
			tablespace,
			pseudoparent,
			vendor,
			product,
			privilege,
			mountpoint,
			pathcount,
			configuration
		FROM	storage_detail
			WHERE key = c1_rec.ROWID;
		
	END LOOP;

END;
/


INSERT INTO storage_summary_temp
SELECT 
	summaryobject_temp
	(
	name				,
	id				,
	timestamp			,
	flag				,
	NULL				,
	application_size		,
	application_size		,
	application_free		,
	oracle_database_size		,
	oracle_database_size		,
	oracle_database_free		,
	local_filesystem_size		,
	local_filesystem_size		,
	local_filesystem_free		,
	nfs_exclusive_size		,
	nfs_exclusive_free		,
	nfs_shared_size			,
	nfs_shared_free			,
	volumemanager_rawsize		,
	volumemanager_size		,
	volumemanager_free		,
	swraid_rawsize			,
	swraid_size			,
	swraid_free			,
	disk_rawsize			,
	disk_size			,
	disk_free			,
	rawsize				,
	sizeb				,
	free				,
	vendor_emc_size			,
	vendor_emc_rawsize		,
	vendor_sun_size			,
	vendor_sun_rawsize		,
	vendor_others_size		,
	vendor_others_rawsize		,
	vendor_nfs_netapp_size		,
	vendor_nfs_emc_size		,
	vendor_nfs_sun_size		,
	vendor_nfs_others_size		
	)
FROM
	storage_summaryObject
/

INSERT INTO storage_summary_history
SELECT 
	summaryobject_temp
	(
	name				,
	id				,
	timestamp			,
	flag				,
	NULL				,
	application_size		,
	application_size		,
	application_free		,
	oracle_database_size		,
	oracle_database_size		,
	oracle_database_free		,
	local_filesystem_size		,
	local_filesystem_size		,
	local_filesystem_free		,
	nfs_exclusive_size		,
	nfs_exclusive_free		,
	nfs_shared_size			,
	nfs_shared_free			,
	volumemanager_rawsize		,
	volumemanager_size		,
	volumemanager_free		,
	swraid_rawsize			,
	swraid_size			,
	swraid_free			,
	disk_rawsize			,
	disk_size			,
	disk_free			,
	rawsize				,
	sizeb				,
	free				,
	vendor_emc_size			,
	vendor_emc_rawsize		,
	vendor_sun_size			,
	vendor_sun_rawsize		,
	vendor_others_size		,
	vendor_others_rawsize		,
	vendor_nfs_netapp_size		,
	vendor_nfs_emc_size		,
	vendor_nfs_sun_size		,
	vendor_nfs_others_size		
	)
FROM
	storage_summaryObject_history
/
