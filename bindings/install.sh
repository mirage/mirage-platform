#!/bin/sh -ex

prefix=${1:-$PREFIX}
if [ "$prefix" = "" ]; then
  prefix=`opam config var prefix`
fi

mkdir -p $prefix/share/pkgconfig $prefix/lib/mirage-xen
cp mirage-xen-ocaml-bindings.pc $prefix/share/pkgconfig/mirage-xen-ocaml-bindings.pc
cp mirage-xen.pc $prefix/share/pkgconfig/mirage-xen.pc
cp libxencamlbindings.a $prefix/lib/mirage-xen/
