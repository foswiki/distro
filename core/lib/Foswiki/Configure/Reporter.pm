# See bottom of file for license and copyright information
package Foswiki::Configure::Reporter;

use strict;
use warnings;

=begin TML

---+ package Foswiki::Configure::Reporter

Report package for configure, supporting text reporting and
simple TML expansion to HTML.

=cut

sub new {
    my $class = shift;

    my $this = bless( {}, $class );
    $this->clear();
    return $this;
}

=begin TML

---++ ObjectMethod NOTE(...) -> $this

Report a note. The parameters are concatenated to form the message.
Returns the reporter to allow chaining.

=cut

sub NOTE {
    my $this = shift;
    push( @{ $this->{notes} }, @_ );
    return $this;
}

=begin TML

---++ ObjectMethod CONFIRM(...) -> $this

Report a confirmation. The parameters are concatenated to form the message.

=cut

sub CONFIRM {
    my $this = shift;
    push( @{ $this->{confirmations} }, @_ );
    return $this;
}

=begin TML

---++ ObjectMethod WARN(...)

Report a warning. The parameters are concatenated to form the message.
Returns the reporter to allow chaining.

=cut

sub WARN {
    my $this = shift;
    push( @{ $this->{warnings} }, @_ );
}

=begin TML

---++ ObjectMethod ERROR(...) -> $this

Report an error. The parameters are concatenated to form the message.
Returns the reporter to allow chaining.

=cut

sub ERROR {
    my $this = shift;
    push( @{ $this->{errors} }, @_ );
    return $this;
}

=begin TML

---++ ObjectMethod CHANGED($keys) -> $this

Report that a =Foswiki::cfg= entry has changed. The new value will
be taken from the current value in =$Foswiki::cfg=

Example: =$reporter->CHANGED('{Email}{Method}')=

Returns the reporter to allow chaining.

=cut

sub CHANGED {
    my ( $this, $keys ) = @_;
    $this->{changes}->{$keys} = eval "\$Foswiki::cfg$keys";
    return $this;
}

=begin TML

---++ ObjectMethod has($level) -> $number

Return the number of reports of the given level (errors, warnings,
notes, confirmations) gathered so far. 

=cut

sub has {
    my ( $this, $level ) = @_;
    return scalar( keys %{ $this->{changes} } ) if $level eq 'changes';
    return scalar( @{ $this->{$level} } );
}

=begin TML

---++ ObjectMethod clear() -> $this

Clear all contents from the reporter.
Returns the reporter to allow chaining.

=cut

sub clear {
    my $this = shift;
    $this->{notes}         = [];
    $this->{confirmations} = [];
    $this->{warnings}      = [];
    $this->{errors}        = [];
    $this->{changes}       = {};
    return $this;
}

=begin TML

---++ ObjectMethod text($level) -> $text

Get the content of the reporter for the given reporting level.

=cut

sub text {
    my ( $this, $level ) = @_;

    if ( $level eq 'changes' ) {
        my $text = "*Changed:*\n";
        while ( my ( $k, $v ) = each %{ $this->{changes} } ) {
            $text .= "   * $k = $v";
        }
        return $text;
    }

    return join( "\n", @{ $this->{$level} } );
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
