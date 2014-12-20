.PHONY: all _config build install uninstall doc clean

OPAM_PREFIX := $(shell opam config var prefix)

PKG_CONFIG_PATH = $(OPAM_PREFIX)/lib/pkgconfig
export PKG_CONFIG_PATH

EXTRA=runtime/xencaml/libxencaml.a runtime/ocaml/libocaml.a
EXTRA_HEADERS=runtime/config runtime/ocaml runtime/include

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
	rm -rf $(XEN_INCLUDE)
	./cmd install
	mkdir -p $(XEN_LIB) $(XEN_INCLUDE)
	for l in $(EXTRA); do cp _build/$$l $(XEN_LIB); done
	cp -r $(EXTRA_HEADERS) $(XEN_INCLUDE)
	cp mirage-xen.pc $(OPAM_PREFIX)/lib/pkgconfig/

uninstall:
	./cmd uninstall
	rm -rf $(XEN_INCLUDE)

doc: _config
	./cmd doc

clean:
	./cmd clean
