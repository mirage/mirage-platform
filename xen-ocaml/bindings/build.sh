#!/bin/sh -ex

export PKG_CONFIG_PATH=`opam config var prefix`/lib/pkgconfig
PKG_CONFIG_DEPS="mirage-xen-minios"
pkg-config --print-errors --exists ${PKG_CONFIG_DEPS} || exit 1
CFLAGS=`pkg-config --cflags ${PKG_CONFIG_DEPS}`

CC=${CC:-cc}
$CC -Wno-attributes ${EXTRA_MINIOS_CFLAGS} -c -Wall ${CFLAGS} *.c
ar rcs libxencamlbindings.a *.o
