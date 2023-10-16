TARGET=jquery.blockUI.css pkg.js

-include ../../Makefile.include

PKG_SOURCE=jquery.blockUI.uncompressed.js jquery.blockUI.init.uncompressed.js

#git: 
#	git clone https://github.com/malsup/blockui.git $@
#
#ifneq (,$(wildcard git))
#jquery.blockUI.uncompressed.js: git/jquery.blockUI.js
#	cat $^ > $@
#endif

clean:
	rm -f $(TARGET) *gz

pkg.uncompressed.js: $(PKG_SOURCE)
	@echo generating $@
	@$(CAT) $^ > $@
