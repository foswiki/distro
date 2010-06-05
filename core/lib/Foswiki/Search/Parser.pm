# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Search::Parser

Foswiki::Search::Parser is a refactoring mid-step that contains the legacy SEARCH tokens

If if becomes useful, it will become a set of Nodes as for Foswiki::Query

=cut

package Foswiki::Search::Parser;

use strict;
use warnings;

use Assert;
use Error qw( :try );

use Foswiki::Infix::Parser ();
our @ISA = ('Foswiki::Infix::Parser');

use Foswiki::Search::Node ();
use Foswiki::Infix::Error ();

our $MARKER = "\0";

=begin TML

---++ ClassMethod new($session)

Construct a Legacy Search token container (its not yet a proper Node)

=cut

sub new {
    my ( $class, $session ) = @_;
    my $this = bless( { session => $session }, $class );
    return $this;
}

# Initialise on demand before a first parse
sub _initialise {
    my $this = shift;

    return if ( $this->{initialised} );

    # Build pattern of stop words
    my $prefs = $this->{session}->{prefs};
    ASSERT($prefs) if DEBUG;
    $this->{stopwords} = $prefs->getPreference('SEARCHSTOPWORDS') || '';
    $this->{stopwords} =~ s/[\s\,]+/\|/go;
    $this->{stopwords} =~ s/[\(\)]//go;

    $this->{initialised} = 1;
}

=begin TML

---++ ObjectMethod finish()
Break circular references.

=cut

sub finish {
    my $self = shift;

    undef $self->{stopwords};
    undef $self->{initialised};
}

=begin TML

---++ ObjectMethod parse($string, $options) -> tokens..

parses the legacy SEARCH string and makes a 'Node' token container to pass to the algo

# Split the search string into tokens depending on type of search.
# Search is an 'AND' of all tokens - various syntaxes implemented
# by this routine.
=cut

sub parse {
    my ( $this, $searchString, $options ) = @_;

    $this->_initialise();

    my @tokens = ();
    if ( $options->{type} eq 'regex' ) {

        # Regular expression search Example: soap;wsdl;web service;!shampoo
        @tokens = split( /;/, $searchString );

    }
    elsif ( $options->{type} eq 'literal' || $options->{type} eq 'query' ) {

        if ( $searchString eq '' ) {

            # Legacy: empty search returns nothing
        }
        else {

            # Literal search (old style) or query
            $tokens[0] = $searchString;
        }

    }
    else {

        # Keyword search (Google-style) - implemented by converting
        # to regex format. Example: soap +wsdl +"web service" -shampoo

        # Prevent tokenizing on spaces in "literal string"
        $searchString =~ s/(\".*?)\"/&_translateSpace($1)/geo;
        $searchString =~ s/[\+\-]\s+//go;

        # Tokenize string taking account of literal strings, then remove
        # stop words and convert '+' and '-' syntax.
        @tokens =
          grep { !/^($this->{stopwords})$/i }    # remove stopwords
          map {
            s/^\+//o;
            s/^\-/\!/o;
            s/^"//o;
            $_
          }    # remove +, change - to !, remove "
          map { s/$MARKER/ /go; $_ }    # restore space
          split( /[\s]+/, $searchString );    # split on spaces
    }

    my $result = new Foswiki::Search::Node( $searchString, \@tokens, $options );
    return $result;
}

# Convert spaces into translation token characters (typically NULs),
# preventing tokenization.
#
# FIXME: Terminology confusing here!
sub _translateSpace {
    my $text = shift;
    $text =~ s/\s+/$MARKER/go;
    return $text;
}

1;
__END__
Author: Sven Dowideit - http://fosiki.com

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2005-2007 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
