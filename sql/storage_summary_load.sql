--  
--
-- Copyright  (c) 2001,2002  Oracle Corporation All rights reserved 
--
--
--
-- $Id: storage_summary_load.sql,v 1.2 2003/10/09 01:24:11 ajdsouza Exp $ 
--
--
-- NAME  
--	 storage_summary_load.sql
--
-- DESC 
--  DB I/O functions to parse and load the metrics to the repository
--
--
-- FUNCTIONS
--
--
-- NOTES
--
--
-- MODIFIED	(MM/DD/YY)
-- ajdsouza	10/08/03 	- Created package storage_summary_load 
--
--


CREATE OR REPLACE PACKAGE storage_summary_load AS

TYPE stringtable IS TABLE OF VARCHAR2(32767);
TYPE numbertable IS TABLE OF NUMBER;

FUNCTION delete_host_metrics ( 	v_target_id 		IN mgmt_targets.target_id%TYPE, 
				v_target_type 		IN mgmt_targets.target_type%TYPE,
				v_metric_name 		IN mgmt_metrics.metric_name%TYPE ) RETURN INTEGER;

FUNCTION delete_database_metrics (	v_target_id 		IN mgmt_targets.target_id%TYPE, 
					v_target_type 		IN mgmt_targets.target_type%TYPE,
					v_metric_name 		IN mgmt_metrics.metric_name%TYPE,
					v_application_metric_id	IN mgmt_metrics.metric_guid%TYPE,
					v_application_id 	IN mgmt_current_metrics.string_value%TYPE ) RETURN INTEGER;

PROCEDURE load_metrics ( v_target_id IN VARCHAR2, v_timestamp IN VARCHAR2, v_data_buffer IN LONG , v_field_separator IN VARCHAR2 DEFAULT '~~', v_row_separator IN VARCHAR2 DEFAULT '!!!');



END storage_summary_load;
/

CREATE OR REPLACE PACKAGE BODY storage_summary_load AS

FUNCTION parse_arguments(v_values_string IN VARCHAR2, v_separator IN VARCHAR2 DEFAULT '!' ) RETURN stringTable;	
FUNCTION get_target_id ( v_target_name IN VARCHAR2, v_target_type IN VARCHAR2 ) RETURN VARCHAR2;


--------------------------------------------------
-- Procedure Name : parse_arguments
-- Description    : 
--                  
--          INPUT : parse a argument to return a 
--		    string Array based on a separator
--------------------------------------------------
FUNCTION parse_arguments(v_values_string IN VARCHAR2, v_separator IN VARCHAR2 DEFAULT '!' ) RETURN stringTable IS

l_args_list	stringTable := stringTable();
l_sep_position	INTEGER;
l_values_string	VARCHAR2(32767);

BEGIN

	l_values_string := v_values_string;

	WHILE ( LENGTH(l_values_string) > 0 ) LOOP

		l_sep_position := INSTRB(l_values_string,v_separator);

		IF l_sep_position = 0 THEN
			l_sep_position := LENGTH(l_values_string)+1;
		END IF;

		l_args_list.EXTEND;
		l_args_list(l_args_list.LAST) := TRIM(' ' FROM SUBSTR(l_values_string,1,l_sep_position-1));
		l_values_string := TRIM(' ' FROM SUBSTR(l_values_string,l_sep_position+LENGTH(v_separator)));

	END LOOP;

	RETURN l_args_list;
	
END parse_arguments;


--------------------------------------------------------------
-- Procedure Name : get_target_id
-- Description    : 
--                  
--          INPUT : 
--		target_id, 
--		target_type
--------------------------------------------------------------
FUNCTION get_target_id ( v_target_name IN VARCHAR2, v_target_type IN VARCHAR2 ) RETURN VARCHAR2 IS

BEGIN

	RETURN NULL;

END get_target_id;


--------------------------------------------------------------
-- Function Name : delete_host_metrics
--		    delete_database_metrics
-- Description    : 
--         		Delete the metrics and return the number of rows deleted         
--          INPUT : 
--		target_id, 
--		target_type
--		metric_name to be deleted
--		metric_guid for application_id
--		application id for database applications
--------------------------------------------------------------
FUNCTION delete_host_metrics ( 	v_target_id 		IN mgmt_targets.target_id%TYPE, 
				v_target_type 		IN mgmt_targets.target_type%TYPE,
				v_metric_name 		IN mgmt_metrics.metric_name%TYPE ) 
