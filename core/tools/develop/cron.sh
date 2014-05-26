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

# Revert Foswiki.pm as we modified it to show the last revision
svn revert core/lib/Foswiki.pm

# Update to the latest version (and don't stall on conflicts)
svn update --accept 'theirs-full'

# Install the default modules
cd core
perl -T pseudo-install.pl -link default
perl -T pseudo-install.pl -link FoswikiOrgPlugin

# Remove broken links
find -L . -type l -exec rm \{\} \;

# Modify Foswiki.pm to show the last revision
REV=`svnlook youngest /home/svn/nextwiki`
cd lib
sed -e "s/\(RELEASE = '\)/\1SVN $REV: /" Foswiki.pm > Foswiki.pm.new
mv Foswiki.pm.new Foswiki.pm

# Make sure we have links to all non-existing webs to trunk
for dir in data pub; do
    cd ../$dir
    for f in /home/foswiki.org/public_html/$dir/*; do
        if [ -d $f -a ! -e `basename $f` ]; then
            ln -s $f
        fi
    done
done
