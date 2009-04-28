TARGET=ui.base.css ui.all.css

UI_BASE_SOURCE= \
  ui.core.css \
  ui.resizable.css \
  ui.accordion.css \
  ui.dialog.css \
  ui.slider.css \
  ui.tabs.css \
  ui.datepicker.css \
  ui.progressbar.css

UI_ALL_SOURCE= \
  $(UI_BASE_SOURCE) \
  ui.theme.css

-include ../../Makefile.include

ui.base.uncompressed.css: $(UI_BASE_SOURCE)
	@echo creating $@
	@$(CAT) $(UI_BASE_SOURCE) > $@

ui.all.uncompressed.css: $(UI_ALL_SOURCE)
	@echo creating $@
	@$(CAT) $(UI_ALL_SOURCE) > $@

