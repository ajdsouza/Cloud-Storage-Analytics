--
--
-- Copyright  (c) 2001,2002  Oracle Corporation All rights reserved 
--
--
--
-- $Id: storage_summary_analysis.sql,v 1.348 2004/01/29 01:32:03 ajdsouza Exp $ 
--
--
-- NAME  
--	 storage_summary_analysis.sql
--
-- DESC 
--  Creates the package storage_summary for analysis of storage metrics	
--
--
-- FUNCTIONS
--
--
-- NOTES
--
--
-- MODIFIED	(MM/DD/YY)
--
-- ajdsouza	10/01/01 	- Created
--
--
--

CREATE OR REPLACE PACKAGE storage_summary AS

PROCEDURE refresh_masters;

PROCEDURE hostRollupData;

PROCEDURE jobstatus;

PROCEDURE cleanjob;

PROCEDURE rollup; 

-- Clean up previous jobs and schedule
-- execution of the hostrollupdata once in frequency*hours
-- Default frequency is hourly
PROCEDURE submitjob(v_frequency NUMBER DEFAULT 1);

-- this function is exported so that it can be called in SQL
FUNCTION gettotalstorage 
			(
				v_vendor     VARCHAR2,
				v_product    VARCHAR2,
				v_diskconfig VARCHAR2,
				v_sizeb      NUMBER
			) RETURN NUMBER;

PROCEDURE compute_on_demand_summary ( v_target_name  IN mgmt_targets_view.target_name%TYPE );

END storage_summary;
/

SHOW ERROR;

CREATE OR REPLACE PACKAGE BODY storage_summary AS

-----------------------------------------------------
-- Private package types
-----------------------------------------------------
TYPE tableStringTable IS TABLE OF stringTable;

------------------------------------------------------
-- Private package variables
------------------------------------------------------

c_statistics_purge_window	CONSTANT INTEGER := 7;	  -- Purge week old statistics from storage_statistics
c_old_summary_days		CONSTANT NUMBER := 365;   -- A summary computed 365 days back is considered old

-- private package variable for target_type
p_target_type_host	CONSTANT VARCHAR2(25) := STORAGE_SUMMARY_DB.p_target_type_host;
p_target_type_database	CONSTANT VARCHAR2(25) := STORAGE_SUMMARY_DB.p_target_type_database;	

----------------------------------------------------------------------------
--  private package sub programs declared
----------------------------------------------------------------------------

PROCEDURE calcfreediskspace( v_usedkeys IN stringTable);

PROCEDURE calcswraiddiskfreespace(v_usedkeys IN stringTable);

PROCEDURE compute_group_summary(v_groupid stormon_group_table.id%TYPE, v_name VARCHAR2 DEFAULT 'GROUP TOTAL');

PROCEDURE calcstoragesummary( v_targetname mgmt_targets_view.target_name%TYPE ,v_targetid mgmt_targets_view.target_id%TYPE);

-------------------------------------------------------------------------------
-- FUNCTION NAME :	refresh_masters
--
-- DESC 	: 
-- Refresh the 9i tables
--	mgmt_targets
--	node_target_map
--	smp_vdj_job_per_target
--
-- Refresh the mozart tables
--	mgmt_targets
--	node_target_map
--	smp_vdj_job_per_target
--
-- Update the mgmt_targets_to_be_migrated table
--
-- Merge the two target tables into mgmt_targets_merged
--
-- Refresh the groups
--
--
-- ARGS	:
--	
------------------------------------------------------------------------------
PROCEDURE refresh_masters IS

l_errmsg		storage_log.message%TYPE;
l_time			INTEGER := 0;
l_elapsedtime		INTEGER := 0;
l_dummy			NUMBER;

BEGIN

	--------------------------------------
	-- CHECK FOR THE LOCK
	--------------------------------------
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

	-- Free any previous transactions
	COMMIT;

	-- Delete the previoud log for this procedure
	STORAGE_SUMMARY_DB.DELETELOG('refresh_masters');

	-------------------------------------------------------------------
	-- REFRESH mgmt_targets FROM 9I
	-- REFRESH mozzart_mgmt_targets FROM MOZART
	-- PERFORM MIGRATION OF 9I TO MOZART ( This will add entries to the mgmt_migrated_targets) table
	-- BUILD THE NEW mgmt_targets_merged
	-- DELETE THE GROUPS FROM stormon_group_table WITH TARGETS NOT IN mgmt_targets_merged
	-- TBD : DELETE THE SUMMARIES WITH ID NOT IN THE NEW TARGETS OR STORMON_HOST_GROUPS
	-- REBUILD THE DATACENTER AND LOB GROUPS
	-- TBD: DELETE THOSE GROUPS WHICH ARE NOT REQUIRED ANYMORE ???
	-------------------------------------------------------------------

	----------------------------------------------------------------------
	--	Refresh the local copy of the following tables
	--
	--	mgmt_targets
	--	node_target_map
	--	smp_vdj_job_per_target
	--
	----------------------------------------------------------------------
	BEGIN

		STORAGE_SUMMARY_DB.REFRESH_TARGETS;

		-- We commit here as this is a distributed txn
		COMMIT;

	EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			RAISE_APPLICATION_ERROR(-20101,'Failed to refresh 9i master data',TRUE);
	END;

	--STORAGE_SUMMARY_DB.DELETELOG('refresh_9i_targets');
	STORAGE_SUMMARY_DB.LOG_TIME('refresh_masters','refresh_9i_targets','refresh_9i_targets','Refreshed 9i Master data ,STORAGE_SUMMARY.REFRESH_TARGETS ',STORAGE_SUMMARY_DB.GETTIME(l_time));


	----------------------------------------------------------------------
	--	Refresh the local copy of the following mozart tables
	--
	--	mozart_mgmt_targets
	--	mozart_node_target_map
	--	mozart_smp_vdj_job_per_target
	--
	----------------------------------------------------------------------
	BEGIN

		STORAGE_SUMMARY_DB.REFRESH_MOZART_TARGETS;

		-- We commit here as this is a distributed txn
		COMMIT;

	EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			RAISE_APPLICATION_ERROR(-20101,'Failed to refresh mozart master data ',TRUE);
	END;
	
	--STORAGE_SUMMARY_DB.DELETELOG('refresh_mozart_targets');
	STORAGE_SUMMARY_DB.LOG_TIME('refresh_masters','refresh_mozart_targets','refresh_mozart_targets','Refreshed mozart master data STORAGE_SUMMARY.REFRESH_TARGETS ',STORAGE_SUMMARY_DB.GETTIME(l_time));


	-------------------------------------------------------------------------
	-- MERGE THE 9I DATA AND THE MOZRT TARGETS TARGETS, FOR PERFORMANCE REASONS 
	-- ITS BETTER TO HAVE A TABLE , THAN A VIEW
	-------------------------------------------------------------------------
	BEGIN

		STORAGE_SUMMARY_DB.MERGE_TARGETS;
	
		--COMMIT;

	EXCEPTION
		WHEN OTHERS THEN
			--ROLLBACK;
			RAISE_APPLICATION_ERROR(-20101,'Failed to merge the 9i targets and  mozart targets ',TRUE);
	END;

	--STORAGE_SUMMARY_DB.DELETELOG('merge_targets');
	STORAGE_SUMMARY_DB.LOG_TIME('refresh_masters','merge_targets','merge_targets','Merged the 9i targets and mozart targets in STORAGE_SUMMARY.MERGE_TARGETS ',STORAGE_SUMMARY_DB.GETTIME(l_time));


	-------------------------------------------------------------------------
	-- MAINTAIN THE GROUPING TABLE FOR DC AND LOB REPORTING GROUPS
	-------------------------------------------------------------------------
	BEGIN

		------------------------------------------------------------------------------------------------------------------------
		--
		--	This query delete groups which have invalid targets
		--	Deletes groups whose names ahave changed or are deleted
		--	Ads the new groups if they do not already exist
		--
		--
		-- Maintaining summaries for non deleted targets and groups
		-- in tables
		--	STORAGE_SUMMARYOBJECT,
		--	STORAGE_SUMMARYOBJECT_HISTORY,
		--	STORAGE_HISTORY_30DAYS,
		--	STORAGE_HISTORY_52WEEKS	
		--
		-- For targets:
		-- Summaries or target_ids not in mgmt_targets are retained with the same id, 
		-- it is assumed that the target_id of a host deleted from mgmt_targets will not be reused again in mgmt_targets
		--
		-- For groups:
		-- Are archived with id ARCHIVED_<SYSDAYE>_id when the group id is deleted in STORAGE_SUMMARY_DB.GET_HOST_GROUP_ID
		--
		--
		-- No other maintenance is required
		--
		------------------------------------------------------------------------------------------------------------------------

		STORAGE_SUMMARY_DB.REFRESH_DC_LOB_GROUPS;
	
		--COMMIT;

	EXCEPTION
		WHEN OTHERS THEN
			--ROLLBACK;
			RAISE_APPLICATION_ERROR(-20101,'Failed to refresh the datacenter and Lob grouping in grouping table',TRUE);
	END;

	-- All the non distributed txn are treated as a single txn
	COMMIT;

	--STORAGE_SUMMARY_DB.DELETELOG('refresh_groups');
	STORAGE_SUMMARY_DB.LOG_TIME('refresh_masters','refresh_groups','refresh_groups','Refreshed the dc ,lob groups STORAGE_SUMMARY.REFRESH_DC_LOB_GROUP ',STORAGE_SUMMARY_DB.GETTIME(l_time));


	STORAGE_SUMMARY_DB.LOG_TIME('refresh_masters','refresh_masters','refresh_masters','Refreshed masters in STORAGE_SUMMARY.REFRESH_MASTERS ',STORAGE_SUMMARY_DB.GETTIME(l_elapsedtime));

EXCEPTION

	WHEN OTHERS THEN
		
		-- rollback whatever we can
		ROLLBACK;

		l_errmsg := 'ABORTING refreshing masters, '||SUBSTR(SQLERRM,1,2048);

		STORAGE_SUMMARY_DB.LOGERROR('refresh_masters',l_errmsg);

		RAISE;
	
END refresh_masters;

-------------------------------------------------------------------------------
-- FUNCTION NAME :	hostRollupdata
--
-- DESC 	: 
-- Calculate the storage summary for each host in mgmt_targets_view
-- 
--
-- ARGS	:
--
------------------------------------------------------------------------------
PROCEDURE hostRollupData IS

l_targets		stringTable;
l_errmsg		storage_log.message%TYPE;
l_time			INTEGER := 0;
l_targetid		mgmt_targets_view.target_id%TYPE;
l_elapsedtime		INTEGER := 0;
l_dummy			NUMBER;

BEGIN

	l_elapsedtime := STORAGE_SUMMARY_DB.GETTIME(l_time);

	-- Free any previous transactions
	COMMIT;

	-----------------------------------------------------------------------------
	-- Clean up the previous debug and error messages for hostrollupdata
	-----------------------------------------------------------------------------
	STORAGE_SUMMARY_DB.DELETELOG('hostrollupdata');
	STORAGE_SUMMARY_DB.LOG('hostrollupdata','BEGIN Execution of storage summary job');
	
	----------------------------------------------------------------------
	--	Purge statistics out of the purge window
	--
	----------------------------------------------------------------------
	BEGIN

		DELETE 
		FROM	storage_statistics
		WHERE	timestamp < SYSDATE - STORAGE_SUMMARY.c_statistics_purge_window;

		COMMIT;

	EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			RAISE_APPLICATION_ERROR(-20101,'Failed to Purge statistics',TRUE);
	END;

	--STORAGE_SUMMARY_DB.DELETELOG('purge_statistics');
	STORAGE_SUMMARY_DB.LOG_TIME('hostrollupdata','purge_statistics','purge_statistics','Purged statistics table storage_statistics ',STORAGE_SUMMARY_DB.GETTIME(l_time));

	--------------------------------------------------------------------------
	-- Fetch the list of targets to process
	--------------------------------------------------------------------------

	l_targets := STORAGE_SUMMARY_DB.GETHOSTLIST;

	IF NOT l_targets.EXISTS(1) THEN
		RAISE_APPLICATION_ERROR(-20101,'No hosts to summarize , aborting summary job');
	END IF;

	------------------------------------------------------
	-- COMPUTE STORAGE SUMMARY FOR EACH HOST
	------------------------------------------------------
	FOR i IN l_targets.FIRST..l_targets.LAST LOOP
		
		--------------------------------------
		-- CHECK FOR THE LOCK
		--------------------------------------
		BEGIN
			SELECT	1
			INTO	l_dummy
			FROM	storage_lock_table
			WHERE	ROWNUM = 1;
		EXCEPTION
			WHEN NO_DATA_FOUND THEN
				EXIT;		
		END;

		-- If any error during processing , skip to the next target
		BEGIN		
			--------------------------------------------------------
			-- THIS CHECKS IF THE TARGET IS STILL IN MASTER
			-- Fetch the target_id	
			--------------------------------------------------------
			l_targetid := STORAGE_SUMMARY_DB.GETTARGETID(l_targets(i));		

			----------------------------------------------------------------
			-- CHECK IF THE TARGET NEEDS TO BE MIGRATED, IF YES MIGRATE IT
			----------------------------------------------------------------			
			DECLARE
				l_original_target_id		mgmt_targets_view.target_id%TYPE;
			BEGIN
				-- Its in the mgmt_migrated_targets table 
				-- and its status is not MIGRATED 
				-- and it has a 9i target_id
				-- and the name matched the current target name
				SELECT	original_target_id
				INTO	l_original_target_id
				FROM	mgmt_migrated_targets
				WHERE	mozart_target_id = l_targetid
				AND	target_name = l_targets(i)
				AND	status IS NULL
				AND 	original_target_id IS NOT NULL;				

				STORAGE_SUMMARY_DB.MIGRATE_TARGETS(l_original_target_id,l_targetid);
		
				COMMIT;

				STORAGE_SUMMARY_DB.LOG('hostrollupdata',' Target to be migrated from 9i to mozart '||l_targets(i));

			EXCEPTION
				WHEN NO_DATA_FOUND THEN 
					NULL;
				WHEN OTHERS THEN
					ROLLBACK;		    
					RAISE;
			END;
			
			STORAGE_SUMMARY_DB.LOG('hostrollupdata','Summarizing for target '||l_targets(i)||' id = '||l_targetid);	
			
			STORAGE_SUMMARY.CALCSTORAGESUMMARY(l_targets(i),l_targetid);

			STORAGE_SUMMARY_DB.LOG_TIME('hostrollupdata',l_targetid,l_targets(i),'Summarized target ',STORAGE_SUMMARY_DB.GETTIME(l_time));


			-- ROLLUP HISTORY AT THIS POINT TBD

		EXCEPTION
			WHEN OTHERS THEN

				l_errmsg := 'Skipping to the next host, error processing '||l_targets(i)||' '||SUBSTR(SQLERRM,1,2048);			

				STORAGE_SUMMARY_DB.LOGERROR('hostrollupdata',l_errmsg);
		END;

	END LOOP;

	STORAGE_SUMMARY_DB.LOG_TIME('hostrollupdata','hostrollupdata','hostrollupdata','Summarized all targets ',STORAGE_SUMMARY_DB.GETTIME(l_elapsedtime));

EXCEPTION

	WHEN OTHERS THEN

		l_errmsg := 'ABORTING execution of summary job, '||SUBSTR(SQLERRM,1,2048);

		STORAGE_SUMMARY_DB.LOGERROR('hostrollupdata',l_errmsg);

		RAISE;
	
END hostRollupData;


-------------------------------------------------------------------------------
-- FUNCTION NAME :	jobstatus
--
-- DESC 	:
-- Print the status of jobs scheduled for storage_summary.hostrollupdata
-- 
-- ARGS	:
-- 
------------------------------------------------------------------------------
PROCEDURE jobstatus IS

CURSOR c1 IS
SELECT	job,
	what,
	next_date||' '||next_sec,
	DECODE(broken,'N','UNBROKEN','BROKEN')
FROM	user_jobs
WHERE	LOWER(what) LIKE '%storage_summary.%'
OR	LOWER(what) LIKE '%storage_summary_db.%';

l_jobnolist	numberTable;
l_whatlist	stringTable;
l_nextdate	stringTable;
l_status	stringTable;
l_errMsg	storage_log.message%TYPE;


BEGIN

-- Fetch the list of all jobs that can exist
	OPEN c1;
	FETCH c1 BULK COLLECT INTO l_jobnolist,l_whatlist,l_nextdate,l_status;
	CLOSE c1;

	IF l_jobnolist IS NULL OR NOT l_jobnolist.EXISTS(1) THEN
		STORAGE_SUMMARY_DB.PRINTSTMT('No job scheduled for storage summary');
		RETURN;
	END IF;

	FOR i IN l_jobnolist.FIRST..l_jobnolist.LAST LOOP
		STORAGE_SUMMARY_DB.PRINTSTMT('Job '||l_whatlist(i)||' job#:'||l_jobnolist(i)||' executing next at '||l_nextdate(i)||' status '||l_status(i));
	END LOOP;

EXCEPTION
	WHEN OTHERS THEN

		l_errmsg := 'Failed to get the status of storage summary job, '||SUBSTR(SQLERRM,1,2048);

		STORAGE_SUMMARY_DB.LOGERROR('JOB',l_errmsg);

		RAISE;
	
END jobstatus;

-------------------------------------------------------------------------------
-- FUNCTION NAME :	cleanjob
--
-- DESC 	:
-- Clean up all previous storage_summary jobs
-- 
-- ARGS	:
-- 
------------------------------------------------------------------------------
PROCEDURE cleanjob IS

CURSOR c1 IS
SELECT	job,
	what
FROM	user_jobs
WHERE	LOWER(what) LIKE '%storage_summary.%'
OR	LOWER(what) LIKE '%storage_summary_db.%';

l_jobnolist	numberTable;
l_jobList	stringTable;

BEGIN

	-----------------------------------
	-- BREAK THE LOCK
	-----------------------------------
	DELETE FROM storage_lock_table;
	COMMIT;

-- Clean up any old jobs
	OPEN c1;
	FETCH c1 BULK COLLECT INTO l_jobnolist,l_jobList;	
	CLOSE c1;

	IF l_jobnolist IS NOT NULL AND l_jobnolist.EXISTS(1) THEN
		FOR i IN l_jobnolist.FIRST..l_jobnolist.LAST LOOP
			DBMS_JOB.BROKEN(l_jobnoList(i),FALSE);
			DBMS_JOB.REMOVE(l_jobnoList(i));
			STORAGE_SUMMARY_DB.PRINTSTMT('Removed job :'||l_jobList(i)||' job#: '||l_jobnoList(i));
		END LOOP;
	END IF;

	COMMIT;
	
EXCEPTION

	WHEN OTHERS THEN

		ROLLBACK;
		
		RAISE;	
END cleanjob;

-------------------------------------------------------------------------------
-- FUNCTION NAME :	submitjob
--
-- DESC 	:
-- Clean up previous jobs and schedule
-- execution of the hostrollupdata once in frequency*hours
-- Default frequency is hourly
-- 
-- ARGS	:
-- 	frequency (in hours)
------------------------------------------------------------------------------
PROCEDURE submitjob(v_frequency NUMBER DEFAULT 1) IS

l_jobno		INTEGER := 0;
l_frequency	NUMBER(16);
l_errmsg	storage_log.message%TYPE;

BEGIN


-- Delete any DEBUG AND LOG MESSAGES from the last submit
	STORAGE_SUMMARY_DB.DELETELOG('JOB');

-- Clean up any old jobs
	STORAGE_SUMMARY.CLEANJOB;

	--------------------------------------
	-- MAKE AN ENTRY FOR THE LOCK
	--------------------------------------
	INSERT INTO storage_lock_table VALUES(1);
	COMMIT;

	-------------------------------------------------------
	-- Submit the refresh_masters job (Once in 60 Mins )
	-------------------------------------------------------
	DBMS_JOB.SUBMIT(l_jobno,'storage_summary.refresh_masters;',SYSDATE,'SYSDATE + '||(1/96));
	COMMIT;

	STORAGE_SUMMARY_DB.LOG('JOB','Job storage_summary.refresh_masters scheduled '||'job#: '||l_jobno);

	-------------------------------------------------------
	-- Submit the hostrollup job
	-------------------------------------------------------
	-- frequency should be >= 30 mins
	IF v_frequency < 0.5 THEN
		l_frequency := .5;
	ELSE
		l_frequency := v_frequency;
	END IF;

	DBMS_JOB.SUBMIT(l_jobno,'storage_summary.hostrollupdata;',SYSDATE,'SYSDATE + '||(l_frequency/24));
	COMMIT;

	STORAGE_SUMMARY_DB.LOG('JOB','Job storage_summary.hostrollupdata scheduled '||', job#: '||l_jobno);

	-------------------------------------------------------
	-- Submit the statistics gathering job, 
	-- Once a day
	-------------------------------------------------------
	DBMS_JOB.SUBMIT(l_jobno,'storage_summary_db.gather_schema_statistics;',SYSDATE,'SYSDATE + '||(24/24));
	COMMIT;

	STORAGE_SUMMARY_DB.LOG('JOB','Job storage_summary_db.gather_schema_statistics scheduled '||'job#: '||l_jobno);

	
EXCEPTION

	WHEN OTHERS THEN

		ROLLBACK;

		l_errmsg := 'Failed to submit jobs for computing storage summary '||SUBSTR(SQLERRM,1,2048);

		STORAGE_SUMMARY_DB.LOGERROR('JOB',l_errmsg);
		
		RAISE;
END submitjob;



-------------------------------------------------------------------------------
-- FUNCTION NAME :	compute_on_demand_summary
--
-- DESC 	:
-- Computes an summary for the individual host target name passed as argument
-- Raises an exception if the summary computation failed for any reason. 
--
-- ARGS	:
-- 	host target name
------------------------------------------------------------------------------
PROCEDURE compute_on_demand_summary ( v_target_name  IN mgmt_targets_view.target_name%TYPE ) IS

l_target_id		mgmt_targets_view.target_id%TYPE;

BEGIN

	-- Is the target name valid
	BEGIN
		SELECT	target_id 
		INTO	l_target_id
		FROM	mgmt_targets_view
		WHERE	target_name = v_target_name
		AND	target_type = 'oracle_sysman_node';
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			RAISE_APPLICATION_ERROR(-20101,'Target name '||v_target_name||' is not found in the list of host targets',TRUE);
		WHEN OTHERS THEN
			RAISE_APPLICATION_ERROR(-20101,'Failed looking up Target name '||v_target_name||' in the list of host targets',TRUE);
	END;

	-- Stop the currently executing jobs
	STORAGE_SUMMARY.CLEANJOB;
	
	-- Calculate the storage summary for the target
	STORAGE_SUMMARY.CALCSTORAGESUMMARY(v_target_name, l_target_id);

	-- Check if there was metric data to compute the summary
	DECLARE
		l_dummy	INTEGER;
	BEGIN
		SELECT	1
		INTO	l_dummy
		FROM	stormon_load_status
		WHERE	node_id = l_target_id
		AND	ROWNUM = 1;

	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			RAISE_APPLICATION_ERROR(-20101,'Failed to compute summary , No metric data has been loaded for target name '||v_target_name,TRUE);
		WHEN OTHERS THEN
			RAISE_APPLICATION_ERROR(-20101,'Failed while performing check if data was loaded for '||v_target_name,TRUE);
	END;

	-- Check if there is a summary computed for the target
	DECLARE
		l_dummy	INTEGER;
	BEGIN
		SELECT	1
		INTO	l_dummy
		FROM	storage_summaryobject_view
		WHERE	id = l_target_id
		AND	type = 'HOST';

	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			RAISE_APPLICATION_ERROR(-20101,'Failed to compute summary for target name '||v_target_name,TRUE);
		WHEN OTHERS THEN
			RAISE_APPLICATION_ERROR(-20101,'Failed while performing check if summary has been computed for '||v_target_name,TRUE);
	END;	


	-- Check if the summary was computed , but there was an issue with that computation
	DECLARE
		l_dummy		INTEGER;
	BEGIN

		SELECT	1
		INTO	l_dummy
		FROM	storage_summaryObject_view a,
			(
				SELECT	node_id,
					MAX(timestamp)		      timestamp,
					MAX(max_collection_timestamp) max_collection_timestamp
				FROM	stormon_load_status
				WHERE	node_id = l_target_id
				GROUP BY
					node_id
			) b
		WHERE	a.id = b.node_id
		AND	a.type = 'HOST'
		AND	NVL(a.summaryflag,'x') != 'Y'
		AND	(
			a.collection_timestamp  >= CAST ( b.max_collection_timestamp AS DATE )
		OR	a.timestamp >= CAST ( b.timestamp AS DATE )
		);

		RAISE_APPLICATION_ERROR(-20101,'Summary computed , but has an issue for target name '||v_target_name,TRUE);

	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			NULL;
		WHEN OTHERS THEN
			IF SQLCODE != -20101 THEN
				RAISE_APPLICATION_ERROR(-20101,'Failed while performing check if summary computed has an issue for '||v_target_name,TRUE);	
			ELSE
				RAISE;
			END IF;
	END;



	-- Check if the summary was not computed, for the current collection in the repository
	DECLARE
		l_dummy		INTEGER;
	BEGIN

		SELECT	1
		INTO	l_dummy
		FROM	storage_summaryObject_view a,
			(
				SELECT	node_id,				
					MAX(max_collection_timestamp) max_collection_timestamp
				FROM	stormon_load_status
				WHERE	node_id = l_target_id
				GROUP BY
					node_id
			) b
		WHERE	a.id = b.node_id
		AND	a.type = 'HOST'	
		AND	a.collection_timestamp  < CAST ( b.max_collection_timestamp AS DATE );

		RAISE_APPLICATION_ERROR(-20101,'Retaining the old summary , as there was an issue with computing summary with the newly loaded data for target name '||v_target_name,TRUE);

	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			NULL;
		WHEN OTHERS THEN
			IF SQLCODE != -20101 THEN
				RAISE_APPLICATION_ERROR(-20101,'Failed while performing check if summary was computed for the newly loaded data for '||v_target_name,TRUE);	
			ELSE
				RAISE;
			END IF;
	END;


	-- Restore the summary cmputation job
	STORAGE_SUMMARY.SUBMITJOB;

EXCEPTION
	WHEN OTHERS THEN
		-- Restore the summary computation job
		STORAGE_SUMMARY.SUBMITJOB;
		RAISE;
		
END compute_on_demand_summary;



-------------------------------------------------------------------------------
-- FUNCTION NAME :	createcomb
--
-- DESC 	:
--
-- Generate all the combinations for the list of hosts passed 
-- for the number of hosts to chose
-- Generate the n C r combinations
--
-- ARGS	:
-- 	list of hosts to be combined
--	a list of combinations (IN OUT)
--	a combination place holder
--	no of hosts to be combined  , r at a time
--	position of the array element in this iteration
--	level of iteration
--
------------------------------------------------------------------------------
PROCEDURE createcomb(
			v_hostList IN stringTable,					-- List of hosts, n number of hosts
			v_listcombinations IN OUT NOCOPY tableStringTable, 	-- Array of stringTables
			v_combination IN OUT NOCOPY stringTable,		-- Combination of Hosts
			v_hosts   INTEGER,					-- r at a time
			v_position INTEGER,					-- which array element
			v_level	   INTEGER					-- the level of iteration
		)
IS

BEGIN

	-- Fool proof checks
	-- n = 0
	IF v_hostList IS NULL OR NOT v_hostList.EXISTS(1) THEN
		RETURN;
	END IF;

	-- r is > n
	IF v_hosts > v_hostList.COUNT THEN
		RETURN;
	END IF;

	-- Position > n
	IF v_position > v_hostList.COUNT THEN
		RETURN;
	END IF;

	-- Level > r
	IF v_level > v_hosts THEN
		RETURN;
	END IF;

	-- Initialize the combination stringTable at the first iteration
	IF  v_level = 1 THEN
		
		v_combination := stringTable();		
		v_listCombinations := tableStringTable();

	END IF;

	-- Generate the combinations here if r = interation level
	IF  ( v_level = v_hosts ) THEN
	
		-- From the passed in array position to the end
		FOR i IN v_position..v_hostList.COUNT LOOP
			
			-- If no element to hold the current value
			-- extend it
			IF NOT v_combination.EXISTS(v_level) THEN
		
				v_combination.EXTEND;
	
			END IF;

			-- Copy the value
			v_combination(v_level) := v_hostList(i);
				
			-- Save the list of combinations
			IF v_listCombinations IS NULL THEN
				
				 v_listCombinations := tableStringTable();
				
			END IF;

			v_listCombinations.EXTEND;
			v_listCombinations(v_listcombinations.LAST) := v_combination;							

		END LOOP;

	ELSE
		
		-- From the passed in array position to the end	
		FOR i IN v_position..(v_hostList.COUNT-(v_hosts-v_level)) LOOP
			
			-- If no element to hold the current value
			-- extend it	
			IF NOT v_combination.EXISTS(v_level) THEN
		
				v_combination.EXTEND;
	
			END IF;

			-- Copy the value
			v_combination(v_level) := v_hostList(i);
			
			-- Create the combination for the next level, 
			createcomb(v_hostList,v_listcombinations, v_combination,v_hosts,i+1,v_level+1);
	
		END LOOP;

	END IF;

EXCEPTION					
	WHEN OTHERS THEN
		RAISE_APPLICATION_ERROR(-20101,'Failed generating combinations for hosts sharing storage level '||v_level, TRUE);			

END createcomb;

-------------------------------------------------------------------------------
-- FUNCTION NAME: gettotalstorage
--
-- DESC 	: 
-- Get the total raw storage for a LUN based on its configuration and 
--  Vendor,Product information
-- 
-- ARGS	:
--	vendor
--	product
--	diskconfig
--	sizeb
------------------------------------------------------------------------------
FUNCTION gettotalstorage 
			 (
				v_vendor     VARCHAR2,
				v_product    VARCHAR2,
				v_diskconfig VARCHAR2,
				v_sizeb      NUMBER
			) RETURN NUMBER IS
