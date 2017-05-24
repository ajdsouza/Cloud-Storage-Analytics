--  
--
-- Copyright  (c) 2001,2002  Oracle Corporation All rights reserved 
--
--
--
-- $Id: storage_summary_db_9i.sql,v 1.142 2004/01/29 01:33:13 ajdsouza Exp $ 
--
--
-- NAME  
--	 storage_summary_db_9i.sql
--
-- DESC 
--  DB I/O functions for analysis of storage metrics	
--
--
-- FUNCTIONS
--
--
-- NOTES
--
--
-- MODIFIED	(MM/DD/YY)
-- ajdsouza	10/01/01 	- Created package storage_summary
--
--


CREATE OR REPLACE PACKAGE storage_summary_db AS

-- public package variable for target_type
p_target_type_host	CONSTANT VARCHAR2(25) := 'oracle_sysman_node';
p_target_type_database	CONSTANT VARCHAR2(25) := 'oracle_sysman_database';

PROCEDURE	printstmt(v_string  IN VARCHAR2 );
FUNCTION	gettargetid(v_targetname	VARCHAR2) RETURN mgmt_targets_view.target_id%TYPE;

FUNCTION	getmetricguid(
				v_metricname		mgmt_metrics.metric_name%TYPE,
				v_metricColumn		mgmt_metrics.metric_column%TYPE
			)RETURN	mgmt_metrics.metric_guid%TYPE;

FUNCTION	getmetricguid(
				v_targettype		VARCHAR2,
				v_metricname		mgmt_metrics.metric_name%TYPE,
				v_metricColumn		mgmt_metrics.metric_column%TYPE
			)RETURN	mgmt_metrics.metric_guid%TYPE;

FUNCTION	getHostList RETURN stringTable;

PROCEDURE	refresh_targets;
PROCEDURE	refresh_mozart_targets;
PROCEDURE 	merge_targets;

PROCEDURE	migrate_targets ( 
		v_9i_target_id 		IN mgmt_targets_view.target_id%TYPE, 
		v_mozart_target_id 	IN mgmt_targets_view.target_id%TYPE
		);

PROCEDURE	refresh_dc_lob_groups;

PROCEDURE	deletelog(v_id	storage_log.target_id%TYPE);

PROCEDURE 	deleteIssues(v_id	storage_log.target_id%TYPE);

PROCEDURE	log(	v_id		storage_log.target_id%TYPE,
			v_message	storage_log.message%TYPE);

PROCEDURE	logError(	v_id		storage_log.target_id%TYPE,
				v_errmsg  	storage_log.message%TYPE);

PROCEDURE	logIssue(	v_id		storage_log.target_id%TYPE,
				v_message  	storage_log.message%TYPE);

PROCEDURE	logWarning(	v_id		storage_log.target_id%TYPE,
				v_message  	storage_log.message%TYPE);

PROCEDURE	log_time(
			v_job_name	IN storage_statistics.job_name%TYPE,
			v_id		IN storage_statistics.id%TYPE,
			v_name		IN storage_statistics.name%TYPE,			
			v_message	IN storage_statistics.message%TYPE,
			v_time		IN storage_statistics.time_seconds%TYPE);

PROCEDURE	getstoragediskcollection(
				v_targetid	mgmt_targets_view.target_id%TYPE,
				v_targetname	mgmt_targets_view.target_name%TYPE						
			);

PROCEDURE	getstorageswraidcollection(
				v_targetid	mgmt_targets_view.target_id%TYPE,
				v_targetname	mgmt_targets_view.target_name%TYPE				
			);

PROCEDURE	getstoragevolumecollection(
				v_targetid	mgmt_targets_view.target_id%TYPE,
				v_targetname	mgmt_targets_view.target_name%TYPE				
			);

PROCEDURE	getstoragefilesystemcollection(
				v_targetid	mgmt_targets_view.target_id%TYPE,
				v_targetname	mgmt_targets_view.target_name%TYPE				
			);

PROCEDURE	getstorageappcollection(v_targetid	mgmt_targets_view.target_id%TYPE,
					v_targetname 	mgmt_targets_view.target_name%TYPE				
				);

PROCEDURE 	insertsummary(v_summary	IN summaryObject);

PROCEDURE 	insertSummaryHistory(v_summary IN summaryObject );

FUNCTION	get_host_group_id(v_hostList IN stringTable, v_group_type VARCHAR2) RETURN VARCHAR2;

FUNCTION	get_host_group_id(v_hostList IN stringTable, v_group_type VARCHAR2, v_group_name VARCHAR2 ) RETURN VARCHAR2;

FUNCTION	concatlist(v_cursor IN sys_refcursor) 	RETURN VARCHAR2;

FUNCTION	gettime(v_lasttime IN OUT INTEGER) RETURN INTEGER;

PROCEDURE	gather_schema_statistics( v_schema_name  IN VARCHAR2 DEFAULT 'storage_rep');

END storage_summary_db;
/

SHOW ERROR;


CREATE OR REPLACE PACKAGE BODY storage_summary_db AS


------------------------------------------------------
-- Private package variables
------------------------------------------------------
p_group_query_list		stringTable := stringTable();

---------------------------------------------------------------------------------
-- FUNCTION NAME: gettime
--
-- DESC		:
-- Return the time in secs relative to the time passed in
-- Assumes time difference not more than a day
--
-- ARGS		:
--	Time in Secs (Optional)
---------------------------------------------------------------------------------
FUNCTION gettime(v_lasttime  IN OUT INTEGER) RETURN INTEGER IS

l_currenttime	INTEGER(20) := 0;
l_lasttime	INTEGER(20) := v_lasttime;

BEGIN

	-- Fetch the current time in secs since 12AM
	SELECT 	ROUND(TO_CHAR(sysdate,'SSSSSSS')/100)
	INTO 	l_currenttime 
	FROM 	DUAL;

	v_lasttime := l_currenttime;

	CASE	
		-- If both timestamps are of the same day
		WHEN l_currenttime >= l_lasttime THEN
			RETURN l_currenttime - l_lasttime;
		-- If timestamps are of different days
		-- base current secs on previous day ( 1 DAY = 86400 secs)
		ELSE
			RETURN (l_currenttime + 86400 ) - l_lasttime;
	END CASE;

END gettime;

-- Procedure Name : printstmt
-- Description    : dbms_out a long string
--                  
--          INPUT : string
--------------------------------------------------
PROCEDURE printstmt(v_string  IN VARCHAR2 ) IS

l_position		INTEGER := 1;

BEGIN

	WHILE ( LENGTH(SUBSTR(v_string,l_position)) > 0 ) LOOP

		DBMS_OUTPUT.PUT_LINE(SUBSTR(v_string,l_position,255));
		l_position := l_position + 255;
						
	END LOOP;

END printstmt;

-------------------------------------------------------------------------------
-- FUNCTION NAME: gettargetid
--
-- DESC 	: 
-- return the target_guid from mgmt_targets for a node target(host)
-- 
-- ARG
-- targetname (eg fintst1.us.oracle.com)
------------------------------------------------------------------------------
FUNCTION gettargetid(	v_targetname	VARCHAR2 ) RETURN mgmt_targets_view.target_id%TYPE IS

l_targetid 	mgmt_targets_view.target_id%TYPE := NULL;

BEGIN

	SELECT  target_id
	INTO	l_targetid
	FROM    mgmt_targets_view
	WHERE   target_name = v_targetname;

	RETURN l_targetid;

EXCEPTION

	WHEN OTHERS THEN
		RAISE_APPLICATION_ERROR(-20103,'Failed to fetch target id for target '||v_targetname,TRUE);

END gettargetid;


-------------------------------------------------------------------------------
-- FUNCTION NAME: getmetricguid
--
-- DESC 	: 
-- return the metric_guid field from mgmt_metrics for a metric_column
-- 
-- ARG
-- target_type	(optional)
-- metric_name
-- metric_column
------------------------------------------------------------------------------
FUNCTION getmetricguid
				 (
				  v_metricname   mgmt_metrics.metric_name%TYPE,
				  v_metricColumn mgmt_metrics.metric_column%TYPE
				 ) return mgmt_metrics.metric_guid%TYPE  IS

BEGIN

	RETURN storage_summary_db.getmetricguid(p_target_type_host,v_metricname,v_metricColumn);

END getmetricguid;



FUNCTION getmetricguid
				 (
					v_targettype   	VARCHAR2,
				  	v_metricname   	mgmt_metrics.metric_name%TYPE,
				  	v_metricColumn 	mgmt_metrics.metric_column%TYPE
				 ) return mgmt_metrics.metric_guid%TYPE IS

l_metricid	mgmt_metrics.metric_guid%TYPE := NULL;

BEGIN


	SELECT	metric_guid
	INTO	l_metricid
	FROM	mgmt_metrics
	WHERE	target_type   = v_targettype
	AND	metric_name   = v_metricname
	AND	metric_column = v_metricColumn;	

	RETURN l_metricid;

EXCEPTION

	WHEN OTHERS THEN
		RAISE_APPLICATION_ERROR(-20103,'Failed to fetch metrid id for type '||v_targettype||' metric name '||v_metricname,TRUE);

END  getmetricguid;


-------------------------------------------------------------------------------
-- FUNCTION NAME: getHostList
--
-- DESC 	: 
-- Return the list of all hosts in the repository
-- 
-- ARG
--
------------------------------------------------------------------------------
FUNCTION getHostList RETURN stringTable IS

l_targetTable	stringTable;

BEGIN

	SELECT	target_name
	BULK COLLECT INTO l_targetTable
	FROM	mgmt_targets_view;
--	WHERE	target_type = p_target_type_host;

	RETURN l_targetTable;

EXCEPTION

	WHEN OTHERS THEN
		RAISE_APPLICATION_ERROR(-20103,'Failed fetching the List of targets',TRUE);

END getHostList;

-------------------------------------------------------------------------------
-- FUNCTION NAME :	refresh_targets
--
-- DESC 	: 
-- Maintain a local copy of the table MGMT_TARGETS_NEW@OEMDTC.US.ORACLE.COM
-- 
--	DELETE ALL ROWS
--	INSERT NEW ROWS FROM MGMT_TARGETS_NEW@OEMDTC.US.ORACLE.COM
-- ARGS	:
--	
--
------------------------------------------------------------------------------
PROCEDURE refresh_targets IS

l_db_link_name	user_db_links.db_link%TYPE := 'OEMDTC.US.ORACLE.COM';
l_dummy		INTEGER;

BEGIN

-- Clean the issues for the target from storage_log ?? TBD


-- Check if there is a link oemdtc to the oemdatabase, refresh only if 
-- the link exists
--  I am using dynamic sql for compilation to be successful in the development database,
--  the link oemdtc is not available in the development database

	BEGIN
		SELECT	1
		INTO	l_dummy
		FROM	user_db_links
		WHERE	UPPER(db_link) = l_db_link_name;
	
	EXCEPTION

		WHEN NO_DATA_FOUND THEN
			STORAGE_SUMMARY_DB.PRINTSTMT('Database link to 9i '||l_db_link_name||' is not defined, skipping refreshing targets from 9i');
			RETURN;
	END;

