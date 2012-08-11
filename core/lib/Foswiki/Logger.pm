# See bottom of file for license and copyright information
package Foswiki::Logger;

use strict;
use warnings;

use Assert;

=begin TML

---+ package Foswiki::Logger

Object that interfaces to whatever records Foswiki log files.

This is a base class which will be subclassed by a class in the
Logger subdirectory and selected by $Foswiki::cfg{Log}{Implementation}

Note that the implementation has to provide a way for the log to be replayed.
Unfortunately this means that the simpler CPAN loggers are not suitable.

=cut

sub new {
    return bless( {}, shift );
}

=begin TML

---++ ObjectMethod finish()
Release memory. Subclasses must implement this if they use any fields
in the object.

=cut

sub finish {
    my $this = shift;
}

=begin TML

---++ ObjectMethod log($level, @fields)

Adds a log message to a log.

   * =$level= - level of the event - one of =debug=, =info=,
     =warning=, =error=, =critical=, =alert=, =emergency=.
   * =@fields= - an arbitrary list of fields to output to the log.
     These fields are recoverable when the log is enumerated using the
     =eachEventSince= method.

The levels are chosen to be compatible with Log::Dispatch.

=cut

# Default behaviour is a NOP
sub log {
}

=begin TML

---++ ObjectMethod eachEventSince($time, $level) -> $iterator
   * =$time= - a time in the past
   * =$level= - log level to return events for.

Get an iterator over the list of all the events at the given level
between =$time= and now.

Events are returned in *oldest-first* order.

Each event is returned as a reference to an array. The first element
of this array is always the date of the event (seconds since the epoch).
Subsequent elements are the fields passed to =log=.

Note that a log implementation may choose to collapse several log levels
into a single log. In this case, all messages in the same set as the
requested level will be returned if any of the collapsed levels is selected.

=cut

# Default behaviour is an empty iteration
sub eachEventSince {
    require Foswiki::ListIterator;
    return new Foswiki::ListIterator( [] );
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
