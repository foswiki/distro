#!/bin/sh

if [ -e /tmp/build_deb ]; then
	echo '/tmp/build_deb already exists, please move aside'
	exit -1;
fi
if [ ! -e Foswiki-1.1.5.tgz ]; then
	echo 'need Foswiki-1.1.5.tgz file to build'
	exit -1;
fi

mkdir /tmp/build_deb
cp -r debian /tmp/build_deb/
cp Foswiki-1.1.5.tgz /tmp/build_deb/foswiki_1.1.5.orig.tar.gz

cd /tmp/build_deb
tar zxvf /tmp/build_deb/foswiki_1.1.5.orig.tar.gz

#add * to allow for -beta, -auto etc
mv /tmp/build_deb/Foswiki-1.1.5*/ /tmp/build_deb/foswiki-1.1.5/
cd /tmp/build_deb/foswiki-1.1.5

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
