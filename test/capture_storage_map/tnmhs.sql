SET SERVEROUT ON SIZE 1000000

DECLARE

TYPE stringTable is TABLE OF VARCHAR2(1024);

k  stringTable := stringTable (
	'mgmt_storage_report_data',
	'mgmt_storage_report_keys',
	'mgmt_storage_report_alias',
	'mgmt_storage_report_issues',
	'mgmt$storage_report_disk',
	'mgmt$storage_report_volume',
	'mgmt$storage_report_localfs',
	'mgmt$storage_report_nfs',
	'mgmt$storage_report_paths',
	'mgmt$storage_report_data',
	'mgmt$storage_report_keys',
	'mgmt$storage_report_issues',
	'mgmt_v_storage_report_data',
	'mgmt_v_storage_report_unique',
	'mgmt_v_sl_size',
	'mgmt_v_sl_size_summary',
	'mgmt_v_sl_sz_sm_layers'
	);

tsql  stringTable := stringTable (
		'SELECT TO_CHAR(MAX(START_TIMESTAMP),''DD-MON HH24:MI:SS'') from mgmt$ecm_current_snapshots where snapshot_type = ''host_storage''' 
        );

l_target_name mgmt_targets.target_name%type;
l_cnt  VARCHAR2(100);
l_did   mgmt_ecm_gen_snapshot.snapshot_guid%TYPE;

BEGIN

 BEGIN
  SELECT target_name 
  INTO   l_target_name
  FROM   mgmt_targets
  WHERE  target_type = 'host'
  AND    ROWNUM = 1;
 EXCEPTION
   WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('No target found ');
    RETURN;
   WHEN OTHERS THEN RAISE;
 END;

storage_ui_util_pkg.set_storage_context('host_name', l_target_name);

FOR i IN k.FIRST..k.LAST LOOP

	BEGIN
	 	EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM '||k(i) INTO l_cnt;

		DBMS_OUTPUT.PUT_LINE(k(i)||' Count = '||l_cnt);
	EXCEPTION
		WHEN OTHERS THEN
			DBMS_OUTPUT.PUT_LINE('ERROR with Object '||k(i)||' '||SQLERRM);
	END;

END LOOP;

-- STORAGE_ECM_PKG.POST_PROCESSING(l_did);

FOR i IN tsql.FIRST..tsql.LAST LOOP

	BEGIN
	 	EXECUTE IMMEDIATE tsql(I) INTO l_cnt;

		DBMS_OUTPUT.PUT_LINE(tsql(i)||' Results = '||l_cnt);
	EXCEPTION
		WHEN OTHERS THEN
			DBMS_OUTPUT.PUT_LINE('ERROR with SQL '||tsql(i)||' '||SQLERRM);
	END;

END LOOP;

END;
/

SELECT message FROM mgmt_storage_report_issues
/

SELECT error_msg FROM mgmt_system_error_log WHERE module_name = 'STORAGE_REPORTING'
/
