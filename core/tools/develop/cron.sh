#!/bin/sh
# Regular cleanup of shipped webs.

cd $HOME/twikisvn/core

WEBS="Main TWiki Sandbox _default Trash TestCases";

# Cleanup.
# Delete wrongly created files in shipped webs
# Revert modified files
for web in $WEBS; do
    # Note: ignores changes to properties
    svn status --no-ignore data/$web pub/$web \
        | egrep '^(I|\?|M|C)' \
        | sed 's/^\(I\|\?\)...../rm -rf/' \
        | sed 's/^\(M\|C\)...../svn revert/' \
        | sh
done

svn update
perl pseudo-install.pl -link default
