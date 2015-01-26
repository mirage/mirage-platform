#!/bin/sh -ex

export PKG_CONFIG_PATH=`opam config var prefix`/lib/pkgconfig
PKG_CONFIG_DEPS="openlibm libminios-xen >= 0.5"
pkg-config --print-errors --exists ${PKG_CONFIG_DEPS} || exit 1

case `uname -m` in
armv*)
 ;;
*)
  ARCH_CFLAGS="-D__x86_64__ -momit-leaf-frame-pointer -mfancy-math-387"
  ;;
esac

# This extra flag only needed for gcc 4.8+
GCC_MVER2=`gcc -dumpversion | cut -f2 -d.`
if [ $GCC_MVER2 -ge 8 ]; then
  EXTRA_CFLAGS="-fno-tree-loop-distribute-patterns -fno-stack-protector"
fi

CC=${CC:-cc}
PWD=`pwd`
CFLAGS="$EXTRA_CFLAGS -I ${PWD}/include/ -I ${PWD}/src/ \
    -D__XEN_INTERFACE_VERSION__=0x00030205 -D__INSIDE_MINIOS__ \
    $(pkg-config --cflags $PKG_CONFIG_DEPS) \
    -Wextra -Wchar-subscripts -Wno-switch -Wno-unused -Wredundant-decls \
    -fno-builtin ${ARCH_CFLAGS}"

${CC} -c ${CFLAGS} src/*.c
ar rcs libxenposix.a mini_libc.o fmt_fp.o
