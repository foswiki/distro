TARGET=jquery-ui.js 

SOURCES=\
  ui.core.js \
  ui.draggable.js \
  ui.droppable.js \
  ui.resizable.js \
  ui.selectable.js \
  ui.sortable.js \
  ui.accordion.js \
  ui.dialog.js \
  ui.slider.js \
  ui.tabs.js \
  ui.datepicker.js \
  ui.progressbar.js \
  effects.core.js \
  effects.blind.js \
  effects.bounce.js \
  effects.clip.js \
  effects.drop.js \
  effects.explode.js \
  effects.fold.js \
  effects.highlight.js \
  effects.pulsate.js \
  effects.scale.js \
  effects.shake.js \
  effects.slide.js \
  effects.transfer.js 

-include ../Makefile.include

jquery-ui.uncompressed.js: $(SOURCES) Makefile
	@echo creating $@
	@$(CAT) $(SOURCES) > $@

