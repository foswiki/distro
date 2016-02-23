FOSWIKI_ROOT?=~/foswiki/core
TARGET=animate.css animate.js

-include $(FOSWIKI_ROOT)/pub/System/JQueryPlugin/Makefile.include

git: 
	git clone https://github.com/daneden/animate.css.git $@

ifneq (,$(wildcard git))
animate.uncompressed.css: git/animate.css
	cat $^ > $@
endif

clean:
	rm -f $(TARGET) *gz
