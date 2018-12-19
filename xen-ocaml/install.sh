#!/bin/sh -ex

prefix=${1:-$PREFIX}
if [ "$prefix" = "" ]; then
  prefix=`opam config var prefix`
fi

pwd=`pwd`
odir=$prefix/lib
mkdir -p $odir/mirage-xen-ocaml
#We dont install the bytecode version yet
#cd ocaml-src/byterun && make install LIBDIR="${pwd}/obj" BINDIR="${pwd}/obj"
cp ocaml-src/asmrun/libasmrun.a $odir/mirage-xen-ocaml/libxenasmrun.a
cp ocaml-src/libxenotherlibs.a $odir/mirage-xen-ocaml/libxenotherlibs.a
touch $odir/mirage-xen-ocaml/META
mkdir -p $odir/pkgconfig
cp mirage-xen-ocaml.pc $odir/pkgconfig/mirage-xen-ocaml.pc

# Install public includes
idir=$prefix/include/mirage-xen-ocaml/include
mkdir -p $idir/caml

cd ocaml-src/byterun
if [ -f caml/alloc.h ]; then
  HEADERS_SRC=caml
else
  HEADERS_SRC=.
fi

PUBLIC_INCLUDES="alloc.h callback.h config.h custom.h fail.h hash.h intext.h \
  io.h m.h memory.h misc.h mlvalues.h printexc.h s.h signals.h compatibility.h"
if [ -e ../tools/cleanup-header ]; then
  for i in ${PUBLIC_INCLUDES}; do
    sed -f ../tools/cleanup-header $HEADERS_SRC/$i > $idir/caml/$i
  done
  cd ../otherlibs/bigarray
  sed -f ../../tools/cleanup-header bigarray.h > $idir/caml/bigarray.h
else
  for i in ${PUBLIC_INCLUDES} bigarray.h; do
    cp ${HEADERS_SRC}/$i $idir/caml/$i
  done
fi
