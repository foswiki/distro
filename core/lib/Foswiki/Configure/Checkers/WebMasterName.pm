# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::WebMasterName;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

use MIME::Base64;

sub check {
    my $this   = shift;
    my $valobj = shift;

    my $e = '';

    if ( $Foswiki::cfg{Email}{EnableSMIME}
        && !$Foswiki::cfg{Email}{SmimeCertificateFile} )
    {
        my $certfile = '$Foswiki::cfg{DataDir}' . "/SmimeCertificate.pem";
        Foswiki::Configure::Load::expandValue($certfile);
        my $keyfile = '$Foswiki::cfg{DataDir}' . "/SmimePrivateKey.pem";
        Foswiki::Configure::Load::expandValue($keyfile);
        if ( !( -r $certfile && -r $keyfile ) ) {
            $e .= $this->ERROR(
"S/MIME signing with self-signed certificate requested, but files are not present.  Please generate a certificate with the action button."
            );
        }
    }

    $e .= $this->ERROR(
"Please specify the name to appear on Foswiki-generated e-mails.  It can be generic."
    ) unless ( $Foswiki::cfg{WebMasterName} );

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

    my @optionList = $this->parseOptions();

    $optionList[0] = {} unless (@optionList);

    $e .=
      $this->ERROR(".SPEC error: multiple CHECK options for {WebMasterName}")
      if ( @optionList > 1 );

    my $certfile = '$Foswiki::cfg{DataDir}' . "/SmimeCertificate.pem";
    Foswiki::Configure::Load::expandValue($certfile);
    my $keyfile = '$Foswiki::cfg{DataDir}' . "/SmimePrivateKey.pem";
    Foswiki::Configure::Load::expandValue($keyfile);

    my $ok = !$e;
    if ( $button == 2 || $button == 3 ) {
        $e =
          '';   # Check errors include missing files - which we're about to fix.

        $e .= $this->ERROR(
"Please specify the name to appear on Foswiki-generated e-mails.  It can be generic."
        ) unless ( $Foswiki::cfg{WebMasterName} );
        $e .= $this->ERROR(
"The {WebMasterEmail} address must be specified to generate a certificate."
        ) unless ( $Foswiki::cfg{WebMasterEmail} );

        if ( $button == 2 ) {
            $e .= $this->ERROR(
"A certificate file has been specified.  To use a self-signed certificate instead, please clear {Email}{SmimeCertificateFile}."
            ) if ( $Foswiki::cfg{Email}{SmimeCertificateFile} );
            $e .= $this->ERROR(
"A certificate private key file has been specified.  To use a self-signed certificate please clear {Email}{SmimeCertificateFile}."
            ) if ( $Foswiki::cfg{Email}{SmimeKeyFile} && !$e );
        }
        else {
            if ( -f "$certfile.csr" ) {
                $e .= $this->ERROR(
"A Certificate Signing request is pending.  Generating a new one would invalidate it and replace the private key.  Use the Cancel CSR button if you are sure that you want to do this."
                );
            }
        }
        if ($e) {
            $e .= $this->ERROR(
"The preceding errors must be corrected before a certificate can be generated or requested."
            );
            $ok = 0;
        }
        else {
            unless ( $optionList[0]->{'.selfSigned'} = [ $button == 2 ] ) {
                @{ $optionList[0] }{qw/C ST L O OU/} = (
                    [ $Foswiki::cfg{Email}{SmimeCertC} ],
                    [ $Foswiki::cfg{Email}{SmimeCertST} ],
                    [ $Foswiki::cfg{Email}{SmimeCertL} ],
                    [
                             $Foswiki::cfg{Email}{SmimeCertO}
                          || $optionList[0]->{O}[0]
                    ],
                    [
                             $Foswiki::cfg{Email}{SmimeCertOU}
                          || $optionList[0]->{OU}[0]
                    ],
                );
            }
            ( $ok, my $msg, my $keypass ) = $this->generateSelfSigned(
                $Foswiki::cfg{WebMasterName},
                $Foswiki::cfg{WebMasterEmail},
                $certfile, $keyfile, $optionList[0]
            );
            if ($ok) {
                $e .= $this->NOTE($msg);
                if ( $button == 2 ) {
                    $Foswiki::cfg{Email}{SmimeKeyPassword} = $keypass;
                    $Foswiki::cfg{Email}{EnableSMIME}      = 1;

                    $e .=
                        $this->FB_VALUE( '{Email}{SmimeKeyPassword}', $keypass )
                      . $this->FB_VALUE( '{Email}{EnableSMIME}',      1 );
                }
                else {
                    $Foswiki::cfg{Email}{SmimePendingKeyPassword} = $keypass;
                    $e .=
                      $this->FB_VALUE( '{Email}{SmimePendingKeyPassword}',
                        $keypass );
                }
            }
            else {
                $e .= $this->ERROR($msg);
            }
        }

    }
    elsif ( $button == 4 ) {
        if ( -f "$certfile.csr" || -f "$keyfile.csr" ) {
            my $errs = '';

            $errs .= "Can't delete $certfile.csr: $!\n"
              if ( -f "$certfile.csr" && !unlink("$certfile.csr") );
            $errs .= "Can't delete $keyfile.csr: $!\n"
              if ( -f "$keyfile.csr" && !unlink("$keyfile.csr") );
            $e .= (
                  $errs
                ? $this->ERROR("Cancel failed. <br />$errs")
                : $this->NOTE("Request cancelled")
            );
        }
        else {
            $e .= $this->NOTE("No request pending");
        }
    }
    return wantarray
      ? (
        $e,
        [
            qw/{Email}{EnableSMIME} {Email}{SmimeCertificateFile} {Email}{SmimeKeyPassword}/
        ]
      )
      : $e
      if ($ok);

    return wantarray ? ( $e, 0 ) : $e;
}

