CLEAR BREAKS;

SET PAGESIZE 80;
SET LINESIZE 180;

BREAK ON id ON name ON task ; 

SELECT	* 
FROM	( 
	SELECT  id,
		name,
		message,
		ROUND(MAX(time_seconds)) max_time,
		ROUND(MIN(time_seconds)) min_time,
		ROUND(AVG(time_seconds)) avg_time,
		COUNT(*)	  cnt
	FROM	storage_stats_view
	WHERE	job_name = 'rollup'
	GROUP BY
		id,
		name,
		message
	)
WHERE	avg_time > 0
ORDER BY
avg_time ASC,
id,
name,
message
/
