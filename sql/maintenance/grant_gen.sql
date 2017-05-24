--
-- Copyright  (c) 2001,2002  Oracle Corporation All rights reserved 
--
--
--
-- $Id: grant_gen.sql,v 1.4 2003/10/25 01:52:22 ajdsouza Exp $ 
--
-- NAME  
--	 grant_gen.sql
--
-- DESC
--	generate the sqls for granting and revoking read access to storage_rep schema
--
--
--
--
-- MODIFIED	(MM/DD/YY)
-- ajdsouza	07/23/03 	- Created
--
--

-- Execute as storage_rep
--

SET ECHO OFF
SET FEEDBACK OFF
SET LINESIZE 180
SET PAGESIZE 0
SET TERMOUT OFF  
COLUMN object_type noprint
COLUMN object_name noprint

SPOOL grant_read_privilege.sql

SELECT 'SET ECHO OFF'||CHR(10)||'SET FEEDBACK ON' FROM DUAL
/

SELECT DISTINCT 'GRANT '||DECODE(object_type,'TABLE','SELECT','VIEW','SELECT','EXECUTE')||'	ON '||LOWER(object_name)||' TO '||'stormon_test'||CHR(10)||'/' stmt,
	object_type,
	object_name
FROM	USER_OBJECTS
WHERE OBJECT_TYPE NOT IN ('INDEX','DATABASE LINK','SEQUENCE','PACKAGE BODY','TRIGGER')
ORDER BY
DECODE(object_type,'TYPE',9,'TABLE',10,'VIEW',11,12) ASC,
DECODE(INSTRB(object_name,'TABLE'),0,1,2) ASC
/

SPOOL OFF;

SPOOL revoke_read_privilege.sql

SELECT 'SET ECHO OFF'||CHR(10)||'SET FEEDBACK ON' FROM DUAL
/

SELECT	DISTINCT 'REVOKE '||DECODE(object_type,'TABLE','SELECT','VIEW','SELECT','EXECUTE')||'	ON '||LOWER(object_name)||' FROM '||'stormon_test'||' '||DECODE(object_type,'TYPE','FORCE',NULL)||CHR(10)||'/' stmt, 
	object_type,
	object_name
FROM	USER_OBJECTS
WHERE OBJECT_TYPE NOT IN ('INDEX','DATABASE LINK','SEQUENCE','PACKAGE BODY','TRIGGER')
ORDER BY
DECODE(object_type,'TYPE',9,'TABLE',10,'VIEW',11,12) DESC,
DECODE(INSTRB(object_name,'TABLE'),0,1,2) DESC
/

SPOOL OFF;

SPOOL cr_stormon_synonym.sql

SELECT 'SET ECHO OFF'||CHR(10)||'SET FEEDBACK ON' FROM DUAL
/

SELECT DISTINCT 'CREATE SYNONYM '||LOWER(object_name)||' FOR '||'storage_rep.'||LOWER(object_name)||CHR(10)||'/' stmt,
	object_type,
	object_name
FROM	USER_OBJECTS
WHERE OBJECT_TYPE NOT IN ('INDEX','DATABASE LINK','SEQUENCE','PACKAGE BODY','TRIGGER')
ORDER BY
DECODE(object_type,'TYPE',9,'TABLE',10,'VIEW',11,12) ASC,
DECODE(INSTRB(object_name,'TABLE'),0,1,2) ASC
/

SPOOL OFF;

SPOOL drop_stormon_synonym.sql

SELECT 'SET ECHO OFF'||CHR(10)||'SET FEEDBACK ON' FROM DUAL
/

SELECT DISTINCT 'DROP SYNONYM '||LOWER(object_name)||CHR(10)||'/' stmt,
	object_type,
	object_name
FROM	USER_OBJECTS
WHERE OBJECT_TYPE NOT IN ('INDEX','DATABASE LINK','SEQUENCE','PACKAGE BODY','TRIGGER')
ORDER BY
DECODE(object_type,'TYPE',9,'TABLE',10,'VIEW',11,12) DESC,
DECODE(INSTRB(object_name,'TABLE'),0,1,2) DESC
/

SPOOL OFF;

COLUMN object_type print
COLUMN object_name print

SET TERMOUT ON;
SET FEEDBACK ON;
