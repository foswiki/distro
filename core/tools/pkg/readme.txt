
The tools/pkg directory is intended to include scripts and configuration information.

We currently have:

fosiki/
   * contains the buld tools that SvenDowideit uses to build the fosiki debian package http://fosiki.com/Foswiki_debian/
   * as of 2003 it is maintained by SvenDowideit (sponsered by Ardo van Rangelrooij <ardo@debian.org>) 
   * contains the source for the debian foswiki package. this is made using a release tarball, and these files.
   * from http://matrixhasu.altervista.org/index.php?view=use_dpatch
      * diff -u source-tree-original/the-file source-tree/the-file | \
        dpatch patch-template -p "<number>_<short_description>"   \
        "<what the patch does>" > path/to/debian/patches/<number>_<short_description>.dpatch

debian/
   * static debian packaging for the debmarshal.debian.net autobuild packages
   * http://debmarshal.corp.google.com/foswiki/dists/foswiki-1.1/

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