--------------------------------------------------------------------------------------
--
-- Refresh the locally cached tables from OEMDTC using dblink
--
--	mgmt_targets 
--	node_target_map
--	smp_vdt_job_per_target from smp_vdt_job_per_targe@oemdtc ( table at oemdtc )
--
----------------------------------------------------------------------------------------
--
--	mgmt_targets from mgmt_targets_new@oemdtc ( view at oemdtc)
--
	DELETE FROM mgmt_targets;
	
	STORAGE_SUMMARY_DB.PRINTSTMT('Rows deleted from mgmt_targets '||SQL%ROWCOUNT);

	INSERT INTO mgmt_targets (
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
	SELECT	TO_CHAR(target_id)	,
		target_name		,
		target_type		,
		tz			,
		NVL(hosted,0)			,		-- 0 is not hosted, 1 is hosted
		NVL(location,'UNKNOWN')		,	
		NVL(datacenter,'OTHERS')		,
		NVL(support_group,'UNKNOWN')		,
		NVL(escalation_group,'UNKNOWN')	,
		NVL(owner,'UNKNOWN')			,
		NVL(business_owner,'UNKNOWN')  	,
		NVL(ip_address,'UNKNOWN')		,
		NVL(make,'UNKNOWN')			,
		NVL(model,'UNKNOWN')			,
		NVL(operating_system,'UNKNOWN')	
	FROM	MGMT_TARGETS_NEW@oemdtc;

	STORAGE_SUMMARY_DB.PRINTSTMT('Refreshed mgmt_targets from the 9i master , rows inserted '||SQL%ROWCOUNT);
--
--	node_target_map	from node_target_map@oemdtc ( view at oemdtc )
--

	DELETE FROM node_target_map;

	STORAGE_SUMMARY_DB.PRINTSTMT('Rows deleted from node_target_map '||SQL%ROWCOUNT);
	
	INSERT INTO node_target_map (
		node_name,
		target_name,
		target_type,
		agent_status,
		agent_state,
		agent_version,
		tns_address,
		tz
	)
	SELECT	node_name,
		target_name,
		target_type,
		agent_status,
		agent_state,
		agent_version,
		tns_address,
		tz
	FROM	node_target_map@oemdtc;

	STORAGE_SUMMARY_DB.PRINTSTMT('Refreshed node_target_map from the 9i master '||SQL%ROWCOUNT);

--
--	smp_vdt_job_per_target from smp_vdt_job_per_targe@oemdtc ( table at oemdtc )
--

------------------------------------------------------------------------------------------------------------------------------------
--STATUS
--Status of the job notification
--Oracle Enterprise Manager Administrator's Guide
--Release 9.2.0
--Part Number A96670-01
--    * 1 - Submitted - The Management Server has submitted the request to the Intelligent Agent and is waiting for a confirmation
--    * 2 - Scheduled - The Intelligent Agent has responded to the submit request and is now waiting till the actual execution time for the job to get executed
--    * 4 - Running - The job has been started
--    * 9 - Completed - The job terminated successfully (with an exit code of zero 0)
--    * 11 - Failed - The job failed. The exit code was non-zero
--    * 13 - Pending delete - An administrator requested a delete of a scheduled job. Waiting on Intelligent Agent confirmation
--    * 14 - Deleted - The Intelligent Agent has confirmed the delete of the job
--
--	Get only the stormon jobs, theIR job name starts with literals STORAGE and that have a start_time
------------------------------------------------------------------------------------------------------------------------------------

	DELETE FROM smp_vdj_job_per_target;

	STORAGE_SUMMARY_DB.PRINTSTMT('Rows deleted from smp_vdj_job_per_target '||SQL%ROWCOUNT);

	INSERT INTO smp_vdj_job_per_target
	(
		target_name,
		job_name,
		target_type,
		node_name,
		deliver_time,
		start_time,		-- in GMT
		finish_time,		-- In GMT
		next_exec_time,		-- in GMT
		occur_time,
		time_zone,		-- in Hours
		status
	)	
	SELECT	target_name,
		job_name,
		target_type,
		node_name,
		deliver_time,
		start_time,		-- This is in GMT
		finish_time,		-- This is in GMT
		next_exec_time,		-- This is in GMT
		occur_time,
		time_zone/(3600000),	-- Timezone is in milliseconds, this will convert it into hours
		DECODE(TO_CHAR(status),
			'1','SUBMITTED',
			'2','SCHEDULED',
			'4','EXECUTING',
			'9','COMPLETED',
			'11','FAILED',
			'13','SUSPENDED',
			'14','STOPPED',
			'15','INACTIVE',
			status
		)
	FROM	smp_vdj_job_per_target@oemdtc
	WHERE	job_name LIKE 'STORAGE%'
	AND	start_time IS NOT NULL;

	STORAGE_SUMMARY_DB.PRINTSTMT('Refreshed smp_vdj_job_per_target from the 9i master '||SQL%ROWCOUNT);

EXCEPTION
	WHEN OTHERS THEN					
		RAISE_APPLICATION_ERROR(-20103,'ERROR : Failed to refresh the target data from 9i ',TRUE);

END refresh_targets;


-------------------------------------------------------------------------------
-- FUNCTION NAME :	refresh_mozart_targets
--
-- DESC 	: 
-- Maintain a local copy of the target masters from the mozart database
-- 
--	DELETE ALL ROWS
--	INSERT NEW ROWS FROM mozartdb
-- ARGS	:
--	
--
------------------------------------------------------------------------------
PROCEDURE refresh_mozart_targets IS

l_mozart_db_link	user_db_links.db_link%TYPE := 'MOZARTDB.US.ORACLE.COM';
l_dummy			INTEGER;

BEGIN

-- Clean the issues for the target from storage_log ?? TBD

-- Check if there is a link mozartdb to the mozart database, refresh only if 
-- the link exists
-- I am using dynamic sql for compilation to be successful in the development database,
-- the link mozartdb may not be always available in the development database

	BEGIN
		SELECT	1
		INTO	l_dummy
		FROM	user_db_links
		WHERE	UPPER(db_link) = l_mozart_db_link;
	
	EXCEPTION

		WHEN NO_DATA_FOUND THEN
			STORAGE_SUMMARY_DB.PRINTSTMT('Database link to mozart '||l_mozart_db_link||' is not defined, skipping refreshing targets from 9i');
			RETURN;
	END;

--------------------------------------------------------------------------------------
--
-- Refresh the locally cached tables from MOZARTDB using dblink
--
--	mozart_mgmt_targets 
--	mozart_node_target_map
--	mozart_smp_vdt_job_per_target @mozartdb
--
----------------------------------------------------------------------------------------
--
--	mozart_mgmt_targets from mgmt_targets@mozartdb
--

	BEGIN

		DELETE FROM mozart_mgmt_targets;

		STORAGE_SUMMARY_DB.PRINTSTMT('Rows deleted from  mozart_mgmt_targets '||SQL%ROWCOUNT);

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
        	NULL		        ,
		NULL            	,
	        NULL              	,
	        NULL                    ,
	        NULL                    ,
	        NULL                    ,
	        NULL                    ,
	        NULL                    ,
	        NULL
		FROM	MGMT_TARGETS@mozartdb
		WHERE	target_type = 'host';


		STORAGE_SUMMARY_DB.PRINTSTMT('Refreshed mozart_mgmt_targets from the mozart master ros inserted '||SQL%ROWCOUNT);


		-- Update the data center and lob data for targets which are common with 9i, 
		-- targets common with 9i have the same name
		-- AT the moment this information is not stored in mozart, and has to be updated from the 9i-isis table which git provides in 9i

  		UPDATE	mozart_mgmt_targets a
	  	SET	( 
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
			) = (
  				SELECT	b.hosted		,
					b.location		,
					b.datacenter		,
					b.support_group		,
					b.escalation_group	,
					b.owner			,
					b.business_owner 	,
					b.ip_address		,
					b.make			,
					b.model			,
					b.operating_system
  				FROM	mgmt_targets b
  				WHERE	b.target_name = a.target_name
				AND	b.target_type = a.target_type
			)
		  WHERE	EXISTS (
				SELECT	1
				FROM	mgmt_targets c
				WHERE	c.target_name = a.target_name
				AND	c.target_type = a.target_type
			);
 
		STORAGE_SUMMARY_DB.PRINTSTMT('Updated datacenter, lob information in mozart_mgmt_targets from the 9i master , rows updated '||SQL%ROWCOUNT);
	
		-- Update the targets only in mozart and not in 9i with 'UNKNOWN' value for these fields
	  	UPDATE	mozart_mgmt_targets a
  		SET	( 
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
			) = (
  				SELECT	0,
					'OTHERS',		
					'UNKNOWN',
					'UNKNOWN',
					'UNKNOWN',
					'UNKNOWN',
					'UNKNOWN',
					'UNKNOWN',
					'UNKNOWN',
					'UNKNOWN',
					'UNKNOWN'
	  			FROM	DUAL
			)
		  WHERE	NOT EXISTS (
				SELECT	1
				FROM	mgmt_targets c
				WHERE	c.target_name = a.target_name
				AND	c.target_type = a.target_type
			);

		STORAGE_SUMMARY_DB.PRINTSTMT('Updated datacenter, lob information to UNKNOWN in mozart_mgmt_targets , rows updated '||SQL%ROWCOUNT);

	EXCEPTION
		WHEN OTHERS THEN
			RAISE_APPLICATION_ERROR(-20103,'ERROR : Failed to refresh mozart_mgmt_targets from the mozart master ',TRUE);			
	END;





	BEGIN

		-- Refreshing node_target_map
		DELETE FROM mozart_node_target_map;

		STORAGE_SUMMARY_DB.PRINTSTMT('Rows deleted from  mozart_node_target_map '||SQL%ROWCOUNT);

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
		DECODE(target_type,'oracle_database','oracle_sysman_database','host','oracle_sysman_node',target_type),
		NULL,
		NULL,
		NULL,
		NULL,
		timezone_delta/60
		FROM	mgmt_targets@mozartdb
		WHERE	target_type IN ('oracle_database','host');

		STORAGE_SUMMARY_DB.PRINTSTMT('Refreshed mozart_node_target_map from the mozart master , rows inserted '||SQL%ROWCOUNT);

	EXCEPTION
		WHEN OTHERS THEN
			RAISE_APPLICATION_ERROR(-20103,'ERROR : Failed to refresh mozart_node_target_map from the mozart master ',TRUE);			
	END;

	-- Refreshing mozart_smp_vdj_job_per_target
	
	-- This query will return one status for the whole target_list
	-- To get the status for each target in the list then we need to join mgmt_job_step_target to mgmt_job_history
	-- Using the stepid
	-- Predicate on mgmt_job_history is step_type= 1 and get the status form this table
	--
	-- Will be implemented here once vijay gives us access to these tables for storemon in the aoemp_dbs01 database of em4.0 pilot system
	-- TBD

	-- From the functional spec for the job system
	-- Constants for status
	--
	-- SCHEDULED_STATUS constant NUMBER(2) := 1;
	-- EXECUTING_STATUS constant NUMBER(2) := 2;
	-- ABORTED_STATUS constant NUMBER(2) := 3;
	-- FAILED_STATUS constant NUMBER(2) := 4;
	-- COMPLETED_STATUS constant NUMBER(2) := 5;
	-- SUSPENDED_STATUS constant NUMBER(2) := 6;
	-- AGENTDOWN_STATUS constant NUMBER(2) := 7;
	-- STOPPED_STATUS constant NUMBER(2) := 8;
	-- SUSPENDED_LOCK_STATUS constant NUMBER(2) := 9;


	BEGIN

		DELETE FROM mozart_smp_vdj_job_per_target;

		STORAGE_SUMMARY_DB.PRINTSTMT('Rows deleted from  mozart_smp_vdj_job_per_target '||SQL%ROWCOUNT);

		INSERT INTO mozart_smp_vdj_job_per_target
		(
		target_name,
		job_name,
		target_type,
		node_name,
		deliver_time,
		start_time,		-- in GMT
		finish_time,		-- in GMT
		next_exec_time,
		occur_time,
		time_zone,		-- in HOURS
		status
		)
		SELECT  a.target_name,						
		        c.job_name,						
	        	DECODE(LOWER(a.target_type),'host','oracle_sysman_node','oracle_database','oracle_sysman_database',a.target_type),
		        a.host_name,						
	        	NULL,							
		        c.start_time start_time,				-- start_time in GMT
	        	c.end_time end_time, 					-- finish_time in GMT
			NULL, 							-- next_exec_time
			NULL, 							-- occur_time
			a.timezone_delta/60, 					-- timezone in HOURS
			DECODE(c.status,
				1,'SCHEDULED',
				2,'EXECUTING',
				3,'FAILED',
				4,'FAILED',
				5,'COMPLETED',
				6,'SUSPENDED',
				7,'FAILED',
				8,'STOPPED',
				9,'INACTIVE',
				c.status			
			)
		FROM    mgmt_targets@mozartdb a,
		        mgmt_job_target@mozartdb b,
	        (	
			-- The AGGREGATE AND ANALYTIC FUNCTION ENSURE THAT WE PICK THE start_time, end_time and status from the same execution, namely the last execution or if it does not exist the
			-- executing job or if not the scheduled job
	                SELECT  y.job_id job_id,
        	                y.job_name,
				-- This ensures that we get the status for the target_list the target is part of , than the timestamp for the whole job
				x.target_list_index,		
				-- SYS_EXTRACT_UTC extracts the UTC (Coordinated Universal Time--formerly Greenwich Mean Time) from a datetime with time zone displacement
        	                SYS_EXTRACT_UTC( MAX(x.display_start_time) KEEP ( DENSE_RANK FIRST ORDER BY DECODE(x.status,1,1,2,2,3) DESC ,x.display_start_time DESC NULLS LAST ) ) start_time, 	-- TIMESTAMP WITH TIMEZONE 
				SYS_EXTRACT_UTC( MAX(x.display_end_time) KEEP ( DENSE_RANK FIRST ORDER BY DECODE(x.status,1,1,2,2,3) DESC ,x.display_start_time DESC NULLS LAST )  ) end_time, 	-- TIMESTAMP WITH TIMEZONE
				MAX(x.status) KEEP ( DENSE_RANK FIRST ORDER BY DECODE(x.status,1,1,2,2,3) DESC, x.display_start_time DESC NULLS LAST )  status
	                FROM    mgmt_job_exec_summary@mozartdb x,
        	                mgmt_job@mozartdb y
                	WHERE   y.job_type IN ('StormonHostJobs','StormonDbJobs')
	                AND     x.job_id = y.job_id
        	        GROUP BY
                	        y.job_id,
                        	y.job_name,
				x.target_list_index
        	) c
		WHERE   b.job_id = c.job_id
		AND     a.target_guid = b.target_guid
		AND	b.target_list_index = c.target_list_index		-- This ensures that we get the status for the ob on each host, than the timestamp for the whole job
		AND	c.start_time IS NOT NULL
		AND	a.target_type IN ('host','oracle_database');
	

		STORAGE_SUMMARY_DB.PRINTSTMT('Refreshed mozart_smp_vdj_job_per_target from the mozart master ,rows inserted '||SQL%ROWCOUNT);

	EXCEPTION
		WHEN OTHERS THEN
			RAISE_APPLICATION_ERROR(-20103,'ERROR : Failed to refresh mozart_smp_vdj_job_per_target from the mozart master ',TRUE);
	END;


EXCEPTION
	WHEN OTHERS THEN			
		RAISE_APPLICATION_ERROR(-20103,'ERROR : Failed to refresh target data from mozart ',TRUE);

END refresh_mozart_targets;


/*-----------------------------------------------------------------------------------------
     PROCEDURE NAME :  merge_targets
    
     DESC   : 
		Identifies the targets that need to be migrated and inserts them into
		the mgmt_migrated_targets table

		Refresfed the mgmt_targets_merged to hold the common master from 9i and mozart
		( For performance reasons we use a table to hold data than a view )		
    
		Clean up the groups with targets not in the mgmt_targets_view table

     ARGS  :
-------------------------------------------------------------------------------------------*/  
PROCEDURE merge_targets
IS

	l_time					INTEGER := 0;

BEGIN

-- Migration is based on the following assumptions
--
-- 1. The target_name remains the same between mozart and the current 9i system
-- 2. The target_name to target_id map will ALWAYS REMAIN FIXED IN in both the mozart and 9i system
--    There is no facility and plan currently to reuse target_ids in both mozart and 9i, so it seems this is a safe assumption
--
-- 3. In case a target_name of mozart is not present in 9i, then its a new target, and it does not require migration
-- 4. Targets in 9i which do not have data collection in mozart will continue to be treated as 9i targets 
--
	
	l_time := STORAGE_SUMMARY_DB.GETTIME(l_time);

	-----------------------------------------------------------------------------------------------------------
	-- Insert the list of targets to be migrated in this run into the mgmt_migrated_targets table
	-----------------------------------------------------------------------------------------------------------
	BEGIN
		INSERT 	INTO mgmt_migrated_targets (
			original_target_id, 
			mozart_target_id,
			target_name			
		)
		SELECT	original_target_id, 
			mozart_target_id, 
			target_name
		FROM	mgmt_targets_to_be_migrated;

		STORAGE_SUMMARY_DB.PRINTSTMT(' Number of Targets to be migrated from 9i to mozart is '||SQL%ROWCOUNT);

	EXCEPTION
		WHEN NO_DATA_FOUND THEN 
			NULL;
		WHEN OTHERS THEN		    
			RAISE;
	END;
    
	STORAGE_SUMMARY_DB.PRINTSTMT('Time taken to insert the to be migrated targets '||STORAGE_SUMMARY_DB.GETTIME(l_time));


	-----------------------------------------------------------------------------------------------------------
	-- Refresh the merged targets table, Its better to have amerged table than a view for performace reasons
	-- This can be a materialized view with a on commit refresh TBD
	-----------------------------------------------------------------------------------------------------------
	BEGIN
		DELETE FROM mgmt_targets_merged;

		STORAGE_SUMMARY_DB.PRINTSTMT(' Targets deleted from mgmt_targets_merged is '||SQL%ROWCOUNT);

		INSERT 	INTO mgmt_targets_merged(
			target_id,	
			target_name,													   
			target_type,														    
			tz,															
			hosted,  
			location,														    
			datacenter,														    
			support_group,														    
			escalation_group,													    
			owner,															    
			business_owner, 													    
			ip_address,														    
			make,														    
			model,															    
			operating_system
		)
		SELECT	target_id,	
			target_name,													   
			target_type,														    
			tz,															
			hosted,  
			location,														    
			datacenter,														    
			support_group,														    
			escalation_group,													    
			owner,															    
			business_owner, 													    
			ip_address,														    
			make,														    
			model,															    
			operating_system
		FROM	mgmt_targets_merged_view;

		STORAGE_SUMMARY_DB.PRINTSTMT(' Targets inserted into mgmt_targets_merged is '||SQL%ROWCOUNT);

	EXCEPTION
		WHEN OTHERS THEN		    
			RAISE;
	END;
    
	STORAGE_SUMMARY_DB.PRINTSTMT('Time taken to refresh the mgmt_targets_merged table is '||STORAGE_SUMMARY_DB.GETTIME(l_time));

EXCEPTION
	WHEN OTHERS THEN					
		RAISE_APPLICATION_ERROR(-20103,'ERROR : Failed to merge targets from 9i and mozart ',TRUE);		

END merge_targets;


/*-----------------------------------------------------------------------------------------
     PROCEDURE NAME :  migrate_targets
    
     DESC   : 
       Migrates the history and configuraton data from 9i for targets which have started 
       loading data thru mozart.
       
       For migrating a target, we update the target ids of all 
       relevant tables that form the source of summarization AND 
       rollup data (this includes summary details, rollup tables,
       group configuration tables) - the updation involves changing 
       the target_id for the selected target to the mozart target_id.
       
       If the above step is successful, we do an INSERT of the target 
       INTO the table mgmt_migrated_targets to mark it as migrated.
    
     ARGS  :
-------------------------------------------------------------------------------------------*/  
PROCEDURE migrate_targets ( 
		v_9i_target_id 		IN mgmt_targets_view.target_id%TYPE, 
		v_mozart_target_id 	IN mgmt_targets_view.target_id%TYPE
)
IS

	TYPE table_config IS RECORD (
					table_list      stringTable,
					column_list     stringTable
				);

	l_tables_to_update			table_config;
	l_time					INTEGER := 0;

BEGIN

-- Migration is based on the following assumptions
--
-- 1. The target_name remains the same between mozart and the current 9i system
-- 2. The target_name to target_id map will ALWAYS REMAIN FIXED IN in both the mozart and 9i system
--    There is no facility and plan currently to reuse target_ids in both mozart and 9i, so it seems this is a safe assumption
--
-- 3. In case a target_name of mozart is not present in 9i, then its a new target, and it does not require migration
-- 4. Targets in 9i which do not have data collection in mozart will continue to be treated as 9i targets 
--

     /* first step is to INSERT INTO the table mgmt_migrated_targets
        all the values that need to be migrated - this gets a 
        snapshot of targets that will be migrated. Logically,
        this step should come last but I wanted to get a
        snapshot of the targets to be migrated (without locking)
        for all the subsequent updates. Of course transactionally
        it does not matter whether you INSERT first or last.
 
        Please note that mgmt_migrated_targets would have previously
        migrated targets. Hence the select FROM this table for
        updates should include "WHERE migrated_on = l_sysdate"
        clause to migrate only the new targets that need migration.
      */

    /*
      first is the table list WHERE the target_id column 
      is "TARGET_ID"
  
      . storage_localfs_table
      . storage_application_table
      . storage_nfs_table
      . storage_volume_table
      . storage_swraid_table
      . storage_disk_table
      . storage_hostdetail
      . storage_log
      . stormon_host_groups
  
      then the table list WHERE the target_id column is "ID"
  
        storage_statistics
      . storage_history_52weeks
      . storage_history_30days
      . storage_summaryobject_history
      . storage_summaryobject

      I suspect that some other tables may need to be updated
      as well. Here is a list of tables that have target_id as
      a column name - that I have not covered in this procedure.
  
      . mgmt_targets  
  
      I think most likely the above table doesn't need to be migrated.
     */
	
	-- Just a cursory check	
	IF v_9i_target_id IS NULL OR v_mozart_target_id IS NULL THEN
		RETURN;
	END IF;

	l_tables_to_update.table_list :=        stringTable(
						'storage_localfs_table',
						'storage_application_table',
						'storage_nfs_table',
						'storage_volume_table',
						'storage_swraid_table',						
						'storage_disk_table',	
						'storage_log',
	                                        'stormon_host_groups',
						'storage_history_52weeks',
						'storage_history_30days',
						'storage_summaryobject_history',
						'storage_summaryobject',
						'storage_statistics',
						'stormon_load_status'
                                        );

	l_tables_to_update.column_list := stringTable(	                                        
        	                                'target_id',
                	                        'target_id',
                        	                'target_id',
                                	        'target_id',
	                                        'target_id',
        	                                'target_id',                       
                        	                'target_id',
                                	        'target_id',
                                        	'id',
	                                        'id',
        	                                'id',
                	                        'id',
						'id',
						'node_id'
                        	        );

	l_time := STORAGE_SUMMARY_DB.GETTIME(l_time);

	FOR i IN l_tables_to_update.table_list.FIRST..l_tables_to_update.table_list.LAST LOOP
	
			BEGIN
						
				EXECUTE IMMEDIATE 
				'
				UPDATE	'||l_tables_to_update.table_list(i)||' a
				SET 	a.'||l_tables_to_update.column_list(i)||' =  :1
				WHERE	a.'||l_tables_to_update.column_list(i)||' = :2
				'
				USING v_mozart_target_id, v_9i_target_id;	
	
				STORAGE_SUMMARY_DB.PRINTSTMT( 'Migrated table '||l_tables_to_update.table_list(i)||' '||l_tables_to_update.column_list(i)||' '||SQL%ROWCOUNT );
	
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					STORAGE_SUMMARY_DB.PRINTSTMT( 'No rows to update in table to be migrated '||l_tables_to_update.table_list(i)||' for field '||l_tables_to_update.column_list(i));
				WHEN OTHERS THEN
					RAISE;
			END;
	
			STORAGE_SUMMARY_DB.PRINTSTMT('Time taken to migrate the table  '||l_tables_to_update.table_list(i)||' is '||STORAGE_SUMMARY_DB.GETTIME(l_time));
	
	END LOOP;

	-----------------------------------------------------------------------
	-- Update the status of the migrated mozart target in the 
	-- mgmt_migrated_targets table
	-----------------------------------------------------------------------
	UPDATE	mgmt_migrated_targets
	SET	status = 'MIGRATED'
	WHERE	mozart_target_id = v_mozart_target_id;


EXCEPTION
	WHEN OTHERS THEN					
		RAISE_APPLICATION_ERROR(-20103,'ERROR : Failed to migrate targets from 9i to mozart ',TRUE);				

END migrate_targets;

-------------------------------------------------------------------------------
-- FUNCTION NAME :	deletelog
--
-- DESC 	: 
-- Delete all errors and debug messages for a target
-- 
-- ARGS	:
--	host idenification (name or id)
--
------------------------------------------------------------------------------
PROCEDURE deletelog( v_id	storage_log.target_id%TYPE) IS

-- log is a autonomous transaction , independent of the main transaction
-- TBD
PRAGMA AUTONOMOUS_TRANSACTION;

BEGIN

-- Clean the issues for the target from storage_log
	DELETE FROM storage_log 
	WHERE	target_id = v_id
	AND	type IN ('DEBUG','ERROR');

	COMMIT;

EXCEPTION
	WHEN OTHERS THEN		

		ROLLBACK;		

		RAISE_APPLICATION_ERROR(-20103,'ERROR : Failed to delete log for '||v_id,TRUE);		

END deletelog;


-------------------------------------------------------------------------------
-- FUNCTION NAME :	deleteIssues
--
-- DESC 	: 
-- Delete all issues and warning messages for a target
-- 
-- ARGS	:
--	host idenification (name or id)
--
------------------------------------------------------------------------------
PROCEDURE deleteIssues( v_id	storage_log.target_id%TYPE) IS

BEGIN

-- Clean the issues for the target from storage_log
	DELETE FROM storage_log 
	WHERE	target_id = v_id
	AND	type IN ('ISSUE','WARNING');

EXCEPTION
	WHEN OTHERS THEN		
		
		RAISE_APPLICATION_ERROR(-20103,'ERROR : Failed to delete issues for '||v_id,TRUE);		
		

END deleteIssues;


-------------------------------------------------------------------------------
-- FUNCTION NAME :	log
--
-- DESC 	: 
-- Log processing messages to the log table
-- 
-- ARGS	:
--	host idenification (name or id)
--	message	
--
------------------------------------------------------------------------------
PROCEDURE log(	v_id		storage_log.target_id%TYPE,
		v_message	storage_log.message%TYPE ) IS

-- log is a autonomous transaction , independent of the main transaction
-- TBD
PRAGMA AUTONOMOUS_TRANSACTION;

BEGIN

	STORAGE_SUMMARY_DB.PRINTSTMT('DEBUG '||v_id||' '||v_message);

	INSERT INTO storage_log(target_id,timestamp,type,location,message)
		VALUES(
			v_id,
			SYSDATE,
			'DEBUG',
			'STORAGE_SUMMARY',
			v_message);
	COMMIT;

EXCEPTION
	WHEN OTHERS THEN

		ROLLBACK;
		
		RAISE_APPLICATION_ERROR(-20103,'ERROR : Failed to Log this debug message for '||v_id,TRUE);		
		
END log;

-------------------------------------------------------------------------------
-- FUNCTION NAME :	logerror
--
-- DESC 	: 
-- Log processing errors to the log table
-- 
-- ARGS	:
--	host idenification (name or id)
--	error_message
--
------------------------------------------------------------------------------
PROCEDURE logError( v_id	storage_log.target_id%TYPE,
		  v_errmsg  	storage_log.message%TYPE ) IS

-- Error log is a autonomous transaction , independent of the main transaction
-- TBD
PRAGMA AUTONOMOUS_TRANSACTION;

BEGIN

	STORAGE_SUMMARY_DB.PRINTSTMT('ERROR : '||v_id||' '||v_errmsg);

	INSERT INTO storage_log(target_id,timestamp,type,location,message)
		VALUES
			 (
				v_id,
				SYSDATE,							
				'ERROR',
				'STORAGE_SUMMARY',
				v_errmsg
			 );
	COMMIT;

EXCEPTION
	WHEN OTHERS THEN

		ROLLBACK;		

		RAISE_APPLICATION_ERROR(-20103,'ERROR : Failed to Log this error message for '||v_id,TRUE);		
		

END logError;


-------------------------------------------------------------------------------
-- FUNCTION NAME :	logIssue
--
-- DESC 	: 
-- Log Analysis issues for a target into the log table
-- 
-- ARGS	:
--	host idenification (name or id)
--	message
--
------------------------------------------------------------------------------
PROCEDURE logIssue(	v_id	storage_log.target_id%TYPE,
			v_message  	storage_log.message%TYPE ) IS


BEGIN

	STORAGE_SUMMARY_DB.PRINTSTMT('ISSUE : '||v_id||' '||v_message);

	INSERT INTO storage_log(target_id,timestamp,type,location,message)
		VALUES
			 (
				v_id,
				SYSDATE,
				'ISSUE',					
				'STORAGE_SUMMARY',		
				v_message
			 );

EXCEPTION
	WHEN OTHERS THEN
		
		RAISE_APPLICATION_ERROR(-20103,'ERROR : Failed to Log this issue message for '||v_id,TRUE);		

END logIssue;


-------------------------------------------------------------------------------
-- FUNCTION NAME :	logWarning
--
-- DESC 	: 
-- Log analysis warnings to the log table
-- 
-- ARGS	:
--	host idenification (name or id)
--	error_message
--
------------------------------------------------------------------------------
PROCEDURE logWarning(	v_id		storage_log.target_id%TYPE,
			v_message  	storage_log.message%TYPE ) IS

BEGIN

	STORAGE_SUMMARY_DB.PRINTSTMT('WARNING : '||v_id||' '||v_message);

	INSERT INTO storage_log(target_id,timestamp,type,location,message)
		VALUES
			 (
				v_id,
				SYSDATE,							
				'WARNING',
				'STORAGE_SUMMARY',
				v_message
			 );

EXCEPTION
	WHEN OTHERS THEN
		
		RAISE_APPLICATION_ERROR(-20103,'ERROR : Failed to Log this warning message for '||v_id,TRUE);				

END logWarning;


-------------------------------------------------------------------------------
-- FUNCTION NAME :	log_time
--
-- DESC 	: 
-- Log time statistics to the storage_statistics table
-- 
-- ARGS	:
--	job_name, id, name, message, time
--	
--
------------------------------------------------------------------------------
PROCEDURE log_time(
			v_job_name	IN storage_statistics.job_name%TYPE,
			v_id		IN storage_statistics.id%TYPE,
			v_name		IN storage_statistics.name%TYPE,			
			v_message	IN storage_statistics.message%TYPE,
			v_time		IN storage_statistics.time_seconds%TYPE
		) IS

-- Error log is a autonomous transaction , independent of the main transaction
-- TBD
PRAGMA AUTONOMOUS_TRANSACTION;

BEGIN

	STORAGE_SUMMARY_DB.PRINTSTMT('Time taken: '||v_id||' '||v_message||' '||v_time);

	INSERT INTO storage_statistics(job_name,timestamp,id,name,message,time_seconds)
	VALUES	 (
			v_job_name,
			SYSDATE,
--			UTL_RAW.CAST_TO_RAW(v_id),							
			v_id,
			v_name,
			v_message,
			v_time
		 );

	COMMIT;

EXCEPTION
	WHEN OTHERS THEN

		ROLLBACK;

		RAISE_APPLICATION_ERROR(-20103,'ERROR : Failed to Log to storage_statistics '||v_id,TRUE);		
				
END log_time;


-------------------------------------------------------------------------------
-- PROCEDURE NAME: getstoragediskcollection
--
-- DESC 	: 
-- Get a snapshot of the relevent disk metric data 
-- 
-- ARG
-- target_guid
-- target_name
------------------------------------------------------------------------------ 
PROCEDURE getstoragediskcollection
				 (
				  v_targetid mgmt_targets_view.target_id%TYPE,
				  v_targetname mgmt_targets_view.target_name%TYPE				  
				 ) IS

l_capacityguid	  	mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'disk_devices','disk_devices_capacity');
l_vendorguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'disk_devices','disk_devices_vendor');
l_productguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'disk_devices','disk_devices_product');
l_configurationguid	mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'disk_devices','disk_devices_configuration');
l_typeguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'disk_devices','disk_devices_type');
l_inodeguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'disk_devices','disk_devices_inode');
l_slicekeyguid	  	mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'disk_devices','disk_devices_slice_key');
l_diskkeyguid	    	mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'disk_devices','disk_devices_disk_key'); 
l_filetypeguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'disk_devices','disk_devices_filetype');
l_pathguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'disk_devices','disk_devices_logical_name');
l_formatguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'disk_devices','disk_devices_device_status');

