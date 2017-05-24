SET SERVEROUT ON;
DECLARE
l_rid  mgmt_storage_report_data.global_unique_id%TYPE;
BEGIN
select ecm_snapshot_id INTO l_rid 
from mgmt_v_storage_report_data 
where storage_layer = 'NFS' and rownum = 1;
STORAGE_ECM_PKG.POST_PROCESSING(l_rid);
END;
/

COMMIT;
