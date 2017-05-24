/* Copyright (c) 2004, Oracle. All rights reserved.  */

/*  $Id: snmhsinq.c 16-sep-2004.13:37:19 ajdsouza Exp $ 

   NAME
     snmhsinq.c

   DESCRIPTION
     execute scsi inquiry for a scsi disk to get the vendor, product , serial number and vendor specific information

   EXPORT FUNCTION(S)
     <external functions defined for use outside package - one-line descriptions>

   INTERNAL FUNCTION(S)
     <other external functions defined - one-line descriptions>

   STATIC FUNCTION(S)
     <static functions defined - one-line descriptions>

   NOTES
     <other useful comments, qualifications, etc.>

   MODIFIED   (MM/DD/YY)
   ajdsouza   09/16/04 - 
   ajdsouza   06/30/04 - return values to be Oracle types
   ajdsouza   06/25/04 - storage reporting sources 
   ajdsouza   06/01/04 - Creation

*/

#ifndef S_ORACLE
# include "s.h"
#endif

#ifndef SNMHSUTL_ORACLE
# include "snmhsutl.h"
#endif

#ifndef SNMHSINQ_ORACLE
# include "snmhsinq.h"
#endif

#include <strings.h>  /* for bzero */
#include <netinet/in.h> /* for ntohl (endianness) */

#ifdef SOLARIS
# include <sys/scsi/scsi.h>
#elif HPUX
# include <sys/scsi.h>
#elif LINUX
# include <scsi/scsi.h>
# include <scsi/scsi_ioctl.h>
# include <sys/ioctl.h>

# define CMDOFF (2 * sizeof(unsigned int))

 /* The command buffer is typecast with this struct
    to make it easier to set the input and output length
    and allocate the data buffer.  */
 typedef struct scsi_ioctl_cmd
 {
   unsigned int    inlen;
   unsigned int    outlen;
   char            data[1];
 } Scsi_Ioctl_Cmd;

#endif

/*---------------------------------------------------------------------------
                     PRIVATE TYPES AND CONSTANTS
  ---------------------------------------------------------------------------*/
/* Max size of char buffers*/
#define BUFFER_MAX      255
/* SIze of the vendor specific bytes in std scsiinquiry*/
#define VENDOR_SPECIFIC 20

/*---------------------------------------------------------------------------
                     STATIC FUNCTION DECLARATIONS 
  ---------------------------------------------------------------------------*/


/*---------------------------------------------------------------------------
                           EXPORT FUNCTIONS
  ---------------------------------------------------------------------------*/
