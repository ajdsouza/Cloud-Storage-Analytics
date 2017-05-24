/*

 	Copyright  (c) 2001,2002  Oracle Corporation All rights reserved

  	$Id: idainfo.c,v 1.10 2002/12/06 23:30:03 vswamida Exp $
  	
	This program executes ioctls to get the vendor,
	serial number, model, and host adapter number from
	the Compaq Array given as a parameter.

	Vijay Swamidass 10/18/2002
*/

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/types.h>
#include <asm/types.h>
#include <sys/ioctl.h>
#include <drivers/block/ida_ioctl.h>
#include <drivers/block/ida_cmd.h>
#include "stormon.h"

/* Max size of command line argument - logical name*/
#define BUFFER_SIZE     256

struct faulttol_type
{
  __u8 ft_id;
  char *ft_mode;
};

/* Taken from fwspecwww.doc */
static struct faulttol_type ft_modes[] = {
  {0, "RAID 0"},
  {1, "Data Guard (RAID 4)"},
  {2, "Mirroring (RAID 1)"},
  {3, "Distributed Data Guard (RAID 5)"}
};
#define FTMODESSIZE (sizeof(ft_modes)/sizeof(struct faulttol_type))

/* Taken from drivers/block/cciss.c in the Linux source */
struct board_type
{
  __u32 board_id;
  char *product_name;
};

static struct board_type products[] = {
  {0x0040110E, "IDA"},
  {0x0140110E, "IDA-2"},
  {0x1040110E, "IAES"},
  {0x2040110E, "SMART"},
  {0x3040110E, "SMART-2/E"},
  {0x40300E11, "SMART-2/P"},
  {0x40310E11, "SMART-2SL"},
  {0x40320E11, "Smart Array 3200"},
  {0x40330E11, "Smart Array 3100ES"},
  {0x40340E11, "Smart Array 221"},
  {0x40400E11, "Integrated Array"},
  {0x40510E11, "Smart Array 4250ES"},
  {0x40580E11, "Smart Array 431"},
};
#define PRODUCTSSIZE (sizeof(products)/sizeof(struct board_type))

/*******************************************************************
*
* ARGUMENTS:
*       path name of a compaq raid array, i.e. /dev/ida/c0d0
*
* DESC :
*       return the vendor, model, serial number and other
*	disk related information
*
********************************************************************/

