--  
--
-- Copyright  (c) 2001,2002  Oracle Corporation All rights reserved 
--
--
--
-- $Id: refresh_prod_master_data.sql,v 1.1 2003/07/07 16:53:33 ajdsouza Exp $ 
--
--
-- NAME  
--	 refresh_prod_master_data.sql
--
-- DESC 
--  Script to refresh the master tables in the stormon production database
--
--
-- FUNCTIONS
--
--
-- NOTES
--
--
-- MODIFIED	(MM/DD/YY)
-- ajdsouza	07/07/03 	- Created
--
--
-------------------------------------------------------------------------------------
--
--	Populate the cached tables from OEMDTC database using dblinks
--
--
--	mgmt_metrics is updates by executing perl script admetrics
--	mgmt_targets from mgmt_targets_new@oemdtc ( view at oemdtc)
--	node_target_map	from node_target_map@oemdtc ( view at oemdtc )
--	smp_vdt_job_per_target from smp_vdt_job_per_targe@oemdtc ( table at oemdtc )
--
-------------------------------------------------------------------------------------

-- mgmt_metrics is updated using the perl script addmetrics



-- Refreshing mgmt_targets
DELETE FROM mgmt_targets
/

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
SELECT	target_id		,
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
FROM	MGMT_TARGETS_NEW@OEMDTC.US.ORACLE.COM
/


-- Refreshing node_target_map
DELETE FROM node_target_map
/

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
FROM	node_target_map@OEMDTC.US.ORACLE.COM
/


-- Refreshing smp_vdj_job_per_target
DELETE FROM smp_vdj_job_per_target
/

INSERT INTO smp_vdj_job_per_target
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
SELECT	target_name,
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
FROM	smp_vdj_job_per_target@OEMDTC.US.ORACLE.COM	 
/

COMMIT;
