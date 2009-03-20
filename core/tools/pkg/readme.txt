
The tools/pkg directory is intended to include scripts and configuration information.

We currently have:

debian/
   * contains the source for the debian foswiki package. this is made using a release tarball, and these files.
   * as of 2003 it is maintained by SvenDowideit (sponsered by Ardo van Rangelrooij <ardo@debian.org>) 
   * from http://matrixhasu.altervista.org/index.php?view=use_dpatch
      * diff -u source-tree-original/the-file source-tree/the-file | \
        dpatch patch-template -p "<number>_<short_description>"   \
        "<what the patch does>" > path/to/debian/patches/<number>_<short_description>.dpatch
