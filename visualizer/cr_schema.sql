
DROP TABLE mgmt_targets
/
CREATE TABLE mgmt_targets(
TARGET_GUID  		RAW(16),
TARGET_NAME		VARCHAR2(256),
TARGET_TYPE		VARCHAR2(256),
COMMENTS		VARCHAR2(256),
CONSTRAINT mgmt_targets_pk PRIMARY KEY
(
	target_guid,
	target_name
)
)
/

DROP TABLE mgmt_target_composite
/

CREATE TABLE mgmt_target_composite(
COMPOSITE_NAME		VARCHAR2(256),
COMPOSITE_TYPE		VARCHAR2(256),
MEMBER_TARGET_NAME	VARCHAR2(256),
MEMBER_TARGET_TYPE	VARCHAR2(256)
)
/


DROP TABLE mgmt_storage_issues
/
CREATE TABLE mgmt_storage_issues(
TARGET_GUID		RAW(16),
TYPE	 		VARCHAR2(32)  ,
MESSAGE			VARCHAR2(1000)
)
/


DROP TABLE mgmt_storage_keys
/
CREATE TABLE mgmt_storage_keys(
TARGET_GUID		RAW(16),
KEY_VALUE		VARCHAR2(256)  ,
PARENT_KEY_VALUE	VARCHAR2(256)
)
/


DROP TABLE mgmt_storage_data
/
CREATE TABLE mgmt_storage_data(
TARGET_GUID  		RAW(16) ,
KEY_VALUE 		VARCHAR2(256)  ,
GLOBAL_UNIQUE_ID 	VARCHAR2(256)  ,
NAME			VARCHAR2(64)  ,
STORAGE_LAYER 		VARCHAR2(32)  ,
EM_QUERY_FLAG 		VARCHAR2(64)  ,
ENTITY_TYPE		VARCHAR2(64)  ,
RAWSIZEB 		NUMBER  ,
SIZEB 			NUMBER  ,
USEDB 			NUMBER  ,
FREEB 			NUMBER  ,
A1			VARCHAR2(256),
CONSTRAINT mgmt_storage_data_pk PRIMARY KEY
(
	target_guid,
	key_value
)        
)
/


-- Storage entities attributes
DROP VIEW mgmt$storage_report_data
/

CREATE OR REPLACE VIEW mgmt$storage_report_data
(
	target_name,
	target_type,
        key_value,
        global_unique_id,
        name,
        storage_layer,
        is_top_layer,
	is_part_of_top_layer,
	is_bottom_layer,
	is_intermediate_layer,	
	is_container_layer,
	is_spare,
	is_allocated,
        entity_type,
        rawsizeb,
        sizeb,
        usedb,
        freeb
)
AS
SELECT	b.target_name,
	b.target_type,
        a.key_value,
        a.global_unique_id,
        a.name,
        a.storage_layer,
        DECODE(INSTRB(a.em_query_flag,'TOP'),0,'N','Y'),
        DECODE(INSTRB(a.em_query_flag,'PIECE_OF_TOP'),0,'N','Y'),
        DECODE(INSTRB(a.em_query_flag,'BOTTOM'),0,'N','Y'),
        DECODE(INSTRB(a.em_query_flag,'INTERMEDIATE'),0,'N','Y'),
        DECODE(INSTRB(a.em_query_flag,'CONTAINER'),0,'N','Y'),
        DECODE(INSTRB(a.em_query_flag,'SPARE'),0,'N','Y'),
        DECODE(INSTRB(a.em_query_flag,'UNALLOCATED'),0,'Y','N'),
        SUBSTR(a.entity_type,1,32),
        a.rawsizeb,
        a.sizeb,
        a.usedb,
        a.freeb
FROM	mgmt_storage_data a,
	mgmt_targets b
WHERE	a.target_guid = b.target_guid
/

-- Storage report keys
DROP VIEW mgmt$storage_report_keys
/

CREATE OR REPLACE VIEW mgmt$storage_report_keys
(
	target_name,
	target_type,
	key_value,
	parent_key_value
)
AS
SELECT	b.target_name,
	b.target_type,
	a.key_value,
	a.parent_key_value
FROM	mgmt_storage_keys a,
	mgmt_targets b
WHERE	a.target_guid = b.target_guid
/


-- Storage report issues
DROP VIEW mgmt$storage_report_issues
/

