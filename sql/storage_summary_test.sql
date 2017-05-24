--  
--
-- Copyright  (c) 2001,2002  Oracle Corporation All rights reserved 
--
--
--
-- $Id: storage_summary_test.sql,v 1.29 2003/01/14 00:23:15 ajdsouza Exp $ 
--
--
-- NAME  
--	 storage_test.sql
--
-- DESC 
--  Creates the package storage_test 
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



CREATE OR REPLACE PACKAGE storage_test AS

PROCEDURE summary(v_hostname VARCHAR2);

PROCEDURE summary(v_hosttable stringTable); 

PROCEDURE groupsummary(v_hosttable stringTable); 

PROCEDURE detail(v_hostname VARCHAR2);

PROCEDURE onehoststoragehistory (
				v_period	VARCHAR2,
				v_storage_type	VARCHAR2,
				v_hostname	VARCHAR2
				);

PROCEDURE groupstoragehistory(
				v_period	VARCHAR2,
				v_storage_type	VARCHAR2,	
				v_hostTable	stringTable	
			);

END storage_test;
/


CREATE OR REPLACE PACKAGE BODY storage_test AS

p_tlast INTEGER := 0;

-----------------------------------------------------------------------
--
--  Print a storageSummaryTable
--
-----------------------------------------------------------------------
PROCEDURE print_summary( v_targetid  VARCHAR2 ) IS


