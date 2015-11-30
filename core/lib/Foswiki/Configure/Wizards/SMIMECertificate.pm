# See bottom of file for license and copyright information
package Foswiki::Configure::Wizards::SMIMECertificate;

=begin TML

---++ package Foswiki::Configure::Wizards::SMIMECertificate

Wizard methods to handle SMIME certificates.

=cut

use strict;
use warnings;

use Foswiki::Configure::Wizard ();
our @ISA = ('Foswiki::Configure::Wizard');

=begin TML

---++ WIZARD generate_cert

Generate a self-signed certficate for the WebMaster.
This allows immediate use of signed email.

=cut

sub generate_cert {

    # \%checks is provided by an internal cross-call from the
    # request_cert wizard method. It's empty when generating a self-signed
    # cert.
    my ( $this, $reporter, $root, $checks ) = @_;

    $checks ||= { '.selfSigned' => 1 };

    my $certfile = '$Foswiki::cfg{DataDir}' . "/SmimeCertificate.pem";
    Foswiki::Configure::Load::expandValue($certfile);
    my $keyfile = '$Foswiki::cfg{DataDir}' . "/SmimePrivateKey.pem";
    Foswiki::Configure::Load::expandValue($keyfile);

    my $ok = 1;
    unless ( $Foswiki::cfg{WebMasterEmail} ) {
        $reporter->ERROR(
"The {WebMasterEmail} address must be specified to generate a certificate."
        );
        $ok = 0;
    }
    unless ( $Foswiki::cfg{WebMasterName} ) {
        $reporter->ERROR(
"{WebMasterName} if not set. Please specify the name to appear on Foswiki-generated e-mails.  It can be generic."
        );
        $ok = 0;
    }

    if ( $Foswiki::cfg{Email}{SmimeCertificateFile} ) {
        $reporter->ERROR(
"A certificate file has been specified.  To use a self-signed certificate instead, please clear {Email}{SmimeCertificateFile}."
        );
        $ok = 0;
    }

    if ( $Foswiki::cfg{Email}{SmimeKeyFile} && $ok ) {
        $reporter->ERROR(
"A certificate private key file has been specified.  To use a self-signed certificate please clear {Email}{SmimeCertificateFile}."
        );
        $ok = 0;
    }
    else {
        if ( -f "$certfile.csr" ) {
            $reporter->ERROR(
"A Certificate Signing Request is pending.  Generating a new one would invalidate it and replace the private key. Cancel the Certificate Signing Request before processding."
            );
            $ok = 0;
        }
    }
    unless ($ok) {
        $reporter->ERROR(
"The preceding errors must be corrected before a certificate can be generated or requested."
        );
        return;
    }

    ( $ok, my $keypass ) = _inner_generate(
        $reporter,
        $Foswiki::cfg{WebMasterName},
        $Foswiki::cfg{WebMasterEmail},
        $certfile, $keyfile, $checks
    );
    if ($ok) {
        $Foswiki::cfg{Email}{SmimeKeyPassword} = $keypass;
        $reporter->CHANGED('{Email}{SmimeKeyPassword}');
    }

    return undef;    # return the report
}

