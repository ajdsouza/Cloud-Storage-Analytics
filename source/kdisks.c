/*
*
* Copyright  (c) 2001,2002  Oracle Corporation All rights reserved
*
*  $Id: kdisks.c,v 1.146 2003/03/12 17:50:04 ajdsouza Exp $ 
*
*
*
* NAME  
*	 kdisks.c
*
* DESC 
*    Discover and print information for all disk devices
* FUNCTIONS
*
*
* NOTES
*
*
* MODIFIED	(MM/DD/YY)
* ajdsouza	06/24/02 - Created
*
*/

#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <errno.h>
#include <kvm.h>
#ifndef _KERNEL
#define _KERNEL
#endif
#include <sys/dditypes.h>
#undef _KERNEL
#include <sys/ddi_impldefs.h>
#include <sys/sunddi.h>
#include <sys/scsi/scsi.h>
#ifndef _KERNEL
#define _KERNEL
#endif
#include <sys/scsi/conf/device.h>
#include <sys/scsi/scsi_address.h>
#include <sys/scsi/impl/transport.h>
#undef _KERNEL
#include <sys/mkdev.h>
#include <sys/stat.h>
#include <sys/dkio.h>
#include <sys/vtoc.h>

/* 
   The following are not defined on 5.6
   Check if its 5.6
*/
#ifdef _PTRDIFF_T
#define OS_5_7
#else
#define OS_5_6
#endif

/*
  Need to define the following 5.7 constants if less then
  5.7
*/
#ifdef OS_5_6

/* Define the long pointer difference */
#define _PTRDIFF_T
#if defined(_LP64) || defined(_I32LPx)
typedef long    ptrdiff_t;              /* pointer difference */
#else
typedef int     ptrdiff_t;              /* (historical version) */
#endif


/*
 * Media types or profiles known
 */
#define	DK_UNKNOWN		0x00	/* Media inserted - type unknown */

/*
 * SFF 8090 Specification Version 3, media types 0x01 - 0xfffe are retained to
 * maintain compatibility with SFF8090.  The following define the
 * optical media type.
 */
#define	DK_MO_ERASABLE		0x03 /* MO Erasable */
#define	DK_MO_WRITEONCE		0x04 /* MO Write once */
#define	DK_AS_MO		0x05 /* AS MO */
#define	DK_CDROM		0x08 /* CDROM */
#define	DK_CDR			0x09 /* CD-R */
#define	DK_CDRW			0x0A /* CD-RW */
#define	DK_DVDROM		0x10 /* DVD-ROM */
#define	DK_DVDR			0x11 /* DVD-R */
#define	DK_DVDRAM		0x12 /* DVD_RAM or DVD-RW */

/*
 * Media types for other rewritable magnetic media
 */
#define	DK_FIXED_DISK		0x10001	/* Fixed disk SCSI or otherwise */
#define	DK_FLOPPY		0x10002 /* Floppy media */
#define	DK_ZIP			0x10003 /* IOMEGA ZIP media */
#define	DK_JAZ			0x10004 /* IOMEGA JAZ media */

/* 
   Channel disk types not defined in 5_6
 */
#define DDI_NT_SCSI_NEXUS	"ddi_ctl:devctl:scsi"	/* nexus drivers */
#define DDI_NT_SBD_ATTACHMENT_POINT	"ddi_ctl:attachment_point:sbd"   /* generic bd attachment pt */
#define DDI_NT_FC_ATTACHMENT_POINT	"ddi_ctl:attachment_point:fc"
#define DDI_NT_SCSI_ATTACHMENT_POINT	"ddi_ctl:attachment_point:scsi"  /* scsi attachment pt */
#define DDI_NT_PCI_ATTACHMENT_POINT	"ddi_ctl:attachment_point:pci"   /* PCI attachment pt */
#define DDI_NT_BLOCK_FABRIC	"ddi_block:fabric"	/* Fabric Devices */

#endif
/* End of 5_6 definitions */


#ifndef TRUE
#define TRUE 1
#define FALSE 0
#endif
#define UNKNOWN 0xffff

#define BUFFER_MAX 255
#define BUFFER_MAX_CONFIG 2000
#define MAX_NODES 25000 /* Icreased it to 20K from 5K , for severs with a lot of disks like tapesrv02 */
#define MAX_MINOR_NODES 50

/* Flags for different DISK types*/
#define DISK_UNKNOWN 0X01
#define DISK_SCSI  0X02
#define DISK_IDE   0x03
#define DISK_META  0x04

/* Slice number for a backup slice on a _SUNOS_VTOC_8 slice disk*/
#define BACKUP_SLICE 2

/* Flag to indicate a pseudo node*/
#define PSEUDO_NODE 0x01

/* Default block size for blocks returned in DKIOGCPART */
#define DEFAULT_BLOCKSIZE 512

/*Indicate if the disk is formatted or not ie VTOC table on the disk or no */
enum{UNFORMATTED,FORMATTED};

/* Node class for layered rdriver disks, not in sunddi so add it here*/
#define DDI_NT_BLOCK_CHAN_RDRIVER "rd_ddi_block:chan" 


/* Structure to keep track of relevent parent device data when walking down the tree */
struct devicetree{
  struct  devicetree *parentnode; /* Parent devicetree */
  uintptr_t   memaddress;     /* Node address in kmem*/
  uintptr_t   parentaddress;  /* Node parent address in kmem*/
  char   name[BUFFER_MAX];
  char   address[BUFFER_MAX];
  char   bindingname[BUFFER_MAX];
  char   physicalPath[BUFFER_MAX]; /* Physical path to the node*/
  char   devicepath[BUFFER_MAX]; /* Path for the backup CHAR slice of the disk node */
  int    controllerType; /* scsi or ide etc.*/
  int    nodeid;
  int    nodeclass;
  int   pseudonode;  /* Indicate if node is on a pseudo node */
  int    instance;
  int    disktype;
  double size;   /* Size of the whole disk from DKIOCGMEDIAINFO*/
  uint_t  mediatype;    /* media type from  DKIOCGMEDIAINFO*/
  uint_t  blocksize;    /* block size from DKIOCGMEDIAINFO*/
  diskaddr_t  nsize;    /* No of blocks from DKIOCMEDIAINFO */
  ushort_t v_sectorsz;  /* Sector size from DKIOCGVTOC*/
  unsigned short dkg_ncyl; /* Number of data cylinders from DKIOCGGEOM */
  unsigned short dkg_acyl; /*  Number of alternate cylinders from DKIOCGGEOM */
  unsigned short dkg_nsect; /* Number of data sectors per track from DKIOCGEOM */
  unsigned short dkg_pcyl;  /* Number of physical cylinders from DKIOCGGEOM  */
  unsigned short dkg_rpm;    /* RPM from DKIOCGGEOM */
  /* scsi data from the node properties*/
  char   class[BUFFER_MAX];
  int    target;
  int    lun;  
  char   vendor[BUFFER_MAX];
  char   product[BUFFER_MAX];
  char   serialnumber[BUFFER_MAX];
  /* scsi data from the scsi_device structure for scsi devices*/
  ushort_t   scsitarget;
  uchar_t    scsilun;
  char   scsivendor[BUFFER_MAX];
  char   scsiproduct[BUFFER_MAX];
  char   scsirevision[BUFFER_MAX];
  char   scsiserial[BUFFER_MAX];
  /* device id data*/
  char   deviceidtype[BUFFER_MAX];
  char   deviceidhint[BUFFER_MAX];
  int    deviceidlength;
  uchar_t   deviceid[BUFFER_MAX]; 
  /* Controller data*/
  char    dki_cname[DK_DEVLEN];  /* controller name (no unit #) */
  ushort_t dki_ctype; /* controller type */
  ushort_t dki_cnum;  /* controller number */  
  /* Disk driver type*/  
  int    formatstatus;
  char   configuration[BUFFER_MAX_CONFIG]; /* config values as prop=value with a -- separator*/
  char   volumeLabel[LEN_DKL_VVOL];   /* Volume label for the disk */
  char   ascii_label[LEN_DKL_ASCII];  /* ascii label for the disk */
};


/* Structure to store disk data for each minor node device
   to be printed */
struct minornodedata{
  char  name[BUFFER_MAX];   
  char  nodepath[BUFFER_MAX];  /* Physical path to the minor node*/
  ulong_t  majornumber;
  ulong_t  minornumber;
  int  spectype;               /* BLOCK or CHAR */
  char  nodetype[BUFFER_MAX];  /* Indicat device type DDI_NT...*/
  char  nodeclass[BUFFER_MAX];
  char  clone[BUFFER_MAX];
  /* Partition data */
  ushort_t    partitiontype;  /* V_USR,V_BACKUP etc.*/
  ushort_t   partition;       /* Partition number */
  daddr_t        startsector; /* Starting sector for this partition*/
  long           nsize;       /* # of blocks in partition */
  double  size;        /* size of the partition in bytes */
};

struct minornodedata minorNodeList[MAX_MINOR_NODES];

/* List of recognized disk drivers*/
char *drivers[] = {"sd","ssd","dad","emcp","rdriver"};

struct devicetree devices[MAX_NODES];
struct devicetree *pdevice = devices;

/* Store the effective userid during execution*/
uid_t  effectiveuid;

