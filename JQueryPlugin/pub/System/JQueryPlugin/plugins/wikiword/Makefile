TARGET=\
  wikiword.js \
  $(JQUERYPLUGIN_LIB)/WIKIWORD.pm

DOWNGRADEMAP=downgradeMap.small.uncompressed.js

-include ../../Makefile.include

wikiword.uncompressed.js: jquery.wikiword.uncompressed.js $(DOWNGRADEMAP)
	@echo "generating $@"
	@$(CAT) $^ > $@
