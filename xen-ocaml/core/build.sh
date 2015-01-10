#!/bin/sh -ex

export PKG_CONFIG_PATH=`opam config var prefix`/lib/pkgconfig
PKG_CONFIG_DEPS="openlibm libminios-xen >= 0.5"
pkg-config --print-errors --exists ${PKG_CONFIG_DEPS} || exit 1

case `uname -m` in
armv*)
  ARCH_CFLAGS="-DTARGET_arm"
  m_header=m.arm.h
 ;;
*)
  ARCH_CFLAGS="-DTARGET_amd64 -D__x86_64__ -momit-leaf-frame-pointer -mfancy-math-387"
  m_header=m.x86_64.h
  ;;
esac

# This extra flag only needed for gcc 4.8+
# TODO we only need this for minios and not applications I think
GCC_MVER2=`gcc -dumpversion | cut -f2 -d.`
if [ $GCC_MVER2 -ge 8 ]; then
  EXTRA_CFLAGS=-fno-tree-loop-distribute-patterns
fi

CC=${CC:-cc}
PWD=`pwd`
GCC_INCLUDE=`env LANG=C ${CC} -print-search-dirs | sed -n -e 's/install: \(.*\)/\1/p'`
CFLAGS="$EXTRA_CFLAGS -O3 -Wno-attributes \
  -DSYS_xen $(pkg-config --cflags $PKG_CONFIG_DEPS) \
   -I `opam config var prefix`/include/mirage-xen/include \
   -DNATIVE_CODE -USYS_linux"  

rm -rf ocaml-src
cp -r `opam config var prefix`/lib/ocaml-src ocaml-src
# TODO fix Makefile.config, perhaps run configure 
cp ${m_header} ocaml-src/config/m.h
cp Makefile.config ocaml-src/config/Makefile
echo '#define OCAML_OS_TYPE "Unix"' > ocaml-src/config/s.h
echo '#define POSIX_SIGNALS 1' >> ocaml-src/config/s.h
echo '#define HAS_DIRENT 1' >> ocaml-src/config/s.h
echo '#define HAS_GETTIMEOFDAY 1' >> ocaml-src/config/s.h
cd ocaml-src
cd asmrun && make -j8 NATIVECCCOMPOPTS="${CFLAGS}" NATIVECCPROFOPTS="${CFLAGS}" && cd ..
CFLAGS="$CFLAGS -I../../byterun" 
cd otherlibs/bigarray && make CFLAGS="${CFLAGS}" bigarray_stubs.o mmap_unix.o
cd ../str && make CFLAGS="${CFLAGS}" strstubs.o && cd ../..
ar rcs libxenotherlibs.a otherlibs/bigarray/bigarray_stubs.o otherlibs/bigarray/mmap_unix.o otherlibs/str/strstubs.o