BEGIN

DELETE FROM stormon_temp_disk;

INSERT INTO stormon_temp_disk (
	rowcount		,	
	target_id		, 	 /* is RAW(16) in git3       */
	targetname		,	-- Target name
	keyvalue		, 	/* is varchar2(256) in git3 */
	collection_timestamp	,
	rawsizeb		,
	sizeb			,
	usedb			,
	freeb			,
	storagevendor		,
	storageproduct		,
	storageconfig		,
 	type			,	-- DISK,SLICE,SUBDISK
	filetype		,	-- BLOCK OR CHARACTER
	linkinode		,	
	diskkey			,
	path			,	-- OS Path
	status			,	-- Formatted or unformatted,OFFLINE
	parent			,	-- SWRAID parent
	backup			,	-- Y/N flag for backup elements
	freetype			
)
SELECT 	rownum,			-- rownum
	v_targetid ,		-- target_id
	v_targetname ,		-- targetname
	j.string_value,		-- keyvalue = slicekey
	a.collection_timestamp,	-- collection_timestamp
	0,			-- rawsizeb
	NVL(a.value,0) ,	-- sizeb
	0,			-- usedb
	0,			-- freeb
	b.string_value ,	-- storagevendor
	c.string_value ,	-- storageproduct
	d.string_value ,	-- storageconfig
	DECODE(f.string_value,'SLICE','PARTITION',f.string_value) , -- type
	k.string_value ,	-- filetype
	g.string_value ,	-- linkinode
  	i.string_value ,	-- diskkey
	l.string_value ,	-- path	
	m.string_value ,	-- status
	NULL,			-- swraid parent
	'N',			-- backup
	NULL			-- freetype
