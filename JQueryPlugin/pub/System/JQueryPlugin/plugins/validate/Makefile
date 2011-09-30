TARGET=\
  jquery.validate.js \
  jquery.validate.methods.js \
  jquery.validate.init.js \
  $(JQUERYPLUGIN_LIB)/VALIDATE.pm

-include ../../Makefile.include

jquery.validate.methods.uncompressed.js: \
  jquery.validate.additional-methods.uncompressed.js \
  jquery.validate.foswiki-methods.uncompressed.js
	@echo creating validation methods
	@$(CAT) $+ > $@
