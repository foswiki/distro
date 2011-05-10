
The tools/pkg directory is intended to include scripts and configuration information.

We currently have:

debian/
   * autoBuild by Drake Diedrich - atm from svn source
   * http://debmarshal.corp.google.com/foswiki/dists/foswiki-1.1/
fosiki/
   * contains the buld tools that SvenDowideit uses to build the fosiki debian package http://fosiki.com/Foswiki_debian/
   * as of 2003 it is maintained by SvenDowideit (sponsered by Ardo van Rangelrooij <ardo@debian.org>) 
   * contains the source for the debian foswiki package. this is made using a release tarball, and these files.
   * from http://matrixhasu.altervista.org/index.php?view=use_dpatch
      * diff -u source-tree-original/the-file source-tree/the-file | \
        dpatch patch-template -p "<number>_<short_description>"   \
        "<what the patch does>" > path/to/debian/patches/<number>_<short_description>.dpatch
