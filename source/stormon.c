/*
*
* Copyright  (c) 2002 Oracle Corporation All rights reserved
*
*  $Id: stormon.c,v 1.6 2002/12/05 19:06:09 vswamida Exp $ 
*
*
* NAME  
*	 stormon.c
*
* DESC 
*	common routines used by stormon binary executables
*
* FUNCTIONS
*
*
* NOTES
*
*
* MODIFIED	(MM/DD/YY)
* ajdsouza	05/01/02 - Created
*
*/

#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include "stormon.h"

/*******************************************************************
*
* FUNCTION : checkandcopy
*
* ARGUMENTS:
*	address of the destination pointer
*	source pointer
*	size
*
* DESC : Copy src to destination to size with null termination 
*	 Raise error if length of src > size
*        
********************************************************************/

int checkandcopy (char **dest, const char *src, size_t size)
{
  *dest = (char *) calloc (size + 1, sizeof (char));
  if (!*dest)
    {
      exit (EXIT_FAILURE);
    }

  strncpy (*dest, src, size + 1);

  if ((*dest)[size] != '\0')
    {
      free (*dest);
      return EXIT_FAILURE;
    }

  (*dest)[size] = '\0';

  return EXIT_SUCCESS;
}


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
void eraseenv ()
{
  extern char **environ;
  char **this;

  /***********Print Environment (debug) ************ 
  this = environ; 
  while(*this != NULL){
    printf("%s\n",*this);
    this++;
  }
  **************************************************/

  /* Copy environ pointer so that we don't change the real address */
  this = environ;
  /* Erase each array member */
  while (*this != NULL)
    {
      *this = NULL;
      this++;
    }

  /* Erase environment */

  /* Commented because erasing this pointer causes seg faults on Linux */
  /* environ = NULL; */

}