BEGIN

	IF ( v_vendor LIKE 'EMC%' AND v_product LIKE '%SYMMETRIX%' )
	THEN

		CASE

			-- List types in the DESC order of length , so 	
			-- We can have a wide match of configuration			    
			WHEN v_diskconfig LIKE  '%UNPROTECTED%' THEN
				RETURN	v_sizeb;
			WHEN v_diskconfig LIKE  '%BCV_RDF_R2_MIRR%' THEN
				RETURN	v_sizeb * 2;
    			WHEN v_diskconfig LIKE  '%BCV_RDF_R1_MIRR%' THEN
				RETURN	v_sizeb * 2;
    			WHEN v_diskconfig LIKE  '%RDF_R1_RAID_S%' THEN
				RETURN	v_sizeb * 4/3;
    			WHEN v_diskconfig LIKE  '%RDF_R2_RAID_S%' THEN
				RETURN	v_sizeb * 4/3;
			WHEN v_diskconfig LIKE  '%RAID_S_MIRR%' THEN
				RETURN v_sizeb * 2 * 4/3;
    			WHEN v_diskconfig LIKE  '%RDF_R1_MIRR%' THEN
				RETURN	v_sizeb * 2;
    			WHEN v_diskconfig LIKE  '%RDF_R2_MIRR%' THEN
				RETURN	v_sizeb * 2;
    			WHEN v_diskconfig LIKE  '%BCV_MIRR_2%' THEN
				RETURN	v_sizeb * 2;
    			WHEN v_diskconfig LIKE  '%BCV_RDF_R1%' THEN
				RETURN	v_sizeb;
    			WHEN v_diskconfig LIKE  '%DRV_MIRR_2%' THEN
				RETURN	v_sizeb * 2;
    			WHEN v_diskconfig LIKE  '%BCV_RDF_R2%' THEN
				RETURN	v_sizeb;
			WHEN v_diskconfig LIKE  '%RAID_S%' THEN
				RETURN v_sizeb * 4/3;
    			WHEN v_diskconfig LIKE  '%RDF_R1%' THEN
				RETURN	v_sizeb;
    			WHEN v_diskconfig LIKE  '%RDF_R2%' THEN
				RETURN	v_sizeb;
    			WHEN v_diskconfig LIKE  '%BCV%' THEN
				RETURN	v_sizeb;
    			WHEN v_diskconfig LIKE  '%SPARE%' THEN
				RETURN	v_sizeb;
    			WHEN v_diskconfig LIKE  '%MIRR_2%' THEN
				RETURN v_sizeb * 2;
    			WHEN v_diskconfig LIKE  '%MIRR_3%' THEN
				RETURN v_sizeb * 3;
    			WHEN v_diskconfig LIKE  '%MIRR_4%' THEN
				RETURN v_sizeb * 4;  
    			WHEN v_diskconfig LIKE  '%DRV%' THEN
				RETURN	v_sizeb;  	
			ELSE
				RETURN v_sizeb;
		END CASE;

	ELSE

		RETURN v_sizeb;

	END IF;
  
END gettotalstorage;


------------------------------------------------------------------------------------------------------------
-- FUNCTION NAME: rollup
--
-- DESC 	: Roll up the summary into 30day, 17 week and 12 Month archives
-- 		  For target id, shared id
-- 
-- ARGS	:	target_name
--		target_id
--
--
-- Clean up rollup log for the id
-- 1. Fetch id, and collection_timestamp range
-- 2. Fetch the LATEST SUMMARY from storage_summaryObject_history W/0 issues
-- 3. Fetch the timestamp of the LAST ROLLED UP SUMMARY as STARTTIME 
-- 3.1 If there is NO rolled up HISTORY for the id , start with the CUTOFF TIME
-- 5. If min timestamp in storage_summaryObject_history is <= start time, take MIN TIMESTAMP as START TIME
-- 6. Generate the timestamps for all the rollup points between start time and end time 
-- 7. ROLLUP HISTORY for the ID between the start and end time from storage_summaryObject_history and the 
--	rolled up table from summaries W/O issues
-- 9.  Fill in the rolledup summaries for timestamps with NO summaries
-- 8. REPORTING GROUPS SPECIAL
--	ROLLUP history from the rolled up summary targets in the rollup table
-- 10. PURGE any overlapping summaries from the rolled up history table
-- 11. INSERT the rolled up summaries
-- 12. INSERT the last summary W/O issues from storage_summaryObject into the rolledup table for continuity
-- 13. PURGE the history with COLLECTION TIMESTAMP < CUTOFF TIME from the rolled up history table
-- 14. Loop to the next roll up history table and start with STEP 3
-- 15. PURGE the rolled up summaries from storage_summaryObject_history
-- 16. COMMIT ALL CHANGES to the rolled up history table
--
------------------------------------------------------------------------------------------------------------
PROCEDURE rollup IS

l_historysummaryobjects		storageSummaryTable;
l_sortedHistoryObjects		storageSummaryTable;

l_tableList			stringTable := stringTable('storage_history_30days','storage_history_52weeks');
l_formatList			stringTable := stringTable('DD','D');

l_tablename			VARCHAR2(50);
l_formatmodel			VARCHAR2(10);

l_idList			stringTable;
l_correctedGroupSummaries	storageSummaryTable;
l_latestObject                  summaryObject;
l_lastHistoryObject		summaryObject;
l_value				summaryObject;

l_cutofftime			DATE;
l_starttime			DATE;
l_least_valid_summary_ts 	DATE;
l_max_timestamp			DATE;
l_tmTable			dateTable;
l_npoints			INTEGER(4);
l_dummy				INTEGER(1);

l_errMsg			storage_log.message%TYPE;

l_time				INTEGER := 0;
l_elapsedtime			INTEGER := 0;
				
BEGIN

	---------------------------------------------------------------------
	-- DELETE THE PREVIOUS DEBUG AND ERROR MESSAGES FOR RULLUP
	--------------------------------------------------------------------	
	STORAGE_SUMMARY_DB.DELETELOG('rollup');

	STORAGE_SUMMARY_DB.LOG('rollup','Begining rollup job STORAGE_SUMMARY.ROLLUP, Rolling up targets and shared summaries ');

	---------------------------------------------------------------------
	-- ROLLUP EACH VALID REPORTING GROUP, SHARED AND TARGET ID
	---------------------------------------------------------------------
	FOR rec IN (
			SELECT	a.id 				id ,
				b.type 				type,
				b.name				name,				
				MAX(collection_timestamp) 	max_timestamp, 
				MIN(collection_timestamp) 	min_timestamp 
			FROM	(	
					SELECT	id,
						type,
						name
					FROM	stormon_group_table
					UNION
					SELECT	target_id,						
						'HOST',
						target_name name
					FROM	mgmt_targets_view
				) b,
				storage_summaryobject_history a
			WHERE	b.id = a.id
			GROUP BY 
			a.id,
			b.type,
			b.name	
			ORDER BY
			DECODE(b.type,'HOST',1,'SHARED_GROUP',2,3) ASC
		)
		LOOP	

		--------------------------------------
		-- CHECK FOR THE LOCK
		--------------------------------------
		BEGIN
			SELECT	1
			INTO	l_dummy
			FROM	storage_lock_table
			WHERE	ROWNUM = 1;
		EXCEPTION
			WHEN NO_DATA_FOUND THEN
				EXIT;		
		END;

		l_time := 0;
		l_elapsedtime := 0;

		l_elapsedtime := STORAGE_SUMMARY_DB.GETTIME(l_time);

		STORAGE_SUMMARY_DB.LOG('rollup','Id = '||rec.id||' Rolling up between timestamps '
		||TO_CHAR(rec.max_timestamp,'DD-MON-YY HH24:MI:SS')||' and '
		||TO_CHAR(rec.min_timestamp,'DD-MON-YY HH24:MI:SS'));
		
		----------------------------------------------------------
		-- ROLLBACK SKIP THIS ID WHEN EXCEPTIONS
		----------------------------------------------------------
		BEGIN	

			-- Initialize the objects
			l_idList	:= NULL;
			l_latestObject  := NULL;

                        ---------------------------------------------------------------------------
                        -- FETCH THE MOST CURRENT OBJECT FROM STORAGE_SUMMARYOBJECT_HISTORY
                        -- ONLY VALID SUMMARIES (summaryFlag = Y and issues = 0 ) EXIST IN 
                        -- STORAGE_SUMMARYOBJECT_HISTORY
                        ---------------------------------------------------------------------------
                        BEGIN
                                SELECT        *
                                INTO        l_latestObject
                                FROM        (
                                                SELECT	VALUE(a)
                                                FROM	storage_summaryObject_history a
                                                WHERE	id = rec.id
                                                AND	collection_timestamp <= rec.max_timestamp
                                                ORDER BY
                                                        collection_timestamp DESC
                                        ) a
                                WHERE        ROWNUM = 1;
                        
                        EXCEPTION

                                WHEN NO_DATA_FOUND THEN
                                        STORAGE_SUMMARY_DB.LOG('rollup','Id = '||rec.id||' Failed to find the latest Object less than  '||TO_CHAR(rec.max_timestamp,'DD-MON-YY HH24:MI:SS')||' in storage_summaryobject_history ');
                        END;


			-----------------------------------------------------------------------
			-- FETCH ALL TARGET AND SHARED ID's IF THIS IS IS AN REPORTING GROUP
			-----------------------------------------------------------------------	
			IF rec.type LIKE 'REPORTING%' THEN

				BEGIN
		
					-- This query to be tested
					EXECUTE IMMEDIATE '
                                        SELECT  id
                                        FROM    stormon_group_table a
                                        WHERE   type = ''SHARED_GROUP''
--                                        AND     EXISTS
--                                               (
--					-- Does this shared id have a target in this group ?
--                                                        SELECT  1
--                                                        FROM    stormon_host_groups b,
--                                                                stormon_host_groups c
--                                                        WHERE   c.group_id = a.id
--                                                        AND     b.group_id = :groupid
--                                                        AND     b.target_id = c.target_id
--                                                )
                                        AND     NOT EXISTS (
                                        -- Does this shared id have a target which is not in this group ?
                                                        SELECT  1
                                                        FROM    stormon_host_groups b
                                                        WHERE   b.group_id = a.id
                                                        AND     b.target_id NOT IN
                                                        (
                                                                SELECT  target_id
                                                                FROM    stormon_host_groups
                                                                WHERE   group_id = :groupid
                                                        )
                                                )
                                        UNION
                                        SELECT  target_id
                                        FROM    stormon_host_groups
                                        WHERE   group_id = :groupid '
					BULK COLLECT INTO l_idList
					USING rec.id, rec.id;

					IF l_idList IS NULL OR NOT l_idList.EXISTS(1) THEN
						RAISE_APPLICATION_ERROR(-20101,'No Target and shared IDs found for this group '||rec.id);
					END IF;

				END;		

			END IF;

			----------------------------------------------------------
			-- ROLLUP HISTORY FOR EACH HISTORY TABLE
			---------------------------------------------------------
			FOR k IN l_tableList.FIRST..l_tableList.LAST LOOP
			
				-- Initialize the obects 
				l_historysummaryobjects		:= NULL;
				l_sortedHistoryObjects		:= NULL;
				l_lastHistoryObject		:= NULL;
				l_value				:= NULL;
				l_starttime			:= NULL;
				l_least_valid_summary_ts	:= NULL;
				l_correctedGroupSummaries	:= NULL;

				l_tablename 			:= l_tableList(k);
				l_formatmodel			:= l_formatList(k);
		
				STORAGE_SUMMARY_DB.PRINTSTMT('Table = '||l_tablename);
				STORAGE_SUMMARY_DB.PRINTSTMT('Format model '||l_formatmodel);

				-- Get the cut off history time
				IF UPPER(l_formatmodel) = 'D' THEN
	
				        l_cutofftime	:= TRUNC(rec.max_timestamp,l_formatmodel)-(53*7);
	
				ELSE
			                l_cutofftime	:= TRUNC(rec.max_timestamp,l_formatmodel)-32;
		
				END IF;
				
				STORAGE_SUMMARY_DB.PRINTSTMT('Cutoff date '||TO_CHAR(l_cutofftime,'DD-MON-YY HH24:MI:SS'));
	
				----------------------------------------------------
				-- FETCH THE LAST OBJECT FROM THE HISTORY TABLE
				-- FETCH A VALID SUMMARY summaryFlag = Y
				-- NOT A NULL(N) , PLACEHOLDER(P) OR LAST SUMMARY(L)
				----------------------------------------------------
				BEGIN

					EXECUTE IMMEDIATE
					'SELECT	*
					FROM	(
							SELECT	VALUE(a)
							FROM '||l_tablename||' a
							WHERE	id = :a
							AND	summaryflag = ''Y''
							ORDER BY
							collection_timestamp DESC
						)
					WHERE	ROWNUM = 1'
					INTO 	l_lastHistoryObject
					USING rec.id;

				EXCEPTION

					--------------------------------------------------------
					-- NO HISTORY DATA FOR THIS ID
					--------------------------------------------------------
					WHEN NO_DATA_FOUND THEN

						STORAGE_SUMMARY_DB.PRINTSTMT('No history found for '||rec.id|| ' in '||l_tablename);
						l_lastHistoryObject := NULL;

				END; -- END OF BLOCK FOR FETCHING LAST OBJECT FROM ROLLED UP HISTORY

				-----------------------------------------------------------------------------------------
				-- START TIME FOR ROLLUP IS LEAST OF MIN TIMESTAMP IN STORAGE_SUMMARYOBJECT_HISTORY OR
				-- MAX TIME OF LAST ROLLUP IN ROLLED UP HISTORY TABLE
				-----------------------------------------------------------------------------------------
                                IF l_lastHistoryObject IS NULL THEN
	
					l_starttime 			:= l_cutofftime;				
					l_least_valid_summary_ts 	:= TRUNC(rec.min_timestamp,l_formatmodel);				

				ELSIF rec.min_timestamp < l_lastHistoryObject.collection_timestamp THEN

                                        l_starttime 			:= TRUNC(rec.min_timestamp,l_formatmodel);
					l_least_valid_summary_ts 	:= TRUNC(rec.min_timestamp,l_formatmodel);

                                ELSE

                                        l_starttime 			:= TRUNC(l_lastHistoryObject.collection_timestamp,l_formatmodel);
					l_least_valid_summary_ts 	:= TRUNC(l_lastHistoryObject.collection_timestamp,l_formatmodel);

                                END IF;
				

				STORAGE_SUMMARY_DB.PRINTSTMT('Start date '||TO_CHAR(l_starttime,'DD-MON-YY HH24:MI:SS'));		


				IF l_starttime <= TRUNC(rec.max_timestamp,l_formatmodel) THEN

					-----------------------------------------------------------------------------------------
					--	CREATE A COLLECTION OF ALL TIMESTAMPS BETWEEN START TIME AND MAX TIME IN
					--      STORAGE_SUMMARYOBJECT_HISTORY
					-----------------------------------------------------------------------------------------
			
				        IF UPPER(l_formatmodel) = 'MON' THEN
				
			        	        l_npoints        := MONTHS_BETWEEN(TRUNC(rec.max_timestamp,l_formatmodel),l_starttime);
			
				        ELSIF UPPER(l_formatmodel) = 'D' THEN
			
			        	        l_npoints       := ROUND((TRUNC(rec.max_timestamp,l_formatmodel) - l_starttime) / 7);
				
				        ELSE
			
			        	        l_npoints       := ROUND(TRUNC(rec.max_timestamp,l_formatmodel) - l_starttime);
			
				        END IF;
			
					STORAGE_SUMMARY_DB.PRINTSTMT('No of points '||l_npoints||' between '||TO_CHAR(l_starttime,'DD-MON-YY HH24:MI:SS')||' and '||
								TO_CHAR(rec.max_timestamp,'DD-MON-YY HH24:MI:SS'));
		
	
					-------------------------------------------------------------------------------
				        -- LIST OF TIMESTAMPS FROM STARTTIME TO MAXTIMESTAMP 
					-------------------------------------------------------------------------------
					l_tmTable := dateTable();
					l_tmTable.EXTEND(l_npoints+1);
			
			        	FOR i IN 1..l_npoints+1 LOOP
			    
				                IF l_formatmodel = 'DD' THEN
			
			        	                l_tmTable(i) := l_starttime + (i-1);
			
				                ELSIF l_formatmodel = 'D' THEN
			
			        	                 l_tmTable(i) := l_starttime + 7*(i-1);
			
				                ELSE 
			
				                         l_tmTable(i) := ADD_MONTHS(l_starttime,(i-1));
			
			        	        END IF;
			        
				        END LOOP;	
			
					STORAGE_SUMMARY_DB.PRINTSTMT('History time end points '||TO_CHAR(l_tmtable(1),'DD-MON-YYYY HH24:MI:SS')||' And '||
							TO_CHAR(l_tmtable(l_npoints+1),'DD-MON-YYYY HH24:MI:SS'));
	
					----------------------------------------------------------------------------------
					--	COMPUTE THE SUMMARY OBJECTS FOR THIS TARGET ID IN THEN INTERVAL
					--	BETWEEN START TIME AND MAX TIMESTAMP IN STORAGE_SUMMARYOBJECT_HISTORY
					-----------------------------------------------------------------------------------
					STORAGE_SUMMARY_DB.PRINTSTMT('Computing summary Objects for '||rec.id||' start time '||TO_CHAR(l_starttime,'DD-MON-YYYY HH24:MI:SS')||
						' max time '||TO_CHAR(rec.max_timestamp,'DD-MON-YYYY HH24:MI:SS'));
	
					EXECUTE IMMEDIATE 
					'SELECT	summaryObject(
						NULL					,	-- rowcount
						NULL					,	-- name
						id					,	-- id
						SYSDATE					,	-- timestamp
						TRUNC(collection_timestamp,:formatmodel),	-- collection_timestamp
						MAX(hostcount)				,	-- hostcount
						MAX(actual_targets)			,	-- actual_targets
						0					,	-- issues
						0					,	-- warnings
						''Y''		     			,	-- summaryFlag
						AVG(application_rawsize)	,
						AVG(application_size)	,
						AVG(application_used)	,
						AVG(application_free)	,
						AVG(oracle_database_rawsize)	,
						AVG(oracle_database_size)	,
						AVG(oracle_database_used)	,
						AVG(oracle_database_free)	,
						AVG(local_filesystem_rawsize),
						AVG(local_filesystem_size)	,
						AVG(local_filesystem_used)	,
						AVG(local_filesystem_free)	,
						AVG(nfs_exclusive_size)	,
						AVG(nfs_exclusive_used)	,
						AVG(nfs_exclusive_free)	,
						AVG(nfs_shared_size)		,
						AVG(nfs_shared_used)		,
						AVG(nfs_shared_free)		,
						AVG(volumemanager_rawsize)	,
						AVG(volumemanager_size)	,
						AVG(volumemanager_used)	,
						AVG(volumemanager_free)	,
						AVG(swraid_rawsize)		,
						AVG(swraid_size)		,
						AVG(swraid_used)		,
						AVG(swraid_free)		,
						AVG(disk_backup_rawsize)	,
						AVG(disk_backup_size)	,
						AVG(disk_backup_used)	,
						AVG(disk_backup_free)	,
						AVG(disk_rawsize)		,
						AVG(disk_size)		,
						AVG(disk_used)		,
						AVG(disk_free)		,
						AVG(rawsize)			,
						AVG(sizeb)			,
						AVG(used)			,
						AVG(free)			,
						AVG(vendor_emc_size)		,
						AVG(vendor_emc_rawsize)	,
						AVG(vendor_sun_size)		,
						AVG(vendor_sun_rawsize)	,
						AVG(vendor_hp_size)		,
						AVG(vendor_hp_rawsize)	,
						AVG(vendor_hitachi_size)	,
						AVG(vendor_hitachi_rawsize)	,
						AVG(vendor_others_size)	,
						AVG(vendor_others_rawsize)	,
						AVG(vendor_nfs_netapp_size)	,
						AVG(vendor_nfs_emc_size)	,
						AVG(vendor_nfs_sun_size)	,
						AVG(vendor_nfs_others_size)
					)	
					FROM
					(
					SELECT	id			,	-- id
						timestamp		,	-- timestamp
						collection_timestamp	,	-- collection_timestamp
						hostcount		,	-- hostcount
						actual_targets		,	-- actual_targets
						issues			,	-- issues
						warnings		,	-- warnings
						summaryFlag     	,	-- summaryFlag
						application_rawsize	,
						application_size	,
						application_used	,
						application_free	,
						oracle_database_rawsize	,
						oracle_database_size	,
						oracle_database_used	,
						oracle_database_free	,
						local_filesystem_rawsize,
						local_filesystem_size	,
						local_filesystem_used	,
						local_filesystem_free	,
						nfs_exclusive_size	,
						nfs_exclusive_used	,
						nfs_exclusive_free	,
						nfs_shared_size		,
						nfs_shared_used		,
						nfs_shared_free		,
						volumemanager_rawsize	,
						volumemanager_size	,
						volumemanager_used	,
						volumemanager_free	,
						swraid_rawsize		,
						swraid_size		,
						swraid_used		,
						swraid_free		,
						disk_backup_rawsize	,
						disk_backup_size	,
						disk_backup_used	,
						disk_backup_free	,
						disk_rawsize		,
						disk_size		,
						disk_used		,
						disk_free		,
						rawsize			,
						sizeb			,
						used			,
						free			,
						vendor_emc_size		,
						vendor_emc_rawsize	,
						vendor_sun_size		,
						vendor_sun_rawsize	,
						vendor_hp_size		,
						vendor_hp_rawsize	,
						vendor_hitachi_size	,
						vendor_hitachi_rawsize	,
						vendor_others_size	,
						vendor_others_rawsize	,
						vendor_nfs_netapp_size	,
						vendor_nfs_emc_size	,
						vendor_nfs_sun_size	,
						vendor_nfs_others_size		
					FROM	storage_summaryobject_history
					WHERE	id = :x
					AND	collection_timestamp >= TRUNC(:y,:formatmodel)
					AND	TRUNC(collection_timestamp,:formatmodel) <= :z
					UNION
					-------------------------------------------------------------------
					-- MERGE WITH DATA IN THE ROLLED UP TABLE IN THE SAME TIME WINDOW
					-------------------------------------------------------------------
					SELECT	id			,	-- id
						timestamp		,	-- timestamp
						collection_timestamp	,	-- collection_timestamp
						hostcount		,	-- hostcount
						actual_targets		,	-- actual_targets
						issues			,	-- issues
						warnings		,	-- warnings
						summaryFlag     	,	-- summaryFlag
						application_rawsize	,
						application_size	,
						application_used	,
						application_free	,
						oracle_database_rawsize	,
						oracle_database_size	,
						oracle_database_used	,
						oracle_database_free	,
						local_filesystem_rawsize,
						local_filesystem_size	,
						local_filesystem_used	,
						local_filesystem_free	,
						nfs_exclusive_size	,
						nfs_exclusive_used	,
						nfs_exclusive_free	,
						nfs_shared_size		,
						nfs_shared_used		,
						nfs_shared_free		,
						volumemanager_rawsize	,
						volumemanager_size	,
						volumemanager_used	,
						volumemanager_free	,
						swraid_rawsize		,
						swraid_size		,
						swraid_used		,
						swraid_free		,
						disk_backup_rawsize	,
						disk_backup_size	,
						disk_backup_used	,
						disk_backup_free	,
						disk_rawsize		,
						disk_size		,
						disk_used		,
						disk_free		,
						rawsize			,
						sizeb			,
						used			,
						free			,
						vendor_emc_size		,
						vendor_emc_rawsize	,
						vendor_sun_size		,
						vendor_sun_rawsize	,
						vendor_hp_size		,
						vendor_hp_rawsize	,
						vendor_hitachi_size	,
						vendor_hitachi_rawsize	,
						vendor_others_size	,
						vendor_others_rawsize	,
						vendor_nfs_netapp_size	,
						vendor_nfs_emc_size	,
						vendor_nfs_sun_size	,
						vendor_nfs_others_size		
					FROM	'||l_tablename||' 
					WHERE	id = :a
					AND	summaryFlag = ''Y''
					AND	collection_timestamp >= TRUNC(:b,:formatmodel)
					AND	TRUNC(collection_timestamp,:formatmodel) <= :c
					)
					GROUP BY
					id,				
					TRUNC(collection_timestamp,:formatmodel)'
					BULK COLLECT INTO l_historySummaryObjects
					USING l_formatmodel,rec.id,l_starttime,l_formatmodel,l_formatmodel,rec.max_timestamp,rec.id,l_starttime,
					l_formatmodel,l_formatmodel,rec.max_timestamp,l_formatmodel;
	
					IF l_historySummaryObjects IS NOT NULL AND l_historySummaryObjects.EXISTS(1) THEN
		
						STORAGE_SUMMARY_DB.PRINTSTMT('No of rows fetched from the history table '||l_historySummaryObjects.COUNT);
						STORAGE_SUMMARY_DB.PRINTSTMT('Fetched data time end points '||TO_CHAR(l_historySummaryObjects(1).collection_timestamp,'DD-MON-YYYY HH24:MI:SS')||
							' And '||TO_CHAR(l_historySummaryObjects(l_historySummaryObjects.LAST).collection_timestamp,'DD-MON-YYYY HH24:MI:SS'));
					ELSE
						STORAGE_SUMMARY_DB.PRINTSTMT('NO history data fetched');
					END IF;
						
					-----------------------------------------------------------------------------------------
					--	FILL IN THE ABSENT TIMESTAMPS IN THIS INTERVAL , THOSE SUMMARIIES ARE FLAGGED N
					-----------------------------------------------------------------------------------------	
					SELECT	summaryObject(
						ROWNUM,				-- rowcount
					        b.name,				-- name
					        NVL(b.id,rec.id),		-- id
						SYSDATE,			-- timestamp
					        VALUE(a),			-- collection_timestamp
						NVL(b.hostcount,0),		-- hostcount
						NVL(b.actual_targets,0),	-- actual_targets
						b.issues,			-- No. of issues
						b.warnings,			-- No of warnings
						NVL(b.summaryflag,'N'),		-- summaryFlag, If null then N indicates its a placeholder summary Object
					        NVL(b.application_rawsize,0),        
					        NVL(b.application_size,0),
					        NVL(b.application_used,0),
					        NVL(b.application_free,0),
					        NVL(b.oracle_database_rawsize,0),
					        NVL(b.oracle_database_size,0),
					        NVL(b.oracle_database_used,0),
					        NVL(b.oracle_database_free,0),
					        NVL(b.local_filesystem_rawsize,0),
					        NVL(b.local_filesystem_size,0),
					        NVL(b.local_filesystem_used,0),
					        NVL(b.local_filesystem_free,0),
					        NVL(b.nfs_exclusive_size,0),
						NVL(b.nfs_exclusive_used,0),
					        NVL(b.nfs_exclusive_free,0),
					        0,				-- nfs_shared_size, no group summary
						0,				-- nfs_shared_used, no group summary
					        0,				-- nfs_shared_free, no group summary
					        NVL(b.volumemanager_rawsize,0),
					        NVL(b.volumemanager_size,0),
					        NVL(b.volumemanager_used,0),
					        NVL(b.volumemanager_free,0),
					        NVL(b.swraid_rawsize,0),
					        NVL(b.swraid_size,0),
					        NVL(b.swraid_used,0),
					        NVL(b.swraid_free,0),
						NVL(b.disk_backup_rawsize,0),
						NVL(b.disk_backup_size,0),	
						NVL(b.disk_backup_used,0),
						NVL(b.disk_backup_free,0),
					        NVL(b.disk_rawsize,0),
					        NVL(b.disk_size,0),
					        NVL(b.disk_used,0),
					        NVL(b.disk_free,0),
					        NVL(b.rawsize,0),
					        NVL(b.sizeb,0),
					        NVL(b.used,0),
					        NVL(b.free,0),
					        NVL(b.vendor_emc_size,0),
					        NVL(b.vendor_emc_rawsize,0),
					        NVL(b.vendor_sun_size,0),
					        NVL(b.vendor_sun_rawsize,0),
					        NVL(b.vendor_hp_size,0),
					        NVL(b.vendor_hp_rawsize,0),
					        NVL(b.vendor_hitachi_size,0),
					        NVL(b.vendor_hitachi_rawsize,0),
					        NVL(b.vendor_others_size,0),
					        NVL(b.vendor_others_rawsize,0),
					        NVL(b.vendor_nfs_netapp_size,0),
					        NVL(b.vendor_nfs_emc_size,0),
					        NVL(b.vendor_nfs_sun_size,0),
					        NVL(b.vendor_nfs_others_size,0)    
					       	)
					BULK COLLECT INTO l_sortedHistoryObjects
					FROM	TABLE ( CAST ( l_historysummaryObjects AS storageSummaryTable ) ) b,
						TABLE ( CAST ( l_tmTable AS dateTable ) ) a
					WHERE	VALUE(a) = b.collection_timestamp(+)
					ORDER BY 
					VALUE(a) ASC; 	
	
					STORAGE_SUMMARY_DB.PRINTSTMT('No of date points '||l_sortedHistoryObjects.COUNT);
	
					-------------------------------------------------------------------------------
					-- KEEP CONTINUITY IN HISTORY
					-- CHECK FOR ABSENT TIMESTAMPS
					-- CHECK FOR VALID SUMMARY OBJECTS FOR THIS ID
					-- FILL IN ABSENT TIMESTAMPS WITH VALID ROLLED UP SUMMARY OBJECTS
					-------------------------------------------------------------------------------
					BEGIN
		
						-----------------------------------------
						-- Check for absent timestamps
						-----------------------------------------
						SELECT	1
						INTO	l_dummy
						FROM	TABLE( CAST( l_sortedHistoryObjects AS storageSummaryTable ) )
						WHERE	ROWNUM = 1
						AND	summaryFlag = 'N';
						
						BEGIN

							----------------------------------------------------------------
							-- Find the first real summaryObject in the list for this host
							----------------------------------------------------------------
							SELECT	VALUE(a)
							INTO	l_value
							FROM	TABLE ( CAST ( l_sortedhistoryObjects AS storageSummaryTable ) ) a
							WHERE	rowcount = ( 
												SELECT	MAX(rowcount)
												FROM	TABLE ( CAST ( l_sortedhistoryObjects AS storageSummaryTable ) ) b
												WHERE 	b.summaryflag = 'Y'					
											);
		
						EXCEPTION
							------------------------------------------------------------
							-- NO VALID SUMMARY OBJECT IN ALL TIMESTAMPS IN THE INTERVAL
							------------------------------------------------------------
							WHEN NO_DATA_FOUND THEN		
			
								--------------------------------------------------------------------------
								-- NO ROLLED UP HISTORY FOR THIS ID , SKIP ROLLING UP HISTORY THIS TABLE
								--------------------------------------------------------------------------
								STORAGE_SUMMARY_DB.PRINTSTMT('No Valid history point Found in Collection');
							
								IF l_lastHistoryObject IS NULL THEN	
	
									STORAGE_SUMMARY_DB.LOGERROR('rollup',' id = '||rec.id||' No valid object to rollup history , skip to next table');
	
									GOTO next_table;
	
								END IF;
	
								STORAGE_SUMMARY_DB.PRINTSTMT('Take the last rolledup object as history object');					
								l_value := l_lastHistoryObject;
						
						END;
				
	
						----------------------------------------------------------------------------------------------
						-- REPLACE ABSENT TIMESTAMPS WITH VALID SUMMARY OBJECTS FROM THE HIGHER COLLECTION_TIMESTAMP
						----------------------------------------------------------------------------------------------
						STORAGE_SUMMARY_DB.PRINTSTMT('the dummy filler history object '||l_value.id);
				
					        FOR j IN REVERSE l_sortedhistoryObjects.FIRST..l_sortedhistoryObjects.LAST
			        		LOOP
							STORAGE_SUMMARY_DB.PRINTSTMT('Filling for '||l_sortedhistoryObjects(j).collection_timestamp);

							------------------------------------------------------------------------------------------------------
							-- PLACE HOLDER SUMMARIES ONLY AFTER COLLECTION_TIMESTAMP WHEN VALID SUMMARY FROM COLLECTION EXISTS			
							------------------------------------------------------------------------------------------------------
							IF l_sortedhistoryObjects(j).collection_timestamp < TRUNC(l_least_valid_summary_ts,l_formatmodel)
							THEN						
								EXIT;
							END IF;

							-- IF ITS A NULL SUMMARY , PUT A PLACEHOLDER THERE
		                			IF NVL(l_sortedhistoryObjects(j).summaryflag,'N') != 'Y' THEN
		
		        	                		l_value.collection_timestamp		:= l_sortedhistoryObjects(j).collection_timestamp;
			                   	   		l_value.timestamp 	       		:= l_sortedhistoryObjects(j).timestamp;
				                        	l_sortedhistoryObjects(j)	    	:= l_value;
			        	                	l_sortedhistoryObjects(j).summaryflag	:= 'P';
		
				                	ELSE
		        			                l_value := l_sortedhistoryObjects(j);
					                END IF;
				
			        		END LOOP;
		
					EXCEPTION
		
						WHEN NO_DATA_FOUND THEN
							STORAGE_SUMMARY_DB.PRINTSTMT('All History points in collection are valid');
							NULL;
	
					END; -- END OF BLOCK FOR FILLING ABSENT TIMESTAMPS WITH VALID SUMMARIES
	
	
					IF l_sortedHistoryObjects IS NOT NULL AND l_sortedHistoryObjects.EXISTS(1) THEN
				
						-------------------------------------------------------------------------------------
						--	DELETE AND INSERT THE HISTORY OBJECTS INTO THE ROLLED UP HISTORY TABLE
						-------------------------------------------------------------------------------------
						STORAGE_SUMMARY_DB.PRINTSTMT('Deleting/Inserting into '||l_tablename||' for '||rec.id);
	
						FOR i IN l_sortedHistoryObjects.FIRST..l_sortedHistoryObjects.LAST LOOP	

							BEGIN
								EXECUTE IMMEDIATE ' DELETE FROM '||l_tablename||' WHERE id = :id AND collection_timestamp = :collection_timestamp ' 
								USING 
								l_sortedHistoryObjects(i).id , 
								l_sortedHistoryObjects(i).collection_timestamp;

							EXCEPTION
								WHEN OTHERS THEN
									RAISE_APPLICATION_ERROR(-20101,' Failed to delete from '||l_tablename||' for '||
									l_sortedHistoryObjects(i).id||' for timestamp '||
									l_sortedHistoryObjects(i).collection_timestamp);
							END;

							BEGIN

								EXECUTE IMMEDIATE ' INSERT INTO '||l_tablename||' VALUES(:1)' USING l_sortedHistoryObjects(i);
	
							EXCEPTION
								WHEN OTHERS THEN
									RAISE_APPLICATION_ERROR(-20101,' Failed to insert into '||l_tablename||' for '||
									l_sortedHistoryObjects(i).id||' for timestamp '||
									l_sortedHistoryObjects(i).collection_timestamp);
							END;

						END LOOP;
	
					END IF;


                                        ---------------------------------------------------------------------------------
                                        --        DELETE THE PREVIOUS LAST OBJECT AND
                                        --        INSERT THE MOST CURRENT VALID OBJECT INTO THE ROLLED UP HISTORY TABLE
                                        ---------------------------------------------------------------------------------
					BEGIN

						IF l_latestObject IS NOT NULL THEN

							l_latestObject.summaryFlag	:= 'L';  -- Indicate this is a placeholder summary for continuity of the history graph

							IF l_latestObject.collection_timestamp = TRUNC(l_latestObject.collection_timestamp,l_formatmodel) 
							THEN                                          
								l_latestObject.collection_timestamp := l_latestObject.collection_timestamp + 1/24;
							END IF;

							EXECUTE IMMEDIATE ' DELETE FROM '||l_tablename||' WHERE id = :id AND summaryFlag = ''L'' ' USING rec.id;
							EXECUTE IMMEDIATE ' INSERT INTO '||l_tablename||' VALUES(:1)' USING l_latestObject;

						END IF;

                                        EXCEPTION
                                                WHEN OTHERS THEN                                                                                                               
                                                        RAISE_APPLICATION_ERROR(-20101,'Failed to Delete/insert Last object into '||l_tablename||' for '||rec.id);
                                        END;
						
					-----------------------------------------------------------------------
					-- PURGE HISTORY FROM ROLLED UP HISTORY TABLE FOR DATE < CUTOFF 
					-----------------------------------------------------------------------
					BEGIN

						STORAGE_SUMMARY_DB.PRINTSTMT('purging history below the cutoff line');

						EXECUTE IMMEDIATE 'DELETE FROM '||l_tablename||'
						WHERE	id = :1
						AND	collection_timestamp < :2 ' USING rec.id, l_cutofftime;

					EXCEPTION
						WHEN OTHERS THEN
							RAISE_APPLICATION_ERROR(-20101,'Failed to purge old History  from '||l_tablename||' for '||rec.id||' Before '||l_cutofftime);
					END;	


				END IF;


				<<next_table>>	
				STORAGE_SUMMARY_DB.LOG_TIME('rollup',rec.id,rec.name,'Time taken to complete rollup for table '||l_tablename,STORAGE_SUMMARY_DB.GETTIME(l_time));
						
				----------------------------------------------------------------------------------------------
				--	APPLY GROUP CORRECTION AT THIS POINT
				----------------------------------------------------------------------------------------------
				IF rec.type LIKE 'REPORTING%' THEN

					IF l_tablename = 'storage_history_30days' THEN
	
						SELECT	summaryObject (
							NULL,						-- rowcount
							'GROUP TOTAL',					-- name
							rec.id,						-- id
							SYSDATE,					-- timestamp
							a.collection_timestamp,				-- collection_timestamp
							b.host_count,					-- hostcount
							b.actual_targets,				-- actual_targets
							NULL,						-- No of hosts with issues
							NULL,						-- No of hosts with warnings
							'Y',						-- summaryFlag
							NVL(SUM(application_rawsize),0),
							NVL(SUM(application_size),0),
							NVL(SUM(application_used),0),
							NVL(SUM(application_free),0),
							NVL(SUM(oracle_database_rawsize),0),
							NVL(SUM(oracle_database_size),0),
							NVL(SUM(oracle_database_used),0),
							NVL(SUM(oracle_database_free),0),
							NVL(SUM(local_filesystem_rawsize),0),
							NVL(SUM(local_filesystem_size),0),
							NVL(SUM(local_filesystem_used),0),
							NVL(SUM(local_filesystem_free),0),
							NVL(SUM(nfs_exclusive_size),0),
							NVL(SUM(nfs_exclusive_used),0),
							NVL(SUM(nfs_exclusive_free),0),
							0,				-- nfs_shared_size, no group summary
							0,
							0,				-- nfs_shared_free, no group summary
							NVL(SUM(volumemanager_rawsize),0),
							NVL(SUM(volumemanager_size),0),
							NVL(SUM(volumemanager_used),0),
							NVL(SUM(volumemanager_free),0),
							NVL(SUM(swraid_rawsize),0),
							NVL(SUM(swraid_size),0),
							NVL(SUM(swraid_used),0),
							NVL(SUM(swraid_free),0),
							NVL(SUM(disk_backup_rawsize),0),
							NVL(SUM(disk_backup_size),0),
							NVL(SUM(disk_backup_used),0),
							NVL(SUM(disk_backup_free),0),
							NVL(SUM(disk_rawsize),0),
							NVL(SUM(disk_size),0),
							NVL(SUM(disk_used),0),
							NVL(SUM(disk_free),0),
							NVL(SUM(rawsize),0),
							NVL(SUM(sizeb),0),
							NVL(SUM(used),0),
							NVL(SUM(free),0),
							NVL(SUM(vendor_emc_size),0),
							NVL(SUM(vendor_emc_rawsize),0),
							NVL(SUM(vendor_sun_size),0),
							NVL(SUM(vendor_sun_rawsize),0),
							NVL(SUM(vendor_hp_size),0),
							NVL(SUM(vendor_hp_rawsize),0),
							NVL(SUM(vendor_hitachi_size),0),
							NVL(SUM(vendor_hitachi_rawsize),0),
							NVL(SUM(vendor_others_size),0),
							NVL(SUM(vendor_others_rawsize),0),
							NVL(SUM(vendor_nfs_netapp_size),0),
							NVL(SUM(vendor_nfs_emc_size),0),
							NVL(SUM(vendor_nfs_sun_size),0),
							NVL(SUM(vendor_nfs_others_size),0)
						)
						BULK COLLECT INTO l_correctedGroupSummaries
						FROM	storage_history_30days a,
						(
							SELECT	a.collection_timestamp,
								a.host_count,
								a.actual_targets 
							FROM	(
									SELECT	a.collection_timestamp,
										c.host_count		host_count,
										COUNT(*) 		actual_targets,
										MAX(timestamp) 		timestamp
									FROM	storage_history_30days a,
										stormon_host_groups b,
										stormon_group_table c										
									WHERE	a.id = b.target_id
									AND	b.group_id = c.id
									AND	c.id = rec.id
									AND	a.summaryFlag != 'L'									
									GROUP BY
									collection_timestamp,
									c.host_count
							) a,
								(
									SELECT	collection_timestamp,
										actual_targets,
										timestamp
									FROM	storage_history_30days
									WHERE	id = rec.id	
									AND	summaryFlag != 'L'								
							) b
							WHERE	a.collection_timestamp = b.collection_timestamp
							AND	a.actual_targets >= b.actual_targets
						) b,
						TABLE ( CAST ( l_idList AS stringTable ) ) c
						WHERE	a.id  = VALUE(c)
						AND	a.collection_timestamp = b.collection_timestamp
						AND	a.summaryFlag != 'L'
						GROUP BY
							a.collection_timestamp,
							b.host_count,
							b.actual_targets;
				
					ELSE
				
						SELECT	summaryObject (
							NULL,						-- rowcount
							'GROUP TOTAL',					-- name
							rec.id,						-- id
							SYSDATE,					-- timestamp
							a.collection_timestamp,				-- collection_timestamp
							b.host_count,					-- hostcount
							b.actual_targets,				-- actual_targets
							NULL,						-- No of hosts with issues
							NULL,						-- No of hosts with warnings
							'Y',						-- summaryFlag
							NVL(SUM(application_rawsize),0),
							NVL(SUM(application_size),0),
							NVL(SUM(application_used),0),
							NVL(SUM(application_free),0),
							NVL(SUM(oracle_database_rawsize),0),
							NVL(SUM(oracle_database_size),0),
							NVL(SUM(oracle_database_used),0),
							NVL(SUM(oracle_database_free),0),
							NVL(SUM(local_filesystem_rawsize),0),
							NVL(SUM(local_filesystem_size),0),
							NVL(SUM(local_filesystem_used),0),
							NVL(SUM(local_filesystem_free),0),
							NVL(SUM(nfs_exclusive_size),0),
							NVL(SUM(nfs_exclusive_used),0),
							NVL(SUM(nfs_exclusive_free),0),
							0,				-- nfs_shared_size, no group summary
							0,
							0,				-- nfs_shared_free, no group summary
							NVL(SUM(volumemanager_rawsize),0),
							NVL(SUM(volumemanager_size),0),
							NVL(SUM(volumemanager_used),0),
							NVL(SUM(volumemanager_free),0),
							NVL(SUM(swraid_rawsize),0),
							NVL(SUM(swraid_size),0),
							NVL(SUM(swraid_used),0),
							NVL(SUM(swraid_free),0),
							NVL(SUM(disk_backup_rawsize),0),
							NVL(SUM(disk_backup_size),0),
							NVL(SUM(disk_backup_used),0),
							NVL(SUM(disk_backup_free),0),
							NVL(SUM(disk_rawsize),0),
							NVL(SUM(disk_size),0),
							NVL(SUM(disk_used),0),
							NVL(SUM(disk_free),0),
							NVL(SUM(rawsize),0),
							NVL(SUM(sizeb),0),
							NVL(SUM(used),0),
							NVL(SUM(free),0),
							NVL(SUM(vendor_emc_size),0),
							NVL(SUM(vendor_emc_rawsize),0),
							NVL(SUM(vendor_sun_size),0),
							NVL(SUM(vendor_sun_rawsize),0),
							NVL(SUM(vendor_hp_size),0),
							NVL(SUM(vendor_hp_rawsize),0),
							NVL(SUM(vendor_hitachi_size),0),
							NVL(SUM(vendor_hitachi_rawsize),0),
							NVL(SUM(vendor_others_size),0),
							NVL(SUM(vendor_others_rawsize),0),
							NVL(SUM(vendor_nfs_netapp_size),0),
							NVL(SUM(vendor_nfs_emc_size),0),
							NVL(SUM(vendor_nfs_sun_size),0),
							NVL(SUM(vendor_nfs_others_size),0)
						)
						BULK COLLECT INTO l_correctedGroupSummaries
						FROM	storage_history_52weeks a,
				                (
				                        SELECT  a.collection_timestamp,
								a.host_count,
				                                a.actual_targets 
				                        FROM    (
									SELECT	a.collection_timestamp,
										c.host_count		host_count,
										COUNT(*)		actual_targets,
					                                        MAX(a.timestamp)		timestamp
					                                FROM    storage_history_52weeks a,
										stormon_host_groups b,
										stormon_group_table c
					                                WHERE   a.id = b.target_id
					                                AND     b.group_id = c.id
									AND	c.id = rec.id	
									AND	a.summaryFlag != 'L'				                                
					                                GROUP BY
					                                        a.collection_timestamp,
										c.host_count
				                        ) a,
				                        	(
									SELECT  collection_timestamp,
										actual_targets,
										timestamp
					                                FROM    storage_history_52weeks
					                                WHERE   id = rec.id
									AND	summaryFlag != 'L'					                                
				                        ) b
				                        WHERE   a.collection_timestamp = b.collection_timestamp
				                        AND     a.actual_targets >= b.actual_targets
				                ) b,
						TABLE ( CAST ( l_idList AS stringTable ) ) c
						WHERE	a.id  = VALUE(c)
						AND	a.collection_timestamp = b.collection_timestamp
						AND	a.summaryFlag != 'L'
						GROUP BY
							a.collection_timestamp,
							b.host_count,
							b.actual_targets;
					END IF;


					STORAGE_SUMMARY_DB.LOG_TIME('rollup',rec.id,rec.name,'Time taken for fetching corrected group summaries for table '||l_tablename,STORAGE_SUMMARY_DB.GETTIME(l_time));	

					IF l_correctedGroupSummaries IS NOT NULL AND l_correctedGroupSummaries.EXISTS(1) THEN

						-- STORAGE_SUMMARY_DB.LOG('rollup','Group id = '||rec.id||' NO of corrected summaries fetched '||l_correctedGroupSummaries.COUNT);

						FOR i IN l_correctedGroupSummaries.FIRST..l_correctedGroupSummaries.LAST LOOP
			
							STORAGE_SUMMARY_DB.PRINTSTMT(' Group id = '||rec.id||' Inserting the corrected data '||
								l_correctedGroupSummaries(i).collection_timestamp||' '||
								l_correctedGroupSummaries(i).actual_targets||' '||
								l_correctedGroupSummaries(i).sizeb);

							BEGIN
				
								EXECUTE IMMEDIATE ' DELETE FROM '||l_tablename||' WHERE id = :id AND collection_timestamp = :collection_timestamp ' 
								USING	l_correctedGroupSummaries(i).id,
									l_correctedGroupSummaries(i).collection_timestamp;
				
							
							EXCEPTION
								WHEN OTHERS THEN
									RAISE_APPLICATION_ERROR(-20101,' Failed to delete from '||l_tablename||' for corrected summary '||
									l_correctedGroupSummaries(i).id||' for timestamp '||
									l_correctedGroupSummaries(i).collection_timestamp);
							END;


							BEGIN

								EXECUTE IMMEDIATE ' INSERT INTO '||l_tablename||' VALUES (:1) ' USING l_correctedGroupSummaries(i);

							EXCEPTION

								WHEN OTHERS THEN
									RAISE_APPLICATION_ERROR(-20101,' Failed to insert into '||l_tablename||' for corrected summary '||
									l_correctedGroupSummaries(i).id||' for timestamp '||
									l_correctedGroupSummaries(i).collection_timestamp);
						
							END;
				
						END LOOP;
				
					END IF;
					
					STORAGE_SUMMARY_DB.LOG_TIME('rollup',rec.id,rec.name,' Time taken for correcting group summaries in table '||l_tablename,STORAGE_SUMMARY_DB.GETTIME(l_time));		

				END IF; -- End of the group correction

			END LOOP; -- ROLLUP HISTORY TABLE LOOP

			-----------------------------------------------------------------------
			-- PURGE FROM storage_summaryobjet_history ALL ROLLED UP HISTORY DATA 
			-----------------------------------------------------------------------
			BEGIN

				STORAGE_SUMMARY_DB.PRINTSTMT('Deleting  From STORAGE_SUMMARYOBJECT_HISTORY '||rec.id);

				EXECUTE IMMEDIATE 'DELETE FROM storage_summaryobject_history WHERE id = :1 AND collection_timestamp >= :2 AND collection_timestamp <= :3 '
				USING rec.id,rec.min_timestamp,rec.max_timestamp;
	
			EXCEPTION
				WHEN OTHERS THEN
					RAISE_APPLICATION_ERROR(-20101,'Failed to purge rolled up History from storage_summaryoBject_history for '||rec.id||' between '||rec.min_timestamp||' and '||rec.max_timestamp);
			END;

			----------------------------------------------------------------------------
			-- COMMIT CHANGES , AFTER COMPLETING ROLLUP OF ALL HISTORY TABLES FOR A ID
			----------------------------------------------------------------------------
			COMMIT;

		EXCEPTION
			-------------------------------------------------
			-- ROLLBACK AND SKIP TO THE NEXT TARGET
			-------------------------------------------------
			WHEN OTHERS THEN

				ROLLBACK;
	
				l_errmsg := 'Rolling back the history for '||rec.id||' error is '||SUBSTR(SQLERRM,1,2048);

				STORAGE_SUMMARY_DB.LOGERROR('rollup','Id = '||rec.id||' '||l_errmsg);

		END;	-- END OF BLOCK FOR ALL PROCESSING FOR A TARGET

		STORAGE_SUMMARY_DB.LOG_TIME('rollup',rec.id,rec.name,' Time taken to rollup ',STORAGE_SUMMARY_DB.GETTIME(l_elapsedtime));

	END LOOP;  -- TARGET LOOP

	STORAGE_SUMMARY_DB.LOG('rollup','End of execution of rollup job');

