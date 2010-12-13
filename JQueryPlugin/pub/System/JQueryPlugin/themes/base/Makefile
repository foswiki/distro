TARGET=jquery-ui.css

UI_SOURCE= \
  jquery.ui.core.css \
  jquery.ui.resizable.css \
  jquery.ui.accordion.css \
  jquery.ui.dialog.css \
  jquery.ui.slider.css \
  jquery.ui.tabs.css \
  jquery.ui.datepicker.css \
  jquery.ui.progressbar.css \
  jquery.ui.autocomplete.css \
  jquery.ui.selectable.css \
  jquery.ui.button.css \
  jquery.ui.theme.css

-include ../../Makefile.include

jquery-ui.uncompressed.css: $(UI_SOURCE)
	@echo creating $@
	@$(CAT) $(UI_SOURCE) |sed 's/@VERSION/1.8.5/g' > $@

