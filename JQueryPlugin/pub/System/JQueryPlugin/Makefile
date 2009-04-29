SUBDIRS=i18n plugins themes ui
TARGET=jquery-all.js
#JQUERY_VERSION=jquery-1.3.2.js
JQUERY_VERSION=jquery-1.3.2p1.js
JQUERY_VERSION=jquery-1.2.6.js

JS_SOURCES=\
  jquery.js \
  plugins/easing/jquery.easing.js \
  plugins/metadata/jquery.metadata.js \
  plugins/bgiframe/jquery.bgiframe.js \
  plugins/hoverIntent/jquery.hoverIntent.js \
  plugins/foswiki/jquery.foswiki.js

-include Makefile.include
jquery-all.js: $(JS_SOURCES) Makefile
	@echo creating $@
	@$(MINIFYJS) $(JS_SOURCES) > $@

jquery-1.3.2p1.js: jquery-1.3.2.js jquery.patch
	@echo patching $<
	@$(PATCH) -i jquery.patch -o $@

jquery.uncompressed.js: $(JQUERY_VERSION) Makefile
	@$(CAT) $< > $@
