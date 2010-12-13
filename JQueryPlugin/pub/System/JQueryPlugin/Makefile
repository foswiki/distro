SUBDIRS=i18n plugins themes ui
TARGET=\
  jquery-1.3.2.js \
  jquery-1.3.2p1.js \
  jquery-1.4.2.js \
  jquery-1.4.3.js \
  jquery-1.4.4.js

-include Makefile.include

jquery-1.3.2p1.uncompressed.js: jquery-1.3.2.uncompressed.js jquery.patch
	@echo patching $<
	@$(PATCH) -i jquery.patch -o $@
