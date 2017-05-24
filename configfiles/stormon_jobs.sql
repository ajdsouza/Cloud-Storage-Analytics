--
--
-- Copyright  (c) 2001,2002  Oracle Corporation All rights reserved 
--
--
--
-- $Id: stormon_jobs.sql,v 1.29 2003/07/28 20:08:44 ajdsouza Exp $ 
--
--
--
--

--------------------------------------------------------------------------------------
-- Package : stormon_jobs
--
-- Desc:
-- Package to submit stormon host and db jobs using the job system in em4.0
--
--------------------------------------------------------------------------------------
REVOKE EXECUTE ON stormon_jobs FROM PUBLIC
/

DROP PUBLIC SYNONYM stormon_jobs
/

DROP TYPE stringTable
/

CREATE TYPE stringTable AS TABLE OF VARCHAR2(4000)
/

CREATE OR REPLACE PACKAGE stormon_jobs AS

	PROCEDURE submit_to_host( 
			v_target_name		IN	mgmt$target.target_name%TYPE ,
			v_username		IN	VARCHAR2,
			v_password		IN	VARCHAR2,
			v_hour_of_execution	IN	INTEGER	DEFAULT 16,
			v_interval_hours	IN	NUMBER	DEFAULT 24 );

	PROCEDURE submit_to_database (
			v_target_name		IN	mgmt$target.target_name%TYPE,
			v_username		IN	VARCHAR2,
			v_password		IN	VARCHAR2,
			v_db_username		IN	VARCHAR2,
			v_db_password		IN	VARCHAR2,
			v_hour_of_execution	IN	INTEGER	DEFAULT 15,
			v_interval_hours	IN	NUMBER	DEFAULT 24 );

	PROCEDURE submit_to_host_group ( 
			v_group_name		IN	mgmt$target.target_name%TYPE ,
			v_username		IN	VARCHAR2,
			v_password		IN	VARCHAR2,
			v_hour_of_execution	IN	INTEGER	DEFAULT 16,
			v_interval_hours	IN	NUMBER	DEFAULT 24 );

	PROCEDURE submit_to_database_group (
			v_group_name		IN	mgmt$target.target_name%TYPE,
			v_username		IN	VARCHAR2,
			v_password		IN	VARCHAR2,
			v_db_username		IN	VARCHAR2,
			v_db_password		IN	VARCHAR2,
			v_hour_of_execution	IN	INTEGER	DEFAULT 15 ,
			v_interval_hours	IN	NUMBER	DEFAULT 24);

END stormon_jobs;
/

CREATE OR REPLACE PACKAGE BODY stormon_jobs AS

--------------------------------------------------------------------------------------
-- Package variables
--------------------------------------------------------------------------------------
p_stormon_host_job_type	VARCHAR2(50) := 'StormonHostJobs';
p_stormon_db_job_type	VARCHAR2(50) := 'StormonDbJobs';

p_host_target_type	VARCHAR2(50) := 'host';
p_db_target_type	VARCHAR2(50) := 'oracle_database';

p_repository_host	VARCHAR2(100) := 'rmsun11.us.oracle.com';
p_repository_port	VARCHAR2(10)  := '1521';
p_repository_sid	VARCHAR2(10)  := 'emap';

--p_repository_host	VARCHAR2(100) := 'eagle1-pc.us.oracle.com';
--p_repository_port	VARCHAR2(10)  := '1521';
--p_repository_sid	VARCHAR2(10)  := 'iasem';

p_repository_user_name	VARCHAR2(20)  := 'stormon_mozart';
p_repository_password	VARCHAR2(20)  := 'stormon_mozart';

p_target_list_name	CONSTANT INTEGER := 1;
p_target_list_group	CONSTANT INTEGER := 2;
p_target_list_all	CONSTANT INTEGER := 3;

p_job_interval_hours	CONSTANT INTEGER := 24;   
p_job_submission_hour	CONSTANT INTEGER := 22;

--------------------------------------------------------------------------------------
-- Private Subroutines
--------------------------------------------------------------------------------------
PROCEDURE display_jobs( v_job_type IN mgmt_job.job_type%TYPE );

PROCEDURE clean_job( 
			v_job_type IN mgmt_job.job_type%TYPE, 
			v_job_name IN mgmt_job.job_name%TYPE DEFAULT NULL );