CREATE OR REPLACE VIEW mgmt$storage_report_issues
(
	target_name,
	target_type,
	type,
	message
)
AS
SELECT	b.target_name,
	b.target_type,
	a.type,
	a.message
FROM	mgmt_storage_issues a,
	mgmt_targets b
WHERE	a.target_guid = b.target_guid
/	


-- The view with summary by layer for a target
DROP VIEW mgmt$storage_report_target
/

CREATE OR REPLACE VIEW mgmt$storage_report_target
AS
SELECT	a.target_name,
	a.target_type,
	a.storage_layer,
	SUM( DECODE(a.is_bottom_layer,'Y',avg_sizeb,0) ) bottom_level_sizeb,
	SUM( DECODE(a.is_part_of_top_layer,'Y',avg_freeb,DECODE(a.is_top_layer,'Y',avg_sizeb,DECODE(a.is_intermediate_layer||a.is_allocated,'YN',avg_sizeb,0))) ) top_level_sizeb,
	SUM( DECODE(a.is_top_layer,'Y',avg_freeb,DECODE(a.is_intermediate_layer||a.is_allocated,'YN',avg_sizeb,0)) ) top_level_freeb,
	SUM( DECODE(a.is_bottom_layer,'Y',avg_freeb,0) ) bottom_level_freeb
FROM	(
SELECT	a.target_name,
	a.target_type,
	a.storage_layer,
        a.is_top_layer,
	a.is_part_of_top_layer,
	a.is_bottom_layer,
	a.is_intermediate_layer,	
	a.is_container_layer,
	a.is_spare,
	a.is_allocated,	
	AVG(sizeb) avg_sizeb,
	AVG(freeb) avg_freeb
FROM	mgmt$storage_report_data a
GROUP BY
	a.target_name,
	a.target_type,
	a.storage_layer,
        a.is_top_layer,
	a.is_part_of_top_layer,
	a.is_bottom_layer,
	a.is_intermediate_layer,	
	a.is_container_layer,
	a.is_spare,
	a.is_allocated,
	NVL(a.global_unique_id,key_value)
) a
GROUP BY
	a.target_name,
	a.target_type,
	a.storage_layer
ORDER BY
	a.target_name,
	a.target_type,
	a.storage_layer
/


-- The storage summary for a group of targets
DROP VIEW mgmt$storage_report_group
/

CREATE OR REPLACE VIEW mgmt$storage_report_group
AS
SELECT	a.group_name,
	a.storage_layer,
	SUM( DECODE(a.is_bottom_layer,'Y',avg_sizeb,0) ) bottom_level_sizeb,
	SUM( DECODE(a.is_part_of_top_layer,'Y',avg_freeb,DECODE(a.is_top_layer,'Y',avg_sizeb,DECODE(a.is_intermediate_layer||a.is_allocated,'YN',avg_sizeb,0))) ) top_level_sizeb,
	SUM( DECODE(a.is_top_layer,'Y',avg_freeb,DECODE(a.is_intermediate_layer||a.is_allocated,'YN',avg_sizeb,0)) ) top_level_freeb,
	SUM( DECODE(a.is_bottom_layer,'Y',avg_freeb,0) ) bottom_level_freeb
FROM	(
SELECT	b.group_name,
	a.storage_layer,
        a.is_top_layer,
	a.is_part_of_top_layer,
	a.is_bottom_layer,
	a.is_intermediate_layer,	
	a.is_container_layer,
	a.is_spare,
	a.is_allocated,
	AVG(sizeb) avg_sizeb,
	AVG(freeb) avg_freeb
FROM	mgmt$storage_report_data a,
	(
	SELECT	c.target_name   	group_name,		
		a.target_name,
		a.target_type	
	FROM	mgmt_targets a,
		mgmt_target_composite b,
		(
			SELECT  target_guid,
				target_name,
				target_type
			FROM    mgmt_targets
			WHERE   target_type = 'composite'
		) c
	WHERE	b.member_target_type = 'host'
	AND	a.target_name = b.member_target_name
	AND	a.target_type = b.member_target_type		
	START WITH
 		b.composite_name = c.target_name AND
		b.composite_type = 'composite'
	CONNECT BY
		PRIOR b.member_target_name = b.composite_name AND
		PRIOR b.member_target_type = b.composite_type
	) b
WHERE	a.target_name = b.target_name
GROUP BY	
	b.group_name,
	a.storage_layer,
        a.is_top_layer,
	a.is_part_of_top_layer,
	a.is_bottom_layer,
	a.is_intermediate_layer,	
	a.is_container_layer,
	a.is_spare,
	a.is_allocated,
	NVL(a.global_unique_id,a.target_name||' '||key_value)
) a
GROUP BY	
	a.group_name,
	a.storage_layer
