#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <fcntl.h>
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
#include <sys/scsi/adapters/glmreg.h>
#include <sys/scsi/adapters/glmvar.h>
#include <sys/mkdev.h>
#include <sys/stat.h>
#include <sys/dkio.h>
#include <sys/vtoc.h>

#ifndef TRUE
#define TRUE 1
#define FALSE 0
#endif

#define BUFFER_MAX 255

/* Flags for different DISK controller types*/
#define SCSI  0X01
#define IDE   0x02
#define UNKNOWN 0X00

/* List of recognized disk drivers*/
char *drivers[] = {"sd","ssd","dad","emcp","rdriver"};
char physicalPath[BUFFER_MAX];
uid_t	effectiveuid;

void walkdown(kvm_t *kd,struct dev_info *pparent,int level);
void printdeviceinfo(kvm_t *kd,struct dev_info *deviaddress,struct dev_info *pparent, int level);
void printDeviceProperties(kvm_t *kd, struct ddi_prop *propaddress,int level);
void printMinorNodeData(kvm_t *kd,struct dev_info *devi,struct ddi_minor_data *pminor_data,int level);

void printDeviceid(kvm_t *kd,struct dev_info *devi,int level);
/* Print the scsi_device data from the devi_driver_data member */
void printScsiData(kvm_t *kd,struct dev_info *dev,int level);


/* Erase the environment - for security*/
void eraseenv()
{
  
  extern  char **environ;
  while(*environ != NULL){
    *environ = NULL;
    *environ++;
  }
  
}