PROCEDURE submit_to_all_my_hosts (   
			v_username		IN	VARCHAR2,
			v_password		IN	VARCHAR2,
			v_hour_of_execution	IN	INTEGER		DEFAULT 16 ,
			v_interval_hours	IN	NUMBER		DEFAULT 24 );

PROCEDURE submit_to_all_my_databases (
			v_username		IN	VARCHAR2,
			v_password		IN	VARCHAR2,
			v_db_username		IN	VARCHAR2,
			v_db_password		IN	VARCHAR2,
			v_hour_of_execution	IN	INTEGER		DEFAULT 15,
			v_interval_hours	IN	NUMBER		DEFAULT 24 );

PROCEDURE execute_job (   		v_target_list_type	IN	INTEGER,
					v_name			IN	mgmt$target.target_name%TYPE,
					v_username		IN	VARCHAR2,
					v_password		IN	VARCHAR2,					
					v_job_type		IN	VARCHAR2,
					v_hour_of_execution	IN	INTEGER,
					v_interval_hours	IN	NUMBER,										
					v_db_username		IN	VARCHAR2 DEFAULT NULL,
					v_db_password		IN	VARCHAR2 DEFAULT NULL );

--------------------------------------------------------------------------------------
-- name : display_jobs
--
-- Desc: display_jobs jobs for the specified job type
--

-- Args: job_type
--
--------------------------------------------------------------------------------------
PROCEDURE display_jobs( v_job_type IN mgmt_job.job_type%TYPE ) IS

BEGIN

	FOR rec IN (
		SELECT	execution_id, 
			status 
		FROM	MGMT_JOB_EXEC_SUMMARY 
		WHERE	job_id IN ( 
				 SELECT	job_id 
				 FROM	mgmt_job
				 WHERE	UPPER(job_type) LIKE DECODE(UPPER(v_job_type),NULL,'-1',UPPER(UPPER(v_job_type)))
			  )
		)
	LOOP

		DBMS_OUTPUT.PUT_LINE('Execution Id : '||rec.execution_id||CHR(9)||CHR(9)||'Status : '||rec.status);

	END LOOP;

END display_jobs;


--------------------------------------------------------------------------------------
-- name : clean_job
--
-- Desc:  stop and delete all jobs of specified job_name
--

-- Args:  job_type,job_name
--
--------------------------------------------------------------------------------------
PROCEDURE clean_job ( 
				v_job_type  IN mgmt_job.job_type%TYPE,
				v_job_name IN mgmt_job.job_name%TYPE DEFAULT NULL
		 ) IS

BEGIN

	DBMS_OUTPUT.PUT_LINE(' Deleting Jobs of type '||v_job_type||' with name '||v_job_name);

	-- First stop all currently running executions
	FOR crec IN (
		SELECT execution_id 
		FROM   mgmt_job_exec_summary
		WHERE  status NOT IN (3, 4, 5, 8) 
		AND    job_id IN ( 
				  SELECT job_id 
				  FROM	 mgmt_job
				  WHERE	 UPPER(job_type) LIKE DECODE(UPPER(v_job_type),NULL,'-1',UPPER(v_job_type)) 
				  AND	 UPPER(job_name) LIKE UPPER(v_job_name)||'%'
		  )
	)
	LOOP
        
		DBMS_OUTPUT.PUT_LINE('Stopping execution of execution id ' || crec.execution_id);
		MGMT_JOBS.STOP_EXECUTION(crec.execution_id);

	END LOOP;

	-- Delete all jobs
	FOR crec IN ( 
			SELECT	job_name 
			FROM	mgmt_job 
			WHERE	nested = 0 
			AND	UPPER(job_type) LIKE  DECODE(UPPER(v_job_type),NULL,'-1',UPPER(v_job_type)) 
			AND	UPPER(job_name) LIKE UPPER(v_job_name)||'%'
	) 
	LOOP

		BEGIN

			MGMT_JOBS.DELETE_JOB(crec.job_name, 1);

		EXCEPTION
			WHEN OTHERS THEN
			    RAISE_APPLICATION_ERROR(-20101,'Failed to delete job ' || crec.job_name ||':' || SQLERRM,TRUE);
		END;

	END LOOP;

--	COMMIT;

END clean_job;