word snmhsinq_scsiinquiry(word v_no_of_args, oratext ** v_args)
{

  oratext        *logicalname;
  int             disk;
  oratext         pagecodes[BUFFER_MAX];
  oratext         vendorspecific[VENDOR_SPECIFIC];
  int             bufflen;
  int             scsicmd;
  /* Used for reading SCSI Page Codes */
  int             i, j;
  /* return structure from READ CAPACITY SCSI command */
  struct scsicapacity
  {
    unsigned long   capacity;
    unsigned long   blocksize;
  }
                 *scpt;

  /*SCSI Command buffer */
  oratext        *ucmd;
#ifdef SOLARIS
  oratext         cmd[10];
  oratext         buffer[96];
#elif HPUX
  oratext        *cmd;
  oratext         buffer[96];
#elif LINUX
  oratext        *cmd;
  /* buffer is a pointer on linux because it will be set 
     to the location within the command buffer that contains
     the data. */
  oratext        *buffer;
#endif

  /* 0 = Device connected */
  unsigned long   pqualifier;

  /*0 = direct access (magnetic disk), 
     1 = sequential access
     2 = printer
     5 = cdrom, 
     7 - optical disks,
     12 = Raid controller
     13 = Encolsure device
     14 = simplified direct access device (magnetic disk)
   */
  unsigned long   pdtype;
  oratext         vendor[BUFFER_MAX];
  oratext         product[BUFFER_MAX];
  oratext         revision[BUFFER_MAX];
  oratext         serialno[BUFFER_MAX];
  oratext         hitachiserial[BUFFER_MAX];

  /* disk size in bytes , double as > 4GB */
  double          sizeb = 0;

  /* Store the effective userid, - to restore before ioctl and 
     open commands   */

  uid_t           effectiveuid;

#ifdef SOLARIS
  /* Solaris structure for SCSI commands */
  ucmd = (oratext *) calloc(1, sizeof(struct uscsi_cmd));
#elif HPUX
  /* HPUX structure for SCSI commands */
  ucmd = (oratext *) calloc(1, sizeof(struct sctl_io));
  cmd = ((struct sctl_io *) ucmd)->cdb;
#elif LINUX
  /* Linux structure for SCSI commands 
     The linux command buffer has a two byte offset for the 
     input and output length */
  ucmd = malloc(CMDOFF + 96);
  /* Command buffer */
  cmd = ucmd + CMDOFF;
  /* Data buffer */
  buffer = ucmd + CMDOFF;
#endif


  /*----------------------------------------------------------
    SECURE THE PROGRAM
    ERASE ENVIRONMENT
    SAVE AND REVOKE EFFECTIVE SUID
  -----------------------------------------------------------*/

  /* Erase environment */
  DISCARD         snmhsutl_eraseenv();

  /* Store the effective user id of the process */
  effectiveuid = geteuid();

  /* revoke effective root uid privilege */
  SNMHS_REVOKE_ENHANCED_PRIVILEGE;

  /*----------------------------------------------------------
    CHECK AND VALIDATE ARGUMENT, LOGICAL NAME OF THE DISK DEVICE
  ------------------------------------------------------------*/

  /* Check for argument */
  if (v_no_of_args <= 1)
  {
    printf("error:: Usage : scsiinq <logicalname>\n");
    return EX_FAIL; 
  }

  /* Copy the input arguments with null termination */
  if (snmhsutl_copy(&logicalname, v_args[1], BUFFER_SIZE) != EXIT_SUCCESS)
  {
    printf("error:: scsiinq.c: Argument larger than buffersize %d \n",
           BUFFER_SIZE);
    return EX_FAIL; 
  }

  /* Validate the input, only disk name allowed no flags, 
     raise error if arg begins with - */
  if (logicalname[0] == '-')
  {
    printf("error:: scsiinq.c: Invalid argument %s \n", logicalname);
    return EX_FAIL; 
  }

  /*------------------------------------------------------------
    GET THE FILE DESCRIPTOR
    ------------------------------------------------------------*/

  /* Restore the root effective userid of the process */
  SNMHS_SET_ENHANCED_PRIVILEGE;

  if ((disk = open((char *) logicalname, O_RDONLY | O_NDELAY)) == -1)
  {
    /* revoke effective root uid privilege */
    SNMHS_REVOKE_ENHANCED_PRIVILEGE;

    /* Possibly a cdrom device if BUSY */
    if (errno == EBUSY)
      printf("error:: device %s BUSY, Possible CDROM device \n", logicalname);
    else
      printf("error:: %d %s %s\n", errno, strerror(errno), logicalname);

    return EX_FAIL; 
  }

  /* revoke effective root uid privilege */
  SNMHS_REVOKE_ENHANCED_PRIVILEGE;

  /* Free the malloced memory for logicalname */
  free(logicalname);

  /*----------------------------------------------------------------
    SCSI TEST UNIT READY OX00, GROUP 0 COMMAND, CDB SIZE = 6
    ---------------------------------------------------------------*/
  bzero(buffer, 96);

  cmd[0] = 0x00;
  cmd[1] = 0x00;
  cmd[2] = 0x00;
  cmd[3] = 0x00;
  cmd[4] = 0;
  cmd[5] = 0x00;

#ifdef SOLARIS

  ((struct uscsi_cmd *) ucmd)->uscsi_flags = USCSI_READ;
  ((struct uscsi_cmd *) ucmd)->uscsi_cdb = (caddr_t) cmd;
  ((struct uscsi_cmd *) ucmd)->uscsi_cdblen = CDB_GROUP0;
  ((struct uscsi_cmd *) ucmd)->uscsi_timeout = 30;

  scsicmd = USCSICMD;

#elif HPUX

  ((struct sctl_io *) ucmd)->flags = SCTL_READ;
  ((struct sctl_io *) ucmd)->cdb_length = 6;
  ((struct sctl_io *) ucmd)->data = (void *) buffer;
  ((struct sctl_io *) ucmd)->data_length = sizeof(struct inquiry);
  ((struct sctl_io *) ucmd)->max_msecs = 2000;

  scsicmd = SIOC_IO;

#elif LINUX

  ((Scsi_Ioctl_Cmd *) ucmd)->inlen = 0;
  ((Scsi_Ioctl_Cmd *) ucmd)->outlen = 96;

  scsicmd = SCSI_IOCTL_SEND_COMMAND;

#endif

  /* Restore the root effective userid of the process */
  SNMHS_SET_ENHANCED_PRIVILEGE;

  if (ioctl(disk, scsicmd, ucmd) == -1)
  {
    /* revoke effective root uid privilege */
    SNMHS_REVOKE_ENHANCED_PRIVILEGE;
    close(disk);

    /* I/O error is device is not available */
    if (errno == EIO)
      printf("error:: device %s not available, Possibly taken offline \n",
             logicalname);
    else
      printf("error:: SCSI TEST UNIT READY %d %s \n", errno, strerror(errno));

    return EX_FAIL; 
  }

  /* revoke effective root uid privilege */
  SNMHS_REVOKE_ENHANCED_PRIVILEGE;

  /*----------------------------------------------------------------
    SCSI READ CAPACITY OX25, GROUP 1 COMMAND, CBD SIZE = 10
    ---------------------------------------------------------------*/
  bzero(buffer, 96);

  cmd[0] = 0x25;
  cmd[1] = 0x00;
  cmd[2] = 0x00;
  cmd[3] = 0x00;
  cmd[4] = 0x00;
  cmd[5] = 0x00;
  cmd[6] = 0x00;
  cmd[7] = 0x00;
  cmd[8] = 0x00;
  cmd[9] = 0x00;

#ifdef SOLARIS

  ((struct uscsi_cmd *) ucmd)->uscsi_flags = USCSI_READ;
  ((struct uscsi_cmd *) ucmd)->uscsi_cdb = (caddr_t) cmd;
  ((struct uscsi_cmd *) ucmd)->uscsi_cdblen = CDB_GROUP1;
  ((struct uscsi_cmd *) ucmd)->uscsi_bufaddr = (caddr_t) buffer;
  ((struct uscsi_cmd *) ucmd)->uscsi_buflen = 96;
  ((struct uscsi_cmd *) ucmd)->uscsi_timeout = 30;

  scsicmd = USCSICMD;

#elif HPUX

  ((struct sctl_io *) ucmd)->flags = SCTL_READ;
  ((struct sctl_io *) ucmd)->cdb_length = 10;
  ((struct sctl_io *) ucmd)->data = (void *) buffer;
  ((struct sctl_io *) ucmd)->data_length = sizeof(struct inquiry);
  ((struct sctl_io *) ucmd)->max_msecs = 2000;

  scsicmd = SIOC_IO;


#elif LINUX

  ((Scsi_Ioctl_Cmd *) ucmd)->inlen = 0;
  ((Scsi_Ioctl_Cmd *) ucmd)->outlen = 96;

  scsicmd = SCSI_IOCTL_SEND_COMMAND;

#endif

  /* Restore the root effective userid of the process */
  SNMHS_SET_ENHANCED_PRIVILEGE;

  if (ioctl(disk, scsicmd, ucmd) == -1)
  {
    /* revoke effective root uid privilege */
    SNMHS_REVOKE_ENHANCED_PRIVILEGE;

    close(disk);

    printf("error:: SCSI READ CAPACITY %d %s \n", errno, strerror(errno));
    return EX_FAIL; 
  }

  /* revoke effective root uid privilege */
  SNMHS_REVOKE_ENHANCED_PRIVILEGE;

  /* Read the capacity and block size from the result buffer */
  scpt = (struct scsicapacity *) buffer;

  /* Convert from network (SCSI) byte order 
     to host byte order */
  scpt->capacity = ntohl(scpt->capacity);
  scpt->blocksize = ntohl(scpt->blocksize);

  sizeb = (double) scpt->capacity * (double) scpt->blocksize;


  /*----------------------------------------------------------------
    SCSI INQUIRY OX12, GROUP 0 COMMAND, CBD SIZE = 6
    ---------------------------------------------------------------*/
  bzero(buffer, 96);

  cmd[0] = 0x12;
  cmd[1] = 0x00;
  cmd[2] = 0x00;
  cmd[3] = 0x00;
  cmd[4] = 96;
  cmd[5] = 0x00;

#ifdef SOLARIS

  ((struct uscsi_cmd *) ucmd)->uscsi_flags = USCSI_READ;
  ((struct uscsi_cmd *) ucmd)->uscsi_cdb = (caddr_t) cmd;
  ((struct uscsi_cmd *) ucmd)->uscsi_cdblen = CDB_GROUP0;
  ((struct uscsi_cmd *) ucmd)->uscsi_bufaddr = (caddr_t) buffer;
  ((struct uscsi_cmd *) ucmd)->uscsi_buflen = 96;
  ((struct uscsi_cmd *) ucmd)->uscsi_timeout = 30;

  scsicmd = USCSICMD;

#elif HPUX

  ((struct sctl_io *) ucmd)->flags = SCTL_READ;
  ((struct sctl_io *) ucmd)->cdb_length = 6;
  ((struct sctl_io *) ucmd)->data = (void *) buffer;
  ((struct sctl_io *) ucmd)->data_length = sizeof(struct inquiry);
  ((struct sctl_io *) ucmd)->max_msecs = 2000;

  scsicmd = SIOC_IO;

#elif LINUX

  ((Scsi_Ioctl_Cmd *) ucmd)->inlen = 0;
  ((Scsi_Ioctl_Cmd *) ucmd)->outlen = 96;

  scsicmd = SCSI_IOCTL_SEND_COMMAND;

#endif

  /* Restore the root effective userid of the process */
  SNMHS_SET_ENHANCED_PRIVILEGE;

  if (ioctl(disk, scsicmd, ucmd) == -1)
  {

    /* revoke effective root uid privilege */
    SNMHS_REVOKE_ENHANCED_PRIVILEGE;

    close(disk);

    printf("error:: SCSI INQUIRY %d %s \n", errno, strerror(errno));
    return EX_FAIL; 
  }

  /* revoke effective root uid privilege */
  SNMHS_REVOKE_ENHANCED_PRIVILEGE;

  pqualifier = buffer[0] & (0x3200);
  pdtype = buffer[0] & (0x0133);
  sprintf((char *) vendor, "%8.8s", &buffer[8]);
  sprintf((char *) product, "%16.16s", &buffer[16]);
  sprintf((char *) revision, "%4.4s", &buffer[32]);

  /* Bytes 36-55 are vendor specific */
  for (i = 0; i < VENDOR_SPECIFIC; i++)
    vendorspecific[i] = buffer[36 + i];

  /*------------------------------------------------------------
    HITACHI SPECIAL

    For hitachi 12 bytes from offset 36 give the serial number
    The serial number is in HEX
    This is to be inteprested as 
    4 bytes - Model
    4 bytes  - Array serial number
    1 byte - Port Id
    3 Bytes - Device ID
    If same disk is mounted on two controllers, multipathed 
    the port number would change
    So take serial number to be array serial number + device id
    -----------------------------------------------------------*/
  if (vendor && (!strncasecmp((char *) vendor, "HITACHI", 7)))
    sprintf((char *) hitachiserial, "%12.12s", &buffer[36]);

 /*----------------------------------------------------------------
    SCSI INQUIRY OX12 WITH VITAL PRODUCT DATA, SUPPORTED PAGE CODES
    EVPD =1
    OPERATION CODE = 0X00
    GROUP 0 COMMAND, CBD SIZE = 6
    ---------------------------------------------------------------*/
  bzero(buffer, 96);

  cmd[0] = 0x12;
  cmd[1] = 0x01;
  cmd[2] = 0x00;
  cmd[3] = 0x00;
  cmd[4] = 96;
  cmd[5] = 0x00;

#ifdef SOLARIS

  ((struct uscsi_cmd *) ucmd)->uscsi_flags = USCSI_READ;
  ((struct uscsi_cmd *) ucmd)->uscsi_cdb = (caddr_t) cmd;
  ((struct uscsi_cmd *) ucmd)->uscsi_cdblen = CDB_GROUP0;
  ((struct uscsi_cmd *) ucmd)->uscsi_bufaddr = (caddr_t) buffer;
  ((struct uscsi_cmd *) ucmd)->uscsi_buflen = 96;
  ((struct uscsi_cmd *) ucmd)->uscsi_timeout = 30;

  scsicmd = USCSICMD;

#elif HPUX

  ((struct sctl_io *) ucmd)->flags = SCTL_READ;
  ((struct sctl_io *) ucmd)->cdb_length = 6;
  ((struct sctl_io *) ucmd)->data = (void *) buffer;
  ((struct sctl_io *) ucmd)->data_length = 96;
  ((struct sctl_io *) ucmd)->max_msecs = 2000;

  scsicmd = SIOC_IO;

#elif LINUX

  ((Scsi_Ioctl_Cmd *) ucmd)->inlen = 0;
  ((Scsi_Ioctl_Cmd *) ucmd)->outlen = 96;

  scsicmd = SCSI_IOCTL_SEND_COMMAND;

#endif

  /* Restore the root effective userid of the process */
  SNMHS_SET_ENHANCED_PRIVILEGE;

  if (ioctl(disk, scsicmd, ucmd) == -1)
  {
    /* revoke effective root uid privilege */
    SNMHS_REVOKE_ENHANCED_PRIVILEGE;

    close(disk);

    printf("error:: SCSI INQUIRY WITH VITAL PRODUCT DATA %d %s \n", errno,
           strerror(errno));
    return EX_FAIL; 
  }

  /* revoke effective root uid privilege */
  SNMHS_REVOKE_ENHANCED_PRIVILEGE;

  /*-----------------------------------------------------------------------
    Byte 4 gives the length of the page
    -----------------------------------------------------------------------*/
  if (buffer[3] < BUFFER_MAX)
    bufflen = buffer[3];
  else
  {
    printf("warn:: invalid buffer size, skipping inquiry pagecodes\n");
    bufflen = 0;
  }

  /*------------------------------------------------------------------------
    Copy the list of supported page codes to pagecodes array for later use 
    Data starts from byte 5
    -----------------------------------------------------------------------*/
  for (i = 0; i < bufflen; i++)
    pagecodes[i] = buffer[4 + i];


  /* ------------------------------------------------------------------------
     Iterate through the page codes, calling each one and printing the results 
     ------------------------------------------------------------------------ */
  for (i = 0; i < bufflen; i++)
  {

    /* Initialze the buffer to fetch each page */
    bzero(buffer, 96);

    cmd[0] = 0x12;
    cmd[1] = 0x01;
    cmd[2] = pagecodes[i];
    cmd[3] = 0x00;
    cmd[4] = 96;
    cmd[5] = 0x00;

#ifdef SOLARIS

    ((struct uscsi_cmd *) ucmd)->uscsi_flags = USCSI_READ;
    ((struct uscsi_cmd *) ucmd)->uscsi_cdb = (caddr_t) cmd;
    ((struct uscsi_cmd *) ucmd)->uscsi_cdblen = CDB_GROUP0;
    ((struct uscsi_cmd *) ucmd)->uscsi_bufaddr = (caddr_t) buffer;
    ((struct uscsi_cmd *) ucmd)->uscsi_buflen = 96;
    ((struct uscsi_cmd *) ucmd)->uscsi_timeout = 30;

    scsicmd = USCSICMD;

#elif HPUX

    ((struct sctl_io *) ucmd)->flags = SCTL_READ;
    ((struct sctl_io *) ucmd)->cdb_length = 6;
    ((struct sctl_io *) ucmd)->data = (void *) buffer;
    ((struct sctl_io *) ucmd)->data_length = 96;
    ((struct sctl_io *) ucmd)->max_msecs = 2000;

    scsicmd = SIOC_IO;

#elif LINUX

    ((Scsi_Ioctl_Cmd *) ucmd)->inlen = 0;
    ((Scsi_Ioctl_Cmd *) ucmd)->outlen = 96;

    scsicmd = SCSI_IOCTL_SEND_COMMAND;

#endif

    /* Restore the root effective userid of the process */
    SNMHS_SET_ENHANCED_PRIVILEGE;

    if (ioctl(disk, scsicmd, ucmd) == -1)
    {

      /* revoke effective root uid privilege */
      SNMHS_REVOKE_ENHANCED_PRIVILEGE;

      close(disk);

      printf("error:: SCSI INQUIRY page code %d %s \n", errno,
             strerror(errno));
      return EX_FAIL; 
    }

    /* revoke effective root uid privilege */
    SNMHS_REVOKE_ENHANCED_PRIVILEGE;

#ifdef HPUX
    if (((struct sctl_io *) ucmd)->cdb_status != S_CHECK_CONDITION)
    {
#endif
      /*--------------------------------------------------------
	0x80 returns then save serial number, its supposed 
	to be ascii and get it later   OPERATION CODE = 0X80
	--------------------------------------------------------*/
      if (pagecodes[i] == 0x80)
        sprintf((char *) serialno, "%*.*s", buffer[3], buffer[3], &buffer[4]);

      /*---------------------------------------------------
	Print the hex value of each page supported
	--------------------------------------------------*/
      printf("sq_vpd_pagecode_%2.2x::", pagecodes[i]);

      /*------------------------------------------------------
	Byte 4 gived the length of the page
	Data starts from byte 5
	------------------------------------------------------*/
      for (j = 0; j < buffer[3]; j++)
        printf("%2.2x", buffer[4 + j]);

      printf("\n");
#ifdef HPUX
    }
#endif
  }

  /* Print the data from scsi inquiry */
  printf("sq_peripheral_qualifier::%lu\n", pqualifier);
  printf("sq_device_type::%lu\n", pdtype);
  printf("sq_vendor::%s\n", vendor);
  printf("sq_product::%s\n", product);
  printf("sq_revision::%s\n", revision);
  printf("sq_serial_no::%s\n", serialno);
  printf("sq_capacity::%.0f\n", sizeb);

  /* Print the vendor specific buffer */
  printf("sq_vendorspecific::0x");
  for (i = 0; i < VENDOR_SPECIFIC; i++)
    printf("%2.2x", vendorspecific[i]);
  printf("\n");

  /* In case of hitachi print the hitachi specific data */
  if (vendor && (!strncasecmp((char *) vendor, "HITACHI", 7)))
    printf("sq_hitachi_serial::%s\n", hitachiserial);


  DISCARD         close(disk);

  return EX_SUCC; 

}
