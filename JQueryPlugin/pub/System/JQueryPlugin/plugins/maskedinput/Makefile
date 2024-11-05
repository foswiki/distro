TARGET=pkg.js
-include ../../Makefile.include

git: 
	git clone https://github.com/digitalBush/jquery.maskedinput.git $@

ifneq (,$(wildcard git))
pkg.uncompressed.js: git/dist/jquery.maskedinput.js jquery.maskedinput.init.uncompressed.js
	cat $^ > $@
endif
