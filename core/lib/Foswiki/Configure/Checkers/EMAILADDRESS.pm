# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::EMAILADDRESS;

# Default checker for EMAILADDRESS items
#
# Button 1 = Test syntax (should be check-on-change)
# Button 2 = Test mail to address (should be a button)
#
# CHECK options in spec file
#  CHECK="option option:val option:val,val,val"
#    list:delim (default ',\\\\s*')
#    nullok
#
# Use this checker if possible; otherwise subclass the item-specific checker from it.

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check {
    my $this   = shift;
    my $valobj = shift;

    my $keys = $valobj->getKeys();

    my $e = '';

    my @optionList = $this->parseOptions();

    $optionList[0] = {} unless (@optionList);

    $e .= $this->ERROR(".SPEC error: multiple CHECK options for EMAILADDRESS")
      if ( @optionList > 1 );

    my $nullok = $optionList[0]->{nullok}[0] || 10;
    my $list = $optionList[0]->{list}[0];
    $list = ',\s+' if ( defined $list && $list == 1 );

    my $value = $this->getCfg($keys);

    if ( !defined $value ) {
        $e .= $this->ERROR("Not defined");
    }
    else {
        my @addrs = split( qr{$list}, $value ) if ( defined $list );
        push @addrs, $value unless ( defined $list );

        $e .= $this->ERROR("An e-mail address is required")
          unless ( @addrs || $nullok );

        foreach my $addr (@addrs) {
            $e .=
              $this->WARN("\"$addr\" does not appear to be an e-mail address")
              unless (
                $addr =~ /^([a-z0-9!+$%&'*+-\/=?^_`{|}~.]+\@[a-z0-9\.\-]+)$/i );

            # unless( $addr =~ /\s*[^@]+\@\S+\s*/ );
        }
    }

    $value = $this->getItemCurrentValue();
    $e     = $this->showExpandedValue($value) . $e;

    if ( !$this->{item}->feedback && !$this->{FeedbackProvided} ) {

        # There is no feedback configured for this item, so do any
        # specified tests in the checker (not a good thing).

        $e .= $this->provideFeedback( $valobj, 0, 'No Feedback' );
    }

    return $e;
}

sub provideFeedback {
    my $this = shift;
    my ( $valobj, $button, $label ) = @_;

    $this->{FeedbackProvided} = 1;

    # Normally, we call check first, but not if called by check.

    my $e = $button ? $this->check($valobj) : '';

    my $keys = $valobj->getKeys();

    delete $this->{FeedbackProvided};

    # We only need to run the checker for button 1
    #
    # For button 2, actually send a test e-mail

    if ( $button == 2 ) {
        if ( $e =~ /(?:Warning|Error)/ ) {
            $e .= $this->WARN("Will not test due to previous errors");
        }
        else {
            my $fh;
            my $pid = open( $fh, '-|' );
            if ( defined $pid ) {
                if ($pid) {
                    local $/;
                    $e .= <$fh>;
                    close $fh;
                }
                else {
                    eval { print $this->_mailFork($keys); };
                    print $@ if ($@);
                    exit(0);
                }
            }
            else {
                die "Unable to fork: $!\n";
            }
        }
    }

    return wantarray ? ( $e, 0 ) : $e;
}

# The actual test runs this routine in a fork to prevent
# corruption of configure's data structures.

sub _mailFork {
    my $this = shift;

    my $keys = shift;

    my $addrs = $this->getCfg($keys);

    require Foswiki::Net;

    return $this->ERROR("{EnableEmail} is not checked")
      unless ( $Foswiki::cfg{EnableEmail} );

    return $this->ERROR("{WebMasterEmail} is not defined")
      unless ( $Foswiki::cfg{WebMasterEmail} );

    Foswiki::Configure::Load::expandValue(
        $Foswiki::cfg{Email}{SmimeCertificateFile} );
    Foswiki::Configure::Load::expandValue( $Foswiki::cfg{Email}{SmimeKeyFile} );

    $Foswiki::cfg{SMTP}{Debug} = 1;

    my $msg = <<MAIL;
From: $Foswiki::cfg{WebMasterEmail}
To: $addrs
Subject: Test of Foswiki email to $keys
MIME-Version: 1.0
Content-Type: text/plain; charset=utf-8
Content-Transfer-Encoding: 8bit

Test message from Foswiki.
MAIL
    my $net       = Foswiki::Net->new();
    my $stderr    = '';
    my $neterrors = '';
    eval {
        local *STDERR;
        open( STDERR, '>', \$stderr );
        $neterrors = $net->sendEmail( $msg, 1 );
        close STDERR;
    } or $neterrors .= $@;

    my $results = $this->ERROR($neterrors) if ($neterrors);
    $results .=
      $this->NOTE("Transcript of e-mail server dialog")
      . "<div><pre>$stderr</pre></div>"
      if ($stderr);

    return $results if ($neterrors);

    return $this->NOTE(
"Mail was sent successfully to $addrs from $Foswiki::cfg{WebMasterEmail}, however the $Foswiki::cfg{WebMasterEmail} mailbox may receive a deferred delivery error later"
    ) . $results;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
