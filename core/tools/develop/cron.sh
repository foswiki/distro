#!/bin/sh
cd /usr/home/trunk.foswiki.org

#WEBS="Main TWiki Sandbox _default Trash TestCases";

# Cleanup.
# Delete wrongly created files in shipped webs
# Revert modified files
#for web in $WEBS; do
#    # Note: ignores changes to properties
#    svn status --no-ignore data/$web pub/$web \
#        | egrep '^(I|\?|M|C)' \
#        | sed 's/^\(I\|\?\)...../rm -rf/' \
#        | sed 's/^\(M\|C\)...../svn revert/' \
#        | sh
#done

svn revert core/lib/Foswiki.pm
svn update
REV=`svnlook youngest /home/svn/nextwiki`
cd core
perl pseudo-install.pl -link default
cd lib
sed -e "s/\(RELEASE = '\)/\1SVN $REV: /" Foswiki.pm > Foswiki.pm.new
mv Foswiki.pm.new Foswiki.pm
cd ../data
for f in /home/foswiki.org/data/*; do
    if [ -d $f -a ! -e `basename $f` ]; then
        ln -s $f
    fi
done
cd ../pub
for f in /home/foswiki.org/pub/*; do
    if [ -d $f -a ! -e `basename $f` ]; then
        ln -s $f
    fi
done