int main (int argc, char **argv)
{
  char *logicalname;
  int disk;			/* File handle */
  int r;			/* Return code for ioctls */
  int k;			/* counter */

  ida_ioctl_t *ida_ioctl;	/* Command Structure for ida ioctl */
  int drives;			/* Number of drives in the array */
  int ft;			/* Fault tolerance mode */
  int cylinders;
  int heads;
  unsigned int sectors;
  double capacity;		/* Capacity */
  char product[20];
  char serial[40];

  /* Store the effective userid, - to restore before ioctl and 
     open commands   */

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
    CHECK AND VALIDATE ARGUMENT, LOGICAL NAME OF THE DISK DEVICE
  ------------------------------------------------------------*/

  /* Check for argument */
  if (argc <= 1)
    {
      printf ("error:: Usage : idainfo <logicalname>\n");
      exit (EXIT_FAILURE);
    }

  /* Copy the input arguments with null termination */
  if (checkandcopy (&logicalname, argv[1], BUFFER_SIZE) != EXIT_SUCCESS)
    {
      printf ("error:: idainfo.c: Argument larger than buffersize %d \n",
	      BUFFER_SIZE);
      exit (EXIT_FAILURE);
    }

  /* Validate the input, only disk name allowed no flags, 
     raise error if arg begins with - */
  if (logicalname[0] == '-')
    {
      printf ("error:: idainfo.c: Invalid argument %s \n", logicalname);
      exit (EXIT_FAILURE);
    }


  /*------------------------------------------------------------
    GET THE FILE DESCRIPTOR
   ------------------------------------------------------------*/

  /* Restore the root effective userid of the process */
  seteuid (effectiveuid);

  if ((disk = open (logicalname, O_RDONLY | O_NDELAY)) == -1)
    {
      /* revoke effective root uid privilege */
      seteuid (getuid ());
      printf ("error:: %d %s \n", errno, strerror (errno));
      exit (EXIT_FAILURE);
    }

  /* revoke effective root uid privilege */
  seteuid (getuid ());

  /* Free the malloced memory for logicalname */
  free (logicalname);

  ida_ioctl = calloc (1, sizeof (ida_ioctl_t));

  /* -------------------------------------
     Get Configuration 
     SENSE CONFIG 0x50
     ------------------------------------- */

  ida_ioctl->cmd = SENSE_CONFIG;
  ida_ioctl->blk = 0;
  ida_ioctl->blk_cnt = 0;

  /* Restore the root effective userid of the process */
  seteuid (effectiveuid);

  r = ioctl (disk, IDAPASSTHRU, ida_ioctl);

  /* revoke effective root uid privilege */
  seteuid (getuid ());

  if (r)
    {
      close (disk);
      printf ("error:: %d %s \n", errno, strerror (errno));
      exit (EXIT_FAILURE);
    }

  drives = ida_ioctl->c.config.log_unit_phys_drv;
  ft = ida_ioctl->c.config.fault_tol_mode;
  cylinders = ida_ioctl->c.config.drv.cyl;
  heads = ida_ioctl->c.config.drv.heads;
  sectors = ida_ioctl->c.config.drv.sect_per_track * heads * cylinders;


  /* -------------------------------------
     Get Physical Drive Info 
     ID_PHYS_DRV 0x15
     ------------------------------------- 
     This is not needed at the moment. 

     bzero(ida_ioctl,sizeof(ida_ioctl));
     for (k = 0; k < drives; k++)
     {
     ida_ioctl->cmd = ID_PHYS_DRV;
     ida_ioctl->blk = 0;

     Bits 24-31 are the disk number

     ida_ioctl->blk |= (0xff & k) << 24;
     ida_ioctl->blk_cnt = 0;
     ida_ioctl->unit = k;
     r = ioctl (disk, IDAPASSTHRU, ida_ioctl);
     if (r)
     {
     close (disk);
     printf ("error:: %d %s \n", errno, strerror (errno));
     exit (EXIT_FAILURE);
     }

     printf ("%s\n", ida_ioctl->c.id_phys_drv.drv_model);
     printf ("%s\n", ida_ioctl->c.id_phys_drv.drv_sn);
     }
   */

  /* -------------------------------------
     Get Drive ID (Serial)
     ID_LOG_DRV_EXT 0x18
     ------------------------------------- */
  ida_ioctl->cmd = ID_LOG_DRV_EXT;
  ida_ioctl->blk = 0;
  ida_ioctl->blk_cnt = 0;

  /* Restore the root effective userid of the process */
  seteuid (effectiveuid);

  r = ioctl (disk, IDAPASSTHRU, ida_ioctl);

  /* revoke effective root uid privilege */
  seteuid (getuid ());

  if (r)
    {
      close (disk);
      printf ("error:: %d %s \n", errno, strerror (errno));
      exit (EXIT_FAILURE);
    }

  /* log_drv_id is a 4 byte identifier assigned to the logical
   * drive. Value will be 0xffffffff if the drive is unused. */
  sprintf (serial, "%8.8x", ida_ioctl->c.id_log_drv_ext.log_drv_id);

  /* -------------------------------------
     Get Controller Product Name 
     ID_CTLR 0x11
     ------------------------------------- */
  bzero (ida_ioctl, sizeof (ida_ioctl));
  ida_ioctl->cmd = ID_CTLR;
  ida_ioctl->blk = 0;
  ida_ioctl->blk_cnt = 0;

  /* Restore the root effective userid of the process */
  seteuid (effectiveuid);

  r = ioctl (disk, IDAPASSTHRU, ida_ioctl);

  /* revoke effective root uid privilege */
  seteuid (getuid ());

  if (r)
    {
      close (disk);
      printf ("error:: %d %s \n", errno, strerror (errno));
      exit (EXIT_FAILURE);
    }

  /* Get product id (model) */
  k = 0;
  while (ida_ioctl->c.id_ctlr.board_id != products[k].board_id
	 && k < PRODUCTSSIZE)
    {
      k++;
    }

  sprintf (product, "%s", products[k].product_name);

  /* -------------------------------------
     Get Logical Drive Size 
     ID_LOG_DRV 0x10
     ------------------------------------- */

  bzero (ida_ioctl, sizeof (ida_ioctl));
  ida_ioctl->cmd = ID_LOG_DRV;
  ida_ioctl->blk = 0;
  ida_ioctl->blk_cnt = 0;

  /* Restore the root effective userid of the process */
  seteuid (effectiveuid);

  r = ioctl (disk, IDAPASSTHRU, ida_ioctl);

  /* revoke effective root uid privilege */
  seteuid (getuid ());

  if (r)
    {
      close (disk);
      printf ("error:: %d %s \n", errno, strerror (errno));
      exit (EXIT_FAILURE);
    }

  capacity =
    (double) ida_ioctl->c.id_log_drv.nr_blks *
    (double) ida_ioctl->c.id_log_drv.blk_size;

  /* PRINT THE RESULTS */

  /* Hardcode the Vendor because it is always Compaq */
  printf ("ida_unique_id::%s\n", serial);
  printf ("ida_vendor::Compaq\n");
  printf ("ida_product::%s\n", product);
  printf ("ida_cylinders::%d\n", cylinders);
  printf ("ida_sectors::%d\n", sectors);
  printf ("ida_capacity::%0.0f\n", capacity);
  printf ("ida_physicaldrives::%d\n", drives);

  /* Get Raid Mode */
  k = 0;
  while (ft != ft_modes[k].ft_id && k < FTMODESSIZE)
    {
      k++;
    }

  printf ("ida_faulttolmode::%s\n", ft_modes[k].ft_mode);

  free (ida_ioctl);
  close (disk);
  exit (EXIT_SUCCESS);
}