BEGIN
		
	FOR rec IN (SELECT * FROM storage_summaryObject WHERE id = v_targetid) 
	LOOP


		DBMS_OUTPUT.PUT_line('**********************************************');

		DBMS_OUTPUT.PUT_line('Storage Summary Report');
		DBMS_OUTPUT.PUT_line('Host : '||rec.name);
		DBMS_OUTPUT.PUT_line('Host Id : '||rec.id);
		DBMS_OUTPUT.PUT_line('Timestammp : '||TO_CHAR(rec.timestamp,'DD-MON-YY HH24'));
		DBMS_OUTPUT.PUT_line('Collection Timestamp : '||TO_CHAR(rec.collection_timestamp,'DD-MON-YY HH24'));
		DBMS_OUTPUT.PUT_LINE('Flag : '||rec.summaryFlag);
		DBMS_OUTPUT.PUT_LINE('Issues: '||NVL(rec.issues,0));
		DBMS_OUTPUT.PUT_LINE('Warnings: '||NVL(rec.warnings,0));

		DBMS_OUTPUT.PUT_line('------------------------------------');
		
		DBMS_OUTPUT.PUT_line('Total ');
		DBMS_OUTPUT.PUT_line('Total Raw Size			'||rec.rawsize);
		DBMS_OUTPUT.PUT_line('Total Size			'||rec.sizeb);
		DBMS_OUTPUT.PUT_line('Total Used			'||rec.used);
		DBMS_OUTPUT.PUT_line('Total Free Space	 		'||rec.free);

		DBMS_OUTPUT.PUT_line('------------------------------------');
		
		DBMS_OUTPUT.PUT_line('Disks');
		DBMS_OUTPUT.PUT_line('Disks RawSize			'||rec.disk_rawsize);
		DBMS_OUTPUT.PUT_line('Disks Size			'||rec.disk_size);
		DBMS_OUTPUT.PUT_line('Disks Used			'||rec.disk_used);
		DBMS_OUTPUT.PUT_line('Disks Free			'||rec.disk_free);

		DBMS_OUTPUT.PUT_line('------------------------------------');

		DBMS_OUTPUT.PUT_line('Backup Disks');
		DBMS_OUTPUT.PUT_line('Backup Disks Rawsize		'||rec.disk_backup_rawsize);
		DBMS_OUTPUT.PUT_line('Backup Disks Size			'||rec.disk_backup_size);
		DBMS_OUTPUT.PUT_line('Backup Disks Used			'||rec.disk_backup_used);
		DBMS_OUTPUT.PUT_line('Backup Disks Free			'||rec.disk_backup_free);

		DBMS_OUTPUT.PUT_line('------------------------------------');
		
		DBMS_OUTPUT.PUT_line('Volume Manager ');
		DBMS_OUTPUT.PUT_line('Volume Manager Raw Size		'||rec.volumemanager_rawsize);
		DBMS_OUTPUT.PUT_line('Volume Manager Size		'||rec.volumemanager_size);
		DBMS_OUTPUT.PUT_line('Volume Manager Used		'||rec.volumemanager_used);
		DBMS_OUTPUT.PUT_line('Volume Manager Free		'||rec.volumemanager_free);
		
		DBMS_OUTPUT.PUT_line('-------------------------------------');
		
		DBMS_OUTPUT.PUT_line('SW RAID ');
		DBMS_OUTPUT.PUT_line('SW RAID Raw Size			'||rec.swraid_rawsize);
		DBMS_OUTPUT.PUT_line('SW RAID Size			'||rec.swraid_size);
		DBMS_OUTPUT.PUT_line('SW RAID Used			'||rec.swraid_used);
		DBMS_OUTPUT.PUT_line('SW RAID Free			'||rec.swraid_free);

		DBMS_OUTPUT.PUT_line('-------------------------------------');	
		
		DBMS_OUTPUT.PUT_line('Filesystems');

		DBMS_OUTPUT.PUT_line('Filesystems Rawsize		'||rec.local_filesystem_rawsize);
		DBMS_OUTPUT.PUT_line('Filesystems Size			'||rec.local_filesystem_size);
		DBMS_OUTPUT.PUT_line('Filesystems Used			'||rec.local_filesystem_used);
		DBMS_OUTPUT.PUT_line('Filesystems Free			'||rec.local_filesystem_free);
		
		DBMS_OUTPUT.PUT_line('-------------------------------------');
		
		DBMS_OUTPUT.PUT_line('Oracle Database ');

		DBMS_OUTPUT.PUT_line('Database Raw size			'||rec.oracle_database_rawsize);
		DBMS_OUTPUT.PUT_line('Database Size			'||rec.oracle_database_size);
		DBMS_OUTPUT.PUT_line('Database Used			'||rec.oracle_database_used);
		DBMS_OUTPUT.PUT_line('Database Free 			'||rec.oracle_database_free);
		
		DBMS_OUTPUT.PUT_line('-------------------------------------');
		
		DBMS_OUTPUT.PUT_line('NFS ');
		DBMS_OUTPUT.PUT_line('NFS Exclusive Size 		'||rec.nfs_exclusive_size);
		DBMS_OUTPUT.PUT_line('NFS Exclusive Used 		'||rec.nfs_exclusive_used);
		DBMS_OUTPUT.PUT_line('NFS Exclusive Free 		'||rec.nfs_exclusive_free);

		DBMS_OUTPUT.PUT_line('NFS Shared Size 		'||rec.nfs_shared_size);
		DBMS_OUTPUT.PUT_line('NFS Shared Used 		'||rec.nfs_shared_used);
		DBMS_OUTPUT.PUT_line('NFS Shared Free 		'||rec.nfs_shared_free);

		DBMS_OUTPUT.PUT_line('-------------------------------------');
		
		DBMS_OUTPUT.PUT_line('Disk Storage by Vendor');
		DBMS_OUTPUT.PUT_line('EMC size			'||rec.vendor_emc_size);
		DBMS_OUTPUT.PUT_line('EMC rawsize		'||rec.vendor_emc_rawsize);
		DBMS_OUTPUT.PUT_line('SUN size			'||rec.vendor_sun_size);
		DBMS_OUTPUT.PUT_line('SUN rawsize		'||rec.vendor_sun_rawsize);
		DBMS_OUTPUT.PUT_line('HP size			'||rec.vendor_hp_size);
		DBMS_OUTPUT.PUT_line('HP rawsize		'||rec.vendor_hp_rawsize);
		DBMS_OUTPUT.PUT_line('Hitachi size		'||rec.vendor_hitachi_size);
		DBMS_OUTPUT.PUT_line('Hitachi rawsize		'||rec.vendor_hitachi_rawsize);
		DBMS_OUTPUT.PUT_line('Other Vendors size	'||rec.vendor_others_size);
		DBMS_OUTPUT.PUT_line('Other Vendors rawsize	'||rec.vendor_others_rawsize);

		DBMS_OUTPUT.PUT_line('-------------------------------------');

		DBMS_OUTPUT.PUT_line('NFS Exclusive Storage by Vendor');
		DBMS_OUTPUT.PUT_line('NFS NetApp 		'||rec.vendor_nfs_netapp_size);
		DBMS_OUTPUT.PUT_line('NFS EMC 			'||rec.vendor_nfs_emc_size);
		DBMS_OUTPUT.PUT_line('NFS SUN 			'||rec.vendor_nfs_sun_size);
		DBMS_OUTPUT.PUT_line('NFS Others 		'||rec.vendor_nfs_others_size);

	END LOOP;


