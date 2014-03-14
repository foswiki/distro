# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::ListIterator
*implements* Foswiki::Iterator

Iterator over a perl list

WARNING: this Iterator will skip any elements that are == undef. 
SMELL: hasNext should not 'return 1 if defined($this->{next}), but rather use a boolean - to allow array elements to be undef too.

=cut

package Foswiki::ListIterator;
use strict;
use warnings;

use Foswiki::Iterator ();
our @ISA = ('Foswiki::Iterator');

use Assert;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ new(\@list)

Create a new iterator over the given list. Designed primarily for operations
over fully defined lists of object references. The list is not damaged in
any way.

=cut

sub new {
    my ( $class, $list ) = @_;

    $list = [] unless defined $list;

    ASSERT( UNIVERSAL::isa( $list, 'ARRAY' ) ) if DEBUG;

    my $this = bless(
        {
            list    => $list,
            index   => 0,
            process => undef,
            filter  => undef,
            next    => undef,
        },
        $class
    );
    return $this;
}

=begin TML

---++ hasNext() -> $boolean

Returns false when the iterator is exhausted.

<verbatim>
my $it = new Foswiki::ListIterator(\@list);
while ($it->hasNext()) {
   ...
</verbatim>

=cut

sub hasNext {
    my ($this) = @_;
    return 1
      if defined( $this->{next} )
      ; #SMELL: this is still wrong if the array element == undef, but at least means zero is an element
    my $n;
    do {
        if ( $this->{list} && $this->{index} < scalar( @{ $this->{list} } ) ) {
            $n = $this->{list}->[ $this->{index}++ ];
        }
        else {
            return 0;
        }
    } while ( $this->{filter} && !&{ $this->{filter} }($n) );
    $this->{next} = $n;
    print STDERR "ListIterator::hasNext -> $this->{index} == $this->{next}\n"
      if Foswiki::Iterator::MONITOR;
    return 1;
}

=begin TML

---++ skip(count) -> $countremaining

skip X elements (returns 0 if successful, or number of elements remaining to skip if there are not enough elements to skip)
skip must set up next as though hasNext was called.

=cut

sub skip {
    my $this  = shift;
    my $count = shift;

    if ( defined( $this->{next} ) ) {
        $count--;
    }

    $count ||= 0;

    return 0 if ( $count <= 0 );
    print STDERR
"--------------------------------------------ListIterator::skip($count)  $this->{index}, "
      . scalar( @{ $this->{list} } ) . "\n"
      if Foswiki::Iterator::MONITOR;

    my $length = scalar( @{ $this->{list} } );

    if ( ( $this->{index} + $count ) >= $length ) {

        #list too small
        $count = $this->{index} + $count - $length;
        $this->{index} = 1 + $length;
    }
    else {
        $this->{index} += $count;
        $count = 0;
    }
    $this->{next} = undef;
    my $hasnext = $this->hasNext();
    if ($hasnext) {
        $count--;
    }
    print STDERR
"--------------------------------------------ListIterator::skip() => $this->{index} $count, $hasnext\n"
      if Foswiki::Iterator::MONITOR;

    return $count;
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

For example,
<verbatim>
my @list = ( 1, 2, 3 );

my $it = new Foswiki::ListIterator(\@list);
$it->{filter} = sub { return $_[0] != 2 };
$it->{process} = sub { return $_[0] + 1 };
while ($it->hasNext()) {
    my $x = $it->next();
    print "$x, ";
}
</verbatim>
will print
<verbatim>
2, 4
</verbatim>

=cut

sub next {
    my $this = shift;
    $this->hasNext();
    my $n = $this->{next};
    $this->{next} = undef;
    $n = &{ $this->{process} }($n) if $this->{process};
    return $n;
}

=begin TML

---++ ObjectMethod all() -> @list

Exhaust the iterator. Return all remaining elements in the iteration
as a list. The returned list should be considered to be immutable.

This method is cheap if it is called when the cursor is at the first
element in the iteration, and expensive otherwise, as it requires a list
copy to be made.

=cut

sub all {
    my $this = shift;
    if ( $this->{index} ) {
        my @copy = @{ $this->{list} };    # don't damage the original list
        splice( @copy, 0, $this->{index} );
        $this->{index} = scalar( @{ $this->{list} } );
        return @copy;
    }
    else {

        # At the start (good)
        $this->{index} = scalar( @{ $this->{list} } );
        return @{ $this->{list} };
    }
}

=begin TML

---++ reset() -> $boolean

Start at the begining of the list
<verbatim>
$it->reset();
while ($it->hasNext()) {
   ...
</verbatim>

=cut

sub reset {
    my ($this) = @_;
    $this->{next}  = undef;
    $this->{index} = 0;

    return 1;
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
of this distribution.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
