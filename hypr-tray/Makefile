PREFIX ?= $(HOME)/.local

install:
	cargo build --release
	install -Dm755 target/release/hypr-tray $(DESTDIR)$(PREFIX)/bin/hypr-tray

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/hypr-tray

.PHONY: install uninstall
