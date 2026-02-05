TARGET=pkg.js
-include ../../Makefile.include

git: 
	git clone https://github.com/digitalBush/jquery.maskedinput.git $@

ifneq (,$(wildcard git))
jquery.maskedinput.uncompressed.js: git/dist/jquery.maskedinput.js
	cp $^ $@

pkg.uncompressed.js: jquery.maskedinput.uncompressed.js jquery.maskedinput.init.uncompressed.js
	cat $^ > $@
endif

clean:
	rm -f $(TARGET) *gz
