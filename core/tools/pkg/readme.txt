
The tools/pkg directory is intended to include scripts and configuration information.

We currently have:

debian/
   * contains the static content of the debian package for the current branch

build_deb.sh
   * the command to run without parameters to build the debian packages
     for the current branch
   * a wrapper around autobuild_deb.sh
   * used like the original build_deb.sh

autobuild_deb.sh
   * the main work script to create a unique package version number
     given the repository revision number and branch.

autohost-deb.sh
   * a script run by cron on the deb repository machine to pull the latest
     svn version of this branch
   * launches a build on $BUILD_HOST, which it can log into as root
     or the same user running as cron on this host
   * launches autosetup-deb.sh as root on the build host
   * launches autobuild_deb.sh as foswiki on the build host
   * launches autoteardown-deb.sh as root on the build host
   * copies the .debs, source packages, and signed upload files to the
     $REPOSITORYHOST incoming directory

debmarshal-foswiki.sh
   * run on the $REPOSITORYHOST from cron to import incoming uploads
   * uses debmarshal to maintain multiple tracks and point releases
   * runs EDOS to verify dependencies can be met and are not worse than
     previous builds

autosetup-deb.sh
autoteardown-deb.sh
   * run as root on the buildhost to install prerequisite packages
     or otherwise clean the system afterwards
