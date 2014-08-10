#!/bin/sh

ROOT=/usr/home/trunk.foswiki.org
PROD=/home/foswiki.org/public_html

#ROOT=/var/www/github/foswiki
#PROD=/var/www/foswiki/trunk/core

cd $ROOT/core
git checkout lib/Foswiki.pm
git status -uno
git stash save

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

# Pull the superproject.  If anything changed, then run an init to pick up new default extensions
echo Run git pull, and if changes, init the submodules
git pull
git submodule sync
git submodule update --init

# Update all the submodules
echo Running git submodule update --remote
git submodule update --remote

# Remove broken links.
echo Removing broken links
find -L . -type l -exec rm \{\} \;

# Install the default modules, and optional extensions
cd $ROOT/core
git stash pop
perl -T pseudo-install.pl -link default
perl -T pseudo-install.pl -link FoswikiOrgPlugin

# Modify Foswiki.pm to show the last revision
REV=`git rev-parse --short=12 HEAD`
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
