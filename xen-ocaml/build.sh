#!/bin/sh -ex

MJOBS=${4:-NJOBS}
export PKG_CONFIG_PATH=`opam config var prefix`/lib/pkgconfig
PKG_CONFIG_DEPS="mirage-xen-posix openlibm libminios-xen >= 0.5"
pkg-config --print-errors --exists ${PKG_CONFIG_DEPS} || exit 1
case `uname -m` in
armv*)
  ARCH_CFLAGS=""
  m_file="arm"
 ;;
*)
  ARCH_CFLAGS="-momit-leaf-frame-pointer -mfancy-math-387"
  m_file="x86_64"
  ;;
esac

# This extra flag only needed for gcc 4.8+
GCC_MVER2=`gcc -dumpversion | cut -f2 -d.`
if [ $GCC_MVER2 -ge 8 ]; then
  EXTRA_CFLAGS="-fno-tree-loop-distribute-patterns -fno-stack-protector"
fi

CC=${CC:-cc}
PWD=`pwd`
CFLAGS="-Wall -Wno-attributes ${ARCH_CFLAGS} ${EXTRA_CFLAGS} ${CI_CFLAGS} -DSYS_xen -USYS_linux \
  $(pkg-config --cflags $PKG_CONFIG_DEPS) \
  -I `opam config var prefix`/include/mirage-xen/include"

rm -rf ocaml-src
cp -r `opam config var prefix`/lib/ocaml-src ocaml-src

case `ocamlopt -version` in
4.01.* | 4.02.[01]) patch < trace-gc.patch -p 0
esac

cp config/s.h ocaml-src/config/
cp config/m.${m_file}.h ocaml-src/config/m.h
cp config/Makefile.${m_file} ocaml-src/config/Makefile
touch ocaml-src/config/Makefile
cd ocaml-src
# cd byterun && make BYTECCCOMPOPTS="${CFLAGS}" BYTECCCOMPOPTS="${CFLAGS}" libcamlrun.a && cd ..
cd asmrun && make -j${NJOBS} UNIX_OR_WIN32=unix NATIVECCCOMPOPTS="-DNATIVE_CODE ${CFLAGS}" NATIVECCPROFOPTS="-DNATIVE_CODE ${CFLAGS}" libasmrun.a && cd ..
CFLAGS="$CFLAGS -I../../byterun" 
cd otherlibs/bigarray && make CFLAGS="${CFLAGS}" bigarray_stubs.o mmap_unix.o
cd ../str && make CFLAGS="${CFLAGS}" strstubs.o && cd ../..
ar rcs libxenotherlibs.a otherlibs/bigarray/bigarray_stubs.o otherlibs/bigarray/mmap_unix.o otherlibs/str/strstubs.o
