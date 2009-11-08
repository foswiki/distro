TARGET=jquery.superfish.js ../supersubs/jquery.supersubs.js jquery.superfish.css jquery.superfish-navbar.css jquery.superfish-vertical.css $(JQUERYPLUGIN_LIB)/SUPERFISH.pm $(JQUERYPLUGIN_LIB)/SUPERFISH.pm
-include ../../Makefile.include

upstream: copyupstream patch all

copyupstream:
	cp superfish-1.4.8/css/superfish.css jquery.superfish.uncompressed.css
	cp superfish-1.4.8/css/superfish-navbar.css jquery.superfish-navbar.uncompressed.css
	cp superfish-1.4.8/css/superfish-vertical.css jquery.superfish-vertical.uncompressed.css
	cp superfish-1.4.8/js/superfish.js jquery.superfish.uncompressed.js
	cp superfish-1.4.8/js/supersubs.js ../supersubs/jquery.supersubs.uncompressed.js
	cp superfish-1.4.8/images/arrows-ffffff.png MenuArrow.png
	cp superfish-1.4.8/images/shadow.png MenuShadow.png

patch:
	patch -p0 < jquery.superfish.uncompressed.css.diff
