VERSION = Foswiki-1.1.3
RELEASE = -1
TARFILE = $(VERSION).tgz
DESTDIR = /Library/WebServer/Documents
POSTFLIGHT = Resources/postflight


# How to create a package/image
#
# 0. Adjust ReadMe.rtf
# 1. Adjust VERSION
# 2. $ make clean
# 3. $ make diskimage
# 4. $ make sign 

.PHONY: postflight package clean tar locallibcfg sitelibcfg httpdconf

tar:
	cp $(TARFILE) $(DESTDIR); cd $(DESTDIR); tar xzf $(TARFILE)
	chown -R www:www $(DESTDIR)/$(VERSION)
	cd $(DESTDIR); ln -s $(VERSION) foswiki
	#older version needed 'logs' to be created by hand if configure hasn't been run yet
	#mkdir $(DESTDIR)/foswiki/working/logs
	chown www:www $(DESTDIR)/foswiki/working/logs

locallibcfg: tar
	cd $(DESTDIR)/foswiki/bin; cp LocalLib.cfg.txt LocalLib.cfg 
	echo "sed -i .orig 's%^\$$foswikiLibPath.*$$%\$$foswikiLibPath\ =\ \\\"$(DESTDIR)/foswiki/lib\\\"\;%g'   $(DESTDIR)/foswiki/bin/LocalLib.cfg" > tmpsed.sh
	chmod +x tmpsed.sh; ./tmpsed.sh && rm -f tmpsed.sh
	chown www:www $(DESTDIR)/foswiki/bin/LocalLib.cfg 

sitelibcfg: tar
	cp LocalSite.cfg $(DESTDIR)/foswiki/lib
	chown www:www $(DESTDIR)/foswiki/lib/LocalSite.cfg

httpdconf: tar
	echo "sed -i .orig 's%/var/www/foswiki%$(DESTDIR)/foswiki%g'   $(DESTDIR)/foswiki/foswiki_httpd_conf.txt" > tmpsed.sh
	echo "sed -i .orig 's%php_admin_flag engine off%#php_admin_flag engine off%g'   $(DESTDIR)/foswiki/foswiki_httpd_conf.txt" >> tmpsed.sh
	chmod +x tmpsed.sh; ./tmpsed.sh && rm -f tmpsed.sh
	cp $(DESTDIR)/foswiki/foswiki_httpd_conf.txt /etc/apache2/other/foswiki_httpd.conf 

localinstall: locallibcfg sitelibcfg httpdconf

postflight:
	mkdir Resources
	echo "#!/bin/sh" > $(POSTFLIGHT)
	echo "/usr/sbin/apachectl restart" >> $(POSTFLIGHT)
	echo "cd /Library/WebServer/Documents " >> $(POSTFLIGHT)
	echo "ln -s $(VERSION) foswiki" >> $(POSTFLIGHT)
	echo "date >> /tmp/$(VERSION)-install.log" >> $(POSTFLIGHT)
	echo "sleep 3" >> $(POSTFLIGHT)
	echo "open http://127.0.0.1/foswiki/bin/view" >> $(POSTFLIGHT)
	chmod +x $(POSTFLIGHT)
	cp ReadMe.rtf Resources

buildroot:
	mkdir -p Application_Root$(DESTDIR)
	chown -R root:admin Application_Root/*
	chmod -R 1775 Application_Root/Library
	chmod -R 775 Application_Root/Library/Webserver
	mkdir -p Application_Root/private/etc/apache2/other
	chown -R root:wheel Application_Root/private
	chmod -R 755 Application_Root/private
	cp -pR $(DESTDIR)/$(VERSION) Application_Root$(DESTDIR)
	cp -pR /etc/apache2/other/foswiki_httpd.conf  Application_Root/private/etc/apache2/other/foswiki_httpd.conf

package: localinstall postflight buildroot
	/Developer/Applications/Utilities/PackageMaker.app/Contents/MacOS/PackageMaker \
	--no-recommend \
	--title $(VERSION)$(RELEASE) \
	--root-volume-only \
	--target 10.5 \
	--out  $(VERSION)$(RELEASE).pkg \
	--root Application_Root \
	--id org.foswiki \
	--resources Resources \
	--scripts Resources 

sign:
	gpg -a  -b $(VERSION)$(RELEASE).dmg

diskimage: package
	mkdir diskimage
	cp $(VERSION)$(RELEASE).pkg ReadMe.rtf diskimage
	hdiutil create -srcfolder "diskimage" -volname "$(VERSION)$(RELEASE)" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDZO -size 20M $(VERSION)$(RELEASE).dmg

localclean:
	rm -rf $(DESTDIR)/foswiki
	rm -rf $(DESTDIR)/$(VERSION)
	rm -f /etc/apache2/other/foswiki_httpd.conf	
	rm -f /etc/apache2/other/foswiki_httpd.conf.ETW
pkgclean:
	rm -f $(VERSION)$(RELEASE).pkg
	rm -f $(VERSION)$(RELEASE).dmg*
	rm -rf Application_Root
	rm -rf Resources
	rm -rf diskimage

clean: localclean pkgclean