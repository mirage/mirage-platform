#!/bin/sh -ex

prefix=$1
if [ "$prefix" = "" ]; then
  prefix=`opam config var prefix`
fi

odir=$prefix/lib
rm -rf $odir/mirage-xen
rm -f $odir/pkgconfig/mirage-xen-minios.pc
rm -f $odir/pkgconfig/mirage-xen-posix.pc
idir=$prefix/include/mirage-xen/include
rm -rf $idir
