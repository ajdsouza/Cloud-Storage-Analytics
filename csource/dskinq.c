#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <sys/fcntl.h>
#include <sys/types.h>
#include <sys/dkio.h>
#include <sys/vtoc.h>


void main(int argc , char **argv){

  char  logicalname[200];
  int   disk;
  struct dk_cinfo dkbuffer;
  struct vtoc     vtocbuffer;
  struct dk_allmap  allmap;
  struct dk_minfo  minfo;
  struct dk_geom dkgeom;
  uid_t	effectiveuid;
  extern  environ;
 /* Erase environment */
  environ = NULL;
  
  /* Store the effective user id of the process	*/
  effectiveuid = geteuid();

  /* revoke effective root uid privilege */
  seteuid(getuid());   

  strcpy(logicalname,argv[1]);

  /*------------------------------------------------------------
    GET THE FILE DESCRIPTOR
    ------------------------------------------------------------*/

 /* Restore the root effective userid of the process */
  seteuid(effectiveuid);
  
  if (( disk = open(logicalname,O_RDONLY|O_NDELAY)) == -1 )
    {
      /* Possibly a cdrom device if BUSY */
      if ( errno == EBUSY )
	printf("error:: device %s BUSY, Possible CDROM device \n",logicalname);
      else
	printf("error:: %d %s \n",errno,strerror(errno));

        exit(EXIT_FAILURE);
    }
  
  /* revoke effective root uid privilege */
  seteuid(getuid());  

  /*------------------------------------------------------------
    SEND A DKIOCINFO COMMAND TO THE DISK
    ------------------------------------------------------------*/

  
  if ( ioctl(disk,DKIOCINFO,(intptr_t)&dkbuffer) == -1 )
    {
      /* I/O error is device is not available */
      if ( errno == EIO )
	printf("error:: device %s not available, Possibly taken offline \n",logicalname);
      else
	printf("error:: %d %s \n",errno,strerror(errno));
      
      /* exit(EXIT_FAILURE);*/
    }
  


 /*------------------------------------------------------------
    SEND A  DKIOCGMEDIAINFO  COMMAND TO THE DISK
    ------------------------------------------------------------*/
 
  
  if ( ioctl(disk,DKIOCGMEDIAINFO,(intptr_t)&minfo) == -1 )
    {
      /* I/O error is device is not available */
      if ( errno == EIO )
	printf("error:: device %s not available, Possibly taken offline \n",logicalname);
      else
	printf("error:: %d %s \n",errno,strerror(errno));
      
      /* exit(EXIT_FAILURE);*/
    }

 

  /*------------------------------------------------------------
    SEND A  DKIOCGGEOM COMMAND TO THE DISK
    ------------------------------------------------------------*/
 
  
  if ( ioctl(disk,DKIOCGGEOM,(intptr_t)&dkgeom) == -1 )
    {
      /* I/O error is device is not available */
      if ( errno == EIO )
	printf("error:: device %s not available, Possibly taken offline \n",logicalname);
      else
	printf("error:: %d %s \n",errno,strerror(errno));

      /* exit(EXIT_FAILURE);*/
    }

  

 /*------------------------------------------------------------
    SEND A  DKIOCGAPART  COMMAND TO THE DISK
    ------------------------------------------------------------*/
 
  
  if ( ioctl(disk,DKIOCGAPART,(intptr_t)&allmap) == -1 )
    {
      /* I/O error is device is not available */
      if ( errno == EIO )
	printf("error:: device %s not available, Possibly taken offline \n",logicalname);
      else
	printf("error:: %d %s \n",errno,strerror(errno));
      
      /* exit(EXIT_FAILURE); */
    }

 
    
  /*------------------------------------------------------------
    SEND A  DKIOCGVTOC COMMAND TO THE DISK
    ------------------------------------------------------------*/

  
  if ( ioctl(disk,DKIOCGVTOC,(intptr_t)&vtocbuffer) == -1 )
    {
      /* I/O error is device is not available */
      if ( errno == EIO )
	printf("error:: device %s not available, Possibly taken offline \n",logicalname);
      else
	printf("error:: %d %s \n",errno,strerror(errno));

      /* exit(EXIT_FAILURE);*/
    }

 

}
