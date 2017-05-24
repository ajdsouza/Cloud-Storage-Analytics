--
-- Look at file $HOME/ajdsouza/tmp/mapload for perl script to load file /home/ajdsouza/tmp/mapfile.txt
-- Edit file /home/ajdsouza/tmp/mapfile.txt to load a different mapping configuration
--

--------------------------------------------------------------------------------
--
-- Fetch the storage etities which are dependent on a given storage entity
--
--------------------------------------------------------------------------------
SELECT  LEVEL,
        a.target_name,
        b.storage_layer,
	b.name,
        a.key_value,
        SYS_CONNECT_BY_PATH(LOWER(a.key_value),' / ')     storage_map1,
	b.sizeb,
	b.usedb,
	b.freeb
-- Oracle applies the predicate after the connect , for the predicate to have precedence , do a virtual query with predicate
FROM   	mgmt$storage_report_keys a,
	mgmt$storage_report_data b
WHERE	a.target_name = b.target_name
AND	a.key_value = b.key_value
START WITH
	a.key_value = 'DK2' AND
	a.target_name = '2'
CONNECT BY
        PRIOR a.parent_key_value(+) = a.key_value AND 
	PRIOR a.target_name(+) = a.target_name
/


-------------------------------------------------------------------------------
--
-- Fetch the storage entities which are shared with a particular target
-- 
------------------------------------------------------------------------------- 
SELECT  LEVEL,
        a.target_name,
        b.storage_layer,
	b.name,
        a.key_value,
	b.global_unique_id,
        SYS_CONNECT_BY_PATH(LOWER(a.key_value),' / ')     storage_map1,
        b.sizeb,
        b.usedb,
        b.freeb
-- Oracle applies the predicate after the connect , for the predicate to have precedence , do a virtual query with predicate
FROM    mgmt$storage_report_keys a,
        mgmt$storage_report_data b
WHERE   a.target_name = b.target_name
AND     a.key_value = b.key_value
START WITH
		b.global_unique_id IS NOT NULL
	AND	b.is_bottom_layer = 'Y'
        AND     a.key_value NOT IN (                              -- Is at the lowest level
		SELECT  c.parent_key_value
		FROM    mgmt$storage_report_keys c
		WHERE   c.target_name = a.target_name
		AND	c.parent_key_value IS NOT NULL
        )
        AND     ( b.storage_layer,b.global_unique_id ) IN
        (
	        SELECT  d.storage_layer,
        	        d.global_unique_id
	        FROM    mgmt$storage_report_data d
        	WHERE   d.global_unique_id IS NOT NULL
		AND	d.is_bottom_layer = 'Y'
	        AND     d.target_name = '2'
        )
CONNECT BY
        PRIOR a.parent_key_value(+) = a.key_value AND
        PRIOR a.target_name(+) = a.target_name
/


-- Unallocated devices
SELECT  b.target_name,
        b.storage_layer,        
	b.name,
        b.key_value,
        b.global_unique_id,
        b.entity_type,
        b.sizeb,
        b.usedb,
        b.freeb
FROM    mgmt$storage_report_data b
WHERE   b.is_allocated = 'N'
/
