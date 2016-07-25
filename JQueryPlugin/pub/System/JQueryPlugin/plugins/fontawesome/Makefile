FOSWIKI_ROOT?=~/foswiki/core
TARGET=\
  fontawesome.css \
  icon-animate.css \
  FontAwesome.otf \
  fontawesome-webfont.eot \
  fontawesome-webfont.svg \
  fontawesome-webfont.ttf \
  fontawesome-webfont.woff \
  fontawesome-webfont.woff2 

-include $(FOSWIKI_ROOT)/pub/System/JQueryPlugin/Makefile.include

git: git-fontawesome git-fontawesome-animation

git-fontawesome:
	git clone https://github.com/FortAwesome/Font-Awesome.git $@

git-fontawesome-animation:
	git clone https://github.com/l-lin/font-awesome-animation.git $@

ifneq (,$(wildcard git-fontawesome))
icon-animate.uncompressed.css: git-fontawesome-animation/dist/font-awesome-animation.css
	cat $^ |sed 's/..\/fonts\///g' > $@
endif

ifneq (,$(wildcard git-fontawesome))
fontawesome.uncompressed.css: git-fontawesome/css/font-awesome.css 
	cat $^ |sed 's/..\/fonts\///g' > $@

%.otf: git-fontawesome/fonts/%.otf
	cp $< $@

%.eot: git-fontawesome/fonts/%.eot
	cp $< $@

%.svg: git-fontawesome/fonts/%.svg
	cp $< $@

%.ttf: git-fontawesome/fonts/%.ttf
	cp $< $@

%.woff: git-fontawesome/fonts/%.woff
	cp $< $@

%.woff2: git-fontawesome/fonts/%.woff2
	cp $< $@
endif
