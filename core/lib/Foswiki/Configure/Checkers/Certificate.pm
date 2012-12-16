# -*- mode: CPerl; -*-
# Foswiki off-line task management framework addon for Foswiki
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.

use strict;
use warnings;

=pod

---+ package Foswiki::Configure::Checkers::CertificateChecker
Configure GUI checker for Certificate items.

This checker validates files that contain X.509 certificates,
such as for the S/MIME signatures and for the Tasks framework.

It must be subclassed for the various certificate types, as the requirements
are slightly different.

=cut

package Foswiki::Configure::Checkers::Certificate;

use base 'Foswiki::Configure::Checker';
use Foswiki::Configure::Load;

use MIME::Base64;

# Warning threshold for certificate expiration
# 30 days

my $expwarn = 30 * ( 24 * 60 * 60 );

# Private methods

# Load PEM certificate file & extract DER

sub loadCert {
    my $file = shift;

    open( my $cf, '<', $file ) or return ( 1, scalar $! );
    local $/;
    my $cert = <$cf>;
    close $cf;

    my @certs = (0);
    $cert =~ s/\r//go;

    push @certs, decode_base64($1)
      while ( $cert =~
/^-----BEGIN\s+(?:(?:X509|TRUSTED)\s+)?CERTIFICATE-----$(.*?)^-----END\s+(?:(?:X509|TRUSTED)\s+)?CERTIFICATE-----$/msog
      );

    return ( 1, "None found" ) unless ( @certs > 1 );

    return @certs;
}

# Remove duplicates from a subject alternate name list & sort

sub dedup( $@ ) {
    my $hostnames = shift;

    my %x = map { $_ => 1 } @_;

    return map { $_->[0] }
      sort {
        my @a = @$a;
        shift @a;
        my @b = @$b;
        shift @b;

        while ( @a && @b ) {
            my $c = shift @a cmp shift @b;
            return $c if ($c);
        }
        return @a <=> @b;
      } map { [ $_, ( $hostnames ? reverse split( /\./, $_ ) : $_ ) ] }
      keys %x;
}

=pod

---++ ObjectMethod checkUsage( $valueObject, $usage ) -> $errorString
Validates a Certificate item for the configure GUI
   * =$valueObject= - configure value object
   * =$usage= - Required use (email, client, server, clientserver)

Returns empty string if OK, error string with any errors
Optionally returns list of subjects.

=cut

