TARGET=pkg.js
PKG_SOURCE=jquery.chili.uncompressed.js jquery.chili.init.uncompressed.js

-include ../../Makefile.include

clean:
	rm -f $(TARGET) *gz pkg.uncompressed.js

pkg.uncompressed.js: $(PKG_SOURCE)
	@echo generating $@
	@$(CAT) $^ > $@
