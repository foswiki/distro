#!/usr/bin/perl -w
BEGIN {
    unshift @INC, split( /:/, $ENV{TWIKI_LIBS} );
}
use Foswiki::Contrib::Build;

# Create the build object
$build = new Foswiki::Contrib::Build('UnitTestContrib');

# (Optional) Set the details of the repository for uploads.
# This can be any web on any accessible TWiki installation.
# These defaults will be used when expanding tokens in .txt
# files, but be warned, they can be overridden at upload time!

# name of web to upload to
$build->{UPLOADTARGETWEB} = 'Plugins';
# Full URL of pub directory
$build->{UPLOADTARGETPUB} = 'http://twiki.org/p/pub';
# Full URL of bin directory
$build->{UPLOADTARGETSCRIPT} = 'http://twiki.org/cgi-bin';
# Script extension
$build->{UPLOADTARGETSUFFIX} = '';

# Build the target on the command line, or the default target
$build->build($build->{target});

