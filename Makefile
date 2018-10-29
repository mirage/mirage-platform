.PHONY: all build clean install test
.DEFAULT: all

all:	build
	@ :

xen-ocaml-build:
	cd xen-ocaml && $(MAKE) build

xen-ocaml-install:
	cd xen-ocaml && $(MAKE) install

xen-ocaml-uninstall:
	cd xen-ocaml && $(MAKE) uninstall

xen-posix-build:
	cd xen-posix && $(MAKE) build

xen-posix-install:
	cd xen-posix && $(MAKE) install

xen-posix-uninstall:
	cd xen-posix && $(MAKE) uninstall
