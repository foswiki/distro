#! /usr/bin/perl -w

# This script is used by the build script when building a TWiki release.
# It is used to create the documents in the TWiki root.
# It creates complete stand-alone HMTL versions of TWiki topics which
# requires no external resources. This is because especiall the INSTALL.html
# is expected to be read by a browser as a file without having a working TWiki
# installation.
# It expects the topic viewed as HTML in the plain skin in STDIN and returns the
# filtered topic in STDOUT
# The script does the following processing
# - Reduce the header section to a bare minimum so no CSS or scripts are loaded
# - Removes all images
# - Changes all links from pointing to the server that was used for the build to
#   twiki.org

use strict;

BEGIN {
    use File::Spec;

    my $LIB_ENV = $ENV{FOSWIKI_LIBS} || $ENV{TWIKI_LIBS} || '';

    unshift @INC, split( /:/, $LIB_ENV );
    unshift @INC, '../lib/CPAN/lib/';
    unshift @INC, '../lib/';

}
use Foswiki;

{

    # Read entire file from STDIN
    local $/;
    my $topichtml = <>;

    $topichtml =~ s|(?<=[?;&])FOSWIKISESSID=\w*[;&]?||g;

# Replace the header with a minimal header to avoid all references to other files
    $topichtml =~
s|<head>.*?<title>\s*(\S*).*?</title>.*?</head>|<head><title>$1</title></head>|gs;

# Remove image tags so we avoid dependance of other files or internet connection
    $topichtml =~ s|<img.*?>||g;

    # Changes all links to attachments to twiki.org
    $topichtml =~
s|$Foswiki::cfg{DefaultUrlHost}$Foswiki::cfg{PubUrlPath}/*|http://foswiki.org/pub/|g;

    # Changes all links to topics to twiki.org
    $topichtml =~
s|($Foswiki::cfg{DefaultUrlHost}$Foswiki::cfg{ScriptUrlPath}/view)/*|http://foswiki.org/|g;

    #This URL param is not wanted when we link to twiki.org
    $topichtml =~ s/href="\?skin=plain#/href="#/g;

    # Send the modified file to STDOUT
    print $topichtml;

}
