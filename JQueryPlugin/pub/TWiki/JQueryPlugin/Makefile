TWIKIROOT=~/twiki/trunk/core
TARGET= \
  effects.blind.js.gz \
  effects.bounce.js.gz \
  effects.clip.js.gz \
  effects.core.js.gz \
  effects.drop.js.gz \
  effects.explode.js.gz \
  effects.fold.js.gz \
  effects.highlight.js.gz \
  effects.pulsate.js.gz \
  effects.scale.js.gz \
  effects.shake.js.gz \
  effects.slide.js.gz \
  effects.transfer.js.gz \
  jquery-all.css.gz \
  jquery-all.js.gz \
  jquery.autocomplete.js.gz \
  jquery.cycle.js.gz \
  jquery.cycle.trans.js.gz \
  jquery.debug.js.gz \
  jquery.form.js.gz \
  jquery.maskedinput.js.gz \
  jquery.rating.css.gz \
  jquery.rating.js.gz \
  jquery.shake.js.gz \
  jquery.spinner.js.gz \
  jquery.superfish.css.gz \
  jquery.superfish.js.gz \
  jquery.validate.additional-methods.js.gz \
  jquery.validate.js.gz \
  ui.accordion.js.gz \
  ui.core.js.gz \
  ui.datepicker.js.gz \
  ui.dialog.js.gz \
  ui.draggable.js.gz \
  ui.droppable.js.gz \
  ui.mouse.js.gz \
  ui.resizable.js.gz \
  ui.selectable.js.gz \
  ui.slider.js.gz \
  ui.sortable.js.gz \
  ui.tabs.js


MINIFYJS=TWIKICPAN=$(TWIKIROOT)/lib/CPAN/lib $(TWIKIROOT)/tools/minifyjs
MINIFYCSS=TWIKICPAN=$(TWIKIROOT)/lib/CPAN/lib $(TWIKIROOT)/tools/minifycss
GZIP=gzip


.SUFFIXES: .js .css

all: $(TARGET)
clean: 
	rm -f $(TARGET)

JS_VALIDATE_SOURCE=\
  jquery.validate.uncompressed.js \
  jquery.validate.additional-methods.js

JS_SOURCES=\
  jquery.js \
  jquery.metadata.js \
  jquery.easing.js \
  jquery.hoverIntent.js \
  jquery.bgiframe.js \
  jquery.shrinkurls.js \
  jquery.innerfade.js \
  jquery.tooltip.js \
  jquery.nifty.js \
  jquery.treeview.js \
  jquery.treeview.async.js \
  jquery.twiki.js \
  jquery.tabpane.js \
  jquery.chili.js

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