END rollup;




-------------------------------------------------------------------------------
-- FUNCTION NAME: compute_group_summary
--
-- DESC 	: 
-- Compute the group summary for a group of hosts and return the id for the group
-- 
-- ARGS	:
--	List of hosts
--	
--
-------------------------------------------------------------------------------
PROCEDURE compute_group_summary(v_groupid stormon_group_table.id%TYPE , v_name VARCHAR2 DEFAULT 'GROUP TOTAL' ) IS

	-----------------------------------------------------
	-- SUMMARY FOR A GROUP OF HOSTS WITH SHARED STORAGE
	-- SIMPLE AGGREGATION - SHARED CORRECTION
	------------------------------------------------------
-- Simple aggregated summary for the group
-- add hosts with no issues
CURSOR c0( c_allIdsWoIssuesList stringTable ) IS
SELECT	summaryObject(
	NULL,					-- rowcount
	NULL,					-- name
	NULL,					-- id
	SYSDATE,				-- timestamp
	MAX(collection_timestamp),              -- collection_timestamp
	NULL,					-- hostcount
	NULL,					-- actual_targets
	NULL,					-- No of hosts with issues
	NULL,					-- No of hosts with warnings
	'Y',					-- summaryFlag
	NVL(SUM(application_rawsize),0),
	NVL(SUM(application_size),0),
	NVL(SUM(application_used),0),
	NVL(SUM(application_free),0),	
	NVL(SUM(oracle_database_rawsize),0),
	NVL(SUM(oracle_database_size),0),
	NVL(SUM(oracle_database_used),0),
	NVL(SUM(oracle_database_free),0),
	NVL(SUM(local_filesystem_rawsize),0),
	NVL(SUM(local_filesystem_size),0),
	NVL(SUM(local_filesystem_used),0),
	NVL(SUM(local_filesystem_free),0),
	NVL(SUM(nfs_exclusive_size),0),
	NVL(SUM(nfs_exclusive_used),0),
	NVL(SUM(nfs_exclusive_free),0),
	0,				-- nfs_shared_size, no group summary
	0,
	0,				-- nfs_shared_free, no group summary
	NVL(SUM(volumemanager_rawsize),0),
	NVL(SUM(volumemanager_size),0),
	NVL(SUM(volumemanager_used),0),
	NVL(SUM(volumemanager_free),0),
	NVL(SUM(swraid_rawsize),0),
	NVL(SUM(swraid_size),0),
	NVL(SUM(swraid_used),0),
	NVL(SUM(swraid_free),0),
	NVL(SUM(disk_backup_rawsize),0),
	NVL(SUM(disk_backup_size),0),
	NVL(SUM(disk_backup_used),0),
	NVL(SUM(disk_backup_free),0),
	NVL(SUM(disk_rawsize),0),
	NVL(SUM(disk_size),0),
	NVL(SUM(disk_used),0),
	NVL(SUM(disk_free),0),
	NVL(SUM(rawsize),0),
	NVL(SUM(sizeb),0),
	NVL(SUM(used),0),
	NVL(SUM(free),0),
	NVL(SUM(vendor_emc_size),0),
	NVL(SUM(vendor_emc_rawsize),0),
	NVL(SUM(vendor_sun_size),0),
	NVL(SUM(vendor_sun_rawsize),0),
	NVL(SUM(vendor_hp_size),0),
	NVL(SUM(vendor_hp_rawsize),0),
	NVL(SUM(vendor_hitachi_size),0),
	NVL(SUM(vendor_hitachi_rawsize),0),
	NVL(SUM(vendor_others_size),0),
	NVL(SUM(vendor_others_rawsize),0),
	NVL(SUM(vendor_nfs_netapp_size),0),
	NVL(SUM(vendor_nfs_emc_size),0),
	NVL(SUM(vendor_nfs_sun_size),0),
	NVL(SUM(vendor_nfs_others_size),0)
	)
	FROM
	storage_summaryObject	,
	TABLE ( CAST( c_allIdsWoIssuesList AS stringTable ) ) b
	WHERE	id = VALUE(b);

l_errmsg		storage_log.message%TYPE;
l_dummy			NUMBER(16);
l_time			INTEGER := 0;
l_summaryObject		SummaryObject;
l_hostIdList		stringTable;
l_hostIdWoIssuesList	stringTable;
l_allIdsWoIssuesList	stringTable;

BEGIN

	-----------------------------------------------------------------------------
	-- 	CLEAN UP OF LOG AND ISSUES SHOULD OCCUR IN THE SUB THAT CALLS THIS
	--	AUTONOMOUS TRANSACTIONS NOT SUPPORTED FOR DISTRIBUTES TRANSACTIONS
	--
	--	CLEAN THE PREVIOUS DEBUG AND ERROR MESSAGES FOR THIS GROUP ID
	-----------------------------------------------------------------------------
	STORAGE_SUMMARY_DB.DELETELOG(v_groupid);

	----------------------------------------------------------------------------------
	-- GET List Of Hosts for this group ID, only targets which are in the master table 
	-- mgmt_targets
	----------------------------------------------------------------------------------
	SELECT	a.target_id
	BULK COLLECT INTO l_hostIdList
	FROM	stormon_host_groups a,
		stormon_group_table b
	WHERE	a.group_id = b.id
	AND	b.id = v_groupid;

--	AND	b.type||'' = 'REPORTING_GROUP'; , Why is this required ??
		
	IF l_hostIdList IS NULL OR NOT l_hostIdList.EXISTS(1) THEN
		RETURN;
	END IF;
	
	STORAGE_SUMMARY_DB.PRINTSTMT('Hosts for group id '||v_groupid||' = '||l_hostIdList.COUNT);

	--------------------------------------------------------
	--	CHECK IF GROUP SUMMARY NEEDS TO BE RECOMPUTED
	--	ONLY IF Group timestamp < any host timestamp
	--------------------------------------------------------		
	BEGIN
		l_time	:= 0;
		l_time  := STORAGE_SUMMARY_DB.GETTIME(l_time);

		SELECT	1
		INTO	l_dummy
		FROM	storage_summaryObject a
		WHERE	a.id = v_groupid
		AND	a.timestamp >= ( 
					SELECT	MAX(b.timestamp)
					FROM	storage_summaryObject b,
						TABLE( CAST( l_hostIdList AS stringTable ) ) c
					WHERE	b.id = VALUE(c)
					);

		STORAGE_SUMMARY_DB.LOG_TIME('compute_group_summary',v_groupid,v_name,'Checking timestamp ',STORAGE_SUMMARY_DB.GETTIME(l_time));

	EXCEPTION

		WHEN NO_DATA_FOUND THEN

			STORAGE_SUMMARY_DB.PRINTSTMT('Summary not found recomputing summary for '||v_groupid||' '||v_name);

			---------------------------------------------------------
			--	LIST OF HOSTS WITH VALID SUMMARIES AND NO ISSUES
			---------------------------------------------------------
			SELECT	DISTINCT a.id
			BULK COLLECT INTO l_hostIdWoIssuesList
			FROM	storage_summaryObject a,
				TABLE( CAST (l_hostIdList AS stringTable ) ) b
			WHERE	a.id = VALUE(b)
			AND	a.summaryFlag = 'Y';

			IF l_hostIdWoIssuesList IS NOT NULL AND l_hostIdWoIssuesList.EXISTS(1) THEN
			-- if there are hosts without issues then compute a summary				
	
				---------------------------------------------------------------------------------------------
				--	LIST OF ALL TARGET AND SHARED IDS WITH SUMMARIES AND NO ISSUES FOR THIS GROUP
				---------------------------------------------------------------------------------------------
				-- This query is to be tested
				SELECT DISTINCT	b.id
				BULK COLLECT INTO l_allIdsWoIssuesList
				FROM	stormon_host_groups a,
					stormon_group_table b
				WHERE	a.group_id = b.id
				AND	b.type = 'SHARED_GROUP'
				AND NOT EXISTS (
					SELECT 	1
					FROM	stormon_host_groups c
					WHERE	c.group_id = b.id
					AND	c.target_id NOT IN
					(
						SELECT	VALUE(d)
						FROM	TABLE( CAST( l_hostIdWoIssuesList AS stringTable ) ) d
					)
				)
				UNION
				SELECT	VALUE(a)
				FROM	TABLE( CAST( l_hostIdWoIssuesList AS stringTable ) ) a;

				--------------------------------------------------------
				-- Fetch group summary for Hosts
				--------------------------------------------------------
				OPEN c0(l_allIdsWoIssuesList);
				FETCH c0 INTO l_summaryObject;
				CLOSE c0;

				STORAGE_SUMMARY_DB.LOG_TIME('compute_group_summary',v_groupid,v_name,'computing group summary',STORAGE_SUMMARY_DB.GETTIME(l_time));


			ELSE
			-- Do not require a summary if there are no hosts to add up, log am empty summary with the max collection_timestamp of the targets
			-- This is debatable, why should a blsnk summary be inserted ?, why not skip summary computation

				STORAGE_SUMMARY_DB.LOG(v_groupid,'No hosts without issues for group '||v_groupid||' '||v_name);

			 	l_summaryObject :=  summaryObject(NULL,NULL,NULL,SYSDATE,NULL,NULL,NULL,NULL,NULL,'Y',
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);

				SELECT	MAX(b.collection_timestamp)
				INTO	l_summaryObject.collection_timestamp
				FROM	storage_summaryObject b,
					TABLE( CAST( l_hostIdList AS stringTable ) ) c
				WHERE	b.id = VALUE(c);
														
			END IF;

			---------------------------------------------------------
			-- Count of all hosts for this group
			---------------------------------------------------------
			l_summaryObject.hostCount := l_hostIdList.COUNT;

			-------------------------------------------------------- 
			-- The actual number of hosts with summaries 
			-------------------------------------------------------- 
			IF l_hostIdWoIssuesList IS NOT NULL AND l_hostIdWoIssuesList.EXISTS(1) THEN
				l_summaryObject.actual_targets := l_hostIdWoIssuesList.COUNT;
			ELSE
				l_summaryObject.actual_targets	:= 0;
			END IF;

			---------------------------------------------------------
			--	COUNT OF HOSTS WITH ISSUES
			---------------------------------------------------------
			BEGIN

				SELECT	COUNT(*)
				INTO	l_summaryObject.issues
				FROM	TABLE( CAST (l_hostIdList AS stringTable ) ) b,
					storage_summaryObject a
				WHERE	a.id = VALUE(b)
				AND	a.summaryFlag = 'I';

			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					l_summaryObject.issues := 0;
			END;

			---------------------------------------------------------
			--	COUNT OF HOSTS WITH WARNINGS
			---------------------------------------------------------
			BEGIN

				SELECT	COUNT(*)
				INTO	l_summaryObject.warnings
				FROM	(
						SELECT	DISTINCT target_id
						FROM	storage_log a,
							TABLE( CAST (l_hostIdList AS stringTable ) ) b
						WHERE	a.target_id = VALUE(b)
						AND	a.type = 'WARNING'
					);

			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					l_summaryObject.warnings := 0;
			END;

			l_summaryObject.id	:= v_groupid;
			l_summaryObject.name	:= v_name;

			---------------------------------------------------------
			--	IF THE COLLECTION_TIMESTAMP IS NULL 
			-- 	THEN SET IT TO SYSDATE - CHECK THIS OUT will it impact the
			--	the rollup job
			---------------------------------------------------------
			IF l_summaryObject.collection_timestamp IS NULL THEN

				l_summaryObject.collection_timestamp := l_summaryObject.timestamp;	
	
			END IF;

			---------------------------------------------------
			--	INSERT GROUP SUMMARY AND COMMIT
			---------------------------------------------------
			STORAGE_SUMMARY_DB.INSERTSUMMARY(l_summaryObject);
			STORAGE_SUMMARY_DB.INSERTSUMMARYHISTORY(l_summaryObject);

	END; -- END OF BLOCK TO COMPUTE SUMMARY FOR THE GROUP ID


