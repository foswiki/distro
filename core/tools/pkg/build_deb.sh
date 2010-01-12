#!/bin/sh

if [ -e /tmp/build_deb ]; then
	echo '/tmp/build_deb already exists, please move aside'
	exit -1;
fi

mkdir /tmp/build_deb

version=`(svn info || git svn info) | awk '/Last Changed Rev:/ { print $4; }'`

./autobuild-deb.sh `cd ../../.. ; pwd` /tmp/build_deb $version "-sa -us -uc"
