#!/bin/sh
# Usage:
# mklinks.sh [-cp|-echo] <plugin> ...
# Make links from the core into twikiplugins, to pseudo-install these
# components into a subversion checkout area. Default is to process
# all plugins and contribs, or you can do just a subset. Default behaviour
# is to skip a link if there is an existing file in the way. You can also
# request a cp instead of ln -s, which will stomp existing files.
#    -cp - copy files from the twikiplugins area instead of linking them.
#    DESTROYS THE EXISTING INSTALL OF THE PLUGIN EVEN IF FILES HAVE CHANGED
#    -echo - just print the names of files that would be linked/copied
#    <plugin>... list of plugins and contribs to link into the core.
#    Example: CommentPlugin RenderListPlugin JSCalendarContrib
#    Optional, defaults to all plugins and contribs.
shopt -s nullglob

function mklink () {
    link=`echo $1 | sed -e 's#twikiplugins/[A-Za-z0-9]*/##'`
    if [ -L $link ]; then
        # Always kill links
        $destroy $link
    fi
    if [ x$wipeout = x -a -e $link ]; then
        # If we are linking, and there's a file in the way, check
        # if it is different
        x=`diff -q $1 $link`
        if [ "$x" = "" ]; then
            $destroy $link
        else
            echo "diff $1 $link different - Keeping $link intact"
        fi
    else
        target=`dirname $link | sed -e 's/[^\/][^\/]*/../g'`
        # if wipeout is 1, will simply overwrite whatever is already there
        $build $target/$1 $link
    fi
}

# Main program
if [ "$1" = "-cp" ]; then
    shift;
    # must be -r to catch dirs
    build="cp -rf"
    destroy="rm -rf"
    # set wipeout to always overwrite existing installed files
    wipeout=1
elif [ "$1" = "-echo" ]; then
    shift;
    build="echo"
    destroy="echo"
else
    build="ln -s"
    destroy="rm"
wipeout=1
fi

# examine remaining params
params=""
for param in $* ; do
    params="$params twikiplugins/$param"
done

# default is to do all plugins and contribs
if [ "$params" = "" ]; then
    for param in twikiplugins/*Contrib ; do
        params="$params $param"
    done
    for param in twikiplugins/*Plugin ; do
        params="$params $param"
    done
fi

for dir in $params; do
    module=`basename $dir`

    # pub dir
    if [ -d $dir/pub/TWiki/$module ]; then
        mklink $dir/pub/TWiki/$module
    fi
    for pubdir in $dir/pub/*; do
        if [ ! -e pub/`basename $pubdir` ]; then
            mklink $pubdir
        fi
    done

    # lib dir
    for type in Plugins Contrib; do
        if [ -d $dir/lib/TWiki/$type/$module ]; then
            mklink $dir/lib/TWiki/$type/$module
        fi
        for pm in $dir/lib/TWiki/$type/*.pm; do
            mklink $dir/lib/TWiki/$type/*.pm
        done
    done

    # data dir
    if [ -d $dir/data/TWiki ]; then
        for txt in $dir/data/TWiki/*.txt; do
            mklink $txt
        done
    fi

    # templates dir
    if [ -d $dir/templates ]; then
        for tmpl in $dir/templates/*.tmpl; do
            mklink $tmpl
        done
    fi

    # unit tests dir
    if [ -d $dir/test/unit/$module ]; then
        mklink $dir/test/unit/$module
    fi
done