FROM	mgmt_current_metrics a,
	mgmt_current_metrics b,
	mgmt_current_metrics c,
	mgmt_current_metrics d,
	mgmt_current_metrics f,
	mgmt_current_metrics g,
	mgmt_current_metrics i,
	mgmt_current_metrics j,
	mgmt_current_metrics k,
	mgmt_current_metrics l,
	mgmt_current_metrics m
WHERE	a.target_guid  = v_targetid
AND	b.target_guid  = a.target_guid
AND	c.target_guid  = a.target_guid
AND	d.target_guid  = a.target_guid
AND	f.target_guid  = a.target_guid
AND	g.target_guid  = a.target_guid
AND	i.target_guid  = a.target_guid
AND	j.target_guid  = a.target_guid
AND	k.target_guid  = a.target_guid
AND	l.target_guid  = a.target_guid
AND	m.target_guid  = a.target_guid
AND	b.key_value    = a.key_value
AND	c.key_value    = a.key_value
AND	d.key_value    = a.key_value
AND	f.key_value    = a.key_value
AND	g.key_value    = a.key_value
AND	i.key_value    = a.key_value
AND	j.key_value    = a.key_value
AND	k.key_value    = a.key_value
AND	l.key_value    = a.key_value
AND	m.key_value    = a.key_value
AND	a.metric_guid  = l_capacityguid
AND	b.metric_guid  = l_vendorguid
AND	c.metric_guid  = l_productguid
AND	d.metric_guid  = l_configurationguid
AND	f.metric_guid  = l_typeguid
AND	g.metric_guid  = l_inodeguid
AND	i.metric_guid  = l_diskkeyguid
AND	j.metric_guid  = l_slicekeyguid
AND	k.metric_guid  = l_filetypeguid
AND	l.metric_guid  = l_pathguid
AND	m.metric_guid  = l_formatguid;

END getstoragediskcollection;

-------------------------------------------------------------------------------
-- PROCEDURE NAME: getstorageswraidcollection
--
-- DESC 	: 
-- Get a snapshot of the  metric data for swraid manager
-- 
-- ARG
-- target_guid
-- target_name
------------------------------------------------------------------------------ 
PROCEDURE getstorageswraidcollection
				 (
				  v_targetid   mgmt_targets_view.target_id%TYPE,
				  v_targetname mgmt_targets_view.target_name%TYPE		
				 ) IS

l_typeguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_swraid','storage_swraid_type');
l_filetypeguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_swraid','storage_swraid_filetype');
l_nameguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_swraid','storage_swraid_name'); /* is storage_swraid_logical_name in git3 */
l_inodeguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_swraid','storage_swraid_inode'); /* is storage_swraid_inode_raw in git3 */
l_diskkeyguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_swraid','storage_swraid_diskkey');
l_slicekeyguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_swraid','storage_swraid_slicekey');
l_sizeguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_swraid','storage_swraid_size');
l_configguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_swraid','storage_swraid_configuration');
l_parentguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_swraid','storage_swraid_parent');

