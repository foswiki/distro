# See bottom of file for license and copyright information
package Foswiki::Iterator::EventIterator;

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

---++ =Foswiki::Iterator::EventIterator=
Private subclass of LineIterator that
   * Selects log records that match the requested begin time and levels.
   * reasembles divided records into a single log record
   * splits the log record into fields

=cut

package Foswiki::Iterator::EventIterator;
require Foswiki::LineIterator;
our @ISA = ('Foswiki::LineIterator');

use constant TRACE => 0;

sub new {
    my ( $class, $fh, $threshold, $level, $version, $filename ) = @_;
    my $this = $class->SUPER::new($fh);
    $this->{_api}       = $version;
    $this->{_threshold} = $threshold;
    $this->{_reqLevel}  = $level;
    $this->{_filename}  = $filename || 'n/a';

    #  print STDERR "EventIterator created for $this->{_filename} \n";
    return $this;
}

=begin TML

---+++ ObjectMethod hasNext() -> $boolean
Reads records, reassembling them and skipping until a record qualifies per the requested time and levels.

The next matching record is parsed and saved into an instance variable until requested.

Returns true if a cached record is available.

=cut

sub hasNext {
    my $this = shift;
    return 1 if defined $this->{_nextEvent};
    while ( $this->SUPER::hasNext() ) {
        my $ln = $this->SUPER::next();

        # Merge records until record ends in |
        while ( substr( $ln, -1 ) ne '|' && $this->SUPER::hasNext() ) {
            $ln .= "\n" . $this->SUPER::next();
        }

        my @line = split( /\s*\|\s*/, $ln );
        shift @line;    # skip the leading empty cell
        next unless scalar(@line) && defined $line[0];

        if (
            $line[0] =~ s/\s+($this->{_reqLevel})\s*$//    # test the level
              # accept a plain 'old' format date with no level only if reading info (statistics)
            || $line[0] =~ m/^\d{1,2} [a-z]{3} \d{4}/i
            && $this->{_reqLevel} =~ m/info/
          )
        {
            $this->{_level} = $1 || 'info';
            $line[0] = Foswiki::Time::parseTime( $line[0] );
            next
              unless ( defined $line[0] ); # Skip record if time doesn't decode.
            if ( $line[0] >= $this->{_threshold} ) {    # test the time
                $this->{_nextEvent}  = \@line;
                $this->{_nextParsed} = $this->formatData();
                return 1;
            }
        }
    }
    return 0;
}

=begin TML

---+++ ObjectMethod snoopNext() -> $hashref
Returns a hash of the fields in the next available record without
moving the record pointer.  (If the file has not yet been read, the hasNext() method is called,
which will read the file until it finds a matching record.

=cut

sub snoopNext {
    my $this = shift;
    return $this->{_nextParsed};    # if defined $this->{_nextParsed};
                                    #return undef unless $this->hasNext();
                                    #return $this->{_nextParsed};
}

=begin TML

---+++ ObjectMethod next() -> \$hash or @array
Returns a hash, or an array of the fields in the next available record depending on the API version.

=cut

sub next {
    my $this = shift;
    undef $this->{_nextEvent};
    return $this->{_nextParsed}[0] if $this->{_api};
    return $this->{_nextParsed}[1];
}

=begin TML

---++ PrivateMethod formatData($this) -> ( $hashRef, @array )

Used by the EventIterator to assemble the read log record into a hash for the Version 1
interface, or the array returned for the original Version 0 interface.

=cut

sub formatData {
    my $this = shift;
    my $data = $this->{_nextEvent};
    my %fhash;    # returned hash of identified fields
    $fhash{level}    = $this->{_level};
    $fhash{filename} = $this->{_filename}
      if (TRACE);
    if ( $this->{_level} eq 'info' ) {
        $fhash{epoch}      = @$data[0];
        $fhash{user}       = @$data[1];
        $fhash{action}     = @$data[2];
        $fhash{webTopic}   = @$data[3];
        $fhash{extra}      = @$data[4];
        $fhash{remoteAddr} = @$data[5];
    }
    elsif ( $this->{_level} =~ m/warning|error|critical|alert|emergency/ ) {
        $fhash{epoch} = @$data[0];
        $fhash{extra} = join( ' ', @$data[ 1 .. $#$data ] );
    }
    elsif ( $this->{_level} eq 'debug' ) {
        $fhash{epoch} = @$data[0];
        $fhash{extra} = join( ' ', @$data[ 1 .. $#$data ] );
    }

    return (
        [
            \%fhash,

            (
                [
                    $fhash{epoch},
                    $fhash{user}       || '',
                    $fhash{action}     || '',
                    $fhash{webTopic}   || '',
                    $fhash{extra}      || '',
                    $fhash{remoteAddr} || '',
                    $fhash{level},
                ]
            )
        ]
    );
}

1;
__END__
Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2013 Foswiki Contributors. Foswiki Contributors
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