/*******************************************************************
*
* FUNCTION : eraseenv
*
* ARGUMENTS:
*			
*
* DESC : Erase the environment - for security
*        
********************************************************************/
void eraseenv()
{
  
  extern  char **environ;
  
  /* Erase each array member*/
  while(*environ != NULL){
    *environ = NULL;
    *environ++;
  }
  
  /* Erase environment */
  environ = NULL;  
  
}


/* Print a byte buffer*/
void printBuffer(uchar_t *buffer, size_t size)
{
  int i;
  
  if ( size )
    {
      printf("0x");
      for (
	   i=0;
	   (i <size) && (i<BUFFER_MAX);
	   i++)
	printf("%2.2x",buffer[i]);
    }
  
  printf("|");
  
}


/* Build the physical path to a device node*/
void buildPhysicalPath(struct devicetree  *treeaddress)
{
  
  if ( !treeaddress )
    return;

  /* If the device path to this device is saved then
     return it, no need to interate higher*/
  if ( strlen(treeaddress->physicalPath) )    
    return;

  /* Print the physical path from the parent devicetree */
  buildPhysicalPath(treeaddress->parentnode);   
  
  /* If at the topmost node then parentaddress is NULL 
     so print devices and end iteration */
  if ( !treeaddress->parentaddress )    
    sprintf(treeaddress->physicalPath,"%s","/devices");             
  else {
  
    /* Print the physical path for this node as /name@address
       if not the root node, if root node then print /devices*/
    
    sprintf(treeaddress->physicalPath,"%s/%s",
	    treeaddress->parentnode->physicalPath,treeaddress->name);
    
    /* Add address is it is not null or blank*/
    if (
	(treeaddress->address) && 
	strlen(treeaddress->address) 
	)
      sprintf(treeaddress->physicalPath,"%s@%s",
	      treeaddress->physicalPath,treeaddress->address);
                
  }

}


/* Read the length of buffer requested */
uchar_t *readBuffer(kvm_t *kd,uintptr_t address,int size)
{

  static	uchar_t buffer[BUFFER_MAX];
  uchar_t	*pointer;
  int	readsize;
  int	i;
  ptrdiff_t  pdiff;

  if ( address == (uintptr_t) NULL)
    return NULL;
  
  /* Clean up the buffer */
  for (i=0;i<BUFFER_MAX;i++)
    buffer[i] = NULL;
  
  /* Limit buffer to be read to BUFFER_MAX in any case */
  readsize = ( size > BUFFER_MAX) ? BUFFER_MAX:size;
  
  for(pointer=buffer;pointer<(buffer+readsize);pointer++){
    
    pdiff = pointer-buffer;

    if ( kvm_kread(kd,address+pdiff,(void *)pointer,sizeof(uchar_t)) == -1 ){
      
      printf("error:: kdisks.c, readBuffer: %d %s \n",errno,strerror(errno));      
      exit(EXIT_FAILURE);  
      
    }
    
  }
  
  return buffer;
}


/* return the string buffer null terminated from kvm */
char *readStringBuffer(kvm_t *kd,uintptr_t address)
{

	static char stringbuffer[BUFFER_MAX];
	char	    *pointer;
	ptrdiff_t   pdiff;

	if ( address == (uintptr_t) NULL)
		return "\0";

	for(pointer=stringbuffer;pointer<(stringbuffer+BUFFER_MAX);pointer++){
	  
	  pdiff = pointer-stringbuffer;
	  
	  if ( kvm_kread(kd,address+pdiff,(void *)pointer,sizeof(char)) == -1 ){
	    
	    printf("error:: kdisks.c, readStringBuffer: %d %s \n",errno,strerror(errno));      
	    exit(EXIT_FAILURE); 	    
	    
	  }
	  
	  if ( *pointer == '\0' )
	    break;
	  
	}
	
	stringbuffer[BUFFER_MAX-1] = '\0';
	
	return stringbuffer;
}


/* Return the string , null terminated from the character buffer*/
char *readStringFromBuffer(char  *str, size_t  size){

  static char charbuffer[BUFFER_MAX];
  int i;

  for(
      i=0;
      ( i < size) && ( i < BUFFER_MAX );
      i++){
    
    if  ( str[i] == '\0' )
      break;
    
    charbuffer[i] = str[i];
  }
  
  charbuffer[i] = '\0';
  
  return charbuffer;

}


/* Check if any of the minor devices repesents a disk 
   if any minor node is of type DDI_NT_BLOCK or
   DDI_NT_BLOCK_CHAN then the node represents a disk
   device
*/
boolean_t isMinorDeviceADisk(kvm_t *kd, struct devicetree *treeaddress,
			     struct ddi_minor_data *pminor_data)
{
    
  struct ddi_minor_data minor_data;
  char	*value;
    
  for(;pminor_data != (struct ddi_minor_data *)NULL;
      pminor_data = minor_data.next) {
    
    if ( kvm_kread(kd,(uintptr_t)pminor_data,(void *)&minor_data,
		   sizeof(struct ddi_minor_data)) == -1 ){
      
      printf("error:: kdisks.c, isMinorDeviceADisk: %d %s \n",errno,strerror(errno));      
      exit(EXIT_FAILURE);       
    }
    
    /* Read the node type for the minor node*/
    value = readStringBuffer(kd,(uintptr_t)minor_data.mu.d_minor.node_type);
    
    /*If minor node type is one of the following then it
      represents a disk
      If node type is null, then skip the test */      
    if (
	value
	&&
	(
	 ( !strcasecmp(value,DDI_NT_BLOCK) )||
	 ( !strcasecmp(value,DDI_NT_BLOCK_CHAN) )||
	 ( !strcasecmp(value,DDI_NT_BLOCK_CHAN_RDRIVER) )
	 )
	)
      return TRUE;
    
    /* If minor node is an DM_ALIAS ie points to another dev_info structure 
       check if the minor node in that dev_info structure is a disk
    */
    if ( minor_data.type == DDM_ALIAS )
      if ( isMinorDeviceADisk(kd,treeaddress,minor_data.mu.d_alias.dmp))
	return TRUE;
    
    /* If the minor node does not noint to the parent address
       then its a ALIASED node so break and return*/
    if ((intptr_t)minor_data.dip != treeaddress->memaddress)
      break;
    
  }
  
  return FALSE;
  
}


/* 
   Check if a dev_info structure passed is a disk 

   This is a +ve check, if none of the cases are true its not a disk
   atleast one minor node is a disk or 
   the driver is a disk or pseudo disk 
   driver
*/
boolean_t isNodeADisk(kvm_t *kd,struct devicetree *treeaddress,
		      struct dev_info *device){
  
  char	*value;
  boolean_t result;
  int i;
  
  if ( (intptr_t)device == (intptr_t)NULL)
    return FALSE;
  
  /* If there is a minor node for this dev_info structure
     Check if any minor device is a disk 
  */
  if( device->devi_minor )
    if( isMinorDeviceADisk(kd,treeaddress,device->devi_minor))
      return TRUE;
  
  /* If result is FALSE then check the driver list to make sure*/
  /* Check if the devi_node_name is in the list of known drivers*/
  value = readStringBuffer(kd,(uintptr_t)device->devi_node_name);
  
  if ( !value )
    return FALSE;
  
  for (   i=0;
	  i<(sizeof(drivers)/sizeof(char *));
	  i++)
    {
      
      if ( !strcasecmp(value,drivers[i]) )
	return TRUE;
      
    }
  
  return FALSE;
  
}



/* 
   Get the partition number for each minor node along with the 
   controller information for the disk
*/
void storeDiskPartition( 
			struct devicetree *treeaddress,
			struct minornodedata *minornode 
			){

  char  *slicemap[][2]={
    "a",":a",
      "b",":b",
      "c",":c",
      "d",":d",
      "e",":e",
      "f",":f",
      "g",":g",
      "h",":h"
  };

  int i,j;    
  int   disk;
  struct dk_cinfo dkbuffer;

  /*-----------------------------------------------------------
    Guess the partition if DKIOCINFO fails
    Guess the partition from the slice name,   
     ---------------------------------------------------------*/
  if ( strlen(minornode->name) )
    for(i=0;2*i<sizeof(slicemap)/sizeof(char *);i++)
      for(j=0;j<2;j++)
	if ( !strncasecmp(minornode->name,slicemap[i][j],strlen(slicemap[i][j])) )
	  minornode->partition = i;
  
  /*-----------------------------------------------------------
    GET THE PARTITION TYPE FROM DKIOCINFO
    ----------------------------------------------------------*/
  /*If no path for the slice return */
  if ( !strlen(minornode->nodepath) )
    return;
  
  /*------------------------------------------------------------
    GET THE FILE DESCRIPTOR
    ------------------------------------------------------------*/  
  /* Restore the root effective userid of the process */
  seteuid(effectiveuid);
  
  if (( disk = open(minornode->nodepath,O_RDONLY|O_NDELAY)) == -1 ){    
    /* revoke effective root uid privilege */
    seteuid(getuid()); 
    return;
  }
  
  /* revoke effective root uid privilege */
  seteuid(getuid());  
  
  /*------------------------------------------------------------
    SEND A DKIOCINFO COMMAND TO THE DISK
    ------------------------------------------------------------*/  
  if ( ioctl(disk,DKIOCINFO,(intptr_t)&dkbuffer) == -1 )
    {
      close(disk);
      return;   
    }
  
  /* ----------------------------------------------------------
     Save the partition number and controller information
     ---------------------------------------------------------*/
  minornode->partition = dkbuffer.dki_partition;
  
  /*------------------------------------------------------------
    Controller infomation is the same for all partitions
    -------------------------------------------------------------*/
  if ( !strlen(treeaddress->dki_cname) ){
    
    sprintf(treeaddress->dki_cname,"%s",dkbuffer.dki_cname);
    treeaddress->dki_cnum = dkbuffer.dki_cnum;
    treeaddress->dki_ctype = dkbuffer.dki_ctype;
    
  }
  
  close(disk);
  
}