BEGIN

DELETE FROM stormon_temp_swraid;

INSERT INTO stormon_temp_swraid(
	rowcount		,	
	target_id		, 	 /* is RAW(16) in git3       */
	targetname		,	-- Target name
	keyvalue		, 	/* is varchar2(256) in git3 */
	collection_timestamp	,
	rawsizeb		,
	sizeb			,
	usedb			,
	freeb			,
	storagevendor		,
	storageproduct		,
	storageconfig		,
 	type			,	-- DISK,SLICE,SUBDISK
	filetype		,	-- BLOCK OR CHARACTER
	linkinode		,	
	diskkey			,
	path			,	-- OS Path
	status			,	-- Formatted or unformatted,OFFLINE
	parent			,	-- SWRAID parent
	backup			,	-- Y/N flag for backup elements
	freetype			
)
SELECT	rownum,			-- rownum
	v_targetid,		-- target_id
	v_targetname,		-- targetname
	f.string_value,		-- keyvalue = slicekey
	a.collection_timestamp,	-- collection_timestamp
	0,			-- rawsizeb
	NVL(g.value,0),		-- sizeb
	0,			-- usedb
	0,			-- freeb
	NULL,			-- storagevendor
	NULL,			-- storageproduct
	h.string_value,		-- storageconfig
	a.string_value,		-- type
	b.string_value,		-- filetype
	d.string_value,		-- linkinode
	e.string_value,		-- diskkey
	c.string_value,		-- path	
	'UNFORMATTED',		-- status
	i.string_value,		-- swraid parent
	'N',			-- backup
	NULL			-- freetype			
FROM	mgmt_current_metrics a,
	mgmt_current_metrics b,
	mgmt_current_metrics c,
	mgmt_current_metrics d,
	mgmt_current_metrics e,
	mgmt_current_metrics f,
	mgmt_current_metrics g,
	mgmt_current_metrics h,
	mgmt_current_metrics i
WHERE a.target_guid = v_targetid
AND   b.target_guid = a.target_guid
AND   c.target_guid = a.target_guid
AND   d.target_guid = a.target_guid
AND   e.target_guid = a.target_guid
AND   f.target_guid = a.target_guid
AND   g.target_guid = a.target_guid
AND   h.target_guid = a.target_guid
AND   i.target_guid = a.target_guid
AND   b.key_value   = a.key_value
AND   c.key_value   = a.key_value
AND   d.key_value   = a.key_value
AND   e.key_value   = a.key_value
AND   f.key_value   = a.key_value
AND   g.key_value   = a.key_value
AND   h.key_value   = a.key_value
AND   i.key_value   = a.key_value
AND   a.metric_guid = l_typeguid
AND   b.metric_guid = l_filetypeguid
AND   c.metric_guid = l_nameguid
AND   d.metric_guid = l_inodeguid
AND   e.metric_guid = l_diskkeyguid
AND   f.metric_guid = l_slicekeyguid
AND   g.metric_guid = l_sizeguid
AND   h.metric_guid = l_configguid
AND   i.metric_guid = l_parentguid;

END getstorageswraidcollection;


-------------------------------------------------------------------------------
-- PROCEDURE NAME: getstoragevolumecollection
--
-- DESC 	: 
-- Get a snapshot of the  metric data for volume manager
-- 
-- ARG
-- target_guid
-- target_name
------------------------------------------------------------------------------ 
PROCEDURE getstoragevolumecollection
				 (
				   	v_targetid mgmt_targets_view.target_id%TYPE,
					v_targetname mgmt_targets_view.target_name%TYPE				
				 ) IS

l_voltypeguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_volume_layers','storage_volume_layers_type');
l_volnameguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_volume_layers','storage_volume_layers_name');
l_volsizeguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_volume_layers','storage_volume_layers_size');
l_volinodeguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_volume_layers','storage_volume_layers_inode');
l_volpathguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_volume_layers','storage_volume_layers_path');
l_volfiletypeguid	mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_volume_layers','storage_volume_layers_filetype');
l_volgroup		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_volume_layers','storage_volume_layers_diskgroup');
l_configguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_volume_layers','storage_volume_layers_config');
l_voldisknameguid	mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_volume_layers','storage_volume_layers_diskname');

BEGIN

DELETE FROM stormon_temp_volume;

INSERT INTO stormon_temp_volume(
	rowcount		,
  	target_id		, /* is RAW(16) in git3       */
	targetname		,	-- Target name
  	keyvalue		, /* is varchar2 in git3 */
	collection_timestamp	,
	type			,	-- VOLUME, DISK, DISKSLICE
	name			,
	diskgroup		,
	rawsizeb		,
	sizeb			,
	usedb			,
	freeb			,
	path			,
	linkinode		,
	filetype		,
	configuration		,
	diskname		,
	backup			,
	freetype		
)
SELECT	rownum,											-- rownum
	v_targetid,										-- target_id
	v_targetname,										-- targetname
	NVL(g.string_value,'NO_DG')||'-'||NVL(a.string_value,'NO_TYPE')||'-'||b.string_value,	-- keyvalue =  diskgroup-name 
	a.collection_timestamp,									-- collection_timestamp
	a.string_value,										-- type
	b.string_value,										-- name
	g.string_value,										-- diskgroup
	0,											-- rawsizeb
	c.value,										-- sizeb
	0,											-- usedb
	0,											-- freeb
	i.string_value,										-- path
	d.string_value,										-- inode			
	e.string_value,										-- filetype
	h.string_value,										-- configuration
	f.string_value,										-- diskname
	'N',											-- backup
	NULL											-- freetype				
FROM	mgmt_current_metrics a,
	mgmt_current_metrics b,
	mgmt_current_metrics c,
	mgmt_current_metrics d,
	mgmt_current_metrics e,
	mgmt_current_metrics f,
	mgmt_current_metrics g,
	mgmt_current_metrics h,
	mgmt_current_metrics i
WHERE	a.target_guid = v_targetid
AND	b.target_guid = a.target_guid
AND	c.target_guid = a.target_guid
AND	d.target_guid = a.target_guid
AND	e.target_guid = a.target_guid
AND	f.target_guid = a.target_guid
AND	g.target_guid = a.target_guid
AND	h.target_guid = a.target_guid
AND	i.target_guid = a.target_guid
AND	b.key_value   = a.key_value
AND	c.key_value   = a.key_value
AND	d.key_value   = a.key_value
AND	e.key_value   = a.key_value
AND	f.key_value   = a.key_value
AND	g.key_value   = a.key_value
AND	h.key_value   = a.key_value
AND	i.key_value   = a.key_value
AND	a.metric_guid = l_voltypeguid
AND	b.metric_guid = l_volnameguid
AND	c.metric_guid = l_volsizeguid
AND	d.metric_guid = l_volinodeguid
AND	e.metric_guid = l_volfiletypeguid
AND	f.metric_guid = l_voldisknameguid
AND	g.metric_guid = l_volgroup
AND	h.metric_guid = l_configguid
AND	i.metric_guid = l_volpathguid
;

END getstoragevolumecollection;


-------------------------------------------------------------------------------
-- PROCEDURE NAME: getstoragefilesystemcollection
--
-- DESC 	: 
-- Get a snapshot of the  metric data for nfs
-- 
-- ARG
-- target_guid
-- target_name
------------------------------------------------------------------------------ 
PROCEDURE getstoragefilesystemcollection
			(
				v_targetid   mgmt_targets_view.target_id%TYPE,
				v_targetname mgmt_targets_view.target_name%TYPE		
			 ) IS

l_filesystemguid	mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_filesystems','storage_filesystems_filesystem');
l_sizeguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_filesystems','storage_filesystems_size');
l_usedguid 		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_filesystems','storage_filesystems_used');
l_freeguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_filesystems','storage_filesystems_free');
l_fstypeguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_filesystems','storage_filesystems_fstype');
l_inodeguid 		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_filesystems','storage_filesystems_inode');
l_serverguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_filesystems','storage_filesystems_nfs_server');
l_mountcountguid	mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_filesystems','storage_filesystems_nfs_exclusive');
l_vendorguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_filesystems','storage_filesystems_nfs_vendor');
--l_productguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_filesystems','storage_filesystems_nfs_product');
l_mountpointguid	mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_filesystems','storage_filesystems_mountpoint');
l_mounttypeguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_filesystems','storage_filesystems_mounttype');
l_mountinodeguid	mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_filesystems','storage_filesystems_mountpointinode');
l_privilegeguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_filesystems','storage_filesystems_nfs_privilege');

BEGIN

DELETE FROM stormon_temp_filesystem;

INSERT INTO stormon_temp_filesystem(
	rowcount		,
  	target_id		,        /* is RAW(16) in git3       */
	targetname		,	-- Target name
  	keyvalue		, /* is varchar2 in git3 */
	collection_timestamp	,
	type			,
	filesystem		,
	linkinode		,
	rawsizeb		,
	sizeb			,
	usedb			,
	freeb			,
	mountpoint		,
	mountpointid		,
	mounttype		,
	privilege		,
	server			,
	vendor			,
	nfscount		,
	backup			
)
SELECT	rownum,											-- rownum
	v_targetid,										-- target_id
	v_targetname,										-- targetname
	DECODE(LOWER(e.string_value),'nfs',a.string_value,NVL(j.string_value,a.string_value)),	-- keyvalue , linkinode for localfs and filesystem for nfs filesystems
	a.collection_timestamp,									-- collection_timestamp
	e.string_value,										-- type
	a.string_value,										-- filesystem
	j.string_value,										-- linkinode
	0,											-- rawsizeb
	b.value,										-- sizeb
	c.value,										-- usedb
	d.value,										-- freeb
	h.string_value,										-- mountpoint
	-- The metrics loads the filesystemid-fileinode for mountpoint, we are interested only in the filesystem ID
	-- The metrics need to be altered for this after taking into account the effects of NFS
	SUBSTR(k.string_value,1,INSTR(k.string_value,'-')-1),					-- mountpoint filesystem id
	m.string_value,										-- mounttype , EXCLSUIVE OR SHARED for nfs, this is computed
	l.string_value,										-- privilege
	f.string_value,										-- server
	g.string_value,										-- vendor
	i.value,										-- nfscount
	'N'											-- backup	 
FROM	mgmt_current_metrics a,
	mgmt_current_metrics b,
	mgmt_current_metrics c,
	mgmt_current_metrics d,
	mgmt_current_metrics e,
	mgmt_current_metrics f,
	mgmt_current_metrics g,
	mgmt_current_metrics h,
	mgmt_current_metrics i,
	mgmt_current_metrics j,
	mgmt_current_metrics k,
	mgmt_current_metrics l,
	mgmt_current_metrics m
WHERE  	a.target_guid = v_targetid
AND 	b.target_guid = a.target_guid
AND 	c.target_guid = a.target_guid
AND 	d.target_guid = a.target_guid
AND 	e.target_guid = a.target_guid
AND 	f.target_guid = a.target_guid
AND 	g.target_guid = a.target_guid
AND 	h.target_guid = a.target_guid
AND	i.target_guid = a.target_guid
AND	j.target_guid = a.target_guid
AND	k.target_guid = a.target_guid
AND	l.target_guid = a.target_guid
AND	m.target_guid(+) = a.target_guid
AND 	b.key_value   = a.key_value
AND 	c.key_value   = a.key_value
AND 	d.key_value   = a.key_value
AND 	e.key_value   = a.key_value
AND 	f.key_value   = a.key_value
AND 	g.key_value   = a.key_value
AND 	h.key_value   = a.key_value
AND	i.key_value   = a.key_value
AND	j.key_value   = a.key_value
AND	k.key_value   = a.key_value
AND	l.key_value   = a.key_value
AND	m.key_value(+)   = a.key_value
AND 	a.metric_guid = l_filesystemguid
AND 	b.metric_guid = l_sizeguid
AND 	c.metric_guid = l_usedguid
AND 	d.metric_guid = l_freeguid
AND 	e.metric_guid = l_fstypeguid
AND 	f.metric_guid = l_serverguid
AND 	g.metric_guid = l_vendorguid
AND 	h.metric_guid = l_mountpointguid
AND 	i.metric_guid = l_mountcountguid
AND	j.metric_guid = l_inodeguid
AND	k.metric_guid = l_mountinodeguid
AND	l.metric_guid = l_privilegeguid
AND	m.metric_guid(+) = l_mounttypeguid
;

