# See bottom of file for license and copyright information

package Foswiki::Configure::Checkers::Email::EnableSMIME;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');
use Foswiki::Configure::Load;

my @modules = (
    [ 'Crypt::SMIME' => 'Required for S/MIME',                      0.09 ],
    [ 'Crypt::X509'  => 'Required for validation',                  0.51 ],
    [ 'Convert::PEM' => 'Required for encrypted private key files', 0.08 ],
);

sub check {
    my $this = shift;
    my ($valobj) = @_;

    my $e = '';

    return $e unless $Foswiki::cfg{Email}{EnableSMIME};

    foreach my $mod (@modules) {
        my $m = $this->checkPerlModule(@$mod);

        if ( $m =~ m/Not installed/ ) {
            $e .= $m;
        }
    }
    $e = $this->ERROR($e) if ($e);

    my $selfCert = "\$Foswiki::cfg{DataDir}/SmimeCertificate.pem";
    Foswiki::Configure::Load::expandValue($selfCert);
    my $selfKey = "\$Foswiki::cfg{DataDir}/SmimePrivateKey.pem";
    Foswiki::Configure::Load::expandValue($selfKey);

    $e .= $this->ERROR(
"Either Certificate and Key files must be provided for S/MIME email, or a self-signed certificate can be generated.  To generate a self-signed certificate or generate a signing request, use the respective WebmasterName action button."
      )
      unless (
           $Foswiki::cfg{Email}{SmimeCertificateFile}
        && $Foswiki::cfg{Email}{SmimeKeyFile}
        || (   !$Foswiki::cfg{Email}{SmimeCertificateFile}
            && !$Foswiki::cfg{Email}{SmimeKeyFile}
            && -r $selfCert
            && -r $selfKey )
      );

    if ( !$this->{item}->{FEEDBACK} && !$this->{FeedbackProvided} ) {

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

    #    my $keys = $valobj->{keys};

    delete $this->{FeedbackProvided};

    # check() does all that's necessary
    # We simply re-do if a button (usually autocheck) is provided.

    return wantarray ? ( $e, 0 ) : $e;
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

