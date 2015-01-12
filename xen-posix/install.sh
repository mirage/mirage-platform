#!/bin/sh -ex

prefix=$1
if [ "$prefix" = "" ]; then
  prefix=`opam config var prefix`
fi

odir=$prefix/lib
mkdir -p $odir
cp libxenposix.a $odir/mirage-xen/libxenposix.a
cp mirage-xen-minios.pc $odir/pkgconfig/mirage-xen-minios.pc
cp mirage-xen-posix.pc $odir/pkgconfig/mirage-xen-posix.pc
idir=$prefix/include/mirage-xen/include
rm -rf $idir
mkdir -p $idir
cp -r include/* $idir
