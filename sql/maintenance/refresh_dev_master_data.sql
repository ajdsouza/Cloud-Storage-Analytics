EXEC STORAGE_SUMMARY.CLEANJOB;

ALTER SESSION CLOSE DATABASE LINK storagedb
/

DROP DATABASE LINK storagedb
/

CREATE SHARED DATABASE LINK storagedb CONNECT TO stormon_test IDENTIFIED BY stormon_test  AUTHENTICATED BY stormon_test IDENTIFIED BY stormon_test USING '(DESCRIPTION = (ADDRESS_LIST = (ADDRESS = (PROTOCOL = TCP)(HOST = rmsun11.us.oracle.com)(PORT = 1521)))(CONNECT_DATA = (SID = emap)(GLOBAL_NAME = emap_rmsun11)(SERVER = dedicated)))'
/


DECLARE

l_tableList	stringTable := stringTable(
						'mgmt_metrics', 		
						'mgmt_targets',			-- This is a synonym to a local table in emap_rnsum11 OEMMON.SMP_VDT_TARGET
						'node_target_map',		-- This is a local table at emap_rmsun11 built from view MGMT_TARGETS_NEW@OEMDTC.US.ORACLE.COM
						'smp_vdj_job_per_target',
						'mozart_mgmt_targets',
						'mozart_node_target_map',
						'mozart_smp_vdj_job_per_target',
						'mgmt_migrated_targets',
						'mgmt_targets_merged');	-- This is a local table at emap_rmsun11 , built using dblink to table SMP_VDJ_JOB_PER_TARGET@OEMDTC.US.ORACLE.COM


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


INSERT INTO mgmt_targets(target_id,target_name,target_type) 
VALUES(10000001,'dlsun1170.us.oracle.com','oracle_sysman_node')
/

INSERT INTO mgmt_targets(target_id,target_name,target_type) 
VALUES(10000002,'lothar.us.oracle.com','oracle_sysman_node')
/

INSERT INTO mgmt_targets(target_id,target_name,target_type) 
VALUES(10000003,'rmdc-oem01.us.oracle.com','oracle_sysman_node')
/

INSERT INTO mgmt_targets(target_id,target_name,target_type) 
VALUES(10000004,'gede.us.oracle.com','oracle_sysman_node')
/

INSERT INTO mgmt_targets(target_id,target_name,target_type) 
VALUES(10000005,'miata.us.oracle.com','oracle_sysman_node')
/

INSERT INTO mgmt_targets(target_id,target_name,target_type) 
VALUES(10000006,'eagle1-pc.us.oracle.com','oracle_sysman_node')
/

INSERT INTO mgmt_targets(target_id,target_name,target_type) 
VALUES(10000007,'raj.us.oracle.com','oracle_sysman_node')
/

INSERT INTO mgmt_targets(target_id,target_name,target_type) 
VALUES(10000008,'sunray3.us.oracle.com','oracle_sysman_node')
/

INSERT INTO mgmt_targets(target_id,target_name,target_type) 
VALUES(10000009,'pebblebeach.us.oracle.com','oracle_sysman_node')
/

INSERT INTO mgmt_targets(target_id,target_name,target_type) 
VALUES(10000010,'ajdsouza-pc.us.oracle.com','oracle_sysman_node')
/

INSERT INTO mgmt_targets(target_id,target_name,target_type) 
VALUES(10000011,'pinnacle.us.oracle.com','oracle_sysman_node')
/

INSERT INTO mgmt_targets(target_id,target_name,target_type) 
VALUES(10000012,'pinnacle','oracle_sysman_node')
/

INSERT INTO mgmt_targets(target_id,target_name,target_type) 
VALUES(10000013,'labsun1.us.oracle.com','oracle_sysman_node')
/

INSERT INTO mgmt_targets(target_id,target_name,target_type) 
VALUES(10000014,'git-tools04','oracle_sysman_node')
/

INSERT INTO mgmt_targets(target_id,target_name,target_type) 
VALUES(10000015,'git-tools06','oracle_sysman_node')
/

INSERT INTO smp_view_targets(target_name,target_type,node_name) 
VALUES('emd_dlsun1170','oracle_sysman_database','dlsun1170.us.oracle.com')
/

INSERT INTO smp_view_targets(target_name,target_type,node_name) 
VALUES('orcl9i_lothar','oracle_sysman_database','lothar.us.oracle.com')
/

INSERT INTO smp_view_targets(target_name,target_type,node_name) 
VALUES('db1_lothar','oracle_sysman_database','lothar.us.oracle.com')
/

INSERT INTO smp_view_targets(target_name,target_type,node_name) 
VALUES('db3_lothar','oracle_sysman_database','lothar.us.oracle.com')
/

INSERT INTO smp_view_targets(target_name,target_type,node_name) 
VALUES('db4_lothar','oracle_sysman_database','lothar.us.oracle.com')
/

INSERT INTO smp_view_targets(target_name,target_type,node_name) 
VALUES('db5_lothar','oracle_sysman_database','lothar.us.oracle.com')
/