--------------------------------------------------------------------------------------
-- name : submit_to_host
--
-- Desc: Submit the stormon host job for a target
--

-- Args:
--
--------------------------------------------------------------------------------------
PROCEDURE submit_to_host( 
				v_target_name		IN	mgmt$target.target_name%TYPE ,
			   	v_username		IN	VARCHAR2,
			   	v_password		IN	VARCHAR2,
				v_hour_of_execution	IN	INTEGER	DEFAULT 16 ,
				v_interval_hours	IN	NUMBER	DEFAULT 24
) IS

BEGIN

	STORMON_JOBS.EXECUTE_JOB(   	STORMON_JOBS.P_TARGET_LIST_NAME,
					v_target_name, 
					v_username,
					v_password,				
					STORMON_JOBS.P_STORMON_HOST_JOB_TYPE,					
					v_hour_of_execution,
					v_interval_hours);	

END submit_to_host;


--------------------------------------------------------------------------------------
-- name : submit_to_host_group
--
-- Desc: Submit the stormon host job for a group of targets
--

-- Args:
--
--------------------------------------------------------------------------------------
PROCEDURE submit_to_host_group ( 
					v_group_name		IN	mgmt$target.target_name%TYPE ,
					v_username		IN	VARCHAR2,
					v_password		IN	VARCHAR2,
					v_hour_of_execution	IN	INTEGER		DEFAULT 16,
					v_interval_hours	IN	NUMBER		DEFAULT 24  
)
IS

BEGIN

	STORMON_JOBS.EXECUTE_JOB(  	STORMON_JOBS.P_TARGET_LIST_GROUP,
					v_group_name,
					v_username,
					v_password,					
					STORMON_JOBS.P_STORMON_HOST_JOB_TYPE,					
					v_hour_of_execution,
					v_interval_hours );

END submit_to_host_group;


--------------------------------------------------------------------------------------
-- name : submit_to_all_my_hosts
--
-- Desc: Submit the stormon host job for all targets for the current user
--
--
-- Args:
--	common user name for all the hosts
--	common password  for all the hosts
--------------------------------------------------------------------------------------
PROCEDURE submit_to_all_my_hosts (   
					v_username		IN	VARCHAR2,
					v_password		IN	VARCHAR2,
					v_hour_of_execution	IN	INTEGER		DEFAULT 16 ,
					v_interval_hours	IN	NUMBER		DEFAULT 24
 ) 
IS

BEGIN

	STORMON_JOBS.EXECUTE_JOB(  	STORMON_JOBS.P_TARGET_LIST_ALL,
					NULL,
					v_username,
					v_password,					
					STORMON_JOBS.P_STORMON_HOST_JOB_TYPE,					
					v_hour_of_execution,
					v_interval_hours );


END submit_to_all_my_hosts;


--------------------------------------------------------------------------------------
-- name : submit_to_database
--
-- Desc: Submit the stormon db job to a single database target
--
-- Args:
--
--------------------------------------------------------------------------------------
PROCEDURE submit_to_database (
			v_target_name		IN	mgmt$target.target_name%TYPE,
			v_username		IN	VARCHAR2,
			v_password		IN	VARCHAR2,
			v_db_username		IN	VARCHAR2,
			v_db_password		IN	VARCHAR2,
			v_hour_of_execution	IN	INTEGER		DEFAULT 15,
			v_interval_hours	IN	NUMBER		DEFAULT 24
	)

IS

BEGIN

	STORMON_JOBS.EXECUTE_JOB(  	STORMON_JOBS.P_TARGET_LIST_NAME,
					v_target_name,
					v_username,
					v_password,
					STORMON_JOBS.P_STORMON_DB_JOB_TYPE,
					v_hour_of_execution,
					v_interval_hours,
					v_db_username,
					v_db_password);
	
END submit_to_database;


--------------------------------------------------------------------------------------
-- name : submit_to_database_group
--
-- Desc: Submit the stormon db job for a group of db targets
--
-- Args:
--
--------------------------------------------------------------------------------------
PROCEDURE submit_to_database_group (
			v_group_name		IN	mgmt$target.target_name%TYPE ,
			v_username		IN	VARCHAR2,
			v_password		IN	VARCHAR2,
			v_db_username		IN	VARCHAR2,
			v_db_password		IN	VARCHAR2,
			v_hour_of_execution	IN	INTEGER		DEFAULT 15,
			v_interval_hours	IN	NUMBER		DEFAULT 24
	)

