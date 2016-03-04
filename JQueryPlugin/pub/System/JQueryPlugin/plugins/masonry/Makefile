TARGET=jquery.masonry.js

-include ../../Makefile.include

git: 
	git clone https://github.com/desandro/masonry.git $@

ifneq (,$(wildcard git))
jquery.masonry.uncompressed.js: git/dist/masonry.pkgd.js jquery.masonry.init.uncompressed.js
	cat $^ > $@
endif
