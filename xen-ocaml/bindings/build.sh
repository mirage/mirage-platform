#!/bin/sh -ex

export PKG_CONFIG_PATH=`opam config var prefix`/lib/pkgconfig
PKG_CONFIG_DEPS="mirage-xen libminios-xen"
pkg-config --print-errors --exists ${PKG_CONFIG_DEPS} || exit 1

# TODO these need to be in the main minios flags exposed somehow
EXTRA_MINIOS_CFLAGS="-D__XEN_INTERFACE_VERSION__=0x00030205 -D__INSIDE_MINIOS__"
CC=${CC:-cc}
for i in *.c; do
  $CC -Wno-attributes ${EXTRA_MINIOS_CFLAGS} -c -Wall `pkg-config --cflags ${PKG_CONFIG_DEPS}` $i
done
ar rcs libxencamlbindings.a *.o
