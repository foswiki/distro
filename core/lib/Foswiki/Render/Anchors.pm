# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Render::Anchors

Support for rendering anchors. Objects of this class represent
a set of generated anchor names, which must be unique in a rendering
context (topic). The renderer maintains a set of these objects, one
for each topic, to ensure that anchor names are not re-used.

=cut

package Foswiki::Render::Anchors;

use strict;
use warnings;
use Assert;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ ClassMethod new()

Construct a new anchors set.

=cut

sub new {
    return bless( { names => {} }, shift );
}

=begin TML

---++ ObjectMethod clear()

Clear the anchor set. Clearing the anchor set will cause it to forget
any anchors generated to date.

=cut

sub clear {
    my $this = shift;
    $this->{names} = {};
}

=begin TML

---++ ObjectMethod add($text) -> $name
Add a new anchor to the set. Return the name that was added.
Note that if a name is added twice, it isn't an error, but only
the one name is added.

=cut

sub add {
    my ( $this, $text ) = @_;
    my $anchorName = make($text);
    $this->{names}->{$anchorName} = 1;
    return $anchorName;
}

=begin TML

---++ ObjectMethod addUnique($text [,$alreadyMade]) -> $uniqueName
Add a new anchor to the set. if it's already present, rename it.

If =$alreadyMade=, then $text is assumed to be a valid anchor name
that was made by =make=.

Return the name that was added.

=cut

sub addUnique {
    my ( $this, $text, $alreadyMade ) = @_;
    my $anchorName;
    if ($alreadyMade) {
        $anchorName = $text;
    }
    else {
        $anchorName = make($text);
    }
    my $cnt    = 1;
    my $suffix = '';

    while ( exists $this->{names}->{ $anchorName . $suffix } ) {

        # $anchorName.$suffix must _always_ be 'compatible', or things
        # would get complicated (whatever that means)
        $suffix = '_AN' . $cnt++;

        # limit resulting name to 32 chars
        $anchorName = substr( $anchorName, 0, 32 - length($suffix) );

        # this is only needed because '__' would not be 'compatible'
        $anchorName =~ s/_+$//g;
    }
    $anchorName .= $suffix;
    $this->{names}->{$anchorName} = 1;
    return $anchorName;
}

=begin TML

---++ StaticMethod make( $text ) -> $name

Make an anchor name from some text, subject to:
   1 Given the same text, this function must always return the same
     anchor name
   2 NAME tokens must begin with a letter ([A-Za-z]) and may be
     followed by any number of letters, digits ([0-9]), hyphens ("-"),
     underscores ("_"), colons (":"), and periods (".").
     (from http://www.w3.org/TR/html401/struct/links.html#h-12.2.1)

The making process tranforms an arbitrary text string to a string that
can legally be used for an HTML anchor.

=cut

sub make {
    my ($text) = @_;

    $text =~ s/^\s*(.*?)\s*$/$1/;
    $text =~ s/$Foswiki::regex{headerPatternNoTOC}//g;

    if ( $text =~ m/^$Foswiki::regex{anchorRegex}$/ ) {

        # accept, already valid -- just remove leading #
        return substr( $text, 1 );
    }

    # $anchorName is a *byte* string. If it contains any wide characters
    # the encoding algorithm will not work.
    #ASSERT($text !~ /[^\x00-\xFF]/) if DEBUG;
    $text =~ s/[^\x00-\xFF]//g;
    ASSERT( $text !~ /[^\x00-\xFF]/ ) if DEBUG;

    # SMELL:  This corrects for anchors containing < and >
    # which for some reason are encoded when building the anchor, but
    # un-encoded when building the link.
    #
    # Convert &, < and > back from entity
    $text =~ s/&lt;/</g;
    $text =~ s/&gt;/>/g;
    $text =~ s/&amp;/&/g;

    # strip out potential links so they don't get rendered.
    # remove double bracket link
    $text =~ s/\[(?:\[.*?\])?\[(.*?)\]\s*\]/$1/g;

    # need to pick <nop> out separately as it may be nested
    # inside a HTML tag without a problem
    $text =~ s/<nop>//g;

    # remove HTML tags and entities
    $text =~ s/<\/?[a-zA-Z][^>]*>//gi;
    $text =~ s/&#?[a-zA-Z0-9]+;//g;

    # remove escape from escaped wikiWords
    $text =~
      s/!($Foswiki::regex{wikiWordRegex}|$Foswiki::regex{abbrevRegex})/$1/g;

    # remove spaces
    $text =~ s/\s+/_/g;

    # use _ as an escape character to escape any byte outside the
    # range specified by http://www.w3.org/TR/html401/struct/links.html
    $text =~ s/([^A-Za-z0-9:._])/'_'.sprintf('%02d', ord($1))/ge;

    # clean up a bit
    $text =~ s/__/_/g;
    $text =~ s/^_*//;
    $text =~ s/_*$//;

    # Ensure the anchor always starts with an [A-Za-z]
    $text = 'A_' . $text unless $text =~ m/^[A-Za-z]/;

    return $text;
}

=begin TML

---++ ObjectMethod makeHTMLTarget($name) -> $id
Make an id that can be used as the target of links.

=cut

sub makeHTMLTarget {
    my ( $this, $name ) = @_;

    my $goodAnchor = make($name);
    my $id = $this->addUnique( $goodAnchor, 1 );

    if ( $Foswiki::cfg{RequireCompatibleAnchors} ) {

        # Add in extra anchors compatible with old formats, as required
        require Foswiki::Compatibility;
        my @extras = Foswiki::Compatibility::makeCompatibleAnchors($name);
        foreach my $extra (@extras) {
            next if ( $extra eq $goodAnchor );
            $id = $this->addUnique( $extra, 1 );
        }
    }
    return $id;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to a few lines of the code in this
file as follows:

Copyright (C) 2001-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
