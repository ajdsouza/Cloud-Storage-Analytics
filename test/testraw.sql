		SELECT
			mt.target_id target_guid,
			TRUNC(collection_timestamp,'MON') timestamp,
			value value
		FROM
			mgmt_metrics_raw ,
			mgmt_targets	mt			
		WHERE    
			mt.target_name = 'target_100'
			AND target_guid = mt.target_id
			AND metric_guid = 4088	
			AND collection_timestamp BETWEEN to_date('05:29:2001','MM:DD:YYYY') AND to_date('05:31:2002','MM:DD:YYYY')
/

		SELECT
			mt.target_id target_guid,
			TRUNC(collection_timestamp,'MON') timestamp,
			value value
		FROM
			mgmt_metrics_raw ,
			mgmt_targets	mt			
		WHERE    
			mt.target_name in ( 'target_100','target_99','target_98','target_97','target_96','target_95','target_94','target_93','target_92','target_91','target_90')
			AND target_guid = mt.target_id
			AND metric_guid = 4088
			AND collection_timestamp BETWEEN to_date('05:29:2001','MM:DD:YYYY') AND to_date('05:31:2002','MM:DD:YYYY')
/
	
