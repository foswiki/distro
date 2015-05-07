# See bottom of file for license and copyright information
package Foswiki::Iterator::AggregateEventIterator;

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

---++ =Foswiki::Iterator::AggregateEventIterator=
Private subclass of Foswiki::AggregateIterator that implements the snoopNext method

=cut

# Private subclass of AggregateIterator that can snoop Events.
require Foswiki::AggregateIterator;
our @ISA = ('Foswiki::AggregateIterator');

sub new {
    my ( $class, $list, $unique ) = @_;
    my $this = bless(
        {
            Itr_list    => $list,
            Itr_index   => 0,
            index       => 0,
            process     => undef,
            filter      => undef,
            next        => undef,
            unique      => $unique,
            unique_hash => {}
        },
        $class
    );
    return $this;
}

=begin TML

---+++ ObjectMethod snoopNext() -> $boolean
Return the field hash of the next availabable record.

=cut

sub snoopNext {
    my $this = shift;
    return $this->{list}->snoopNext();
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

