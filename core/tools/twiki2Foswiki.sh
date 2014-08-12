#!/bin/bash
# Change files from TWiki namespace to Foswiki
# $1 - name of the subdirectory to operate on
# e.g 
function process () {
    [ -f $1 -a "$1" != "mapname.sh" ] && { \
        grep -s -q "TWiki" $1 && {
            sed -e 's.data/TWiki/.data/System/.g' $1 | \
            sed -e 's.pub/TWiki/.pub/System/.g' | \
            sed -e 's/TWiki::/Foswiki::/g' $1 | \
            sed -e 's/new TWiki(/new Foswiki(/g' | \
            sed -e 's/package TWiki;/package Foswiki;/g' | \
            sed -e 's/TWiki Enterprise/Foswiki/g' | \
            sed -e 's/TWiki Collaboration/Foswiki Collaboration/g' | \
            sed -e 's/require TWiki/require Foswiki/g' | \
            sed -e 's/use TWiki;/use Foswiki;/g' | \
            sed -e "s/isa( *'TWiki' *)/isa('Foswiki')/g" | \
            sed -e 's/TWiki Contributors/Foswiki Contributors/g' | \
            sed -e 's./TWiki/./Foswiki/.g' | \
            sed -e 's/TWiki\.org/Foswiki.org/g' | \
            sed -e 's/TWiki\.spec/Foswiki.spec/g' | \
            sed -e 's/TWiki\.pot/Foswiki.pot/g' | \
            sed -e 's/TWiki\.pm/Foswiki.pm/g' \
                > /tmp/blah;
            mv /tmp/blah $1;
        }
    }
}

function process_module () {
    echo "Processing $1";
    [ -d $1/lib/TWiki -a ! -d $1/lib/Foswiki ] && \
        svn mv $1/lib/TWiki $1/lib/Foswiki
    [ -d $1/data/TWiki -a ! -d $1/data/System ] && \
        svn mv $1/data/TWiki $1/data/System
    [ -d $1/pub/TWiki -a ! -d $1/pub/System ] && \
        svn mv $1/pub/TWiki $1/pub/System
    for f in `find $1 -name '\.svn' -prune -o -name '*.pm'`; do \
        process $f; done
    for f in `find $1 -name '\.svn' -prune -o -name '*.pl'`; do \
        process $f; done
    for f in `find $1 -name '\.svn' -prune -o -name '*.spec'`; do \
        process $f; done
    for f in `find $1 -name '\.svn' -prune -o -name '*.cfg'`; do \
        process $f; done
    for f in `find $1 -name '\.svn' -prune -o -name 'MANIFEST'`; do \
        process $f; done
    if [ -d $1/bin ]; then
        for f in `find $1/bin -name '\.svn' -prune -o -name '*'`; do \
            process $f; done
        for f in `find $1/bin -name '\.svn' -prune -o -name '\.*'`; do \
            process $f; done
    fi
}

process_module $1