/* DKIOCGETMEDIAINFO is not defined for 5_6 */
#ifdef OS_5_7
/*
  Get media information using the
  DKIOCGETMEDIAINFO ioctl on any CHAR minor node
*/
void storeMediaInformation(struct devicetree *treeaddress){ 
  
  int   disk;  
  struct dk_minfo  minfo;  
  int i;  
  
  /* Try to get the partition information from one of the 
     CHAR minor nodes*/
  for(i=0;
      i<sizeof(minorNodeList)/sizeof(struct minornodedata *);
      i++)
    { 
      
      /* No more minor nodes left */
      if  ( minorNodeList[i].majornumber == UNKNOWN )
	break;  
      
      /* Only char minor nodes with known partition 
	 to get the media information*/
      if (
	  (  minorNodeList[i].partition == UNKNOWN )||
	  (  minorNodeList[i].spectype == S_IFBLK )
	  )
	continue;
      
      /* If the disk path is not set continue to the next minor node */
      if ( !strlen(minorNodeList[i].nodepath) )
	continue;
      
      /*------------------------------------------------------------
	GET THE FILE DESCRIPTOR
	------------------------------------------------------------*/  
      /* Restore the root effective userid of the process */
      seteuid(effectiveuid);
      
      if (( disk = open(minorNodeList[i].nodepath,O_RDONLY|O_NDELAY)) == -1 ){
	/* revoke effective root uid privilege */
	seteuid(getuid());
	continue;
      }
      
      /* revoke effective root uid privilege */
      seteuid(getuid());
      
      /*------------------------------------------------------------
	SEND A  DKIOCGMEDIAINFO  COMMAND TO THE DISK
	This gets the media information
	type
	block size
	size = no of blocks* capacity
	------------------------------------------------------------*/
      if ( ioctl(disk,DKIOCGMEDIAINFO,(intptr_t)&minfo) == -1 )
	{
	  close(disk);
	  continue;
	}
      
      treeaddress->size = (double)minfo.dki_capacity * (double)minfo.dki_lbsize;
      treeaddress->nsize = minfo.dki_capacity; 
      treeaddress->blocksize = minfo.dki_lbsize;
      treeaddress->mediatype = minfo.dki_media_type;
      
      close(disk);
      
      /* successfull in getting the partition information so break 
	 the out of the loop */
      break;
      
    }  
  
}

#endif
/* End of OS_5_7*/



/*
  store informaton related to the disk geometry
  DKIOCGGEOM ioctl on any CHAR minor node
*/
void storeDiskGeometry(struct devicetree *treeaddress){ 
  
  int   disk;  
  struct dk_geom  geom;  
  int i;  
  
  /* Try to get the geometry information from one of the 
     CHAR minor nodes*/
  for(i=0;
      i<sizeof(minorNodeList)/sizeof(struct minornodedata *);
      i++)
    { 
      
      /* No more minor nodes left */
      if ( minorNodeList[i].majornumber == UNKNOWN )
	break;  
      
      /* Only char minor nodes with known partition 
	 to get the geometry information*/
      if (
	  (  minorNodeList[i].partition == UNKNOWN )||
	  (  minorNodeList[i].spectype == S_IFBLK )
	  )
	continue;
      
      /* If the disk path is not set continue to the next minor node */
      if ( !strlen(minorNodeList[i].nodepath) )
	continue;
      
      /*------------------------------------------------------------
	GET THE FILE DESCRIPTOR
	------------------------------------------------------------*/  
      /* Restore the root effective userid of the process */
      seteuid(effectiveuid);
      
      if (( disk = open(minorNodeList[i].nodepath,O_RDONLY|O_NDELAY)) == -1 ){	
	/* revoke effective root uid privilege */
	seteuid(getuid());
	continue;
      }
      
      /* revoke effective root uid privilege */
      seteuid(getuid());
      
      /*------------------------------------------------------------
	SEND A  DKIOCGGEOM  COMMAND TO THE DISK
	This gets the disk geometry information			
	------------------------------------------------------------*/
      if ( ioctl(disk,DKIOCGGEOM,(intptr_t)&geom) == -1 )
	{
	  close(disk);
	  continue;
	}
      
      treeaddress->dkg_ncyl = geom.dkg_ncyl; 
      treeaddress->dkg_acyl = geom.dkg_acyl;
      treeaddress->dkg_nsect = geom.dkg_nsect; 
      treeaddress->dkg_pcyl = geom.dkg_pcyl;
      treeaddress->dkg_rpm = geom.dkg_rpm;
      
      close(disk);
      
      /* successfull in getting the geometry information so break 
	 the out of the loop*/
      break;
      
    }

}



/*
  Get the partition information using format routines
  This function is called if DKIOCVTOC fails for a disk  
*/
void storePartitionSize(struct devicetree *treeaddress){ 
  
  int   disk;  

  /* dk_minfo is available in 0S_5_7 only*/
#ifdef OS_5_7
  struct dk_minfo  minfo;
#endif

  struct dk_allmap dkmap;
  int i,j;  
  
  /* Try to get the partition information from one of the 
     char minor nodes*/
  for(i=0;
      i<sizeof(minorNodeList)/sizeof(struct minornodedata *);
      i++)
    { 
      
      /* No more minor nodes left */
      if  ( minorNodeList[i].majornumber == UNKNOWN )
	break;  
      
      /* Only CHAR minor nodes with KNOWN partition 
	 to get the partition table*/
      if (
	  (  minorNodeList[i].partition == UNKNOWN )||
	  (  minorNodeList[i].spectype == S_IFBLK )
	  )
	continue;
      
      /* If the disk path is not set continue to the next minor node */
      if ( !strlen(minorNodeList[i].nodepath) )
	continue;
      
      /*------------------------------------------------------------
	GET THE FILE DESCRIPTOR
	------------------------------------------------------------*/  
      /* Restore the root effective userid of the process */
      seteuid(effectiveuid);
      
      if (( disk = open(minorNodeList[i].nodepath,O_RDONLY|O_NDELAY)) == -1 ){
	/* revoke effective root uid privilege */
	seteuid(getuid());
	continue;
      }
      
      /* revoke effective root uid privilege */
      seteuid(getuid());
      
      /*------------------------------------------------------------
	SEND A  DKIOCGMEDIAINFO  COMMAND TO THE DISK
	This gets the media information
	type
	block size
	size = no of blocks* capacity
	DO this only if block size is not yet got, ie UNKNOWN
	------------------------------------------------------------*/
/* DKIOCGETMEDIAINFO is not defined for 5_6 , default the blocksize*/
#ifdef OS_5_7

      if ( treeaddress->blocksize == UNKNOWN )
	{
	  if ( ioctl(disk,DKIOCGMEDIAINFO,(intptr_t)&minfo) == -1 )
	    {
	      close(disk);
	      continue;
	    }
	  
	  treeaddress->size = (double)minfo.dki_capacity *(double)minfo.dki_lbsize;
	  treeaddress->nsize = minfo.dki_capacity;
	  treeaddress->blocksize = minfo.dki_lbsize;	  
	  treeaddress->mediatype = minfo.dki_media_type;

	}
#else      
      treeaddress->blocksize = DEFAULT_BLOCKSIZE;
#endif

      /*------------------------------------------------------------
	SEND A DKIOCGAPART COMMAND TO THE DISK
	This gets the partitions and their sizes in blocks
	------------------------------------------------------------*/  
      if ( ioctl(disk,DKIOCGAPART,(intptr_t)&dkmap) == -1 )                    
	{
	  close(disk);
	  continue;    
	}
      
      /*------------------------------------------------------------
	SAVE THE PARTITION INFORMATION IN THE MINOR NODES ARRAY
	------------------------------------------------------------*/     
      for(j=0;
	  j<sizeof(minorNodeList)/sizeof(struct minornodedata *);
	  j++)
	{    
	  
	  /* No more minor nodes left */
	  if ( minorNodeList[j].majornumber == UNKNOWN )
	    break;
	  
	  /*--------------------------------------------------------
	    If the partition number is > partition number from dk_allmap
	    table	
	    -------------------------------------------------------*/
	  if ( minorNodeList[j].partition >= 
	       sizeof(dkmap.dka_map)/sizeof(struct dk_map) )
	    continue;
	  
	  /*-------------------------------------------------------------
	    Save the partition type,startsector and size
	    ------------------------------------------------------------*/      	  	  
	  minorNodeList[j].startsector = dkmap.dka_map[minorNodeList[j].partition].dkl_cylno;

	  minorNodeList[j].nsize = dkmap.dka_map[minorNodeList[j].partition].dkl_nblk;

	  minorNodeList[j].size = 
	    (double)dkmap.dka_map[minorNodeList[j].partition].dkl_nblk*(double)treeaddress->blocksize;
	  
	}
      
      close(disk);
      
      /* successfull in getting the partition information so break 
	 the out of the loop*/
      break;
      
    }

}


