#!/bin/sh
#
# Run on the build host, typically from cron.  This is a script to:
#
# 1) check out release branch
# 2) find revision number, and if changed
# 3) copies to another, isolated machine (usually local VM)
# 4) run the autobuild-deb.sh script from there
# 5) copy the resulting packages to an incoming dir on a repository machine
#
# New versions of this script should be deployed when switching autobuilders
# to newly supported distributions (eg. Debian/squeeze) or new Foswiki
# branches are made.
#

set -e

if [ "x$BRANCH" = "x" ] ; then
  BRANCH=Release01x00
fi

REPOSITORYHOST=debmarshal.debian.net
INCOMING=/var/lib/debmarshal/foswiki/incoming
TIMEOUT='timeout 600'

cd ${HOME}

if [ ! -d $BRANCH ] ; then
  if [ "x$BRANCH" = "xtrunk" ] ; then
    svn co http://svn.foswiki.org/trunk
  else
    svn co http://svn.foswiki.org/branches/$BRANCH
  fi
fi

#
# Check whether there have been changes in the release or trunk
#
cd $BRANCH
lastrelease=`$TIMEOUT svn info | awk '/Last Changed Rev:/ { print $4; }'`
$TIMEOUT svn up >/dev/null
release=`$TIMEOUT svn info | awk '/Last Changed Rev:/ { print $4; }'`
cd ..

if [ "$lastrelease" = "$release" ]
then
  exit 0
fi

# Always build a full source release, since the Debian packaging is in the
# same branch where source changes occur
rebuild_flags="-sa"

#
# Configure foswiki-build-host in your /etc/hosts file, generally pointing
# to a local virtual machine of some sort that can be logged into as both
# the same username this script is running under, and as root.
# The build script returns a list of files as the new build result.
#
BUILDHOST=foswiki-build-host
DEST_DIR=/tmp/build_deb

remotehome=`ssh ${BUILDHOST} pwd`

rsync -a --delete ${BRANCH}/ ${BUILDHOST}:${BRANCH}

#
# Make sbuild suid root and installs packages needed by the build, and whatever
# else becomes required to build
#
ssh root@${BUILDHOST} ${remotehome}/${BRANCH}/core/tools/pkg/autosetup-deb.sh ${remotehome}/${BRANCH} $DEST_DIR

#
# The actual build runs unprivileged, and returns the filenames of the packages
# that were built.  The build should sign the packages, so the build user
# should have a gpg key without a password.
#
ssh ${BUILDHOST} ${remotehome}/${BRANCH}/core/tools/pkg/autobuild-deb.sh ~/${BRANCH} $DEST_DIR $release $rebuild_flags

#
# Final root step.  This may run install tests or clean up.
#
ssh root@${BUILDHOST} ${remotehome}/${BRANCH}/core/tools/pkg/autoteardown-deb.sh ${remotehome}/${BRANCH} $DEST_DIR

echo Copying built files to repository
tmpdir=`mktemp -d`
echo scp ${BUILDHOST}:${DEST_DIR}/* ${tmpdir}/
scp ${BUILDHOST}:${DEST_DIR}/* ${tmpdir}/
ssh ${BUILDHOST} rm -rf ${DEST_DIR}
echo scp ${tmpdir}/* ${REPOSITORYHOST}:${INCOMING}
scp ${tmpdir}/* ${REPOSITORYHOST}:${INCOMING}
rm -rf ${tmpdir}

echo "Done"
exit 0
