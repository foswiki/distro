TARGET=\
  slimbox2.js \
  slimbox2.init.js \
  slimbox2.css \
  closelabel.gif \
  loading.gif \
  nextlabel.gif \
  prevlabel.gif

-include ../../Makefile.include

git: 
	git clone https://github.com/cbeyls/slimbox.git $@

ifneq (,$(wildcard git))
slimbox2.uncompressed.js: git/js/slimbox2.js
	cp $^ $@

slimbox2.uncompressed.css: git/css/slimbox2.css
	cp $^ $@

%.gif: git/css/%.gif
	cp $^ $@
endif
