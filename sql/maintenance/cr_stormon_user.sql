--
-- Copyright  (c) 2001,2002  Oracle Corporation All rights reserved 
--
--
--
-- $Id: cr_stormon_user.sql,v 1.5 2003/08/20 01:37:37 ajdsouza Exp $ 
--
-- NAME  
--	 cr_stormon_user.sql
--
-- DESC
--	Create the stormon and stormon mozart users  
--
--
--	Steps to create stormon schema
--
--	As dba execute cr_tbs
--	As dba execute cr_stormon_user
--
--	As storage_rep execute cr_stormon_schema_size
--	As storage_rep execute grant_gen
--	As storage_rep execute grant_read_privilege
--
--	As stormon_mozart execute cr_stormon_mozart_schema
--	As stormon_test execute cr_stormon_synonym
--
--
-- MODIFIED	(MM/DD/YY)
-- ajdsouza	07/23/03 	- Created
--
--

-- Execute with dba privilege

-- Create the stormon user
CREATE USER storage_rep IDENTIFIED BY --<--storage_rep_password-->
/

ALTER USER  storage_rep  TEMPORARY TABLESPACE stormon_temp
/

GRANT CONNECT , RESOURCE TO storage_rep
/

-- Create the storon mozart user
DROP USER stormon_mozart CASCADE
/

CREATE USER stormon_mozart IDENTIFIED BY stormon_mozart
/

ALTER USER stormon_mozart TEMPORARY TABLESPACE stormon_temp
/

GRANT CONNECT , RESOURCE TO stormon_mozart
/


-- Create the storon mozart user
DROP USER stormon_test CASCADE
/

CREATE USER stormon_test IDENTIFIED BY stormon_test
/

ALTER USER stormon_test TEMPORARY TABLESPACE stormon_temp
/

GRANT CONNECT , RESOURCE TO stormon_test
/
