#!/bin/sh -ex

prefix=${1:-$PREFIX}
if [ "$prefix" = "" ]; then
  prefix=`opam config var prefix`
fi

odir=$prefix/lib
mkdir -p $odir/mirage-xen-posix
cp libxenposix.a $odir/mirage-xen-posix/libxenposix.a
mkdir -p $prefix/share/pkgconfig
cp mirage-xen-minios.pc $prefix/share/pkgconfig/mirage-xen-minios.pc
cp mirage-xen-posix.pc $prefix/share/pkgconfig/mirage-xen-posix.pc
idir=$prefix/include/mirage-xen-posix/include
rm -rf $idir
mkdir -p $idir
cp -r include/* $idir
