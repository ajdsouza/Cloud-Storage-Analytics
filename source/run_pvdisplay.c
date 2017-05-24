/*
*
* Copyright  (c) 2001,2002  Oracle Corporation All rights reserved
*
*  $Id: run_pvdisplay.c,v 1.3 2003/03/11 01:25:58 ajdsouza Exp $ 
*
*
* NAME  
*	 run_pvdisplay.c
*
* DESC 
*	execute pvdisplay to list the LVM volumes on a host
*	The binary requires suid to be set to execute pvdisplay
*
*
* FUNCTIONS
*
*
* NOTES
*
*
* MODIFIED	(MM/DD/YY)
* vswamida	10/20/02 - Created
*
*/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include "stormon.h"
#include <errno.h>

#define BUFFER_SIZE	256		/* Max size of command line arguments */

	int main (int argc , char **argv)
	{

		char 	*path = NULL;
		FILE 	*fp;
		int  	size;
		int	i,j;
		char	**args;

		char 	*patharray[] = {
					"/sbin/pvdisplay",
					"/usr/sbin/pvdisplay"
					};

		char	*cmdoptions[] = {
						"-v"
					};

		uid_t	effectiveuid;

		/* Erase environment */
		eraseenv();

		/* Store the effective user id of the process	*/
		effectiveuid = geteuid();
		
		/* revoke effective root uid privilege */
        	seteuid(getuid());

		if ( argc < 2 )
		{
		  printf("error::Usage : run_pvdisplay <args>\n");
		  exit(EXIT_FAILURE);
		}


		size = (sizeof(patharray)/(sizeof(char *)));

		/* Restore the root effective userid of the process */
		seteuid(effectiveuid);

		for(i=0; i<size;i++)
		{
			/* Check if file exists and can be accessed */
			fp = fopen(patharray[i],"rb");

			if ( fp )
			{
				fclose(fp);

				path = patharray[i]; 
				break;
			}
		
		}

		/* revoke effective root uid privilege */
        	seteuid(getuid());

		if (!path )
		{
		  printf("error::run_pvdisplay.c :  pvdisplay not found \n");
		  exit(EXIT_FAILURE);
		}


		args = NULL;

		args = (char **)calloc(argc,sizeof(char *));
		if ( !args )
		{
		  printf("error::run_pvdisplay.c: Failed to allocated buffer to arg \n");
		  exit(EXIT_FAILURE);
		}

		args[0] =  (char *)calloc(strlen("pvdisplay") + 1,sizeof(char));
		if ( !args[0] )
		{
		  printf("error::run_pvdisplay.c: Failed to allocated buffer to args[0] \n");
		  exit(EXIT_FAILURE);
		}

		strcpy(args[0],"pvdisplay");

   		for (i=1; i<argc; i++)
   		{

			/* Copy the input arguments with null termination */
			if ( checkandcopy(&args[i],argv[i],BUFFER_SIZE) != EXIT_SUCCESS )
			{
			  printf("error::run_pvdisplay.c: Arg > than buffer size %d \n",BUFFER_SIZE);
			  exit(EXIT_FAILURE);
			}

			/* Validate input with cmd options */
			size = (sizeof(cmdoptions)/(sizeof(char *)));

			for(j=0; j<size;j++)
			{

				/* If argument is diskgroup or Volume name and not a flag skip check*/
				if ( args[i][0] != '-' )
					break;

				/* invalid flag if flag > 2  */
				if ( strlen(args[i]) != 2)  
				{				 
				  printf("error::run_pvdisplay.c : Invalid arg length %s\n",args[i]);
				  exit(EXIT_FAILURE);
				}

				if (! strcmp(cmdoptions[j],args[i]) )
					break;

				if ( j == size-1 )
				{				  
				  printf("error::run_pvdisplay.c : Invalid argument %s \n",args[i]);
				  exit(EXIT_FAILURE);
				}

			}


		}
		

		args[argc] = NULL;

		/* Restore the root effective userid of the process */
		/*		seteuid(effectiveuid);*/
		
		/* Restore the root effective userid of the process */
		setuid(effectiveuid);

		if ( execv(path,args) == -1)
		  {
		  /* revoke effective root uid privilege */
		  seteuid(getuid());
		  
		  printf("error::%d %s \n",errno,strerror(errno));
		  exit(EXIT_FAILURE);
		}
		
		/* revoke effective root uid privilege */
        	seteuid(getuid());		
		exit(EXIT_SUCCESS);

	}

