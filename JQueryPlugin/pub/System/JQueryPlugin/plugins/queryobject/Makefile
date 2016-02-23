TARGET=jquery.queryobject.js 

-include ../../Makefile.include

clean:
	rm -f $(TARGET) *.gz

git: 
	git clone https://github.com/alrusdi/jquery-plugin-query-object.git $@

ifneq (,$(wildcard git))
jquery.queryobject.uncompressed.js: git/jquery.query-object.js
	cat $^ > $@
endif
