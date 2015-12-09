#!/bin/sh

# These permissions are set to be permissive enough for Foswiki to run on a wide variety of platforms
# Note that the bin/configure file directory checkers will report files that are more or less
# permissive than these settings.  These permissions will work on most systems. On multi-purpose
# servers, the "world" permissions should be removed, and the corresponding changes made to
# the configuration variables listed below.

OPT=-c              # -c: Show changes.   On FreeBSD,  needs to be -vv

ROOT=444            # Server root read only
DIR=755             # Directories need "exec" for directory operations. Matches {Store}{dirPermission}
TOPICS=644          # Topics: Update by foswiki CGI, read by web server Matches {Store}{filePermission}
ATTACHMENTS=644     # Attachments:  Same, Matches {Store}{filePermission}.
RCS=444             # RCS Revision histories are always read only
PFV=644             # PlainFile revision histories need to be writable.
EXECUTABLE=555      # Programs called by CGI or Shell
READONLY=444        # Samples, READMEs, Perl modules, helpers, etc.
WORKING=644         # workareas, logfiles, etc.
PASSWORD=640        # .htpasswd Read by web server, writable by Foswiki CGI
SECURITY=600        # passwords, Configuration. Read/write by Foswiki CGI, nothing else should need them.
SECURITYRO=440      # Other access control related, not updated by Foswiki.

echo "Everything in root is read only - $ROOT"
find . -maxdepth 1 -type f  -exec chmod $OPT $ROOT {} \;

echo
echo "All directories have exec bit for recursive reading - $DIR"
find . -type d  -exec chmod $OPT $DIR {} \;

echo
echo "Files in data ($TOPICS) & pub ($ATTACHMENTS) writable by server,"
find data -type f -name "*.txt" -exec chmod $OPT $TOPICS {} \;
find data -type f -name "*.lease" -exec chmod $OPT $TOPICS {} \;
find data -type f -name ".changes" -exec chmod $OPT $TOPICS {} \;
find pub -type f -exec chmod $OPT $ATTACHMENTS {} \;

echo
echo "   except for history files which are read-only ($RCS)"
find data pub -name '*,v' -type f -exec chmod $OPT $RCS {} \;
find data -name "*,pfv" -print0 | xargs -0 -I{{ find {{ -type f -exec chmod $PFV {} \;

echo
echo "Everything in data top level is writable by server ($TOPICS)."
find data -maxdepth 1 -type f ! -name .htpasswd  -exec chmod $OPT $TOPICS {} \;

echo
echo "bin and tools needs to be executable ($EXECUTABLE) - with exceptions"
find bin -type f ! -name LocalLib.cfg.txt ! -name setlib.cfg -exec chmod $OPT $EXECUTABLE {} \;
find tools -maxdepth 1 -type f ! -name extender.pl -exec chmod $OPT $EXECUTABLE {} \;
echo
echo " ... these are the exceptions: ($READONLY)"
chmod $OPT $READONLY bin/LocalLib.cfg.txt
chmod $OPT $READONLY bin/setlib.cfg
chmod $OPT $READONLY tools/extender.pl

echo
echo "Everything else is read only ($READONLY)"
find lib -type f ! -name LocalSite.cfg -exec chmod $OPT $READONLY {} \;
find locale -type f -exec chmod $OPT $READONLY {} \;
find templates -type f -exec chmod $OPT $READONLY {} \;

echo
echo "Working is server writable ($WORKING) - with exceptions ($READONLY)"
find working -type f ! -name README ! -name "cgisess_*" -exec chmod $OPT $WORKING {} \;
find working/configure -type f ! -name "cgisess_*" -exec chmod $OPT $READONLY {} \;
find working/configure -name "cgisess_*" -exec chmod $OPT $SECURITY {} \;
find working -name README -exec chmod $OPT $READONLY {} \;

echo
echo "Security related files should not be world readable - ($SECURITY)."
find . -name .htaccess -exec chmod $OPT $SECURITYRO {} \;
find working -name cgisess_*  -exec chmod $OPT $SECURITY {} \;
chmod $OPT $PASSWORD data/.htpasswd
chmod $OPT $SECURITY lib/LocalSite.cfg

echo "Updates completed"
