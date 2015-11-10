TARGET=sprintf.js 

-include ../../Makefile.include

.PHONY: git

git:
	git clone https://github.com/alexei/sprintf.js.git git

sprintf.uncompressed.js: git/src/sprintf.js
	cp $< $@

clean: 
	rm -f $(TARGET) *.gz
