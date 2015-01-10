#!/bin/sh -ex

prefix=$1
if [ "$prefix" = "" ]; then
  prefix=`opam config var prefix`
fi

odir=$prefix/lib
mkdir -p $odir/pkgconfig $odir/mirage-xen
cp mirage-xen-ocaml-bindings.pc $odir/pkgconfig/mirage-xen-ocaml-bindings.pc
cp libxencamlbindings.a $odir/mirage-xen/
