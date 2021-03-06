
SET ECHO OFF;
SET TERMOUT OFF;
SET FEEDBACK OFF;
SET VERIFY ON;

CLEAR COLUMNS;
CLEAR BREAKS;
TTITLE OFF;
BTITLE OFF;
REPH OFF;

COLUMN name FORMAT a35;
COLUMN type FORMAT a25;
COLUMN path FORMAT a25;
COLUMN target_id FORMAT a10;
COLUMN original_target_id FORMAT a10;
COLUMN mozart_target_id FORMAT a10;
COLUMN target_type FORMAT a25;
COLUMN composite_type FORMAT a25;
COLUMN target_name FORMAT a40;
COLUMN missing_targets FORMAT a40;
COLUMN member_target_name FORMAT a30;
COLUMN composite_name FORMAT a30;
COLUMN metric_name FORMAT a30;
COLUMN node_name FORMAT a40;
COLUMN id FORMAT a20;
COLUMN freetype FORMAT a20;
COLUMN backup FORMAT a1;
COLUMN configuration FORMAT a25;
COLUMN vendor FORMAT a30;
COLUMN filesystem FORMAT a60;
COLUMN mountpoint FORMAT a30;
COLUMN tablespace FORMAT a30;
COLUMN filename FORMAT a50;
COLUMN appname FORMAT a15;
COLUMN dbname FORMAT a15;
COLUMN appid FORMAT a15;
COLUMN dbid FORMAT a15;
COLUMN diskkey FORMAT a40;
COLUMN keyvalue FORMAT a60;
COLUMN parentkey FORMAT a60;
COLUMN parent  FORMAT a20;
COLUMN linkinode FORMAT a20;
COLUMN diskgroup format a20;
COLUMN message FORMAT a60;
COLUMN target_lob FORMAT a30;
COLUMN target_datacenter FORMAT a15;
COLUMN ipaddress FORMAT a16;
COLUMN LOCATION format a10;
COLUMN string_value format a30;
COLUMN metric_column format a38;
COLUMN groupid format a10;
COLUMN parameter format a30;
COLUMN value format a30;
COLUMN group_id format a30;
COLUMN old_id format a30;
COLUMN old_type format a30;
COLUMN new_id format a30;
COLUMN new_type format a30;
COLUMN new_name format a30;
COLUMN db_link format a30;
COLUMN host_count format 99999;
COLUMN parent_id format a10;
COLUMN child_id format a10;
column PEG format 99.99;
column PE_this_year format 99.9;
column Price_to_sales format 99.9;
column Profit_margin format 99.9;
COLUMN os format A20;
COLUMN time format A20;
COLUMN job format a15;
COLUMN file_name format a60;
COLUMN job_name format a40;
COLUMN task format a30;
COLUMN avg_time FORMAT 999999;
COLUMN max_time FORMAT 999999;
COLUMN min_time FORMAT 999999;
COLUMN max_col_time FORMAT a15;
COLUMN min_col_time FORMAT a15;
COLUMN property_name FORMAT a20;
COLUMN property_value FORMAT a30;
COLUMN host_name FORMAT a15;
COLUMN utc_time FORMAT a30;
COLUMN start_time FORMAT a20;
COLUMN end_time FORMAT a20;
COLUMN target_time FORMAT a30;
COLUMN operating_system FORMAT a15;
COLUMN datacenter FORMAT a15;
COLUMN support_group FORMAT a15;
COLUMN escalation_group FORMAT a15;
COLUMN owner FORMAT a10;
COLUMN business_owner FORMAT a12;
COLUMN ip_address FORMAT a16;
COLUMN make FORMAT a10;
COLUMN model FORMAT a10;
COLUMN target_guid FORMAT a25;
COLUMN object_name FORMAT a30;
COLUMN object FORMAT a30;
COLUMN timestamp FORMAT a30;
COLUMN timestamp FORMAT a30;
COLUMN column_name FORMAT A20;
COLUMN ENDPOINT_ACTUAL_VALUE FORMAT A50;
COLUMN mountpointid FORMAT a50;
COLUMN job_status FORMAT A40;
COLUMN finish_time FORMAT A15;
COLUMN finishtime FORMAT A15;
COLUMN start_time FORMAT A15;
COLUMN starttime FORMAT A15;
COLUMN duration FORMAT A8;
COLUMN next_exec_time FORMAT A20;
COLUMN node_id FORMAT A10;
COLUMN NEXT_EXECUTION_TIME FORMAT a20;
COLUMN Collection_timestamp FORMAT a20;
COLUMN summary_time FORMAT a15;
COLUMN summary_time_gmt FORMAT a15;
COLUMN mounttype FORMAT a30;
COLUMN privilege FORMAT a30;
COLUMN target FORMAT a40;
COLUMN other_mounts FORMAT a40;
COLUMN summary_status FORMAT A15;

set serverout on size 1000000
set linesize 200;
set pagesize 80;
set time on;

SET VERIFY ON;
SET FEEDBACK ON;
SET ECHO OFF;
SET TERMOUT ON;
