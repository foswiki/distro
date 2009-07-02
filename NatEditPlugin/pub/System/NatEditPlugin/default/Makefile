TARGET= \
  styles.css

GZIP=gzip


.SUFFIXES: .js .css

all: $(TARGET) $(TARGET:.js=.js.gz) $(TARGET:.css=.css.gz)

%.gz: %
	@echo compressing $< to $@
	@$(GZIP) -c $< > $@
