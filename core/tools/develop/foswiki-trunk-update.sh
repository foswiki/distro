#!/bin/sh

#ROOT=/usr/home/trunk.foswiki.org
#PROD=/home/foswiki.org/public_html

ROOT=/var/www/github/foswiki
PROD=/var/www/foswiki/trunk/core

cd $ROOT

# Make sure there are no manual edits in the way
git submodule foreach 'git reset HEAD --hard'

# Clean everything except
# - Configuration:  bin/LocalLib and lib/LocalSite
# - working.  Has cgi sessions, plugin storage.
# - Main and Sandbox webs - they get updated
#    other webs are either symlinks that will be re-established, or can be discarded, like Trash
# - Logs in data: debug, error, event and configure

git submodule foreach 'git clean -fdx -n \
--exclude="bin/LocalLib*" --exclude="lib/LocalSite*" \
--exclude="working" \
--exclude="data/Main" --exclude="pub/Main" \
--exclude="data/Sandbox" --exclude="pub/Sandbox" \
--exclude="data/debug*" --exclude="data/error*" --exclude="data/event*" --exclude="data/configure*" \
|| :'

# Pull the superproject.  If anything changed, then run an init to pick up new default extensions
echo Run git pull, and if changes, init the submodules
[[ $(git pull) = *Already\ up-to-date.* ]] || git submodule update --init

# Update all the submodules
echo Running git submodule update --remote
git submodule update --remote

# Remove broken links.
echo Removing broken links
find -L . -type l -exec rm \{\} \;

# Install the default modules
cd $ROOT/core
perl -T pseudo-install.pl -link default
perl -T pseudo-install.pl -link FoswikiOrgPlugin

# Updating and installing FoswikiOrgPlugin
# *** Probably makes more sense to just add this to the submodules
# for a for a trunk.foswiki.org specific branch of the superproject
#cd ../FoswikiOrgPlugin && git clean -fdx && git pull


# Modify Foswiki.pm to show the last revision
#REV=`svnlook youngest /home/svn/nextwiki`
#cd lib
#sed -e "s/\(RELEASE = '\)/\1SVN $REV: /" Foswiki.pm > Foswiki.pm.new
#mv Foswiki.pm.new Foswiki.pm

# Make sure we have links to all non-existing webs to trunk
cd $ROOT/core
for dir in data pub; do
    cd ../$dir
    for f in $PROD/$dir/*; do
        if [ -d $f -a ! -e `basename $f` ]; then
            ln -s $f
        fi
    done
done
