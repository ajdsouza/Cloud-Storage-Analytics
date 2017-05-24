--  
--
-- Copyright  (c) 2001,2002  Oracle Corporation All rights reserved 
--
--
--
-- $Id: cr_mgmt_storage_views.sql,v 1.5 2004/01/07 21:55:05 ajdsouza Exp $ 
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


-----------------------------------------------
- 	MGMT_STORAGE_LOCALFS_VIEW
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


CREATE OR REPLACE VIEW mgmt$storage_map_top_down
(
	rank,
	indent_level,
	target_guid,
	storage_layer,
	entity,
	key_value,
	parent_storage_layer,
	parent_entity,
	parent_key_value,
	storage_map1
)
AS
SELECT  ROWNUM,
	level,
	target_guid,
	storage_layer,
	entity,
	key_value,
	parent_storage_layer,
	parent_entity,
	parent_key_value,
	SYS_CONNECT_BY_PATH(LOWER(key_value),' / ') 	storage_map1
FROM    -- Oracle applies the predicate after the connect , for the predicat to have precedence , do a virtual query to do the fileration
	(
               	SELECT  *
                FROM    mgmt_storage_keys
       	)
START WITH
       	parent_key_value IS NULL	
CONNECT BY
        PRIOR key_value(+) = parent_key_value
	AND PRIOR storage_layer(+) = parent_storage_layer
	AND PRIOR entity(+) = parent_entity 
/


CREATE OR REPLACE VIEW mgmt$storage_map_bottom_up
       (
	rank,
	indent_level,
	target_guid,
	storage_layer,
	entity,
	key_value,
	parent_storage_layer,
	parent_entity,
	parent_key_value,
	storage_map1
)
AS
SELECT  ROWNUM,
	level,
	target_guid,
	storage_layer,
	entity,
	key_value,
	parent_storage_layer,
	parent_entity,
	parent_key_value,
	SYS_CONNECT_BY_PATH(LOWER(key_value),' / ') 	storage_map1	
FROM    -- Oracle applies the predicate after the connect , for the predicat to have precedence , do a virtual query to do the fileration
	(
               	SELECT  *
                FROM    mgmt_storage_keys
       	)
START WITH
	key_value NOT IN (				-- Is at the lowest level
		SELECT	parent_key_value
		FROM	mgmt_storage_keys
		WHERE	parent_key_value IS NOT NULL
	)
CONNECT BY
        PRIOR parent_key_value(+) = key_value
	AND PRIOR parent_storage_layer(+) = storage_layer
	AND PRIOR parent_entity(+) = entity
/
