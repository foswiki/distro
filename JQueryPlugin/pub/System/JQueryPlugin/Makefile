SUBDIRS=i18n plugins themes ui
TARGET=\
  jquery.js \
  jquery-all.js \
  jquery-all.css

JS_SOURCES=\
  jquery.js \
  plugins/bgiframe/jquery.bgiframe.js \
  plugins/chilli/jquery.chili.js \
  plugins/easing/jquery.easing.js \
  plugins/hoverIntent/jquery.hoverIntent.js \
  plugins/metadata/jquery.metadata.js \
  plugins/nifty/jquery.nifty.js \
  plugins/tabpane/jquery.tabpane.js \
  plugins/tooltip/jquery.tooltip.js \
  plugins/treeview/jquery.treeview.js \
  plugins/treeview/jquery.treeview.async.js \
  plugins/foswiki/jquery.foswiki.js

CSS_SOURCES=\
  plugins/nifty/jquery.nifty.css \
  plugins/tabpane/jquery.tabpane.css \
  plugins/treeview/jquery.treeview.css

-include Makefile.include
jquery-all.js: $(JS_SOURCES) Makefile
	@echo creating $@
	@$(MINIFYJS) $(JS_SOURCES) > $@

jquery-all.css: $(CSS_SOURCES) 
	@echo creating $@
	@$(MINIFYCSS) $(CSS_SOURCES) > $@