RETURN INTEGER IS

BEGIN

	EXECUTE IMMEDIATE'
	DELETE	FROM	MGMT_CURRENT_METRICS 
	WHERE	TARGET_GUID = :1
	AND	METRIC_GUID IN ( 
			SELECT	METRIC_GUID
			FROM	MGMT_METRICS
			WHERE	TARGET_TYPE = :2 
			AND	METRIC_NAME = :3) ' USING v_target_id, v_target_type, v_metric_name;
	
	RETURN SQL%ROWCOUNT;

END delete_host_metrics;


FUNCTION delete_database_metrics (	v_target_id 		IN mgmt_targets.target_id%TYPE, 
					v_target_type 		IN mgmt_targets.target_type%TYPE,
					v_metric_name 		IN mgmt_metrics.metric_name%TYPE,
					v_application_metric_id	IN mgmt_metrics.metric_guid%TYPE,
					v_application_id 	IN mgmt_current_metrics.string_value%TYPE )
RETURN INTEGER IS

BEGIN

	EXECUTE IMMEDIATE '
	DELETE FROM MGMT_CURRENT_METRICS 
	WHERE	TARGET_GUID = :1 
	AND	METRIC_GUID IN( 
			SELECT METRIC_GUID 
                        FROM   MGMT_METRICS 
                        WHERE  TARGET_TYPE = :2 
                        AND    METRIC_NAME = :3) 
	AND	KEY_VALUE IN (
                        SELECT KEY_VALUE 
                        FROM   MGMT_CURRENT_METRICS   
                        WHERE  TARGET_GUID  = :1
                        AND    METRIC_GUID  = :4         
                        AND    STRING_VALUE = :5) ' USING v_target_id, v_target_type, v_metric_name, v_target_id, v_application_metric_id ,v_application_id;

	RETURN SQL%ROWCOUNT;

END delete_database_metrics;

--------------------------------------------------------------
-- Procedure Name : load_metrics
-- Description    : 
--                  
--          INPUT : 
--		target_id, 
--		timestamp, 
--		data buffer
--		field separatror
--		row_separator		    
--------------------------------------------------------------
PROCEDURE load_metrics ( v_target_id IN VARCHAR2, v_timestamp IN VARCHAR2, v_data_buffer IN LONG , v_field_separator IN VARCHAR2 DEFAULT '~~', v_row_separator IN VARCHAR2 DEFAULT '!!!') IS

l_data_rows     stringtable := stringTable();
l_columns       stringTable := stringTable();
l_key_value 	stringtable := stringTable();
l_value         stringTable := stringTable();
l_metric_guid   numberTable := numberTable();

BEGIN 

	l_data_rows := STORAGE_SUMMARY_LOAD.PARSE_ARGUMENTS(v_data_buffer,v_row_separator);
                                                
        -- No data to load here
        IF l_data_rows IS NULL OR NOT l_data_rows.EXISTS(1) THEN
              RETURN;
        END IF;

        l_key_value.EXTEND(l_data_rows.COUNT);
        l_value.EXTEND(l_data_rows.COUNT);
	l_metric_guid.EXTEND(l_data_rows.COUNT);

        FOR i IN l_data_rows.FIRST..l_data_rows.LAST LOOP
                                                    
             l_columns := PARSE_ARGUMENTS(l_data_rows(i),v_field_separator);
                                                     
             IF l_columns IS NULL OR NOT l_columns.EXISTS(3) THEN
                  RAISE_APPLICATION_ERROR(-20101,'Data to load may not have either of key, value or metric guid '||l_data_rows(i));
             END IF;

             l_key_value(i) := l_columns(1);
             l_value(i) := l_columns(2);
             l_metric_guid(i) := TO_NUMBER(l_columns(3));
                                                     
        END LOOP;

	FORALL i IN l_key_value.FIRST..l_key_value.LAST  
         INSERT INTO MGMT_CURRENT_METRICS(TARGET_GUID,METRIC_GUID,COLLECTION_TIMESTAMP,KEY_VALUE,VALUE,STRING_VALUE)  
	 VALUES (v_target_id , l_metric_guid(i), TO_DATE( v_timestamp,'MM:DD:YYYY HH24:MI:SS') ,l_key_value(i) ,l_value(i) ,l_value(i) );

  RETURN;

END load_metrics;


END storage_summary_load;
/
