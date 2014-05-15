#!/bin/sh -x

# Detect OCaml version and symlink in right runtime files
OCAML_VERSION=`ocamlc -version`
case $OCAML_VERSION in
4.00.1)
  echo Only OCaml 4.01.0 is supported
  exit 1
  ;;
4.01.0)
  ;;
*)
  echo Unknown OCaml version $OCAML_VERSION
  exit 1
esac

case `uname -m` in
armv*)
  ARCH_CFLAGS="-DTARGET_arm"
  ARCH_OBJ="arm.o"
 ;;
*)
  ARCH_CFLAGS="-DTARGET_amd64 -D__x86_64__ -m64 -mno-red-zone -momit-leaf-frame-pointer -mfancy-math-387"
  ARCH_OBJ="amd64.o"
  ;;
esac

echo $ARCH_OBJ | cat - runtime/ocaml/libocaml.cclib.in > runtime/ocaml/libocaml.cclib

PKG_CONFIG_DEPS="openlibm libminios"

# This extra flag only needed for gcc 4.8+
GCC_MVER2=`gcc -dumpversion | cut -f2 -d.`
if [ $GCC_MVER2 -ge 8 ]; then
  EXTRA_CFLAGS=-fno-tree-loop-distribute-patterns
fi

case "$1" in
xen)
  CC=${CC:-cc}
  PWD=`pwd`
  GCC_INCLUDE=`env LANG=C ${CC} -print-search-dirs | sed -n -e 's/install: \(.*\)/\1/p'`
  CFLAGS="$EXTRA_CFLAGS -O3 -U __linux__ -U __FreeBSD__ -U __sun__ \
    -D__XEN_INTERFACE_VERSION__=0x00030205 -D__INSIDE_MINIOS__ -nostdinc -std=gnu99 \
    -fno-stack-protector -fno-reorder-blocks -fstrict-aliasing \
    -I${GCC_INCLUDE}/include \
    -I ${PWD}/runtime/include/ \
    -DCAML_NAME_SPACE \
    -DSYS_xen -I${PWD}/runtime/ocaml $(pkg-config --cflags $PKG_CONFIG_DEPS) \
    -Wextra -Wchar-subscripts -Wno-switch \
    -Wno-unused -Wredundant-decls \
    -DNATIVE_CODE ${ARCH_CFLAGS}"
  ;;
*)
  CC="${CC:-cc}"
  CFLAGS="-Wall -O3"
  ;;
esac
