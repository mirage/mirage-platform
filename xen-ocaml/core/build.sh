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

CC=${CC:-cc}
PWD=`pwd`
CFLAGS="$EXTRA_CFLAGS -Wno-attributes \
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
