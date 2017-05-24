DECLARE

l_hosttable	stringTable := stringTable('ss','dlsun1170.us.oracle.com','lothar.us.oracle.com','rmdc-oem01.us.oracle.com','sm2sun01.us.oracle.com','rmdcbkp6.us.oracle.com','gede.us.oracle.com','pebblebeach.us.oracle.com','raj.us.oracle.com','sunray3.us.oracle.com','eagle1-pc.us.oracle.com','miata.us.oracle.com');

l_targetIdList	stringTable;

l_id		VARCHAR2(20);

l_time		INTEGER := 0;

BEGIN

	l_time	:= STORAGE_SUMMARY.GETTIME(l_time);

	l_id := STORAGE_REPORT.GETGROUPID(l_hostTable);

	DBMS_OUTPUT.PUT_LINE('Time for fetching group id '||STORAGE_SUMMARY.GETTIME(l_time));

	FOR rec IN ( SELECT name, sizeb, issues FROM storage_summaryObject WHERE id = l_id ) LOOP

		DBMS_OUTPUT.PUT_LINE(rec.name||' '||rec.sizeb||' issues='||rec.issues);

	END LOOP;

	DBMS_OUTPUT.PUT_LINE('Time for fetching group summary '||STORAGE_SUMMARY.GETTIME(l_time));

	SELECT target_id
	BULK COLLECT INTO l_targetIdList
	FROM	mgmt_targets_view,
		TABLE( CAST ( L_hostTable AS stringTable ) ) b
	WHERE	target_name = VALUE(b);

	DBMS_OUTPUT.PUT_LINE('Time for fetching ids '||STORAGE_SUMMARY.GETTIME(l_time));

	FOR i IN l_targetIdList.FIRST..l_targetIdList.LAST LOOP

		FOR rec IN ( SELECT name, collection_timestamp, NVL(summaryflag,'N') summaryflag ,issues, sizeb, free FROM storage_summaryObject WHERE id = l_targetIdList(i) ) LOOP

			DBMS_OUTPUT.PUT_LINE(rec.name||' '||rec.collection_timestamp||' '||rec.summaryflag||' '||rec.issues||' '||rec.sizeb||' '||rec.free);

		END LOOP;

	END LOOP;

	DBMS_OUTPUT.PUT_LINE('Time for fetching summaried for targets per ID '||STORAGE_SUMMARY.GETTIME(l_time));

--	FOR rec IN ( SELECT name, collection_timestamp, NVL(summaryflag,'N') summaryflag ,issues, sizeb, free FROM TABLE (CAST(l_targetIdList AS stringTable) ) b, storage_summaryObject WHERE id = VALUE(b) ) LOOP

--		DBMS_OUTPUT.PUT_LINE(rec.name||' '||rec.collection_timestamp||' '||rec.summaryflag||' '||rec.issues||' '||rec.sizeb||' '||rec.free);

--	END LOOP;

--	DBMS_OUTPUT.PUT_LINE('Time for fetching summaried for targets In one SQL '||STORAGE_SUMMARY.GETTIME(l_time));

END;
/
