TARGET=git jquery.mousewheel.js 

-include ../../Makefile.include

git:
	git clone https://github.com/jquery/jquery-mousewheel.git git

jquery.mousewheel.uncompressed.js: git/jquery.mousewheel.js
	cp $^ $@

clean: 
	rm -f $(TARGET) *.gz

