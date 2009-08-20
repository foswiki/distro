SUBDIRS=i18n plugins themes ui
TARGET=jquery-1.2.6.js jquery-1.3.2.js jquery-1.3.2p1.js

JS_SOURCES=\
  jquery-1.2.6.js \
  plugins/easing/jquery.easing.js \
  plugins/metadata/jquery.metadata.js \
  plugins/bgiframe/jquery.bgiframe.js \
  plugins/hoverintent/jquery.hoverIntent.js \
  plugins/foswiki/jquery.foswiki.js

-include Makefile.include

jquery-1.3.2p1.uncompressed.js: jquery-1.3.2.uncompressed.js jquery.patch
	@echo patching $<
	@$(PATCH) -i jquery.patch -o $@
