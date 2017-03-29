FOSWIKI_ROOT?=~/foswiki/core
TARGET= engine.js
SOURCE = textareastate.uncompressed.js undomanager.uncompressed.js rawengine.uncompressed.js


-include $(FOSWIKI_ROOT)/pub/System/JQueryPlugin/Makefile.include

engine.uncompressed.js: $(SOURCE)
	@echo creating $@; echo "/* WARNING: this file is auto-created from $^ */" > $@; $(CAT) $^ >> $@; \

jslint_src: $(SOURCE:.uncompressed.js=.jslint) 
	@echo -n ""

jslint: jslint_src
