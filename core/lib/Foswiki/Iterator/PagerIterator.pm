# See bottom of file for license and copyright information

=begin

---+ package Foswiki::Iterator::PagerIterator

Iterator that Pages another iterator 

=cut

package Foswiki::Iterator::PagerIterator;

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

---++ ClassMethod new( $iter, $pagesize, $showpage)

skip a certain number of results based on pagesize and page number

(page 1 is the first page)

=cut

sub new {
    my ( $class, $iter, $pagesize, $showpage ) = @_;
    ASSERT( UNIVERSAL::isa( $iter, 'Foswiki::Iterator' ) ) if DEBUG;

    my $this = bless( {}, $class );
    $this->{iterator} = $iter;

    $this->{next} = undef;
    $this->{pending} =
      0;    #has 'hasNext' already been called, but 'next' hasn't been

    $this->{pagesize} =
         $pagesize
      || $Foswiki::cfg{Search}{DefaultPageSize}
      || 25;
    $this->{showpage} = $showpage;
    $this->{showpage} = 1 unless ( defined( $this->{showpage} ) );

    $this->{pager_skip_results_from} =
      $this->{pagesize} * ( $this->{showpage} - 1 );
    print STDERR
"    $this->{pager_skip_results_from} = $this->{pagesize} * ($this->{showpage}-1);\n"
      if Foswiki::Iterator::MONITOR;
    $this->{pager_result_count} = $this->{pagesize};

    return $this;
}

sub pagesize {
    my $this = shift;
    return $this->{pagesize};
}

sub showpage {
    my $this = shift;
    return $this->{showpage};
}

#lie - give the requested pagesize - it might be less, if we're at the end of the list
#and we can never know if there is just one more, as the underlying iterator may have only asked for pagesize reaults
#so it can't tell us
sub numberOfTopics {
    my $this = shift;
    if ( !$this->hasNext() && ( $this->{pager_result_count} > 0 ) ) {
        return $this->{pagesize} - $this->{pager_result_count};
    }
    else {
        #we're still iterating, so we don't know the page size
        return $this->{pagesize};
    }
}

#another lie - this hopes that the inner iterator knows the number, and isn't just guessing.
sub numberOfPages {
    my $this = shift;
    if ( !$this->hasNext() && ( $this->{pager_result_count} > 0 ) ) {

#if we've exhausted the undelying iterator, and have not got pagesize elements, then we know there are no more.
        return $this->showpage();
    }
    else {
        #we're still iterating, so we don't know the page size
        return
          int( $this->{iterator}->numberOfTopics() / $this->{pagesize} ) + 1;
    }
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

    if ( $this->{pager_skip_results_from} > 0 ) {
        $this->{pager_skip_results_from} =
          $this->skip( $this->{pager_skip_results_from} );

        #this already loads $this->{next}

    }
    else {
        if ( $this->{iterator}->hasNext() ) {
            $this->{next}    = $this->{iterator}->next();
            $this->{pending} = 1;
        }
    }

    if ( $this->{pending} ) {
        if ( $this->{pager_result_count} <= 0 ) {

            #SVEN - huh?
            #finished.
            $this->{next}    = undef;
            $this->{pending} = 0;
            return 0;
        }
        $this->{pager_result_count}--;
        return 1;
    }
    return 0;
}

#skip X elements (returns 0 if successful, or number of elements remaining to skip if there are not enough elements to skip)
#skip must set up next as though hasNext was called.
sub skip {
    my $this  = shift;
    my $count = shift;

    print STDERR
"--------------------------------------------PagerIterator::skip($count)\n"
      if Foswiki::Iterator::MONITOR;

    #ask CAN skip() for faster path
    if ( 1 == 2 && $this->{iterator}->can('skip') ) {
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
            ( $count >= 0
            ) #must come first - don't want to advance the inner itr if count ==0
            and $this->{iterator}->hasNext()
          )
        {
            $count--;
            $this->{next} =
              $this->{iterator}->next()
              ;    #drain next, so hasNext goes to next element
            $this->{pending} = defined( $this->{next} );
        }
    }

    #in the bute force method, $count == -1 if there were enough elements.
    if ( $count >= 0 ) {

        #skipped past the end of the set
        $this->{next}    = undef;
        $this->{pending} = 0;
    }
    print STDERR
"--------------------------------------------PagerIterator::skip() => $count\n"
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

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
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
