TARGET=\
  jquery.scrollTo.js \
  jquery.scrollTo.init.js \
  $(JQUERYPLUGIN_LIB)/SCROLLTO.pm

-include ../../Makefile.include

git: 
	git clone https://github.com/flesler/jquery.scrollTo.git $@

ifneq (,$(wildcard git))
jquery.scrollTo.uncompressed.js: git/jquery.scrollTo.js
	cat $^ > $@
endif
