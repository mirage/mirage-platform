.PHONY: build

build:
	cd core && $(MAKE) build && $(MAKE) install
	cd bindings && $(MAKE) build && $(MAKE) install

uninstall:
	cd bindings && $(MAKE) uninstall
	cd core && $(MAKE) uninstall