ORDER BY	
	a.group_name,	
	a.storage_layer
/



----------------------------------------------------------------------
--
-- Traverse the storage entities for a host in top down direction
-- 
----------------------------------------------------------------------
DROP VIEW mgmt$storage_report_top_layout
/

CREATE OR REPLACE VIEW mgmt$storage_report_top_layout
(
	target_name,
	storage_map,
	tree_level,
	parent_storage_layer,
	parent_key_value,
	storage_layer,
	key_value,
	entity_type,
	rawsizeb,
	sizeb,
	usedb,
	freeb
)
AS
SELECT	a.target_name,
	a.storage_map,
	a.lv,
	a.parent_storage_layer,
	a.parent_key_value,
	a.storage_layer,
	a.key_value,
	a.entity_type,
	a.rawsizeb,
	a.sizeb,
	a.usedb,
	a.freeb
FROM
	(
	SELECT	ROWNUM row_count,
		LEVEL lv,
		a.target_name,
		b.storage_layer,
		a.key_value,
		c.storage_layer parent_storage_layer,
		a.parent_key_value,
	 	SYS_CONNECT_BY_PATH(LOWER(a.key_value),' / ') storage_map,
		b.entity_type,
		b.rawsizeb,
		b.sizeb,
	 	b.usedb,
		b.freeb
	FROM    mgmt$storage_report_keys a,
		mgmt$storage_report_data b,
		mgmt$storage_report_data c
	WHERE   b.key_value = a.key_value AND        	
		b.target_name = a.target_name AND
		a.parent_key_value = c.key_value(+) AND
		a.target_name = c.target_name(+)
	START WITH
	 	a.parent_key_value IS NULL		
	AND	(
		b.is_top_layer||b.is_part_of_top_layer = 'YN'
	OR	b.is_intermediate_layer||b.is_allocated = 'YN'
	)
	CONNECT BY
	 	PRIOR a.key_value(+) = a.parent_key_value AND
 	        PRIOR a.target_name(+) = a.target_name
	) a
ORDER BY
	a.target_name,
	a.row_count
/



----------------------------------------------------------------------
--
-- Traverse the storage entities for a host in bottom up direction
-- 
----------------------------------------------------------------------
DROP VIEW  mgmt$storage_report_bot_layout
/

CREATE OR REPLACE VIEW  mgmt$storage_report_bot_layout
(
	target_name,
	storage_map,
	tree_level,
	storage_layer,
	key_value,
	entity_type,
	child_storage_layer,
	child_key_value,
	rawsizeb,
	sizeb,
	usedb,
	freeb
)
AS
SELECT	a.target_name,
	a.storage_map,
	a.lv,
	a.storage_layer,
	a.key_value,
	a.entity_type,
	a.parent_storage_layer,	
	a.parent_key_value,
	a.rawsizeb,
	a.sizeb,
	a.usedb,
	a.freeb
FROM
	(
	SELECT	ROWNUM row_count,
		LEVEL lv,
		a.target_name,
		b.storage_layer,
		a.key_value,
		c.storage_layer parent_storage_layer,
		a.parent_key_value,
	 	SYS_CONNECT_BY_PATH(LOWER(a.key_value),' / ') storage_map,
		b.entity_type,
		b.rawsizeb,
		b.sizeb,
	 	b.usedb,
		b.freeb
	FROM    mgmt$storage_report_keys a,
		mgmt$storage_report_data b,
		mgmt$storage_report_data c
	WHERE   b.key_value = a.key_value AND
		b.target_name = a.target_name AND
		a.parent_key_value = c.key_value(+) AND
		a.target_name = c.target_name(+)
	START WITH        			
		b.is_bottom_layer = 'Y'
	AND	a.key_value NOT IN (                              -- Is at the lowest level
		  	SELECT  c.parent_key_value 
			FROM    mgmt$storage_report_keys c 
	 		WHERE   c.target_name = a.target_name
			AND	c.parent_key_value IS NOT NULL
		 )
	CONNECT BY
	 	PRIOR a.parent_key_value(+) = a.key_value AND
		PRIOR a.target_name(+) = a.target_name
	) a
ORDER BY
	a.target_name,
	a.row_count
/

