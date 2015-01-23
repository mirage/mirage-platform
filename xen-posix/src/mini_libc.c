/*
 * Define a minimal POSIX-compatible API to allow the OCaml runtime to compile.
 *
 * Most functions either always return an error or panic. A few
 * actually do something:
 *
 * - atoi and calloc are implemented
 * - write(1 or 2, ...) uses printk to display the output
 * - exit calls do_exit
 *
 * Based on Mini-OS sys.c by Samuel Thibault <Samuel.Thibault@eu.citrix.net>,
 * October 2007.
 */

#include <mini-os/os.h>
#include <mini-os/lib.h>
#include <errno.h>
#include <limits.h>
#include <sys/types.h>
#include "fmt_fp.h"
#define HUGE_VAL	(__builtin_huge_val())

#define     ENOSYS          38      /* Function not implemented */

#define print_unsupported(fmt, ...) \
    printk("Unsupported function "fmt" called in Mini-OS kernel\n", ## __VA_ARGS__);

/* Crash on function call */
#define unsupported_function_crash(function) \
    int __unsup_##function(void) asm(#function); \
    int __unsup_##function(void) \
    { \
	print_unsupported(#function); \
	do_exit(); \
    }

/* Log and err out on function call */
#define unsupported_function_log(type, function, ret) \
    type __unsup_##function(void) asm(#function); \
    type __unsup_##function(void) \
    { \
	print_unsupported(#function); \
	errno = ENOSYS; \
	return ret; \
    }

/* Err out on function call */
#define unsupported_function(type, function, ret) \
    type __unsup_##function(void) asm(#function); \
    type __unsup_##function(void) \
    { \
	errno = ENOSYS; \
	return ret; \
    }

void *stderr = NULL;
void *stdout = NULL;
void * __stack_chk_guard = NULL;

char *getenv(const char *name)
{
  printk("getenv(%s) -> null\n", name);
  return NULL;
}

void* calloc(size_t nmemb, size_t _size)
{
  register size_t size=_size*nmemb;
  void* x=malloc(size);
  memset(x,0,size);
  return x;
}

ssize_t write(int fd, const void *buf, size_t count)
{
  if (fd == 1 || fd == 2)
  {
    console_print(NULL, buf, count);
  }
  else
  {
    printk("Error: write to FD %d: '%*s'\n", fd, count, buf);
  }
  return count;
}

void exit(int status)
{
  printk("Mirage exiting with status %d\n", status);
  do_exit();
}

int atoi(const char *nptr)
{
  return simple_strtoul(nptr, NULL, 10);
}

int open64(const char *pathname, int flags)
{
  printk("Attempt to open(%s)!\n", pathname);
  return -1;
}

struct _buffer {
    char *buf;
    char *end;
};

void out(buffer_t *f, const char *s, size_t l)
{
    while (l > 0) {
        if (f->buf <= f->end)
            *(f->buf++) = *(s++);
        --l;
    }
}

int fprintf(void *stream, const char *fmt, ...)
{
  va_list  args;
  va_start(args, fmt);
  print(0, fmt, args);
  va_end(args);
  return 1;
}

int printf(const char *fmt, ...)
{
  va_list args;
  va_start(args, fmt);
  print(0, fmt, args);
  va_end(args);
  return 1;
}

int fflush (void * stream)
{
  return 0;
}

void abort(void)
{
  printk("Abort called!\n");
  do_exit();
}

#define ZEROPAD 1               /* pad with zero */
#define SIGN    2               /* unsigned/signed long */
#define PLUS    4               /* show plus */
#define SPACE   8               /* space if plus */
#define LEFT    16              /* left justified */
#define SPECIAL 32              /* 0x */
#define LARGE   64              /* use 'ABCDEF' instead of 'abcdef' */

char *minios_printf_render_float(char *buf, char *end, long double y, char fmt, char qualifier, int size, int precision, int type)
{
    buffer_t buffer = {
        .buf = buf,
        .end = end
    };
    int fl = 0;

    if (type & ZEROPAD) fl |= ZERO_PAD;
    if (type & PLUS) fl |= MARK_POS;
    if (type & SPACE) fl |= PAD_POS;
    if (type & LEFT) fl |= LEFT_ADJ;
    if (type & SPECIAL) fl |= ALT_FORM;

    fmt_fp(&buffer, y, size, precision, fl, fmt);

    return buffer.buf;
}

/* Not supported by FS yet.  */
unsupported_function_crash(link);
unsupported_function(int, readlink, -1);
unsupported_function_crash(umask);

/* We could support that.  */
unsupported_function_log(int, chdir, -1);

/* No dynamic library support.  */
unsupported_function_log(void *, dlopen, NULL);
unsupported_function_log(void *, dlsym, NULL);
unsupported_function_log(char *, dlerror, NULL);
unsupported_function_log(int, dlclose, -1);

/* We don't raise signals anyway.  */
unsupported_function(int, sigemptyset, -1);
unsupported_function(int, sigfillset, -1);
unsupported_function(int, sigaddset, -1);
unsupported_function(int, sigdelset, -1);
unsupported_function(int, sigismember, -1);
unsupported_function(int, sigprocmask, -1);
unsupported_function(int, sigaction, -1);
unsupported_function(int, __sigsetjmp, 0);
unsupported_function(int, sigaltstack, -1);
unsupported_function_crash(kill);

/* Unsupported */
unsupported_function_crash(pipe);
unsupported_function_crash(fork);
unsupported_function_crash(execv);
unsupported_function_crash(execve);
unsupported_function_crash(waitpid);
unsupported_function_crash(wait);
unsupported_function_crash(lockf);
unsupported_function_crash(sysconf);
unsupported_function(int, tcsetattr, -1);
unsupported_function(int, tcgetattr, 0);
unsupported_function(int, grantpt, -1);
unsupported_function(int, unlockpt, -1);
unsupported_function(char *, ptsname, NULL);

/* net/if.h */
unsupported_function_log(unsigned int, if_nametoindex, -1);
unsupported_function_log(char *, if_indextoname, (char *) NULL);
unsupported_function_log(struct  if_nameindex *, if_nameindex, (struct  if_nameindex *) NULL);
unsupported_function_crash(if_freenameindex);

/* Linuxish abi for the Caml runtime, don't support 
   Log, and return an error code if possible.  If it is not possible
   to inform the application of an error, then crash instead!
*/

unsupported_function_log(struct dirent *, readdir64, NULL);
unsupported_function_log(clock_t, clock, -1);
unsupported_function_log(char *, getwd, NULL);
unsupported_function_log(void *, opendir, NULL);
unsupported_function_log(struct dirent *, readdir, NULL);
unsupported_function_log(int, closedir, -1);
unsupported_function_log(int, getrusage, -1);
unsupported_function_log(int, getrlimit, -1);
unsupported_function_log(int, getrlimit64, -1);
unsupported_function_log(int, __xstat64, -1);
unsupported_function_log(long, __strtol_internal, LONG_MIN);
unsupported_function_log(double, __strtod_internal, HUGE_VAL);
unsupported_function_log(int, utime, -1);
unsupported_function_log(int, truncate64, -1);
unsupported_function_log(int, tcflow, -1);
unsupported_function_log(int, tcflush, -1);
unsupported_function_log(int, tcdrain, -1);
unsupported_function_log(int, tcsendbreak, -1);
unsupported_function_log(int, cfsetospeed, -1);
unsupported_function_log(int, cfsetispeed, -1);
unsupported_function_crash(cfgetospeed);
unsupported_function_crash(cfgetispeed);
unsupported_function_log(int, symlink, -1);
unsupported_function_log(const char*, inet_ntop, NULL);
unsupported_function_crash(__fxstat64);
unsupported_function_crash(__lxstat64);
unsupported_function_log(int, socketpair, -1);
unsupported_function_crash(sigsuspend);
unsupported_function_log(int, sigpending, -1);
unsupported_function_log(int, shutdown, -1);
unsupported_function_log(int, setuid, -1);
unsupported_function_log(int, setgid, -1);
unsupported_function_crash(rewinddir);
unsupported_function_log(int, getpriority, -1);
unsupported_function_log(int, setpriority, -1);
unsupported_function_log(int, mkfifo, -1);
unsupported_function_log(int, getitimer, -1);
unsupported_function_log(int, setitimer, -1);
unsupported_function_log(void *, getservbyport, NULL);
unsupported_function_log(void *, getservbyname, NULL);
unsupported_function_log(void *, getpwuid, NULL);
unsupported_function_log(void *, getpwnam, NULL);
unsupported_function_log(void *, getprotobynumber, NULL);
unsupported_function_log(void *, getprotobyname, NULL);
unsupported_function_log(int, getpeername, -1);
unsupported_function_log(int, getnameinfo, -1);
unsupported_function_log(char *, getlogin, NULL);
unsupported_function_crash(__h_errno_location);
unsupported_function_log(int, gethostbyname_r, -1);
unsupported_function_log(int, gethostbyaddr_r, -1);
unsupported_function_log(int, getgroups, -1);
unsupported_function_log(void *, getgrgid, NULL);
unsupported_function_log(void *, getgrnam, NULL);
unsupported_function_log(int, getaddrinfo, -1);
unsupported_function_log(int, freeaddrinfo, -1);
unsupported_function_log(int, ftruncate64, -1);
unsupported_function_log(int, fchown, -1);
unsupported_function_log(int, fchmod, -1);
unsupported_function_crash(execvp);
unsupported_function_log(int, dup, -1)
unsupported_function_log(int, chroot, -1)
unsupported_function_log(int, chown, -1);
unsupported_function_log(int, chmod, -1);
unsupported_function_crash(alarm);
unsupported_function_log(int, inet_pton, -1);
unsupported_function_log(int, access, -1);

unsupported_function_crash(stat);
unsupported_function_crash(lstat);
unsupported_function_crash(unlink);
unsupported_function_crash(getcwd);
unsupported_function_crash(system);
unsupported_function_crash(close);
unsupported_function_log(off_t, lseek, -1);
unsupported_function_crash(fcntl);
unsupported_function_crash(read);
unsupported_function_crash(gmtime);
unsupported_function_crash(strtod);
unsupported_function_crash(rename);
unsupported_function_crash(times);
unsupported_function_crash(strerror);
