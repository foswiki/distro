TARGET=jquery.browser.js 

-include ../../Makefile.include

git:
	git clone https://github.com/gabceb/jquery-browser-plugin.git git

ifneq (,$(wildcard git))
jquery.browser.uncompressed.js: git/dist/jquery.browser.js
	cp $< $@

endif

clean: 
	rm -f $(TARGET) *.gz
