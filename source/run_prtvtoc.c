/*
*
* Copyright  (c) 2001,2002  Oracle Corporation All rights reserved
*
*  $Id: run_prtvtoc.c,v 1.13 2003/03/11 01:25:58 ajdsouza Exp $ 
*
*  $Log: run_prtvtoc.c,v $
*  Revision 1.13  2003/03/11 01:25:58  ajdsouza
*  *** empty log message ***
*
*  Revision 1.12  2002/06/25 23:32:10  ajdsouza
*  *** empty log message ***
*
*  Revision 1.11  2002/06/25 21:49:15  ajdsouza
*  *** empty log message ***
*
*  Revision 1.10  2002/06/25 17:19:29  ajdsouza
*  *** empty log message ***
*
*  Revision 1.9  2002/06/25 17:10:26  ajdsouza
*  *** empty log message ***
*
*  Revision 1.8  2002/06/25 16:49:56  ajdsouza
*  *** empty log message ***
*
*  Revision 1.7  2002/06/12 17:42:30  ajdsouza
*
*  Revoke SUID after checking for the file
*
*  Revision 1.6  2002/05/03 17:08:12  ajdsouza
*  Check size before copying command line buffers
*  Validate command line arguments
*
*  Revision 1.5  2002/04/24 23:49:52  ajdsouza
*  Erase environ
*  Restore effective to real userid and revert to effective root userid before command
*
*  Revision 1.4  2002/04/23 07:00:08  ajdsouza
*  Added Exit functions
*
*  Revision 1.3  2002/04/22 22:54:20  ajdsouza
*  Delcarations at the bgining , switched to the gcc compiler
*
*  Revision 1.2  2002/04/19 22:26:54  ajdsouza
*  path for prtvtoc hard coded at compile time
*
*
*
*
* NAME  
*	 run_prtvtoc.c
*
* DESC 
*	execute prtvtoc -h <logicalname> to List the partitions for a disk
*	The binary requires suid to be set to execute prtvtoc
*
*
* FUNCTIONS
*
*
* NOTES
*
*
* MODIFIED	(MM/DD/YY)
* ajdsouza	04/17/02 - prtvtoc Path compiled hadcoded
* ajdsouza	10/01/01 - Created
*
*/


#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include "stormon.h"
#include <errno.h>

#define BUFFER_SIZE	256		/* Max size of command line arguments */


	main (int argc , char **argv)
	{
		char 	*path;
		FILE 	*fp;
		int  	size;
		int 	i;
		char	**args;

		char 	*patharray[] = {
					"/etc/prtvtoc",
					"/usr/sbin/prtvtoc",
					"/bin/prtvtoc",
					"/usr/bin/prtvtoc",
					"/usr/local/bin/prtvtoc",
					"/usr/local/git/bin/prtvtoc"
					};

		uid_t	effectiveuid;

		extern  environ;

		/* Erase environment */
		environ = NULL;

		/* Store the effective user id of the process	*/
		effectiveuid = geteuid();

		if ( argc <= 1 )
		{		  
		  printf("error::Usage : run_prtvtoc <logicalname>\n");
		  exit(EXIT_FAILURE);
		}


		size = (sizeof(patharray)/(sizeof(char *)));

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
		  printf("error::run_prtvtoc.c : prtvtoc not found\n");
		  exit(EXIT_FAILURE);
		}


		args = (char **)calloc(4,sizeof(char *));
		if ( !args )
		{		  
		  printf("error::run_prtvtoc.c: Failed to allocate buffer to args \n");
		  exit(EXIT_FAILURE);
		}

		args[0] =  (char *)calloc(8,sizeof(char));
		if ( !args[0] )
		{		  
		  printf("error::run_prtvtoc.c: Failed to allocated buffer to args[0] \n");
		  exit(EXIT_FAILURE);
		}
		strcpy(args[0],"prtvtoc");

		args[1] =  (char *)calloc(3,sizeof(char));
		if ( !args[1] )
		{		  
		  printf("error::run_prtvtoc.c: Failed to allocated buffer to args[1] \n");
		  exit(EXIT_FAILURE);
		}
		strcpy(args[1],"-h");

		/* Copy the input arguments with null termination */
		if ( checkandcopy(&args[2],argv[1],BUFFER_SIZE) != EXIT_SUCCESS )
		{		  
		  printf("error::run_prtvtoc.c: Argument larger than buffersize %d \n",BUFFER_SIZE);
		  exit(EXIT_FAILURE);
		}

		/* Validate the input, only disk name allowed no flags, raise error if arg begins with - */
		if ( args[2][0] == '-' ){		  
		  printf("error::run_prtvtoc.c: Invalid argument %s \n",args[2]);
		  exit(EXIT_FAILURE);
		}

		args[3] = NULL;

		/* Restore the root effective userid of the process */
		seteuid(effectiveuid);

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

