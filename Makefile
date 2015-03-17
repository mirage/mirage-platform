OS ?= unix

PREFIX ?= /usr/local

ifneq "$(MIRAGE_OS)" ""
OS := $(MIRAGE_OS)
endif

.PHONY: all build clean install test
.DEFAULT: all

all:	build
	@ :

build:
	cd $(OS) && $(MAKE) all MIRAGE_OS=$(OS)

clean:
	cd $(OS) && $(MAKE) clean MIRAGE_OS=$(OS)

install:
	cd $(OS) && $(MAKE) install MIRAGE_OS=$(OS)

uninstall:
	cd $(OS) && $(MAKE) uninstall MIRAGE_OS=$(OS)

test:
	cd $(OS) && $(MAKE) test MIRAGE_OS=$(OS)

doc:
	cd $(OS) && $(MAKE) doc MIRAGE_OS=$(OS)

unix-%:
	$(MAKE) OS=unix PREFIX=$(PREFIX) $*

xen-build:
	cd xen && $(MAKE)
	cd bindings && $(MAKE) build

xen-install:
	cd xen && $(MAKE) install
	cd bindings && $(MAKE) install

xen-uninstall:
	ocamlfind remove mirage-xen || true
	cd bindings && $(MAKE) uninstall

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


VERSION = $(shell grep 'VERSION=' unix/_vars | sed 's/VERSION=*//')
ARCHIVE = https://github.com/mirage/mirage-platform/archive/v$(VERSION).tar.gz

release:
	git tag -a v$(VERSION) -m "Version $(VERSION)."
	git push upstream v$(VERSION)
	$(MAKE) pr

pr:
	opam pin add mirage-$(OS) . -n
	opam publish prepare mirage-$(OS).$(VERSION) $(ARCHIVE)
	opam unpin mirage-$(OS) -n
	OPAMPUBLISHBYPASSCHECKS=1 OPAMYES=1 \
	  opam publish submit mirage-$(OS).$(VERSION) \
	  && rm -rf mirage-$(OS).$(VERSION)
