# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Iterator::NumberRangeIterator

Iterator over a range of integer values, with programmable increment.

=cut

package Foswiki::Iterator::NumberRangeIterator;
use Foswiki::Iterator;
our @ISA = ('Foswiki::Iterator');

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

---++ ClassMethod new($start, $end, $inc)
Construct a new iterator from start to end step inc.
The range is inclusive i.e. if $end == $start, you will get an iterator
that returns a single value.

The iteration step is the absolute value of $inc, and defaults to 1.

=cut

sub new {
    my ( $class, $start, $end, $inc ) = @_;
    $inc ||= 1;
    return bless(
        {
            start => $start,
            end   => $end,
            inc   => ( $end > $start ) ? abs($inc) : -abs($inc),
            cur   => $start,
        },
        $class
    );
}

sub hasNext {
    my $this = shift;
    if ( $this->{inc} > 0 ) {
        return $this->{cur} <= $this->{end};
    }
    else {
        return $this->{cur} >= $this->{end};
    }
}

sub next {
    my $this = shift;
    my $res  = $this->{cur};
    $this->{cur} += $this->{inc};
    return $res;
}

sub reset {
    my $this = shift;
    $this->{cur} = $this->{start};
}

1;

__END__
Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010 Foswiki Contributors. All Rights Reserved.
Foswiki Contributors are listed in the AUTHORS file in the root
f this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
