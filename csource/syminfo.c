/*
*
* Copyright  (c) 2001,2002  Oracle Corporation All rights reserved
*
*  $Id: syminfo.c,v 1.19 2003/01/07 00:12:14 vswamida Exp $ 
*
*
* NAME  
*	 syminfo.c
*
* DESC 
*
* FUNCTIONS
*
*
* NOTES
*
*
* MODIFIED	(MM/DD/YY)
* vswamida	09/17/02 - Created
*
*/

#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <strings.h>            /* for bzero */
#include <unistd.h>             /* for getuid, setuid, etc. */
#include "symapi.h"
#include "stormon.h"

#ifdef D_HPUX
#define seteuid(x) setresuid(-1,(x),-1)
#define setegid(x) setresgid(-1,(x),-1)
#endif

  /*------------------------------------------------------------
    CONVERT DEVICE STATUS CODE TO A STRING
   ------------------------------------------------------------*/
char *
GetStatusStr (SYMAPI_DEV_STATUS_T status_code)
{
  char *statusstr = NULL;	/* Contains the status for the current device */

  /* Translate status code to a string */
  switch (status_code)
    {
    case SYMAPI_DEV_STATUS_NA:
      statusstr = "NA";
      break;
    case SYMAPI_DEV_STATUS_NOT_READY:
      statusstr = "NOT_READY";
      break;
    case SYMAPI_DEV_STATUS_READY:
      statusstr = "READY";
      break;
    case SYMAPI_DEV_STATUS_WRITE_DISABLED:
      statusstr = "WRITE_DISABLED";
      break;
    default:
      statusstr = "UNKNOWN_STATUS";
    }
  return statusstr;
}


  /*------------------------------------------------------------
    CONVERT DEVICE CONFIG CODE TO A STRING
   ------------------------------------------------------------*/
char *
GetConfigStr (SYMAPI_DEV_CONFIG_T config_code)
{
  char *configstr = NULL;	/* Contains the configuration for the current device */

  /* Translate configuration code to a string */
  switch (config_code)
    {
    case SYMAPI_DC_UNPROTECTED:
      configstr = "UNPROTECTED";
      break;
    case SYMAPI_DC_MIRR_2:
      configstr = "MIRR_2";
      break;
    case SYMAPI_DC_MIRR_3:
      configstr = "MIRR_3";
      break;
    case SYMAPI_DC_MIRR_4:
      configstr = "MIRR_4";
      break;
    case SYMAPI_DC_RAID_S:
      configstr = "RAID_S";
      break;
    case SYMAPI_DC_RAID_S_MIRR:
      configstr = "RAID_S_MIRR";
      break;
    case SYMAPI_DC_RDF_R1:
      configstr = "RDF_R1";
      break;
    case SYMAPI_DC_RDF_R2:
      configstr = "RDF_R2";
      break;
    case SYMAPI_DC_RDF_R1_RAID_S:
      configstr = "RDF_R1_RAID_S";
      break;
    case SYMAPI_DC_RDF_R2_RAID_S:
      configstr = "RDF_R2_RAID_S";
      break;
    case SYMAPI_DC_RDF_R1_MIRR:
      configstr = "RDF_R1_MIRR";
      break;
    case SYMAPI_DC_RDF_R2_MIRR:
      configstr = "RDF_R2_MIRR";
      break;
    case SYMAPI_DC_BCV:
      configstr = "BCV";
      break;
    case SYMAPI_DC_SPARE:
      configstr = "SPARE";
      break;
    case SYMAPI_DC_BCV_MIRR_2:
      configstr = "BCV_MIRR_2";
      break;
    case SYMAPI_DC_BCV_RDF_R1:
      configstr = "BCV_RDF_R1";
      break;
    case SYMAPI_DC_BCV_RDF_R1_MIRR:
      configstr = "BCV_RDF_R1_MIRR";
      break;
    case SYMAPI_DC_DRV:
      configstr = "DRV";
      break;
    case SYMAPI_DC_DRV_MIRR_2:
      configstr = "DRV_MIRR_2";
      break;
    case SYMAPI_DC_BCV_RDF_R2:
      configstr = "BCV_RDF_R2";
      break;
    case SYMAPI_DC_BCV_RDF_R2_MIRR:
      configstr = "BCV_RDF_R2_MIRR";
      break;
    default:
      configstr = "UNKNOWN_CONFIG";
    }
  return configstr;
}

  /*------------------------------------------------------------
    DECODE AND PRINT THE RESULTS
   ------------------------------------------------------------*/