/* 
   Get all the (VTOC table )partitions for the disk along with size of 
   each partition
*/

void storeVtocSize(
			struct devicetree *treeaddress			
			){ 
  int   disk;  
  struct vtoc     vtocbuffer;
  int i,j;  
  
  /*--------------------------------------------------------------
    Save the partition information to block devices with the same 
    minor node number
    *---------------------------------------------------------------*/
  for(i=0;
      i<sizeof(minorNodeList)/sizeof(struct minornodedata *);
      i++)
    { 
      
      /* No more minor nodes left */
      if  ( minorNodeList[i].majornumber == UNKNOWN )
	break;  
      
      /* Only block minor nodes with UNKNOWN partition 
	 to get the partition number*/
      if (
	  (  minorNodeList[i].partition != UNKNOWN )||
	  (  minorNodeList[i].spectype == S_IFCHR )
	  )
	continue;
      
      /* Find the partition number from the char minor node*/
      for(j=0;
	  j<sizeof(minorNodeList)/sizeof(struct minornodedata *);
	  j++)
	{	  
	  
	  /* No more minor nodes left to search*/
	  if  ( minorNodeList[j].majornumber == UNKNOWN )
	    break; 
	  
	  /* Read partition number from RAW minor nodes only*/
	  if (
	      (  minorNodeList[j].partition == UNKNOWN )||
	      (  minorNodeList[j].spectype == S_IFBLK )
	      )
	    continue;
	  
	  /* If major and minor number matches save partition number*/
	  if (
	      ( minorNodeList[j].majornumber ==  minorNodeList[i].majornumber )&&
	      ( minorNodeList[j].minornumber ==  minorNodeList[i].minornumber )
	      )
	    {
	      minorNodeList[i].partition = minorNodeList[j].partition;
	      break;
	    }
	  
	}
      
    }
  
  /* If the disk path is not set return*/
  if ( !strlen(treeaddress->devicepath) )
    return;
  
  /*------------------------------------------------------------
    GET THE FILE DESCRIPTOR
    ------------------------------------------------------------*/  
  /* Restore the root effective userid of the process */
  seteuid(effectiveuid);
  
  if (( disk = open(treeaddress->devicepath,O_RDONLY|O_NDELAY)) == -1 ){
    /* revoke effective root uid privilege */
    seteuid(getuid());      
    return;
  }
  
  /* revoke effective root uid privilege */
  seteuid(getuid());
  
  /*------------------------------------------------------------
    SEND A  DKIOCGVTOC COMMAND TO THE DISK
    ------------------------------------------------------------*/    
  if ( ioctl(disk,DKIOCGVTOC,(intptr_t)&vtocbuffer) == -1 )          
    {
      close(disk);
      treeaddress->formatstatus = UNFORMATTED;
      return;
    }
  
  treeaddress->formatstatus = FORMATTED;
    
  /*------------------------------------------------------------
    SAVE THE PARTITION INFORMATION IN THE MINOR NODES ARRAY
    ------------------------------------------------------------*/  
  sprintf(treeaddress->volumeLabel,"%s:",vtocbuffer.v_volume);
  sprintf(treeaddress->ascii_label,"%s",vtocbuffer.v_asciilabel);
  treeaddress->v_sectorsz = vtocbuffer.v_sectorsz;
  
  for(i=0;
      i<sizeof(minorNodeList)/sizeof(struct minornodedata *);
      i++)
    {    
      
      /* No more minor nodes left */
      if  ( minorNodeList[i].majornumber == UNKNOWN )
	break;
      
      /*--------------------------------------------------------
	If the partition number is > partition number from vtoc table	
	-------------------------------------------------------*/
      if ( minorNodeList[i].partition >= vtocbuffer.v_nparts )
	continue;
      
      /* ------------------------------------------------------------
	 Save the path of the raw backup slice as treeaddress->devicepath
	 -------------------------------------------------------------*/
      if (
	  ( vtocbuffer.v_part[minorNodeList[i].partition].p_tag == V_BACKUP) &&
	  ( minorNodeList[i].spectype == S_IFCHR )
	  )
	sprintf(treeaddress->devicepath,"%s", minorNodeList[i].nodepath);
      
      /*-------------------------------------------------------------
	Save the partition type,startsector and size
	------------------------------------------------------------*/
      minorNodeList[i].partitiontype = vtocbuffer.v_part[minorNodeList[i].partition].p_tag;
      
      minorNodeList[i].startsector = vtocbuffer.v_part[minorNodeList[i].partition].p_start;

      minorNodeList[i].nsize =  vtocbuffer.v_part[minorNodeList[i].partition].p_size;  
      
      minorNodeList[i].size = 
	(double)vtocbuffer.v_part[minorNodeList[i].partition].p_size*(double)treeaddress->v_sectorsz;
      
    }
  
  close(disk);

}



/* Store the minor node data for each disk node
   minor nodes equate to partitions*/
void storeDiskMinorNodes(kvm_t  *kd,struct devicetree *treeaddress,
			 struct ddi_minor_data *pminor_data)
{
  
  char *value;
  struct ddi_minor_data minor_data;
  int i = 0;
  
  /* Print the details for each minor node for this disk node*/
  for(
      i=0;
      ( pminor_data != ( struct ddi_minor_data *)NULL) &&
	( i < MAX_MINOR_NODES );
      i++,pminor_data = minor_data.next
      ) {
    
    if ( kvm_kread(kd,(uintptr_t)pminor_data,(void *)&minor_data,
		   sizeof(struct ddi_minor_data)) == -1 ){
      
      printf("error:: kdisks.c, storeDiskMinorNodes: %d %s \n",errno,strerror(errno));      
      exit(EXIT_FAILURE); 
      
    }
    
    /* Device type or node type */
    value = readStringBuffer(kd,(uintptr_t)minor_data.mu.d_minor.node_type);
    
    /* If the minor node is not a disk device type then do not store the node
       , The exception is pseudo devices where value may be NULL or of type DDI_PSEUDO*/
    if ( 
	( !value )||
	( !strcasecmp(value,"") )
	)
      sprintf(minorNodeList[i].nodetype,"%s","NULL");
    else if ( !strcasecmp(value,DDI_NT_BLOCK) )
      sprintf(minorNodeList[i].nodetype,"%s","DDI_NT_BLOCK");
    else if ( !strcasecmp(value,DDI_NT_BLOCK_CHAN) )
      sprintf(minorNodeList[i].nodetype,"%s","DDI_NT_BLOCK_CHAN");
    else if ( !strcasecmp(value,DDI_NT_BLOCK_WWN) )
      sprintf(minorNodeList[i].nodetype,"%s","DDI_NT_BLOCK_WWN");
    else if ( !strcasecmp(value,DDI_PSEUDO) )
      sprintf(minorNodeList[i].nodetype,"%s","DDI_PSEUDO");
    else if ( !strcasecmp(value,DDI_NT_BLOCK_FABRIC) )
      sprintf(minorNodeList[i].nodetype,"%s","DDI_NT_BLOCK_FABRIC");
   else if ( !strcasecmp(value,DDI_NT_NEXUS) )
      sprintf(minorNodeList[i].nodetype,"%s","DDI_NT_NEXUS");
    else if ( !strcasecmp(value,DDI_NT_SCSI_NEXUS) )
      sprintf(minorNodeList[i].nodetype,"%s","DDI_NT_SCSI_NEXUS");
    else if ( !strcasecmp(value,DDI_NT_SBD_ATTACHMENT_POINT) )
      sprintf(minorNodeList[i].nodetype,"%s","DDI_NT_SBD_ATTACHMENT_POINT");
    else if ( !strcasecmp(value,DDI_NT_FC_ATTACHMENT_POINT) )
      sprintf(minorNodeList[i].nodetype,"%s","DDI_NT_FC_ATTACHMENT_POINT");
    else if ( !strcasecmp(value,DDI_NT_ATTACHMENT_POINT) )
      sprintf(minorNodeList[i].nodetype,"%s","DDI_NT_ATTACHMENT_POINT");
    else if ( !strcasecmp(value,DDI_NT_SCSI_ATTACHMENT_POINT) )
      sprintf(minorNodeList[i].nodetype,"%s","DDI_NT_SCSI_ATTACHMENT_POINT");
    else if ( !strcasecmp(value,DDI_NT_PCI_ATTACHMENT_POINT) )
      sprintf(minorNodeList[i].nodetype,"%s","DDI_NT_PCI_ATTACHMENT_POINT");
    else if ( !strcasecmp(value,DDI_NT_CD) )
      sprintf(minorNodeList[i].nodetype,"%s","DDI_NT_CD");
    else if ( !strcasecmp(value,DDI_NT_CD_CHAN) )
      sprintf(minorNodeList[i].nodetype,"%s","DDI_NT_CD_CHAN");
    else if ( !strcasecmp(value,DDI_NT_BLOCK_CHAN_RDRIVER) )
     sprintf(minorNodeList[i].nodetype,"%s","DDI_NT_BLOCK_CHAN_RDRIVER"); 
    else
      sprintf(minorNodeList[i].nodetype,"%s",value);
    
    /* Device node name */
    value = readStringBuffer(kd,(uintptr_t)minor_data.mu.d_minor.name);
    
    /* Print the physical path from the parent nodes*/       
    sprintf(minorNodeList[i].name,":%s",value);
    sprintf(minorNodeList[i].nodepath,"%s%s",
	    treeaddress->physicalPath,minorNodeList[i].name);
    
    /* Major number and minor number */
    minorNodeList[i].majornumber=major(minor_data.mu.d_minor.dev);
    minorNodeList[i].minornumber= minor(minor_data.mu.d_minor.dev);
    
    /* Flag to indicate, block or character */
    minorNodeList[i].spectype =  minor_data.mu.d_minor.spec_type;

    /* mdclass only in OS_5_7 */
#ifdef OS_5_7
    
    /* Store the node class, may be useful in cluster cases*/
    switch(minor_data.mu.d_minor.mdclass & DEVCLASS_MASK)
      {
      case GLOBAL_DEV:
	sprintf(minorNodeList[i].nodeclass,"%s","GLOBAL_DEV");
	break;
      case NODEBOUND_DEV:
	sprintf(minorNodeList[i].nodeclass,"%s","NODEBOUND_DEV");
	break;
      case NODESPECIFIC_DEV:
	sprintf(minorNodeList[i].nodeclass,"%s","NODESPECIFIC_DEV");
	break;
      case ENUMERATED_DEV:
	sprintf(minorNodeList[i].nodeclass,"%s","ENUMERATED_DEV");
	break;
      default:
	sprintf(minorNodeList[i].nodeclass,"%d",
		minor_data.mu.d_minor.mdclass & DEVCLASS_MASK);	
      }
    
    /* Store flag to indicate if device is a clone*/
    if ( minor_data.mu.d_minor.mdclass & CLONE_DEV )
      sprintf(minorNodeList[i].clone,"%s","CLONE_DEV");

#else

    sprintf(minorNodeList[i].nodeclass,"%s","UNKNOWN");
    sprintf(minorNodeList[i].clone,"%s","UNKNOWN");

#endif
    /* End of OS_5_7 */
    
     
    /* Get the partition information for this minor node if
       minor node is a CHAR device*/
    if ( minor_data.mu.d_minor.spec_type == S_IFCHR )
      storeDiskPartition(treeaddress,&minorNodeList[i]);
    
    /* Save the path of partition# 2, type char as  the devicepath in 
       treeaddress
       For now assume 2 to be the backup slice
       If unable to get partition# for the slice( IOCTL error) then
       use slice c as the backup slice
    */
    if (
	( minor_data.mu.d_minor.spec_type == S_IFCHR )&&
	(
	 ( minorNodeList[i].partition == BACKUP_SLICE )||
	 ( !strncasecmp(minorNodeList[i].name,":c",2) )
	 )
	)
      sprintf(treeaddress->devicepath,"%s", minorNodeList[i].nodepath);
    
    /* If minor node is an DM_ALIAS ie. points into another dev_info structure 
       check if the minor node in that dev_info structure is a disk
    */
    if ( minor_data.type == DDM_ALIAS )      
      storeDiskMinorNodes(kd,treeaddress,minor_data.mu.d_alias.dmp);
    
    
    /* If the minor node does not point to the address of the device then
       its an aliased minor node so skip*/
    if ((intptr_t)minor_data.dip != (intptr_t)treeaddress->memaddress)
      break;
    
  }
  
}


