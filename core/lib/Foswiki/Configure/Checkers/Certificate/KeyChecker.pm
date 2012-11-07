# -*- mode: CPerl; -*-
# Foswiki off-line task management framework addon for Foswiki
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.

use strict;
use warnings;

=pod

---+ package Foswiki::Configure::Checkers::Certificate::KeyChecker
Configure GUI checker for Certificate Key items.

This checker validates files that contain private key files
such as for the S/MIME signatures and for the Tasks framework.

It must be subclassed for the various certificate types, as the requirements
are slightly different.

=cut

package Foswiki::Configure::Checkers::Certificate::KeyChecker;

use base 'Foswiki::Configure::Checker';
use Foswiki::Configure::Load;

# Private methods

# Decoding formats for known (and supported by decoders) private key types
#<<<
my %keyFormats = ( # PEM Header          Decoder argument list
  'RSA PRIVATE KEY' => [ Name => 'RSA PRIVATE KEY',
                         ASN  => qq(
       RSAPrivateKey SEQUENCE {
          version INTEGER, n INTEGER, e INTEGER, d INTEGER, p INTEGER, q INTEGER,
          dp INTEGER, dq INTEGER, iqmp INTEGER
       } ),            ],
  'DSA PRIVATE KEY' => [ Name => "DSA PRIVATE KEY",
                         ASN => qq(
       DSAPrivateKey SEQUENCE {
          version INTEGER, p INTEGER, q INTEGER, g INTEGER, pub_key INTEGER, priv_key INTEGER
       } )             ],
                 );

# Known encryption formats

my %decryptable = ( # Header code     decoder sub
                   'DES-EDE3-CBC' => \&decryptCPEM,
                  );
#>>>
# Decrypt using Convert::PEM

sub decryptCPEM {
    my ( $format, $pem, $encryption, $iv, $passkey, $password ) = @_;

    eval { require Convert::PEM; };
    if ($@) {
        return status => [ WARNING =>
"Unable to verify password $passkey: Please install Convert::PEM from CPAN.\n"
        ];
    }

    my $cvt = Convert::PEM->new( @{ $keyFormats{$format} } );

    my $key = $cvt->decode(
        Content  => $pem,
        Password => $password
    );
    unless ( defined $key ) {
        return ( status => [ ERROR => $cvt->errstr . ": Check $passkey.\n" ] );
    }

    #   return ( status => [ NOTE => "$passkey  verified" ],
    #             key => $pem->encode( Content => $key ) );
    return ( status => [ NOTE => "$passkey verified" ] );
}

# Load a key file that's supposed to contain a private key (PEM)

sub loadKey {
    my $file     = shift;
    my $passkey  = shift;
    my $password = shift;

    open( my $cf, '<', $file ) or return ( 1, scalar $! );
    local $/;
    my $key = <$cf>;
    close $cf;

    my @keys = (0);

    $key =~ s/\r//go;

    my @key;
    while ( $key =~
/^(-----BEGIN ((RSA|DSA) PRIVATE KEY)-----\n(?:(.*?\n)\n)?.*?^-----END (?:RSA|DSA) PRIVATE KEY-----$)/msgo
      )
    {
        my ( $pem, $format, $type, $headers ) = ( $1, $2, $3, $4 );
        my %h = map { split( /:\s*/, $_, 2 ) } split( /\n/, $headers )
          if ( defined $headers );

        @key = (
            type => $type || 'Unknown',
            view => 'private',
        );

        die "Unknown key type $format, update keyFormats in KeyChecker\n"
          unless ( defined $keyFormats{ $format || '' } );

        unless ( $h{'Proc-Type'} && $h{'Proc-Type'} eq '4,ENCRYPTED' ) {
            push @key, encrypted => '<em>unencrypted</em>';
            push @key,
              status => [ WARNING =>
"Password specified for unencrypted file, please clear $passkey"
              ]
              if ( defined $password && length $password );
            next;
        }

        push @key, encrypted => 'encrypted';
        unless ($passkey) {
            push @key, status =>
              [ ERROR => "Encrypted keyfile not supported for this item" ];
            next;
        }
        unless ( defined $password && length $password ) {
            push @key,
              status => [ ERROR => "$passkey must be specified; see $passkey" ];
            next;
        }
        unless ( $h{'DEK-Info'} ) {
            push @key, status =>
              [ ERROR => "Corrupt file: missing DEK-Info encryption header\n" ];
            next;
        }
        unless ( $h{'DEK-Info'} =~ /([\w-]+),([[:xdigit:]]+)$/
            && $decryptable{$1} )
        {
            push @key,
              status => [ WARNING => "$1 encryption is not supported" ];
            next;
        }
        my ( $encryption, $iv ) = ( $1, $2 );

        push @key, $decryptable{$encryption}
          ->( $format, $pem, $encryption, $iv, $passkey, $password );
    }
    continue {
        my %k;

        # This supports, e.g. status => [s1,m1], status => [s2,m2]
        while (@key) {
            my ( $k, $v ) = splice( @key, 0, 2 );
            if ( exists $k{$k} ) {
                if ( ref $k{$k} ) {
                    $k{$k} = [ @{ $k{$k} }, ref $v ? @$v : $v ];
                }
                else {
                    $k{$k} = [ $k{$k}, ref $v ? @$v : $v ];
                }
            }
            else {
                $k{$k} = $v;
            }
        }
        push @keys, [ map { $_, $k{$_} } keys %k ];
        @key = ();
    }

    return ( 1, "None found" ) unless ( @keys > 1 );
    return @keys;
}

