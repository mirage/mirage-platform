#!/bin/sh -ex

prefix=$1
if [ "$prefix" = "" ]; then
  prefix=`opam config var prefix`
fi

odir=$prefix/lib
mkdir -p $odir
cp ocaml-src/asmrun/libasmrun.a $odir/mirage-xen/libxenasmrun.a
cp ocaml-src/libxenotherlibs.a $odir/mirage-xen/libxenotherlibs.a
cp mirage-xen-ocaml.pc $odir/pkgconfig/mirage-xen-ocaml.pc
idir=$prefix/include/mirage-xen/include
mkdir -p $idir/caml
cp -r ocaml-src/byterun/*.h ocaml-src/otherlibs/bigarray/bigarray.h $idir/caml/
