# See bottom of file for license and copyright information
package Foswiki::Logger;

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

---++ ObjectMethod =log($level, @fields)= or =log( { param => 'value', } )=

Adds a log message to a log.

---+++ Compatibility interface:
<verbatim>
 $this->logger->log( 'info', $user, $action, $webTopic, $message, $remoteAddr );
 $this->logger->log( 'warning', $mess );
 $this->logger->log( 'debug', $mess );
</verbatim>

---+++ Native interface:
<verbatim>
 $this->logger->log( { level      => 'info',
                       user       => $user,
                       action     => $action,
                       webTopic   => $webTopic,
                       extra      => $message,
                       remoteAddr => $remoteAddr } );

 $this->logger->log( { level => 'warning',
                       caller => $caller,
                       fields  => \@fields } );

 $this->logger->log( { level => 'debug',
                       fields  => \@fields } );
</verbatim>

Fields recorded for info messages are generally fixed.  Any levels other than info
can be called with an array of additional fields to log.

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

---++ StaticMethod eachEventSince($time, \@levels, $api) -> $iterator
   * =$time= - a time in the past
   * =\@levels= - log levels to return events for.
   * API version.  If true, return hash name => value, otherwise return fixed list

Get an iterator over the list of all the events at the given level(s)
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

=begin TML

---++ ClassMethod setCommonFields( \%fhash )
   * =%fhash= - Hashref of fields to be logged.

This routine assigns values to some common fields that are useful in logs.

In the older Logging API, these were only provided by the Foswiki::writeEvent()
method for "info" level events.

| =$fhash->{agent}= | The user agent |
| =$fhash->{timestamp}= | The time of the event |
| =$fhash->{user}= | The logged in user, if any |
| =$fhash->{webTopic}= | The current topic |
| =$fhash->{remoteAddr}= | Remote IP Address |

=cut

sub setCommonFields {

    # my $fhash = shift
    my $user = $_[0]->{user} || $Foswiki::Plugins::SESSION->{user};
    my $users = $Foswiki::Plugins::SESSION->{users};
    my $login;
    $login = $users->getLoginName($user) if ($users);
    $_[0]->{user} = $login if $login;

    unless ( defined $_[0]->{agent} ) {
        my $agent    = '';
        my $cgiQuery = $Foswiki::Plugins::SESSION->{request};
        if ($cgiQuery) {
            my $agentStr = $cgiQuery->user_agent();
            if ($agentStr) {
                if ( $agentStr =~
m/(MSIE 6|MSIE 7|MSIE 8|MSI 9|Firefox|Opera|Konqueror|Chrome|Safari)/
                  )
                {
                    $_[0]->{agent} = $1;
                }
                else {
                    $agentStr =~ m/([\w]+)/;
                    $_[0]->{agent} = $1;
                }
            }
        }
    }

    unless ( defined $_[0]->{remoteAddr} ) {
        $_[0]->{remoteAddr} =
          $Foswiki::Plugins::SESSION->{request}->remoteAddress() || ''
          if ( defined $Foswiki::Plugins::SESSION->{request} );
    }

    unless ( defined $_[0]->{webTopic} ) {
        my $webTopic = $Foswiki::Plugins::SESSION->{webName} || '';
        $webTopic .= '.' if ($webTopic);
        $webTopic .= $Foswiki::Plugins::SESSION->{topicName} || '';
        $_[0]->{webTopic} = $webTopic || '';
    }

    return;

}

=begin TML

---++ ClassMethod getOldCall( \%fhash )
   * =%fhash= - Hashref of fields to be logged.

This utility routine converts the new style hash calling convention into
the older parameter list calling convention.   Use it in an old logger
to work with the new style calls in Foswiki 2.

In Foswiki 1.1 and earlier, event logs were "filtered" by the core.  With Foswiki 2,
the logger is responsible for filtering.  This routine implements the 1.1 filter and
returns undef if the record should not be logged.

<verbatim>
    my $level;
    my @fields;

    # Native interface:  Convert the hash back to list format
    if ( ref( $_[0] ) eq 'HASH' ) {
        ($level, @fields) = Foswiki::Logger::getOldCall(@_);
        return unless defined $level;
    }
    else {
        ( $level, @fields ) = @_;
    }
</verbatim>

=cut

sub getOldCall {
    my $fhash = shift;
    my @fields;

    Foswiki::Logger::setCommonFields($fhash);
    my $level = $fhash->{level};
    delete $fhash->{level};
    if ( $level eq 'info' ) {

        # Implement the core event filter
        return undef
          if ( defined $fhash->{action}
            && defined $Foswiki::cfg{Log}{Action}{ $fhash->{action} }
            && !$Foswiki::cfg{Log}{Action}{ $fhash->{action} } );

        foreach my $key (qw( user action webTopic )) {
            push( @fields, $fhash->{$key} || '' );
            delete $fhash->{$key};
        }

        # The original writeEvent appended the agent to the extra field
        # New version will append agent and any other unaccounted for fields
        my $extra = $fhash->{extra} || '';
        delete $fhash->{extra};
        foreach my $key ( sort keys %$fhash ) {
            next if $key eq 'remoteAddr';
            $extra .= " $fhash->{$key}";
        }
        push( @fields, $extra );
        push( @fields, $fhash->{remoteAddr} || '' );
    }
    elsif ( $level eq 'notice' ) {    # Configuration changes logged as notice
        foreach my $key (qw( user remoteAddr setting oldvalue newvalue)) {
            push( @fields, $fhash->{$key} || '' );
            delete $fhash->{$key};
        }
    }
    else {
        push( @fields, $fhash->{caller} )     if defined $fhash->{caller};
        push( @fields, @{ $fhash->{extra} } ) if defined $fhash->{extra};
    }

    return ( $level, @fields );
}

=begin TML

---++ Log4Perl compatibility methods

These methods implement the simple Log4Perl methods, for example
=$this->logger->error('Some failure');

---+++ ObjectMethod debug( $message )

Equivalent to log( 'debug', $message )

=cut

sub debug {
    my $this = shift;
    $this->log( 'debug', @_ );
}

=begin TML

---+++ ObjectMethod info( $message )

Equivalent to log( 'info', $message )

=cut

sub info {
    my $this = shift;
    $this->log( 'info', @_ );
}

=begin TML

---+++ ObjectMethod notice( $message )

Equivalent to log( 'notice', $message )

=cut

sub notice {
    my $this = shift;
    $this->log( 'notice', @_ );
}

=begin TML

---+++ ObjectMethod warn( $message )

Equivalent to log( 'warn', $message )

=cut

sub warn {
    my $this = shift;
    $this->log( 'warning', @_ );
}

=begin TML

---+++ ObjectMethod error( $message )

Equivalent to log( 'error', $message )

=cut

sub error {
    my $this = shift;
    $this->log( 'error', @_ );
}

=begin TML

---+++ ObjectMethod critical( $message )

Equivalent to log( 'critical', $message )

=cut

sub critical {
    my $this = shift;
    $this->log( 'critical', @_ );
}

=begin TML

---+++ ObjectMethod alert( $message )

Equivalent to log( 'alert', $message )

=cut

sub alert {
    my $this = shift;
    $this->log( 'alert', @_ );
}

=begin TML

---+++ ObjectMethod emergency( $message )

Equivalent to log( 'emergency', $message ).

=cut

sub emergency {
    my $this = shift;
    $this->log( 'emergency', @_ );
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