END getstoragefilesystemcollection;


-------------------------------------------------------------------------------
-- PROCEDURE NAME: getstorageappcollection
--
-- DESC 	: 
-- Get a snapshot of the  metric data for applications
-- TODO handle diff target_types for different apps
--
-- ARG
-- target_guid
-- target_name
------------------------------------------------------------------------------ 
PROCEDURE getstorageappcollection(
				v_targetid   mgmt_targets_view.target_id%TYPE,
				v_targetname mgmt_targets_view.target_name%TYPE ) IS

l_typeguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_applications','storage_applications_type');
l_nameguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_applications','storage_applications_name');
l_idguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_applications','storage_applications_id');
l_fileguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_applications','storage_applications_file');
l_inodeguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_applications','storage_applications_inode');
l_sizeguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_applications','storage_applications_size');
l_usedguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_applications','storage_applications_used');
l_freeguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_applications','storage_applications_free');
l_tblspaceguid 		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_applications','storage_applications_oracle_database_tablespace');
l_filetypeguid		mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_applications','storage_applications_filetype');
l_oemtargetnameguid	mgmt_metrics.metric_guid%TYPE := getmetricguid(p_target_type_host,'storage_applications','storage_applications_oem_target_name');

BEGIN

DELETE FROM stormon_temp_app;

INSERT INTO stormon_temp_app(
	rowcount		,
  	target_id		, /* is RAW(16) in git3       */  	
	targetname		,	-- Target name
	oem_target_name		,
	parentkey       	,
  	keyvalue		, /* is varchar2 in git3 */
	collection_timestamp	,
	type			,
	appname			,
	appid			,
	filename		,
	filetype		,
	linkinode		,
	rawsizeb		,
	sizeb			,
	usedb			,
	freeb			,
	tablespace		,	
	backup			
)
SELECT	rownum,							-- rownum
	v_targetid,						-- target_id
	v_targetname,						-- targetname for the node target
	k.string_value,						-- target_name for the database target
	SUBSTR(
		NVL(e.string_value,d.string_value),1,
		DECODE
			(
				INSTR(NVL(e.string_value,d.string_value),'-'),
				0,
				LENGTH(NVL(e.string_value,d.string_value)),
				INSTR(NVL(e.string_value,d.string_value),'-')-1
			)
	),							-- parentkey ( Filesystem of the file if based on a fs )
	NVL(e.string_value,d.string_value),			-- keyvalue = linkinode
	a.collection_timestamp, 				-- collection_timestamp
	a.string_value,						-- type
	b.string_value,						-- appname
	c.string_value,						-- appid
	d.string_value,						-- filename
	j.string_value,						-- filetype
	e.string_value,						-- linkinode				
	0,							-- rawsizeb
	f.value,						-- sizeb
	g.value,						-- usedb
	h.value,						-- freeb
	i.string_value,						-- tablespace
	'N'							-- backup			 
FROM   	mgmt_current_metrics a,
	mgmt_current_metrics b,
	mgmt_current_metrics c,
	mgmt_current_metrics d,
	mgmt_current_metrics e,
	mgmt_current_metrics f,
	mgmt_current_metrics g,
	mgmt_current_metrics h,
	mgmt_current_metrics i,
	mgmt_current_metrics j,
	mgmt_current_metrics k
WHERE  	a.target_guid = v_targetid
AND 	b.target_guid = a.target_guid
AND 	c.target_guid = a.target_guid
AND 	d.target_guid = a.target_guid
AND 	e.target_guid = a.target_guid
AND 	f.target_guid = a.target_guid
AND 	g.target_guid = a.target_guid
AND 	h.target_guid = a.target_guid
AND 	i.target_guid = a.target_guid
AND 	j.target_guid(+) = a.target_guid
AND 	k.target_guid = a.target_guid
AND 	b.key_value   = a.key_value
AND 	c.key_value   = a.key_value
AND 	d.key_value   = a.key_value
AND 	e.key_value   = a.key_value
AND 	f.key_value   = a.key_value
AND 	g.key_value   = a.key_value
AND 	h.key_value   = a.key_value
AND 	i.key_value   = a.key_value
AND 	j.key_value(+)   = a.key_value
AND 	k.key_value   = a.key_value
AND 	a.metric_guid = l_typeguid
AND 	b.metric_guid = l_nameguid
AND 	c.metric_guid = l_idguid
AND 	d.metric_guid = l_fileguid
AND 	e.metric_guid = l_inodeguid
AND 	f.metric_guid = l_sizeguid
AND 	g.metric_guid = l_usedguid
AND 	h.metric_guid = l_freeguid
AND 	i.metric_guid = l_tblspaceguid
AND 	j.metric_guid(+) = l_filetypeguid
AND 	k.metric_guid = l_oemtargetnameguid
;

END getstorageappcollection;


-------------------------------------------------------------------------------
-- FUNCTION NAME: get_host_group_id
--
-- DESC 	: 
-- Return the group ID for a set of Hosts
--
-- Create a new group id if one doesnt exist
-- If multiple group ids exist, delete all but one of them
-- 
-- If group name is passed use it as an additional predicate in the search 
-- if no group name is passed search on group type and list of targets passed
--
-- ARG
-- HostList
-- group type
-- group name
------------------------------------------------------------------------------
FUNCTION get_host_group_id(v_hostList IN stringTable, v_group_type VARCHAR2) RETURN VARCHAR2 IS

BEGIN

	RETURN  get_host_group_id(v_hostList, v_group_type, NULL);

END get_host_group_id;


FUNCTION get_host_group_id(v_hostList IN stringTable, v_group_type VARCHAR2, v_group_name VARCHAR2) RETURN VARCHAR2 IS

l_group_id	stormon_group_table.id%TYPE;
l_host_count	stormon_group_table.host_count%TYPE;
l_group_id_list	stringTable;

-- Creating a new host group  is a autonomous transaction , independent of the main transaction, 
-- This is done right now to ensure that we are able to release the lock on storage_lock_table at the end of this procedure
--PRAGMA AUTONOMOUS_TRANSACTION;

BEGIN

	IF v_hostList IS NULL OR NOT v_hostList.EXISTS(1)
	THEN
		RAISE_APPLICATION_ERROR(-20103,'Host List is NULL in get_host_group_id',TRUE);
	END IF;
	
	-- Ensure single threaded execution here, to make sure we have only group dfor a combination of hosts
--	LOCK TABLE storage_group_lock IN EXCLUSIVE MODE;

	l_host_count := v_hostList.COUNT;

	-- Get the group id's which match the group name, type and host names passed
	IF v_group_name IS NOT NULL THEN
			
		SELECT	a.id
		BULK COLLECT INTO l_group_id_list
		FROM	TABLE( CAST(v_hostList AS stringTable) ) c,
			stormon_host_groups b,			
			stormon_group_table a
		WHERE	a.type	= v_group_type	
		AND	a.name = v_group_name
		AND	a.host_count = l_host_count
		AND	b.group_id = a.id
		AND	b.target_id = VALUE(c)
		GROUP BY a.id
		HAVING COUNT(*) = l_host_count;

	ELSE
		
		SELECT	a.id
		BULK COLLECT INTO l_group_id_list
		FROM	TABLE( CAST(v_hostList AS stringTable) ) c,
			stormon_host_groups b,			
			stormon_group_table a
		WHERE	a.type	= v_group_type
		AND	a.host_count = l_host_count
		AND	b.group_id = a.id
		AND	b.target_id = VALUE(c)
		GROUP BY a.id
		HAVING COUNT(*) = l_host_count;

	END IF;


	-- Create a new group id if no groups exists already for the group type, name and hosts passed
	IF l_group_id_list IS NOT NULL AND l_group_id_list.EXISTS(1) THEN
		
		-- If more than one group id that matches the same set of hosts and type exists then delete all but one
		IF l_group_id_list.EXISTS(2) THEN
		
			-- The trigger on stormon_group_table will archive the summaries with deleted group ids
			FORALL i IN 2..l_group_id_list.LAST 	
			DELETE FROM stormon_group_table WHERE id = l_group_id_list(i);
				
		END IF;

		l_group_id := l_group_id_list(1);
		
	ELSE
		
		-- If a group name is passed then delete all groups with this group name and type
		IF v_group_name IS NOT NULL THEN
	
			-- The trigger on stormon_group_table will archive the summaries with deleted group ids
			DELETE 
			FROM	stormon_group_table
			WHERE	type = v_group_type
			AND	name = v_group_name;

		END IF;

		-- Get the ID for the new group to be inserted
		-- The appending is important to differentiate the group ids from target_id in mmgt_targets
		SELECT	'g_'||stormonGroupId.NEXTVAL
		INTO	l_group_id
		FROM	DUAL;	

		-- Insert the group
		INSERT INTO stormon_group_table VALUES( l_group_id,v_group_type, NVL( v_group_name,l_group_id), l_host_count );

		-- Insert the hosts for this group
		FORALL i IN v_hostList.FIRST..v_hostList.LAST 	
			INSERT INTO stormon_host_groups VALUES(l_group_id,v_hostList(i));

	END IF;

	-- TBD Remove this commit , TBD why do we need it here, make tis txn as part of the main txn
	-- This is done right now to ensure that we are able to release the lock on storage_lock_table at the end of this procedure
	--COMMIT;	
	
	RETURN l_group_id;

EXCEPTION

	WHEN OTHERS THEN
	-- TBD Remove this commit , TBD why do we need it here, make tis txn as part of the main txn
	-- This is done right now to ensure that we are able to release the lock on storage_lock_table at the end of this procedure
		--ROLLBACK;		

		RAISE_APPLICATION_ERROR(-20103,'DEBUG : Failed to fetch the group id of type '||v_group_type||' ,for name '||v_group_name,TRUE);
		

END get_host_group_id;


-------------------------------------------------------------------------------
-- FUNCTION NAME: insertSummary
--
-- DESC 	: 
-- insert the summary object into the reporting table 
-- 
-- ARG
-- storagesummary object
------------------------------------------------------------------------------
PROCEDURE insertSummary(v_summary IN summaryObject ) IS

BEGIN		

	IF v_summary IS NULL 	
	THEN
		RAISE_APPLICATION_ERROR(-20103,'DEBUG : Summary Object is NULL in insertSummary '||NVL(v_summary.id,v_summary.name),TRUE);
	END IF;

	IF v_summary.id IS NULL THEN
		RAISE_APPLICATION_ERROR(-20103,'DEBUG : Summary Object Id is NULL in insertGroupSummary for '||NVL(v_summary.id,v_summary.name),TRUE);
	END IF;
	
	DELETE FROM storage_summaryobject a WHERE a.id = v_summary.id;
	INSERT INTO storage_summaryobject VALUES(v_summary);
	
EXCEPTION 

	WHEN OTHERS THEN
		RAISE_APPLICATION_ERROR(-20103,'DEBUG : Failed to insert summary object into reporting table for '||NVL(v_summary.id,v_summary.name),TRUE);
END insertSummary;



-------------------------------------------------------------------------------
-- FUNCTION NAME: insertSummaryHistory
--
-- DESC 	: 
-- insert the summary object into the history table
-- 
-- ARG
-- storagesummary object
------------------------------------------------------------------------------
PROCEDURE insertSummaryHistory(v_summary IN summaryObject ) IS

BEGIN		

	IF v_summary IS NULL 	
	THEN
		RAISE_APPLICATION_ERROR(-20103,'DEBUG : Summary Object is NULL in insertSummary '||NVL(v_summary.id,v_summary.name),TRUE);		
	END IF;

	IF v_summary.id IS NULL THEN
		RAISE_APPLICATION_ERROR(-20103,'DEBUG : Summary Object Id is NULL in insertGroupSummary for '||NVL(v_summary.id,v_summary.name),TRUE);
	END IF;
	
	INSERT INTO storage_summaryobject_history VALUES(v_summary);
	
EXCEPTION 

	WHEN OTHERS THEN
		RAISE_APPLICATION_ERROR(-20103,'DEBUG : Failed to insert summary object into history table for '||NVL(v_summary.id,v_summary.name),TRUE);
