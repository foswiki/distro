TARGET=jquery.form.js $(JQUERYPLUGIN_LIB)/FORM.pm
-include ../../Makefile.include

git: 
	git clone https://github.com/malsup/form.git $@

ifneq (,$(wildcard git))
jquery.form.uncompressed.js: git/jquery.form.js
	cat $^ > $@
endif
