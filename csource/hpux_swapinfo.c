/*
*
* Copyright  (c) 2001,2002  Oracle Corporation All rights reserved
*
*  $Id: hpux_swapinfo.c,v 1.2 2003/01/09 18:07:05 vswamida Exp $ 
*
*
* NAME  
*	 hpux_swapinfo.c
*
* DESC 
* 	Get the swap devices and their sizes
*	The hp swapinfo command does not allow non-root access by default
*
* FUNCTIONS
*
*
* NOTES
*
*
* MODIFIED	(MM/DD/YY)
* vswamida	01/09/03 - Created
*
*/


#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <errno.h>
#include <strings.h>		/* for bzero */
#include <sys/pstat.h>
#include <devnm.h>
#include <unistd.h>		/* for getuid, setuid, etc. */
#include "stormon.h"

int
main ()
{
  struct pst_swapinfo swapinfo;
  char path[100];
  int r;
  int idx;

  do
    {
      pstat_getswap (&swapinfo, sizeof (struct pst_swapinfo), 1, 0);
      idx = swapinfo.pss_idx;

      /* GET THE DEVICE NAME */
      r =
	devnm (S_IFBLK,
	       (dev_t) ((swapinfo.pss_major << 24) | swapinfo.pss_minor),
	       path, sizeof (path), 1);
      if (r)
	{
	  printf ("error:: Failed to get device name.\n");
	  exit (EXIT_FAILURE);
	}

      /* Use space as a separator to be compatible with Filesystem.pm parsing */
      printf ("%s %d\n", path, swapinfo.pss_nblks);

    }
  while (idx != 0);

  exit (EXIT_SUCCESS);
}