/* Read and store the relevent disk device properties */
void storeDiskDeviceProperties(kvm_t *kd,struct devicetree *treeaddress,
			       struct ddi_prop *propaddress){
  
  struct ddi_prop device_property;
  struct ddi_prop *pdevice_property;
  char   propType[BUFFER_MAX];
  char	*strValue;
  uchar_t *byteValue;
  int	*intValue;
  boolean_t   boolValue;
  int 	i;  
  int   size;
  
  /* Go thru the list of properties to glean the properties of interest*/ 
  for(  pdevice_property = propaddress;
	pdevice_property != NULL;
	pdevice_property = device_property.prop_next	
	){
    
    if ( kvm_kread(kd,(uintptr_t)pdevice_property,(void *)&device_property,
		   sizeof(struct ddi_prop)) == -1 ){
      
      printf("error:: kdisks.c,storeDiskDeviceProperties: %d %s \n",errno,strerror(errno));      
      exit(EXIT_FAILURE); 
      
    }
    
    strValue = readStringBuffer(kd,(uintptr_t)device_property.prop_name);
    strcpy(propType,strValue);
    /* For disks we are interested only in the 
       lun ,
       target ,
       vendor ,
       product properties
       for now ,otherwise go to the next property*/
    if ( strncasecmp(propType,"target",6) && 
	 strncasecmp(propType,"lun",3) &&
	 strncasecmp(propType,"class",5) &&
	 strncasecmp(propType,"layered_driver",14) &&
	 strncasecmp(propType,"PathA",5) &&
	 strncasecmp(propType,"PathA",5) &&
	 !strstr(propType,"vendor") &&
	 !strstr(propType,"product")
	 )
      continue;
    
    /* Check for the data type of the property */
    switch(device_property.prop_flags&DDI_PROP_TYPE_MASK){
      
    case DDI_PROP_TYPE_INT:
      intValue = (int *)readBuffer(kd,
				   (uintptr_t)device_property.prop_val,
				   device_property.prop_len);         
      break;
    case DDI_PROP_TYPE_STRING:
      strValue = readStringBuffer(kd,(uintptr_t)device_property.prop_val);
      
      break;
    case DDI_PROP_TYPE_BYTE:
    case DDI_PROP_TYPE_COMPOSITE:
      byteValue = readBuffer(kd,
			     (uintptr_t)device_property.prop_val,
			     device_property.prop_len);   
      break;
    default:
      /* -----------------------------------------------------
	 If length 0 then boolean and value true
	 ----------------------------------------------------*/
      if ( device_property.prop_len ==  0)
	boolValue=TRUE;	
      else
	{	  
	  byteValue = readBuffer(kd,
				 (uintptr_t)device_property.prop_val,
				 device_property.prop_len);
	}
    }
    
        
    /* -------------------------------------------------------
       Check for the data type of the property 
       and store the required values in the devicetree
       ------------------------------------------------------*/
    switch(device_property.prop_flags&DDI_PROP_TYPE_MASK){
    case DDI_PROP_TYPE_INT:
      
      /*-------------------------------------------------------- 
	Although I am reading length ints, its hard to imagine why
	target or lun will meed to be more than one int size (4 bytes)
	so take only the first element of the array
	-----------------------------------------------------*/   
      if ( !strncasecmp(propType,"target",6) )
	treeaddress->target = intValue[0];
      else if ( !strncasecmp(propType,"lun",3) )
	treeaddress->lun = intValue[0];
      break;
    case DDI_PROP_TYPE_STRING:
      /*-------------------------------------------------------- 
	Implicit assumption that value will be less than BUFFER_MAX
	------------------------------------------------------*/   
      if ( strstr(propType,"vendor") )
	sprintf(treeaddress->vendor,"%s",strValue);
      else if ( strstr(propType,"product") )
	sprintf(treeaddress->product,"%s",strValue);
      else if ( !strncasecmp(propType,"class",5) )
	sprintf(treeaddress->class,"%s",strValue);
      break;
    default:
      if (
	  ( !strncasecmp(propType,"layered_driver",14) )||
	  ( !strncasecmp(propType,"PathA",5) ) ||
	  ( !strncasecmp(propType,"PathB",5) )
	  )
	/* Keep appending the information as configuration information with a -- separator */
	{	  	  
	  
	  /* Length of the current string */
	  size = strlen(treeaddress->configuration) + 1;
	  
	  /* size used in the string
	     size+3  
	     separator -- between the previous value,  one for =
	     if first value then size+1 , no separator */
	  size = ( size > 0) ? size+3:size+1;
	  
	  /* check if there is space left in treeaddress->configuration to copy the name, value*/	  
	  if (  (strlen(propType) + device_property.prop_len) > (BUFFER_MAX_CONFIG-size) )
	    continue;
	  
	  /* Copy the permissible amount of configuration with a -- between configurations */	  
	  if ( !strlen(treeaddress->configuration) )
	    sprintf(treeaddress->configuration,"%s=",propType);  
	  else
	    sprintf(treeaddress->configuration,"%s--%s=",treeaddress->configuration,propType);

	  /* Current size */
	  size = strlen(treeaddress->configuration);

	  /* Copy the byte buffer -assumption it represents printable chars*/
	  for(i=0;i<device_property.prop_len;i++)     
            treeaddress->configuration[size+i] = byteValue[i];

	  treeaddress->configuration[size+i] = '\0';

	}
    
    }

  }

}

