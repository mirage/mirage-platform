.PHONY: all _config build install uninstall doc clean

OPAM_PREFIX := $(shell opam config var prefix)

PKG_CONFIG_PATH = $(OPAM_PREFIX)/lib/pkgconfig
export PKG_CONFIG_PATH

OCAMLFIND ?= ocamlfind

XEN_LIB = $(shell ocamlfind printconf destdir)/mirage-xen
XEN_INCLUDE = $(OPAM_PREFIX)/include/mirage-xen

all: build

_config:
	./cmd configure xen

build: _config
	./cmd build
	ocamlbuild $(EXTRA)

install:
	./cmd install
	cp mirage-xen.pc $(OPAM_PREFIX)/lib/pkgconfig/

uninstall:
	./cmd uninstall
	rm -f $(OPAM_PREFIX)/lib/pkgconfig/mirage-xen.pc

doc: _config
	./cmd doc

clean:
	./cmd clean
