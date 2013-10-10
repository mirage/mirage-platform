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

/* $Id: config.h 9117 2008-11-02 14:30:05Z xleroy $ */

#ifndef CAML_CONFIG_H
#define CAML_CONFIG_H

#define ARCH_SIXTYFOUR
#define SIZEOF_INT 4
#define SIZEOF_LONG 8
#define SIZEOF_PTR 8
#define SIZEOF_SHORT 2
#define ARCH_INT64_TYPE long
#define ARCH_UINT64_TYPE unsigned long
#define ARCH_INT64_PRINTF_FORMAT "l"
#undef ARCH_BIG_ENDIAN
#undef ARCH_ALIGN_DOUBLE
#undef ARCH_ALIGN_INT64
#undef NONSTANDARD_DIV_MOD
#define OCAML_OS_TYPE "xen"
#define OCAML_STDLIB_DIR "/usr/local/lib/ocaml"
#define POSIX_SIGNALS
//#define HAS_GETRUSAGE
#define HAS_TIMES
//#define HAS_SOCKETS
//#define HAS_SOCKLEN_T
//#define HAS_INET_ATON
//#define HAS_IPV6
//#define HAS_UNISTD
//#define HAS_OFF_T
//#define HAS_DIRENT
//#define HAS_REWINDDIR
//#define HAS_LOCKF
//#define HAS_MKFIFO
#define HAS_GETCWD
//#define HAS_GETWD
//#define HAS_GETPRIORITY
//#define HAS_UTIME
//#define HAS_UTIMES
//#define HAS_DUP2
//#define HAS_FCHMOD
//#define HAS_TRUNCATE
//#define HAS_SYS_SELECT_H
//#define HAS_SELECT
//#define HAS_SYMLINK
//#define HAS_WAITPID
//#define HAS_WAIT4
//#define HAS_GETGROUPS
//#define HAS_TERMIOS
//#define HAS_SETITIMER
//#define HAS_GETHOSTNAME
//#define HAS_UNAME
#define HAS_GETTIMEOFDAY
//#define HAS_MKTIME
//#define HAS_SETSID
//#define HAS_PUTENV
//#define HAS_LOCALE
//#define HAS_MMAP
//#define HAS_GETHOSTBYNAME_R 6
//#define HAS_GETHOSTBYADDR_R 8
//#define HAS_STACK_OVERFLOW_DETECTION

#ifndef CAML_NAME_SPACE
#include "compatibility.h"
#endif

/* Types for signed chars, 32-bit integers, 64-bit integers,
   native integers (as wide as a pointer type) */

typedef signed char schar;

#if SIZEOF_PTR == SIZEOF_LONG
/* Standard models: ILP32 or I32LP64 */
typedef long intnat;
typedef unsigned long uintnat;
#define ARCH_INTNAT_PRINTF_FORMAT "l"
#elif SIZEOF_PTR == SIZEOF_INT
/* Hypothetical IP32L64 model */
typedef int intnat;
typedef unsigned int uintnat;
#define ARCH_INTNAT_PRINTF_FORMAT ""
#elif SIZEOF_PTR == 8 && defined(ARCH_INT64_TYPE)
/* Win64 model: IL32LLP64 */
typedef ARCH_INT64_TYPE intnat;
typedef ARCH_UINT64_TYPE uintnat;
#define ARCH_INTNAT_PRINTF_FORMAT ARCH_INT64_PRINTF_FORMAT
#else
#error "No integer type available to represent pointers"
#endif

#if SIZEOF_INT == 4
typedef int int32;
typedef unsigned int uint32;
#define ARCH_INT32_PRINTF_FORMAT ""
#elif SIZEOF_LONG == 4
typedef long int32;
typedef unsigned long uint32;
#define ARCH_INT32_PRINTF_FORMAT "l"
#elif SIZEOF_SHORT == 4
typedef short int32;
typedef unsigned short uint32;
#define ARCH_INT32_PRINTF_FORMAT ""
#else
#error "No 32-bit integer type available"
#endif

#if defined(ARCH_INT64_TYPE)
typedef ARCH_INT64_TYPE int64;
typedef ARCH_UINT64_TYPE uint64;
#else
#  ifdef ARCH_BIG_ENDIAN
typedef struct { uint32 h, l; } uint64, int64;
#  else
typedef struct { uint32 l, h; } uint64, int64;
#  endif
#endif

/* Endianness of floats */

/* ARCH_FLOAT_ENDIANNESS encodes the byte order of doubles as follows:
   the value [0xabcdefgh] means that the least significant byte of the
   float is at byte offset [a], the next lsb at [b], ..., and the
   most significant byte at [h]. */

#if defined(__arm__) && !defined(__ARM_EABI__)
#define ARCH_FLOAT_ENDIANNESS 0x45670123
#elif defined(ARCH_BIG_ENDIAN)
#define ARCH_FLOAT_ENDIANNESS 0x76543210
#else
#define ARCH_FLOAT_ENDIANNESS 0x01234567
#endif

/* We use threaded code interpretation if the compiler provides labels
   as first-class values (GCC 2.x). */

#if defined(__GNUC__) && __GNUC__ >= 2 && !defined(DEBUG) && !defined (SHRINKED_GNUC) && !defined(CAML_JIT)
#define THREADED_CODE
#endif


/* Do not change this definition. */
#define Page_size (1 << Page_log)

/* Memory model parameters */

/* The size of a page for memory management (in bytes) is [1 << Page_log].
   It must be a multiple of [sizeof (value)] and >= 8 and <= 20. */
#define Page_log 12             /* A page is 4 kilobytes. */

/* Initial size of stack (bytes). */
#define Stack_size (4096 * sizeof(value))

/* Minimum free size of stack (bytes); below that, it is reallocated. */
#define Stack_threshold (256 * sizeof(value))

/* Default maximum size of the stack (words). */
#define Max_stack_def (1024 * 1024)


/* Maximum size of a block allocated in the young generation (words). */
/* Must be > 4 */
#define Max_young_wosize 256


/* Minimum size of the minor zone (words).
   This must be at least [Max_young_wosize + 1]. */
#define Minor_heap_min 4096

/* Maximum size of the minor zone (words).
   Must be greater than or equal to [Minor_heap_min].
*/
#define Minor_heap_max (1 << 28)

/* Default size of the minor zone. (words)  */
#define Minor_heap_def 32768


/* Minimum size increment when growing the heap (words).
   Must be a multiple of [Page_size / sizeof (value)]. */
#define Heap_chunk_min (2 * Page_size / sizeof (value))

/* Default size increment when growing the heap. (words)
   Must be a multiple of [Page_size / sizeof (value)].
   (Approx 512 Kb for a 32-bit platform, 1 Mb for a 64-bit platform.) */
#define Heap_chunk_def (31 * Page_size)

/* Default initial size of the major heap (words);
   same constraints as for Heap_chunk_def. */
#define Init_heap_def (31 * Page_size)


/* Default speed setting for the major GC.  The heap will grow until
   the dead objects and the free list represent this percentage of the
   total size of live objects. */
#define Percent_free_def 80

/* Default setting for the compacter: 500%
   (i.e. trigger the compacter when 5/6 of the heap is free or garbage)
   This can be set quite high because the overhead is over-estimated
   when fragmentation occurs.
 */
#define Max_percent_free_def 500


#endif /* CAML_CONFIG_H */
