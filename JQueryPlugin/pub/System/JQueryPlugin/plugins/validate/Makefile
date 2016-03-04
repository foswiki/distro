TARGET=jquery.validate.js jquery.validate.methods.js jquery.validate.init.js 

-include ../../Makefile.include

jquery.validate.methods.uncompressed.js: \
  jquery.validate.additional-methods.uncompressed.js \
  jquery.validate.foswiki-methods.uncompressed.js
	@echo creating validation methods
	@$(CAT) $+ > $@


clean:
	rm -f $(TARGET) *.gz jquery.validate.methods.uncompressed.js

