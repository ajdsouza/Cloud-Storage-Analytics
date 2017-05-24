--
--
-- Copyright  (c) 2001,2002  Oracle Corporation All rights reserved 
--
--
--
-- $Id: storage.sql,v 1.22 2003/05/30 22:39:30 rjkumar Exp $ 
--
--
--
--

CREATE OR REPLACE PACKAGE storage IS

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
   procedure register (
      p_portlet_instance       in  WWPRO_API_PROVIDER.portlet_instance_record);
--------------------------------------------------

--------------------------------------------------
-- Procedure Name : deregister
-- Description    : Allows the portlet to do instance-level cleanup.
--                   INPUT : Portlet    - Portlet instance.
--------------------------------------------------
   procedure deregister (
      p_portlet_instance       in  WWPRO_API_PROVIDER.portlet_instance_record);
-------------------------------------------------- 
-- Procedure Name : show
-- Description    : Displays the portlet page based on a mode.
--                   INPUT : PortletRecord   - Record of portlet instance.
--------------------------------------------------
   procedure show (
      p_portlet_record        in out WWPRO_API_PROVIDER.portlet_runtime_record);
--------------------------------------------------
-- Procedure Name : copy
-- Description    : Copies the portlet's customization and default settings
--                  from a portlet instance to a new portlet instance.
--                   INPUT : PortletInfo     - Record of portlet info.
--------------------------------------------------
   procedure copy (
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
procedure display_storage_summary (
  p_group_name		in  varchar2,
  p_group_type          in  varchar2,
  p_chart_type          in  varchar2,  
  p_report_type	     	in  VARCHAR2,
  p_host_type           in  varchar2, 
  p_orderfield       	in  integer,  
  p_ordertype        	in  varchar2,  
  p_reference_path   	in  varchar2,
  p_page_url         	in  varchar2 
);
--------------------------------------------------
-- Procedure Name : change_display
-- Description    : Refresh the storage with newer display type
--                   INPUT : ReferencePath  - Portlet instance id
--                           Page URL       - URL of the calling page
--                           Display Type   - Type to display metric values
--------------------------------------------------
   procedure change_display (
      p_reference_path        in    varchar2,
      p_page_url              in    varchar2,
      p_group_name     in    varchar2 DEFAULT 'ALL',
      p_group_type     in    varchar2 DEFAULT 'REPORTING_ALL',
      p_chart_type            in    varchar2 DEFAULT 'PIE',
      p_report_type	      in    VARCHAR2 DEFAULT NULL,
      p_host_type             in    varchar2 DEFAULT 'ALL_HOSTS',
      p_orderfield            in    integer  DEFAULT 3, 
      p_ordertype             in    varchar2 DEFAULT 'DEFAULT'
   );

--------------------------------------------------
-- Procedure Name : get_dc_lob_report
-- Description    : Refresh the storage summary with newer display type 
--                   INPUT : ReferencePath  - Portlet instance id
--                           Page URL       - URL of the calling page 
--                           Display Type   - datacenter
--			     LOB	    - LOB
--			     chart type
--------------------------------------------------
   procedure get_dc_lob_report (
      p_reference_path        in    varchar2,
      p_page_url              in    varchar2,
      p_datacenter	      in    varchar2 DEFAULT 'ALL',
      p_lob		      in    varchar2 DEFAULT 'ALL',
      p_chart_type            in    varchar2 DEFAULT 'PIE'
   );

--------------------------------------------------
-- Procedure  Name : l_draw_graph
-- Description    : Global function to invoke servlet to
--                  generate HTML graph chart.
--------------------------------------------------
   Procedure l_draw_graph(
      p_id               in varchar2,
      p_period           in varchar2, 
      p_storage_type     in varchar2
  );
--------------------------------------------------
-- Procedure Name : display_storage_history
-- Description    : display storage history in a popup window
--                   INPUT :
--------------------------------------------------
   procedure display_storage_history (
      p_period           in varchar2,
      p_storage_type     in varchar2,
      p_id               in storage_summaryObject.id%TYPE
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
procedure display_host_details (
	p_id          IN varchar2,
	p_orderTable  IN INTEGER DEFAULT 2,	-- DISK TABLE
	p_orderfield  IN INTEGER DEFAULT 4,	-- SIZE
	P_orderType   IN VARCHAR2 DEFAULT 'DEFAULT'
);
--------------------------------------------------
-- Procedure Name : display_issues
-- Description    : display_issues
--          INPUT : target name
--                  target id 
--------------------------------------------------
procedure display_issues (
  p_id    	  in varchar2,
  p_message_type  in varchar2,   -- Type of message , ISSUE or WARNING
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
  p_id   	  in varchar2
);


--------------------------------------------------------------------
-- Name : classical_drill_down
-- 
-- Desc : Procedure to build the UI, the cgi nvokes this procedure
--		The default starts with ALL datacenters and LOB's
--		For drill downs pass the specific Datacenter and LOB
--------------------------------------------------------------------
PROCEDURE classical_drill_down( 
				p_group_name	IN VARCHAR2 DEFAULT 'ALL',
				p_group_type	IN VARCHAR2 DEFAULT 'REPORTING_ALL',
				p_chart_type		IN VARCHAR2 DEFAULT 'PIE' ,
				p_report_type		IN VARCHAR2 DEFAULT NULL,
				p_host_type		IN VARCHAR2 DEFAULT 'ALL_HOSTS',	 
				p_orderfield		IN INTEGER DEFAULT 3, 
				p_ordertype		IN VARCHAR2 DEFAULT 'DEFAULT'
);

--------------------------------------------------------------------
-- Name : quick_look_up_report
-- 
-- Desc : build storage on a wild card search for group or host names.
--	  More than one name to be separated by a ,
--
--------------------------------------------------------------------
PROCEDURE quick_look_up_report(
				p_group_name_like 	stormon_group_table.name%TYPE,
				p_group_type		stormon_group_table.type%TYPE,
				p_chart_type		IN VARCHAR2 DEFAULT 'PIE' 
		);


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
-- Package variables and constants
-- 
-- Desc : Initialize the package level configuratioon structures, 
--	to be initialized one time.
--
--
--------------------------------------------------------------------
-- IF DEBUG THEN PRINT DEBUG STATEMENTS
l_mode			VARCHAR2(24) := 'PRODUCTION';

-- Table of string Tables
TYPE t_stringTable IS TABLE OF stringTable;

-- Table of integers
TYPE intTable IS TABLE OF INTEGER;

-- Table of integer tables
TYPE t_intTable IS TABLE OF intTable;

-- Type numberTable is table of numbers
TYPE numberTable IS TABLE OF NUMBER(16);

-- Table for holding column configuration
TYPE column_record IS RECORD ( 
				column_name VARCHAR2(50), 
				field_name VARCHAR2(100) := NULL, 
				order_clause VARCHAR2(100) , 
				order_type VARCHAR2(10) := 'DESC' );

-- Collection to fetch data from detail queries
TYPE  t_resultsRec IS RECORD (
				type		stringTable, 
				path		stringTable, 
				filesystem 	stringTable, 
				rawsizeb	numberTable, 
				sizeb 		numberTable, 
				usedb		numberTable, 
				freeb		numberTable, 
				vendor		stringTable, 
				backup		stringTable, 
				product		stringTable, 
				mountpoint 	stringTable,
				configuration 	stringTable,
				freetype 	stringTable,
				tablespace 	stringTable,
				dbid 		stringTable
				);

TYPE title_record IS RECORD (
				column_no INTEGER, 
				subtitle intTable := NULL);


-- Columns for each Table type
TYPE  hostsummaryrec IS RECORD (
				querytype numberTable, 
				type stringTable,
				name stringTable, 
				rawsizeb numberTable, 
				sizeb numberTable, 
				usedb numberTable, 
				freeb numberTable);

-- Column Table for summaries
TYPE summary_column_list IS VARRAY(30) OF column_record;

-- Column table for detailed report
TYPE detail_column_list IS VARRAY(24) OF column_record;
TYPE detail_column_qlist IS VARRAY(10) OF detail_column_List;	

-- Table for titles of report tables
TYPE titletable IS TABLE OF title_record;
TYPE t_titleTable IS TABLE OF titleTable;

-- Cache for query results, table of summaryTables
TYPE t_allSummaries IS TABLE OF storageSummaryTable;


----------------------------------------------------------------------
-- CONSTANT DECLARATION
----------------------------------------------------------------------
PREFERENCE_PATH       varchar2(32) := 'mymetrics.storage';
BLANK                 varchar2(32) := chr(38) || 'nbsp;';
BLANK2                varchar2(32) := BLANK || BLANK; 
BLANK4                varchar2(32) := BLANK || BLANK || BLANK || BLANK ;
BLANK16               varchar2(1024) := BLANK4 || BLANK4 || BLANK4 || BLANK4 ;
BLANK64               varchar2(1024) := BLANK16 || BLANK16 || BLANK16 || BLANK16 ;

L_BASE_KB             number       := 1024 ; 
L_BASE_MB             number       := 1024 * L_BASE_KB; 
L_BASE_GB             number       := 1024 * L_BASE_MB; 
L_BASE_TB             number       := 1024 * L_BASE_GB; 

-- Color declarations  --
TABLE_HEADER_COLOR	varchar2(7)	:= '#CCCC8C';
RED_COLOR		varchar2(64)	:= '<font color="#cc0000">';   

-- Asending and descing column images
IMG_ASC               constant varchar2(256) := 
                      '<IMG BORDER=0 SRC=' || '/myImages/asc_sort.gif' || '>';
IMG_DESC              constant varchar2(256) := 
                      '<IMG BORDER=0 SRC=' || '/myImages/desc_sort.gif' || '>';

IMG_TOP                        constant varchar2(512) :=
                                '<A HREF="javascript:;" onclick="javascript:loadpage(''top'');"><IMG BORDER=0 SRC=' ||
                                '/myImages/mv-up.gif' ||
                                ' align=ABSBOTTOM ALT="Go to Top of the Page"></A>';
                                
--L_DC_TITLE varchar2(255)    := 'Data Center Storage Distribution';
--L_DC_SUBTITLE varchar2(255) := ' ';

-- TOP N To be listed in pie charts
c_topnRank				CONSTANT INTEGER := 6;

-- Constants for associating with the type of table to display
c_summary_host_table			CONSTANT INTEGER := 1;
c_summary_host_vendor_table		CONSTANT INTEGER := 2;
c_summary_dc_table			CONSTANT INTEGER := 3;
c_summary_lob_table			CONSTANT INTEGER := 4;


-- Constants for associating with the type of table to display
c_detailed_report_query_count		CONSTANT INTEGER := 7;

c_detailed_report_summary		CONSTANT INTEGER := 1;
c_detailed_report_disks			CONSTANT INTEGER := 2;
c_detailed_report_swraid		CONSTANT INTEGER := 3;
c_detailed_report_volumes		CONSTANT INTEGER := 4;
c_detailed_report_localfs		CONSTANT INTEGER := 5;
c_detailed_report_nfs			CONSTANT INTEGER := 6;
c_detailed_report_oracle_db		CONSTANT INTEGER := 7;



-- ORDER OF FIELD NAMES
c_detailed_field_type		CONSTANT  INTEGER := 1;
c_detailed_field_path		CONSTANT  INTEGER := 2;
c_detailed_field_filesystem	CONSTANT  INTEGER := 3;
c_detailed_field_rawsizeb	CONSTANT  INTEGER := 4;
c_detailed_field_sizeb		CONSTANT  INTEGER := 5;
c_detailed_field_usedb		CONSTANT  INTEGER := 6;
c_detailed_field_freeb		CONSTANT  INTEGER := 7;
c_detailed_field_vendor		CONSTANT  INTEGER := 8;
c_detailed_field_backup		CONSTANT  INTEGER := 9;
c_detailed_field_product	CONSTANT  INTEGER := 10;
c_detailed_field_mountpoint	CONSTANT  INTEGER := 11;
c_detailed_field_configuration	CONSTANT  INTEGER := 12;
c_detailed_field_freetype	CONSTANT  INTEGER := 13;
c_detailed_field_tablespace	CONSTANT  INTEGER := 14;
c_detailed_field_dbid		CONSTANT  INTEGER := 15;


-- Table for holding column configuration for summary report
l_list_of_summary_columns	summary_column_list := summary_column_list();

-- Columns for each Table type for summary report
l_list_of_summary_tables	t_titleTable := t_titleTable();

-- Table for holding configuration information for the detailed report
l_list_of_detailed_columns 	detail_column_qlist 	:= detail_column_qlist();

-- Other configuration structures for the detailed report

-- Table for detail report columns
l_detailed_table_columns	t_intTable 		:= t_intTable();

-- table of order of detail report columns
l_detailed_table_column_order	t_intTable	 	:= t_intTable();

-- defaute order list for each detail report table
l_detail_default_order_list	stringTable		:= stringTable();

-- SQL table name for each detail report table
l_detailed_report_table_name	stringTable		:= stringTable();

-- Table titles for detail report tables
l_detailed_table_title_list	stringTable		:= stringTable();

-- Not found error messages for detailed report tables
l_detailed_notfound_mesg_list	stringTable		:= stringTable();


----------------------------------------------------------------
-- Declarations for package subroutines
----------------------------------------------------------------
PROCEDURE get_dc_lob_from_name(	p_group_name	IN	stormon_group_table.name%TYPE,
				p_group_type	IN	stormon_group_table.type%TYPE,
				p_datacenter	OUT	VARCHAR2,
				p_lob		OUT	VARCHAR2);

FUNCTION get_lob_dc_title(
		p_dc IN  stormon_group_table.name%TYPE, 
		p_lob IN stormon_group_table.name%TYPE 
) RETURN VARCHAR2;


PROCEDURE print_host_title_table(l_summaryObject IN summaryObject );

PROCEDURE printstmt( v_string IN VARCHAR2);

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

	DBMS_OUTPUT.PUT_LINE('Initializing the package');

--HTP.p('Initializing the package'||'<BR>');
--	STORAGE.p_init_status := 1;

---------------------------------------
-- Summary report configuration
---------------------------------------

	-----------------------------------------
	-- COLUMN CONFIGURATION
	-----------------------------------------
	l_list_of_summary_columns.EXTEND(30);
	l_list_of_summary_columns(1).column_name := 'LOB';
	l_list_of_summary_columns(1).order_clause := 'TARGET_LOB';
	l_list_of_summary_columns(1).order_type := 'ASC';

	l_list_of_summary_columns(2).column_name := 'Rawsize';
	l_list_of_summary_columns(2).order_clause := 'RAWSIZE';
	l_list_of_summary_columns(2).order_type := 'DESC';

	l_list_of_summary_columns(3).column_name := 'Attached';
	l_list_of_summary_columns(3).order_clause := 'SIZEB';
	l_list_of_summary_columns(3).order_type := 'DESC';

	l_list_of_summary_columns(4).column_name := 'Database';
	l_list_of_summary_columns(4).order_clause := 'ORACLE_DATABASE_SIZE';
	l_list_of_summary_columns(4).order_type := 'DESC';

	l_list_of_summary_columns(5).column_name := 'Local Filesystems';
	l_list_of_summary_columns(5).order_clause := 'LOCAL_FILESYSTEM_SIZE';
	l_list_of_summary_columns(5).order_type := 'DESC';

	l_list_of_summary_columns(6).column_name := 'Dedicated NFS';
	l_list_of_summary_columns(6).order_clause := 'NFS_EXCLUSIVE_SIZE';
	l_list_of_summary_columns(6).order_type := 'DESC';

	l_list_of_summary_columns(7).column_name := 'Volume Manager';
	l_list_of_summary_columns(7).order_clause := 'VOLUMEMANAGER_SIZE';
	l_list_of_summary_columns(7).order_type := 'DESC';

	l_list_of_summary_columns(8).column_name := 'SW Raid Manager';
	l_list_of_summary_columns(8).order_clause := 'SWRAID_SIZE';
	l_list_of_summary_columns(8).order_type := 'DESC';

	l_list_of_summary_columns(9).column_name := 'Backup Disks';
	l_list_of_summary_columns(9).order_clause := 'DISK_BACKUP_SIZE';
	l_list_of_summary_columns(9).order_type := 'DESC';

	l_list_of_summary_columns(10).column_name := 'Disks';
	l_list_of_summary_columns(10).order_clause := 'DISK_SIZE';
	l_list_of_summary_columns(10).order_type := 'DESC';

	l_list_of_summary_columns(11).column_name := '%Used';
	l_list_of_summary_columns(11).order_clause := '(USED/DECODE(SIZEB,NULL,1,0,1,SIZEB))';
	l_list_of_summary_columns(11).order_type := 'DESC';

	l_list_of_summary_columns(12).column_name := 'Free';
	l_list_of_summary_columns(12).order_clause := 'FREE';
	l_list_of_summary_columns(12).order_type := 'DESC';

	l_list_of_summary_columns(13).column_name := 'Issues';
	l_list_of_summary_columns(13).order_clause := 'ISSUES';
	l_list_of_summary_columns(13).order_type := 'DESC';

	l_list_of_summary_columns(14).column_name := 'Related Links';
	l_list_of_summary_columns(14).order_clause := NULL;
	l_list_of_summary_columns(14).order_type := 'DESC';

	l_list_of_summary_columns(15).column_name := 'EMC Symmetrix Rawsize/Attached';
	l_list_of_summary_columns(15).order_clause := 'VENDOR_EMC_SIZE';
	l_list_of_summary_columns(15).order_type := 'DESC';

	l_list_of_summary_columns(16).column_name := 'Network Appliance';
	l_list_of_summary_columns(16).order_clause := 'VENDOR_NFS_NETAPP_SIZE';
	l_list_of_summary_columns(16).order_type := 'DESC';

	l_list_of_summary_columns(17).column_name := 'Sun';
	l_list_of_summary_columns(17).order_clause := 'VENDOR_SUN_SIZE';
	l_list_of_summary_columns(17).order_type := 'DESC';

	l_list_of_summary_columns(18).column_name := 'Hitachi';
	l_list_of_summary_columns(18).order_clause := 'VENDOR_HITACHI_SIZE';
	l_list_of_summary_columns(18).order_type := 'DESC';

	l_list_of_summary_columns(19).column_name := 'Other Vendors';
	l_list_of_summary_columns(19).order_clause := '(VENDOR_NFS_OTHERS_SIZE+VENDOR_NFS_SUN_SIZE+VENDOR_NFS_EMC_SIZE+VENDOR_OTHERS_SIZE+VENDOR_HP_SIZE)';
	l_list_of_summary_columns(19).order_type := 'DESC';

	l_list_of_summary_columns(20).column_name := 'Hosts';
	l_list_of_summary_columns(20).order_clause := 'HOSTCOUNT ';
	l_list_of_summary_columns(20).order_type := 'DESC';

	l_list_of_summary_columns(21).column_name := 'Allocated/Used';
	l_list_of_summary_columns(21).order_clause := 'DISK_SIZE';
	l_list_of_summary_columns(21).order_type := 'DESC';

	l_list_of_summary_columns(22).column_name := 'Used';
	l_list_of_summary_columns(22).order_clause := 'USED';
	l_list_of_summary_columns(22).order_type := 'DESC';

	l_list_of_summary_columns(23).column_name := 'Other';
	l_list_of_summary_columns(23).order_clause := '(USED-DISK_BACKUP_SIZE)';
	l_list_of_summary_columns(23).order_type := 'DESC';

	l_list_of_summary_columns(24).column_name := 'Total';
	l_list_of_summary_columns(24).order_clause := 'USED';
	l_list_of_summary_columns(24).order_type := 'DESC';

	l_list_of_summary_columns(25).column_name := 'Host Name';
	l_list_of_summary_columns(25).order_clause := 'TARGET_NAME';
	l_list_of_summary_columns(25).order_type := 'ASC';

	l_list_of_summary_columns(26).column_name := 'With<BR>Issues';
	l_list_of_summary_columns(26).order_clause := 'ISSUES';
	l_list_of_summary_columns(26).order_type := 'DESC';

	l_list_of_summary_columns(27).column_name := 'Data Center';
	l_list_of_summary_columns(27).order_clause := 'TARGET_DATACENTER';
	l_list_of_summary_columns(27).order_type := 'ASC';

	l_list_of_summary_columns(28).column_name := 'Total';
	l_list_of_summary_columns(28).order_clause := 'HOSTCOUNT';
	l_list_of_summary_columns(28).order_type := 'DESC';

	l_list_of_summary_columns(29).column_name := 'Summarized';
	l_list_of_summary_columns(29).order_clause := 'ACTUAL_TARGETS';
	l_list_of_summary_columns(29).order_type := 'DESC';

	l_list_of_summary_columns(30).column_name := 'Not<BR>Scheduled';
	l_list_of_summary_columns(30).order_clause := 'HOSTCOUNT-ACTUAL_TARGETS';
	l_list_of_summary_columns(30).order_type := 'DESC';

	-----------------------------------------
	-- TABLE COLUMNS
	-----------------------------------------
	-- Columns for each Table type
	l_list_of_summary_tables.EXTEND(4);
	
	l_list_of_summary_tables(c_summary_host_table) := titleTable();
	l_list_of_summary_tables(c_summary_host_table).EXTEND(7);
	l_list_of_summary_tables(c_summary_host_vendor_table) := titleTable();
	l_list_of_summary_tables(c_summary_host_vendor_table).EXTEND(8);
	l_list_of_summary_tables(c_summary_dc_table) := titleTable();
	l_list_of_summary_tables(c_summary_dc_table).EXTEND(8);
	l_list_of_summary_tables(c_summary_lob_table) := titleTable();
	l_list_of_summary_tables(c_summary_lob_table).EXTEND(8);

	-- Host Table
	l_list_of_summary_tables(c_summary_host_table)(1).column_no := 25;
	l_list_of_summary_tables(c_summary_host_table)(2).column_no := 2;
	l_list_of_summary_tables(c_summary_host_table)(3).column_no := 3;
	l_list_of_summary_tables(c_summary_host_table)(4).column_no := 21;
	l_list_of_summary_tables(c_summary_host_table)(4).subtitle  := intTable(4, 5, 6, 7, 8, 9, 10);
	l_list_of_summary_tables(c_summary_host_table)(5).column_no := 11;
	l_list_of_summary_tables(c_summary_host_table)(6).column_no := 12;
	l_list_of_summary_tables(c_summary_host_table)(7).column_no := 14;

	-- Vendor Table
	l_list_of_summary_tables(c_summary_host_vendor_table)(1).column_no := 25;
	l_list_of_summary_tables(c_summary_host_vendor_table)(2).column_no := 2;
	l_list_of_summary_tables(c_summary_host_vendor_table)(3).column_no := 3;
	l_list_of_summary_tables(c_summary_host_vendor_table)(4).column_no := 15;
	l_list_of_summary_tables(c_summary_host_vendor_table)(5).column_no := 16;
	l_list_of_summary_tables(c_summary_host_vendor_table)(6).column_no := 17;
	l_list_of_summary_tables(c_summary_host_vendor_table)(7).column_no := 18;
	l_list_of_summary_tables(c_summary_host_vendor_table)(8).column_no := 19;

	-- DC Table
	l_list_of_summary_tables(c_summary_dc_table)(1).column_no := 27;
	l_list_of_summary_tables(c_summary_dc_table)(2).column_no := 20;
	l_list_of_summary_tables(c_summary_dc_table)(2).subtitle  := intTable( 29, 30, 26, 28);
	l_list_of_summary_tables(c_summary_dc_table)(3).column_no := 2;
	l_list_of_summary_tables(c_summary_dc_table)(4).column_no := 3;
	l_list_of_summary_tables(c_summary_dc_table)(5).column_no := 22;
	l_list_of_summary_tables(c_summary_dc_table)(5).subtitle := intTable( 24, 9, 23);
	l_list_of_summary_tables(c_summary_dc_table)(6).column_no := 11;
	l_list_of_summary_tables(c_summary_dc_table)(7).column_no := 12;
	l_list_of_summary_tables(c_summary_dc_table)(8).column_no := 14;

	-- DC Table
	l_list_of_summary_tables(c_summary_lob_table)(1).column_no := 1;
	l_list_of_summary_tables(c_summary_lob_table)(2).column_no := 20;
	l_list_of_summary_tables(c_summary_lob_table)(2).subtitle  := intTable( 29, 30, 26, 28);
	l_list_of_summary_tables(c_summary_lob_table)(3).column_no := 2;
	l_list_of_summary_tables(c_summary_lob_table)(4).column_no := 3;
	l_list_of_summary_tables(c_summary_lob_table)(5).column_no := 22;
	l_list_of_summary_tables(c_summary_lob_table)(5).subtitle := intTable( 24, 9, 23);
	l_list_of_summary_tables(c_summary_lob_table)(6).column_no := 11;
	l_list_of_summary_tables(c_summary_lob_table)(7).column_no := 12;
	l_list_of_summary_tables(c_summary_lob_table)(8).column_no := 14;


------------------------------------------
-- Detailed report configuration
------------------------------------------
	-----------------------------------------
	-- COLUMN CONFIGURATION
	-----------------------------------------
	l_list_of_detailed_columns.EXTEND(c_detailed_report_query_count);
	
	-- SUMMARY FIELDS
	l_list_of_detailed_columns(c_detailed_report_summary) := detail_column_list();
	l_list_of_detailed_columns(c_detailed_report_summary).EXTEND(5);

	l_list_of_detailed_columns(c_detailed_report_summary)(1).column_name := 'Name';
	l_list_of_detailed_columns(c_detailed_report_summary)(1).field_name := NULL;
	l_list_of_detailed_columns(c_detailed_report_summary)(1).order_type := 'ASC';

	l_list_of_detailed_columns(c_detailed_report_summary)(2).column_name := 'Rawsize';
	l_list_of_detailed_columns(c_detailed_report_summary)(2).field_name := NULL;
	l_list_of_detailed_columns(c_detailed_report_summary)(2).order_type := 'DESC';

	l_list_of_detailed_columns(c_detailed_report_summary)(3).column_name := 'Size';
	l_list_of_detailed_columns(c_detailed_report_summary)(3).field_name := NULL;
	l_list_of_detailed_columns(c_detailed_report_summary)(3).order_type := 'DESC';

	l_list_of_detailed_columns(c_detailed_report_summary)(4).column_name := 'Used';
	l_list_of_detailed_columns(c_detailed_report_summary)(4).field_name := NULL;
	l_list_of_detailed_columns(c_detailed_report_summary)(4).order_type := 'DESC';

	l_list_of_detailed_columns(c_detailed_report_summary)(5).column_name := 'Free';
	l_list_of_detailed_columns(c_detailed_report_summary)(5).field_name := NULL;
	l_list_of_detailed_columns(c_detailed_report_summary)(5).order_type := 'DESC';


	-- DISK FIELDS
	l_list_of_detailed_columns(c_detailed_report_disks) := detail_column_list();
	l_list_of_detailed_columns(c_detailed_report_disks).EXTEND(9);

	l_list_of_detailed_columns(c_detailed_report_disks)(1).column_name := 'Path';
	l_list_of_detailed_columns(c_detailed_report_disks)(1).field_name := 'path';
	l_list_of_detailed_columns(c_detailed_report_disks)(1).order_type := 'ASC';

	l_list_of_detailed_columns(c_detailed_report_disks)(2).column_name := 'Type';
	l_list_of_detailed_columns(c_detailed_report_disks)(2).field_name := 'type';
	l_list_of_detailed_columns(c_detailed_report_disks)(2).order_type := 'ASC';

	l_list_of_detailed_columns(c_detailed_report_disks)(3).column_name := 'Rawsize';
	l_list_of_detailed_columns(c_detailed_report_disks)(3).field_name := 'rawsizeb';
	l_list_of_detailed_columns(c_detailed_report_disks)(3).order_type := 'DESC';

	l_list_of_detailed_columns(c_detailed_report_disks)(4).column_name := 'Size';
	l_list_of_detailed_columns(c_detailed_report_disks)(4).field_name := 'sizeb';
	l_list_of_detailed_columns(c_detailed_report_disks)(4).order_type := 'DESC';

	l_list_of_detailed_columns(c_detailed_report_disks)(5).column_name := 'Used';
	l_list_of_detailed_columns(c_detailed_report_disks)(5).field_name := 'usedb';
	l_list_of_detailed_columns(c_detailed_report_disks)(5).order_type := 'DESC';

	l_list_of_detailed_columns(c_detailed_report_disks)(6).column_name := 'Free';
	l_list_of_detailed_columns(c_detailed_report_disks)(6).field_name := 'freeb';
	l_list_of_detailed_columns(c_detailed_report_disks)(6).order_type := 'DESC';

	l_list_of_detailed_columns(c_detailed_report_disks)(7).column_name := 'Backup';
	l_list_of_detailed_columns(c_detailed_report_disks)(7).field_name := 'backup';
	l_list_of_detailed_columns(c_detailed_report_disks)(7).order_type := 'ASC';

	l_list_of_detailed_columns(c_detailed_report_disks)(8).column_name := 'Configuration';
	l_list_of_detailed_columns(c_detailed_report_disks)(8).field_name := 'configuration';
	l_list_of_detailed_columns(c_detailed_report_disks)(8).order_type := 'ASC';

	l_list_of_detailed_columns(c_detailed_report_disks)(9).column_name := 'Vendor';
	l_list_of_detailed_columns(c_detailed_report_disks)(9).field_name := 'vendor';
	l_list_of_detailed_columns(c_detailed_report_disks)(9).order_type := 'ASC';


	
	-- SWAID FIELDS
	l_list_of_detailed_columns(c_detailed_report_swraid) := detail_column_list();
	l_list_of_detailed_columns(c_detailed_report_swraid).EXTEND(9);

	l_list_of_detailed_columns(c_detailed_report_swraid)(1).column_name := 'Path';
	l_list_of_detailed_columns(c_detailed_report_swraid)(1).field_name := 'path';
	l_list_of_detailed_columns(c_detailed_report_swraid)(1).order_type := 'ASC';

	l_list_of_detailed_columns(c_detailed_report_swraid)(2).column_name := 'Type';
	l_list_of_detailed_columns(c_detailed_report_swraid)(2).field_name := 'type';
	l_list_of_detailed_columns(c_detailed_report_swraid)(2).order_type := 'ASC';

	l_list_of_detailed_columns(c_detailed_report_swraid)(3).column_name := 'Rawsize';
	l_list_of_detailed_columns(c_detailed_report_swraid)(3).field_name := 'rawsizeb';
	l_list_of_detailed_columns(c_detailed_report_swraid)(3).order_type := 'DESC';

	l_list_of_detailed_columns(c_detailed_report_swraid)(4).column_name := 'Size';
	l_list_of_detailed_columns(c_detailed_report_swraid)(4).field_name := 'sizeb';
	l_list_of_detailed_columns(c_detailed_report_swraid)(4).order_type := 'DESC';

	l_list_of_detailed_columns(c_detailed_report_swraid)(5).column_name := 'Used';
	l_list_of_detailed_columns(c_detailed_report_swraid)(5).field_name := 'usedb';
	l_list_of_detailed_columns(c_detailed_report_swraid)(5).order_type := 'DESC';

	l_list_of_detailed_columns(c_detailed_report_swraid)(6).column_name := 'Free';
	l_list_of_detailed_columns(c_detailed_report_swraid)(6).field_name := 'freeb';
	l_list_of_detailed_columns(c_detailed_report_swraid)(6).order_type := 'DESC';

	l_list_of_detailed_columns(c_detailed_report_swraid)(7).column_name := 'Backup';
	l_list_of_detailed_columns(c_detailed_report_swraid)(7).field_name := 'backup';
	l_list_of_detailed_columns(c_detailed_report_swraid)(7).order_type := 'ASC';

	l_list_of_detailed_columns(c_detailed_report_swraid)(8).column_name := 'Configuration';
	l_list_of_detailed_columns(c_detailed_report_swraid)(8).field_name := 'configuration';
	l_list_of_detailed_columns(c_detailed_report_swraid)(8).order_type := 'ASC';

	l_list_of_detailed_columns(c_detailed_report_swraid)(9).column_name := 'Vendor';
	l_list_of_detailed_columns(c_detailed_report_swraid)(9).field_name := 'vendor';
	l_list_of_detailed_columns(c_detailed_report_swraid)(9).order_type := 'ASC';


	-- VOLUME MANAGER FIELDS
	l_list_of_detailed_columns(c_detailed_report_volumes) := detail_column_list();
	l_list_of_detailed_columns(c_detailed_report_volumes).EXTEND(9);

	l_list_of_detailed_columns(c_detailed_report_volumes)(1).column_name := 'Path';
	l_list_of_detailed_columns(c_detailed_report_volumes)(1).field_name := 'path';
	l_list_of_detailed_columns(c_detailed_report_volumes)(1).order_type := 'ASC';

	l_list_of_detailed_columns(c_detailed_report_volumes)(2).column_name := 'Type';
	l_list_of_detailed_columns(c_detailed_report_volumes)(2).field_name := 'type';
	l_list_of_detailed_columns(c_detailed_report_volumes)(2).order_type := 'ASC';

	l_list_of_detailed_columns(c_detailed_report_volumes)(3).column_name := 'Rawsize';
	l_list_of_detailed_columns(c_detailed_report_volumes)(3).field_name := 'rawsizeb';
	l_list_of_detailed_columns(c_detailed_report_volumes)(3).order_type := 'DESC';

	l_list_of_detailed_columns(c_detailed_report_volumes)(4).column_name := 'Size';
	l_list_of_detailed_columns(c_detailed_report_volumes)(4).field_name := 'sizeb';
	l_list_of_detailed_columns(c_detailed_report_volumes)(4).order_type := 'DESC';

	l_list_of_detailed_columns(c_detailed_report_volumes)(5).column_name := 'Used';
	l_list_of_detailed_columns(c_detailed_report_volumes)(5).field_name := 'usedb';
	l_list_of_detailed_columns(c_detailed_report_volumes)(5).order_type := 'DESC';

	l_list_of_detailed_columns(c_detailed_report_volumes)(6).column_name := 'Free';
	l_list_of_detailed_columns(c_detailed_report_volumes)(6).field_name := 'freeb';
	l_list_of_detailed_columns(c_detailed_report_volumes)(6).order_type := 'DESC';

	l_list_of_detailed_columns(c_detailed_report_volumes)(7).column_name := 'Backup';
	l_list_of_detailed_columns(c_detailed_report_volumes)(7).field_name := 'backup';
	l_list_of_detailed_columns(c_detailed_report_volumes)(7).order_type := 'ASC';

	l_list_of_detailed_columns(c_detailed_report_volumes)(8).column_name := 'Configuration';
	l_list_of_detailed_columns(c_detailed_report_volumes)(8).field_name := 'configuration';
	l_list_of_detailed_columns(c_detailed_report_volumes)(8).order_type := 'ASC';

	l_list_of_detailed_columns(c_detailed_report_volumes)(9).column_name := 'Freetype';
	l_list_of_detailed_columns(c_detailed_report_volumes)(9).field_name := 'freetype';
	l_list_of_detailed_columns(c_detailed_report_volumes)(9).order_type := 'ASC';


	-- LOCAL FILESYSTEM FIELDS
	l_list_of_detailed_columns(c_detailed_report_localfs) := detail_column_list();
	l_list_of_detailed_columns(c_detailed_report_localfs).EXTEND(8);

	l_list_of_detailed_columns(c_detailed_report_localfs)(1).column_name := 'Filesystem';
	l_list_of_detailed_columns(c_detailed_report_localfs)(1).field_name := 'filesystem';
	l_list_of_detailed_columns(c_detailed_report_localfs)(1).order_type := 'ASC';

	l_list_of_detailed_columns(c_detailed_report_localfs)(2).column_name := 'Type';
	l_list_of_detailed_columns(c_detailed_report_localfs)(2).field_name := 'type';
	l_list_of_detailed_columns(c_detailed_report_localfs)(2).order_type := 'ASC';

	l_list_of_detailed_columns(c_detailed_report_localfs)(3).column_name := 'Rawsize';
	l_list_of_detailed_columns(c_detailed_report_localfs)(3).field_name := 'rawsizeb';
	l_list_of_detailed_columns(c_detailed_report_localfs)(3).order_type := 'DESC';

	l_list_of_detailed_columns(c_detailed_report_localfs)(4).column_name := 'Size';
	l_list_of_detailed_columns(c_detailed_report_localfs)(4).field_name := 'sizeb';
	l_list_of_detailed_columns(c_detailed_report_localfs)(4).order_type := 'DESC';

	l_list_of_detailed_columns(c_detailed_report_localfs)(5).column_name := 'Used';
	l_list_of_detailed_columns(c_detailed_report_localfs)(5).field_name := 'usedb';
	l_list_of_detailed_columns(c_detailed_report_localfs)(5).order_type := 'DESC';

	l_list_of_detailed_columns(c_detailed_report_localfs)(6).column_name := 'Free';
	l_list_of_detailed_columns(c_detailed_report_localfs)(6).field_name := 'freeb';
	l_list_of_detailed_columns(c_detailed_report_localfs)(6).order_type := 'DESC';

	l_list_of_detailed_columns(c_detailed_report_localfs)(7).column_name := 'Backup';
	l_list_of_detailed_columns(c_detailed_report_localfs)(7).field_name := 'backup';
	l_list_of_detailed_columns(c_detailed_report_localfs)(7).order_type := 'ASC';

	l_list_of_detailed_columns(c_detailed_report_localfs)(8).column_name := 'Mountpoint';
	l_list_of_detailed_columns(c_detailed_report_localfs)(8).field_name := 'mountpoint';
	l_list_of_detailed_columns(c_detailed_report_localfs)(8).order_type := 'ASC';



	-- NFS FILESYSTEM FIELDS
	l_list_of_detailed_columns(c_detailed_report_nfs) := detail_column_list();
	l_list_of_detailed_columns(c_detailed_report_nfs).EXTEND(8);

	l_list_of_detailed_columns(c_detailed_report_nfs)(1).column_name := 'Filesystem';
	l_list_of_detailed_columns(c_detailed_report_nfs)(1).field_name := 'filesystem';
	l_list_of_detailed_columns(c_detailed_report_nfs)(1).order_type := 'ASC';

	l_list_of_detailed_columns(c_detailed_report_nfs)(2).column_name := 'Type';
	l_list_of_detailed_columns(c_detailed_report_nfs)(2).field_name := 'type';
	l_list_of_detailed_columns(c_detailed_report_nfs)(2).order_type := 'ASC';

	l_list_of_detailed_columns(c_detailed_report_nfs)(3).column_name := 'Rawsize';
	l_list_of_detailed_columns(c_detailed_report_nfs)(3).field_name := 'rawsizeb';
	l_list_of_detailed_columns(c_detailed_report_nfs)(3).order_type := 'DESC';

	l_list_of_detailed_columns(c_detailed_report_nfs)(4).column_name := 'Size';
	l_list_of_detailed_columns(c_detailed_report_nfs)(4).field_name := 'sizeb';
	l_list_of_detailed_columns(c_detailed_report_nfs)(4).order_type := 'DESC';

	l_list_of_detailed_columns(c_detailed_report_nfs)(5).column_name := 'Used';
	l_list_of_detailed_columns(c_detailed_report_nfs)(5).field_name := 'usedb';
	l_list_of_detailed_columns(c_detailed_report_nfs)(5).order_type := 'DESC';

	l_list_of_detailed_columns(c_detailed_report_nfs)(6).column_name := 'Free';
	l_list_of_detailed_columns(c_detailed_report_nfs)(6).field_name := 'freeb';
	l_list_of_detailed_columns(c_detailed_report_nfs)(6).order_type := 'DESC';

	l_list_of_detailed_columns(c_detailed_report_nfs)(7).column_name := 'Vendor';
	l_list_of_detailed_columns(c_detailed_report_nfs)(7).field_name := 'vendor';
	l_list_of_detailed_columns(c_detailed_report_nfs)(7).order_type := 'ASC';

	l_list_of_detailed_columns(c_detailed_report_nfs)(8).column_name := 'Mountpoint';
	l_list_of_detailed_columns(c_detailed_report_nfs)(8).field_name := 'mountpoint';
	l_list_of_detailed_columns(c_detailed_report_nfs)(8).order_type := 'ASC';



	-- ORACLE DATABASE FIELDS
	l_list_of_detailed_columns(c_detailed_report_oracle_db) := detail_column_list();
	l_list_of_detailed_columns(c_detailed_report_oracle_db).EXTEND(7);

	l_list_of_detailed_columns(c_detailed_report_oracle_db)(1).column_name := 'DB Name/SID';
	l_list_of_detailed_columns(c_detailed_report_oracle_db)(1).field_name := 'dbid';
	l_list_of_detailed_columns(c_detailed_report_oracle_db)(1).order_type := 'ASC';

	l_list_of_detailed_columns(c_detailed_report_oracle_db)(2).column_name := 'Tablespace';
	l_list_of_detailed_columns(c_detailed_report_oracle_db)(2).field_name := 'tablespace';
	l_list_of_detailed_columns(c_detailed_report_oracle_db)(2).order_type := 'ASC';

	l_list_of_detailed_columns(c_detailed_report_oracle_db)(3).column_name := 'Filename';
	l_list_of_detailed_columns(c_detailed_report_oracle_db)(3).field_name := 'filename';
	l_list_of_detailed_columns(c_detailed_report_oracle_db)(3).order_type := 'ASC';

	l_list_of_detailed_columns(c_detailed_report_oracle_db)(4).column_name := 'Size';
	l_list_of_detailed_columns(c_detailed_report_oracle_db)(4).field_name := 'sizeb';
	l_list_of_detailed_columns(c_detailed_report_oracle_db)(4).order_type := 'DESC';

	l_list_of_detailed_columns(c_detailed_report_oracle_db)(5).column_name := 'Used';
	l_list_of_detailed_columns(c_detailed_report_oracle_db)(5).field_name := 'usedb';
	l_list_of_detailed_columns(c_detailed_report_oracle_db)(5).order_type := 'DESC';

	l_list_of_detailed_columns(c_detailed_report_oracle_db)(6).column_name := 'Free';
	l_list_of_detailed_columns(c_detailed_report_oracle_db)(6).field_name := 'freeb';
	l_list_of_detailed_columns(c_detailed_report_oracle_db)(6).order_type := 'DESC';

	l_list_of_detailed_columns(c_detailed_report_oracle_db)(7).column_name := 'Backup';
	l_list_of_detailed_columns(c_detailed_report_oracle_db)(7).field_name := 'backup';
	l_list_of_detailed_columns(c_detailed_report_oracle_db)(7).order_type := 'ASC';


	----------------------------------------
	-- QUERIES TITLES 
	----------------------------------------
	l_detailed_table_title_list.EXTEND(c_detailed_report_query_count);

	l_detailed_table_title_list(c_detailed_report_summary) 		:= '<A NAME="total"></A>Total Storage';
	l_detailed_table_title_list(c_detailed_report_disks) 	        := '<A NAME="disks"></A>Disks';
	l_detailed_table_title_list(c_detailed_report_swraid) 		:= '<A NAME="swraid"></A>Storage managed by Software raid Manager';
	l_detailed_table_title_list(c_detailed_report_volumes)  	:= '<A NAME="volumemanager"></A>Storage managed by Volume Manager';
	l_detailed_table_title_list(c_detailed_report_localfs)		:= '<A NAME="localfilesystem"></A>Local File Systems ';
	l_detailed_table_title_list(c_detailed_report_nfs)		:= '<A NAME="nfs"></A>NFS Dedicated ';
	l_detailed_table_title_list(c_detailed_report_oracle_db)		:= '<A NAME="database"></A>Storage managed by Oracle Database Server ';

	----------------------------------------
	-- NOT FOUND MESSAGES 
	----------------------------------------
	l_detailed_notfound_mesg_list.EXTEND(c_detailed_report_query_count);

	l_detailed_notfound_mesg_list(c_detailed_report_summary) 	:= 'Total Storage';
	l_detailed_notfound_mesg_list(c_detailed_report_disks) 	:= 'No Disks detected on this system';
	l_detailed_notfound_mesg_list(c_detailed_report_swraid) 	:= 'Storage managed by Software raid Manager not detected on this system ';
	l_detailed_notfound_mesg_list(c_detailed_report_volumes)  := 'Storage managed by Volume Manager not detected on this system ';
	l_detailed_notfound_mesg_list(c_detailed_report_localfs)	:= 'No Local File Systems detected on this system';
	l_detailed_notfound_mesg_list(c_detailed_report_nfs)		:= 'No NFS (Dedicated) Mounted storage detected on this system';
	l_detailed_notfound_mesg_list(c_detailed_report_oracle_db)	:= 'Storage managed by Oracle Database Server not detected on this system';


	-- Fields to select for each Table type
	l_detailed_table_columns.EXTEND(c_detailed_report_query_count);

	l_detailed_table_columns(c_detailed_report_summary) 		:= intTable(1,NULL,NULL,2,3,4,5,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
	l_detailed_table_columns(c_detailed_report_disks) 		:= intTable(2,1,NULL,3,4,5,6,9,7,NULL,NULL,8,NULL,NULL,NULL);
	l_detailed_table_columns(c_detailed_report_swraid) 		:= intTable(2,1,NULL,3,4,5,6,NULL,7,NULL,NULL,8,NULL,NULL,NULL);
	l_detailed_table_columns(c_detailed_report_volumes) 	:= intTable(2,1,NULL,3,4,5,6,NULL,7,NULL,NULL,8,NULL,NULL,NULL);
	l_detailed_table_columns(c_detailed_report_localfs) 		:= intTable(2,NULL,1,3,4,5,6,NULL,7,NULL,8,NULL,NULL,NULL,NULL);
	l_detailed_table_columns(c_detailed_report_nfs) 		:= intTable(NULL,NULL,1,3,4,5,6,7,NULL,NULL,8,NULL,NULL,NULL,NULL);
	l_detailed_table_columns(c_detailed_report_oracle_db) 		:= intTable(NULL,3,NULL,NULL,4,5,6,NULL,7,NULL,NULL,NULL,NULL,2,1);

	-- PRINT ORDER FOR COLUMNS FOR EACH TABLE
	l_detailed_table_column_order.EXTEND(c_detailed_report_query_count);

	l_detailed_table_column_order(c_detailed_report_summary) 	:= intTable(
                                                        c_detailed_field_type,
                                                        c_detailed_field_rawsizeb,
                                                        c_detailed_field_sizeb,
                                                        c_detailed_field_usedb,
                                                        c_detailed_field_freeb);

	l_detailed_table_column_order(c_detailed_report_disks) 	:= intTable(
							c_detailed_field_path,
							c_detailed_field_type,
							c_detailed_field_rawsizeb,
							c_detailed_field_sizeb,
							c_detailed_field_usedb,
							c_detailed_field_freeb,
							c_detailed_field_vendor,
							c_detailed_field_configuration,
							c_detailed_field_backup);

	l_detailed_table_column_order(c_detailed_report_swraid) 	:= intTable(
							c_detailed_field_path,
							c_detailed_field_type,
							c_detailed_field_rawsizeb,
							c_detailed_field_sizeb,
							c_detailed_field_usedb,
							c_detailed_field_freeb,
							c_detailed_field_configuration,
							c_detailed_field_backup);

	l_detailed_table_column_order(c_detailed_report_volumes) 	:= intTable(
							c_detailed_field_path,
							c_detailed_field_type,
							c_detailed_field_rawsizeb,
							c_detailed_field_sizeb,
							c_detailed_field_usedb,
							c_detailed_field_freeb,
							c_detailed_field_configuration,
							c_detailed_field_backup);

	l_detailed_table_column_order(c_detailed_report_localfs) 	:= intTable(
							c_detailed_field_filesystem,
							c_detailed_field_type,
							c_detailed_field_mountpoint,
							c_detailed_field_rawsizeb,
							c_detailed_field_sizeb,
							c_detailed_field_usedb,
							c_detailed_field_freeb,
							c_detailed_field_backup);

	l_detailed_table_column_order(c_detailed_report_nfs) 		:= intTable(
							c_detailed_field_filesystem,
							c_detailed_field_mountpoint,
							c_detailed_field_rawsizeb,
							c_detailed_field_sizeb,
							c_detailed_field_usedb,
							c_detailed_field_freeb,
							c_detailed_field_vendor);

	l_detailed_table_column_order(c_detailed_report_oracle_db) 	:= intTable(
							c_detailed_field_dbid,
							c_detailed_field_path,
							c_detailed_field_tablespace,
							c_detailed_field_sizeb,
							c_detailed_field_usedb,
							c_detailed_field_freeb
							);

	--  default ORDER BY list for each query
	
	l_detail_default_order_list.EXTEND(c_detailed_report_query_count);

	l_detail_default_order_list(c_detailed_report_summary) 		:= NULL;
	l_detail_default_order_list(c_detailed_report_disks) 	:= NULL;
	l_detail_default_order_list(c_detailed_report_swraid) 		:= NULL;
	l_detail_default_order_list(c_detailed_report_volumes) 	:= NULL;
	l_detail_default_order_list(c_detailed_report_localfs) 		:= NULL;
	l_detail_default_order_list(c_detailed_report_nfs) 		:= NULL;
	l_detail_default_order_list(c_detailed_report_oracle_db) 	:= ' 	dbid,
						DECODE(appname,''TOTAL'',1,2) DESC';


	--  Tablename for each query
	
	l_detailed_report_table_name.EXTEND(c_detailed_report_query_count);

	l_detailed_report_table_name(c_detailed_report_summary) 	:= NULL;
	l_detailed_report_table_name(c_detailed_report_disks) 	:= 'storage_disk_view';
	l_detailed_report_table_name(c_detailed_report_swraid) 		:= 'storage_swraid_view';
	l_detailed_report_table_name(c_detailed_report_volumes) 	:= 'storage_volume_view';
	l_detailed_report_table_name(c_detailed_report_localfs) 	:= 'storage_localfs_view';
	l_detailed_report_table_name(c_detailed_report_nfs) 		:= 'storage_nfs_view';
	l_detailed_report_table_name(c_detailed_report_oracle_db) 	:= 'storage_oracledb_view';


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


	IF l_mode = 'DEBUG' AND v_message IS NOT NULL THEN
		HTP.P(v_message||' = '||l_timeperiod);
		DBMS_OUTPUT.PUT_LINE(v_message||' = '||l_timeperiod);
	END IF;

	--RETURN l_timeperiod;

END gettime;


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
		l_args_list(l_args_list.LAST) := TRIM(' ' from SUBSTR(l_values_string,1,l_sep_position-1));
		l_values_string := TRIM(' ' from SUBSTR(l_values_string,l_sep_position+1));

	END LOOP;

	RETURN l_args_list;
	
END parse_arguments;

--------------------------------------------------
-- Procedure Name : display_tip
-- Description    : display underlined  title before table display
--                  category  
--          INPUT : target name
--------------------------------------------------
procedure display_tip( p_tip  IN stringTable)
is
   l_data  varchar2(1024);
begin

   IF p_tip IS NOT NULL AND p_tip.EXISTS(1) THEN

	   UTIL_PORTAL.include_portal_stylesheet;
	   HTP.P('<BR><BR>');
	   HTP.tableopen(cborder      => 'border=0',
                  calign       => 'center',
                  cattributes  => 'width=100% cellspacing=0 cellpadding=0');	
                      	  
        l_data := '<IMG BORDER="0" SRC="/myImages/tip.gif" >Tip :';	
        
	FOR i IN p_tip.FIRST..p_tip.LAST LOOP
            l_data := l_data || p_tip(i);

    	END LOOP;

	    HTP.tableRowOpen;

	    HTP.tableData(cvalue      => l_data,
                          cnowrap     => ' ', 
                          cattributes => 'class="OraTipText"' );                     

	    HTP.tableRowClose;                       	  
    
	    HTP.tableClose;     
    
    
	    HTP.p('<BR>');    

   END IF;

end display_tip;

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
-- Function  Name : get_display_time
-- Description    : Returns display for a time period
--                  
--                   INPUT : period('D','M','Q','Y')
--                   OUTPUT : Last Day, Week etc.
--------------------------------------------------
   function get_display_time(
      p_period  in varchar2 )
      return varchar2
   is
      l_display_time   varchar2(64);


   begin

    IF UPPER(p_period) = 'W' THEN
        l_display_time := 'Last Week''s';
    ELSIF UPPER(p_period) = 'M' THEN
        l_display_time := 'Last Month''s';        
    ELSIF UPPER(p_period) = 'Q' THEN
        l_display_time := 'Last Quarter''s';                
    ELSE
        l_display_time := 'Last Years''s';
    END IF;


      return l_display_time;         
   end get_display_time;  

--------------------------------------------------
-- Function  Name : get_display_range
-- Description    : Returns display for a time period
--                  
--                   INPUT : period('D','M','Q','Y')
--                   OUTPUT : From Start Date to End Date.
--------------------------------------------------
   function get_display_range(
      p_period  in varchar2 )
      return varchar2
   is
      l_display_range   varchar2(256);
      l_startdate       date;
      l_enddate         date;


   begin

    l_enddate := SYSDATE;	

    IF UPPER(p_period) = 'W' THEN
        l_startdate := TRUNC(l_enddate-6,'DD');
    ELSIF UPPER(p_period) = 'M' THEN
      	l_startdate := TRUNC(ADD_MONTHS(l_enddate,-1)+1,'DD');        
    ELSIF UPPER(p_period) = 'Q' THEN
	l_startdate := TRUNC(ADD_MONTHS(l_enddate,-3)+1,'D');     
    ELSE
	l_startdate := TRUNC(ADD_MONTHS(l_enddate,-12)+1,'D');        
    END IF;

    l_display_range := TO_CHAR(l_startdate,'DD-MON-YY')||' to '||TO_CHAR(l_enddate,'DD-MON-YY');

    return l_display_range;         
   end get_display_range;  

--------------------------------------------------
-- Function  Name : get_display_storage
-- Description    : Returns storage display name
--                  
--                   INPUT : short name for storage type
--                   OUTPUT : long name for storage type
--------------------------------------------------
   function get_display_storage(
      p_storage_type  in varchar2 )
      return varchar2
   is
      l_display_storage   varchar2(256);


   begin


    IF UPPER(p_storage_type) = 'DB' THEN       
        l_display_storage := 'All Databases';
    ELSIF UPPER(p_storage_type) = 'LFS' THEN
        l_display_storage := 'Local FileSystems';
    ELSIF UPPER(p_storage_type) = 'DNFS' THEN
        l_display_storage := 'Dedicated NFS';        
    ELSIF UPPER(p_storage_type) = 'DISKS' THEN
        l_display_storage := 'All Disks';                
    ELSIF UPPER(p_storage_type) = 'TOTAL' THEN
        l_display_storage := 'Total Used';
    ELSE
        l_display_storage := 'Total Attached ,Total Used';       
    END IF;   
 
      return l_display_storage;         
   end get_display_storage;  

--------------------------------------------------
-- Function  Name : get_storage_unit
-- Description    : Returns varchar2 in TB, GB,MB
--                  
--                   INPUT : number
--                   OUTPUT : storage unit
--------------------------------------------------
   function get_storage_unit(
      p_number  in number )
      return varchar2
   is
      l_unit   varchar2(32);
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
      return varchar2
   is
      l_data varchar2(32);

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
      p_number  in varchar2,
      p_unit    in varchar2 )
      return number
   is
      l_data number;
      l_number number;

   begin

       l_number := to_number(p_number);


       if (p_unit = 'MB') then
         l_data := round(l_number/L_BASE_MB);
       elsif (p_unit = 'GB') then          
         l_data := round(l_number/L_BASE_GB);
       elsif(p_unit = 'TB') then
         l_data := round(l_number/L_BASE_TB,2);
       end if;           
       
      return l_data;         
   end ; 



--------------------------------------------------
-- Function  Name : get_base_value
-- Description    : Returns number in TB, GB,MB
--                  
--                   INPUT : varchar2
--                   OUTPUT : number
--------------------------------------------------
   function get_base_value(
      p_unit  in varchar2 )
      return number
   is
      l_base number;

   begin

       if (p_unit = ' MB') then
         l_base := L_BASE_MB;
       elsif (p_unit = ' GB') then          
         l_base := L_BASE_GB;
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
function get_chart_image(
			p_title        in varchar2,
			p_subtitle     in varchar2,
			p_fieldname    in stringTable,                     
			p_fieldvalue   in stringTable,                                         
			p_display_type in varchar2 DEFAULT 'PIE',
			p_unit         in varchar2 DEFAULT NULL,  
			p_bartag       in varchar2 DEFAULT 'B'
                    ) return varchar2 
is    

    l_image            varchar2(32767);
    l_data             varchar2(32767);
    l_chart_colors     varchar2(32767);
    l_legend	       varchar2(32767);
    l_chart_values     varchar2(32767);
    l_series_width     number;
    l_width            number;
    l_height           number;  
    l_rowcol           varchar2(16);
             
begin

      
      IF p_fieldname IS NULL OR NOT p_fieldname.EXISTS(1) THEN
         RETURN NULL;
      END IF;

      l_chart_colors  := '99ff99,ffff99,ccffff,99ccff,ffffcc,99ffff,ffcccc,cccc99,00cccc,6699cc,cc0000,9999ff,ffff66,009999,00cc00,cc66cc,ff9999';
                
      if (trim(' ' from p_display_type) = 'PIE') then   

                if (p_fieldname.count <= 2) then
                   l_width := 200;
                else
                   l_width := 250;
                end if;

                l_height := 250;
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
            'legend=SOUTH' || chr(38) ||
            'enablelegend=YES' || chr(38) ||
            'valuepercentage=PERCENT' || chr(38) ||
            'seriescolors=' || l_chart_colors || chr(38) ||
            'html=NO" >';
	else

                if (p_fieldname.count <= 2) then
                   l_width := 175;
                   l_series_width := 20;
                else
                   l_width := 250;
                   l_series_width := 25;
                end if;

                l_height := 275;
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
									l_chart_values := p_bartag||j||','|| get_fmt_storage(p_fieldvalue(j),p_unit);						
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
            'legend=SOUTH' || chr(38) ||
            'enablelegend=YES' || chr(38) ||
            'pointlabel=NO' || chr(38) ||            
            'seriescolors=' || l_chart_colors || chr(38) ||
            'html=NO" >';

	--htp.p('l_image ' || l_image);
     
     end if;       

                
    return l_image;
    
end get_chart_image;
                                       

--------------------------------------------------
-- Function  Name : get_storage_usage_meter
-- Description    : Returns a meter showing %used Vs %Free
--
--                   INPUT : used,free
--                   OUTPUT : formatted number
--------------------------------------------------
   function get_storage_usage_meter(
      p_rawsize      in number,
      p_used_percent in number
   )
      return varchar2
   is
      l_data varchar2(32767);

   begin
   
      IF (p_rawsize != 0) THEN
	      l_data  := '<TABLE width=100 cellspacing=0 cellpadding=0>
			     <TR>
			        <TD align=center>
			           <TABLE width=75 height=10 border=0 class="RegionBorder" cellspacing=1 cellpadding=1>
			              <TR>
			                <TD bgcolor=#cc0000 height=3 width=' || p_used_percent || '%' || '>' || '<IMG BORDER="0" SRC="/myImages/dot.gif"></TD>
			                <TD bgcolor=#ffffff height=3 width=' || (100 - p_used_percent) || '%' || '>' || '<IMG BORDER="0" SRC="/myImages/dot.gif"></TD>
			              </TR>
			            </TABLE>
			         </TD>
                	         <TD align=left valign=middle><font face=Arial size=1>' || p_used_percent || '%' || '</font>
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
	p_summary   in summaryObject
   )
      return varchar2
   is

      l_winprop3  varchar2(256);
      l_data      varchar2(2048);
      
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
      p_summary    in summaryObject,
      p_tag	   in VARCHAR2,
      p_issue_type in VARCHAR2 DEFAULT 'ISSUE', -- ISSUE or WARNING
      p_host_type  in VARCHAR2 DEFAULT 'ALL_HOSTS' -- Can be one of ALL_HOSTS , SUMMARIZED_HOSTS, FAILED_HOSTS , NOT_COLLECTED_HOSTS, ISSUE_HOSTS
   )
      return varchar2
   is

      l_data    varchar2(2048) := NULL;
      l_winprop varchar2(2048) := 'toolbar=yes,location=no,directories=yes,status=yes,menubar=yes,scrollbars=yes,resizable=yes,left=50,top=50,width=900,height=600';                                
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
      p_summary    in summaryObject ,
      p_tag	   in VARCHAR2
   )
      return varchar2
   is

      l_data    varchar2(2048) := NULL;
      l_winprop varchar2(2048) := 'toolbar=yes,location=no,directories=yes,status=yes,menubar=yes,scrollbars=yes,resizable=yes,left=50,top=50,width=900,height=600';                                

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
   function get_hostdetails_fmt_link(
      p_summary    in summaryObject
   )
      return varchar2
   is
              
	l_data    varchar2(2048);
	l_winprop varchar2(2048) := 'toolbar=yes,location=no,directories=yes,status=yes,menubar=yes,scrollbars=yes,resizable=yes,left=50,top=50,width=900,height=550';           

   begin

	IF p_summary.id IS NULL THEN
		RETURN p_summary.name;
	END IF;

         l_data        := '''/pls/'
           	            || UTIL_PORTAL.get_portal_schema
                	    || '/'
	                    || UTIL_PORTAL.get_portlet_schema
        	            || '.STORAGE.display_host_details?p_id='
	                    || p_summary.id                        
                            || '''';
   	
	l_data := HTF.anchor(curl => 'javascript:;',
     	 	      	      cattributes => 'style="color: blue" onMouseOver="return false; "onMouseOut="return  false; "  onClick="javascript:windowhandle=window.open(' || l_data || ',''' || 'issuewindow' ||  ''', ' || '''' || l_winprop || ''''  || ');windowhandle.focus();"  ',
                       	      ctext =>  p_summary.name);   
            		
      	
	return l_data;                                            	               
       
    end get_hostdetails_fmt_link;


--------------------------------------------------
-- Procedure Name : l_create_name
-- Description    : Local procedure to create names to be used.
--                   INPUT : Portlet     - Portlet instance.
--                           Name        - Preference name to be created.
--                           Type        - Type to be associated.
--                           Description - Description of preference name.
--------------------------------------------------
   procedure l_create_name (
      p_portlet_instance      in  WWPRO_API_PROVIDER.portlet_instance_record,
      p_name                  in  varchar2,
      p_type_name             in  varchar2,
      p_description           in  varchar2)
   is
      l_reference_path        varchar2(255) :=
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
      p_preference_path  in varchar2,
      p_data_name        in varchar2 
   )
      return varchar2
   is
      l_custom_1              varchar2(255);


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
   procedure l_draw_footnote 
   is
      l_footnote             varchar2(1024);
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

--------------------------------------------------
-- Procedure Name : get_dc_lob_report
-- Description    : Refresh the storage summary with newer display type 
--                   INPUT : ReferencePath  - Portlet instance id
--                           Page URL       - URL of the calling page 
--                           Display Type   - datacenter
--			     LOB	    - LOB
--			     chart type
--------------------------------------------------
   procedure get_dc_lob_report (
      p_reference_path        in    varchar2,
      p_page_url              in    varchar2,
      p_datacenter	      in    varchar2 DEFAULT 'ALL',
      p_lob		      in    varchar2 DEFAULT 'ALL',
      p_chart_type            in    varchar2 DEFAULT 'PIE'
   )
   is

	l_page_url   varchar2(4096); 
	l_group_name stormon_group_table.name%TYPE;
	l_group_type stormon_group_table.type%TYPE;

   begin

	--htp.p(' HERE'||'<BR>');

	IF p_datacenter = 'ALL' AND p_lob = 'ALL' THEN
		l_group_name := 'ALL';
		l_group_type := 'REPORTING_ALL';
	ELSIF p_datacenter = 'ALL' THEN
		l_group_name := p_lob;
		l_group_type := 'REPORTING_LOB';
	ELSIF p_lob = 'ALL' THEN
		l_group_name := p_datacenter;
		l_group_type := 'REPORTING_DATACENTER';
	ELSE
		l_group_name := p_datacenter||'-'||p_lob;
		l_group_type := 'REPORTING_DATACENTER_LOB';
	END IF;

	STORAGE.CHANGE_DISPLAY(p_reference_path,p_page_url,l_group_name,l_group_type,p_chart_type);
      
   end get_dc_lob_report;

--------------------------------------------------
-- Procedure Name : change_display
-- Description    : Refresh the storage summary with newer display type 
--                   INPUT : ReferencePath  - Portlet instance id 
--                           Page URL       - URL of the calling page 
--                           Display Type   - Type to display metric values 
--------------------------------------------------
   procedure change_display (
      p_reference_path        in    varchar2,
      p_page_url              in    varchar2,
      p_group_name     in    varchar2 DEFAULT 'ALL',
      p_group_type     in    varchar2 DEFAULT 'REPORTING_ALL',
      p_chart_type            in    varchar2 DEFAULT 'PIE',
      p_report_type	      in    VARCHAR2 DEFAULT NULL,
      p_host_type             in    varchar2 DEFAULT 'ALL_HOSTS',
      p_orderfield            in    integer  DEFAULT 3, 
      p_ordertype             in    varchar2 DEFAULT 'DEFAULT'
   )
   is
      l_page_url   varchar2(4096); 
      
   begin


      l_page_url := p_page_url || chr(38) ||
		'p_group_name='|| p_group_name             || chr(38) ||
		'p_group_type='|| p_group_type            || chr(38) ||
		'p_chart_type='       || p_chart_type        || chr(38) ||
		'p_report_type='      || p_report_type     || chr(38) ||
		'p_host_type='        || p_host_type           || chr(38) ||
		'p_orderfield='      || p_orderfield     || chr(38) || 
		'p_ordertype='       || p_ordertype;
       

      OWA_UTIL.redirect_url(l_page_url);
      
   end change_display;

--------------------------------------------------
--------------------------------------------------
-- Procedure Name : store_session_data
-- Description    : Procedure to save Portlet eidt page selections
--          INPUT : ReferencePath   - Path where preferences stored.
--                : BackPageUrl     - URL to the previous page.
--                : Type            - Type .
--------------------------------------------------
   procedure store_session_data (
      p_reference_path        in varchar2,
      p_back_page_url         in varchar2,
      p_portlet_title         in varchar2 DEFAULT NULL,
      p_type                  in varchar2 DEFAULT NULL
   )
   is
   begin

      UTIL_PORTAL.store_value( 'type', p_type, p_reference_path );
      OWA_UTIL.redirect_url(p_back_page_url);

      EXCEPTION
         WHEN OTHERS THEN
            HTP.p( 'Exception thrown in store_session_data : ' || sqlerrm );

   end store_session_data;
--------------------------------------------------

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
      p_group_name       	in varchar2, 
      p_group_type       	in varchar2,
      p_chart_type         	in varchar2,
      p_report_type      	in VARCHAR2,
      p_host_type            	in varchar2,
      p_orderfield      	in INTEGER,
      p_ordertype       	in varchar2
      )
   return boolean
   is
      -- target  variables
      l_custom_1              varchar2(32767);

      runvar1                 integer;
      runvar2                 integer;

      
      l_ref_path varchar2(255);


begin
      l_ref_path := p_portlet_record.reference_path;

      display_storage_summary(p_group_name,
                              p_group_type,    
			      p_chart_type,                          
			      p_report_type,
			      p_host_type,	
                              p_orderfield, 
                              p_ordertype, 
                              PREFERENCE_PATH ||  l_ref_path,
                              replace(p_portlet_record.page_url,chr(38),'%26'));                               

      display_tip(stringTable('<BR>1. Aggregation not done for hosts with Issues or hosts with no data collection',
			      '<BR>2. Refer to FAQ for resolving outstanding Issues ')
		);

      HTP.formClose();
      
      return true;
      

   end l_show_all;
--------------------------------------------------

--------------------------------------------------
-- Procedure Name : l_show
-- Description    : Local procedure to display Storage UI.
--                   INPUT : PortletRecord   - Record of portlet instance.
--------------------------------------------------
   procedure l_show (
	      p_portlet_record        in out WWPRO_API_PROVIDER.portlet_runtime_record
	)
   is

      l_portlet_info          WWPRO_API_PROVIDER.portlet_record;
      l_title                 varchar2(4096);
      l_has_customize         boolean := false;
      l_has_edit              boolean := false;
      l_group_name	      stormon_group_table.name%TYPE;            
      l_group_type	      stormon_group_table.type%TYPE;
      l_chart_type            varchar2(1024) := 'PIE';   
      l_report_type	      VARCHAR2(1024);
      l_host_type             varchar2(1024) := 'ALL_HOSTS';               
      l_orderfield            INTEGER := 3;            
      l_ordertype             varchar2(1024) := 'DEFAULT';            
      l_result                boolean;
      l_ref_path              varchar2(255);
      l_names                 OWA.VC_ARR;
      l_values                OWA.VC_ARR;

      l_dc		      stormon_group_table.name%TYPE;
      l_lob		      stormon_group_table.type%TYPE;

   begin

      -- Set Edit/Customize links only if URL params are invalid
      if (UTIL_PORTAL.get_portal_user like '%ADMIN%') then
         l_has_edit      := true;
      else
         l_has_customize := false;
      end if;
            
      l_portlet_info := get_portlet_info(
                           p_portlet_record.provider_id,
                           p_portlet_record.language);
                                        
      l_ref_path :=  p_portlet_record.reference_path;                    


      WWPRO_API_PARAMETERS.retrieve( l_names, l_values );

      FOR runvar in 1..l_names.count loop

	IF (l_names(runvar) = 'p_group_name' ) THEN
      	   l_group_name := l_values(runvar);
	ELSIF (l_names(runvar) = 'p_group_type' ) THEN
      	   l_group_type := l_values(runvar);
	ELSIF (l_names(runvar) = 'p_chart_type' ) THEN
      	   l_chart_type := l_values(runvar);
	ELSIF (l_names(runvar) = 'p_report_type' ) THEN
      	   l_report_type := l_values(runvar);
	ELSIF (l_names(runvar) = 'p_host_type' ) THEN
      	   l_host_type := l_values(runvar);
	ELSIF (l_names(runvar) = 'p_orderfield' ) THEN
      	   l_orderfield := l_values(runvar);
	ELSIF (l_names(runvar) = 'p_ordertype' ) THEN
      	   l_ordertype := l_values(runvar);
	END IF;

      END LOOP;
      
      if (l_group_name is null ) then
          l_group_name := 'ALL';
      end if;

      if (l_group_type is null ) then
          l_group_type := 'REPORTING_ALL';
      end if;

     if (l_chart_type is null ) then
          l_chart_type := 'PIE';
      end if;   

      if (l_report_type is null ) then
	IF l_group_type = 'REPORTING_DATACENTER_LOB' THEN		
		l_report_type := 'HOSTS';
	ELSE	
	   	l_report_type := 'GROUPS';
	END IF;
      end if;
      
      if (l_host_type is null ) then
          l_host_type := 'ALL_HOSTS';
      end if;
         
      if (l_orderfield is null ) then
          l_orderfield := 3;
      end if;      

      if (l_ordertype is null ) then
          l_ordertype := 'DEFAULT';
      end if;                    

      STORAGE.GET_DC_LOB_FROM_NAME(l_group_name,l_group_type,l_dc,l_lob);

      IF l_report_type = 'HOSTS' THEN

	      if l_host_type = 'FAILED_HOSTS' then

	 	l_title := 'Hosts with No Storage Summaries in '|| STORAGE.GET_LOB_DC_TITLE(l_dc,l_lob);

	      elsif l_host_type = 'ISSUE_HOSTS' then

	 	l_title := 'Hosts with Issues in '||STORAGE.GET_LOB_DC_TITLE(l_dc,l_lob);
	  
	      elsif l_host_type = 'SUMMARIZED_HOSTS' then

   		l_title := 'Storage Summary for Hosts in '|| STORAGE.GET_LOB_DC_TITLE(l_dc,l_lob);

	      elsif l_host_type = 'ALL_HOSTS' then
	
		   l_title := 'Storage Summary for all Hosts in  '|| STORAGE.GET_LOB_DC_TITLE(l_dc,l_lob);
	  
	      end if;

    ELSE

	 l_title := 'Storage Summary    '||STORAGE.GET_LOB_DC_TITLE(l_dc,l_lob);	      

     END IF;

      if (p_portlet_record.has_title_region) then
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

      HTP.P('</script>');
      

--RJKUMAR to check this

-- the get_dc_lob_report javascript
      HTP.formOpen(curl        => UTIL_PORTAL.get_portlet_schema ||'.STORAGE.get_dc_lob_report',
                   cmethod     => 'get', 
                   ctarget     => NULL,
                   cenctype    => NULL,
                   cattributes => 'name="showform_' ||p_portlet_record.reference_path || '"');

      HTP.p('<script LANGUAGE=JavaScript>
              function link_get_dc_lob_report(object1,object2,object3) {
                 var dc=null;
                 var lob=null;
                 var chart_type=null;	
                 
                 dc =  object1[object1.selectedIndex].value;
                 lob = object2[object2.selectedIndex].value;
                 chart_type = object3[object3.selectedIndex].value; ' || 
                'document.forms["showform_' ||
                                   p_portlet_record.reference_path || '"].p_datacenter.value=dc; ' ||

                'document.forms["showform_' ||
                                   p_portlet_record.reference_path || '"].p_lob.value=lob; ' ||

                'document.forms["showform_' ||
                                   p_portlet_record.reference_path || '"].p_chart_type.value=chart_type; ' ||                                   
                                                                                                 
                'document.forms["showform_' ||
                                   p_portlet_record.reference_path || '"].submit(); ' ||
                ' }</script>');	

      HTP.p('<INPUT TYPE=hidden
                    name=p_reference_path
                    value="' || PREFERENCE_PATH ||
                          p_portlet_record.reference_path || '">');

      HTP.p('<INPUT TYPE=hidden
                    name=p_page_url
                    value="' || p_portlet_record.page_url || '">');

      HTP.p('<INPUT TYPE=hidden
                    name=p_datacenter
                    value="' || '' || '">');

      HTP.p('<INPUT TYPE=hidden
                    name=p_lob
                    value="' || '' || '">');
                                        
      HTP.p('<INPUT TYPE=hidden
                    name=p_chart_type
                    value="' || '' || '">');

      HTP.formClose;     


-- The change_display java script
      HTP.formOpen(curl        => UTIL_PORTAL.get_portlet_schema ||'.STORAGE.change_display',
                   cmethod     => 'get', 
                   ctarget     => NULL,
                   cenctype    => NULL,
                   cattributes => 'name="showform2_' || p_portlet_record.reference_path || '"');


--RJKUMAR Check if this is ok, I Dont understand the significance of this block
      HTP.p('<script LANGUAGE=JavaScript>

              function link_change_display(parent_name,parent_type,chart_type,report_type,host_type,orderfield,ordertype) {
                document.forms["showform2_' ||
                                   p_portlet_record.reference_path || '"].p_group_name.value=parent_name; ' ||

                'document.forms["showform2_' ||
                                   p_portlet_record.reference_path || '"].p_group_type.value=parent_type; ' ||

                'document.forms["showform2_' ||
                                   p_portlet_record.reference_path || '"].p_chart_type.value=chart_type; ' ||       

                'document.forms["showform2_' ||
                                   p_portlet_record.reference_path || '"].p_report_type.value=report_type; ' ||     

                'document.forms["showform2_' ||
                                   p_portlet_record.reference_path || '"].p_host_type.value=host_type; ' ||       

                'document.forms["showform2_' ||
                                   p_portlet_record.reference_path || '"].p_orderfield.value=orderfield; ' ||                                                                     
                'document.forms["showform2_' ||
                                   p_portlet_record.reference_path || '"].p_ordertype.value=ordertype; ' ||                                                                     
                'document.forms["showform2_' ||
                                   p_portlet_record.reference_path || '"].submit(); ' ||
                ' }
           </script>');


      HTP.p('<INPUT TYPE=hidden
                    name=p_reference_path
                    value="' || PREFERENCE_PATH ||
                          p_portlet_record.reference_path || '">');

      HTP.p('<INPUT TYPE=hidden
                    name=p_page_url
                    value="' || p_portlet_record.page_url || '">');

      HTP.p('<INPUT TYPE=hidden
                    name=p_group_name
                    value="' || '' || '">');

      HTP.p('<INPUT TYPE=hidden
                    name=p_group_type
                    value="' || '' || '">');
                                        
      HTP.p('<INPUT TYPE=hidden
                    name=p_chart_type
                    value="' || '' || '">');

      HTP.p('<INPUT TYPE=hidden
                    name=p_report_type
                    value="' || '' || '">');

      HTP.p('<INPUT TYPE=hidden
                    name=p_host_type
                    value="' || '' || '">');
         
      HTP.p('<INPUT TYPE=hidden
                    name=p_orderfield
                    value="' || '' || '">');

      HTP.p('<INPUT TYPE=hidden
                    name=p_ordertype
                    value="' || '' || '">');

      HTP.formClose;                    

      l_result := l_show_all(p_portlet_record, 
                             l_group_name,
                             l_group_type,
			     l_chart_type,
			     l_report_type,
                             l_host_type,                              
			     l_orderfield,
			     l_ordertype
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
   procedure l_show_about (
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
   procedure l_show_help (
      p_portlet_record   in out WWPRO_API_PROVIDER.portlet_runtime_record)
   is
   begin

      HTP.p('<script LANGUAGE=JavaScript>');
      HTP.p('PopUp(''/myHelp/storage.html'')');         
      HTP.p('</script>');
      
   end l_show_help; -- procedure end of l_show_help;
--------------------------------------------------
--------------------------------------------------
-- Procedure Name : l_show_edit_defaults
-- Description    : Local procedure to display Service Details Edit Defaults.
-- INPUT          : PortletRecord   - Record of portlet instance.
--------------------------------------------------
   procedure l_show_edit_defaults (
      p_portlet_record        in out WWPRO_API_PROVIDER.portlet_runtime_record)
   is
      l_form_name             varchar2(128);
      l_type                  varchar2(1024);
      l_portlet_info          WWPRO_API_PROVIDER.portlet_record;

   begin




      -- Obtain all values from session storage.
      l_type := UTIL_PORTAL.load_value(
                         'type',
                         PREFERENCE_PATH ||
                         p_portlet_record.reference_path
                        );


      -- replace all special characters by '_' underscore
      l_form_name := 'reportform';

      -- generate form names
      -- first form is the main form and second one is the dumy one
      -- mainly for list boxes
      l_form_name := UTIL_PORTAL.FORM_PREFIX_1 || l_form_name;

      UTIL_PORTAL.include_portal_stylesheet;

      UTIL_PORTAL.draw_portlet_edit_page_header(
         p_portlet_record,
         PREFERENCE_PATH,
         l_portlet_info.title,
         'STORGE.store_session_data',
         l_form_name );

      HTP.tableOpen(cborder      => 'border=0',
                    calign       => 'center',
                    cattributes  => 'width=50% cellspacing=5 cellpadding=2 ' ||
                                    'class="OraBGAccentDark"' );

      -- Storage Type
      HTP.tableRowOpen;
      HTP.tableHeader(cvalue => WWUI_API_PORTLET.portlet_subheadertext(
                                 'Type'),
                      cnowrap => ' ',
                      cattributes => 'align=left class="OraTableColumnHeader"');
      HTP.tableHeader(cvalue => '<INPUT TYPE=TEXT NAME=p_rep_title ' ||
                                'SIZE=75 value="' ||
                                'TEST' ||'">',
                      cattributes => 'align=left class="OraTableColumnHeader"');
      HTP.tableRowClose;


      HTP.tableClose;

      HTP.formClose;

      WWUI_API_PORTLET_DIALOG.close_dialog();

      EXCEPTION
         WHEN OTHERS THEN
            HTP.p( 'Exception thrown in l_show_edit_defaults : ' || sqlerrm );

   end l_show_edit_defaults; -- procedure end of l_show_edit_defaults;
--------------------------------------------------

--------------------------------------------------
-- Procedure Name : l_show_details
-- Description    : Local procedure to display storage Details.
--                   INPUT : PortletRecord   - Record of portlet instance.
--------------------------------------------------
   procedure l_show_details (
      p_portlet_record    in out WWPRO_API_PROVIDER.portlet_runtime_record)
   is
   begin
      HTP.p('Not implemented');
   end l_show_details; -- procedure end of l_show_details;
--------------------------------------------------

--------------------------------------------------
-- Procedure Name : l_show_preview
-- Description    : Local procedure to display storage Preview.
--                   INPUT : PortletRecord   - Record of portlet instance.
--------------------------------------------------
   procedure l_show_preview (
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
      p_language          in  varchar2)
   return WWPRO_API_PROVIDER.portlet_record
   is
      portlet_info        WWPRO_API_PROVIDER.portlet_record;
   begin
      portlet_info.name                     := 'STORAGE';
      portlet_info.id                       :=
         STORAGE_PROVIDER.PORTLET_STORAGE;

      portlet_info.title                    := 'Storage';
      portlet_info.description              :=
         'DC,LOB and Hosts Storage';

      portlet_info.provider_id              := p_provider_id;
      portlet_info.language                 := p_language;

      portlet_info.timeout                  := 300;
      portlet_info.timeout_msg              :=
         'Storage Portlet timed out: Query took longer than '||
         portlet_info.timeout ||
         ' seconds';

      portlet_info.api_version              := WWPRO_API_PROVIDER.API_VERSION_1;

      portlet_info.has_show_edit            := false;
      portlet_info.has_show_edit_defaults   := true;
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
      p_reference_path    in varchar2)
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
   procedure register (
      p_portlet_instance      in  WWPRO_API_PROVIDER.portlet_instance_record)
   is
      l_reference_path        varchar2(255) :=
         PREFERENCE_PATH||p_portlet_instance.reference_path;
   begin

      WWPRE_API_NAME.create_path(l_reference_path);

      l_create_name(p_portlet_instance, 'group_name',   'STRING', 'group_name');
      l_create_name(p_portlet_instance, 'group_type',  'STRING', 'group_type');    
      l_create_name(p_portlet_instance, 'chart_type',  'STRING', 'chart_type');      
      l_create_name(p_portlet_instance, 'report_type',  'STRING', 'report_type');  
      l_create_name(p_portlet_instance, 'host_type',  'STRING', 'host_type');  
      l_create_name(p_portlet_instance, 'orderfield',  'INTEGER', 'orderfield');      
      l_create_name(p_portlet_instance, 'ordertype',  'STRING', 'ordertype');      
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
   procedure deregister (
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
   procedure show (
      p_portlet_record        in out WWPRO_API_PROVIDER.portlet_runtime_record)
   is
      l_portlet_info          WWPRO_API_PROVIDER.portlet_record;
   begin

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
         l_show_details(p_portlet_record);

      elsif (p_portlet_record.exec_mode = WWPRO_API_PROVIDER.MODE_PREVIEW)
      then
         l_show_preview(p_portlet_record);
      elsif (p_portlet_record.exec_mode = WWPRO_API_PROVIDER.MODE_SHOW_EDIT_DEFAULTS)
      then
         l_show_edit_defaults(p_portlet_record);         

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
   procedure copy (
      p_copy_portlet_info     in WWPRO_API_PROVIDER.copy_portlet_record)
   is
      src                     varchar2(100);
      dst                     varchar2(100);
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
      p_language              in  varchar2)
   return WWPRO_API_PROVIDER.portlet_parameter_table
   is
      param_tab               WWPRO_API_PROVIDER.portlet_parameter_table;
   begin

      return param_tab;

   end describe_parameters; -- function end of describe_parameters
--------------------------------------------------
--------------------------------------------------
-- Procedure Name : display_selection_option
-- Description    : Display data centers or Lobs for selection 
--          INPUT : 
--------------------------------------------------
procedure display_selection_option (
  p_datacenter	in  varchar2,
  p_lob		in  varchar2,  
  p_chart_type  in  varchar2,
  p_reference_path  in  varchar2,
  p_page_url        in  varchar2   
)
is
  runvar1                 integer;
  l_dc_combo_box          varchar(10240);   
  l_lob_combo_box          varchar(10240);   
  l_disp_combo_box        varchar(10240);       
  l_chart_type_list          stringTable := stringTable('PIE','VBAR','HBAR'); 
  l_reference_path        varchar2(128);

begin   
            
       l_reference_path  := replace(p_reference_path,PREFERENCE_PATH,'');

       l_dc_combo_box := 'Data Center <select name="DC" >';
       
       for k in ( select 'ALL' dc from dual
                  union
                  select name dc from 
                  stormon_group_table
		  where type = 'REPORTING_DATACENTER'
                  order by 1 asc
       ) loop
            

          if (instr(k.dc,p_datacenter ) > 0)   then            
             l_dc_combo_box :=  l_dc_combo_box ||
                             '<option value="' || replace(k.dc,' ','%20') ||
                             '" selected>' || k.dc || '</option>';                                    
          else               
             l_dc_combo_box :=  l_dc_combo_box ||
                             '<option value="' || replace(k.dc,' ','%20') ||
                             '" >' || k.dc || '</option>';                                    
                                
          end if;    
          
       end loop;  
       l_dc_combo_box := l_dc_combo_box || '</select>';
       
       l_lob_combo_box := 'LOB <select name="LOB" >';
       
       for k in ( select 'ALL' lob from dual
                  union
                  select name lob from 
                  stormon_group_table
		  where type = 'REPORTING_LOB'
                  order by 1 asc
             ) loop
          if (instr(k.lob,p_lob ) > 0)   then            
             l_lob_combo_box :=  l_lob_combo_box ||
                             '<option value="' || replace(k.lob,' ','%20') ||
                             '" selected>' || k.lob || '</option>';                                    
          else               
             l_lob_combo_box :=  l_lob_combo_box ||
                             '<option value="' || replace(k.lob,' ','%20') ||
                             '" >' || k.lob || '</option>';                                    
                                
          end if;    
       end loop;  
       l_lob_combo_box := l_lob_combo_box || '</select>';

       l_disp_combo_box := 'Chart Type <select name="CHARTTYPE" >';
              
       for k in 1..l_chart_type_list.count loop

          if (instr(l_chart_type_list(k),p_chart_type ) > 0)   then            
             l_disp_combo_box :=  l_disp_combo_box ||
                             '<option value="' || replace(l_chart_type_list(k),' ','%20') ||
                             '" selected>'     || replace(replace(l_chart_type_list(k),'VBAR','Vertical Bar'),'HBAR','Horizontal Bar') || '</option>';                                    
          else               
             l_disp_combo_box :=  l_disp_combo_box ||
                             '<option value="' || replace(l_chart_type_list(k),' ','%20') ||
                             '" >'             || replace(replace(l_chart_type_list(k),'VBAR','Vertical Bar'),'HBAR','Horizontal Bar') || '</option>';                                    
                                
          end if;           

       end loop;   
       l_disp_combo_box := l_disp_combo_box || '</select>';
       

      HTP.formClose;
      
      HTP.formOpen(curl        => UTIL_PORTAL.get_portlet_schema ||
                                  '.STORAGE.get_dc_lob_report',
                   cmethod     => 'get', 
                   ctarget     => NULL,
                   cenctype    => NULL,
                   cattributes => 'name="showform1_' ||
                                   l_reference_path || '"');

                     
       HTP.tableopen(cborder      => 'border=0',
                     calign       => 'center',
                     cattributes  => 'width=100% cellspacing=0 cellpadding=4 class="RegionBorder"');
   

       HTP.tablerowopen(calign      => 'center',
                        cvalign     => 'middle',
                        cattributes => 'bgcolor=' );
                        

       HTP.tableheader(cvalue      => WWUI_API_PORTLET.portlet_text(                                                                             
                                      l_dc_combo_box  ,1), 
                       cnowrap     => ' ', 
                       cattributes => 'width=15% align=left bgcolor=' || TABLE_HEADER_COLOR);                        


       HTP.tableheader(cvalue      => WWUI_API_PORTLET.portlet_text(                                                                             
                                      l_lob_combo_box  ,1), 
                       cnowrap     => ' ', 
                       cattributes => 'width=15% align=left bgcolor=' || TABLE_HEADER_COLOR);                        

       HTP.tableheader(cvalue      => WWUI_API_PORTLET.portlet_text(                                                                             
                                      l_disp_combo_box  ,1), 
                       cnowrap     => ' ', 
                       cattributes => 'width=15% align=left bgcolor=' || TABLE_HEADER_COLOR);                        
                       
      HTP.tableheader(calign => 'left',
                      cvalue => '<INPUT TYPE=BUTTON NAME=GO 
                                 value="GO"
                                 onClick="javascript:link_get_dc_lob_report(document.showform1_' || l_reference_path || '.DC,' || 'document.showform1_' || l_reference_path || '.LOB,' || 'document.showform1_' || l_reference_path || '.CHARTTYPE' || ');">',
                      cattributes  => 'width=5% bgcolor=' || TABLE_HEADER_COLOR);    

      HTP.tableheader(calign => 'left',
                      cvalue => BLANK,
                      cattributes  => 'width=60% bgcolor=' || TABLE_HEADER_COLOR);    

      HTP.tableheader( cvalue      => WWUI_API_PORTLET.portlet_text(
					HTF.anchor(
                                    		curl => 'javascript:PopUp(''/myHelp/storage.html'');', 
                                         	cattributes => ' style="color: blue" style=""  ',
                                         	ctext => '<B>FAQ ?</B>' ) 
                                               ,1),
                       cnowrap     => ' ',
                       cattributes => 'align=right width=5% bgcolor=' || TABLE_HEADER_COLOR);
 
      HTP.tablerowclose(); 

      HTP.tableclose(); 
                                                                               
end;



------------------------------------------------
-- PRINT POTLET TABLE OPEN
------------------------------------------------
PROCEDURE print_ptable_open(p_border varchar2 default 'border=0',
                            p_align  varchar2 default 'center',
                            p_attrib varchar2 default 'width=100% cellspacing=1 cellpadding=4'
                           )   
IS

BEGIN
       HTP.tableopen(cborder      => 'border=0',
                     calign       => 'center',
                     cattributes  => p_attrib);
END;

------------------------------------------------
-- PRINT POTLET TABLE CLOSE
------------------------------------------------
PROCEDURE print_ptable_close IS

BEGIN
       HTP.tableclose;
END;


------------------------------------------------
-- PRINT POTLET ROW OPEN
------------------------------------------------
PROCEDURE print_prow_open (
     p_rowcolor   varchar2 DEFAULT NULL,
     p_rowbgcolor varchar2 DEFAULT NULL
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
-- PRINT POTLET ROW CLOSE
------------------------------------------------
PROCEDURE print_prow_close  IS

BEGIN
       HTP.tablerowclose;
END;

------------------------------------------------
-- PRINT A COLORED LINE 
------------------------------------------------
PROCEDURE print_line(
   p_attrib  in varchar2
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
PROCEDURE print_pcol (p_col      varchar2  DEFAULT NULL,
                      p_align    varchar2  DEFAULT 'RIGHT',
                      p_width    varchar2  DEFAULT NULL, 
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
--PROCEDURE print_phcol (
--			p_col varchar2    DEFAULT NULL,
--			p_align varchar2  DEFAULT 'CENTER',
--			p_width varchar2  DEFAULT NULL
--                    ) IS

--BEGIN
--      HTP.tabledata(cvalue      => WWUI_API_PORTLET.portlet_subheadertext(
--                                     '<B>' || p_col || '</B>'),
--                    cnowrap     => '',
--                     cattributes => ' align=' || p_align ||
--                                    ' width=' || p_width );
--END;

------------------------------------------------
-- PRINT POTLET HEADER COLUMN
------------------------------------------------
PROCEDURE print_phcol (p_col     varchar2    DEFAULT NULL,
                       p_align   varchar2    DEFAULT 'CENTER',
                       p_width   varchar2    DEFAULT NULL,
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
PROCEDURE print_pheader(p_title  varchar2  DEFAULT NULL,
                        p_align  varchar2  DEFAULT 'LEFT')  IS

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
procedure display_storage_summary (
  p_group_name               in  varchar2,
  p_group_type              in  varchar2,
  p_chart_type          in  varchar2,  
  p_report_type	     in	 VARCHAR2,
  p_host_type             in  varchar2, 
  p_orderfield       in  integer,  
  p_ordertype        in  varchar2,  
  p_reference_path   in  varchar2,
  p_page_url         in  varchar2 
)
is
   
	p_datacenter 	VARCHAR2(255);
	p_lob		VARCHAR2(255);
  begin

      get_dc_lob_from_name(p_group_name,p_group_type,p_datacenter,p_lob);

      display_selection_option (p_datacenter,
                                p_lob,
                                p_chart_type,
                                p_reference_path,
                                p_page_url
                               ); 

       STORAGE. classical_drill_down(p_group_name,p_group_type,p_chart_type,p_report_type,p_host_type,p_orderfield,p_ordertype);       
    null;
end;
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
Procedure format_data_in_html (
   p_title         in  varchar2,
   p_subtitle      in  varchar2,   
   p_numrows       in  integer,
   p_numcols       in  integer,
   p_series_name   in  varchar2,
   p_chart_type    in  varchar2,
   p_enablelegend  in  varchar2 DEFAULT 'YES',
   p_yaxis_title   in  varchar2 DEFAULT '',
   p_suffix        in  varchar2 DEFAULT ''
)
is
   l_serieswidth  number;

begin

      if (p_chart_type = 'LINE') then
         l_serieswidth :=3;
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
      p_period         in varchar2,
      p_period_t       in varchar2,      
      p_storage_type   in varchar2,
      p_id             in varchar2
   )
      return varchar2
   is
      l_data   varchar2(1024);
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
      p_period          in varchar2,   
      p_storage_type    in varchar2,
      p_storage_type_t  in varchar2,      
      p_id              in varchar2)
      return varchar2
   is
      l_data           varchar2(1024);
      l_storage_type   varchar2(256);

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
-- Procedure  Name : l_draw_graph
-- Description    : Global function to invoke servlet to
--                  generate HTML graph chart.
--------------------------------------------------
   Procedure l_draw_graph(
      p_id               in varchar2,
      p_period           in varchar2, 
      p_storage_type     in varchar2
  )
   is
	l_legend          varchar2(256);
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
	
    EXECUTE IMMEDIATE '
			SELECT COUNT(*) ,
			MAX('||l_maxsize_check_fld||')
			FROM '||l_tablename||' 
			WHERE id = :id 
			AND collection_timestamp BETWEEN :startdate AND :enddate' 
	INTO  l_count , l_max_value USING p_id,l_startdate,l_enddate;
	
	l_unit_element := l_check_unit(l_max_value);

	IF l_count > 0 THEN
	      format_data_in_html (
	      ' ',
	      ' ',
	      --l_title || ' History from '||TO_CHAR(l_startdate,'DD-MON-YY')||' to '||TO_CHAR(l_enddate,'DD-MON-YY') ,              
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
		SELECT collection_timestamp, sizeb, used  
		FROM  
		( 
			SELECT	collection_timestamp, 
				('||l_flds(1)||'/'||l_storageFactor(l_unit_element)||') sizeb , 
				('||l_flds(2)||'/'||l_storageFactor(l_unit_element)||') used 
			FROM '||l_tablename||' 
			WHERE id = :id
			AND	collection_timestamp BETWEEN :startdate AND :enddate  
		)
		ORDER BY collection_timestamp ASC';
              
    OPEN l_historycursor FOR l_sqlstmt USING p_id,l_startdate,l_enddate;

    LOOP

        FETCH l_historycursor INTO l_collection_timestamp,l_size, l_used;

        EXIT WHEN l_historycursor%NOTFOUND;
    
	DBMS_OUTPUT.PUT_LINE(to_char(l_collection_timestamp,'YYYYMMDD HH24:MI:SS') || ',' || l_size|| ',' || l_used );
	htp.prn(to_char(l_collection_timestamp,'YYYYMMDD') || ' 00:00:00' || ',' || l_size|| ',' || l_used ||   ';' );            

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
-- Procedure Name : display_storage_history
-- Description    : display storage history in a popup window
--                   INPUT :
--------------------------------------------------
   procedure display_storage_history (
      p_period           in varchar2,
      p_storage_type     in varchar2,
      p_id               in storage_summaryObject.id%TYPE
   )
   is


   l_base_url     varchar2(256);
   l_1w_url       varchar2(1024);
   l_1q_url       varchar2(1024);
   l_1m_url       varchar2(1024);
   l_1y_url       varchar2(1024);
   l_range_url    varchar2(4096);

   l_db_url       varchar2(1024);
   l_lfs_url      varchar2(1024);
   l_disk_url     varchar2(1024);
   l_nfs_url      varchar2(1024);
   l_total_url    varchar2(1024);
   l_type_url     varchar2(4096);

   l_common_url   varchar2(4096);
   l_ref_path     varchar2(255);
   l_graph_image  varchar2(4096);

   l_dk_gray_bg_color	  VARCHAR2(10) := '#999999'; --#999999
   l_gray_bg_color	  VARCHAR2(10) := '#cccccc'; --#cccccc	
   l_beige_bg_color       VARCHAR2(10) := '#CCCC8C';
   l_title                VARCHAR2(1024); 

   l_summaryObject   summaryObject;

  begin

	BEGIN			

			SELECT	summaryObject(
	 			ROWNUM,
				name,			
 				id,        
				type,
	 			timestamp,					-- timestamp
 				collection_timestamp,				-- collection_timestamp
 				hostcount,					-- hostcount
 				actual_targets,					-- actual_targets
	 			issues,						-- issues
 				hostcount-(actual_targets+issues),		-- not collected
 				warnings,					-- warnings
 				summaryFlag,					-- summaryFlag
 				application_rawsize     ,
 				application_size        ,
 				application_used        ,
 				application_free        ,
 				oracle_database_rawsize        ,
 				oracle_database_size        ,
 				oracle_database_used        ,
 				oracle_database_free        ,
 				local_filesystem_rawsize,
 				local_filesystem_size        ,
	 			local_filesystem_used        ,
 				local_filesystem_free        ,
 				nfs_exclusive_size        ,
 				nfs_exclusive_used        ,
 				nfs_exclusive_free        ,
 				nfs_shared_size                ,
 				nfs_shared_used                ,
 				nfs_shared_free                ,
 				volumemanager_rawsize        ,
 				volumemanager_size        ,
 				volumemanager_used        ,
 				volumemanager_free        ,
 				swraid_rawsize                ,
 				swraid_size                ,
 				swraid_used                ,
 				swraid_free                ,
 				disk_backup_rawsize        ,
 				disk_backup_size        ,
 				disk_backup_used        ,
 				disk_backup_free        ,
 				disk_rawsize                ,
 				disk_size                ,
 				disk_used                ,
 				disk_free                ,
 				rawsize                        ,
 				sizeb                        ,
 				used                        ,
 				free                        ,
 				vendor_emc_size                ,
 				vendor_emc_rawsize        ,
 				vendor_sun_size                ,
 				vendor_sun_rawsize        ,
 				vendor_hp_size                ,
 				vendor_hp_rawsize        ,
 				vendor_hitachi_size        ,
 				vendor_hitachi_rawsize        ,
 				vendor_others_size        ,
 				vendor_others_rawsize      ,
 				vendor_nfs_netapp_size     ,
 				vendor_nfs_emc_size        ,
 				vendor_nfs_sun_size        ,
				vendor_nfs_others_size )                                       
			INTO	l_summaryObject
			FROM	storage_summaryObject_view
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


    l_title := '<B>' || get_display_time(p_period) || '  '  ||
               get_display_storage(p_storage_type) || '  '  || 
               'History from' || '  '  || 
               get_display_range(p_period) ||
               '</B>';
               
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

    HTP.tableRowOpen;

    HTP.tableData( cvalue      => WWUI_API_PORTLET.portlet_text(l_title,1),
                  cnowrap     => ' ',
                  cattributes => 'align=left ');

    HTP.tableRowClose;


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
-- Procedure Name : display_host_details
-- Description    : display_host_details
--          INPUT : target name
--		  : target_id
-- 		  : table to sort
-- 		  : column to sort
-- 		  : order to sort
--------------------------------------------------
procedure display_host_details (
	p_id          IN varchar2,
	p_orderTable  IN INTEGER DEFAULT 2,	-- DISK TABLE
	p_orderfield  IN INTEGER DEFAULT 4,	-- SIZE
	P_orderType   IN VARCHAR2 DEFAULT 'DEFAULT'
)
IS

l_summaryObject	summaryObject;
l_messageList	stringTable;
l_queryString	VARCHAR2(4000);
l_orderString   VARCHAR2(2000);
l_results 	t_resultsRec;	
l_cursor   	sys_refcursor;
l_summary 	hostsummaryrec;
l_chart_names	stringTable;
l_chart_values	stringTable;
l_count         integer :=0;
l_clToggle	integer :=1;
l_row_color    	varchar2(24);
l_bg_color     	varchar2(24);
l_time		INTEGER := 0;
l_storage_link  varchar2(4096);

--------------------------------------------------
-- Function  Name : get_sorting_link
-- Description    : 
--
--                   INPUT :  group/host id
--                   OUTPUT : HREF for the group/host History
--------------------------------------------------
function get_sorting_link(
	v_column_name IN VARCHAR2, 
	v_ordertable  IN INTEGER,
	v_orderfield  IN INTEGER
)
RETURN varchar2
IS
      l_data 	   VARCHAR2(4000);
      l_ordertype  VARCHAR2(4);
      l_img_src    VARCHAR2(256);  
      l_winprop    varchar2(2048) := 'toolbar=no,location=no,directories=no,status=no,menubar=no,scrollbars=yes,resizable=yes,left=50,top=50,width=900,height=600'; 
      l_aname      varchar2(32);

BEGIN

      IF (v_ordertable = 2) THEN
        l_aname := '#disks';
      ELSIF (v_ordertable = 3) THEN
        l_aname := '#swraid';
      ELSIF (v_ordertable = 4) THEN
        l_aname := '#volumemanager';
      ELSIF (v_ordertable = 5) THEN
        l_aname := '#localfilesystem';
      ELSIF (v_ordertable = 6) THEN
        l_aname := '#nfs';
      ELSIF (v_ordertable = 7) THEN
        l_aname := '#database';
      END IF;

	IF 
		l_list_of_detailed_columns IS NOT NULL and 
		l_list_of_detailed_columns.EXISTS(v_ordertable) AND
		l_list_of_detailed_columns(v_ordertable) IS NOT NULL AND
		l_list_of_detailed_columns(v_ordertable).EXISTS(v_orderfield) AND
		l_list_of_detailed_columns(v_ordertable)(v_orderfield).field_name IS NOT NULL 
	THEN

		-- If the already sorted table/column combination then link should sort in reverse order
		IF 
			p_orderTable = v_ordertable AND
			p_orderfield = v_orderfield  
		THEN
 
			IF p_ordertype = 'DESC' 
			THEN
				l_ordertype := 'ASC';
			ELSIF p_ordertype = 'ASC' THEN
				l_ordertype := 'DESC';
			ELSIF   p_ordertype = 'DEFAULT' THEN

				IF l_list_of_detailed_columns(v_ordertable)(v_orderfield).order_type = 'DESC' 
				THEN
					l_ordertype := 'ASC';
				ELSE
					l_ordertype := 'DESC';
				END IF;

			ELSE

				l_ordertype := l_list_of_detailed_columns(v_ordertable)(v_orderfield).order_type;
			END IF;	

                        if (l_ordertype = 'ASC') then
                           l_img_src := IMG_ASC;
                        else
                           l_img_src := IMG_DESC;
                        end if;

	         l_data        := '/pls/'
           	            || UTIL_PORTAL.get_portal_schema
                	    || '/'
	                    || UTIL_PORTAL.get_portlet_schema
        	            || '.STORAGE.display_host_details?p_id='
	                    || p_id
	                    || chr(38)
	                    || 'p_orderTable='
	                    || v_ordertable
	                    || chr(38)
	                    || 'p_orderfield='
	                    || v_orderfield
	                    || chr(38)
	                    || 'p_orderType='
	                    || l_ordertype	                    	                    	                    
                          || '';
                              
       		 l_data := HTF.anchor(curl => l_data || l_aname,
	      	 	      	      cattributes => 'style="color: black" onMouseOver="return false;" onMouseOut="return  false;"  ',
                             	      ctext =>  v_column_name || l_img_src);

                        


			-- PUT THE ASC DESC SORT SYMBOL HERE			
			-- l_sortsymbol := ;
		ELSE

			l_ordertype := l_list_of_detailed_columns(v_ordertable)(v_orderfield).order_type;

	         l_data        := '/pls/'
           	            || UTIL_PORTAL.get_portal_schema
                	    || '/'
	                    || UTIL_PORTAL.get_portlet_schema
        	            || '.STORAGE.display_host_details?p_id='
	                    || p_id
	                    || chr(38)
	                    || 'p_orderTable='
	                    || v_ordertable
	                    || chr(38)
	                    || 'p_orderfield='
	                    || v_orderfield
	                    || chr(38)
	                    || 'p_orderType='
	                    || l_ordertype	                    	                    	                    
                            || '';

       		 l_data := HTF.anchor(curl => l_data || l_aname,
	      	 	      	      cattributes => 'style="color: black" onMouseOver="return false;" onMouseOut="return  false;"  ',
                             	      ctext =>  v_column_name);
                             	                                  

		END IF;

        ELSE
		l_data := v_column_name;
	END IF;

	RETURN  l_data;                          

END get_sorting_link;   

  
BEGIN

	-- Initialize the config structures
	-- STORAGE.initialize;

	BEGIN

		SELECT	summaryObject(
 			ROWNUM,
			name,			
 			id,        
			type,
 			timestamp,					-- timestamp
 			collection_timestamp,				-- collection_timestamp
 			hostcount,					-- hostcount
 			actual_targets,					-- actual_targets
 			issues,						-- issues
 			hostcount-(actual_targets+issues),		-- not collected
 			warnings,					-- warnings
 			summaryFlag,					-- summaryFlag
 			application_rawsize     ,
 			application_size        ,
 			application_used        ,
 			application_free        ,
 			oracle_database_rawsize        ,
 			oracle_database_size        ,
 			oracle_database_used        ,
 			oracle_database_free        ,
 			local_filesystem_rawsize,
 			local_filesystem_size        ,
	 		local_filesystem_used        ,
 			local_filesystem_free        ,
 			nfs_exclusive_size        ,
 			nfs_exclusive_used        ,
 			nfs_exclusive_free        ,
 			nfs_shared_size                ,
 			nfs_shared_used                ,
 			nfs_shared_free                ,
 			volumemanager_rawsize        ,
 			volumemanager_size        ,
 			volumemanager_used        ,
 			volumemanager_free        ,
 			swraid_rawsize                ,
 			swraid_size                ,
 			swraid_used                ,
 			swraid_free                ,
 			disk_backup_rawsize        ,
 			disk_backup_size        ,
 			disk_backup_used        ,
 			disk_backup_free        ,
 			disk_rawsize                ,
 			disk_size                ,
 			disk_used                ,
 			disk_free                ,
 			rawsize                        ,
 			sizeb                        ,
 			used                        ,
 			free                        ,
 			vendor_emc_size                ,
 			vendor_emc_rawsize        ,
 			vendor_sun_size                ,
 			vendor_sun_rawsize        ,
 			vendor_hp_size                ,
 			vendor_hp_rawsize        ,
 			vendor_hitachi_size        ,
 			vendor_hitachi_rawsize        ,
 			vendor_others_size        ,
 			vendor_others_rawsize      ,
 			vendor_nfs_netapp_size     ,
 			vendor_nfs_emc_size        ,
 			vendor_nfs_sun_size        ,
			vendor_nfs_others_size )                                       
		INTO	l_summaryObject
		FROM	storage_summaryObject_view
		WHERE	id = p_id;
	
	EXCEPTION
		WHEN OTHERS THEN
			RAISE;
	END;

	---------------------------------
	-- BULK FETCH THE SUMMARY
	--------------------------------
	SELECT DECODE(type,
			'_TOTAL',c_detailed_report_summary,
			'_DISKS',c_detailed_report_disks,
			'_SWRAID',c_detailed_report_swraid,
			'_VOLUME_MANAGER',c_detailed_report_volumes,
			'_LOCAL_FILESYSTEM',c_detailed_report_localfs,
			'NFS_EXCLUSIVE',c_detailed_report_nfs, 
			'_ALL_DATABASES',c_detailed_report_oracle_db,NULL) querytype,
			type,
			name,
			rawsizeb,
			sizeb,		
			usedb,
			freeb 
	BULK COLLECT INTO 
			l_summary.querytype,
			l_summary.type,
			l_summary.name, 
			l_summary.rawsizeb, 
			l_summary.sizeb,
			l_summary.usedb,
			l_summary.freeb 
	FROM stormon_hostdetail_view WHERE id = p_id
	ORDER BY 
		DECODE(type,
		'_TOTAL',1,
		'_DISKS',2,
		'_BACKUP_DISKS',3,
		'_SWRAID',4,
		'_VOLUME_MANAGER',5,
		'_LOCAL_FILESYSTEM',6,
		'NFS_EXCLUSIVE',7,
		'NFS_SHARED',8,
		'_ALL_DATABASES',9,100) ASC;
    			
    				
       UTIL_PORTAL.include_portal_stylesheet;

       l_storage_link := '<B>' ||
                         '<A style="color: blue" HREF="javascript:;" onclick="javascript:loadpage(''total'');">Total Storage</A>' || BLANK4 ||       
                         '<A style="color: blue" HREF="javascript:;" onclick="javascript:loadpage(''disks'');">Disks</A>' || BLANK4 ||
                         '<A style="color: blue" HREF="javascript:;" onclick="javascript:loadpage(''swraid'');">SW RAID</A>' || BLANK4 ||
                         '<A style="color: blue" HREF="javascript:;" onclick="javascript:loadpage(''volumemanager'');">Volume Manager</A>' || BLANK4 ||
                         '<A style="color: blue" HREF="javascript:;" onclick="javascript:loadpage(''localfilesystem'');">Local Filesystem</A>' || BLANK4 ||
                         '<A style="color: blue" HREF="javascript:;" onclick="javascript:loadpage(''nfs'');">NFS</A>' || BLANK4 ||
                         '<A style="color: blue" HREF="javascript:;" onclick="javascript:loadpage(''database'');">Database</A>' || BLANK4 ||
                         '<A style="color: blue" HREF="javascript:;" onclick="javascript:loadpage(''issues'');">Issues</A>' || BLANK4 ||
                         '<A style="color: blue" HREF="javascript:;" onclick="javascript:loadpage(''warnings'');">Warnings</A>' || 
                         '</B>';
      HTP.p('<script LANGUAGE=JavaScript>');
      
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
                                                                                                                                                      
	print_ptable_open;              

	print_prow_open;
        print_pheader('<B>' || get_history_link(l_summaryObject) || '</B>' ||
       	              BLANK2 || '<A style="color: blue" HREF="javascript:PopUp(''/myHelp/storage.html'');"><B>FAQ ?</B></A>' ,
               	     'RIGHT');                     
	print_prow_close;
	
	print_line('bgcolor=#CCCC8C');           
	print_prow_open;
	print_pcol(l_storage_link,'LEFT');                     		
	print_prow_close;
	print_line('bgcolor=#CCCC8C');           	
	print_ptable_close;              
        print_line_break;

	-- Print the title table
 	print_host_title_table(l_summaryObject);

        print_ptable_open;	
	print_line('bgcolor=#CCCC8C');           	        
	print_ptable_close;              	
		        
	print_ptable_open;              	
	print_prow_open;
   
	IF l_summary.name IS NOT NULL AND l_summary.name.EXISTS(1) 
	THEN

		---------------------------------------------------
		-- Draw charts only if the summary is a valid one
		---------------------------------------------------
		IF  
			l_summaryObject.summaryFlag = 'Y' AND
			l_summaryObject.sizeb > 0 
		THEN		
	
			---------------------------------------------------
			-- Plot the Used Vs Free pie chart
			---------------------------------------------------		    
    			IF l_summary.type(1) = '_TOTAL' THEN
	
				l_chart_names  := stringTable(
								'Used '|| get_fmt_storage(l_summary.usedb(1)),
								'Free '|| get_fmt_storage(l_summary.freeb(1))
								);
	    	
	    			l_chart_values := stringTable(
								l_summary.usedb(1),
								l_summary.freeb(1) );

	    			print_pcol(get_chart_image(
						'Used vs Free' ,
			                       '(Total ' || get_fmt_storage(l_summary.sizeb(1)) ||  ' )',
	                                        l_chart_names,
						l_chart_values) ,
						'CENTER' );
    			END IF;    	    	
		    		  
			l_chart_names := stringTable();
			l_chart_values := stringTable();
	
			---------------------------------------------	
			-- Plot the Free by category pie chart
			---------------------------------------------
			FOR i IN l_summary.name.FIRST..l_summary.name.LAST  LOOP
		        	 
			        IF 	
					l_summary.freeb(i) > 0 
					AND l_summary.type(I) IN ('_DISKS','_SWRAID','_VOLUME_MANAGER','_LOCAL_FILESYSTEM','NFS_EXCLUSIVE','_ALL_DATABASES') 
				THEN	         	

					l_chart_names.EXTEND;
					l_chart_values.EXTEND;
			
					l_chart_names(l_chart_names.LAST)   := l_summary.name(i)||' '|| get_fmt_storage(l_summary.freeb(i));
					l_chart_values(l_chart_values.LAST) := l_summary.freeb(i);
	
				END IF;
	
			END LOOP;
		    
			IF l_chart_names IS NOT NULL AND l_chart_names.EXISTS(1) THEN

				print_pcol(get_chart_image(
						'Free Storage Distribution' ,
			                       '(Free ' || get_fmt_storage(l_summary.freeb(l_summary.freeb.FIRST)) ||  ' )',
	                                        l_chart_names,
						l_chart_values),
						'CENTER' );
			END IF;
	
		END IF;
		
		print_prow_close;            
		print_ptable_close;              	    
		    
		FOR I IN l_summary.name.FIRST..l_summary.name.LAST LOOP
					
			----------------------------------------------------------
			-- PRINT DETAIL TABLE ONLY FOR THESE TYPES
			----------------------------------------------------------
			IF l_summary.querytype(I) NOT IN (c_detailed_report_summary,c_detailed_report_disks,c_detailed_report_swraid,c_detailed_report_volumes,c_detailed_report_localfs,c_detailed_report_nfs,c_detailed_report_oracle_db) OR
				l_summary.querytype(I) IS NULL	
			THEN
				GOTO next_type;
			END IF;
	
			print_line_break; 			             		                      			
			print_ptable_open;                  
	
			----------------------------------------------------------
			-- PRINT TABLE TITLE
			----------------------------------------------------------
			print_prow_open;
			IF l_detailed_table_title_list IS NOT NULL AND l_detailed_table_title_list.EXISTS(l_summary.queryType(I)) THEN
				print_pheader(l_detailed_table_title_list(l_summary.queryType(I)) || IMG_TOP);
			ELSE
				print_pheader(l_summary.name(I));                     	
			END IF;
			print_prow_close;                       
	
			----------------------------------------------------------
			-- PRINT THE COLUMN HEADINGS	
			----------------------------------------------------------
			print_prow_open(NULL,TABLE_HEADER_COLOR);		
		   
			FOR k IN l_detailed_table_column_order(l_summary.querytype(I)).FIRST..l_detailed_table_column_order(l_summary.querytype(I)).LAST LOOP

				IF l_detailed_table_column_order(l_summary.querytype(I))(k) IS NOT NULL THEN	
	
					print_phcol(
							get_sorting_link(
								l_list_of_detailed_columns(l_summary.querytype(I))(l_detailed_table_columns(l_summary.querytype(I))(l_detailed_table_column_order(l_summary.querytype(I))(k))).column_name,
								l_summary.querytype(I),
								l_detailed_table_columns(l_summary.querytype(I))(l_detailed_table_column_order(l_summary.querytype(I))(k))
								)
						);
				END IF;
			END LOOP;		
			print_prow_close;
			
			----------------------------------------------------------
			-- CHECK IF DETAILS EXIST FOR THIS TYPE
			----------------------------------------------------------
			IF l_summary.sizeb(I) = 0 THEN
	
			    	l_row_color := WWUI_API_PORTLET.portlet_subheader_color;	
			   	print_prow_open(l_row_color);
				IF l_detailed_notfound_mesg_list IS NOT NULL AND l_detailed_notfound_mesg_list.EXISTS(l_summary.queryType(I)) THEN
			       	 print_pcol('<I>' || l_detailed_notfound_mesg_list(l_summary.queryType(I)) || '</I>','LEFT',NULL,l_detailed_table_column_order(l_summary.querytype(I)).COUNT);	
				ELSE
			       	 print_pcol('<I>' || l_summary.name(I) || ' Not Found for  this target' || '</I>','LEFT',NULL,l_detailed_table_column_order(l_summary.querytype(I)).COUNT);	
				END IF;
			        print_prow_close;                                       
			        print_ptable_close;              		        
				GOTO next_type;
	
			END IF;
			
			l_row_color := WWUI_API_PORTLET.portlet_subheader_color;
			l_clToggle  :=1;
	                l_bg_color  := NULL;
	
			----------------------------------------------------------
			-- PRINT THE SUMMARY TABLE 
			----------------------------------------------------------
			IF l_summary.querytype(I) = c_detailed_report_summary THEN
	
					      FOR J IN REVERSE l_summary.name.FIRST..l_summary.name.LAST  LOOP
	
	                                      		IF (INSTR(UPPER(l_summary.name(J)),'TOTAL')> 0) THEN
			                                	l_bg_color  := '#CCCCCC';
	                		                        l_row_color := NULL;
							ELSE	
						        	-- to alert data row background colors
						        	if ( MOD(l_clToggle, 2) != 0 ) then
							       	 l_row_color := WWUI_API_PORTLET.portlet_body_color;
								else
							       	 l_row_color := WWUI_API_PORTLET.portlet_subheader_color;
								end if;			
								l_clToggle := l_clToggle + 1;              		    			    
	                                		END IF;
	                                      				
						        print_prow_open(l_row_color,l_bg_color);
						        print_pcol(l_summary.name(J),'LEFT');
							IF l_summary.sizeb(J) = 0 THEN
						        	print_pcol('-','RIGHT');
						        	print_pcol('-','RIGHT');
						        	print_pcol('-','RIGHT');
						        	print_pcol('-','RIGHT');
							ELSE
						        	print_pcol(get_fmt_storage(l_summary.rawsizeb(J)),'RIGHT');
						        	print_pcol(get_fmt_storage(l_summary.sizeb(J)),'RIGHT');  
						        	print_pcol(get_fmt_storage(l_summary.usedb(J)),'RIGHT'); 
						        	print_pcol(get_fmt_storage(l_summary.freeb(J)),'RIGHT');               
							END IF;
						        print_prow_close;                               
					    END LOOP;    
	
			ELSE
			----------------------------------------------------------
			-- PRINT THE OTHER DETAIL TABLES
			----------------------------------------------------------
	
				----------------------------------------------------------
				-- BUILD THE QUERY STRING FOR THE OTHER DETAILS
				----------------------------------------------------------
				l_querystring := NULL;
				l_orderstring := NULL;
	
				------------------------------------
				-- SELECT FIELDS
				------------------------------------
				FOR k IN l_detailed_table_columns(l_summary.querytype(I)).FIRST..l_detailed_table_columns(l_summary.querytype(I)).LAST LOOP
	
					IF k = 1 THEN
						IF l_detailed_table_columns(l_summary.querytype(I))(k) IS NOT NULL THEN
							l_queryString := 'SELECT '||l_list_of_detailed_columns(l_summary.querytype(I))(l_detailed_table_columns(l_summary.querytype(I))(k)).field_name;
						ELSE
							l_queryString := 'SELECT NULL ';
						END IF;
					ELSE
						IF l_detailed_table_columns(l_summary.querytype(I))(k) IS NOT NULL THEN
							l_queryString := l_queryString||','||l_list_of_detailed_columns(l_summary.querytype(I))(l_detailed_table_columns(l_summary.querytype(I))(k)).field_name;
						ELSE
							l_querystring := l_queryString||', NULL ';
						END IF;
					END IF;
		
				END LOOP;
	
				------------------------------------
				-- TABLE NAME 
				------------------------------------
				IF l_detailed_report_table_name(l_summary.querytype(I)) IS NOT NULL THEN
	
					l_queryString := l_queryString||' FROM '||l_detailed_report_table_name(l_summary.querytype(I))||' WHERE target_id = :id ';
	
				ELSE
	
					GOTO next_type;
	
				END IF;
	
	
				------------------------------------
				-- DEFAULT ORDER BY STRING
				------------------------------------
				IF l_detail_default_order_list(l_summary.querytype(I)) IS NOT NULL THEN
	
					l_orderString := ' ORDER BY '||l_detail_default_order_list(l_summary.querytype(I));
				
				END IF;
	
	
				------------------------------------
				-- ORDER BY SORT CONDITION 
				------------------------------------
				IF p_ordertable = l_summary.querytype(I) THEN
				
					IF 	l_list_of_detailed_columns(p_orderTable) IS NOT NULL AND
						l_list_of_detailed_columns(p_ordertable).EXISTS(p_orderfield) AND
						l_list_of_detailed_columns(p_ordertable)(p_orderfield).field_name IS NOT NULL
					THEN
						IF l_orderString IS NOT NULL THEN
							l_orderString := l_orderString||' , '||l_list_of_detailed_columns(p_ordertable)(p_orderfield).field_name;
						ELSE
							l_orderString := ' ORDER BY '||l_list_of_detailed_columns(p_ordertable)(p_orderfield).field_name;
						END IF;
	
						IF p_ordertype IN ('DESC','ASC') THEN
							l_orderString := l_orderString||' '||p_ordertype;
						ELSE
							l_orderString := l_orderString||' '||l_list_of_detailed_columns(p_ordertable)(p_orderfield).order_type;
						END IF;	
	
					END IF;
	
				END IF;
	
				------------------------------------
				-- BULK FETCH FROM THE QUERY
				------------------------------------
				l_queryString := l_queryString||' '||l_orderString;
	
				OPEN l_cursor FOR l_queryString USING p_id;
	
				FETCH l_cursor BULK COLLECT INTO 
	                                			l_results.type ,
	                                			l_results.path,
	                                			l_results.filesystem,
	                                			l_results.rawsizeb,
	                                			l_results.sizeb,
	                                			l_results.usedb,
	                                			l_results.freeb,
	                                			l_results.vendor,
	                                			l_results.backup,
	                                			l_results.product,
	                                			l_results.mountpoint,
	                                			l_results.configuration,
	                                			l_results.freetype,
	                                			l_results.tablespace,
	                                			l_results.dbid;
	
				CLOSE l_cursor;
				
	
				------------------------------------
				-- PRINT THE RESULTS
				------------------------------------
				IF l_results.sizeb IS NOT NULL AND l_results.sizeb.EXISTS(1) THEN
	
					-- PRINT ALL THE FETCHED RESULTS FOR THIS QUERY
					FOR J IN l_results.sizeb.FIRST..l_results.sizeb.LAST LOOP
	
						-- to alert data row background colors
						IF ( MOD(l_clToggle, 2) != 0 ) THEN
					         l_row_color := WWUI_API_PORTLET.portlet_body_color;
						ELSE
					         l_row_color := WWUI_API_PORTLET.portlet_subheader_color;
						END IF;			
					        l_clToggle := l_clToggle + 1;              		    
					
		                                print_prow_open(l_row_color);
	
						-- PRINT ALL THE COLUMNS FOR THIS QUERY TYPE
				                FOR k IN l_detailed_table_column_order(l_summary.querytype(I)).FIRST..l_detailed_table_column_order(l_summary.querytype(I)).LAST LOOP
	
	                       				IF l_detailed_table_column_order(l_summary.querytype(I))(k) IS NOT NULL 
							THEN
								CASE l_detailed_table_column_order(l_summary.querytype(I))(k)
									WHEN c_detailed_field_type THEN
			                               				print_pcol(nvl(l_results.type(J),'-'),'LEFT');
									WHEN c_detailed_field_path THEN
										print_pcol(replace(nvl(l_results.path(J),' '),'!', '<BR>'),'LEFT');
									WHEN c_detailed_field_filesystem THEN
										print_pcol(nvl(l_results.filesystem(J),'-'),'LEFT');
									WHEN c_detailed_field_rawsizeb THEN
										print_pcol(get_fmt_storage(l_results.rawsizeb(J)),'RIGHT');
									WHEN c_detailed_field_sizeb THEN
										print_pcol(get_fmt_storage(l_results.sizeb(J)),'RIGHT');
									WHEN c_detailed_field_usedb THEN
										print_pcol(get_fmt_storage(l_results.usedb(J)),'RIGHT');
									WHEN c_detailed_field_freeb THEN
										print_pcol(get_fmt_storage(l_results.freeb(J)),'RIGHT');
									WHEN c_detailed_field_vendor THEN
			                               				print_pcol(nvl(l_results.vendor(J),'-'),'LEFT');
									WHEN c_detailed_field_backup THEN
			                               				print_pcol(nvl(l_results.backup(J),'-'),'LEFT');
									WHEN c_detailed_field_product THEN
			                               				print_pcol(nvl(l_results.product(J),'-'),'LEFT');
									WHEN c_detailed_field_mountpoint THEN
			                               				print_pcol(nvl(l_results.mountpoint(J),'-'),'LEFT');
									WHEN c_detailed_field_configuration THEN
			                               				print_pcol(nvl(l_results.configuration(J),'-'),'LEFT');
									WHEN c_detailed_field_freetype THEN
			                               				print_pcol(nvl(l_results.freetype(J),'-'),'LEFT');
									WHEN c_detailed_field_tablespace THEN
			                               				print_pcol(nvl(l_results.tablespace(J),'-'),'LEFT');
									WHEN c_detailed_field_dbid THEN
			                               				print_pcol(nvl(l_results.dbid(J),'-'),'LEFT');
									ELSE	print_pcol('-','LEFT');
								END CASE;
							END IF;
	
						END LOOP;
	
						print_prow_close;                               
	
	                		END LOOP;
					------------------------------------------
					--	TOTAL FOR A TABLE
					------------------------------------------
	
					print_prow_open(NULL,'#cccccc');
	
					-- PRINT ALL THE COLUMNS FOR THIS QUERY TYPE
			                FOR k IN l_detailed_table_column_order(l_summary.querytype(I)).FIRST..l_detailed_table_column_order(l_summary.querytype(I)).LAST LOOP
	
	               				IF l_detailed_table_column_order(l_summary.querytype(I))(k) IS NOT NULL 
						THEN
							CASE l_detailed_table_column_order(l_summary.querytype(I))(k)
								WHEN c_detailed_field_rawsizeb THEN
									print_pcol(get_fmt_storage(l_summary.rawsizeb(I)),'RIGHT');
								WHEN c_detailed_field_sizeb THEN
									print_pcol(get_fmt_storage(l_summary.sizeb(I)),'RIGHT');
								WHEN c_detailed_field_usedb THEN
									print_pcol(get_fmt_storage(l_summary.usedb(I)),'RIGHT');
								WHEN c_detailed_field_freeb THEN
									print_pcol(get_fmt_storage(l_summary.freeb(I)),'RIGHT');
								ELSE 
									IF K = 1 THEN
	                               						print_pcol('TOTAL','LEFT');
									ELSE	
										print_pcol('-','CENTER');
									END IF;
							END CASE;
						END IF;
	
					END LOOP;
	
					print_prow_close;            				
	
				END IF; -- IF RESULTS EXIST
	
			END IF; -- IF querytype
	
			print_ptable_close;
		
			<<next_type>>
			NULL;
		END LOOP;
	
	ELSE
	
				-- TBD PRINT NO DETAILED SUMMARY FOR THIS TARGET
				NULL;
	
	END IF;

-- Table to print Issues 
       print_line_break; 			
       print_line_break; 			
       print_ptable_open;
       print_prow_open;
       print_pheader('<A NAME="issues"></A>Storage Consistency Issues' || IMG_TOP);                     	                  	
       print_prow_close;                            		                  
       print_prow_open(NULL,TABLE_HEADER_COLOR);				
       print_phcol('Issues');                     	                     
       print_prow_close;                                       

       l_row_color := WWUI_API_PORTLET.portlet_subheader_color; 
       l_clToggle := 1;
        	            
	OPEN l_cursor FOR '
				SELECT	message
				FROM	storage_issues_view
				WHERE	id = :p_id
				AND     type = :p_type 
				ORDER BY timestamp DESC' USING p_id, 'ISSUE';

	FETCH l_cursor BULK COLLECT INTO l_messageList;

	CLOSE l_cursor;

	IF l_messageList IS NOT NULL AND l_messageList.EXISTS(1) THEN

		FOR i IN l_messageList.FIRST..l_messageList.LAST LOOP

			print_prow_open(l_row_color);
			print_pcol(l_messageList(i),'LEFT');
			print_prow_close;                            	
               
			-- to alert data row background colors
			if ( MOD(i , 2) != 0 ) then
				l_row_color := WWUI_API_PORTLET.portlet_body_color;
			else
				l_row_color := WWUI_API_PORTLET.portlet_subheader_color;
			end if;				              		                   	           

       		END LOOP;
	ELSE

		print_prow_open(l_row_color);
	    	print_pcol('<I>' || 'No Storage consistency issues found for this host' || '</I>','LEFT',NULL,3);	
	        print_prow_close; 
                                             
	END IF;
		        
       print_ptable_close;                               						  				       
 

-- Table to print warnings 

       print_line_break; 			
       print_ptable_open;
       print_prow_open;
       print_pheader('<A NAME="warnings"></A>Storage Consistency Warnings');                     	
       print_prow_close;                            		                  
       print_prow_open(NULL,TABLE_HEADER_COLOR);				
       print_phcol('Warnings');                     	                     
       print_prow_close;                                       

	OPEN l_cursor FOR '
				SELECT	message
				FROM	storage_issues_view
				WHERE	id = :p_id
				AND     type = :p_type 
				ORDER BY timestamp DESC' USING p_id, 'WARNING';

	FETCH l_cursor BULK COLLECT INTO l_messageList;

	CLOSE l_cursor;

	l_row_color := WWUI_API_PORTLET.portlet_subheader_color; 

	IF l_messageList IS NOT NULL AND l_messageList.EXISTS(1) THEN

		FOR i IN l_messageList.FIRST..l_messageList.LAST LOOP

			print_prow_open(l_row_color);
			print_pcol(l_messageList(i),'LEFT');
			print_prow_close;                            	
               
			-- to alert data row background colors
			if ( MOD(i , 2) != 0 ) then
				l_row_color := WWUI_API_PORTLET.portlet_body_color;
			else
				l_row_color := WWUI_API_PORTLET.portlet_subheader_color;
			end if;				              		                   	           

       		END LOOP;
	ELSE

		print_prow_open(l_row_color);
	    	print_pcol('<I>' || 'No Storage consistency warnings found for this host' || '</I>','LEFT',NULL,3);	
	        print_prow_close; 
                                             
	END IF;
 
       print_ptable_close;                               						  				       

 END;    

--------------------------------------------------
-- Procedure Name : display_issues
-- Description    : display_issues
--          INPUT : target name
--                  target id 
--------------------------------------------------
procedure display_issues (
  p_id    	  in varchar2,
  p_message_type  in varchar2,	-- Type of message , ISSUE or WARNING
  p_host_type	  in VARCHAR2 DEFAULT 'ALL_HOSTS' -- Type of Hosts to report ALL_HOSTS,FAILED_HOSTS,ISSUE_HOSTS,NOT_COLLECTED_HOSTS,SUMMARIZED_HOSTS
)
is

l_row_color	varchar2(24);

l_cursor	sys_Refcursor;
l_tablename	VARCHAR2(256);
l_targetList	stringTable;
l_messageList	stringTable;


l_predicate     VARCHAR2(1000);
l_sqlstmt	VARCHAR2(5000);
l_title		VARCHAR2(1000);
l_summaryObject	summaryObject;

BEGIN

        UTIL_PORTAL.include_portal_stylesheet;
	l_row_color := WWUI_API_PORTLET.portlet_subheader_color;

	BEGIN

		SELECT	summaryObject(
 			ROWNUM,
			name,			
 			id,        
			type,
 			timestamp,					-- timestamp
 			collection_timestamp,				-- collection_timestamp
 			hostcount,					-- hostcount
 			actual_targets,					-- actual_targets
 			issues,						-- issues
 			hostcount-(actual_targets+issues),		-- not collected
 			warnings,					-- warnings
 			summaryFlag,					-- summaryFlag
 			application_rawsize     ,
 			application_size        ,
 			application_used        ,
 			application_free        ,
 			oracle_database_rawsize        ,
 			oracle_database_size        ,
 			oracle_database_used        ,
 			oracle_database_free        ,
 			local_filesystem_rawsize,
 			local_filesystem_size        ,
	 		local_filesystem_used        ,
 			local_filesystem_free        ,
 			nfs_exclusive_size        ,
 			nfs_exclusive_used        ,
 			nfs_exclusive_free        ,
 			nfs_shared_size                ,
 			nfs_shared_used                ,
 			nfs_shared_free                ,
 			volumemanager_rawsize        ,
 			volumemanager_size        ,
 			volumemanager_used        ,
 			volumemanager_free        ,
 			swraid_rawsize                ,
 			swraid_size                ,
 			swraid_used                ,
 			swraid_free                ,
 			disk_backup_rawsize        ,
 			disk_backup_size        ,
 			disk_backup_used        ,
 			disk_backup_free        ,
 			disk_rawsize                ,
 			disk_size                ,
 			disk_used                ,
 			disk_free                ,
 			rawsize                        ,
 			sizeb                        ,
 			used                        ,
 			free                        ,
 			vendor_emc_size                ,
 			vendor_emc_rawsize        ,
 			vendor_sun_size                ,
 			vendor_sun_rawsize        ,
 			vendor_hp_size                ,
 			vendor_hp_rawsize        ,
 			vendor_hitachi_size        ,
 			vendor_hitachi_rawsize        ,
 			vendor_others_size        ,
 			vendor_others_rawsize      ,
 			vendor_nfs_netapp_size     ,
 			vendor_nfs_emc_size        ,
 			vendor_nfs_sun_size        ,
			vendor_nfs_others_size )                                       
		INTO	l_summaryObject
		FROM	storage_summaryObject_view
		WHERE	id = p_id;
	
	EXCEPTION
		WHEN OTHERS THEN
			RAISE;
	END;


        IF l_summaryObject.type = 'HOST' THEN
                -- ID is a target id
		-- SQL Statement

		l_sqlstmt :=	'
				SELECT	a.target_name,						
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
				SELECT	a.target_name,						
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
	--	print_prow_close;                                      
	--	print_ptable_close;

	END IF;

	print_ptable_open;	
	print_line('bgcolor=#CCCC8C');           	        
	print_ptable_close;            
							     
	print_host_title_table(l_summaryObject);
						
	print_ptable_open;	
	print_line('bgcolor=#CCCC8C');           	        
	print_ptable_close; 

	print_line_break;              			
	print_ptable_open;
	print_prow_open;
	print_pheader(l_title);
	print_prow_close;                                      
	print_ptable_close;
       
	-- Print the Issue Table
	print_ptable_open;
	print_prow_open(NULL,TABLE_HEADER_COLOR);				
	print_phcol('Host');                     	        	                 	
	print_phcol('Message');                     	                     
	print_prow_close;        


	-- Umable to do this using EXECUTE IMMEDIATE, 
	-- Gives ORA 1019, unable to allocate memory on the user side 
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
			print_prow_close;
			
		END LOOP;

	ELSE

		print_prow_open;	

		IF p_message_type = 'ISSUE' THEN
			print_pcol('<I>' || ' No Issues ' || '</I>','LEFT');	
		ELSE       		              
			print_pcol('<I>' || ' No Warnings ' || '</I>','LEFT');		               
		END IF;
		print_prow_close;                  

	END IF;

	print_ptable_close;  
                             						  				       
	display_tip(stringTable('Refer to FAQ for resolving outstanding Issues for a host '));

 END;    


--------------------------------------------------
-- Procedure Name : display_hosts_not_collected
-- Description    : display hosts with no storage metrics
--          INPUT : data center
--                  lob
--		     title
--------------------------------------------------
procedure display_hosts_not_collected (
  p_id    	  in varchar2
)
is

l_row_color	varchar2(24);
l_cursor	sys_Refcursor;
l_targetList	stringTable;

l_dummy         VARCHAR2(1);
l_title		VARCHAR2(1000) := NULL;
l_summaryObject	summaryObject;
l_sqlstmt	VARCHAR2(500);

	  
BEGIN

	l_row_color := WWUI_API_PORTLET.portlet_subheader_color;
	UTIL_PORTAL.include_portal_stylesheet;

	BEGIN

		SELECT	summaryObject(
 			ROWNUM,
			name,			
 			id,        
			type,
 			timestamp,					-- timestamp
 			collection_timestamp,				-- collection_timestamp
 			hostcount,					-- hostcount
 			actual_targets,					-- actual_targets
 			issues,						-- issues
 			hostcount-(actual_targets+issues),		-- not collected
 			warnings,					-- warnings
 			summaryFlag,					-- summaryFlag
 			application_rawsize     ,
 			application_size        ,
 			application_used        ,
 			application_free        ,
 			oracle_database_rawsize        ,
 			oracle_database_size        ,
 			oracle_database_used        ,
 			oracle_database_free        ,
 			local_filesystem_rawsize,
 			local_filesystem_size        ,
	 		local_filesystem_used        ,
 			local_filesystem_free        ,
 			nfs_exclusive_size        ,
 			nfs_exclusive_used        ,
 			nfs_exclusive_free        ,
 			nfs_shared_size                ,
 			nfs_shared_used                ,
 			nfs_shared_free                ,
 			volumemanager_rawsize        ,
 			volumemanager_size        ,
 			volumemanager_used        ,
 			volumemanager_free        ,
 			swraid_rawsize                ,
 			swraid_size                ,
 			swraid_used                ,
 			swraid_free                ,
 			disk_backup_rawsize        ,
 			disk_backup_size        ,
 			disk_backup_used        ,
 			disk_backup_free        ,
 			disk_rawsize                ,
 			disk_size                ,
 			disk_used                ,
 			disk_free                ,
 			rawsize                        ,
 			sizeb                        ,
 			used                        ,
 			free                        ,
 			vendor_emc_size                ,
 			vendor_emc_rawsize        ,
 			vendor_sun_size                ,
 			vendor_sun_rawsize        ,
 			vendor_hp_size                ,
 			vendor_hp_rawsize        ,
 			vendor_hitachi_size        ,
 			vendor_hitachi_rawsize        ,
 			vendor_others_size        ,
 			vendor_others_rawsize      ,
 			vendor_nfs_netapp_size     ,
 			vendor_nfs_emc_size        ,
 			vendor_nfs_sun_size        ,
			vendor_nfs_others_size )                                       
		INTO	l_summaryObject
		FROM	storage_summaryObject_view
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
				SELECT	a.name
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
	print_ptable_close;            
						     
	print_host_title_table(l_summaryObject);
	
	print_ptable_open;	
	print_line('bgcolor=#CCCC8C');           	        			
	print_ptable_close;

	IF l_summaryObject.type != 'HOST' THEN
	
		print_line_break;
		print_ptable_open;		
		print_prow_open;			
		print_pheader(l_title);
		print_prow_close; 

		print_prow_open(NULL,TABLE_HEADER_COLOR);
		print_phcol('Host','left');                     	                     
		print_prow_close;        

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
				print_prow_close;                            		           	

		       END LOOP;  

		END IF;

		print_ptable_close; 

	END IF;
                                             						  				       
	display_tip(stringTable('Enable collection of Storage data to view Storage Reports'));

 END display_hosts_not_collected;    



-------------------------------------------------------
-- Print the title table for a Target
-------------------------------------------------------
PROCEDURE print_host_title_table(l_summaryObject IN summaryObject ) 
IS

   l_datacenter   stormon_group_table.name%TYPE;
   l_lob	  stormon_group_table.name%TYPE;
   l_group_name   stormon_group_table.name%TYPE;
   l_group_type	  stormon_group_table.type%TYPE;

   l_title_align	VARCHAR2(20) := 'RIGHT';
   l_value_align	VARCHAR2(20) := 'LEFT';

BEGIN

        --print_ptable_open;
        print_ptable_open('0','center','width=40% cellspacing=0 cellpadding=4 class=""') ;	

	IF l_summaryObject.type = 'HOST' THEN
		
		print_prow_open;
		print_pcol('Host Name : ',l_title_align);
		print_pcol('<B>' || l_summaryObject.name || '</B>',l_value_align);
		print_prow_close;
	
		BEGIN
			SELECT  a.name,
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
		print_pcol('Data Center : ',l_title_align);
		print_pcol('<B>' || l_datacenter || '</B>',l_value_align);	
		print_prow_close;
		

		print_prow_open;	
		print_pcol('LOB(Line Of Business) : ',l_title_align);
		print_pcol('<B>' || l_lob || '</B>',l_value_align);		
		print_prow_close;
		

		print_prow_open;	
		print_pcol('Date Data Collected ',l_title_align);
		IF	l_summaryObject.summaryFlag = 'N' THEN

			print_pcol('<B>' ||  'Collection not enabled (collection never successful)' || '</B>',l_value_align);

		ELSIF	l_summaryObject.summaryFlag = 'I'  THEN

			print_pcol('<B>' || 'Computation of storage summary has failed since '||l_summaryObject.collection_timestamp || '</B>',l_value_align);
		ELSE
			print_pcol('<B>' || l_summaryObject.collection_timestamp || '</B>',l_value_align);
		END IF;

		print_prow_close;
		

	ELSIF l_summaryObject.type IN ('REPORTING_DATACENTER','REPORTING_LOB','REPORTING_DATACENTER_LOB','REPORTING_ALL') THEN
	-- For groups 

		STORAGE.GET_DC_LOB_FROM_NAME(l_summaryObject.name,l_summaryObject.type,l_datacenter,l_lob);

		print_prow_open;
		print_pcol('Data Center : ',l_title_align);
		print_pcol('<B>' || l_datacenter || '</B>',l_value_align);	
		print_prow_close;
		

		print_prow_open;	
		print_pcol('LOB(Line Of Business) : ',l_title_align);
		print_pcol('<B>' || l_lob || '</B>',l_value_align);		
		print_prow_close;	
		

	ELSE

		print_prow_open;	
		print_pcol('Group name : ',l_title_align);
		print_pcol('<B>' || l_summaryObject.name || '</B>',l_value_align);	
		print_prow_close;
					

	END IF;

	print_ptable_close;              	
  
END print_host_title_table;



------------------------------------------------
-- CREATE A TITLE BASED ON THE DATACENTER AND LOB
------------------------------------------------
FUNCTION get_lob_dc_title(
		p_dc  IN stormon_group_table.name%TYPE, 
		p_lob IN stormon_group_table.name%TYPE 
) RETURN VARCHAR2 
IS

l_title		VARCHAR2(2000);

BEGIN

	IF p_lob = 'ALL' THEN
		l_title := 'All LOBs';
	ELSE
		l_title := 'LOB '||p_lob;
	END IF;

	IF p_dc = 'ALL' THEN
		l_title :=  l_title||' in All Data Centers';
	ELSE
		l_title := l_title||' in '||p_dc||' Data Center';
	END IF;
	
	RETURN l_title;

END get_lob_dc_title;

--------------------------------------------------------------------
-- Name : classical_drill_down
-- 
-- Desc : Procedure to build the UI, the cgi nvokes this procedure
--		The default starts with ALL datacenters and LOB's
--		For drill downs pass the specific Datacenter and LOB
--------------------------------------------------------------------
PROCEDURE classical_drill_down ( 
				p_group_name		IN VARCHAR2 DEFAULT 'ALL',
				p_group_type		IN VARCHAR2 DEFAULT 'REPORTING_ALL',
				p_chart_type		IN VARCHAR2 DEFAULT 'PIE' ,
				p_report_type		IN VARCHAR2 DEFAULT NULL,
				p_host_type		IN VARCHAR2 DEFAULT 'ALL_HOSTS',	 
				p_orderfield		IN INTEGER DEFAULT 3, 
				p_ordertype		IN VARCHAR2 DEFAULT 'DEFAULT'
) IS

-- Table for chart configuration
TYPE chart_record IS RECORD (chart_no INTEGER, query_no INTEGER);
TYPE charttable IS TABLE OF chart_record;

-- Cache for query results, table of summaryTables
l_allsummaries		t_allSummaries := t_allSummaries();
l_targetSummaries	storageSummaryTable;
l_group_summary		summaryObject;
l_type_of_reports	stringTable := stringTable();		-- List of the type of reports based on the parent type

l_summary_fields	VARCHAR2(5000);
l_queries		stringTable := stringTable();		-- Queries
l_titles		t_stringTable := t_stringTable();	-- Table titles
l_tables		t_stringTable := t_stringTable();	-- Tables

l_host_predicate	VARCHAR2(1000);

l_group_id		stormon_group_table.id%TYPE;
l_id_count		NUMBER;
l_elapsedtime		INTEGER := 0;
l_time			INTEGER := 0;
l_unit          	VARCHAR2(32);
l_bartag		VARCHAR2(2);
l_orderList		VARCHAR2(4000) := ' sizeb DESC ';

l_dc			stormon_group_table.name%TYPE;
l_lob			stormon_group_table.name%TYPE;

-------------------------------
-- VARIABLES FOR CHARTING
-------------------------------
l_charts	chartTable := chartTable();

c_USEDFREE	CONSTANT INTEGER := 1;
c_VENDOR	CONSTANT INTEGER := 2;
c_DC		CONSTANT INTEGER := 3;
c_LOB		CONSTANT INTEGER := 4;
c_HOSTUSED	CONSTANT INTEGER := 5;
c_HOSTFREE	CONSTANT INTEGER := 6;

l_fieldname	stringTable;
l_fieldvalue	stringTable;

l_charttitle	VARCHAR2(1000);
l_chartsubtitle	VARCHAR2(1000);
l_legend	VARCHAR2(4000);
l_values	VARCHAR2(4000);



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
      return varchar2
   is
      l_data varchar2(256);

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
-- Function  Name : get_summary_drilldown_fmt_link
-- Description    : 
--
--                   INPUT : group/host name
--                   OUTPUT : HREF for the group
--------------------------------------------------
   function get_summary_drilldown_fmt_link(
      p_summary    in summaryObject,
      p_tag	   in VARCHAR2,
      p_report_type in VARCHAR2 DEFAULT NULL,
      p_host_type  in VARCHAR2 DEFAULT 'ALL_HOSTS'
   )
      return varchar2
   is

	l_data    varchar2(2048);
	l_winprop varchar2(2048) := 'toolbar=yes,location=no,directories=yes,status=yes,menubar=yes,scrollbars=yes,resizable=yes,left=50,top=50,width=900,height=550';

   begin
       	
      
	l_data := HTF.anchor(curl => 'javascript:link_change_display(''' ||replace(replace(p_summary.name,' ','%20'),'TOTAL','ALL') || ''',''' || replace(p_summary.type,' ','%20')  || ''',''' || p_chart_type || ''',''' ||p_report_type || ''',''' || p_host_type || ''',''' || ''',''' || ''');', cattributes => ' style="color: blue" ', ctext => p_tag );

      
      return l_data;
      
   end get_summary_drilldown_fmt_link;

 
--------------------------------------------------
-- Function  Name : get_summary_sorting_link
-- Description    : 
--
--                   INPUT : group/host id
--                   OUTPUT : HREF for the group/host History
--------------------------------------------------
   function get_summary_sorting_link(
      p_column_name in varchar2, 
      p_column_no   in integer
   )
      return varchar2
   is
      l_data        varchar2(4000);
      l_ordertype   VARCHAR2(4);
      l_img_src     varchar2(256);  
   begin

	IF l_list_of_summary_columns IS NOT NULL and l_list_of_summary_columns.EXISTS(p_column_no) AND l_list_of_summary_columns(p_column_no).order_clause IS NOT NULL THEN

		-- If creating link to the currently sorted column then check and reverse it, for other columns
		-- stick to the default order
		IF p_orderfield = p_column_no 
		THEN

			IF p_ordertype = 'DESC' THEN
				l_ordertype := 'ASC';
			ELSIF p_ordertype = 'ASC' THEN
				l_ordertype := 'DESC';
			ELSIF p_ordertype = 'DEFAULT' THEN
				IF l_list_of_summary_columns(p_column_no).order_type = 'DESC' 
				THEN
					l_ordertype := 'ASC';
				ELSE
					l_ordertype := 'DESC';
				END IF;
			ELSE
				l_ordertype := l_list_of_summary_columns(p_column_no).order_type;
			END IF;

                        if (l_ordertype = 'ASC') then
                           l_img_src := IMG_ASC;
                        else
                           l_img_src := IMG_DESC;
                        end if;
                        
	         	l_data := HTF.anchor(curl => 'javascript:link_change_display(''' || replace(p_group_name,' ','%20') || ''',''' || replace(p_group_type,' ','%20')  || ''',''' || p_chart_type || ''',''' || p_report_type || ''',''' || p_host_type || ''',''' || p_column_no || ''',''' || l_ordertype ||''');', 
          	              cattributes => ' style="color: black" ',
                              ctext => p_column_name || l_img_src);
                              			-- PUT THE ASC DESC SORT SYMBOL HERE			
			-- l_sortsymbol := ;

		ELSE
			l_ordertype := l_list_of_summary_columns(p_column_no).order_type;
	         	l_data := HTF.anchor(curl => 'javascript:link_change_display(''' || replace(p_group_name,' ','%20') || ''',''' || replace(p_group_type,' ','%20')  || ''',''' || p_chart_type || ''',''' || p_report_type || ''',''' || p_host_type || ''',''' || p_column_no || ''',''' || l_ordertype ||''');', 
        	  	              cattributes => ' style="color: black" ',
                	              ctext => p_column_name);			
			
		END IF;


        ELSE
		l_data := p_column_name;
	END IF;
         return  l_data;                          
   end get_summary_sorting_link;   
    
------------------------------------------------
-- PRINT SUMMARY FROM THE RESULT ARRAY 
-- CHOSE FIELDS BASED ON THE TABLE TYPE
------------------------------------------------
PROCEDURE printrow (i INTEGER, j INTEGER ,k INTEGER) IS

l_others_used			NUMBER(16);
l_vendor_others			NUMBER(16); 
l_percent_used			NUMBER(2);
l_row_color                     varchar2(24);
l_bg_color                      varchar2(24);  
l_formatstring			VARCHAR2(6000);

BEGIN
                  
	IF ( MOD(k, 2) != 0 ) THEN
	         l_row_color := WWUI_API_PORTLET.portlet_subheader_color;
	         l_bg_color := NULL;
	ELSE
	         l_row_color := WWUI_API_PORTLET.portlet_body_color;
	         l_bg_color := NULL;			         
	END IF;
			
	IF	l_allSummaries(i)(k).id IS NULL  OR 
		l_group_id = l_allSummaries(i)(k).id
	THEN
	         l_row_color := NULL;
	         l_bg_color := '#CCCCCC';			         			
	END IF; 

	-- Used %
	IF l_allSummaries(i)(k).sizeb = 0 THEN
		l_percent_used := 0;
	ELSE			
		l_percent_used	:= ROUND( ( l_allSummaries(i)(k).used / NVL(l_allSummaries(i)(k).sizeb,1) ) * 100,0);
	END IF;

	-- Others used
	l_others_used := l_allSummaries(i)(k).used - l_allSummaries(i)(k).disk_backup_size;

	-- Other vendors
	l_vendor_others	:=  	l_allSummaries(i)(k).vendor_nfs_others_size + 
				l_allSummaries(i)(k).vendor_nfs_sun_size +
				l_allSummaries(i)(k).vendor_nfs_others_size +
				l_allSummaries(i)(k).vendor_others_size +
				l_allSummaries(i)(k).vendor_hp_size;

	----------------------------------------------------
	-- PRINT THE FIELDS DEPENDING ON THE TABLE TYPE
	----------------------------------------------------

	IF l_tables(i)(j) = c_summary_dc_table OR l_tables(i)(j) = c_summary_lob_table THEN

		print_prow_open(l_row_color,l_bg_color);

		-- Drill down to the next report
		IF  	l_allSummaries(i)(k).id IS NULL OR 
			l_group_id = l_allSummaries(i)(k).id
		THEN
			print_pcol(l_allSummaries(i)(k).name ,'LEFT');
		ELSE
			IF l_allSummaries(i)(k).type IN ('REPORTING_DATACENTER','REPORTING_LOB','REPORTING_DATACENTER_LOB') THEN
				print_pcol(get_summary_drilldown_fmt_link(l_allSummaries(i)(k),l_allSummaries(i)(k).name),'LEFT');
			ELSE
				print_pcol(get_summary_drilldown_fmt_link(l_allSummaries(i)(k),l_allSummaries(i)(k).name,'HOSTS','ALL_HOSTS'),'LEFT');
			END IF;
		END IF;

		-- Summarized Hosts
		IF l_allSummaries(i)(k).actual_targets > 0 THEN
			print_pcol(get_summary_drilldown_fmt_link(l_allSummaries(i)(k),l_allSummaries(i)(k).actual_targets,'HOSTS','SUMMARIZED_HOSTS'),'RIGHT');
		ELSE
			print_pcol('-','RIGHT');
		END IF;

		-- Not collected Hosts
		IF l_allSummaries(i)(k).notcollected > 0 THEN
			print_pcol(get_hosts_not_collected_link(l_allSummaries(i)(k),l_allSummaries(i)(k).notcollected),'RIGHT');		
		ELSE
			print_pcol('-','RIGHT');		
		END IF;

		-- Issue Hosts
		IF l_allSummaries(i)(k).issues > 0 THEN
			print_pcol(get_issue_fmt_link(l_allSummaries(i)(k),l_allSummaries(i)(k).issues,'ISSUE','ISSUE_HOSTS'),'RIGHT');
		ELSE
			print_pcol('-','RIGHT');
		END IF;

		-- All Hosts
		IF l_allSummaries(i)(k).hostcount > 0 THEN
			print_pcol(get_summary_drilldown_fmt_link(l_allSummaries(i)(k),l_allSummaries(i)(k).hostcount,'HOSTS','ALL_HOSTS'),'RIGHT');
		ELSE
			print_pcol('-','RIGHT');
		END IF;

		print_pcol(get_fmt_storage(l_allSummaries(i)(k).rawsize));
		print_pcol(get_fmt_storage(l_allSummaries(i)(k).sizeb));
		print_pcol(get_fmt_storage(l_allSummaries(i)(k).used));
		print_pcol(get_fmt_storage(l_allSummaries(i)(k).disk_backup_size));
		print_pcol(get_fmt_storage(l_others_used));
		print_pcol(get_storage_usage_meter(l_allSummaries(i)(k).rawsize,l_percent_used));
		print_pcol(get_fmt_storage(l_allSummaries(i)(k).free));                                  	

		-- Format the related links column
		l_formatstring := get_history_link(l_allSummaries(i)(k));

		IF l_allSummaries(i)(k).warnings > 0 THEN

			l_formatstring := l_formatstring||' '||get_issue_fmt_link(l_allSummaries(i)(k),'Warnings','WARNING','ALL_HOSTS');

		END IF;

		print_pcol(l_formatstring,'LEFT');

		print_prow_close;
                               
	ELSIF  l_tables(i)(j) = c_summary_host_table THEN

		print_prow_open(l_row_color,l_bg_color);

		IF	l_allSummaries(i)(k).id IS NULL OR 
			l_group_id = l_allSummaries(i)(k).id
		THEN
			print_pcol(l_allSummaries(i)(k).name ,'LEFT');
		ELSE		
			print_pcol(get_hostdetails_fmt_link(l_allSummaries(i)(k)),'LEFT');
		END IF;

		print_pcol(get_fmt_storage(l_allSummaries(i)(k).rawsize));
		print_pcol(get_fmt_storage(l_allSummaries(i)(k).sizeb));
		print_pcol(get_fmt_AU_storage(l_allSummaries(i)(k).oracle_database_size,l_allSummaries(i)(k).oracle_database_used));
		print_pcol(get_fmt_AU_storage(l_allSummaries(i)(k).local_filesystem_size,l_allSummaries(i)(k).local_filesystem_used));
		print_pcol(get_fmt_AU_storage(l_allSummaries(i)(k).nfs_exclusive_size,l_allSummaries(i)(k).nfs_exclusive_used));
		print_pcol(get_fmt_AU_storage(l_allSummaries(i)(k).volumemanager_size,l_allSummaries(i)(k).volumemanager_used));
		print_pcol(get_fmt_AU_storage(l_allSummaries(i)(k).swraid_size,l_allSummaries(i)(k).swraid_used));
		print_pcol(get_fmt_storage(l_allSummaries(i)(k).disk_backup_size));
		print_pcol(get_fmt_AU_storage(l_allSummaries(i)(k).disk_size,l_allSummaries(i)(k).disk_used));
		print_pcol(get_storage_usage_meter(l_allSummaries(i)(k).rawsize,l_percent_used));
		print_pcol(get_fmt_storage(l_allSummaries(i)(k).free));
		
		-- Format the related links column
		l_formatstring := get_history_link(l_allSummaries(i)(k));

		IF	l_allSummaries(i)(k).id IS NULL OR 
			l_group_id = l_allSummaries(i)(k).id
		THEN			
		-- For totals check the count of hosts

			-- Issues for totals
			IF p_host_type IN ('ALL_HOSTS','FAILED_HOSTS','ISSUE_HOSTS','WARNING_HOSTS') THEN
		
				IF l_allSummaries(i)(k).issues > 0  THEN

					l_formatstring := l_formatstring||' '||get_issue_fmt_link(l_allSummaries(i)(k),'Issues','ISSUE',p_host_type);
	
				END IF;

			END IF;

			-- Not collected for Totals
			IF p_host_type IN ('ALL_HOSTS','FAILED_HOSTS','NOT_COLLECTED_HOSTS','WARNING_HOSTS') THEN

				IF l_allSummaries(i)(k).notcollected > 0 THEN
	
					-- Not collected Hosts
					l_formatstring := l_formatstring||' '||get_hosts_not_collected_link((l_allSummaries(i)(k)),'Not Scheduled');

				END IF;

			END IF;
		
			-- Warnings for Totals
			IF l_allSummaries(i)(k).warnings > 0 THEN

				l_formatstring := l_formatstring||' '||get_issue_fmt_link(l_allSummaries(i)(k),'Warning','WARNING',p_host_type);

			END IF;

		ELSE
		-- For individual hosts check the summaryflag

			-- Issues link for INdividual hosts
			IF l_allSummaries(i)(k).summaryFlag = 'I' THEN

				l_formatstring := l_formatstring||' '||get_issue_fmt_link(l_allSummaries(i)(k),'Issues','ISSUE');

			ELSIF l_allSummaries(i)(k).summaryFlag = 'N' THEN
			-- LInk for Not collected Hosts

				l_formatstring := l_formatstring||' '||get_hosts_not_collected_link((l_allSummaries(i)(k)),'Not Scheduled');

			END IF;				
		
			IF l_allSummaries(i)(k).warnings > 0 THEN

				l_formatstring := l_formatstring||' '||get_issue_fmt_link(l_allSummaries(i)(k),'Warning','WARNING');

			END IF;

		END IF;

		print_pcol(l_formatstring,'LEFT');

		print_prow_close;
                               
	ELSIF  l_tables(i)(j) = c_summary_host_vendor_table THEN	

		print_prow_open(l_row_color,l_bg_color);
		
		IF	l_allSummaries(i)(k).id IS NULL OR
			l_group_id = l_allSummaries(i)(k).id
		THEN
			print_pcol(l_allSummaries(i)(k).name ,'LEFT');
		ELSE		
			print_pcol(get_hostdetails_fmt_link(l_allSummaries(i)(k)),'LEFT');
		END IF;
                          
		print_pcol(get_fmt_storage(l_allSummaries(i)(k).rawsize));
		print_pcol(get_fmt_storage(l_allSummaries(i)(k).sizeb));
		print_pcol(get_fmt_AU_storage(l_allSummaries(i)(k).vendor_emc_rawsize,l_allSummaries(i)(k).vendor_emc_size));
		print_pcol(get_fmt_storage(l_allSummaries(i)(k).vendor_nfs_netapp_size));
		print_pcol(get_fmt_storage(l_allSummaries(i)(k).vendor_sun_size));
		print_pcol(get_fmt_storage(l_allSummaries(i)(k).vendor_hitachi_size));
		print_pcol(get_fmt_storage(l_vendor_others));
		print_prow_close;
                               
	END IF;

END printrow;

BEGIN

	GETTIME(l_time);
	l_elapsedtime := l_time;

	-- Quick look up reports
	IF UPPER(p_group_name) LIKE '% LIKE %' THEN

		l_type_of_reports := stringTable(p_group_type);
	
	ELSE -- Drill down reports
		-- If not specified to be a report of hosts then decide on the type of report
		IF p_report_type = 'HOSTS' THEN 
		-- else flag it as a host report
			l_type_of_reports := stringTable('HOST');
		ELSE

			-- If no child p_child_group_type is passed then pick from the defaults for this parent type from the reports stormon_group_reports_type
			SELECT	child_type
			BULK COLLECT INTO l_type_of_reports
			FROM	stormon_group_reports_type
			WHERE	report_type = 'DC_LOB_REPORTS'
			AND	parent_type = p_group_type;

			-- If no children group types of specified type for this parent type then its a host report
			IF l_type_of_reports IS NULL OR NOT l_type_of_reports.EXISTS(1) THEN
			
				l_type_of_reports := stringTable('HOST');
			
			END IF;
	
		END IF;

	END IF;

	--------------------------------------------------------------------------------------------
	-- List of fields to be selected for summary
	--------------------------------------------------------------------------------------------
	l_summary_fields := 'SELECT	summaryObject(
						ROWNUM,
						a.name,						
						a.id,	
						a.type,
						a.timestamp		,			-- timestamp
						a.collection_timestamp	,			-- collection_timestamp
						a.hostcount		,			-- hostcount
						a.actual_targets		,			-- actual_targets
						a.issues			,			-- issues
						a.hostcount-(a.actual_targets+a.issues),		-- not collected
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
				)';

	-------------------------------------------------------------------------------------------
	-- Get the group id based on the parent type, child type , parent name and child name
	--------------------------------------------------------------------------------------------
	BEGIN

		IF UPPER(p_group_name) LIKE '% LIKE %' THEN
			
			--
			-- Get the count of all ids for the predicates
			-- Cannot do a bulk fetch of remote objects for dynamic sql, Gives ORA-1019 error,unable to allocate memory.
			--	
			EXECUTE IMMEDIATE '
			SELECT	COUNT(*)
			FROM	storage_summaryObject_view a
			WHERE	a.type = '''||p_group_type||'''
			AND	( 
					'||p_group_name||' 
			)'
			INTO l_id_count;							

			-- If only one id is available , save the group id , the report is a single id report.
			IF l_id_count = 1 THEN

				-- Get all the ids for the predicates
				EXECUTE IMMEDIATE '
				SELECT	a.id
				FROM	storage_summaryObject_view a
				WHERE	a.type = '''||p_group_type||'''
				AND	( 
						'||p_group_name||' 
				)
				AND	ROWNUM = 1 '
				INTO l_group_id;	
				
			END IF;

		ELSE	
			
			BEGIN	
		
				SELECT	a.id
				INTO	l_group_id
				FROM	storage_summaryObject_view a
				WHERE	a.type = p_group_type
				AND	a.name = p_group_name;

			EXCEPTION

				WHEN NO_DATA_FOUND THEN 
					NULL;
					-- Can print no summaries message here					

			END;

		END IF;	

	EXCEPTION

		WHEN OTHERS THEN
			RAISE;
	END;


	---------------------------------------------------
	--	If this is a host quick lookup report and
	--	search returns only one host, print the 
	-- 	host detail report
	---------------------------------------------------
	IF	p_group_type = 'HOST' AND
		l_group_id IS NOT NULL
	THEN
		STORAGE.DISPLAY_HOST_DETAILS(l_group_id);
		RETURN;
	END IF;


        ---------------------------------------------------
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


	
	FOR i IN l_type_of_reports.FIRST..l_type_of_reports.LAST LOOP

		-- add a new query
		-- Set up the sql predicate for the query
		l_queries.EXTEND;

		IF l_type_of_reports(i) = 'HOST' THEN
		-- if a host type report
					
			IF UPPER(p_group_name) LIKE '% LIKE %' THEN 			
				-- this is a like query
				l_queries(l_queries.LAST) := ' 		storage_summaryObject_view a	
								WHERE 	a.type = '''||p_group_type||'''	
								AND	('
									||p_group_name||'
								)';	

			ELSE			
				-- the sql predicate to get the target_ids from stormon_host_groups
				l_queries(l_queries.LAST) := ' 		storage_summaryObject_view a,									
									stormon_host_groups b									
								WHERE 	a.id = b.target_id
								AND	b.group_id = '''||l_group_id||'''';
			END IF;

			-----------------------------------------------------------
			-- predicate for fetching hosts with issues
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

				l_queries(l_queries.LAST) := l_queries(l_queries.LAST)||' AND '||l_host_predicate;

			END IF;
			
			
		ELSE			
		-- for group type reports

			IF UPPER(p_group_name) LIKE '% LIKE %' THEN 	

				-- the sql predicate to get the ids from stormon_group_of_groups_table			
				l_queries(l_queries.LAST) := ' 		storage_summaryObject_view a							
								WHERE 	a.type = '''||l_type_of_reports(i)||'''
								AND	(
										'||p_group_name||'
								)'
								 ;				

			ELSE

				-- the sql predicate to get the ids from stormon_group_of_groups_table			
				l_queries(l_queries.LAST) := ' 		storage_summaryObject_view a,									
									stormon_group_of_groups_table c
								WHERE 	a.id = c.child_id 
								AND	a.type = '''||l_type_of_reports(i)||'''
								AND	c.parent_id = '''||l_group_id||''''
								 ;	
			
			END IF;
							
		END IF;

		-- Set the tables based on the report type
		-- Titles for each table
		l_tables.EXTEND;
		l_titles.EXTEND;

		IF l_type_of_reports(i) = 'HOST' THEN

			l_tables(l_tables.LAST) := stringTable(	
							c_summary_host_table,
							c_summary_host_vendor_table);

			l_titles(l_titles.LAST) := stringTable(
							'Storage Summary By Usage',
							'Storage Summary By Vendor');

		ELSIF l_type_of_reports(i) = 'REPORTING_DATACENTER' THEN

			l_tables(l_tables.LAST)	:= stringTable(c_summary_dc_table);
			l_titles(l_titles.LAST)	:=  stringTable('Storage Summary By Data Center');

		ELSIF l_type_of_reports(i) = 'REPORTING_LOB' THEN

			l_tables(l_tables.LAST)	:= stringTable(c_summary_lob_table);
			l_titles(l_titles.LAST)	:=  stringTable('Storage Summary By LOB');
		
		ELSIF l_type_of_reports(i) = 'REPORTING_DATACENTER_LOB' THEN

			IF p_group_type = 'REPORTING_DATACENTER' THEN
							
				l_tables(l_tables.LAST)	:= stringTable(c_summary_lob_table);
				l_titles(l_titles.LAST)	:=  stringTable('Storage Summary By LOB');

			ELSIF p_group_type = 'REPORTING_LOB' THEN

				l_tables(l_tables.LAST)	:= stringTable(c_summary_dc_table);
				l_titles(l_titles.LAST)	:=  stringTable('Storage Summary By Data Center');

			END IF;

		END IF;

	END LOOP;

	------------------------------------------
	-- Charts to be plotted for this report
	------------------------------------------
	-- If host report
	IF p_report_type = 'HOSTS' THEN
		
		IF	p_host_type = 'ALL_HOSTS' OR 
			p_host_type = 'SUMMARIZED_HOSTS'
		THEN
		-- HOST LIST REPORT, ALL HOSTS OR HOSTS WITH SUMMARIES

			l_charts.EXTEND(4);

			l_charts(1).chart_no := c_USEDFREE;
			l_charts(1).query_no := 1;

			l_charts(2).chart_no := c_VENDOR;
			l_charts(2).query_no := 1;

			l_charts(3).chart_no := c_HOSTUSED;
			l_charts(3).query_no := 1;

			l_charts(4).chart_no := c_HOSTFREE;
			l_charts(4).query_no := 1;

		END IF;
	

	-- If a on host report print the charts depending on the type of parent group
	ELSE
				
		-- DBMS_OUTPUT.PUT_LINE('Group type '||p_group_type);
		IF p_group_type = 'HOST' THEN

			l_charts.EXTEND(4);

			l_charts(1).chart_no := c_USEDFREE;
			l_charts(1).query_no := 1;

			l_charts(2).chart_no := c_VENDOR;
			l_charts(2).query_no := 1;

			l_charts(3).chart_no := c_HOSTUSED;
			l_charts(3).query_no := 1;

			l_charts(4).chart_no := c_HOSTFREE;
			l_charts(4).query_no := 1;

		ELSIF p_group_type = 'REPORTING_ALL' THEN
			-- All LOB and DCs
			
			l_charts.EXTEND(4);

			l_charts(1).chart_no := c_USEDFREE;
			l_charts(1).query_no := 1;

			l_charts(2).chart_no := c_DC;
			l_charts(2).query_no := 1;

			l_charts(3).chart_no := c_LOB;
			l_charts(3).query_no := 2;

			l_charts(4).chart_no := c_VENDOR;
			l_charts(4).query_no := 1;

		
		ELSIF	p_group_type = 'REPORTING_DATACENTER' THEN
		-- All LOBs for a DC
						
			l_charts.EXTEND(3);

			l_charts(1).chart_no := c_USEDFREE;
			l_charts(1).query_no := 1;

			l_charts(2).chart_no := c_LOB;
			l_charts(2).query_no := 1;

			l_charts(3).chart_no := c_VENDOR;
			l_charts(3).query_no := 1;

		ELSIF p_group_type = 'REPORTING_LOB' THEN
		-- All DCs for LOB'

			l_charts.EXTEND(3);

			l_charts(1).chart_no := c_USEDFREE;
			l_charts(1).query_no := 1;

			l_charts(2).chart_no := c_DC;
			l_charts(2).query_no := 1;

			l_charts(3).chart_no := c_VENDOR;
			l_charts(3).query_no := 1;

		ELSIF p_group_type = 'REPORTING_DATACENTER_LOB' THEN
		-- All DCs for LOB'

			IF	p_host_type = 'ALL_HOSTS' OR 
				p_host_type = 'SUMMARIZED_HOSTS'			
			THEN
			-- HOST LIST REPORT, ALL HOSTS OR HOSTS WITH SUMMARIES

				l_charts.EXTEND(4);
	
				l_charts(1).chart_no := c_USEDFREE;
				l_charts(1).query_no := 1;

				l_charts(2).chart_no := c_VENDOR;
				l_charts(2).query_no := 1;

				l_charts(3).chart_no := c_HOSTUSED;
				l_charts(3).query_no := 1;

				l_charts(4).chart_no := c_HOSTFREE;
				l_charts(4).query_no := 1;

			END IF;

		ELSE

			l_charts.EXTEND(2);

			l_charts(1).chart_no := c_USEDFREE;
			l_charts(1).query_no := 1;

			l_charts(2).chart_no := c_VENDOR;
			l_charts(2).query_no := 1;

		END IF;

	END IF;


	GETTIME(l_time,'Time taken to build the predicates');	

	IF l_group_id IS NOT NULL THEN
	
		BEGIN

			-- The summary Row
			EXECUTE IMMEDIATE l_summary_fields||' FROM  storage_summaryObject_view a WHERE a.id = '''||l_group_id||'''' INTO  l_group_summary;

		EXCEPTION
			WHEN NO_DATA_FOUND THEN
				NULL;
		END;

	ELSE

		IF p_group_type = 'HOST' THEN

			EXECUTE IMMEDIATE l_summary_fields||'	
			FROM	
			(
				SELECT	''TOTAL''			name,						
					NULL				id,	
					'''||p_group_type||'''		type,
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
					SUM(a.vendor_nfs_others_size)	vendor_nfs_others_size
				FROM	storage_summaryObject_view a,		
					(	
						SELECT  id	
						FROM    storage_summaryObject_view        						
						WHERE   type = '''||p_group_type||'''	
						AND     ('||p_group_name||')        			     
						UNION
						SELECT  id
						FROM    stormon_group_table a
						WHERE   type = ''SHARED_GROUP''	
						AND     NOT EXISTS	
	        				(
					                SELECT  1
        					        FROM    stormon_host_groups
			        		        WHERE   group_id = a.id
		        	        		AND     target_id NOT IN
					                (
        					                SELECT  target_id
                					        FROM    storage_summaryObject_view                        					        
			        	                	WHERE	type = '''||p_group_type||'''		
        	        			        	AND     ('||p_group_name||')		
			        	        	)		
					        )	
					) b
				WHERE a.id = b.id											
			) a'
			INTO  l_group_summary;	


		ELSE

			EXECUTE IMMEDIATE l_summary_fields||'	
			FROM	
			(
				SELECT	''TOTAL''			name,						
					NULL				id,	
					'''||p_group_type||'''		type,
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
					SUM(a.vendor_nfs_others_size)	vendor_nfs_others_size
				FROM	storage_summaryObject_view a,		
					(	
						SELECT  target_id id	
						FROM    stormon_host_groups a,
        						stormon_group_table b
						WHERE   a.group_id = b.id	
						AND     b.type = '''||p_group_type||'''	
						AND     ('||p_group_name||')        			     
						UNION
						SELECT  id
						FROM    stormon_group_table a
						WHERE   type = ''SHARED_GROUP''	
						AND     NOT EXISTS	
	        				(
					                SELECT  1
        					        FROM    stormon_host_groups
			        		        WHERE   group_id = a.id
		        	        		AND     target_id NOT IN
					                (
        					                SELECT  target_id
                					        FROM    stormon_host_groups a,
                        					        stormon_group_table b
			        	                	WHERE   a.group_id = b.id
	        			        	        AND     b.type = '''||p_group_type||'''		
        	        			        	AND     ('||p_group_name||')		
			        	        	)		
					        )	
					) b
				WHERE a.id = b.id											
			) a'
			INTO  l_group_summary;	

		END IF;
	
		-- I am setting this so the != l_group_id check doest fail, else we have to NVL l_group_id in the != checks
		l_group_id := '-1';
			
	END IF;


	----------------------------------------------------
	-- BUILD THE LIST OF ID'S FROM RESULTS OF EACH QUERY
	----------------------------------------------------
	FOR i IN l_queries.FIRST..l_queries.LAST LOOP
	
		l_allSummaries.EXTEND;

		--------------------------------------------------------------
		-- BUILD THE SQL FOR THE TABLE USING PREDICATES CREATED ABOVE
		--------------------------------------------------------------

		--PRINTSTMT(l_summary_fields||' FROM '||l_queries(i)||' ORDER BY '||l_orderList);
		--HTP.P( l_summary_fields||' FROM '||l_queries(i)||' ORDER BY '||l_orderList);
	
		EXECUTE IMMEDIATE l_summary_fields||' FROM '||l_queries(i)||' ORDER BY '||l_orderList BULK COLLECT INTO  l_targetSummaries;

		l_allSummaries(i) := l_targetSummaries;

		IF 
			l_allSummaries IS NOT NULL AND 
			l_allSummaries.EXISTS(i) AND 
			l_allSummaries(i) IS NOT NULL AND 
			l_allSummaries(i).EXISTS(1) 
		THEN
			
			IF l_group_summary IS NOT NULL THEN

				l_allSummaries(i).EXTEND;
				l_allSummaries(i)(l_allSummaries(i).LAST) := l_group_summary;	
				l_allSummaries(i)(l_allSummaries(i).LAST).name := 'TOTAL';

			END IF;

		ELSE

--			HTP.P('RESULTS ARE NULL');
			l_allSummaries(i) := NULL;			

		END IF;

		GETTIME(l_time,'Time taken to Get IDs for query '||i);

	END LOOP;	-- END LOOP FOR ALL QUERIES

	---------------------------------------------
	--	CHARTING START HERE
	---------------------------------------------
        print_ptable_open('1','0');
        print_prow_open;
    
	IF l_charts IS NOT NULL AND l_charts.EXISTS(1) THEN

		FOR i IN l_charts.FIRST..l_charts.LAST LOOP

			l_charttitle 		:= NULL;
			l_chartsubtitle		:= NULL;
			l_fieldname 		:= NULL;
			l_fieldvalue 		:= NULL;
			l_legend 		:= NULL;
			l_values 		:= NULL;

			-- HTP.P(' Chart '||l_charts(i).chart_no||'<BR>');

			CASE l_charts(i).chart_no
		
			--------------------------------
			-- USED FREE PIE CHART
			--------------------------------
			WHEN c_USEDFREE THEN

                                l_bartag     := 'U';

				-- Take the last summary , it should represent the total for the other summaries
				-- either compued on the fly with id = null
				--
				IF 	l_allSummaries IS NOT NULL AND
					l_allSummaries.EXISTS(l_charts(i).query_no) AND
					l_allSummaries(l_charts(i).query_no).EXISTS(1) AND
					(
						l_allSummaries(l_charts(i).query_no)(l_allSummaries(l_charts(i).query_no).LAST).id IS NULL						
						OR
						l_allSummaries(l_charts(i).query_no)(l_allSummaries(l_charts(i).query_no).LAST).id = l_group_id	
					)
				THEN   
					
					IF 	l_allSummaries(l_charts(i).query_no)(l_allSummaries(l_charts(i).query_no).LAST).used != 0 OR
						l_allSummaries(l_charts(i).query_no)(l_allSummaries(l_charts(i).query_no).LAST).free != 0 
					THEN

						-- HTP.P(' chart used free <BR> ');
						l_fieldname	:= stringTable('Used','Free');	
						l_fieldvalue	:= stringTable(	l_allSummaries(l_charts(i).query_no)(l_allSummaries(l_charts(i).query_no).LAST).used,
										l_allSummaries(l_charts(i).query_no)(l_allSummaries(l_charts(i).query_no).LAST).free);
					END IF;

					l_charttitle := 'Used vs Free';
			        	l_chartsubtitle := '(Total ' || get_fmt_storage(l_allSummaries(l_charts(i).query_no)(l_allSummaries(l_charts(i).query_no).LAST).sizeb) ||  ' )';

	        		END IF;

			--------------------------------
			-- VENDOR PIE CHART
			--------------------------------
			WHEN c_VENDOR THEN

                                l_bartag     := 'V';

				IF 	l_allSummaries IS NOT NULL AND
					l_allSummaries.EXISTS(l_charts(i).query_no) AND
					l_allSummaries(l_charts(i).query_no).EXISTS(1) AND
					(
						l_allSummaries(l_charts(i).query_no)(l_allSummaries(l_charts(i).query_no).LAST).id IS NULL
						OR
						l_allSummaries(l_charts(i).query_no)(l_allSummaries(l_charts(i).query_no).LAST).id = l_group_id	
					)
				THEN   					

					SELECT	name,
						sizeb
					BULK COLLECT INTO l_fieldname, l_fieldvalue
					FROM	(
							SELECT	'Network Appliance(NFS)' name,
								VENDOR_NFS_NETAPP_SIZE sizeb					
							FROM	TABLE ( CAST ( l_allSummaries(l_charts(i).query_no) as storageSummaryTable ) )
							WHERE	(  
									id IS NULL 
									OR id = l_group_id
								)
							AND	VENDOR_NFS_NETAPP_SIZE > 0	
							UNION	
							SELECT	 'Others' name,
								( VENDOR_OTHERS_SIZE + VENDOR_NFS_EMC_SIZE + VENDOR_NFS_SUN_SIZE + VENDOR_NFS_OTHERS_SIZE ) sizeb
							FROM	TABLE ( CAST ( l_allSummaries(l_charts(i).query_no) as storageSummaryTable ) )
							WHERE	(  
									id IS NULL 
									OR id = l_group_id
								)
							AND	( VENDOR_OTHERS_SIZE + VENDOR_NFS_EMC_SIZE + VENDOR_NFS_SUN_SIZE + VENDOR_NFS_OTHERS_SIZE ) > 0
							UNION
							SELECT	'Hitachi' name,
								VENDOR_HITACHI_SIZE sizeb
							FROM	TABLE ( CAST ( l_allSummaries(l_charts(i).query_no) as storageSummaryTable ) )
							WHERE	(  
									id IS NULL 
									OR id = l_group_id
								)
							AND	VENDOR_HITACHI_SIZE > 0
							UNION
							SELECT	'Sun' name,
								VENDOR_SUN_SIZE	sizeb
							FROM	TABLE ( CAST ( l_allSummaries(l_charts(i).query_no) as storageSummaryTable ) )
							WHERE	(  
									id IS NULL 
									OR id = l_group_id
								)
							AND	VENDOR_SUN_SIZE > 0
							UNION
							SELECT	'EMC Symmetrix' name,
								VENDOR_EMC_SIZE sizeb
							FROM	TABLE ( CAST ( l_allSummaries(l_charts(i).query_no) as storageSummaryTable ) )
							WHERE	(  
									id IS NULL 
									OR id = l_group_id
								)
							AND	VENDOR_EMC_SIZE > 0
					)
					ORDER BY sizeb DESC;

					l_charttitle := 'Vendor Distribution';
			        	l_chartsubtitle := '(Total ' || get_fmt_storage(l_allSummaries(l_charts(i).query_no)(l_allSummaries(l_charts(i).query_no).LAST).sizeb) ||  ' )';
						
	        		END IF;

			--------------------------------
			-- DATACENTER PIE CHART
			--------------------------------
			WHEN c_DC THEN

				l_bartag     := 'D';

				IF 	l_allSummaries IS NOT NULL AND
					l_allSummaries.EXISTS(l_charts(i).query_no) AND
					l_allSummaries(l_charts(i).query_no).EXISTS(1)
				THEN


				        SELECT  DECODE(FLOOR(rk/c_topnrank),0,name,'OTHERS'),
					        SUM(sizeb)						
					BULK COLLECT INTO l_fieldname, l_fieldvalue
				        FROM (
				                SELECT  name,
				                        sizeb,
				                        RANK() OVER ( ORDER BY sizeb DESC ) rk
				                FROM   	TABLE ( CAST ( l_allSummaries(l_charts(i).query_no) as storageSummaryTable ) )
				                WHERE   ( 
								id IS NOT NULL
								AND id != l_group_id
						)
				                AND     sizeb != 0				                				                
				        )
				        GROUP BY
				        DECODE(FLOOR(rk/c_topnrank),0,name,'OTHERS')
				        ORDER BY
			                SUM(sizeb) DESC;														

					l_charttitle := 'Data Center Distribution';
			        	l_chartsubtitle := '(Total ' || get_fmt_storage(l_allSummaries(l_charts(i).query_no)(l_allSummaries(l_charts(i).query_no).LAST).sizeb) ||  ' )';

				END IF;	

			--------------------------------
			-- LOB PIE CHART
			--------------------------------
			WHEN c_LOB THEN	
							
                                l_bartag     := 'L';

				IF 	l_allSummaries IS NOT NULL AND
					l_allSummaries.EXISTS(l_charts(i).query_no) AND
					l_allSummaries(l_charts(i).query_no).EXISTS(1)
				THEN

				        SELECT  DECODE(FLOOR(rk/c_topnrank),0,name,'OTHERS') name,
				                SUM(sizeb)						
					BULK COLLECT INTO l_fieldname, l_fieldvalue
				        FROM (
				                SELECT  name,
				                        sizeb,
				                        RANK() OVER ( ORDER BY sizeb DESC ) rk
				                FROM   	TABLE ( CAST ( l_allSummaries(l_charts(i).query_no) as storageSummaryTable ) )
				                WHERE  ( 
								id IS NOT NULL
								AND id != l_group_id
						)
				                AND     sizeb != 0				                				                
				        )
				        GROUP BY
				        DECODE(FLOOR(rk/c_topnrank),0,name,'OTHERS')
				        ORDER BY
			                SUM(sizeb) DESC;													

					l_charttitle := 'LOB Distribution';
			        	l_chartsubtitle := '(Total ' || get_fmt_storage(l_allSummaries(l_charts(i).query_no)(l_allSummaries(l_charts(i).query_no).LAST).sizeb) ||  ' )';

				END IF;	

			--------------------------------
			-- HOSTS USED PIE CHART
			--------------------------------
			WHEN c_HOSTUSED THEN

                                l_bartag     := 'H';
				IF 	l_allSummaries IS NOT NULL AND
					l_allSummaries.EXISTS(l_charts(i).query_no) AND
					l_allSummaries(l_charts(i).query_no).EXISTS(1)
				THEN

				        SELECT  DECODE(FLOOR(rk/c_topnrank),0,name,'OTHERS') name,
				                SUM(used)
					BULK COLLECT INTO l_fieldname, l_fieldvalue
				        FROM (
				                SELECT  name,
				                        used,
				                        RANK() OVER ( ORDER BY used DESC ) rk
				                FROM   	TABLE ( CAST ( l_allSummaries(l_charts(i).query_no) as storageSummaryTable ) )
				                WHERE  ( 
								id IS NOT NULL
								AND id != l_group_id
						)
				                AND     used != 0				                				                
				        )
				        GROUP BY
				        DECODE(FLOOR(rk/c_topnrank),0,name,'OTHERS')
				        ORDER BY
			                SUM(used) DESC;	
								
					l_charttitle := 'Used Storage by Host';
			        	l_chartsubtitle := '(Used ' || get_fmt_storage(l_allSummaries(l_charts(i).query_no)(l_allSummaries(l_charts(i).query_no).LAST).used) ||  ' )';

				END IF;
	
			--------------------------------
			-- HOSTS FREE PIE CHART
			--------------------------------
			WHEN c_HOSTFREE THEN

                                l_bartag     := 'H';

				IF 	l_allSummaries IS NOT NULL AND
					l_allSummaries.EXISTS(l_charts(i).query_no) AND
					l_allSummaries(l_charts(i).query_no).EXISTS(1)
				THEN
				
				        SELECT  DECODE(FLOOR(rk/c_topnrank),0,name,'OTHERS') name,
				                SUM(free)
					BULK COLLECT INTO l_fieldname,l_fieldvalue
				        FROM (
				                SELECT  name,
				                        free,
				                        RANK() OVER ( ORDER BY free DESC ) rk
				                FROM   	TABLE ( CAST ( l_allSummaries(l_charts(i).query_no) as storageSummaryTable ) )
				                WHERE  ( 
								id IS NOT NULL
								AND id != l_group_id
						)
				                AND     free != 0				                				                
				        )
				        GROUP BY
				        DECODE(FLOOR(rk/c_topnrank),0,name,'OTHERS')
				        ORDER BY
			                SUM(free) DESC;

					l_charttitle := 'Free Storage by Host';	
			        	l_chartsubtitle := '(Free ' || get_fmt_storage(l_allSummaries(l_charts(i).query_no)(l_allSummaries(l_charts(i).query_no).LAST).free) ||  ' )';

				END IF;	

			END CASE;


			-- At least 1 element to draw a pie
			IF l_fieldname IS NOT NULL AND l_fieldname.EXISTS(1) THEN

                                l_unit := get_storage_unit(l_allSummaries(l_charts(i).query_no)(l_allSummaries(l_charts(i).query_no).LAST).sizeb);
				
				-- HTP.P(' Drawning chart '||l_charttitle||'<BR>');

   				print_pcol(get_chart_image(
						l_charttitle ,
						l_chartsubtitle,
						l_fieldname,
						l_fieldvalue,					
						p_chart_type,
						l_unit,
                                                l_bartag                     
						) ,
						'CENTER' );
			END IF;

		END LOOP;

	END IF;

        print_prow_close;                
        print_ptable_close;   
 	GETTIME(l_time,' Time taken to print Charts ');              	
	---------------------------------------------
	--	PRINT EACH TABLE
	---------------------------------------------
	FOR i IN l_queries.FIRST..l_queries.LAST LOOP
		
		IF 
			l_tables IS NOT NULL AND 
			l_tables.EXISTS(i) AND
			l_tables(i).EXISTS(1) 
		THEN

			FOR j IN l_tables(i).FIRST..l_tables(i).LAST LOOP
	
				-----------------------------------------------------
				--	PRINT THE TABLE TITLE AND COLUMN HEADINGS
				--	< REPLACE THIS WITH HTML STDOUT>
				-----------------------------------------------------
				print_ptable_open('1','2');
	
				IF 
					l_titles IS NOT NULL AND
					l_titles.EXISTS(i) AND 
					l_titles(i).EXISTS(j) 
				THEN
					print_prow_open;
					print_pheader(l_titles(i)(j));
					print_prow_close;						
				END IF;
	
				IF 
					l_list_of_summary_tables IS NOT NULL AND
					l_list_of_summary_tables.EXISTS(l_tables(i)(j)) AND 
					l_list_of_summary_tables(l_tables(i)(j)).EXISTS(1) 
				THEN
	
					--------------------------------------------
					-- PRINT FIRST TITLE ROW
					--------------------------------------------
	                                print_prow_open(NULL,TABLE_HEADER_COLOR);				
	
					FOR k IN l_list_of_summary_tables(l_tables(i)(j)).FIRST..l_list_of_summary_tables(l_tables(i)(j)).LAST LOOP
	
	                                        IF l_list_of_summary_tables(l_tables(i)(j))(k).subtitle IS NOT NULL AND l_list_of_summary_tables(l_tables(i)(j))(k).subtitle.EXISTS(1) THEN
	
	  						print_phcol(get_summary_sorting_link(l_list_of_summary_columns(l_list_of_summary_tables(l_tables(i)(j))(k).column_no).column_name,l_list_of_summary_tables(l_tables(i)(j))(k).column_no),'CENTER',NULL,l_list_of_summary_tables(l_tables(i)(j))(k).subtitle.COUNT);
	
						ELSE
						        IF (l_tables(i)(j) != c_summary_host_vendor_table) THEN

	  							print_phcol(get_summary_sorting_link(l_list_of_summary_columns(l_list_of_summary_tables(l_tables(i)(j))(k).column_no).column_name,l_list_of_summary_tables(l_tables(i)(j))(k).column_no),'CENTER',NULL,1,2);				
	  					 	ELSE
	  							print_phcol(get_summary_sorting_link(l_list_of_summary_columns(l_list_of_summary_tables(l_tables(i)(j))(k).column_no).column_name,l_list_of_summary_tables(l_tables(i)(j))(k).column_no),'CENTER',NULL);					  					 	
	  					 	END IF;	

	
	                                        END IF;
	
	
					END LOOP;		
	
			                print_prow_close;
	
	
					--------------------------------------------
					-- PRINT SECOND TITLE ROW IF IT EXISTS
					--------------------------------------------
					FOR k IN l_list_of_summary_tables(l_tables(i)(j)).FIRST..l_list_of_summary_tables(l_tables(i)(j)).LAST LOOP
	
						IF l_list_of_summary_tables(l_tables(i)(j))(k).subtitle IS NOT NULL AND l_list_of_summary_tables(l_tables(i)(j))(k).subtitle.EXISTS(1) THEN
	
		                                	print_prow_open(NULL,TABLE_HEADER_COLOR);				
	
			                                FOR l IN l_list_of_summary_tables(l_tables(i)(j)).FIRST..l_list_of_summary_tables(l_tables(i)(j)).LAST LOOP
			
			                                        IF l_list_of_summary_tables(l_tables(i)(j))(l).subtitle IS NOT NULL AND l_list_of_summary_tables(l_tables(i)(j))(l).subtitle.EXISTS(1) THEN
			
			                                                FOR m IN l_list_of_summary_tables(l_tables(i)(j))(l).subtitle.FIRST..l_list_of_summary_tables(l_tables(i)(j))(l).subtitle.LAST LOOP
			
			                                                        print_phcol(get_summary_sorting_link(l_list_of_summary_columns(l_list_of_summary_tables(l_tables(i)(j))(l).subtitle(m)).column_name,l_list_of_summary_tables(l_tables(i)(j))(l).subtitle(m)));
			
			                                                END LOOP;
			
								--ELSE
			
			                                        --	print_phcol(NULL);
									
			                                        END IF;
			
			                                END LOOP;
	
			                		print_prow_close;
	
							EXIT;
	
						END IF;
	
					END LOOP;
	
	
				END IF;
	
	
				---------------------------------------------
				--	PRINT ROWS FOR EACH TABLE
				--	< REPLACE THIS WITH HTML STDOUT>
				---------------------------------------------
				IF 
					l_allSummaries IS NULL OR 
					NOT l_allSummaries.EXISTS(i) OR 
					l_allSummaries(i) IS NULL OR
					NOT l_allSummaries(i).EXISTS(1) 
				THEN			
					STORAGE.GET_DC_LOB_FROM_NAME(p_group_name,p_group_type,l_dc,l_lob);		
					print_prow_open;					
	                        	print_pcol('<I>' || ' No storage exists for this combination '||STORAGE.GET_LOB_DC_TITLE(l_dc,l_lob) || '</I>','LEFT');
	                        	print_prow_close;
				ELSE
	
					FOR k IN l_allSummaries(i).FIRST..l_allSummaries(i).LAST LOOP
				
						PRINTROW(i,j,k);	
	
					END LOOP;
				
				END IF;
	
		                print_ptable_close;
		                print_line_break;
	
			END LOOP;

		END IF;

	END LOOP;  -- END OF LOOP FOR PRINTING ALL SUMMARIES

	GETTIME(l_time,' Time taken to print Tables');
	GETTIME(l_elapsedtime,' Total Time taken');	

END CLASSICAL_DRILL_DOWN;

--------------------------------------------------------------------
-- Name : quick_look_up_report
-- 
-- Desc : build storage on a wild card search for group or host names.
--	  More than one name to be separated by a ,
--
--------------------------------------------------------------------
PROCEDURE quick_look_up_report(
				p_group_name_like 	stormon_group_table.name%TYPE,
				p_group_type		stormon_group_table.type%TYPE,
				p_chart_type		IN VARCHAR2 DEFAULT 'PIE'
		)
IS

l_predicate		VARCHAR2(32767) := NULL;
l_arguments_list	stringTable;
l_group_name_like 	stormon_group_table.name%TYPE;


BEGIN
		
	l_group_name_like := replace(p_group_name_like,',',' ');        	
	l_arguments_list := STORAGE.PARSE_ARGUMENTS(l_group_name_like,' ');        


	IF l_arguments_list IS NOT NULL AND l_arguments_list.EXISTS(1) THEN

		FOR i IN l_arguments_list.FIRST..l_arguments_list.LAST LOOP
			
			IF l_predicate IS NULL THEN

				l_predicate := ' LOWER(name) LIKE ''%'||TRIM(LOWER(l_arguments_list(i)))||'%'' ';
			ELSE
				l_predicate :=	l_predicate||' OR LOWER(name) LIKE ''%'||TRIM(LOWER(l_arguments_list(i)))||'%'' ';		
	
			END IF;
		END LOOP;
		
	ELSE
	   l_predicate := ' LOWER(name) LIKE ''%''';
	END IF;

	STORAGE.classical_drill_down(l_predicate,p_group_type,p_chart_type);

END quick_look_up_report;


BEGIN

NULL;

-- HTP.p gives an error here , RJKumar ?
--	HTP.p('invoking initialization '||'<BR>');

	DBMS_OUTPUT.PUT_LINE(' invoking initialization ');
	STORAGE.INITIALIZE;

end; -- package specification STORAGE
/
