#!/bin/sh -ex

MJOBS=${8:-NJOBS}
export PKG_CONFIG_PATH=`opam config var prefix`/lib/pkgconfig
PKG_CONFIG_DEPS="openlibm libminios-xen >= 0.5"
pkg-config --print-errors --exists ${PKG_CONFIG_DEPS} || exit 1

case `uname -m` in
armv*)
  ARCH_CFLAGS="-DTARGET_arm"
 ;;
*)
  ARCH_CFLAGS="-DTARGET_amd64 -D__x86_64__ -momit-leaf-frame-pointer -mfancy-math-387"
  ;;
esac

CC=${CC:-cc}
PWD=`pwd`
CFLAGS="-Wno-attributes -DSYS_xen -USYS_linux \
  $(pkg-config --cflags $PKG_CONFIG_DEPS) \
  -I `opam config var prefix`/include/mirage-xen/include"

rm -rf ocaml-src
cp -r `opam config var prefix`/lib/ocaml-src ocaml-src
cp config/*.h ocaml-src/config/
cp Makefile.config ocaml-src/config/Makefile
cd ocaml-src
# cd byterun && make BYTECCCOMPOPTS="${CFLAGS}" BYTECCCOMPOPTS="${CFLAGS}" libcamlrun.a && cd ..
cd asmrun && make -j${NJOBS} UNIX_OR_WIN32=unix NATIVECCCOMPOPTS="-DNATIVE_CODE ${CFLAGS}" NATIVECCPROFOPTS="-DNATIVE_CODE ${CFLAGS}" libasmrun.a && cd ..
CFLAGS="$CFLAGS -I../../byterun" 
cd otherlibs/bigarray && make CFLAGS="${CFLAGS}" bigarray_stubs.o mmap_unix.o
cd ../str && make CFLAGS="${CFLAGS}" strstubs.o && cd ../..
ar rcs libxenotherlibs.a otherlibs/bigarray/bigarray_stubs.o otherlibs/bigarray/mmap_unix.o otherlibs/str/strstubs.o
