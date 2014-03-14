# See bottom of file for license and copyright information

=begin

---+ package Foswiki::Iterator::ProcessIterator

Iterator that filters another iterator by calling an external process on each
element in the iteration.

=cut

package Foswiki::Iterator::ProcessIterator;

use strict;
use warnings;
use Assert;

use Foswiki::Iterator ();
our @ISA = ('Foswiki::Iterator');

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ ClassMethod new( $iter, $sub )
Construct a new iterator that will filter $iter by calling
$sub. on each element. $sub should return the filtered value
for the element.

=cut

sub new {
    my ( $class, $iter, $sub, $data ) = @_;
    ASSERT( UNIVERSAL::isa( $iter, 'Foswiki::Iterator' ) ) if DEBUG;
    ASSERT( ref($sub) eq 'CODE' ) if DEBUG;
    my $this = bless( {}, $class );
    $this->{iterator} = $iter;
    $this->{process}  = $sub;
    $this->{data}     = $data;
    $this->{next}     = undef;
    return $this;
}

# See Foswiki::Iterator for a description of the general iterator contract
sub hasNext {
    my $this = shift;
    return $this->{iterator}->hasNext();
}

# See Foswiki::Iterator for a description of the general iterator contract
sub next {
    my $this = shift;
    return &{ $this->{process} }( $this->{iterator}->next(), $this->{data} );
}

# See Foswiki::Iterator for a description of the general iterator contract
sub reset {
    my ($this) = @_;

    #TODO: need to carefully consider what side effects this has

    return;
}

sub all {
    my $this = shift;
    my @results;
    while ( $this->hasNext() ) {
        push( @results, $this->next() );
    }
    return @results;
}

1;
__END__
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
