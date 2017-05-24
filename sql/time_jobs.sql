CLEAR BREAKS;

SET PAGESIZE 80;
SET LINESIZE 180;


SELECT  job_name,
        id,
        name,
        message,
	timestamp,
        time_seconds 
        FROM    storage_stats_view
        WHERE   job_name = 'hostrollupdata'
        AND     id = 'hostrollupdata'
ORDER BY
job_name,
id,
name,
message
/

BREAK ON id ON name ON task ; 

SELECT	* 
FROM	( 
	SELECT  job_name,
		id,
		name,
		message,
		ROUND(MAX(time_seconds)) max_time,
		ROUND(MIN(time_seconds)) min_time,
		ROUND(AVG(time_seconds)) avg_time,
		COUNT(*)	  cnt
	FROM	storage_stats_view
	WHERE	job_name = 'hostrollupdata'
	AND	id = 'hostrollupdata'
	GROUP BY
		job_name,
		id,
		name,
		message
	)
WHERE	avg_time > 0
ORDER BY
job_name,
id,
name,
message
/

