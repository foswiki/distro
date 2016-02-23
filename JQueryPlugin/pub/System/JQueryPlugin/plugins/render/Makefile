TARGET=jquery.render.js jquery.template-loader.js

-include ../../Makefile.include

git:
	git clone https://github.com/BorisMoore/jsviews.git git

ifneq (,$(wildcard git))
jquery.render.uncompressed.js: git/jsrender.js
	cp $< $@
endif

clean: 
	rm -f $(TARGET) *.gz
