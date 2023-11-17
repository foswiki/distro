TARGET=pkg.js
PKG_SOURCE= jquery.scrollTo.uncompressed.js jquery.scrollTo.init.uncompressed.js

-include ../../Makefile.include

clean:
	rm -f $(TARGET) *gz pkg.uncompressed.js

git: 
	git clone https://github.com/flesler/jquery.scrollTo.git $@

ifneq (,$(wildcard git))
jquery.scrollTo.uncompressed.js: git/jquery.scrollTo.js
	cat $^ > $@
endif

pkg.uncompressed.js: $(PKG_SOURCE)
	@echo generating $@
	@$(CAT) $^ > $@
