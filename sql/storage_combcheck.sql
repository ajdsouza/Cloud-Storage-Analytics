

CREATE OR REPLACE PACKAGE storage_combcheck AS

PROCEDURE CREATECOMB(
			v_hosts   INTEGER,
			v_position INTEGER,
			v_level	   INTEGER,
			v_hostlist stringTable,
			v_combination IN OUT stringTable,
			v_shareddetails IN detailTable);

PROCEDURE TEST( n  INTEGER);
PROCEDURE calcsharedstorage(v_combination IN stringTable,v_sharedDetails IN detailTable );
PROCEDURE teststorage( v_target_id NUMBER );

END storage_combcheck;
/


CREATE OR REPLACE PACKAGE BODY storage_combcheck AS

-- Generate all the combinations for the list of hosts passed 
-- for the number of hosts to chose
-- Generate the n C r combinations
PROCEDURE createcomb(
			v_hosts   INTEGER,		-- r at a time
			v_position INTEGER,		-- which array element
			v_level	   INTEGER,		-- the level of iteration
			v_hostList stringTable,		-- List of hosts, n number of hosts
			v_combination IN OUT stringTable,
			v_shareddetails IN detailTable
		)
IS

BEGIN

	-- Generate the combinations here if r = interation level
	IF  ( v_level = v_hosts ) THEN
	
		-- From the passed in array position to the end
		FOR i IN v_position..v_hostList.COUNT LOOP
			
			-- If no element to hold the current value
			-- extend it
			IF NOT v_combination.EXISTS(v_level) THEN
		
				v_combination.EXTEND;
	
			END IF;

			-- Copy the value
			v_combination(v_level) := v_hostList(i);
				
			-- Calculate the shared storage for this combination					
			STORAGE_COMBCHECK.CALCSHAREDSTORAGE(v_combination,v_shareddetails);	

		END LOOP;

	ELSE
		
		-- From the passed in array position to the end	
		FOR i IN v_position..(v_hostList.COUNT-(v_hosts-v_level)) LOOP

			-- If no element to hold the current value
			-- extend it	
			IF NOT v_combination.EXISTS(v_level) THEN
		
				v_combination.EXTEND;
	
			END IF;

			-- Copy the value
			v_combination(v_level) := v_hostList(i);
			
			-- Create the combination for the next level, 
			createcomb(v_hosts,i+1,v_level+1,v_hostList,v_combination,v_shareddetails);
	
		END LOOP;

	END IF;


END createcomb;


PROCEDURE teststorage( v_target_id NUMBER ) IS
	
	l_shareddetails		detailTable;
	l_hostlist		stringTable;
	l_combination		stringTable := stringTable();	

BEGIN

	EXECUTE IMMEDIATE 
	'SELECT 
	detailObject
	(
	target_id,
	detailtype,
	keyvalue,
	NULL,
	backup,
	type,
	filename,
	rawsizeb,
	sizeb,
	usedb,
	freeb,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL	
	)		
	FROM
	diskTable a
	WHERE
	a.keyvalue IS NOT NULL
	AND a.keyvalue IN 
	(
		SELECT	b.keyvalue
		FROM	TABLE( CAST( l_diskTable AS storageDiskTAble) ) b
		WHERE	b.kayvalue IS NOT NULL	
	)' BULK COLLECT INTO l_shareddiskTable;

	IF l_shareddetails IS NULL OR NOT l_shareddetails.EXISTS(1) THEN
		DBMS_OUTPUT.PUT_LINE('NO SHARDE DETAILS FOR '||v_target_id);
		RETURN;
	END IF;

	SELECT DISTINCT a.target_id
	BULK COLLECT INTO l_hostlist	
	FROM TABLE( CAST(l_shareddetails AS detailTable) ) a;

	IF l_hostlist IS NULL OR NOT l_hostlist.EXISTS(2) THEN
		DBMS_OUTPUT.PUT_LINE(' NO SHARED COUNT FOR '||v_target_id);
		RETURN;
	END IF;

	FOR i IN 2..l_hostlist.LAST LOOP
		             
		createcomb(i,1,1,l_hostlist,l_combination,l_shareddetails);

	END LOOP;

	IF l_combination IS NOT NULL AND l_combination.EXISTS(1) THEN
		l_combination.DELETE;
	END IF;


