DECLARE

l_historysummaryobjects		storageSummaryTable;
l_sortedHistoryObjects		storageSummaryTable;

l_tableList			stringTable := stringTable('storage_history_52weeks');
l_formatList			stringTable := stringTable('D');

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

l_id 				stormon_group_table.id%TYPE;
				
BEGIN
	
	-- Rollback the changes fo the last transaction
	ROLLBACK;

	SELECT id INTO l_id FROM stormon_group_table WHERE name = 'ALL';

	DBMS_OUTPUT.PUT_LINE('Group Id '||l_id);

	DELETE FROM storage_history_52weeks WHERE id = l_id;

	INSERT INTO storage_summaryObject_history SELECT * FROM storage_summaryobject WHERE id = l_id;

	---------------------------------------------------------------------
	-- DELETE THE PREVIOUS DEBUG AND ERROR MESSAGES FOR RULLUP
	--------------------------------------------------------------------	

	DBMS_OUTPUT.PUT_LINE('Begining rollup job STORAGE_SUMMARY.ROLLUP, Rolling up targets and shared summaries ');

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
			AND	a.id = l_id
			GROUP BY 
			a.id,
			b.type,
			b.name	
			ORDER BY
			DECODE(b.type,'HOST',1,'SHARED_GROUP',2,3) ASC
		)
	LOOP	

		l_time := 0;
		l_elapsedtime := 0;

		l_elapsedtime := STORAGE_SUMMARY.GETTIME(l_time);

		DBMS_OUTPUT.PUT_LINE('Id = '||rec.id||' Rolling up between timestamps '
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
                                        DBMS_OUTPUT.PUT_LINE('Id = '||rec.id||' Failed to find the latest Object less than  '||TO_CHAR(rec.max_timestamp,'DD-MON-YY HH24:MI:SS')||' in storage_summaryobject_history ');
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
		
				DBMS_OUTPUT.PUT_LINE('Table = '||l_tablename);
				DBMS_OUTPUT.PUT_LINE('Format model '||l_formatmodel);

				-- Get the cut off history time
				IF UPPER(l_formatmodel) = 'D' THEN
	
				        l_cutofftime	:= TRUNC(rec.max_timestamp,l_formatmodel)-(53*7);
	
				ELSE
			                l_cutofftime	:= TRUNC(rec.max_timestamp,l_formatmodel)-32;
		
				END IF;
				
				DBMS_OUTPUT.PUT_LINE('Cutoff date '||TO_CHAR(l_cutofftime,'DD-MON-YY HH24:MI:SS'));
	
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

						DBMS_OUTPUT.PUT_LINE('No history found for '||rec.id|| ' in '||l_tablename);
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
				

				DBMS_OUTPUT.PUT_LINE('Start date '||TO_CHAR(l_starttime,'DD-MON-YY HH24:MI:SS'));		


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
			
					DBMS_OUTPUT.PUT_LINE('No of points '||l_npoints||' between '||TO_CHAR(l_starttime,'DD-MON-YY HH24:MI:SS')||' and '||
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
			
					DBMS_OUTPUT.PUT_LINE('History time end points '||TO_CHAR(l_tmtable(1),'DD-MON-YYYY HH24:MI:SS')||' And '||
							TO_CHAR(l_tmtable(l_npoints+1),'DD-MON-YYYY HH24:MI:SS'));
	
					----------------------------------------------------------------------------------
					--	COMPUTE THE SUMMARY OBJECTS FOR THIS TARGET ID IN THEN INTERVAL
					--	BETWEEN START TIME AND MAX TIMESTAMP IN STORAGE_SUMMARYOBJECT_HISTORY
					-----------------------------------------------------------------------------------
					DBMS_OUTPUT.PUT_LINE('Computing summary Objects for '||rec.id||' start time '||TO_CHAR(l_starttime,'DD-MON-YYYY HH24:MI:SS')||
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
		
						DBMS_OUTPUT.PUT_LINE('No of rows fetched from the history table '||l_historySummaryObjects.COUNT);
						DBMS_OUTPUT.PUT_LINE('Fetched data time end points '||TO_CHAR(l_historySummaryObjects(1).collection_timestamp,'DD-MON-YYYY HH24:MI:SS')||
							' And '||TO_CHAR(l_historySummaryObjects(l_historySummaryObjects.LAST).collection_timestamp,'DD-MON-YYYY HH24:MI:SS'));
					ELSE
						DBMS_OUTPUT.PUT_LINE('NO history data fetched');
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
	
					DBMS_OUTPUT.PUT_LINE('No of date points '||l_sortedHistoryObjects.COUNT);
	
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
								DBMS_OUTPUT.PUT_LINE('No Valid history point Found in Collection');
							
								IF l_lastHistoryObject IS NULL THEN	
	
									DBMS_OUTPUT.PUT_LINE(' id = '||rec.id||' No valid object to rollup history , skip to next table');
	
									GOTO next_table;
	
								END IF;
	
								DBMS_OUTPUT.PUT_LINE('Take the last rolledup object as history object');					
								l_value := l_lastHistoryObject;
						
						END;
				
	
						----------------------------------------------------------------------------------------------
						-- REPLACE ABSENT TIMESTAMPS WITH VALID SUMMARY OBJECTS FROM THE HIGHER COLLECTION_TIMESTAMP
						----------------------------------------------------------------------------------------------
						DBMS_OUTPUT.PUT_LINE('the dummy filler history object '||l_value.id);
				
					        FOR j IN REVERSE l_sortedhistoryObjects.FIRST..l_sortedhistoryObjects.LAST
			        		LOOP
							DBMS_OUTPUT.PUT_LINE('Filling for '||l_sortedhistoryObjects(j).collection_timestamp);

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
							DBMS_OUTPUT.PUT_LINE('All History points in collection are valid');
							NULL;
	
					END; -- END OF BLOCK FOR FILLING ABSENT TIMESTAMPS WITH VALID SUMMARIES
	
	
					IF l_sortedHistoryObjects IS NOT NULL AND l_sortedHistoryObjects.EXISTS(1) THEN
				
						-------------------------------------------------------------------------------------
						--	DELETE AND INSERT THE HISTORY OBJECTS INTO THE ROLLED UP HISTORY TABLE
						-------------------------------------------------------------------------------------
						DBMS_OUTPUT.PUT_LINE('Deleting/Inserting into '||l_tablename||' for '||rec.id);
	
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

						DBMS_OUTPUT.PUT_LINE('purging history below the cutoff line');

						EXECUTE IMMEDIATE 'DELETE FROM '||l_tablename||'
						WHERE	id = :1
						AND	collection_timestamp < :2 ' USING rec.id, l_cutofftime;

					EXCEPTION
						WHEN OTHERS THEN
							RAISE_APPLICATION_ERROR(-20101,'Failed to purge old History  from '||l_tablename||' for '||rec.id||' Before '||l_cutofftime);
					END;	


				END IF;


				<<next_table>>	
				DBMS_OUTPUT.PUT_LINE('Time taken to complete rollup for table '||l_tablename||' is '||STORAGE_SUMMARY.GETTIME(l_time));
						
				----------------------------------------------------------------------------------------------
				--	APPLY GROUP CORRECTION AT THIS POINT
				----------------------------------------------------------------------------------------------
				IF rec.type LIKE 'REPORTING%' THEN

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


					DBMS_OUTPUT.PUT_LINE('Time taken for fetching corrected group summaries for table '||l_tablename||' is '||STORAGE_SUMMARY.GETTIME(l_time));	

					IF l_correctedGroupSummaries IS NOT NULL AND l_correctedGroupSummaries.EXISTS(1) THEN

						-- DBMS_OUTPUT.PUT_LINE('Group id = '||rec.id||' NO of corrected summaries fetched '||l_correctedGroupSummaries.COUNT);

						FOR i IN l_correctedGroupSummaries.FIRST..l_correctedGroupSummaries.LAST LOOP
			
							DBMS_OUTPUT.PUT_LINE(' Group id = '||rec.id||' Inserting the corrected data '||
								l_correctedGroupSummaries(i).collection_timestamp||' '||
								l_correctedGroupSummaries(i).actual_targets||' '||
								l_correctedGroupSummaries(i).sizeb);

							BEGIN
				
							--	EXECUTE IMMEDIATE ' DELETE FROM '||l_tablename||' WHERE id = :id AND collection_timestamp = :collection_timestamp ' 
							--		USING	l_correctedGroupSummaries(i).id,
							--		l_correctedGroupSummaries(i).collection_timestamp;
								NULL;
				
							
							EXCEPTION
								WHEN OTHERS THEN
									RAISE_APPLICATION_ERROR(-20101,' Failed to delete from '||l_tablename||' for corrected summary '||
									l_correctedGroupSummaries(i).id||' for timestamp '||
									l_correctedGroupSummaries(i).collection_timestamp);
							END;


							BEGIN

							-- EXECUTE IMMEDIATE ' INSERT INTO '||l_tablename||' VALUES (:1) ' USING l_correctedGroupSummaries(i);
								NULL;

							EXCEPTION

								WHEN OTHERS THEN
									RAISE_APPLICATION_ERROR(-20101,' Failed to insert into '||l_tablename||' for corrected summary '||
									l_correctedGroupSummaries(i).id||' for timestamp '||
									l_correctedGroupSummaries(i).collection_timestamp);
						
							END;
				
						END LOOP;
				
					END IF;
					
					DBMS_OUTPUT.PUT_LINE(' Time taken for correcting group summaries in table '||l_tablename||' is '||STORAGE_SUMMARY.GETTIME(l_time));		

				END IF; -- End of the group correction

			END LOOP; -- ROLLUP HISTORY TABLE LOOP

			-----------------------------------------------------------------------
			-- PURGE FROM storage_summaryobjet_history ALL ROLLED UP HISTORY DATA 
			-----------------------------------------------------------------------
			BEGIN

				DBMS_OUTPUT.PUT_LINE('Deleting  From STORAGE_SUMMARYOBJECT_HISTORY '||rec.id);

				EXECUTE IMMEDIATE 'DELETE FROM storage_summaryobject_history WHERE id = :1 AND collection_timestamp >= :2 AND collection_timestamp <= :3 '
				USING rec.id,rec.min_timestamp,rec.max_timestamp;
	
			EXCEPTION
				WHEN OTHERS THEN
					RAISE_APPLICATION_ERROR(-20101,'Failed to purge rolled up History from storage_summaryoBject_history for '||rec.id||' between '||rec.min_timestamp||' and '||rec.max_timestamp);
			END;

			----------------------------------------------------------------------------
			-- COMMIT CHANGES , AFTER COMPLETING ROLLUP OF ALL HISTORY TABLES FOR A ID
			----------------------------------------------------------------------------
--			COMMIT;

		EXCEPTION
			-------------------------------------------------
			-- ROLLBACK AND SKIP TO THE NEXT TARGET
			-------------------------------------------------
			WHEN OTHERS THEN

				ROLLBACK;
	
				l_errmsg := 'Rolling back the history for '||rec.id||' error is '||SUBSTR(SQLERRM,1,2048);

				DBMS_OUTPUT.PUT_LINE('Id = '||rec.id||' '||l_errmsg);

		END;	-- END OF BLOCK FOR ALL PROCESSING FOR A TARGET

		DBMS_OUTPUT.PUT_LINE(' Time taken to rollup '||STORAGE_SUMMARY.GETTIME(l_elapsedtime));

	END LOOP;  -- TARGET LOOP

	DBMS_OUTPUT.PUT_LINE('End of execution of rollup job');

END;
/