END print_summary;


PROCEDURE printhistory( v_id VARCHAR2 , p_period  VARCHAR2 , p_storage_type VARCHAR2)  IS

--p_period		VARCHAR2(20) := 'LAST-WEEK';
--p_storage_type	VARCHAR2(20) := 'ALL-DATABASES';
--l_id			VARCHAR2(20) := '10000001';

l_historycursor	sys_refcursor;
l_npoints	INTEGER;
l_tablename	VARCHAR2(50);
l_flds		VARCHAR2(500);
l_sqlstmt	VARCHAR2(2000);

l_collection_timestamp DATE;
l_attachedsize	NUMBER(16);
l_size		NUMBER(16);
l_used		NUMBER(16);

BEGIN

	IF UPPER(p_period) = 'LAST-WEEK' THEN

		l_npoints := 8;
		l_tablename := 'stormon_history_day_view';

	ELSIF UPPER(p_period) = 'LAST-MONTH' THEN

		l_npoints := 31;
		l_tablename := 'stormon_history_day_view';

	ELSIF UPPER(p_period) = 'LAST-QUARTER' THEN

		l_npoints := 14;
		l_tablename := 'stormon_history_week_view';

	ELSE
		l_npoints := 53;
		l_tablename := 'stormon_history_week_view';

	END IF;

	IF UPPER(p_storage_type) = 'ALL-DATABASES' THEN
		
		l_flds := ' collection_timestamp, sizeb, oracle_database_size , oracle_database_used ';
		
	ELSIF UPPER(p_storage_type) = 'LOCAL-FILE-SYSTEM' THEN

		l_flds := ' collection_timestamp, sizeb, local_filesystem_size , local_filesystem_used ';

	ELSIF UPPER(p_storage_type) = 'DEDICATED-NFS' THEN

		l_flds := ' collection_timestamp, sizeb, nfs_exclusive_size , nfs_exclusive_used ';

	ELSIF UPPER(p_storage_type) = 'ALL-DISKS' THEN

		l_flds := ' collection_timestamp, sizeb, disk_size , disk_used ';

	ELSE 

		l_flds := ' collection_timesatmp, sizeb , disk_size , disk_used ';

	END IF;	
	
	l_sqlstmt := 'SELECT '||l_flds||' FROM '||l_tablename||' WHERE id = :id AND ROWNUM < :npoints';

	DBMS_OUTPUT.PUT_LINE('History for '||v_id||' '||p_storage_type||' '||p_period);

	OPEN l_historycursor FOR l_sqlstmt USING v_id,l_npoints;

	LOOP
		FETCH l_historycursor INTO l_collection_timestamp,l_attachedsize, l_size, l_used;
		DBMS_OUTPUT.PUT_LINE(l_collection_timestamp||' '||l_attachedsize||' '||l_size||' '||l_used);
		EXIT WHEN l_historycursor%NOTFOUND;

	END LOOP;

	CLOSE l_historycursor;

END printhistory;

-----------------------------------------------------------------------
--
--  Print a storageObject
--
-----------------------------------------------------------------------
PROCEDURE detail(v_hostname VARCHAR2 ) IS

CURSOR c_disk(c_targetid  VARCHAR2) IS
SELECT	type,
	path,
	rawsizeb,
	sizeb,
	usedb,
	freeb,
	configuration,
	freetype,
	backup,
	vendor
FROM	storage_disk_view
WHERE	target_id = c_targetid;

