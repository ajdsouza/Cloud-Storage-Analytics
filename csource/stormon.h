/*
*
* Copyright  (c) 2002 Oracle Corporation All rights reserved
*
*  $Id: stormon.h,v 1.3 2002/10/03 17:08:26 ajdsouza Exp $ 
*
*
* NAME  
*	 stormon.h
*
* DESC 
*	common routines used by stormon binary executables
*
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

#ifndef STORMON_H
#define STORMON_H


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
extern int checkandcopy(char **dest, const char *src, size_t size);


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
extern void eraseenv();


#endif
