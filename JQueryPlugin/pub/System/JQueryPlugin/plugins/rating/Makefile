TARGET=pkg.js jquery.rating.css 
PKG_SOURCE=jquery.rating.js jquery.rating.init.js

-include ../../Makefile.include

clean:
	rm -f $(TARGET) *gz pkg.uncompressed.js

pkg.uncompressed.js: $(PKG_SOURCE)
	@echo generating $@
	@$(CAT) $^ > $@
