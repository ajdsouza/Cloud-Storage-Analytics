--
--
-- Copyright  (c) 2001,2002  Oracle Corporation All rights reserved 
--
--
--
-- $Id: storage_new.sql,v 1.153 2003/10/25 01:51:09 ajdsouza Exp $ 
--
--
--
--

DROP TYPE tab_object_table
/
DROP TYPE tab_object
/
DROP TYPE report_object_table
/
DROP TYPE report_object
/
DROP TYPE display_object_table
/
DROP TYPE display_object
/

DROP TYPE titletable
/
DROP TYPE title_object
/

DROP TYPE storage_reporting_results
/
DROP TYPE storage_reporting_table_object
/

CREATE TYPE storage_reporting_table_object AS OBJECT (
field1	VARCHAR2(2000),
field2	VARCHAR2(2000),
field3	VARCHAR2(2000),
field4	VARCHAR2(2000),
field5	VARCHAR2(2000),
field6	VARCHAR2(2000),
field7	VARCHAR2(2000),
field8	VARCHAR2(2000),
field9	VARCHAR2(2000),
field10	VARCHAR2(2000),
field11	VARCHAR2(2000),
field12	VARCHAR2(2000),
field13	VARCHAR2(2000),
field14	VARCHAR2(2000),
field15	VARCHAR2(2000),
field16	VARCHAR2(2000),
field17	VARCHAR2(2000),
field18	VARCHAR2(2000),
field19	VARCHAR2(2000),
field20	VARCHAR2(2000)
)
/

CREATE TYPE storage_reporting_results AS TABLE OF storage_reporting_table_object
/

CREATE TYPE title_object AS OBJECT (
column_no		INTEGER, 
subtitle		intTable
)
/

CREATE TYPE titletable AS TABLE OF title_object
/

CREATE TYPE display_object AS OBJECT (
type			INTEGER,
title			VARCHAR2(255),
display_type		INTEGER,				
column_titles		titletable,
flat_table_columns	INTEGER,
width			VARCHAR2(50),
tag			VARCHAR2(50),
sql_table		VARCHAR2(100),
predicate		VARCHAR2(2000),
default_order_by	VARCHAR2(2000),
error_message		VARCHAR2(2000),
total_field		VARCHAR2(255)
)
/

CREATE TYPE display_object_table AS TABLE OF display_object
/

CREATE TYPE report_object AS OBJECT (
report_type		VARCHAR2(100),
tag			VARCHAR2(50),
title			VARCHAR2(100),
display_object_list	display_object_table,
function		VARCHAR2(4000)
)
/

CREATE TYPE report_object_table AS TABLE OF report_object
/

CREATE TYPE tab_object AS OBJECT (
title				VARCHAR2(100),
main_tab			VARCHAR2(50),
function			VARCHAR2(4000),
status				VARCHAR2(50),
start_display_object_list	display_object_table,
sub_tabs			report_object_table,
end_display_object_list		display_object_table
)
/

CREATE TYPE tab_object_table AS TABLE OF tab_object
/


CREATE OR REPLACE PACKAGE storage IS


PROCEDURE initialize;

----------------------------------------------------------------------
-- storage.pks
----------------------------------------------------------------------
-- File Type   : PL/SQL Specification file
-- Author      : Rajesh Kumar
-- Contact     : Rajesh.x.kumar@oracle.com
-- Date        : Dec. 13, 2001
-- Description : Storage routines are prototyped in this file.
--               DEPENDENCIES: WWPRO_API_PROVIDER
--                             WWSEC_API
--                             WWPRE_API_NAME
--                             WWCTX_API
--                             WWUI_API_PORTLET
--                             HTP
--                             UTIL_PORTAL
----------------------------------------------------------------------

--------------------------------------------------
-- VERSION CONSTANTS
--------------------------------------------------
-- All previous versions are commented to know the different releases
-- for this storage portlet
--CURRENT_VERSION     number := XXX;

CURRENT_VERSION     number := 1.1;
--------------------------------------------------
--------------------------------------------------
-- Function  Name : get_portlet_info
-- Description    : Returns details of the portlet in portlet_record structure.
--                   INPUT : ProviderId - Identifier for the provider.
--                           Language   - Language to return strings in.
--                  OUTPUT : Portlet    - Record of the portlet's properties.
--------------------------------------------------
   function get_portlet_info (
      p_provider_id           in  integer,
      p_language              in  varchar2)
   return WWPRO_API_PROVIDER.portlet_record;
--------------------------------------------------

--------------------------------------------------
-- Function  Name : is_runnable
-- Description    : Determines if the portlet can be run.
--                   INPUT : ProviderId     - Identifier for the provider.
--                           ReferencePath  - Set when method show is invoked.
--                  OUTPUT : Boolean answer.
--------------------------------------------------
   function is_runnable (
      p_provider_id           in  integer,
      p_reference_path        in varchar2)
   return boolean;
--------------------------------------------------

--------------------------------------------------
-- Procedure Name : register
-- Description    : Allows the portlet to do instance-level initialization.
--                   INPUT : Portlet    - Portlet instance.
--------------------------------------------------
   PROCEDURE register (
      p_portlet_instance       in  WWPRO_API_PROVIDER.portlet_instance_record);
--------------------------------------------------

--------------------------------------------------
-- Procedure Name : deregister
-- Description    : Allows the portlet to do instance-level cleanup.
--                   INPUT : Portlet    - Portlet instance.
--------------------------------------------------
   PROCEDURE deregister (
      p_portlet_instance       in  WWPRO_API_PROVIDER.portlet_instance_record);
-------------------------------------------------- 
-- Procedure Name : show
-- Description    : Displays the portlet page based on a mode.
--                   INPUT : PortletRecord   - Record of portlet instance.
--------------------------------------------------
   PROCEDURE show (
      p_portlet_record        in out WWPRO_API_PROVIDER.portlet_runtime_record);
--------------------------------------------------
-- Procedure Name : copy
-- Description    : Copies the portlet's customization and default settings
--                  from a portlet instance to a new portlet instance.
--                   INPUT : PortletInfo     - Record of portlet info.
--------------------------------------------------
   PROCEDURE copy (
      p_copy_portlet_info     in WWPRO_API_PROVIDER.copy_portlet_record);
--------------------------------------------------

--------------------------------------------------
-- Function  Name : describe_parameters
-- Description    : Returns the portlet parameter table.
--                   INPUT : ProviderId - Identifier for the provider.
--                           Language   - Language to return strings in.
--                  OUTPUT : Portlet    - Record of the portlet's properties.
--------------------------------------------------
   function describe_parameters (
      p_provider_id           in  integer,
      p_language              in  varchar2)
   return WWPRO_API_PROVIDER.portlet_parameter_table;
--------------------------------------------------
-- Procedure Name : display_storage_summary
-- Description    : Display data centers / Lob current storage data
--          INPUT : 
--------------------------------------------------
PROCEDURE display_storage_summary (
	p_main_tab		IN VARCHAR2,
	p_search		IN VARCHAR2,
	p_group_name		IN VARCHAR2,
	p_group_type		IN VARCHAR2,
	p_chart_type		IN VARCHAR2,  
	p_drill_down_group_type IN VARCHAR2,
	p_sub_tab		IN VARCHAR2,
	p_host_type		IN VARCHAR2, 
	p_orderfield		IN INTEGER,  
	p_ordertype		IN VARCHAR2,  
	p_display_object_type	IN VARCHAR2,
	p_portlet_record	IN OUT WWPRO_API_PROVIDER.portlet_runtime_record,
	p_page_url		IN VARCHAR2
);

--------------------------------------------------
-- Procedure Name : change_display
-- Description    : Refresh the storage with newer display type
--                   INPUT : ReferencePath  - Portlet instance id
--                           Page URL       - URL of the calling page
--                           Display Type   - Type to display metric values
--------------------------------------------------
 PROCEDURE change_display (
	p_page_url              IN VARCHAR2,
	p_main_tab		IN VARCHAR2 DEFAULT 'MAIN_TAB_DATACENTER',
	p_search		IN VARCHAR2 DEFAULT 'FALSE',
	p_group_name		IN VARCHAR2 DEFAULT 'ALL',
	p_group_type     	IN VARCHAR2 DEFAULT 'REPORTING_DATACENTER',
	p_chart_type            IN VARCHAR2 DEFAULT 'PIE',
	p_drill_down_group_type IN VARCHAR2 DEFAULT 'REPORTING_DATACENTER',
	p_sub_tab	      	IN VARCHAR2 DEFAULT 'SUMMARY',
	p_host_type             IN VARCHAR2 DEFAULT 'ALL_HOSTS',
	p_orderfield            IN INTEGER DEFAULT 3, 
	p_ordertype             IN VARCHAR2 DEFAULT 'DEFAULT',
	p_display_object_type	IN VARCHAR2 DEFAULT 'top'
);

--------------------------------------------------------------------------------
--
-- name : quick_lookup
--
-- description : execute the quick look up report
--
-- args : 
--  referencePath  
--  page URL       - URL of the calling page
--  main_tab   
--  group name
--  group type
--
--
------------------------------------------------------------------------------------------
PROCEDURE quick_lookup (
--	p_reference_path	IN	VARCHAR2,
	p_page_url		IN	VARCHAR2,
	p_main_tab		IN	VARCHAR2 DEFAULT 'MAIN_TAB_HOSTLOOKUP',
	p_type			IN	VARCHAR2 DEFAULT 'REPORTING_DATACENTER',
	p_value			IN	VARCHAR2 DEFAULT 'ALL'
);

--------------------------------------------------
-- Procedure Name : get_group_report
-- Description    : Refresh the storage summary with newer display type 
--                   INPUT : ReferencePath  - Portlet instance id
--                           Page URL       - URL of the calling page 
--                           Display Type   - datacenter
--			     LOB	    - LOB
--			     chart type
--------------------------------------------------
   PROCEDURE get_group_report (
      p_page_url              in    VARCHAR2,
      p_main_tab	      IN    VARCHAR2 DEFAULT 'MAIN_TAB_DATACENTER',
      p_group_type	      IN    stormon_group_table.type%TYPE DEFAULT 'REPORTING_DATACENTER',
      p_group_name	      in    stormon_group_table.name%TYPE DEFAULT 'ALL'	
   ); 

--------------------------------------------------
-- Procedure  Name : l_draw_graph
-- Description    : Global function to invoke servlet to
--                  generate HTML graph chart.
--------------------------------------------------
   PROCEDURE l_draw_graph(
      p_id               in VARCHAR2,
      p_period           in VARCHAR2, 
      p_storage_type     in VARCHAR2
  );
--------------------------------------------------
-- Procedure Name : display_storage_history
-- Description    : display storage history in a popup window
--                   INPUT :
--------------------------------------------------
   PROCEDURE display_storage_history (
      p_period           in VARCHAR2,
      p_storage_type     in VARCHAR2,
      p_id               in storage_summaryObject_view.id%TYPE
   );
--------------------------------------------------
-- Procedure Name : display_host_details
-- Description    : display_host_details
--          INPUT : target name
--		  : target_id
-- 		  : table to sort
-- 		  : column to sort
-- 		  : order to sort
--------------------------------------------------
PROCEDURE SINGLE_HOST_REPORT (
				p_portlet_record  	IN OUT WWPRO_API_PROVIDER.portlet_runtime_record,
				p_main_tab		IN VARCHAR2 ,
				p_search_name		IN VARCHAR2 ,
				p_name			IN VARCHAR2 ,
				p_type			IN VARCHAR2 ,
				p_chart_type		IN VARCHAR2 ,
				p_drill_down_group_type	IN VARCHAR2 ,
				p_sub_tab		IN VARCHAR2 , --p_drill_down_type	IN VARCHAR2 DEFAULT 'DEFAULT',
				p_host_type		IN VARCHAR2 ,	 
				p_orderfield		IN INTEGER , 
				p_ordertype		IN VARCHAR2 ,
				p_display_object_type	IN VARCHAR2 DEFAULT 'top' );

--------------------------------------------------
-- Procedure Name : display_issues
-- Description    : display_issues
--          INPUT : target name
--                  target id 
--------------------------------------------------
PROCEDURE display_issues (
  p_id    	  in VARCHAR2,
  p_message_type  in VARCHAR2,   -- Type of message , ISSUE or WARNING
  p_host_type	  in VARCHAR2 DEFAULT 'ALL_HOSTS' -- Type of Hosts to report ALL,FAILED,NOT COLLECTED,SUMMARIZED
);

--------------------------------------------------
-- Procedure Name : display_hosts_not_collected
-- Description    : display hosts with no storage metrics
--          INPUT : data center
--                  lob
--		    title
--------------------------------------------------
procedure display_hosts_not_collected (
  p_id   	  in VARCHAR2
);


--------------------------------------------------------------------
-- Name : classical_drill_down
-- 
-- Desc : Procedure to build the UI, the cgi nvokes this procedure
--		The default starts with ALL datacenters and LOB's
--		For drill downs pass the specific Datacenter and LOB
--------------------------------------------------------------------
PROCEDURE classical_drill_down (
				p_portlet_record  	IN OUT WWPRO_API_PROVIDER.portlet_runtime_record,
				p_main_tab		IN VARCHAR2 DEFAULT 'MAIN_TAB_DATACENTER',
				p_search_name		IN VARCHAR2 DEFAULT 'FALSE',
				p_name			IN VARCHAR2 DEFAULT 'ALL',
				p_type			IN VARCHAR2 DEFAULT 'REPORTING_DATACENTER',
				p_chart_type		IN VARCHAR2 DEFAULT 'PIE' ,
				p_drill_down_group_type	IN VARCHAR2 DEFAULT 'REPORTING_DATACENTER',
				p_sub_tab		IN VARCHAR2 DEFAULT 'SUMMARY', --p_drill_down_type	IN VARCHAR2 DEFAULT 'DEFAULT',
				p_host_type		IN VARCHAR2 DEFAULT 'ALL_HOSTS',	 
				p_orderfield		IN INTEGER DEFAULT 3, 
				p_ordertype		IN VARCHAR2 DEFAULT 'DEFAULT',
				p_display_object_type	IN VARCHAR2 DEFAULT 'top' 								
			);



   function get_fmt_storage(
      p_number  in number)
      return VARCHAR2;

   function get_fmt_storage(
      p_number  in VARCHAR2,
      p_unit    in VARCHAR2 )
      return number;

   function get_fmt_AU_storage(
      p_allocated  in number,
      p_used       in number
   )
      return VARCHAR2;


   function get_storage_usage_meter(
      p_rawsize      in number,
      p_used_percent in number,
      p_size	     IN NUMBER DEFAULT 1	
   )
      return VARCHAR2;

   function get_history_link(
	p_id   in storage_summaryObject_view.id%TYPE,
	p_name IN VARCHAR2 DEFAULT 'History'
   )
      return VARCHAR2;

-- To be deleted
   function get_history_link(
	p_summary   in storage_summaryObject_view%ROWTYPE
   )
      return VARCHAR2;

   function get_issue_fmt_link(
      p_id	   in storage_summaryObject_view.id%TYPE,
      p_tag	   in VARCHAR2,
      p_issue_type in VARCHAR2 DEFAULT 'ISSUE', -- ISSUE or WARNING
      p_host_type  in VARCHAR2 DEFAULT 'ALL_HOSTS' -- Can be one of ALL_HOSTS , SUMMARIZED_HOSTS, FAILED_HOSTS , NOT_COLLECTED_HOSTS, ISSUE_HOSTS
   )
      return VARCHAR2;

-- To be deleted
   function get_issue_fmt_link(
      p_summary    in storage_summaryObject_view%ROWTYPE,
      p_tag	   in VARCHAR2,
      p_issue_type in VARCHAR2 DEFAULT 'ISSUE', -- ISSUE or WARNING
      p_host_type  in VARCHAR2 DEFAULT 'ALL_HOSTS' -- Can be one of ALL_HOSTS , SUMMARIZED_HOSTS, FAILED_HOSTS , NOT_COLLECTED_HOSTS, ISSUE_HOSTS
   )
      return VARCHAR2;

   function get_hosts_not_collected_link(
      p_id	   in storage_summaryObject_view.id%TYPE,
      p_tag	   in VARCHAR2
   )
      return VARCHAR2;

-- To be deleted
   function get_hosts_not_collected_link(
      p_summary    in storage_summaryObject_view%ROWTYPE,
      p_tag	   in VARCHAR2
   )
      return VARCHAR2;

FUNCTION get_hostdetails_fmt_link ( 
	p_page_url	  	IN  	VARCHAR2,
	p_name			IN	VARCHAR2,
	p_type			IN	VARCHAR2,
	p_tag			IN	VARCHAR2,
	p_chart_type		IN	VARCHAR2 DEFAULT 'PIE') 
RETURN VARCHAR2;

FUNCTION GET_DRILLDOWN_LINK(
	p_main_tab		IN	VARCHAR2,
	p_name			IN	VARCHAR2,
	p_type			IN	VARCHAR2,
	p_tag			IN	VARCHAR2,
	p_chart_type		IN	VARCHAR2 DEFAULT 'PIE',
	p_drill_down_group_type	IN	VARCHAR2 DEFAULT 'REPORTING_DATACENTER',
	p_sub_tab		IN	VARCHAR2 DEFAULT 'SUMMARY',
	p_host_type		IN	VARCHAR2 DEFAULT 'ALL_HOSTS'
   )
RETURN VARCHAR2;

END storage; -- package specification STORAGE
/


CREATE OR REPLACE PACKAGE BODY storage IS

----------------------------------------------------------------------
-- storage.pkb
----------------------------------------------------------------------
-- File Type   : PL/SQL Package Body file
-- Author      : Rajesh Kumar
-- Contact     : Rajesh.x.kumar@oracle.com
-- Date        : June. 13, 2002
-- Description : STORAGE routines are defined in this file.
--               DEPENDENCIES: WWPRO_API_PROVIDER
--                             WWSEC_API
--                             WWPRE_API_NAME
--                             WWCTX_API
--                             WWUI_API_PORTLET
--                             HTP
--                             UTIL_PORTAL
--                             UTIL_SQL


--------------------------------------------------------------------
-- Package data types
-- .
--
--
--------------------------------------------------------------------

	TYPE summary_table IS RECORD (
	name				stringTable,	
	id				stringTable,
	type				stringTable,	
	timestamp			dateTable,	-- Timestamp for the summaryObject
	collection_timestamp		dateTable,	-- Max collection timestamp of the metrics of this summaryobject
	hostcount			intTable,	-- No of targets in this summary
	actual_targets			intTable,	-- No of targets counted in this summary
	issues				intTable,	-- No of issues , or hosts which failed summary computation
	warnings			intTable,	-- No. od warnings , or No. of hosts with warnings in a group summary
	summaryflag			stringTable,	-- Flag indicating if this summary is a place holder Y/N
	application_rawsize		numberTable,		-- Non Oracle DB applications
	application_size		numberTable,
	application_used		numberTable,
	application_free		numberTable,
	oracle_database_rawsize		numberTable,		-- Oracle DB's
	oracle_database_size		numberTable,
	oracle_database_used		numberTable,
	oracle_database_free		numberTable,
	local_filesystem_rawsize	numberTable,		-- Local Filesystems
	local_filesystem_size		numberTable,
	local_filesystem_used		numberTable,		
	local_filesystem_free		numberTable,
	nfs_exclusive_size		numberTable,		-- NFS exclusive
	nfs_exclusive_used		numberTable,		
	nfs_exclusive_free		numberTable,
	nfs_shared_size			numberTable,		-- NFS shared
	nfs_shared_used			numberTable,
	nfs_shared_free			numberTable,
	volumemanager_rawsize		numberTable,		-- VM
	volumemanager_size		numberTable,
	volumemanager_used		numberTable,
	volumemanager_free		numberTable,
	swraid_rawsize			numberTable,		-- swraid
	swraid_size			numberTable,
	swraid_used			numberTable,
	swraid_free			numberTable,
	disk_backup_rawsize		numberTable,		-- Disk Backup
	disk_backup_size		numberTable,	
	disk_backup_used		numberTable,
	disk_backup_free		numberTable,
	disk_rawsize			numberTable,		-- Disk
	disk_size			numberTable,
	disk_used			numberTable,	
	disk_free			numberTable,		
	rawsize				numberTable,		-- Disk + NFS storage
	sizeb				numberTable,
	used				numberTable,
	free				numberTable,
	vendor_emc_size			numberTable,		-- Storage by vendor
	vendor_emc_rawsize		numberTable,
	vendor_sun_size			numberTable,
	vendor_sun_rawsize		numberTable,
	vendor_hp_size			numberTable,	
	vendor_hp_rawsize		numberTable,
	vendor_hitachi_size		numberTable,
	vendor_hitachi_rawsize		numberTable,
	vendor_others_size		numberTable,
	vendor_others_rawsize		numberTable,
	vendor_nfs_netapp_size		numberTable,
	vendor_nfs_emc_size		numberTable,
	vendor_nfs_sun_size		numberTable,	
	vendor_nfs_others_size		numberTable
	);

--------------------------------------------------------------------
-- Package variables and constants
-- 
-- Desc : Initialize the package level configuratioon structures, 
--	to be initialized one time.
--
--
--------------------------------------------------------------------
-- IF DEBUG THEN PRINT DEBUG STATEMENTS
p_mode			VARCHAR2(24) := 'DEBUG';

----------------------------------------------------------------------
-- CONSTANT DECLARATION
----------------------------------------------------------------------
PREFERENCE_PATH       VARCHAR2(32) := 'mymetrics.storage';
BLANK                 VARCHAR2(32) := chr(38) || 'nbsp;';
BLANK2                VARCHAR2(32) := BLANK || BLANK; 
BLANK4                VARCHAR2(32) := BLANK || BLANK || BLANK || BLANK ;
BLANK16               VARCHAR2(1024) := BLANK4 || BLANK4 || BLANK4 || BLANK4 ;
BLANK64               VARCHAR2(1024) := BLANK16 || BLANK16 || BLANK16 || BLANK16 ;

L_BASE_KB             number       := 1024 ; 
L_BASE_MB             number       := 1024 * L_BASE_KB; 
L_BASE_GB             number       := 1024 * L_BASE_MB; 
L_BASE_TB             number       := 1024 * L_BASE_GB; 

-- Color declarations  --
TABLE_HEADER_COLOR	VARCHAR2(7)	:= '#CCCC8C';
RED_COLOR		VARCHAR2(64)	:= '<font color="#cc0000">';   

-- Asending and descing column images
IMG_ASC               constant VARCHAR2(256) := 
                      '<IMG BORDER=0 SRC=' || '/myImages/asc_sort.gif' || '>';
IMG_DESC              constant VARCHAR2(256) := 
                      '<IMG BORDER=0 SRC=' || '/myImages/desc_sort.gif' || '>';

-- Table for holding column configuration
TYPE column_record IS RECORD ( 
                                column_name VARCHAR2(50), 
                                column_type VARCHAR2(25),
                                field_name VARCHAR2(100) := NULL, 
                                order_clause VARCHAR2(100) , 
                                order_type VARCHAR2(10) := 'DESC' );

-- Column Table for summaries
TYPE summary_column_list IS VARRAY(58) OF column_record;

-- Table for holding column configuration for summary report
l_list_of_summary_columns	summary_column_list := summary_column_list();

-- TOP N To be listed in pie charts
c_topnRank			CONSTANT INTEGER := 6;
-- Colums in a flat table
c_flattable_columns		CONSTANT INTEGER := 2;
-- Max number of fields in the storage_reporting_table_object
c_max_reporting_fields		CONSTANT INTEGER := 20;

-- Display Types
c_display_type_chart		CONSTANT INTEGER := 100;
c_display_type_table		CONSTANT INTEGER := 101;
c_display_type_flattable	CONSTANT INTEGER := 102;
c_display_type_row		CONSTANT INTEGER := 103;
c_display_type_section_open	CONSTANT INTEGER := 104;
c_display_type_meter		CONSTANT INTEGER := 105;
c_display_type_graph		CONSTANT INTEGER := 106;
c_display_type_section_close	CONSTANT INTEGER := 107;
c_display_type_subsection_open	CONSTANT INTEGER := 108;
c_display_type_ssection_close	CONSTANT INTEGER := 109;
c_display_type_column_open	CONSTANT INTEGER := 110;
c_display_type_column_close	CONSTANT INTEGER := 111;
c_display_type_navigation_tags	CONSTANT INTEGER := 112;
c_display_type_search_box	CONSTANT INTEGER := 113;
c_display_type_combo_box	CONSTANT INTEGER := 114;

c_display_type_outertable_open	CONSTANT INTEGER := 115;
c_display_type_table_close	CONSTANT INTEGER := 116;
c_display_type_row_open		CONSTANT INTEGER := 117;
c_display_type_row_close	CONSTANT INTEGER := 118;

c_display_type_main_tabs	CONSTANT INTEGER := 119;
c_display_type_sub_tabs		CONSTANT INTEGER := 120;
c_display_type_report_title	CONSTANT INTEGER := 121;	
c_display_type_fulltable_open	CONSTANT INTEGER := 122;

c_display_type_attributes	CONSTANT INTEGER := 123;
c_display_type_draw_line	CONSTANT INTEGER := 124;

c_vendor_table			CONSTANT INTEGER := 1;
c_usage_summary_table		CONSTANT INTEGER := 2;
c_host_count_table		CONSTANT INTEGER := 3;
c_group_usage_table		CONSTANT INTEGER := 4;
c_group_vendor_table		CONSTANT INTEGER := 5;
c_host_usage_table		CONSTANT INTEGER := 6;
c_host_vendor_table		CONSTANT INTEGER := 7;
c_free_storage_table		CONSTANT INTEGER := 8;
c_chart_used_free		CONSTANT INTEGER := 9;
c_chart_vendor			CONSTANT INTEGER := 10;
c_chart_top_n_used		CONSTANT INTEGER := 11;
c_chart_top_n_free		CONSTANT INTEGER := 12;
c_chart_by_used			CONSTANT INTEGER := 13;
c_chart_where_free		CONSTANT INTEGER := 14;
c_meter_usage			CONSTANT INTEGER := 15;
c_history_graph			CONSTANT INTEGER := 16;
c_host_usage_summary_table	CONSTANT INTEGER := 17;
c_detailedreport_summary_table	CONSTANT INTEGER := 18;
c_detailed_disk_table		CONSTANT INTEGER := 19;
c_detailed_swraid_table		CONSTANT INTEGER := 21;
c_detailed_volume_table		CONSTANT INTEGER := 22;
c_detailed_localfs_table	CONSTANT INTEGER := 23;
c_detailed_dedicated_nfs_table	CONSTANT INTEGER := 24;
c_detailed_app_oracledb_table	CONSTANT INTEGER := 25;
c_detailed_issues_table		CONSTANT INTEGER := 26;
c_detailed_warnings_table	CONSTANT INTEGER := 27;
c_detailed_shared_nfs_table	CONSTANT INTEGER := 28;

-- Predefined display Objects
l_vendor_table			display_object;
l_usage_summary_table		display_object;
l_host_count_table		display_object;
l_group_usage_table		display_object;
l_group_vendor_table		display_object;
l_host_usage_table		display_object;
l_host_vendor_table		display_object;
l_free_storage_table		display_object;
l_chart_used_free		display_object;
l_chart_vendor			display_object;
l_chart_top_n_used		display_object;
l_chart_top_n_free		display_object;
l_chart_by_used			display_object;
l_chart_where_free		display_object;
l_meter_usage			display_object;
l_history_graph			display_object;
l_host_usage_summary_table	display_object;
l_detailed_summary_object 	display_object;
l_detailed_disk_object 		display_object;
l_detailed_swraid_object 	display_object;
l_detailed_volume_object 	display_object;
l_detailed_localfs_object 	display_object;
l_detailed_nfs_object 		display_object;
l_detailed_shared_nfs_object 	display_object;
l_detailed_oracledb_object 	display_object;
l_issues_object			display_object;
l_warnings_object 		display_object;

l_outer_table_object		display_object;
l_fullwidth_table_object		display_object;
l_table_close_object		display_object;

l_row_open_object    		display_object;
l_row_close_object		display_object;

l_column_open_object		display_object;
l_column_50_open_object		display_object;	
l_column_close_object 		display_object;

l_row_object			display_object;
l_navigation_link_object	display_object;

----------------------------------------------------------------
-- Declarations for package subroutines
----------------------------------------------------------------
PROCEDURE get_dc_lob_from_name(	p_group_name	IN	stormon_group_table.name%TYPE,
				p_group_type	IN	stormon_group_table.type%TYPE,
				p_datacenter	OUT	VARCHAR2,
				p_lob		OUT	VARCHAR2 );

PROCEDURE print_host_title_table(l_summaryObject IN storage_summaryObject_view%ROWTYPE );

PROCEDURE printstmt( v_string IN VARCHAR2);


--------------------------------------------------
-- Procedure Name : printstmt
-- Description    : dbms_out a long string
--                  
--          INPUT : string
--------------------------------------------------
PROCEDURE printstmt(v_string  IN VARCHAR2 ) IS

l_position	INTEGER := 1;

BEGIN

	WHILE ( LENGTH(SUBSTR(v_string,l_position)) > 0 ) LOOP

		DBMS_OUTPUT.PUT_LINE(SUBSTR(v_string,l_position,255));
		l_position := l_position + 255;
		
	END LOOP;

END printstmt;

PROCEDURE printn ( a VARCHAR2 ) IS

BEGIN
	
	IF STORAGE.P_MODE = 'PRODUCTION' THEN
		RETURN;
	END IF;

	HTP.P(a||' <BR> ');
	STORAGE.PRINTSTMT(a);
	-- ROLLBACK;
	-- INSERT INTO T VALUES(a);
	-- OMMIT;

END;

--------------------------------------------------------------------
-- Name : initialize
-- 
-- Desc : Initialize the package level configuratioon structures, 
--	to be initialized one time.
--
--
--------------------------------------------------------------------
PROCEDURE initialize IS

BEGIN

--	Assuming this to be atomic
--	IF STORAGE.p_init_status = 1 THEN
--		RETURN;
--	END IF;

--	STORAGE.PRINTN('Initializing the package');

--	STORAGE.p_init_status := 1;

---------------------------------------
-- Summary report configuration
---------------------------------------

	-----------------------------------------
	-- COLUMN CONFIGURATION
	-----------------------------------------
	IF l_list_of_summary_columns IS NOT NULL AND l_list_of_summary_columns.EXISTS(1) THEN
		l_list_of_summary_columns.TRIM(l_list_of_summary_columns.COUNT);
	END IF;
	l_list_of_summary_columns.EXTEND(58);
	l_list_of_summary_columns(1).column_name := 'Name';
	l_list_of_summary_columns(1).column_type := 'CHARACTER';
	l_list_of_summary_columns(1).field_name := 'name';
	l_list_of_summary_columns(1).order_clause := 'NAME';
	l_list_of_summary_columns(1).order_type := 'ASC';

	l_list_of_summary_columns(2).column_name := 'Rawsize';
	l_list_of_summary_columns(2).column_type := 'NUMERIC';
	l_list_of_summary_columns(2).field_name := 'rawsize';
	l_list_of_summary_columns(2).order_clause := 'RAWSIZE';
	l_list_of_summary_columns(2).order_type := 'DESC';

	l_list_of_summary_columns(3).column_name := 'Attached';
	l_list_of_summary_columns(3).column_type := 'NUMERIC';
	l_list_of_summary_columns(3).field_name := 'sizeb';
	l_list_of_summary_columns(3).order_clause := 'SIZEB';
	l_list_of_summary_columns(3).order_type := 'DESC';

	l_list_of_summary_columns(4).column_name := 'Database';
	l_list_of_summary_columns(4).column_type := 'NUMERIC';
	l_list_of_summary_columns(4).order_clause := 'ORACLE_DATABASE_SIZE';
	l_list_of_summary_columns(4).order_type := 'DESC';

	l_list_of_summary_columns(5).column_name := 'Local Filesystems';
	l_list_of_summary_columns(5).column_type := 'NUMERIC';
	l_list_of_summary_columns(5).order_clause := 'LOCAL_FILESYSTEM_SIZE';
	l_list_of_summary_columns(5).order_type := 'DESC';

	l_list_of_summary_columns(6).column_name := 'Dedicated NFS';
	l_list_of_summary_columns(6).column_type := 'NUMERIC';
	l_list_of_summary_columns(6).order_clause := 'NFS_EXCLUSIVE_SIZE';
	l_list_of_summary_columns(6).order_type := 'DESC';

	l_list_of_summary_columns(7).column_name := 'Volume Manager';
	l_list_of_summary_columns(7).column_type := 'NUMERIC';
	l_list_of_summary_columns(7).order_clause := 'VOLUMEMANAGER_SIZE';
	l_list_of_summary_columns(7).order_type := 'DESC';

	l_list_of_summary_columns(8).column_name := 'SW Raid Manager';
	l_list_of_summary_columns(8).column_type := 'NUMERIC';	
	l_list_of_summary_columns(8).order_clause := 'SWRAID_SIZE';
	l_list_of_summary_columns(8).order_type := 'DESC';

	l_list_of_summary_columns(9).column_name := 'Backup Disks';
	l_list_of_summary_columns(9).column_type := 'NUMERIC';
	l_list_of_summary_columns(9).order_clause := 'DISK_BACKUP_SIZE';
	l_list_of_summary_columns(9).order_type := 'DESC';

	l_list_of_summary_columns(10).column_name := 'Disks';
	l_list_of_summary_columns(10).column_type := 'NUMERIC';
	l_list_of_summary_columns(10).order_clause := 'DISK_SIZE';
	l_list_of_summary_columns(10).order_type := 'DESC';

	l_list_of_summary_columns(11).column_name := '%Used';
	l_list_of_summary_columns(11).column_type := 'NUMERIC';
	l_list_of_summary_columns(11).order_clause := '(USED/DECODE(SIZEB,NULL,1,0,1,SIZEB))';
	l_list_of_summary_columns(11).order_type := 'DESC';

	l_list_of_summary_columns(12).column_name := 'Free';
	l_list_of_summary_columns(12).column_type := 'NUMERIC';
	l_list_of_summary_columns(12).field_name := 'free';
	l_list_of_summary_columns(12).order_clause := 'FREE';
	l_list_of_summary_columns(12).order_type := 'DESC';

	l_list_of_summary_columns(13).column_name := 'Issues';
	l_list_of_summary_columns(13).column_type := 'NUMERIC';
	l_list_of_summary_columns(13).order_clause := 'ISSUES';
	l_list_of_summary_columns(13).order_type := 'DESC';

	l_list_of_summary_columns(14).column_name := 'Related Links';
	l_list_of_summary_columns(14).column_type := 'CHARACTER';
	l_list_of_summary_columns(14).order_clause := NULL;
	l_list_of_summary_columns(14).order_type := 'DESC';

	l_list_of_summary_columns(15).column_name := 'EMC Symmetrix Rawsize/Attached';
	l_list_of_summary_columns(15).column_type := 'NUMERIC';
	l_list_of_summary_columns(15).order_clause := 'VENDOR_EMC_SIZE';
	l_list_of_summary_columns(15).order_type := 'DESC';

	l_list_of_summary_columns(16).column_name := 'Network Appliance';
	l_list_of_summary_columns(16).column_type := 'NUMERIC';
	l_list_of_summary_columns(16).order_clause := 'VENDOR_NFS_NETAPP_SIZE';
	l_list_of_summary_columns(16).order_type := 'DESC';

	l_list_of_summary_columns(17).column_name := 'Sun';
	l_list_of_summary_columns(17).column_type := 'NUMERIC';
	l_list_of_summary_columns(17).order_clause := 'VENDOR_SUN_SIZE';
	l_list_of_summary_columns(17).order_type := 'DESC';

	l_list_of_summary_columns(18).column_name := 'Hitachi';
	l_list_of_summary_columns(18).column_type := 'NUMERIC';
	l_list_of_summary_columns(18).order_clause := 'VENDOR_HITACHI_SIZE';
	l_list_of_summary_columns(18).order_type := 'DESC';

	l_list_of_summary_columns(19).column_name := 'Other Vendors';
	l_list_of_summary_columns(19).column_type := 'NUMERIC';
	l_list_of_summary_columns(19).order_clause := '(VENDOR_NFS_OTHERS_SIZE+VENDOR_NFS_SUN_SIZE+VENDOR_NFS_EMC_SIZE+VENDOR_OTHERS_SIZE+VENDOR_HP_SIZE)';
	l_list_of_summary_columns(19).order_type := 'DESC';

	l_list_of_summary_columns(20).column_name := 'Hosts';
	l_list_of_summary_columns(20).column_type := 'NUMERIC';
	l_list_of_summary_columns(20).order_clause := 'HOSTCOUNT ';
	l_list_of_summary_columns(20).order_type := 'DESC';

	l_list_of_summary_columns(21).column_name := 'Allocated/Used';
	l_list_of_summary_columns(21).column_type := 'NUMERIC';
	l_list_of_summary_columns(21).order_clause := 'DISK_SIZE';
	l_list_of_summary_columns(21).order_type := 'DESC';

	l_list_of_summary_columns(22).column_name := 'Used';
	l_list_of_summary_columns(22).column_type := 'NUMERIC';
	l_list_of_summary_columns(22).field_name := 'used';
	l_list_of_summary_columns(22).order_clause := 'used';
	l_list_of_summary_columns(22).order_type := 'DESC';

	l_list_of_summary_columns(23).column_name := 'Other';
	l_list_of_summary_columns(23).column_type := 'NUMERIC';
	l_list_of_summary_columns(23).order_clause := '(USED-DISK_BACKUP_USED)';
	l_list_of_summary_columns(23).order_type := 'DESC';

	l_list_of_summary_columns(24).column_name := 'Total';
	l_list_of_summary_columns(24).column_type := 'NUMERIC';
	l_list_of_summary_columns(24).order_clause := 'USED';
	l_list_of_summary_columns(24).order_type := 'DESC';

	l_list_of_summary_columns(25).column_name := 'Backup Disks';
	l_list_of_summary_columns(25).column_type := 'NUMERIC';	
	l_list_of_summary_columns(25).order_clause := 'DISK_BACKUP_USED';
	l_list_of_summary_columns(25).order_type := 'DESC';

	l_list_of_summary_columns(26).column_name := 'With<BR>Issues';
	l_list_of_summary_columns(26).column_type := 'NUMERIC';
	l_list_of_summary_columns(26).order_clause := 'ISSUES';
	l_list_of_summary_columns(26).order_type := 'DESC';
--
	l_list_of_summary_columns(27).column_name := 'Attached';
	l_list_of_summary_columns(27).column_type := 'NUMERIC';
	l_list_of_summary_columns(27).order_clause := NULL;
	l_list_of_summary_columns(27).order_type := NULL;
--
	l_list_of_summary_columns(28).column_name := 'Total';
	l_list_of_summary_columns(28).column_type := 'NUMERIC';
	l_list_of_summary_columns(28).order_clause := 'HOSTCOUNT';
	l_list_of_summary_columns(28).order_type := 'DESC';

	l_list_of_summary_columns(29).column_name := 'Summarized';
	l_list_of_summary_columns(29).column_type := 'NUMERIC';
	l_list_of_summary_columns(29).order_clause := 'ACTUAL_TARGETS';
	l_list_of_summary_columns(29).order_type := 'DESC';

	l_list_of_summary_columns(30).column_name := 'Not Collected';
	l_list_of_summary_columns(30).column_type := 'NUMERIC';
	l_list_of_summary_columns(30).order_clause := 'HOSTCOUNT-ACTUAL_TARGETS';
	l_list_of_summary_columns(30).order_type := 'DESC';

	l_list_of_summary_columns(31).column_name := 'Storage Vendor';
	l_list_of_summary_columns(31).column_type := 'CHARACTER';
	l_list_of_summary_columns(31).order_clause := NULL;
	l_list_of_summary_columns(31).order_type := NULL;

	l_list_of_summary_columns(32).column_name := 'Raw';
	l_list_of_summary_columns(32).column_type := 'NUMERIC';
	l_list_of_summary_columns(32).order_clause := NULL;
	l_list_of_summary_columns(32).order_type := NULL;

	l_list_of_summary_columns(33).column_name := 'Host Visible';
	l_list_of_summary_columns(33).column_type := 'NUMERIC';
	l_list_of_summary_columns(33).order_clause := NULL;
	l_list_of_summary_columns(33).order_type := NULL;

	l_list_of_summary_columns(34).column_name := 'Host type';
	l_list_of_summary_columns(34).column_type := 'CHARACTER';
	l_list_of_summary_columns(34).order_clause := NULL;
	l_list_of_summary_columns(34).order_type := NULL;

	l_list_of_summary_columns(35).column_name := 'Host Count';
	l_list_of_summary_columns(35).column_type := 'NUMERIC';
	l_list_of_summary_columns(35).order_clause := NULL;
	l_list_of_summary_columns(35).order_type := NULL;

	l_list_of_summary_columns(36).column_name := 'Storage type';
	l_list_of_summary_columns(36).column_type := 'CHARACTER';
	l_list_of_summary_columns(36).order_clause := NULL;
	l_list_of_summary_columns(36).order_type := NULL;

	l_list_of_summary_columns(37).column_name := 'Unallocated';
	l_list_of_summary_columns(37).column_type := 'NUMERIC';
	l_list_of_summary_columns(37).order_clause := 'FREE-(LOCAL_FILESYSTEM_FREE+ORACLE_DATABASE_FREE+NFS_EXCLUSIVE_FREE)';
	l_list_of_summary_columns(37).order_type := 'DESC';

	l_list_of_summary_columns(38).column_name := 'Path';
	l_list_of_summary_columns(38).column_type := 'CHARACTER';
	l_list_of_summary_columns(38).field_name := 'path';
	l_list_of_summary_columns(38).order_clause := 'PATH';
	l_list_of_summary_columns(38).order_type := 'ASC ';

	l_list_of_summary_columns(39).column_name := 'Type';
	l_list_of_summary_columns(39).column_type := 'CHARACTER';
	l_list_of_summary_columns(39).field_name := 'type';
	l_list_of_summary_columns(39).order_clause := 'TYPE';
	l_list_of_summary_columns(39).order_type := 'ASC ';

	l_list_of_summary_columns(40).column_name := 'Rawsize';
	l_list_of_summary_columns(40).column_type := 'NUMERIC';
	l_list_of_summary_columns(40).field_name := 'STORAGE.GET_FMT_STORAGE(rawsizeb)';
	l_list_of_summary_columns(40).order_clause := 'rawsizeb';	
	l_list_of_summary_columns(40).order_type := 'DESC ';

	l_list_of_summary_columns(41).column_name := 'Size';
	l_list_of_summary_columns(41).column_type := 'NUMERIC';
	l_list_of_summary_columns(41).field_name := 'STORAGE.GET_FMT_STORAGE(sizeb)';
	l_list_of_summary_columns(41).order_clause := 'SIZEB';	
	l_list_of_summary_columns(41).order_type := 'DESC ';

	l_list_of_summary_columns(42).column_name := 'Used';
	l_list_of_summary_columns(42).column_type := 'NUMERIC';
	l_list_of_summary_columns(42).field_name := 'STORAGE.GET_FMT_STORAGE(usedb)';
	l_list_of_summary_columns(42).order_clause := 'usedb';	
	l_list_of_summary_columns(42).order_type := 'DESC ';

	l_list_of_summary_columns(43).column_name := 'Free';
	l_list_of_summary_columns(43).column_type := 'NUMERIC';
	l_list_of_summary_columns(43).field_name := 'STORAGE.GET_FMT_STORAGE(freeb)';
	l_list_of_summary_columns(43).order_clause := 'freeb';	
	l_list_of_summary_columns(43).order_type := 'DESC ';

	l_list_of_summary_columns(44).column_name := 'Backup';
	l_list_of_summary_columns(44).column_type := 'CHARACTER';
	l_list_of_summary_columns(44).field_name := 'backup';
	l_list_of_summary_columns(44).order_clause := 'BACKUP';	
	l_list_of_summary_columns(44).order_type := 'ASC ';

	l_list_of_summary_columns(45).column_name := 'Configuration';
	l_list_of_summary_columns(45).column_type := 'CHARACTER';
	l_list_of_summary_columns(45).field_name := 'configuration';
	l_list_of_summary_columns(45).order_clause := 'CONFIGURATION';	
	l_list_of_summary_columns(45).order_type := 'ASC ';

	l_list_of_summary_columns(46).column_name := 'Vendor';
	l_list_of_summary_columns(46).column_type := 'CHARACTER';
	l_list_of_summary_columns(46).field_name := 'vendor';
	l_list_of_summary_columns(46).order_clause := 'VENDOR';	
	l_list_of_summary_columns(46).order_type := 'ASC ';

	l_list_of_summary_columns(47).column_name := 'Filesystem';
	l_list_of_summary_columns(47).column_type := 'CHARACTER';
	l_list_of_summary_columns(47).field_name := 'filesystem';
	l_list_of_summary_columns(47).order_clause := 'FILESYSTEM';	
	l_list_of_summary_columns(47).order_type := 'ASC ';

	l_list_of_summary_columns(48).column_name := 'Mountpoint';
	l_list_of_summary_columns(48).column_type := 'CHARACTER';
	l_list_of_summary_columns(48).field_name := 'mountpoint';
	l_list_of_summary_columns(48).order_clause := 'MOUNTPOINT';	
	l_list_of_summary_columns(48).order_type := 'ASC ';

	l_list_of_summary_columns(49).column_name := 'DB Name-SID';
	l_list_of_summary_columns(49).column_type := 'CHARACTER';
	l_list_of_summary_columns(49).field_name := 'appid';
	l_list_of_summary_columns(49).order_clause := 'appid';	
	l_list_of_summary_columns(49).order_type := 'ASC ';

	l_list_of_summary_columns(50).column_name := 'Tablespace';
	l_list_of_summary_columns(50).column_type := 'CHARACTER';
	l_list_of_summary_columns(50).field_name := 'tablespace';
	l_list_of_summary_columns(50).order_clause := 'TABLESPACE';	
	l_list_of_summary_columns(50).order_type := 'ASC ';

	l_list_of_summary_columns(51).column_name := 'Filename';
	l_list_of_summary_columns(51).column_type := 'CHARACTER';
	l_list_of_summary_columns(51).field_name := 'filename';
	l_list_of_summary_columns(51).order_clause := 'FILENAME';	
	l_list_of_summary_columns(51).order_type := 'ASC ';

	l_list_of_summary_columns(52).column_name := 'Path';
	l_list_of_summary_columns(52).column_type := 'CHARACTER';
	l_list_of_summary_columns(52).field_name := 'REPLACE(NVL(path,'' ''),''!'', ''<BR>'')';
	l_list_of_summary_columns(52).order_clause := 'path';	
	l_list_of_summary_columns(52).order_type := 'ASC ';

	l_list_of_summary_columns(53).column_name := 'Issues';
	l_list_of_summary_columns(53).column_type := 'CHARACTER';
	l_list_of_summary_columns(53).field_name := 'message';
	l_list_of_summary_columns(53).order_clause := 'message';	
	l_list_of_summary_columns(53).order_type := 'ASC ';

	l_list_of_summary_columns(54).column_name := 'Warnings';
	l_list_of_summary_columns(54).column_type := 'CHARACTER';
	l_list_of_summary_columns(54).field_name := 'message';
	l_list_of_summary_columns(54).order_clause := 'message';	
	l_list_of_summary_columns(54).order_type := 'ASC ';

	l_list_of_summary_columns(55).column_name := 'No. Of Mounts';
	l_list_of_summary_columns(55).column_type := 'CHARACTER';
	l_list_of_summary_columns(55).field_name := 'nfscount';
	l_list_of_summary_columns(55).order_clause := 'nfscount';	
	l_list_of_summary_columns(55).order_type := 'ASC ';

	l_list_of_summary_columns(56).column_name := 'Privilege';
	l_list_of_summary_columns(56).column_type := 'CHARACTER';
	l_list_of_summary_columns(56).field_name := 'privilege';
	l_list_of_summary_columns(56).order_clause := 'privilege';	
	l_list_of_summary_columns(56).order_type := 'ASC ';

	l_list_of_summary_columns(57).column_name := 'NFS Server';
	l_list_of_summary_columns(57).column_type := 'CHARACTER';
	l_list_of_summary_columns(57).field_name := 'server';
	l_list_of_summary_columns(57).order_clause := 'server';	
	l_list_of_summary_columns(57).order_type := 'ASC ';

	l_list_of_summary_columns(58).column_name := 'Available';
	l_list_of_summary_columns(58).column_type := 'NUMERIC';
	l_list_of_summary_columns(58).field_name := '(LOCAL_FILESYSTEM_SIZE+NFS_EXCLUSIVE_SIZE+VOLUMEMANAGER_FREE+SWRAID_FREE+DISK_FREE)';
	l_list_of_summary_columns(58).order_clause := '(LOCAL_FILESYSTEM_SIZE+NFS_EXCLUSIVE_SIZE+VOLUMEMANAGER_FREE+SWRAID_FREE+DISK_FREE)';
	l_list_of_summary_columns(58).order_type := 'DESC';


-- Standard display object used to build reports
	l_outer_table_object		:=	display_object(NULL,NULL,c_display_type_outertable_open,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
	l_fullwidth_table_object	:=	display_object(NULL,NULL,c_display_type_fulltable_open,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
	l_table_close_object		:=	display_object(NULL,NULL,c_display_type_table_close,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);

	l_row_open_object    		:=	display_object(NULL,NULL,c_display_type_row_open,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
	l_row_close_object		:=	display_object(NULL,NULL,c_display_type_row_close,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);

	l_column_open_object		:=	display_object(NULL,NULL,c_display_type_column_open,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
	l_column_50_open_object		:=	display_object(NULL,NULL,c_display_type_column_open,NULL,NULL,'50%',NULL,NULL,NULL,NULL,NULL,NULL);	
	l_column_close_object 		:=	display_object(NULL,NULL,c_display_type_column_close,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);

	l_row_object			:=	display_object(NULL,NULL,c_display_type_row,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);

	l_navigation_link_object	:= 	display_object(NULL,NULL,c_display_type_navigation_tags,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);

	-- Vendor table
	l_vendor_table					:= display_object(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
	l_vendor_table.type 				:= c_vendor_table;
	l_vendor_table.display_type 			:= c_display_type_table;
	l_vendor_table.column_titles			:= titleTable();
	l_vendor_table.column_titles.EXTEND(2);	

	l_vendor_table.column_titles(1)		 	:= title_object(31,NULL);
	l_vendor_table.column_titles(2)		 	:= title_object(27,inttable(32,33));
	
	-- Usage table
	l_usage_summary_table				:= display_object(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
	l_usage_summary_table.title			:= 'Storage Summary';
	l_usage_summary_table.type			:= c_usage_summary_table;
	l_usage_summary_table.display_type		:= c_display_type_flattable;
	l_usage_summary_table.tag			:= NULL;
	l_usage_summary_table.flat_table_columns	:= 1;
	l_usage_summary_table.column_titles		:= titleTable();
	l_usage_summary_table.column_titles.EXTEND(11);
	
	l_usage_summary_table.column_titles(1) 	:= title_object(2,NULL);
	l_usage_summary_table.column_titles(2) 	:= title_object(3,NULL);
	l_usage_summary_table.column_titles(3) 	:= title_object(58,NULL);
	l_usage_summary_table.column_titles(4) 	:= title_object(22,NULL);	
	l_usage_summary_table.column_titles(5) 	:= title_object(12,NULL);
	l_usage_summary_table.column_titles(6) 	:= title_object(11,NULL);
	l_usage_summary_table.column_titles(7) 	:= title_object(37,NULL);
	l_usage_summary_table.column_titles(8)	:= title_object(29,NULL);
	l_usage_summary_table.column_titles(9) := title_object(30,NULL);
	l_usage_summary_table.column_titles(10) := title_object(13,NULL);
	l_usage_summary_table.column_titles(11) := title_object(28,NULL);

	-- Host Usage table ( Same fields as usage table, but diferent query )
	l_host_usage_summary_table := l_usage_summary_table;	

	-- host table
	l_host_count_table	 			:= display_object(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
	l_host_count_table.type 			:= c_host_count_table;
	l_host_count_table.display_type 		:= c_display_type_flattable;	
	l_host_count_table.flat_table_columns		:= 1;
	l_host_count_table.column_titles		:= titleTable();
	l_host_count_table.column_titles.EXTEND(4);
	
	l_host_count_table.column_titles(1) := title_object(29,NULL);
	l_host_count_table.column_titles(2) := title_object(30,NULL);
	l_host_count_table.column_titles(3) := title_object(13,NULL);
	l_host_count_table.column_titles(4) := title_object(28,NULL);

	-- group usage table
	l_group_usage_table				:= display_object(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
	l_group_usage_table.title			:= 'Storage Summary by Usage';
	l_group_usage_table.type			:= c_group_usage_table;
	l_group_usage_table.tag				:= 'Storage Summary by Usage';
	l_group_usage_table.display_type		:= c_display_type_table;
	l_group_usage_table.column_titles		:= titleTable();
	l_group_usage_table.column_titles.EXTEND(8);
	
	-- Set this column dynamically at runtime based on the type
	l_group_usage_table.column_titles(1) := title_object(1,NULL);
	l_group_usage_table.column_titles(2) := title_object(2,NULL);
	l_group_usage_table.column_titles(3) := title_object(3,NULL);
	l_group_usage_table.column_titles(4) := title_object(58,NULL);
	l_group_usage_table.column_titles(5) := title_object(22,inttable(9,23,22));
	l_group_usage_table.column_titles(6) := title_object(11,NULL);
	l_group_usage_table.column_titles(7) := title_object(12,inttable(12,37));	
	l_group_usage_table.column_titles(8) := title_object(14,NULL);

	-- group vendor table	
	l_group_vendor_table				:= display_object(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
	l_group_vendor_table.type			:= c_group_vendor_table;
	l_group_vendor_table.display_type		:= c_display_type_table;
	l_group_vendor_table.column_titles	:= titleTable();
	l_group_vendor_table.column_titles.EXTEND(9);
	
	l_group_vendor_table.column_titles(1) := title_object(1,NULL);
	l_group_vendor_table.column_titles(2) := title_object(2,NULL);
	l_group_vendor_table.column_titles(3) := title_object(3,NULL);
	l_group_vendor_table.column_titles(4) := title_object(15,NULL);
	l_group_vendor_table.column_titles(5) := title_object(16,NULL);
	l_group_vendor_table.column_titles(6) := title_object(17,NULL);
	l_group_vendor_table.column_titles(7) := title_object(18,NULL);
	l_group_vendor_table.column_titles(8) := title_object(19,NULL);
	l_group_vendor_table.column_titles(9) := title_object(14,NULL);

	-- host usage table	
	l_host_usage_table				:= display_object(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);	
	l_host_usage_table.title			:= 'Storage Summary by Usage';				
	l_host_usage_table.type 			:= c_host_usage_table;
	l_host_usage_table.display_type 		:= c_display_type_table;
	l_host_usage_table.tag				:= 'Storage Summary by Usage';
	l_host_usage_table.column_titles		:= titleTable();
	l_host_usage_table.column_titles.EXTEND(15);
	
	l_host_usage_table.column_titles(1) := title_object(1,NULL);
	l_host_usage_table.column_titles(2) := title_object(2,NULL);
	l_host_usage_table.column_titles(3) := title_object(3,NULL);
	l_host_usage_table.column_titles(4) := title_object(58,NULL);
	l_host_usage_table.column_titles(5) := title_object(4,NULL);
	l_host_usage_table.column_titles(6) := title_object(5,NULL);
	l_host_usage_table.column_titles(7) := title_object(6,NULL);
	l_host_usage_table.column_titles(8) := title_object(7,NULL);
	l_host_usage_table.column_titles(9) := title_object(8,NULL);
	l_host_usage_table.column_titles(10) := title_object(9,NULL);
	l_host_usage_table.column_titles(11) := title_object(10,NULL);
	l_host_usage_table.column_titles(12) := title_object(11,NULL);
	l_host_usage_table.column_titles(13) := title_object(12,NULL);
	l_host_usage_table.column_titles(14) := title_object(37,NULL);
	l_host_usage_table.column_titles(15) := title_object(14,NULL);

	-- host vendor table	
	l_host_vendor_table				:= display_object(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
	l_host_vendor_table.title			:= 'Storage Summary by Vendor';
	l_host_vendor_table.type			:= c_host_vendor_table;
	l_host_vendor_table.display_type		:= c_display_type_table;
	l_host_vendor_table.tag				:= 'Storage Summary by Vendor';
	l_host_vendor_table.column_titles		:= titleTable();
	l_host_vendor_table.column_titles.EXTEND(9);
	
	l_host_vendor_table.column_titles(1) := title_object(1,NULL);
	l_host_vendor_table.column_titles(2) := title_object(2,NULL);
	l_host_vendor_table.column_titles(3) := title_object(3,NULL);
	l_host_vendor_table.column_titles(4) := title_object(15,NULL);
	l_host_vendor_table.column_titles(5) := title_object(16,NULL);
	l_host_vendor_table.column_titles(6) := title_object(17,NULL);
	l_host_vendor_table.column_titles(7) := title_object(18,NULL);
	l_host_vendor_table.column_titles(8) := title_object(19,NULL);
	l_host_vendor_table.column_titles(9) := title_object(14,NULL);

	-- Free storage
	l_free_storage_table				:= display_object(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
	l_free_storage_table.type			:= c_free_storage_table;
	l_free_storage_table.display_type 		:= c_display_type_table;
	l_free_storage_table.column_titles		:= titleTable();
	l_free_storage_table.column_titles.EXTEND(2);
	
	l_free_storage_table.column_titles(1) := title_object(36,NULL);	
	l_free_storage_table.column_titles(2) := title_object(12,NULL);	
	
	-- charts
	-- used free chart
	l_chart_used_free			:= display_object(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
	l_chart_used_free.type			:= c_chart_used_free;	
	l_chart_used_free.display_type		:= c_display_type_chart;

	-- by vendor chart
	l_chart_vendor				:= display_object(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
	l_chart_vendor.type			:= c_chart_vendor;
	l_chart_vendor.display_type		:= c_display_type_chart;

	-- top n used chart
	l_chart_top_n_used			:= display_object(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
	l_chart_top_n_used.type			:= c_chart_top_n_used;
	l_chart_top_n_used.display_type		:= c_display_type_chart;

	-- top n free
	l_chart_top_n_free			:= display_object(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
	l_chart_top_n_free.type			:= c_chart_top_n_free;
	l_chart_top_n_free.display_type		:= c_display_type_chart;

	-- all by used chart
	l_chart_by_used				:= display_object(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
	l_chart_by_used.type			:= c_chart_by_used;
	l_chart_by_used.display_type		:= c_display_type_chart;
 
	-- all by used chart
	l_chart_where_free			:= display_object(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
	l_chart_where_free.type			:= c_chart_where_free;
	l_chart_where_free.display_type		:= c_display_type_chart;

	-- Usage meter
	l_meter_usage				:= display_object(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
	l_meter_usage.type			:= c_meter_usage;
	l_meter_usage.display_type 		:= c_display_type_meter;

	-- HIstory graph
	l_history_graph				:= display_object(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
	l_history_graph.type			:= c_history_graph;
	l_history_graph.display_type 		:= c_display_type_graph;


------------------------------------------
-- Detailed report display objects
------------------------------------------
	
	-- SUMMARY FIELDS
	l_detailed_summary_object 			:= display_object(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
	l_detailed_summary_object.type 			:= c_detailedreport_summary_table;
	l_detailed_summary_object.display_type 		:= c_display_type_table;
	l_detailed_summary_object.title			:= 'Total Storage';
	l_detailed_summary_object.sql_table		:= 'stormon_hostdetail_view';
	l_detailed_summary_object.predicate		:= ' id = :id ';
	l_detailed_summary_object.default_order_by 	:= '		
	DECODE(type,
		''_TOTAL'',10,
		''_DISKS'',2,
		''_BACKUP_DISKS'',3,
		''_SWRAID'',4,
		''_VOLUME_MANAGER'',5,
		''_LOCAL_FILESYSTEM'',6,
		''NFS_EXCLUSIVE'',7,
		''NFS_SHARED'',8,
		''_ALL_DATABASES'',9,100) ASC';
	l_detailed_summary_object.error_message 	:= 'No Storage summary available for this host';	
	l_detailed_summary_object.tag			:= 'Total';
	l_detailed_summary_object.total_field		:= 'name';

	l_detailed_summary_object.column_titles				:= titleTable();
	l_detailed_summary_object.column_titles.EXTEND(5);
	l_detailed_summary_object.column_titles(1)		 	:= title_object(1,NULL);
	l_detailed_summary_object.column_titles(2)		 	:= title_object(40,NULL);
	l_detailed_summary_object.column_titles(3)		 	:= title_object(41,NULL);
	l_detailed_summary_object.column_titles(4)		 	:= title_object(42,NULL);
	l_detailed_summary_object.column_titles(5)		 	:= title_object(43,NULL);


	-- DISK FIELDS
	l_detailed_disk_object 					:= display_object(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
	l_detailed_disk_object.type 				:= c_detailed_disk_table;
	l_detailed_disk_object.display_type 			:= c_display_type_table;
	l_detailed_disk_object.title				:= 'Disks';
	l_detailed_disk_object.sql_table	 		:= 'storage_disk_view';
	l_detailed_disk_object.predicate			:= 'target_id = :id';
	l_detailed_disk_object.default_order_by 		:= NULL;
	l_detailed_disk_object.error_message 			:= 'No Disks detected on this system';	
	l_detailed_disk_object.tag				:= 'Disks';
	l_detailed_disk_object.total_field			:= 'path';

	l_detailed_disk_object.column_titles			:= titleTable();
	l_detailed_disk_object.column_titles.EXTEND(9);
	l_detailed_disk_object.column_titles(1)		 	:= title_object(52,NULL);
	l_detailed_disk_object.column_titles(2)		 	:= title_object(39,NULL);
	l_detailed_disk_object.column_titles(3)		 	:= title_object(40,NULL);
	l_detailed_disk_object.column_titles(4)		 	:= title_object(41,NULL);
	l_detailed_disk_object.column_titles(5)		 	:= title_object(42,NULL);
	l_detailed_disk_object.column_titles(6)		 	:= title_object(43,NULL);
	l_detailed_disk_object.column_titles(7)		 	:= title_object(44,NULL);
	l_detailed_disk_object.column_titles(8)		 	:= title_object(45,NULL);
	l_detailed_disk_object.column_titles(9)		 	:= title_object(46,NULL);

	
	-- SWAID FIELDS
	l_detailed_swraid_object 				:= display_object(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
	l_detailed_swraid_object.type 				:= c_detailed_swraid_table;
	l_detailed_swraid_object.display_type 			:= c_display_type_table;
	l_detailed_swraid_object.title				:= 'Storage managed by Software raid Manager';
	l_detailed_swraid_object.sql_table	 		:= 'storage_swraid_view';
	l_detailed_swraid_object.predicate			:= 'target_id = :id';
	l_detailed_swraid_object.default_order_by 		:= 'type';
	l_detailed_swraid_object.error_message			:= 'Storage managed by Software raid Manager not detected on this system ';
	l_detailed_swraid_object.tag				:= 'Software Raid';
	l_detailed_swraid_object.total_field			:= 'path';

	l_detailed_swraid_object.column_titles			:= titleTable();
	l_detailed_swraid_object.column_titles.EXTEND(8);
	l_detailed_swraid_object.column_titles(1)		:= title_object(52,NULL);
	l_detailed_swraid_object.column_titles(2)		:= title_object(39,NULL);
	l_detailed_swraid_object.column_titles(3)		:= title_object(40,NULL);
	l_detailed_swraid_object.column_titles(4)		:= title_object(41,NULL);
	l_detailed_swraid_object.column_titles(5)		:= title_object(42,NULL);
	l_detailed_swraid_object.column_titles(6)		:= title_object(43,NULL);
	l_detailed_swraid_object.column_titles(7)		:= title_object(44,NULL);
	l_detailed_swraid_object.column_titles(8)		:= title_object(45,NULL);


	-- VOLUME MANAGER FIELDS
	l_detailed_volume_object 				:= display_object(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
	l_detailed_volume_object.type 				:= c_detailed_volume_table;
	l_detailed_volume_object.display_type 			:= c_display_type_table;
	l_detailed_volume_object.sql_table	 		:= 'storage_volume_view';
	l_detailed_volume_object.predicate	 		:= 'target_id = :id';
	l_detailed_volume_object.default_order_by 		:= 'type';
	l_detailed_volume_object.title				:= 'Storage managed by Volume Manager';
	l_detailed_volume_object.error_message			:= 'Storage managed by Volume Manager not detected on this system ';
	l_detailed_volume_object.tag				:= 'Volume Manager';
	l_detailed_volume_object.total_field			:= 'path';

	l_detailed_volume_object.column_titles				:= titleTable();
	l_detailed_volume_object.column_titles.EXTEND(8);
	l_detailed_volume_object.column_titles(1)		 	:= title_object(52,NULL);
	l_detailed_volume_object.column_titles(2)		 	:= title_object(39,NULL);
	l_detailed_volume_object.column_titles(3)		 	:= title_object(40,NULL);
	l_detailed_volume_object.column_titles(4)		 	:= title_object(41,NULL);
	l_detailed_volume_object.column_titles(5)		 	:= title_object(42,NULL);
	l_detailed_volume_object.column_titles(6)		 	:= title_object(43,NULL);
	l_detailed_volume_object.column_titles(7)		 	:= title_object(44,NULL);
	l_detailed_volume_object.column_titles(8)		 	:= title_object(45,NULL);

	-- LOCAL FILESYSTEM FIELDS
	l_detailed_localfs_object 				:= display_object(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
	l_detailed_localfs_object.type 				:= c_detailed_localfs_table;
	l_detailed_localfs_object.display_type 			:= c_display_type_table;
	l_detailed_localfs_object.title				:= 'Local File Systems ';
	l_detailed_localfs_object.sql_table	 		:= 'storage_localfs_view';
	l_detailed_localfs_object.predicate	 		:= 'target_id = :id';
	l_detailed_localfs_object.default_order_by 		:= NULL;	
	l_detailed_localfs_object.error_message			:= 'No Local File Systems detected on this system';
	l_detailed_localfs_object.tag		 		:= 'Local Filesystem';	
	l_detailed_localfs_object.total_field			:= 'filesystem';	

	l_detailed_localfs_object.column_titles				:= titleTable();
	l_detailed_localfs_object.column_titles.EXTEND(8);
	l_detailed_localfs_object.column_titles(1)		 	:= title_object(47,NULL);
	l_detailed_localfs_object.column_titles(2)		 	:= title_object(39,NULL);
	l_detailed_localfs_object.column_titles(3)		 	:= title_object(40,NULL);
	l_detailed_localfs_object.column_titles(4)		 	:= title_object(41,NULL);
	l_detailed_localfs_object.column_titles(5)		 	:= title_object(42,NULL);
	l_detailed_localfs_object.column_titles(6)		 	:= title_object(43,NULL);
	l_detailed_localfs_object.column_titles(7)		 	:= title_object(44,NULL);
	l_detailed_localfs_object.column_titles(8)		 	:= title_object(48,NULL);

	-- NFS FILESYSTEM FIELDS
	l_detailed_nfs_object 				:= display_object(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
	l_detailed_nfs_object.type 			:= c_detailed_dedicated_nfs_table;
	l_detailed_nfs_object.display_type 		:= c_display_type_table;
	l_detailed_nfs_object.title			:= 'NFS Dedicated ';
	l_detailed_nfs_object.sql_table	 		:= 'storage_nfs_view';
	l_detailed_nfs_object.predicate	 		:= 'target_id = :id';
	l_detailed_nfs_object.default_order_by 		:= NULL;
	l_detailed_nfs_object.error_message		:= 'No Dedicated NFS storage mounted on this system';
	l_detailed_nfs_object.tag		 	:= 'NFS Dedicated';
	l_detailed_nfs_object.total_field		:= 'filesystem';

	l_detailed_nfs_object.column_titles			:= titleTable();
	l_detailed_nfs_object.column_titles.EXTEND(11);
	l_detailed_nfs_object.column_titles(1)		 	:= title_object(47,NULL);
	l_detailed_nfs_object.column_titles(2)		 	:= title_object(39,NULL);
	l_detailed_nfs_object.column_titles(3)		 	:= title_object(40,NULL);
	l_detailed_nfs_object.column_titles(4)		 	:= title_object(41,NULL);
	l_detailed_nfs_object.column_titles(5)		 	:= title_object(42,NULL);
	l_detailed_nfs_object.column_titles(6)		 	:= title_object(43,NULL);
	l_detailed_nfs_object.column_titles(7)		 	:= title_object(46,NULL);
	l_detailed_nfs_object.column_titles(8)		 	:= title_object(48,NULL);
	l_detailed_nfs_object.column_titles(9)		 	:= title_object(55,NULL);
	l_detailed_nfs_object.column_titles(10)		 	:= title_object(56,NULL);
	l_detailed_nfs_object.column_titles(11)		 	:= title_object(57,NULL);


	-- Shared NFS FILESYSTEM FIELDS
	l_detailed_shared_nfs_object 				:= display_object(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
	l_detailed_shared_nfs_object.type 			:= c_detailed_shared_nfs_table;
	l_detailed_shared_nfs_object.display_type 		:= c_display_type_table;
	l_detailed_shared_nfs_object.title			:= 'NFS Shared';
	l_detailed_shared_nfs_object.sql_table	 		:= 'storage_nfs_shared_view';
	l_detailed_shared_nfs_object.predicate	 		:= 'target_id = :id';
	l_detailed_shared_nfs_object.default_order_by 		:= NULL;
	l_detailed_shared_nfs_object.error_message		:= 'No Shared NFS storage mounted on this system';
	l_detailed_shared_nfs_object.tag		 	:= 'NFS Shared';	
	l_detailed_shared_nfs_object.total_field		:= 'filesystem';

	l_detailed_shared_nfs_object.column_titles			:= titleTable();
	l_detailed_shared_nfs_object.column_titles.EXTEND(11);
	l_detailed_shared_nfs_object.column_titles(1)		 	:= title_object(47,NULL);
	l_detailed_shared_nfs_object.column_titles(2)		 	:= title_object(39,NULL);
	l_detailed_shared_nfs_object.column_titles(3)		 	:= title_object(40,NULL);
	l_detailed_shared_nfs_object.column_titles(4)		 	:= title_object(41,NULL);
	l_detailed_shared_nfs_object.column_titles(5)		 	:= title_object(42,NULL);
	l_detailed_shared_nfs_object.column_titles(6)		 	:= title_object(43,NULL);
	l_detailed_shared_nfs_object.column_titles(7)		 	:= title_object(46,NULL);
	l_detailed_shared_nfs_object.column_titles(8)		 	:= title_object(48,NULL);
	l_detailed_shared_nfs_object.column_titles(9)		 	:= title_object(55,NULL);
	l_detailed_shared_nfs_object.column_titles(10)		 	:= title_object(56,NULL);
	l_detailed_shared_nfs_object.column_titles(11)		 	:= title_object(57,NULL);


	-- ORACLE DATABASE FIELDS
	l_detailed_oracledb_object 				:= display_object(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
	l_detailed_oracledb_object.type 			:= c_detailed_app_oracledb_table;
	l_detailed_oracledb_object.display_type 		:= c_display_type_table;
	l_detailed_oracledb_object.title			:= 'Storage managed by Oracle Database Server ';
	l_detailed_oracledb_object.sql_table	 		:= 'storage_oracledb_view';
	l_detailed_oracledb_object.predicate	 		:= 'target_id = :id';
	l_detailed_oracledb_object.default_order_by 		:=  ' 	
						appid,
						DECODE(appname,NULL,2,1) ASC';  -- appname is NULL for the total of a appid
	l_detailed_oracledb_object.error_message		:= 'Storage managed by Oracle Database Server not detected on this system';
	l_detailed_oracledb_object.tag		 		:= 'Oracle Database';
	l_detailed_oracledb_object.total_field			:= 'appid';

	l_detailed_oracledb_object.column_titles			:= titleTable();
	l_detailed_oracledb_object.column_titles.EXTEND(7);
	l_detailed_oracledb_object.column_titles(1)		 	:= title_object(49,NULL);
	l_detailed_oracledb_object.column_titles(2)		 	:= title_object(50,NULL);
	l_detailed_oracledb_object.column_titles(3)		 	:= title_object(51,NULL);
	l_detailed_oracledb_object.column_titles(4)		 	:= title_object(41,NULL);
	l_detailed_oracledb_object.column_titles(5)		 	:= title_object(42,NULL);
	l_detailed_oracledb_object.column_titles(6)		 	:= title_object(43,NULL);
	l_detailed_oracledb_object.column_titles(7)		 	:= title_object(44,NULL);


	-- ISSUE FIELDS
	l_issues_object 				:= display_object(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
	l_issues_object.type 				:= c_detailed_issues_table;
	l_issues_object.display_type 			:= c_display_type_table;
	l_issues_object.title				:= 'Storage Consistency Issues ';
	l_issues_object.sql_table	 		:= 'storage_issues_view';
	l_issues_object.predicate	 		:= '
		type = ''ISSUE'' 
		AND id = :id';
	l_issues_object.default_order_by 		:=  ' 	TIMESTAMP DESC';
	l_issues_object.error_message			:= 'No Storage consistency issues found for this host';
	l_issues_object.tag		 		:= 'Issues';

	l_issues_object.column_titles			:= titleTable();
	l_issues_object.column_titles.EXTEND(1);
	l_issues_object.column_titles(1)		:= title_object(53,NULL);


	-- WARNING FIELDS
	l_warnings_object 				:= display_object(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
	l_warnings_object.type 				:= c_detailed_warnings_table;
	l_warnings_object.display_type 			:= c_display_type_table;
	l_warnings_object.title				:= 'Storage Consistency Warnings ';
	l_warnings_object.sql_table	 		:= 'storage_issues_view';
	l_warnings_object.predicate	 		:= '
		type = ''WARNING'' 
		AND id = :id';
	l_warnings_object.default_order_by 		:=  ' 	TIMESTAMP DESC';
	l_warnings_object.error_message			:= 'No Storage consistency warnings found for this host';
	l_warnings_object.tag		 		:= 'Warnings';

	l_warnings_object.column_titles			:= titleTable();
	l_warnings_object.column_titles.EXTEND(1);
	l_warnings_object.column_titles(1)		:= title_object(54,NULL);

--	STORAGE.PRINTN(' End of Initialization ');

EXCEPTION
	WHEN OTHERS THEN
		STORAGE.PRINTN(' Error initializing '||SQLERRM);
		RAISE;
END initialize;


--------------------------------------------------
-- Procedure Name : gettime
-- Description    : get the time diff in secs
--                  
--          INPUT : last time in secs
--------------------------------------------------
PROCEDURE gettime(v_lasttime  IN OUT INTEGER, v_message IN VARCHAR2 DEFAULT NULL) IS

l_currenttime	INTEGER(20) := 0;
l_lasttime	INTEGER(20) := v_lasttime;
l_timeperiod	INTEGER(20) := 0;

BEGIN

	-- Fetch the current time in secs since 12AM
	SELECT 	ROUND(TO_CHAR(sysdate,'SSSSSSS')/100)
	INTO 	l_currenttime 
	FROM 	DUAL;

	v_lasttime := l_currenttime;

	CASE	
		-- If both timestamps are of the same day
		WHEN l_currenttime >= l_lasttime THEN
			l_timeperiod :=	 l_currenttime - l_lasttime;
		-- If timestamps are of different days
		-- base current secs on previous day ( 1 DAY = 86400 secs)
		ELSE
			l_timeperiod := (l_currenttime + 86400 ) - l_lasttime;
	END CASE;


	IF STORAGE.P_MODE != 'PRODUCTION' AND v_message IS NOT NULL THEN
		HTP.P(v_message||' = '||l_timeperiod||'<BR>');
		DBMS_OUTPUT.PUT_LINE(v_message||' = '||l_timeperiod);
	END IF;

	--RETURN l_timeperiod;

END gettime;

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
		l_args_list(l_args_list.LAST) := SUBSTR(l_values_string,1,l_sep_position-1);
		l_values_string := SUBSTR(l_values_string,l_sep_position+1);

	END LOOP;

	RETURN l_args_list;
	
END parse_arguments;

--------------------------------------------------
-- Procedure Name : get_display_object_id
-- Description    : generate a unique id for a display object
--
--          INPUT : display_object
--------------------------------------------------
FUNCTION get_display_object_id ( p_display_object IN display_object ) RETURN VARCHAR2 
IS
BEGIN

	RETURN p_display_object.display_type||'_'||p_display_object.type||'_'||REPLACE(p_display_object.tag,' ','_');

END get_display_object_id;

--------------------------------------------------
-- Procedure Name : display_tip
-- Description    : display underlined  title before table display
--                  category  
--          INPUT : target name
--------------------------------------------------
PROCEDURE display_tip( p_tip  IN stringTable ) IS

l_data	VARCHAR2(4000);

BEGIN

	IF p_tip IS NOT NULL AND p_tip.EXISTS(1) THEN

		FOR i IN p_tip.FIRST..p_tip.LAST LOOP
	            l_data := l_data || p_tip(i);
    		END LOOP;

	UTIL_PORTAL.include_portal_stylesheet;

		HTP.P('
	<TABLE  class="fullwidthtable" align="center" cellspacing=0 cellpadding=0>
	<TR>
		<TD class="OraTipText" NOWRAP ><IMG BORDER="0" SRC="/myImages/tip.gif" >Tip :'||l_data||'</TD>
	</TR>
	</TABLE>');
     
	END IF;

END display_tip;

--------------------------------------------------
-- Function  Name : check_for_zero
-- Description    : Returns 1 if the input is 0
--                  else returns the number
--                   INPUT : number
--                   OUTPUT : number
--------------------------------------------------
   function check_for_zero(
      p_number  in number )
      return number
   is
      l_number number;

   begin

       if (p_number != 0) then
         l_number := p_number;
       else
         l_number := 1;
       end if;    

       
      return l_number;
         
   end check_for_zero; -- end of function check_for_zero




--------------------------------------------------
-- Function  Name : get_storage_unit
-- Description    : Returns VARCHAR2 in TB, GB,MB
--                  
--                   INPUT : number
--                   OUTPUT : storage unit
--------------------------------------------------
   function get_storage_unit(
      p_number  in number )
      return VARCHAR2
   is
      l_unit   VARCHAR2(32);
      l_number number;

   begin

       l_number := to_number(p_number);
       if (l_number <= L_BASE_GB) then
         l_unit := 'MB';
       elsif ((l_number > L_BASE_GB) and (l_number <= L_BASE_TB) )  then
         l_unit := 'GB';
       elsif (l_number > L_BASE_TB) then
         l_unit := 'TB';
       end if;           
      return l_unit;         
   end get_storage_unit;  


--------------------------------------------------
-- Function  Name : get_fmt_storage
-- Description    : Returns number in TB, GB,MB
--
--                   INPUT : number
--                   OUTPUT : formatted number
--------------------------------------------------
   function get_fmt_storage(
      p_number  in number)
      return VARCHAR2
   is
      l_data VARCHAR2(32);

   begin


       if(p_number <= 0) then
         l_data := '-';
       elsif (p_number <= L_BASE_GB) then
         l_data := round(p_number/L_BASE_MB) || ' MB';
       elsif ((p_number > L_BASE_GB) and (p_number <= L_BASE_TB) )  then
         l_data := round(p_number/L_BASE_GB) || ' GB';
       elsif (p_number > L_BASE_TB) then
         l_data := round(p_number/L_BASE_TB,2) || ' TB';
       end if;
      return l_data;
   end get_fmt_storage;

--------------------------------------------------
-- Function  Name : get_fmt_storage
-- Description    : Returns number in TB, GB,MB
--                  
--                   INPUT : number
--                   OUTPUT : formatted number
--------------------------------------------------
   function get_fmt_storage(
      p_number  in VARCHAR2,
      p_unit    in VARCHAR2 )
      return number
   is
      l_data number;
      l_number number;

   begin

       l_number := to_number(p_number);


       if (p_unit = ' MB') then
         l_data := round(l_number/L_BASE_MB);
       elsif (p_unit = ' GB') then          
         l_data := round(l_number/L_BASE_GB);
       elsif(p_unit = ' TB') then
         l_data := round(l_number/L_BASE_TB,2);
       end if;           
       
      return l_data;         
   end ; 


--------------------------------------------------
-- Function  Name : get_fmt_AU_storage
-- Description    :
--
--                   INPUT : allocated/Used
--                   OUTPUT : formatted data A/U
--------------------------------------------------
   function get_fmt_AU_storage(
      p_allocated  in number,
      p_used       in number
   )
      return VARCHAR2
   is
      l_data VARCHAR2(256);

   begin

       
       if ((p_allocated = 0) and (p_used = 0))  then
           l_data := '-';
       elsif (p_allocated > 0) then
          if (p_used > 0) then
            l_data := get_fmt_storage(p_allocated) || ' / ' || RED_COLOR || get_fmt_storage(p_used);
          else
            l_data := get_fmt_storage(p_allocated) || ' / ' || RED_COLOR || '0';
          end if;
      end if; 

      return l_data;

   end get_fmt_AU_storage;

--------------------------------------------------
-- Function  Name : get_base_value
-- Description    : Returns number in TB, GB,MB
--                  
--                   INPUT : VARCHAR2
--                   OUTPUT : number
--------------------------------------------------
   function get_base_value(
      p_unit  in VARCHAR2 )
      return number
   is
      l_base number;

   begin

       if (p_unit = ' MB') then
         l_base := L_BASE_MB;
       elsif (p_unit = ' GB') then          l_base := L_BASE_GB;
       elsif(p_unit = ' TB') then
         l_base := L_BASE_TB;
       end if;           
      return l_base;         
   end get_base_value;     


--------------------------------------------------
-- Function Name  : get_chart_image
-- Description    : returns pie chart/bar chart image 
--                  of the data 
--                   INPUT : title,
--                           subtitle,
--                           seriescolors,
--                           pie_data,
--                           numrows,
--                           numcols,
--                           rowcol
--------------------------------------------------
FUNCTION get_chart_image(
			p_title        in VARCHAR2,
			p_subtitle     in VARCHAR2,
			p_fieldname    in stringTable,                     
			p_fieldvalue   in stringTable,                                         
			p_display_type in VARCHAR2 DEFAULT 'PIE',
			p_unit         in VARCHAR2 DEFAULT NULL,  
			p_bartag       in VARCHAR2 DEFAULT 'B',
			p_legend_position IN VARCHAR2 DEFAULT 'SOUTH'
                    ) return VARCHAR2 
is    

    l_image            VARCHAR2(32767);
    l_data             VARCHAR2(32767);
    l_chart_colors     VARCHAR2(32767);
    l_legend	       VARCHAR2(32767);
    l_chart_values     VARCHAR2(32767);
    l_series_width     number;
    l_width            number;
    l_height           number;  
    l_rowcol           VARCHAR2(16);

    l_graphic_width	NUMBER;  
    l_graphic_height	NUMBER;
    l_max_legend_size	NUMBER;
             
BEGIN

      IF p_fieldname IS NULL OR NOT p_fieldname.EXISTS(1) THEN
         RETURN NULL;
      END IF;

      l_chart_colors  := '99ff99,ffff99,ccffff,99ccff,ffffcc,99ffff,ffcccc,cccc99,00cccc,6699cc,cc0000,9999ff,ffff66,009999,00cc00,cc66cc,ff9999';
                
      if (trim(' ' from p_display_type) = 'PIE') then 

		-- Width and height of the pie graphic
		l_graphic_width := 280;  
		l_graphic_height := 250;

		IF p_legend_position IN ('SOUTH','NORTH') THEN
	
			l_height := l_graphic_height + ( p_fieldname.COUNT * 10 );			
			l_width := l_graphic_width; 
	
		ELSE

			SELECT	MAX(LENGTH(VALUE(a))) 
			INTO	l_max_legend_size
			FROM	TABLE ( CAST( p_fieldname AS stringTable ) ) a;
		
			l_width := l_graphic_width + ( l_max_legend_size * 7 );
			l_height := l_graphic_height;
		
		END IF;

                l_rowcol := 'ROW'; 
                                                                   	
      		FOR j IN p_fieldname.FIRST..p_fieldname.LAST LOOP										

					IF j = 1 THEN

						l_legend := p_fieldname(j)||' '|| get_fmt_storage(p_fieldvalue(j));				
						l_chart_values := p_fieldvalue(j);						

					ELSE
					
						l_legend := l_legend||','||p_fieldname(j)||' '||get_fmt_storage(p_fieldvalue(j));						
						l_chart_values := l_chart_values||','||p_fieldvalue(j);
						
					END IF;
					
		END LOOP;
      
      
      
	l_image := '<IMG  SRC="/' ||
  	    lower(UTIL_PORTAL.get_portal_schema)||'/Pie?width=' || l_width || chr(38) ||
            'height=' || l_height || chr(38) ||
            'title=' || replace(p_title,' ','%20') || chr(38) ||
            'subtitle=' || replace(p_subtitle,' ','%20') || chr(38) ||
            'footnote=' || '' || chr(38) ||
            'seriesnames=' || replace(l_legend,' ','%20') || chr(38) ||
            'data=' || replace(l_chart_values,' ','%20') || chr(38) ||
            'rows=' || p_fieldname.COUNT || chr(38) ||
            'columns=' || p_fieldname.COUNT || chr(38) ||
            'rowcol=' || l_rowcol || chr(38) ||
            'chartstyle=EFFECT3D' || chr(38) ||
            'legend='||p_legend_position || chr(38) ||
            'enablelegend=YES' || chr(38) ||
            'valuepercentage=PERCENT' || chr(38) ||
            'seriescolors=' || l_chart_colors || chr(38) ||
            'html=NO" >';
	else


		-- Width and height of the pie graphic
		l_graphic_width := 215;  
		l_graphic_height := 240;
		-- l_height := 275;

		IF p_legend_position IN ('SOUTH','NORTH') THEN
	
			l_height := l_graphic_height + ( p_fieldname.COUNT * 10 );			
			l_width := l_graphic_width; 
	
		ELSE

			SELECT	MAX(LENGTH(VALUE(a))) 
			INTO	l_max_legend_size
			FROM	TABLE ( CAST( p_fieldname AS stringTable ) ) a;
		
			l_width := l_graphic_width + ( l_max_legend_size * 7 );
			l_height := l_graphic_height;
		
		END IF;

                if (p_fieldname.count <= 2) then
                --   l_width := 175;
                   l_series_width := 20;
                else
                 --  l_width := 250;
                   l_series_width := 25;
                end if;
                
                l_rowcol := 'COLUMN'; 

      		FOR j IN p_fieldname.FIRST..p_fieldname.LAST LOOP										

					IF j = 1 THEN

						l_legend := p_bartag||j||': '||p_fieldname(j)||' '|| get_fmt_storage(p_fieldvalue(j));

					ELSE
					
						l_legend := l_legend||','||p_bartag||j||': '||p_fieldname(j)||' '||get_fmt_storage(p_fieldvalue(j));
						
					END IF;
					
					FOR k IN p_fieldvalue.FIRST..p_fieldvalue.LAST LOOP			
													
							IF k = 1 THEN
								IF j = 1 THEN
									l_chart_values := p_bartag||j||','||get_fmt_storage(p_fieldvalue(j),p_unit);						
								ELSE
									l_chart_values := l_chart_values||';'||p_bartag||j||','||get_fmt_storage(p_fieldvalue(j),p_unit);	
								END IF;
							ELSE
								l_chart_values := l_chart_values||','||0;
							END IF;
							
					END LOOP;
					
		END LOOP;

      l_chart_colors  := '99ff99,99ff99,99ff99,99ff99,99ff99,99ff99,99ff99,99ff99,99ff99,99ff99,99ff99,99ff99,99ff99,99ff99,99ff99,99ff99,99ff99';     	
     	l_image := '<IMG  SRC="/' ||
            lower(UTIL_PORTAL.get_portal_schema)||'/ChartsServlet?width=' || l_width || chr(38) ||
            'height=' || l_height || chr(38) ||
            'title=' || replace(p_title,' ','%20') || chr(38) ||
            'subtitle=' || replace(p_subtitle,' ','%20') || chr(38) ||
            'footnote=' || '' || chr(38) ||
            'seriesnames=' || replace(l_legend,' ','%20') || chr(38) ||
            'serieswidth=' || l_series_width || chr(38) ||            
            'data=' || replace(l_chart_values,' ','%20') || chr(38) ||
            'rows=' || p_fieldname.COUNT || chr(38) ||
            'columns=' || (p_fieldValue.COUNT + 1) || chr(38) ||
            'rowcol=' || l_rowcol || chr(38) ||
            'chartstyle=BASIC' || chr(38) ||
            'charttype=' || p_display_type || chr(38) ||            
            'xseriestype=' || chr(38) ||            
            'yfirstaxis=' || chr(38) ||            
            'ysecondaxis=' || chr(38) ||                                    
            'legend='||p_legend_position || chr(38) ||
            'enablelegend=YES' || chr(38) ||
            'pointlabel=NO' || chr(38) ||            
            'seriescolors=' || l_chart_colors || chr(38) ||
            'html=NO" >';

	--htp.p('l_image ' || l_image);
     
	END IF;       
                
	RETURN l_image;
    
END get_chart_image;
                                       

--------------------------------------------------
-- Function  Name : get_storage_usage_meter
-- Description    : Returns a meter showing %used Vs %Free
--
--                   INPUT : used,free
--                   OUTPUT : formatted number
--------------------------------------------------
   function get_storage_usage_meter(
      p_rawsize      in number,
      p_used_percent in number,
      p_size	     IN NUMBER DEFAULT 1
   )
      return VARCHAR2
   is
      l_data VARCHAR2(32767);

      l_width		NUMBER := 75;
      l_height		NUMBER := 10;      
      l_fontsize	INTEGER := 1;
		
   begin

      
	l_width := l_width + ( p_size - 1 ) * l_width;   
	l_height := l_height + ( p_size - 1 ) * .5 * l_height;
	l_fontsize := l_fontsize + ( p_size - 1 ) * l_fontsize;
	

	-- Doest look good above 15
	IF l_height > 15 THEN
		l_height := 15;
	END IF;
	
	IF l_fontsize > 2 THEN
		l_fontsize := 2;
	END IF;

      IF (p_rawsize != 0) THEN
	      l_data  := '<TABLE width=100 cellspacing=0 cellpadding=0 align=center >
			     <TR>
			        <TD align=center>
			           <TABLE width='||l_width||' height='||l_height||' border=0 class="RegionBorder" cellspacing=1 cellpadding=1>
			              <TR>
			                <TD bgcolor=#cc0000 height=3 width=' || p_used_percent || '%' || '>' || '<IMG BORDER="0" SRC="/myImages/dot.gif"></TD>
			                <TD bgcolor=#ffffff height=3 width=' || (100 - p_used_percent) || '%' || '>' || '<IMG BORDER="0" SRC="/myImages/dot.gif"></TD>
			              </TR>
			            </TABLE>
			         </TD>
                	         <TD align=left valign=middle><font face=Arial size='||l_fontsize||' >' || p_used_percent || '%' || '</font>
	                         </TD>
	                       </TR>
        	          </TABLE>' ;
       ELSE
       		l_data := ' - ';
       
       END IF;                   

       return l_data;
end  get_storage_usage_meter;

--------------------------------------------------
-- Function  Name : get_history_link
-- Description    : 
--
--                   INPUT : group/host id
--                   OUTPUT : HREF for the group/host History
--------------------------------------------------
   function get_history_link(
	p_id   in storage_summaryObject_view.id%TYPE,
	p_name IN VARCHAR2 DEFAULT 'History'
   )
      return VARCHAR2
   is

      l_winprop3  VARCHAR2(256);
      l_data      VARCHAR2(2048);
      
   begin

	IF p_id IS NULL THEN
		RETURN NULL;
	END IF;

      l_winprop3 := 'toolbar=no,location=no,directories=no,status=no,menubar=no,scrollbars=no,resizable=yes,left=100,top=100,width=725,height=480';                          
      l_data        := '''/pls/'
                       || UTIL_PORTAL.get_portal_schema
                       || '/'
                       || UTIL_PORTAL.get_portlet_schema
                       || '.STORAGE.display_storage_history?p_period='
                       || 'Q'
                       || chr(38)
                       || 'p_storage_type='
                       || 'TOTAL'
                       || chr(38)
                       || 'p_id='
                       || p_id                    
                       || '''';
                              
       	l_data := HTF.anchor(curl => 'javascript:;',
	      	      	     cattributes => 'style="color: blue" onMouseOver="return false; "
      	                                     onMouseOut="return  false; "  onClick="javascript:windowhandle=window.open(' || l_data || ',''' || 'storagehistwindow' ||  ''', ' || '''' || l_winprop3 || ''''  || ');windowhandle.focus();"  ',
                             ctext =>  p_name);

      return l_data;

   end get_history_link;   


-- To be deleted
   function get_history_link(
	p_summary   in storage_summaryObject_view%ROWTYPE
   )
      return VARCHAR2
   is

      l_winprop3  VARCHAR2(256);
      l_data      VARCHAR2(2048);
      
   begin

	IF p_summary.id IS NULL THEN
		RETURN NULL;
	END IF;

      l_winprop3 := 'toolbar=no,location=no,directories=no,status=no,menubar=no,scrollbars=no,resizable=yes,left=100,top=100,width=725,height=480';                          
      l_data        := '''/pls/'
                       || UTIL_PORTAL.get_portal_schema
                       || '/'
                       || UTIL_PORTAL.get_portlet_schema
                       || '.STORAGE.display_storage_history?p_period='
                       || 'Q'
                       || chr(38)
                       || 'p_storage_type='
                       || 'TOTAL'
                       || chr(38)
                       || 'p_id='
                       || p_summary.id                    
                       || '''';
                              
       	l_data := HTF.anchor(curl => 'javascript:;',
	      	      	     cattributes => 'style="color: blue" onMouseOver="return false; "
      	                                     onMouseOut="return  false; "  onClick="javascript:windowhandle=window.open(' || l_data || ',''' || 'storagehistwindow' ||  ''', ' || '''' || l_winprop3 || ''''  || ');windowhandle.focus();"  ',
                             ctext =>  'History');

      return l_data;

   end get_history_link;   



--------------------------------------------------
-- Function  Name : get_issue_fmt_link
-- Description    : 
--
--                   INPUT : group/host name
--                   OUTPUT : HREF for the group
--------------------------------------------------
   function get_issue_fmt_link(
      p_id	   in storage_summaryObject_view.id%TYPE,
      p_tag	   in VARCHAR2,
      p_issue_type in VARCHAR2 DEFAULT 'ISSUE', -- ISSUE or WARNING
      p_host_type  in VARCHAR2 DEFAULT 'ALL_HOSTS' -- Can be one of ALL_HOSTS , SUMMARIZED_HOSTS, FAILED_HOSTS , NOT_COLLECTED_HOSTS, ISSUE_HOSTS
   )
      return VARCHAR2
   is

      l_data    VARCHAR2(2048) := NULL;
      l_winprop VARCHAR2(2048) := 'toolbar=yes,location=no,directories=yes,status=yes,menubar=yes,scrollbars=yes,resizable=yes,left=50,top=50,width=900,height=600';

   begin

	IF p_id IS NULL THEN
		RETURN p_tag;
	END IF;

   	
	l_data        := '''/pls/'
       	            || UTIL_PORTAL.get_portal_schema
               	    || '/'
                    || UTIL_PORTAL.get_portlet_schema
       	            || '.STORAGE.display_issues?p_id='
                    || p_id
                    || chr(38)
		    || 'p_message_type='
		    || p_issue_type
                    || chr(38)
		    || 'p_host_type='
		    || p_host_type
                    || '''';

	l_data := HTF.anchor(curl => 'javascript:;',
     	 	      	      cattributes => 'style="color: blue" onMouseOver="return false; "onMouseOut="return  false; "  onClick="javascript:windowhandle=window.open(' || l_data || ',''' || 'issuewindow' ||  ''', ' || '''' || l_winprop || ''''  || ');windowhandle.focus();"  ',
                       	      ctext =>  p_tag);   
            		
      	
	return l_data;                                            	               
       
    end get_issue_fmt_link;


-- To be deleted
   function get_issue_fmt_link(
      p_summary    in storage_summaryObject_view%ROWTYPE,
      p_tag	   in VARCHAR2,
      p_issue_type in VARCHAR2 DEFAULT 'ISSUE', -- ISSUE or WARNING
      p_host_type  in VARCHAR2 DEFAULT 'ALL_HOSTS' -- Can be one of ALL_HOSTS , SUMMARIZED_HOSTS, FAILED_HOSTS , NOT_COLLECTED_HOSTS, ISSUE_HOSTS
   )
      return VARCHAR2
   is

      l_data    VARCHAR2(2048) := NULL;
      l_winprop VARCHAR2(2048) := 'toolbar=yes,location=no,directories=yes,status=yes,menubar=yes,scrollbars=yes,resizable=yes,left=50,top=50,width=900,height=600';                                
   begin

	IF p_summary.id IS NULL THEN
		RETURN p_tag;
	END IF;

   	
	l_data        := '''/pls/'
       	            || UTIL_PORTAL.get_portal_schema
               	    || '/'
                    || UTIL_PORTAL.get_portlet_schema
       	            || '.STORAGE.display_issues?p_id='
                    || p_summary.id
                    || chr(38)
		    || 'p_message_type='
		    || p_issue_type
                    || chr(38)
		    || 'p_host_type='
		    || p_host_type
                    || '''';

	l_data := HTF.anchor(curl => 'javascript:;',
     	 	      	      cattributes => 'style="color: blue" onMouseOver="return false; "onMouseOut="return  false; "  onClick="javascript:windowhandle=window.open(' || l_data || ',''' || 'issuewindow' ||  ''', ' || '''' || l_winprop || ''''  || ');windowhandle.focus();"  ',
                       	      ctext =>  p_tag);   
            		
      	
	return l_data;                                            	               
       
    end get_issue_fmt_link;

--------------------------------------------------
-- Function  Name : get_hosts_not_collected_link
-- Description    : 
--
--                   INPUT : group/host name
--                   OUTPUT : HREF for the group
--------------------------------------------------
   function get_hosts_not_collected_link(
      p_id	   in storage_summaryObject_view.id%TYPE,
      p_tag	   in VARCHAR2
   )
      return VARCHAR2
   is

      l_data    VARCHAR2(2048) := NULL;
      l_winprop VARCHAR2(2048) := 'toolbar=yes,location=no,directories=yes,status=yes,menubar=yes,scrollbars=yes,resizable=yes,left=50,top=50,width=900,height=600';                                
   begin

	IF p_id IS NULL THEN
		RETURN p_tag;
	END IF;
       		
	-- HOST LIST PAGE
	l_data        := '''/pls/'
         	            || UTIL_PORTAL.get_portal_schema
                	    || '/'
	                    || UTIL_PORTAL.get_portlet_schema
        	            || '.STORAGE.display_hosts_not_collected?p_id='
	                    || p_id
                            || '''';

	l_data := HTF.anchor(curl => 'javascript:;',
	      	 	      	      cattributes => 'style="color: blue" onMouseOver="return false; "onMouseOut="return  false; "  onClick="javascript:windowhandle=window.open(' || l_data || ',''' || 'hosts_not_collcted_window' ||  ''', ' || '''' || l_winprop || ''''  || ');windowhandle.focus();"  ',
                             	      ctext =>  p_tag );		
            	      		
	return l_data;                                            	               
       
    end get_hosts_not_collected_link;


-- To be deleted
   function get_hosts_not_collected_link(
      p_summary    in storage_summaryObject_view%ROWTYPE,
      p_tag	   in VARCHAR2
   )
      return VARCHAR2
   is

      l_data    VARCHAR2(2048) := NULL;
      l_winprop VARCHAR2(2048) := 'toolbar=yes,location=no,directories=yes,status=yes,menubar=yes,scrollbars=yes,resizable=yes,left=50,top=50,width=900,height=600';                                

   begin

	IF p_summary.id IS NULL THEN
		RETURN p_tag;
	END IF;
       		
	-- HOST LIST PAGE
	l_data        := '''/pls/'
         	            || UTIL_PORTAL.get_portal_schema
                	    || '/'
	                    || UTIL_PORTAL.get_portlet_schema
        	            || '.STORAGE.display_hosts_not_collected?p_id='
	                    || p_summary.id
                            || '''';

	l_data := HTF.anchor(curl => 'javascript:;',
	      	 	      	      cattributes => 'style="color: blue" onMouseOver="return false; "onMouseOut="return  false; "  onClick="javascript:windowhandle=window.open(' || l_data || ',''' || 'hosts_not_collcted_window' ||  ''', ' || '''' || l_winprop || ''''  || ');windowhandle.focus();"  ',
                             	      ctext =>  p_tag );		
            	      		
	return l_data;                                            	               
       
    end get_hosts_not_collected_link;



--------------------------------------------------
-- Function  Name : get_hostdetails_fmt_link
-- Description    : 
--
--                   INPUT : summaryObject
--                   OUTPUT : HREF for the group
--------------------------------------------------
FUNCTION get_hostdetails_fmt_link ( 
	p_page_url	  	IN 	VARCHAR2,
	p_name			IN	VARCHAR2,
	p_type			IN	VARCHAR2,
	p_tag			IN	VARCHAR2,
	p_chart_type		IN	VARCHAR2 DEFAULT 'PIE' ) RETURN VARCHAR2 
IS

l_data		VARCHAR2(2048);
l_plsql_url	VARCHAR2(2048);

BEGIN

--	l_data := '<A target='||p_name||' HREF="javascript:link_change_display('''|| 'SINGLE_HOST_REPORT' || ''',''FALSE'',''' ||REPLACE(p_name,' ','%20') || ''',''' || REPLACE(p_type,' ','%20')  || ''',''' || p_chart_type || ''','''','''','''','''||''','''','''');"  style="color: blue" >'|| p_tag ||'</A>';

	l_plsql_url := '''/pls/'
         	            || UTIL_PORTAL.get_portal_schema
                	    || '/'
	                    || UTIL_PORTAL.get_portlet_schema
        	            || '.STORAGE.CHANGE_DISPLAY?'
	                    || 'p_page_url='||REPLACE(p_page_url,CHR(38),'%26')|| CHR(38)
	                    || 'p_main_tab=SINGLE_HOST_REPORT'|| CHR(38)
	                    || 'p_search=FALSE'|| CHR(38)
	                    || 'p_group_name='||REPLACE(p_name,' ','%20')|| CHR(38)
	                    || 'p_group_type='||REPLACE(p_type,' ','%20')|| CHR(38)
	                    || 'p_chart_type='||p_chart_type|| CHR(38)
	                    || 'p_drill_down_group_type='||CHR(38)
	                    || 'p_sub_tab='|| CHR(38)
	                    || 'p_host_type='|| CHR(38)
	                    || 'p_orderfield='|| CHR(38)
	                    || 'p_ordertype='|| CHR(38)
	                    || 'p_display_object_type='			    
                            || '''';

	l_data := '<A HREF="javascript:;" style="color: blue" onMouseOver="return false; "onMouseOut="return  false; "  onClick="javascript:windowhandle=window.open('||l_plsql_url||',''single_host_report_window'', ''toolbar=yes,location=no,directories=yes,status=yes,menubar=yes,scrollbars=yes,resizable=yes,left=50,top=50,width=1000,height=700'');windowhandle.focus();"  >'||p_tag||'</A>';


	RETURN l_data;

END get_hostdetails_fmt_link;


--------------------------------------------------
-- Function  Name : get_drilldown_link
-- Description    : 
--
--                   INPUT : 
--			name
--			type
--			chart_type
--			drilldown_type
--			host_type
--	
--                   OUTPUT : HREF for the group
--------------------------------------------------
FUNCTION get_drilldown_link (
	p_main_tab		IN	VARCHAR2,
	p_name			IN	VARCHAR2,
	p_type			IN	VARCHAR2,
	p_tag			IN	VARCHAR2,
	p_chart_type		IN	VARCHAR2 DEFAULT 'PIE',
	p_drill_down_group_type	IN	VARCHAR2 DEFAULT 'REPORTING_DATACENTER',
	p_sub_tab		IN	VARCHAR2 DEFAULT 'SUMMARY',
	p_host_type		IN	VARCHAR2 DEFAULT 'ALL_HOSTS'
)
RETURN VARCHAR2
IS

l_data		VARCHAR2(2048);

BEGIN
       	      
	l_data := '<a HREF="javascript:link_change_display('''||REPLACE(p_main_tab,' ','%20') || ''',''FALSE'',''' ||REPLACE(p_name,' ','%20') || ''',''' || REPLACE(p_type,' ','%20')  || ''',''' || p_chart_type || ''','''||p_drill_down_group_type||''','''||p_sub_tab || ''',''' || p_host_type || ''','''','''','''');"  style="color: blue" >'|| p_tag ||'</a>';
    
	RETURN l_data;
      
END get_drilldown_link;

--------------------------------------------------
-- Procedure Name : l_create_name
-- Description    : Local procedure to create names to be used.
--                   INPUT : Portlet     - Portlet instance.
--                           Name        - Preference name to be created.
--                           Type        - Type to be associated.
--                           Description - Description of preference name.
--------------------------------------------------
   PROCEDURE l_create_name (
      p_portlet_instance      in  WWPRO_API_PROVIDER.portlet_instance_record,
      p_name                  in  VARCHAR2,
      p_type_name             in  VARCHAR2,
      p_description           in  VARCHAR2)
   is
      l_reference_path        VARCHAR2(255) :=
         PREFERENCE_PATH||p_portlet_instance.reference_path;
   begin

      WWPRE_API_NAME.create_name(
         p_path          => l_reference_path,
         p_name          => p_name,
         p_type_name     => p_type_name,
         p_description   => p_description,
         p_language      => WWCTX_API.get_nls_language);

   end l_create_name; -- procedure end of l_create_name
--------------------------------------------------
-- Function  Name : get_saved_value
-- Description    : Returns current display type
--                   INPUT : Preference path
--                   OUTPUT : Display type
--------------------------------------------------
   function get_saved_value(
      p_preference_path  in VARCHAR2,
      p_data_name        in VARCHAR2 
   )
      return VARCHAR2
   is
      l_custom_1              VARCHAR2(255);


   begin

      l_custom_1 := UTIL_PORTAL.load_value(
                       p_data_name,
                       p_preference_path );


      return l_custom_1; -- return the stored display type
         
   end get_saved_value; -- end of function get_display_type


--------------------------------------------------
-- Procedure Name : l_draw_footnote
-- Description    : Local procedure to display footnote.
--          INPUT : NONE
--------------------------------------------------
   PROCEDURE l_draw_footnote 
   is
      l_footnote             VARCHAR2(1024);
   begin
      HTP.tableopen(cborder       => 'border=0',
                    calign        => 'center',
                    cattributes   => 'cellspacing=0 cellpadding=5 width=100%');

      HTP.tableRowOpen;

      -- set report footnote
--      l_footnote :=  HTF.fontOpen(
                       -- ccolor =>  UTIL_PORTAL.FOOT_NOTE_TEXT_COLOR,
                       -- cface  =>  UTIL_PORTAL.FOOT_NOTE_FONT_FACE,
--                        csize  =>  '1' ) ||
--                     UTIL_PORTAL.FOOT_NOTE ||
--                     HTF.fontClose;

      HTP.tableheader(calign      => 'left',
                      cnowrap     => ' ',
--                      cvalue      => '<A HREF="' ||
--                                     UTIL_PORTAL.FOOT_NOTE_ACTION || '">' ||
--                                     l_footnote || '</A>',
                      cattributes => ' height=10 class=PortletHeaderColor');

      HTP.tableRowClose;

      HTP.tableClose;

   end l_draw_footnote;

--------------------------------------------------
-- Procedure Name : change_display
-- Description    : Refresh the storage summary with newer display type 
--                   INPUT : ReferencePath  - Portlet instance id 
--                           Page URL       - URL of the calling page 
--                           Display Type   - Type to display metric values 
--------------------------------------------------
PROCEDURE change_display (
	p_page_url              IN    VARCHAR2,
	p_main_tab	      IN    VARCHAR2 DEFAULT 'MAIN_TAB_DATACENTER',
	p_search		      IN    VARCHAR2 DEFAULT 'FALSE',
	p_group_name	      IN    VARCHAR2 DEFAULT 'ALL',
	p_group_type	      IN    VARCHAR2 DEFAULT 'REPORTING_DATACENTER',
	p_chart_type            in    VARCHAR2 DEFAULT 'PIE',
	p_drill_down_group_type IN    VARCHAR2 DEFAULT 'REPORTING_DATACENTER',
	p_sub_tab	      	      IN    VARCHAR2 DEFAULT 'SUMMARY',
	p_host_type             IN    VARCHAR2 DEFAULT 'ALL_HOSTS',
	p_orderfield            IN    INTEGER  DEFAULT 3, 
	p_ordertype             IN    VARCHAR2 DEFAULT 'DEFAULT',
	p_display_object_type   IN    VARCHAR2 DEFAULT 'top'
)
IS

l_page_url	VARCHAR2(4096); 
      
BEGIN

      l_page_url := p_page_url || CHR(38) ||
		'p_main_tab='|| p_main_tab             || CHR(38) ||
		'p_search='|| p_search       || CHR(38) ||
		'p_group_name='|| p_group_name             || CHR(38) ||
		'p_group_type='|| p_group_type            || CHR(38) ||
		'p_chart_type='       || p_chart_type        || CHR(38) ||
		'p_drill_down_group_type='      || p_drill_down_group_type     || CHR(38) ||
		'p_sub_tab='      || p_sub_tab     || CHR(38) ||
		'p_host_type='        || p_host_type           || CHR(38) ||
		'p_orderfield='      || p_orderfield     || CHR(38) || 
		'p_ordertype='       || p_ordertype || CHR(38) ||
		'p_display_object_type=' ||p_display_object_type||CHR(35)||p_display_object_type
--		'p_display_object_type=' ||p_display_object_type||CHR(38)||CHR(35)||p_display_object_type
		;
       
      OWA_UTIL.redirect_url(l_page_url);
      
END change_display;


--------------------------------------------------
-- Procedure Name : get_group_report
-- Description    : Refresh the storage summary with newer display type 
--                   INPUT : ReferencePath  - Portlet instance id
--                           Page URL       - URL of the calling page 
--                           Display Type   - datacenter
--			     LOB	    - LOB
--			     chart type
--------------------------------------------------
   PROCEDURE get_group_report (
--      p_reference_path        IN    VARCHAR2,
      p_page_url              IN    VARCHAR2,
      p_main_tab	      IN    VARCHAR2 DEFAULT 'MAIN_TAB_DATACENTER',
      p_group_type	      IN    stormon_group_table.type%TYPE DEFAULT 'REPORTING_DATACENTER',
      p_group_name	      IN    stormon_group_table.name%TYPE DEFAULT 'ALL'	
   )
   is	
   begin

	STORAGE.CHANGE_DISPLAY( --p_reference_path,
				p_page_url,p_main_tab,'FALSE',p_group_name,p_group_type,'PIE',p_group_type);
      
   end get_group_report;

--------------------------------------------------------------------------------
--
-- name : quick_lookup
--
-- description : execute the quick look up report
--
-- args : 
--  referencePath  
--  page URL       - URL of the calling page
--  main_tab   
--  group name
--  group type
--
--
------------------------------------------------------------------------------------------
PROCEDURE quick_lookup (
--	p_reference_path	IN	VARCHAR2,
	p_page_url		IN	VARCHAR2,
	p_main_tab		IN	VARCHAR2 DEFAULT 'MAIN_TAB_HOSTLOOKUP',
	p_type			IN	VARCHAR2 DEFAULT 'REPORTING_DATACENTER',
	p_value			IN	VARCHAR2 DEFAULT 'ALL'
) IS
BEGIN
	STORAGE.CHANGE_DISPLAY(--p_reference_path,
	p_page_url,p_main_tab,'TRUE',p_value,p_type,'PIE',p_type);

END quick_lookup;



--------------------------------------------------
-- Function Name  : l_show_all
-- Description    : Local procedure to display targets
--                  and storage details in storage UI.
--          INPUT : PortletRecord   - Record of portlet instance.
--          OUTPUT: Result - return false if no targets
--                           otherwise true
--------------------------------------------------

   function l_show_all(
      p_portlet_record  	in out WWPRO_API_PROVIDER.portlet_runtime_record,
      p_main_tab		IN VARCHAR2,
      p_search		        IN VARCHAR2,
      p_group_name       	in VARCHAR2, 
      p_group_type       	in VARCHAR2,
      p_chart_type         	in VARCHAR2,
      p_drill_down_group_type	IN VARCHAR2,
      p_sub_tab      		in VARCHAR2,
      p_host_type            	in VARCHAR2,
      p_orderfield      	in INTEGER,	
      p_ordertype       	in VARCHAR2,
      p_display_object_type	IN VARCHAR2
      )
   return boolean
   is
      -- target  variables
      l_custom_1              VARCHAR2(32767);

      runvar1                 integer;
      runvar2                 integer;

      
begin

PRINTN(' IN  function l_show_all ');

HTP.P ('

<STYLE type = "text/css">
body { margin-left: .1%; margin-right: 1% }

.clean {}

TABLE.boxsectiontable { border-style:none ; margin-top:1em ; padding:0 ; }
TABLE.boxsectiontable TR.titlerow { background-color:#CCCCCC; }
TABLE.boxsectiontable TR.titlerow TH FONT.titlefont { color:#336699; }
TABLE.boxsectiontable TR.titlerow TR.contentrow { width:100%; }
TABLE.boxsectiontable TR.titlerow TR.contentrow TD.contentcolumn { width=:100%; }
TABLE.boxsectiontable TABLE.contenttable { border-style:solid; border-width:thin; width=100%; padding:0 ; border-color:#CCCC8C; width:100%; }
TABLE.boxsectiontable TABLE.contenttable TABLE.innercontent { width:100%; padding:2 ; }

TABLE.sectiontable { border-style:none ; margin-left:0em; margin-top:1em ; padding:0 ; width:100%; }
TABLE.sectiontable TR.titlerow {}
TABLE.sectiontable TH.headercolumn { width:100%; text-align:left; white-space:nowrap; }
TABLE.sectiontable TR.titlerow TH.headercolumn FONT.titlefont { color:#336699; }
TABLE.sectiontable TR.titlerow TR.contentrow { width:100%; }
TABLE.sectiontable TR.titlerow TR.contentrow TD.contentcolumn { width:100%; }
TABLE.sectiontable TABLE.contenttable { border-style:solid none none none; border-width:.25em; width=100%; padding:0 ; border-color:#CCCC8C; width:100%; }
TABLE.sectiontable TABLE.contenttable TABLE.innercontent { width:100%; padding:2 ; }

TABLE.datatable { border:none ; margin-top:.5em ; width:100%; border-collapse:collapse }
TABLE.datatable TR.headerrow {}
TABLE.datatable TR.headerrow TH.titleheader { text-align:center; white-space:nowrap; background-color:#CCCC99; border:2px outset #f7f7e7; }
TABLE.datatable TR.headerrow TH.titleheader FONT.titlefont { color:#336699; font-weight:bold; text-decoration:none; vertical-align:bottom; }
TD.lightcolor { background-color:#f7f7e7;color:#000000; vertical-align:baseline; border:1px solid #cccc99 }
TD.darkcolor { background-color:#ffffff; color:#000000; vertical-align:baseline; border:1px solid #cccc99 }

TABLE.subsectiontable { border-style:solid ; margin-top:.5em ; padding:0; border-color:#CCCC8C; border-width:.1em; width:100%; }
TABLE.subsectiontable TR.stitlerow { background-color:#CCCC99; }
TABLE.subsectiontable TR.stitlerow TH.stitleheader { text-align:left; width:100%; white-space:nowrap; }
TABLE.subsectiontable TR.stitlerow TH.stitleheader FONT.stitlefont { color:#336699; }
TABLE.subsectiontable TR.stitlerow TR.contentrow { width:100%; }
TABLE.subsectiontable TR.stitlerow TR.contentrow TD.contentcolumn { width=:100%; }

TD.charcolumn { text-align:left; white-space:nowrap; }
TD.numcolumn { text-align:right; white-space:nowrap; }
TD.graphiccolumn { text-align:center; white-space:nowrap; }

.stdfont {font-family:Arial, Helvetica, Geneva, sans-serif; font-size:10pt; text-indent:1}
.sortableheaderlink { color:#336699; }
.linkcolor { color:blue; }
.tabletitlecolor { color:#336699; }

TABLE.tlinktable { border-style: none none solid none; border-width:.25em;  margin-left:1em; margin-top:1em ; border-color:#CCCC8C; width:100%; padding:0; }

TABLE.linktable { border-style: none none none none; border-width:.1em;  margin-left:0em;; width:100%; padding:0; border-color:#CCCC8C; }
TABLE.linktable TD.linkcolumn { width:100%; text-align:right; white-space:nowrap; }
TABLE.linktable TD.linkcolumn FONT.linkfont{ font-family: Arial, Helvetica; font-size: 10pt; }

.OraHeader,.x13 {font-family:Arial,Helvetica,Geneva,sans-serif;font-size:16pt;color:#336699}
.OraBGAccentDark,.x9 {background-color:#cccc99}
.p_OraSpacingHeader,.x3m {margin:4px 0px 2px 0px}

TABLE.titletable { border-style:none; margin-top:1em ; margin-left:0em; padding:0; width:100%; }
TABLE.titletable TD.titledata { font-family:Arial,Helvetica,Geneva,sans-serif;font-size:16pt;color:#336699; width:100%; }
TABLE.titletable TD.titleunderline { background-color:#cccc8c ; width:100% }

TABLE.choiceboxtable { border-style: solid none solid none; border-width:.1em;  margin-left:0em; width:100%; padding:0; border-color:#CCCC8C; background-color:#f7f7e7 }

TABLE.emptywidthtable { border-style:none; margin-left:1em; padding:0; width:90%; }
TABLE.fullwidthtable { border-style:none; padding:0; width:100%; }
TABLE.nowidthtable { border-style:none; padding:0; }

FONT.errormessagefont {font-family:Arial, Helvetica, Geneva, sans-serif; font-style:italic; font-size:10pt; text-indent:1; color:RGB(175,0,0) }

</STYLE>

');

      display_storage_summary(p_main_tab,
			      p_search,
			      p_group_name,
                              p_group_type,    
			      p_chart_type,
			      p_drill_down_group_type,                          
			      p_sub_tab,
			      p_host_type,	
                              p_orderfield, 
                              p_ordertype, 
			      p_display_object_type,
			      p_portlet_record,				                              
                              REPLACE(p_portlet_record.page_url,chr(38),'%26')
			);                               

-- Close the column and row in the outer oemip table and open a new one
	HTP.P('
		</TD>		
	</TR>
	<TR>
		<TD>
		<BR><BR>
');

      display_tip(stringTable('<BR>1. Aggregation not done for hosts with Issues or hosts with no data collection',
			      '<BR>2. Refer to FAQ for resolving outstanding Issues ')
		);

-- Close the column and row in the outer oemip table and open a new one
	HTP.P('
		<BR><BR>
		</TD>		
	</TR>
	<TR>
		<TD>
');
      
	RETURN TRUE;
      

   end l_show_all;
--------------------------------------------------

--------------------------------------------------
-- Procedure Name : l_show
-- Description    : Local procedure to display Storage UI.
--                   INPUT : PortletRecord   - Record of portlet instance.
--------------------------------------------------
   PROCEDURE l_show (
	      p_portlet_record        in out WWPRO_API_PROVIDER.portlet_runtime_record
	)
   is

      l_portlet_info          WWPRO_API_PROVIDER.portlet_record;
      l_title                 VARCHAR2(50) := 'Storage Summary ';
      l_has_customize         boolean := false;
      l_has_edit              boolean := false;
      l_main_tab	      VARCHAR2(1024);
      l_search		      VARCHAR2(10) := 'FALSE';
      l_group_name	      stormon_group_table.name%TYPE;
      l_group_type            stormon_group_table.type%TYPE;
      l_chart_type            VARCHAR2(1024) := 'PIE';
      l_drill_down_group_type VARCHAR2(1024) := 'REPORTING_DATACENTER';
      l_report_type	      VARCHAR2(1024) := 'SUMMARY';
      l_host_type             VARCHAR2(1024) := 'ALL_HOSTS';
      l_orderfield            INTEGER := 3;
      l_ordertype             VARCHAR2(1024) := 'DEFAULT';
      l_display_object_type   VARCHAR2(1024) := 'top';
      l_result                boolean;
      l_ref_path              VARCHAR2(255);
      l_names                 OWA.VC_ARR;
      l_values                OWA.VC_ARR;

   begin

      PRINTN(' In procedure l_show ');
         
      l_portlet_info := get_portlet_info(
                           p_portlet_record.provider_id,
                           p_portlet_record.language);
                                        
      l_ref_path :=  p_portlet_record.reference_path;  

      WWPRO_API_PARAMETERS.retrieve( l_names, l_values );

      FOR runvar in 1..l_names.count loop

	PRINTN(' IN l_show '||l_names(runvar)||' '||l_values(runvar));

	IF (l_names(runvar) = 'p_main_tab' ) THEN
      	   l_main_tab := l_values(runvar);
	ELSIF (l_names(runvar) = 'p_search' ) THEN
      	   l_search := l_values(runvar);
	ELSIF (l_names(runvar) = 'p_group_name' ) THEN
      	   l_group_name := l_values(runvar);
	ELSIF (l_names(runvar) = 'p_group_type' ) THEN
      	   l_group_type := l_values(runvar);
	ELSIF (l_names(runvar) = 'p_chart_type' ) THEN
      	   l_chart_type := l_values(runvar);
	ELSIF (l_names(runvar) = 'p_drill_down_group_type' ) THEN
      	   l_drill_down_group_type := l_values(runvar);
	ELSIF (l_names(runvar) = 'p_sub_tab' ) THEN
      	   l_report_type := l_values(runvar);
	ELSIF (l_names(runvar) = 'p_host_type' ) THEN
      	   l_host_type := l_values(runvar);
	ELSIF (l_names(runvar) = 'p_orderfield' ) THEN
      	   l_orderfield := l_values(runvar);
	ELSIF (l_names(runvar) = 'p_ordertype' ) THEN
      	   l_ordertype := l_values(runvar);
	ELSIF (l_names(runvar) = 'p_display_object_type' ) THEN
      	   l_display_object_type := l_values(runvar);
	END IF;

      END LOOP;
    
      if ( l_main_tab is null ) then
	l_main_tab := 'MAIN_TAB_DATACENTER';
	l_search := 'FALSE';
 	l_group_name := 'ALL';
	l_group_type := 'REPORTING_DATACENTER';
	l_drill_down_group_type := 'REPORTING_DATACENTER';
	l_report_type := 'SUMMARY';
      end if; 

      if ( l_chart_type is null ) then
          l_chart_type := 'PIE';
      end if;   

      if ( l_drill_down_group_type is null ) then
	   	l_drill_down_group_type := l_group_type;
      END IF; 

      if ( l_report_type is null ) then
	   	l_report_type := 'SUMMARY';
      END IF;      
      
      if ( l_host_type is null ) then
          l_host_type := 'ALL_HOSTS';
      end if;
         
      if ( l_orderfield is null ) then
          l_orderfield := 3;
      end if;

      if (l_ordertype is null ) then
          l_ordertype := 'DEFAULT';
      end if;   

      if (l_display_object_type is null ) then
          l_display_object_type := 'top';
      end if;

      if ( p_portlet_record.has_title_region ) then
         WWUI_API_PORTLET.draw_portlet_header(
            p_provider_id        => p_portlet_record.provider_id,
            p_portlet_id         => p_portlet_record.portlet_id,
            p_title              => l_title,
            p_has_details        => false,
            p_has_edit           => l_has_customize,
            p_has_edit_defaults  => l_has_edit,
            p_has_help           => false, 
            p_has_about          => false,
            p_referencepath      => p_portlet_record.reference_path,
            p_back_url           => p_portlet_record.page_url);
      end if;

      WWUI_API_PORTLET.open_portlet(p_portlet_record.has_border);

      HTP.P('<layer name="tooltip" bgcolor="#FFFFCC" visibility="hide"></layer>');   
      HTP.p('<script LANGUAGE=JavaScript>
      
             IE=(document.all)?1:0;
             NS=(document.layers)?1:0;

             function toolTip(e,msg,on) { 
               if (!IE && !NS) {
                 if (!msg) msg = '''';
                 window.status = msg; 
                 return true;
               }
               if (IE) {
                 if (window.event.srcElement.title == '''') { 
                   window.event.srcElement.title = msg;
                 }
               }    
               else if (NS) {
                 if (on) {
                   document.layers["tooltip"].document.write(''<table border=0><tr><td>''+msg+''</td></tr></table>''); 
                   document.layers["tooltip"].document.close(); 
                   document.layers["tooltip"].top = e.pageY+10;
                   document.layers["tooltip"].left= e.pageX-45; 
                   document.layers["tooltip"].visibility="show"; 
                 }
                 else document.layers["tooltip"].visibility="hide"; 
               }
               return true;
             }');
      
      HTP.P('function PopUp( Dest)
             {
               lov_win = window.open( Dest, "_blank", "width=780,height=580,scrollbars=yes,resizable=yes,menubar=yes,location=no" );
               lov_win.opener = self;
             }');  

      HTP.P('function loadpage(myvalue)
             {
               var url = location.href;	
               var i =   url.indexOf(''#'');
               if (i != -1) url   = url.substring(0,i);
               location.href = url + ''#'' + myvalue;
             }');


      HTP.P('</script>'); 
      

-- the get_group_report javascript
      HTP.formOpen(curl        => UTIL_PORTAL.get_portlet_schema ||'.STORAGE.get_group_report',
                   cmethod     => 'get', 
                   ctarget     => NULL,
                   cenctype    => NULL,
                   cattributes => 'name="showform_' ||p_portlet_record.reference_path || '"');

      HTP.p('<script LANGUAGE=JavaScript>
              function link_get_group_report(object0,object1,object2) {
 	         var main_tab=null;
                 var group_type=null;
                 var group_name=null;
                 
		 main_tab=object0;
                 group_type =  object1;
                 group_name = object2[object2.selectedIndex].value; ' || 
                'document.forms["showform_' || p_portlet_record.reference_path || '"].p_main_tab.value=main_tab; ' ||

                'document.forms["showform_' || p_portlet_record.reference_path || '"].p_group_type.value=group_type; ' ||

                'document.forms["showform_' || p_portlet_record.reference_path || '"].p_group_name.value=group_name; ' ||
                                                                                                                               
                'document.forms["showform_' || p_portlet_record.reference_path || '"].submit(); ' ||
                ' }</script>');	

--      HTP.p('<INPUT TYPE=hidden name=p_reference_path value="' || PREFERENCE_PATH || p_portlet_record.reference_path || '">');

      HTP.p('<INPUT TYPE=hidden name=p_page_url value="' || p_portlet_record.page_url || '">');

      HTP.p('<INPUT TYPE=hidden name=p_main_tab value="' || '' || '">');

      HTP.p('<INPUT TYPE=hidden name=p_group_type value="' || '' || '">');

      HTP.p('<INPUT TYPE=hidden name=p_group_name value="' || '' || '">');
                                        
      HTP.formClose;     


-- Javascript to re-execute the report
      HTP.formOpen(curl        => UTIL_PORTAL.get_portlet_schema ||'.STORAGE.change_display',
                   cmethod     => 'get', 
                   ctarget     => NULL,
                   cenctype    => NULL,
                   cattributes => 'name="showform2_' || p_portlet_record.reference_path || '"');

      HTP.p('<script LANGUAGE=JavaScript>

              function link_change_display(main_tab,search,parent_name,parent_type,chart_type,drill_down_group_type,report_type,host_type,orderfield,ordertype,display_object_type) {

                document.forms["showform2_' || p_portlet_record.reference_path || '"].p_main_tab.value=main_tab; ' ||

		'document.forms["showform2_' || p_portlet_record.reference_path || '"].p_search.value=search; ' ||

                'document.forms["showform2_' || p_portlet_record.reference_path || '"].p_group_name.value=parent_name; ' ||	

                'document.forms["showform2_' || p_portlet_record.reference_path || '"].p_group_type.value=parent_type; ' ||

                'document.forms["showform2_' || p_portlet_record.reference_path || '"].p_chart_type.value=chart_type; ' ||       

                'document.forms["showform2_' || p_portlet_record.reference_path || '"].p_drill_down_group_type.value=drill_down_group_type; ' ||

                'document.forms["showform2_' || p_portlet_record.reference_path || '"].p_sub_tab.value=report_type; ' ||     

                'document.forms["showform2_' || p_portlet_record.reference_path || '"].p_host_type.value=host_type; ' ||       

                'document.forms["showform2_' || p_portlet_record.reference_path || '"].p_orderfield.value=orderfield; ' ||                                                                     

                'document.forms["showform2_' || p_portlet_record.reference_path || '"].p_ordertype.value=ordertype; ' ||                                                              

               'document.forms["showform2_' || p_portlet_record.reference_path || '"].p_display_object_type.value=display_object_type; ' ||                                                              

                'document.forms["showform2_' || p_portlet_record.reference_path || '"].submit(); ' ||
                ' }
           </script>');


 --     HTP.P('<INPUT TYPE=hidden name=p_reference_path value="' || PREFERENCE_PATH || p_portlet_record.reference_path || '">');

      HTP.p('<INPUT TYPE=hidden name=p_page_url value="' || p_portlet_record.page_url || '">');

      HTP.p('<INPUT TYPE=hidden name=p_main_tab value="' || '' || '">');

      HTP.p('<INPUT TYPE=hidden name=p_search value="' || '' || '">');

      HTP.p('<INPUT TYPE=hidden name=p_group_name value="' || '' || '">');

      HTP.p('<INPUT TYPE=hidden name=p_group_type value="' || '' || '">');
                                        
      HTP.p('<INPUT TYPE=hidden name=p_chart_type value="' || '' || '">');

      HTP.p('<INPUT TYPE=hidden name=p_drill_down_group_type value="' || '' || '">');

      HTP.p('<INPUT TYPE=hidden name=p_sub_tab value="' || '' || '">');

      HTP.p('<INPUT TYPE=hidden name=p_host_type value="' || '' || '">');
         
      HTP.p('<INPUT TYPE=hidden name=p_orderfield value="' || '' || '">');

      HTP.p('<INPUT TYPE=hidden name=p_ordertype value="' || '' || '">');

      HTP.p('<INPUT TYPE=hidden name=p_display_object_type value="' || '' || '">');

      HTP.formClose;                    


-- Quick lookup java script
      HTP.formOpen(curl        => UTIL_PORTAL.get_portlet_schema ||'.STORAGE.QUICK_LOOKUP',
                   cmethod     => 'get', 
                   ctarget     => NULL,
                   cenctype    => NULL,
                   cattributes => 'name="showform3_' ||p_portlet_record.reference_path || '"');

      HTP.p('<script LANGUAGE=JavaScript>
              function quick_lookup() {
                 var type=null;
                 var value=null;
                 
                 for (var i=0;i<3;i++) {
                    if(document.formui.theradio[i].checked == true) {
			if ( i == 0 ){
	                      type = ''HOST'';       
			}
			else if ( i == 1 ){
				type = ''REPORTING_DATACENTER'';
			}
			else{
				type = ''REPORTING_LOB'';
			}
                    }                 
                 }
                 
                 value = document.formui.insearch.value; ' ||
                 
                'document.forms["showform3_' ||p_portlet_record.reference_path || '"].p_type.value=type; ' ||	

                'document.forms["showform3_' ||p_portlet_record.reference_path || '"].p_value.value=value; ' ||

                'document.forms["showform3_' ||p_portlet_record.reference_path || '"].submit(); ' ||
                ' }
           </script>');

--      HTP.P('<INPUT TYPE=hidden name=p_reference_path value="' || PREFERENCE_PATH || p_portlet_record.reference_path || '">');

      HTP.p('<INPUT TYPE=hidden name=p_page_url value="' || p_portlet_record.page_url || '">');
                    
      HTP.p('<INPUT TYPE=hidden name=p_main_tab value="' || 'MAIN_TAB_HOSTLOOKUP' || '">');

      HTP.P('<INPUT TYPE=hidden name=p_type value="' || '' || '">');

      HTP.p('<INPUT TYPE=hidden name=p_value value="' || '' || '">');
                                                 
      HTP.formClose;                    

	l_result := STORAGE.L_SHOW_ALL(p_portlet_record,
			     l_main_tab, 
			     l_search,
                             l_group_name,
                             l_group_type,
			     l_chart_type,
			     l_drill_down_group_type,
			     l_report_type,
                             l_host_type,                              
			     l_orderfield,
			     l_ordertype,
			     l_display_object_type
                            );               
                        
      if ( l_result = true ) then 
         l_draw_footnote();                
      else
         UTIL_PORTAL.display_error( 'Storage Report  NOT customized');
      end if;

      WWUI_API_PORTLET.close_portlet;

   end l_show; -- procedure end of l_show;
--------------------------------------------------


--------------------------------------------------
-- Procedure Name : l_show_about
-- Description    : Local procedure to display storage About.
--                   INPUT : PortletRecord - Record of portlet instance.
--------------------------------------------------
   PROCEDURE l_show_about (
      p_portlet_record in out WWPRO_API_PROVIDER.portlet_runtime_record)
   is
   begin

      UTIL_PORTAL.draw_mode_pages_header();

      HTP.p('<BR><CENTER>
             <TABLE align=center     border=0
                    cellspacing=0    cellpadding=0>');

      HTP.p('<TR><TD colspan=2 align=center>
                <font face=Arial size=5>About Storage Portlet</font>
             </TD></TR>');

      HTP.p('<TR><TD colspan=2 align=center>'
                ||chr(38)||'nbsp;
             </TD></TR>');

      HTP.p('<TR>
                <TD><font face=Arial size=3><B>Version' ||
                   chr(38) || 'nbsp;</B></font></TD>
                <TD><font face=Arial size=3>' || CURRENT_VERSION ||
                   '</font></TD>
             </TR>');

      HTP.p('<TR>
                <TD><font face=Arial size=3><B>Source' ||
                   chr(38) || 'nbsp;</B></font></TD>
                <TD><font face=Arial size=3>STORAGE package
                   </font></TD>
             </TR>');

      HTP.p('<TR>
                <TD><font face=Arial size=3><B>Type' ||
                   chr(38) || 'nbsp;</B></font></TD>
                <TD><font face=Arial size=3>PL/SQL portlet
                   </font></TD>
             </TR>');

      HTP.p('<TR>
                <TD><font face=Arial size=3><B>Owner' ||
                   chr(38) || 'nbsp;</B></font></TD>
                <TD><font face=Arial size=3>Global IT Web Development Team
                   </font></TD>
             </TR>');

      HTP.p('</TABLE></CENTER>');

      UTIL_PORTAL.draw_mode_pages_footer();

   end l_show_about; -- procedure end of l_show_about;
--------------------------------------------------

--------------------------------------------------
-- Procedure Name : l_show_help
-- Description    : Local procedure to display storage Help.
--                   INPUT : PortletRecord   - Record of portlet instance.
--------------------------------------------------
   PROCEDURE l_show_help (
      p_portlet_record   in out WWPRO_API_PROVIDER.portlet_runtime_record)
   is
   begin

      HTP.p('<script LANGUAGE=JavaScript>');
      HTP.p('PopUp(''/myHelp/storage.html'')');         
      HTP.p('</script>');
      
   end l_show_help; -- procedure end of l_show_help;
--------------------------------------------------



--------------------------------------------------
-- Procedure Name : l_show_details
-- Description    : Local procedure to display storage Details.
--                   INPUT : PortletRecord   - Record of portlet instance.
--------------------------------------------------
--   PROCEDURE l_show_details (
--      p_portlet_record    in out WWPRO_API_PROVIDER.portlet_runtime_record)
--   is
--   begin
--      HTP.p('Not implemented');
--   end l_show_details; -- procedure end of l_show_details;
--------------------------------------------------

--------------------------------------------------
-- Procedure Name : l_show_preview
-- Description    : Local procedure to display storage Preview.
--                   INPUT : PortletRecord   - Record of portlet instance.
--------------------------------------------------
   PROCEDURE l_show_preview (
      p_portlet_record    in out WWPRO_API_PROVIDER.portlet_runtime_record)
   is
   begin
      null;
   end l_show_preview; -- procedure end of l_show_preview;
--------------------------------------------------
----------------------------------------------------------------------

--------------------------------------------------
-- Function  Name : get_portlet_info
-- Description    : Returns details of the portlet in portlet_record structure.
--                   INPUT : ProviderId - Identifier for the provider.
--                           Language   - Language to return strings in.
--                  OUTPUT : Portlet    - Record of the portlet's properties.
--------------------------------------------------
   function get_portlet_info (
      p_provider_id       in  integer,
      p_language          in  VARCHAR2)
   return WWPRO_API_PROVIDER.portlet_record
   is
      portlet_info        WWPRO_API_PROVIDER.portlet_record;
   begin
      portlet_info.name                     := 'STORAGE';
      portlet_info.id                       :=  STORAGE_PROVIDER.PORTLET_STORAGE;

      portlet_info.title                    := 'Storage';
      portlet_info.description              := 'DC,LOB and Hosts Storage';

      portlet_info.provider_id              := p_provider_id;
      portlet_info.language                 := p_language;

      portlet_info.timeout                  := 300;
      portlet_info.timeout_msg              :='Storage Portlet timed out: Query took longer than '||portlet_info.timeout ||' seconds';

      portlet_info.api_version              := WWPRO_API_PROVIDER.API_VERSION_1;

      portlet_info.has_show_edit            := false;
      portlet_info.has_show_edit_defaults   := false;
      portlet_info.has_show_preview         := true;

      portlet_info.call_is_runnable         := true;
      portlet_info.call_get_portlet         := true;
      portlet_info.has_show_link_mode       := true;

      portlet_info.accept_content_type      := 'text/html';

      portlet_info.created_on               := '26-MAR-01';
      portlet_info.created_by               := 'Rajesh Kumar';

      portlet_info.last_updated_on          := sysdate;
      portlet_info.last_updated_by          := 'Rajesh Kumar';

      portlet_info.preference_store_path    := PREFERENCE_PATH;

      return portlet_info;

   end get_portlet_info; -- function end of get_portlet_info
--------------------------------------------------

--------------------------------------------------
-- Function  Name : is_runnable
-- Description    : Determines if the portlet can be run.
--                   INPUT : ProviderId     - Identifier for the provider.
--                           ReferencePath  - Set when method show is invoked.
--                  OUTPUT : Boolean answer.
--------------------------------------------------
   function is_runnable (
      p_provider_id       in  integer,
      p_reference_path    in VARCHAR2)
   return boolean
   is
   begin

      if (p_reference_path is null)
      then
         -- Caller is provider framework.
         -- Portlet will be displayed in provider repository, only if
         -- logged-in user is part of the OEM group.

-- TODO: create group and replace OEM used below
         return WWSEC_API.is_user_in_group(
                   WWSEC_API.id(WWCTX_API.get_user), -- UserId of logged-in user
                   WWSEC_API.group_id('STORAGE'));       -- GroupId of OEM group

      else
         -- Caller is making security check before displaying portlet
         -- Again, Portlet will be displayed, only if
         -- logged-in user is part of the OEM group.

         return WWSEC_API.is_user_in_group(
                   WWSEC_API.id(WWCTX_API.get_user), -- UserId of logged-in user
                   WWSEC_API.group_id('STORAGE'));       -- GroupId of OEM group

      end if;

   end is_runnable; -- function end of is_runnable
--------------------------------------------------

--------------------------------------------------
-- Procedure Name : register
-- Description    : Allows the portlet to do instance-level initialization.
--                   INPUT : Portlet    - Portlet instance.
--------------------------------------------------
   PROCEDURE register (
      p_portlet_instance      in  WWPRO_API_PROVIDER.portlet_instance_record)
   is
      l_reference_path        VARCHAR2(255) :=
         PREFERENCE_PATH||p_portlet_instance.reference_path;
   begin

      WWPRE_API_NAME.create_path(l_reference_path);

      l_create_name(p_portlet_instance, 'main_tab',   'STRING', 'main_tab');
      l_create_name(p_portlet_instance, 'search',   'STRING', 'search');
      l_create_name(p_portlet_instance, 'group_name',   'STRING', 'group_name');
      l_create_name(p_portlet_instance, 'group_type',  'STRING', 'group_type');    
      l_create_name(p_portlet_instance, 'chart_type',  'STRING', 'chart_type'); 
      l_create_name(p_portlet_instance, 'drill_down_group_type',  'STRING', 'drill_down_group_type');     
      l_create_name(p_portlet_instance, 'report_type',  'STRING', 'report_type');  
      l_create_name(p_portlet_instance, 'host_type',  'STRING', 'host_type');  
      l_create_name(p_portlet_instance, 'orderfield',  'INTEGER', 'orderfield');
      l_create_name(p_portlet_instance, 'ordertype',  'STRING', 'ordertype');
      l_create_name(p_portlet_instance, 'display_object_type',  'STRING', 'display_object_type');
      l_create_name(p_portlet_instance, 'customization_1', 'STRING', 'Customization 1');
      l_create_name(p_portlet_instance, 'customization_2', 'STRING', 'Customization 2');
      l_create_name(p_portlet_instance, 'customization_3', 'STRING', 'Customization 3');
      l_create_name(p_portlet_instance, 'customization_4', 'STRING', 'Customization 4');
      l_create_name(p_portlet_instance, 'customization_5', 'STRING', 'Customization 5'); 
            
   end register; -- procedure end of register
--------------------------------------------------

--------------------------------------------------
-- Procedure Name : deregister
-- Description    : Allows the portlet to do instance-level cleanup.
--                   INPUT : Portlet    - Portlet instance.
--------------------------------------------------
   PROCEDURE deregister (
      p_portlet_instance      in  WWPRO_API_PROVIDER.portlet_instance_record)
   is
   begin

      WWPRE_API_NAME.delete_path(
         PREFERENCE_PATH||p_portlet_instance.reference_path);

   end deregister; -- procedure end of deregister
--------------------------------------------------

--------------------------------------------------
-- Procedure Name : show
-- Description    : Displays the portlet page based on a mode.
--                   INPUT : PortletRecord   - Record of portlet instance.
--------------------------------------------------
   PROCEDURE show (
      p_portlet_record        in out WWPRO_API_PROVIDER.portlet_runtime_record
   )
   is
      l_portlet_info          WWPRO_API_PROVIDER.portlet_record;
   begin

      PRINTN(' IN show');

      l_portlet_info := get_portlet_info(
                           p_portlet_record.provider_id,
                           p_portlet_record.language);

      if (not is_runnable(
                 p_portlet_record.provider_id,
                 p_portlet_record.reference_path)
         )
      then
         util_portal.portlet_error(
            l_portlet_info.name,
            'security',
            'Not Runnable',
            'show');
         raise WWPRO_API_PROVIDER.PORTLET_SECURITY_EXCEPTION;
      end if;

      if    (p_portlet_record.exec_mode = WWPRO_API_PROVIDER.MODE_SHOW)
      then
         l_show(p_portlet_record);

      elsif (p_portlet_record.exec_mode = WWPRO_API_PROVIDER.MODE_SHOW_ABOUT)
      then
         l_show_about(p_portlet_record);

      elsif (p_portlet_record.exec_mode = WWPRO_API_PROVIDER.MODE_SHOW_HELP)
      then
         l_show_help(p_portlet_record);

      elsif (p_portlet_record.exec_mode = WWPRO_API_PROVIDER.MODE_SHOW_DETAILS)
      then
		HTP.p('Not implemented');
	-- l_show_details(p_portlet_record);

      elsif (p_portlet_record.exec_mode = WWPRO_API_PROVIDER.MODE_PREVIEW)
      then
         l_show_preview(p_portlet_record);

      else
         util_portal.portlet_error(
            l_portlet_info.name,
            'execution',
            'Unknown Execution Mode',
            'show');
         raise WWPRO_API_PROVIDER.PORTLET_EXECUTION_EXCEPTION;
      end if;

   end show; -- procedure end of show
--------------------------------------------------

--------------------------------------------------
-- Procedure Name : copy
-- Description    : Copies the portlet's customization and default settings
--                  from a portlet instance to a new portlet instance.
--                   INPUT : PortletInfo     - Record of portlet info.
--------------------------------------------------
   PROCEDURE copy (
      p_copy_portlet_info     in WWPRO_API_PROVIDER.copy_portlet_record)
   is
      src                     VARCHAR2(100);
      dst                     VARCHAR2(100);
   begin

      -- Get each of the name/value pairs stored from srcreferencepath
      -- and copy the value to dstreferencepath
      src := PREFERENCE_PATH || p_copy_portlet_info.srcreferencepath;
      dst := PREFERENCE_PATH || p_copy_portlet_info.dstreferencepath;

      -- display type
      util_portal.store_value(
         'customization_1',
         util_portal.load_value('customization_1', src),
         dst);

      util_portal.store_value(
         'customization_2',
         util_portal.load_value('customization_2', src),
         dst);

   end copy; -- procedure end of copy
--------------------------------------------------
--------------------------------------------------
-- Function  Name : describe_parameters
-- Description    : Returns the portlet parameter table.
--                   INPUT : ProviderId - Identifier for the provider.
--                           Language   - Language to return strings in.
--                  OUTPUT : Portlet    - Record of the portlet's properties.
--------------------------------------------------
   function describe_parameters (
      p_provider_id           in  integer,
      p_language              in  VARCHAR2)
   return WWPRO_API_PROVIDER.portlet_parameter_table
   is
      param_tab               WWPRO_API_PROVIDER.portlet_parameter_table;
   begin

      return param_tab;

   end describe_parameters; -- function end of describe_parameters
--------------------------------------------------

------------------------------------------------
-- PRINT POTLET TABLE OPEN
------------------------------------------------
PROCEDURE print_ptable_open(p_cellspacing VARCHAR2 default  '1',
                            p_cellpadding VARCHAR2 default  '4'
                           )  
IS

BEGIN
       HTP.tableopen(cborder      => 'border=0',
                     calign       => 'center',
                     cattributes  => 'width=100% cellspacing=' || p_cellspacing || ' cellpadding=' || p_cellpadding || ' class=""');
END;


------------------------------------------------
-- PRINT POTLET ROW OPEN
------------------------------------------------
PROCEDURE print_prow_open (
     p_rowcolor   VARCHAR2 DEFAULT NULL,
     p_rowbgcolor VARCHAR2 DEFAULT NULL
)
IS

BEGIN
    if (p_rowcolor is not NULL) then
    HTP.tablerowopen(calign      => '',
                     cvalign     => '',
                     cattributes => 'class=' || p_rowcolor );
    else
    HTP.tablerowopen(calign      => '',
                     cvalign     => '',
                     cattributes => 'bgcolor=' || p_rowbgcolor );    
    end if;                 
END;

------------------------------------------------
-- PRINT A COLORED LINE 
------------------------------------------------
PROCEDURE print_line(
   p_attrib  in VARCHAR2
)  IS

BEGIN
       HTP.tablerowopen;

       HTP.tableData( cvalue      => '<IMG BORDER="0" SRC="/myImages/dot.gif" WIDTH="800" HEIGHT="1">', 
                     cnowrap     => ' ', 
                     cattributes => p_attrib);                    
       HTP.tablerowclose;
END;     
                
------------------------------------------------
-- PRINT POTLET COLUMN
------------------------------------------------
PROCEDURE print_pcol (p_col      VARCHAR2  DEFAULT NULL,
                      p_align    VARCHAR2  DEFAULT 'RIGHT',
                      p_width    VARCHAR2  DEFAULT NULL, 
                      p_colspan  number    DEFAULT NULL
                     ) IS

BEGIN

	IF p_colspan IS NOT NULL THEN

	       HTP.tabledata(cvalue      => WWUI_API_PORTLET.portlet_subheadertext(
                                     NVL(p_col,'-')),
                     cnowrap     => '',
                     cattributes => ' align=' || p_align ||                                    
                                    ' colspan=' || p_colspan ||                                    
                                    ' width=' || p_width);
                                                                        
	ELSE

	       HTP.tabledata(cvalue      => WWUI_API_PORTLET.portlet_subheadertext(
	                                    NVL(p_col,'-')),
	                     cnowrap     => ' ',
	                     cattributes => 'align=' || p_align ||
	                                    ' width=' || p_width );

	END IF;
END;

------------------------------------------------
-- PRINT POTLET HEADER COLUMN
------------------------------------------------
PROCEDURE print_phcol (p_col     VARCHAR2    DEFAULT NULL,
                       p_align   VARCHAR2    DEFAULT 'CENTER',
                       p_width   VARCHAR2    DEFAULT NULL,
		       p_colspan number      DEFAULT 1,
                       p_rowspan number      DEFAULT 1  		       
                     ) IS

BEGIN
       HTP.tabledata(cvalue      => WWUI_API_PORTLET.portlet_subheadertext(
                                     '<B>' || p_col || '</B>'),
                     cnowrap     => '',
                     cattributes => ' align=' || p_align ||
				    ' colspan=' || p_colspan ||
				    ' rowspan=' || p_rowspan ||
				    ' width=' || p_width );				    			    
END;


------------------------------------------------
-- PRINT POTLET HEADER
------------------------------------------------
PROCEDURE print_pheader(p_title  VARCHAR2  DEFAULT NULL,
                        p_align  VARCHAR2  DEFAULT 'LEFT')  IS

BEGIN
       HTP.tableheader(cvalue      => WWUI_API_PORTLET.portlet_text(p_title,1),
                       cnowrap     => ' ',
                       cattributes => 'align=' || p_align  );
END;


------------------------------------------------
-- PRINT POTLET LINE BREAK
------------------------------------------------
PROCEDURE print_line_break  IS

BEGIN
       HTP.P('<BR>');
END;


-----------------------------------------------
-- PRINT POTLET COLUMN OPEN
------------------------------------------------
PROCEDURE print_col_open (p_attrib  VARCHAR2 DEFAULT NULL)
IS
BEGIN
       HTP.P('<TD ' || p_attrib || '>');
 
END print_col_open;

--------------------------------------------------
-- Procedure Name : get_dc_lob_from_name
-- Description    : from the group name and group type parse the datacenter and lob
--          INPUT : 
--			group name
--			group type
--			datacenter vaariable
--			lob variable
--------------------------------------------------
PROCEDURE get_dc_lob_from_name(	p_group_name	IN	stormon_group_table.name%TYPE,
				p_group_type	IN	stormon_group_table.type%TYPE,
				p_datacenter	OUT	VARCHAR2,
				p_lob		OUT	VARCHAR2)
IS

BEGIN

	IF p_group_type = 'REPORTING_ALL' THEN

		p_datacenter	:= 'ALL';
		p_lob		:= 'ALL';

	ELSIF	p_group_type = 'REPORTING_DATACENTER' THEN

		p_datacenter	:= p_group_name;
		p_lob		:= 'ALL';

	ELSIF p_group_type = 'REPORTING_LOB' THEN

		p_datacenter	:= 'ALL';
		p_lob		:= p_group_name;

	ELSIF p_group_type = 'REPORTING_DATACENTER_LOB' THEN

		p_datacenter	:= SUBSTR(p_group_name,1,INSTRB(p_group_name,'-')-1);
		p_lob		:= SUBSTR(p_group_name,INSTRB(p_group_name,'-')+1);			

	END IF;

END get_dc_lob_from_name;

--------------------------------------------------
-- Procedure Name : display_storage_summary
-- Description    : Display data centers / Lob current storage data
--          INPUT : 
--------------------------------------------------
PROCEDURE display_storage_summary (
	p_main_tab		IN VARCHAR2,
	p_search		IN VARCHAR2,
	p_group_name		IN VARCHAR2,
	p_group_type		IN VARCHAR2,
	p_chart_type		IN VARCHAR2,  
	p_drill_down_group_type IN VARCHAR2,
	p_sub_tab		IN VARCHAR2,
	p_host_type		IN VARCHAR2, 
	p_orderfield		IN INTEGER,  
	p_ordertype		IN VARCHAR2,  
	p_display_object_type	IN VARCHAR2,
	p_portlet_record	IN OUT WWPRO_API_PROVIDER.portlet_runtime_record,
	p_page_url		IN VARCHAR2
)
IS
BEGIN

	STORAGE.PRINTN(' Executing 
	STORAGE.DISPLAY_STORAGE_SUMMARY ('''||
	p_main_tab||''',
	'''||p_search||''',
	'''||p_group_name||''',
	'''||p_group_type||''',
	'''||p_chart_type||''',  
	'''||p_drill_down_group_type||''',
	'''||p_sub_tab||''',
	'''||p_host_type||''', 
	'||p_orderfield||',  
	'''||p_ordertype||''',  
	'''||p_display_object_type||''',
	p_portlet_record	IN OUT WWPRO_API_PROVIDER.portlet_runtime_record,
	'''||p_page_url||'''
)');

	IF p_main_tab = 'SINGLE_HOST_REPORT' THEN

	       STORAGE.SINGLE_HOST_REPORT(p_portlet_record,p_main_tab,p_search,p_group_name,p_group_type,p_chart_type,p_drill_down_group_type,p_sub_tab,p_host_type,p_orderfield,p_ordertype,p_display_object_type);

	ELSE

	       STORAGE.CLASSICAL_DRILL_DOWN(p_portlet_record,p_main_tab,p_search,p_group_name,p_group_type,p_chart_type,p_drill_down_group_type,p_sub_tab,p_host_type,p_orderfield,p_ordertype,p_display_object_type);       
	END IF;
	   
EXCEPTION
	WHEN OTHERS THEN
		STORAGE.PRINTN('Raising exception in storage report '||SQLERRM);

END display_storage_summary;
--------------------------------------------------
-- Procedure Name : format_data_in_html
-- Description    : Procedure to Procedure formats spits the data into 
--                  html format
--                  INPUT - width
--                        - height
--                        - seriesnames
--                        - series colors
--                        - number of rows
--                        - number of columns
--------------------------------------------------
PROCEDURE format_data_in_html (
   p_title         in  VARCHAR2,
   p_subtitle      in  VARCHAR2,   
   p_numrows       in  integer,
   p_numcols       in  integer,
   p_series_name   in  VARCHAR2,
   p_chart_type    in  VARCHAR2,
   p_enablelegend  in  VARCHAR2 DEFAULT 'YES',
   p_yaxis_title   in  VARCHAR2 DEFAULT '',
   p_suffix        in  VARCHAR2 DEFAULT ''
)
is
   l_serieswidth  number;

begin

      if (p_chart_type = 'LINE') then
         l_serieswidth :=2;
      else
         l_serieswidth :=30; 
      end if;

      htp.prn('<graph width="'  || 650 || 
              '" height="' || 325 || 
              '" title="' || p_title ||
              '" subtitle="' || p_subtitle || 
              '" footnote="' || '' || 
              '" font="' || '' || 
              '" charttype="' || p_chart_type || 
              '" chartstyle="' || 'BASIC' || 
              '" seriesnames="' || p_series_name || 
              '" seriescolors="' || '0000ff,ff0000,ffff66' || 
              '" rows="' || p_numrows || 
              '" cols="' || p_numcols || 
              '" rowcols="' ||'COLUMN' || 
              '" legendalign="' || 'SOUTH' || 
              '" enablelegend="' || p_enablelegend ||  
              '" xseriestype="' || 'TIME' || 
              '" serieswidth="' || l_serieswidth || 
              '" yfirstaxis="' ||  '' || 
              '" ysecondaxis="' || '' ||              
              '" yaxistitle="' || p_yaxis_title ||    
              '" suffix="' || p_suffix ||                                       
              '" ymax="dummy' || 
              '" mindimension="DAY' ||               
              '" data="');                            
   
end;
-------------------------------------------------

--------------------------------------------------
-- Function  Name : get_range_history_url
-- Description    : Returns history url
--                  for range (week,month,quarter,year)
--                   INPUT : period,storage type
--                   OUTPUT : url
--------------------------------------------------
   function get_range_history_url(
      p_period         in VARCHAR2,
      p_period_t       in VARCHAR2,      
      p_storage_type   in VARCHAR2,
      p_id             in VARCHAR2
   )
      return VARCHAR2
   is
      l_data   VARCHAR2(1024);
   begin

      if (p_period = p_period_t) then
	      l_data := '<B>1' || p_period || '</B>';
      else
	      l_data :=
	          '/pls/' || lower(UTIL_PORTAL.get_portal_schema) || '/' ||
	          UTIL_PORTAL.get_portlet_schema ||
	          '.storage.display_storage_history?p_period=' || p_period_t || chr(38) || 
	          'p_storage_type=' ||  p_storage_type  || chr(38) || 
	          'p_id=' || p_id ;

	      l_data :=HTF.anchor(
       	           	    curl => l_data,
			    cattributes => '',
                       	    ctext =>  '1' || p_period_t
                           );
      end if;

      return l_data;         
   end get_range_history_url;  
--------------------------------------------------
-- Function  Name : get_storage_history_url
-- Description    : Returns history url
--                  for  different storage type (DB,DISK etc.)
--                   INPUT : period,storage type
--                   OUTPUT : storage unit
--------------------------------------------------
   function get_storage_history_url(      
      p_period          in VARCHAR2,   
      p_storage_type    in VARCHAR2,
      p_storage_type_t  in VARCHAR2,      
      p_id              in VARCHAR2)
      return VARCHAR2
   is
      l_data           VARCHAR2(1024);
      l_storage_type   VARCHAR2(256);

   begin

           
      l_storage_type :=  replace(p_storage_type_t,'LFS','Local FileSystems');
      l_storage_type :=  replace(l_storage_type,'DISKS','All Disks');
      l_storage_type :=  replace(l_storage_type,'DB','All Databases');      
      l_storage_type :=  replace(l_storage_type,'DNFS','Dedicated NFS');
      l_storage_type :=  replace(l_storage_type,'TOTAL','Total Used');
                                                         
      if (p_storage_type = p_storage_type_t) then
	      l_data := '<B>' || l_storage_type || '</B>';
      else
	      l_data :=
	          '/pls/' || lower(UTIL_PORTAL.get_portal_schema) || '/' ||
	          UTIL_PORTAL.get_portlet_schema ||
	          '.storage.display_storage_history?p_period=' || p_period || chr(38) || 
	          'p_storage_type=' ||  p_storage_type_t  || chr(38) || 
	          'p_id=' || p_id;
	          
	      l_data :=HTF.anchor(
       	           	    curl => l_data,
			    cattributes => '',
                       	    ctext =>  l_storage_type
                           );
      end if;

      return l_data;         
   end get_storage_history_url;  
   
--------------------------------------------------
-- PROCEDURE  Name : l_draw_graph
-- Description    : Global function to invoke servlet to
--                  generate HTML graph chart.
--------------------------------------------------
   Procedure l_draw_graph(
      p_id               in VARCHAR2,
      p_period           in VARCHAR2, 
      p_storage_type     in VARCHAR2
  )
   is
	l_legend          VARCHAR2(256);
	l_historycursor    sys_refcursor;
	l_startdate	DATE;
	l_enddate	DATE;

	l_count    INTEGER;	
	l_tablename    VARCHAR2(50);
	l_flds        stringTable;
	l_sqlstmt    VARCHAR2(2000);

	l_collection_timestamp	DATE;

	l_size        NUMBER;
	l_used        NUMBER;    

	l_maxsize_check_fld	VARCHAR2(50);
	l_max_value		NUMBER;

	l_storageunit	stringTable := stringTable('KB','MB','GB','TB');
	l_storagefactor	intTable := intTable(L_BASE_KB,L_BASE_MB,L_BASE_GB,L_BASE_TB);
	l_unit_element	INTEGER;
	
	l_title         VARCHAR2(512) :=''; 

	FUNCTION l_check_unit( p_value  IN NUMBER ) RETURN INTEGER IS

	BEGIN

		IF p_value >= L_BASE_TB THEN
		
			RETURN 4;

		ELSIF p_value >= L_BASE_GB THEN

			RETURN 3;

		ELSIF p_value >= L_BASE_MB THEN

			RETURN 2;

		ELSE
			RETURN 1;

		END IF;

	END l_check_unit;
      
   begin
      
    UTIL_PORTAL.include_portal_stylesheet;

    l_enddate := SYSDATE;	

    IF UPPER(p_period) = 'W' THEN
        l_startdate := TRUNC(l_enddate-6,'DD');
        l_tablename := 'stormon_history_day_view';
        l_title := 'Last Week''s';
    ELSIF UPPER(p_period) = 'M' THEN
      	l_startdate := TRUNC(ADD_MONTHS(l_enddate,-1)+1,'DD');        
        l_tablename := 'stormon_history_day_view';
        l_title := 'Last Month''s';        
    ELSIF UPPER(p_period) = 'Q' THEN
	l_startdate := TRUNC(ADD_MONTHS(l_enddate,-3)+1,'D');   
        l_tablename := 'stormon_history_week_view';
        l_title := 'Last Quarter''s';                
    ELSE
	l_startdate := TRUNC(ADD_MONTHS(l_enddate,-12)+1,'D');        
        l_tablename := 'stormon_history_week_view';
        l_title := 'Last Years''s';
    END IF;

    IF UPPER(p_storage_type) = 'DB' THEN       
	l_maxsize_check_fld := 'oracle_database_used';
	l_flds := stringTable('oracle_database_size' ,'oracle_database_used' );
        l_legend := 'Allocated Database Space,Used Database Space';               
        l_title := l_title || ' All Databases ';
    ELSIF UPPER(p_storage_type) = 'LFS' THEN
	l_maxsize_check_fld := 'local_filesystem_used';
        l_flds := stringTable('local_filesystem_size','local_filesystem_used');
        l_legend := 'Allocated File System Space,Used File System Space';        
        l_title := l_title || ' Local FileSystems ';
    ELSIF UPPER(p_storage_type) = 'DNFS' THEN
	l_maxsize_check_fld := 'nfs_exclusive_used';
        l_flds := stringTable('nfs_exclusive_size','nfs_exclusive_used');
        l_legend := 'Allocated Dedicated NFS Space,Used Dedicated NFS Space';
        l_title := l_title || ' Dedicated NFS ';        
    ELSIF UPPER(p_storage_type) = 'DISKS' THEN
	l_maxsize_check_fld := 'disk_used';
        l_flds := stringTable('disk_size','disk_used');
        l_legend := 'Attached Disk Space,Used Disk Space';     
        l_title := l_title || ' All Disks ';                
    ELSIF UPPER(p_storage_type) = 'TOTAL' THEN
	l_maxsize_check_fld := 'used';
        l_flds := stringTable('sizeb','used');
        l_legend := 'Total Attached ,Total Used';     
        l_title := l_title || ' Total Used ';
    ELSE
	l_maxsize_check_fld := 'used';
        l_flds := stringTable('sizeb','used');
        l_legend := 'Total Attached ,Total Used';       
    END IF;   
	    
    STORAGE.PRINTN('
			SELECT /*+ DRIVING_SITE(a)*/ COUNT(*) ,
			MAX('||l_maxsize_check_fld||')
			FROM '||l_tablename||' a 
			WHERE id = '||p_id||'
			AND collection_timestamp BETWEEN '||TO_CHAR(l_startdate,'DD-MON-YY HH24:MI:SS')||' AND '||TO_CHAR(l_enddate,'DD-MON-YY HH24:MI:SS') );

    EXECUTE IMMEDIATE '
			SELECT /*+ DRIVING_SITE(a)*/ COUNT(*) ,
			MAX('||l_maxsize_check_fld||')
			FROM '||l_tablename||' a 
			WHERE id = :id 
			AND collection_timestamp BETWEEN :startdate AND :enddate' 
	INTO  l_count , l_max_value USING p_id,l_startdate,l_enddate;
	
	l_unit_element := l_check_unit(l_max_value);

	IF l_count > 0 THEN
	      format_data_in_html (
	      ' ',
	      l_title || ' History from '||TO_CHAR(l_startdate,'DD-MON-YY')||' to '||TO_CHAR(l_enddate,'DD-MON-YY') ,              
              l_count,
              3,
              l_legend,
              'LINE',
              'YES',
              'Storage in '||l_storageUnit(l_unit_element),
              ' ' || l_storageUnit(l_unit_element)
              );                                    
	ELSE
		RAISE NO_DATA_FOUND;
	END IF;
              
   l_sqlstmt := '
		SELECT /*+ DRIVING_SITE(a)*/ collection_timestamp, sizeb, used  
		FROM  
		( 
			SELECT	 /*+ DRIVING_SITE(a)*/ collection_timestamp, 
				('||l_flds(1)||'/'||l_storageFactor(l_unit_element)||') sizeb , 
				('||l_flds(2)||'/'||l_storageFactor(l_unit_element)||') used 
			FROM '||l_tablename||' a
			WHERE id = :id
			AND	collection_timestamp BETWEEN :startdate AND :enddate  
		) a
		ORDER BY collection_timestamp ASC';
              
    OPEN l_historycursor FOR l_sqlstmt USING p_id,l_startdate,l_enddate;

    LOOP

        FETCH l_historycursor INTO l_collection_timestamp,l_size, l_used;

        EXIT WHEN l_historycursor%NOTFOUND;
    
	DBMS_OUTPUT.PUT_LINE(to_char(l_collection_timestamp,'YYYYMMDD HH24:MI:SS') || ',' || l_size|| ',' || l_used );
	htp.prn(to_char(l_collection_timestamp,'YYYYMMDD HH24:MI:SS') || ',' || l_size|| ',' || l_used ||   ';' );            

    END LOOP;

	IF l_historycursor%ROWCOUNT = 0 THEN
	  raise NO_DATA_FOUND;
	END IF; 

    CLOSE l_historycursor;

    htp.prn('">' );                                     

      Exception 
        WHEN OTHERS THEN  
         htp.p(' ');         
         format_data_in_html ('' ,'No History Available' ,1,3,l_legend,'LINE');                                    
         htp.prn(sysdate || ',' || 0 ||',' || 0 || ';' );            
         htp.prn('">' );                                 
               
   end l_draw_graph;



--------------------------------------------------
-- PROCEDURE Name : display_storage_history
-- Description    : display storage history in a popup window
--                   INPUT :
--------------------------------------------------
   procedure display_storage_history (
      p_period           in VARCHAR2,
      p_storage_type     in VARCHAR2,
      p_id               in storage_summaryObject_view.id%TYPE
   )
   is


   l_base_url     VARCHAR2(256);
   l_1w_url       VARCHAR2(1024);
   l_1q_url       VARCHAR2(1024);
   l_1m_url       VARCHAR2(1024);
   l_1y_url       VARCHAR2(1024);
   l_range_url    VARCHAR2(4096);

   l_db_url       VARCHAR2(1024);
   l_lfs_url      VARCHAR2(1024);
   l_disk_url     VARCHAR2(1024);
   l_nfs_url      VARCHAR2(1024);
   l_total_url    VARCHAR2(1024);
   l_type_url     VARCHAR2(4096);

   l_common_url   VARCHAR2(4096);
   l_ref_path     VARCHAR2(255);
   l_graph_image  VARCHAR2(4096);

   l_dk_gray_bg_color	  VARCHAR2(10) := '#999999'; --#999999
   l_gray_bg_color	  VARCHAR2(10) := '#cccccc'; --#cccccc	
   l_beige_bg_color VARCHAR2(10) := '#CCCC8C';

   l_summaryObject   storage_summaryObject_view%ROWTYPE;

  begin

	BEGIN			
-- hostcount-(actual_targets+issues),		-- not collected
			SELECT	/*+ DRIVING_SITE(a)*/ *	 			                           
			INTO	l_summaryObject
			FROM	storage_summaryObject_view a
			WHERE	id = p_id;
	
	EXCEPTION

		WHEN OTHERS THEN
			RAISE;
	END;

      UTIL_PORTAL.include_portal_stylesheet;
      l_1w_url := get_range_history_url(p_period,'W',p_storage_type,p_id);
      l_1m_url := get_range_history_url(p_period,'M',p_storage_type,p_id);
      l_1q_url := get_range_history_url(p_period,'Q',p_storage_type,p_id);
      l_1y_url := get_range_history_url(p_period,'Y',p_storage_type,p_id);

                 
      l_range_url := l_1w_url || ' | ' ||
                     l_1m_url || ' | ' ||
                     l_1q_url || ' | ' ||
                     l_1y_url;

      l_db_url   := get_storage_history_url(p_period,p_storage_type,'DB',p_id);
      l_lfs_url  := get_storage_history_url(p_period,p_storage_type,'LFS',p_id);
      l_disk_url := get_storage_history_url(p_period,p_storage_type,'DISKS',p_id);
      l_nfs_url  := get_storage_history_url(p_period,p_storage_type,'DNFS',p_id);
      l_total_url:= get_storage_history_url(p_period,p_storage_type,'TOTAL',p_id);
      
      l_type_url  := 	l_db_url   || ' | ' ||
			l_lfs_url  || ' | ' ||
			l_nfs_url  || ' | ' ||
       			l_disk_url || ' | ' ||
			l_total_url;

      l_graph_image := '<IMG SRC='  ||
          '/' ||
          lower(UTIL_PORTAL.get_portal_schema) ||
          '/ChartsServlet?url=' ||
          '/pls/' || lower(UTIL_PORTAL.get_portal_schema) || '/' ||
          UTIL_PORTAL.get_portlet_schema ||
          '.storage.l_draw_graph?p_id=' ||
          p_id || '%26' ||
          'p_period=' ||
           p_period   ||
          '%26' || 'p_storage_type=' ||
          p_storage_type     ||
          chr(38) || 'html=YES' || ' >';


    l_base_url := '/pls/' || UTIL_PORTAL.get_portal_schema ||
                    '/' || UTIL_PORTAL.get_portlet_schema ;


    HTP.htmlOpen;
    HTP.headOpen;
    HTP.title (ctitle => 'Utilization - History');
    HTP.headClose;

    HTP.bodyOpen(cbackground   => '"white"',
                 cattributes   => NULL
                 );

    HTP.formOpen(curl        => '',
                   cmethod     => '',
                   ctarget     => NULL,
                   cenctype    => NULL,
                   cattributes => 'name="storagehistform"');

    HTP.tableopen(cborder      => 'border=0',
                  calign       => 'center',
                  cattributes  => 'width=100% cellspacing=0 cellpadding=0');

    print_line('bgcolor='||l_beige_bg_color); 

    HTP.tableclose;

    STORAGE.print_host_title_table(l_summaryObject);

    HTP.tableopen(cborder      => 'border=0',
                  calign       => 'center',
                  cattributes  => 'width=100% cellspacing=0 cellpadding=0');

    HTP.tableRowOpen;

    HTP.tabledata( cvalue      => WWUI_API_PORTLET.portlet_text('Range :',1),
                   cnowrap     => ' ',
                   cattributes => 'align=left bgcolor='||l_gray_bg_color);

    HTP.tabledata( cvalue      => WWUI_API_PORTLET.portlet_text(l_range_url,1),
                   cnowrap     => ' ',
                   cattributes => 'align=left bgcolor='||l_gray_bg_color);

    HTP.tabledata( cvalue      => WWUI_API_PORTLET.portlet_text('Type :',1),
                   cnowrap     => ' ',
                   cattributes => 'align=right bgcolor='||l_gray_bg_color);

    HTP.tabledata( cvalue      => WWUI_API_PORTLET.portlet_text(l_type_url,1),
                   cnowrap     => ' ',
                   cattributes => 'align=left bgcolor='||l_gray_bg_color);

    HTP.tableRowClose;

    HTP.tableRowOpen;

    HTP.tableData( cvalue      => WWUI_API_PORTLET.portlet_text(l_graph_image,1),
                  cnowrap     => ' ',
                  cattributes => 'align=center colspan=4 ');

    HTP.tableRowClose;

    HTP.tableRowOpen;

    HTP.tableData( cvalue      => WWUI_API_PORTLET.portlet_text('<B><A HREF=javascript:; onClick="javascript:window.print();">Print This Page</A></B>' ,1),
                  cnowrap     => ' ',
                  cattributes => 'align=right colspan=4 ');

    HTP.tableRowClose;

    HTP.tableclose;
    HTP.formClose;
    HTP.bodyClose;
    HTP.htmlClose;

end display_storage_history;


--------------------------------------------------
-- PROCEDURE Name : display_issues
-- Description    : display_issues
--          INPUT : target name
--                  target id 
--------------------------------------------------
procedure display_issues (
  p_id    	  in VARCHAR2,
  p_message_type  in VARCHAR2,	-- Type of message , ISSUE or WARNING
  p_host_type	  in VARCHAR2 DEFAULT 'ALL_HOSTS' -- Type of Hosts to report ALL_HOSTS,FAILED_HOSTS,ISSUE_HOSTS,NOT_COLLECTED_HOSTS,SUMMARIZED_HOSTS
)
is

l_row_color	VARCHAR2(24);

l_cursor	sys_Refcursor;
l_tablename	VARCHAR2(256);
l_targetList	stringTable;
l_messageList	stringTable;


l_predicate     VARCHAR2(1000);
l_sqlstmt	VARCHAR2(5000);
l_title		VARCHAR2(1000);
l_summaryObject	storage_summaryObject_view%ROWTYPE;

BEGIN

        UTIL_PORTAL.include_portal_stylesheet;
	l_row_color := WWUI_API_PORTLET.portlet_subheader_color;

	BEGIN

		SELECT	/*+ DRIVING_SITE(a)*/*                                  
		INTO	l_summaryObject
		FROM	storage_summaryObject_view a
		WHERE	id = p_id;
	
	EXCEPTION
		WHEN OTHERS THEN
			RAISE;
	END;


        IF l_summaryObject.type = 'HOST' THEN
                -- ID is a target id
		-- SQL Statement

		l_sqlstmt :=	'
				SELECT	/*+ DRIVING_SITE(a)*/ a.target_name,						
					a.message 
				FROM	storage_issues_view a
				WHERE	a.id = :p_id 
				AND	a.type = :p_message_type
				ORDER BY
				a.target_name,
				a.timestamp asc';

		-- Title for Groups
		IF p_message_type = 'ISSUE' THEN                 	
			l_title := 'Storage consistency Issues';
		ELSE
			l_title := 'Storage consistency Warnings';
		END IF;

	ELSE
		-- Type of Hosts in the group to show messages for
		IF p_host_type = 'FAILED_HOSTS' THEN

			l_predicate := ' AND summaryflag IN (''I'',''N'') ';
	
		ELSIF p_host_type = 'ISSUE_HOSTS' THEN
	
			l_predicate := ' AND summaryflag = ''I'' ';

		ELSIF p_host_type = 'SUMMARIZED_HOSTS' THEN

			l_predicate := ' AND summaryflag = ''Y'' ';

		ELSIF p_host_type = 'NOT_COLLECTED_HOSTS' THEN

			l_predicate := ' AND summaryflag = ''N'' ) ';

		ELSIF p_host_type = 'WARNING_HOSTS' THEN
		
			l_predicate := 'AND warnings > 0 ';
		ELSE 
			l_predicate := NULL;
			
		END IF;
                
                -- ID is a group id
		-- SQL statement
		l_sqlstmt :=	'
				SELECT	/*+ DRIVING_SITE(a)*/a.target_name,						
					a.message 
				FROM	storage_issues_view a, 
					storage_summaryObject b,
					stormon_host_groups c
				WHERE	b.id = c.target_id
				AND	c.group_id = :p_id
				AND	a.id = b.id 
				AND	a.type = :p_message_type '||l_predicate||'
				ORDER BY
				a.target_name,
				a.timestamp asc';
			
		-- Title for Groups
		IF p_message_type = 'ISSUE' THEN
                 	
			l_title := 'Hosts with Issues '; 

		ELSE
			l_title := 'Hosts with Warnings ';

		END IF;


	--	print_line_break; 			
	--	print_ptable_open;
	--	print_prow_open;
	--	print_pheader(l_title);
	--	HTP.P('</TR>');                                      
	--	HTP.P('</TABLE>');

	END IF;

	print_ptable_open;	
	print_line('bgcolor=#CCCC8C');           	        
	HTP.P('</TABLE>');        
							     
	print_host_title_table(l_summaryObject);
						
	print_ptable_open;	
	print_line('bgcolor=#CCCC8C');           	        
	HTP.P('</TABLE>');        

	print_line_break;              			
	print_ptable_open;
	print_prow_open;
	print_pheader(l_title);
	HTP.P('</TR>');        
	HTP.P('</TABLE>');        
    
	-- Print the Issue Table
	print_ptable_open;
	print_prow_open(NULL,TABLE_HEADER_COLOR);				
	HTP.P('<TH align="center" >Host</TH>');                     	        	                 	
	HTP.P('<THalign="center" >Message</TH>');                     	        	                 	
	HTP.P('</TR>');        


	-- Umable to do this using EXECUTE IMMEDIATE, 
	-- Gives ORA 1019, unable to allocate memory on the user side 
	STORAGE.PRINTN(l_sqlstmt||'USING '||p_id||', '||p_message_type);
	
	OPEN l_cursor FOR l_sqlstmt USING p_id, p_message_type;

	FETCH l_cursor BULK COLLECT INTO l_targetList,l_messageList;

	CLOSE l_cursor;

	IF l_messageList IS NOT NULL AND l_messageList.EXISTS(1) THEN

		FOR i IN l_messageList.FIRST..l_messageList.LAST
		LOOP

			IF ( MOD(i, 2) != 0 ) THEN
			         l_row_color := WWUI_API_PORTLET.portlet_subheader_color;
			ELSE
			         l_row_color := WWUI_API_PORTLET.portlet_body_color;
			END IF;
	 	
			print_prow_open(l_row_color);
			print_pcol(l_targetList(i),'LEFT');	       		        
			print_pcol(l_messageList(i),'LEFT');               
			HTP.P('</TR>');        
			
		END LOOP;

	ELSE

		print_prow_open;	

		IF p_message_type = 'ISSUE' THEN
			print_pcol('<I>' || ' No Issues ' || '</I>','LEFT');	
		ELSE       		              
			print_pcol('<I>' || ' No Warnings ' || '</I>','LEFT');		               
		END IF;
		HTP.P('</TR>');                  

	END IF;

	HTP.P('</TABLE>');  
                             						  				       
	display_tip(stringTable('Refer to FAQ for resolving outstanding Issues for a host '));

 END;    


--------------------------------------------------
-- PROCEDURE Name : display_hosts_not_collected
-- Description    : display hosts with no storage metrics
--          INPUT : data center
--                  lob
--		     title
--------------------------------------------------
procedure display_hosts_not_collected (
  p_id    	  in VARCHAR2
)
is

l_row_color	VARCHAR2(24);
l_cursor	sys_Refcursor;
l_targetList	stringTable;

l_dummy         VARCHAR2(1);
l_title		VARCHAR2(1000) := NULL;
l_summaryObject	storage_summaryObject_view%ROWTYPE;
l_sqlstmt	VARCHAR2(500);

	  
BEGIN

	l_row_color := WWUI_API_PORTLET.portlet_subheader_color;
	UTIL_PORTAL.include_portal_stylesheet;

	BEGIN

		SELECT	/*+ DRIVING_SITE(a)*/*                                 
		INTO	l_summaryObject
		FROM	storage_summaryObject_view a
		WHERE	id = p_id;
	
	EXCEPTION
		WHEN OTHERS THEN
			RAISE;
	END;

	-- ID is a target id, and has a been collected atleast once
        IF l_summaryObject.type = 'HOST' AND  l_summaryObject.summaryFlag != 'N' THEN
                
		RETURN;				
		
	END IF;

	-- id id is a group
	
	IF l_summaryObject.type != 'HOST' THEN

                -- ID is a group id
                -- SQL statement        

		l_sqlstmt :=  '
				SELECT	/*+ DRIVING_SITE(a)*/ a.name
				FROM	storage_summaryObject_view a , 
					stormon_host_groups b
				WHERE	a.id  = b.target_id
				AND	b.group_id = :p_id
				AND	summaryFlag = ''N''
				ORDER BY
				a.name';
			
		l_title := 'Hosts with Storage data collection NOT enabled';
                              	
		OPEN l_cursor FOR l_sqlstmt USING p_id;

		FETCH l_cursor BULK COLLECT INTO l_targetList;
	
		CLOSE l_cursor;

	END IF; 

	print_ptable_open;
	print_line('bgcolor=#CCCC8C');           	        
	HTP.P('</TABLE>');            
						     
	print_host_title_table(l_summaryObject);
	
	print_ptable_open;	
	print_line('bgcolor=#CCCC8C');           	        			
	HTP.P('</TABLE>');

	IF l_summaryObject.type != 'HOST' THEN
	
		print_line_break;
		print_ptable_open;		
		print_prow_open;			
		print_pheader(l_title);
		HTP.P('</TR>'); 

		print_prow_open(NULL,TABLE_HEADER_COLOR);
		print_phcol('Host','left');                     	                     
		HTP.P('</TR>');        

		IF l_targetList IS NOT NULL AND l_targetList.EXISTS(1) THEN

			FOR i IN l_targetList.FIRST..l_targetList.LAST
			LOOP

				IF ( MOD(i, 2) != 0 ) THEN
				         l_row_color := WWUI_API_PORTLET.portlet_subheader_color;
				ELSE
			        	 l_row_color := WWUI_API_PORTLET.portlet_body_color;
				END IF;
 	
				print_prow_open(l_row_color);
				print_pcol(l_targetList(i),'LEFT');	         
				HTP.P('</TR>');                            		           	

		       END LOOP;  

		END IF;

		HTP.P('</TABLE>'); 

	END IF;
                                             						  				       
	display_tip(stringTable('Enable collection of Storage data to view Storage Reports'));

 END display_hosts_not_collected;    


-------------------------------------------------------
-- Print the title table for a Target
-------------------------------------------------------
PROCEDURE print_host_title_table(l_summaryObject IN storage_summaryObject_view%ROWTYPE) 
IS

   l_datacenter   stormon_group_table.name%TYPE;
   l_lob	  stormon_group_table.name%TYPE;
   l_group_name   stormon_group_table.name%TYPE;
   l_group_type	  stormon_group_table.type%TYPE;

   l_title_align	VARCHAR2(20) := 'RIGHT';
   l_value_align	VARCHAR2(20) := 'LEFT';

BEGIN

        print_ptable_open;

	IF l_summaryObject.type = 'HOST' THEN
		
		print_prow_open;
		print_pcol('Host Name',l_title_align);
		print_pcol('<B>' || l_summaryObject.name || '</B>',l_value_align);
		HTP.P('</TR>');
	
		BEGIN
			SELECT  /*+ DRIVING_SITE(a)*/ a.name,
				a.type
			INTO	l_group_name,
				l_group_type
			FROM    stormon_group_table a,
			        stormon_host_groups b
			WHERE   a.id = b.group_id
			AND     b.target_id = l_summaryObject.id
			AND     a.type = 'REPORTING_DATACENTER_LOB'	
			AND     ROWNUM = 1;

			STORAGE.GET_DC_LOB_FROM_NAME(l_group_name,l_group_type,l_datacenter,l_lob);

		EXCEPTION
				WHEN OTHERS THEN
					RAISE;
		END;

		print_prow_open;	
		print_pcol('Data Center',l_title_align);
		print_pcol('<B>' || l_datacenter || '</B>',l_value_align);	
		HTP.P('</TR>');
		

		print_prow_open;	
		print_pcol('LOB(Line Of Business)',l_title_align);
		print_pcol('<B>' || l_lob || '</B>',l_value_align);		
		HTP.P('</TR>');
		

		print_prow_open;	
		print_pcol('Date Data Collected ',l_title_align);
		IF	l_summaryObject.summaryFlag = 'N' THEN

			print_pcol('<B>' ||  'Collection not enabled (collection never successful)' || '</B>',l_value_align);

		ELSIF	l_summaryObject.summaryFlag = 'I'  THEN

			print_pcol('<B>' || 'Computation of storage summary has failed since '||l_summaryObject.collection_timestamp || '</B>',l_value_align);
		ELSE
			print_pcol('<B>' || l_summaryObject.collection_timestamp || '</B>',l_value_align);
		END IF;

		HTP.P('</TR>');
		

	ELSIF l_summaryObject.type IN ('REPORTING_DATACENTER','REPORTING_LOB','REPORTING_DATACENTER_LOB','REPORTING_ALL') THEN
	-- For groups 

		STORAGE.GET_DC_LOB_FROM_NAME(l_summaryObject.name,l_summaryObject.type,l_datacenter,l_lob);

		print_prow_open;
		print_pcol('Data Center',l_title_align);
		print_pcol('<B>' || l_datacenter || '</B>',l_value_align);	
		HTP.P('</TR>');
		

		print_prow_open;	
		print_pcol('LOB(Line Of Business)',l_title_align);
		print_pcol('<B>' || l_lob || '</B>',l_value_align);		
		HTP.P('</TR>');	
		

	ELSE

		print_prow_open;	
		print_pcol('Group name',l_title_align);
		print_pcol('<B>' || l_summaryObject.name || '</B>',l_value_align);	
		HTP.P('</TR>');
					

	END IF;

	HTP.P('</TABLE>');              	
  
END print_host_title_table;


PROCEDURE PRINT_TABLE_RESULTS ( p_table_result_object IN storage_reporting_table_object , p_field_position IN INTEGER , p_class IN VARCHAR2 ) IS

BEGIN
	
	CASE
		WHEN p_field_position = 1 THEN
			HTP.P('<TD class="'||p_class||'">'||p_table_result_object.field1||'</TD>');
		WHEN p_field_position = 2 THEN
			HTP.P('<TD class="'||p_class||'">'||p_table_result_object.field2||'</TD>');
		WHEN p_field_position = 3 THEN
			HTP.P('<TD class="'||p_class||'">'||p_table_result_object.field3||'</TD>');
		WHEN p_field_position = 4 THEN
			HTP.P('<TD class="'||p_class||'">'||p_table_result_object.field4||'</TD>');
		WHEN p_field_position = 5 THEN
			HTP.P('<TD class="'||p_class||'">'||p_table_result_object.field5||'</TD>');
		WHEN p_field_position = 6 THEN
			HTP.P('<TD class="'||p_class||'">'||p_table_result_object.field6||'</TD>');
		WHEN p_field_position = 7 THEN
			HTP.P('<TD class="'||p_class||'">'||p_table_result_object.field7||'</TD>');
		WHEN p_field_position = 8 THEN
			HTP.P('<TD class="'||p_class||'">'||p_table_result_object.field8||'</TD>');
		WHEN p_field_position = 9 THEN
			HTP.P('<TD class="'||p_class||'">'||p_table_result_object.field9||'</TD>');
		WHEN p_field_position = 10 THEN
			HTP.P('<TD class="'||p_class||'">'||p_table_result_object.field10||'</TD>');
		WHEN p_field_position = 11 THEN
			HTP.P('<TD class="'||p_class||'">'||p_table_result_object.field11||'</TD>');
		WHEN p_field_position = 12 THEN
			HTP.P('<TD class="'||p_class||'">'||p_table_result_object.field12||'</TD>');
		WHEN p_field_position = 13 THEN
			HTP.P('<TD class="'||p_class||'">'||p_table_result_object.field13||'</TD>');
		WHEN p_field_position = 14 THEN
			HTP.P('<TD class="'||p_class||'">'||p_table_result_object.field14||'</TD>');
		WHEN p_field_position = 15 THEN
			HTP.P('<TD class="'||p_class||'">'||p_table_result_object.field15||'</TD>');
		WHEN p_field_position = 16 THEN
			HTP.P('<TD class="'||p_class||'">'||p_table_result_object.field16||'</TD>');
		WHEN p_field_position = 17 THEN
			HTP.P('<TD class="'||p_class||'">'||p_table_result_object.field17||'</TD>');
		WHEN p_field_position = 18 THEN
			HTP.P('<TD class="'||p_class||'">'||p_table_result_object.field18||'</TD>');
		WHEN p_field_position = 19 THEN
			HTP.P('<TD class="'||p_class||'">'||p_table_result_object.field19||'</TD>');
		WHEN p_field_position = 20 THEN
			HTP.P('<TD class="'||p_class||'">'||p_table_result_object.field20||'</TD>');
		ELSE
			HTP.P('<TD class="'||p_class||'"></TD>');
	END CASE;

END PRINT_TABLE_RESULTS;


PROCEDURE print_history_graph( p_id IN VARCHAR2 )
IS

BEGIN

HTP.P('

<TABLE  border=0 ALIGN="center" width=100% cellspacing=0 cellpadding=0>
	<TR>
		<TD NOWRAP align=center><font class="PortletText1"><img SRC=/imetdev/ChartsServlet?url=/pls/imetdev/IDEVSRC.storage.l_draw_graph?p_id='||p_id||'%26p_period=Q%26p_storage_type=TOTAL'||'&'||'html=YES ></font></TD>
	</TR>
	<TR>
		<TD align=right>'||STORAGE.GET_HISTORY_LINK(p_id,'Detailed History')||'</TD>
	</TR>
</TABLE>	
	
');

END print_history_graph;

PROCEDURE print ( a VARCHAR2 ) IS

	l_sep_position	INTEGER;
	l_values_string	VARCHAR2(32767);

BEGIN

	IF STORAGE.P_MODE != 'DEBUG' THEN

		RETURN;

	END IF;

	HTP.P(a);

	l_values_string := a;

	WHILE ( LENGTH(l_values_string) > 0 ) LOOP
		
		DBMS_OUTPUT.PUT_LINE(SUBSTR(l_values_string,1,255));

		l_values_string := SUBSTR(l_values_string,256);

	END LOOP;
	
END print;


--------------------------------------------------
-- Function  Name : get_summary_sorting_link
-- Description    : 
--
--                   INPUT : group/host id
--                   OUTPUT : HREF for the group/host History
--------------------------------------------------
FUNCTION get_summary_sorting_link(
	p_main_tab			IN VARCHAR2,
	p_search_name			IN VARCHAR2,
	p_name				IN VARCHAR2,
	p_type				IN VARCHAR2,
	p_chart_type			IN VARCHAR2,
	p_drill_down_group_type		IN VARCHAR2,
	p_sub_tab			IN VARCHAR2, 	--p_drill_down_type	IN VARCHAR2 DEFAULT 'DEFAULT',
	p_host_type			IN VARCHAR2,	 
	p_orderfield			IN INTEGER, 	-- display field requested by the user
	p_ordertype			IN VARCHAR2,	-- display order type requested by the user
	p_display_object_type		IN VARCHAR2,	-- display object type requested by the user
	p_column_no			IN INTEGER,	-- current column no
	p_object_id			IN VARCHAR2	-- the id of display_object brig printed
   )
RETURN VARCHAR2
IS
	l_column_name	VARCHAR2(4000);
	l_data		VARCHAR2(4000);
	l_ordertype	VARCHAR2(2000);
	l_img_src	VARCHAR2(256) := NULL;  

BEGIN

	PRINTN('IN FUNCTION get_summary_sorting_link');

	IF l_list_of_summary_columns IS NULL OR NOT l_list_of_summary_columns.EXISTS(p_column_no) THEN
    
		RETURN	p_column_no;

	END IF;

	l_column_name := NVL(l_list_of_summary_columns(p_column_no).column_name,p_column_no);

	IF l_list_of_summary_columns(p_column_no).order_clause IS NULL THEN

		RETURN	l_column_name;

	END IF;

	-- If creating link to the currently sorted column then check and reverse it, for other columns
	-- stick to the default order
	IF	p_orderfield 		= p_column_no AND 
		p_display_object_type 	= p_object_id
	THEN			
		
		IF p_ordertype LIKE 'DESC%' THEN
			l_ordertype := 'ASC';
		ELSIF p_ordertype LIKE 'ASC%' THEN
			l_ordertype := 'DESC';
		ELSIF p_ordertype LIKE 'DEFAULT%' THEN
			IF l_list_of_summary_columns(p_column_no).order_type LIKE 'DESC%' 
			THEN
				l_ordertype := 'ASC';
			ELSE
				l_ordertype := 'DESC';
			END IF;
		ELSE
			l_ordertype := l_list_of_summary_columns(p_column_no).order_type;
		END IF;

		IF (l_ordertype = 'ASC%') THEN
			l_img_src := IMG_ASC;
		ELSE
			l_img_src := IMG_DESC;
		END IF;
                        
	ELSE
		l_ordertype := l_list_of_summary_columns(p_column_no).order_type;
					
	END IF;
		
	l_data := '<A HREF="javascript:link_change_display('''||replace(p_main_tab,' ','%20')||''','''||replace(p_search_name,' ','%20')||''','''||replace(p_name,' ','%20')||''','''||replace(p_type,' ','%20')||''','''||p_chart_type||''','''||p_drill_down_group_type||''','''||p_sub_tab||''','''||p_host_type||''','''||p_column_no||''','''||l_ordertype||''','''||p_object_id||''');"><SPAN class="sortableheaderlink">'|| l_column_name || l_img_src||'</SPAN></A>';

	RETURN l_data;                          

END get_summary_sorting_link;   
    

--------------------------------------------------------------------------------------------------------
--
-- Name : print_display_object
--
--
--
--
-- print the display objects passed
--
--------------------------------------------------------------------------------------------------------

PROCEDURE print_display_object( 
			p_portlet_record  		IN OUT WWPRO_API_PROVIDER.portlet_runtime_record,
			p_main_tab			IN VARCHAR2,
			p_search_name			IN VARCHAR2,
			p_name				IN VARCHAR2,
			p_type				IN VARCHAR2,
			p_chart_type			IN VARCHAR2,
			p_drill_down_group_type		IN VARCHAR2,
			p_sub_tab			IN VARCHAR2,
			p_host_type			IN VARCHAR2,	 
			p_orderfield			IN INTEGER, 
			p_ordertype			IN VARCHAR2,
			p_display_object_type		IN VARCHAR2,	
			p_display_object		IN display_object,
			p_list_of_display_objects	IN display_object_table,
			p_sub_tab_object		IN report_object,
			p_main_tab_object		IN tab_object,
			p_list_of_sub_tabs		IN report_object_table,
			p_list_of_main_tabs		IN tab_object_table,
			p_summary			IN storage_summaryObject_view%ROWTYPE
		) IS 

-- Pie charting variables
l_unit          		VARCHAR2(32);
l_bartag			VARCHAR2(2);
l_fieldname			stringTable;
l_fieldvalue			stringTable;
l_chart_title			VARCHAR2(1000);
l_chart_subtitle		VARCHAR2(1000);
l_legend			VARCHAR2(4000);
l_legend_position		VARCHAR2(50) := 'EAST';
l_values			VARCHAR2(4000);

-- display variables
l_cell_style_class		VARCHAR2(50);

-- Meter variables
l_metered_percent		NUMBER;
l_metered_total			NUMBER;

--Search box variables
l_radiobuttons			VARCHAR2(1024);

-- Table variables
l_row_color                     VARCHAR2(24);
l_bg_color                      VARCHAR2(24);  
l_field_position		INTEGER;
l_column_count			INTEGER;
l_offset			INTEGER;
l_table_title_rows		INTEGER;

-- Tag variables
l_section_tag			VARCHAR2(4000);
l_report_tag			VARCHAR2(4000);

-- Combo box variables
l_list_for_combo_box		VARCHAR2(32767);
l_reference_path 		VARCHAR2(4000);

-- collection and object for holding the table data
l_table_total			storage_reporting_table_object;
l_table_results			storage_reporting_results;

l_cursor			sys_Refcursor;

BEGIN

			CASE		
			WHEN	p_display_object.display_type = c_display_type_section_open THEN
						 

				HTP.P('<!--------- c_display_type_section_open -------------------->');

				HTP.P( 
	'
					<TABLE class="sectiontable" cellspacing=0>
	
					<TR class="titlerow stdfont">
						<TH class="headercolumn" width='||NVL(p_display_object.width,'100')||'%><FONT class="PortletHeaderText titlefont"> <A NAME="'||STORAGE.GET_DISPLAY_OBJECT_ID(p_display_object)||'" </A>'||p_display_object.title);
				-- Print the top arrow if this is a navigable tag		
				IF p_display_object.tag IS NOT NULL THEN
	
					HTP.P('<A HREF="javascript:;" onclick="javascript:loadpage(''top'');"><IMG BORDER=0 SRC=/myImages/mv-up.gif align=ABSBOTTOM ALT="Go to Top of the Page"></A>');
	
				END IF;
	
				HTP.P(
				' </FONT></TH>
					</TR>
	
					<TR class="contentrow" >
						<TD class="contentcolumn" >
							<TABLE class="contenttable" cellspacing=0 >
							<TR>
								<TD>
									<TABLE class="innercontent">
									<TR valign=top>
				');      													
	
				RETURN;	
				
			WHEN   	p_display_object.display_type = c_display_type_section_close THEN 
				
				HTP.P('<!--------- c_display_type_section_close -------------------->');
					
				HTP.P(
'
				</TR>
				</TABLE>

			</TD>
		</TR>
		</TABLE>

	</TD>
</TR>
</TABLE>
			');

				RETURN;
	
			WHEN	p_display_object.display_type = c_display_type_subsection_open THEN
							       											
				HTP.P('<!--------- c_display_type_subsection_open -------------------->');

				HTP.P( 
'

						<TABLE class="subsectiontable" cellspacing=0 >

						<TR class="stitlerow stdfont" >
							<TH class="stitleheader" ><FONT class="PortletHeaderText stitlefont"> '||p_display_object.title||' </FONT></TH>
						</TR>

						<TR class="contentrow" >
							<TD width=100% >
							
								<TABLE width=100%>
								<TR>										
				');
					
				RETURN;
	
			WHEN   	p_display_object.display_type = c_display_type_ssection_close THEN 
	
				HTP.P('<!--------- c_display_type_ssection_close -------------------->');

				HTP.P(
'								</TR>
								</TABLE>
							</TD>
						</TR>
						</TABLE>

');

				RETURN;
						
			WHEN	p_display_object.display_type = c_display_type_outertable_open THEN
	
				HTP.P('<!--------- c_display_type_outertable open  -------------------->');

				HTP.P('	<TABLE class="emptywidthtable" cellspacing=0 cellpadding=0 >');		
				RETURN;

			WHEN	p_display_object.display_type = c_display_type_fulltable_open THEN
	
				HTP.P('<!--------- c_display_type_emptytable open  -------------------->');

				HTP.P('	<TABLE class="fullwidthtable" cellspacing=0 cellpadding=0 >');		
				RETURN;


			WHEN	p_display_object.display_type = c_display_type_table_close THEN
	
				HTP.P('<!--------- c_display_type_table_close -------------------->');

				HTP.P('	</TABLE>');		
				RETURN;

			WHEN	p_display_object.display_type = c_display_type_row_open THEN
	
				HTP.P('<!--------- c_display_type_row_open -------------------->');

				HTP.P('	<TR>');		
				RETURN;

			WHEN	p_display_object.display_type = c_display_type_row_close THEN
	
				HTP.P('<!--------- c_display_type_row_close -------------------->');

				HTP.P('	</TR>');		
				RETURN;

			WHEN	p_display_object.display_type = c_display_type_row THEN
	
				HTP.P('<!--------- c_display_type_new_row -------------------->');

				HTP.P('	</TR><TR>');		
				RETURN;
	
			WHEN	p_display_object.display_type = c_display_type_column_open THEN
				
				HTP.P('<!--------- c_display_type_column_open -------------------->');

				HTP.P('		<TD width='||p_display_object.width||'>');
				RETURN;
	
			WHEN	p_display_object.display_type = c_display_type_column_close THEN
				
				HTP.P('<!--------- c_display_type_column_close -------------------->');

				HTP.P('		</TD>');
				RETURN;

			WHEN	p_display_object.display_type = c_display_type_draw_line THEN
	
				HTP.P('<!--------- c_display_type_draw_line -------------------->');

				HTP.P('	
				<TABLE class="fullwidthtable" cellspacing=0 cellpadding=0  >
					<TR>
						<TD bgcolor=#CCCC8C height=3></TD>
					</TR>
				</TABLE>');		
				RETURN;
	
			WHEN	p_display_object.display_type = c_display_type_navigation_tags THEN
	
					
				HTP.P('<!--------- c_display_type_navigation_tags -------------------->');

				-- Collect all the tags and print them
/*				FOR j IN p_list_of_sub_tabs.FIRST..p_list_of_sub_tabs.LAST LOOP
			
					l_report_tag := NULL;
					l_section_tag := NULL;

					IF p_list_of_sub_tabs(j) IS NULL THEN
						GOTO next_report_tag;
					END IF;
													
					IF p_list_of_sub_tabs(j).tag  IS NOT NULL THEN
						l_report_tag := '<A HREF="javascript:;" onclick="javascript:loadpage('''||p_list_of_sub_tabs(j).tag||''');" style="color:blue"><SPAN class="linkcolor">'||p_list_of_sub_tabs(j).tag||'</SPAN></A>';	
					END IF;
*/			
				IF p_list_of_display_objects IS NOT NULL AND p_list_of_display_objects.EXISTS(1) THEN
				
					
					FOR k IN p_list_of_display_objects.FIRST.. p_list_of_display_objects.LAST LOOP

						IF p_list_of_display_objects(k) IS NULL THEN
							GOTO next_section_tag;			
						END IF;

						IF p_list_of_display_objects(k).display_type IS NULL THEN
							GOTO next_section_tag;			
						END IF;	

						IF p_list_of_display_objects(k).tag  IS NULL THEN
							GOTO next_section_tag;			
						END IF;	

						IF l_section_tag IS NULL THEN					
							l_section_tag := '<A HREF="javascript:;" onclick="javascript:loadpage('''||STORAGE.GET_DISPLAY_OBJECT_ID(p_list_of_display_objects(k))||''');" style="color:blue"><SPAN class="linkcolor">'||p_list_of_display_objects(k).tag||'</SPAN></A>';
						ELSE
							l_section_tag := l_section_tag||'&'||'nbsp;'||'
								<A HREF="javascript:;" onclick="javascript:loadpage('''||STORAGE.GET_DISPLAY_OBJECT_ID(p_list_of_display_objects(k))||''');" style="color:blue"><SPAN class="linkcolor">'||p_list_of_display_objects(k).tag||'</SPAN></A>';
						END IF;
				
					<<next_section_tag>>
					NULL;
					END LOOP;
					
					IF l_section_tag IS NOT NULL THEN
						
						HTP.P('
						<TABLE class="linktable">
						<TR>						
							<TD class="linkcolumn">
							<FONT class="linkfont">
								'||l_section_tag||'&'||'nbsp;'||'
							</FONT>
							</TD>
						</TR>
						</TABLE>');
					END IF;

				END IF;

/*				END LOOP;
*/
				
				RETURN;
	
			WHEN	p_display_object.display_type = c_display_type_search_box THEN			

				HTP.P('<!--------- c_display_type_search_box -------------------->');

				IF (p_type = 'HOST' ) then   
					l_radiobuttons   := l_radiobuttons || '<INPUT TYPE=RADIO  NAME="theradio" CHECKED>Host Name';
				ELSE
					l_radiobuttons   := l_radiobuttons || '<INPUT TYPE=RADIO  NAME="theradio">Host Name';
				END IF;

				IF (p_type = 'REPORTING_DATACENTER') then   
					l_radiobuttons   := l_radiobuttons || '<INPUT TYPE=RADIO  NAME="theradio" CHECKED>Data Center';
				ELSE
					l_radiobuttons   := l_radiobuttons || '<INPUT TYPE=RADIO  NAME="theradio">Data Center';
				END IF;

				IF (p_type = 'REPORTING_LOB') then   
					l_radiobuttons   := l_radiobuttons || '<INPUT TYPE=RADIO  NAME="theradio" CHECKED>Line Of Business';
				ELSE
					l_radiobuttons   := l_radiobuttons || '<INPUT TYPE=RADIO  NAME="theradio">Line of Business';
				END IF;
                       
				HTP.P('
<FORM NAME=formui>
	<TABLE class="choiceboxtable" cellspacing=0 cellpading=0 >	
	<TR>
		<TD align=left valign=bottom >'||l_radiobuttons||'</TD>
		<TD align=left rowspan=5>
');

				STORAGE.DISPLAY_TIP(stringTable(
					'<BR>1.Search for a single value or multiple values',
					'<BR>2.When searching for multiple values , separate each value by a Coma ( eg. adc,hqdc,rmdc )',
					'<BR>3.Wild Character ( * ) accepted')
				);

				HTP.P('
		</TD>		
	</TR>	
	<TR bgcolor=>
		<TD align=left valign=top >
			<INPUT TYPE=TEXT  NAME="insearch" VALUE="' ||p_name || '" size=40>
			<INPUT TYPE=BUTTON NAME=search VALUE="Search" onClick="javascript:quick_lookup();"> 		
		</TD>			
	</TR>			
	</TABLE>	
</FORM>	
');
				RETURN;


			WHEN	p_display_object.display_type = c_display_type_combo_box THEN	

			-- Print the group list combo box or the quick lookup tale depending ton the main tab	
				HTP.P('<!--------- c_display_type_combo_box -------------------->');

				l_list_for_combo_box :=  p_display_object.title||' <select name="group_name" >';
       
				FOR k IN ( 
					SELECT	'ALL' option_value
					FROM	dual
					UNION
					SELECT	/*+ DRIVING_SITE(a)*/name option_value
					FROM	stormon_group_table a
					WHERE	type = p_type
					ORDER BY 1 ASC
       				) LOOP
            

					IF (INSTRB(k.option_value,p_name ) > 0) THEN
	             				l_list_for_combo_box :=  l_list_for_combo_box || '<option value="' || REPLACE(k.option_value,' ','%20') || '" selected>' || k.option_value || '</option>';                                    
					ELSE               
	             				l_list_for_combo_box :=  l_list_for_combo_box ||'<option value="' || REPLACE(k.option_value,' ','%20') || '" >' || k.option_value || '</option>';                                                                    	
					END IF;    
          
				END LOOP;  

       				l_list_for_combo_box := l_list_for_combo_box || '</select>';

				l_reference_path  := REPLACE(PREFERENCE_PATH ||p_portlet_record.reference_path,PREFERENCE_PATH,'');

				HTP.P('
<FORM action="'||UTIL_PORTAL.get_portlet_schema ||'.STORAGE.get_group_report" method="get" name="showform1_' ||l_reference_path || '" >

	<TABLE class="choiceboxtable" cellspacing=0 cellpading=0 >
	<TR valign=top>
		<TD NOWRAP width=5% align=left><FONT class="PortletText1">'||l_list_for_combo_box ||'</FONT></TD>						
		<TD width="1%"></TD>
		<TD ALIGN="left"><INPUT TYPE=BUTTON NAME=GO value="GO" onClick="javascript:link_get_group_report('''||p_main_tab||''','''||p_type||''',document.showform1_' || l_reference_path || '.group_name);"></TD>
	
	</TR>	
	</TABLE>
</FORM>
');
				RETURN;

			WHEN	p_display_object.display_type = c_display_type_main_tabs THEN		

				HTP.P('<!--------- c_display_type_main_tabs  -------------------->');

			-- Print the main menu tabs
				HTP.P('

<DIV align="right">

<TABLE  class="nowidthtable" cellspacing=0 cellpadding=0 >
<TR>
<TD>'||'&'||'nbsp'||'&'||'nbsp;</TD>
<TD>

   <TABLE  class="fullwidthtable" cellspacing=0 cellpadding=0 >
   <TR>');


				FOR i IN p_list_of_main_tabs.FIRST..p_list_of_main_tabs.LAST LOOP


					IF p_list_of_main_tabs(i).status = 'ENABLE' THEN
						IF p_list_of_main_tabs(i).main_tab = p_main_tab THEN
				
							HTP.P('
	   <TD class="LeftTabForeSlant" valign="top" align="left" width="10" height="19" NOWRAP="">'||'&'||'nbsp;</TD>
	   <TD valign="middle" NOWRAP class="TabForegroundColor">'||'&'||'nbsp;'||'&'||'nbsp;<FONT class="TabForegroundText">'||p_list_of_main_tabs(i).title||'</FONT>'||'&'||'nbsp;'||'&'||'nbsp;</TD>
	   <TD align="right" class="RightTabForeCurve" width="8" NOWRAP="">'||'&'||'nbsp;'||'&'||'nbsp;</TD>
		');
			
						ELSE

							HTP.P('
	   <TD class="LeftTabBgSlant" valign="top" align="left" width="10" height="19" NOWRAP="">'||'&'||'nbsp;</TD>
	   <TD valign="middle" NOWRAP class="TabBackgroundColor">'||'&'||'nbsp;'||'&'||'nbsp;<A HREF="'||p_list_of_main_tabs(i).function||'"><FONT class="TabBackgroundText">'||p_list_of_main_tabs(i).title||'</FONT></A>'||'&'||'nbsp;'||'&'||'nbsp;</TD>
	   <TD align="right" class="RightTabBgCurve" width="8" NOWRAP="">'||'&'||'nbsp;'||'&'||'nbsp;</TD>
		');

						END IF;
					END IF;

				END LOOP;
   	
				HTP.P('
		<TD align="right" width="16" NOWRAP="">'||'&'||'nbsp;'||'&'||'nbsp;'||'&'||'nbsp;'||'&'||'nbsp;</TD>');

				HTP.P('
   </TR>	
   </TABLE>

</TD>
</TR>
</TABLE>
<DIV>');
				HTP.P('
	</TD>	
</TR><TR>
	<TD>
');

				HTP.P('
<DIV align="right">

		<TABLE  class="fullwidthtable" cellspacing=0 cellpadding=0 >	
		<TR>
			<TD  class="TabForegroundColor"><IMG SRC="/images/pobtrans.gif" BORDER="0" HEIGHT="3"></TD>
		</TR>
		</TABLE>

</DIV>
');

				RETURN;

			WHEN	p_display_object.display_type = c_display_type_sub_tabs THEN		

				HTP.P('<!--------- c_display_type_sub_tabs -------------------->');

			-- Print the main menu tabs

				HTP.P('
<DIV align="left">	

		<TABLE  class="fullwidthtable" cellspacing=0 cellpadding=0 >	
		<TR>
			<TD>
				  <TABLE  class="fullwidthtable" cellspacing=0 cellpadding=0 >				  
				   <TR>');

			-- Print the report sub tabs
				FOR h IN p_list_of_main_tabs.FIRST..p_list_of_main_tabs.LAST LOOP

					IF p_list_of_main_tabs(h).main_tab = p_main_tab THEN
			
						FOR i IN p_list_of_main_tabs(h).sub_tabs.FIRST..p_list_of_main_tabs(h).sub_tabs.LAST LOOP

							IF p_list_of_main_tabs(h).sub_tabs(i).report_type = p_sub_tab THEN
			
								HTP.P('
			   
						<TD NOWRAP class="TabForegroundColor" rowspan=2 height=28 >'||'&'||'nbsp;'||'&'||'nbsp;<FONT class="TabForegroundText">'||p_list_of_main_tabs(h).sub_tabs(i).title||'</FONT>'||'&'||'nbsp;'||'&'||'nbsp;</TD>
						<TD class="TabForegroundColor" rowspan=2 height=28 width="35"><IMG src="/images/subtab.gif" height=25 ></TD>		');
					
							ELSE

								HTP.P('
			   
						<TD NOWRAP class="TabForegroundColor" rowspan=2 height=28 >'||'&'||'nbsp;'||'&'||'nbsp;<A HREF="'||p_list_of_main_tabs(h).sub_tabs(i).function||'"><FONT class="SubTabBgText">'||p_list_of_main_tabs(h).sub_tabs(i).title||'</FONT></A>'||'&'||'nbsp;'||'&'||'nbsp;</TD>
						<TD class="TabForegroundColor" rowspan=2 height=28 width="35"><IMG src="/images/subtab.gif" height=25 ></TD>');

							END IF;
	
						END LOOP;

					EXIT;
					END IF;

				END LOOP;

				HTP.P('    
						<TD class="TabForegroundColor" height="12"><img src="/images/pobtrans.gif" width="30" height="1"></TD>
						<TD class="TabForegroundColor" height="12" width="100%"><img src="/images/pobtrans.gif" width="30" height="1"></TD>
					</TR>
					<TR>
						<TD class="LeftSubTab" height="13"><img src="/images/pobtrans.gif" width="30" height="1"></TD>
						<TD class="PageColor" height="13"><img src="/images/pobtrans.gif"></TD>
					</TR>
				</TABLE>

			</TD>
		</TR>
		</TABLE>
</DIV>
');
				RETURN;

			WHEN	p_display_object.display_type = c_display_type_report_title THEN		

				HTP.P('<!--------- c_display_type_report_title  -------------------->');

			-- Print the report title here
				HTP.P('

<TABLE class="titletable">
<TR>
	<TD class="titledata">'||p_display_object.title||'</TD>
	<TD NOWRAP align=right width=5%><FONT class="PortletText1"><A HREF="javascript:PopUp(''/myHelp/storage.html'');"  style="color: blue" style=""  ><B>FAQ ?</B></A></FONT></TD>

</TR>
</TABLE>
');

				RETURN;

			WHEN	p_display_object.display_type = c_display_type_attributes THEN		

				HTP.P('<!--------- c_display_type_attributes  -------------------->');

				IF p_summary.name IS NULL THEN 
					RETURN;
				END IF;

                                DECLARE             
                          
                                        TYPE title_property IS RECORD ( name    VARCHAR2(500),
                                                                        value   VARCHAR2(500));

                                        TYPE title_property_table IS TABLE OF title_property;

                                        l_list_of_title_properties      title_property_table := title_property_table();

                                BEGIN

                                        IF  p_summary.type = 'HOST' THEN

                                                l_list_of_title_properties.EXTEND;
                                                l_list_of_title_properties(l_list_of_title_properties.LAST).name := 'Host Name';
                                                l_list_of_title_properties(l_list_of_title_properties.LAST).value := p_summary.name;

                                                FOR rec IN (
                                                                SELECT  /*+ DRIVING_SITE(a)*/1	sort_order,
									DECODE(a.type,
                                                                                'REPORTING_DATACENTER','Data Center',
                                                                                'REPORTING_LOB','Line of Business',
                                                                                'REPORTING_CUSTOMER','Customer Name',
                                                                                'Group '||a.type
                                                                        )               name,
                                                                        a.name          value
                                                                FROM    stormon_group_table a,
                                                                        stormon_host_groups b
                                                                WHERE   a.id = b.group_id
                                                                AND     b.target_id = p_summary.id
                                                                AND     a.type IN ('REPORTING_DATACENTER','REPORTING_LOB','REPORTING_CUSTOMER')					
                                                                UNION
                                                                SELECT  2	sort_order,
									'Data of Data Collection',
                                                                        DECODE(a.summaryFlag,
                                                                                'N','Collection not enabled (collection never successful)',
                                                                                'I','Computation of storage summary has failed since '||p_summary.collection_timestamp,
                                                                                p_summary.collection_timestamp
                                                                        )
                                                                FROM    stormon_temp_results a 
								WHERE	a.row_type = 'SUMMARY'
								ORDER BY 
									1 ASC
                                                        )
                                                LOOP

                                                        l_list_of_title_properties.EXTEND;
                                                        l_list_of_title_properties(l_list_of_title_properties.LAST).name := rec.name;
                                                        l_list_of_title_properties(l_list_of_title_properties.LAST).value := rec.value;

                                                END LOOP;

                                        ELSE

                                                FOR rec IN (
                                                                SELECT  DECODE(a.type,
                                                                                'REPORTING_DATACENTER','Data Center',
                                                                                'REPORTING_LOB','Line of Business',
                                                                                'REPORTING_CUSTOMER','Customer Name',
                                                                                'Group '||a.type) name,
                                                                        a.name          value
                                                                FROM    stormon_temp_results a 
								WHERE	a.row_type = 'SUMMARY'
                                                        )
                                                LOOP

                                                        l_list_of_title_properties.EXTEND;
                                                        l_list_of_title_properties(l_list_of_title_properties.LAST).name := rec.name;
                                                        l_list_of_title_properties(l_list_of_title_properties.LAST).value := rec.value;

                                                END LOOP;

                                        END IF;

                                        IF l_list_of_title_properties IS NULL OR NOT l_list_of_title_properties.EXISTS(1) THEN
                                                RETURN;
                                        END IF;

                                        HTP.P('
                                        <TABLE class="fullwidthtable" cellspacing=0 cellpadding=0>');

                                        FOR i IN l_list_of_title_properties.FIRST..l_list_of_title_properties.LAST LOOP

                                                HTP.P('
                                                <TR>');

                                                HTP.P('
                                                        <TD align="right" width="48%">'||l_list_of_title_properties(i).name||'</TD>');

                                                HTP.P('
                                                        <TD width="3%" align="center">'||'&'||'nbsp;'||':'||'&'||'nbsp;'||'</TD>');

                                                HTP.P('
                                                        <TD align="left">'||l_list_of_title_properties(i).value||'</TD>');

                                                HTP.P('
                                                </TR>');

                                        END LOOP;

                                        HTP.P('
                                        </TABLE>');

                                END;

				RETURN;

			ELSE
				NULL;

			END CASE;		
	
	
			-----------------------------------------------------
			-- skim data and Render each display object here
			-----------------------------------------------------
			CASE 
	
				----------------------------------
				--	Usage table, same level
				----------------------------------
				WHEN p_display_object.type =  c_usage_summary_table THEN
					
					SELECT	storage_reporting_table_object(
						GET_FMT_STORAGE(rawsize),
						GET_FMT_STORAGE(sizeb),
						GET_FMT_STORAGE(local_filesystem_size+nfs_exclusive_size+volumemanager_free+swraid_free+disk_free),
						GET_FMT_STORAGE(used),
						GET_FMT_STORAGE(free),
						GET_STORAGE_USAGE_METER(sizeb,ROUND((used * 100 )/DECODE(sizeb,NULL,1,0,1,sizeb)),3),					
						GET_FMT_STORAGE(free-(local_filesystem_free+oracle_database_free+nfs_exclusive_free)),
						GET_DRILLDOWN_LINK(p_main_tab,p_name,p_type,actual_targets,p_chart_type,p_drill_down_group_type,'HOST_DETAILS','SUMMARIZED_HOSTS'),				
						GET_HOSTS_NOT_COLLECTED_LINK(id,notcollected),
						GET_ISSUE_FMT_LINK(id,issues,'ISSUE','ISSUE_HOSTS'),
						GET_DRILLDOWN_LINK(p_main_tab,p_name,p_type,hostcount,p_chart_type,p_drill_down_group_type,'HOST_DETAILS'),			
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL					
					)
					BULK COLLECT INTO l_table_results
					FROM	stormon_temp_results a
					WHERE	a.row_type = 'SUMMARY';
	
				----------------------------------
				--	Usage table, same level
				----------------------------------
				WHEN p_display_object.type= c_host_usage_summary_table THEN
					
					SELECT	storage_reporting_table_object(
						GET_FMT_STORAGE(rawsize),
						GET_FMT_STORAGE(sizeb),
						GET_FMT_STORAGE(used),
						GET_FMT_STORAGE(disk_backup_used),
						GET_FMT_STORAGE(used-disk_backup_used),					
						GET_FMT_STORAGE(free),
						GET_FMT_STORAGE(free-(local_filesystem_free+oracle_database_free+nfs_exclusive_free)),
						GET_STORAGE_USAGE_METER(sizeb,ROUND((used * 100 )/DECODE(sizeb,NULL,1,0,1,sizeb)),3),					
						actual_targets,
						notcollected,
						issues,
						hostcount,
						NULL,
						NULL,
						NULL,					
						NULL,
						NULL,
						NULL,
						NULL,
						NULL					
					)
					BULK COLLECT INTO l_table_results
					FROM	stormon_temp_results a
					WHERE	a.row_type = 'SUMMARY';
	
				-------------------------------------------------
				--	Usage table for a list of groups
				-------------------------------------------------
				WHEN p_display_object.type= c_group_usage_table THEN
					
					SELECT	storage_reporting_table_object(
						STORAGE.GET_DRILLDOWN_LINK(p_main_tab,name,type,name),
						GET_FMT_STORAGE(rawsize),
						GET_FMT_STORAGE(sizeb),	
						GET_FMT_STORAGE(local_filesystem_size+nfs_exclusive_size+volumemanager_free+swraid_free+disk_free),
						GET_FMT_STORAGE(disk_backup_used),
						GET_FMT_STORAGE(used-disk_backup_used),
						GET_FMT_STORAGE(used),
						GET_STORAGE_USAGE_METER(sizeb,ROUND((used * 100 )/DECODE(sizeb,NULL,1,0,1,sizeb))),
						GET_FMT_STORAGE(free),
						GET_FMT_STORAGE(free-(local_filesystem_free+oracle_database_free+nfs_exclusive_free)),
						GET_HISTORY_LINK(id),					
						NULL,
						NULL,
						NULL,
						NULL,					
						NULL,
						NULL,
						NULL,
						NULL,						
						NULL					
					)
					BULK COLLECT INTO l_table_results
					FROM	stormon_temp_results a
					WHERE	a.row_type = 'DETAIL';
	
					SELECT	storage_reporting_table_object(
						name,
						GET_FMT_STORAGE(rawsize),
						GET_FMT_STORAGE(sizeb),	
						GET_FMT_STORAGE(local_filesystem_size+nfs_exclusive_size+volumemanager_free+swraid_free+disk_free),				
						GET_FMT_STORAGE(disk_backup_used),
						GET_FMT_STORAGE(used-disk_backup_used),
						GET_FMT_STORAGE(used),
						GET_STORAGE_USAGE_METER(sizeb,ROUND((used * 100 )/DECODE(sizeb,NULL,1,0,1,sizeb))),
						GET_FMT_STORAGE(free),
						GET_FMT_STORAGE(free-(local_filesystem_free+oracle_database_free+nfs_exclusive_free)),
						GET_HISTORY_LINK(id),					
						NULL,
						NULL,
						NULL,
						NULL,					
						NULL,
						NULL,
						NULL,
						NULL,						
						NULL					
					)
					INTO	l_table_total
					FROM	stormon_temp_results a
					WHERE	a.row_type = 'SUMMARY';
		
				-----------------------------------------------
				-- Usage table for a list of hosts
				-----------------------------------------------
				WHEN p_display_object.type= c_host_usage_table THEN
	
					SELECT	storage_reporting_table_object(
						STORAGE.GET_HOSTDETAILS_FMT_LINK(p_portlet_record.page_url,id,type,name),
						GET_FMT_STORAGE(rawsize),
						GET_FMT_STORAGE(sizeb),
						GET_FMT_STORAGE(local_filesystem_size+nfs_exclusive_size+volumemanager_free+swraid_free+disk_free),
						GET_FMT_AU_STORAGE(oracle_database_size,oracle_database_used),
						GET_FMT_AU_STORAGE(local_filesystem_size,local_filesystem_used),
						GET_FMT_AU_STORAGE(nfs_exclusive_size,nfs_exclusive_used),
						GET_FMT_AU_STORAGE(volumemanager_size,volumemanager_used),
						GET_FMT_AU_STORAGE(swraid_size,swraid_used),
						GET_FMT_STORAGE(disk_backup_size),
						GET_FMT_AU_STORAGE(disk_size,disk_used),
						GET_STORAGE_USAGE_METER(sizeb,ROUND((used * 100 )/DECODE(sizeb,NULL,1,0,1,sizeb))),				
						GET_FMT_STORAGE(free),					
						GET_FMT_STORAGE(free-(local_filesystem_free+oracle_database_free+nfs_exclusive_free)),
						GET_HISTORY_LINK(id),											
						NULL,
						NULL,
						NULL,
						NULL,
						NULL					
						)
					BULK COLLECT INTO l_table_results
					FROM	stormon_temp_results a
					WHERE	a.row_type = 'DETAIL';
	
	
					SELECT	storage_reporting_table_object(
						name,
						GET_FMT_STORAGE(rawsize),
						GET_FMT_STORAGE(sizeb),
						GET_FMT_STORAGE(local_filesystem_size+nfs_exclusive_size+volumemanager_free+swraid_free+disk_free),
						GET_FMT_AU_STORAGE(oracle_database_size,oracle_database_used),
						GET_FMT_AU_STORAGE(local_filesystem_size,local_filesystem_used),
						GET_FMT_AU_STORAGE(nfs_exclusive_size,nfs_exclusive_used),
						GET_FMT_AU_STORAGE(volumemanager_size,volumemanager_used),
						GET_FMT_AU_STORAGE(swraid_size,swraid_used),
						GET_FMT_STORAGE(disk_backup_size),
						GET_FMT_AU_STORAGE(disk_size,disk_used),
						GET_STORAGE_USAGE_METER(sizeb,ROUND((used * 100 )/DECODE(sizeb,NULL,1,0,1,sizeb))),				
						GET_FMT_STORAGE(free),					
						GET_FMT_STORAGE(free-(local_filesystem_free+oracle_database_free+nfs_exclusive_free)),
						GET_HISTORY_LINK(id),					
						NULL,
						NULL,
						NULL,
						NULL,						
						NULL					
						)
					INTO	l_table_total
					FROM	stormon_temp_results a
					WHERE	a.row_type = 'SUMMARY';
	
				------------------------------------
				--	Vendor table , same level
				------------------------------------
				WHEN p_display_object.type= c_vendor_table THEN
	
					SELECT	storage_reporting_table_object(
						vendor,
						GET_FMT_STORAGE(rawsize),
						GET_FMT_STORAGE(sizeb),
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL
						)
					BULK COLLECT INTO l_table_results
					FROM	(
							SELECT	'Network Appliance(NFS)' 	vendor,
								VENDOR_NFS_NETAPP_SIZE		sizeb,
								VENDOR_NFS_NETAPP_SIZE		rawsize						
							FROM	stormon_temp_results a
							WHERE	a.row_type = 'SUMMARY'	
							UNION	
	 						SELECT	 'Others' 											name,
								( VENDOR_OTHERS_SIZE + VENDOR_NFS_EMC_SIZE + VENDOR_NFS_SUN_SIZE + VENDOR_NFS_OTHERS_SIZE ) 	sizeb,
								( VENDOR_OTHERS_RAWSIZE + VENDOR_NFS_EMC_SIZE + VENDOR_NFS_SUN_SIZE + VENDOR_NFS_OTHERS_SIZE ) 	rawsize
							FROM	stormon_temp_results a
							WHERE	a.row_type = 'SUMMARY'
							UNION
							SELECT	'Hitachi' 		vendor,
								VENDOR_HITACHI_SIZE 	sizeb,
								VENDOR_HITACHI_RAWSIZE	rawsize
							FROM	stormon_temp_results a
							WHERE	a.row_type = 'SUMMARY'	
							UNION
							SELECT	'Sun' 		vendor,
								VENDOR_SUN_SIZE		sizeb,
								VENDOR_SUN_RAWSIZE 	rawsize
							FROM	stormon_temp_results a
							WHERE	a.row_type = 'SUMMARY'	
							UNION
							SELECT	'EMC Symmetrix' 	vendor,
								VENDOR_EMC_SIZE 	sizeb,
								VENDOR_EMC_RAWSIZE 	rawsize
							FROM	stormon_temp_results a
							WHERE	a.row_type = 'SUMMARY'	
					) a
					WHERE	a.sizeb > 0
					ORDER BY sizeb DESC;
	
	
					SELECT	storage_reporting_table_object(
						name,
						GET_FMT_STORAGE(rawsize),
						GET_FMT_STORAGE(sizeb),
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL
						)
					INTO	l_table_total
					FROM	stormon_temp_results a
					WHERE	a.row_type = 'SUMMARY';
	
				WHEN p_display_object.type= c_group_vendor_table THEN
	
					SELECT	storage_reporting_table_object(
						name,
						GET_FMT_STORAGE(rawsize),
						GET_FMT_STORAGE(sizeb),
						GET_FMT_AU_STORAGE(vendor_emc_rawsize,vendor_emc_size),
						GET_FMT_STORAGE(vendor_nfs_netapp_size),
						GET_FMT_STORAGE(vendor_sun_size),
						GET_FMT_STORAGE(vendor_hitachi_size),
						GET_FMT_STORAGE(
								vendor_nfs_others_size + 
								vendor_nfs_sun_size +
								vendor_nfs_others_size +
								vendor_others_size +
								vendor_hp_size),
						GET_HISTORY_LINK(id),
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL					
						)
					BULK COLLECT INTO l_table_results
					FROM	stormon_temp_results a
					WHERE	a.row_type = 'DETAIL';
	
					SELECT	storage_reporting_table_object(
						name,
						GET_FMT_STORAGE(rawsize),
						GET_FMT_STORAGE(sizeb),
						GET_FMT_AU_STORAGE(vendor_emc_rawsize,vendor_emc_size),
						GET_FMT_STORAGE(vendor_nfs_netapp_size),
						GET_FMT_STORAGE(vendor_sun_size),
						GET_FMT_STORAGE(vendor_hitachi_size),
						GET_FMT_STORAGE(
								vendor_nfs_others_size + 
								vendor_nfs_sun_size +
								vendor_nfs_others_size +
								vendor_others_size +
								vendor_hp_size),
						GET_HISTORY_LINK(id),
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL					
						)
					INTO	l_table_total
					FROM	stormon_temp_results a
					WHERE	a.row_type = 'SUMMARY';
					
				WHEN p_display_object.type= c_host_vendor_table THEN
				
					SELECT	storage_reporting_table_object(
						STORAGE.GET_HOSTDETAILS_FMT_LINK(p_portlet_record.page_url,id,type,name),
						GET_FMT_STORAGE(rawsize),
						GET_FMT_STORAGE(sizeb),
						GET_FMT_AU_STORAGE(vendor_emc_rawsize,vendor_emc_size),
						GET_FMT_STORAGE(vendor_nfs_netapp_size),
						GET_FMT_STORAGE(vendor_sun_size),
						GET_FMT_STORAGE(vendor_hitachi_size),
						GET_FMT_STORAGE(
								vendor_nfs_others_size + 
								vendor_nfs_sun_size +
								vendor_nfs_others_size +
								vendor_others_size +
								vendor_hp_size
						),
						GET_HISTORY_LINK(id),
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL
						)
					BULK COLLECT INTO l_table_results
					FROM	stormon_temp_results a
					WHERE	a.row_type = 'DETAIL';	
	
					SELECT	storage_reporting_table_object(
						name,
						GET_FMT_STORAGE(rawsize),
						GET_FMT_STORAGE(sizeb),
						GET_FMT_AU_STORAGE(vendor_emc_rawsize,vendor_emc_size),
						GET_FMT_STORAGE(vendor_nfs_netapp_size),
						GET_FMT_STORAGE(vendor_sun_size),
						GET_FMT_STORAGE(vendor_hitachi_size),
						GET_FMT_STORAGE(
								vendor_nfs_others_size + 
								vendor_nfs_sun_size +
								vendor_nfs_others_size +
								vendor_others_size +
								vendor_hp_size
						),
						GET_HISTORY_LINK(id),
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL
						)
					INTO	l_table_total
					FROM	stormon_temp_results a
					WHERE	a.row_type = 'SUMMARY';
	
				-----------------------------------------------
				-- Host count table
				-----------------------------------------------
				WHEN p_display_object.type= c_host_count_table THEN
	
					SELECT	storage_reporting_table_object(
						GET_DRILLDOWN_LINK(p_main_tab,p_name,p_type,actual_targets,p_chart_type,p_drill_down_group_type,'HOST_DETAILS','SUMMARIZED_HOSTS'),
						GET_HOSTS_NOT_COLLECTED_LINK(id,notcollected),
						GET_ISSUE_FMT_LINK(id,issues,'ISSUE','ISSUE_HOSTS'),
						GET_DRILLDOWN_LINK(p_main_tab,p_name,p_type,hostcount,p_chart_type,p_drill_down_group_type,'HOST_DETAILS'),
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL
						)
					BULK COLLECT INTO l_table_results
					FROM	stormon_temp_results a
					WHERE	a.row_type = 'SUMMARY';
	
	
				-----------------------------------------------
				-- Free storage table
				-----------------------------------------------
				WHEN p_display_object.type= c_free_storage_table THEN
	
					SELECT	storage_reporting_table_object(
						type,					
						GET_FMT_STORAGE(free),
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL						
						)
					BULK COLLECT INTO l_table_results
					FROM	(
							SELECT	'Disks'		type,
								disk_size	sizeb,
								disk_free	free
							FROM	stormon_temp_results a
							WHERE	a.row_type = 'SUMMARY'	
							UNION
							SELECT	'Software Raid'	type,
								swraid_size	sizeb,
								swraid_free	free
							FROM	stormon_temp_results a
							WHERE	a.row_type = 'SUMMARY'
							UNION
							SELECT	'Volume Manager'	type,	
								volumemanager_size	sizeb,
								volumemanager_free	free
							FROM	stormon_temp_results a
							WHERE	a.row_type = 'SUMMARY'	
							UNION
							SELECT	'Local Filesystem'	type,	
								local_filesystem_size	sizeb,
								local_filesystem_free	free
							FROM	stormon_temp_results a
							WHERE	a.row_type = 'SUMMARY'
							UNION
							SELECT	'Oracle Database'	type,	
								oracle_database_size	sizeb,
								oracle_database_free	free
							FROM	stormon_temp_results a
							WHERE	a.row_type = 'SUMMARY'	
							UNION
							SELECT	'Dedicated NFS'	type,	
								nfs_exclusive_size	sizeb,
								nfs_exclusive_free	free
							FROM	stormon_temp_results a
							WHERE	a.row_type = 'SUMMARY'	
						) a
					WHERE	a.sizeb > 0
					ORDER BY
						a.free DESC;
	
	
					SELECT	storage_reporting_table_object(
						name,					
						GET_FMT_STORAGE(free),
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL,
						NULL						
						)
					INTO	l_table_total
					FROM	stormon_temp_results a
					WHERE	a.row_type = 'SUMMARY';
	
				WHEN p_display_object.type= c_chart_used_free THEN
	
	                                l_bartag     := 'U';
					l_chart_title		:= 'Used Vs Free';
					l_chart_subtitle 	:= 'Total Storage '||GET_FMT_STORAGE(p_summary.sizeb);
	
					SELECT	name,
						value
					BULK COLLECT INTO l_fieldname, l_fieldvalue
					FROM	(
							SELECT	'Used'	 name,
								used		value
							FROM	stormon_temp_results a
							WHERE	a.row_type = 'SUMMARY'
							UNION
							SELECT	'Free'	hosts,	
								free		value
							FROM	stormon_temp_results a
							WHERE	a.row_type = 'SUMMARY'
						) a;
	
				WHEN p_display_object.type= c_chart_where_free THEN
	
	                                l_bartag     := 'F';
					l_chart_title		:= 'Free Storage Distribution';
					l_chart_subtitle 	:= 'Free Storage '||GET_FMT_STORAGE(p_summary.free);
	
	
					SELECT	type,
						free
					BULK COLLECT INTO l_fieldname, l_fieldvalue
					FROM	(
							SELECT	'Disks'		type,
								disk_size	sizeb,
								disk_free	free
							FROM	stormon_temp_results a
							WHERE	a.row_type = 'SUMMARY'
							UNION
							SELECT	'Software Raid'	type,
								swraid_size	sizeb,
								swraid_free	free
							FROM	stormon_temp_results a
							WHERE	a.row_type = 'SUMMARY'
							UNION
							SELECT	'Volume Manager'	type,	
								volumemanager_size	sizeb,
								volumemanager_free	free
							FROM	stormon_temp_results a
							WHERE	a.row_type = 'SUMMARY'
							UNION
							SELECT	'Local Filesystem'	type,	
								local_filesystem_size	sizeb,
								local_filesystem_free	free
							FROM	stormon_temp_results a
							WHERE	a.row_type = 'SUMMARY'
							UNION
							SELECT	'NFS Dedicated Filesystem'	type,	
								nfs_exclusive_size	sizeb,
								nfs_exclusive_free	free
							FROM	stormon_temp_results a
							WHERE	a.row_type = 'SUMMARY'
							UNION
							SELECT	'Oracle Database'	type,	
								oracle_database_size	sizeb,
								oracle_database_free	free
							FROM	stormon_temp_results a
							WHERE	a.row_type = 'SUMMARY'
						) a
					WHERE	a.sizeb > 0
					ORDER BY
						a.free DESC;					

				WHEN p_display_object.type = c_chart_vendor THEN
				--------------------------------
				-- VENDOR PIE CHART
				--------------------------------
	
	                                l_bartag     := 'V';
					l_chart_title		:= 'Vendor Distribution';
					l_chart_subtitle 	:= 'Total Storage '||GET_FMT_STORAGE(p_summary.sizeb);
	
					SELECT	name,
						value		
					BULK COLLECT INTO l_fieldname, l_fieldvalue			
					FROM	(
							SELECT	'Network Appliance(NFS)' name,
								VENDOR_NFS_NETAPP_SIZE value
							FROM	stormon_temp_results a
							WHERE	a.row_type = 'SUMMARY'
							UNION
							SELECT	'Others' name,
								( VENDOR_OTHERS_SIZE + VENDOR_NFS_EMC_SIZE + VENDOR_NFS_SUN_SIZE + VENDOR_NFS_OTHERS_SIZE ) value
							FROM	stormon_temp_results a
							WHERE	a.row_type = 'SUMMARY'
							UNION
							SELECT	'Hitachi' name,
								VENDOR_HITACHI_SIZE value
							FROM	stormon_temp_results a
							WHERE	a.row_type = 'SUMMARY'
							UNION
							SELECT	'Sun' name,
								VENDOR_SUN_SIZE	value
							FROM	stormon_temp_results a
							WHERE	a.row_type = 'SUMMARY'
							UNION
							SELECT	'EMC Symmetrix' name,
								VENDOR_EMC_SIZE value
							FROM	stormon_temp_results a
							WHERE	a.row_type = 'SUMMARY'
					) a
					WHERE	value > 0
					ORDER BY value DESC; 
	
	
				WHEN p_display_object.type= c_chart_top_n_used THEN
				--------------------------------
				-- HOSTS USED PIE CHART
				--------------------------------			
	                                l_bartag     := 'H';
					l_chart_title		:= 'Used Storage';
					l_chart_subtitle 	:= 'Used Storage '||GET_FMT_STORAGE(p_summary.used);
	
	
				        SELECT  DECODE(FLOOR(rk/c_topnrank),0,name,'OTHERS') name,
				                SUM(used)					
					BULK COLLECT INTO l_fieldname, l_fieldvalue
				        FROM (
				                SELECT  name,
				                        used,
				                        RANK() OVER ( ORDER BY used DESC ) rk
				                FROM   	stormon_temp_results a
						WHERE	a.row_type = 'DETAIL'
				                AND	( 
								id IS NOT NULL
								AND id != p_summary.id
						)
				                AND     used != 0				                				                
				        )
				        GROUP BY
				        DECODE(FLOOR(rk/c_topnrank),0,name,'OTHERS')
				        ORDER BY
			                SUM(used) DESC;	
									
	
				WHEN p_display_object.type= c_chart_top_n_free THEN
				--------------------------------
				-- HOSTS FREE PIE CHART
				--------------------------------
	
	                                l_bartag	:= 'H';
					l_chart_title		:= 'Free Storage';
					l_chart_subtitle 	:= 'Free Storage '||GET_FMT_STORAGE(p_summary.free);
	
				        SELECT  DECODE(FLOOR(rk/c_topnrank),0,name,'OTHERS') name,
				                SUM(free)
					BULK COLLECT INTO l_fieldname, l_fieldvalue					
				        FROM (
				                SELECT  name,
				                        free,
				                        RANK() OVER ( ORDER BY free DESC ) rk
				                FROM   	stormon_temp_results a
						WHERE	a.row_type = 'DETAIL'
				                and	(
								id IS NOT NULL
								AND id != p_summary.id
						)
				                AND     free != 0
				        )
				        GROUP BY
				        DECODE(FLOOR(rk/c_topnrank),0,name,'OTHERS')
				        ORDER BY
			                SUM(free) DESC;
	
				--------------------------------   
				-- DATACENTER PIE CHART  
				--------------------------------  
				WHEN p_display_object.type = c_chart_by_used THEN
	
					l_bartag     := 'D';
					l_chart_title		:= 'Storage Distribution';
					l_chart_subtitle 	:= 'Total Storage '||GET_FMT_STORAGE(p_summary.sizeb);
	
					SELECT  DECODE(FLOOR(rk/c_topnrank),0,name,'OTHERS'),
						SUM(sizeb)
					BULK COLLECT INTO l_fieldname, l_fieldvalue								
					FROM (
						SELECT  name,
							sizeb,
					                RANK() OVER ( ORDER BY sizeb DESC ) rk
					        FROM   	stormon_temp_results a
						WHERE	a.row_type = 'DETAIL'
					        AND	( 
								id IS NOT NULL
								AND id != p_summary.id
							)
					        	AND     sizeb != 0	                				                
					        )
					        GROUP BY
					        DECODE(FLOOR(rk/c_topnrank),0,name,'OTHERS')
					        ORDER BY
				                SUM(sizeb) DESC;
	
				WHEN p_display_object.type IN ( c_detailedreport_summary_table ,
								c_detailed_disk_table,	
								c_detailed_swraid_table,
								c_detailed_volume_table,
								c_detailed_localfs_table,
								c_detailed_dedicated_nfs_table,
								c_detailed_shared_nfs_table,
								c_detailed_app_oracledb_table,
								c_detailed_issues_table,
								c_detailed_warnings_table
								 )
				THEN

				DECLARE
					----------------------------------------------------------
					-- BUILD THE QUERY STRING FOR THE OTHER DETAILS
					----------------------------------------------------------
					l_select_fields		VARCHAR2(4000) := NULL;
					l_detailed_query 	VARCHAR2(4000) := NULL;
					l_total_query		VARCHAR2(4000) := NULL;
					l_orderstring 		VARCHAR2(4000) := NULL;
	
				BEGIN
					------------------------------------
					-- SELECT FIELDS
					------------------------------------
					IF p_display_object.column_titles IS NULL OR NOT p_display_object.column_titles.EXISTS(1) THEN
	
						RETURN;
	
					END IF;
	
					FOR k IN p_display_object.column_titles.FIRST..p_display_object.column_titles.LAST LOOP
		
						IF k = 1 THEN
							IF	p_display_object.column_titles(k) IS NOT NULL AND
								p_display_object.column_titles(k).column_no IS NOT NULL AND
								l_list_of_summary_columns.EXISTS(p_display_object.column_titles(k).column_no) AND
								l_list_of_summary_columns(p_display_object.column_titles(k).column_no).field_name IS NOT NULL
							THEN
								l_select_fields := 'SELECT storage_reporting_table_object('||l_list_of_summary_columns(p_display_object.column_titles(k).column_no).field_name;
							ELSE
								l_select_fields := 'SELECT storage_reporting_table_object(NULL ';
							END IF;
						ELSE
							IF	p_display_object.column_titles(k) IS NOT NULL AND
								p_display_object.column_titles(k).column_no IS NOT NULL AND
								l_list_of_summary_columns.EXISTS(p_display_object.column_titles(k).column_no) AND
								l_list_of_summary_columns(p_display_object.column_titles(k).column_no).field_name IS NOT NULL
							THEN
								l_select_fields := l_select_fields||','||l_list_of_summary_columns(p_display_object.column_titles(k).column_no).field_name;
							ELSE
								l_select_fields := l_select_fields||', NULL ';
							END IF;
						END IF;
		
					END LOOP;
					
					----------------------------------------------------
					-- Fill in the balance empty fields for the object
					----------------------------------------------------
					IF p_display_object.column_titles.COUNT < c_max_reporting_fields THEN

						FOR k IN (p_display_object.column_titles.LAST)+1..c_max_reporting_fields LOOP
							l_select_fields := l_select_fields||', NULL ';
						END LOOP;

					END IF;

					------------------------------------
					-- TABLE NAME
					------------------------------------
					IF p_display_object.sql_table IS NOT NULL THEN
	
						l_select_fields := l_select_fields||') FROM '||p_display_object.sql_table;
	
					ELSE
	
						RETURN;
	
					END IF;
	
					------------------------------------
					-- PREDICATE
					------------------------------------
					IF p_display_object.predicate IS NOT NULL THEN
	
						l_select_fields := l_select_fields||' WHERE '||p_display_object.predicate;
	
					ELSE
	
						RETURN;
	
					END IF;

					--------------------------------------------
					-- Get the details without the total
					--------------------------------------------
					IF p_display_object.total_field IS NOT NULL THEN
						l_detailed_query := l_select_fields||' AND UPPER('||p_display_object.total_field||') NOT LIKE ''TOTAL%'' ';
					ELSE
						l_detailed_query := l_select_fields;
					END IF;

					------------------------------------
					-- DEFAULT ORDER BY STRING
					------------------------------------
					IF p_display_object.default_order_by IS NOT NULL THEN
			
						l_orderString := ' ORDER BY '||p_display_object.default_order_by;
				
					END IF;
	
					------------------------------------
					-- ORDER BY SORT CONDITION 
					------------------------------------
					PRINTN(' Display object id compare '||p_display_object_type||' and the id '||STORAGE.GET_DISPLAY_OBJECT_ID(p_display_object));

					IF p_display_object_type = STORAGE.GET_DISPLAY_OBJECT_ID(p_display_object) THEN
				
						IF 	p_orderfield IS NOT NULL AND 
							l_list_of_summary_columns.EXISTS(p_orderfield) AND
							l_list_of_summary_columns(p_orderfield).order_clause IS NOT NULL
						THEN
							IF l_orderString IS NOT NULL THEN
								l_orderString := l_orderString||' , '||l_list_of_summary_columns(p_orderfield).order_clause;
							ELSE
								l_orderString := ' ORDER BY '||l_list_of_summary_columns(p_orderfield).order_clause;
							END IF;
	
							IF p_ordertype IN ('DESC','ASC') THEN
								l_orderString := l_orderString||' '||p_ordertype;
							ELSE
								l_orderString := l_orderString||' '||l_list_of_summary_columns(p_orderfield).order_type;
							END IF;	
	
						END IF;
	
					END IF;
		
					------------------------------------
					-- BULK FETCH FROM THE QUERY
					------------------------------------
					l_detailed_query := l_detailed_query||' '||l_orderString;
					
					STORAGE.PRINTN( 'Detailed query ' || l_detailed_query );

					-- Name contains id for a single host report
					OPEN l_cursor FOR l_detailed_query USING p_name;
	
					FETCH l_cursor BULK COLLECT INTO l_table_results;
	
					CLOSE l_cursor;


					--------------------------------------------
					-- Get the total
					--------------------------------------------
					IF p_display_object.total_field IS NOT NULL THEN

						-- Fetch the total
						l_total_query := l_select_fields||' AND UPPER('||p_display_object.total_field||') LIKE ''TOTAL%'' ';
						
						STORAGE.PRINTN( 'Totals query ' || l_total_query );
	
						BEGIN
							-- Name contains id for a single host report
							EXECUTE IMMEDIATE l_total_query INTO l_table_total USING p_name;
							--OPEN l_cursor FOR l_total_query USING p_name;							
		
							--FETCH l_cursor INTO l_table_total;
		
							--CLOSE l_cursor;
						EXCEPTION
							WHEN NO_DATA_FOUND  THEN
								NULL;
							WHEN TOO_MANY_ROWS THEN
								NULL;
							WHEN OTHERS THEN
								RAISE;
						END;

					END IF;
					
					STORAGE.PRINTN('completed fetching the data');
				END;

				WHEN p_display_object.type= c_meter_usage THEN
	
					SELECT	ROUND(( used * 100 )/DECODE(sizeb,NULL,1,0,1,sizeb)),
						sizeb
					INTO	l_metered_percent,l_metered_total
					FROM	stormon_temp_results a
					WHERE	a.row_type = 'SUMMARY';				
	
				WHEN p_display_object.type= c_history_graph THEN
				
					NULL;
				ELSE
				-- unsupported table type
					RETURN;
	
			END CASE;
	
			CASE
	
				WHEN p_display_object.display_type = c_display_type_meter THEN
	
					HTP.P('<!--------- c_display_type_meter -------------------->');

					HTP.P('<TH align="center">'|| GET_STORAGE_USAGE_METER(l_metered_total,l_metered_percent,3)||'</TH>');
	
				WHEN p_display_object.display_type = c_display_type_chart THEN
					
					HTP.P('<!--------- c_display_type_chart -------------------->');

					print_ptable_open('1','0');
					print_prow_open;
			
					-- At least 1 element to draw a pie
					IF l_fieldname IS NOT NULL AND l_fieldname.EXISTS(1) THEN
							                	                
						l_unit := get_storage_unit(p_summary.sizeb);
		
	   					print_pcol(get_chart_image(
							NULL,			-- l_chart_title
							l_chart_subtitle,
							l_fieldname,
							l_fieldvalue,
							p_chart_type,
							l_unit,
	                                                l_bartag,
							l_legend_position
							) ,
							'left' );

					END IF;
					
					HTP.P('</TR>');
					HTP.P('</TABLE>');
	
				-- Print the history graph
				WHEN p_display_object.display_type = c_display_type_graph THEN
				
					HTP.P('<!--------- c_display_type_graph -------------------->');
	
					IF NVL(p_summary.id,'-1') != '-1' THEN
						PRINT_HISTORY_GRAPH(p_summary.id);
					END IF;
					
				-- Display flat table 
				WHEN p_display_object.display_type = c_display_type_flattable THEN
	
					HTP.P('<!--------- c_display_type_flattable -------------------->');

					IF p_display_object.column_titles IS NULL OR NOT p_display_object.column_titles.EXISTS(1) THEN
						RETURN;
					END IF;
	
					HTP.P('<TABLE  class="datatable" cellspacing=1 cellpadding=1 >');
	
					HTP.P('	<TR class="headerrow stdfont" >
							<TH  class="titleheader" colspan='||NVL(p_display_object.flat_table_columns,1)*2||' ><FONT class="titlefont"><A NAME="'||p_display_object.tag||'" </A>'||p_display_object.title||'</FONT></TH>
						</TR>');						
	
					IF l_table_results IS NULL OR NOT l_table_results.EXISTS(1) THEN

						HTP.P('
					</TABLE>
						');				

						RETURN;

					END IF;

					FOR j IN l_table_results.FIRST..l_table_results.LAST LOOP
	
						l_field_position := 0;
	
						FOR k IN p_display_object.column_titles.FIRST..FLOOR(p_display_object.column_titles.LAST/NVL(p_display_object.flat_table_columns,1))+SIGN(MOD(p_display_object.column_titles.LAST,NVL(p_display_object.flat_table_columns,1))) LOOP
	
	
							HTP.P('
									<TR class="stdfont"> 
								');
								
							IF MOD(k,2) != 0 THEN
								l_cell_style_class :=	'lightcolor';
							ELSE
								l_cell_style_class :=	'darkcolor';
							END IF;
		
							FOR l IN 1..NVL(p_display_object.flat_table_columns,1) LOOP
	
						                IF (k-1)*NVL(p_display_object.flat_table_columns,1)+l > p_display_object.column_titles.COUNT THEN
									EXIT;
						                END IF;
	
						                IF l <= MOD(p_display_object.column_titles.LAST,NVL(p_display_object.flat_table_columns,1))+1 THEN
									l_offset := l-1;
						                ELSIF MOD(p_display_object.column_titles.LAST,NVL(p_display_object.flat_table_columns,1)) > 0 THEN
						                	l_offset := l;
						                ELSE
									l_offset := 0;
							        END IF;
	
								l_field_position := k+FLOOR(p_display_object.column_titles.LAST/NVL(p_display_object.flat_table_columns,1))*(l-1)+l_offset;
	
								IF 	p_display_object.column_titles(l_field_position).column_no IS NOT NULL THEN
						
	                             					HTP.P('			<TD class="charcolumn '||l_cell_style_class||'" width=><FONT class="PortletSubHeaderText">'||l_list_of_summary_columns(p_display_object.column_titles(l_field_position).column_no).column_name||'</FONT></TD> ');
	
									CASE
										WHEN l_list_of_summary_columns(p_display_object.column_titles(l_field_position).column_no).column_type = 'NUMERIC' THEN
											
											PRINT_TABLE_RESULTS(l_table_results(j),l_field_position,'numcolumn '||l_cell_style_class);
	
										WHEN l_list_of_summary_columns(p_display_object.column_titles(l_field_position).column_no).column_type = 'GRAPHIC' THEN
		
											PRINT_TABLE_RESULTS(l_table_results(j),l_field_position,'graphiccolumn '||l_cell_style_class);	
										ELSE
											PRINT_TABLE_RESULTS(l_table_results(j),l_field_position,'charcolumn '||l_cell_style_class);
									END CASE;				
													
								END IF;
	
						        END LOOP;
	
							HTP.P('
								</TR>
							');						
	
						END LOOP;
	
					END LOOP;
	
					HTP.P('</TABLE>
					');				
	
				-- Display table
				WHEN p_display_object.display_type = c_display_type_table THEN
	
					HTP.P('<!--------- c_display_type_table -------------------->');

					IF 	p_display_object.column_titles IS NULL OR NOT p_display_object.column_titles.EXISTS(1) THEN
						RETURN;
					END IF;
				
					HTP.P('<TABLE  border="0" cellspacing=0 cellpadding=0 width="100%">');

					-- Print the table title
					IF p_display_object.title IS NOT NULL THEN
						
						HTP.P('	<TR>
								<TH align="left" width="100%" > <FONT class="stdfont tabletitlecolor"><A name="'|| STORAGE.GET_DISPLAY_OBJECT_ID(p_display_object)||'"></A>'|| p_display_object.title);			

						-- Print the top arrow if this is a navigable tag		
						IF p_display_object.tag IS NOT NULL THEN
	
							HTP.P('<A HREF="javascript:;" onclick="javascript:loadpage(''top'');"><IMG BORDER=0 SRC=/myImages/mv-up.gif align=ABSBOTTOM ALT="Go to Top of the Page"></A>');
	
						END IF;

						HTP.P('</FONT>
							</TH>
							</TR>');
					END IF;

					HTP.P('<TR><TD width="100%"  >');
					HTP.P('<TABLE  class="datatable" cellspacing=1 cellpadding=1 >');
				
					-- Check if the title columns have more than one row ( only two rows supported at this time )	
					l_table_title_rows := 1;		
					FOR j IN p_display_object.column_titles.FIRST..p_display_object.column_titles.LAST LOOP
		
						IF p_display_object.column_titles(j).subtitle IS NOT NULL AND p_display_object.column_titles(j).subtitle.EXISTS(1) THEN
							l_table_title_rows := 2;
							EXIT;
						END IF;
	
					END LOOP;


					-- Count the max columns to set colspan for error message if no table data to print
					l_column_count := 0;
					IF l_table_title_rows > 1 THEN

						FOR k IN p_display_object.column_titles.FIRST..p_display_object.column_titles.LAST LOOP
					
							IF 	p_display_object.column_titles(k).subtitle IS NULL OR NOT p_display_object.column_titles(k).subtitle.EXISTS(1) 
							THEN
						
								l_column_count := l_column_count + 1;			
						
							ELSE
	
								FOR l IN p_display_object.column_titles(k).subtitle.FIRST..p_display_object.column_titles(k).subtitle.LAST LOOP
	
									l_column_count := l_column_count + 1;				
	
								END LOOP;
	
							END IF;
			
						END LOOP;
					ELSE
						l_column_count := p_display_object.column_titles.COUNT;
					END IF;

					--------------------------------------------
					-- PRINT FIRST TITLE ROW
					--------------------------------------------							
					HTP.P('
						<TR class="headerrow stdfont" >
							');
		
					FOR j IN p_display_object.column_titles.FIRST..p_display_object.column_titles.LAST LOOP
		
						IF p_display_object.column_titles(j).subtitle IS NOT NULL AND p_display_object.column_titles(j).subtitle.EXISTS(1) THEN
										
								HTP.P('<TH  class="titleheader" colspan='||p_display_object.column_titles(j).subtitle.COUNT||'><FONT class="titlefont">'||
				STORAGE.GET_SUMMARY_SORTING_LINK(
					p_main_tab,
					p_search_name,
					p_name,
					p_type,
					p_chart_type,
					p_drill_down_group_type,
					p_sub_tab,
					p_host_type,
					p_orderfield,				
					p_ordertype,
					p_display_object_type,
					p_display_object.column_titles(j).column_no,
					STORAGE.GET_DISPLAY_OBJECT_ID(p_display_object))||'</FONT></TH>');

						ELSE
										
								HTP.P('<TH  class="titleheader" rowspan='||l_table_title_rows||'><FONT class="titlefont">'||
				STORAGE.GET_SUMMARY_SORTING_LINK(
					p_main_tab,
					p_search_name,
					p_name,
					p_type,
					p_chart_type,
					p_drill_down_group_type,
					p_sub_tab,
					p_host_type,
					p_orderfield,				
					p_ordertype,
					p_display_object_type,
					p_display_object.column_titles(j).column_no,
					STORAGE.GET_DISPLAY_OBJECT_ID(p_display_object))||'</FONT></TH>');	
		  				 	
						END IF;	
		
					END LOOP;				
		
					HTP.P('
						</TR>
					');		               
					
					--------------------------------------------
					-- PRINT SECOND TITLE ROW IF IT EXISTS
					--------------------------------------------
	
					IF l_table_title_rows = 2 THEN
		
						HTP.P('
						<TR class="headerrow stdfont" >
							');					
		
						FOR l IN p_display_object.column_titles.FIRST..p_display_object.column_titles.LAST LOOP
				
							IF p_display_object.column_titles(l).subtitle IS NOT NULL AND p_display_object.column_titles(l).subtitle.EXISTS(1) THEN
					
								FOR m IN p_display_object.column_titles(l).subtitle.FIRST..p_display_object.column_titles(l).subtitle.LAST LOOP
														
								HTP.P('<TH  class="titleheader"><FONT class="titlefont">'||
				STORAGE.GET_SUMMARY_SORTING_LINK(
					p_main_tab,
					p_search_name,
					p_name,
					p_type,
					p_chart_type,
					p_drill_down_group_type,
					p_sub_tab,
					p_host_type,
					p_orderfield,				
					p_ordertype,
					p_display_object_type,
					p_display_object.column_titles(l).subtitle(m),
					STORAGE.GET_DISPLAY_OBJECT_ID(p_display_object))||'</FONT></TH>');
									
								END LOOP;			
								
							END IF;
	
						END LOOP;
	
						HTP.P('
							</TR>
						');
	
					END IF;

				-- Print the table data here	
				IF l_table_total IS NOT NULL THEN
					IF l_table_results IS NULL AND NOT l_table_results.EXISTS(1) THEN
						l_table_results := storage_reporting_results();
					END IF;
					l_table_results.EXTEND;
					l_table_results(l_table_results.LAST) := l_table_total;
				END IF;			

				IF l_table_results IS NOT NULL AND l_table_results.EXISTS(1) THEN

					FOR j IN l_table_results.FIRST..l_table_results.LAST LOOP
		
						HTP.P('
						<TR class="stdfont"> 
							');
								
						IF MOD(j,2) != 0 THEN
							l_cell_style_class :=	'lightcolor';
						ELSE
							l_cell_style_class :=	'darkcolor';
						END IF;
	
						l_field_position := 0;
	
						FOR k IN p_display_object.column_titles.FIRST..p_display_object.column_titles.LAST LOOP
						
							IF 	p_display_object.column_titles(k).subtitle IS NULL OR NOT p_display_object.column_titles(k).subtitle.EXISTS(1) THEN
						
								l_field_position := l_field_position + 1;
	
								CASE
									WHEN l_list_of_summary_columns(p_display_object.column_titles(k).column_no).column_type = 'NUMERIC' THEN
			
										PRINT_TABLE_RESULTS(l_table_results(j),l_field_position,'numcolumn '||l_cell_style_class);
		
									WHEN l_list_of_summary_columns(p_display_object.column_titles(k).column_no).column_type = 'GRAPHIC' THEN
				
										PRINT_TABLE_RESULTS(l_table_results(j),l_field_position,'graphiccolumn '||l_cell_style_class);	
									ELSE
										PRINT_TABLE_RESULTS(l_table_results(j),l_field_position,'charcolumn '||l_cell_style_class);
								END CASE;					
						
							ELSE
	
								FOR l IN p_display_object.column_titles(k).subtitle.FIRST..p_display_object.column_titles(k).subtitle.LAST LOOP
		
									l_field_position :=  l_field_position + 1;
		
									CASE
										WHEN l_list_of_summary_columns(p_display_object.column_titles(k).subtitle(l)).column_type = 'NUMERIC' THEN
			
											PRINT_TABLE_RESULTS(l_table_results(j),l_field_position,'numcolumn '||l_cell_style_class);
		
										WHEN l_list_of_summary_columns(p_display_object.column_titles(k).subtitle(l)).column_type = 'GRAPHIC' THEN
		
											PRINT_TABLE_RESULTS(l_table_results(j),l_field_position,'graphiccolumn '||l_cell_style_class);	
										ELSE
											PRINT_TABLE_RESULTS(l_table_results(j),l_field_position,'charcolumn '||l_cell_style_class);
									END CASE;					
	
								END LOOP;
	
							END IF;
					
						END LOOP;
		
						HTP.P('
					</TR>
						');
	
					END LOOP;			
	
				ELSE
					IF p_display_object.error_message IS NOT NULL THEN
						HTP.P('
						<TR class="stdfont"> 
							<TD align="center" class="lightcolor" colspan='||l_column_count||'><FONT class="errormessagefont">'|| p_display_object.error_message ||'<FONT></TD>
						</TR>
					');
					END IF;

				END IF;

				HTP.P('
				</TABLE>
				');

				HTP.P('
				</TD></TR></TABLE>');
				STORAGE.PRINTN('end of display table ');
		END CASE;		

EXCEPTION
	WHEN OTHERS THEN
		STORAGE.PRINTN(' Raising exception in print_display_object '||SQLERRM);
		RAISE;
	
END print_display_object;


PROCEDURE single_host_report (
				p_portlet_record  	IN OUT WWPRO_API_PROVIDER.portlet_runtime_record,
				p_main_tab		IN VARCHAR2 ,
				p_search_name		IN VARCHAR2 ,
				p_name			IN VARCHAR2 ,
				p_type			IN VARCHAR2 ,
				p_chart_type		IN VARCHAR2 ,
				p_drill_down_group_type	IN VARCHAR2 ,
				p_sub_tab		IN VARCHAR2 , 
				p_host_type		IN VARCHAR2 ,	 
				p_orderfield		IN INTEGER , 
				p_ordertype		IN VARCHAR2 ,
				p_display_object_type	IN VARCHAR2 DEFAULT 'top' )
IS

l_summary			storage_summaryObject_view%ROWTYPE;
l_time				INTEGER := 0;
l_storage_link  		VARCHAR2(4096);
l_hostdetail_report_object	report_object;  

BEGIN

	BEGIN

		SELECT	/*+ DRIVING_SITE(a)*/*                         
		INTO	l_summary
		FROM	storage_summaryObject_view a
		WHERE	id = p_name;
	
	EXCEPTION
		WHEN OTHERS THEN
			RAISE;
	END;


	-----------------------------------------------------------------------------
	-- Inserting the fetched data into temporary tables for querying
	-----------------------------------------------------------------------------
	BEGIN

		DELETE FROM stormon_temp_results;
	
		IF l_summary.name IS NOT NULL THEN
	
			INSERT INTO stormon_temp_results
			VALUES(
				'SUMMARY',
				l_summary.name,
				l_summary.id,
				l_summary.type,
				l_summary.timestamp,
				l_summary.collection_timestamp,
				l_summary.hostcount,
				l_summary.actual_targets,
				l_summary.issues,
				l_summary.hostcount-(l_summary.actual_targets+l_summary.issues),		-- not collected,
				l_summary.warnings,
				l_summary.summaryflag,
				l_summary.application_rawsize,
				l_summary.application_size,
				l_summary.application_used,
				l_summary.application_free,
				l_summary.oracle_database_rawsize,
				l_summary.oracle_database_size,
				l_summary.oracle_database_used,
				l_summary.oracle_database_free,
				l_summary.local_filesystem_rawsize,
				l_summary.local_filesystem_size,
				l_summary.local_filesystem_used,
				l_summary.local_filesystem_free,
				l_summary.nfs_exclusive_size,
				l_summary.nfs_exclusive_used,
				l_summary.nfs_exclusive_free,
				l_summary.nfs_shared_size,
				l_summary.nfs_shared_used,
				l_summary.nfs_shared_free,
				l_summary.volumemanager_rawsize,
				l_summary.volumemanager_size,
				l_summary.volumemanager_used,
				l_summary.volumemanager_free,
				l_summary.swraid_rawsize,
				l_summary.swraid_size,
				l_summary.swraid_used,
				l_summary.swraid_free,
				l_summary.disk_backup_rawsize,
				l_summary.disk_backup_size,
				l_summary.disk_backup_used,
				l_summary.disk_backup_free,
				l_summary.disk_rawsize,
				l_summary.disk_size,
				l_summary.disk_used,
				l_summary.disk_free,
				l_summary.rawsize,
				l_summary.sizeb,
				l_summary.used,
				l_summary.free,
				l_summary.vendor_emc_size,
				l_summary.vendor_emc_rawsize,
				l_summary.vendor_sun_size,
				l_summary.vendor_sun_rawsize,
				l_summary.vendor_hp_size,
				l_summary.vendor_hp_rawsize,
				l_summary.vendor_hitachi_size,
				l_summary.vendor_hitachi_rawsize,
				l_summary.vendor_others_size,
				l_summary.vendor_others_rawsize,
				l_summary.vendor_nfs_netapp_size,
				l_summary.vendor_nfs_emc_size,
				l_summary.vendor_nfs_sun_size,
				l_summary.vendor_nfs_others_size);			
	
			END IF;

		EXCEPTION
			WHEN OTHERS THEN
				STORAGE.PRINTN('Error inserting results into stormon_temp_results');
				RAISE;	
		END;


		STORAGE.GETTIME(l_time,'Time taken to insert fetched data into temporary tables');


			l_hostdetail_report_object := report_object(
							'SINGLE_HOST_REPORT',
							NULL,
							'Host Detail Report',
							display_object_table(
								l_outer_table_object,
									l_row_open_object,
									l_column_open_object,
										l_fullwidth_table_object,
											l_row_open_object,
											l_column_open_object,
												display_object(NULL,'Host Detail Report',c_display_type_report_title,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
											l_column_close_object,
											l_row_close_object,
										l_table_close_object,
									l_column_close_object,
									l_row_close_object,

									l_row_open_object,
									l_column_open_object,
										l_fullwidth_table_object,
											l_row_open_object,
											l_column_open_object,
												l_navigation_link_object,
											l_column_close_object,
											l_row_close_object,											
										l_table_close_object,
									l_column_close_object,
									l_row_close_object,

									l_row_open_object,
									l_column_open_object,
										display_object(NULL,NULL,c_display_type_draw_line,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
									l_column_close_object,
									l_row_close_object,

									l_row_open_object,
									l_column_open_object,
										display_object(NULL,NULL,c_display_type_attributes,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
									l_column_close_object,	
									l_row_close_object,	

									l_row_open_object,
									l_column_open_object,
										display_object(NULL,'Storage Distribution',c_display_type_section_open,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
											l_column_open_object,	
												display_object(NULL,'Free Storage Distribution',c_display_type_subsection_open,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
													l_column_50_open_object,
														l_chart_used_free,
													l_column_close_object,
													l_column_50_open_object,
														l_chart_where_free,
													l_column_close_object,		
													l_column_50_open_object,	
														display_object(NULL,'History',c_display_type_subsection_open,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
															l_column_open_object,
																l_history_graph,
															l_column_close_object,
														display_object(NULL,NULL,c_display_type_ssection_close,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
													l_column_close_object,
												display_object(NULL,NULL,c_display_type_ssection_close,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
											l_column_close_object,										
										display_object(NULL,NULL,c_display_type_section_close,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
									l_column_close_object,
									l_row_close_object,

									l_row_open_object,
									l_column_open_object,
										l_fullwidth_table_object,
											l_row_open_object,
											l_column_open_object,
												l_detailed_summary_object,
											l_column_close_object,
											l_row_close_object,											
										l_table_close_object,
									l_column_close_object,
									l_row_close_object,

									l_row_open_object,
									l_column_open_object,
										l_fullwidth_table_object,
											l_row_open_object,
											l_column_open_object,
												l_detailed_disk_object,
											l_column_close_object,
											l_row_close_object,											
										l_table_close_object,
									l_column_close_object,
									l_row_close_object,

									l_row_open_object,
									l_column_open_object,
										l_fullwidth_table_object,
											l_row_open_object,
											l_column_open_object,
												l_detailed_swraid_object,
											l_column_close_object,
											l_row_close_object,											
										l_table_close_object,
									l_column_close_object,
									l_row_close_object,

									l_row_open_object,
									l_column_open_object,
										l_fullwidth_table_object,
											l_row_open_object,
											l_column_open_object,
												l_detailed_volume_object,
											l_column_close_object,
											l_row_close_object,											
										l_table_close_object,
									l_column_close_object,
									l_row_close_object,

									l_row_open_object,
									l_column_open_object,
										l_fullwidth_table_object,
											l_row_open_object,
											l_column_open_object,
												l_detailed_localfs_object,
											l_column_close_object,
											l_row_close_object,											
										l_table_close_object,
									l_column_close_object,
									l_row_close_object,

									l_row_open_object,
									l_column_open_object,
										l_fullwidth_table_object,
											l_row_open_object,
											l_column_open_object,
												l_detailed_nfs_object,
											l_column_close_object,
											l_row_close_object,											
										l_table_close_object,
									l_column_close_object,
									l_row_close_object,

									l_row_open_object,
									l_column_open_object,
										l_fullwidth_table_object,
											l_row_open_object,
											l_column_open_object,
												l_detailed_shared_nfs_object,
											l_column_close_object,
											l_row_close_object,											
										l_table_close_object,
									l_column_close_object,
									l_row_close_object,

									l_row_open_object,
									l_column_open_object,
										l_fullwidth_table_object,
											l_row_open_object,
											l_column_open_object,
												l_detailed_oracledb_object,
											l_column_close_object,
											l_row_close_object,											
										l_table_close_object,
									l_column_close_object,
									l_row_close_object,

									l_row_open_object,
									l_column_open_object,
										l_fullwidth_table_object,
											l_row_open_object,
											l_column_open_object,
												l_issues_object,
											l_column_close_object,
											l_row_close_object,											
										l_table_close_object,
									l_column_close_object,
									l_row_close_object,

									l_row_open_object,
									l_column_open_object,
										l_fullwidth_table_object,
											l_row_open_object,
											l_column_open_object,
												l_warnings_object,
											l_column_close_object,
											l_row_close_object,
										l_table_close_object,
									l_column_close_object,
									l_row_close_object,
								l_table_close_object
								),
								NULL							
							);

	FOR i IN l_hostdetail_report_object.display_object_list.FIRST..l_hostdetail_report_object.display_object_list.LAST LOOP
		
		STORAGE.PRINTN('IN single host report displaying host '||l_hostdetail_report_object.display_object_list(i).title);

		STORAGE.PRINT_DISPLAY_OBJECT(
					p_portlet_record ,
					p_main_tab,
					p_search_name,
					p_name,
					p_type,
					p_chart_type,
					p_drill_down_group_type,
					p_sub_tab, 
					p_host_type,	 
					p_orderfield, 
					p_ordertype,
					p_display_object_type,
					l_hostdetail_report_object.display_object_list(i),
					l_hostdetail_report_object.display_object_list,
					l_hostdetail_report_object,
					NULL,
					NULL,
					NULL,
					l_summary
			);


	END LOOP;


	-------------------------------------------------------
	-- Delete the data inserted into the temporary tables
	-------------------------------------------------------
	DELETE FROM stormon_temp_results;
                                                                                                                                                    

/*	HTP.P( '<TABLE border=0>');              

	print_prow_open;
        print_pheader('<B>' || get_history_link(l_summary) || '</B>' ||
       	              BLANK2 || '<A HREF="javascript:PopUp(''/myHelp/storage.html'');"><B>FAQ ?</B></A>' ,
               	     'RIGHT');                     
	HTP.P('</TR>');
	
	print_line('bgcolor=#CCCC8C');           
	print_prow_open;
	print_pcol(l_storage_link,'RIGHT');                     		
	HTP.P('</TR>');
	print_line('bgcolor=#CCCC8C');           	
	HTP.P('</TABLE>');              
        print_line_break;
*/
			  				     
 END single_host_report ;    


------------------------------------------------
-- Generate the summary report
------------------------------------------------
PROCEDURE classical_drill_down (
				p_portlet_record  	IN OUT WWPRO_API_PROVIDER.portlet_runtime_record,
				p_main_tab		IN VARCHAR2 DEFAULT 'MAIN_TAB_DATACENTER',
				p_search_name		IN VARCHAR2 DEFAULT 'FALSE',
				p_name			IN VARCHAR2 DEFAULT 'ALL',
				p_type			IN VARCHAR2 DEFAULT 'REPORTING_DATACENTER',
				p_chart_type		IN VARCHAR2 DEFAULT 'PIE' ,
				p_drill_down_group_type	IN VARCHAR2 DEFAULT 'REPORTING_DATACENTER',
				p_sub_tab		IN VARCHAR2 DEFAULT 'SUMMARY', --p_drill_down_type	IN VARCHAR2 DEFAULT 'DEFAULT',
				p_host_type		IN VARCHAR2 DEFAULT 'ALL_HOSTS',	 
				p_orderfield		IN INTEGER DEFAULT 3, 
				p_ordertype		IN VARCHAR2 DEFAULT 'DEFAULT',
				p_display_object_type	IN VARCHAR2 DEFAULT 'top'				
			) IS

l_list_of_main_tabs		tab_object_table;
l_report_objects		report_object_table;
l_summary_report_object		report_object;
l_group_details_report_object	report_object;
l_host_details_report_object	report_object;
l_display_object		display_object;

l_name				VARCHAR2(32767);
l_group_type			stormon_group_table.type%TYPE;
l_group_type_title		VARCHAR2(50);

l_predicate			VARCHAR2(32767);
l_list_of_targets_predicate	VARCHAR2(32767);
l_group_summary_predicate	VARCHAR2(32767);
l_host_details_predicate	VARCHAR2(32767);
l_list_of_c_groups_predicate	VARCHAR2(32767);
l_group_details_predicate	VARCHAR2(32767);
l_host_predicate		VARCHAR2(32767);
l_orderList			VARCHAR2(4000) := ' sizeb DESC ';

l_table				INTEGER;
l_id_count			INTEGER;
l_group_id			stormon_group_table.id%TYPE;

l_cursor			SYS_REFCURSOR;
l_summary			storage_summaryObject_view%ROWTYPE;
l_all_summaries			summary_table;

-- Timing variables
l_elapsed_time			INTEGER := 0;
l_time				INTEGER := 0;

-- Report Title
l_report_title			VARCHAR2(1000);

--------------------------------------------------------------------------------------------
-- List of fields to be selected for summary
--------------------------------------------------------------------------------------------
l_summary_fields VARCHAR2(5000) := 'SELECT	
--						ROWNUM,
						a.name,
						a.id,
						a.type,						-- a.type,
						a.timestamp		,			-- timestamp
						a.collection_timestamp	,			-- collection_timestamp
						a.hostcount		,			-- hostcount
						a.actual_targets		,		-- actual_targets
						a.issues			,		-- issues
--						a.hostcount-(a.actual_targets+a.issues),	-- not collected
						a.warnings		,			-- warnings
						a.summaryFlag     	,			-- summaryFlag
						a.application_rawsize	,
						a.application_size	,
						a.application_used	,
						a.application_free	,
						a.oracle_database_rawsize	,
						a.oracle_database_size	,
						a.oracle_database_used	,
						a.oracle_database_free	,
						a.local_filesystem_rawsize,
						a.local_filesystem_size	,
						a.local_filesystem_used	,
						a.local_filesystem_free	,
						a.nfs_exclusive_size	,
						a.nfs_exclusive_used	,
						a.nfs_exclusive_free	,
						a.nfs_shared_size		,
						a.nfs_shared_used		,
						a.nfs_shared_free		,
						a.volumemanager_rawsize	,
						a.volumemanager_size	,
						a.volumemanager_used	,
						a.volumemanager_free	,
						a.swraid_rawsize		,
						a.swraid_size		,
						a.swraid_used		,
						a.swraid_free		,
						a.disk_backup_rawsize	,
						a.disk_backup_size	,
						a.disk_backup_used	,
						a.disk_backup_free	,
						a.disk_rawsize		,
						a.disk_size		,
						a.disk_used		,
						a.disk_free		,
						a.rawsize			,
						a.sizeb			,
						a.used			,
						a.free			,
						a.vendor_emc_size		,
						a.vendor_emc_rawsize	,
						a.vendor_sun_size		,
						a.vendor_sun_rawsize	,
						a.vendor_hp_size		,
						a.vendor_hp_rawsize	,
						a.vendor_hitachi_size	,
						a.vendor_hitachi_rawsize	,
						a.vendor_others_size	,
						a.vendor_others_rawsize	,
						a.vendor_nfs_netapp_size	,
						a.vendor_nfs_emc_size	,
						a.vendor_nfs_sun_size	,
						a.vendor_nfs_others_size
				';


l_group_summary_fields	VARCHAR2(5000)	:= '				
				SELECT	/*+ DRIVING_SITE(a)*/ ''TOTAL''			name,						
					NULL				id,	
					'''||p_type||'''		type,
					SYSDATE				timestamp,		-- timestamp
					MAX(a.collection_timestamp)	collection_timestamp,	-- collection_timestamp
					NULL				hostcount,		-- hostcount
					NULL				actual_targets,		-- actual_targets
					NULL				issues,			-- issues
					NULL				notcollected,		-- not collected
					NULL				warnings,		-- warnings
					''N''     			summaryflag,		-- summaryFlag
					SUM(a.application_rawsize)	application_rawsize,
					SUM(a.application_size)		application_size,
					SUM(a.application_used)		application_used,
					SUM(a.application_free)		application_free,
					SUM(a.oracle_database_rawsize)	oracle_database_rawsize,
					SUM(a.oracle_database_size)	oracle_database_size,
					SUM(a.oracle_database_used)	oracle_database_used,
					SUM(a.oracle_database_free)	oracle_database_free,
					SUM(a.local_filesystem_rawsize)	local_filesystem_rawsize,
					SUM(a.local_filesystem_size)	local_filesystem_size,
					SUM(a.local_filesystem_used)	local_filesystem_used,
					SUM(a.local_filesystem_free)	local_filesystem_free,
					SUM(a.nfs_exclusive_size)	nfs_exclusive_size,
					SUM(a.nfs_exclusive_used)	nfs_exclusive_used,
					SUM(a.nfs_exclusive_free)	nfs_exclusive_free,
					SUM(a.nfs_shared_size	)	nfs_shared_size,
					SUM(a.nfs_shared_used	)	nfs_shared_used,
					SUM(a.nfs_shared_free	)	nfs_shared_free,
					SUM(a.volumemanager_rawsize)	volumemanager_rawsize,
					SUM(a.volumemanager_size)	volumemanager_size,
					SUM(a.volumemanager_used)	volumemanager_used,
					SUM(a.volumemanager_free)	volumemanager_free,
					SUM(a.swraid_rawsize	)	swraid_rawsize,
					SUM(a.swraid_size	)	swraid_size,
					SUM(a.swraid_used	)	swraid_used,
					SUM(a.swraid_free	)	swraid_free,
					SUM(a.disk_backup_rawsize)	disk_backup_rawsize,
					SUM(a.disk_backup_size)		disk_backup_size,
					SUM(a.disk_backup_used)		disk_backup_used,
					SUM(a.disk_backup_free)		disk_backup_free,
					SUM(a.disk_rawsize	)	disk_rawsize,
					SUM(a.disk_size	)		disk_size,
					SUM(a.disk_used	)		disk_used,
					SUM(a.disk_free	)		disk_free,
					SUM(a.rawsize		)	rawsize,
					SUM(a.sizeb		)	sizeb,
					SUM(a.used		)	used,
					SUM(a.free		)	free,
					SUM(a.vendor_emc_size	)	vendor_emc_size,
					SUM(a.vendor_emc_rawsize)	vendor_emc_rawsize,
					SUM(a.vendor_sun_size	)	vendor_sun_size,
					SUM(a.vendor_sun_rawsize)	vendor_sun_rawsize,
					SUM(a.vendor_hp_size	)	vendor_hp_size,
					SUM(a.vendor_hp_rawsize)	vendor_hp_rawsize,
					SUM(a.vendor_hitachi_size)	vendor_hitachi_size,
					SUM(a.vendor_hitachi_rawsize)	vendor_hitachi_rawsize,
					SUM(a.vendor_others_size)	vendor_others_size,
					SUM(a.vendor_others_rawsize)	vendor_others_rawsize,
					SUM(a.vendor_nfs_netapp_size)	vendor_nfs_netapp_size,
					SUM(a.vendor_nfs_emc_size)	vendor_nfs_emc_size,
					SUM(a.vendor_nfs_sun_size)	vendor_nfs_sun_size,
					SUM(a.vendor_nfs_others_size)	vendor_nfs_others_size';

PROCEDURE print_line(
   p_attrib   	 in VARCHAR2,
   p_cellspacing in NUMBER DEFAULT 0,
   p_cellpadding in NUMBER DEFAULT 1,
   p_height	 in NUMBER DEFAULT 3
)  
IS

BEGIN

	PRINT_PTABLE_OPEN(p_cellspacing,p_cellpadding);       

        HTP.tablerowopen;

	HTP.tabledata(cnowrap     => '',
                     cattributes => ' align=left'||
				    ' height='|| p_height ||' '||
				     p_attrib);

        HTP.tablerowclose;

	HTP.P('</TABLE>');

END print_line;     

BEGIN

	GETTIME(l_time);
	l_elapsed_time := l_time;				

	PRINTN(' IN classical_drill_down');
	---------------------------------------------------------------
	-- QUERY BUILDER
	---------------------------------------------------------------
	-- NAME/TYPE	DEFAULT		DRILLDOWN		Group query		default query 		drill down
	-- =/GROUP	Same level	DRILL_DOWN_TYPE='HOSTS'	name=,type=		name=,type=		( SELECT target_id FROM stormon_host_groups )
	-- LIKE/Group	Same level	DRILL_DOWN_TYPE='HOSTS'	name like , type =	name like, type=	( SELECT target_id FROM stormon_host_groups )
	-- =/HOST	HOST DETAIL 	-			name = , type =		name=,type =		-
	-- LIKE/Host	Same Level	-			name like type =	nmae like, type=	-

	-- The report title

	-- Get the group type title depending on drill down requested
	IF p_type = 'REPORTING_DATACENTER' THEN
		l_group_type_title := 'Data Center';
	ELSIF p_type = 'REPORTING_LOB' THEN
		l_group_type_title := 'Line of Business';
	ELSIF p_type = 'REPORTING_CUSTOMER' THEN
		l_group_type_title := 'Customer';
	ELSIF p_type = 'HOST' THEN
		l_group_type_title := 'Host';	
	ELSE
		l_group_type_title := 'Group';
	END IF;

	-- Main tab
	IF p_main_tab = 'MAIN_TAB_HOSTLOOKUP' THEN
		l_report_title := l_group_type_title;		
	ELSIF p_main_tab = 'MAIN_TAB_DATACENTER' THEN
		l_report_title := 'Data Center';		
	ELSIF p_main_tab = 'MAIN_TAB_LOB' THEN
		l_report_title := 'Line of Business';
	ELSE
		l_report_title := 'Customer';	
	END IF;
		
	IF p_name IS NOT NULL THEN

		l_report_title := l_report_title||' : '||p_name;

		-- Sub tab
		IF p_sub_tab = 'SUMMARY' THEN		
			l_report_title := 'Storage Summary for '||l_report_title;		
		ELSIF p_sub_tab = 'GROUP_DETAILS' THEN
			l_report_title :=  l_group_type_title||' Details for '||l_report_title;
		ELSE
			l_report_title := 'Host Details for '||l_report_title;
		END IF;

	ELSE

		IF p_main_tab = 'MAIN_TAB_HOSTLOOKUP' THEN
	
			l_report_title := 'Look Up Storage Report ';

		ELSE
			l_report_title := 'Storage Report for '||l_report_title;

		END IF;
		
	END IF;

	---------------------------------------------------------------------------------------------------------------
	-- List of reporting objects to be spitted out in this order, based on the type of the report arguments
	---------------------------------------------------------------------------------------------------------------
	l_summary_report_object := 	report_object (
							'SUMMARY',
							'Summary',
							'Summary',
							display_object_table (
								l_row_open_object,
								l_column_open_object,
									l_navigation_link_object,
								l_column_close_object,
								l_row_close_object,
							
								l_row_open_object,
								l_column_open_object,
								display_object(NULL,'Storage Summary',c_display_type_section_open,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
									l_column_50_open_object,
										l_host_usage_summary_table,
									l_column_close_object,
									l_column_50_open_object,	
										display_object(NULL,'History',c_display_type_subsection_open,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
											l_column_open_object,
												l_history_graph,
											l_column_close_object,
										display_object(NULL,NULL,c_display_type_ssection_close,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
									l_column_close_object,
								display_object(NULL,NULL,c_display_type_section_close,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
								l_column_close_object,
								l_row_close_object,
							
								l_row_open_object,
								l_column_open_object,
								display_object(NULL,'Free Storage',c_display_type_section_open,NULL,NULL,NULL,'Free storage Distribution',NULL,NULL,NULL,NULL,NULL),
									l_column_50_open_object,
										l_free_storage_table,
									l_column_close_object,	
									l_column_50_open_object,
										display_object(NULL,'Free Storage Distribution',c_display_type_subsection_open,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
											l_column_open_object,
												l_chart_where_free,
											l_column_close_object,
										display_object(NULL,NULL,c_display_type_ssection_close,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
									l_column_close_object,
								display_object(NULL,NULL,c_display_type_section_close,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
								l_column_close_object,
								l_row_close_object,
							
								l_row_open_object,
								l_column_open_object,
								display_object(NULL,'Storage Summary by Vendor',c_display_type_section_open,NULL,NULL,NULL,'Storage Summary by Vendor',NULL,NULL,NULL,NULL,NULL),
									l_column_50_open_object,
										l_vendor_table,
									l_column_close_object,
									l_column_50_open_object,
										display_object(NULL,'Vendor Distribution',c_display_type_subsection_open,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
											l_column_open_object,
												l_chart_vendor,
											l_column_close_object,
										display_object(NULL,NULL,c_display_type_ssection_close,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
									l_column_close_object,
								display_object(NULL,NULL,c_display_type_section_close,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
								l_column_close_object,
								l_row_close_object
								),
								'javascript:link_change_display('''||p_main_tab||''','''||p_search_name||''','''||p_name||''','''||p_type||''','''||p_chart_type||''','''||p_drill_down_group_type||''','''||'SUMMARY'||''','''||p_host_type||''','''','''',''top'');'
							);


	l_host_details_report_object :=	report_object (
								'HOST_DETAILS',
								'Host Details',
								'Host Details',
								display_object_table (
									l_row_open_object,
									l_column_open_object,
										l_navigation_link_object,
									l_column_close_object,
									l_row_close_object,
							
									l_row_open_object,
									l_column_open_object,
									display_object(NULL,'Storage by Host',c_display_type_section_open,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
										l_column_open_object,	
											display_object(NULL,'Host Distribution',c_display_type_subsection_open,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
												l_column_50_open_object,
													l_chart_used_free,
												l_column_close_object,
												l_column_50_open_object,
													l_chart_top_n_used,
												l_column_close_object,
												l_column_open_object,
													l_chart_top_n_free,
												l_column_close_object,
											display_object(NULL,NULL,c_display_type_ssection_close,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
										l_column_close_object,
										l_row_object,
											l_column_open_object,	
												l_host_usage_table,
											l_column_close_object,
										l_row_object,
											l_column_open_object,	
												l_host_vendor_table,
											l_column_close_object,
									display_object(NULL,NULL,c_display_type_section_close,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
									l_column_close_object,
									l_row_close_object
								),
								'javascript:link_change_display('''||p_main_tab||''','''||p_search_name||''','''||p_name||''','''||p_type||''','''||p_chart_type||''','''||p_drill_down_group_type||''','''||'HOST_DETAILS'||''','''||p_host_type||''','''','''',''top'');'
							);


	l_group_details_report_object := report_object (
								'GROUP_DETAILS',
								l_group_type_title||' Details',
								l_group_type_title||' Details',
								display_object_table (
									l_row_open_object,
									l_column_open_object,
										l_navigation_link_object,
									l_column_close_object,
									l_row_close_object,
							
									l_row_open_object,
									l_column_open_object,
									display_object(NULL,'Storage by '||l_group_type_title,c_display_type_section_open,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
										l_column_open_object,
											display_object(NULL,l_group_type_title||' Distribution',c_display_type_subsection_open,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
												l_column_50_open_object,
													l_chart_used_free,
												l_column_close_object,
												l_column_open_object,
													l_chart_by_used,
												l_column_close_object,
											display_object(NULL,NULL,c_display_type_ssection_close,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
										l_column_close_object,
										l_row_object,
											l_column_open_object,
												l_group_usage_table,
											l_column_close_object,
										display_object(NULL,NULL,c_display_type_section_close,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
									l_column_close_object,
									l_row_close_object
								),
								'javascript:link_change_display('''||p_main_tab||''','''||p_search_name||''','''||p_name||''','''||p_type||''','''||p_chart_type||''','''||p_drill_down_group_type||''','''||'GROUP_DETAILS'||''','''||p_host_type||''','''','''',''top'');'
							);
	l_report_objects := report_object_table(l_summary_report_object,l_group_details_report_object,l_host_details_report_object);
	
	l_list_of_main_tabs :=  tab_object_table
				(
					tab_object(
							'Data Center',
							'MAIN_TAB_DATACENTER',
							'javascript:link_change_display(''MAIN_TAB_DATACENTER'',''FALSE'',''ALL'',''REPORTING_DATACENTER'',''PIE'',''REPORTING_DATACENTER'',''SUMMARY'',''ALL_HOSTS'','''','''',''top'');',
							'ENABLE',
							display_object_table(
								l_outer_table_object,
									l_row_open_object,
									l_column_open_object,
										display_object(NULL,NULL,c_display_type_main_tabs,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
									l_column_close_object,
									l_row_close_object,
									l_row_open_object,
									l_column_open_object,
										display_object(NULL,NULL,c_display_type_sub_tabs,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
									l_column_close_object,
									l_row_close_object,
									l_row_open_object,
									l_column_open_object,
										display_object(NULL,l_report_title,c_display_type_report_title,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
									l_column_close_object,
									l_row_close_object,
									l_row_open_object,
									l_column_open_object,
										display_object(NULL,'Data Center',c_display_type_combo_box,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
									l_column_close_object,
									l_row_close_object
								),
							l_report_objects,
							display_object_table(
								l_table_close_object
							)),
					tab_object(
							'Line of Business',
							'MAIN_TAB_LOB',
							'javascript:link_change_display(''MAIN_TAB_LOB'',''FALSE'',''ALL'',''REPORTING_LOB'',''PIE'',''REPORTING_LOB'',''SUMMARY'',''ALL_HOSTS'','''','''',''top'');',
							'ENABLE',
							display_object_table(
								l_outer_table_object,
									l_row_open_object,
									l_column_open_object,
										display_object(NULL,NULL,c_display_type_main_tabs,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
									l_column_close_object,
									l_row_close_object,
									l_row_open_object,
									l_column_open_object,
										display_object(NULL,NULL,c_display_type_sub_tabs,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
									l_column_close_object,
									l_row_close_object,
									l_row_open_object,
									l_column_open_object,
										display_object(NULL,l_report_title,c_display_type_report_title,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
									l_column_close_object,
									l_row_close_object,									
									l_row_open_object,
									l_column_open_object,
										display_object(NULL,'Line of Business',c_display_type_combo_box,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
									l_column_close_object,
									l_row_close_object
								),
							l_report_objects,
							display_object_table(
								l_table_close_object
							)),
					tab_object(
							'Customer',
							'MAIN_TAB_CUSTOMER',
							'javascript:link_change_display(''MAIN_TAB_CUSTOMER'',''FALSE'',''ALL'',''REPORTING_CUSTOMER'',''PIE'',''REPORTING_CUSTOMER'',''SUMMARY'',''ALL_HOSTS'','''','''',''top'');',
							'ENABLE',
							display_object_table(
								l_outer_table_object,
									l_row_open_object,
									l_column_open_object,
										display_object(NULL,NULL,c_display_type_main_tabs,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
									l_column_close_object,
									l_row_close_object,
									l_row_open_object,
									l_column_open_object,
										display_object(NULL,NULL,c_display_type_sub_tabs,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
									l_column_close_object,
									l_row_close_object,
									l_row_open_object,
									l_column_open_object,
										display_object(NULL,l_report_title,c_display_type_report_title,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
									l_column_close_object,
									l_row_close_object,									
									l_row_open_object,
									l_column_open_object,
										display_object(NULL,'Customer',c_display_type_combo_box,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
									l_column_close_object,
									l_row_close_object
								),
							l_report_objects,
							display_object_table(
								l_table_close_object
							)),
					tab_object(
							'Host Search',
							'MAIN_TAB_HOSTLOOKUP',
							'javascript:link_change_display(''MAIN_TAB_HOSTLOOKUP'',''TRUE'','''',''HOST'',''PIE'',''HOST'',''SUMMARY'',''ALL_HOSTS'','''','''',''top'');',
							'ENABLE',
							display_object_table(
								l_outer_table_object,
									l_row_open_object,
									l_column_open_object,
										display_object(NULL,NULL,c_display_type_main_tabs,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
									l_column_close_object,
									l_row_close_object,
									l_row_open_object,
									l_column_open_object,
										display_object(NULL,NULL,c_display_type_sub_tabs,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
									l_column_close_object,
									l_row_close_object,
									l_row_open_object,
									l_column_open_object,
										display_object(NULL,l_report_title,c_display_type_report_title,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
									l_column_close_object,
									l_row_close_object,									
									l_row_open_object,
									l_column_open_object,
										display_object(NULL,'Search',c_display_type_search_box,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
									l_column_close_object,
									l_row_close_object
							),
							l_report_objects,
							display_object_table(
								l_table_close_object
							)),
					tab_object(
							'GIT Reports',
							'MAIN_TAB_GIT_REPORTS',
							NULL,
							'DISABLE',
							NULL,
							NULL,
							NULL)	
				);

--	PRINTN(' display objects Initialized');

/*
	CASE
		-- Its a HOST drill down or Host Type report
		WHEN p_drill_down_type = 'HOSTS' OR p_type = 'HOST' THEN
			
			-- Summary Object
			-- Host detail report

		ELSE

			IF l_all_summaries IS NULL OR NOT l_all_summaries.EXISTS(1) THEN

			-- Summary only

			ELSIF	l_id_count = 1 AND 
				l_group_id IS NOT NULL AND				
				l_all_summaries.COUNT = 1 AND 
				l_group_id = l_all_summaries(1).id THEN
						
				-- SUmmary only


			ELSE

				-- Summary
				-- Detail

			END IF;
	END CASE;
*/


-- Loop thru the main tabs, sub tabs and display object lists and print them

	IF l_list_of_main_tabs IS NULL OR NOT l_list_of_main_tabs.EXISTS(1) THEN
			RETURN;
	END IF;

	FOR g IN l_list_of_main_tabs.FIRST..l_list_of_main_tabs.LAST LOOP
	
		-- Display main tab contents only the main tab type is requested
		IF l_list_of_main_tabs(g).main_tab != p_main_tab THEN
			GOTO next_main_tab;
		END IF;	

		-- display the main tab start Objects
		IF l_list_of_main_tabs(g).start_display_object_list IS NOT NULL AND l_list_of_main_tabs(g).start_display_object_list.EXISTS(1) THEN

			FOR q IN l_list_of_main_tabs(g).start_display_object_list.FIRST..l_list_of_main_tabs(g).start_display_object_list.LAST LOOP
				
				PRINT_DISPLAY_OBJECT(	
						p_portlet_record ,
						p_main_tab,
						p_search_name,
						p_name,
						p_type,
						p_chart_type,
						p_drill_down_group_type,
						p_sub_tab, 
						p_host_type,	 
						p_orderfield, 
						p_ordertype,
						p_display_object_type,
						l_list_of_main_tabs(g).start_display_object_list(q),			
						l_list_of_main_tabs(g).start_display_object_list,						
						NULL,	
						l_list_of_main_tabs(g),						
						l_list_of_main_tabs(g).sub_tabs,
						l_list_of_main_tabs,
						NULL);
			END LOOP;		

		END IF;
			
		-- If no query valus is passed then return at this point, no other objects to render.
		IF p_name IS NULL THEN
			GOTO print_end_display_objects;
		END IF;

		IF l_list_of_main_tabs(g).sub_tabs IS NULL OR NOT l_list_of_main_tabs(g).sub_tabs.EXISTS(1) THEN

			GOTO print_end_display_objects;

		END IF;

		------------------------------------------------------------------------------------------
		-- BUILD THE QUERY CONDITIONS HERE
		------------------------------------------------------------------------------------------
		-- Set the group type for query
		IF p_name = 'ALL'AND p_main_tab IN ('MAIN_TAB_DATACENTER','MAIN_TAB_LOB','MAIN_TAB_CUSTOMER') THEN
			l_group_type := 'REPORTING_ALL';
		ELSE	
			l_group_type := p_type;	
		END IF;

		-- if the query is a search query in the quick host loookup tab build a search predicate

		IF p_main_tab = 'MAIN_TAB_HOSTLOOKUP' AND p_search_name = 'TRUE' THEN

			DECLARE			
				l_arguments_list	stringTable;
			BEGIN
	
				l_arguments_list := STORAGE.PARSE_ARGUMENTS(TRIM(REPLACE(p_name,'*','%')),',');

				IF l_arguments_list IS NOT NULL AND l_arguments_list.EXISTS(1) THEN

					FOR i IN l_arguments_list.FIRST..l_arguments_list.LAST LOOP
			
						IF l_name IS NULL THEN

							l_name := '  LOWER(a.name) LIKE ''%'||TRIM(LOWER(l_arguments_list(i)))||'%'' ';
						ELSE
							l_name := l_name||' OR LOWER(a.name) LIKE ''%'||TRIM(LOWER(l_arguments_list(i)))||'%'' ';		
				
						END IF;

					END LOOP;

					l_name := '( '||l_name||' ) ';

				END IF;
			END;

		ELSE

			-- set the name predicate
			IF p_name = 'ALL' THEN
				l_name := ' 1 = 1 ';		
			ELSE
				l_name := ' UPPER(a.name) = UPPER('''||p_name||''')';
			END IF;	
		
		END IF;
	
		-- Default predicate for the input arguments
		l_predicate := ' 	FROM	storage_summaryObject_view a
					WHERE	a.type = '''||l_group_type||'''
					AND	'||l_name;
	

		-- List of target ids for the input arguments
		IF p_type = 'HOST' THEN

			l_list_of_targets_predicate := 'SELECT   /*+ DRIVING_SITE(a)*/ target_id id	
							FROM    mgmt_targets_view a     						
							WHERE   '||REPLACE(l_name,'(a.name)','(a.target_name)');   
		ELSE

			l_list_of_targets_predicate := 'SELECT   /*+ DRIVING_SITE(a)*/ b.target_id id	
							FROM    stormon_host_groups b,
        							stormon_group_table a
							WHERE   b.group_id = a.id	
							AND     a.type = '''||l_group_type||'''
							AND     '||l_name;
		END IF;


		l_host_details_predicate := ' FROM	storage_summaryObject_view a,
							('||l_list_of_targets_predicate||'
							) b
						WHERE	a.id = b.id';


		-- Predicate to compute group summary for the input arguments from all targets
		--SELECT	a.id , a.host_count
		--FROM	stormon_group_table a 
		--WHERE	type = 'SHARED_GROUP' 
		--AND NOT EXISTS 
		--( 
		--	SELECT	1 
		--	FROM	(
		--		SELECT	target_id
		--		FROM	mgmt_targets_view 
		--		MINUS
		--		SELECT	target_id
		--		FROM	mgmt_targets_view
		--		WHERE	LOWER(target_name) LIKE '%gitmon%'				
		--		) c,
		--		stormon_host_groups b 
		--	WHERE	b.group_id = a.id
		--	AND	b.target_id = c.target_id
		--)

		l_group_summary_predicate := 	'	FROM	storage_summaryObject_view a,		
							('||	l_list_of_targets_predicate||'							     
								UNION	
								SELECT   /*+ DRIVING_SITE(a)*/ a.id
								FROM    stormon_group_table a
								WHERE   type = ''SHARED_GROUP''	
								AND     NOT EXISTS
		        					(	
							                SELECT   /*+ DRIVING_SITE(b)*/ 1
        							        FROM    (
											SELECT	 /*+ DRIVING_SITE(a)*/ target_id		
											FROM	mgmt_targets_view a
											MINUS
											'||l_list_of_targets_predicate||'
										) c,
										stormon_host_groups b
				        			        WHERE   b.group_id = a.id
		        			       			AND     b.target_id = c.target_id								
								)					        	
							) b	
							WHERE	a.id = b.id
							AND	a.summaryFlag = ''Y''';


		
		-- Have a group details only if there is a drill down to another group possible
		IF p_main_tab = 'MAIN_TAB_HOSTLOOKUP' AND p_search_name = 'TRUE' THEN

			l_list_of_c_groups_predicate := '		SELECT	 /*+ DRIVING_SITE(a)*/ a.id child_id
									FROM	stormon_group_table a									
									WHERE	a.type = '''||l_group_type||'''
									AND	'||l_name;
		ELSE
		
			l_list_of_c_groups_predicate := '		SELECT	 /*+ DRIVING_SITE(a)*/ DISTINCT b.child_id child_id
									FROM	stormon_group_of_groups_table b,
										stormon_group_table p,
										stormon_group_table a
									WHERE	b.parent_id = p.id
									AND	b.child_id = a.id
									AND	a.type = '''||p_drill_down_group_type||'''
									AND	p.type = '''||l_group_type||'''
									AND	'||l_name;
		END IF;

	
		l_group_details_predicate := ' FROM	storage_summaryObject_view a,
								('||l_list_of_c_groups_predicate||'
								) b
							WHERE	a.id = b.child_id ';	

		-----------------------------------------------------------
		-- predicate for fetching hosts with issues or all hosts
		-----------------------------------------------------------
		IF	p_host_type = 'ALL_HOSTS' THEN
			l_host_predicate := NULL;
		ELSIF	p_host_type = 'SUMMARIZED_HOSTS' THEN
			l_host_predicate := ' a.summaryFlag = ''Y'' ';
		ELSIF	p_host_type = 'FAILED_HOSTS' THEN
			l_host_predicate := ' a.summaryFlag IN (''I'',''N'') ';
		ELSIF	p_host_type = 'ISSUE_HOSTS' THEN
			l_host_predicate := ' a.summaryFlag = ''I'' ';
		ELSIF	p_host_type = 'NOT_COLLECTED_HOSTS' THEN
			l_host_predicate := ' a.summaryFlag = ''N'' ';
		ELSIF	p_host_type = 'WARNING_HOSTS' THEN
			l_host_predicate := ' a.warnings > 0 ';	
		ELSE
			l_host_predicate := NULL;
		END IF;	

		IF l_host_predicate IS NOT NULL THEN
	
			l_host_details_predicate:=	l_host_details_predicate||' AND '||l_host_predicate;

		END IF;	

	
		STORAGE.GETTIME(l_time,'Time for Initializing Configuration');

		-------------------------------------------------------------------------------------------
		-- Get the group id based on the parent type , parent name
		--------------------------------------------------------------------------------------------
		BEGIN
	
			--
			-- Get the count of all ids for the predicates
			-- Cannot do a bulk fetch of remote objects for dynamic sql, Gives ORA-1019 error,unable to allocate memory.
			--			
			PRINTN('
			SELECT	 /*+ DRIVING_SITE(a)*/ COUNT(*)'
			||l_predicate	);

			EXECUTE IMMEDIATE '
			SELECT	 /*+ DRIVING_SITE(a)*/ COUNT(*)'
			||l_predicate	
			INTO l_id_count;							
			
			STORAGE.PRINTN('Details in ths group = '||l_id_count);

			-- If only one id is available , save the group id , the report is a single id report.
			IF l_id_count = 1 THEN

				PRINTN('
				SELECT	 /*+ DRIVING_SITE(a)*/ id
				FROM	(
						SELECT	 /*+ DRIVING_SITE(a)*/ a.id
						'||l_predicate||'
					) a
				WHERE	ROWNUM = 1');

				-- Get all the ids for the predicates
				EXECUTE IMMEDIATE '
				SELECT	 /*+ DRIVING_SITE(a)*/ id
				FROM	(
						SELECT	 /*+ DRIVING_SITE(a)*/ a.id
						'||l_predicate||'
					) a
				WHERE	ROWNUM = 1'
				INTO l_group_id;	
				
			END IF;

		EXCEPTION

			WHEN OTHERS THEN
				PRINTN(SQLERRM);
				RAISE;
		END;

		STORAGE.GETTIME(l_time,'Time to Check for group id');

		---------------------------------------------------
		--	If this is a host quick lookup report and
		--	search returns only one host, print the
		-- 	host detail report
		---------------------------------------------------
		IF	p_main_tab = 'MAIN_TAB_HOSTLOOKUP' AND
			p_sub_tab = 'HOST_DETAILS' AND
			p_type = 'HOST' AND
			l_id_count = 1 AND
			l_group_id IS NOT NULL
		THEN
			STORAGE.SINGLE_HOST_REPORT(
				p_portlet_record,
				p_main_tab,
				p_search_name,
				l_group_id,	-- The name at for this function contains the host id
				p_type,
				p_chart_type,
				p_drill_down_group_type,
				p_sub_tab,
				p_host_type,
				p_orderfield,
				p_ordertype,
				p_display_object_type );
			RETURN;
		END IF;

		---------------------------------------------------------
		--	Get the group summary or calculate one
		---------------------------------------------------------
		IF l_group_id IS NOT NULL THEN
	
			BEGIN
			
				PRINTN(l_summary_fields||' FROM  storage_summaryObject_view a WHERE a.id = '''||l_group_id||'''');
				-- The summary Row
				EXECUTE IMMEDIATE l_summary_fields||' FROM  storage_summaryObject_view a WHERE a.id = '''||l_group_id||'''' INTO 					
					l_summary.name,
					l_summary.id,
					l_summary.type,
					l_summary.timestamp,
					l_summary.collection_timestamp,
					l_summary.hostcount,
					l_summary.actual_targets,
					l_summary.issues,
					l_summary.warnings,
					l_summary.summaryflag,
					l_summary.application_rawsize,
					l_summary.application_size,
					l_summary.application_used,
					l_summary.application_free,
					l_summary.oracle_database_rawsize,
					l_summary.oracle_database_size,
					l_summary.oracle_database_used,
					l_summary.oracle_database_free,
					l_summary.local_filesystem_rawsize,
					l_summary.local_filesystem_size,
					l_summary.local_filesystem_used,
					l_summary.local_filesystem_free,
					l_summary.nfs_exclusive_size,
					l_summary.nfs_exclusive_used,
					l_summary.nfs_exclusive_free,
					l_summary.nfs_shared_size,
					l_summary.nfs_shared_used,
					l_summary.nfs_shared_free,
					l_summary.volumemanager_rawsize,
					l_summary.volumemanager_size,
					l_summary.volumemanager_used,
					l_summary.volumemanager_free,
					l_summary.swraid_rawsize,
					l_summary.swraid_size,
					l_summary.swraid_used,
					l_summary.swraid_free,
					l_summary.disk_backup_rawsize,
					l_summary.disk_backup_size,
					l_summary.disk_backup_used,
					l_summary.disk_backup_free,
					l_summary.disk_rawsize,
					l_summary.disk_size,
					l_summary.disk_used,
					l_summary.disk_free,
					l_summary.rawsize,
					l_summary.sizeb,
					l_summary.used,
					l_summary.free,
					l_summary.vendor_emc_size,
					l_summary.vendor_emc_rawsize,
					l_summary.vendor_sun_size,
					l_summary.vendor_sun_rawsize,
					l_summary.vendor_hp_size,
					l_summary.vendor_hp_rawsize,
					l_summary.vendor_hitachi_size,
					l_summary.vendor_hitachi_rawsize,
					l_summary.vendor_others_size,
					l_summary.vendor_others_rawsize,
					l_summary.vendor_nfs_netapp_size,
					l_summary.vendor_nfs_emc_size,
					l_summary.vendor_nfs_sun_size,
					l_summary.vendor_nfs_others_size;

			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					NULL;
			END;

		ELSE
			PRINTN(l_summary_fields||'
				FROM	(
					'||l_group_summary_fields||' '||l_group_summary_predicate||'				
					) a ');

			EXECUTE IMMEDIATE l_summary_fields||'
				FROM	(
					'||l_group_summary_fields||' '||l_group_summary_predicate||'				
					) a'
			INTO
					l_summary.name,
					l_summary.id,
					l_summary.type,
					l_summary.timestamp,
					l_summary.collection_timestamp,
					l_summary.hostcount,
					l_summary.actual_targets,
					l_summary.issues,
					l_summary.warnings,
					l_summary.summaryflag,
					l_summary.application_rawsize,
					l_summary.application_size,
					l_summary.application_used,
					l_summary.application_free,
					l_summary.oracle_database_rawsize,
					l_summary.oracle_database_size,
					l_summary.oracle_database_used,
					l_summary.oracle_database_free,
					l_summary.local_filesystem_rawsize,
					l_summary.local_filesystem_size,
					l_summary.local_filesystem_used,
					l_summary.local_filesystem_free,
					l_summary.nfs_exclusive_size,
					l_summary.nfs_exclusive_used,
					l_summary.nfs_exclusive_free,
					l_summary.nfs_shared_size,
					l_summary.nfs_shared_used,
					l_summary.nfs_shared_free,
					l_summary.volumemanager_rawsize,
					l_summary.volumemanager_size,
					l_summary.volumemanager_used,
					l_summary.volumemanager_free,
					l_summary.swraid_rawsize,
					l_summary.swraid_size,
					l_summary.swraid_used,
					l_summary.swraid_free,
					l_summary.disk_backup_rawsize,
					l_summary.disk_backup_size,
					l_summary.disk_backup_used,
					l_summary.disk_backup_free,
					l_summary.disk_rawsize,
					l_summary.disk_size,
					l_summary.disk_used,
					l_summary.disk_free,
					l_summary.rawsize,
					l_summary.sizeb,
					l_summary.used,
					l_summary.free,
					l_summary.vendor_emc_size,
					l_summary.vendor_emc_rawsize,
					l_summary.vendor_sun_size,
					l_summary.vendor_sun_rawsize,
					l_summary.vendor_hp_size,
					l_summary.vendor_hp_rawsize,
					l_summary.vendor_hitachi_size,
					l_summary.vendor_hitachi_rawsize,
					l_summary.vendor_others_size,
					l_summary.vendor_others_rawsize,
					l_summary.vendor_nfs_netapp_size,
					l_summary.vendor_nfs_emc_size,
					l_summary.vendor_nfs_sun_size,
					l_summary.vendor_nfs_others_size;
				
			-- I am setting this so the != l_group_id check doest fail, else we have to NVL l_group_id in the != checks
			l_summary.id := '-1';
			l_group_id := '-1';			
		END IF;

		l_summary.name := 'TOTAL';
	
		STORAGE.GETTIME(l_time,'Time to Fetch group summary');

		PRINTN( 'Group summary obtained ');

		---------------------------------------------------
		-- To be designed, different order for each table
		-- BUILD THE ORDER BY CLAUSE FOR THE QUERY
		---------------------------------------------------
        	IF p_orderfield IS NOT NULL AND l_list_of_summary_columns.EXISTS(p_orderfield) THEN
	
                	l_orderList := NVL(l_list_of_summary_columns(p_orderfield).order_clause,' sizeb ');

	                IF p_ordertype IN ('DESC','ASC') THEN
        	                l_orderList := l_orderList||' '||p_ordertype;
                	ELSE
                        	l_orderList := l_orderList||' '||l_list_of_summary_columns(p_orderfield).order_type;
	                END IF;
        
        	END IF;


		-- Loop and display the report from each report object
		FOR h IN l_list_of_main_tabs(g).sub_tabs.FIRST..l_list_of_main_tabs(g).sub_tabs.LAST LOOP
		
			IF l_list_of_main_tabs(g).sub_tabs(h) IS NULL THEN
				GOTO next_sub_tab;
			END IF;

			IF l_list_of_main_tabs(g).sub_tabs(h).display_object_list IS NULL OR NOT l_list_of_main_tabs(g).sub_tabs(h).display_object_list.EXISTS(1) THEN
				GOTO next_sub_tab;
			END IF;
		
			-- Display only the report type requested
			IF l_list_of_main_tabs(g).sub_tabs(h).report_type != p_sub_tab THEN
				GOTO next_sub_tab;
			END IF;	

			-------------------------------------------------------------------------------------
			--	Fetch all the summaries at the same level for the types to be reported
			--
			--	DOing a direct bulk collect thru dynamic sql, execute immediate gives a 
			-- 	1019 oracle error
			-- 	SO I am using cursors here, works fine with dynamic sql on db links
			-------------------------------------------------------------------------------------
			BEGIN

				IF l_list_of_main_tabs(g).sub_tabs(h).report_type = 'HOST_DETAILS' THEN
		
					PRINTN(l_summary_fields||' '||l_host_details_predicate||' ORDER BY '||l_orderList);
	
					OPEN l_cursor FOR l_summary_fields||' '||l_host_details_predicate||' ORDER BY '||l_orderList;

				ELSIF l_list_of_main_tabs(g).sub_tabs(h).report_type = 'GROUP_DETAILS' THEN

					PRINTN(l_summary_fields||' '||l_group_details_predicate||' ORDER BY '||l_orderList);
	
					OPEN l_cursor FOR l_summary_fields||' '||l_group_details_predicate||' ORDER BY '||l_orderList;
				
				END IF;

				IF l_cursor%ISOPEN THEN
		
					FETCH l_cursor BULK COLLECT
					INTO 
					l_all_summaries.name,
					l_all_summaries.id,
					l_all_summaries.type,
					l_all_summaries.timestamp,
					l_all_summaries.collection_timestamp,
					l_all_summaries.hostcount,
					l_all_summaries.actual_targets,
					l_all_summaries.issues,
					l_all_summaries.warnings,
					l_all_summaries.summaryflag,
					l_all_summaries.application_rawsize,
					l_all_summaries.application_size,
					l_all_summaries.application_used,
					l_all_summaries.application_free,
					l_all_summaries.oracle_database_rawsize,
					l_all_summaries.oracle_database_size,
					l_all_summaries.oracle_database_used,
					l_all_summaries.oracle_database_free,
					l_all_summaries.local_filesystem_rawsize,
					l_all_summaries.local_filesystem_size,
					l_all_summaries.local_filesystem_used,
					l_all_summaries.local_filesystem_free,
					l_all_summaries.nfs_exclusive_size,
					l_all_summaries.nfs_exclusive_used,
					l_all_summaries.nfs_exclusive_free,
					l_all_summaries.nfs_shared_size,
					l_all_summaries.nfs_shared_used,
					l_all_summaries.nfs_shared_free,
					l_all_summaries.volumemanager_rawsize,
					l_all_summaries.volumemanager_size,
					l_all_summaries.volumemanager_used,
					l_all_summaries.volumemanager_free,
					l_all_summaries.swraid_rawsize,
					l_all_summaries.swraid_size,
					l_all_summaries.swraid_used,
					l_all_summaries.swraid_free,
					l_all_summaries.disk_backup_rawsize,
					l_all_summaries.disk_backup_size,
					l_all_summaries.disk_backup_used,
					l_all_summaries.disk_backup_free,
					l_all_summaries.disk_rawsize,
					l_all_summaries.disk_size,
					l_all_summaries.disk_used,
					l_all_summaries.disk_free,
					l_all_summaries.rawsize,
					l_all_summaries.sizeb,
					l_all_summaries.used,
					l_all_summaries.free,
					l_all_summaries.vendor_emc_size,
					l_all_summaries.vendor_emc_rawsize,
					l_all_summaries.vendor_sun_size,
					l_all_summaries.vendor_sun_rawsize,
					l_all_summaries.vendor_hp_size,
					l_all_summaries.vendor_hp_rawsize,
					l_all_summaries.vendor_hitachi_size,
					l_all_summaries.vendor_hitachi_rawsize,
					l_all_summaries.vendor_others_size,
					l_all_summaries.vendor_others_rawsize,
					l_all_summaries.vendor_nfs_netapp_size,
					l_all_summaries.vendor_nfs_emc_size,
					l_all_summaries.vendor_nfs_sun_size,
					l_all_summaries.vendor_nfs_others_size;
		
					CLOSE l_cursor;					

				ELSE
					STORAGE.PRINTN('NO host or group details to be fetched, cursor failed to open ');
				END IF;

				STORAGE.GETTIME(l_time,'Time to Fetch child summaries');
				
			EXCEPTION
				WHEN OTHERS THEN

					IF l_cursor%ISOPEN THEN					
						CLOSE l_cursor;					
					END IF;

					STORAGE.PRINTN(' Failed while fetching the detail summaries '||SQLERRM);
					RAISE;			
			END;


	-----------------------------------------------------------------------------
	-- Inserting the fetched data into temporary tables for querying
	-----------------------------------------------------------------------------
	BEGIN

		DELETE FROM stormon_temp_results;
	
		IF l_summary.name IS NOT NULL THEN
	
			INSERT INTO stormon_temp_results
			VALUES(
				'SUMMARY',
				l_summary.name,
				l_summary.id,
				l_summary.type,
				l_summary.timestamp,
				l_summary.collection_timestamp,
				l_summary.hostcount,
				l_summary.actual_targets,
				l_summary.issues,
				l_summary.hostcount-(l_summary.actual_targets+l_summary.issues),		-- not collected,
				l_summary.warnings,
				l_summary.summaryflag,
				l_summary.application_rawsize,
				l_summary.application_size,
				l_summary.application_used,
				l_summary.application_free,
				l_summary.oracle_database_rawsize,
				l_summary.oracle_database_size,
				l_summary.oracle_database_used,
				l_summary.oracle_database_free,
				l_summary.local_filesystem_rawsize,
				l_summary.local_filesystem_size,
				l_summary.local_filesystem_used,
				l_summary.local_filesystem_free,
				l_summary.nfs_exclusive_size,
				l_summary.nfs_exclusive_used,
				l_summary.nfs_exclusive_free,
				l_summary.nfs_shared_size,
				l_summary.nfs_shared_used,
				l_summary.nfs_shared_free,
				l_summary.volumemanager_rawsize,
				l_summary.volumemanager_size,
				l_summary.volumemanager_used,
				l_summary.volumemanager_free,
				l_summary.swraid_rawsize,
				l_summary.swraid_size,
				l_summary.swraid_used,
				l_summary.swraid_free,
				l_summary.disk_backup_rawsize,
				l_summary.disk_backup_size,
				l_summary.disk_backup_used,
				l_summary.disk_backup_free,
				l_summary.disk_rawsize,
				l_summary.disk_size,
				l_summary.disk_used,
				l_summary.disk_free,
				l_summary.rawsize,
				l_summary.sizeb,
				l_summary.used,
				l_summary.free,
				l_summary.vendor_emc_size,
				l_summary.vendor_emc_rawsize,
				l_summary.vendor_sun_size,
				l_summary.vendor_sun_rawsize,
				l_summary.vendor_hp_size,
				l_summary.vendor_hp_rawsize,
				l_summary.vendor_hitachi_size,
				l_summary.vendor_hitachi_rawsize,
				l_summary.vendor_others_size,
				l_summary.vendor_others_rawsize,
				l_summary.vendor_nfs_netapp_size,
				l_summary.vendor_nfs_emc_size,
				l_summary.vendor_nfs_sun_size,
				l_summary.vendor_nfs_others_size);			
	
			END IF;
	
	
			IF l_all_summaries.name IS NOT NULL AND l_all_summaries.name.EXISTS(1) THEN
	
				FORALL i IN l_all_summaries.name.FIRST..l_all_summaries.name.LAST
					INSERT INTO stormon_temp_results
					VALUES(
					'DETAIL',
					l_all_summaries.name(i),
					l_all_summaries.id(i),
					l_all_summaries.type(i),
					l_all_summaries.timestamp(i),
					l_all_summaries.collection_timestamp(i),
					l_all_summaries.hostcount(i),
					l_all_summaries.actual_targets(i),
					l_all_summaries.issues(i),
					l_all_summaries.hostcount(i)-(l_all_summaries.actual_targets(i)+l_all_summaries.issues(i)),
					l_all_summaries.warnings(i),
					l_all_summaries.summaryflag(i),
					l_all_summaries.application_rawsize(i),
					l_all_summaries.application_size(i),
					l_all_summaries.application_used(i),
					l_all_summaries.application_free(i),
					l_all_summaries.oracle_database_rawsize(i),
					l_all_summaries.oracle_database_size(i),
					l_all_summaries.oracle_database_used(i),
					l_all_summaries.oracle_database_free(i),
					l_all_summaries.local_filesystem_rawsize(i),
					l_all_summaries.local_filesystem_size(i),
					l_all_summaries.local_filesystem_used(i),
					l_all_summaries.local_filesystem_free(i),
					l_all_summaries.nfs_exclusive_size(i),
					l_all_summaries.nfs_exclusive_used(i),
					l_all_summaries.nfs_exclusive_free(i),
					l_all_summaries.nfs_shared_size(i),
					l_all_summaries.nfs_shared_used(i),
					l_all_summaries.nfs_shared_free(i),
					l_all_summaries.volumemanager_rawsize(i),
					l_all_summaries.volumemanager_size(i),
					l_all_summaries.volumemanager_used(i),
					l_all_summaries.volumemanager_free(i),
					l_all_summaries.swraid_rawsize(i),
					l_all_summaries.swraid_size(i),
					l_all_summaries.swraid_used(i),
					l_all_summaries.swraid_free(i),
					l_all_summaries.disk_backup_rawsize(i),
					l_all_summaries.disk_backup_size(i),
					l_all_summaries.disk_backup_used(i),
					l_all_summaries.disk_backup_free(i),
					l_all_summaries.disk_rawsize(i),
					l_all_summaries.disk_size(i),
					l_all_summaries.disk_used(i),
					l_all_summaries.disk_free(i),
					l_all_summaries.rawsize(i),
					l_all_summaries.sizeb(i),
					l_all_summaries.used(i),
					l_all_summaries.free(i),
					l_all_summaries.vendor_emc_size(i),
					l_all_summaries.vendor_emc_rawsize(i),
					l_all_summaries.vendor_sun_size(i),
					l_all_summaries.vendor_sun_rawsize(i),
					l_all_summaries.vendor_hp_size(i),
					l_all_summaries.vendor_hp_rawsize(i),
					l_all_summaries.vendor_hitachi_size(i),
					l_all_summaries.vendor_hitachi_rawsize(i),
					l_all_summaries.vendor_others_size(i),
					l_all_summaries.vendor_others_rawsize(i),
					l_all_summaries.vendor_nfs_netapp_size(i),
					l_all_summaries.vendor_nfs_emc_size(i),
					l_all_summaries.vendor_nfs_sun_size(i),
					l_all_summaries.vendor_nfs_others_size(i));			
	
			END IF;

		EXCEPTION
			WHEN OTHERS THEN
				STORAGE.PRINTN('Error inserting results into stormon_temp_results');
				RAISE;	
		END;


		STORAGE.GETTIME(l_time,'Time taken to insert fetched data into temporary tables');

			
			FOR i IN l_list_of_main_tabs(g).sub_tabs(h).display_object_list.FIRST..l_list_of_main_tabs(g).sub_tabs(h).display_object_list.LAST LOOP

				IF l_list_of_main_tabs(g).sub_tabs(h).display_object_list(i) IS NULL THEN
					GOTO next_display_object;
				END IF;

				l_display_object := l_list_of_main_tabs(g).sub_tabs(h).display_object_list(i);

				IF l_display_object.display_type IS NULL THEN
	
					GOTO next_display_object;
			
				END IF;

				PRINT_DISPLAY_OBJECT(
					p_portlet_record ,
					p_main_tab,
					p_search_name,
					p_name,
					p_type,
					p_chart_type,
					p_drill_down_group_type,
					p_sub_tab, 
					p_host_type,	 
					p_orderfield, 
					p_ordertype,
					p_display_object_type,
					l_display_object,
					l_list_of_main_tabs(g).sub_tabs(h).display_object_list,
					l_list_of_main_tabs(g).sub_tabs(h),
					l_list_of_main_tabs(g),
					l_list_of_main_tabs(g).sub_tabs,
					l_list_of_main_tabs,
					l_summary);

			<<next_display_object>>
			NULL;
			-- STORAGE.GETTIME(l_time,'Rendering Object '||i);
			END LOOP;

		<<next_sub_tab>>
		NULL;
		--STORAGE.GETTIME(l_time,'Rendering report '||i);
		END LOOP;


		<< print_end_display_objects >>
		-- display the main tab end Objects
		IF l_list_of_main_tabs(g).end_display_object_list IS NOT NULL AND l_list_of_main_tabs(g).end_display_object_list.EXISTS(1) THEN

			FOR q IN l_list_of_main_tabs(g).end_display_object_list.FIRST..l_list_of_main_tabs(g).end_display_object_list.LAST LOOP
				
				PRINT_DISPLAY_OBJECT(	
						p_portlet_record ,
						p_main_tab,
						p_search_name,
						p_name,
						p_type,
						p_chart_type,
						p_drill_down_group_type,
						p_sub_tab, 
						p_host_type,	 
						p_orderfield, 
						p_ordertype,
						p_display_object_type,
						l_list_of_main_tabs(g).end_display_object_list(q),			
						l_list_of_main_tabs(g).end_display_object_list,						
						NULL,	
						l_list_of_main_tabs(g),						
						l_list_of_main_tabs(g).sub_tabs,
						l_list_of_main_tabs,
						l_summary);
			END LOOP;		

		END IF;

	EXIT;
	<< next_main_tab >>
	NULL;
	END LOOP;


	-------------------------------------------------------
	-- Delete the data inserted into the temporary tables
	-------------------------------------------------------
	DELETE FROM stormon_temp_results;

STORAGE.GETTIME(l_elapsed_time,'Total time taken');

EXCEPTION

WHEN OTHERS THEN
	
	STORAGE.PRINTN(' Raising exception in classical_drill_down '||SQLERRM);
	RAISE;
	
END classical_drill_down;


--------------------------------------------------
-- Procedure Name : display_lookup
-- Description    : display the lookup table
--
--                  INPUT : NONE
--
--                  OUTPUT : NONE
--------------------------------------------------
   PROCEDURE display_lookup(
      p_name     in VARCHAR2
   )
   is
   begin
     
     HTP.P('<FORM NAME=lookup>');

     HTP.P('<TABLE Border=0 align=center cellspacing=0 cellpadding=0 class=""');
     print_line('bgcolor=#CCCC8C');                     
     HTP.P('</TR>');  
     print_prow_open;       

     print_prow_open;            
     HTP.tabledata( cvalue => CHR(38) || 'nbsp;' , cattributes=>'align=LEFT');                               
     HTP.P('</TR>');  


     HTP.P('<TD ALIGN=LEFT>');
    
     HTP.P('<select name=lookup multiple size=8>');

          FOR k in (SELECT  /*+ DRIVING_SITE(a)*/ DISTINCT target_name
                    FROM mgmt_targets_view a
                   ) LOOP 

             HTP.P('<option ' || ' value="' || 
                    k.target_name || '">' ||  k.target_name || 
                    '</option>'
                  );                         
          END LOOP;
          
     HTP.P('</select>');
          
     HTP.P('</TD>');
     HTP.P('</TR>');  

     HTP.P('</TABLE>');        
     
     HTP.P('</FORM>');

   end display_lookup; 



BEGIN

NULL;

-- HTP.p gives an error here , RJKumar ?

--	PRINTN(' invoking initialization ');
	STORAGE.INITIALIZE;

END; -- package specification STORAGE
/


SHOW ERROR;
