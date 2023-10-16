TARGET=pkg.js slimbox2.css
PKG_SOURCE=slimbox2.uncompressed.js slimbox2.init.uncompressed.js

-include ../../Makefile.include

git: 
	git clone https://github.com/cbeyls/slimbox.git $@

ifneq (,$(wildcard git))
slimbox2.uncompressed.js: git/js/slimbox2.js
	cp $^ $@

slimbox2.uncompressed.css: git/css/slimbox2.css
	cp $^ $@

%.gif: git/css/%.gif
	cp $^ $@
endif

clean:
	rm -f $(TARGET) *gz pkg.uncompressed.js

pkg.uncompressed.js: $(PKG_SOURCE)
	@echo generating $@
	@$(CAT) $^ > $@
