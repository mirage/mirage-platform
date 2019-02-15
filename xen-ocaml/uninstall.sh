#!/bin/sh -ex

prefix=$1
if [ "$prefix" = "" ]; then
  prefix=`opam config var prefix`
fi

odir=$prefix/lib
rm -f $odir/pkgconfig/mirage-xen-ocaml.pc
rm -rf $odir/mirage-xen-ocaml
rm -rf $prefix/include/mirage-xen-ocaml
rm -f $odir/ocaml/libasmrunxen.a