END insertSummaryHistory;


--------------------------------------------------------
-- FUNCTION NAME : concatList
--
-- DESC:
-- Concat the output from the cursor into a varchar2 variable
--
-- ARGS : CURSOR RETURNING VARCHAR2
--
-- RETURN VALUE : CONCATENATED RESULTS
--
--------------------------------------------------------
FUNCTION concatlist(v_cursor IN sys_refcursor) 	RETURN VARCHAR2 IS

l_string	VARCHAR2(2000);
l_stringTable	stringTable;

BEGIN	
	
	FETCH v_cursor BULK COLLECT INTO l_stringTable;
	CLOSE v_cursor;

	IF l_stringTable IS NOT NULL AND l_stringTable.EXISTS(1) THEN

		FOR i IN l_stringTable.FIRST..l_stringTable.LAST LOOP
			
			IF  ( LENGTH(l_string) + LENGTH(l_stringTable(i)) ) > 2000 THEN
				EXIT;
			END IF;
						
			IF i = 1 THEN
				l_string := l_stringTable(i);
			ELSE	
				l_string := l_string||' !'||CHR(10)||l_stringTable(i);
			END IF;

		END LOOP;

	END IF;

	RETURN l_string;

EXCEPTION
	WHEN OTHERS THEN 
		RETURN NULL;
END concatList;

--------------------------------------------------------------------------------------------
-- PROCEDURE NAME	: refresh_dc_lob_groups
--
-- DESC			: 
-- create host group ids for the group queries in p_group_query
-- 
-- ARG
--
---------------------------------------------------------------------------------------------
PROCEDURE refresh_dc_lob_groups IS

l_cursor		sys_refcursor;
l_group_name		stormon_group_table.name%TYPE;
l_group_type		stormon_group_table.type%TYPE;
l_host_count		stormon_group_table.host_count%TYPE;
l_target_cursor		sys_refcursor;

l_target_list		stringTable;
l_group_id		stormon_group_table.id%TYPE;

l_time			INTEGER := 0;

BEGIN

	l_time := STORAGE_SUMMARY_DB.GETTIME(l_time);

	-- Delete the log for this procedure
	STORAGE_SUMMARY_DB.DELETELOG('refresh_dc_lob_groups');

	STORAGE_SUMMARY_DB.LOG('refresh_dc_lob_groups','In STORAGE_SUMMAY_DB.refresh_dc_lob_groups');

	-----------------------------------------------------------------------------------------------------------
	-- Delete the groups which have targets that are not in the target master
	-- Deleting a group will delete the group to host mapping from stormon_host_groups with the trigger
	-----------------------------------------------------------------------------------------------------------
	BEGIN
	
		STORAGE_SUMMARY_DB.LOG('refresh_dc_lob_groups','Deleting groups with deleted target_ids');
	
		DELETE FROM stormon_group_table o
		WHERE   NOT EXISTS  
	        (
		        SELECT  a.group_id
		        FROM    stormon_host_groups a,
		                mgmt_targets_view B
		        WHERE   a.target_id = b.target_id
			AND	a.group_id = o.id
	        );

		STORAGE_SUMMARY_DB.PRINTSTMT(' groups deleted from stormon_group_table is '||SQL%ROWCOUNT);

	EXCEPTION
		WHEN OTHERS THEN		    
			RAISE;
	END;

	STORAGE_SUMMARY_DB.LOG_TIME(
			'refresh_dc_lob_groups',
			'refresh_dc_lob_groups',
			'refresh_dc_lob_groups','Time taken to delete groups for invalid hosts from stormon_group_table is ',STORAGE_SUMMARY_DB.GETTIME(l_time));

	-------------------------------------------------------------------------------------------------------------------------------
	-- If a query is defined to clean up the groups of this type then execute this query to clean stale groups
	-- The trigger on stormon_group_table ensures deletion of rows in stormon_-host_groups and stormon_group_of_groups_table
	-------------------------------------------------------------------------------------------------------------------------------
	BEGIN

		STORAGE_SUMMARY_DB.LOG('refresh_dc_lob_groups','Deleting groups with no names for REPORTING_DATACENTER ');

		DELETE	FROM stormon_group_table
		WHERE	type = 'REPORTING_DATACENTER'
		AND	name NOT IN 
			(
				SELECT DISTINCT datacenter
				FROM	mgmt_targets_view a
				WHERE	datacenter IS NOT NULL
			);

		STORAGE_SUMMARY_DB.PRINTSTMT(' Deleted groups for REPORTING_DATACENTER '||SQL%ROWCOUNT);

	EXCEPTION
		WHEN OTHERS THEN
			STORAGE_SUMMARY_DB.PRINTSTMT('Failed to delete groups for  REPORTING_DATACENTER');
			RAISE;
	END;

	BEGIN

		STORAGE_SUMMARY_DB.LOG('refresh_dc_lob_groups','Deleting groups with no names for REPORTING_LOB ');

		DELETE	FROM stormon_group_table
		WHERE	type = 'REPORTING_LOB'
		AND	name NOT IN 
			(
				SELECT DISTINCT escalation_group
				FROM	mgmt_targets_view a
				WHERE	escalation_group IS NOT NULL
			);

		STORAGE_SUMMARY_DB.PRINTSTMT(' Deleted groups for REPORTING_LOB '||SQL%ROWCOUNT);

	EXCEPTION
		WHEN OTHERS THEN
			STORAGE_SUMMARY_DB.PRINTSTMT('Failed to delete groups for REPORTING_LOB');
			RAISE;
	END;

	BEGIN

		STORAGE_SUMMARY_DB.LOG('refresh_dc_lob_groups','Deleting groups with no names for REPORTING_DATACENTER_LOB ');

		DELETE	FROM stormon_group_table
		WHERE	type = 'REPORTING_DATACENTER_LOB'
		AND	name NOT IN 
			(
				SELECT DISTINCT 	datacenter||'-'||escalation_group
				FROM	mgmt_targets_view a
				WHERE	escalation_group IS NOT NULL 
				OR	datacenter IS NOT NULL
			);	
	
		STORAGE_SUMMARY_DB.PRINTSTMT(' Deleted groups for REPORTING_DATACENTER_LOB '||SQL%ROWCOUNT);

	EXCEPTION
		WHEN OTHERS THEN
			STORAGE_SUMMARY_DB.PRINTSTMT('Failed to delete groups for REPORTING_DATACENTER_LOB');
			RAISE;
	END;

	STORAGE_SUMMARY_DB.LOG_TIME(
			'refresh_dc_lob_groups',
			'refresh_dc_lob_groups',
			'refresh_dc_lob_groups','Time taken to delete invalid groups from stormon_group_table is ',STORAGE_SUMMARY_DB.GETTIME(l_time));

	----------------------------------------------------------------------------------
	-- Build the datacenter, LOB groups based on the query passed in
	----------------------------------------------------------------------------------
	FOR i IN p_group_query_list.FIRST..p_group_query_list.LAST 
	LOOP
		----------------------------------------------------------------------------------------
		-- Now insert the new groups of this type if they do not already exist
		----------------------------------------------------------------------------------------
		OPEN l_cursor FOR p_group_query_list(i);

		LOOP
			FETCH l_cursor INTO l_group_type, l_group_name, l_host_count, l_target_cursor;

			EXIT WHEN l_cursor%NOTFOUND;

			FETCH l_target_cursor BULK COLLECT INTO l_target_list;

			IF l_target_list IS NOT NULL AND l_target_list.EXISTS(1) THEN

				l_group_id := STORAGE_SUMMARY_DB.GET_HOST_GROUP_ID(l_target_list,l_group_type,l_group_name);
				
				-- Let the hostrollup job compute the group summary when it needs to, there is no need to do it here
				-- in view of package dependency and transaction integrity
				--STORAGE_SUMMARY.COMPUTE_GROUP_SUMMARY(l_group_id,l_group_name);

			END IF;
		
		END LOOP;

		CLOSE l_cursor;

	END LOOP;

	STORAGE_SUMMARY_DB.LOG_TIME('refresh_dc_lob_groups','refresh_dc_lob_groups','refresh_dc_lob_groups',' Inserted the new groups in ',STORAGE_SUMMARY_DB.GETTIME(l_time));

	---------------------------------------------------------------------------------
	-- Configuration for maintaining the parent , child relationship between groups 
	-- in the stormon_group_of_groups_table
	---------------------------------------------------------------------------------
	----------------------------------------------------------------------------------
	-- Populate the relationship table for the datacenter , Lob relationship
	----------------------------------------------------------------------------------

	-- Delete the previous parent child relationship for the parent and child group types passed in
	BEGIN

		STORAGE_SUMMARY_DB.LOG('refresh_dc_lob_groups','Refreshing groups with for relationship between REPORTING_ALL and  REPORTING_DATACENTER ');
		
		-- deleting the existing groups
		DELETE		FROM	stormon_group_of_groups_table
				WHERE	parent_id IN ( 
							SELECT	id
							FROM	stormon_group_table
							WHERE	type = 'REPORTING_ALL'
				)
				AND	child_id IN (
							SELECT	id
							FROM	stormon_group_table
							WHERE	type = 'REPORTING_DATACENTER'
				);
	
		STORAGE_SUMMARY_DB.PRINTSTMT(' Deleted groups for relationship between REPORTING_ALL and REPORTING_DATACENTER '||SQL%ROWCOUNT);

		-- inserting new groups
		INSERT INTO stormon_group_of_groups_table 			
			SELECT  DISTINCT parent.id,			        
			        child.id			        
			FROM    stormon_group_table child,
		        	stormon_group_table parent
			WHERE   child.type = 'REPORTING_DATACENTER'	
			AND     parent.type = 'REPORTING_ALL'
			AND     parent.name = 'ALL';	

		STORAGE_SUMMARY_DB.PRINTSTMT(' Inserted groups for relationship between REPORTING_ALL and REPORTING_DATACENTER '||SQL%ROWCOUNT);

	EXCEPTION
		WHEN OTHERS THEN
			STORAGE_SUMMARY_DB.PRINTSTMT('Failed to refresh groups for relationship between REPORTING_ALL and REPORTING_DATACENTER ');
			RAISE;
	END;


	-- Delete the previous parent child relationship for the parent and child group types passed in
	BEGIN

		STORAGE_SUMMARY_DB.LOG('refresh_dc_lob_groups','Refreshing groups with for relationship between REPORTING_ALL and  REPORTING_LOB ');

		DELETE		FROM	stormon_group_of_groups_table
				WHERE	parent_id IN ( 
							SELECT	id
							FROM	stormon_group_table
							WHERE	type = 'REPORTING_ALL'
				)
				AND	child_id IN (
							SELECT	id
							FROM	stormon_group_table
							WHERE	type = 'REPORTING_LOB'
				);
	
		STORAGE_SUMMARY_DB.PRINTSTMT(' Deleted groups for relationship between REPORTING_ALL and  REPORTING_LOB '||SQL%ROWCOUNT);

		-- inserting new groups
		INSERT INTO stormon_group_of_groups_table 			
			SELECT  DISTINCT parent.id,			        
			        child.id			        
			FROM    stormon_group_table child,
		        	stormon_group_table parent
			WHERE   child.type = 'REPORTING_LOB'	
			AND     parent.type = 'REPORTING_ALL'
			AND     parent.name = 'ALL';	

		STORAGE_SUMMARY_DB.PRINTSTMT(' Inserted groups for relationship between REPORTING_ALL and REPORTING_LOB '||SQL%ROWCOUNT);

	EXCEPTION
		WHEN OTHERS THEN
			STORAGE_SUMMARY_DB.PRINTSTMT('Failed to refresh groups for relationship between REPORTING_ALL and  REPORTING_LOB ');
			RAISE;
	END;


	-- Delete the previous parent child relationship for the parent and child group types passed in
	BEGIN

		STORAGE_SUMMARY_DB.LOG('refresh_dc_lob_groups','Refreshing groups with for relationship between REPORTING_DATACENTER and  REPORTING_DATACENTER_LOB ');

		DELETE		FROM	stormon_group_of_groups_table
				WHERE	parent_id IN ( 
							SELECT	id
							FROM	stormon_group_table
							WHERE	type = 'REPORTING_DATACENTER'
				)
				AND	child_id IN (
							SELECT	id
							FROM	stormon_group_table
							WHERE	type = 'REPORTING_DATACENTER_LOB'
				);
	
		STORAGE_SUMMARY_DB.PRINTSTMT(' Deleted groups for relationship between REPORTING_DATACENTER and  REPORTING_DATACENTER_LOB '||SQL%ROWCOUNT);

		-- inserting new groups
		INSERT INTO stormon_group_of_groups_table 			
			SELECT  DISTINCT parent.id,			        
			        child.id			        
			FROM    stormon_group_table child,
				(
			                SELECT	DISTINCT datacenter datacenter,
						escalation_group lob,
						datacenter||'-'||escalation_group datacenter_lob
			                FROM    mgmt_targets_view	
		        	) b,	
		        	stormon_group_table parent
			WHERE   child.type = 'REPORTING_DATACENTER_LOB'	
			AND     parent.type = 'REPORTING_DATACENTER'
			AND     parent.name = b.datacenter
			AND	child.name = b.datacenter_lob;	

		STORAGE_SUMMARY_DB.PRINTSTMT(' Inserted groups for relationship between REPORTING_DATACENTER and REPORTING_DATACENTER_LOB '||SQL%ROWCOUNT);

	EXCEPTION
		WHEN OTHERS THEN
			STORAGE_SUMMARY_DB.PRINTSTMT('Failed to refresh groups for relationship between REPORTING_DATACENTER and  REPORTING_DATACENTER_LOB ');
			RAISE;
	END;


	-- Delete the previous parent child relationship for the parent and child group types passed in
	BEGIN

		STORAGE_SUMMARY_DB.LOG('refresh_dc_lob_groups','Refreshing groups with for relationship between REPORTING_LOB and  REPORTING_DATACENTER_LOB ');

		DELETE		FROM	stormon_group_of_groups_table
				WHERE	parent_id IN ( 
							SELECT	id
							FROM	stormon_group_table
							WHERE	type = 'REPORTING_LOB'
				)
				AND	child_id IN (
							SELECT	id
							FROM	stormon_group_table
							WHERE	type = 'REPORTING_DATACENTER_LOB'
				);
	
		STORAGE_SUMMARY_DB.PRINTSTMT(' Deleted groups for relationship between REPORTING_LOB and  REPORTING_DATACENTER_LOB '||SQL%ROWCOUNT);

		-- inserting new groups
		INSERT INTO stormon_group_of_groups_table 			
			SELECT  DISTINCT parent.id,			        
			        child.id			        
			FROM    stormon_group_table child,
				(
			                SELECT	DISTINCT datacenter datacenter,
						escalation_group lob,
						datacenter||'-'||escalation_group datacenter_lob
			                FROM    mgmt_targets_view	
		        	) b,	
		        	stormon_group_table parent
			WHERE   child.type = 'REPORTING_DATACENTER_LOB'	
			AND     parent.type = 'REPORTING_LOB'
			AND     parent.name = b.lob
			AND	child.name = b.datacenter_lob;	

		STORAGE_SUMMARY_DB.PRINTSTMT(' Inserted groups for relationship between REPORTING_LOB and  REPORTING_DATACENTER_LOB '||SQL%ROWCOUNT);

	EXCEPTION
		WHEN OTHERS THEN
			STORAGE_SUMMARY_DB.PRINTSTMT('Failed to Refresh groups for relationship between REPORTING_LOB and  REPORTING_DATACENTER_LOB ');
			RAISE;
	END;


	STORAGE_SUMMARY_DB.LOG_TIME(
			'refresh_dc_lob_groups',
			'refresh_dc_lob_groups',
			'refresh_dc_lob_groups','Time taken to Refresh invalid group relationships from stormon_group_of_groups_table is ',STORAGE_SUMMARY_DB.GETTIME(l_time));


