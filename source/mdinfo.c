/*

 	Copyright  (c) 2001,2002  Oracle Corporation All rights reserved

  	$Id: mdinfo.c,v 1.8 2002/12/05 18:09:41 vswamida Exp $

	Vijay Swamidass 10/18/2002
*/

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <endian.h>
#include <sys/types.h>
#include <sys/ioctl.h>
#include <linux/major.h>
#include <linux/raid/md_u.h>
#include "stormon.h"

/* Max size of command line argument - logical name*/
#define BUFFER_SIZE     256

/* Max size of char buffers*/
#define BUFFER_MAX      255


int main (int argc, char **argv)
{
  char *logicalname;

  int disk;
  int r;
  int k;

  mdu_array_info_t array_info;	/* Array Information Struct */
  mdu_disk_info_t disk_info;	/* Disk Information Struct */

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
      printf ("error:: Usage : mdinfo <logicalname>\n");
      exit (EXIT_FAILURE);
    }

  /* Copy the input arguments with null termination */
  if (checkandcopy (&logicalname, argv[1], BUFFER_SIZE) != EXIT_SUCCESS)
    {
      printf ("error:: mdinfo.c: Argument larger than buffersize %d \n",
	      BUFFER_SIZE);
      exit (EXIT_FAILURE);
    }

  /* Validate the input, only disk name allowed no flags, 
     raise error if arg begins with - */
  if (logicalname[0] == '-')
    {
      printf ("error:: mdinfo.c: Invalid argument %s \n", logicalname);
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


  /*----------------------------------------------------------------
    		MD ARRAY INFO	
    ----------------------------------------------------------------*/

  /* Restore the root effective userid of the process */
  seteuid (effectiveuid);

  /* query the disk for identity information */
  r = ioctl (disk, GET_ARRAY_INFO, &array_info);

  /* revoke effective root uid privilege */
  seteuid (getuid ());

  if (r)
    {
      close (disk);
      printf ("error:: %d %s \n", errno, strerror (errno));
      exit (EXIT_FAILURE);
    }

  printf ("type=DISK|level=%d|chunksize=%d|size=%.0f|major=%d|minor=%d\n",
	  array_info.level, array_info.chunk_size,
	  (double) array_info.size, MD_MAJOR, array_info.md_minor);


  /*----------------------------------------------------------------
    		MD DISK INFO	
    ----------------------------------------------------------------*/

  /* Iterate through the disks based on the number provided above */
  for (k = 0; k < array_info.nr_disks; k++)
    {

      disk_info.number = k;

      /* Restore the root effective userid of the process */
      seteuid (effectiveuid);

      /* query the disk for identity information */
      r = ioctl (disk, GET_DISK_INFO, &disk_info);

      /* revoke effective root uid privilege */
      seteuid (getuid ());

      if (r)
	{
	  close (disk);
	  printf ("error:: %d %s \n", errno, strerror (errno));
	  exit (EXIT_FAILURE);
	}

      printf ("type=SUBDISK|major=%d|minor=%d|raiddisk=%d\n", disk_info.major,
	      disk_info.minor, disk_info.raid_disk);

    }

  close (disk);
  exit (EXIT_SUCCESS);
}
