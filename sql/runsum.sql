DECLARE

l_hosttable	stringTable := stringTable(
						'dlsun1170.us.oracle.com',
						'lothar.us.oracle.com',
						'rmdc-oem01.us.oracle.com',						
						'rmdcbkp6.us.oracle.com',	
						'rmdcbkp5.oracle.com',	
						'gede.us.oracle.com',
						'miata.us.oracle.com',
						'eagle1-pc.us.oracle.com',
						'raj.us.oracle.com',
						'sunray3.us.oracle.com',
						'pebblebeach.us.oracle.com');

l_hostidtable	stringTable := stringTable(
						'10000001',
						'10000002',
						'10000003',
						'1377',
						'1392',
						'10000004',
						'10000005',
						'10000006',
						'10000007',
						'10000008',
						'10000009'
					);
BEGIN

	FOR i IN l_hostTable.FIRST..l_hostTable.LAST LOOP

		STORAGE_SUMMARY.CALCSTORAGESUMMARY(l_hostTable(i),l_hostidtable(i));

	END LOOP;

END;
/
