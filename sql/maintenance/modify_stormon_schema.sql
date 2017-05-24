-- As storage_rep
EXEC storage_summary.cleanjob;


----------------------------------------------------------------------------
--  Schema for caching the master data from job scheduled in em
--
----------------------------------------------------------------------------
CREATE TABLE mozart_mgmt_targets (
	target_id		VARCHAR2(256)	NOT NULL,
	target_name		VARCHAR2(255)	NOT NULL,
	target_type		VARCHAR2(255),
	tz			NUMBER,
	hosted			NUMBER,
	location		VARCHAR2(255),
	datacenter		VARCHAR2(255),
	support_group		VARCHAR2(255),
	escalation_group	VARCHAR2(255),
	owner			VARCHAR2(255),
	business_owner 		VARCHAR2(255),
	ip_address		VARCHAR2(255),
	make			VARCHAR2(255),
	model			VARCHAR2(255),
	operating_system	VARCHAR2(255)
)
PCTFREE 5 PCTUSED 70 TABLESPACE data_storage STORAGE( INITIAL 20M )
/
CREATE UNIQUE INDEX mozart_mgmt_targets_idx1 ON mozart_mgmt_targets(target_id) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 5M )
/



CREATE TABLE mozart_node_target_map (
	node_name	 	VARCHAR2(255) NOT NULL,
	target_name		VARCHAR2(255) NOT NULL,
	target_type		VARCHAR2(255) NOT NULL,
	agent_status		VARCHAR2(4),
	agent_state		VARCHAR2(4),
	agent_version		VARCHAR2(64),
	tns_address		VARCHAR2(4000),
	tz			NUMBER
)
PCTFREE 5 PCTUSED 70 TABLESPACE data_storage STORAGE( INITIAL 20M )
/
CREATE UNIQUE INDEX mozart_node_target_map_idx1 ON mozart_node_target_map(node_name,target_name,target_type) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 8M )
/


CREATE TABLE mozart_smp_vdj_job_per_target (
	target_name		VARCHAR2(255),
	job_name		VARCHAR2(64),
	target_type		VARCHAR2(255),
	node_name		VARCHAR2(255),
	deliver_time		DATE,
	start_time		DATE,
	finish_time		DATE,
	next_exec_time 		DATE,
	occur_time		DATE,
	time_zone		NUMBER,
	status			NUMBER
)
PCTFREE 5 PCTUSED 70 TABLESPACE data_storage STORAGE( INITIAL 20M )
/
CREATE INDEX mozart_smp_vdj_job_idx1 ON mozart_smp_vdj_job_per_target(target_name,target_type) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 8M )
/

ALTER TYPE volumeObject MODIFY ATTRIBUTE TARGET_ID VARCHAR2(256) CASCADE
/
ALTER TYPE diskObject MODIFY ATTRIBUTE TARGET_ID VARCHAR2(256) CASCADE
/
ALTER TYPE filesystemObject MODIFY ATTRIBUTE TARGET_ID VARCHAR2(256) CASCADE
/
ALTER TYPE applicationObject MODIFY ATTRIBUTE TARGET_ID VARCHAR2(256) CASCADE
/


ALTER TABLE STORAGE_APPLICATION_TABLE MODIFY TARGET_ID VARCHAR2(256)
/
ALTER TABLE STORAGE_SWRAID_TABLE MODIFY TARGET_ID VARCHAR2(256)
/
ALTER TABLE STORAGE_DISK_TABLE MODIFY TARGET_ID VARCHAR2 (256)
/
ALTER TABLE STORAGE_LOCALFS_TABLE MODIFY TARGET_ID VARCHAR2 (256)
/
ALTER TABLE STORAGE_NFS_TABLE MODIFY TARGET_ID VARCHAR2 (256)
/
ALTER TABLE STORAGE_VOLUME_TABLE MODIFY TARGET_ID VARCHAR2 (256)
/

-- Move target_id from NUMBER to VARCHAR2 
-- 
-- MGMT_CURRENT_METRICS 
SET SERVEROUT ON SIZE 1000000;

DECLARE

l_tableList		stringTable := stringTable( 
							'mgmt_current_metrics',
--							'mgmt_targets' ,
--							'storage_statistics');

l_oldcolumnList		stringTable := stringTable(
							'target_guid' ,
--							'target_id',
--							'id');

l_nullcolumnList	stringTable := stringTable(
							'ENABLE_NOT_NULL' ,
--							'ENABLE_NOT_NULL',
--							'ENABLE_NOT_NULL');

l_tmpcolumnList		stringTable := stringTable(
							'target_guid_new',
--							'target_id_new',
--							'id_new' );

l_updcolumnList		stringTable := stringTable(
							'target_guid',
--							'target_id',
--							'UTL_RAW.CAST_TO_VARCHAR2(id)' );

l_indexlist		stringTable := stringTable( 
				'CREATE UNIQUE INDEX mgmt_current_metrics_idx1 ON X(target_guid,metric_guid,key_value) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 450M )' , 
--				'CREATE UNIQUE INDEX mgmt_targets_idx1 ON X(target_id) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 5M )' ,
--				'CREATE INDEX storage_statistics_idx1 ON X ( job_name, timestamp, id ) PCTFREE 5 TABLESPACE index_storage STORAGE ( INITIAL 100M )');

