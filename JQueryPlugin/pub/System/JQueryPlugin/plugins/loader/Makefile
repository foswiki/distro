TARGET=pkg.js

-include ../../Makefile.include

PKG_SOURCE=loader.uncompressed.js button.uncompressed.js

pkg.uncompressed.js: $(PKG_SOURCE)
	@$(CAT) $^ > $@

clean:
	rm -f $(TARGET) *gz
