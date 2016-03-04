TARGET=jquery.serialScroll.js 

-include ../../Makefile.include

git: 
	git clone https://github.com/flesler/jquery.serialScroll.git $@

ifneq (,$(wildcard git))
jquery.serialScroll.uncompressed.js: git/jquery.serialScroll.js
	cat $^ > $@
endif
