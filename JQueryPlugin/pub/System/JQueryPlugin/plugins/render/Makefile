TARGET=jquery.render.js jquery.template-loader.js

-include ../../Makefile.include

jquery.render.uncompressed.js: git/jsrender.js
	cp $< $@

clean: 
	rm -f $(TARGET) *.gz