EXCEPTION

	WHEN OTHERS THEN

		RAISE_APPLICATION_ERROR(-20103,'DEBUG : Failed to refresh the dc lob groups ',TRUE);
		
END refresh_dc_lob_groups;


--------------------------------------------------------------------------------------------
-- PROCEDURE NAME	: gather_schema_statistics
--
-- DESC			: 
-- Gather statistcs for the modified tables and their corresponding indexes in the 
-- storage_rep schema
-- 
-- ARG
--
---------------------------------------------------------------------------------------------
PROCEDURE gather_schema_statistics( v_schema_name  IN VARCHAR2 DEFAULT 'storage_rep') IS

	l_object_list		DBMS_STATS.ObjectTab;
	l_list_of_tables	stringTable;
	l_timestamp		DATE := SYSDATE;

	l_elapsedtime		INTEGER := 0;
	l_time			INTEGER := 0;

	l_errmsg 		storage_log.message%TYPE;

BEGIN

	--------------------------------------
	-- CHECK FOR THE LOCK
	--------------------------------------
	DECLARE
		l_dummy		INTEGER;
	BEGIN
		SELECT	1
		INTO	l_dummy
		FROM	storage_lock_table
		WHERE	ROWNUM = 1;
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			RETURN;		
	END;

	l_elapsedtime := STORAGE_SUMMARY_DB.GETTIME(l_time);

	-- Delete the previous log for gather_schema_statistics
	STORAGE_SUMMARY_DB.DELETELOG('gather_schema_statistics');
	STORAGE_SUMMARY_DB.LOG('gather_schema_statistics','Gathering statistics for schema '||v_schema_name||' in procedure storage_summary_db.gather_schema_statistics');

	----------------------------------------------------------------------------------
	-- 	Need privilege to do this
	--	DBMS_STATS.FLUSH_DATABASE_MONITORING_INFO;
	--
	--	DBMS_STATS PROCEDURES DO A COMMIT ON THEIR OWN
	--
	----------------------------------------------------------------------------------

	----------------------------------------------------------------------------------------------------------------------
	-- Gather the statistics for all tables and their indexes , Oracle will look up the 
	-- USER_TAB_MODIFICATIONS table to ppick the tables to 
	-- gather statistics for
	----------------------------------------------------------------------------------------------------------------------
	 DBMS_STATS.GATHER_SCHEMA_STATS(
			v_schema_name,			-- Schema to analyze (NULL means current schema). 
			DBMS_STATS.AUTO_SAMPLE_SIZE,	-- Percentage of rows to estimate
			FALSE,				-- Whether or not to use random block sampling instead of random row sampling
			'FOR ALL COLUMNS SIZE AUTO',	-- method_opt
			DBMS_STATS.DEFAULT_DEGREE,	-- Degree of parallelism. NULL means use the table default value specified by the DEGREE clause in the CREATE TABLE or ALTER TABLE statemen
			'DEFAULT',			-- Granularity of statistics to collect (only pertinent if the table is partitioned).
			TRUE,				-- Gather statistics on the indexes as well.
			NULL,				-- User stat table identifier describing where to save the current statistics. 
			NULL,				-- Identifier (optional) to associate with these statistics within stattab.
			'GATHER AUTO',			-- Further specification of which objects to gather statistics for
			l_object_list, 			-- List of objects found to be stale or empty.
			NULL				-- Schema containing stattab (if different than ownname). 
			);

	IF l_object_list IS NOT NULL AND l_object_list.EXISTS(1) THEN
	
		FOR i IN l_object_list.FIRST..l_object_list.LAST LOOP

			STORAGE_SUMMARY_DB.LOG(	'gather_schema_statistics','Gathered statistics with GATHER AUTO for table '||l_object_list(i).objname);

		END LOOP;	

	END IF;

	----------------------------------------------------------------------------------------------------------------------
	-- Get the tables from the USER_TAB_MODIFICATIONS that are left out by the previous procedure
	-- Check on timestamp ensures that we dont pick any of the tables which might have been analyzed by th previous command 
	-- and have had a subsequent dml 
	-- Cannot make the two procedures atomic so the timestamp check
	----------------------------------------------------------------------------------------------------------------------
	
/*	FOR NOW WE WILL RELY ON GATHER AUTO TO PICK ALL TABLES

	SELECT	TABLE_NAME BULK COLLECT INTO l_list_of_tables FROM USER_TAB_MODIFICATIONS AND timestamp < l_timestamp;

	IF l_list_of_tables IS NOT NULL AND l_list_of_tables.EXISTS(1) THEN

		FOR i IN l_list_of_tables.FIRST..l_list_of_tables.LAST LOOP

			DBMS_STATS.GATHER_TABLE_STATS(
					v_schema_name,			-- Schema of table to analyze
					UPPER(l_list_of_tables(i)),	-- Name of table.
					NULL,				-- Name of partition
					DBMS_STATS.AUTO_SAMPLE_SIZE,	-- Percentage of rows to estimate (NULL means compute)
					FALSE,				-- Whether or not to use random block sampling instead of random row sampling
					'FOR ALL COLUMNS SIZE AUTO',	-- method_opt
					DBMS_STATS.DEFAULT_DEGREE,	-- Degree of parallelism. NULL means use the table default value specified by the DEGREE clause in table DDL
					'DEFAULT',			-- Granularity of statistics to collec
					TRUE);				-- Gather statistics on the indexes for this table.			

		END LOOP;

		FOR i IN l_list_of_tables.FIRST..l_list_of_tables.LAST LOOP

			STORAGE_SUMMARY_DB.LOG('gather_schema_statistics',' Table in USER_TAB_MODIFICATIONS , gathered statistics for '||l_list_of_tables(i));			

		END LOOP;

	END IF;
*/
	STORAGE_SUMMARY_DB.LOG_TIME(
				'gather_schema_statistics',
				'gather_schema_statistics',
				'gather_schema_statistics',
				'Time taken to gather statistics for for schema '||v_schema_name,
				STORAGE_SUMMARY_DB.GETTIME(l_elapsedtime));

	STORAGE_SUMMARY_DB.LOG('gather_schema_statistics','Completed Gathering statistics in storage_summary_db.gather_schema_statistics for schema '||v_schema_name);

EXCEPTION
	WHEN OTHERS THEN
		-- rollback whatever we can
		ROLLBACK;

		l_errmsg := 'Failed in procedure STORAGE_SUMMARY_DB.gather_schema_statistics , gathering statistics for schema '||v_schema_name||CHR(10)||SUBSTR(SQLERRM,1,2048);

		STORAGE_SUMMARY_DB.LOGERROR('gather_schema_statistics',l_errmsg);	

		RAISE;	

END gather_schema_statistics;	




------------------------------------------------
-- Package initialization
------------------------------------------------
BEGIN

	------------------------------------
	-- List of dc lob grouping queries
	------------------------------------	
	p_group_query_list.EXTEND(4);
	
	-- Datacenter grouping refresh and cleanup queries
	p_group_query_list(1) := '
		SELECT	''REPORTING_DATACENTER'',
			datacenter, 
			COUNT(*),
			CURSOR (
				SELECT	target_id
				FROM	mgmt_targets_view
				WHERE	datacenter = a.datacenter
			)
		FROM	mgmt_targets_view a
		GROUP BY
			datacenter
		';
	
	-- LOB grouping refresh and cleanup queries
	p_group_query_list(2) := '
		SELECT	''REPORTING_LOB'',
			escalation_group,
			COUNT(*),
			CURSOR (
				SELECT	target_id
				FROM	mgmt_targets_view
				WHERE	escalation_group = a.escalation_group
			)
		FROM	mgmt_targets_view a
		GROUP BY
			escalation_group
		';


	-- DC-LOB grouping refresh and cleanup queries
	p_group_query_list(3) := '
		SELECT	''REPORTING_DATACENTER_LOB'',
			datacenter||''-''||escalation_group,
			COUNT(*),
			CURSOR (
				SELECT	target_id
				FROM	mgmt_targets_view
				WHERE	escalation_group = a.escalation_group
				AND	datacenter = a.datacenter
			)
		FROM	mgmt_targets_view a
		GROUP BY
			escalation_group,
			datacenter
		';

	-- ALL group refresh query, no cleanup query is required for all, nothing can get stale here
	p_group_query_list(4) := '
		SELECT	''REPORTING_ALL'',
			''ALL'',
			COUNT(*),
			CURSOR (
				SELECT	target_id
				FROM	mgmt_targets_view				
			)
		FROM	mgmt_targets_view a					
		GROUP BY
			1		
		';			

END storage_summary_db;
/

SHOW ERROR;
