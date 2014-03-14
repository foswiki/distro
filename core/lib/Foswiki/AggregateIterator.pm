# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::AggregateIterator
*implements* Foswiki::Iterator

Combine multiple iterators into a single iteration.

=cut

package Foswiki::AggregateIterator;
use strict;
use warnings;

use Foswiki::Iterator ();
our @ISA = ('Foswiki::Iterator');

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ new(\@list, $unique)

Create a new iterator over the given list of iterators. The list is
not damaged in any way.

If =$unique= is set, we try to not repeat values.
Warning: =$unique= assumes that the values are strings.

=cut

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

---++ hasNext() -> $boolean

Returns false when the iterator is exhausted.

=cut

sub hasNext {
    my ($this) = @_;
    return 1 if $this->{next};
    my $n;
    do {
        unless ( $this->{list} ) {
            if ( $this->{Itr_index} < scalar( @{ $this->{Itr_list} } ) ) {
                $this->{list} = $this->{Itr_list}->[ $this->{Itr_index}++ ];
            }
            else {
                return 0;    #no more iterators in list
            }
        }
        if ( $this->{list}->hasNext() ) {
            $n = $this->{list}->next();
        }
        else {
            $this->{list} = undef;    #goto next iterator
        }
      } while ( !$this->{list}
        || ( $this->{filter} && !&{ $this->{filter} }($n) )
        || ( $this->{unique} && !$this->unique($n) ) );
    $this->{next} = $n;
    return 1;
}

sub unique {
    my ( $this, $value ) = @_;

    unless ( defined( $this->{unique_hash}{$value} ) ) {
        $this->{unique_hash}{$value} = 1;
        return 1;
    }

    return 0;
}

=begin TML

---++ next() -> $data

Return the next entry in the list.

The iterator object can be customised to pre- and post-process entries from
the list before returning them. This is done by setting two fields in the
iterator object:

   * ={filter}= can be defined to be a sub that filters each entry. The entry
     will be ignored (next() will not return it) if the filter returns false.
   * ={process}= can be defined to be a sub to process each entry before it
     is returned by next. The value returned from next is the value returned
     by the process function.

=cut

sub next {
    my $this = shift;
    $this->hasNext();
    my $n = $this->{next};
    $this->{next} = undef;
    $n = &{ $this->{process} }($n) if $this->{process};

    #print STDERR "next - $n \n";
    return $n;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2007 TWiki Contributors. All Rights Reserved.
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