IS

BEGIN

	STORMON_JOBS.EXECUTE_JOB(  	STORMON_JOBS.P_TARGET_LIST_GROUP,
					v_group_name,
					v_username,
					v_password,
					STORMON_JOBS.P_STORMON_DB_JOB_TYPE,
					v_hour_of_execution,
					v_interval_hours,
					v_db_username,
					v_db_password);
	
END submit_to_database_group;


--------------------------------------------------------------------------------------
-- name : submit_to_all_my_databases
--
-- Desc: Submit the stormon db job for all db targets 
--
-- Args:
--
--------------------------------------------------------------------------------------
PROCEDURE submit_to_all_my_databases (
			v_username		IN	VARCHAR2,
			v_password		IN	VARCHAR2,
			v_db_username		IN	VARCHAR2,
			v_db_password		IN	VARCHAR2,
			v_hour_of_execution	IN	INTEGER		DEFAULT 15,
			v_interval_hours	IN	NUMBER		DEFAULT 24
	)

IS

BEGIN

	STORMON_JOBS.EXECUTE_JOB(  	STORMON_JOBS.P_TARGET_LIST_ALL,
					NULL,
					v_username,
					v_password,					
					STORMON_JOBS.P_STORMON_DB_JOB_TYPE,					
					v_hour_of_execution,
					v_interval_hours,								
					v_db_username,
					v_db_password);
	
END submit_to_all_my_databases;

--------------------------------------------------------------------------------------
-- name : execute_job
--
-- Desc:  Execute the stormon Host and DB jobs
--
-- Args:
--
--------------------------------------------------------------------------------------
PROCEDURE execute_job (   
					v_target_list_type	IN	INTEGER,
					v_name			IN	mgmt$target.target_name%TYPE,
					v_username		IN	VARCHAR2,
					v_password		IN	VARCHAR2,
					v_job_type		IN	VARCHAR2,
					v_hour_of_execution	IN	INTEGER,
					v_interval_hours	IN	NUMBER,	
					v_db_username		IN	VARCHAR2 DEFAULT NULL,
					v_db_password		IN	VARCHAR2 DEFAULT NULL
 ) 
IS

l_target_type			mgmt$target.target_type%TYPE;
l_job_name			mgmt_job.job_name%TYPE;
l_zone_job_name			mgmt_job.job_name%TYPE;
l_job_desc			mgmt_job.job_description%TYPE;

l_target_list_sql		VARCHAR2(4000);

l_list_of_targets		stringTable;
l_list_of_supported_targets	stringTable;  -- Only Linux and sunOS
l_list_of_targets_to_skip	stringTable;
l_list_of_scheduled_targets	stringTable;
l_zone_target_list		stringTable;

l_job_targets			MGMT_JOB_TARGET_LIST;
l_job_params			MGMT_JOB_PARAM_LIST;
l_schedule			MGMT_JOB_SCHEDULE_RECORD;
l_job_id			RAW(16);
l_execution_id			RAW(16);

l_start_time			DATE := SYSDATE;
l_timezone_offset		NUMBER;
l_gmt_time			DATE;
l_session_timestamp_zone	TIMESTAMP WITH TIME ZONE;
l_timezone_hour			NUMBER;
l_timezone_minutes		NUMBER;
l_timezone_abbrv		v$timezone_names.tzabbrev%TYPE;

l_dummy				INTEGER;

