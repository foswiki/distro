TARGET=\
  jquery.jqgrid.js \
  jquery.jqgrid.init.js \
  $(JQUERYPLUGIN_LIB)/GRID.pm

SUBDIRS=i18n css

-include ../../Makefile.include

JSSOURCE=\
  grid.base.js \
  grid.common.js \
  grid.formedit.js \
  grid.inlinedit.js \
  grid.celledit.js \
  grid.subgrid.js \
  grid.treegrid.js \
  grid.custom.js \
  grid.postext.js \
  grid.tbltogrid.js \
  grid.setcolumns.js \
  grid.import.js \
  jquery.fmatter.js \
  JsonXml.js \
  jquery.searchFilter.js


jquery.jqgrid.uncompressed.js: $(JSSOURCE)
	@echo creating $@ from JSSOURCE
	@$(CAT) $^ > $@

