TARGET=jquery.observable.js jquery.views.js

-include ../../Makefile.include

git:
	git clone https://github.com/BorisMoore/jsviews.git git

ifneq (,$(wildcard git))
jquery.observable.uncompressed.js: git/jquery.observable.js
	cp $< $@

jquery.views.uncompressed.js: git/jquery.views.js
	cp $< $@
endif

clean: 
	rm -f $(TARGET) *.gz