BEGIN

	-- rudimentary check for job type
	IF v_job_type NOT IN ( STORMON_JOBS.P_STORMON_HOST_JOB_TYPE, STORMON_JOBS.P_STORMON_DB_JOB_TYPE ) THEN

		DBMS_OUTPUT.PUT_LINE('Unsupported job type '||v_job_type||' target_type should be one of '||STORMON_JOBS.P_STORMON_HOST_JOB_TYPE||', '||STORMON_JOBS.P_STORMON_DB_JOB_TYPE||' Aborting job submission');
		RETURN;		

	END IF;

	IF v_target_list_type NOT IN ( STORMON_JOBS.P_TARGET_LIST_NAME, STORMON_JOBS.P_TARGET_LIST_GROUP, STORMON_JOBS.P_TARGET_LIST_ALL ) THEN

		DBMS_OUTPUT.PUT_LINE('Unsupported job target list '||v_target_list_type||' , JOb can be submitted for a single target , group of targets or all targets ,  Aborting job submission');
		RETURN;		

	END IF;


	-- Set target_type to query based on job type
	IF v_job_type = STORMON_JOBS.P_STORMON_HOST_JOB_TYPE THEN

		l_target_type 	:= STORMON_JOBS.P_HOST_TARGET_TYPE;
		l_job_name 	:= 'STORMON_HOST';

	ELSIF v_job_type = STORMON_JOBS.P_STORMON_DB_JOB_TYPE THEN
		
		l_target_type 	:= STORMON_JOBS.P_DB_TARGET_TYPE;
		l_job_name 	:= 'STORMON_DB';

	END IF;


	-- Get the list of targets for job submission
	-- Explode group of groups by using connect by clause
	IF v_target_list_type = STORMON_JOBS.P_TARGET_LIST_GROUP THEN

		l_target_list_sql := '
					SELECT	target_name
					FROM	(
							SELECT  DISTINCT member_target_name	target_name,
								member_target_type 		target_type
							FROM    mgmt$target_composite						
							CONNECT BY
							        PRIOR member_target_name = composite_name
							AND     PRIOR member_target_type = composite_type
							START WITH composite_name = :name
						) a
					WHERE	target_type =  :target_type';

		l_job_name 	:= l_job_name||'_GROUP_'||v_name;

	ELSIF v_target_list_type = STORMON_JOBS.P_TARGET_LIST_NAME THEN

		l_target_list_sql := '
					SELECT	target_name
					FROM	mgmt$target a
					WHERE	target_name = :name
					AND	target_type = :target_type';

		l_job_name 	:= l_job_name||'_'||v_name;

	ELSE  
		l_target_list_sql := '
					SELECT	target_name
					FROM	mgmt$target a
					WHERE	target_name LIKE :name||''%''
					AND	target_type = :target_type';

		l_job_name 	:= l_job_name||'_ALL';	

	END IF;
	
	l_job_desc := l_job_name;


	EXECUTE IMMEDIATE l_target_list_sql BULK COLLECT INTO l_list_of_targets USING v_name, l_target_type;

	IF l_list_of_targets IS NULL OR NOT l_list_of_targets.EXISTS(1) THEN
		DBMS_OUTPUT.PUT_LINE('No targets of type '||l_target_type||' found , aborting submission of job type '||v_job_type);
		RETURN;
	END IF;

		
-- Check for Host OS to be either Linux and sunOS
	IF l_target_type = STORMON_JOBS.P_HOST_TARGET_TYPE  THEN

		SELECT	VALUE(a)
		BULK COLLECT INTO l_list_of_supported_targets
		FROM	TABLE ( CAST ( l_list_of_targets AS stringTable ) ) a
		WHERE 	EXISTS 
		(
			SELECT	1
			FROM	mgmt$target_properties b
			WHERE	target_name = VALUE(a)
			AND	LOWER(target_type) = STORMON_JOBS.P_HOST_TARGET_TYPE
			AND	UPPER(property_name) = 'OS'
			AND	UPPER(property_value) IN ('SUNOS','LINUX')
		);
			
		IF l_list_of_supported_targets IS NULL OR NOT l_list_of_supported_targets.EXISTS(1) THEN
			DBMS_OUTPUT.PUT_LINE('No targets of type sunOS and Linux found , aborting scheduling of job '||l_job_name||' of type '||v_job_type);
			RETURN;
		END IF;

	ELSE

		l_list_of_supported_targets :=  l_list_of_targets;

	END IF;	
			
-- delete any jobs of this type that are scheduled on the group or target 
	STORMON_JOBS.CLEAN_JOB(v_job_type,l_job_name);			


