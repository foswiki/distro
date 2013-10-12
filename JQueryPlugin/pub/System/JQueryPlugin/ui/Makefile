TARGET=\
  jquery-ui.js \
  jquery.ui.autocomplete.init.js \
  jquery.ui.resizable.init.js \
  jquery.ui.draggable.init.js \
  jquery.ui.accordion.init.js \
  jquery.ui.tabs.init.js \
  jquery.ui.slider.init.js \
  jquery.ui.dialog.init.js \
  jquery.ui.button.init.js \
  jquery.ui.datepicker.init.js \
  jquery.ui.progressbar.init.js \
  jquery.ui.tooltip.init.js

# TODO: not yet init'ed widgets
# droppable, selectable, sortable

SOURCES=\
  jquery.ui.core.js\
  jquery.ui.widget.js\
  jquery.ui.mouse.js\
  jquery.ui.draggable.js\
  jquery.ui.droppable.js\
  jquery.ui.resizable.js\
  jquery.ui.selectable.js\
  jquery.ui.sortable.js\
  jquery.ui.effect.js\
  jquery.ui.accordion.js\
  jquery.ui.autocomplete.js\
  jquery.ui.button.js\
  jquery.ui.datepicker.js\
  jquery.ui.dialog.js\
  jquery.ui.menu.js \
  jquery.ui.position.js\
  jquery.ui.progressbar.js\
  jquery.ui.slider.js\
  jquery.ui.spinner.js \
  jquery.ui.tabs.js\
  jquery.ui.tooltip.js \
  jquery.ui.effect-blind.js\
  jquery.ui.effect-bounce.js\
  jquery.ui.effect-clip.js\
  jquery.ui.effect-drop.js\
  jquery.ui.effect-explode.js\
  jquery.ui.effect-fade.js\
  jquery.ui.effect-fold.js\
  jquery.ui.effect-highlight.js\
  jquery.ui.effect-pulsate.js\
  jquery.ui.effect-scale.js\
  jquery.ui.effect-shake.js\
  jquery.ui.effect-slide.js\
  jquery.ui.effect-transfer.js


-include ../Makefile.include

jquery-ui.uncompressed.js: $(SOURCES) Makefile
	@echo creating $@
	@$(CAT) $(SOURCES) > $@
