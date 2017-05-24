EXEC STORAGE_SUMMARY.CLEANJOB;

ALTER SESSION CLOSE DATABASE LINK storagedb
/

DROP DATABASE LINK storagedb
/

CREATE SHARED DATABASE LINK storagedb CONNECT TO stormon_test IDENTIFIED BY stormon_test  AUTHENTICATED BY stormon_test IDENTIFIED BY stormon_test USING '(DESCRIPTION = (ADDRESS_LIST = (ADDRESS = (PROTOCOL = TCP)(HOST = rmsun11.us.oracle.com)(PORT = 1521)))(CONNECT_DATA = (SID = emap)(GLOBAL_NAME = emap_rmsun11)(SERVER = dedicated)))'
/

DECLARE

l_tableList	stringTable := stringTable(
						'storage_summaryObject',
						'storage_summaryObject_history',
						'storage_history_30days',
						'storage_history_52weeks',
						'storage_log',
						'storage_application_table',
						'storage_localfs_table',						
						'storage_nfs_table',
						'storage_volume_table',
						'storage_swraid_table',
						'storage_disk_table',					
						'stormon_group_table',
						'stormon_group_of_groups_table',
						'stormon_host_groups',
						'stormon_load_status');


l_num_rows_this_db	NUMBER;
l_num_rows_dblink_db	NUMBER;

BEGIN

FOR i IN l_tableList.FIRST..l_tableList.LAST 
LOOP
	
	DBMS_OUTPUT.PUT('Deleting and inserting or table '||l_tableList(i));

	EXECUTE IMMEDIATE 'DELETE FROM	'||l_tableList(i);

	EXECUTE IMMEDIATE 'INSERT INTO 	'||l_tableList(i)||' SELECT * FROM '||l_tableList(i)||'@storagedb';

	EXECUTE IMMEDIATE ' SELECT COUNT(*) FROM '||l_tableList(i) INTO l_num_rows_this_db;

	EXECUTE IMMEDIATE ' SELECT COUNT(*) FROM '||l_tableList(i)||'@storagedb' INTO l_num_rows_dblink_db;

	DBMS_OUTPUT.PUT_LINE(' Number of rows '||l_num_rows_this_db||' / '||l_num_rows_dblink_db);

END LOOP;

END;
/

COMMIT;

ALTER SESSION CLOSE DATABASE LINK storagedb
/
DROP DATABASE LINK storagedb
/
