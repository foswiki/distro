#!/bin/sh

ROOT=/usr/home/trunk.foswiki.org
PROD=/home/foswiki.org/public_html

#ROOT=/var/www/github/foswiki
#PROD=/var/www/foswiki/trunk/core

cd $ROOT/core
git checkout lib/Foswiki.pm
git status -uno
git stash save --quiet

cd $ROOT
# Make sure there are no other manual edits in the way
git submodule foreach 'git reset HEAD --hard'

# Clean everything except
# - Configuration:  bin/LocalLib and lib/LocalSite
# - working.  Has cgi sessions, plugin storage.
# - Main and Sandbox webs - they get updated
#    other webs are either symlinks that will be re-established, or can be discarded, like Trash
# - Logs in data: debug, error, event and configure

git submodule foreach 'git clean -fdx \
--exclude="bin/LocalLib*" --exclude="lib/LocalSite*" \
--exclude="working" \
--exclude="data/Main" --exclude="pub/Main" \
--exclude="data/Sandbox" --exclude="pub/Sandbox" \
--exclude="data/Trash" --exclude="pub/Trash" \
--exclude="data/configur*" --exclude="data/debug*" --exclude="data/error*" --exclude="data/events*" --exclude="data/log*" --exclude="data/warn*" \
|| :'

# Pull the superproject,  then run sync and init to pick up new extensions
echo Run git pull, and if changes, init the submodules
git pull
git submodule sync
git submodule update --init

# Update all the submodules to their latest commit
echo Running git submodule update --remote
git submodule update --remote

# Note, this leaves the submodules in a detached state
# We could do a git submodule foreach git checkout master
# but by not doing this,  it's possible to have different extensions running
# different branches per their .gitmodules configuration.

# Remove broken links.
echo Removing broken links
find -L . -type l -exec rm \{\} \;

# Restore the modified files, install the default modules, and optional extensions
cd $ROOT/core
git stash pop --quiet
perl -T pseudo-install.pl -link default
perl -T pseudo-install.pl -link FoswikiOrgPlugin
# Before adding any extensions here,  add them to the superproject
# git submodule add -b <branch> https://github.com/foswiki/<extension>.git  <extension>
# and push to the trunk.foswiki.org branch.

# Copy any files from the foswiki.org site that are lost during the git clean.
cp -a $PROD/data/System/WebLeftBarFoswikiWebsList.txt* $ROOT/core/data/System/.
cp -a $PROD/data/System/FoswikiSiteChanges.txt* $ROOT/core/data/System/.
cp -a $PROD/data/System/WebTopBar* $ROOT/core/data/System/.

# Modify Foswiki.pm to show the last revision
REV=`git log --abbrev=12 --format=format:%h:%ci -1`
cd lib
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
