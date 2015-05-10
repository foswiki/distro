# See bottom of file for license and copyright information
package Foswiki::Iterator::MergeEventIterator;

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

---++ =Foswiki::Iterator::MergeEventIterator=
Private subclass of Foswiki::Iterator that
   * Is passed a array reference of a list of iterator arrays.
   * Scans across the list of iterators using snoopNext to find the iterator with the lowest timestamp
   * returns true to hasNext if any iterator has any records available.
   * returns the record with the lowest timestamp to the next() request.

=cut

require Foswiki::Iterator;
our @ISA = ('Foswiki::Iterator');

sub new {
    my ( $class, $list ) = @_;
    my $this = bless(
        {
            Itr_list_ref => $list,
            process      => undef,
            filter       => undef,
            next         => undef,
        },
        $class
    );
    return $this;
}

=begin TML

---+++ ObjectMethod hasNext() -> $boolean
Scans all the iterators to determine if any of them have a record available.

=cut

sub hasNext {
    my $this = shift;

    foreach my $It ( @{ $this->{Itr_list_ref} } ) {
        return 1 if $It->hasNext();
    }
    return 0;
}

=begin TML

---+++ ObjectMethod next() -> \$hash or @array
Snoop all of the iterators to find the lowest timestamp record, and return the
field hash, or field array, depending up on the requested API version.

=cut

sub next {
    my $this = shift;
    my $lowIt;
    my $lowest;

    foreach my $It ( @{ $this->{Itr_list_ref} } ) {
        next unless $It->hasNext();
        my $nextRec = @{ $It->snoopNext() }[0];
        my $epoch   = $nextRec->{epoch};

        if ( !defined $lowest || $epoch <= $lowest ) {
            $lowIt  = $It;
            $lowest = $epoch;
        }
    }
    return $lowIt->next();
}

1;
__END__
Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2013 Foswiki Contributors. Foswiki Contributors
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