sub generateSelfSigned {
    my $this = shift;
    my ( $name, $email, $certfile, $keyfile, $options ) = @_;

    require File::Temp;

    # CHECK="expires:356d passlen:15,37 O='' OU='' C='' ST='' L=''"

    my $days = $options->{expires}[0] || 366;
    if ( $days =~ /^(\d+)([ymwd])?$/i ) {
        $days = $1;
        if ( defined $2 ) {
            my $m = lc $2;
            if ( $m eq 'y' ) {
                $days *= 365.242;
            }
            elsif ( $m eq 'm' ) {
                $days *= 365.242 / 12;
            }
            elsif ( $m eq 'w' ) {
                $days *= 7;
            }
            $days = int($days);
        }
    }
    else {
        $days = 356;
    }
    my $minpass = $options->{passlen}[0] || 15;
    my $maxpass = $options->{passlen}[1] || $minpass * 3;
    $maxpass = 37 if ( $maxpass > 37 );

    # Required
    my @dnc = (
        O  => $options->{O}[0]  || "Foswiki Customers",
        OU => $options->{OU}[0] || "Self-signed certificates",
    );

    # Optional - reverse order
    foreach my $dnc (qw/L ST C/) {
        unshift @dnc, $dnc => $options->{$dnc}[0] if ( $options->{$dnc}[0] );
    }

    my $DN = '';
    while (@dnc) {
        my ( $dnc, $dcv ) = splice( @dnc, 0, 2 );
        $DN .= "$dnc=$dcv\n";
    }

    my $passlen = $minpass + int( rand( $maxpass + 1 - $minpass ) );

# openssl is somewhat fussy about password chars, and note that + is used in the EOF marker
# for the shell.  I don't have a spec for what's accepted, so this may need to be adjusted.
# This password is never displayed or provided to a user, so there are no human factors
# to consider.
    my $graphics =
      join( '', 'a' .. 'z', 'A' .. 'Z', '0' .. '9', q(!%^*_-,./?;:[]|) );
    my $keypass = '';
    for ( my $i = 0 ; $i < $passlen ; $i++ ) {
        $keypass .= substr( $graphics, int( rand( length($graphics) ) ), 1 );
    }

    my $time   = time;
    my $tmpdir = File::Temp->newdir;

    my $tmpfile = File::Temp->new();
    chmod( ( stat $tmpfile )[2] & 07700 );

    local $ENV{OPENSSL_CONF} = "$tmpfile";
    local $ENV{HOME}         = "$tmpdir";

    print $tmpfile ( << "CONFIG" );
HOME                    = $tmpdir
RANDFILE                = $tmpdir/.rnd
[ req ]
input_password          = $keypass
output_password         = $keypass
req_extensions          = req_ext
x509_extensions         = self_ext
default_md              = sha1
distinguished_name      = req_distinguished_name
string_mask             = nombstr
prompt                  = no

[ req_distinguished_name ]
$DN
CN=$name
emailAddress=$email

[ self_ext ]
basicConstraints       = CA:FALSE
keyUsage               = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName         = email:copy
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid,issuer
extendedKeyUsage       = emailProtection, clientAuth
nsCertType             = client, email

[ req_ext ]
basicConstraints       = CA:FALSE
keyUsage               = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName         = email:copy
subjectKeyIdentifier   = hash
extendedKeyUsage       = emailProtection, clientAuth
nsCertType             = client, email
CONFIG

    $tmpfile->flush;

    # Protect key file - even though it's encrypted.
    my $self = $options->{'.selfSigned'}[0];
    my $cmd  = (
        $self
        ? "-x509 -days $days -set_serial $time -out $certfile"
        : '-new -subject'
    );
    $keyfile .= '.csr' unless ($self);
    my $um = umask(0117);
    my ( $output, $keyoutput );
    {
        no warnings 'exec';

        $output =
`openssl req -config $tmpfile -newkey rsa:2048 -keyout $keyfile $cmd -batch 2>&1`;
        if ($?) {
            umask($um);
            return ( 0,
                    "Unable to create certificate"
                  . ( $self ? '' : ' request' )
                  . ": <pre>$output</pre>" );
        }

    # Get key into the right format (RSA PRIVATE KEY, not ENCRYPTED PRIVATE KEY)
        $keyoutput =
          `openssl rsa -in $keyfile -out $keyfile -des3 2>&1 <<+++EOF+++
$keypass
$keypass
$keypass
+++EOF+++
`;
    }
    umask($um);
    if ($?) {
        return ( 0, "Unable to convert private key: <pre>$keyoutput</pre>" );
    }

    # Cert can be readable by all - arguably should not be group write,
    # but some webserver environments might require that.

    if ($self) {
        $um = ( stat $certfile )[2];
        chmod( ( ( $um & 0664 ) | 0664 ), $certfile ) if ( defined $um );
    }

    if ($self) {
        return (
            1,
"Created and activated a self-signed certificate for \"$name\" &lt;$email&gt;, which is valid for $days days.<p>Because this is a self-signed certificate, it will not automatically be accepted by most e-mail clients.  You will have to instruct your recipients to trust this certificate, or obtain a trusted certificate at your convenience.",
            $keypass
        );
    }

    open( my $f, '>', "$certfile.csr" )
      or return ( 0, $this->ERROR("Can't save CSR: $!") );
    print $f $output;
    close $f or return ( 0, $this->ERROR("Close failed saving CSR: $!") );

    return (
        1,
"Your private key has been created.  Your certificate signing request is displayed below.  Please transmit it to your CA, then proceed to the Install button.  Do NOT click either action button again, as it will over-write the private key, rendering the CSR useless.<pre>$output</pre>",
        $keypass,
    );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
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
