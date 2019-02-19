#!/bin/sh -ex

MJOBS=${4:-NJOBS}
PKG_CONFIG_DEPS="mirage-xen-posix openlibm libminios-xen >= 0.5"
check_deps () {
  pkg-config --print-errors --exists ${PKG_CONFIG_DEPS}
}

if ! check_deps 2>/dev/null; then
  # only rely on `opam` if deps are unavailable
  export PKG_CONFIG_PATH=`opam config var prefix`/lib/pkgconfig
fi

check_deps || exit 1
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

# These are needed by https://github.com/ocaml/ocaml/blob/4.07.1/byterun/caml/stack.h
case `uname -m` in
armv*)
  TARGET_ARCH="arm"
 ;;
i386|i486|i586|i686)
  TARGET_ARCH="i386"
  ;;
x86_64)
  TARGET_ARCH="amd64"
  ;;
*)
  echo Unsupported architecture
  exit 1
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
  -fno-builtin-fprintf -Werror=format \
  $(pkg-config --cflags $PKG_CONFIG_DEPS) \
  "

rm -rf ocaml-src
cp -r `ocamlfind query ocaml-src` ocaml-src
chmod -R u+w ocaml-src

OCAMLOPT_VERSION=$(ocamlopt -version)
echo Detected OCaml version $OCAMLOPT_VERSION
case $OCAMLOPT_VERSION in
4.04.2)
  echo Applying OCaml 4.04 config
  cp config/version-404.h ocaml-src/byterun/caml/version.h
  S_H_LOCATION="ocaml-src/config/"
  BIGARRAY_OBJ="bigarray_stubs.o mmap_unix.o"
  ;;
4.05.*)
  echo Applying OCaml 4.05 config
  cp config/version-405.h ocaml-src/byterun/caml/version.h
  S_H_LOCATION="ocaml-src/config/"
  BIGARRAY_OBJ="bigarray_stubs.o mmap_unix.o"
  CFLAGS="-D__ANDROID__ $CFLAGS"
  ;;
4.06.0)
  echo Applying OCaml 4.06.0 config
  cp config/version-4060.h ocaml-src/byterun/caml/version.h
  S_H_LOCATION="ocaml-src/byterun/caml/"
  BIGARRAY_OBJ="bigarray_stubs.o mmap.o mmap_ba.o"
  CFLAGS="-D__ANDROID__ $CFLAGS"
  ;;
4.06.*)
  echo Applying OCaml 4.06.1 config
  cp config/version-4061.h ocaml-src/byterun/caml/version.h
  S_H_LOCATION="ocaml-src/byterun/caml/"
  BIGARRAY_OBJ="bigarray_stubs.o mmap.o mmap_ba.o"
  CFLAGS="-D__ANDROID__ $CFLAGS"
  ;;
4.07.0)
  echo Applying OCaml 4.07.0 config
  cp config/version-4070.h ocaml-src/byterun/caml/version.h
  S_H_LOCATION="ocaml-src/byterun/caml/"
  BIGARRAY_OBJ="mmap.o mmap_ba.o"
  CFLAGS="-D__ANDROID__ $CFLAGS"
  ;;
4.07.*)
  echo Applying OCaml 4.07.1 config
  cp config/version-4071.h ocaml-src/byterun/caml/version.h
  S_H_LOCATION="ocaml-src/byterun/caml/"
  BIGARRAY_OBJ="mmap.o mmap_ba.o"
  CFLAGS="-D__ANDROID__ $CFLAGS"
  ;;
4.08.*)
  echo Applying OCaml 4.08.0 config
  cp config/version-4080.h ocaml-src/runtime/caml/version.h
  S_H_LOCATION="ocaml-src/runtime/caml/"
  BIGARRAY_OBJ="mmap.o mmap_ba.o"
  CFLAGS="-D__ANDROID__ $CFLAGS"
  ;;
*)
  echo unsupported OCaml version $OCAMLOPT_VERSION
  exit 1
  ;;
esac

cd ocaml-src && ./configure && cd ..
cp config/s.h $S_H_LOCATION

cd ocaml-src

# cd byterun && make BYTECCCOMPOPTS="${CFLAGS}" BYTECCCOMPOPTS="${CFLAGS}" libcamlrun.a && cd ..

case $OCAMLOPT_VERSION in
4.04.2|4.05.*)
  cd asmrun && make -j${NJOBS} UNIX_OR_WIN32=unix NATIVECCCOMPOPTS="-DNATIVE_CODE ${CFLAGS}" NATIVECCPROFOPTS="-DNATIVE_CODE ${CFLAGS}" libasmrun.a && cd ..
  ;;
4.06.*|4.07.*)
  cd asmrun && make -j${NJOBS} UNIX_OR_WIN32=unix CPPFLAGS="-DNATIVE_CODE ${CFLAGS} -I../byterun -DTARGET_${TARGET_ARCH}" NATIVECCPROFOPTS="-DNATIVE_CODE ${CFLAGS}" libasmrun.a && cd ..
  ;;
4.08.*)
  cd runtime && make -j${NJOBS} UNIX_OR_WIN32=unix CPPFLAGS="-DNATIVE_CODE ${CFLAGS} -DTARGET_${TARGET_ARCH}" NATIVECCPROFOPTS="-DNATIVE_CODE ${CFLAGS}" libasmrun.a && cd ..
  ;;
*)
  echo unsupported OCaml version $OCAMLOPT_VERSION
  exit 1
  ;;
esac
# This directory doesn't really exist on 4.08, but it's also unneeded, so it's
# effectively harmless to leave it here.
CFLAGS="$CFLAGS -I../../byterun"
cd otherlibs/bigarray && make CFLAGS="${CFLAGS} -I../unix -DIN_OCAML_BIGARRAY" ${BIGARRAY_OBJ}
ar rcs ../../libxenotherlibs.a ${BIGARRAY_OBJ}

cd ../../..

echo "($(pkg-config libminios-xen --libs)$(pkg-config openlibm --libs)$(cat flags/libs.tmp))" > flags/libs
echo "($(pkg-config libminios-xen --cflags)$(pkg-config openlibm --cflags)$(cat flags/cflags.tmp))" > flags/cflags
