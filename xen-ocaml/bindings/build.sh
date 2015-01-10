#!/bin/sh -ex

export PKG_CONFIG_PATH=`opam config var prefix`/lib/pkgconfig
PKG_CONFIG_DEPS="mirage-xen libminios-xen"
pkg-config --print-errors --exists ${PKG_CONFIG_DEPS} || exit 1

CC=${CC:-cc}
for i in *.c; do
  $CC -D__INSIDE_MINIOS__ -c -Wall `pkg-config --cflags ${PKG_CONFIG_DEPS}` $i
done
ar rcs libxencamlbindings.a *.o