-- Get the list of targets that have jobs already submitted for them
	SELECT	DISTINCT a.target_name
	BULK COLLECT INTO l_list_of_targets_to_skip
	FROM	mgmt_job_target a,
		mgmt_job b,
		TABLE ( CAST ( l_list_of_supported_targets AS stringTable ) ) c
	WHERE	a.job_id = b.job_id
	AND	b.job_type = v_job_type
	AND	a.target_name = VALUE(c);


	IF l_list_of_targets_to_skip IS NOT NULL AND l_list_of_targets_to_skip.EXISTS(1) THEN

		FOR i IN l_list_of_targets_to_skip.FIRST..l_list_of_targets_to_skip.LAST LOOP

			DBMS_OUTPUT.PUT_LINE(' Skipping target '||l_list_of_targets_to_skip(i)||' as Job of type '||v_job_type||' has already been scheduled ');

		END LOOP;

	END IF;

-- Submit jobs only for those targets which do not have a job scheduled
	SELECT	VALUE(a)
	BULK COLLECT INTO l_list_of_scheduled_targets
	FROM	TABLE( CAST ( l_list_of_supported_targets AS stringTable ) ) a
	MINUS
	SELECT	VALUE(b)	
	FROM	TABLE( CAST ( l_list_of_targets_to_skip AS stringTable ) ) b;

	IF l_list_of_scheduled_targets IS NULL OR NOT l_list_of_scheduled_targets.EXISTS(1) THEN
		DBMS_OUTPUT.PUT_LINE('Job type '||v_job_type||' has already been scheduled on all requested targets ');
		RETURN;
	END IF;

-- prepare the parameter List for job submission
	l_job_params := MGMT_JOB_PARAM_LIST();
	l_job_params.extend(5);
	l_job_params(1) := MGMT_JOB_PARAM_RECORD('upload_db_user', 1, p_repository_user_name, NULL);
	l_job_params(2) := MGMT_JOB_PARAM_RECORD('upload_db_password', 1, p_repository_password, NULL);
	l_job_params(3) := MGMT_JOB_PARAM_RECORD('upload_db_tns',1, '"(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=TCP)(HOST='||p_repository_host||')(PORT='||p_repository_port||')))(CONNECT_DATA=(SID='||p_repository_sid||')))"', NULL);
	l_job_params(4) := MGMT_JOB_PARAM_RECORD('username', 1, v_username, NULL);
	l_job_params(5) := MGMT_JOB_PARAM_RECORD('password', 1, v_password, NULL);

	IF l_target_type = STORMON_JOBS.P_DB_TARGET_TYPE THEN
				
		l_job_params.EXTEND(3);

		l_job_params(6) := MGMT_JOB_PARAM_RECORD('em_target_type', 1,'oracle_sysman_database',NULL);
		l_job_params(7) := MGMT_JOB_PARAM_RECORD('em_target_username', 1, v_db_username, NULL);
		l_job_params(8) := MGMT_JOB_PARAM_RECORD('em_target_password', 1, v_db_password, NULL);

	ELSE

		l_job_params.EXTEND(1);
		l_job_params(6) := MGMT_JOB_PARAM_RECORD('em_target_type', 1,'oracle_sysman_node',NULL);		

	END IF;


--  Get the GMT time corresponding to the current session timezone
	BEGIN
		EXECUTE IMMEDIATE 'SELECT CAST( current_timestamp AS TIMESTAMP WITH TIME ZONE ) FROM DUAL ' INTO l_session_timestamp_zone;

		EXECUTE IMMEDIATE 'SELECT SYS_EXTRACT_UTC( :session_timestamp_with_zone) FROM DUAL' INTO l_gmt_time USING l_session_timestamp_zone;

	EXCEPTION
		WHEN OTHERS THEN
			RAISE_APPLICATION_ERROR(-20101,'Failed to get the session timezone ',TRUE);		
	END;

