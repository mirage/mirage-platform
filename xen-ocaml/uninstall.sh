#!/bin/sh -ex

prefix=$1
if [ "$prefix" = "" ]; then
  prefix=`opam config var prefix`
fi

rm -f $prefix/share/pkgconfig/mirage-xen-ocaml.pc
rm -rf $prefix/lib/mirage-xen-ocaml
rm -rf $prefix/include/mirage-xen-ocaml
