TARGET=\
  jquery.localscroll.js \
  $(JQUERYPLUGIN_LIB)/LOCALSCROLL.pm

-include ../../Makefile.include

git: 
	git clone https://github.com/flesler/jquery.localScroll.git $@

ifneq (,$(wildcard git))
jquery.localscroll.uncompressed.js: git/jquery.localScroll.js
	cat $^ > $@
endif
