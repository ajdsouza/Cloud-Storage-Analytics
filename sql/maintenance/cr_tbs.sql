--
-- Copyright  (c) 2001,2002  Oracle Corporation All rights reserved 
--
--
--
-- $Id: cr_tbs.sql,v 1.8 2003/08/18 16:36:08 ajdsouza Exp $ 
--
-- NAME  
--	 cr_tbs.sql
--
-- DESC
--	Create tabelspaces for the stormon user, 
--
--
-- MODIFIED	(MM/DD/YY)
-- ajdsouza	07/23/03 	- Created
--
--

-- Execute with dba privilege



--
-- ANALYZE TABLE <xx> COMPUTE STATISTICS
--
-- SELECT 	AVG_SPACE,
--		AVG_ROW_LEN,
--		NUM_ROWS,
--		BLOCKS ,
--		EMPTY_BLOCKS,
--		SAMPLE_SIZE
-- FROM		USER_TABLES
-- 
-- 
--
-- TABLE_NAME                      AVG_SPACE AVG_ROW_LEN   NUM_ROWS     BLOCKS EMPTY_BLOCKS SAMPLE_SIZE	ESTIMATED ROWS	  	ESTIMATED SIZE				Initial		
-- ------------------------------ ---------- ----------- ---------- ---------- ------------ ----------- ------------------  	--------------
-- MGMT_METRICS                         3229          72        131          2            1         131
-- MGMT_TARGETS                         4087          46        913         11            0         913
-- 
-- MGMT_CURRENT_METRICS                 6649          74      49379       3101          105       49379    9000000            	9000000*74		700MB		700M		
--	INDEX																		450MB		450MB 
--
-- STORAGE_HISTORY_30DAYS                889         326      50631       2311          895       50631    200000		200000*326		100MB		100M
-- STORAGE_HISTORY_52WEEKS               883         326      51031       2326          880       51031    200000		200000*326		100MB		100M
-- STORAGE_SUMMARYOBJECT                1055         316      30466       1379           55       30466	   30000		30000*316		15MB		15M
-- STORAGE_SUMMARYOBJECT_HISTORY        8036           0          0        956            0           0    30000		30000*316		15MB		15M
-- 
-- STORAGE_HOSTDETAIL                   2175          73         78          1            0          78    20000		20000*73		2MB		2M
-- STORMON_HOST_GROUPS                   882          25     100191        376           55      100191    100000		100000*25		3MB		3M
-- STORAGE_LOG                          4569         104       2622         81            5        2622    60000		60000*104		6MB		6M
-- 
-- STORAGE_DISK_TABLE                   1840         400        480         11            0         480	   150000		200000*400		80MB(*6)	80M
-- STORAGE_SWRAID_TABLE                 7827          150         3          1            0           3    150000
-- STORAGE_VOLUME_TABLE                 6804          150        37          3            0          37    150000
-- STORAGE_NFS_TABLE                       0           0          0          0            1           0    150000
-- STORAGE_LOCALFS_TABLE                6225          150        83          3            0          83    150000
-- STORAGE_APPLICATION_TABLE            5191         250         79          3            0          79    150000
-- STORAGE_STATISTICS			1260	      84	4594	    61	      12739	   4594	   3360000		3360000*75		252MB		250MB
-- 

-- Table space for all reporting tables
CREATE TABLESPACE data_storage DATAFILE '/home/oracle/9i/oradata/dev1/stormon/data_storage1.dbf' SIZE 2048M EXTENT MANAGEMENT LOCAL UNIFORM SIZE 128K SEGMENT SPACE MANAGEMENT AUTO
/
-- Tablespace for indices
CREATE TABLESPACE index_storage DATAFILE '/home/oracle/9i/oradata/dev1/stormon/index_storage1.dbf' SIZE 1536M EXTENT MANAGEMENT LOCAL UNIFORM SIZE 128K SEGMENT SPACE MANAGEMENT AUTO
/

--  Undo tablespace 3600 * 800K (100 Undo blocks /Sec) = 2.5G
CREATE UNDO TABLESPACE stormon_undo DATAFILE '/home/oracle/9i/oradata/dev1/stormon/undo1.dbf' SIZE 2000M REUSE
/

-- Temporary tablespace for sorting, we need a lot of temp space for the analysis job, especially the groupig operation
-- Extents are allocated in sizes of 1M till the max size is hit, so if you get ORA-1652 we need a bigger temporaty tablespace
-- eg. alter tablespace stormon_temp add tempfile '/u02/oracle/9i/oradata/dev1/stormon/temp2.dbf' SIZE 1024M

CREATE TEMPORARY TABLESPACE stormon_temp TEMPFILE '/home/oracle/9i/oradata/dev1/stormon/temp1.dbf' SIZE 400M REUSE EXTENT MANAGEMENT LOCAL UNIFORM SIZE 1M
/

-- SET THE INITIALIZATION PARAMETER UNDO_MANAGEMENT = AUTO 

ALTER SYSTEM SET UNDO_TABLESPACE = stormon_undo
/

ALTER SYSTEM SET UNDO_RETENTION = 3600
/

