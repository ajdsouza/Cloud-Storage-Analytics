--
-- Copyright  (c) 2001,2002  Oracle Corporation All rights reserved 
--
--
--
-- $Id: alter_dev_schema.sql,v 1.1 2003/11/17 19:08:42 ajdsouza Exp $ 
--
-- NAME  
--	 alter_dev_schema.sql
--
-- DESC
--
-- MOdifies the schema created by cr_stormon_schema_size to suit the dev environment
--
-- MODIFIED	(MM/DD/YY)
-- ajdsouza	11/17/03 	- Created
--
--

-- Execute with dba privilege

ALTER SESSION CLOSE DATABASE LINK oemdtc
/
DROP DATABASE LINK oemdtc
/
-- DB link to the 9i-isis table to refresh 9i masters for dev system , for dev system take data from the stormon production tables
CREATE SHARED DATABASE LINK oemdtc CONNECT TO stormon_test IDENTIFIED BY stormon_test  AUTHENTICATED BY stormon_test IDENTIFIED BY stormon_test USING '(DESCRIPTION = (ADDRESS_LIST = (ADDRESS = (PROTOCOL = TCP)(HOST = rmsun11.us.oracle.com)(PORT = 1521)))(CONNECT_DATA = (SID = emap)(GLOBAL_NAME = emap_rmsun11)(SERVER = dedicated)))'
/


