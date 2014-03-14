# See bottom of file for license and copyright information
package Foswiki::Search::Node;

=begin TML

---+ package Foswiki::Search

Refactoring mid-step that contains a set of SEARCH tokens and options.

=cut

use strict;
use warnings;

use Assert;
use Error qw( :try );

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

# Some day this may usefully be an infix node
#use Foswiki::Infix::Node ();
#our @ISA = ('Foswiki::Infix::Node');

=begin TML

---++ ClassMethod new($search, $tokens, $options)

Construct a search token container.

=cut

sub new {
    my ( $class, $search, $tokens, $options ) = @_;
    my $this = bless(
        {
            tokens  => $tokens,
            search  => $search,
            options => $options,
        },
        $class
    );
    return $this;
}

=begin TML

---++ ObjectMethod tokens() -> \@tokenList

Return a ref to a list of tokens that are ANDed to perform the search.

=cut

sub tokens {
    my $this = shift;
    return [] unless $this->{tokens};
    return $this->{tokens};
}

=begin TML

---++ ObjectMethod isEmpty() -> boolean

Return true if this search is empty (has no tokens)

=cut

sub isEmpty {
    my $this = shift;
    return !( $this->{tokens} && scalar( @{ $this->{tokens} } ) > 0 );
}

sub stringify {
    my $this = shift;
    return
      join( ' ', @{ $this->{tokens} } ) . ' {'
      . join( ',',
        map  { "$_=>$this->{options}->{$_}" }
        grep { !/^_/ } keys %{ $this->{options} } )
      . '}';
}

=begin TML

---++ ObjectMethod simplify(%opts)

does nothing yet

=cut

sub simplify {
}

1;
__END__
Author: Sven Dowideit - http://fosiki.com

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
