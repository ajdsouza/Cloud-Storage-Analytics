set serverout on;

define job_type_to_be_cleaned=StormonDbJobs

@cleanjob

DECLARE

jobTargets	MGMT_JOB_TARGET_LIST;
jobParams	MGMT_JOB_PARAM_LIST;
jobName		varchar2(64);
schedule	MGMT_JOB_SCHEDULE_RECORD;
job_id		RAW(16);
execution_id	RAW(16);

BEGIN

    jobName := 'StormonDbJobs';

    jobTargets := MGMT_JOB_TARGET_LIST();
    jobTargets.extend(2);
    jobTargets(1) := MGMT_JOB_TARGET_RECORD('em400bdb', 'oracle_database');
    jobTargets(2) := MGMT_JOB_TARGET_RECORD('em40p_pinnacle.us.oracle.com', 'oracle_database');

    jobParams := MGMT_JOB_PARAM_LIST();
    jobParams.extend(8);
    jobParams(1) := MGMT_JOB_PARAM_RECORD('username', 1, 'oracle', null);
    jobParams(2) := MGMT_JOB_PARAM_RECORD('password', 1, 'oracle9', null);
    jobParams(3) := MGMT_JOB_PARAM_RECORD('upload_db_user', 1, 'storage_rep', null);
    jobParams(4) := MGMT_JOB_PARAM_RECORD('upload_db_password', 1, 'storage_rep', null);
    jobParams(5) := MGMT_JOB_PARAM_RECORD('upload_db_tns', 1,'"(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=TCP)(HOST=eagle1-pc.us.oracle.com)(PORT=1521)))(CONNECT_DATA=(SID=iasem)))"', null);
    jobParams(6) := MGMT_JOB_PARAM_RECORD('em_target_type', 1,'oracle_sysman_database',null);
    jobParams(7) := MGMT_JOB_PARAM_RECORD('em_target_username', 1, 'system', null);
    jobParams(8) := MGMT_JOB_PARAM_RECORD('em_target_password', 1, 'manager', null);
    
    -- Specify a one-time schedule
    schedule := MGMT_JOB_SCHEDULE_RECORD(
					MGMT_JOBS.INTERVAL_FREQUENCY_CODE,
                                        SYSDATE,			-- Start time
					null,				-- end time
					0,				-- execution hours
					0,				-- execution minutes
					5,				-- Time interval in minutes
					null,				-- month
					null,				-- days
                                        MGMT_JOBS.TIMEZONE_REPOSITORY,	-- Timezone info TIMEZONE_TARGET|TIMEZONE_REPOSITORY
					0,				-- target index from target list, whoze timezone is used 
					0);				-- timezone offset


    MGMT_JOBS.submit_job(
		jobName,					-- jobname
		'This job executes the stormon Db job',		-- description
                'StormonDbJobs',				-- jobtype
                jobTargets,					-- job targets
                jobParams,					-- job params
	    	schedule,					-- job schedule
                job_id,						-- job id	(out)
                execution_id					-- execution id (out)
								-- P_OWNER        VARCHAR2    IN     DEFAULT
								-- P_SYSTEM_JOB   NUMBER(38)  IN     DEFAULT
		);

    dbms_output.put_line('Job ' || jobName || ' successfully inserted');

END;
/

COMMIT
/

SELECT	execution_id, 
	status 
FROM	MGMT_JOB_EXEC_SUMMARY 
WHERE	job_id IN ( 
		 SELECT	job_id 
		 FROM	mgmt_job
		 WHERE	UPPER(job_type) LIKE DECODE('&job_type_to_be_cleaned',NULL,'-1',UPPER('&job_type_to_be_cleaned'))
	      )
/

undefine job_type_to_be_cleaned;