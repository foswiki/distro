TARGET=pkg.js
PKG_SOURCE=jquery.innerfade.uncompressed.js jquery.innerfade.init.uncompressed.js

-include ../../Makefile.include

clean:
	rm -f $(TARGET) *gz pkg.uncompressed.js

pkg.uncompressed.js: $(PKG_SOURCE)
	@echo generating $@
	@$(CAT) $^ > $@
