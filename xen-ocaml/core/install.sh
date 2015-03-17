#!/bin/sh -ex

prefix=$1
if [ "$prefix" = "" ]; then
  prefix=`opam config var prefix`
fi

pwd=`pwd`
odir=$prefix/lib
mkdir -p $odir
#We dont install the bytecode version yet
#cd ocaml-src/byterun && make install LIBDIR="${pwd}/obj" BINDIR="${pwd}/obj"
cp ocaml-src/asmrun/libasmrun.a $odir/mirage-xen-ocaml/libxenasmrun.a
cp ocaml-src/libxenotherlibs.a $odir/mirage-xen-ocaml/libxenotherlibs.a
cp mirage-xen-ocaml.pc $odir/pkgconfig/mirage-xen-ocaml.pc

# Install public includes
idir=$prefix/include/mirage-xen-ocaml/include
mkdir -p $idir/caml
cd ocaml-src/byterun

PUBLIC_INCLUDES="alloc.h callback.h config.h custom.h fail.h hash.h intext.h \
  memory.h misc.h mlvalues.h printexc.h signals.h compatibility.h"
for i in ${PUBLIC_INCLUDES}; do
  sed -f ../tools/cleanup-header $i > $idir/caml/$i
done
cd ../otherlibs/bigarray
sed -f ../../tools/cleanup-header bigarray.h > $idir/caml/bigarray.h
