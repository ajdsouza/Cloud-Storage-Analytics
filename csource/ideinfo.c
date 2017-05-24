/*

 	Copyright  (c) 2001,2002  Oracle Corporation All rights reserved

  	$Id: ideinfo.c,v 1.8 2002/12/05 18:10:11 vswamida Exp $

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
#include <netinet/in.h>
#include <linux/hdreg.h>	/* Contains defines for IDE Drives */
#include "stormon.h"

/* Max size of command line argument - logical name*/
#define BUFFER_SIZE     256

/* Max size of char buffers*/
#define BUFFER_MAX      255

typedef unsigned char byte;

void convert_idestring (byte * s, const int bytecount)
{
  byte *p = s;
  byte *end = &s[bytecount & ~1];	/* Make the bytecount even */

  for (p = end; p != s;)
    {
      unsigned short *pp = (unsigned short *) (p -= 2);
      *pp = ntohs (*pp);
    }
}

int main (int argc, char **argv)
{
  char *logicalname;

  int disk;
  int r;

  unsigned char model[40];
  unsigned char serial[20];
  unsigned char *ucmd;
  unsigned char *buffer;

  unsigned short *cylinders;
  unsigned short *heads;
  unsigned short *scts_trk;
  unsigned int *sectors;

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
      printf ("error:: Usage : ideinfo <logicalname>\n");
      exit (EXIT_FAILURE);
    }

  /* Copy the input arguments with null termination */
  if (checkandcopy (&logicalname, argv[1], BUFFER_SIZE) != EXIT_SUCCESS)
    {
      printf ("error:: ideinfo.c: Argument larger than buffersize %d \n",
	      BUFFER_SIZE);
      exit (EXIT_FAILURE);
    }

  /* Validate the input, only disk name allowed no flags, 
     raise error if arg begins with - */
  if (logicalname[0] == '-')
    {
      printf ("error:: ideinfo.c: Invalid argument %s \n", logicalname);
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
    				IDE IDENTIFY
    ---------------------------------------------------------------*/

  ucmd = (unsigned char *) malloc (4 + BUFFER_MAX);

  ucmd[0] = WIN_IDENTIFY;	/* Cmd 0xEC */
  ucmd[1] = 0;			/* Nsect */
  ucmd[2] = 0;			/* Feature */
  ucmd[3] = 0x01;		/* Sectors to read */

  buffer = ucmd + 4;

  /* Restore the root effective userid of the process */
  seteuid (effectiveuid);

  /* query the disk for identity information */
  r = ioctl (disk, HDIO_DRIVE_CMD, ucmd);

  /* revoke effective root uid privilege */
  seteuid (getuid ());
  close (disk);

  if (r)
    {
      printf ("error:: %d %s \n", errno, strerror (errno));

      exit (EXIT_FAILURE);
    }

  sprintf (serial, "%20.20s", &buffer[20]);
  sprintf (model, "%40.40s", &buffer[54]);
  sectors = (unsigned int *) (&buffer[120]);
  /* These are not reliable, so we don't do anything with them for now */
  cylinders = (unsigned short *) (&buffer[2]);
  heads = (unsigned short *) (&buffer[6]);
  scts_trk = (unsigned short *) (&buffer[12]);

  /* Convert the byte order */
  convert_idestring (serial, 20);
  convert_idestring (model, 40);

  printf ("ide_serial_no::%s\n", serial);
  printf ("ide_model::%s\n", model);
  /* Sector is 512 bytes - ANSI Standard X3T10/0948D */
  printf ("ide_capacity::%.0f\n", (double) *sectors * 512);

  exit (EXIT_SUCCESS);
}
