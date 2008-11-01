TWIKIROOT=~/twiki/MAIN
TARGET= \
  jquery-all.js \
  jquery-all.css \
  jquery.superfish.js \
  jquery.superfish.css \
  jquery.debug.js \
  jquery.spinner.js \
  ui.accordion.js \
  ui.core.js \
  ui.datepicker.js \
  ui.dialog.js \
  ui.draggable.js \
  ui.droppable.js \
  ui.mouse.js \
  ui.resizable.js \
  ui.selectable.js \
  ui.slider.js \
  ui.sortable.js \
  ui.tabs.js \
  effects.blind.js \
  effects.bounce.js \
  effects.clip.js \
  effects.core.js \
  effects.drop.js \
  effects.explode.js \
  effects.fold.js \
  effects.highlight.js \
  effects.pulsate.js \
  effects.scale.js \
  effects.shake.js \
  effects.slide.js \
  effects.transfer.js

MINIFYJS=$(TWIKIROOT)/tools/minifyjs
MINIFYCSS=$(TWIKIROOT)/tools/minifycss


.SUFFIXES: .js .css

all: $(TARGET)
clean: 
	rm -f $(TARGET)

JS_SOURCES=\
  jquery.js \
  jquery.metadata.js \
  jquery.easing.js \
  jquery.hoverIntent.js \
  jquery.bgiframe.js \
  jquery.shrinkurls.js \
  jquery.blockUI.js \
  jquery.innerfade.js \
  jquery.dom.js \
  jquery.tooltip.js \
  jquery.nifty.js \
  jquery.treeview.js \
  jquery.treeview.async.js \
  jquery.twiki.js \
  jquery.tabpane.js

CSS_SOURCES=\
  jquery.nifty.css \
  jquery.twiki.css \
  jquery.tabpane.css \
  jquery.treeview.css

jquery-all.js: $(JS_SOURCES) Makefile $(MINIFYJS)
	@echo creating $@
	@$(MINIFYJS) $(JS_SOURCES) > $@


jquery-all.css: $(CSS_SOURCES) Makefile
	@echo creating $@
	@$(MINIFYCSS) $(CSS_SOURCES) > $@

%.js: %.uncompressed.js
	@echo creating $@ from $<
	@$(MINIFYJS) $< > $@
