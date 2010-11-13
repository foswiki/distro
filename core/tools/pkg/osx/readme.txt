This directory contains everything needed to create a MacOS installer
package for Foswiki.

What the Makefile does:
-----------------------

First of all, a fully functional installation is created under
/Library/WebServer/Documents/foswiki. 

locallib.cfg and foswiki_httpd.conf are dynamically adjusted.

LocalSite.cfg is copied, using a prepared copy which is tuned for this
installation. This definitely leaves some room for improvement.

Once the installation is complete, all data is copied to
Application_Root, which is the root of the package's directory
structure. Owners and permissions have to match the OS!

Finally the packager is started and the disk image is created.

Requirements:
-------------

  - Foswiki-x.y.z.tgz has to be copied to this directory

Creating the installer:
-----------------------

  - Adjust version information in ReadMe.rtf
  - Adjust version information in Makefile
  - $ sudo make clean (removes previous data and installation!)
  - $ sudo make diskimage
  - $ sudo make sign

More information: 

  - http://foswiki.org/Support/FoswikiOnMacOSXLeopard