void
PrintDevStruct (SYMAPI_DEVICE_T * dcfg)
{
  double blocks;
  double blocksize;
  SYMAPI_HYPER_T *hyper_config = NULL;	/* hyper configuration data structure pointer */

  /* Store the # of blocks and blocksize for later multiplication 
     Use double for portability */
  blocks = (double) (dcfg->dev_capacity);
  blocksize = (double) (dcfg->dev_block_size);

  printf ("%s|", dcfg->vendor_id);
  printf ("%s|", dcfg->product_id);
  printf ("%s|", dcfg->symid);
  printf ("%0.0f|", blocks * blocksize);
  printf ("%s|", dcfg->pdevname);
  printf ("%s|", dcfg->sym_devname);
  printf ("%s|", GetStatusStr (dcfg->dev_status));
  printf ("%s|", GetConfigStr (dcfg->dev_config));

  /*------------------------------------------------------------
    ITERATE THROUGH ALL THE HYPERS FOR THE DEVICE
    PRINT A UNIQUE ID FOR THE SPINDLE: 
	DIRECTOR_ID.INTERFACE.SCSI_ID.SERIAL_ID
   ------------------------------------------------------------*/
  for (hyper_config = dcfg->mset_hyper_info; hyper_config != NULL;
       hyper_config = hyper_config->p_next_hyper)
    {
      /* hyper_type 16 = SYMAPI_DT_REMOTE_R1
         hyper_type 32 = SYMAPI_DT_REMOTE_R2
         Skip these RDF Hypers because they do not have director_ident, 
         da_interface, or disk_scsi_id information */
      if (hyper_config->hyper_type != 16 && hyper_config->hyper_type != 32)
	{
	  printf ("%s.%x.%d.%s", hyper_config->director_ident,
		  hyper_config->da_interface, hyper_config->disk_scsi_id,
		  hyper_config->disk_serial_id);

	  /* Print a comma separator between each spindle only if there is another hyper
	     and it is not an RDF device.  RDF devices don't list a director_ident. */
	  if (hyper_config->p_next_hyper != NULL
	      && strcmp (hyper_config->p_next_hyper->director_ident, ""))
	    {
	      printf (",");
	    }
	}
    }
  printf ("\n");
}

/***** Begin Main ***********************************************/

