#! /bin/sh

REPOS="$1"
REV="$2"
let "REV2 = $2 - 20"
if [ "$REV2" -lt "0" ]
then
    let "REV2 = 0"
fi

# Please change paths according to your setup
/usr/local/bin/svn log file://$REPOS -r $REV:$REV2 -v --xml > /tmp/svnlog.xml
/usr/bin/xsltproc $REPOS/hooks/svnlog.xslt /tmp/svnlog.xml > /home/foswiki.org/pub/svn2rss.xml
chmod 777 /tmp/svnlog.xml
