TARGET=pkg.js
PKG_SOURCE=jquery.observable.uncompressed.js jquery.views.uncompressed.js

-include ../../Makefile.include

pkg.js: $(PKG_SOURCE)
	@echo minifying $@ from $^; $(JSMIN) $^ > $@

clean: 
	rm -f $(TARGET) *.gz

git:
	git clone https://github.com/BorisMoore/jsviews.git git

ifneq (,$(wildcard git))
jquery.observable.uncompressed.js: git/jquery.observable.js
	cp $< $@

jquery.views.uncompressed.js: git/jquery.views.js
	cp $< $@
endif

