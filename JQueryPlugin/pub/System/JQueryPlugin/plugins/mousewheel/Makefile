TARGET=jquery.mousewheel.js 

-include ../../Makefile.include

git:
	git clone https://github.com/jquery/jquery-mousewheel.git git

ifneq (,$(wildcard git))
jquery.mousewheel.uncompressed.js: git/jquery.mousewheel.js
	cp $^ $@
endif

clean: 
	rm -f $(TARGET) *.gz

