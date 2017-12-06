TARGET=pkg.js
PKG_JS_SOURCE=jquery.validate.uncompressed.js jquery.validate.methods.uncompressed.js jquery.validate.init.uncompressed.js

-include ../../Makefile.include

jquery.validate.methods.uncompressed.js: \
  jquery.validate.additional-methods.uncompressed.js \
  jquery.validate.foswiki-methods.uncompressed.js
	@echo creating validation methods
	@$(CAT) $+ > $@

pkg.uncompressed.js: $(PKG_JS_SOURCE)
	@echo creating pkg
	@$(CAT) $(PKG_JS_SOURCE) > $@

clean:
	rm -f $(TARGET) *.gz jquery.validate.methods.uncompressed.js pkg.uncompressed.js

