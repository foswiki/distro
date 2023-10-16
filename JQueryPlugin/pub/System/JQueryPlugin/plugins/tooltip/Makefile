TARGET=pkg.js jquery.tooltip.css 
PKG_SOURCE= jquery.tooltip.uncompressed.js jquery.tooltip.init.uncompressed.js

-include ../../Makefile.include

clean:
	rm -f $(TARGET) *gz pkg.uncompressed.js

pkg.uncompressed.js: $(PKG_SOURCE)
	@echo generating $@
	@$(CAT) $^ > $@