CURSOR c_swraid(c_targetid  VARCHAR2) IS
SELECT	type,
	path,
	rawsizeb,
	sizeb,
	usedb,
	freeb,
	configuration,
	freetype,
	backup
FROM	storage_swraid_view
WHERE	target_id = c_targetid;

CURSOR c_volume(c_targetid  VARCHAR2) IS
SELECT	type,
	path,
	rawsizeb,
	sizeb,
	usedb,
	freeb,
	configuration,
	freetype,
	backup	
FROM	storage_volume_view
WHERE	target_id = c_targetid;

CURSOR c_localfs(c_targetid  VARCHAR2) IS
SELECT	type,
	filesystem,
	mountpoint,
	rawsizeb,
	sizeb,
	usedb,
	freeb,
	backup			
FROM	storage_localfs_view
WHERE	target_id = c_targetid;

CURSOR c_nfs(c_targetid  VARCHAR2) IS
SELECT	type,
	filesystem,
	mountpoint,
	rawsizeb,
	sizeb,
	usedb,
	freeb,	
	vendor			
FROM	storage_nfs_view
WHERE	target_id = c_targetid;

CURSOR c_oracledb(c_targetid  VARCHAR2) IS
SELECT	appname,
	dbid,
	tablespace,
	filename,
	rawsizeb,
	sizeb,
	usedb,
	freeb,
	backup	
FROM	storage_oracledb_view
WHERE	target_id = c_targetid
ORDER BY
dbid,
DECODE(appname,'TOTAL',1,2) DESC;

CURSOR c_issues(c_targetid VARCHAR2) IS
SELECT	type,
	timestamp,
	message
FROM	storage_issues_view
WHERE	id = c_targetid
ORDER BY 
type,
timestamp DESC;

l_targetid	VARCHAR2(256);

