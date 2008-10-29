# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2007 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution. NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.

=pod

---+ package TWiki::LineIterator

Iterator over the lines in a file

=cut

package TWiki::LineIterator;

use strict;

=pod

---++ new( $file )

Create a new iterator over the given file. if the file cannot be opened, then
there will be no elements in the iterator.

=cut


sub new {
    my ($class, $file) = @_;
    my $this = bless({}, $class);
    $this->{nextLine} = undef;
    if( open($this->{handle}, '<', $file )) {
        $this->next();
    } else {
        die $!;
    };
    $this->{process} = undef;
    $this->{filter} = undef;

    return $this;
}

sub _DESTROY {
    my $this = shift;
    if( defined( $this->{nextLine} )) {
        # the iterator is still open
        close( $this->{handle} );
    }
}

=pod

---++ hasNext() -> $boolean

Returns false when the iterator is exhausted.

<verbatim>
my $it = new TWiki::ListIterator(\@list);
while ($it->hasNext()) {
   ...
</verbatim>

=cut

sub hasNext {
    my $this = shift;
    return defined( $this->{nextLine} );
}

=pod

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
my $it = new TWiki::LineIterator("/etc/passwd");
$it->{filter} = sub { $_[0] =~ /^.*?:/; return $1; };
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
    my $h = $this->{handle};
    local $/ = "\n";
    do {
        $this->{nextLine} = <$h>;
        if( ! defined( $this->{nextLine} )) {
            close( $h );
        } else {
            chomp( $this->{nextLine} );
        }
    } while (!( !defined( $this->{nextLine} ) ||
               !$this->{filter} ||
                 !&{$this->{filter}}($this->{nextLine})));
    $curLine = &{$this->{process}}($curLine) if $this->{process};
    return $curLine;
}

1;
