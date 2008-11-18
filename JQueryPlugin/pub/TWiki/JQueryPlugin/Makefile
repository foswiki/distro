TWIKIROOT=~/twiki/trunk/core
TARGET= \
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
  effects.transfer.js \
  jquery-all.css \
  jquery-all.js \
  jquery.autocomplete.js \
  jquery.cycle.js \
  jquery.cycle.trans.js \
  jquery.debug.js \
  jquery.form.js \
  jquery.maskedinput.js \
  jquery.rating.css \
  jquery.rating.js \
  jquery.shake.js \
  jquery.spinner.js \
  jquery.superfish.css \
  jquery.superfish.js \
  jquery.validate.additional-methods.js \
  jquery.validate.js \
  jquery.wikiword.js \
  jquery.ifixpng.js \
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
  ui.tabs.js


MINIFYJS=TWIKICPAN=$(TWIKIROOT)/lib/CPAN/lib $(TWIKIROOT)/tools/minifyjs
MINIFYCSS=TWIKICPAN=$(TWIKIROOT)/lib/CPAN/lib $(TWIKIROOT)/tools/minifycss
GZIP=gzip


.SUFFIXES: .js .css

all: $(TARGET) $(TARGET:.js=.js.gz) $(TARGET:.css=.css.gz)

JS_VALIDATE_SOURCE=\
  jquery.validate.uncompressed.js \
  jquery.validate.additional-methods.js

JS_SOURCES=\
  jquery.js \
  jquery.bgiframe.js \
  jquery.chili.js \
  jquery.easing.js \
  jquery.hoverIntent.js \
  jquery.innerfade.js \
  jquery.metadata.js \
  jquery.nifty.js \
  jquery.shrinkurls.js \
  jquery.tabpane.js \
  jquery.tooltip.js \
  jquery.treeview.async.js \
  jquery.treeview.js \
  jquery.twiki.js

CSS_SOURCES=\
  jquery.nifty.css \
  jquery.twiki.css \
  jquery.tabpane.css \
  jquery.treeview.css

jquery-all.js: $(JS_SOURCES) Makefile
	@echo creating $@
	@$(MINIFYJS) $(JS_SOURCES) > $@

jquery-all.css: $(CSS_SOURCES) 
	@echo creating $@
	@$(MINIFYCSS) $(CSS_SOURCES) > $@

jquery.validate.js: $(JS_VALIDATE_SOURCE)
	@echo creating $@ from $(JS_VALIDATE_SOURCE)
	@$(MINIFYJS) $(JS_VALIDATE_SOURCE) > $@

%.js: %.uncompressed.js
	@echo creating $@ from $<
	@$(MINIFYJS) $< > $@

%.gz: %
	@echo compressing $< to $@
	@$(GZIP) -c $< > $@

%.css: %.uncompressed.css
	@echo creating $@ from $<
	@$(MINIFYCSS) $< > $@