/* Return the type of Controller the minor node represents, SCSI, IDE or UNKNOWN etc.*/
int getControllerType(kvm_t *kd, struct devicetree *treeaddress,
		      struct ddi_minor_data *pminor_data){
  
  struct ddi_minor_data minor_data;
  int type;
  char *value;

  if ( treeaddress->controllerType )
    return  treeaddress->controllerType;
  
  /*------------------------------------------------------
    Loop thru the chain of minor nodes
    -----------------------------------------------------*/
  for(;pminor_data != (struct ddi_minor_data *)NULL;
      pminor_data = minor_data.next) {
    
    if ( kvm_kread(kd,(uintptr_t)pminor_data,(void *)&minor_data,
		   sizeof(struct ddi_minor_data)) == -1 ){
      
      printf("error:: kdisks.c,getControllerType: %d %s \n",errno,strerror(errno));      
      exit(EXIT_FAILURE); 
      
    }
    
    /* Read the node type for the minor node*/
    value = readStringBuffer(kd,(uintptr_t)minor_data.mu.d_minor.node_type);
    
    /* At the moment we know for sure these node types 
       represent SCSI controller*/
    if (
	value
	&&
	(
	 ( !strcasecmp(value,DDI_NT_SCSI_NEXUS) )||
	 ( !strcasecmp(value,DDI_NT_SCSI_ATTACHMENT_POINT) )||
	 ( !strcasecmp(value,DDI_NT_FC_ATTACHMENT_POINT) )||
	 ( !strcasecmp(value,DDI_NT_BLOCK_WWN) )
	 )
	)
      {
	treeaddress->controllerType =  DISK_SCSI;	
	return DISK_SCSI;
      }
    
    /*-------------------------------------------------------------
      If minor node is an DM_ALIAS ie points to another dev_info 
      structure check if the minor node in that dev_info structure 
      is a disk
       ----------------------------------------------------------- */
    if ( minor_data.type == DDM_ALIAS )
      if (
	  ( type =  getControllerType(kd,treeaddress,minor_data.mu.d_alias.dmp)) 
	  != DISK_UNKNOWN 
	  )	
	return type; 
    
    /*------------------------------------------------------------
      If this is a aliased node , 
      it doesnt point to the original dev_info structure
      then dont go to the next sibbling, break from the loop
      -------------------------------------------------------------*/
    if ( (intptr_t)minor_data.dip != (intptr_t)treeaddress->memaddress )
      break;
    
  }
  
  return DISK_UNKNOWN;

}



/*  Return the disk type as SCSI, IDE or UNKNOWN
 */
int getDiskType(kvm_t *kd,struct devicetree *treeaddress, 
		struct dev_info *device){ 
  
  struct dev_info controller;
  
  if (
      ( !device )||
      ( !treeaddress )
      )
    return DISK_UNKNOWN;
  
  /*------------------------------------------------------------
    If property class=scsi then scsi disk
    --------------------------------------------------------------*/
  if ( !strncasecmp(treeaddress->class,"scsi",4) )
    return DISK_SCSI;
  
  /*-------------------------------------------------------------
    Check controller type for the disk
    ---------------------------------------------------------------*/
  if (
      ( treeaddress->dki_ctype == DKC_SCSI_CCS )||
      ( treeaddress->dki_ctype == DKC_MD21 )
      )
    return DISK_SCSI;
  else if (treeaddress->dki_ctype == DKC_DIRECT )
    return DISK_IDE;  
  else if (treeaddress->dki_ctype == DKC_MD )
    return DISK_META;
  
  /*-------------------------------------------------------------
    Check if parent controller is a scsi controller
    ---------------------------------------------------------------*/
  if ( treeaddress->parentnode == (struct devicetree *) NULL)    
    return DISK_UNKNOWN;
  
  /*-------------------------------------------------------------
    If the controller type is saved then return that
    ---------------------------------------------------------------*/ 
  if ( treeaddress->parentnode->controllerType )
    return  treeaddress->parentnode->controllerType;
  
  /*-------------------------------------------------------------
     Fetch the contoller type from the parent
     ---------------------------------------------------------------*/  
  if ( kvm_kread(kd,(uintptr_t)treeaddress->parentnode->memaddress,(void *)&controller,
		 sizeof(controller)) == -1 )
    {
      printf("error:: kdisks.c,getDiskType: %d %s \n",errno,strerror(errno));      
      exit(EXIT_FAILURE);       
    }
  
  return (  treeaddress->parentnode->controllerType = 
	    getControllerType(kd,treeaddress->parentnode,controller.devi_minor) );
  
}



/* Print the scsi_device data from the devi_driver_data member */
void storeScsiData(kvm_t *kd,struct devicetree *treeaddress,
		   struct dev_info *device)
{
  
  struct scsi_device scsidevice;
  struct scsi_inquiry scsiinquiry;
  char  *value;
  
  if ( device->devi_driver_data == (caddr_t) NULL)
    return;
  
  if ( kvm_kread(kd,(uintptr_t)device->devi_driver_data,(void *)&scsidevice,
		 (size_t)sizeof(struct scsi_device)) == -1 ){
    
    printf("error:: kdisks.c,storeScsiData: %d %s \n",errno,strerror(errno));      
    exit(EXIT_FAILURE);    
    
  }

  treeaddress->scsitarget = scsidevice.sd_address.a_target;
  treeaddress->scsilun = scsidevice.sd_address.a_lun;
  
  if ( !scsidevice.sd_inq )
    return;
  
  if ( kvm_kread(kd,(uintptr_t)scsidevice.sd_inq,(void *)&scsiinquiry,
		 (size_t)sizeof(struct scsi_inquiry)) == -1 ){
    
    printf("error:: kdisks.c,storeScsiData: %d %s \n",errno,strerror(errno));      
    exit(EXIT_FAILURE);  
    
  }

  value = readStringFromBuffer(scsiinquiry.inq_vid,sizeof(scsiinquiry.inq_vid));
  sprintf(treeaddress->scsivendor,"%s",value);
  
  value = readStringFromBuffer(scsiinquiry.inq_pid,sizeof(scsiinquiry.inq_pid));
  sprintf(treeaddress->scsiproduct,"%s",value);
  
  value = readStringFromBuffer(scsiinquiry.inq_revision,sizeof(scsiinquiry.inq_revision));
  sprintf(treeaddress->scsirevision,"%s",value);
  
  value = readStringFromBuffer(scsiinquiry.inq_serial,sizeof(scsiinquiry.inq_serial));
  sprintf(treeaddress->scsiserial,"%s",value);

}



/* Read and store the data from the device id structure */
void storeDeviceidData(kvm_t *kd,struct devicetree *treeaddress,
		       struct dev_info *device){

  struct impl_devid 	device_id;
  caddr_t       value;
  ushort_t  	intValue;
  int		i;
  ptrdiff_t     pdiff;
  uchar_t       *devid;
  
  /* For solaris 2.9 device id information is stored in properties and
     device->devi_devid is set to -1
  */   
  if (  ( (intptr_t)device->devi_devid == (intptr_t) NULL) ||
	( (intptr_t)device->devi_devid == (intptr_t) -1 )
	)
    return;  
  
  if ( kvm_kread(kd,(intptr_t)device->devi_devid,(void *)&device_id,
		 (size_t)sizeof(struct impl_devid)) == -1 ){
    
    printf("error:: kdisks.c,storeDeviceidData: %d %s \n",errno,strerror(errno));      
    exit(EXIT_FAILURE);  
    
  }
    
  /* Print the type of device id
     DEVID_NONE              
     DEVID_SCSI3_WWN         
     DEVID_SCSI_SERIAL       
     DEVID_FAB               
     DEVID_ENCAP             
  */

  intValue = DEVID_GETTYPE(&device_id);

  switch(intValue){
  case DEVID_NONE:
    sprintf(treeaddress->deviceidtype,"%s","DEVID_NONE");
    break;
  case  DEVID_SCSI3_WWN:
    sprintf(treeaddress->deviceidtype,"%s","DEVID_SCSI3_WWN");
    break;
  case  DEVID_SCSI_SERIAL:
    sprintf(treeaddress->deviceidtype,"%s","DEVID_SCSI_SERIAL");
    break;
  case DEVID_FAB:
    sprintf(treeaddress->deviceidtype,"%s","DEVID_FAB");
    break;
  case DEVID_ENCAP:
    sprintf(treeaddress->deviceidtype,"%s","DEVID_ENCAP");
    break;
  default:
    sprintf(treeaddress->deviceidtype,"%d",intValue);
  }
  
  value = readStringFromBuffer(device_id.did_driver,(size_t)DEVID_HINT_SIZE);
  sprintf(treeaddress->deviceidhint,"%s",value);

  intValue = DEVID_GETLEN(&device_id);
  treeaddress->deviceidlength = intValue;
  
  /* ---------------------------------------------------------------
     Read the device id , of length inValue at address  of device_id 
     + offset as shown below
     --------------------------------------------------------------*/
  pdiff =  (intptr_t)device->devi_devid
    +(intptr_t)&device_id.did_id 
    - (intptr_t)&device_id;
  
  if ( intValue )
    devid = readBuffer(kd,pdiff,intValue);
  
  for(i=0;((i<intValue)&&(i<BUFFER_MAX));i++)     
    treeaddress->deviceid[i] = devid[i];      
  
}


/* Print all disk device information 
   print minor nodes if they exist , else print a line for the disk node */
