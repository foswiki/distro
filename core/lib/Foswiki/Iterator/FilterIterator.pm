# See bottom of file for license and copyright information

=begin

---+ package Foswiki::Iterator::FilterIterator

Iterator that filters another iterator based on the results from a function.

=cut

package Foswiki::Iterator::FilterIterator;

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

---++ ClassMethod new( $iter, $sub, $data )
Construct a new iterator that will filter $iter based on the results from
$sub. $sub should return 0 if the next() from $iter should be filtered and
1 if it should be treated as the next item in the sequence.

$data is an optional arbitrary data item which will be passed to $sub in $_[1]

=cut

sub new {
    my ( $class, $iter, $sub, $data ) = @_;
    ASSERT( UNIVERSAL::isa( $iter, 'Foswiki::Iterator' ) ) if DEBUG;
    ASSERT( ref($sub) eq 'CODE' ) if DEBUG;
    my $this = bless( {}, $class );
    $this->{iterator} = $iter;
    $this->{filter}   = $sub;
    $this->{data}     = $data;
    $this->{next}     = undef;
    $this->{pending}  = 0;
    return $this;
}

#lie - give the unfiltered count for speed.
sub numberOfTopics {
    my $this = shift;
    return $this->{iterator}->numberOfTopics();
}

sub nextWeb {
    my $this = shift;
    $this->{iterator}->nextWeb();
}

sub sortResults {
    my $this = shift;
    $this->{iterator}->sortResults(@_);
}

# See Foswiki::Iterator for a description of the general iterator contract
sub hasNext {
    my $this = shift;
    return 1 if $this->{pending};
    while ( $this->{iterator}->hasNext() ) {
        $this->{next} = $this->{iterator}->next();
        if ( &{ $this->{filter} }( $this->{next}, $this->{data} ) ) {
            $this->{pending} = 1;
            return 1;
        }
    }
    return 0;
}

#WARNING: foswiki has always skipped results before evaluating the filter - this is for speed, but a terrible thing to do
sub skip {
    my $this  = shift;
    my $count = shift;

    #ask CAN skip() for faster path
    if ( $this->{iterator}->can('skip') ) {
        $count = $this->{iterator}->skip($count);

        if ( $this->{iterator}->hasNext() ) {
            $this->{next}    = $this->{iterator}->next();
            $this->{pending} = 1;
            $count--;
        }
    }
    else {

        #brute force
        while (
            ( $count > 0
            ) #must come first - don't want to advance the inner itr if count ==0
            and $this->{iterator}->hasNext()
          )
        {
            $count--;
            $this->{next} =
              $this->{iterator}->next()
              ;    #drain next, so hasNext goes to next element
        }
    }

    if ( $count >= 0 ) {

        #skipped past the end of the set
        $this->{next}    = undef;
        $this->{pending} = 0;
    }
    print STDERR
"--------------------------------------------FilterIterator::skip() => $count\n"
      if Foswiki::Iterator::MONITOR;

    return $count;
}

# See Foswiki::Iterator for a description of the general iterator contract
sub next {
    my $this = shift;
    return unless $this->hasNext();
    $this->{pending} = 0;
    return $this->{next};
}

# See Foswiki::Iterator for a description of the general iterator contract
sub reset {
    my ($this) = @_;

    return unless ( $this->{iterator}->reset() );
    $this->{next}    = undef;
    $this->{pending} = 0;

    return 1;
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