END teststorage;


PROCEDURE calcsharedstorage(v_combination IN stringTable,v_sharedDetails IN detailTable) IS

	l_combdetails	detailTable;
	l_count		NUMBER;

BEGIN

	IF	v_combination IS NULL OR NOT v_combination.EXISTS(1) OR
		v_shareddetails IS NULL OR NOT v_shareddetails.EXISTS(1)
	THEN
		RETURN;
	END IF;

	l_count := v_combination.COUNT;

	FOR i IN v_combination.FIRST..v_combination.LAST LOOP

		DBMS_OUTPUT.PUT(v_combination(i)||'-');

	END LOOP;

	DBMS_OUTPUT.NEW_LINE;	
	-- Cannot have dynamic SQL for collection tables	


	SELECT
	detailObject
	(
	NULL,
	a.detailtype,
	NULL,
	NULL,
	NULL,
	a.type,
	NULL,
	SUM(a.rawsizeb),
	SUM(a.sizeb),
	SUM(a.usedb),
	SUM(freeb),
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL
	)
	BULK COLLECT INTO l_combdetails
	FROM	(
		SELECT
		a.detailtype	detailtype,
		a.keyvalue	keyvalue,
		a.type		type,
		AVG(a.rawsizeb)	rawsizeb,
		AVG(a.sizeb)	sizeb,
		AVG(a.usedb)	usedb,
		AVG(freeb)	freeb
		FROM	TABLE( CAST( v_sharedDetails AS detailTable ) ) a,
			TABLE( CAST( v_combination AS stringTable) ) b
		WHERE	a.target_id = VALUE(b)
			AND a.keyvalue IS NOT NULL
		GROUP BY
			a.detailtype,
			a.type,
			a.keyvalue			
		HAVING	COUNT(*) = l_count
	) a
	GROUP BY
	a.detailtype,
	a.type;

	IF l_combdetails IS NULL OR NOT l_combdetails.EXISTS(1) THEN
		DBMS_OUTPUT.PUT_LINE('NOTHING IN COMMON FOR THIS COMBINATION');
		RETURN;
	END IF;	
	
	FOR i IN l_combdetails.FIRST..l_combdetails.LAST LOOP

		DBMS_OUTPUT.PUT(l_combdetails(i).detailtype||' ');
		DBMS_OUTPUT.PUT(l_combdetails(i).backup||' ');
		DBMS_OUTPUT.PUT(l_combdetails(i).type||' ');
		DBMS_OUTPUT.PUT(l_combdetails(i).rawsizeb||' ');
		DBMS_OUTPUT.PUT(l_combdetails(i).sizeb||' ');
		DBMS_OUTPUT.PUT(l_combdetails(i).usedb||' ');
		DBMS_OUTPUT.PUT(l_combdetails(i).freeb||' ');

		DBMS_OUTPUT.NEW_LINE;

	END LOOP;

END calcsharedstorage;



PROCEDURE test(n INTEGER) IS

	v_list  stringTable := stringTable();
	v_comb  stringTable := stringTable();

BEGIN

	v_list.EXTEND(n);
	
	FOR i IN 1..n LOOP

		v_list(i) := CHR(65+i-1);

	END LOOP;

	FOR i IN 2..v_list.LAST LOOP

		DBMS_OUTPUT.PUT_LINE(v_list.COUNT||'c'||i);
	             
		createcomb(i,1,1,v_list,v_comb,NULL);

	END LOOP;

END test;


END storage_combcheck;
/


