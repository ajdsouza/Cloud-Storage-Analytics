/*
*
* Copyright  (c) 2001,2002  Oracle Corporation All rights reserved
*
*  $Id: diskinq.c,v 1.9 2002/05/03 17:08:12 ajdsouza Exp $ 
*
*  $Log: diskinq.c,v $
*  Revision 1.9  2002/05/03 17:08:12  ajdsouza
*  Check size before copying command line buffers
*  Validate command line arguments
*
*  Revision 1.8  2002/04/30 05:51:25  ajdsouza
*  Erase environment before execution
*
*  Revision 1.7  2002/04/24 02:38:17  ajdsouza
*  Added bounds check for second argument
*
*  Revision 1.6  2002/04/23 07:00:08  ajdsouza
*  Added Exit functions
*
*  Revision 1.5  2002/04/19 22:34:40  ajdsouza
*  Return the SCSI inquiry information for a disk to STDOUT,
*  Use the kstat library
*
*
*
*
* NAME  
*	 run_diskinq.c
*
* DESC 
* Get the scsi inq information for a diskdevice from the kstat structure
*
*
* FUNCTIONS
*
*
* NOTES
*
*
* MODIFIED	(MM/DD/YY)
* ajdsouza	04/17/02 - Std comments
* ajdsouza	10/01/01 - Created
*
*/

#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>
#include <kstat.h>
#include <errno.h>
#include "stormon.h"

#define BUFFER_SIZE	256		/* Max size of command line arguments */


	void readValue(kstat_t *kst , char *name);
	
	kstat_named_t *knp;
	
	main(int argc , char **argv)
	{
	
		kstat_ctl_t *kc;
		kstat_t *sderror;
	
		char *module;
		char *arg;
		int instance = -1;

		extern  environ;

		/* Erase environment */
		environ = NULL;
	
		if ( argc < 3 )
		{
			fprintf(stderr,"Usage : diskinq <instance> <driver>\n");
			exit(EXIT_FAILURE);
		}
	
		instance = strtol(argv[1],NULL,10);
	
		if (
			( ( instance == 0 ) && (errno == EINVAL ) ) ||
			( errno == ERANGE )
		)
		{
			fprintf(stderr,"diskinq : error reading instance \n");
			exit(EXIT_FAILURE);
		}
	
		/*  Module has the format driver||serr  so join argv[2] to err */
		if ( checkandcopy(&arg,argv[2],BUFFER_SIZE) != EXIT_SUCCESS )
		{
			fprintf(stderr,"diskinq.c: Argument larger than buffersize %d \n",BUFFER_SIZE);
			exit(EXIT_FAILURE);
		}

		module = (char *)calloc(BUFFER_SIZE+5,sizeof(char));
		if ( !module )
		{
			fprintf(stderr,"diskinq.c: Failed to allocated buffer to module \n");
			exit(EXIT_FAILURE);
		}

		snprintf(module,BUFFER_SIZE+5,"%serr",arg);

		free(arg);


		/* Initialize the kstat control structure */
		if ((kc = kstat_open()) == NULL)
		{ 
			perror("kstat_open failed"); 
			exit(EXIT_FAILURE);
	        }
	
		/* Traverse the kstat structure for module=sderr and given instance */
		if ( (sderror = kstat_lookup(kc, module, instance, NULL)) == NULL)
		{
			perror("kstat_lookup failed");
			exit(EXIT_FAILURE);
		}
	                            
		/* Read data from the kernel for this kstat */
		if ( kstat_read(kc, sderror, NULL) == -1 )
		{
			perror("kstat_read failed");
			exit(EXIT_FAILURE);
		}
	
		/* checked if this kstat has named data records ,sderr is a named data record kstat */
	        if ( sderror->ks_type != KSTAT_TYPE_NAMED )
	        {
			perror("diskinq.c , Wrong kstat type ");
			exit(EXIT_FAILURE);
	        }

		/* Read each of the value for each of these names */
		readValue(sderror,"Vendor"); 
		readValue(sderror,"Product"); 
		readValue(sderror,"Revision"); 
		readValue(sderror,"Serial No"); 
		readValue(sderror,"Size"); 
		readValue(sderror,"Soft Errors"); 
		readValue(sderror,"Transport Errors"); 
		readValue(sderror,"Device Not Ready"); 
		readValue(sderror,"Hard Errors"); 
		readValue(sderror,"Media Error"); 
		readValue(sderror,"Illegal Request"); 
		readValue(sderror,"No Device"); 
		readValue(sderror,"Predictive Failure Analysis"); 
	
		free(module);

		exit(EXIT_SUCCESS);
        }
	
	
	void readValue(kstat_t *kst , char *name)
	{
	
	/* Get data section from the kstat->ks__data with the specified name  */
	
	        if ( ( knp = (kstat_named_t*)kstat_data_lookup(kst, name)) == NULL )
		{
			perror("kstat_data_lookup failed");
			exit(EXIT_FAILURE);
		}
	
	        printf("%s:%s:%s	",kst->ks_module,kst->ks_name,name);
	
	        switch(knp->data_type)
		{
			case KSTAT_DATA_CHAR:
				printf("%.16s",knp->value.c);
				break;
			case KSTAT_DATA_INT32:
				printf("%ld",knp->value.i32);
				break;
			case KSTAT_DATA_UINT32:
				printf("%lu",knp->value.ui32);
				break;
			case KSTAT_DATA_INT64:
				printf("%lld",knp->value.i64);
				break;
			case KSTAT_DATA_UINT64:
				printf("%llu",knp->value.ui64);
				break;
		}
	
	       printf("\n");
	}
