TARGET=jquery.treeview.js jquery.treeview.css
-include ../../Makefile.include

JS_SOURCES=\
  jquery.treeview.uncompressed.js \
  jquery.treeview.init.uncompressed.js

jquery.treeview.js: $(JS_SOURCES)
	@echo creating $@ 
	@$(MINIFYJS) $(JS_SOURCES) > $@
