# See bottom of file for license and copyright information
package Foswiki::Configure::Reporter;

use strict;
use warnings;

=begin TML

---+ package Foswiki::Configure::Reporter

Report package for configure, supporting text reporting and
simple TML expansion to HTML.

This class doesn't actually handle expansion of TML to anything else;
it simply stores messages for processing by formatting back ends.
However it is a sensible place to define the subset of TML that is expected
to be supported by renderers.

   * Single level of lists (* and 1)
   * Blank line = paragraph break &lt;p /&gt;
   * &gt; at start of line = &lt;br&gt; before and after
     (i.e. line stands alone)
   * Simple tables | like | this |
   * Text styling e.g. <nop>*bold*, <nop>=code= etc
   * URL links [<nop>[http://that][text description]]
   * &lt;verbatim&gt;...&lt;/verbatim&gt;
   * ---+++ Headings

Each of the reporting methods (NOTE, WARN, ERROR) accepts any number of
message parameters. These are treated as individual error messages, rather
than being concatenated into a single message. \n can be used in any
message, and it will survive into the final TML.

Most renderers will assume an implicit > at the front of every WARN and
ERROR message.

=cut

sub new {
    my $class = shift;

    my $this = bless( {}, $class );
    $this->clear();
    return $this;
}

=begin TML

---++ ObjectMethod NOTE(@notes) -> $this

Report one or more notes. Each parameter is handled as an independent
message. Returns the reporter to allow chaining.

=cut

sub NOTE {
    my $this = shift;
    push( @{ $this->{messages} }, map { { level => 'notes', text => $_ } } @_ );
    return $this;
}

=begin TML

---++ ObjectMethod WARN(@warnings)

Report one or more warnings. Each parameter is handled as an independent
message. Returns the reporter to allow chaining.

=cut

sub WARN {
    my $this = shift;
    push(
        @{ $this->{messages} },
        map { { level => 'warnings', text => $_ } } @_
    );
}

=begin TML

---++ ObjectMethod ERROR(@errors) -> $this

Report one or more errors. Each parameter is handled as an independent
message. Returns the reporter to allow chaining.

=cut

sub ERROR {
    my $this = shift;
    push( @{ $this->{messages} },
        map { { level => 'errors', text => $_ } } @_ );
    return $this;
}

=begin TML

---++ ObjectMethod CHANGED($keys) -> $this

Report that a =Foswiki::cfg= entry has changed. The new value will
be taken from the current value in =$Foswiki::cfg= at the time of
the call to CHANGED.

Example: =$reporter->CHANGED('{Email}{Method}')=

Returns the reporter to allow chaining.

=cut

sub CHANGED {
    my ( $this, $keys ) = @_;
    $this->{changes}->{$keys} = eval "\$Foswiki::cfg$keys";
    return $this;
}

=begin TML

---++ ObjectMethod clear() -> $this

Clear all contents from the reporter.
Returns the reporter to allow chaining.

=cut

sub clear {
    my $this = shift;
    $this->{messages} = [];
    $this->{changes}  = {};
    return $this;
}

=begin TML

---++ ObjectMethod messages() -> \@messages

Get the content of the reporter. @messages is an ordered array of hashes,
each of which has fields:
   * level: one of errors, warnings, notes
   * text: text of the message
Each message corresponds to a single parameter to one of the ERROR,
WARN or NOTES methods.

=cut

sub messages {
    my ($this) = @_;

    return $this->{messages};
}

=begin TML

---++ ObjectMethod changes() -> \%changes

Get the content of the reporter. %changes is a hash mapping a key
to a (new) value. Each entry corresponds to a call to the CHANGED
method (though multiple calls to CHANGED with the same keys will
only result in one entry).

=cut

sub changes {
    my ($this) = @_;

    return $this->{changes};
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2014 Foswiki Contributors. Foswiki Contributors
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
