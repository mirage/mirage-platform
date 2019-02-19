#!/bin/sh -ex

PKG_CONFIG_DEPS="openlibm libminios-xen >= 0.5"
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
 ;;
*)
  ARCH_CFLAGS="-D__x86_64__ -momit-leaf-frame-pointer -mfancy-math-387"
  ;;
esac

# This extra flag only needed for gcc 4.8+
GCC_MVER2=`gcc -dumpversion | cut -f2 -d.`
if [ $GCC_MVER2 -ge 8 ]; then
  EXTRA_CFLAGS="-fno-tree-loop-distribute-patterns -fno-stack-protector"
fi

# TODO: remove -Wno-sign-compare
CC=${CC:-cc}
PWD=`pwd`
CFLAGS="$EXTRA_CFLAGS ${CI_CFLAGS} -I ${PWD}/include/ -I ${PWD}/src/ \
    -D__XEN_INTERFACE_VERSION__=0x00030205 -D__INSIDE_MINIOS__ \
    $(pkg-config --cflags $PKG_CONFIG_DEPS) \
    -Wextra -Wchar-subscripts -Wno-switch -Wno-unused -Wredundant-decls -Wall \
    -Wno-sign-compare -Werror=unused-variable \
    -fno-builtin ${ARCH_CFLAGS}"

${CC} -c ${CFLAGS} src/*.c
ar rcs libxenposix.a mini_libc.o fmt_fp.o dtoa.o strtol.o

echo "($(pkg-config libminios-xen --libs)$(pkg-config openlibm --libs)$(cat flags/minios-libs.tmp))" > flags/minios-libs
echo "($(pkg-config libminios-xen --cflags)$(pkg-config openlibm --cflags)$(cat flags/minios-cflags.tmp))" > flags/minios-cflags
echo "($(pkg-config libminios-xen --libs)$(pkg-config openlibm --libs)$(cat flags/posix-libs.tmp))" > flags/posix-libs
echo "($(pkg-config libminios-xen --cflags)$(pkg-config openlibm --cflags)$(cat flags/posix-cflags.tmp))" > flags/posix-cflags
