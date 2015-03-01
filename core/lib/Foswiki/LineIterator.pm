# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::LineIterator
*implements* Foswiki::Iterator

Iterator over the lines read from a file handle.

=cut

package Foswiki::LineIterator;

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

---++ new( $fh )

Create a new iterator over the given file handle.

=cut

sub new {
    my ( $class, $fh ) = @_;
    my $this = bless(
        {
            nextLine => undef,
            handle   => $fh,
        },
        $class
    );
    Foswiki::LineIterator::next($this);
    $this->{process} = undef;
    $this->{filter}  = undef;

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
    my $this = shift;
    return defined( $this->{nextLine} );
}

=begin TML

---++ next() -> $data

Return the next line in the file.

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
my $it = new Foswiki::LineIterator("/etc/passwd");
$it->{filter} = sub { $_[0] =~ m/^.*?:/; return $1; };
$it->{process} = sub { return "User $_[0]"; };
while ($it->hasNext()) {
    my $x = $it->next();
    print "$x\n";
}
</verbatim>

=cut

sub next {
    my ($this) = @_;
    my $curLine = $this->{nextLine};
    local $/ = "\n";
    while (1) {
        my $h = $this->{handle};
        $this->{nextLine} = <$h>;
        if ( !defined( $this->{nextLine} ) ) {
            last;
        }
        else {
            chomp( $this->{nextLine} );
        }
        last if !$this->{filter};
        last unless &{ $this->{filter} }( $this->{nextLine} );
    }
    $curLine = &{ $this->{process} }($curLine)
      if defined $curLine && $this->{process};
    return $curLine;
}

# See Foswiki::Iterator for a description of the general iterator contract
sub reset {
    my ($this) = @_;

    return;
}

1;
__END__
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
