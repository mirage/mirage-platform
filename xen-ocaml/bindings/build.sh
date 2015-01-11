#!/bin/sh -ex

export PKG_CONFIG_PATH=`opam config var prefix`/lib/pkgconfig
PKG_CONFIG_DEPS="mirage-xen-minios"
pkg-config --print-errors --exists ${PKG_CONFIG_DEPS} || exit 1
CFLAGS=`pkg-config --cflags mirage-xen-ocaml`
MINIOS_CFLAGS=`pkg-config --cflags mirage-xen-minios mirage-xen-ocaml`

CC=${CC:-cc}
$CC -Wall -Wno-attributes ${MINIOS_CFLAGS} -c barrier_stubs.c eventchn_stubs.c exit_stubs.c gnttab_stubs.c  main.c page_stubs.c  sched_stubs.c start_info_stubs.c  xb_stubs.c
$CC -Wall -Wno-attributes ${CFLAGS} -c atomic_stubs.c clock_stubs.c cstruct_stubs.c 
ar rcs libxencamlbindings.a *.o
