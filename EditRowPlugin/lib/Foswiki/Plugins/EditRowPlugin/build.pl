
#!/usr/bin/perl -w
BEGIN {
    unshift @INC, split( /:/, $ENV{FOSWIKI_LIBS} );
}
use Foswiki::Contrib::Build;

# Create the build object
$build = new Foswiki::Contrib::Build('EditRowPlugin');

# Set the details of the repository for uploads.
# This can be any web on any accessible TWiki installation.

# name of web to upload to
$build->{UPLOADTARGETWEB} = 'Extensions';
# Full URL of pub directory
$build->{UPLOADTARGETPUB} = 'http://foswiki.org/pub';
# Full URL of bin directory
$build->{UPLOADTARGETSCRIPT} = 'http://foswiki.org/bin';
# Script extension
$build->{UPLOADTARGETSUFFIX} = '';

# Build the target on the command line, or the default target
$build->build($build->{target});

