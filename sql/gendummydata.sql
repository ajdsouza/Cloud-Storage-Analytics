DECLARE

	l_summaryObject	summaryObject;

BEGIN

	SELECT	VALUE(a)
	INTO	l_summaryObject
	FROM	storage_summaryObject a
	WHERE	id = 1377;

	l_summaryObject.name := 'DUMMY';

	FOR i IN 1..30000 LOOP

		SELECT stormonGroupId.NEXTVAL
		INTO	l_summaryObject.id
		FROM	dual;

		INSERT INTO storage_summaryObject VALUES(l_summaryObject);		

	END LOOP;


END;
/

COMMIT;

DECLARE

l_id	NUMBER;

BEGIN

	FOR i IN 1..50000 LOOP
		
		SELECT stormongroupid.NEXTVAL
		INTO l_id
		FROM DUAL;

		INSERT INTO stormon_host_groups VALUES(l_id,'TEST',2,'10000001');
		INSERT INTO stormon_host_groups VALUES(l_id,'TEST',2,'10000002');


	END LOOP;

END;
/

COMMIT;

DECLARE

l_summary	summaryObject;

BEGIN
	SELECT	VALUE(a)
	INTO	l_summary
	FROM	storage_summaryObject a
	WHERE	id = 20017;

	l_summary.name := 'DUMMY';

	FOR i IN 1..50000 LOOP
		
		SELECT stormongroupid.NEXTVAL
		INTO l_summary.id
		FROM DUAL;

		INSERT INTO storage_history_30days VALUES(l_summary);
		INSERT INTO storage_history_52weeks VALUES(l_summary);

		DBMS_OUTPUT.PUT_LINE(i);

	END LOOP;

END;
/

COMMIT;
