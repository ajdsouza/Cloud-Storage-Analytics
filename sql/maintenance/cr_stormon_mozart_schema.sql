--
-- Copyright  (c) 2001,2002  Oracle Corporation All rights reserved 
--
--
--
-- $Id: cr_stormon_mozart_schema.sql,v 1.1 2003/07/24 00:53:00 ajdsouza Exp $ 
--
-- NAME  
--	 cr_stormon_mozart_schema.sql
--
-- DESC
--	Create schema for the mozart stormon user
--
--
-- MODIFIED	(MM/DD/YY)
-- ajdsouza	07/23/03 	- Created
--
--

-- Execute as stormon mozart user ( stormon_mozart )

DROP SYNONYM mgmt_current_metrics
/
DROP SYNONYM mgmt_metrics
/
DROP SYNONYM mgmt_targets
/
DROP SYNONYM smp_view_targets
/
DROP SYNONYM smp_vdj_job_per_target
/


CREATE SYNONYM mgmt_current_metrics FOR storage_rep.mgmt_current_metrics
/
CREATE SYNONYM mgmt_metrics FOR storage_rep.mgmt_metrics
/
CREATE SYNONYM mgmt_targets FOR storage_rep.mozart_mgmt_targets
/
CREATE SYNONYM smp_view_targets FOR storage_rep.mozart_node_target_map
/
CREATE SYNONYM smp_vdj_job_per_target FOR storage_rep.mozart_smp_vdj_job_per_target
/

