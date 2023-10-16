TARGET=pkg.js

-include ../../Makefile.include

PKG_SOURCE=jquery.cycle.uncompressed.js jquery.cycle.init.uncompressed.js

clean:
	rm -f $(TARGET) *gz pkg.uncompressed.js

pkg.uncompressed.js: $(PKG_SOURCE)
	@echo generating $@
	@$(CAT) $^ > $@
