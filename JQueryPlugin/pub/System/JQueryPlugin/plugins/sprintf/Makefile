TARGET=sprintf.js 

-include ../../Makefile.include

git:
	git clone https://github.com/alexei/sprintf.js.git git

ifneq (,$(wildcard git))
sprintf.uncompressed.js: git/src/sprintf.js
	cp $< $@
endif

clean: 
	rm -f $(TARGET) *.gz