INSERT INTO smp_view_targets(target_name,target_type,node_name) 
VALUES('apps_lothar','oracle_sysman_database','lothar.us.oracle.com')
/

INSERT INTO smp_view_targets(target_name,target_type,node_name) 
VALUES('em400bdb','oracle_sysman_database','gede.us.oracle.com')
/

INSERT INTO smp_view_targets(target_name,target_type,node_name)
VALUES('em40p_pinnacle.us.oracle.com','oracle_sysman_database','pinnacle.us.oracle.com')
/

INSERT INTO smp_view_targets(target_name,target_type,node_name)
VALUES('em40p_pinnacle','oracle_sysman_database','pinnacle')
/

INSERT INTO smp_view_targets(target_name,target_type,node_name) 
VALUES('oemoltp_rmdc-oem01','oracle_sysman_database','rmdc-oem01.us.oracle.com')
/

INSERT INTO smp_view_targets(target_name,target_type,node_name)
VALUES('emeiat_rmdc-oem01','oracle_sysman_database','rmdc-oem01.us.oracle.com')
/

INSERT INTO smp_view_targets(target_name,target_type,node_name) 
VALUES('iasem_eagle1-pc','oracle_sysman_database','eagle1-pc.us.oracle.com')
/

INSERT INTO smp_view_targets(target_name,target_type,node_name) 
VALUES('oemtest2_labsun1','oracle_sysman_database','labsun1.us.oracle.com')
/

INSERT INTO smp_view_targets(target_name,target_type,node_name) 
VALUES('oemtest1_labsun1','oracle_sysman_database','labsun1.us.oracle.com')
/

INSERT INTO mgmt_targets(target_id,target_name,target_type) 
VALUES(10000017,'backup.ca.oracle.com','oracle_sysman_node')
/

INSERT INTO mgmt_targets(target_id,target_name,target_type) 
VALUES(10000018,'camisdzl2.ca.oracle.com','oracle_sysman_node')
/

INSERT INTO mgmt_targets(target_id,target_name,target_type) 
VALUES(10000019,'canetmgr.ca.oracle.com','oracle_sysman_node')
/

INSERT INTO mgmt_targets(target_id,target_name,target_type) 
VALUES(10000020,'canis1.ca.oracle.com','oracle_sysman_node')
/

INSERT INTO mgmt_targets(target_id,target_name,target_type) 
VALUES(10000021,'canis2.ca.oracle.com','oracle_sysman_node')
/

INSERT INTO mgmt_targets(target_id,target_name,target_type) 
VALUES(10000022,'ckam-sun1.ca.oracle.com','oracle_sysman_node')
/

INSERT INTO mgmt_targets(target_id,target_name,target_type) 
VALUES(10000023,'git-tools01.ca.oracle.com','oracle_sysman_node')
/

INSERT INTO mgmt_targets(target_id,target_name,target_type) 
VALUES(10000024,'git-tools02.ca.oracle.com','oracle_sysman_node')
/

INSERT INTO mgmt_targets(target_id,target_name,target_type) 
VALUES(10000025,'git-tools03.ca.oracle.com','oracle_sysman_node')
/

INSERT INTO mgmt_targets(target_id,target_name,target_type) 
VALUES(10000026,'git-tools04.ca.oracle.com','oracle_sysman_node')
/

INSERT INTO mgmt_targets(target_id,target_name,target_type) 
VALUES(10000027,'git-tools05.ca.oracle.com','oracle_sysman_node')
/

INSERT INTO mgmt_targets(target_id,target_name,target_type) 
VALUES(10000028,'git-tools06.ca.oracle.com','oracle_sysman_node')
/

INSERT INTO mgmt_targets(target_id,target_name,target_type) 
VALUES(10000029,'git-tools08.ca.oracle.com','oracle_sysman_node')
/

INSERT INTO mgmt_targets(target_id,target_name,target_type) 
VALUES(10000030,'redhat.ca.oracle.com','oracle_sysman_node')
/

INSERT INTO mgmt_targets(target_id,target_name,target_type) 
VALUES(10000031,'git-tools07.ca.oracle.com','oracle_sysman_node')
/

INSERT INTO mgmt_targets(target_id,target_name,target_type) 
VALUES(10000032,'cadmssun1.ca.oracle.com','oracle_sysman_node')
/

INSERT INTO mgmt_targets(target_id,target_name,target_type) 
VALUES(10000033,'cafinsun1.ca.oracle.com','oracle_sysman_node')
/

INSERT INTO mgmt_targets(target_id,target_name,target_type) 
VALUES(10000034,'tooltst3.us.oracle.com','oracle_sysman_node')
/

INSERT INTO mgmt_targets(target_id,target_name,target_type) 
VALUES(10000035,'hqlnx03.us.oracle.com','oracle_sysman_node')
/

INSERT INTO mgmt_targets(target_id,target_name,target_type) 
VALUES(10000036,'git-tst.us.oracle.com','oracle_sysman_node')
/

COMMIT;

ALTER SESSION CLOSE DATABASE LINK storagedb
/

DROP DATABASE LINK storagedb
/