int main (int argc, char **argv)
{

  /* License keys for symmetrix */
  /* char *licensearray[] = {
    "License Key: 7FBE-9150-E0BC-9CCD  SYMAPI Feature: BASE",
    "License Key: A936-39CD-A0FF-CDC5  SYMAPI Feature: Configuration Mgr"
  }; */

  /* License file */
  /* char licensefile[] = "/var/symapi/config/symapi_licenses.dat"; */
  /* Lock file */
  /* char lockfile[] = "/var/symapi/config/symapislck"; */

  /* Specifying a test database allows us to test the program logic without an
     real Sym */
  /* char static_database_file[] =
    "/usr/emc/API/symapi_old/db/sample_symapi_db1.bin"; */
  char *database_file;

  int logsetting = 0;
  int ret_code;			/* Return code for function calls */
  int sH;			/* Sym session handle */
  char **sim_id_list = NULL;	/* Symmetrix ID List */
  int symm_num;			/* Index for sim_id_list */
  int count;			/* Used as a parameter for Sym calls, Value not used */

  char **dev_name_list = NULL;	/* device filename list pointer */
  char **pdev_name_list = NULL;	/* device filename list pointer */
  int dev_num;			/* Index for dev_name_list */
  int pdev_num;			/* Index for dev_name_list */

  SYMAPI_DEVICE_T *dev_config = NULL;	/* device configuration data structure pointer */
  SYMAPI_DEVICE_T *pdev_config = NULL;	/* phys. device configuration data structure pointer */

  uid_t effectiveuid;

  /*----------------------------------------------------------
    SECURE THE PROGRAM
    ERASE ENVIRONMENT
    SAVE AND REVOKE EFFECTIVE SUID
  -----------------------------------------------------------*/

  /* Erase environment */
  eraseenv ();

  /* Store the effective user id of the process */
  effectiveuid = geteuid ();

  /* revoke effective root uid privilege */
  seteuid (getuid ());

  /*----------------------------------------------------------
    SET THE DATABASE FILE, NULL FOR PRODUCTION USE.
  ------------------------------------------------------------*/

#ifdef TEST
  database_file = static_database_file;
#else
  database_file = NULL;
#endif

  /*------------------------------------------------------------
    FUTURE: CREATE A LICENSE FILE AND LOCK FILE IF THEY ARE NOT PRESENT
  -------------------------------------------------------------*/

  /*------------------------------------------------------------
    CREATE THE SESSION WITH SYMINIT
   ------------------------------------------------------------*/

#ifndef TEST
  /* Restore the root effective userid of the process */
  seteuid (effectiveuid);

  ret_code =
    SymInit (database_file, SYMINIT_ACCMODE_NONE, &sH, NULL,
	     "ORACLE - Stormon");

  /* revoke effective root uid privilege */
  seteuid (getuid ());

  if (ret_code != SYMAPI_C_SUCCESS)
    {
      printf ("error:: syminfo.c: SymInit failed with code %d (%s)\n",
	      ret_code, SymPerror (sH, ret_code));
      exit (EXIT_FAILURE);
    }

  /* Turn of logging, to prevent writing to the disk */
  ret_code = SymPrefsSet (sH, SYM_PREF_LOGGING_STATE, &logsetting);
  if (ret_code != SYMAPI_C_SUCCESS)
    {
      printf ("error:: syminfo.c: SymPrefsSet failed with code %d (%s)\n",
	      ret_code, SymPerror (sH, ret_code));
      exit (EXIT_FAILURE);
    }

  /* Restore the root effective userid of the process */
  seteuid (effectiveuid);

  /* SymDiscover scans the devices and updates the configuration database */
  ret_code = SymDiscover (sH, NULL);

  /* revoke effective root uid privilege */
  seteuid (getuid ());

  if (ret_code != SYMAPI_C_SUCCESS)
    {
      printf ("error:: syminfo.c: SymDiscover failed with code %d (%s)\n",
	      ret_code, SymPerror (sH, ret_code));
      exit (EXIT_FAILURE);
    }

#else

  ret_code =
    SymInit (database_file, SYMINIT_ACCMODE_READ_MOD_NOWRITE, &sH, NULL,
	     "ORACLE - Stormon");

  if (ret_code != SYMAPI_C_SUCCESS)
    {
      printf ("error:: syminfo.c: SymInit failed with code %d (%s)\n",
	      ret_code, SymPerror (sH, ret_code));
      exit (EXIT_FAILURE);
    }

#endif

  /*------------------------------------------------------------
    CALL SYMLIST TO GET LIST OF ATTACHED SYMMETRIX DEVICES
   ------------------------------------------------------------*/

  ret_code = SymList (sH, &sim_id_list, &count);
  if (ret_code != SYMAPI_C_SUCCESS)
    {
      printf ("error:: syminfo.c: SymList failed with code %d (%s)\n",
	      ret_code, SymPerror (sH, ret_code));
      exit (EXIT_FAILURE);
    }

  /*------------------------------------------------------------
    ITERATE THROUGH ALL VISIBLE SYMMETRICES,
   ------------------------------------------------------------*/
  for (symm_num = 0; sim_id_list[symm_num] != NULL; symm_num++)
    {

  /*------------------------------------------------------------
    CALL SYMPDEVLIST TO GET LIST OF VISIBLE EMC PHYSICAL DEVICES. 

    FOR MULTIPATHED DEVICES WE WANT TO SEE BOTH PHYSICAL DEVICES. 
    SYMPDEVLIST RETURNS ALL EMC PHYSICAL DEVICES ON THE SYSTEM.
    SYMDEVLIST RETURNS ALL EMC DEVICE IDS (i.e. 000,03A) BUT ONLY 
    ONE PHYSICAL DEVICE (i.e. /dev/rdsk/xxxxxxx) PER DEVICE ID.  
   ------------------------------------------------------------*/
      ret_code =
	SymPdevList (sH, sim_id_list[symm_num], &pdev_name_list, &count);
      if (ret_code != SYMAPI_C_SUCCESS)
	{
	  printf ("error:: syminfo.c: SymPdevList failed with code %d (%s)\n",
		  ret_code, SymPerror (sH, ret_code));
	  exit (EXIT_FAILURE);
	}

  /*------------------------------------------------------------
    ITERATE THROUGH ALL THE PHYSICAL DEVICES ON THE SYM,
    CALL SYMPDEVSHOW TO GET CONFIGURATION OF THE DEVICE
    PRINT ALL THE RESULTS
   ------------------------------------------------------------*/
      for (pdev_num = 0; pdev_name_list[pdev_num] != NULL; pdev_num++)
	{
	  ret_code = SymPdevShow (sH, pdev_name_list[pdev_num], &pdev_config);
	  if (ret_code != SYMAPI_C_SUCCESS)
	    {
	      printf
		("error:: syminfo.c: SymPdevShow failed with code %d (%s)\n",
		 ret_code, SymPerror (sH, ret_code));
	      exit (EXIT_FAILURE);
	    }
	  PrintDevStruct (pdev_config);
	}

  /*------------------------------------------------------------
    CALL SYMDEVLIST TO GET LIST OF VISIBLE EMC DEVICES 
    ON EACH SYM
   ------------------------------------------------------------*/
      ret_code =
	SymDevList (sH, sim_id_list[symm_num], &dev_name_list, &count);
      if (ret_code != SYMAPI_C_SUCCESS)
	{
	  printf ("error:: syminfo.c: SymDevList failed with code %d (%s)\n",
		  ret_code, SymPerror (sH, ret_code));
	  exit (EXIT_FAILURE);
	}

  /*------------------------------------------------------------
    ITERATE THROUGH ALL THE DEVICES ON THE SYM,
    CALL SYMDEVSHOW TO GET CONFIGURATION OF THE DEVICE
   ------------------------------------------------------------*/
      for (dev_num = 0; dev_name_list[dev_num] != NULL; dev_num++)
	{
	  ret_code =
	    SymDevShow (sH, sim_id_list[symm_num], dev_name_list[dev_num],
			&dev_config);
	  if (ret_code != SYMAPI_C_SUCCESS)
	    {
	      printf
		("error:: syminfo.c: SymDevShow failed with code %d (%s)\n",
		 ret_code, SymPerror (sH, ret_code));
	      exit (EXIT_FAILURE);
	    }

	  /* we have already printed all the physical device info with 
	     sympdevlist, so we skip any devices that have physical paths */
	  if (strlen (dev_config->pdevname) == 0)
	    {
	      PrintDevStruct (dev_config);
	    }

	}
    }

  exit (EXIT_SUCCESS);
}
