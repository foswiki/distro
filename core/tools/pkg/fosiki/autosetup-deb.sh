#!/bin/sh

#
# This script is run as root on the build host before the Debian
# package is built.  It may be used to install build dependencies
# or to perform other privileged operations.
#

branchdir="$1"
debdir="$2"

aptitude update
aptitude install -y subversion libwww-perl zip fakeroot dpkg-dev \
	debhelper tardy po-debconf dpatch devscripts build-essential \
	libcss-minifier-xs-perl libjavascript-minifier-xs-perl \
	liberror-perl
apt-get clean
aptitude dist-upgrade -y
