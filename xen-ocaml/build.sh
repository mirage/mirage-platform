#!/bin/sh -ex

PREFIX=${1:-$PREFIX}
if [ "$PREFIX" = "" ]; then
  PREFIX="$(opam config var prefix)"
fi

MJOBS=${4:-NJOBS}
PKG_CONFIG_DEPS="mirage-xen-posix openlibm libminios-xen >= 0.5"
check_deps () {
  pkg-config --print-errors --exists ${PKG_CONFIG_DEPS}
}

if ! check_deps 2>/dev/null; then
  # only rely on `opam` if deps are unavailable
  export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig"
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
  BIGARRAY_OBJ=""
  CFLAGS="-D__ANDROID__ $CFLAGS"
  CONFIGURE_OPTS="--disable-vmthreads --disable-systhreads --disable-graph-lib --disable-str-lib --disable-unix-lib --disable-ocamldoc"
  ;;
4.09.*)
  echo Applying OCaml 4.09.0 config
  cp config/version-4090.h ocaml-src/runtime/caml/version.h
  S_H_LOCATION="ocaml-src/runtime/caml/"
  BIGARRAY_OBJ=""
  CFLAGS="-D__ANDROID__ $CFLAGS"
  CONFIGURE_OPTS="--disable-systhreads --disable-str-lib --disable-unix-lib --disable-ocamldoc"
  ;;
4.10.*)
  echo Applying OCaml 4.10.0 config
  cp config/version-4100.h ocaml-src/runtime/caml/version.h
  S_H_LOCATION="ocaml-src/runtime/caml/"
  BIGARRAY_OBJ=""
  CFLAGS="-D__ANDROID__ $CFLAGS"
  CONFIGURE_OPTS="--disable-systhreads --disable-str-lib --disable-unix-lib --disable-ocamldoc"
  ;;
4.11.*)
  echo Applying OCaml 4.11.0 config
  cp config/version-4110.h ocaml-src/runtime/caml/version.h
  S_H_LOCATION="ocaml-src/runtime/caml/"
  BIGARRAY_OBJ=""
  CFLAGS="-D__ANDROID__ $CFLAGS"
  CONFIGURE_OPTS="--disable-systhreads --disable-str-lib --disable-unix-lib --disable-ocamldoc"
  ;;
*)
  echo unsupported OCaml version $OCAMLOPT_VERSION
  exit 1
  ;;
esac

cd ocaml-src && ./configure ${CONFIGURE_OPTS} && cd ..
cp config/s.h $S_H_LOCATION

cd ocaml-src

case $OCAMLOPT_VERSION in
4.04.2|4.05.*)
  cd asmrun && make -j${NJOBS} UNIX_OR_WIN32=unix NATIVECCCOMPOPTS="-DNATIVE_CODE ${CFLAGS}" NATIVECCPROFOPTS="-DNATIVE_CODE ${CFLAGS}" libasmrun.a && cd ..
  IS_408_OR_MORE=0
  ;;
4.06.*|4.07.*)
  cd asmrun && make -j${NJOBS} UNIX_OR_WIN32=unix CPPFLAGS="-DNATIVE_CODE ${CFLAGS} -I../byterun -DTARGET_${TARGET_ARCH}" NATIVECCPROFOPTS="-DNATIVE_CODE ${CFLAGS}" libasmrun.a && cd ..
  IS_408_OR_MORE=0
  ;;
4.08.*|4.09.*|4.10.*|4.11.*)
  cd runtime && make -j${NJOBS} UNIX_OR_WIN32=unix OC_NATIVE_CPPFLAGS="-DNATIVE_CODE -DXXXX=1 ${CFLAGS} -DTARGET_${TARGET_ARCH}" libasmrun.a && cd ..
  IS_408_OR_MORE=1
  ;;
*)
  echo unsupported OCaml version $OCAMLOPT_VERSION
  exit 1
  ;;
esac

if [ $IS_408_OR_MORE -eq 0 ]; then
  CFLAGS="$CFLAGS -I../../byterun"
  cd otherlibs/bigarray && make CFLAGS="${CFLAGS} -I../unix -DIN_OCAML_BIGARRAY" ${BIGARRAY_OBJ}
  ar rcs ../../libxenotherlibs.a ${BIGARRAY_OBJ}
  cd ../..
else
  ar rcs libxenotherlibs.a
fi

cd ..

echo "($(cat flags/libs.tmp) -cclib \"$(pkg-config libminios-xen openlibm --libs | xargs)\")" > flags/libs
echo "($(pkg-config libminios-xen openlibm --cflags | xargs) $(cat flags/cflags.tmp))" > flags/cflags