sub _inner_generate {
    my ( $reporter, $name, $email, $certfile, $keyfile, $options ) = @_;

    require File::Temp;

    # CHECK="expires:356d passlen:15,37 O='' OU='' C='' ST='' L=''"

    my $days    = 356;
    my $minpass = 15;
    my $maxpass = $minpass * 3;
    $maxpass = 37 if ( $maxpass > 37 );

    # Required
    my @dnc = (
        O  => "Foswiki Customers",
        OU => "Self-signed certificates",
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
    my $self = $options->{'.selfSigned'};
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
        my $command =
"openssl req -config $tmpfile -newkey rsa:2048 -keyout $keyfile $cmd -batch";
        $output = `$command 2>&1`;
        if ($?) {
            umask($um);
            $reporter->ERROR( "Unable to create certificate"
                  . ( $self ? '' : ' request' )
                  . ( $? == -1 ? " (No openssl: $!)" : $? )
                  . " with '$command' "
                  . ": <pre>$output</pre>" );
            return 0;
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
        $reporter->ERROR( "Unable to convert private key"
              . ( $? == -1 ? " (No openssl: $!)" : '' )
              . ": <pre>$keyoutput</pre>" );
        return 0;
    }

    # Cert can be readable by all - arguably should not be group write,
    # but some webserver environments might require that.

    if ($self) {
        $um = ( stat $certfile )[2];
        chmod( ( ( $um & 0664 ) | 0664 ), $certfile ) if ( defined $um );
    }

    if ($self) {
        $reporter->NOTE( <<HERE );
Created and activated a self-signed certificate for \"$name\" &lt;$email&gt;, which is valid for $days days.
<p>Because this is a self-signed certificate, it will not automatically be accepted by most e-mail clients.
You will have to instruct your recipients to trust this certificate, or obtain a trusted certificate at your convenience."
HERE
        return ( 1, $keypass );
    }

    open( my $f, '>', "$certfile.csr" )
      or return ( 0, $reporter->ERROR("Can't save CSR: $!") );
    print $f $output;
    close $f or return ( 0, $reporter->ERROR("Close failed saving CSR: $!") );

    $reporter->NOTE( <<HERE );
Your private key has been created.  Your certificate signing request is displayed below. 
Please transmit it to your CA, then proceed with installation. 
Do NOT click either action button again, as it will over-write the private key, rendering the CSR useless.
HERE
    $reporter->NOTE("<verbatim>$output</verbatim>");

    return ( 1, $keypass, );
}

=begin TML

---++ WIZARD request_cert

Generate a certificate signing request for the WebMaster. This request
must be signed by a Certificate Authority to create a certificate,
then installed.

=cut

sub request_cert {
    my ( $this, $reporter, $root ) = @_;
    return $this->generate_cert(
        $reporter,
        $root,
        {
            C  => [ $Foswiki::cfg{Email}{SmimeCertC} ],
            ST => [ $Foswiki::cfg{Email}{SmimeCertST} ],
            L  => [ $Foswiki::cfg{Email}{SmimeCertL} ],
            O  => [ $Foswiki::cfg{Email}{SmimeCertO} ],
            U  => [ $Foswiki::cfg{Email}{SmimeCertOU} ],
        }
    );
}

=begin TML

---++ WIZARD cancel_cert

Cancel a pending Certificate Signing request. This destroys the
private key associated with the request.

=cut

sub cancel_cert {
    my ( $this, $reporter, $root ) = @_;
    my $ok = 1;

    my $certfile = '$Foswiki::cfg{DataDir}' . "/SmimeCertificate.pem";
    Foswiki::Configure::Load::expandValue($certfile);
    my $keyfile = '$Foswiki::cfg{DataDir}' . "/SmimePrivateKey.pem";
    Foswiki::Configure::Load::expandValue($keyfile);

    if ( -f "$certfile.csr" || -f "$keyfile.csr" ) {
        if ( -f "$certfile.csr" && !unlink("$certfile.csr") ) {
            $ok = 0;
            $reporter->ERROR("Can't delete $certfile.csr: $!");
        }
        if ( -f "$keyfile.csr" && !unlink("$keyfile.csr") ) {
            $ok = 0;
            $reporter->ERROR("Can't delete $keyfile.csr: $!");
        }
        if ($ok) {
            $reporter->NOTE("Request cancelled");
        }
        else {
            $reporter->ERROR("Cancel failed.");
        }
    }
    else {
        $reporter->NOTE("No request pending");
    }
    return undef;    # return the report
}

=begin TML

---++ WIZARD show_request

Show the pending SSL Certificate signing request.

=cut

sub show_request {
    my ( $this, $reporter ) = @_;

    my $certfile = '$Foswiki::cfg{DataDir}' . "/SmimeCertificate.pem";
    Foswiki::Configure::Load::expandValue($certfile);
    my $csrfile = "$certfile.csr";

    unless ( -r $csrfile ) {
        $reporter->ERROR("No CSR pending");
        return undef;
    }

    my $output;
    {
        no warnings 'exec';

        $output = `openssl req -in $csrfile -batch -subject -text 2>&1`;
    }
    if ($?) {
        $reporter->ERROR(
            "Operation failed" . ( $? == -1 ? " (No openssl: $!)" : '' ) );
    }
    else {
        $reporter->NOTE($output);
    }

    return undef;    # return the report
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
