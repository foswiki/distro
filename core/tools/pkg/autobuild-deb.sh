#!/bin/sh -x
#
# The autobuild script for the debs as produced for the 1.0 release using the
# packaging from trunk.  4 commandline arguments are required, the full local
# paths of the repositoties, their versions, and a final destination directory
# to put the resulting debs in.
#

set -e

#
# Paths of the subversion repository, a final destination directory,
# the subversion repository revision, and optional package build flags.
#
branch=$1
dest=$2
branchrev=$3
rebuild_flags=$4

#
# Run a pseudo-install of the new branch revision
#
export FOSWIKI_HOME=${branch}/core
export FOSWIKI_LIBS=${FOSWIKI_HOME}/lib:${FOSWIKI_HOME}/lib/CPAN/lib
cd ${FOSWIKI_HOME}

perl pseudo-install.pl -clean -u developer
perl pseudo-install.pl -clean -A developer

#
# Run the unit tests.
#
# cd test/unit
# perl ../bin/TestRunner.pl -clean FoswikiSuite.pm || true

#
# Build tarballs of source, with svn revision number embedded
#
cd ${FOSWIKI_HOME}/tools
./build.pl release -auto || echo build.pl returned $?

#
# copy the tarball to the package build directory
#
cp  ../Foswiki-*.tgz ${FOSWIKI_HOME}/tools/pkg/

#
# Get the last real release number and the version number on the tarball
#
tarversion=`echo ../Foswiki-*.tgz | sed 's%../Foswiki-%%' | sed 's/.tgz//'`
releaseversion=`echo $tarversion | sed s/-.*//`

cd ${FOSWIKI_HOME}/tools/pkg


#
# Do about the same as these, but with modified source and package revisions
#
#	rm -rf /tmp/build_deb
#	./build_deb.sh
#
# Copy the tarball to the Debian .orig.tar.gz filename, unpack, rename dir,
# copy the debian dir, add a new entry to bump the version, and build packages.
#
tmpdir=`mktemp -d /tmp/stage1-1.0.XXXXXXXXXX`

#
# First build using Foswiki's in-tree BuildContrib to get a source package
#
pkgversion="${releaseversion}-auto${branchrev}"
debversion="0"
cp Foswiki-${tarversion}.tgz ${tmpdir}/foswiki_${pkgversion}.orig.tar.gz
tar zxf Foswiki-${tarversion}.tgz -C ${tmpdir}
cp -r debian ${tmpdir}/Foswiki-${tarversion}/debian
cd ${tmpdir}/Foswiki-${tarversion}
#clean out svn dirs, ignore failures
find . -name .svn -exec rm -rf '{}' \; || true

DEBFULLNAME="Foswiki Autobuilder" \
DEBEMAIL="foswiki-discuss@lists.sourceforge.net" \
  dch -v "${pkgversion}-${debversion}" "nmu: autobuild"


debuild -us -uc || echo debuild returned $?

echo "First build completed"

#
# Jump to a new directory, unpack the source package, and build it again,
# just to be sure it builds from the source package as well as tarball.
#
tmpdir2=`mktemp -d /tmp/stage2-1.0.XXXXXXXXXX`
cd ${tmpdir2}
dpkg-source -x ${tmpdir}/*.dsc
rm -rf ${tmpdir}
cd foswiki-${pkgversion} || ls -l

#
# Build package, signing with a key that matches the dch entry above.
# The key should be unprotected.
#
debuild ${rebuild_flags}

echo "Second build completed"

[ -d ${dest} ] || mkdir ${dest}
cp ../* ${dest} || ls -l ../* ${dest}

rm -rf ${tmpdir2}

echo "Done - $0"
