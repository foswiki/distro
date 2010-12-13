TARGET=jquery-ui.js 

SOURCES=\
  jquery.ui.core.js\
  jquery.ui.widget.js\
  jquery.ui.mouse.js\
  jquery.ui.draggable.js\
  jquery.ui.droppable.js\
  jquery.ui.resizable.js\
  jquery.ui.selectable.js\
  jquery.ui.sortable.js\
  jquery.ui.dialog.js\
  jquery.ui.accordion.js\
  jquery.ui.button.js\
  jquery.ui.datepicker.js\
  jquery.ui.position.js\
  jquery.ui.progressbar.js\
  jquery.ui.slider.js\
  jquery.ui.tabs.js\
  jquery.effects.core.js\
  jquery.effects.blind.js\
  jquery.effects.bounce.js\
  jquery.effects.clip.js\
  jquery.effects.drop.js\
  jquery.effects.explode.js\
  jquery.effects.fade.js\
  jquery.effects.fold.js\
  jquery.effects.highlight.js\
  jquery.effects.pulsate.js\
  jquery.effects.scale.js\
  jquery.effects.shake.js\
  jquery.effects.slide.js\
  jquery.effects.transfer.js

#  jquery.ui.autocomplete.js\

-include ../Makefile.include

jquery-ui.uncompressed.js: $(SOURCES) Makefile
	@echo creating $@
	@$(CAT) $(SOURCES) > $@