END compute_group_summary;



-------------------------------------------------------------------------------
-- FUNCTION NAME: calcfreediskspace
--
-- DESC 	: 
-- Disks and partitions not used by swraid,volumes,filesystems and applications
-- 
-- ARGS	:
--
--	used keys
--
-------------------------------------------------------------------------------
PROCEDURE calcfreediskspace(	v_usedkeys IN stringTable ) IS

-- Free size is the sum of all the unpartitioned disks that are not used by volume manager, 
-- filessystem and applications(Oracle db)

-- Select disks that are not partitioned and not in used
-- Disks ( unformatted or Not sliced ) and no slice in use	
CURSOR c1(c_usedkeys stringTable ) IS 
SELECT	DISTINCT diskkey
FROM	stormon_temp_disk a
WHERE	type = 'DISK'
AND	a.freetype IS NULL 	-- Only consistent free disks
AND	NVL(backup,'N') = 'N'
AND    
	(
	status LIKE '%UNFORMATTED%'
	OR NOT EXISTS 
       		(
		-- Check if disk is partitioned
		SELECT 'x'
		FROM   stormon_temp_disk b
		WHERE  a.diskkey = b.diskkey
		AND    b.type = 'PARTITION'
		)
	)
AND    NOT EXISTS 
       (
		-- Check if the disk or any of its slices or pseudo device is in use
		SELECT 'x'
		FROM	stormon_temp_disk c,
			TABLE(CAST( c_usedkeys AS stringTable)) d
		WHERE	c.diskkey = a.diskkey
		AND	c.keyvalue  = VALUE(d)

	)
GROUP BY diskkey;


-- List of disk keys minus free Disks
CURSOR c2(c_unusedDiskKeyTable stringTable) IS 
SELECT	diskkey
FROM	stormon_temp_disk a
WHERE	freetype IS NULL	-- Only consistent free disks
AND	NVL(backup,'N') = 'N'
MINUS
SELECT VALUE(b)
FROM TABLE( CAST( c_unusedDiskKeyTable AS stringTable ) ) b
;


-- List of disk keys sans disks where whole DISK is in use
-- If backup slice(disk) is used implies all slices are used
CURSOR c3 (	c_usedkeys stringTable,
		c_partitionDiskkeyTable stringTable) IS
SELECT VALUE(a)
FROM   TABLE(CAST( c_partitionDiskkeyTable AS stringTable )) a
-- Only consistent free disks
WHERE	NOT EXISTS
		(
			SELECT 'x'
			FROM	stormon_temp_disk b	
			WHERE	b.diskkey = VALUE(a)
			AND	b.freetype IS NOT NULL
		)
-- Backup slice or whole disk should not be in use
AND  NOT EXISTS	(
			-- Check if backup slice(whole disk) is in use 
			SELECT	'x'
			FROM	stormon_temp_disk b,
				TABLE( CAST( c_usedkeys AS stringTable ) ) c
			WHERE	b.diskkey = VALUE(a)			
			AND 	b.type = 'DISK'
			AND	b.keyvalue = VALUE(c)
		)
;


-- List of free slices not used 
CURSOR   c4(	c_usedkeys stringTable,
		c_freeBackupDiskKeyTable stringTable ) IS
SELECT  DISTINCT b.keyvalue		
FROM     TABLE( CAST( c_freeBackupDiskKeyTable AS stringTable ) ) a,
	 stormon_temp_disk b
WHERE    b.diskkey  = VALUE(a)
AND	 b.freetype IS NULL 	-- Only consistent free disks
AND 	 b.type     = 'PARTITION'
AND 	 NOT EXISTS	(
				-- Check if slice is in use
	 			SELECT 'x'
				FROM	TABLE(CAST( c_usedkeys AS stringTable)) d
				WHERE	VALUE(d) =  b.keyvalue
			);

l_unuseddiskkeyTable		stringTable;
l_partitionDiskKeyTable 	stringTable;
l_freeBackupDiskKeyTable	stringTable;
l_unusedSliceKeyvalueTable	stringTable;
l_rownumList			numberTable;
l_dummy				NUMBER(16) := 0;

BEGIN

	STORAGE_SUMMARY_DB.PRINTSTMT('In CalcfreeDiskspace ');

	BEGIN
	
		SELECT	1
		INTO	l_dummy
		FROM	stormon_temp_disk
		WHERE	ROWNUM = 1;

	EXCEPTION	
		WHEN NO_DATA_FOUND THEN	
			RETURN;	
	END;
	
------------------------------------
-- BACKUP DISKS
------------------------------------

	---------------------------------------------------
	-- MARK ALL BACKUP DISKS AS FREETYPE = BACKUP_SLICE
	-- AND freeb = 0
	---------------------------------------------------
	-- List of rownums with backup disks	
	UPDATE	stormon_temp_disk
	SET	freeb = 0 
	WHERE	NVL(backup,'N') = 'Y';	

	STORAGE_SUMMARY_DB.PRINTSTMT('Marked free size for backup disks');
