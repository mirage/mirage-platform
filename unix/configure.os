#!/bin/sh

OS=`uname -s`

CFLAGS=${CFLAGS:--Wall -O3}
case `uname -m` in
armv7l)
  CFLAGS="${CFLAGS} -fPIC"
  ;;
amd64|x86_64)
  CFLAGS="${CFLAGS} -fPIC"
  ;;
esac
