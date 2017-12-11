TARGET=\
  jquery.livequery.js \
  $(JQUERYPLUGIN_LIB)/LIVEQUERY.pm

-include ../../Makefile.include

git: 
	git clone https://github.com/hazzik/livequery.git $@

ifneq (,$(wildcard git))
jquery.livequery.uncompressed.js: git/dist/jquery.livequery.js
	cat $^ > $@
endif
