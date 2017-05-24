/*

 	Copyright  (c) 2001,2002  Oracle Corporation All rights reserved

  	$Id: ccissinfo.c,v 1.8 2002/12/05 18:10:57 vswamida Exp $
  	
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
#include <linux/cciss_ioctl.h>
#include "stormon.h"

/* Max size of command line argument - logical name*/
#define BUFFER_SIZE     256

/* Size of CISS Inquiry buffer */
#define INQ_BUF_SIZE     128

#define CISS_INQUIRY 0x12	/* SCSI/CISS Inquiry */
#define CCISS_READ_CAPACITY 0x25	/* Read Capacity */
#define CISS_REPORT_LOG 0xc2	/* Report Logical LUNs */
#define CISS_REPORT_PHYS 0xc3	/* Report Physical LUNs */

struct faulttol_type
{
  __u8 ft_id;
  char *ft_mode;
};

/* Taken from page 21 of Open_CISS_Spec.pdf (http://sourceforge.net/projects/cciss/) */
static struct faulttol_type ft_modes[] = {
  {0x00, "RAID 0"},
  {0x01, "Data Guard (RAID 4)"},
  {0x02, "Mirroring (RAID 1)"},
  {0x03, "Distributed Data Guard (RAID 5)"},
  {0x04, "RAID 5+1"},
  {0x05, "Advanced Data Guard (RAID ADG)"},
  {0xFF, "INVALID DATA"}
};
#define FTMODESSIZE (sizeof(ft_modes)/sizeof(struct faulttol_type))

typedef struct _ReadCapdata_struct
{
  BYTE total_size[4];		// Total size in blocks
  BYTE block_size[4];		// Size of blocks in bytes
}
ReadCapdata_struct;

// Data returned
typedef struct _ReportLUNdata_struct
{
  BYTE LUNListLength[4];
  DWORD reserved;
  BYTE LUN[CISS_MAX_LUN][8];
}
ReportLunData_struct;

/*******************************************************************
*
* ARGUMENTS:
*       path name of a compaq raid array, i.e. /dev/cciss/c0d0
*
* DESC :
*       return the vendor, model, serial number and other related info
*
********************************************************************/

