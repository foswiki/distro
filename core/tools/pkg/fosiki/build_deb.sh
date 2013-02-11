#!/bin/sh

if [ -e /tmp/build_deb ]; then
	echo '/tmp/build_deb already exists, please move aside'
	exit -1;
fi
if [ ! -e Foswiki-1.1.7.tgz ]; then
	echo 'need Foswiki-1.1.7.tgz file to build'
	exit -1;
fi

mkdir /tmp/build_deb
cp -r debian /tmp/build_deb/
cp Foswiki-1.1.7.tgz /tmp/build_deb/foswiki_1.1.7.orig.tar.gz

cd /tmp/build_deb
tar zxvf /tmp/build_deb/foswiki_1.1.7.orig.tar.gz

#add * to allow for -beta, -auto etc
mv /tmp/build_deb/Foswiki-1.1.7*/ /tmp/build_deb/foswiki-1.1.7/
cd /tmp/build_deb/foswiki-1.1.7

mv ../debian .

#clean out svn dirs
find . -name .svn -exec rm -rf '{}' \;


#debuild
#see http://www.debian.org/doc/maint-guide/ch-build.en.html
dpkg-buildpackage -rfakeroot

#TODO
#interdiff -z foswiki_4.1.2-{8,9}.diff.gz
#upload this too

#update the debian repos on distributedINFORMATION.com
#echo ================== upload into experimental debian repos
#cd /data/home/sven/src/wikiring/projects/Foswiki/FoswikiInstaller/experimental/
#reprepro --component main --priority normal  --section web --ignore=wrongdistribution   includedeb experimental /tmp/build_deb/*.deb

##############################
# CREATING PATCHES
# 1. run a build_deb.sh
# 2. cd /tmp/build_deb/foswiki-1.1.7
# 3. run dpatch-edit-patch your-new-patchname
# 4. once its at a shell, make your change and type 'exit'
# 4a. if you want to discard, 'exit 260' will work
# 5. copy the generated dpatch file to the debian/patches dir and add to 00list
# 6. run a new build_deb.sh :) DONE.
