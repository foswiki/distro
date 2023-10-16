TARGET=pkg.js jquery.farbtastic.css 
PKG_SOURCE=jquery.farbtastic.uncompressed.js jquery.farbtastic.init.uncompressed.js

-include ../../Makefile.include

clean:
	rm -f $(TARGET) *gz pkg.uncompressed.js

pkg.uncompressed.js: $(PKG_SOURCE)
	@echo generating $@
	@$(CAT) $^ > $@
