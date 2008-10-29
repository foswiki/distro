#!/bin/sh

if [ -e /tmp/build_deb ]; then
	echo '/tmp/build_deb already exists, please move aside'
	exit -1;
fi
if [ ! -e TWiki-4.2.3.tgz ]; then
	echo 'need TWiki-4.2.3.tgz file to build'
	exit -1;
fi

mkdir /tmp/build_deb
cp TWiki-4.2.3.tgz /tmp/build_deb/twiki_4.2.3.orig.tar.gz

mkdir /tmp/build_deb/twiki-4.2.3 

cp -r debian /tmp/build_deb/twiki-4.2.3
cd /tmp/build_deb/twiki-4.2.3
find . -name .svn -exec rm -rf '{}' \;

tar zxvf /tmp/build_deb/twiki_4.2.3.orig.tar.gz

#patch it
#fakeroot debian/rules patch

#debuild
#see http://www.debian.org/doc/maint-guide/ch-build.en.html
dpkg-buildpackage -rfakeroot

#TODO
#interdiff -z twiki_4.1.2-{8,9}.diff.gz
#upload this too

#update the debian repos on distributedINFORMATION.com
#echo ================== upload into experimental debian repos
#cd /data/home/sven/src/wikiring/projects/TWiki/TWikiInstaller/experimental/
#reprepro --component main --priority normal  --section web --ignore=wrongdistribution   includedeb experimental /tmp/build_deb/*.deb

