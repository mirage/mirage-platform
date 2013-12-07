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

xen-%:
	$(MAKE) OS=xen PREFIX=$(PREFIX) $*
