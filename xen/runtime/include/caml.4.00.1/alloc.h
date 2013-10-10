/***********************************************************************/
/*                                                                     */
/*                           Objective Caml                            */
/*                                                                     */
/*         Xavier Leroy and Damien Doligez, INRIA Rocquencourt         */
/*                                                                     */
/*  Copyright 1996 Institut National de Recherche en Informatique et   */
/*  en Automatique.  All rights reserved.  This file is distributed    */
/*  under the terms of the GNU Library General Public License, with    */
/*  the special exception on linking described in file ../LICENSE.     */
/*                                                                     */
/***********************************************************************/

/* $Id: alloc.h,v 1.18 2005/09/22 14:21:50 xleroy Exp $ */

#ifndef CAML_ALLOC_H
#define CAML_ALLOC_H


#ifndef CAML_NAME_SPACE
#include "compatibility.h"
#endif
#include "misc.h"
#include "mlvalues.h"

CAMLextern value caml_alloc (mlsize_t, tag_t);
CAMLextern value caml_alloc_small (mlsize_t, tag_t);
CAMLextern value caml_alloc_tuple (mlsize_t);
CAMLextern value caml_alloc_string (mlsize_t);  /* size in bytes */
CAMLextern value caml_copy_string (char const *);
CAMLextern value caml_copy_string_array (char const **);
CAMLextern value caml_copy_double (double);
CAMLextern value caml_copy_int32 (int32);       /* defined in [ints.c] */
CAMLextern value caml_copy_int64 (int64);       /* defined in [ints.c] */
CAMLextern value caml_copy_nativeint (intnat);  /* defined in [ints.c] */
CAMLextern value caml_alloc_array (value (*funct) (char const *),
                                   char const ** array);

typedef void (*final_fun)(value);
CAMLextern value caml_alloc_final (mlsize_t, /*size in words*/
                                   final_fun, /*finalization function*/
                                   mlsize_t, /*resources consumed*/
                                   mlsize_t  /*max resources*/);

CAMLextern int caml_convert_flag_list (value, int *);

#endif /* CAML_ALLOC_H */
