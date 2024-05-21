TARGET=treeview.js treeview.css jquery.treeview.async.js

-include ../../Makefile.include

clean:
	rm -f $(TARGET) *.gz

treeview.css: jquery.treeview.uncompressed.css foswiki.uncompressed.css
	@echo "generating $@"
	@cat $^ | $(CSSMIN) $(CSSMIN_ARGS)> $@
	
treeview.js: jquery.treeview.js jquery.treeview.async.js jquery.treeview.init.js
	@echo "generating $@"
	@$(JSMIN) $^ > $@	