=pod

---++ ObjectMethod check( $valueObject, $password ) -> $errorString
Validates a Key item for the configure GUI
   * =$valueObject= - configure value object
   * =$password= - Optional password key name for this file

A lot of checking is done here to prevent mystery errors at runtime.

Returns empty string if OK, error string with any errors

=cut

sub check {
    my $this    = shift;
    my $valobj  = shift;
    my $passkey = shift;

    my $keys = $valobj->getKeys() or die "No keys for value";
    my $value = eval "\$Foswiki::cfg$keys";
    return $this->ERROR("Can't evaluate current value of $keys: $@") if ($@);

# The default value may not have been available when the other defaulting is done.

    unless ( defined $value ) {
        $value = eval "\$Foswiki::defaultCfg->$keys";
        return $this->ERROR("Can't evaluate default value of $keys: $@")
          if ($@);
        $value = "***UNDEF***" unless defined $value;
    }

    # Expand any references to other variables

    Foswiki::Configure::Load::expandValue($value);

    return '' unless ( defined $value && length $value );
    my $xpv = "<b>Note:</b> $value";
    my $xpn = $this->NOTE($xpv);

    ( ( stat $value )[2] || 0 ) & 007
      and return $xpn . $this->ERROR("File permissions allow world access");

    my $password;
    if ($passkey) {
        $password = eval "\$Foswiki::cfg$passkey";
        return $xpn
          . $this->ERROR("Can't evaluate current value of $passkey: $@")
          if ($@);
    }

    my ( $errors, @keys ) = loadKey( $value, $passkey, $password );

    return $xpn . $this->ERROR( "No key in file: " . $keys[0] ) if ($errors);

    my $key = { @{ shift @keys } };

    my $warnings = '';
    $errors = '';

    my $notes = sprintf(
        "%s<br />\
Key Information: %s %s %s key", $xpv, ucfirst $key->{encrypted}, $key->{type},
        $key->{view}
    );

    if ( ( my $s = $key->{status} ) ) {
        while (@$s) {
            my ( $sev, $msg ) = splice( @$s, 0, 2 );

            eval sprintf "\$%ss .= ' $msg'", lc $sev;
            die "$@\n" if ($@);
        }
    }

    if (@keys) {
        $warnings .=
            "File contains "
          . @keys
          . " additional keys.  These will not be used and should be removed.";
    }

    $notes =~ s,<br />\z,,;

    my $sts = $this->NOTE($notes);
    $sts .= $this->WARN($warnings) if ($warnings);
    $sts .= $this->ERROR($errors)  if ($errors);
    return $sts;
}
1;
__END__

This is an original work by Timothe Litt.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 3
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details, published at
http://www.gnu.org/copyleft/gpl.html
