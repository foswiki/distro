TARGET= \
  jquery.superfish.js \
  jquery.superfish.css \
  jquery.superfish-navbar.css \
  jquery.superfish-vertical.css \
  jquery.superfish-megafish.css \
  $(JQUERYPLUGIN_LIB)/SUPERFISH.pm \
  $(JQUERYPLUGIN_LIB)/SUPERFISH.pm

-include ../../Makefile.include

git:
	git clone https://github.com/joeldbirch/superfish.git git

ifneq (,$(wildcard git))
jquery.superfish.uncompressed.js: git/dist/js/superfish.js
	cp $^ $@

jquery.superfish.uncompressed.css: git/dist/css/superfish.css
	cp $^ $@

jquery.superfish-navbar.uncompressed.css: git/dist/css/superfish-navbar.css
	cp $^ $@

jquery.superfish-vertical.uncompressed.css: git/dist/css/superfish-vertical.css
	cp $^ $@

jquery.superfish-megafish.uncompressed.css: git/dist/css/megafish.css
	cp $^ $@
endif

clean: 
	rm -f $(TARGET) *.gz