BEGIN
	
	SELECT	target_id
	INTO	l_targetid
	FROM	mgmt_targets_view
	WHERE	target_name = v_hostname;

	DBMS_OUTPUT.PUT_LINE('TARGET ID   :		'||l_targetid);
	
	FOR rec IN ( SELECT type,name,rawsizeb,sizeb,usedb,freeb FROM stormon_hostdetail_view WHERE id = l_targetid )
	LOOP

		DBMS_OUTPUT.PUT_LINE('**************************************************');
		DBMS_OUTPUT.PUT_LINE('TYPE :		'||rec.type);
		DBMS_OUTPUT.PUT_LINE('TYPE :		'||rec.name);
		DBMS_OUTPUT.PUT_LINE('RAW SIZE :	'||rec.rawsizeb);
		DBMS_OUTPUT.PUT_LINE('SIZE :		'||rec.sizeb);
		DBMS_OUTPUT.PUT_LINE('USED :		'||rec.usedb);
		DBMS_OUTPUT.PUT_LINE('FREE :		'||rec.freeb);
		
		CASE rec.type

			WHEN '_DISKS' THEN

				FOR c1_rec IN c_disk(l_targetid) LOOP
					DBMS_OUTPUT.PUT_line('-------------------------------------');
					DBMS_OUTPUT.PUT_LINE('		TYPE	:'||c1_rec.type);
					DBMS_OUTPUT.PUT_LINE('		PATH	:'||c1_rec.path);
					DBMS_OUTPUT.PUT_LINE('		RAWSIZE	:'||c1_rec.rawsizeb);
					DBMS_OUTPUT.PUT_LINE('		SIZE	:'||c1_rec.sizeb);
					DBMS_OUTPUT.PUT_LINE('		USED	:'||c1_rec.usedb);
					DBMS_OUTPUT.PUT_LINE('		FREE	:'||c1_rec.freeb);
					DBMS_OUTPUT.PUT_LINE('		CONFIG	:'||c1_rec.configuration);
					DBMS_OUTPUT.PUT_LINE('		VENDOR	:'||c1_rec.vendor);
					DBMS_OUTPUT.PUT_LINE('		FREETYPE:'||c1_rec.freetype);										
					DBMS_OUTPUT.PUT_LINE('		BACKUP	:'||c1_rec.backup);

				END LOOP;

			WHEN '_SWRAID' THEN

				FOR c1_rec IN c_swraid(l_targetid) LOOP
					DBMS_OUTPUT.PUT_line('-------------------------------------');	
					DBMS_OUTPUT.PUT_LINE('		TYPE	:'||c1_rec.type);
					DBMS_OUTPUT.PUT_LINE('		PATH	:'||c1_rec.path);
					DBMS_OUTPUT.PUT_LINE('		RAWSIZE	:'||c1_rec.rawsizeb);
					DBMS_OUTPUT.PUT_LINE('		SIZE	:'||c1_rec.sizeb);
					DBMS_OUTPUT.PUT_LINE('		USED	:'||c1_rec.usedb);
					DBMS_OUTPUT.PUT_LINE('		FREE	:'||c1_rec.freeb);
					DBMS_OUTPUT.PUT_LINE('		CONFIG	:'||c1_rec.configuration);
					DBMS_OUTPUT.PUT_LINE('		FREETYPE:'||c1_rec.freetype);
					DBMS_OUTPUT.PUT_LINE('		BACKUP	:'||c1_rec.backup);									

				END LOOP;

			WHEN '_VOLUME_MANAGER' THEN

				FOR c1_rec IN c_volume(l_targetid) LOOP
					DBMS_OUTPUT.PUT_line('-------------------------------------');		
					DBMS_OUTPUT.PUT_LINE('		TYPE	:'||c1_rec.type);		
					DBMS_OUTPUT.PUT_LINE('		PATH	:'||c1_rec.path);
					DBMS_OUTPUT.PUT_LINE('		RAWSIZE	:'||c1_rec.rawsizeb);
					DBMS_OUTPUT.PUT_LINE('		SIZE	:'||c1_rec.sizeb);
					DBMS_OUTPUT.PUT_LINE('		USED	:'||c1_rec.usedb);
					DBMS_OUTPUT.PUT_LINE('		FREE	:'||c1_rec.freeb);
					DBMS_OUTPUT.PUT_LINE('		CONFIG	:'||c1_rec.configuration);
					DBMS_OUTPUT.PUT_LINE('		FREETYPE:'||c1_rec.freetype);
					DBMS_OUTPUT.PUT_LINE('		BACKUP	:'||c1_rec.backup);									

				END LOOP;

			WHEN '_LOCAL_FILESYSTEM' THEN

				FOR c1_rec IN c_localfs(l_targetid) LOOP
					DBMS_OUTPUT.PUT_line('-------------------------------------');		
					DBMS_OUTPUT.PUT_LINE('		TYPE		:'||c1_rec.type);
					DBMS_OUTPUT.PUT_LINE('		FILESYSTEM	:'||c1_rec.filesystem);
					DBMS_OUTPUT.PUT_LINE('		MOUNTPOINT	:'||c1_rec.mountpoint);
					DBMS_OUTPUT.PUT_LINE('		RAWSIZE		:'||c1_rec.rawsizeb);
					DBMS_OUTPUT.PUT_LINE('		SIZE		:'||c1_rec.sizeb);
					DBMS_OUTPUT.PUT_LINE('		USED		:'||c1_rec.usedb);
					DBMS_OUTPUT.PUT_LINE('		FREE		:'||c1_rec.freeb);
					DBMS_OUTPUT.PUT_LINE('		BACKUP		:'||c1_rec.backup);									

				END LOOP;


			WHEN 'NFS_EXCLUSIVE' THEN

				FOR c1_rec IN c_nfs(l_targetid) LOOP
					DBMS_OUTPUT.PUT_line('-------------------------------------');		
					DBMS_OUTPUT.PUT_LINE('		TYPE		:'||c1_rec.type);
					DBMS_OUTPUT.PUT_LINE('		FILESYSTEM	:'||c1_rec.filesystem);
					DBMS_OUTPUT.PUT_LINE('		MOUNTPOINT	:'||c1_rec.mountpoint);
					DBMS_OUTPUT.PUT_LINE('		RAWSIZE		:'||c1_rec.rawsizeb);
					DBMS_OUTPUT.PUT_LINE('		SIZE		:'||c1_rec.sizeb);
					DBMS_OUTPUT.PUT_LINE('		USED		:'||c1_rec.usedb);
					DBMS_OUTPUT.PUT_LINE('		FREE		:'||c1_rec.freeb);
					DBMS_OUTPUT.PUT_LINE('		VENDOR		:'||c1_rec.vendor);									

				END LOOP;

			WHEN '_ALL_DATABASES' THEN

				FOR c1_rec IN c_oracledb(l_targetid) LOOP
					DBMS_OUTPUT.PUT_line('-------------------------------------');		
					DBMS_OUTPUT.PUT_LINE('		DBNAME		:'||c1_rec.appname);
					DBMS_OUTPUT.PUT_LINE('		DBID		:'||c1_rec.dbid);
					DBMS_OUTPUT.PUT_LINE('		TABLESPACE	:'||c1_rec.tablespace);
					DBMS_OUTPUT.PUT_LINE('		FILENAME	:'||c1_rec.filename);
					DBMS_OUTPUT.PUT_LINE('		RAWSIZE		:'||c1_rec.rawsizeb);
					DBMS_OUTPUT.PUT_LINE('		SIZE		:'||c1_rec.sizeb);
					DBMS_OUTPUT.PUT_LINE('		USED		:'||c1_rec.usedb);
					DBMS_OUTPUT.PUT_LINE('		FREE		:'||c1_rec.freeb);
					DBMS_OUTPUT.PUT_LINE('		BACKUP		:'||c1_rec.backup);

				END LOOP;

			ELSE NULL;

		END CASE;

	END LOOP;

	DBMS_OUTPUT.PUT_LINE('ISSUES:');
	FOR c1_rec IN c_issues(l_targetid) LOOP
	
		DBMS_OUTPUT.PUT_LINE(TO_CHAR(c1_rec.timestamp,'DD-MON HH:MI')||'	'||c1_rec.message);

	END LOOP;


