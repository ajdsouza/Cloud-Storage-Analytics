/*
*
* Copyright  (c) 2001,2002  Oracle Corporation All rights reserved
*
*  $Id: runcmd.c,v 1.23 2003/01/02 21:44:58 vswamida Exp $ 
*
*
* NAME  
*	 runcmd.c
*
* DESC 
*	execute the storage stormon executables requiring suid privilege 
*       - clean environment
*       - right privileges
*
* FUNCTIONS
*
*
* NOTES
*
*
* MODIFIED	(MM/DD/YY)
* ajdsouza	10/01/02 - Created
*
*/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include "stormon.h"

#ifdef D_HPUX
/* HPUX doesn't ahve seteuid/seteguid */
#define seteuid(x) setresuid(-1,(x),-1)
#define setegid(x) setresgid(-1,(x),-1)
#endif

#define BUFFER_SIZE	256		/* Max size of command line arguments */

int main (int argc , char **argv)
{
  
  FILE 	*fp; 
  int  	size;
  int	i;
  char	**args;

  /* cmd to path map */
  struct cmdpath {
    char *cmd;
    char *path;
  };
  
  /* List of commands available to be executed */
  struct cmdpath patharray[] = {
    {"scsiinq","/usr/local/git/oem/storage/scsiinq"},
#ifdef D_SOLARIS
    {"kdisks64","/usr/local/git/oem/storage/kdisks64"},
    {"kdisks","/usr/local/git/oem/storage/kdisks"},
    {"syminfo","/usr/local/git/oem/storage/syminfo"},
    {"run_vxprint","/usr/local/git/oem/storage/run_vxprint"}
#elif D_HPUX
    {"syminfo","/usr/local/git/oem/storage/syminfo"}
#elif D_LINUX
    {"run_raw","/usr/local/git/oem/storage/run_raw"},
    {"run_sfdisk","/usr/local/git/oem/storage/run_sfdisk"},
    {"run_pvdisplay","/usr/local/git/oem/storage/run_pvdisplay"},
    {"mdinfo","/usr/local/git/oem/storage/mdinfo"},
    {"ideinfo","/usr/local/git/oem/storage/ideinfo"},
    {"idainfo","/usr/local/git/oem/storage/idainfo"},
    {"ccissinfo","/usr/local/git/oem/storage/ccissinfo"}
#endif
  };
  
  
  uid_t	effectiveuid;  /* Effective uid of the process */

  /* ---------------------------------------------------------------
     Do the secure stuff 
     ---------------------------------------------------------------*/

  /* Erase the environment */
  eraseenv();

  /* 
   * Commented 10/30/02
   * ld ignores LD_LIBRARY_PATH for setuid programs.
   * All libraries for setuid programs must be in a trusted directory
   * such as /usr/lib.
   * The crle command can be used to modify the trusted directory list.
   * See 'man ld.so.1' for more information

   if ( putenv("LD_LIBRARY_PATH=/usr/local/git/oem/storage/emc") != 0 )
   {
   printf("error::Failed to set the LD_LIBRARY_PATH in runcmd.\n");
   exit(EXIT_FAILURE);      
   }
   */

  /* Store the effective user id of the process	*/
  effectiveuid = geteuid();
  
  /* revoke effective root uid privilege */
  seteuid(getuid());
  
  /* At least one arguments needs to be passed */
  if ( argc < 2 )
    {
      printf("error::Usage : runcmd <args>\n");
      exit(EXIT_FAILURE);
    }
  
  /* -------------------------------------------------------------------
     Initialize the array of arguments to be passed to exec 
  ---------------------------------------------------------------------*/
  args = NULL;
  
  args = (char **)calloc(argc,sizeof(char *));
  if ( !args )
    {
      printf("error::runcmd.c: Failed to allocated buffer to arg \n");
      exit(EXIT_FAILURE);
    }
  
  /* Copy each of the input arguments with null termination */
  for (i=0; i<argc-1; i++)		  		    
    if ( checkandcopy(&args[i],argv[i+1],BUFFER_SIZE) != EXIT_SUCCESS )
      {
	printf("error::runcmd.c: Arg > than buffer size %d \n",BUFFER_SIZE);
	exit(EXIT_FAILURE);
      }
  
  /* Null terminate the array of args to exec */
  args[argc] = NULL;
  

  /* -----------------------------------------------------------------------
     Validate the cmd passed , to be in the list of supported commands 
  -------------------------------------------------------------------------*/
  size = (sizeof(patharray)/(sizeof(struct cmdpath)));
    
  /* Check is the command to be executed is in the list */
  for(i=0; i<size;i++)			
    if ( !strcasecmp(args[0],patharray[i].cmd ) )
      break;			    
  
  if ( i == size )
    {				  
      printf("error::runcmd.c : Invalid argument %s \n",args[0]);
      exit(EXIT_FAILURE);
    }
  

  /* Check if path to be executed exists and can be accessed */
  fp = fopen(patharray[i].path,"rb");
  
  if ( fp )    
    fclose(fp);
  else
    {
      printf("error::runcmd.c : %s cannot be accessed \n",patharray[i].path);
      exit(EXIT_FAILURE);    
    }
  
  
  /* -----------------------------------------------------------------------
     Execute the command with the agruments passed in 
     -------------------------------------------------------------------------*/
  
  /* Restore the root effective userid of the process */
  seteuid(effectiveuid);
  
  if ( execv(patharray[i].path,args) == -1 )
    {
      /* revoke effective root uid privilege */
      seteuid(getuid());
      printf("error::executing %s - %d %s \n",patharray[i].path,errno,strerror(errno));
      exit(EXIT_FAILURE);
    }
  
  /* revoke effective root uid privilege */
  seteuid(getuid());	
  exit(EXIT_SUCCESS);
  
}


