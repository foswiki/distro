TARGET=imagesloaded.js

-include ../../Makefile.include

git: 
	git clone https://github.com/desandro/imagesloaded.git $@

ifneq (,$(wildcard git))
imagesloaded.uncompressed.js: git/imagesloaded.pkgd.js 
	cat $^ > $@
endif
