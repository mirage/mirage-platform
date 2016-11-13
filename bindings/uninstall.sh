#!/bin/sh -ex

prefix=$1
if [ "$prefix" = "" ]; then
  prefix=`opam config var prefix`
fi

rm -f $orefix/share/pkgconfig/mirage-xen-ocaml-bindings.pc
rm -f $prefix/share/pkgconfig/mirage-xen.pc
rm -f $prefix/lib/mirage-xen/libxencamlbindings.a
