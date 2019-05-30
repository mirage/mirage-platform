#!/bin/sh -ex

prefix=$1
if [ "$prefix" = "" ]; then
  prefix=`opam config var prefix`
fi

OCAML_LIB_DIR=$(opam config var stublibs)
odir=$prefix/lib
rm -f $odir/pkgconfig/mirage-xen-ocaml.pc
rm -rf $odir/mirage-xen-ocaml
rm -rf $prefix/include/mirage-xen-ocaml
rm -f $OCAML_LIB_DIR/libasmrunxen.a
