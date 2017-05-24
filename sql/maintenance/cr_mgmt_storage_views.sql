--  
--
-- Copyright  (c) 2001,2002  Oracle Corporation All rights reserved 
--
--
--
-- $Id: cr_mgmt_storage_views.sql,v 1.1 2003/11/18 05:41:11 ajdsouza Exp $ 
--
--
-- NAME  
--	 cr_mgmt_storage_views.sql
--
-- DESC 
--  	Create the mozart storage views to fetch data from 9i stormon repository
--
--
-- FUNCTIONS
--
--
-- NOTES
--
--
-- MODIFIED	(MM/DD/YY)
-- ajdsouza	11/17/03 	- Created


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


