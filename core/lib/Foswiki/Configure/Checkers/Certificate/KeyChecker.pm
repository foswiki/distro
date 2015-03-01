# Foswiki off-line task management framework addon for Foswiki
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.

use strict;
use warnings;

=pod

---+ package Foswiki::Configure::Checkers::Certificate::KeyChecker
Checker for Certificate Key items.

This checker validates files that contain private key files
such as for the S/MIME signatures and for the Tasks framework.

It must be subclassed for the various certificate types, as the requirements
are slightly different.

=cut

package Foswiki::Configure::Checkers::Certificate::KeyChecker;

require Foswiki::Configure::Checker;
our @ISA = qw(Foswiki::Configure::Checker);

use Foswiki::Configure::Load ();

use Assert;

sub check {
    ASSERT( 0, "Subclasses must implement this" ) if DEBUG;
}

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
                   'DES-EDE3-CBC' => \&_decryptCPEM,
                  );
#>>>
# Decrypt using Convert::PEM

sub _decryptCPEM {
    my ( $format, $pem, $encryption, $iv, $passkey, $password ) = @_;

    eval('require Convert::PEM');
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

sub _loadKey {
    my $file     = shift;
    my $passkey  = shift;
    my $password = shift;

    open( my $cf, '<', $file ) or return ( 1, scalar($!) );
    local $/;
    my $key = <$cf>;
    close $cf;

    my @keys = (0);

    $key =~ s/\r//g;

    my @key;
    while ( $key =~
m/^(-----BEGIN ((RSA|DSA) PRIVATE KEY)-----\n(?:(.*?\n)\n)?.*?^-----END (?:RSA|DSA) PRIVATE KEY-----$)/msg
      )
    {
        my ( $pem, $format, $type, $headers ) = ( $1, $2, $3, $4 );
        my %h;
        %h = map { split( /:\s*/, $_, 2 ) } split( /\n/, $headers )
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
        unless ( $h{'DEK-Info'} =~ m/([\w-]+),([[:xdigit:]]+)$/
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

---++ ObjectMethod check( $keys, $password, $reporter )
Validates a Key item for the configure GUI
   * =$keys= - configure value object
   * =$password= - Optional password key name for this file

A lot of checking is done here to prevent mystery errors at runtime.

=cut

sub validateKeys {
    my ( $this, $keys, $passkey, $reporter ) = @_;

    my $value = eval("\$Foswiki::cfg$keys");
    if ($@) {
        return $reporter->ERROR( "Can't evaluate current value of $keys: "
              . Foswiki::Configure::Reporter::stripStacktrace($@) );
    }

# The default value may not have been available when the other defaulting is done.

    unless ( defined $value ) {
        $value = eval("\$Foswiki::Configure::defaultCfg->$keys");
        if ($@) {
            return $reporter->ERROR(
                "Can't evaluate default value of $keys: "
                  . Foswiki::Configure::Reporter::stripStacktrace($@) );
        }
        $value = "***UNDEF***" unless defined $value;
    }

    # Expand any references to other variables

    Foswiki::Configure::Load::expandValue($value);

    return '' unless ( defined $value && length $value );
    my $xpv = "<b>Note:</b> $value";
    $reporter->NOTE($xpv);

    ( ( stat $value )[2] || 0 ) & 007
      and return $reporter->ERROR("File permissions allow world access");

    my $password;
    if ($passkey) {
        $password = eval("\$Foswiki::cfg$passkey");
        if ($@) {
            return $reporter->ERROR(
                "Can't evaluate current value of $passkey: "
                  . Foswiki::Configure::Reporter::stripStacktrace($@) );
        }
    }

    my ( $errors, @keys ) = _loadKey( $value, $passkey, $password );

    return $reporter->ERROR( "No key in file: " . $keys[0] ) if ($errors);

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
            $sev =~ m/^([\w]+)$/ or die "Bad severity";
            $sev = lc $1;

            eval("\$sev = \\\$${sev}s");
            die "$@\n" if ($@);
            $$sev .= $msg;
        }
    }

    if (@keys) {
        $warnings .=
            "File contains "
          . @keys
          . " additional keys.  These will not be used and should be removed.";
    }

    $notes =~ s,<br />\z,,;

    $reporter->NOTE($notes);
    $reporter->WARN($warnings) if ($warnings);
    $reporter->ERROR($errors)  if ($errors);
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
