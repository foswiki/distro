# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::WEBTOPIC;

# Default checker for WEBTOPIC items
#
# CHECK options in spec file
#  CHECK="option option:val option:val,val,val"
#
#   exists:{webname} - Web or WebTopic must exist.   If a {webname} key is provided,
#                      it will be used as the default web to check.
#
#
# Use this checker if possible; otherwise subclass the item-specific checker from it.

use strict;
use warnings;

use Assert;
use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

use Foswiki ();

sub check_current_value {
    my ( $this, $reporter, $defaultWeb, $defaultTopic ) = @_;

    my $webtopic = $this->checkExpandedValue($reporter);
    return unless defined $webtopic;

    $webtopic =~ m/^\s*(.*?)\s*$/;    #Check for leading and trailing spaces
    unless ( $webtopic eq $1 ) {
        $reporter->ERROR("Leading / Trailing spaces are not valid.");
        return;
    }

    my $type = $this->{item}->{typename};

    my $exists = $this->{item}->CHECK_option('exists');

    my $ckweb;
    my $cktopic = $webtopic;

    if ( $type eq 'WEB' ) {
        $ckweb   = $webtopic;
        $cktopic = $Foswiki::cfg{WebPrefsTopicName};
    }
    elsif ( $type eq 'TOPIC' ) {
        $cktopic = $webtopic;
        if ( defined $exists ) {
            if ( $exists =~ /^\{.*\}$/ ) {
                $ckweb = eval("\$Foswiki::cfg$exists");
            }
            elsif ( length($exists) > 1 ) {
                $ckweb = $exists;
            }
        }
    }

    # SMELL:  CLI tools/configure doesn't create a session by default
    # but the Foswiki::Func calls need a session.
    unless ($Foswiki::Plugins::SESSION) {
        $reporter->NOTE(" Creating a SESSION");
        Foswiki->new('admin');    # Create admin session for topic checkins
    }

    ( $ckweb, $cktopic ) =
      Foswiki::Func::normalizeWebTopicName( $ckweb, $cktopic );

    unless ( Foswiki::Func::isValidWebName($ckweb) ) {
        $reporter->ERROR("Invalid Web Name");
        return;
    }
    unless ( Foswiki::Func::isValidTopicName($cktopic) ) {
        $reporter->ERROR("Invalid Topic Name");
        return;
    }

    if ( defined $exists ) {
        unless ( Foswiki::Func::topicExists( $ckweb, $cktopic ) ) {
            if ( $type eq 'WEB' ) {
                $reporter->ERROR("$type does not exist: $ckweb");
            }
            else {
                $reporter->ERROR("$type does not exist: $ckweb.$cktopic");
            }
        }
    }

}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2018 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
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