sub checkUsage {
    my $this   = shift;
    my $valobj = shift;
    my $usage  = shift;

    my $keys = ( ref($valobj) ? $valobj->getKeys() : $valobj )
      or die "No keys for value";
    my $value = eval "\$Foswiki::cfg$keys";
    my $e     = '';
    if ($@) {
        $e = $this->ERROR("Can't evaluate current value of $keys: $@");
        return ( $e, ) if (wantarray);
        return $e;
    }

# The default value may not have been available when  the other defaulting is done.

    unless ( defined $value ) {
        $value = eval "\$Foswiki::defaultCfg->$keys";
        if ($@) {
            $e = $this->ERROR("Can't evaluate default value of $keys: $@");
            return ( $e, ) if (wantarray);
            return $e;
        }
        $value = "***UNDEF***" unless defined $value;
    }

    # Expand any references to other variables

    Foswiki::Configure::Load::expandValue($value);

    unless ( defined $value && length $value ) {
        return ( '', ) if (wantarray);
        return '';
    }
    my $xpv = "<b>Note:</b> $value";
    my $xpn = $this->NOTE($xpv);

    my ( $errors, @certs ) = loadCert($value);

    if ($errors) {
        $e = $xpn . $this->ERROR( "No certificate in file: " . $certs[0] );
    }
    else {
        ( ( stat $value )[2] || 0 ) & 002
          and $e = $xpn . $this->ERROR("File permissions allow world write");
    }
    if ($e) {
        return ( $e, ) if (wantarray);
        return $e;
    }

    eval { require Crypt::X509; };
    if ($@) {
        $e =
          $xpn
          . $this->WARN(
            "Unable to verify certificate: Please install Crypt::X509 from CPAN"
          );
        return ( $e, ) if (wantarray);
        return $e;
    }

    my $x = Crypt::X509->new( cert => shift @certs );
    if ( $x->error ) {
        $e = $xpn . $this->ERROR( "Invalid certificate: " . $x->error );
        return ( $e, ) if (wantarray);
        return $e;
    }

    my $sts      = '';
    my $warnings = '';
    $errors = '';

    my $notes = sprintf(
        "%s<br />\
Certificate Information:<br />
Issued by %s for %s", $xpv, ( $x->issuer_cn || 'Unknown issuer' ),
        ( $x->subject_cn || "Unknown subject" )
    );
    my @ans;
    my $hostnames;
    if ( $usage eq 'email' ) {
        push @ans, $x->subject_email if ( $x->subject_email );
    }
    if ( my $an = $x->SubjectAltName ) {
        if ( $usage eq 'email' ) {
            push @ans, map { ( split( /=/, $_, 2 ) )[1] }
              grep { /^(?:rfc822Name|x400Address)=(.?:.*)$/ } @$an;
        }
        elsif ( $usage =~ /^(?:client|server|clientserver)$/ ) {
            push @ans, map { ( split( /=/, $_, 2 ) )[1] }
              grep { /^(?:dNSName|iPAddress)=(?:.*)$/ } @$an;
            $hostnames = 1;
        }
        else {
            die "Unknown certificate usage required"
              ;    # Code issue: subclass has a new (or typo in) usage type
        }
    }
    if (@ans) {
        @ans = dedup( $hostnames, @ans );
        $notes .= ": " . join( ', ', @ans );
    }
    $notes .= "<br />";

    my $tm  = $x->not_before;
    my $now = time;
    if ( $now < $tm ) {
        $errors .= " Not valid until " . gmtime($tm) . " UTC";
    }
    else {
        $notes .= " Valid from: " . gmtime($tm) . " UTC";
    }
    $tm = $x->not_after;
    if ( $now > $tm ) {
        $errors .= " Expired " . gmtime($tm) . " UTC";
    }
    elsif ( ( $now + $expwarn ) > $tm ) {
        $warnings .= " Expires soon " . gmtime($tm) . " UTC";
    }
    else {
        $notes .= " Expires " . gmtime($tm) . " UTC";
    }
    $notes .= '<br />' unless ( $notes =~ />$/ );

    my %ku;
    %ku = map { $_ => 1 } @{ $x->KeyUsage } if ( $x->KeyUsage );
    my %xku;
    %xku = map { $_ => 1 } @{ $x->ExtKeyUsage } if ( $x->ExtKeyUsage );
    if ( $usage eq 'email' ) {
        $errors .= " Not valid for email protection"
          unless ( $xku{emailProtection}
            && $ku{digitalSignature} );
    }
    elsif ( $usage eq 'client' ) {
        $errors .= " Not valid for client authentication"
          unless ( $xku{clientAuth}
            && $ku{digitalSignature}
            && $ku{keyEncipherment}
            && $ku{keyAgreement} );
    }
    elsif ( $usage eq 'server' ) {
        $errors .= " Not valid for server authentication"
          unless ( $xku{serverAuth}
            && $ku{digitalSignature}
            && $ku{keyEncipherment}
            && $ku{keyAgreement} );
    }
    elsif ( $usage eq 'clientserver' ) {
        $errors .= " Not valid for client/server authentication"
          unless ( $xku{clientAuth}
            && $xku{serverAuth}
            && $ku{digitalSignature}
            && $ku{keyEncipherment}
            && $ku{keyAgreement} );
    }

    $notes =~ s,<br />\z,,;

    $sts .= $this->NOTE($notes);
    $sts .= $this->WARN($warnings) if ($warnings);
    $sts .= $this->ERROR($errors) if ($errors);
    ( $notes, $warnings, $errors ) = ('') x 3;

    # Handle any chained certificates in file.
    # These must be CAs, so we don't bother with alternate names
    # or other unlikely detail.  The goal is to confirm that the
    # certificates are what's expected and in the right order.

    if (@certs) {
        $notes .= "Supplemental certificates:<br />";

        my $n    = 0;
        my $mult = @certs > 1;
        while (@certs) {
            $n++;
            $x = Crypt::X509->new( cert => shift @certs );
            if ( $x->error ) {
                $errors .= "Invalid certificate $n: " . $x->error;
                next;
            }

            $notes .= "$n: " if ($mult);
            $notes .= sprintf(
                "\
Issued by %s for %s<br />", ( $x->issuer_cn || 'Unknown issuer' ),
                ( $x->subject_cn || "Unknown subject" )
            );

            $tm = $x->not_before;
            if ( $now < $tm ) {
                $errors .= " Not valid until " . gmtime($tm) . " UTC";
            }
            else {
                $notes .= " Valid from: " . gmtime($tm) . " UTC";
            }
            $tm = $x->not_after;
            if ( $now > $tm ) {
                $errors .= " Expired " . gmtime($tm) . " UTC";
            }
            elsif ( ( $now + $expwarn ) > $tm ) {
                $warnings .= " Expires soon " . gmtime($tm) . " UTC";
            }
            else {
                $notes .= " Expires " . gmtime($tm) . " UTC";
            }
            $notes .= '<br />' unless ( $notes =~ />$/ );

            my %ku;
            %ku = map { $_ => 1 } @{ $x->KeyUsage } if ( $x->KeyUsage );
            my %xku;
            %xku = map { $_ => 1 } @{ $x->ExtKeyUsage }
              if ( $x->ExtKeyUsage );
            $errors .= " Not valid for Certificate Authority"
              unless ( $ku{critical}
                && $ku{keyCertSign}
                && $ku{cRLSign} );

            $notes =~ s,<br />\z,,;

            $sts .= $this->NOTE($notes);
            $sts .= $this->WARN($warnings) if ($warnings);
            $sts .= $this->ERROR($errors) if ($errors);
            ( $notes, $warnings, $errors ) = ('') x 3;
        }
    }
    return ( $sts, @ans ) if (wantarray);
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