int main (int argc, char **argv)
{
  char *logicalname;
  int disk;			/* File handle */
  int r;			/* Return Code for ioctls */
  int k;

  IOCTL_Command_struct *cciss_ioctl;	/* Command struct for cciss ioctl */
  ReadCapdata_struct *size_buff;	/* Disk Capacity Ioctl struct */
  /* ReportLunData_struct *ld_buff;
     PhysDevAddr_struct *phys_dev; */
  unsigned int total_size;
  unsigned int block_size;
  unsigned int cylinders;
  unsigned int heads;
  unsigned int sectors;
  unsigned int lun;		/* The lun number of the disk */
  int pagelength;		/* Length of the page returned */
  double capacity;		/* Capacity of the disk */

  unsigned char vendor[9];
  unsigned char product[17];
  unsigned char revision[5];
  unsigned char ft;		/* Fault Toleratant Mode */
  unsigned char inq_buff[INQ_BUF_SIZE];	/* Buffer returned by CISS_INQUIRY */

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
      printf ("error:: Usage : ccissinfo <logicalname>\n");
      exit (EXIT_FAILURE);
    }

  /* Copy the input arguments with null termination */
  if (checkandcopy (&logicalname, argv[1], BUFFER_SIZE) != EXIT_SUCCESS)
    {
      printf ("error:: ccissinfo.c: Argument larger than buffersize %d \n",
	      BUFFER_SIZE);
      exit (EXIT_FAILURE);
    }

  /* Validate the input, only disk name allowed no flags, 
     raise error if arg begins with - */
  if (logicalname[0] == '-')
    {
      printf ("error:: ccissinfo.c: Invalid argument %s \n", logicalname);
      exit (EXIT_FAILURE);
    }

  /* Take the LUN From the last number in the disk name
   * i.e. in /dev/cciss/c0d1, the lun is '1' */
  lun = atoi (&logicalname[15]);

  /* 
   * GET THE FILE DESCRIPTOR
   */

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

  /* 
   * INQUIRY: GET THE VENDOR, PRODUCT, REVISION
   */

  cciss_ioctl = calloc (1, sizeof (IOCTL_Command_struct));

  cciss_ioctl->LUN_info.LogDev.Mode = 1;	/* Logical Volume Addressing */
  cciss_ioctl->LUN_info.LogDev.VolId = lun;
  cciss_ioctl->Request.Timeout = 0;
  cciss_ioctl->Request.Type.Type = TYPE_CMD;
  cciss_ioctl->Request.Type.Attribute = ATTR_SIMPLE;
  cciss_ioctl->Request.Type.Direction = XFER_READ;
  cciss_ioctl->Request.CDBLen = 6;
  cciss_ioctl->Request.CDB[0] = CISS_INQUIRY;
  cciss_ioctl->Request.CDB[1] = 0;
  cciss_ioctl->Request.CDB[2] = 0;
  cciss_ioctl->Request.CDB[3] = 0;
  cciss_ioctl->Request.CDB[4] = INQ_BUF_SIZE;
  cciss_ioctl->Request.CDB[5] = 0;

  cciss_ioctl->buf_size = INQ_BUF_SIZE;
  bzero (inq_buff, INQ_BUF_SIZE);
  cciss_ioctl->buf = inq_buff;

  /* Restore the root effective userid of the process */
  seteuid (effectiveuid);

  r = ioctl (disk, CCISS_PASSTHRU, cciss_ioctl);

  /* revoke effective root uid privilege */
  seteuid (getuid ());

  if (r)
    {
      close (disk);
      printf ("error:: %d %s \n", errno, strerror (errno));
      exit (EXIT_FAILURE);
    }

  sprintf (vendor, "%8.8s", &inq_buff[8]);
  sprintf (product, "%16.16s", &inq_buff[16]);
  sprintf (revision, "%4.4s", &inq_buff[32]);

  /* 
   * GET THE SERIAL (UNIQUE ID)
   */

  free (cciss_ioctl);
  cciss_ioctl = calloc (1, sizeof (IOCTL_Command_struct));

  cciss_ioctl->LUN_info.LogDev.Mode = 1;
  cciss_ioctl->LUN_info.LogDev.VolId = lun;
  cciss_ioctl->Request.Timeout = 0;
  cciss_ioctl->Request.Type.Type = TYPE_CMD;
  cciss_ioctl->Request.Type.Attribute = ATTR_SIMPLE;
  cciss_ioctl->Request.Type.Direction = XFER_READ;
  cciss_ioctl->Request.CDBLen = 6;
  cciss_ioctl->Request.CDB[0] = CISS_INQUIRY;
  cciss_ioctl->Request.CDB[1] = 1;	/* EVPD */
  cciss_ioctl->Request.CDB[2] = 0x83;	/* Page Code for Device Identification */
  cciss_ioctl->Request.CDB[3] = 0;
  cciss_ioctl->Request.CDB[4] = INQ_BUF_SIZE;
  cciss_ioctl->Request.CDB[5] = 0;

  cciss_ioctl->buf_size = INQ_BUF_SIZE;
  bzero (inq_buff, INQ_BUF_SIZE);
  cciss_ioctl->buf = inq_buff;

  /* Restore the root effective userid of the process */
  seteuid (effectiveuid);

  r = ioctl (disk, CCISS_PASSTHRU, cciss_ioctl);

  /* revoke effective root uid privilege */
  seteuid (getuid ());

  if (r)
    {
      close (disk);
      printf ("error:: %d %s \n", errno, strerror (errno));
      exit (EXIT_FAILURE);
    }

  pagelength = inq_buff[3];
  printf ("cciss_unique_id::");
  for (k = 4; k < 4 + pagelength; k++)
    {
      printf ("%2.2x", inq_buff[k]);
    }
  printf ("\n");

  /* 
   * GET THE DISK GEOMETRY
   */

  free (cciss_ioctl);
  cciss_ioctl = calloc (1, sizeof (IOCTL_Command_struct));

  cciss_ioctl->LUN_info.LogDev.Mode = 1;
  cciss_ioctl->LUN_info.LogDev.VolId = lun;
  cciss_ioctl->Request.Timeout = 0;
  cciss_ioctl->Request.Type.Type = TYPE_CMD;
  cciss_ioctl->Request.Type.Attribute = ATTR_SIMPLE;
  cciss_ioctl->Request.Type.Direction = XFER_READ;
  cciss_ioctl->Request.CDBLen = 6;
  cciss_ioctl->Request.CDB[0] = CISS_INQUIRY;
  cciss_ioctl->Request.CDB[1] = 1;	/* EVPD */
  cciss_ioctl->Request.CDB[2] = 0xC1;	/* Page Code for Log. Drive Geometry */
  cciss_ioctl->Request.CDB[3] = 0;
  cciss_ioctl->Request.CDB[4] = INQ_BUF_SIZE;
  cciss_ioctl->Request.CDB[5] = 0;

  cciss_ioctl->buf_size = INQ_BUF_SIZE;
  bzero (inq_buff, INQ_BUF_SIZE);
  cciss_ioctl->buf = inq_buff;

  /* Restore the root effective userid of the process */
  seteuid (effectiveuid);

  r = ioctl (disk, CCISS_PASSTHRU, cciss_ioctl);

  /* revoke effective root uid privilege */
  seteuid (getuid ());

  if (r)
    {
      close (disk);
      printf ("error:: %d %s \n", errno, strerror (errno));
      exit (EXIT_FAILURE);
    }

  pagelength = inq_buff[3];

  cylinders = 0;
  cylinders = (0xff & inq_buff[4]) << 8;
  cylinders |= 0xff & inq_buff[5];
  heads = inq_buff[6];
  sectors = inq_buff[7] * heads * cylinders;
  /* Fault Tolerant Configuration */
  ft = inq_buff[8];

  /* 
   * READ CAPACITY
   */

  free (cciss_ioctl);
  cciss_ioctl = calloc (1, sizeof (IOCTL_Command_struct));

  cciss_ioctl->LUN_info.LogDev.Mode = 1;
  cciss_ioctl->Request.CDBLen = 10;
  cciss_ioctl->Request.Type.Type = TYPE_CMD;
  cciss_ioctl->Request.Type.Attribute = ATTR_SIMPLE;
  cciss_ioctl->Request.Type.Direction = XFER_READ;
  cciss_ioctl->Request.Timeout = 0;
  cciss_ioctl->Request.CDB[0] = CCISS_READ_CAPACITY;

  cciss_ioctl->buf_size = sizeof (ReadCapdata_struct);
  cciss_ioctl->buf = calloc (1, sizeof (ReadCapdata_struct));

  /* Restore the root effective userid of the process */
  seteuid (effectiveuid);

  r = ioctl (disk, CCISS_PASSTHRU, cciss_ioctl);

  /* revoke effective root uid privilege */
  seteuid (getuid ());

  if (r)
    {
      close (disk);
      printf ("error:: %d %s \n", errno, strerror (errno));
      exit (EXIT_FAILURE);
    }

  size_buff = (ReadCapdata_struct *) cciss_ioctl->buf;

  total_size = (0xff & (unsigned int) (size_buff->total_size[0])) << 24;
  total_size |= (0xff & (unsigned int) (size_buff->total_size[1])) << 16;
  total_size |= (0xff & (unsigned int) (size_buff->total_size[2])) << 8;
  total_size |= (0xff & (unsigned int) (size_buff->total_size[3]));

  block_size = (0xff & (unsigned int) (size_buff->block_size[0])) << 24;
  block_size |= (0xff & (unsigned int) (size_buff->block_size[1])) << 16;
  block_size |= (0xff & (unsigned int) (size_buff->block_size[2])) << 8;
  block_size |= (0xff & (unsigned int) (size_buff->block_size[3]));

  capacity = (double) total_size *(double) block_size;

  /*
   * PRINT THE RESULTS
   */

  printf ("cciss_vendor::%s\n", vendor);
  printf ("cciss_product::%s\n", product);
  printf ("cciss_revision::%s\n", revision);
  printf ("cciss_cylinders::%u\n", cylinders);
  printf ("cciss_sectors::%u\n", sectors);
  printf ("cciss_capacity::%.0f\n", capacity);

  /* Get Raid Mode */
  k = 0;
  while (ft != ft_modes[k].ft_id && k < FTMODESSIZE)
    {
      k++;
    }

  printf ("cciss_faulttolmode::%s\n", ft_modes[k].ft_mode);

  free (cciss_ioctl);
  close (disk);
  exit (EXIT_SUCCESS);
}