------------------------------------
-- NON BACKUP DISKS
------------------------------------

	----------------------------------------------------------
	-- THIS PROCESSING IS FOR NON BACKUP DISKS ONLY,
	-- BACKUP DISKS AND SLICES ARE TAKEN TO BE USED COMPLETELY
	----------------------------------------------------------

	-- List of free disks and their size
	OPEN  c1(v_usedkeys);
	FETCH c1 BULK COLLECT INTO l_unusedDiskkeyTable;
	CLOSE c1;
	
	-- List of disks sans the unused disks
	OPEN c2(l_unusedDiskKeyTable);
	FETCH c2 BULK COLLECT INTO l_partitionDiskKeyTable;
	CLOSE c2;

	-- List of sliced disks with back slice not in use
	OPEN  c3(v_usedkeys,l_partitionDiskkeyTable);
	FETCH c3 BULK COLLECT INTO l_freeBackupDiskKeyTable;
	CLOSE c3;	

	-- List of unused slices
	OPEN  c4(v_usedkeys,l_freeBackupDiskkeyTable);
	FETCH c4 BULK COLLECT INTO l_unusedSliceKeyvalueTable;
	CLOSE c4;	

	STORAGE_SUMMARY_DB.PRINTSTMT('Analyzed the free disks and slices');
	----------------------------------------
	-- WHOLE DISK IS NOT SLICED AND FREE
	----------------------------------------
	-- List of rownums with unused disks
	UPDATE	stormon_temp_disk a
	SET	freeb = sizeb,
		freetype = 'Free Disk'	
	WHERE	a.diskkey IN (
				SELECT	VALUE(b)		
				FROM	TABLE ( CAST ( l_unusedDiskKeyTable AS stringTable ) ) b
		)
	AND	a.type = 'DISK';
	
	STORAGE_SUMMARY_DB.PRINTSTMT('Marked free disks');

	------------------------------------------
	--  FREE SPACE IN THE BACKUP SLICE
	------------------------------------------
	-- Its a unused disk slice from a partitioned disk
	-- Update the free disks in storageDiskTable
	UPDATE	stormon_temp_disk a
	SET	freeb = (	
				SELECT	a.sizeb - SUM(AVG(b.sizeb)) 	-- Disk size - sum of all slices ( the avg gives the average across the different keyvalue record for a alice, block , char etc
				FROM	stormon_temp_disk b
				WHERE	b.diskkey =  a.diskkey
				AND	b.type	= 'PARTITION'
				GROUP BY	
					b.keyvalue							
			),
		freetype = 'Free Space on Disk'
	WHERE	a.type = 'DISK'
	AND 	a.diskkey IN (
				SELECT	VALUE(b)		
				FROM	TABLE ( CAST ( l_freeBackupDiskKeyTable AS stringTable ) ) b
		);

	STORAGE_SUMMARY_DB.PRINTSTMT('Marked free partitions');
	----------------------------------------------
	-- FREE DISK SLICES
	----------------------------------------------
	-- Its a unused disk slice from a partitioned disk
	-- Update the free disks in storageDiskTable
	UPDATE	stormon_temp_disk a
	SET	freeb = sizeb,
		freetype = 'Free Partition'
	WHERE	a.type = 'PARTITION'
	AND	a.keyvalue IN ( 
				SELECT	VALUE(b)		
				FROM	TABLE ( CAST ( l_unusedSliceKeyvalueTable AS stringTable ) ) b				
	);
	
	-------------------------------------------------------------
	-- Update the rawsize and usedb for all disks and slices
	-------------------------------------------------------------	
	UPDATE	stormon_temp_disk
	SET	rawsizeb = STORAGE_SUMMARY.GETTOTALSTORAGE(storagevendor,storageproduct,storageconfig,sizeb),
		usedb	 = sizeb - freeb;

	STORAGE_SUMMARY_DB.PRINTSTMT('End Calcfreediskspace');
							
END calcfreediskspace;



-------------------------------------------------------------------------------
-- FUNCTION NAME: calcswraiddiskfreespace
--
-- DESC 	: 
-- Software Raid Disks not used by volumes , filesystems and applications
-- 
-- ARGS	:
--	
--	List of keys used by vm, filesystems, apps (stringTable)
------------------------------------------------------------------------------
PROCEDURE calcswraiddiskfreespace( v_usedkeys IN stringTable ) IS

-- Free size is the sum of all the unpartitioned disks that are not used by volume manager, 
-- filessystem and applications(Oracle db)

-- Select disks that are not partitioned and not in used
-- Disks ( unformatted or Not sliced ) and no slice in use	
CURSOR c1(c_usedkeys stringTable ) IS 
SELECT	DISTINCT diskkey
FROM	stormon_temp_swraid a
WHERE	type = 'DISK'
AND	a.freetype IS NULL 	-- Only consistent free disks
AND	NVL(backup,'N') = 'N'
AND    
	(
	status LIKE '%UNFORMATTED%'
	OR NOT EXISTS 
       		(
		-- Check if disk is partitioned
		SELECT 'x'
		FROM   stormon_temp_swraid b
		WHERE  a.diskkey = b.diskkey
		AND    b.type = 'PARTITION'
		)
	)
AND    NOT EXISTS 
       (
		-- Check if the disk or any of its slices or pseudo device is in use
		SELECT 'x'
		FROM	stormon_temp_swraid c,
			TABLE(CAST( c_usedkeys AS stringTable)) d
		WHERE	c.diskkey = a.diskkey
		AND	c.keyvalue  = VALUE(d)

	)
GROUP BY diskkey;


-- List of disk keys minus free Disks
CURSOR c2(c_unusedDiskKeyTable stringTable) IS 
SELECT	diskkey
FROM	stormon_temp_swraid a
WHERE	freetype IS NULL	-- Only consistent free disks
AND	NVL(backup,'N') = 'N'
MINUS
SELECT VALUE(b)
FROM TABLE( CAST( c_unusedDiskKeyTable AS stringTable ) ) b
;


-- List of disk keys sans disks where whole DISK is in use
-- If backup slice(disk) is used implies all slices are used
CURSOR c3 (	c_usedkeys stringTable,
		c_partitionDiskkeyTable stringTable) IS
SELECT VALUE(a)
FROM   TABLE(CAST( c_partitionDiskkeyTable AS stringTable )) a
-- Only consistent free disks
WHERE	NOT EXISTS
		(
			SELECT 'x'
			FROM	stormon_temp_swraid b	
			WHERE	b.diskkey = VALUE(a)
			AND	b.freetype IS NOT NULL
		)
-- Backup slice or whole disk should not be in use
AND  NOT EXISTS	(
			-- Check if backup slice(whole disk) is in use 
			SELECT	'x'
			FROM	stormon_temp_swraid b,
				TABLE( CAST( c_usedkeys AS stringTable ) ) c
			WHERE	b.diskkey = VALUE(a)			
			AND 	b.type = 'DISK'
			AND	b.keyvalue = VALUE(c)
		)
;


-- List of free slices not used 
CURSOR   c4(	c_usedkeys stringTable,
		c_freeBackupDiskKeyTable stringTable ) IS
SELECT  DISTINCT b.keyvalue		
FROM     TABLE( CAST( c_freeBackupDiskKeyTable AS stringTable ) ) a,
	 stormon_temp_swraid b
WHERE    b.diskkey  = VALUE(a)
AND	 b.freetype IS NULL 	-- Only consistent free disks
AND 	 b.type     = 'PARTITION'
AND 	 NOT EXISTS	(
				-- Check if slice is in use
	 			SELECT 'x'
				FROM	TABLE(CAST( c_usedkeys AS stringTable)) d
				WHERE	VALUE(d) =  b.keyvalue
			);

l_unuseddiskkeyTable		stringTable;
l_partitionDiskKeyTable 	stringTable;
l_freeBackupDiskKeyTable	stringTable;
l_unusedSliceKeyvalueTable	stringTable;
l_rownumList			numberTable;
l_dummy				NUMBER(16) := 0;

BEGIN

	STORAGE_SUMMARY_DB.PRINTSTMT('In calcswraiddiskfreespace ');

	BEGIN
	
		SELECT	1
		INTO	l_dummy
		FROM	stormon_temp_swraid
		WHERE	ROWNUM = 1;

	EXCEPTION	
		WHEN NO_DATA_FOUND THEN	
			RETURN;	
	END;
	
------------------------------------
-- BACKUP DISKS
------------------------------------

	---------------------------------------------------
	-- MARK ALL BACKUP DISKS AS FREETYPE = BACKUP_SLICE
	-- AND freeb = 0
	---------------------------------------------------
	-- List of rownums with backup disks	
	UPDATE	stormon_temp_swraid
	SET	freeb = 0 
	WHERE	NVL(backup,'N') = 'Y';	

	STORAGE_SUMMARY_DB.PRINTSTMT('Marked free size for backup disks');
------------------------------------
-- NON BACKUP DISKS
------------------------------------

	----------------------------------------------------------
	-- THIS PROCESSING IS FOR NON BACKUP DISKS ONLY,
	-- BACKUP DISKS AND SLICES ARE TAKEN TO BE USED COMPLETELY
	----------------------------------------------------------

	-- List of free disks and their size
	OPEN  c1(v_usedkeys);
	FETCH c1 BULK COLLECT INTO l_unusedDiskkeyTable;
	CLOSE c1;
	
	-- List of disks sans the unused disks
	OPEN c2(l_unusedDiskKeyTable);
	FETCH c2 BULK COLLECT INTO l_partitionDiskKeyTable;
	CLOSE c2;

	-- List of sliced disks with back slice not in use
	OPEN  c3(v_usedkeys,l_partitionDiskkeyTable);
	FETCH c3 BULK COLLECT INTO l_freeBackupDiskKeyTable;
	CLOSE c3;	

	-- List of unused slices
	OPEN  c4(v_usedkeys,l_freeBackupDiskkeyTable);
	FETCH c4 BULK COLLECT INTO l_unusedSliceKeyvalueTable;
	CLOSE c4;	

	STORAGE_SUMMARY_DB.PRINTSTMT('Analyzed the free disks and slices');
	----------------------------------------
	-- WHOLE DISK IS NOT SLICED AND FREE
	----------------------------------------
	-- List of rownums with unused disks
	UPDATE	stormon_temp_swraid a
	SET	freeb = sizeb,
		freetype = 'Free Disk'	
	WHERE	a.diskkey IN (
				SELECT	VALUE(b)		
				FROM	TABLE ( CAST ( l_unusedDiskKeyTable AS stringTable ) ) b
		)
	AND	a.type = 'DISK';
	
	STORAGE_SUMMARY_DB.PRINTSTMT('Marked free disks');

	------------------------------------------
	--  FREE SPACE IN THE BACKUP SLICE
	------------------------------------------
	-- Its a unused disk slice from a partitioned disk
	-- Update the free disks in storageDiskTable
	UPDATE	stormon_temp_swraid a
	SET	freeb = (	
				SELECT	a.sizeb - SUM(AVG(b.sizeb)) -- Disk size - sum of all slices ( the avg gives the average across the different keyvalue record for a alice, block , char etc
				FROM	stormon_temp_swraid b
				WHERE	b.diskkey =  a.diskkey
				AND	b.type	= 'PARTITION'
				GROUP BY	
				b.keyvalue								
			),
		freetype = 'Free Space on Disk'
	WHERE	a.type = 'DISK'
	AND 	a.diskkey IN (
				SELECT	VALUE(b)		
				FROM	TABLE ( CAST ( l_freeBackupDiskKeyTable AS stringTable ) ) b
		);

	STORAGE_SUMMARY_DB.PRINTSTMT('Marked free partitions');
	----------------------------------------------
	-- FREE DISK SLICES
	----------------------------------------------
	-- Its a unused disk slice from a partitioned disk
	-- Update the free disks in storageDiskTable
	UPDATE	stormon_temp_swraid a
	SET	freeb = sizeb,
		freetype = 'Free Partition'
	WHERE	a.type = 'PARTITION'
	AND	a.keyvalue IN ( 
				SELECT	VALUE(b)		
				FROM	TABLE ( CAST ( l_unusedSliceKeyvalueTable AS stringTable ) ) b				
	);
	
	-------------------------------------------------------------
	-- Update the usedb for all disks and slices
	-------------------------------------------------------------	
	UPDATE	stormon_temp_swraid
	SET	usedb	 = sizeb - freeb;

	-----------------------------------------------------------------------
	-- Update the rawsize for the raid disk as sum of all the subdisks
	-----------------------------------------------------------------------
	UPDATE	stormon_temp_swraid a
	SET	rawsizeb = sizeb;

	-- Get the raw size as the sum of all subdisks	
	--	SELECT	NVL(SUM(a.sizeb),0)
	--	INTO	l_dummy
	--	FROM	TABLE( CAST (v_swraidTable AS storageDiskTable )) a
	--	WHERE	a.type = 'SUBDISK'				
	--	AND	a.parent = v_swraidTable(l_rownumList(i)).slicekey;

	--	v_swraidTable(l_rownumList(i)).rawsizeb := l_dummy;
	
	-- If subdisk is of type spare mark it as free with freeb = sizeb

	STORAGE_SUMMARY_DB.PRINTSTMT('End calcswraiddiskfreespace');
							
END calcswraiddiskfreespace;

-------------------------------------------------------------------------------
-- FUNCTION NAME: calstoragesummary
--
-- DESC 	: 
-- Calculate the storage summary for a node for a set of collected metrics
-- Insert the summary into the history and current reporting tables
-- Storage the detail object for the host in the host detail reporting table
--
-- ARGS	:
--	target_name
--
-- FLOW :
--	1. Delete Log ( Independent txn)
--	2. Fetch Collections
--	Begin
--	3. Consistency Check
--	4. Delete previous summary details
--	5. Calculate Summary
--	5.1 Insert Details
--	Exception Catch
--	6. Delete previous summary /Insert new summary
--	7. Delete shared summaries
--	8. If Host with Issues Go to 10. Calculate GroupSummary
--	9. Insert Shared summaries for all shared combinations
--	10. Calculate Group Summries
--	11. Insert Group summary
--	12. COMMIT the main transaction
--	13. Rollup History
--	14. Insert History
--	12  Commit History
-------------------------------------------------------------------------------
PROCEDURE calcstoragesummary
			( 
				v_targetname	mgmt_targets_view.target_name%TYPE,
				v_targetid	mgmt_targets_view.target_id%TYPE
			) IS

l_usedkeys			stringTable;
l_diskkeyList			stringTable;
l_failedpartitions		stringTable;

l_hosttable			stringTable;

l_maxMetricTimestamp		DATE:=NULL;
l_minMetricTimestamp		DATE:=NULL;
l_filesystemTimestamp		DATE:=NULL;
l_volumeTimestamp		DATE:=NULL;
l_swraidTimestamp		DATE:=NULL;
l_disktimestamp			DATE:=NULL;
l_lastTimestamp			DATE:=NULL;

l_errMsg			storage_log.message%TYPE;
l_time				INTEGER := 0;
l_elapsedtime			INTEGER := 0;

l_rownumList			numberTable;  		-- List of rowids of a collection
l_dummy				NUMBER(16);
l_count				NUMBER(16);
l_keyvalue			VARCHAR2(1024);

l_summary			summaryObject := NULL; 
l_lastSummary			summaryObject := NULL; 

l_sharedDiskKeys		stringTable;

l_hostList			stringTable;
l_combination			stringTable;
l_combinationTable		tableStringTable;

l_combSummary			summaryObject;

l_groupIdlist			stringTable; 	-- Hold group Id's from stormon_host_groups

-- Constants
c_max_shared_hosts		CONSTANT INTEGER := 15; 	-- Do not compute shared summaries if more than 15 hosts share storage, way too many combinations
c_metric_time_range		CONSTANT NUMBER := 1.5;		-- 1 day, all metrics to be within a 24 hour (1 day) range 

BEGIN

	-- Fetch the timestamp in secs 
	l_time	:= 0;
	l_elapsedtime := 0;
	l_elapsedtime := STORAGE_SUMMARY_DB.GETTIME(l_time);

	------------------------------------------------------
	-- DELETE log for this target
	-- THESE ARE AUTONOMOUS TRANSACTIONS
	------------------------------------------------------
	STORAGE_SUMMARY_DB.DELETELOG(v_targetid);

	STORAGE_SUMMARY_DB.LOG(v_targetid,'******** Summarizing Target '||v_targetname||' *********');

	-------------------------------------------------------------------------
	-- Update the stormon_load_status table
	--
	-- This is independent of the main transaction
	-- This transaction is either commited or rolled back 
	-- at this level
	--------------------------------------------------------------------------
	BEGIN

		-- delete the previous load status rows
		DELETE FROM stormon_load_status WHERE node_id = v_targetid;

		-- Insert the load status for the host metrics
		INSERT INTO stormon_load_status(
		node_id,	-- Target_id of the host the target is on
		target_name,	-- Target name of the target with the collection
		target_type,	-- Target type of the target with the collection
		timestamp,	-- Timestamp of insertion
		max_collection_timestamp,	
		min_collection_timestamp
		)		
		SELECT	a.target_guid,
			b.target_name,
			b.target_type,
			SYSTIMESTAMP,
			TO_TIMESTAMP_TZ( TO_CHAR(MIN(collection_timestamp),'DD-MON-YYYY HH24:MI:SS ')||SIGN(b.tz)*FLOOR((ABS(b.tz)*60)/60)||':'||MOD((ABS(b.tz)*60),60) ,' DD-MON-YYYY HH24:MI:SS TZH:TZM' ),
			TO_TIMESTAMP_TZ( TO_CHAR(MAX(collection_timestamp),'DD-MON-YYYY HH24:MI:SS ')||SIGN(b.tz)*FLOOR((ABS(b.tz)*60)/60)||':'||MOD((ABS(b.tz)*60),60) ,' DD-MON-YYYY HH24:MI:SS TZH:TZM' ) 
		FROM	mgmt_current_metrics a,
			mgmt_targets_view b,
			mgmt_metrics c
		WHERE	a.target_guid = b.target_id
		AND	a.metric_guid = c.metric_guid
		AND	c.metric_name IN ('disk_devices','storage_filesystems','storage_summary','storage_swraid','storage_volume_layers')
		AND	b.target_id = v_targetid
		GROUP BY
			a.target_guid,
			b.target_name,
			b.target_type,
			b.tz;

		-- Insert the load status for the database metrics
		INSERT INTO stormon_load_status(
		node_id,	-- Target_id of the host the target is on
		target_name,	-- Target name of the target with the collection
		target_type,	-- Target type of the target with the collection
		timestamp,	-- Timestamp of insertion
		max_collection_timestamp,	
		min_collection_timestamp
		)		
		SELECT	a.target_guid,
			a.string_value,
			p_target_type_database,
			SYSTIMESTAMP,
			TO_TIMESTAMP_TZ( TO_CHAR(MIN(collection_timestamp),'DD-MON-YYYY HH24:MI:SS ')||SIGN(b.tz)*FLOOR((ABS(b.tz)*60)/60)||':'||MOD((ABS(b.tz)*60),60) ,' DD-MON-YYYY HH24:MI:SS TZH:TZM' ),
			TO_TIMESTAMP_TZ( TO_CHAR(MAX(collection_timestamp),'DD-MON-YYYY HH24:MI:SS ')||SIGN(b.tz)*FLOOR((ABS(b.tz)*60)/60)||':'||MOD((ABS(b.tz)*60),60) ,' DD-MON-YYYY HH24:MI:SS TZH:TZM' )
		FROM	mgmt_current_metrics a,
			mgmt_targets_view b,
			mgmt_metrics c	
		WHERE	a.target_guid = b.target_id
		AND	a.metric_guid = c.metric_guid
		AND	c.metric_column IN ('storage_applications_oem_target_name')
		AND	b.target_id = v_targetid
		GROUP BY
			a.target_guid,
			string_value,
			b.tz;

		COMMIT;

	EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK; 
			RAISE_APPLICATION_ERROR(-20103,'Failed during updating load status in stormon_load_status for  '||v_targetname,TRUE);
	END;

	STORAGE_SUMMARY_DB.LOG_TIME('calcstoragesummary',v_targetid,v_targetname,' Time to update the stormon_load_status table ',STORAGE_SUMMARY_DB.GETTIME(l_time));

	------------------------------------------------------------
	-- THESE ARE IN THE MAIN TRANSACTION
	-- DELETE the previous issues and warning for this target
	------------------------------------------------------------
	STORAGE_SUMMARY_DB.DELETEISSUES(v_targetid);

	--------------------------------------------------
	-- THESE ARE IN THE MAIN TRANSACTION
	-- DELETE the storage details 
	--------------------------------------------------
	BEGIN

		DELETE FROM storage_application_table WHERE target_id = v_targetid;
		DELETE FROM storage_localfs_table WHERE target_id = v_targetid;
		DELETE FROM storage_nfs_table WHERE target_id = v_targetid;
		DELETE FROM storage_volume_table WHERE target_id = v_targetid;
		DELETE FROM storage_swraid_table WHERE target_id = v_targetid;
		DELETE FROM storage_disk_table WHERE target_id = v_targetid;

	EXCEPTION
		WHEN OTHERS THEN
			RAISE_APPLICATION_ERROR(-20103,'Failed during deletion of the storage details for '||v_targetname,TRUE);
	END;

	STORAGE_SUMMARY_DB.LOG_TIME('calcstoragesummary',v_targetid,v_targetname,' Time to delete the previous details ',STORAGE_SUMMARY_DB.GETTIME(l_time));

	-----------------------------------------------------------------------------
	--	Fetch the last summaryObject if one exists	
	-----------------------------------------------------------------------------
	STORAGE_SUMMARY_DB.PRINTSTMT(' Fetching the last summaryObject');
	BEGIN
		SELECT	VALUE(a)	
		INTO	l_lastSummary
		FROM	storage_summaryobject a
		WHERE	a.id = TO_CHAR(v_targetid);

		l_lastTimestamp := l_lastSummary.collection_timestamp;

	EXCEPTION
		WHEN NO_DATA_FOUND THEN
		 	l_lastTimestamp := NULL;
		WHEN OTHERS THEN
			RAISE_APPLICATION_ERROR(-20103,' Failed fetching the last summary for '||v_targetname,TRUE);
	END;


	----------------------------------------------------------------------------------------
	-- Exceptions in this block will result in the creation of a placeholder summaryObject
	-- with an issue or warning
	----------------------------------------------------------------------------------------
	BEGIN
	
		--------------------------------------------------------
		--	FETCH THE COLLECTONS FOR EACH LEVEL
		--------------------------------------------------------
		BEGIN
		
			DELETE FROM stormon_temp_disk;
			DELETE FROM stormon_temp_swraid;
			DELETE FROM stormon_temp_volume;
			DELETE FROM stormon_temp_filesystem;
			DELETE FROM stormon_temp_app;

			-- List of hosts which are monitored as targets
			l_hosttable 		:= STORAGE_SUMMARY_DB.GETHOSTLIST;
			-- Collection Table of Applications data for a target
		 	 STORAGE_SUMMARY_DB.GETSTORAGEAPPCOLLECTION(v_targetid,v_targetname);	
			-- Collection Table of Filesystem data for a target
		 	STORAGE_SUMMARY_DB.GETSTORAGEFILESYSTEMCOLLECTION(v_targetid,v_targetname);
			-- Collection Table of Volume manager data for a target
			STORAGE_SUMMARY_DB.GETSTORAGEVOLUMECOLLECTION(v_targetid,v_targetname);
			-- Collection Table of swraid data for a target
		 	STORAGE_SUMMARY_DB.GETSTORAGESWRAIDCOLLECTION(v_targetid,v_targetname);
			-- Collection Table of disk device data for a target
		 	STORAGE_SUMMARY_DB.GETSTORAGEDISKCOLLECTION(v_targetid,v_targetname);
		
		EXCEPTION
			WHEN OTHERS THEN
				RAISE_APPLICATION_ERROR(-20101,'Failed fetching the collected storage metrics ',TRUE);
		END;
			
		STORAGE_SUMMARY_DB.LOG_TIME('calcstoragesummary',v_targetid,v_targetname,' Time to fetch collections ',STORAGE_SUMMARY_DB.GETTIME(l_time));
		STORAGE_SUMMARY_DB.PRINTSTMT(' Fetched the collections');

		----------------------------------------------------------
		--		CLEANUP COLLECTIONS
		----------------------------------------------------------
		--		TBD

		----------------------------------------------------------
		--		VALIDATE COLLECTIONS
		----------------------------------------------------------

		----------------------------------------------------------
		--	SKIP IF ALL COLLECTIONS ARE NULL TBDT
		----------------------------------------------------------
		-- Compute summary if 
		-- Metrcs collected are valid and consistent and 
		-- if summary not alreay computed for this data set
	
		-- Check for NULL data before proceeding
		-- If all of these are NULL skip computing summary for this data set
		BEGIN	

			SELECT	1		
			INTO	l_dummy
			FROM	
			(
				SELECT	1			
				FROM	stormon_temp_app	
				WHERE	ROWNUM = 1	
				UNION	
				SELECT	1
				FROM	stormon_temp_filesystem
				WHERE	ROWNUM = 1
				UNION
				SELECT	1
				FROM	stormon_temp_volume
				WHERE	ROWNUM = 1
				UNION
				SELECT	1
				FROM	stormon_temp_swraid
				WHERE	ROWNUM = 1
				UNION
				SELECT	1
				FROM	stormon_temp_disk
				WHERE	ROWNUM = 1
			)
			WHERE	ROWNUM = 1;

		EXCEPTION
			WHEN NO_DATA_FOUND THEN
				RAISE_APPLICATION_ERROR(-20102,'Storage metrics not collected ', TRUE);
		END   ;
	
		----------------------------------------------------------
		--	SKIP IF FILESYSTEM OR DISK METRICS ARE NULL
		----------------------------------------------------------
		DECLARE
			l_dummy		INTEGER;
		BEGIN

			SELECT	1
			INTO	l_dummy
			FROM	stormon_temp_filesystem
			WHERE	ROWNUM = 1;
		
		EXCEPTION
			WHEN NO_DATA_FOUND THEN	
				RAISE_APPLICATION_ERROR(-20101,'No Filesystem metrics ', TRUE);			
			WHEN OTHERS THEN
				RAISE;
		END;

		DECLARE
			l_dummy		INTEGER;
		BEGIN

			SELECT	1
			INTO	l_dummy
			FROM	stormon_temp_disk
			WHERE	ROWNUM = 1;
		
		EXCEPTION
			WHEN NO_DATA_FOUND THEN	
				RAISE_APPLICATION_ERROR(-20101,'No Disk metrics ', TRUE);		
			WHEN OTHERS THEN
				RAISE;
		END;


		--------------------------------------------------------------------------------------
		--	CLEAN UP THE DATABASE METRICS FOR DATABASE JOBS THAT HAVE BEEN TERMINATED
		--	DELETE METRICS FOR DATABASES NOT BEING COLLECTED
		--	AND WITH  COLLECTION TIMESTAMPS < c_metric_time_range DAYS
		--	OF THE MAX TIMESTAMP OF OTHER METRICS
		--------------------------------------------------------------------------------------
		DECLARE
			
			l_list_of_db_to_del 	stringTable;

		BEGIN	

			SELECT	oem_target_name
			BULK COLLECT INTO l_list_of_db_to_del
			FROM	(
					SELECT	target_id,
						oem_target_name,
						MAX(collection_timestamp) collection_timestamp
					FROM	stormon_temp_app 
					GROUP BY
						target_id,
						oem_target_name	
						
				) a
			-- The database target does not have a job scheduled				
			WHERE	NOT EXISTS
			(				
				SELECT	1						
				FROM	stormon_active_targets_view b
				WHERE	b.target_type = p_target_type_database
				AND	b.node_id = a.target_id
				AND	b.target_name = a.oem_target_name
			)
			-- Collection timestamp of the database should be less than c_metric_time_range from the other host metrics
			-- Collection timestamp is in the timezone of the target
			AND	a.collection_timestamp < 
			(
				SELECT	MAX(b.collection_timestamp) -  c_metric_time_range
				FROM	
				(
					SELECT	collection_timestamp collection_timestamp 
					FROM	stormon_temp_filesystem
					UNION
					SELECT	collection_timestamp collection_timestamp
					FROM	stormon_temp_volume
					UNION
					SELECT  collection_timestamp collection_timestamp
					FROM	stormon_temp_swraid
					UNION
					SELECT	collection_timestamp collection_timestamp
					FROM	stormon_temp_disk
				) b
			); 
		
			-- Delete metrics for those dbs from collection
			IF l_list_of_db_to_del IS NOT NULL AND l_list_of_db_to_del.EXISTS(1) THEN

				FOR i IN l_list_of_db_to_del.FIRST..l_list_of_db_to_del.LAST LOOP

					STORAGE_SUMMARY_DB.LOGWARNING(v_targetid, 'Stale database metrics , ignoring metrics for database '||l_list_of_db_to_del(i));
					
				END LOOP;
	
				DELETE FROM stormon_temp_app a
				WHERE 	oem_target_name IN
				(
					SELECT	VALUE(b)
					FROM	TABLE ( CAST ( l_list_of_db_to_del AS stringTable ) ) b		
				);
			
			END IF;

		END;
	
		-----------------------------------------------------------
		--	FETCH THE MAX AND MIN TIMESTAMP FROM THE METRICS
		-----------------------------------------------------------
		STORAGE_SUMMARY_DB.PRINTSTMT('Check for consistency of timestamps');

		SELECT	MAX(a.collection_timestamp),
			MIN(a.collection_timestamp)
		INTO	l_maxMetricTimestamp,
			l_minMetricTimestamp
		FROM	
			(
				SELECT	collection_timestamp collection_timestamp 
				FROM	stormon_temp_app
				UNION
				SELECT	collection_timestamp collection_timestamp 
				FROM	stormon_temp_filesystem
				UNION
				SELECT	collection_timestamp collection_timestamp
				FROM	stormon_temp_volume
				UNION
				SELECT  collection_timestamp collection_timestamp
				FROM	stormon_temp_swraid
				UNION
				SELECT	collection_timestamp collection_timestamp
				FROM	stormon_temp_disk
			) a;


		--------------------------------------------------------------
		--	CHECK IF ANY METRIC TIMESTAMP EXISTS 
		--------------------------------------------------------------
		-- If the fetched timestamp is null, no data exists for the filesystem metric
		-- Skip computing the summary for the target

		IF ( l_minMetricTimestamp IS NULL )
		THEN

			RAISE_APPLICATION_ERROR(-20101,'Invalid metrics, all metrics have a NULL timestamp ',TRUE);

		END IF;
	
		--------------------------------------------------------------
		--	IS SUMMARY ALREADY COMPUTED FOR THIS SET OF METRICS
		--------------------------------------------------------------
		-- If timestamp of the last computed summary is >= the maximum timestamp 
		-- Ipplies summary already computed for this data set 
		
		IF ( l_lastTimestamp IS NOT NULL AND l_lastTimestamp >= l_maxMetricTimestamp )
		THEN
			
			RAISE_APPLICATION_ERROR(-20101,'No new storage metrics collected ', TRUE);
				
		END IF;
	
		--------------------------------------------------------------
		--   CHECK IF ALL METRIC TIMESTAMPS ARE IN 24 HOUR WINDOW
		--------------------------------------------------------------

		IF ( l_maxMetricTimestamp - l_minMetricTimeStamp )  > c_metric_time_range  
		THEN

			RAISE_APPLICATION_ERROR(-20101,'Inconsistent timestamps for the collected metrics , they range between '||TO_CHAR(l_minMetricTimeStamp,'DD-MON-YY HH24:MI')||' and '||TO_CHAR(l_maxMetricTimestamp,'DD-MON-YY HH24:MI'),TRUE);

		END IF;


		-----------------------------------------------------------
		--	CHECK FOR TIMESTAMP CONSISTENCY
		-----------------------------------------------------------
		-- Use the max timestamp from the filesystem metric as the 
		-- collectiontimestamp for the summary for the targetid
		
		-- Do a consistency check for all metric data here wrt collection timestamp
		-- Metrics should be fetched in top down order , FS,VOLUME,SWRAID,DISKS
		-- Apps are fetched independently of the host metrics so cant be compared
		-- Assumed this discipline is maintained during scheduling the collection
	
		SELECT MIN(a.collection_timestamp)
		INTO	l_disktimestamp
		FROM	stormon_temp_disk a;
	
		SELECT MIN(a.collection_timestamp)
		INTO	l_volumetimestamp
		FROM	stormon_temp_volume a;
	
		SELECT MIN(a.collection_timestamp)
		INTO	l_swraidtimestamp
		FROM	stormon_temp_swraid a;
	
		SELECT MIN(a.collection_timestamp)
		INTO	l_filesystemtimestamp
		FROM	stormon_temp_filesystem a;
	
		-- l_disktimestamp >= l_swraidtimestamp >= l_volumetimestamp >= l_filesystemtimestamp
		IF 
			( l_disktimestamp < NVL(NVL(l_swraidtimestamp,l_volumetimestamp),l_filesystemtimestamp) ) OR
			( NVL(l_swraidtimestamp,l_disktimestamp) < NVL(l_volumetimestamp,l_filesystemtimestamp) ) OR
			( NVL(NVL(l_volumetimestamp,l_swraidtimestamp),l_disktimestamp) < l_filesystemtimestamp )
		THEN
			RAISE_APPLICATION_ERROR(-20101,'The timestamps for the collected metrics are not in order for, One of the metrics may have failed loading ',TRUE);
		END IF;
	
		
		---------------------------------------------------------
		-- CHECK FOR NULL INODES
		---------------------------------------------------------
		-- Check for NULL inodes and log them as issues

		FOR rec IN (
				SELECT  type,
					name
				FROM
				(
				-- Disks used in volume manager
					SELECT  'Volume Manager'	type,
						a.path		  	name
					FROM   stormon_temp_volume a
					WHERE  a.type      IN    ('DISK','VOLUME')
					AND    a.linkinode IS NULL
					UNION
					-- Filesystems used
					SELECT  'Filesystem'		type,
						a.filesystem	    	name
					FROM   stormon_temp_filesystem a
					WHERE  a.linkinode IS NULL
					AND    LOWER(NVL(a.type,'X')) != 'nfs'
					UNION
					-- block and char Files used in applications
					SELECT  'Oracle Database'   type,
						a.filename	      	name
					FROM   stormon_temp_app a
					WHERE  a.linkinode IS NULL
					UNION
					-- swraid disks
					SELECT	'Software Raid Manager'	type,
						path	    	name
					FROM	stormon_temp_swraid
					WHERE   type IN ('DISK','PARTITION','SUBDISK')
						AND linkinode IS NULL
					UNION
					-- OS disks
					SELECT  'Disks'		type,
						path		name
					FROM	stormon_temp_disk
					WHERE   linkinode IS NULL
				)
		)
		LOOP

			-- Log issues for the host
			STORAGE_SUMMARY_DB.LOGWARNING(v_targetid,rec.name||' used in '||rec.type||' is inaccessible , the device may no longer be physically available on the host ');
	
		END LOOP;
	
		-----------------------------------------------------------------
		--	CONSISTENCY CHECK FOR PARTITIONS
		-----------------------------------------------------------------
		
		BEGIN

			-- Get the list of diskkeys with inconsistent partitions
			SELECT	DISTINCT diskkey
			BULK COLLECT INTO l_diskkeyList
			FROM	(
				SELECT	diskkey,
					type,
					keyvalue,
				MAX(sizeb) sizeb -- Take the max size for a keyvalue
				FROM	stormon_temp_disk
				GROUP BY
					diskkey,
					type,
					keyvalue
				) a
			GROUP BY	diskkey			
			HAVING SUM(DECODE(a.type,'DISK',sizeb,-1*sizeb)) < 0;
	
			-- If there are inconsistent disks
			IF l_diskkeyList IS NOT NULL AND l_diskkeyList.EXISTS(1) THEN
				
				-- Get the rows that have inconsistent disks and partitions
				-- Flag the inconsistent disks and partitions
				UPDATE	stormon_temp_disk
				SET 	freetype = 'Inconsistent Partition Table'
				WHERE	diskkey IN 
				(
					SELECT	VALUE(a)
					FROM	TABLE( CAST ( l_diskkeyList AS stringTable ) ) a				
				);
				
				-- Get the diskname for each inconsistent disk to log an error message
				SELECT DISTINCT FIRST_VALUE(a.path) OVER ( PARTITION BY diskkey ORDER BY DECODE(type,'DISK',1,2) ASC, DECODE(filetype,'CHARACTER',1,2) ASC  NULLS LAST )
				BULK COLLECT INTO l_failedpartitions
				FROM	stormon_temp_disk a,
					TABLE( CAST ( l_diskkeyList AS stringTable ) ) b	
				WHERE	a.diskkey = VALUE(b);
		
				-- Loop thru the list of disks with inconsistent partition tables
				IF l_failedpartitions IS NOT NULL AND l_failedpartitions.EXISTS(1) THEN
				
					FOR i IN l_failedpartitions.FIRST..l_failedpartitions.LAST LOOP
		
						-- Log issues for the host
						STORAGE_SUMMARY_DB.LOGWARNING(v_targetid,' The Partition Table is not consistent, there is a overlap of partitions for disk '||	l_failedpartitions(i));
	
					END LOOP;
					
				END IF;

			END IF;
	
		EXCEPTION
			WHEN OTHERS THEN
				RAISE_APPLICATION_ERROR(-20103,'Failed in Partition consistency check for '||v_targetname,TRUE);
		END;
			
		------------------------------------------------------------------
		--	CHECK FOR CYLINDER OVERLAP	
		------------------------------------------------------------------
	
		------------------------------------------------------------------
		--	UPDATE KEYVALUES FROM LOWER LEVEL
		--	CONSISTENCY CHECK FOR INODES
		------------------------------------------------------------------

		-----------------------------------------------------------------
		--	UPDATE KEYVALUE FOR SUBDISKS USED IN SWRAID MANAGER
		-----------------------------------------------------------------
		UPDATE	stormon_temp_swraid a
		SET	keyvalue = (
				SELECT	keyvalue
				FROM	stormon_temp_disk b
				WHERE	a.linkinode = b.linkinode
				AND	ROWNUM = 1
			)		
		WHERE	a.type = 'SUBDISK'	
		AND	EXISTS (	
				SELECT	1
				FROM	stormon_temp_disk b
				WHERE	a.linkinode = b.linkinode
		);

		FOR rec IN (
				SELECT	a.path
				FROM	stormon_temp_swraid a
				WHERE	a.type = 'SUBDISK'
				AND	NOT EXISTS (	
					SELECT	1
					FROM	stormon_temp_disk b
					WHERE	NVL(a.linkinode,'x') = NVL(b.linkinode,'y')
				)	                
		)
		LOOP
 			STORAGE_SUMMARY_DB.LOGISSUE(v_targetid,' Disk '||rec.path||' used in software raid is not found in the List of disks');
		
		END LOOP;

		-----------------------------------------------------------------
		--	UPDATE KEYVALUE FOR DISKS USED IN VOLUME MANAGER
		-----------------------------------------------------------------
		UPDATE	stormon_temp_volume a
		SET	keyvalue = (
				SELECT	keyvalue
				FROM	(
					SELECT	keyvalue,
						linkinode
					FROM	stormon_temp_disk 
					UNION
					SELECT	keyvalue,
						linkinode	
					FROM	stormon_temp_swraid	
					) b
				WHERE	a.linkinode = b.linkinode
				AND	ROWNUM = 1
			)		
		WHERE	a.type = 'DISK'	
		AND	EXISTS (	
					SELECT 	1
					FROM	(
						SELECT	linkinode
						FROM	stormon_temp_disk 
						UNION
						SELECT	linkinode	
						FROM	stormon_temp_swraid	
						) b
					WHERE	a.linkinode = b.linkinode
		);

		FOR rec IN (
				SELECT	a.path			         	
				FROM 	stormon_temp_volume a
				WHERE	a.type = 'DISK'	
				AND	a.sizeb > 0
				AND	NOT EXISTS (	
					SELECT 	1
					FROM	(
							SELECT	linkinode
							FROM	stormon_temp_disk 
							UNION
							SELECT	linkinode	
							FROM	stormon_temp_swraid	
						) b
					WHERE	NVL(a.linkinode,'x') = NVL(b.linkinode,'y')
				)
	        )
        	LOOP

			STORAGE_SUMMARY_DB.LOGISSUE(v_targetid,' Disk '||rec.path||' used in volume manager is not found in the List of disks or Raid disks');

	        END LOOP;


		------------------------------------------------------------------------------
		--	MARK THE NON NFS FILESYSTEMS WHICH ARE BASED ON OTHER FILESYSTEMS
		--	THESE FILESYSTEMS ARE NOT INCLUDED IN SUMMARY
		------------------------------------------------------------------------------
		-- SELECT THE BASE(root) FILESYSTEM , filesystem id of the filesystem = mountpointid

		UPDATE	stormon_temp_filesystem
		SET	mounttype = 'BASE'
		WHERE	LOWER(NVL(type,'X')) != 'nfs'
		AND     mountpointid IS NOT NULL
		AND     linkinode IS NOT NULL
		AND     mountpointid = SUBSTR(linkinode,1,INSTR(linkinode,'-')-1);
	
		DECLARE
			l_base_filesystem	stormon_temp_filesystem.mounttype%TYPE;
			l_mountpoint		stormon_temp_filesystem.mountpoint%TYPE;
		BEGIN

		        SELECT  filesystem,			
		                mountpoint
			INTO	l_base_filesystem,
				l_mountpoint				
		        FROM    stormon_temp_filesystem
		        WHERE	mounttype = 'BASE'
		        AND     ROWNUM = 1;  -- There should be only 1 BASE (root) Filesystem

			STORAGE_SUMMARY_DB.LOG(v_targetid,' Base Filesystem for '||v_targetname||' is '||l_base_filesystem||' mounted at '||l_mountpoint);

		EXCEPTION
			WHEN NO_DATA_FOUND THEN
				STORAGE_SUMMARY_DB.LOGWARNING(v_targetid,' No Base Filesystem found for '||v_targetname);		
		END;

		-- GET THOSE FILESYSTEMS WHICH ARE ON MOUNTPOINTS OF OTHER FILESYSTEMS, EXCEPT THE BASE FILESYSTEMS
		-- Solaris clustered disk sets ( /dev/did appear to have cached the volumes they bear , take care of this TBD )
		UPDATE	stormon_temp_filesystem a
		SET	mounttype = 'FILESYSTEM_BASED'
		WHERE	LOWER(NVL(type,'X')) != 'nfs'
	        AND     linkinode IS NOT NULL			
	        AND     SUBSTR(linkinode,1,INSTR(linkinode,'-')-1)  IN
		(
			SELECT  mountpointid
			FROM    stormon_temp_filesystem b
			WHERE   NVL(mounttype,'x') != 'BASE'	 -- Cached from a non base filesystem
			AND     mountpointid IS NOT NULL
			AND	b.sizeb >= a.sizeb		 -- The cached filesystem should be smaller or equal to the size of the mointpoint
			AND	a.linkinode != b.linkinode
	        );

		FOR rec1 IN (
			SELECT	filesystem,
				type
			FROM	stormon_temp_filesystem
			WHERE	mounttype = 'FILESYSTEM_BASED'
		)
		LOOP

			STORAGE_SUMMARY_DB.LOG(v_targetid,' Filesystem '||rec1.filesystem||' of type '||rec1.type||' on target '||v_targetname||' is FILESYSTEM_BASED ');

		END LOOP;

		-----------------------------------------------------------------
		--	UPDATE KEYVALUE FOR FILESYSTEMS USED 
		-----------------------------------------------------------------
		UPDATE	stormon_temp_filesystem a
		SET	keyvalue = (
					SELECT	keyvalue
					FROM	(
						SELECT	keyvalue,
							linkinode
						FROM	stormon_temp_disk
						UNION
						SELECT	keyvalue,
							linkinode
						FROM	stormon_temp_swraid
						UNION
						SELECT	keyvalue,
							linkinode
						FROM	stormon_temp_volume
					) b
					WHERE	a.linkinode = b.linkinode
					AND	ROWNUM = 1
		)
		WHERE	LOWER(NVL(a.type,'x')) != 'nfs'
		AND	EXISTS (
				SELECT 	1
				FROM	(
					SELECT	linkinode
					FROM	stormon_temp_disk
					UNION
					SELECT	linkinode
					FROM	stormon_temp_swraid
					UNION
					SELECT	linkinode
					FROM	stormon_temp_volume
				) b
				WHERE	a.linkinode = b.linkinode				
		);
				
		-- Log issues for filesystems where the filesystem is not found in the underlying layers, with the exception of FILESYSTEM_BASED filesystems 		
		FOR rec IN (
                                SELECT  filesystem
                                FROM    (
	                                SELECT  filesystem,
        	                                b.linkinode
                	                FROM    stormon_temp_filesystem a,
                        	                (
                                	                SELECT  linkinode
                                        	        FROM    stormon_temp_disk
                                                	UNION
	                                                SELECT  linkinode
        	                                        FROM    stormon_temp_swraid
                	                                UNION
                        	                        SELECT  linkinode
                                	                FROM    stormon_temp_volume
	                                        ) b
        	                        WHERE   a.linkinode = b.linkinode(+)
                	                AND     LOWER(NVL(type,'x')) != 'nfs'
                        	        AND     NVL(mounttype,'x') != 'FILESYSTEM_BASED'
					AND	filesystem != '/dev/ramdisk'
                                ) 
                                WHERE   linkinode IS NULL
		)
		LOOP

			STORAGE_SUMMARY_DB.LOGISSUE(v_targetid,'Filesystem '||rec.filesystem||' is not found in the list of disks, RAID disks or volumes');

		END LOOP;

		-- Update a dummy keyvalue for non NFS filesystems with a null keyvalue
		UPDATE	stormon_temp_filesystem
		SET	keyvalue = v_targetname||'_'||ROWNUM
		WHERE	LOWER(NVL(type,'x')) != 'nfs'
		AND	keyvalue IS NULL;

		-----------------------------------------------------------------
		--	UPDATE KEYVALUE FOR APPLICATIONS USED 
		-----------------------------------------------------------------
		-- Update keyvalue for RAW or Character application files
		-- Update parent keys to be the keyvalue for raw or block application files
		UPDATE	stormon_temp_app a
		SET	(
			parentkey,
			keyvalue) = (
					SELECT	keyvalue,
						keyvalue
					FROM	(
						SELECT	keyvalue,
							linkinode
						FROM	stormon_temp_disk
						UNION
						SELECT	keyvalue,
							linkinode
						FROM	stormon_temp_swraid
						UNION
						SELECT	keyvalue,
							linkinode
						FROM	stormon_temp_volume
						UNION
						sELECT  keyvalue,
							linkinode
						FROM	stormon_temp_filesystem	
					) b
					WHERE	a.linkinode = b.linkinode
					AND	ROWNUM = 1
		)		
		WHERE	EXISTS (
				SELECT 	1
				FROM	(
					SELECT	linkinode
					FROM	stormon_temp_disk
					UNION
					SELECT	linkinode
					FROM	stormon_temp_swraid
					UNION
					SELECT	linkinode
					FROM	stormon_temp_volume
					UNION
					SELECT  linkinode
					FROM	stormon_temp_filesystem	
				) b
				WHERE	a.linkinode = b.linkinode
		);

		-- Update keyvalue and parentkey for Filesystem based application files
		UPDATE	stormon_temp_app a
		SET	parentkey = (					-- parentkey keyvalue of the filesystem on which it is based
					SELECT	keyvalue
					FROM	stormon_temp_filesystem b
					WHERE	a.parentkey = b.mountpointid
			),
			keyvalue = filename				-- keyvalue is filename
		WHERE	a.parentkey IN 					-- The application file should be filesystem based
		(
				SELECT  mountpointid			-- mountpointid is just the id for the filesystem
				FROM    stormon_temp_filesystem
		);

		-- Log issues for application files which have no keyvalue
	        FOR rec IN (

			SELECT  filename,
				appname
			FROM	stormon_temp_app a
			WHERE	NOT EXISTS (
				-- The application file should be filesystem based, so its parentid = mountpointid of the mountpoint its comming from
					SELECT  1
					FROM    stormon_temp_filesystem b
					WHERE	NVL(b.keyvalue,'x') = NVL(a.parentkey,'y')
				)
			AND	NOT EXISTS  (
				-- The application file is a character file so its linkinode matches another char device linkinode
				SELECT 	1
				FROM	(
					SELECT	linkinode
					FROM	stormon_temp_disk
					UNION
					SELECT	linkinode
					FROM	stormon_temp_swraid
					UNION
					SELECT	linkinode
					FROM	stormon_temp_volume
					UNION
					SELECT  linkinode
					FROM	stormon_temp_filesystem	
				) b
				WHERE	NVL(a.linkinode,'x') = NVL(b.linkinode,'y')
			)
		)
		LOOP
			STORAGE_SUMMARY_DB.LOGISSUE(v_targetid,'File '||rec.filename||' used in  application '||rec.appname||' not found on the list of disks, RAID disks , volumes and filesystems ');
		END LOOP;
		
		--------------------------------------------------------------------
		-- Select records with same linkinode but different keyvalues
		-- Update them with uniform parentkey and keyvalues
		--------------------------------------------------------------------
		DECLARE

			l_filename_list		stringTable;

		BEGIN

			-- Update the parentkey and keyvalue to the max value for application files with same linkinode but different keyvalue or parentkey
			-- Take the max length values for a given linkinode
			UPDATE	stormon_temp_app a
			SET	( parentkey, keyvalue ) = (
					SELECT	DISTINCT 
						FIRST_VALUE(parentkey) OVER ( ORDER BY LENGTH(parentkey) DESC NULLS LAST ) parentkey,
						FIRST_VALUE(keyvalue) OVER ( ORDER BY LENGTH(keyvalue) DESC NULLS LAST ) keyvalue
					FROM	stormon_temp_app b
					WHERE	a.linkinode = b.linkinode
			)
			WHERE	EXISTS (
				SELECT	1
				FROM	stormon_temp_app b
				WHERE	a.linkinode = b.linkinode
				AND	( 
						a.keyvalue != b.keyvalue
						OR a.parentkey != b.parentkey
					)				
			)
			RETURNING filename BULK COLLECT INTO l_filename_list;

			IF l_filename_list IS NOT NULL AND l_filename_list.EXISTS(1) THEN
				FOR i IN l_filename_list.FIRST..l_filename_list.LAST LOOP
					STORAGE_SUMMARY_DB.LOGWARNING(v_targetid,'Multiple identification key values found for  file '||l_filename_list(i)||' , this may be an inconsistency in configuration ');
				END LOOP;

			END IF;
			
		END;

		--------------------------------------------------------------------
		-- CHECK FOR NULL KEYVALUES
		--------------------------------------------------------------------
		-- Disks
		FOR rec IN ( 
				SELECT	DISTINCT path 
				FROM	stormon_temp_disk a
				WHERE	keyvalue IS NULL
			) 	
		LOOP
			STORAGE_SUMMARY_DB.LOGWARNING(v_targetid,'Unable to obtain an identification Key value for Disk Slice '||rec.path||' , The disk may no longer be physically available on the host ');
		END LOOP;


		-- swraid
		FOR rec IN ( 
				SELECT	DISTINCT type,
					path 
				FROM	stormon_temp_swraid
				WHERE	keyvalue IS NULL
			) 	
		LOOP
			STORAGE_SUMMARY_DB.LOGWARNING(v_targetid,'Unable to obtain an identification Key value for '||rec.type||' '||rec.path||' used in Software Raid Manager, The configuration may be invalid or the device is not physically available on the host');
		END LOOP;


		-- volumes
		FOR rec IN ( 
				SELECT	DISTINCT type,
					path 
				FROM	stormon_temp_volume
				WHERE	keyvalue IS NULL
			) 	
		LOOP
			STORAGE_SUMMARY_DB.LOGWARNING(v_targetid,'Unable to obtain an identification Key value for '||rec.type||' '||rec.path||' used in Volume Manager, The configuration may be invalid or the device is not physically available on the host');

		END LOOP;


		-- filesystem
		FOR rec IN ( 
				SELECT	DISTINCT type,
					filesystem 
				FROM	stormon_temp_filesystem
				WHERE	keyvalue IS NULL
			) 	
		LOOP

			STORAGE_SUMMARY_DB.LOGWARNING(v_targetid,'Unable to obtain an identification Key value for Filesystem '||rec.type||' '||rec.filesystem||' , The configuration may be invalid or the filesystem is not physically available on the host');

		END LOOP;


		-- Application
		FOR rec IN (
				SELECT	DISTINCT type,
					appname,
					filename
				FROM	stormon_temp_app
				WHERE	keyvalue IS NULL
			)
		LOOP
			STORAGE_SUMMARY_DB.LOGWARNING(v_targetid,'Unable to obtain an identification Key value for '||rec.filename||' used in application '||rec.type||' '||rec.appname||' , The configuration may be invalid or the device is not physically available on the host ');
		END LOOP;

		STORAGE_SUMMARY_DB.LOG_TIME('calcstoragesummary',v_targetid,v_targetname,' Time for consistency checks ',STORAGE_SUMMARY_DB.GETTIME(l_time));
		------------------------------------------------------------------
		-- UPDATE RAWSIZES 
		------------------------------------------------------------------
	
		-------------------------------------------------------------------
		-- MARK BACKUP DISKS , SWRAID, VOLUMES, FILESYSTEMS AND APPLICATIONS
		-------------------------------------------------------------------
		-- Mark the backup disks, swraid, volumes, fs, applications
	
		-- Disks
		-- BCV EMC disks are backup
	
		UPDATE	stormon_temp_disk a
		SET	backup = 'y'
		WHERE EXISTS 
		( 
			SELECT	1
			FROM	stormon_temp_disk b
			WHERE	b.storagevendor = 'EMC'
			AND	b.storageconfig LIKE '%BCV%'
			AND	b.diskkey = a.diskkey
		);
	
		------------------------------------------
		-- SWRAID BACKUP
		------------------------------------------
		-- swraid subdisks based on these disks are backup
		-- All swraid disks and partitions based on a backup disk are designated as backup
	
		UPDATE	stormon_temp_swraid a
		SET	backup = 'Y'
		WHERE 	EXISTS
		(
			SELECT	1
			FROM	stormon_temp_swraid b,
				stormon_temp_disk c
			WHERE	
				c.backup = 'Y'
				AND b.keyvalue = c.keyvalue			
				AND b.type = 'SUBDISK'
				AND DECODE(a.type,'SUBDISK',a.parent,a.keyvalue) = b.parent 
				-- The parent for a subdisk is the name of the swraid disk its part of, this is the keyvalue of the swraid disk or partition
		);
	
		------------------------------------------------------------
		-- VOLUMES BACKUP
		------------------------------------------------------------
		-- Update volume diskgroups based on backup disks and swraid disks are backup
		-- If a dingle disk in a disk group is a backup disk, designate all entities from that diskgroup to be backup

		UPDATE	stormon_temp_volume a
		SET	backup = 'Y'
		WHERE 	EXISTS
		(
			SELECT	1
			FROM	stormon_temp_volume b	,
				(
                                        SELECT  keyvalue
                                        FROM    stormon_temp_disk 
					WHERE	backup = 'Y'
                                        UNION
                                        SELECT  keyvalue
                                        FROM    stormon_temp_swraid 
                                        WHERE   type IN ('DISK','PARTITION')
					AND	backup = 'Y'
                                ) c
			WHERE	b.keyvalue = c.keyvalue			
			AND 	b.type = 'DISK'
			AND 	b.diskgroup = a.diskgroup
		);
	
		------------------------------------------------------------
		-- FILESYSTEMS BACKUP
		------------------------------------------------------------
		-- Update filesystems based on volumes, swraid disks, disks which are marked backup.
		-- WHat about cached filesystems if you have applications on them ??- TBD	

		UPDATE	stormon_temp_filesystem a
		SET	backup = 'Y'
		WHERE	EXISTS (
			SELECT  1
                        FROM    (
                                        SELECT  keyvalue
                                        FROM    stormon_temp_disk 
					WHERE	backup = 'Y'
                                        UNION
                                        SELECT  keyvalue
                                        FROM    stormon_temp_swraid 
                                        WHERE   type IN ('DISK','PARTITION')
					AND	backup = 'Y'
					UNION
					SELECT	keyvalue
					FROM	stormon_temp_volume 
					WHERE	type IN ('VOLUME')
					AND	backup = 'Y'
                                ) b
                        WHERE   b.keyvalue = a.keyvalue		
		);

		------------------------------------------------------------
		-- APPLICATIONS BACKUP
		------------------------------------------------------------
		-- Update application inodes based on volumes, swraid disks, disks which are marked backup
	
		UPDATE 	stormon_temp_app a
		SET	backup = 'Y'
		WHERE	EXISTS (
			SELECT  1
                        FROM    (
                                        SELECT  keyvalue
                                        FROM    stormon_temp_disk 
					WHERE	backup = 'Y'
                                        UNION
                                        SELECT  keyvalue
                                        FROM    stormon_temp_swraid 
                                        WHERE   type IN ('DISK','PARTITION')
					AND	backup = 'Y'
					UNION
					SELECT	keyvalue
					FROM	stormon_temp_volume 
					WHERE	type IN ('VOLUME')
					AND	backup = 'Y'
					UNION
					SELECT  keyvalue
                                        FROM    stormon_temp_filesystem
					WHERE	backup = 'Y'					
			) b
			WHERE	b.keyvalue = a.parentkey	
		);

		STORAGE_SUMMARY_DB.LOG_TIME('calcstoragesummary',v_targetid,v_targetname,' Time for backup check ',STORAGE_SUMMARY_DB.GETTIME(l_time));		
		----------------------------------------------------------
		--	COMPUTATION OF STORAGE SUMMARY
		----------------------------------------------------------
		
		-- Initialize the summary Object
		l_summary := summaryObject(NULL,v_targetname,v_targetid,SYSDATE,l_maxMetricTimestamp,1,1,0,0,'Y',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
	

		--------------------------------------------------------------------------
		-- LIST OF KEY VALUES USED AT EACH LEVEL IN THE STORAGE HIERARCHY 
		-- ABOVE DISKS
		-------------------------------------------------------------------------
		SELECT	parentkey keyvalue
		BULK COLLECT INTO l_usedKeys
		FROM	stormon_temp_app
		UNION
		SELECT	keyvalue
		FROM	stormon_temp_filesystem
		WHERE	LOWER(NVL(type,'x')) != 'nfs'
		UNION
		SELECT	keyvalue
		FROM	stormon_temp_volume 
		WHERE	type = 'DISK'
		UNION
		SELECT	keyvalue
		FROM	stormon_temp_swraid
		WHERE	type = 'SUBDISK'
		;
	
		-------------------------------------------------
		--	DISK SUMMARY
		-------------------------------------------------
		
--		IF l_diskTable IS NOT NULL AND l_diskTable.EXISTS(1) THEN
	
		-- Disk Devices
			STORAGE_SUMMARY.CALCFREEDISKSPACE(l_usedkeys);
	
		-- Summary rawsize and size,freesize of all disks mounted on the host
			SELECT	NVL(ROUND(SUM(DECODE(type,'DISK',rawsizeb,0)),0),0), 	-- rawsizeb
				NVL(ROUND(SUM(DECODE(type,'DISK',sizeb,0)),0),0),	-- sizeb
				NVL(ROUND(SUM(freeb),0),0)				-- freeb	
			INTO	l_summary.disk_rawsize,
				l_summary.disk_size,
				l_summary.disk_free
			FROM	( 
					SELECT	DISTINCT type,
						keyvalue,
						FIRST_VALUE(rawsizeb) OVER ( PARTITION BY type, keyvalue ORDER BY rawsizeb DESC NULLS LAST ) rawsizeb,
						FIRST_VALUE(sizeb) OVER ( PARTITION BY type, keyvalue ORDER BY sizeb DESC NULLS LAST ) sizeb,
						FIRST_VALUE(freeb) OVER ( PARTITION BY type, keyvalue ORDER BY sizeb DESC NULLS LAST ) freeb
					FROM	stormon_temp_disk				
				);
	
			l_summary.disk_used 		:= l_summary.disk_size - l_summary.disk_free;
	
			STORAGE_SUMMARY_DB.PRINTSTMT('Computed Disk summary');

		-- Summary rawsize and freesize for all backup disks mounted on the host
			SELECT	NVL(ROUND(SUM(rawsizeb),0),0), 	-- rawsizeb
				NVL(ROUND(SUM(sizeb),0),0)	-- sizeb
			INTO	l_summary.disk_backup_rawsize,
				l_summary.disk_backup_size
			FROM	( 
					SELECT	DISTINCT keyvalue,
						FIRST_VALUE(rawsizeb) OVER ( PARTITION BY keyvalue ORDER BY rawsizeb DESC NULLS LAST ) rawsizeb,
						FIRST_VALUE(sizeb) OVER ( PARTITION BY keyvalue ORDER BY sizeb DESC NULLS LAST ) sizeb
					FROM	stormon_temp_disk
					WHERE	type = 'DISK'
					AND	NVL(backup,'N') = 'Y'
				);

			l_summary.disk_backup_used	:= l_summary.disk_backup_size;
	
			----------------------------------------------------------
			-- SUMMARY OF DISK STORAGE BY VENDOR
			----------------------------------------------------------		
			FOR rec IN  (  
						SELECT	a.storagevendor||'-'||a.storageproduct vendor,		-- vendor
							NVL(ROUND(SUM(a.rawsizeb)),0) rawsizeb,			-- rawsizeb
							NVL(ROUND(SUM(a.sizeb)),0) sizeb,			-- sizeb
							NVL(ROUND(SUM(a.freeb)),0) freeb			-- freeb
						FROM   	( 
								SELECT	DISTINCT keyvalue,
									storagevendor,
									storageproduct,
									FIRST_VALUE(rawsizeb) OVER ( PARTITION BY keyvalue ORDER BY rawsizeb DESC NULLS LAST ) rawsizeb,
									FIRST_VALUE(sizeb) OVER ( PARTITION BY keyvalue ORDER BY sizeb DESC NULLS LAST ) sizeb,
									FIRST_VALUE(freeb) OVER ( PARTITION BY keyvalue ORDER BY sizeb DESC NULLS LAST ) freeb	
								FROM	stormon_temp_disk
								WHERE	type =  'DISK'
							) a
						GROUP BY
						a.storagevendor,
						a.storageproduct
			)
			LOOP
		
				CASE
					WHEN UPPER(rec.vendor) LIKE '%EMC%' THEN
						l_summary.vendor_emc_size	:= l_summary.vendor_emc_size + NVL(rec.sizeb,0);
						l_summary.vendor_emc_rawsize 	:= l_summary.vendor_emc_rawsize + NVL(rec.rawsizeb,0);	
					WHEN	UPPER(rec.vendor) LIKE '%T300%'  OR
						UPPER(rec.vendor) LIKE '%A1000%'  OR
						UPPER(rec.vendor) LIKE '%D1000%'
						THEN
						l_summary.vendor_sun_size	:= l_summary.vendor_sun_size + NVL(rec.sizeb,0);
						l_summary.vendor_sun_rawsize	:= l_summary.vendor_sun_rawsize + NVL(rec.rawsizeb,0);
					WHEN	UPPER(rec.vendor) LIKE '%HITACHI%' THEN
						l_summary.vendor_hitachi_size	:= l_summary.vendor_hitachi_size + NVL(rec.sizeb,0);
						l_summary.vendor_hitachi_rawsize:= l_summary.vendor_hitachi_rawsize + NVL(rec.rawsizeb,0);
					ELSE
						l_summary.vendor_others_size	:= l_summary.vendor_others_size + NVL(rec.sizeb,0);
						l_summary.vendor_others_rawsize	:= l_summary.vendor_others_rawsize + NVL(rec.rawsizeb,0);
				END CASE;
		

			END LOOP;
	
	
--		ELSE
	
--			STORAGE_SUMMARY_DB.LOGISSUE(v_targetid,'There are no disks available on host ');		
	
--		END IF;
	
		---------------------------------------------------
		--	SWRAID DISK SUMMARY
		---------------------------------------------------
		-- Software Raid Manager
--		IF l_swraidTable IS NOT NULL AND l_swraidTable.EXISTS(1) THEN
	
			STORAGE_SUMMARY.CALCSWRAIDDISKFREESPACE(l_usedkeys);
	
		-- Summary rawsize and size,freesize of all nonbackup disks mounted on the host
	
			SELECT	NVL(ROUND(SUM(DECODE(type,'SUBDISK',rawsizeb,0)),0),0), 	-- rawsizeb
				NVL(ROUND(SUM(DECODE(type,'DISK',sizeb,0)),0),0),		-- sizeb
				NVL(ROUND(SUM(freeb),0),0)					-- freeb	
			INTO	l_summary.swraid_rawsize,
				l_summary.swraid_size,
				l_summary.swraid_free
			FROM	( 
					SELECT	DISTINCT type,
						keyvalue,
						FIRST_VALUE(rawsizeb) OVER ( PARTITION BY type, keyvalue ORDER BY rawsizeb DESC NULLS LAST ) rawsizeb,
						FIRST_VALUE(sizeb) OVER ( PARTITION BY type, keyvalue ORDER BY sizeb DESC NULLS LAST ) sizeb,
						FIRST_VALUE(freeb) OVER ( PARTITION BY type, keyvalue ORDER BY sizeb DESC NULLS LAST ) freeb	
					FROM 	stormon_temp_swraid
					WHERE	NVL(backup,'N') = 'N'
				);

			l_summary.swraid_used	:= l_summary.swraid_size - l_summary.swraid_free;
		
--		END IF;
	
		------------------------------------------------------
		-- VOLUME MANAGER SUMMARY
		------------------------------------------------------		

		-- Summary rawsize and size,freesize of all nonbackup disks mounted on the host
--		IF l_volumeTable IS NOT NULL AND l_volumeTable.EXISTS(1) THEN
	
			-- Mark the free volumes, volumes whose keys are not in the used keys of filesystems and applications
			UPDATE	stormon_temp_volume a
			SET	a.freeb 	= a.sizeb,
				a.freetype 	= 'Free Volume'
			WHERE	a.type = 'VOLUME'
			AND	NOT EXISTS (
					SELECT	1
					FROM	TABLE( CAST ( l_usedkeys AS stringTable ) ) c
					WHERE   a.keyvalue = VALUE(c)
				);
	

			-- Update the free size in disks used in volume managers (vxdgfree), the size of the disk- sum of all its slices
			UPDATE 	stormon_temp_volume a
			SET	freetype 	= 'Free space in Disk',
				rawsizeb 	= sizeb,
				freeb 		=  (	
					SELECT	a.sizeb - SUM(b.sizeb)			--  ( Size of the disk - SUM of all the DISKSLICES OF A DISK )
					FROM	stormon_temp_volume b
					WHERE	b.diskgroup = a.diskgroup
					AND 	b.diskname = a.name
					-- SHould be add a check AND  b.type = 'SLICE'						
				)
			WHERE	type = 'DISK';

			-- Flag the disks with slice size > disk size
			UPDATE 	stormon_temp_volume a
			SET	freetype = 'Inconsistent slices',				
				freeb =  0	
			WHERE	type = 'DISK'
			AND	freeb < 0;

			-- Update used size for all volume entities
			UPDATE 	stormon_temp_volume a
			SET	usedb = sizeb - freeb;

			-- Compute the summary for volume manager	
			SELECT	NVL(ROUND(SUM(DECODE(type,'DISK',rawsizeb,0)),0),0),	-- rawsizeb
				NVL(ROUND(SUM(DECODE(type,'DISK',freeb,sizeb)),0),0),	-- sizeb
				NVL(ROUND(SUM(freeb),0),0)				-- freeb	
			INTO	l_summary.volumemanager_rawsize,
				l_summary.volumemanager_size,
				l_summary.volumemanager_free
			FROM	(	
					SELECT	DISTINCT type,
						keyvalue,
						FIRST_VALUE(rawsizeb) OVER ( PARTITION BY type, keyvalue ORDER BY rawsizeb DESC NULLS LAST ) rawsizeb,
						FIRST_VALUE(sizeb) OVER ( PARTITION BY type, keyvalue ORDER BY sizeb DESC NULLS LAST ) sizeb,
						FIRST_VALUE(usedb) OVER ( PARTITION BY type, keyvalue ORDER BY sizeb DESC NULLS LAST ) usedb,
						FIRST_VALUE(freeb) OVER ( PARTITION BY type, keyvalue ORDER BY sizeb DESC NULLS LAST ) freeb
					FROM	stormon_temp_volume
					WHERE	NVL(backup,'N') = 'N'
					AND	type IN ('DISK','VOLUME')
				);

			l_summary.volumemanager_used	:= l_summary.volumemanager_size - l_summary.volumemanager_free;
	
--		END IF;
	
		--------------------------------------------------------
		-- ORACLE DATABASE SUMMARY
		--------------------------------------------------------
	
--		IF l_applicationTable IS NOT NULL AND l_applicationTable.EXISTS(1) THEN
	
			-- Summary of all databases
	
			SELECT	NVL(SUM(b.rawsizeb),0),			-- rawsizeb
				NVL(SUM(b.sizeb),0),			-- sizeb
				NVL(SUM(b.usedb),0),			-- usedb
				NVL(SUM(b.freeb),0)			-- freeb
			INTO	l_summary.oracle_database_rawsize,
				l_summary.oracle_database_size,
				l_summary.oracle_database_used,
				l_summary.oracle_database_free
			FROM   (
					SELECT	DISTINCT parentkey,
						keyvalue,
						FIRST_VALUE(rawsizeb) OVER ( PARTITION BY parentkey, keyvalue ORDER BY rawsizeb DESC NULLS LAST ) rawsizeb,
                                                FIRST_VALUE(sizeb) OVER ( PARTITION BY parentkey, keyvalue ORDER BY sizeb DESC NULLS LAST ) sizeb,
                                                FIRST_VALUE(usedb) OVER ( PARTITION BY parentkey, keyvalue ORDER BY sizeb DESC NULLS LAST ) usedb,
                                                FIRST_VALUE(freeb) OVER ( PARTITION BY parentkey, keyvalue ORDER BY sizeb DESC NULLS LAST ) freeb
					FROM	stormon_temp_app
					WHERE	NVL(backup,'N') = 'N'
			) b;

--		END IF;		
	
		-----------------------------------------------------------
		-- FILESYSTEM SUMMARY
		-----------------------------------------------------------
--		IF l_filesystemTable IS NOT NULL AND l_filesystemTable.EXISTS(1) THEN
			
			STORAGE_SUMMARY_DB.PRINTSTMT('Compute local filesystem summary ');
	
			----------------------------------------------------------
			-- LOCAL FILESYSTEM
			----------------------------------------------------------
	
			SELECT	NVL(SUM(rawsizeb),0),	-- rawsizeb
				NVL(SUM(sizeb),0) ,	-- sizeb
				NVL(SUM(usedb),0) ,	-- usedb
				NVL(SUM(freeb),0) 	-- freeb
			INTO	l_summary.local_filesystem_rawsize,
				l_summary.local_filesystem_size,
				l_summary.local_filesystem_used,
				l_summary.local_filesystem_free
			FROM	(
					SELECT	DISTINCT keyvalue,
						FIRST_VALUE(rawsizeb) OVER ( PARTITION BY keyvalue ORDER BY rawsizeb DESC NULLS LAST ) rawsizeb,
						FIRST_VALUE(sizeb) OVER ( PARTITION BY keyvalue ORDER BY sizeb DESC NULLS LAST ) sizeb,
						FIRST_VALUE(usedb) OVER ( PARTITION BY keyvalue ORDER BY sizeb DESC NULLS LAST ) usedb,
						FIRST_VALUE(freeb) OVER ( PARTITION BY keyvalue ORDER BY sizeb DESC NULLS LAST ) freeb
					FROM	stormon_temp_filesystem a
					WHERE	LOWER(NVL(type,'x'))	!= 'nfs'
					AND	NVL(backup,'N') 	= 'N'
					AND	NVL(mounttype,'X')	!= 'FILESYSTEM_BASED'
					AND	filesystem 		!= '/dev/ramdisk'
				);

			-----------------------------------------------------------
			-- NFS SUMMARY
			-----------------------------------------------------------
	
			STORAGE_SUMMARY_DB.PRINTSTMT('Compute NFS Summary');

			-----------------------------------------------------------
			-- UPDATE THE KEY_VALUES FOR NETAPP NFS FILESYSTEMS BASED
			-- ON QTREES
			-----------------------------------------------------------
			UPDATE	stormon_temp_filesystem a		
			SET	keyvalue = SUBSTR(filesystem,1,INSTRB(filesystem,'/',1,4))	-- key_value to a qtree than a filesystem for Network appliance
			WHERE 	LOWER(a.type) = 'nfs'
			AND	vendor = 'NETAPP'
			AND	INSTRB(filesystem,'/',1,4) > 0;

	
			-- NFS with exclusive mount , cascase the different conditions thru UNION


			-- Those with a single mount count
			UPDATE	stormon_temp_filesystem a
			SET	mounttype = 'EXCLUSIVE'
			WHERE	LOWER(a.type) = 'nfs'
			AND	a.nfscount = 1				-- Exclusive mounted
			AND	NVL(a.mounttype,'X') != 'EXCLUSIVE'	-- Leave out those that have already been tagged
			AND	UPPER(a.privilege) LIKE '%WRITE%'	-- has write privilege
			-- Not cross mounted from one of our host targets
			AND NOT EXISTS (
					SELECT	'x'
					FROM	TABLE(CAST(l_hostTable AS stringTable)) b	
					WHERE
					-- The name may or may not have domain us.oracle.com 					
						UPPER(VALUE(b)) LIKE UPPER(a.server)||'.%'
						OR UPPER(a.server) LIKE UPPER(VALUE(b))||'.%'
				);
		

			--Cascade Rule 1 for exclusive mount
			UPDATE	stormon_temp_filesystem a
			SET	mounttype = 'EXCLUSIVE'
			WHERE	LOWER(a.type) = 'nfs'			
			AND	UPPER(a.privilege) LIKE '%WRITE%'	-- has write privilege
			AND	UPPER(a.server) LIKE 'AUOHSNTAP%'		-- Comes from servers with name starting with 
			AND	UPPER(a.vendor) LIKE 'NETAPP%'		-- Comes from Netapp
			-- Not cross mounted from one of our host targets
			AND NOT EXISTS (
					SELECT	'x'
					FROM	TABLE(CAST(l_hostTable AS stringTable)) b	
					WHERE
					-- The name may or may not have domain us.oracle.com 					
						UPPER(VALUE(b)) LIKE UPPER(a.server)||'.%'
						OR UPPER(a.server) LIKE UPPER(VALUE(b))||'.%'
				);
	
			---------------------------------------------
			-- Mark the others NFS as SHARED nfs 
			---------------------------------------------
			UPDATE	stormon_temp_filesystem a
			SET	mounttype = 'SHARED'
			WHERE	LOWER(a.type) = 'nfs'
			AND	NVL(mounttype,'x') != 'EXCLUSIVE';

			--Cascade Rule 1 for shared mount
			-- Those exclusive mounts, from NETAPP filer starting with pocntap are always shared even if mount count = 1
			UPDATE	stormon_temp_filesystem a
			SET	mounttype = 'SHARED'
			WHERE	LOWER(a.type) = 'nfs'			
			AND	UPPER(a.server) LIKE 'POCNTAP%'		-- Comes from servers with name starting with 
			AND	UPPER(a.vendor) LIKE 'NETAPP%';		-- Comes from Netapp	

			------------------------------------------
			-- NFS Summary exclusive or shared 
			------------------------------------------
			FOR rec IN ( 
					SELECT	mounttype,              	-- mounttype
						NVL(SUM(rawsizeb),0) rawsizeb, 	-- rawsizeb
						NVL(SUM(sizeb),0) sizeb,     	-- sizeb
						NVL(SUM(usedb),0) usedb,     	-- usedb
						NVL(SUM(freeb),0) freeb       	-- freeb
						FROM
						(
							SELECT	DISTINCT keyvalue,
								FIRST_VALUE(mounttype) OVER ( PARTITION BY keyvalue ORDER BY DECODE(mounttype,'EXCLUSIVE',1,2) ASC NULLS LAST )  mounttype,
								FIRST_VALUE(rawsizeb) OVER ( PARTITION BY keyvalue ORDER BY rawsizeb DESC NULLS LAST ) rawsizeb,
								FIRST_VALUE(sizeb) OVER ( PARTITION BY keyvalue ORDER BY sizeb DESC NULLS LAST ) sizeb,
								FIRST_VALUE(usedb) OVER ( PARTITION BY keyvalue ORDER BY sizeb DESC NULLS LAST ) usedb,
								FIRST_VALUE(freeb) OVER ( PARTITION BY keyvalue ORDER BY sizeb DESC NULLS LAST ) freeb		
							FROM    stormon_temp_filesystem
							WHERE   LOWER(NVL(type,'x')) = 'nfs'
						)
						GROUP BY
							mounttype

			)
			LOOP
	
					IF  rec.mounttype = 'EXCLUSIVE' THEN
						l_summary.nfs_exclusive_size := l_summary.nfs_exclusive_size + NVL(rec.sizeb,0);	
						l_summary.nfs_exclusive_free := l_summary.nfs_exclusive_free + NVL(rec.freeb,0);
					ELSE 	-- NFS_SHARED			
						l_summary.nfs_shared_size := l_summary.nfs_shared_size + NVL(rec.sizeb,0);	
						l_summary.nfs_shared_free := l_summary.nfs_shared_free + NVL(rec.freeb,0);			
					END IF;
	
			END LOOP;
	
			l_summary.nfs_exclusive_used := NVL(l_summary.nfs_exclusive_size,0) - NVL(l_summary.nfs_exclusive_free,0);
			l_summary.nfs_shared_used := NVL(l_summary.nfs_shared_size,0) - NVL(l_summary.nfs_shared_free,0);


			-- NFS Summary by vendor 
			FOR rec IN (
					SELECT	vendor,				-- vendor
						NVL(SUM(rawsizeb),0) rawsizeb,	-- rawsizeb
						NVL(SUM(sizeb),0) sizeb,	-- sizeb
						NVL(SUM(usedb),0) usedb,	-- usedb
						NVL(SUM(freeb),0) freeb		-- freeb	
					FROM (
						SELECT	DISTINCT keyvalue,
							FIRST_VALUE(vendor) OVER ( PARTITION BY keyvalue ORDER BY LENGTH(vendor) DESC NULLS LAST ) vendor,
							FIRST_VALUE(rawsizeb) OVER ( PARTITION BY keyvalue ORDER BY rawsizeb DESC NULLS LAST ) rawsizeb,
							FIRST_VALUE(sizeb) OVER ( PARTITION BY keyvalue ORDER BY sizeb DESC NULLS LAST ) sizeb,
							FIRST_VALUE(usedb) OVER ( PARTITION BY keyvalue ORDER BY sizeb DESC NULLS LAST ) usedb,
							FIRST_VALUE(freeb) OVER ( PARTITION BY keyvalue ORDER BY sizeb DESC NULLS LAST ) freeb
						FROM	stormon_temp_filesystem
						WHERE	LOWER(NVL(type,'x')) = 'nfs'
						AND	NVL(mounttype,'SHARED') = 'EXCLUSIVE'		
					)
					GROUP BY
					vendor
			)
			LOOP 
					CASE
						WHEN rec.vendor = 'NETAPP' THEN
							l_summary.vendor_nfs_netapp_size := NVL(rec.sizeb,0);
						WHEN rec.vendor = 'EMC' THEN
							l_summary.vendor_nfs_emc_size := NVL(rec.sizeb,0);	
						ELSE
							l_summary.vendor_nfs_others_size := NVL(l_summary.vendor_nfs_others_size,0) +
												NVL(rec.sizeb,0);
					END CASE;
			
			END LOOP;
		
--		END IF;
	
		STORAGE_SUMMARY_DB.LOG_TIME('calcstoragesummary',v_targetid,v_targetname,' Time for computation of summary',STORAGE_SUMMARY_DB.GETTIME(l_time));
	
		-- Total raw, size , free
	
		l_summary.rawsize	:= l_summary.disk_rawsize + l_summary.nfs_exclusive_size;
		l_summary.sizeb		:= l_summary.disk_size + l_summary.nfs_exclusive_size;
		l_summary.free 		:= l_summary.disk_free +
						l_summary.disk_backup_free +
						l_summary.swraid_free +
						l_summary.volumemanager_free +
						l_summary.application_free +
						l_summary.oracle_database_free +
						l_summary.local_filesystem_free +
						l_summary.nfs_exclusive_free;
		
		l_summary.used 		:= l_summary.sizeb - l_summary.free;
	
		------------------------------------------------------------
		-- 	REFRESH THE DETAILED REPORT FOR THE TARGET
		------------------------------------------------------------

		-------------------------------------------------------
		-- ORACLE DATABASE DETAILED REPORT 
		-------------------------------------------------------
		BEGIN
			
			INSERT INTO storage_application_table
			SELECT  target_id       ,
                                parentkey       ,
                                keyvalue        ,
                                type            ,
                                appname         ,
                                appid           ,                                
				DECODE(grouping(tablespace),1,appid||' Total',appid),
                                grouping(tablespace),
                                tablespace      ,
                                filename        ,
                                SUM(rawsizeb)   ,
                                SUM(sizeb)      ,
                                SUM(usedb)      ,
                                SUM(freeb)      ,
                                NVL(backup,'N')            
                        FROM    (
                                        SELECT	DISTINCT target_id,
                                                parentkey,
                                                keyvalue,
                                                FIRST_VALUE(type) OVER ( PARTITION BY parentkey, keyvalue ORDER BY LENGTH(type) DESC NULLS LAST ) type,
                                                FIRST_VALUE(appname) OVER ( PARTITION BY parentkey, keyvalue ORDER BY LENGTH(appname) DESC NULLS LAST ) appname,
                                                FIRST_VALUE(appid) OVER ( PARTITION BY parentkey, keyvalue ORDER BY LENGTH(appid) DESC NULLS LAST ) appid,
                                                FIRST_VALUE(tablespace) OVER ( PARTITION BY parentkey, keyvalue ORDER BY LENGTH(tablespace) DESC NULLS LAST ) tablespace,
                                                FIRST_VALUE(filename) OVER ( PARTITION BY parentkey, keyvalue ORDER BY LENGTH(filename) DESC NULLS LAST ) filename,
                                                FIRST_VALUE(rawsizeb) OVER ( PARTITION BY parentkey, keyvalue ORDER BY rawsizeb DESC NULLS LAST ) rawsizeb,
                                                FIRST_VALUE(sizeb) OVER ( PARTITION BY parentkey, keyvalue ORDER BY sizeb DESC NULLS LAST ) sizeb,
                                                FIRST_VALUE(usedb) OVER ( PARTITION BY parentkey, keyvalue ORDER BY sizeb DESC NULLS LAST ) usedb,
                                                FIRST_VALUE(freeb) OVER ( PARTITION BY parentkey, keyvalue ORDER BY sizeb DESC NULLS LAST ) freeb ,
                                                FIRST_VALUE(backup) OVER ( PARTITION BY parentkey,keyvalue ORDER BY DECODE(backup,'Y',2,1) DESC NULLS LAST ) backup
					FROM    stormon_temp_app                                        
                                )
			GROUP BY GROUPING SETS (
                                (target_id,parentkey,keyvalue,type,appname,appid,tablespace,filename,backup),
                                (target_id,type,appid)
                        );		

		EXCEPTION
			WHEN NO_DATA_FOUND THEN 
				NULL;
			WHEN OTHERS THEN
				RAISE_APPLICATION_ERROR(-20103,'Failed during insertion of the database details for '||v_targetname);
		END;
			
		STORAGE_SUMMARY_DB.LOG_TIME('calcstoragesummary',v_targetid,v_targetname,' Time for inserting oracle database details ',STORAGE_SUMMARY_DB.GETTIME(l_time));
			
		-------------------------------------------------------
		-- LOCAL FILESYSTEM DETAILED REPORT 
		-------------------------------------------------------
		BEGIN
			
			INSERT INTO storage_localfs_table 		
			SELECT	DISTINCT target_id,
				keyvalue,
				type,
				STORAGE_SUMMARY_DB.CONCATLIST(CURSOR( SELECT filesystem FROM stormon_temp_filesystem WHERE keyvalue = a.keyvalue ORDER BY rowcount)) ,
				STORAGE_SUMMARY_DB.CONCATLIST(CURSOR( SELECT mountpoint FROM stormon_temp_filesystem WHERE keyvalue = a.keyvalue ORDER BY rowcount)) ,
				FIRST_VALUE(rawsizeb) OVER ( PARTITION BY keyvalue ORDER BY rawsizeb DESC NULLS LAST ) ,
				FIRST_VALUE(sizeb) OVER ( PARTITION BY keyvalue ORDER BY sizeb DESC NULLS LAST ) ,
				FIRST_VALUE(usedb) OVER ( PARTITION BY keyvalue ORDER BY sizeb DESC NULLS LAST ) ,
				FIRST_VALUE(freeb) OVER ( PARTITION BY keyvalue ORDER BY sizeb DESC NULLS LAST ) ,
				FIRST_VALUE(backup) OVER ( PARTITION BY keyvalue ORDER BY DECODE(backup,'Y',2,1) DESC NULLS LAST )
			FROM	stormon_temp_filesystem a
			WHERE	LOWER(NVL(type,'X')) != 'nfs';
			
		EXCEPTION
			WHEN NO_DATA_FOUND THEN 
				NULL;
			WHEN OTHERS THEN
				RAISE_APPLICATION_ERROR(-20103,'Failed during insertion of the Local filesystem details for '||v_targetname);	
		END;
			
		STORAGE_SUMMARY_DB.LOG_TIME('calcstoragesummary',v_targetid,v_targetname,' Time for inserting local filesystem details',STORAGE_SUMMARY_DB.GETTIME(l_time));
			
		-------------------------------------------------------
		-- NFS FILESYSTEM DETAILED REPORT 
		-------------------------------------------------------
		BEGIN
			
			INSERT INTO storage_nfs_table	
			SELECT	DISTINCT target_id,
				keyvalue,
				type,
				STORAGE_SUMMARY_DB.CONCATLIST(CURSOR( SELECT filesystem FROM stormon_temp_filesystem WHERE keyvalue = a.keyvalue ORDER BY rowcount)),
				STORAGE_SUMMARY_DB.CONCATLIST(CURSOR( SELECT mountpoint FROM stormon_temp_filesystem WHERE keyvalue = a.keyvalue ORDER BY rowcount)),
				FIRST_VALUE(rawsizeb) OVER ( PARTITION BY keyvalue ORDER BY rawsizeb DESC NULLS LAST ),
				FIRST_VALUE(sizeb) OVER ( PARTITION BY keyvalue ORDER BY sizeb DESC NULLS LAST ),
				FIRST_VALUE(usedb) OVER ( PARTITION BY keyvalue ORDER BY sizeb DESC NULLS LAST ),
				FIRST_VALUE(freeb) OVER ( PARTITION BY keyvalue ORDER BY sizeb DESC NULLS LAST ),
				FIRST_VALUE(vendor) OVER ( PARTITION BY keyvalue ORDER BY LENGTH(vendor) DESC NULLS LAST ),
				FIRST_VALUE(server) OVER ( PARTITION BY keyvalue ORDER BY LENGTH(server) DESC NULLS LAST ),
				FIRST_VALUE(mounttype) OVER ( PARTITION BY keyvalue ORDER BY LENGTH(mounttype) DESC NULLS LAST ),
				FIRST_VALUE(nfscount) OVER ( PARTITION BY keyvalue ORDER BY LENGTH(nfscount) DESC NULLS LAST ),
				FIRST_VALUE(privilege) OVER ( PARTITION BY keyvalue ORDER BY LENGTH(privilege) DESC NULLS LAST )
			FROM	stormon_temp_filesystem a
			WHERE	LOWER(NVL(type,'x')) = 'nfs';
--			AND	UPPER(mounttype) = 'EXCLUSIVE';
			
		EXCEPTION
			WHEN NO_DATA_FOUND THEN 
				NULL;
			WHEN OTHERS THEN
				RAISE_APPLICATION_ERROR(-20103,'Failed during insertion of the NFS details for '||v_targetname);	
		END;
			
		STORAGE_SUMMARY_DB.LOG_TIME('calcstoragesummary',v_targetid,v_targetname,' Time for nfs details',STORAGE_SUMMARY_DB.GETTIME(l_time));	
		-------------------------------------------------------
		-- VOLUME MANAGER DETAILED REPORT 		
		-------------------------------------------------------
		BEGIN
			
			INSERT INTO storage_volume_table
			SELECT	DISTINCT target_id,
				keyvalue,
				type,
				diskgroup,					
				STORAGE_SUMMARY_DB.CONCATLIST(CURSOR( SELECT path FROM stormon_temp_volume WHERE type = a.type AND keyvalue = a.keyvalue ORDER BY rowcount)),
				FIRST_VALUE(rawsizeb) OVER ( PARTITION BY type, keyvalue ORDER BY rawsizeb DESC NULLS LAST ),
				FIRST_VALUE(sizeb) OVER ( PARTITION BY type, keyvalue ORDER BY sizeb DESC NULLS LAST ),
				FIRST_VALUE(usedb) OVER ( PARTITION BY type, keyvalue ORDER BY sizeb DESC NULLS LAST ),
				FIRST_VALUE(freeb) OVER ( PARTITION BY type, keyvalue ORDER BY sizeb DESC NULLS LAST ),				
				FIRST_VALUE(configuration) OVER (PARTITION BY type, keyvalue ORDER BY LENGTH(configuration) DESC NULLS LAST ),
				FIRST_VALUE(freetype) OVER (PARTITION BY type, keyvalue ORDER BY LENGTH(freetype) DESC NULLS LAST ),
				FIRST_VALUE(backup) OVER (PARTITION BY type, keyvalue ORDER BY LENGTH(backup) DESC NULLS LAST )
			FROM	stormon_temp_volume a;

			-- Summary for each disk group
			INSERT INTO storage_volume_table
			SELECT	target_id,
				diskgroup,
				'Disk Group' type,	
				diskgroup,
				diskgroup,	
				SUM(rawsizeb),
				SUM(sizeb),
				SUM(usedb),
				SUM(freeb),
				NULL,
				'Free Space In Disk Group',
				NVL(backup,'N')	
			FROM	(
					SELECT	DISTINCT target_id,
						keyvalue,						
						diskgroup,								
						FIRST_VALUE(rawsizeb) OVER ( PARTITION BY keyvalue ORDER BY rawsizeb DESC NULLS LAST ) rawsizeb,
						FIRST_VALUE(sizeb) OVER ( PARTITION BY keyvalue ORDER BY sizeb DESC NULLS LAST ) sizeb,
						FIRST_VALUE(usedb) OVER ( PARTITION BY keyvalue ORDER BY sizeb DESC NULLS LAST ) usedb,
						FIRST_VALUE(freeb) OVER ( PARTITION BY keyvalue ORDER BY sizeb DESC NULLS LAST ) freeb,
						FIRST_VALUE(backup) OVER (PARTITION BY keyvalue ORDER BY LENGTH(backup) DESC NULLS LAST ) backup
					FROM	stormon_temp_volume a
					WHERE	type = 'DISK'
				)			
			GROUP BY
				target_id, 
				diskgroup,
				backup;
			
		EXCEPTION
			WHEN NO_DATA_FOUND THEN 
				NULL;
			WHEN OTHERS THEN
				RAISE_APPLICATION_ERROR(-20103,'Failed during insertion of the Volume Manager details for '||v_targetname);	
		END;
			
		STORAGE_SUMMARY_DB.LOG_TIME('calcstoragesummary',v_targetid,v_targetname,' Time for inserting volume details',STORAGE_SUMMARY_DB.GETTIME(l_time));
		-------------------------------------------------------
		-- SWRAID DETAILED REPORT 
		-------------------------------------------------------
		BEGIN
			
			INSERT INTO storage_swraid_table 
			SELECT	DISTINCT target_id,
				keyvalue,
				FIRST_VALUE(diskkey) OVER (PARTITION BY type, keyvalue ORDER BY LENGTH(diskkey) DESC NULLS LAST ),
				type,
				STORAGE_SUMMARY_DB.CONCATLIST(CURSOR( SELECT path FROM stormon_temp_swraid WHERE type = a.type AND keyvalue = a.keyvalue ORDER BY rowcount)),	
				FIRST_VALUE(rawsizeb) OVER ( PARTITION BY type, keyvalue ORDER BY rawsizeb DESC NULLS LAST ),
				FIRST_VALUE(sizeb) OVER ( PARTITION BY type, keyvalue ORDER BY sizeb DESC NULLS LAST ),
				FIRST_VALUE(usedb) OVER ( PARTITION BY type, keyvalue ORDER BY sizeb DESC NULLS LAST ),
				FIRST_VALUE(freeb) OVER ( PARTITION BY type, keyvalue ORDER BY sizeb DESC NULLS LAST ),			
				FIRST_VALUE(storageconfig) OVER ( PARTITION BY type, keyvalue ORDER BY LENGTH(storageconfig) DESC NULLS LAST ),
				FIRST_VALUE(freetype) OVER ( PARTITION BY type, keyvalue ORDER BY LENGTH(freetype) DESC NULLS LAST ),
				FIRST_VALUE(backup) OVER ( PARTITION BY type, keyvalue ORDER BY LENGTH(backup) DESC NULLS LAST ),
				FIRST_VALUE(parent) OVER ( PARTITION BY type, keyvalue ORDER BY LENGTH(parent) DESC NULLS LAST )	
			FROM	stormon_temp_swraid a;		
			
		EXCEPTION
			WHEN NO_DATA_FOUND THEN 
				NULL;
			WHEN OTHERS THEN
				RAISE_APPLICATION_ERROR(-20103,'Failed during insertion of the Software Raid details for '||v_targetname);	
		END;
			
		STORAGE_SUMMARY_DB.LOG_TIME('calcstoragesummary',v_targetid,v_targetname,' Time for inserting software raid details',STORAGE_SUMMARY_DB.GETTIME(l_time));	

		-------------------------------------------------------
		-- DISKS DETAILED REPORT 
		-------------------------------------------------------
		BEGIN	
			
			INSERT INTO storage_disk_table
			SELECT	DISTINCT target_id,				
				keyvalue,
				FIRST_VALUE(diskkey) OVER (PARTITION BY type, keyvalue ORDER BY LENGTH(diskkey) DESC NULLS LAST ),
				type,
				STORAGE_SUMMARY_DB.CONCATLIST(CURSOR( SELECT path FROM stormon_temp_disk WHERE type = a.type AND keyvalue = a.keyvalue ORDER BY rowcount)),
				FIRST_VALUE(rawsizeb) OVER ( PARTITION BY type, keyvalue ORDER BY rawsizeb DESC NULLS LAST ),
				FIRST_VALUE(sizeb) OVER ( PARTITION BY type, keyvalue ORDER BY sizeb DESC NULLS LAST ),
				FIRST_VALUE(usedb) OVER ( PARTITION BY type, keyvalue ORDER BY sizeb DESC NULLS LAST ),
				FIRST_VALUE(freeb) OVER ( PARTITION BY type, keyvalue ORDER BY sizeb DESC NULLS LAST ),				
				FIRST_VALUE(storageconfig) OVER (PARTITION BY type, keyvalue ORDER BY LENGTH(storageconfig) DESC NULLS LAST ),
				FIRST_VALUE(freetype) OVER (PARTITION BY type, keyvalue ORDER BY LENGTH(freetype) DESC NULLS LAST),
				FIRST_VALUE(backup) OVER (PARTITION BY type, keyvalue ORDER BY LENGTH(backup) DESC NULLS LAST),
				FIRST_VALUE(storagevendor) OVER ( PARTITION BY type, keyvalue ORDER BY LENGTH(storagevendor) DESC NULLS LAST ),
				FIRST_VALUE(storageproduct) OVER ( PARTITION BY type, keyvalue ORDER BY LENGTH(storageproduct) DESC NULLS LAST ),
				FIRST_VALUE(status) OVER ( PARTITION BY type, keyvalue ORDER BY LENGTH(status) DESC NULLS LAST )
			FROM	stormon_temp_disk a;

		EXCEPTION
			WHEN NO_DATA_FOUND THEN 
				NULL;
			WHEN OTHERS THEN
				RAISE_APPLICATION_ERROR(-20103,'Failed during insertion of the Disk details for '||v_targetname);
		END;


		STORAGE_SUMMARY_DB.LOG_TIME('calcstoragesummary',v_targetid,v_targetname,' Time for inserting disk details ',STORAGE_SUMMARY_DB.GETTIME(l_time));

	------------------------------------------------
	-- If there are issues , raise an exception
	------------------------------------------------
	BEGIN

		SELECT  1
		INTO	l_dummy
		FROM 	storage_log
		WHERE	target_id = l_summary.id
		AND	type = 'ISSUE'
		AND 	ROWNUM = 1;

		RAISE_APPLICATION_ERROR(-20101,NULL);
		
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			NULL;
		WHEN OTHERS THEN
			IF SQLCODE = -20101 THEN
				-- Raise the above exception as an issue summary
				RAISE;
			ELSE
				-- This is a rollback
				RAISE_APPLICATION_ERROR(-20103,'Error fetching issues for the target '||v_targetname,TRUE);
			END IF;
	END;
			
	------------------------------------------------------------------
	-- At this point any summaries with issues will 
	-- will have been caught
	-- CHECK FOR INVALID SUMMARY VALUES, which have no issues
	-- and raise them as an issue
	------------------------------------------------------------------
	IF 
		l_summary.used < 0 OR  l_summary.used > l_summary.sizeb OR
		l_summary.disk_used < 0 OR l_summary.disk_used > l_summary.disk_size OR
		l_summary.disk_backup_used < 0 OR l_summary.disk_backup_used > l_summary.disk_backup_size OR
		l_summary.swraid_used < 0 OR l_summary.swraid_used > l_summary.swraid_size OR
		l_summary.volumemanager_used < 0 OR l_summary.volumemanager_used > l_summary.volumemanager_size OR
		l_summary.local_filesystem_used < 0 OR l_summary.local_filesystem_used > l_summary.local_filesystem_size OR
		l_summary.oracle_database_used < 0 OR 	l_summary.oracle_database_used > l_summary.oracle_database_size OR
		l_summary.application_used < 0 OR l_summary.application_used > l_summary.application_size OR
		l_summary.nfs_exclusive_used < 0 OR l_summary.nfs_exclusive_used > l_summary.nfs_exclusive_size OR
		l_summary.disk_backup_size > l_summary.sizeb OR
		l_summary.swraid_rawsize >  l_summary.disk_size OR
		l_summary.volumemanager_rawsize >  l_summary.disk_size OR
		l_summary.local_filesystem_size > l_summary.disk_size OR
		l_summary.application_size > l_summary.sizeb OR
		l_summary.oracle_database_size > l_summary.sizeb	
	THEN
		RAISE_APPLICATION_ERROR(-20101,'There is an error in the computed storage summary ');
	END IF;


	EXCEPTION

		WHEN OTHERS THEN

			-- Parse the error message
			l_errmsg := SUBSTR(SQLERRM,NVL(INSTRB(SQLERRM,':'),0)+1,2048);

			------------------------------------------------------------------------------------------------
			-- ROLLBACK if processing error
			------------------------------------------------------------------------------------------------
			IF SQLCODE = -20103 THEN
				RAISE;
			END IF;

			-----------------------------------------------------------------------------------------------
			-- ROLLBACK if collection timestamp of last summary = MAX (timestamp) of collected metrics
			-- and collection timestamp is < some reasonable time
			-- But why do this ?, will this happen in real world situations
			-- TBD
			-----------------------------------------------------------------------------------------------

			-----------------------------------------------------------------------------------------
			-- Set the timestamp of the placeholder summary to system time	
			l_summary := summaryObject(NULL,v_targetname,v_targetid,SYSDATE,SYSDATE-STORAGE_SUMMARY.c_old_summary_days,1,1,0,0,NULL,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);


			------------------------------------------------------------------------------------
			-- IF No metrics and metrics NEVER COLLECTED ,mark summary as NEVER COLLECTED
			------------------------------------------------------------------------------------
			IF SQLCODE = -20102 AND ( l_lastSummary IS NULL OR l_lastSummary.summaryFlag = 'N' ) THEN
				
				IF l_lastSummary IS NOT NULL AND l_lastSummary.timestamp >= (SYSDATE-STORAGE_SUMMARY.c_old_summary_days) THEN
					RAISE;				
				END IF;

				-- STORAGE_SUMMARY_DB.LOGISSUE(v_targetid,'Collection of storage metrics has not been enabled');

				l_summary.summaryFlag := 'N';

			------------------------------------------------------------------------------------
			-- If METRICS have been collected once , mark summary as an ISSUE
			------------------------------------------------------------------------------------
			ELSE

				------------------------------------------------------------------------------------------------
				-- ROLLBACK if last summary is not stale
				------------------------------------------------------------------------------------------------
				IF l_lastSummary IS NOT NULL THEN

					-- If last summary was a valid one then retain it for STORAGE_SUMMARY.c_old_summary_days period from SYSDATE
					IF  l_lastSummary.summaryflag = 'Y' AND l_lastSummary.timestamp >= (SYSDATE-STORAGE_SUMMARY.c_old_summary_days) THEN
						RAISE;
					END IF;	
	
					-- If last summary was one with issues then retain it for STORAGE_SUMMARY.c_old_summary_days period from SYSDATE
					IF  l_lastSummary.summaryflag = 'I' AND l_lastSummary.timestamp >= (SYSDATE-STORAGE_SUMMARY.c_old_summary_days) THEN
						RAISE;
					END IF;										
					
				END IF;
			
				l_summary.summaryFlag := 'I';

				-- Take the collection timestamp of the last summary if a summary exists for the host and if
				-- its not a null one
				IF l_lastsummary IS NOT NULL AND l_lastSummary.summaryflag != 'N' AND l_lastsummary.collection_timestamp IS NOT NULL THEN

					l_summary.collection_timestamp := l_lastsummary.collection_timestamp;

				-- Else take the minimum metric timestamp ( This is a probably a case of broken metrics )
				ELSIF l_minMetricTimestamp IS NOT NULL THEN
					-- Slightly less than the minimum metric timestamp, THis will enable the summary to be computed the next
					-- time, if the metric was in the process of loading
					l_summary.collection_timestamp := l_minMetricTimestamp-1;

				END IF;
	
			END IF;

			-- If Summary with ISSUE 
			IF l_summary.summaryFlag = 'I' THEN

				-- If there are no issues logged for the issue summary , log an issue
				BEGIN

					SELECT	1
					INTO 	l_dummy
					FROM	storage_log
					WHERE	target_id = l_summary.id
					AND	type = 'ISSUE'
					AND	ROWNUM = 1;
	
					-- If the summary computation has failed for more than STORAGE_SUMMARY.c_old_summary_days 
					-- Log an issue indicating from when the summary computation has failed
					IF l_summary.collection_timestamp IS NOT NULL AND l_summary.timestamp - l_summary.collection_timestamp > STORAGE_SUMMARY.c_old_summary_days THEN
						STORAGE_SUMMARY_DB.LOGISSUE(v_targetid,'Failed since '||l_summary.collection_timestamp);
					END IF;

				EXCEPTION
					WHEN NO_DATA_FOUND THEN

						IF l_errmsg IS NULL THEN
							l_errmsg := 'Failed to compute storage summary, Processing error ';
						END IF;	

						-- If the summary computation has failed for more than STORAGE_SUMMARY.c_old_summary_days 
						-- Log an issue indicating from when the summary computation has failed
						IF l_summary.collection_timestamp IS NOT NULL AND l_summary.timestamp - l_summary.collection_timestamp > STORAGE_SUMMARY.c_old_summary_days THEN
							l_errmsg := l_errmsg||', '||'Failed since '||l_summary.collection_timestamp;
						END IF;

						STORAGE_SUMMARY_DB.LOGISSUE(v_targetid,l_errmsg);


					WHEN OTHERS THEN
						RAISE_APPLICATION_ERROR(-20103,'Error fetching issues for the target '||v_targetname,TRUE);
				END;



			END IF;					

	END;

	----------------------------------------------------
	-- COUNT ISSUES AND WARNINGS FOR THE TARGET
	-- BUG, WHAT ABOUT ISSUES, WARNINGS LOGGED AFTER THIS , 
	-- THEY WILL NOT GET UPDATED TO THE HOST!!
	----------------------------------------------------
	-- issues and warnings
	BEGIN

		SELECT  NVL(SUM(DECODE(type,'ISSUE',1,0)),0),
			NVL(SUM(DECODE(type,'WARNING',1,0)),0)
		INTO	l_summary.issues,
			l_summary.warnings
		FROM 	storage_log
		WHERE	target_id = l_summary.id
		AND	type IN ('ISSUE','WARNING');

	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			NULL;
		WHEN OTHERS THEN
			RAISE_APPLICATION_ERROR(-20103,'Error fetching issues for the target '||v_targetname,TRUE);
	END;

	---------------------------------------------------------------
	-- Insert the summary object into reporting and history table
	---------------------------------------------------------------	
	STORAGE_SUMMARY_DB.INSERTSUMMARY(l_summary);	

	IF l_summary.summaryFlag = 'Y' THEN
		STORAGE_SUMMARY_DB.INSERTSUMMARYHISTORY(l_summary);
	END IF;

	STORAGE_SUMMARY_DB.LOG_TIME('calcstoragesummary',v_targetid,v_targetname,' Time to save summary',STORAGE_SUMMARY_DB.GETTIME(l_time));

	-----------------------------------------------------------------------
	--	COMPUTING SHARED STORAGE
	-----------------------------------------------------------------------

	------------------------------------------------------------------------
	-- DELETE THE PREVIOUS SHARED SUMMARIES FOR THIS TARGET
	------------------------------------------------------------------------	
	DELETE FROM storage_summaryObject 
	WHERE	id IN ( 
			SELECT	a.id
			FROM	stormon_host_groups b,			
				stormon_group_table a
			WHERE	a.type	= 'SHARED_GROUP'			
			AND	b.group_id = a.id
			AND	b.target_id = v_targetid
		);

	STORAGE_SUMMARY_DB.LOG_TIME('calcstoragesummary',v_targetid,v_targetname,' Time to delete old shared summaries for the target',STORAGE_SUMMARY_DB.GETTIME(l_time));

	----------------------------------------------------------------------------------------------------------
	-- DO NOT INCLUDE HOSTS WITH ISSUES OR HOSTS WITH PLACEHOLDER SUMMARIES
	----------------------------------------------------------------------------------------------------------
	IF NVL(l_summary.summaryFlag,'N') != 'Y' THEN

		STORAGE_SUMMARY_DB.LOG(v_targetid,'Skipping shared summary computation for  '||v_targetname);
		GOTO calc_group_summary;
		
	END IF;

	--------------------------------------------------------------
	-- Get the list of shared Disk keys for this target from Hosts
	-- with NO issues and not placeholder summaries
	--------------------------------------------------------------
	SELECT	DISTINCT a.diskkey
	BULK COLLECT INTO l_sharedDiskKeys
	FROM	storage_disk_table a
	WHERE	a.diskkey IN
		(
			SELECT	b.diskkey
			FROM	stormon_temp_disk b
			WHERE	target_id = v_targetid
			AND	status NOT LIKE '%DISK_OFFLINE%' 
			AND	status != 'NA'
		)
	AND a.target_id != v_targetid	
	AND EXISTS (
			SELECT 'x'
			FROM	storage_summaryObject
			WHERE	id = a.target_id
			AND	summaryFlag = 'Y'
		)	
	AND status NOT LIKE '%DISK_OFFLINE%' 
	AND status != 'NA';

	---------------------------------------------------------------
	-- If no shared disk keys then return
	---------------------------------------------------------------
	IF l_sharedDiskKeys IS NULL OR NOT l_sharedDiskKeys.EXISTS(1) THEN

		STORAGE_SUMMARY_DB.LOG(v_targetid,'No shared Disks for '||v_targetname);
		GOTO calc_group_summary;

	END IF;

	STORAGE_SUMMARY_DB.LOG_TIME('calcstoragesummary',v_targetid,v_targetname,' Time to fetch shared disk keys ',STORAGE_SUMMARY_DB.GETTIME(l_time));
	---------------------------------------------------------------
	-- Get the disk data for shared disks for this target with other 
	-- targets that do not have issues and not placeholder summaries
	---------------------------------------------------------------
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
	SELECT	NULL,			-- rowcount
		target_id,		-- target_id
		NULL,			-- target_name
		keyvalue,		-- keyvalue
		NULL,			-- collection_timestamp
		rawsizeb,		-- rawsizeb
		sizeb,			-- sizeb
		usedb,			-- usedb
		freeb,			-- freeb
		vendor,			-- vendor
		product,		-- product
		configuration,		-- configuration
		type,			-- type
		NULL,			-- filetype
		NULL,			-- linkinode
		NULL,			-- diskkey
		NULL,			-- path
		NULL,			-- status
		NULL,			-- parent
		FIRST_VALUE(backup) OVER (PARTITION BY keyvalue ORDER BY LENGTH(backup) DESC NULLS LAST) , -- backup
		NULL			-- freetype		
	FROM	storage_disk_table a,
		TABLE( CAST( l_sharedDiskkeys AS stringTable) ) b
	WHERE	a.diskkey = VALUE(b)
	AND	EXISTS (
				SELECT	'x'
				FROM	storage_summaryObject
				WHERE	id = a.target_id				
				AND	summaryFlag = 'Y'		
	);

	STORAGE_SUMMARY_DB.LOG_TIME('calcstoragesummary',v_targetid,v_targetname,' Time to fetch shared disk data  ',STORAGE_SUMMARY_DB.GETTIME(l_time));
	---------------------------------------------------------------
	-- If no shared disk data then return
	---------------------------------------------------------------
	BEGIN

		SELECT	1
		INTO	l_dummy
		FROM	stormon_temp_disk
		WHERE 	ROWNUM = 1;

	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			STORAGE_SUMMARY_DB.LOG(v_targetid,'No shared disk data for '||v_targetname);
			GOTO calc_group_summary;
	END;

	---------------------------------------------------------------
	-- This is a redundant check if Hosts > 1
	---------------------------------------------------------------
	BEGIN

		SELECT COUNT( DISTINCT a.target_id )
		INTO l_dummy
		FROM stormon_temp_disk a
		HAVING COUNT( DISTINCT a.target_id ) > 1;

		------------------------------------------------------------------
		-- If the number of hosts is > 6 then dont compute shared summary
		------------------------------------------------------------------
		IF l_dummy > c_max_shared_hosts  THEN
			STORAGE_SUMMARY_DB.LOG(v_targetid,'Hosts sharing storage with '||v_targetname||' is > '||c_max_shared_hosts||', '||l_dummy||' , skipping shared storage ');
			GOTO calc_group_summary;
		END IF;

		STORAGE_SUMMARY_DB.LOG(v_targetid,l_dummy||' Hosts has share storage with '||v_targetname);

		------------------------------------------------------------------
		-- Fetch the list of hosts sharign storage
		------------------------------------------------------------------		
		SELECT	DISTINCT a.target_id	
		BULK COLLECT INTO l_hostlist	
		FROM stormon_temp_disk a;	

		IF l_hostlist IS NULL OR NOT l_hostlist.EXISTS(2) THEN
			RAISE NO_DATA_FOUND;
		END IF;
		----------------------------------------------------------------------------
		-- Log warning message that this Host has shared storage with n other hosts
		----------------------------------------------------------------------------
		FOR i IN l_hostlist.FIRST..l_hostlist.LAST LOOP
			STORAGE_SUMMARY_DB.LOG(v_targetid,'Hosts sharing storage with '||v_targetname||' are '||l_hostlist(i));
		END LOOP;

	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			STORAGE_SUMMARY_DB.LOG(v_targetid,'No Shared disk data for '||v_targetname);
			GOTO calc_group_summary;	
	END;

	-- Fetch the common volumes, swraid, filesystems, database files based on 
	-- shared disks

	----------------------------------------------------------
	--		SHARED SWRAID DISKS
	----------------------------------------------------------	
	-- should get the disk as well as subdisks
	DELETE FROM stormon_temp_swraid;

	INSERT INTO stormon_temp_swraid (
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
	SELECT	NULL,			-- rowcount
		target_id,		-- target_id
		NULL,			-- target_name
		keyvalue,		-- keyvalue
		NULL,			-- collection_timestamp
		rawsizeb,		-- rawsizeb
		sizeb,			-- sizeb
		usedb,			-- usedb
		freeb,			-- freeb
		NULL,			-- vendor
		NULL,			-- product
		NULL,			-- configuration
		type,			-- type
		NULL,			-- filetype
		NULL,			-- linkinode
		NULL,			-- diskkey
		NULL,			-- path
		NULL,			-- status
		NULL,			-- parent
		FIRST_VALUE(backup) OVER (PARTITION BY keyvalue ORDER BY LENGTH(backup) DESC NULLS LAST) , -- backup
		NULL			-- freetype		
	FROM	storage_swraid_table a
	WHERE 	EXISTS
		(
			SELECT	1
			FROM	stormon_temp_disk c,
				storage_swraid_table b
			WHERE	b.type = 'SUBDISK'
			AND 	b.target_id = a.target_id
			AND 	c.target_id = b.target_id
			AND 	c.keyvalue = b.keyvalue			
			AND 	DECODE(a.type,'SUBDISK',a.parent,a.keyvalue) = b.parent
		);

	STORAGE_SUMMARY_DB.LOG_TIME('calcstoragesummary',v_targetid,v_targetname,' Time to fetch shared swraid data  ',STORAGE_SUMMARY_DB.GETTIME(l_time));
	------------------------------------------------------------
	--	SHARED VOLUMES
	------------------------------------------------------------
	-- Issue , should get both the disks, disk slices as well as volumes
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
	SELECT	NULL,				-- rowcount
		target_id,			-- target_id
		NULL,				-- target_name
		keyvalue,			-- keyvalue
		NULL,				-- collection_timestamp
		type,				-- type
		NULL,				-- name
		diskgroup,			-- diskgroup
		rawsizeb,			-- rawsizeb
		sizeb,				-- sizeb
		usedb,				-- usedb
		freeb,				-- freeb
		NULL,				 -- path
		NULL,				-- linkinode
		NULL,				--filetype
		NULL,				-- configuration
		NULL,				-- diskname
		FIRST_VALUE(backup) OVER (PARTITION BY keyvalue ORDER BY LENGTH(backup) DESC NULLS LAST) , -- backup
		NULL				--freetype
	FROM	storage_volume_table a
	WHERE	type IN ('VOLUME','DISKSLICE','DISK')
	AND 	EXISTS
		(
			SELECT	1
			FROM	(
                                        SELECT  c.target_id,
                                                c.keyvalue
                                        FROM    stormon_temp_disk c
                                        UNION
                                        SELECT  d.target_id,
                                                d.keyvalue
                                        FROM    stormon_temp_swraid d
                                        WHERE   d.type IN ('DISK','PARTITION')
                                ) c,
				storage_volume_table b
			WHERE	b.target_id = a.target_id
			AND 	b.diskgroup = a.diskgroup
			AND 	b.type = 'DISK'
			AND 	c.target_id = b.target_id
			AND 	c.keyvalue = b.keyvalue			
		);

	STORAGE_SUMMARY_DB.LOG_TIME('calcstoragesummary',v_targetid,v_targetname,' Time to fetch shared volume data  ',STORAGE_SUMMARY_DB.GETTIME(l_time));
	----------------------------------------------------------
	--	SHARED FILESYSTEMS
	----------------------------------------------------------
	DELETE FROM stormon_temp_filesystem;

	INSERT INTO stormon_temp_filesystem(
	rowcount		,
  	target_id		, /* is RAW(16) in git3       */
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
        SELECT	NULL,				-- rowcount
		target_id,			-- target_id
		NULL,				-- target_name
		keyvalue,			-- keyvalue
		NULL,				-- collection_timestamp
		type,				-- type
		NULL,				-- filesystem
		NULL,				-- linkinode
		rawsizeb,			-- rawsizeb
		sizeb,				-- sizeb
		usedb,				-- usedb
		freeb,				-- freeb
		NULL,				-- mountpoint
		NULL,				-- mointpointid
		NULL,				-- mounttype
		NULL,				-- privilege
		NULL,				-- server
		NULL,				-- vendor
		NULL,				-- nfscount
		FIRST_VALUE(backup) OVER (PARTITION BY keyvalue ORDER BY LENGTH(backup) DESC NULLS LAST)  -- backup		
	FROM	storage_localfs_table a
        WHERE   EXISTS
                (
                        SELECT  1
                        FROM    (
                                        SELECT  c.target_id,
                                                c.keyvalue
                                        FROM    stormon_temp_disk c
                                        UNION
                                        SELECT  d.target_id,
                                                d.keyvalue
                                        FROM    stormon_temp_swraid d
                                        WHERE   d.type IN ('DISK','PARTITION')
					UNION
					SELECT	e.target_id,
						e.keyvalue
					FROM	stormon_temp_volume e 
					WHERE	e.type IN ('VOLUME')
                                ) b
                        WHERE   b.target_id = a.target_id
                        AND	b.keyvalue = a.keyvalue
                );

	STORAGE_SUMMARY_DB.LOG_TIME('calcstoragesummary',v_targetid,v_targetname,' Time to fetch shared filesystem data  ',STORAGE_SUMMARY_DB.GETTIME(l_time));
	--------------------------------------------------------------
	--	SHARED APPLICATIONS ( ORACLE DATABASES )
	--------------------------------------------------------------
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
        SELECT	NULL,                           -- rowcount
                target_id,                      -- target_id
                NULL,                           -- target_name
		NULL,				-- database target name
                parentkey,                      -- parentkey
                keyvalue,                       -- keyvalue
                NULL,                           -- collection_timestamp
                NULL,                           -- type
                NULL,                           -- appname
                NULL,                           -- appid
                NULL,                           -- filename
		NULL,				-- filetype
                NULL,                           -- linkinode
                rawsizeb,                       -- rawsizeb
                sizeb,                          -- sizeb
                usedb,                          -- usedb
                freeb,                          -- freeb
                NULL,                           -- tablespace
                FIRST_VALUE(backup) OVER (PARTITION BY keyvalue ORDER BY LENGTH(backup) DESC NULLS LAST)  -- backup        
	FROM    storage_application_table a
        WHERE   grouping_id = 0 -- Leave out the total records
	AND	EXISTS
                (
                        SELECT  1
                        FROM    (
                                        SELECT  c.target_id,
                                                c.keyvalue
                                        FROM    stormon_temp_disk c
                                        UNION
                                        SELECT  d.target_id,
                                                d.keyvalue
                                        FROM    stormon_temp_swraid d
                                        WHERE   d.type IN ('DISK','PARTITION')
                                        UNION
                                        SELECT  e.target_id,
                                                e.keyvalue
                                        FROM    stormon_temp_volume e
                                        WHERE   e.type = 'VOLUME'
                                        UNION
                                        SELECT  e.target_id,
                                                e.keyvalue
                                        FROM    stormon_temp_filesystem e
                                ) b
                        WHERE   b.target_id = a.target_id
                        AND     b.keyvalue = a.parentkey
                );

	STORAGE_SUMMARY_DB.LOG_TIME('calcstoragesummary',v_targetid,v_targetname,' Time to fetch shared application data  ',STORAGE_SUMMARY_DB.GETTIME(l_time));
	-- Build a consistent list of keys for the shared
		
	-- Do a common consistency check for all keys
	----------------------------------------------------------------
	-- 	COMPUTE SHARED SUMMARY FOR ALL COMBINATIONS OF HOSTS
	----------------------------------------------------------------	
	FOR i IN 2..l_hostlist.LAST LOOP
			     
		createcomb(l_hostlist,l_combinationTable,l_combination,i,1,1);

		IF l_combinationTable IS NULL OR NOT l_combinationTable.EXISTS(1) 
		THEN
			GOTO end_host_loop;
		END IF;
		
		FOR j IN l_combinationTable.FIRST..l_combinationTable.LAST LOOP
			
			l_combination := l_combinationTable(j);

			IF l_combination IS NULL OR NOT l_combination.EXISTS(1) 		
			THEN
				STORAGE_SUMMARY_DB.LOG(v_targetid,'Null combination');
				GOTO end_comb_loop;
			END IF;

			-- Initialize the summary Object
			l_combSummary := summaryObject(NULL,v_targetname,NULL,SYSDATE,l_maxMetricTimestamp,1,1,0,0,'Y',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);

			l_combSummary.id := STORAGE_SUMMARY_DB.GET_HOST_GROUP_ID(l_combination,'SHARED_GROUP');

			l_count 			:= l_combination.COUNT;
			l_combSummary.hostcount 	:= l_count;
			l_combsummary.actual_targets	:= l_count;

			-------------------------------------------------------------------
			-- SHOULD A SUMMARY BE COMPUTED FOR THIS COMBINATION ?
			-------------------------------------------------------------------
			-- Check if the combination has current target v_targetid, else skip this combination
			BEGIN
				 
				SELECT	1
				INTO	l_dummy
				FROM	DUAL
				WHERE	EXISTS (
					SELECT	1
					FROM	TABLE( CAST( l_combination AS stringTable ) ) a
					WHERE	VALUE(a) = v_targetid
					);
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					-- If not does a summary exist for this combination
					BEGIN
						SELECT	1
						INTO	l_dummy
						FROM	dual
						WHERE	NOT EXISTS (
							SELECT	1
							FROM	storage_summaryObject 
							WHERE	id = l_combSummary.id
							);

					EXCEPTION
						WHEN NO_DATA_FOUND THEN
							GOTO end_comb_loop;	
					END;
			END;


			-- Cannot have dynamic SQL for collection tables		

			-------------------------------------------------------------------
			--  FETCH THE COMMON DISKS IN ALL THE HOSTS IN THE COMBINATION
			-------------------------------------------------------------------
			SELECT  a.keyvalue
			BULK COLLECT INTO l_sharedDiskKeys
			FROM	(
					SELECT DISTINCT a.target_id  target_id,
							a.keyvalue   keyvalue
					FROM   stormon_temp_disk a
				) a,
				TABLE( CAST( l_combination AS stringTable ) ) b
			WHERE	a.target_id = VALUE(b)
			GROUP BY 
				a.keyvalue
			HAVING	COUNT(*) = l_count;

			-- If no shared disk keys at this point we should go to the next iteration TBD
		
			DELETE FROM stormon_temp_comb_disk;

			BEGIN

				INSERT INTO stormon_temp_comb_disk (
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
				SELECT	rowcount		,	
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
				FROM	stormon_temp_disk a,
					TABLE( CAST( l_sharedDiskKeys AS stringTable ) ) b ,
					TABLE( CAST( l_combination AS stringTable ) ) c
				WHERE	a.keyvalue = VALUE(b)
				AND	a.target_id = VALUE(c);

				SELECT	1
				INTO	l_dummy
				FROM	stormon_temp_comb_disk
				WHERE	ROWNUM = 1;

			EXCEPTION
				WHEN OTHERS THEN
					STORAGE_SUMMARY_DB.LOG(v_targetid,'No common disk data for this combination '||l_combSummary.id);
					GOTO end_comb_loop;			
			END;

			-- Get the swraid, volume , filesystem, applications common to this
	
			---------------------------------------------------
			--	COMMON SWRAID DISKS
			---------------------------------------------------
			-- should get the disk as well as subdisks

			DELETE FROM stormon_temp_comb_swraid;

			INSERT INTO stormon_temp_comb_swraid(
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
			SELECT	rowcount		,	
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
			FROM	stormon_temp_swraid a
			WHERE 	EXISTS
			(
				SELECT	1
				FROM	stormon_temp_swraid b,
					stormon_temp_comb_disk c
				WHERE 	c.target_id = a.target_id
				AND 	b.target_id = c.target_id
				AND 	b.keyvalue = c.keyvalue			
				AND	b.type = 'SUBDISK'
				AND 	DECODE(a.type,'SUBDISK',a.parent,a.keyvalue) = b.parent
			);

			-----------------------------------------------------
			--	COMMON VOLUMES
			-----------------------------------------------------
			-- Get both the disks, and volumes

			DELETE FROM stormon_temp_comb_volume;

			INSERT INTO stormon_temp_comb_volume(
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
			SELECT	rowcount		,
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
			FROM	stormon_temp_volume a
			WHERE 	EXISTS
			(
				SELECT	1
				FROM	stormon_temp_volume b,
				(

                                        SELECT  target_id,
                                                keyvalue
					FROM 	stormon_temp_comb_disk
                                        UNION
                                        SELECT  target_id,
                                                keyvalue
					FROM 	stormon_temp_comb_swraid 
                                        WHERE   type IN ('DISK','PARTITION')
                                ) c
				WHERE	c.target_id = a.target_id
				AND 	b.target_id = c.target_id
				AND 	b.keyvalue = c.keyvalue			
				AND	b.type = 'DISK'
				AND	b.diskgroup = a.diskgroup
			);

			--------------------------------------------------------
			-- 	COMMON FILESYSTEMS
			--------------------------------------------------------

			DELETE FROM stormon_temp_comb_filesystem;

			INSERT INTO stormon_temp_comb_filesystem(
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
			SELECT	rowcount		,
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
			FROM	stormon_temp_filesystem a
        		WHERE   EXISTS
                	(
				SELECT  1
                        	FROM    (
	                                        SELECT  target_id,
	                                                keyvalue
						FROM 	stormon_temp_comb_disk
	                                        UNION
	                                        SELECT  target_id,
	                                                keyvalue
						FROM 	stormon_temp_comb_swraid
	                                        WHERE   type IN ('DISK','PARTITION')
						UNION
						SELECT	target_id,
							keyvalue
						FROM	stormon_temp_comb_volume 
						WHERE	type IN ('VOLUME')
	                                ) b
	                        WHERE   b.target_id = a.target_id
	                        AND	b.keyvalue = a.keyvalue
	                );

			----------------------------------------------------------
			-- 	COMMON APPLICATIONS
			----------------------------------------------------------

			DELETE FROM stormon_temp_comb_app;

			INSERT INTO stormon_temp_comb_app(
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
			SELECT	rowcount		,
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
			FROM	stormon_temp_app a
		        WHERE   EXISTS
			(
				SELECT  1
				FROM    (
						SELECT  target_id,
							keyvalue
						FROM 	stormon_temp_comb_disk 
						UNION
						SELECT  target_id,
							keyvalue
						FROM 	stormon_temp_comb_swraid 
						WHERE   type IN ('DISK','PARTITION')
						UNION
						SELECT  target_id,
							keyvalue
						FROM	stormon_temp_comb_volume 
						WHERE   type IN ('VOLUME')
						UNION
						SELECT  target_id,
							keyvalue
						FROM	stormon_temp_comb_filesystem 
					) b
				WHERE   b.target_id = a.target_id
				AND     b.keyvalue = a.parentkey
			);

			-----------------------------------------------------------
			--	COMPUTE SUMMARY FOR SHARED STORAGE
			-----------------------------------------------------------
			-- Calculate the storagesummary for this combination
--			IF l_combsharedDisks IS NOT NULL AND l_combSharedDisks.EXISTS(1) THEN
	
			-- Summary for all shared disks for this combination
				SELECT	
				NVL(ROUND(SUM(DECODE(type,'DISK',rawsizeb,0)),0),0), 	-- rawsizeb
				NVL(ROUND(SUM(DECODE(type,'DISK',sizeb,0)),0),0),	-- sizeb
				NVL(ROUND(SUM(freeb),0),0)				-- freeb	
				INTO	l_combsummary.disk_rawsize,
					l_combsummary.disk_size,
					l_combsummary.disk_free
				FROM	( 
					SELECT	type,
						keyvalue,
						AVG(rawsizeb)	rawsizeb,
						AVG(sizeb)	sizeb,
						AVG(freeb)	freeb		
					FROM	stormon_temp_comb_disk
					WHERE	type IN ('DISK','PARTITION')
					GROUP BY	type,
							keyvalue
					);

				l_combsummary.disk_used		:= l_combsummary.disk_size - l_combsummary.disk_free;	

			-- Summary rawsize and freesize for all backup disks mounted on the host

				SELECT	NVL(ROUND(SUM(rawsizeb),0),0), 	-- rawsizeb
					NVL(ROUND(SUM(sizeb),0),0)	-- sizeb
				INTO	l_combsummary.disk_backup_rawsize,
					l_combsummary.disk_backup_size
				FROM	( 
						SELECT	keyvalue,
							AVG(rawsizeb)	rawsizeb,
							AVG(sizeb)	sizeb
						FROM	stormon_temp_comb_disk
						WHERE	type IN ('DISK')
						AND	NVL(backup,'N') = 'Y'
						GROUP BY	
						keyvalue
					);


			-- Summary of Disk Storage by VENDOR		 

				FOR rec IN ( 
						SELECT	a.storagevendor||'-'||a.storageproduct vendor,		-- vendor
							NVL(ROUND(SUM(a.rawsizeb)),0) rawsizeb,			-- rawsizeb
							NVL(ROUND(SUM(a.sizeb)),0) sizeb,			-- sizeb
							NVL(ROUND(SUM(a.freeb)),0) freeb			-- freeb
						FROM   	( 
								SELECT	keyvalue,
									storagevendor,
									storageproduct,
									AVG(rawsizeb)	rawsizeb,
									AVG(sizeb)	sizeb,
									AVG(freeb)	freeb		
								FROM	stormon_temp_comb_disk
								WHERE	type IN ('DISK')	
								GROUP BY	
								keyvalue,
								storagevendor,
								storageproduct
							) a
						GROUP BY
						a.storagevendor,
						a.storageproduct
				)
				LOOP
			
					CASE
						WHEN UPPER(rec.vendor) LIKE '%EMC%' THEN
							l_combsummary.vendor_emc_size		:= l_combsummary.vendor_emc_size + NVL(rec.sizeb,0);
							l_combsummary.vendor_emc_rawsize 	:= l_combsummary.vendor_emc_rawsize + NVL(rec.rawsizeb,0);	
						WHEN	UPPER(rec.vendor) LIKE '%T300%'  OR
							UPPER(rec.vendor) LIKE '%A1000%'  OR
							UPPER(rec.vendor) LIKE '%D1000%'
							THEN
							l_combsummary.vendor_sun_size		:= l_combsummary.vendor_sun_size + NVL(rec.sizeb,0);
							l_combsummary.vendor_sun_rawsize	:= l_combsummary.vendor_sun_rawsize + NVL(rec.rawsizeb,0);
						WHEN	UPPER(rec.vendor) LIKE '%HITACHI%' THEN
							l_combsummary.vendor_hitachi_size	:= l_combsummary.vendor_hitachi_size + NVL(rec.sizeb,0);
							l_combsummary.vendor_hitachi_rawsize	:= l_combsummary.vendor_hitachi_rawsize + NVL(rec.rawsizeb,0);
						ELSE
							l_combsummary.vendor_others_size	:= l_combsummary.vendor_others_size + NVL(rec.sizeb,0);
							l_combsummary.vendor_others_rawsize	:= l_combsummary.vendor_others_rawsize + NVL(rec.rawsizeb,0);
					END CASE;
			
				END LOOP;

			--END IF;

		-- Summary rawsize and size,freesize of all nonbackup disks mounted on the host

			--IF l_combsharedswraid IS NOT NULL AND l_combsharedswraid.EXISTS(1) THEN

				SELECT	NVL(ROUND(SUM(DECODE(type,'SUBDISK',rawsizeb,0)),0),0), 	-- rawsizeb
					NVL(ROUND(SUM(DECODE(type,'DISK',sizeb,0)),0),0),		-- sizeb
					NVL(ROUND(SUM(freeb),0),0)					-- freeb	
				INTO	l_combsummary.swraid_rawsize,
					l_combsummary.swraid_size,
					l_combsummary.swraid_free
				FROM	( 
						SELECT	type,
							keyvalue,
							AVG(rawsizeb)	rawsizeb,
							AVG(sizeb)	sizeb,
							AVG(freeb)	freeb		
						FROM 	stormon_temp_comb_swraid
						WHERE	NVL(backup,'N') = 'N'
						GROUP BY
						type,
						keyvalue
					);

				l_combsummary.swraid_used 	:= l_combsummary.swraid_size - l_combsummary.swraid_free;
	
			--END IF;

		-- Summary for volumes
			--IF l_combsharedvolumes IS NOT NULL AND l_combsharedvolumes.EXISTS(1) THEN

				SELECT	NVL(ROUND(SUM(DECODE(type,'DISK',rawsizeb,0)),0),0),	-- rawsizeb
					NVL(ROUND(SUM(DECODE(type,'DISK',freeb,sizeb)),0),0),	-- sizeb
					NVL(ROUND(SUM(freeb),0),0)				-- freeb	
				INTO	l_combsummary.volumemanager_rawsize,
					l_combsummary.volumemanager_size,
					l_combsummary.volumemanager_free
				FROM	(	
						SELECT	type,
							keyvalue,
							AVG(rawsizeb)	rawsizeb,
							AVG(sizeb)	sizeb,
							AVG(usedb)	usedb,
							AVG(freeb)	freeb
						FROM	stormon_temp_comb_volume
						WHERE	type IN ('VOLUME','DISK')
						AND	NVL(backup,'N') = 'N'
						GROUP BY
						keyvalue,
						type
					);

				l_combsummary.volumemanager_used	:= l_combsummary.volumemanager_size - l_combsummary.volumemanager_free;

			--END IF;

		-- Summary for shared databases
			--IF l_combsharedApplications IS NOT NULL AND l_combsharedapplications.EXISTS(1) THEN

				SELECT	NVL(SUM(b.rawsizeb),0),			-- rawsizeb
					NVL(SUM(b.sizeb),0),			-- sizeb
					NVL(SUM(b.usedb),0),			-- usedb
					NVL(SUM(b.freeb),0)			-- freeb
				INTO	l_combsummary.oracle_database_rawsize,
					l_combsummary.oracle_database_size,
					l_combsummary.oracle_database_used,
					l_combsummary.oracle_database_free
				FROM   (
						SELECT	keyvalue,
							NVL(ROUND(AVG(a.rawsizeb)),0) rawsizeb,
							NVL(ROUND(AVG(a.sizeb)),0) sizeb,
							NVL(ROUND(AVG(a.usedb)),0) usedb,
							NVL(ROUND(AVG(a.freeb)),0) freeb
						FROM	stormon_temp_comb_app a
						WHERE	NVL(a.backup,'N') = 'N'
						GROUP BY	
						a.keyvalue
				) b;

			--END IF;

		-- Summary of all filesystems
			--IF l_combsharedFilesystems IS NOT NULL AND l_combsharedFilesystems.EXISTS(1) THEN

				SELECT	NVL(SUM(rawsizeb),0),	-- rawsizeb
					NVL(SUM(sizeb),0) ,	-- sizeb
					NVL(SUM(usedb),0) ,	-- usedb
					NVL(SUM(freeb),0) 	-- freeb
				INTO	l_combsummary.local_filesystem_rawsize,
					l_combsummary.local_filesystem_size,
					l_combsummary.local_filesystem_used,
					l_combsummary.local_filesystem_free
				FROM	(
						SELECT	keyvalue,
							NVL(ROUND(AVG(a.rawsizeb)),0) rawsizeb,
							NVL(ROUND(AVG(a.sizeb)),0) sizeb,
							NVL(ROUND(AVG(a.usedb)),0) usedb,
							NVL(ROUND(AVG(a.freeb)),0) freeb
						FROM	stormon_temp_comb_filesystem a
						WHERE	LOWER(NVL(a.type,'X')) != 'nfs'
						AND	NVL(backup,'N') = 'N'
						GROUP BY
						a.keyvalue
					);

			-- END IF;


			-- Presently Shared NFS is not computed 
			-- Future enhancement

			-- Total raw, size , free
			l_combsummary.rawsize	:= l_combsummary.disk_rawsize + l_combsummary.nfs_exclusive_size;
			l_combsummary.sizeb	:= l_combsummary.disk_size + l_combsummary.nfs_exclusive_size;
			l_combsummary.free 	:= l_combsummary.disk_free +
							l_combsummary.disk_backup_free +
							l_combsummary.swraid_free +
							l_combsummary.volumemanager_free +
							l_combsummary.application_free +
							l_combsummary.oracle_database_free +
							l_combsummary.local_filesystem_free +
							l_combsummary.nfs_exclusive_free;
	
			l_combsummary.used 	:= l_combsummary.sizeb - l_combsummary.free;

			---------------------------------------------------------
			-- Add the signt to the shared ID 
			-- -2+3-4....etc, Even numbers are negative
			---------------------------------------------------------
			IF ( MOD(l_combsummary.hostcount,2) = 0 ) THEN

				STORAGE_SUMMARY_DB.PRINTSTMT('Shared summary '||l_combsummary.id||' Has an even host count of '||l_combination.COUNT);

				l_combsummary.application_rawsize	:= -1 * l_combsummary.application_rawsize;
				l_combsummary.application_size		:= -1 * l_combsummary.application_size;
				l_combsummary.application_used		:= -1 * l_combsummary.application_used;
				l_combsummary.application_free		:= -1 * l_combsummary.application_free;
				l_combsummary.oracle_database_rawsize	:= -1 * l_combsummary.oracle_database_rawsize;
				l_combsummary.oracle_database_size	:= -1 * l_combsummary.oracle_database_size;
				l_combsummary.oracle_database_used	:= -1 * l_combsummary.oracle_database_used;
				l_combsummary.oracle_database_free	:= -1 * l_combsummary.oracle_database_free;
				l_combsummary.local_filesystem_rawsize	:= -1 * l_combsummary.local_filesystem_rawsize;
				l_combsummary.local_filesystem_size	:= -1 * l_combsummary.local_filesystem_size;
				l_combsummary.local_filesystem_used	:= -1 * l_combsummary.local_filesystem_used;
				l_combsummary.local_filesystem_free	:= -1 * l_combsummary.local_filesystem_free;
				l_combsummary.nfs_exclusive_size	:= -1 * l_combsummary.nfs_exclusive_size;
				l_combsummary.nfs_exclusive_used	:= -1 * l_combsummary.nfs_exclusive_used;
				l_combsummary.nfs_exclusive_free	:= -1 * l_combsummary.nfs_exclusive_free;
				l_combsummary.nfs_shared_size		:= -1 * l_combsummary.nfs_shared_size;
				l_combsummary.nfs_shared_used		:= -1 * l_combsummary.nfs_shared_used;
				l_combsummary.nfs_shared_free		:= -1 * l_combsummary.nfs_shared_free;
				l_combsummary.volumemanager_rawsize	:= -1 * l_combsummary.volumemanager_rawsize;
				l_combsummary.volumemanager_size	:= -1 * l_combsummary.volumemanager_size;
				l_combsummary.volumemanager_used	:= -1 * l_combsummary.volumemanager_used;
				l_combsummary.volumemanager_free	:= -1 * l_combsummary.volumemanager_free;
				l_combsummary.swraid_rawsize		:= -1 * l_combsummary.swraid_rawsize;
				l_combsummary.swraid_size		:= -1 * l_combsummary.swraid_size;
				l_combsummary.swraid_used		:= -1 * l_combsummary.swraid_used;
				l_combsummary.swraid_free		:= -1 * l_combsummary.swraid_free;
				l_combsummary.disk_backup_rawsize	:= -1 * l_combsummary.disk_backup_rawsize;
				l_combsummary.disk_backup_size		:= -1 * l_combsummary.disk_backup_size;
				l_combsummary.disk_backup_used		:= -1 * l_combsummary.disk_backup_used;
				l_combsummary.disk_backup_free		:= -1 * l_combsummary.disk_backup_free;
				l_combsummary.disk_rawsize		:= -1 * l_combsummary.disk_rawsize;
				l_combsummary.disk_size			:= -1 * l_combsummary.disk_size;
				l_combsummary.disk_used			:= -1 * l_combsummary.disk_used;
				l_combsummary.disk_free			:= -1 * l_combsummary.disk_free;
				l_combsummary.rawsize			:= -1 * l_combsummary.rawsize;
				l_combsummary.sizeb			:= -1 * l_combsummary.sizeb;
				l_combsummary.used			:= -1 * l_combsummary.used;
				l_combsummary.free			:= -1 * l_combsummary.free;
				l_combsummary.vendor_emc_size		:= -1 * l_combsummary.vendor_emc_size;
				l_combsummary.vendor_emc_rawsize	:= -1 * l_combsummary.vendor_emc_rawsize;
				l_combsummary.vendor_sun_size		:= -1 * l_combsummary.vendor_sun_size;
				l_combsummary.vendor_sun_rawsize	:= -1 * l_combsummary.vendor_sun_rawsize;
				l_combsummary.vendor_hp_size		:= -1 * l_combsummary.vendor_hp_size;
				l_combsummary.vendor_hp_rawsize		:= -1 * l_combsummary.vendor_hp_rawsize;
				l_combsummary.vendor_hitachi_size	:= -1 * l_combsummary.vendor_hitachi_size;
				l_combsummary.vendor_hitachi_rawsize	:= -1 * l_combsummary.vendor_hitachi_rawsize;
				l_combsummary.vendor_others_size	:= -1 * l_combsummary.vendor_others_size;
				l_combsummary.vendor_others_rawsize	:= -1 * l_combsummary.vendor_others_rawsize;
				l_combsummary.vendor_nfs_netapp_size	:= -1 * l_combsummary.vendor_nfs_netapp_size;
				l_combsummary.vendor_nfs_emc_size	:= -1 * l_combsummary.vendor_nfs_emc_size;
				l_combsummary.vendor_nfs_sun_size	:= -1 * l_combsummary.vendor_nfs_sun_size;
				l_combsummary.vendor_nfs_others_size	:= -1 * l_combsummary.vendor_nfs_others_size;	 	

			END IF;	

			STORAGE_SUMMARY_DB.PRINTSTMT(' INSERTING SUMMARY FOR '||l_combsummary.id||' size = '||l_combsummary.sizeb);

			STORAGE_SUMMARY_DB.INSERTSUMMARY(l_combSummary);
			STORAGE_SUMMARY_DB.INSERTSUMMARYHISTORY(l_combsummary);

			l_combination.DELETE;		
			
			<<end_comb_loop>>
			NULL;
		END LOOP;

		l_combinationTable.DELETE;

		<<end_host_loop>>
		NULL;
	END LOOP;

	----------------------------------------------------------------------------------
	--	INSERT NULL SHARED SUMMARIES FOR THOSE SHARED ID'S NOT PRESENT ANYMORE , 
	--	THIS IS TO GET A BETTER AVERAGE FOR HISTORY POINTS
	--	THAN IF THESE SUMMARIES DIDNT EXIST
	--	SUMMARYFLAG = Y , ISSUES = 0 ( => Include it in history computation )
	----------------------------------------------------------------------------------
	-- Initialize the summary Object
	l_combSummary := summaryObject(NULL,v_targetname,NULL,SYSDATE,l_maxMetricTimestamp,1,1,0,0,'Y',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);

	-- Fetch the shared ids for this target, which do not have summaries
	FOR rec IN ( 
			SELECT	DISTINCT a.id,
				a.host_count
			FROM	stormon_host_groups b,
				stormon_group_table a
			WHERE	a.type = 'SHARED_GROUP'
			AND	b.group_id = a.id
			AND	b.target_id = v_targetid					
			AND     NOT EXISTS
				(
					SELECT  1
					FROM    storage_summaryObject
					WHERE   id = a.id
				)
		)		
	LOOP

		l_combSummary.id 		:= rec.id;
		l_combSummary.hostcount 	:= rec.host_count;
		l_combsummary.actual_targets	:= rec.host_count;

		STORAGE_SUMMARY_DB.INSERTSUMMARY(l_combSummary);
		STORAGE_SUMMARY_DB.INSERTSUMMARYHISTORY(l_combsummary);

	END LOOP;

	-------------------------------------------------------------
	-- COMPUTE STORAGE FOR REPORTING GROUPS HAVING THIS TARGETS
	-------------------------------------------------------------
<<calc_group_summary>>

	STORAGE_SUMMARY_DB.LOG_TIME('calcstoragesummary',v_targetid,v_targetname,' Time for computing shared storage',STORAGE_SUMMARY_DB.GETTIME(l_time));

	STORAGE_SUMMARY_DB.PRINTSTMT('Computing Group summary '||v_targetname);

	-- Fetch all the groups for this target, except the SHARED_GROUP
	SELECT DISTINCT a.id
	BULK COLLECT INTO l_groupIdList
	FROM    stormon_host_groups b,
		stormon_group_table a        	
	WHERE   a.type != 'SHARED_GROUP'
	AND	b.group_id = a.id
	AND     b.target_id = v_targetid;

	IF l_groupIdList IS NOT NULL AND l_groupIdList.EXISTS(1) THEN

		STORAGE_SUMMARY_DB.PRINTSTMT('No. of groups found for '||v_targetname||' = '||l_groupIdList.COUNT);

		FOR i IN l_groupIdList.FIRST..l_groupIdList.LAST LOOP

			BEGIN

				STORAGE_SUMMARY.COMPUTE_GROUP_SUMMARY(l_groupIdList(i));

			EXCEPTION
				WHEN OTHERS THEN

					l_errmsg := 'Failed computing summary for group '||l_groupIdList(i)||' '||SUBSTR(SQLERRM,1,2048);

					STORAGE_SUMMARY_DB.LOGERROR(l_groupIdList(i),l_errmsg);

					-- TBD Should we insert a dummy summary for the GROUP ???			
		
			END;

		END LOOP;

	END IF;

	-- Log messages
	STORAGE_SUMMARY_DB.LOG_TIME('calcstoragesummary',v_targetid,v_targetname,' Time for computing reporting Group Summary',STORAGE_SUMMARY_DB.GETTIME(l_time));

	---------------------------------------------------------------
	--	END STORAGE COMPUTATION
	---------------------------------------------------------------
<<end_calcstoragesummary>>

	------------------------------------------------
	-- Commit All the Transactions for this Host
	------------------------------------------------
	COMMIT;
	
	-- Log the time taken to summarize the host
	STORAGE_SUMMARY_DB.LOG_TIME('calcstoragesummary',v_targetid,v_targetname,' Summarized ',STORAGE_SUMMARY_DB.GETTIME(l_elapsedtime));

EXCEPTION

	WHEN OTHERS THEN

		-- Rollback all the main transactions
		ROLLBACK;

		l_errmsg := 'Rolling back the transaction for '||v_targetname||' ,'||SUBSTR(SQLERRM,1,2048);

		-- Log the error
		STORAGE_SUMMARY_DB.LOGERROR(v_targetid,l_errmsg);

		-- Log the time taken for this host
		STORAGE_SUMMARY_DB.LOG_TIME('calcstoragesummary',v_targetid,v_targetname,' Processed ',STORAGE_SUMMARY_DB.GETTIME(l_elapsedtime));

END calcstoragesummary;

BEGIN
	NULL;
END storage_summary;
/

SHOW ERROR;