c_commit_batch_size	CONSTANT INTEGER := 75000;

PROCEDURE exec_sql( v_sql  IN VARCHAR2 ) IS
BEGIN

	DBMS_OUTPUT.PUT_LINE(v_sql);
	EXECUTE IMMEDIATE v_sql;

END exec_sql;


PROCEDURE batch_commit ( v_tablename IN VARCHAR2 , v_new_columnname IN VARCHAR2, v_old_columnname IN VARCHAR2 ) IS

l_batch_id	NUMBER := 0;
l_dummy		NUMBER;
l_check_stmt	VARCHAR2(4000);

BEGIN
	
	l_check_stmt := ' SELECT  1 FROM '||v_tablename||' WHERE '||v_new_columnname||' IS NULL AND '||v_old_columnname||' IS NOT NULL AND ROWNUM = 1';
	
	LOOP
		
		BEGIN
			
			DBMS_OUTPUT.PUT_LINE( l_check_stmt );
			EXECUTE IMMEDIATE l_check_stmt INTO l_dummy;

		EXCEPTION
			WHEN NO_DATA_FOUND THEN
				DBMS_OUTPUT.PUT_LINE(' Completed the transaction in batches= '||l_batch_id);
				EXIT;
		END;

		EXEC_SQL(' UPDATE '||v_tablename||' SET '||v_new_columnname||' = '||v_old_columnname||' WHERE '||v_new_columnname||' IS NULL AND ROWNUM <='||c_commit_batch_size ) ;
		COMMIT;	
		l_batch_id := l_batch_id + 1;				

	END LOOP;	

END batch_commit;


BEGIN

	FOR i IN l_tableList.FIRST..l_tableList.LAST LOOP
		
		EXEC_SQL( 'RENAME '||l_tableList(i)||' TO X ');

		EXEC_SQL( 'ALTER TABLE '||'X'||' ADD '||l_tmpcolumnLIst(i)||' VARCHAR2(256) ' );

		BATCH_COMMIT( 'X',l_tmpcolumnLIst(i),l_updcolumnList(i) );

		EXEC_SQL( 'ALTER TABLE '||'X'||' DROP COLUMN '||l_oldcolumnLIst(i)||' CHECKPOINT '||c_commit_batch_size );
		
		EXEC_SQL( 'ALTER TABLE '||'X'||' ADD '||l_oldcolumnLIst(i)||' VARCHAR2(256)' );

		BATCH_COMMIT( 'X', l_oldcolumnLIst(i), l_tmpcolumnList(i) );

		EXEC_SQL( l_indexlist(i) );
	
		IF l_nullcolumnlist(i) = 'ENABLE_NOT_NULL' THEN
			EXEC_SQL( 'ALTER TABLE '||'X'||' MODIFY '||l_oldcolumnLIst(i)||' NOT NULL ' );
		END IF;

		EXEC_SQL( 'ALTER TABLE '||'X'||' SET UNUSED ( '||l_tmpcolumnLIst(i)||' ) ' );

		EXEC_SQL( 'ALTER TABLE '||'X'||' DROP UNUSED COLUMNS CHECKPOINT '||c_commit_batch_size );

		EXEC_SQL( 'RENAME X TO '||l_tableList(i));

	END LOOP;

END;
/

CREATE OR REPLACE VIEW mgmt_targets_view
(
	target_id,
	target_name
)
AS
SELECT  DISTINCT         
--        TO_CHAR(target_id),
	target_id,
        target_name        
FROM    mgmt_targets
WHERE	target_type = 'oracle_sysman_node'
/

CREATE OR REPLACE VIEW storage_stats_view
(
	job_name,
	timestamp,
	id,
	name,
	message,
	time_seconds
)
AS
SELECT	job_name,
	timestamp,
--	UTL_RAW.CAST_TO_VARCHAR2(id),
	id,
	name,
	message,
	time_seconds
FROM	storage_statistics
/


DROP DATABASE LINK mozartdb
/

GRANT SELECT , INSERT , DELETE , UPDATE ON mgmt_current_metrics TO stormon_mozart
/
GRANT SELECT ON mgmt_metrics TO stormon_mozart
/
GRANT SELECT ON mozart_mgmt_targets TO stormon_mozart
/
GRANT SELECT ON mozart_node_target_map TO stormon_mozart
/
GRANT SELECT ON mozart_smp_vdj_job_per_target TO stormon_mozart
/

CREATE SHARED DATABASE LINK mozartdb CONNECT TO sysman IDENTIFIED BY sysman40t  AUTHENTICATED BY sysman IDENTIFIED BY sysman40t USING '(DESCRIPTION = (ADDRESS_LIST = (ADDRESS = (PROTOCOL = TCP)(HOST = git-tst.us.oracle.com)(PORT = 1521)))(CONNECT_DATA = (SID = aoemt)(GLOBAL_NAME = aoemt_git-tst)(SERVER = dedicated)))'
/
