#!/bin/sh -x

# Detect OCaml version and symlink in right runtime files
OCAML_VERSION=`ocamlc -version`
case $OCAML_VERSION in
4.00.1|4.01.0)
  ln -nsf ocaml.$OCAML_VERSION runtime/ocaml
  ln -nsf caml.$OCAML_VERSION runtime/include/caml
  ;;
*)
  echo Unknown OCaml version $OCAML_VERSION
  exit 1
esac

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
  CFLAGS="$EXTRA_CFLAGS -O3 -U __linux__ -U __FreeBSD__ -U __sun__ -D__MiniOS__ -D__MiniOS__ -D__x86_64__ \
    -D__XEN_INTERFACE_VERSION__=0x00030205 -D__INSIDE_MINIOS__ -nostdinc -std=gnu99 \
    -fno-stack-protector -m64 -mno-red-zone -fno-reorder-blocks -fstrict-aliasing \
    -momit-leaf-frame-pointer -mfancy-math-387 -I${GCC_INCLUDE}/include \
    -I ${PWD}/runtime/include/ \
    -DCAML_NAME_SPACE -DTARGET_amd64 \
    -DSYS_xen -I${PWD}/runtime/ocaml $(pkg-config --cflags $PKG_CONFIG_DEPS) \
    -Wextra -Wchar-subscripts -Wno-switch \
    -Wno-unused -Wredundant-decls \
    -DNATIVE_CODE"
  ;;
*)
  CC="${CC:-cc}"
  CFLAGS="-Wall -O3"
  ;;
esac