END detail;



-----------------------------------------------------------------------
--
--  Summary report for a List of hosts, along with group summary
--
-----------------------------------------------------------------------
PROCEDURE summary(v_hostname VARCHAR2) IS

l_targetid 	VARCHAR2(20);

BEGIN		
	SELECT	target_id
	INTO	l_targetid
	FROM	mgmt_targets_view
	WHERE	target_name = v_hostname;

	PRINT_SUMMARY(l_targetid);

END summary;


PROCEDURE summary(v_hosttable stringTable) IS

BEGIN

	IF v_hostTable IS NULL OR NOT v_hostTable.EXISTS(1) THEN
		RETURN;
	END IF;

	FOR i IN v_hostTable.FIRST..v_hostTable.LAST 
	LOOP		
		BEGIN
			SUMMARY(v_hostTable(i));
		EXCEPTION
			WHEN OTHERS THEN
				NULL;
		END;
	END LOOP;

END summary;


PROCEDURE groupsummary(v_hosttable stringTable) IS

l_targetid	VARCHAR2(20);

BEGIN

	l_targetid := STORAGE_REPORT.GETGROUPID(v_hostTable);

	PRINT_SUMMARY(l_targetid);

END groupsummary;

-----------------------------------------------------------------------
--
--  History for a host
--
-----------------------------------------------------------------------
PROCEDURE onehoststoragehistory (
				v_period	VARCHAR2,
				v_storage_type	VARCHAR2,
				v_hostname	VARCHAR2
				)IS

l_targetid	VARCHAR2(20);

BEGIN
	SELECT	target_id
	INTO	l_targetid
	FROM	mgmt_targets_view
	WHERE	target_name = v_hostname;
	
	PRINTHISTORY(l_targetid,v_period,v_storage_type);

END onehoststoragehistory;

-----------------------------------------------------------------------
--
--  History for a List of hosts
--
-----------------------------------------------------------------------
PROCEDURE groupstoragehistory (
				v_period	VARCHAR2,
				v_storage_type	VARCHAR2,
				v_hostTable	stringTable
				) IS
l_targetid	VARCHAR2(20);

BEGIN

	l_targetid := STORAGE_REPORT.GETGROUPID(v_hostTable);

	PRINTHISTORY(l_targetid,v_period,v_storage_type);

END groupstoragehistory;


END storage_test;
/


