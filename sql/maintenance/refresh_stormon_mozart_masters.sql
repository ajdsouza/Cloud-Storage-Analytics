DROP DATABASE LINK mozartdb
/

CREATE SHARED DATABASE LINK mozartdb CONNECT TO storemon IDENTIFIED BY storemon  AUTHENTICATED BY storemon IDENTIFIED BY storemon USING '(DESCRIPTION = (ADDRESS_LIST = (ADDRESS = (PROTOCOL = TCP)(HOST = aoemp-dbs01.oracle.com)(PORT = 1521)))(CONNECT_DATA = (SID = aoemp)(GLOBAL_NAME = aoemp_dbs01)(SERVER = dedicated)))'
/

DELETE FROM mozart_mgmt_targets
/

INSERT INTO mozart_mgmt_targets (
	target_id		,
	target_name		,
	target_type		,
	tz			,
	hosted			,
	location		,
	datacenter		,
	support_group		,
	escalation_group	,
	owner			,
	business_owner 		,
	ip_address		,
	make			,
	model			,
	operating_system	
)
SELECT	'mozart_'||target_guid	,
	target_name		,
	'oracle_sysman_node'	,
        timezone_delta/60       ,
        NULL                    ,
        NULL                    ,
        NULL                    ,
        NULL                    ,
        NULL                    ,
        NULL                    ,
        NULL                    ,
        NULL                    ,
        NULL                    ,
        NULL                    ,
        NULL
FROM	MGMT_TARGETS@mozartdb
WHERE	target_type = 'host'
/

-- Refreshing node_target_map
DELETE FROM mozart_node_target_map
/

INSERT INTO mozart_node_target_map (
	node_name,
	target_name,
	target_type,
	agent_status,
	agent_state,
	agent_version,
	tns_address,
	tz
)
SELECT	host_name,
	target_name,
	target_type,
	NULL,
	NULL,
	NULL,
	NULL,
	timezone_delta/60
FROM	mgmt_targets@mozartdb
WHERE	target_type = 'oracle_database'
/


-- Refreshing mozart_smp_vdj_job_per_target
DELETE FROM mozart_smp_vdj_job_per_target
/

INSERT INTO mozart_smp_vdj_job_per_target
(
	target_name,
	job_name,
	target_type,
	node_name,
	deliver_time,
	start_time,
	finish_time,
	next_exec_time,
	occur_time,
	time_zone,
	status
)
SELECT  a.target_name,		
        c.job_name,
        a.target_type,
        a.host_name,
        NULL,
        c.start_time+(a.timezone_delta/60)/24 target_time,	-- start_time
        c.end_time+(a.timezone_delta/60)/24 end_time, -- finish_time
	NULL, -- next_exec_time
	NULL, -- occur_time
	a.timezone_delta/60, -- timezone
	NULL
FROM    mgmt_targets@mozartdb a,
        mgmt_job_target@mozartdb b,
        (
                SELECT  y.job_id job_id,
                        y.job_name,                        
                        SYS_EXTRACT_UTC( MAX(x.display_start_time)) start_time,
			SYS_EXTRACT_UTC( MAX(x.display_end_time)) end_time
                FROM    mgmt_job_exec_summary@mozartdb x,
                        mgmt_job@mozartdb y
                WHERE   y.job_type IN ('StormonHostJobs','StormonDbJobs')
                AND     x.job_id = y.job_id
                GROUP BY
                        y.job_id,
                        y.job_name
        ) c
WHERE   b.job_id = c.job_id
AND     a.target_guid = b.target_guid
/


COMMIT;



