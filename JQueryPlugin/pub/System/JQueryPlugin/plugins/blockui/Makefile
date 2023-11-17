TARGET=jquery.blockUI.css pkg.js
PKG_SOURCE=jquery.blockUI.uncompressed.js jquery.blockUI.init.uncompressed.js

-include ../../Makefile.include

#git: 
#	git clone https://github.com/malsup/blockui.git $@
#
#ifneq (,$(wildcard git))
#jquery.blockUI.uncompressed.js: git/jquery.blockUI.js
#	cat $^ > $@
#endif

clean:
	rm -f $(TARGET) *gz pkg.uncompressed.js

pkg.uncompressed.js: $(PKG_SOURCE)
	@echo generating $@
	@$(CAT) $^ > $@
