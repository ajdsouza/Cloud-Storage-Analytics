CLEAR BREAKS;

SET PAGESIZE 80;
SET LINESIZE 200;

COLUMN message FORMAT a50;

BREAK ON id ON name ON task SKIP 1; 

SELECT  a.id 	  id,
	b.name    name,
	b.message task,
	b.last_execution last_execution,
	b.avg_time,
	a.message,
	a.avg_time,
	a.max_time,
	a.min_time
FROM	
(
	SELECT 	job_name,
		id,
		name,
		message,
		ROUND(MAX(time_seconds)) max_time,
		ROUND(MIN(time_seconds)) min_time,
		ROUND(AVG(time_seconds)) avg_time,
		COUNT(*)	  cnt
	FROM	storage_stats_view
	WHERE	job_name IN ('calcstoragesummary')
	GROUP BY
		job_name,
		id,
		name,
		message
) a,
(
SELECT  job_name,
	id,
	name,
	message,
	ROUND(MAX(time_seconds)) max_time,
	ROUND(MIN(time_seconds)) min_time,
	ROUND(AVG(time_seconds)) avg_time,
	MAX(timestamp)		 last_execution,
	COUNT(*)	  cnt
FROM	storage_stats_view
WHERE	job_name = 'hostrollupdata'
GROUP BY
	job_name,
	id,
	name,
	message
) b
WHERE
a.id = b.id
AND b.avg_time > 0
ORDER BY
b.avg_time ASC,
b.id,
b.name,
b.message,
a.message
/

@setts