void printDiskData(kvm_t *kd,struct devicetree *treeaddress,struct dev_info *device){
  
  char *value;
  int i;
  
  /* ----------------------------------------------------------
     Skip if not cannonical form 2 implies , not successfully 
     probed and attached means devi_info.devi_ops is NULL
     --------------------------------------------------------- */
  if ( !DDI_CF2(device) )
    return;
  
  /* -----------------------------------------------------------
     Read and store the relevent disk node properties in the 
     devicetree structure
     ----------------------------------------------------------*/
  storeDiskDeviceProperties(kd,treeaddress,device->devi_drv_prop_ptr);
  storeDiskDeviceProperties(kd,treeaddress,device->devi_sys_prop_ptr);
  storeDiskDeviceProperties(kd,treeaddress,device->devi_hw_prop_ptr);  

  /*-----------------------------------------------------------
    Clean up the minor nodes data structure
    ----------------------------------------------------------*/  
  for(i=0;i<sizeof(minorNodeList)/sizeof(struct minornodedata );i++)
    {
      minorNodeList[i].majornumber = UNKNOWN;
      minorNodeList[i].partition = UNKNOWN;
      minorNodeList[i].partitiontype = UNKNOWN;
      minorNodeList[i].startsector = UNKNOWN;
      minorNodeList[i].nsize = UNKNOWN;      
      minorNodeList[i].size = UNKNOWN;
      strcpy(minorNodeList[i].nodeclass,"UNKNOWN");
    }
  
  /* --------------------------------------------------------
     Build the physical path for the node, so each minor node
     can build the path to a partition
     -------------------------------------------------------*/
  buildPhysicalPath(treeaddress);
  
  /* --------------------------------------------------------     
     store the chain of relevent minor node data 
     treeaddress->devicepath should be filled in here
     either from V_BACKUP or partition 2
     -------------------------------------------------------*/  
  storeDiskMinorNodes(kd,treeaddress,device->devi_minor);
  
  /* --------------------------------------------------------     
     Get the media information for the disk from
     DKIOCGETMEDIAINFO 
     - blocksize,
     - size
     - media type
     from atleast one of the nodes
     -----------------------------------------------------*/
  /* DKIOCGMEDIAINFO is implemented in OS_5_7 only*/
#ifdef OS_5_7  
  storeMediaInformation(treeaddress);
#endif
  
  /* --------------------------------------------------------     
     Get the disk geometry
     DKIOCGGEOM 
     - no of cylinders
     - sectors per track
     - rpm     
     -----------------------------------------------------*/ 
  storeDiskGeometry(treeaddress);

  /*---------------------------------------------------------
    Get the partition size for each minor node
    DKIOCGVOTC
    --------------------------------------------------------*/
  storeVtocSize(treeaddress);
  
  /*---------------------------------------------------------
    If the disk is unformatted, no VTOC table, so get the 
    partition information from the format routines
    DKIOCGPART
    --------------------------------------------------------*/ 
  if ( treeaddress->formatstatus != FORMATTED )
    storePartitionSize(treeaddress);
  
  /* ----------------------------------------------------------
     store the scsi_device data from the devi_driver_data member 
     ---------------------------------------------------------*/  
  treeaddress->disktype = getDiskType(kd,treeaddress,device);

  if ( treeaddress->disktype == DISK_SCSI )
    storeScsiData(kd,treeaddress,device);
  
  /*-----------------------------------------------------------
    store the device_id data from the devi_devid data member 
    ---------------------------------------------------------*/
  storeDeviceidData(kd,treeaddress,device);

  /* If there are no minor nodes , print the relevent node information
     Possibly a disk with minor nodes not created, wierd case, have noticed this in come
     storEdge arrays , so just leave the check here
  */

  /* Print a line for each minor node here*/
  for(i=0;i<sizeof(minorNodeList)/sizeof(struct minornodedata *);i++)
    {
      
      /* Skip if controller type indicates CDROM 
	 or anyother type of media other than a fixed disk */
      if (
	  ( treeaddress->dki_ctype == DKC_CDROM )||
	  ( treeaddress->dki_ctype == DKC_DSD5215 )||
	  ( treeaddress->dki_ctype == DKC_NCRFLOPPY )||
	  ( treeaddress->dki_ctype == DKC_SMSFLOPPY )||
	  ( treeaddress->dki_ctype == DKC_INTEL82072 )||
	  ( treeaddress->dki_ctype == DKC_INTEL82077 )||
	  ( treeaddress->mediatype == DK_CDROM )||
	  ( treeaddress->mediatype == DK_CDR )||
	  ( treeaddress->mediatype == DK_CDRW )||
	  ( treeaddress->mediatype == DK_DVDROM )||
	  ( treeaddress->mediatype == DK_DVDR )||
	  ( treeaddress->mediatype == DK_DVDRAM )||
	  ( treeaddress->mediatype == DK_MO_ERASABLE )||
	  ( treeaddress->mediatype == DK_MO_WRITEONCE )||
	  ( treeaddress->mediatype == DK_AS_MO )||	  
	  ( treeaddress->mediatype == DK_FLOPPY )||	  
	  ( treeaddress->mediatype == DK_ZIP )||
	  ( treeaddress->mediatype == DK_JAZ )||
	  ( treeaddress->mediatype == DK_UNKNOWN )
	  )
	continue;

      if ( device->devi_minor == NULL)	
	printf("NO_MINOR|");
      else
	{
	  /* If end of minor node list then break*/	  
	  if ( minorNodeList[i].majornumber == UNKNOWN )
	    break;

	  /* If minor node is of type CDROM skip*/	  
	  if ( !strncasecmp(minorNodeList[i].nodetype,"DDI_NT_CD",9) )
	    continue;

	  /* No need to print a unassigned size 0 or UNKNOWN Partition
	     Except in the case of backup slice, or partition representing 
	     the whole disk */	  
	  if 
	    (
	     ( minorNodeList[i].size == 0 ) ||
	     ( minorNodeList[i].size == UNKNOWN )
	     )	    
	    if (
		( minorNodeList[i].partition != BACKUP_SLICE ) &&
		( strncasecmp(minorNodeList[i].name,":c",2) ) &&
		( minorNodeList[i].partitiontype != V_BACKUP )
		)
	      continue;
	  
	  printf("MINOR_NODE|");
	  
	}

      /* Indicate a pseudo node*/
      if ( treeaddress->pseudonode == PSEUDO_NODE )
	printf("PSEUDO_DISK|");
      else
	printf("|");

      printf("%s|%d|%d|%s|%s|%s|%d|%s|%s|%u|",
	     treeaddress->name,
	     treeaddress->instance,
	     treeaddress->target,	     
	     treeaddress->devicepath,
	     treeaddress->volumeLabel,
	     treeaddress->ascii_label,
	     treeaddress->lun,
	     treeaddress->vendor,
	     treeaddress->product,
	     treeaddress->scsitarget);     
      
      /* If lun is a digit print it as a digit else print it as a char */
      printBuffer(&treeaddress->scsilun,1);
      
      /* Print the type of Disk */
      switch( treeaddress->disktype ){
      case DISK_META:
	printf("DISK_META|");
	break;
      case DISK_SCSI:
	printf("DISK_SCSI|");
	break;
      case DISK_IDE:
	printf("DISK_IDE|");
	break;
      default:
	printf("DISK_UNKNOWN|"); 
      }

      printf("%s|%s|%s|%s|%s|%s|%s|",
	     treeaddress->class,
	     treeaddress->scsivendor,
	     treeaddress->scsiproduct,
	     treeaddress->scsirevision,
	     treeaddress->scsiserial,		
	     treeaddress->deviceidtype,
	     treeaddress->deviceidhint
	     );
      
      printBuffer(treeaddress->deviceid,treeaddress->deviceidlength);
      printf("%s|",treeaddress->configuration);
      
      /* Controller data */
      printf("%s|%s|%u|",
	     treeaddress->parentnode->devicepath,
	     treeaddress->dki_cname,
	     treeaddress->dki_cnum);
      
      switch(treeaddress->dki_ctype){
      case DKC_CDROM:
	/* CD-ROM, SCSI or otherwise */
	printf("DKC_CDROM|");
	break;
      case DKC_SCSI_CCS:
	/* SCSI CCS compatible */
	printf("DKC_SCSI_CCS|");
	break;
      case DKC_MD21:
	/* Probably emulex md21 controller*/
	printf("DKC_MD21|");
	break;
      case DKC_MD:
	/* meta-disk (virtual-disk) driver */
	printf("DKC_MD|");
	break;
      case DKC_DIRECT:
	/* Intel direct attached device i.e. IDE */
	printf("DKC_DIRECT|");
	break;
      case DKC_WDC2880:
	printf("DKC_WDC2880|");
	break;
      case DKC_ACB4000:
	printf("DKC_ACB4000|");
	break;
      case DKC_PCMCIA_MEM:
	printf("DKC_PCMCIA_MEM|");
	break;
      case DKC_PCMCIA_ATA:
	printf(" DKC_PCMCIA_ATA|");
	break;
      default:
	printf("%u|",treeaddress->dki_ctype);
      }
      
      /* Print the media information*/
      /* Block size */
      if ( treeaddress->blocksize == UNKNOWN )
	printf("UNKNOWN|");
      else
	printf("%u|",treeaddress->blocksize);

      /* No of blocks */
      if ( treeaddress->nsize == UNKNOWN )
	printf("UNKNOWN|");
      else
	printf("%ul|",treeaddress->nsize);
    
      /* size (bytes)*/
      if ( treeaddress->size == UNKNOWN )
	printf("UNKNOWN|");
      else
	printf("%.0f|",treeaddress->size);   
      
      switch(treeaddress->mediatype){
      case DK_FIXED_DISK:
	/* Fixed disk SCSI or otherwise */
	printf("DK_FIXED_DISK|");
	break;
      case DK_CDROM:
      case DK_CDR:
      case DK_CDRW:	
	/* CD */
	printf("DK_CD|");
	break;
      case DK_DVDROM:
      case DK_DVDR:
      case DK_DVDRAM:	
	/*DVD */
	printf("DK_DVD|");
	break;      
      case DK_UNKNOWN:
	printf("DK_UNKNOWN|");
	break;    
      case UNKNOWN:
	printf("UNKNOWN|");
	break;
      default:
	printf("%u|",treeaddress->mediatype);
      }   

      /* Format status */
      if ( treeaddress->formatstatus == FORMATTED )
	printf("FORMATTED|");
      else
	printf("UNFORMATTED|");
      
      /* No. of data cylinders */
      if ( treeaddress->dkg_ncyl == UNKNOWN )
	printf("UNKNOWN|");
      else
	printf("%u|",treeaddress->dkg_ncyl); 
      
      /* No. of alternate cylinders */
      if ( treeaddress->dkg_acyl == UNKNOWN )
	printf("UNKNOWN|");
      else
	printf("%u|",treeaddress->dkg_acyl); 
      
      /* No. of sectors per track*/
      if ( treeaddress->dkg_nsect == UNKNOWN )
	printf("UNKNOWN|");
      else
	printf("%u|",treeaddress->dkg_nsect); 
      
      /* No. of physical cylinders */
      if ( treeaddress->dkg_pcyl == UNKNOWN )
	printf("UNKNOWN|");
      else
	printf("%u|",treeaddress->dkg_pcyl); 
      
      /* Disk rpm */
      if ( treeaddress->dkg_rpm == UNKNOWN )
	printf("UNKNOWN|");
      else
	printf("%u|",treeaddress->dkg_rpm);
           
      /* If no minor nodes , nothing else to print*/
      if ( device->devi_minor == NULL)	
	{
	  printf("\n");
	  break;
	}
      
      /* Print minor node information */
      printf("%s|%s|%ul|%ul|%s|%s|%s|",
	     minorNodeList[i].nodepath,
	     minorNodeList[i].name,
	     minorNodeList[i].majornumber,
	     minorNodeList[i].minornumber,
	     minorNodeList[i].nodetype,
	     minorNodeList[i].nodeclass,
	     minorNodeList[i].clone
	     );
      
      if ( minorNodeList[i].spectype == S_IFCHR )
	printf("CHARACTER|");
      else if ( minorNodeList[i].spectype == S_IFBLK )
	printf("BLOCK|");
      else
	printf("UNKNOWN|");	
      
      
      /*
	Print the partition information, 
	partition number, type, start sector, size 
      */
      /* Parititon number */
      if ( minorNodeList[i].partition == UNKNOWN )
	printf("UNKNOWN|");
      else
	printf("%u|",minorNodeList[i].partition);
      
      /* partition size (bytes) */
      if ( minorNodeList[i].size == UNKNOWN )
	printf("UNKNOWN|");
      else
	printf("%.0f|",minorNodeList[i].size);
      
      /* start sector */
      if ( minorNodeList[i].startsector == UNKNOWN )
	printf("UNKNOWN|");
      else
	printf("%ul|",minorNodeList[i].startsector);

      /* No of sectors */
      if (  minorNodeList[i].nsize == UNKNOWN )
	printf("UNKNOWN|");
      else
	printf("%ul|", minorNodeList[i].nsize);

      /* Sector size*/
      if ( treeaddress->v_sectorsz == UNKNOWN )
	printf("UNKNOWN|");
      else
	printf("%u|",treeaddress->v_sectorsz);
      
      /* Parititon type */
      switch(minorNodeList[i].partitiontype){
      case V_UNASSIGNED:
	printf("UNASSIGNED|");
	break;
      case V_BOOT:
	printf("BOOT|");
	break;
      case V_ROOT:
	printf("ROOT|");
	break;
      case V_SWAP:
	printf("SWAP|");
	break;
      case V_USR:
	printf("USR|");
	break;
      case V_BACKUP:
	printf("BACKUP|");
	break;
      case V_STAND:
	printf("STAND|");
	break;
      case V_VAR:
	printf("VAR|");
	break;
      case V_HOME:
	printf("HOME|");
	break;
      case V_ALTSCTR:
	printf("ALTSCTR|");
	break;
      case V_CACHE:
	printf("CACHE|");
	break;
      case UNKNOWN:
	printf("UNKNOWN|");
	break;
      default:
	printf("%u|",minorNodeList[i].partitiontype);	
      }
      
      printf("\n");
      
    }

}


