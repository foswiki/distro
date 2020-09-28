FOSWIKI_ROOT?=~/foswiki/core
TARGET=pkg.js localization
PKG_JS_SOURCE=jquery.validate.uncompressed.js jquery.validate.methods.uncompressed.js jquery.validate.init.uncompressed.js

-include $(FOSWIKI_ROOT)/pub/System/JQueryPlugin/Makefile.include

git:
	git clone https://github.com/jquery-validation/jquery-validation.git git && cd git && npm install && grunt

ifneq (,$(wildcard git))
jquery.validate.uncompressed.js: git/dist/jquery.validate.js
	@echo getting $@
	@cp $^ $@

jquery.validate.additional-methods.uncompressed.js: git/dist/additional-methods.js
	@echo getting $@
	@cp $^ $@

localization: git/dist/localization
	@echo getting localization
	@cp $^/* $@
endif

jquery.validate.methods.uncompressed.js: \
  jquery.validate.additional-methods.uncompressed.js \
  jquery.validate.foswiki-methods.uncompressed.js
	@echo creating validation methods
	@$(CAT) $+ > $@

pkg.uncompressed.js: $(PKG_JS_SOURCE)
	@echo creating pkg
	@$(CAT) $(PKG_JS_SOURCE) > $@

clean:
	rm -f $(TARGET) *.gz jquery.validate.methods.uncompressed.js pkg.uncompressed.js localization/*js

