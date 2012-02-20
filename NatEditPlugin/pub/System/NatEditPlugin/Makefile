FOSWIKI_ROOT?=~/foswiki/trunk/core
TARGET= \
  edit.js \
  natedit.js \
  styles.css

NATEDIT_SOURCE=\
  jquery.natedit.uncompressed.js \
  jquery.natedit.insertlink.uncompressed.js \
  jquery.natedit.inserttable.uncompressed.js

SUBDIRS=default

-include $(FOSWIKI_ROOT)/pub/System/JQueryPlugin/Makefile.include

natedit.uncompressed.js: $(NATEDIT_SOURCE)
	@echo generating $@
	@$(CAT) $(NATEDIT_SOURCE) > $@
