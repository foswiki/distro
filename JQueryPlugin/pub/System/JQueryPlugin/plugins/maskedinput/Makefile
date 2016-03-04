TARGET=jquery.maskedinput.js jquery.maskedinput.init.js $(JQUERYPLUGIN_LIB)/MASKEDINPUT.pm
-include ../../Makefile.include

git: 
	git clone https://github.com/digitalBush/jquery.maskedinput.git $@

ifneq (,$(wildcard git))
jquery.maskedinput.uncompressed.js: git/dist/jquery.maskedinput.js
	cat $^ > $@
endif
