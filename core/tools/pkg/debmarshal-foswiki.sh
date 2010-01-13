#!/bin/sh

#
# Automate updating and verifying the foswiki repositories and tracks
# on debmarshal.debian.net
#
#
# Package names to check for dependencies issues using EDOS
#
PACKAGES="foswiki foswiki-core foswiki-configure-cgi foswiki-configure-apache2-basic foswiki-system-web-data foswiki-default-web-data foswiki-empty-web-data foswiki-example-data foswiki-core-autoviewtemplateplugin foswiki-core-commentplugin foswiki-core-edittableplugin foswiki-core-emptyplugin foswiki-core-historyplugin foswiki-core-interwikiplugin foswiki-core-preferencesplugin foswiki-core-renderlistplugin foswiki-core-slideshowplugin foswiki-core-smiliesplugin foswiki-core-spreadsheetplugin foswiki-core-tableplugin foswiki-core-tinymceplugin foswiki-core-twistyplugin foswiki-core-wysiwygplugin foswiki-core-twikicompatibilityplugin foswiki-core-behaviourcontrib foswiki-core-comparerevisionsaddon foswiki-core-jscalendarcontrib foswiki-core-mailercontrib foswiki-core-patternskin foswiki-core-tipscontrib foswiki-core-topicusermappingcontrib"

cd /var/lib/debmarshal/foswiki

/usr/lib/debmarshal/enter_incoming.py

for t in foswiki-trunk foswiki-1.0 foswiki-1.0.9 foswiki-1.0.8 foswiki-1.0.7 foswiki-1.0.6 foswiki-1.0.5
do
   oldlink=`readlink dists/$t/latest`
   if /usr/lib/debmarshal/make_release.py --release snapshot/latest \
      --track $t \
      diff $t/latest 2>&1 | egrep -q '^[-+]'
   then
      /usr/lib/debmarshal/make_release.py --release snapshot/latest \
         --track $t commit
                                     
      ln -sf dists/$t/latest/main dists/$t/
      ln -sf dists/$t/latest/Release dists/$t/
      ln -sf dists/$t/latest/Release.gpg dists/$t/
      
      newlink=`readlink dists/$t/latest`
      /usr/lib/debmarshal/make_release.py --release $t/latest \
         --track $t \
         verify >dists/$t/${newlink}.verify 2>&1 || true
      ln -sf $newlink.verify dists/$t/latest.verify

      cat dists/$t/latest/*/*/Packages \
        ../debian/dists/sid/latest/main/*/Packages | \
        edos-debcheck -explain -quiet -checkonly $PACKAGES > dists/$t/${newlink}.edos 2>&1 || true
      ln -sf $newlink.edos dists/$t/latest.edos
      
      echo
      if [ -f dists/$t/$oldlink.edos ] ; then
         echo "New differences in $t/${newlink} EDOS logs:"
         diff -u dists/$t/${oldlink}.edos \
            dists/$t/${newlink}.edos
      else
         echo "All EDOS logs for ${DERIVATIVE}/${t}:"
         cat dists/$t/${newlink}.edos
      fi

      echo
      if [ -f dists/$t/$oldlink.verify ] ; then
         echo "New differences in $t/${newlink} verify logs:"
         diff -u dists/$t/${oldlink}.verify \
            dists/$t/${newlink}.verify
      else
         echo "All verify logs for ${DERIVATIVE}/${t}:"
         cat dists/$t/${newlink}.verify
      fi
   fi
done
