declare
  l_correctedGroupSummaries       storage_rep.storageSummaryTable;
  l_idList                        storage_rep.stringTable;
  l_id				  VARCHAR2(255);
  l_dateList			  storage_rep.dateTable;
begin

	SELECT id INTO l_id FROM stormon_group_table WHERE name = 'ALL';

	DBMS_OUTPUT.PUT_LINE ( 'Group id ' || l_id );


                                      -- This query to be tested
                                        SELECT  id
	      				BULK COLLECT INTO l_idList
                                        FROM    stormon_group_table a
                                        WHERE   type = 'SHARED_GROUP'
                                        AND     NOT EXISTS (
                                        -- Does this shared id have a target which is not in this group ?
                                                        SELECT  1
                                                        FROM    stormon_host_groups b
                                                        WHERE   b.group_id = a.id
                                                        AND     b.target_id NOT IN
                                                        (
                                                                SELECT  target_id
                                                                FROM    stormon_host_groups
                                                                WHERE   group_id = l_id
                                                        )
                                                )
                                        UNION
                                        SELECT  target_id
                                        FROM    stormon_host_groups
                                        WHERE   group_id = l_id;


                                   IF l_idList IS NULL OR NOT l_idList.EXISTS(1) THEN
                                     RAISE_APPLICATION_ERROR(-20101,'No Target and shared IDs found for this group '||l_id);
				   END IF;


	IF l_idList.EXISTS(1) THEN
		 DBMS_OUTPUT.PUT_LINE ( 'List of IDs for THIS group ' || l_idList.count );
	ELSE
		 DBMS_OUTPUT.PUT_LINE ( 'No ID''s exist for this group' );
		 RETURN;
	END IF;

				                        SELECT  a.collection_timestamp
							BULK COLLECT INTO l_dateList
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
									AND	c.id = l_id	
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
					                                WHERE   id = l_id
									AND	summaryFlag != 'L'					                                
				                        ) b
				                        WHERE   a.collection_timestamp = b.collection_timestamp
				                        AND     a.actual_targets >= b.actual_targets;
				                        
	IF l_dateList IS NOT NULL AND l_dateList.EXISTS(1) THEN
		DBMS_OUTPUT.PUT_LINE('Dates to be corrected in Split query '||l_dateList.COUNT);
	ELSE
		DBMS_OUTPUT.PUT_LINE('NO dates to be corrected in Split query ');
	END IF;

    SELECT storage_rep.summaryObject (
      NULL,                     -- rowcount
      'GROUP TOTAL',            -- name
      l_id,                   -- id
      SYSDATE,                  -- timestamp
      a.collection_timestamp,   -- collection_timestamp
      NULL,             -- hostcount
      NULL,         -- actual_targets
      NULL,                     -- No of hosts with issues
      NULL,                     -- No of hosts with warnings
      'Y',                      -- summaryFlag
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
      0,                          -- nfs_shared_size, no group summary
      0,
      0,                          -- nfs_shared_free, no group summary
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
      FROM storage_history_52weeks a,
      TABLE ( CAST ( l_dateList AS storage_rep.dateTable ) ) b,
      TABLE ( CAST ( l_idList AS storage_rep.stringTable ) ) c
      WHERE a.id  = VALUE(c)
      AND a.collection_timestamp = VALUE(b)
      AND a.summaryFlag != 'L'
      GROUP BY a.collection_timestamp;

  


		IF  l_correctedGroupSummaries.EXISTS(1) THEN

			DBMS_OUTPUT.PUT_LINE(' Data fetched in the Split corrected query '|| l_correctedGroupSummaries.COUNT);
	
		ELSE

			DBMS_OUTPUT.PUT_LINE(' No data fetched in the Split corrected query ');

		END IF;
 


	----------------------------------------------------------------------------------------
	--  COMBINED GROUP SUMMARY CORRECTION QUERY
	--
	----------------------------------------------------------------------------------------

						SELECT	storage_rep.summaryObject (
							NULL,						-- rowcount
							'GROUP TOTAL',					-- name
							l_id,						-- id
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
									AND	c.id = l_id	
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
					                                WHERE   id = l_id
									AND	summaryFlag != 'L'					                                
				                        ) b
				                        WHERE   a.collection_timestamp = b.collection_timestamp
				                        AND     a.actual_targets >= b.actual_targets
				                ) b,
						TABLE ( CAST ( l_idList AS storage_rep.stringTable ) ) c
						WHERE	a.id  = VALUE(c)
						AND	a.collection_timestamp = b.collection_timestamp
						AND	a.summaryFlag != 'L'
						GROUP BY
							a.collection_timestamp,
							b.host_count,
							b.actual_targets;	
      


		IF  l_correctedGroupSummaries.EXISTS(1) THEN

			DBMS_OUTPUT.PUT_LINE(' Data fetched in the Combined corrected query '|| l_correctedGroupSummaries.COUNT);
	
		ELSE

			DBMS_OUTPUT.PUT_LINE(' No data fetched in the Combined corrected query ');

		END IF;


END;
/
