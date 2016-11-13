#!/bin/sh -ex

prefix=$1
if [ "$prefix" = "" ]; then
  prefix=`opam config var prefix`
fi

rm -rf $prefix/lib/mirage-xen-posix
rm -f $prefix/share/pkgconfig/mirage-xen-minios.pc
rm -f $prefix/share/pkgconfig/mirage-xen-posix.pc
rm -rf $prefix/include/mirage-xen-posix
