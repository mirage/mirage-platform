.PHONY: all _config build install uninstall doc clean

PKG_CONFIG_PATH = $(shell opam config var prefix)/lib/pkgconfig
export PKG_CONFIG_PATH

EXTRA=runtime/xencaml/libxencaml.a runtime/ocaml/libocaml.a

OCAMLFIND ?= ocamlfind

XEN_LIB = $(shell ocamlfind printconf path)/mirage-xen

all: build

_config:
	./cmd configure xen

build: _config
	./cmd build
	ocamlbuild $(EXTRA)

install:
	./cmd install
	mkdir -p $(XEN_LIB)
	for l in $(EXTRA); do cp _build/$$l $(XEN_LIB); done

uninstall:
	./cmd uninstall

doc: _config
	./cmd doc

clean:
	./cmd clean
