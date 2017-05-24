-- Status of these hosts for outsourcing

SET ECHO OFF
SET TERMOUT OFF
SET FEEDBACK OFF
SET VERIFY OFF

SET LINESIZE 80
SET PAGESIZE 66

CLEAR BREAKS;
CLEAR COLUMNS;
CLEAR COMPUTES;
TTITLE OFF;
REPH OFF;
BTITLE OFF;

BREAK ON TODAY
COLUMN TODAY NEW_VALUE _DATE
SELECT TO_CHAR(FROM_TZ( CAST ( SYS_EXTRACT_UTC(SYSTIMESTAMP)-(8/24) AS TIMESTAMP ) , '-8:00'), 'fmMonth DD, HH:MI:SS PM TZR TZD')||'PST' TODAY FROM DUAL;
CLEAR BREAKS

COLUMN current_epm NEW_VALUE _current_epm
SELECT '1.5.8.0' current_epm
FROM DUAL;

SPOOL $HOME/tmp/stormon_health_report.lis

----REPORT 1
SET NEWPAGE 1

TTITLE RIGHT 'PAGE:' SQL.PNO SKIP 1  RIGHT _date SKIP 1 CENTER 'STORMON JOB STATUS - SUMMARY' SKIP 1 CENTER '----------------------------------------------' SKIP 2;

COLUMN status FORMAT a60 HEADING 'Stormon Status' WORD_WRAPPED;
COLUMN job_count FORMAT 9999 HEADING 'No.of Jobs';

BREAK ON REPORT;
COMPUTE SUM OF job_count ON REPORT;

SELECT	status,
	COUNT(*) job_count
FROM	stormon_summary_status_view
WHERE	status != 'IGNORE'
GROUP BY
	status
ORDER BY
	status
/

CLEAR BREAKS;
CLEAR COLUMNS;
CLEAR COMPUTES;



----REPORT 2

SET NEWPAGE 0;

TTITLE RIGHT 'PAGE:' SQL.PNO SKIP 1 RIGHT _date SKIP 1 CENTER 'SPREAD OF SCHEDULED STORMON JOBS'  SKIP 1 CENTER '------------------------------------------------' SKIP 2;

-- Spread of the currently scheduled jobs
COLUMN time_of_day FORMAT a20 HEADING 'Time of the day|(HH24:MI) PST';
COLUMN count_all FORMAT 9999 HEADING 'Jobs|Scheduled';
COLUMN comments FORMAT a40 HEADING 'Remarks' WORD_WRAPPED;
--COLUMN count_1 FORMAT 9999 HEADING 'No Job|Scheduled';
--COLUMN count_2 FORMAT 9999 HEADING 'No Job executed|in last 24 Hrs';
--COLUMN count_3 FORMAT 9999 HEADING 'Job May| have timed out';
--COLUMN count_4 FORMAT 9999 HEADING 'Job May have|failed to execute';
--COLUMN count_5 FORMAT 9999 HEADING 'May have failed|in summary comp.';
--COLUMN count_6 FORMAT 9999 HEADING 'Sumary later|than collection';
--COLUMN count_7 FORMAT 9999 HEADING 'Successful|Hosts';


BREAK ON REPORT;
COMPUTE SUM OF count_all count_1 count_2 count_3 ON REPORT;


SELECT	TO_CHAR(start_time-(8/24),'HH24:MI') time_of_day, 
	COUNT(*) count_all,
	DECODE(SIGN(COUNT(*)-150),1,'*** Jobs over 150 ***',NULL) comments
FROM	stormon_summary_status_view
WHERE	start_time IS NOT NULL
GROUP BY
	TO_CHAR(start_time-(8/24),'HH24:MI')
ORDER BY 
	1 ASC
/

CLEAR BREAKS;
CLEAR COLUMNS;
CLEAR COMPUTES;

----REPORT 3

SET NEWPAGE 0;

TTITLE RIGHT 'PAGE:' SQL.PNO SKIP 1  RIGHT _date SKIP 1 CENTER 'HOSTS WITH PROBLEMS IN STORAGE SUMMARY' SKIP 1 CENTER '--------------------------------------------------' SKIP 1 CENTER  _PROBLEM SKIP 2;
BTITLE SKIP 1 LEFT '* - Install Latest version of stormon epm ' _current_epm SKIP 1;

COLUMN node_name HEADING 'Host' FORMAT a20;
COLUMN target_type HEADING 'Job|Target|type' FORMAT a11;
COLUMN summary_time FORMAT a12 HEADING 'Valid|Summary Time|PST';
COLUMN starttime FORMAT a12 HEADING 'OEM Job|Time|PST';
COLUMN job_duration FORMAT 9999999 HEADING 'Job|Duration|(Secs)';
COLUMN job_name FORMAT a30 HEADING 'Job Name';
COLUMN epm_version FORMAT a12 HEADING 'EPM';
--COLUMN status FORMAT a45 HEADING 'Problem';
COLUMN status NEW_VALUE _PROBLEM NOPRINT;

COMPUTE NUMBER OF target_name ON STATUS;
BREAK ON status SKIP PAGE;

SELECT	status,
	SUBSTR(node_name,1,20) 	  	node_name,					
	DECODE(target_type,'oracle_sysman_database','db - '||SUBSTR(target_name,1,6),'oracle_sysman_node','host',NULL) 	target_type,					
	DECODE(epm_version,'&_current_epm',epm_version,NVL(epm_version,'No EPM')||'*') epm_version,
	TO_CHAR(collection_timestamp-(tz/24)-(8/24),'DD-MON HH24:MI') summary_time,
	TO_CHAR(start_time-(8/24),'DD-MON HH24:MI') starttime,
	job_duration
FROM	stormon_summary_status_view
WHERE	status NOT IN ('IGNORE','Successfully Summarized Jobs')
ORDER BY
DECODE(
status,
'FAILED-Metrics loaded , but Summary Computation Failed',1,
'FAILED-Job Executed , but no metrics loaded',2,
'FAILED-stormon Job not executed in Last 24 Hours',3,
'FAILED-stormon Job Missing',4,
5),
start_time,
job_duration
;

SPOOL OFF;

CLEAR BREAKS;
CLEAR COLUMNS;
CLEAR COMPUTES;
TTITLE OFF;
REPH OFF;
BTITLE OFF;
SET NEWPAGE 1

@setts

EXIT;

--ed $HOME/tmp/stormon_health_report.lis