/* Print a byte buffer*/
void printBuffer(uchar_t *buffer, size_t size)
{
  int i;

  printf("0x");
  for (i=0;i <size;i++)
      printf("%2.2x",buffer[i]);
      
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

    if ( kvm_kread(kd,address+pdiff,pointer,sizeof(uchar_t)) == -1 ){
      
      perror("readBUffer");
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
	  
	  if ( kvm_kread(kd,address+pdiff,pointer,sizeof(char)) == -1 ){
	    
	    perror("readBUffer");
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



/* Build the physical path to a leaf device */
void buildPhysicalPath(kvm_t *kd,struct dev_info devi)
{
  
  struct dev_info parent;
  char  *value;
  
  if ((intptr_t)devi.devi_parent == (intptr_t)NULL)
    {
      sprintf(physicalPath,"/devices");
      return;
    }  
  
  if( kvm_kread(kd,(uintptr_t)devi.devi_parent,&parent,sizeof(parent)) == -1 )
    {
      perror("walkdown");
      exit(EXIT_FAILURE);
    }
  
  buildPhysicalPath(kd,parent);

  /* Print the physical path for this node as /name@address
     if not the root node, if root node then print /devices*/   
  value = readStringBuffer(kd,(u_long)devi.devi_node_name);   
  sprintf(physicalPath,"%s/%s",physicalPath,value);
  
  value = readStringBuffer(kd,(u_long)devi.devi_addr); 
  if ( strlen(value) )
    sprintf(physicalPath,"%s@%s",physicalPath,value);
  
}
  


/* Check if any of the minor devices repesents a disk */
boolean_t isMinorDeviceADisk(kvm_t *kd, struct dev_info *deviaddress,
			     struct ddi_minor_data *pminor_data)
{
    
  struct ddi_minor_data minor_data;
  char	*value;
    
  for(;pminor_data != (struct ddi_minor_data *)NULL;
      pminor_data = minor_data.next) {
    
    if ( kvm_kread(kd,(uintptr_t)pminor_data,&minor_data,
		   sizeof(struct ddi_minor_data)) == -1 ){
      
      perror("readBuffer");
      exit(EXIT_FAILURE);
      
    }
          
    /* Read the node type for the minor node*/
    value = readStringBuffer(kd,(uintptr_t)minor_data.mu.d_minor.node_type);
    
    if (
	value 
	&&
	(
	 ( !strcasecmp(value,DDI_NT_BLOCK) )||
	 ( !strcasecmp(value,DDI_NT_BLOCK_CHAN) )
	 )
	)
      return TRUE;
    

   /* If minor node is an DM_ALIAS ie points to another dev_info structure 
       check if the minor node in that dev_info structure is a disk
    */
    if ( minor_data.type == DDM_ALIAS )
      if ( isMinorDeviceADisk(kd,deviaddress,minor_data.mu.d_alias.dmp))
	return TRUE;
    

    if ((intptr_t)minor_data.dip != (intptr_t)deviaddress)
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
boolean_t isNodeADisk(kvm_t *kd,struct dev_info *deviaddress,
		      struct dev_info devi){
  
  char	*value;
  boolean_t result;
  int i;
  
  /* If there is a minor node for this dev_info structure
     Check if any minor device is a disk 
  */
  if( devi.devi_minor )
    if( isMinorDeviceADisk(kd,deviaddress,devi.devi_minor))
      return TRUE;
  
  /* If result is FALSE then check the driver list to make sure*/
  /* Check if the devi_node_name is in the list of known drivers*/
  value = readStringBuffer(kd,(uintptr_t)devi.devi_node_name);
  
  for (   i=0;
	  i<(sizeof(drivers)/sizeof(char *));
	  i++)
    {
      
      if ( !strcasecmp(value,drivers[i]) )
	return TRUE;
      
    }
  
  return FALSE;
  
}


/* Check if any of the property is of type class=scsi */
int checkPropertyClassScsi(kvm_t *kd,struct ddi_prop *propaddress){
  
  struct ddi_prop device_property;
  struct ddi_prop *pdevice_property;
  char	*strValue;
  
  /* Go thru the list of properties to glean the properties of interest*/ 
  for(  pdevice_property = propaddress;
	pdevice_property != NULL;
	pdevice_property = device_property.prop_next	
	){
    
    if ( kvm_kread(kd,(uintptr_t)pdevice_property,&device_property,
		   sizeof(struct ddi_prop)) == -1 ){
      
      perror("readBUffer");
      exit(EXIT_FAILURE);
      
    }
    
    strValue = readStringBuffer(kd,(uintptr_t)device_property.prop_name);
    if ( strcasecmp(strValue,"class") )
      continue;
    
    /* Check for the data type of the property */
    switch(device_property.prop_flags&DDI_PROP_TYPE_MASK){
    case DDI_PROP_TYPE_STRING:
      strValue = readStringBuffer(kd,(uintptr_t)device_property.prop_val);
      if ( strcasecmp(strValue,"scsi") )
	return SCSI;
      break;
    default:
      NULL;      
    }
    
  }
  
  return UNKNOWN;
}
  


/* Return the type of Controller the minor node represents, SCSI, IDE etc.*/
int getControllerType(kvm_t *kd, struct dev_info *devi,struct ddi_minor_data *pminor_data){
  
  struct ddi_minor_data minor_data;
  int type;
  char *value;
  
  /* Loop thru the chain of minor nodes*/
  for(;pminor_data != (struct ddi_minor_data *)NULL;
      pminor_data = minor_data.next) {
    
    if ( kvm_kread(kd,(uintptr_t)pminor_data,&minor_data,
		   sizeof(struct ddi_minor_data)) == -1 ){
      
      perror("readBuffer");
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
      return SCSI;
    
    /* If minor node is an DM_ALIAS ie points to another dev_info structure 
       check if the minor node in that dev_info structure is a disk
    */
    if ( minor_data.type == DDM_ALIAS )         
      if (( type =  getControllerType(kd,devi,minor_data.mu.d_alias.dmp)) != UNKNOWN )	
	return type; 
        
    /* If this is a aliased node , 
       it doesnt point to the original dev_info structure
       then dont go to the next sibbling, break from the loop*/
    if ( (intptr_t)minor_data.dip != (intptr_t)devi )
      break;
    
  }  
  
  return UNKNOWN;

}

int getDiskType(kvm_t  *kd, struct dev_info *devi)
{
  
  struct dev_info  controller;
  int  type;
  
  if ( devi == (struct dev_info *)NULL)
    return;  

    /*Check if device property returns the type of device*/    
  if (( type = checkPropertyClassScsi(kd,devi->devi_drv_prop_ptr)) != UNKNOWN )
    return type;

  if (( type = checkPropertyClassScsi(kd,devi->devi_sys_prop_ptr)) != UNKNOWN )
    return type;
 
  if (( type = checkPropertyClassScsi(kd,devi->devi_hw_prop_ptr)) != UNKNOWN )
    return type;
  

  /* Chec if the parent controller has minor nodes which indicate scsi controllers*/
  if ( devi->devi_parent == (struct dev_info *) NULL)    
    return;

  if(kvm_kread(kd,(uintptr_t)devi->devi_parent,&controller,sizeof(controller)) == -1)
    {
      perror("walkdown");
      exit(EXIT_FAILURE);
    }
  
  return getControllerType(kd,devi->devi_parent,controller.devi_minor);
  
}


void printDiskIOData(char *diskname, int level){
  
  int   disk;
  struct dk_cinfo dkbuffer;
  struct vtoc     vtocbuffer;
  /*------------------------------------------------------------
    GET THE FILE DESCRIPTOR
    ------------------------------------------------------------*/
  
  /* Restore the root effective userid of the process */
  seteuid(effectiveuid);
  
  if (( disk = open(diskname,O_RDONLY|O_NDELAY)) == -1 )    
    return;
    
  
  /* revoke effective root uid privilege */
  seteuid(getuid());  
  
  /*------------------------------------------------------------
    SEND A DKIOCINFO COMMAND TO THE DISK
    ------------------------------------------------------------*/
  /* Restore the root effective userid of the process */
  seteuid(effectiveuid);
  
  if ( ioctl(disk,DKIOCINFO,(intptr_t)&dkbuffer) == -1 )
    return;
  
  /* revoke effective root uid privilege */
  seteuid(getuid());

  printf("\n");
  /* Indent based on the level */
  printf("%*c",level*10,' ');
  
  printf("Partition :%d",dkbuffer.dki_partition);
  printf("\t Controller Number:%d",dkbuffer.dki_cnum);

  switch(dkbuffer.dki_ctype){
  case DKC_CDROM:
    /* CD-ROM, SCSI or otherwise */
    printf("\tController Type:DKC_CDROM");
    break;
  case DKC_SCSI_CCS:
    /* SCSI CCS compatible */
    printf("\tController Type :DKC_SCSI_CCS");
    break;
  case DKC_MD21:
   /* Probably emulex md21 controller*/
    printf("\tController Type:DKC_MD21");
    break;
  case DKC_MD:
    /* meta-disk (virtual-disk) driver */
    printf("\tController Type:DKC_MD");
    break;
  case DKC_DIRECT:
    /* Intel direct attached device i.e. IDE */
    printf("\tController Type:DKC_DIRECT");
    break;
  default:
    printf("\tController Type:%d",dkbuffer.dki_ctype);
  }

  printf("\tController Flag:%d",dkbuffer.dki_flags);  
  

}


void printDiskPartitions(char *diskname, int level){
  
  int   disk;  
  struct vtoc     vtocbuffer;
  int i;
  unsigned long size;

  /*------------------------------------------------------------
    GET THE FILE DESCRIPTOR
    ------------------------------------------------------------*/
  
  /* Restore the root effective userid of the process */
  seteuid(effectiveuid);
  
  if (( disk = open(diskname,O_RDONLY|O_NDELAY)) == -1 )
    return;
      
  /* revoke effective root uid privilege */
  seteuid(getuid());
  
  /*------------------------------------------------------------
    SEND A  DKIOCGVTOC COMMAND TO THE DISK
    ------------------------------------------------------------*/
  /* Restore the root effective userid of the process */
  seteuid(effectiveuid);
  
  if ( ioctl(disk,DKIOCGVTOC,(intptr_t)&vtocbuffer) == -1 )
    {
      /* I/O error is device is not available */
      if ( errno == EIO )
	printf("error:: device %s not available, Possibly taken offline \n",diskname);
      else
	printf("error:: %d %s \n",errno,strerror(errno));
      
      return;
    }

  /* revoke effective root uid privilege */
  seteuid(getuid());  

  printf("\n");
  printf("%*c",level*10,' ');
  printf("Volume Name:%s:",vtocbuffer.v_volume);
  printf("\tascii label:%s",vtocbuffer.v_asciilabel);
  printf("\n");

  for ( i=0;
	i<vtocbuffer.v_nparts;
	i++ )
    {
      /* Indent based on the level */
      printf("%*c",level*10,' ');
      
      printf("Partition %d",i);
      printf("\tType :");
      switch(vtocbuffer.v_part[i].p_tag){
      case V_UNASSIGNED:
	printf("V_UNASSIGNED");
	break;
      case V_BOOT:
	printf("V_BOOT");
	break;
      case V_ROOT:
	printf("V_ROOT");
	break;
      case V_SWAP:
	printf("V_SWAP");
	break;
      case V_USR:
	printf("V_USR");
	break;
      case V_BACKUP:
	printf("V_BACKUP");
	break;
      case V_STAND:
	printf("V_STAND");
	break;
      case V_VAR:
	printf("V_VAR");
	break;
      case V_HOME:
	printf("V_HOME");
	break;
      case V_ALTSCTR:
	printf("V_ALTSCTR");
	break;
      case V_CACHE:
	printf("V_CACHE");
	break;
      default:
	printf("%d",vtocbuffer.v_part[i].p_tag);	
      }

      size = vtocbuffer.v_part[i].p_size*vtocbuffer.v_sectorsz;
      printf("\tSize:%ld \n",size);

    }
  
}


int main(int argc , char *argv[])
{
  u_long	addr;
  kvm_t	*kd;
  struct nlist nl[] = {{"top_devinfo"},{""},};  

  /* Erase environment*/
  eraseenv();
  
  /* Store the effective user id of the process	*/
  effectiveuid = geteuid(); 

  if ( (kd = kvm_open(NULL,NULL,NULL,O_RDONLY,argv[0])) == NULL )
  /* if ( (kd = kvm_open("/dev/ksyms","/dev/kmem",NULL,O_RDONLY,argv[0])) == NULL )*/
    {
      perror(argv[0]);
      exit(EXIT_FAILURE);
    }
  
  kvm_nlist(kd,nl);  
  
  if ( kvm_kread(kd,nl[0].n_value,&addr,sizeof(addr)) == -1 )
    {
      perror(argv[0]);
      exit(EXIT_FAILURE);
    }
  
  walkdown(kd,(struct dev_info *)addr,0);
  
  kvm_close(kd);
  
  exit(EXIT_SUCCESS);
  
}


void walkdown(kvm_t *kd, struct dev_info *pparent, int level){
  
  struct dev_info  parent;
  
  while(pparent != NULL){
    
    if(kvm_kread(kd,(u_long)pparent,&parent,sizeof(parent)) == -1)
      {
	perror("walkdown");
	exit(EXIT_FAILURE);
      }
    
    printdeviceinfo(kd,pparent,&parent,level);
    
    walkdown(kd,parent.devi_child,level+1);
    
    /*fetch the next sibling */
    pparent = parent.devi_sibling;	
    
  }
  
}


void printdeviceinfo(kvm_t *kd,struct dev_info *deviaddress,
		     struct dev_info *pparent,int level){

  char *value;
  
  /* Skip if not cannonical form 2 implies , not successfully probed and attached
     means devi_info.devi_ops is NULL
  */
  if ( !DDI_CF2(pparent) )
    return;
  
  printf("%*c",level*10,' ');
  
  if ( isNodeADisk(kd,deviaddress,*pparent) )
    printf("DISK\t");
  
  value = readStringBuffer(kd,(u_long)pparent->devi_binding_name);
  printf("Device_name:%s",value);
  printf("\tInstance:%d",pparent->devi_instance);
  
  value = readStringBuffer(kd,(u_long)pparent->devi_node_name);
  printf("\tNode name:%s",value);
  
  value = readStringBuffer(kd,(u_long)pparent->devi_addr);
  printf("\tAddress:%s",value); 
  
  switch(pparent->devi_node_class){
  case DDI_NC_PROM:
    printf("\tNode class: DDI_NC_PROM");
    break;
  case DDI_NC_PSEUDO:
    printf("\tNode class:DDI_NC_PSEUDO");
    break;
  default:
    printf("\tNode class:%d",pparent->devi_node_class);
  }
  
  printf("\n");
  
  /* Print the device properties */
  printf("Properties\n");
  printDeviceProperties(kd,pparent->devi_drv_prop_ptr,level);
  printf("System Properties\n");
  printDeviceProperties(kd,pparent->devi_sys_prop_ptr,level);
  printf("HW Properties\n");
  printDeviceProperties(kd,pparent->devi_hw_prop_ptr,level);
  
  /* Print the chain of minor node data */
  buildPhysicalPath(kd,*pparent);
  printMinorNodeData(kd,deviaddress,pparent->devi_minor,level);
  
  /* Print the device id for this node */
  printDeviceid(kd,pparent,level);
  printf("\n");
  
  /* Print scsi data for the device*/  
  if ( getDiskType(kd,pparent) == SCSI )
    printScsiData(kd,pparent,level);
    
  printf("\n");

}



/* Read and print the relevent disk device properties */
void printDeviceProperties(kvm_t *kd,struct ddi_prop *propaddress,int level){

  struct ddi_prop device_property;
  struct ddi_prop *pdevice_property;
  char   propType[BUFFER_MAX];
  char	*strValue;
  uchar_t *byteValue;
  int	*intValue;
  boolean_t   boolValue;
  int 	i;
  
  /* Go thru the list of properties to glean the properties of interest*/ 
  for(  pdevice_property = propaddress;
	pdevice_property != NULL;
	pdevice_property = device_property.prop_next	
	){
    
    if ( kvm_kread(kd,(uintptr_t)pdevice_property,&device_property,
		   sizeof(struct ddi_prop)) == -1 ){
      
      perror("readBUffer");
      exit(EXIT_FAILURE);
      
    }
    
    /* Indent based on the level */
    printf("%*c",level*10,' ');    
    
    strValue = readStringBuffer(kd,(uintptr_t)device_property.prop_name);
    printf("%s:",strValue);
    
    /* Check for the data type of the property */
    switch(device_property.prop_flags&DDI_PROP_TYPE_MASK){
      
    case DDI_PROP_TYPE_INT:
      intValue = (int *)readBuffer(kd,
				   (uintptr_t)device_property.prop_val,
				   device_property.prop_len);         
      for(i=0;i<(device_property.prop_len/sizeof(int));i++) 
	printf("%d",intValue[i]);
      break;
    case DDI_PROP_TYPE_STRING:
      strValue = readStringBuffer(kd,(uintptr_t)device_property.prop_val);
      printf("%s",strValue);      
      break;
    case DDI_PROP_TYPE_BYTE:
    case DDI_PROP_TYPE_COMPOSITE:
      byteValue = readBuffer(kd,
			     (uintptr_t)device_property.prop_val,
			     device_property.prop_len);  
      printBuffer(byteValue,device_property.prop_len);   
      break;
    default:
      /* If length 0 then boolean and value true*/
      if ( device_property.prop_len ==  0)
	printf("TRUE");	
      else
	{	  
	  byteValue = readBuffer(kd,
				 (uintptr_t)device_property.prop_val,
				 device_property.prop_len);
	  printBuffer(byteValue,device_property.prop_len);
	}
    }            
    
    printf("\n");
    
  }
  
  
}


/* Read and print the minor node data list*/
void printMinorNodeData(kvm_t *kd,struct dev_info *devi, 
			struct ddi_minor_data *pminor_data,int level){
  
  char *value;
  struct ddi_minor_data minor_data;
  struct dev_info   device;
  int i = 0; 
  char  diskName[BUFFER_MAX];  

  if ((intptr_t) devi == (intptr_t)NULL )
    return;

  if ( kvm_kread(kd,(uintptr_t)devi,&device,
		 sizeof(struct dev_info)) == -1 ){
    
    perror("readBUffer");
    exit(EXIT_FAILURE);
    
  } 
  
  /* Print the details for each minor node for this disk node*/
  for(
      i=0;
      pminor_data != ( struct ddi_minor_data *)NULL;
      i++,pminor_data = minor_data.next
      ) {
    
    if ( kvm_kread(kd,(uintptr_t)pminor_data,&minor_data,
		   sizeof(struct ddi_minor_data)) == -1 ){
      
      perror("readBUffer");
      exit(EXIT_FAILURE);
      
    }
             
    /* Indent based on the level */
    printf("%*c",level*10,' ');
    
    printf("Minor Type :");
    switch(minor_data.type){
    case DDM_MINOR:
      printf("DDM_MINOR");	
      break;
    case DDM_ALIAS:
      printf("DDM_ALIAS");
      break;
    case DDM_DEFAULT:
      printf("DDM_DEFAULT");
      break;
    case DDM_INTERNAL_PATH:
      printf("DDM_INTERNAL_PATH");
      break;
    default:
      printf("%d",minor_data.type);
    }       
    
    /* Device type or node type */
    value = readStringBuffer(kd,(uintptr_t)minor_data.mu.d_minor.node_type);    
    
    /* If the minor node is not a disk device type then do not store the node
       , The exception is pseudo devices where value may be NULL or of type DDI_PSEUDO*/
    printf("\tNode Type:");
    if ( !strcasecmp(value,DDI_NT_BLOCK) )
      printf("DDI_NT_BLOCK");
    else if ( !strcasecmp(value,DDI_NT_BLOCK_CHAN) )
      printf("DDI_NT_BLOCK_CHAN");
    else if ( !strcasecmp(value,DDI_NT_BLOCK_WWN) )
      printf("DDI_NT_BLOCK_WWN");
    else if ( !strcasecmp(value,DDI_PSEUDO) )
      printf("DDI_PSEUDO");
    else if ( !strcasecmp(value,DDI_NT_NEXUS) )
      printf("DDI_NT_NEXUS");
    else if ( !strcasecmp(value,DDI_NT_SCSI_NEXUS) )
      printf("DDI_NT_SCSI_NEXUS");
    else if ( !strcasecmp(value,DDI_NT_SBD_ATTACHMENT_POINT) )
      printf("DDI_NT_SBD_ATTACHMENT_POINT");
    else if ( !strcasecmp(value,DDI_NT_FC_ATTACHMENT_POINT) )
      printf("DDI_NT_FC_ATTACHMENT_POINT");
    else if ( !strcasecmp(value,DDI_NT_ATTACHMENT_POINT) )
      printf("DDI_NT_ATTACHMENT_POINT");
    else if ( !strcasecmp(value,DDI_NT_SCSI_ATTACHMENT_POINT) )
      printf("DDI_NT_SCSI_ATTACHMENT_POINT");
    else if ( !strcasecmp(value,DDI_NT_PCI_ATTACHMENT_POINT) )
      printf("DDI_NT_PCI_ATTACHMENT_POINT");
    else if ( !strcasecmp(value,DDI_NT_BLOCK_FABRIC) )
      printf("DDI_NT_BLOCK_FABRIC");
    else
      printf(value);
    	    
    /* Device node name */
    value = readStringBuffer(kd,(uintptr_t)minor_data.mu.d_minor.name);    
    sprintf(diskName,"%s:%s",physicalPath,value);
    printf("\tPhysical Path:%s",diskName);

    /* Major number and minor number */
    printf("\tMajor/Minor:%ld/%ld",major(minor_data.mu.d_minor.dev),
	   minor(minor_data.mu.d_minor.dev));
    
    /* Flag to indicate, block or character */
    if ( minor_data.mu.d_minor.spec_type == S_IFCHR )
      printf("\tType:CHAR");
    else
      printf("\tType:BLOCK");
             
  /* Store the node class, may be useful in cluster cases*/
  switch(minor_data.mu.d_minor.mdclass & DEVCLASS_MASK)
    {
    case GLOBAL_DEV:
      printf("\tDevice class:GLOBAL_DEV");
      break;
    case NODEBOUND_DEV:
      printf("\tDevice class:NODEBOUND_DEV");
      break;
    case NODESPECIFIC_DEV:
      printf("\tDevice class:NODESPECIFIC_DEV");
      break;
    case ENUMERATED_DEV:
      printf("\tDevice class:ENUMERATED_DEV");
      break;
    default:
      printf("\tDevice class:%d",minor_data.mu.d_minor.mdclass & DEVCLASS_MASK);	
    }
  
  /* Store flag to indicate if device is a clone*/
  if ( minor_data.mu.d_minor.mdclass & CLONE_DEV )
    printf("\tClone?:CLONE_DEV");

  if ( (isNodeADisk(kd,devi,device))&& ( minor_data.mu.d_minor.spec_type == S_IFCHR ) )
    {      
      printDiskIOData(diskName,level+1);
      printDiskPartitions(diskName,level+1);
    }
  
  printf("\n");

   /* If minor node is an DM_ALIAS ie. points into another ddi_minor_data structure
       Print data from this aliased node and skip to print the next sibbling
   */
  if ( minor_data.type == DDM_ALIAS )
    printMinorNodeData(kd,devi,minor_data.mu.d_alias.dmp,level+1);      
  
  /* 
     If called as an alias node then dont go thru the sibblings of 
     node
     Else loop thru the sibblings
  */
  if ( (intptr_t)minor_data.dip != (intptr_t)devi )
    break;
      
  }
  
}





/* Read and print the device id structure */
void printDeviceid(kvm_t *kd,struct dev_info *devi,int level){

  struct impl_devid 	device_id;
  caddr_t       value;
  ushort_t  	intValue;
  int		i;
  ptrdiff_t     pdiff;
  uchar_t       *devid;
  
  if ( devi->devi_devid == (ddi_devid_t) NULL)
    return;
  
  if ( kvm_kread(kd,(intptr_t)devi->devi_devid,&device_id,(size_t)sizeof(struct impl_devid)) == -1 ){
    
    perror("readBUffer");
    exit(EXIT_FAILURE);
    
  }
  
  /* Indent based on the level */
  printf("%*c",level*10,' ');
    
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
    printf("Type: DEVID_NONE");
    break;
  case  DEVID_SCSI3_WWN:
    printf("Type: DEVID_SCSI3_WWN");
    break;
  case  DEVID_SCSI_SERIAL:
    printf("Type: DEVID_SCSI_SERIAL");
    break;
  case DEVID_FAB:
    printf("Type: DEVID_FAB");
    break;
  case DEVID_ENCAP:
    printf("Type: DEVID_ENCAP");
    break;
  default:
    printf("Type: %d",intValue);
  }
  
  value = readStringFromBuffer(device_id.did_driver,(size_t)DEVID_HINT_SIZE);
  printf("\tHint:%s",value);

  intValue = DEVID_GETLEN(&device_id);
  printf("\tLength: %d\t",intValue);
  
  /* Read the device id , of length inValue at address  of device_id + offset as shown below*/
  pdiff =  (intptr_t)devi->devi_devid+(intptr_t)&device_id.did_id - (intptr_t)&device_id;
  if ( intValue )
    devid = readBuffer(kd,pdiff,intValue);
  
  printf("\tDevice id:");
  printBuffer(devid,intValue);
     
}


/* Print the scsi_device data from the devi_driver_data member */
void printScsiData(kvm_t *kd,struct dev_info *dev,int level)
{
  
  struct scsi_device scsidevice;
  struct scsi_inquiry scsiinquiry;
  char  *value;
  
  if ( dev->devi_driver_data == (caddr_t) NULL)
    return;
  
  if ( kvm_kread(kd,(uintptr_t)dev->devi_driver_data,&scsidevice,(size_t)sizeof(struct scsi_device)) == -1 ){
    
    perror("readBuffer");
    exit(EXIT_FAILURE);
    
  }

  /* Indent based on the level */
  printf("%*c",level*10,' ');
  
  printf("scsi target : %d ",scsidevice.sd_address.a_target);
  printBuffer(&scsidevice.sd_address.a_lun,1);
  
  if ( !scsidevice.sd_inq )
    return;
  
  if ( kvm_kread(kd,(uintptr_t)scsidevice.sd_inq,&scsiinquiry,(size_t)sizeof(struct scsi_inquiry)) == -1 ){
    
    perror("readBUffer");
    exit(EXIT_FAILURE);
    
  }

  value = readStringFromBuffer(scsiinquiry.inq_vid,sizeof(scsiinquiry.inq_vid));
  printf("\tscsi Vendor:%s",value);
  
  value = readStringFromBuffer(scsiinquiry.inq_pid,sizeof(scsiinquiry.inq_pid));
  printf("\tscsi Product:%s",value);
  
  value = readStringFromBuffer(scsiinquiry.inq_revision,sizeof(scsiinquiry.inq_revision));
  printf("\tscsi Version:%s",value);
  
  value = readStringFromBuffer(scsiinquiry.inq_serial,sizeof(scsiinquiry.inq_serial));
  printf("\tscsi Serial#:%s",value);

}

