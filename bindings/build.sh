#!/bin/sh -ex

PKG_CONFIG_DEPS="mirage-xen-minios mirage-xen-ocaml"
check_deps () {
  pkg-config --print-errors --exists ${PKG_CONFIG_DEPS}
}

if ! check_deps 2>/dev/null; then
  # only rely on `opam` if deps are unavailable
  export PKG_CONFIG_PATH=`opam config var prefix`/share/pkgconfig
fi
check_deps || exit 1

CFLAGS=`pkg-config --cflags mirage-xen-ocaml`
MINIOS_CFLAGS=`pkg-config --cflags mirage-xen-minios mirage-xen-ocaml`

# This extra flag only needed for gcc 4.8+
GCC_MVER2=`gcc -dumpversion | cut -f2 -d.`
if [ $GCC_MVER2 -ge 8 ]; then
  EXTRA_CFLAGS="-fno-tree-loop-distribute-patterns -fno-stack-protector"
fi

CC=${CC:-cc}
$CC -Wall -Wno-attributes ${MINIOS_CFLAGS} ${EXTRA_CFLAGS} ${CI_CFLAGS} -c barrier_stubs.c eventchn_stubs.c exit_stubs.c gnttab_stubs.c main.c sched_stubs.c start_info_stubs.c xb_stubs.c mm_stubs.c
$CC -Wall -Wno-attributes ${CFLAGS} ${EXTRA_CFLAGS} ${CI_CFLAGS} -c atomic_stubs.c clock_stubs.c cstruct_stubs.c
ar rcs libxencamlbindings.a *.o
