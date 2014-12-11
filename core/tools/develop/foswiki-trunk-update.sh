#!/bin/sh

ROOT=/usr/home/trunk.foswiki.org
PROD=/home/foswiki.org/public_html

cd $ROOT

ls -la $ROOT/core/working/work_areas/FoswikiOrgPlugin/distro
ls -la $ROOT/core/lib/Foswiki.pm

# Whenever anyone commits to distro,  the webhook should update the distro workarea file.
# This script updates Foswiki.pm.   So if distro is older than Foswiki.pm, we can
# skip the trunk rebuild.  Could also check FoswikiOrgPlugin and FoswikirefsPlugin.

if [ $ROOT/core/working/work_areas/FoswikiOrgPlugin/distro -ot $ROOT/core/lib/Foswiki.pm ];
then
   echo Skipping trunk update.  core/lib/Foswiki.pm is newer than core/working/work_areas/FoswikiOrgPlugin/distro
   exit
fi

git checkout core/lib/Foswiki.pm
git status -uno
git stash save --quiet

git reset HEAD --hard

# Clean everything except
# - Configuration:  bin/LocalLib and lib/LocalSite
# - working.  Has cgi sessions, plugin storage.
# - Main and Sandbox webs - they get updated
#    other webs are either symlinks that will be re-established, or can be discarded, like Trash
# - Logs in data: debug, error, event and configure

git clean -fdx \
--exclude="logs" \
--exclude="core/bin/LocalLib*" --exclude="core/lib/LocalSite*" \
--exclude="core/working" \
--exclude="core/data/Main" --exclude="core/pub/Main" \
--exclude="core/data/Sandbox" --exclude="core/pub/Sandbox" \
--exclude="core/data/Trash" --exclude="core/pub/Trash" \
--exclude="core/data/configur*" --exclude="core/data/debug*" --exclude="core/data/error*" --exclude="core/data/events*" --exclude="core/data/log*" --exclude="core/data/warn*"

echo Pulling updates from github
git pull --force
cd $ROOT/FoswikiOrgPlugin
git pull --force
cd $ROOT/FoswikirefsPlugin
git pull --force

# Remove broken links.
echo Removing broken links
cd $ROOT
find -L . -type l -exec rm \{\} \;

# Restore the modified files, install the default modules, and optional extensions
cd $ROOT
git stash pop --quiet
cd $ROOT/core
perl -T pseudo-install.pl -link default
perl -T pseudo-install.pl -link JsonRpcContrib
perl -T pseudo-install.pl -link ConfigurePlugin
perl -T pseudo-install.pl -link FoswikiOrgPlugin
perl -T pseudo-install.pl -link FoswikirefsPlugin

# Copy any files from the foswiki.org site that are lost during the git clean.
cp -a $PROD/data/System/WebLeftBarFoswikiWebsList.txt* $ROOT/core/data/System/.
cp -a $PROD/data/System/FoswikiSiteChanges.txt* $ROOT/core/data/System/.
cp -a $PROD/data/System/WebTopBar* $ROOT/core/data/System/.

# Modify Foswiki.pm to show the last revision
REV=`git log --abbrev=12 --format=format:%h:%ci -1`
cd $ROOT/core/lib
sed -e "s/\(RELEASE = '\)/\1GIT: $REV: /" Foswiki.pm > Foswiki.pm.new
mv Foswiki.pm.new Foswiki.pm

# Make sure we have links to all non-existing webs to trunk
cd $ROOT/core/lib

for dir in data pub; do
    cd ../$dir
    for f in $PROD/$dir/*; do
        if [ -d $f -a ! -e `basename $f` ]; then
            echo Linking $f into `pwd`
            ln -s $f
        fi
    done
done