-- Group targets based on timezones before submitting jobs
	FOR rec IN ( 
			SELECT	DISTINCT timezone_delta,
				timezone_region
			FROM	mgmt_targets,
				TABLE ( CAST ( l_list_of_scheduled_targets as stringTable ) ) b
			WHERE	target_type = l_target_type
			AND	target_name = VALUE(b)
	 )
	LOOP
		
		-- List of targets for each timezone
		SELECT	VALUE(b)
		BULK COLLECT INTO l_zone_target_list
		FROM	mgmt_targets a,
			TABLE ( CAST ( l_list_of_scheduled_targets as stringTable ) ) b
		WHERE	a.timezone_delta = rec.timezone_delta
		AND 	a.timezone_region = rec.timezone_region
		AND	a.target_name = VALUE(b)
		AND	a.target_type = l_target_type;

		-- Submit job for the list of targets for each timezone
		IF l_zone_target_list IS NOT NULL AND l_zone_target_list.EXISTS(1) THEN

			
			-- Append the timezone abbrv to the job name
			-- SELECT tzname, tzabbrev, tz_offset(tzname) FROM V$TIMEZONE_NAMES gives 1:n mapping from time zone name to abbrv
			-- leaving the timezone name for now
			BEGIN
				SELECT	tzabbrev -- Timezone abbreviation, 
					-- tz_offset(tzname) 
				INTO	l_timezone_abbrv
				FROM	V$timezone_names
				WHERE	UPPER(tzname) = UPPER(rec.timezone_region)
				AND	ROWNUM = 1;

			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					l_timezone_abbrv := NVL(rec.timezone_region,'TZ:'||rec.timezone_delta);							
			END;

			l_timezone_abbrv := NVL(rec.timezone_region,'TZ:'||rec.timezone_delta);
			l_zone_job_name := l_job_name||'_'||l_timezone_abbrv;

			-- Get the time of execution of the target
			IF v_hour_of_execution > 0 THEN	
				l_start_time := TRUNC(l_start_time,'DD') + ( v_hour_of_execution / 24 );
			END IF;

			-- Schedule the next day if time has elapsed in the ' targets timezone 
			IF l_start_time <=  l_gmt_time+( rec.timezone_delta/(60*24)) THEN
				l_start_time := l_start_time + 1;
			END IF;

			l_schedule := MGMT_JOB_SCHEDULE_RECORD(
					MGMT_JOBS.INTERVAL_FREQUENCY_CODE,
		                        l_start_time,			-- Start time
					NULL,				-- end time
					0,				-- execution hours
					0,				-- execution minutes
					v_interval_hours*60,		-- Time interval in minutes
					NULL,				-- month
					NULL,				-- days
       	        		        MGMT_JOBS.TIMEZONE_TARGET,	-- Timezone info TIMEZONE_TARGET|TIMEZONE_REPOSITORY
					1,				-- target index from target list, whoze timezone is used 
					0);				-- timezone offset		

			l_job_targets := MGMT_JOB_TARGET_LIST();
			l_job_targets.extend(l_zone_target_list.COUNT);

			FOR i IN l_zone_target_list.FIRST..l_zone_target_list.LAST LOOP

				l_job_targets(i) := MGMT_JOB_TARGET_RECORD(l_zone_target_list(i), l_target_type);

			END LOOP;

			-- Check for a unique job name if this job name has already been used, this check doesnt take care of concurrency
			-- its a trivial check for now , should be adequate for GIT stop gap purposes, Have to do this as we dont lock.
			SELECT	COUNT(*)
			INTO	l_dummy
			FROM	mgmt_job
			WHERE	job_name = l_job_name;

			IF l_dummy > 0 THEN
				l_job_name := l_job_name||'_'||l_dummy;
			END IF;

			DBMS_OUTPUT.PUT_LINE(l_job_name||'-'||l_zone_job_name);

			-- Submit the job
			MGMT_JOBS.SUBMIT_JOB(
			l_zone_job_name,				-- jobname
			l_job_desc,					-- description
		        v_job_type,					-- jobtype
			l_job_targets,					-- job targets
			l_job_params,					-- job params
			l_schedule,					-- job schedule
			l_job_id,					-- job id	(out)
			l_execution_id					-- execution id (out)
									-- P_OWNER      VARCHAR2    IN     DEFAULT
									-- P_SYSTEM_JOB   NUMBER(38)  IN     DEFAULT
			);

		END IF;
	
	END LOOP;

	COMMIT;

	DBMS_OUTPUT.PUT_LINE('Job ' || l_job_name || ' of type '||v_job_type||' successfully submitted');

EXCEPTION
	WHEN OTHERS THEN

		ROLLBACK;
		DBMS_OUTPUT.PUT_LINE('Failed to schedule job '||l_job_name||' of type '||v_job_type);
		RAISE;

END execute_job;

BEGIN

	NULL;

END stormon_jobs;
/

CREATE OR REPLACE PUBLIC SYNONYM stormon_jobs FOR stormon_jobs
/

GRANT EXECUTE ON stormon_jobs TO PUBLIC
/