/* Walk down the device tree */
void walkdown(
	      kvm_t *kd, struct devicetree *parentnode,
	      struct dev_info *pparent
	      ){
  
  struct dev_info  parent;
  char  *value;
  
  for(;
      pparent != NULL;
      /*fetch the next sibling */
      pparent = parent.devi_sibling){
    
    if (kvm_kread(kd,(uintptr_t)pparent,(void *)&parent,
		  (size_t)sizeof(parent)) == -1)
      {
	printf("error:: kdisks.c,walkdown: %d %s \n",errno,strerror(errno));      
	exit(EXIT_FAILURE);  
      }
    
    /*        
	      Store the relevent information from this node , this is used to build the
	      physical path to a disk device, or figure out the controller for a device
	      devi_parent,devi_node_name,devi_addr,
	      devi_binding_name,devi_nodeid,devi_node_class,devi_instance 
       
    */ 
    
    /* Point to the new devicetree structure to be populated for this node
       This makes me loose a devicetree structure the first time,
       ignoring that for now*/
    if ( pdevice == &devices[MAX_NODES-1] )
      {
	printf("error:: kdisks.c,Reached the MAX_NODES limit %d , increase the MAX_NODES \n",MAX_NODES);
	exit(EXIT_FAILURE);	
      }
    else
      pdevice++;
    
    /* Initialize some structure members*/
    pdevice->pseudonode == UNKNOWN;
    pdevice->size = UNKNOWN;
    pdevice->nsize = UNKNOWN;
    pdevice->blocksize = UNKNOWN;
    pdevice->mediatype = UNKNOWN;
    pdevice->v_sectorsz = UNKNOWN;
    pdevice->dkg_ncyl = UNKNOWN; 
    pdevice->dkg_acyl = UNKNOWN;
    pdevice->dkg_nsect = UNKNOWN; 
    pdevice->dkg_pcyl = UNKNOWN;
    pdevice->dkg_rpm = UNKNOWN;   

    
    /* Link to the parent device tree node*/
    pdevice->parentnode = parentnode;
    
    pdevice->memaddress = (uintptr_t)pparent;
    pdevice->parentaddress = (uintptr_t)parent.devi_parent;
    
    value = readStringBuffer(kd,(uintptr_t)parent.devi_node_name);
    sprintf(pdevice->name,"%s",value);
    
    value = readStringBuffer(kd,(uintptr_t)parent.devi_addr);
    sprintf(pdevice->address,"%s",value);
    
    value = readStringBuffer(kd,(uintptr_t)parent.devi_binding_name);
    sprintf(pdevice->bindingname,"%s",value);
    
    pdevice->instance = parent.devi_instance; 
    pdevice->nodeid = parent.devi_nodeid;     
    /* devi_info_t.devi_node_class defined for OS_5_7 ONLY*/
#ifdef OS_5_7
    pdevice->nodeclass = parent.devi_node_class;
#else
    pdevice->nodeclass = UNKNOWN;
#endif

    /* Check if a node is a pseudo node, 
       either node name is pseudo or the parent is a pseudo node*/
    if ( 
	( !strncasecmp(pdevice->name,"pseudo",6) )||
	( 
	 ( pdevice->parentnode ) &&
	 ( pdevice->parentnode->pseudonode == PSEUDO_NODE )
	 )
	)
      pdevice->pseudonode = PSEUDO_NODE;        
    
    /* If leaf node is a disk node then printdevice information*/
    if (isNodeADisk(kd,pdevice,&parent))
      printDiskData(kd,pdevice,&parent);
       
    /* Walk down this node*/
    walkdown(kd,pdevice,parent.devi_child);    	
          
  }
  
}


int main(int argc , char *argv[])
{
  ulong_t addr;
  kvm_t	*kd;
  struct nlist nl[] = {{"top_devinfo"},{""},};

  /* Store the effective user id of the process	*/
  effectiveuid = geteuid();
  
  /* revoke effective root uid privilege */
  seteuid(getuid()); 
  
  /* Erase environment*/
  eraseenv();  
  
  /* Restore the root effective userid of the process */
  seteuid(effectiveuid);
  
  /* Open an image of the kernel with the kernel symbol table */
  if ( (kd = kvm_open(NULL,NULL,NULL,O_RDONLY,NULL)) == NULL )
    {
      printf("error:: kdisks.c: Failed to open the kernel image %d %s \n",
	     errno,strerror(errno));      
      exit(EXIT_FAILURE);
    }
  
  /* revoke effective root uid privilege */
  seteuid(getuid());
    
  kvm_nlist(kd,nl);
  
  if ( kvm_kread(kd,nl[0].n_value,(void *)&addr,
		 (size_t)sizeof(ulong_t)) == -1 )
    {
      printf("error:: kdisks.c: Failed to read symbols from the kernel image %d %s \n",
	     errno,strerror(errno));      
      exit(EXIT_FAILURE);     
    }
  
  walkdown(kd,(struct devicetree*)NULL,(struct dev_info *)addr);
  
/*  printf(" The size of all nodes %ld\n",(((long)pdevice-(long)(&devices[0]))/(long)sizeof( struct devicetree ))); */

  kvm_close(kd);
  
  exit(EXIT_SUCCESS);
  
}

