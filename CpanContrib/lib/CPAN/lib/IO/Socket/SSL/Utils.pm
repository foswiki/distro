
package IO::Socket::SSL::Utils;
use strict;
use warnings;
use Carp 'croak';
use Net::SSLeay;
use Exporter 'import';

our $VERSION = '0.02';
our @EXPORT = qw(
    PEM_file2cert PEM_string2cert PEM_cert2file PEM_cert2string
    PEM_file2key PEM_string2key PEM_key2file PEM_key2string
    KEY_free CERT_free
    KEY_create_rsa CERT_asHash CERT_create
);

sub PEM_file2cert {
    my $file = shift;
    my $bio = Net::SSLeay::BIO_new_file($file,'r') or
	croak "cannot read $file: $!";
    my $cert = Net::SSLeay::PEM_read_bio_X509($bio);
    Net::SSLeay::BIO_free($bio);
    $cert or croak "cannot parse $file as PEM X509 cert: ".
	Net::SSLeay::ERR_error_string(Net::SSLeay::ERR_get_error());
    return $cert;
}

sub PEM_cert2file {
    my ($cert,$file) = @_;
    my $string = Net::SSLeay::PEM_get_string_X509($cert)
	or croak("cannot get string from cert");
    open( my $fh,'>',$file ) or croak("cannot write $file: $!");
    print $fh $string;
}

sub PEM_string2cert {
    my $string = shift;
    my $bio = Net::SSLeay::BIO_new( Net::SSLeay::BIO_s_mem());
    Net::SSLeay::BIO_write($bio,$string);
    my $cert = Net::SSLeay::PEM_read_bio_X509($bio);
    Net::SSLeay::BIO_free($bio);
    $cert or croak "cannot parse string as PEM X509 cert: ".
	Net::SSLeay::ERR_error_string(Net::SSLeay::ERR_get_error());
    return $cert;
}

sub PEM_cert2string {
    my $cert = shift;
    return Net::SSLeay::PEM_get_string_X509($cert)
	|| croak("cannot get string from cert");
}

sub PEM_file2key {
    my $file = shift;
    my $bio = Net::SSLeay::BIO_new_file($file,'r') or
	croak "cannot read $file: $!";
    my $cert = Net::SSLeay::PEM_read_bio_PrivateKey($bio);
    Net::SSLeay::BIO_free($bio);
    $cert or croak "cannot parse $file as PEM private key: ".
	Net::SSLeay::ERR_error_string(Net::SSLeay::ERR_get_error());
    return $cert;
}

sub PEM_key2file {
    my ($key,$file) = @_;
    my $string = Net::SSLeay::PEM_get_string_PrivateKey($key)
	or croak("cannot get string from key");
    open( my $fh,'>',$file ) or croak("cannot write $file: $!");
    print $fh $string;
}

sub PEM_string2key {
    my $string = shift;
    my $bio = Net::SSLeay::BIO_new( Net::SSLeay::BIO_s_mem());
    Net::SSLeay::BIO_write($bio,$string);
    my $cert = Net::SSLeay::PEM_read_bio_PrivateKey($bio);
    Net::SSLeay::BIO_free($bio);
    $cert or croak "cannot parse string as PEM private key: ".
	Net::SSLeay::ERR_error_string(Net::SSLeay::ERR_get_error());
    return $cert;
}

sub PEM_key2string {
    my $key = shift;
    return Net::SSLeay::PEM_get_string_PrivateKey($key)
	|| croak("cannot get string from key");
}

sub CERT_free {
    my $cert = shift or return;
    Net::SSLeay::X509_free($cert);
}

sub KEY_free {
    my $key = shift or return;
    Net::SSLeay::EVP_PKEY_free($key);
}

sub KEY_create_rsa {
    my $bits = shift || 2048;
    my $key = Net::SSLeay::EVP_PKEY_new();
    my $rsa = Net::SSLeay::RSA_generate_key($bits, 0x10001); # 0x10001 = RSA_F4
    Net::SSLeay::EVP_PKEY_assign_RSA($key,$rsa);
    return $key;
}

# extract information from cert
my %gen2i = qw( OTHERNAME 0 EMAIL 1 DNS 2 X400 3 DIRNAME 4 EDIPARTY 5 URI 6 IP 7 RID 8 );
my %i2gen = reverse %gen2i;
sub CERT_asHash {
    my $cert = shift;
    my $digest_name = shift || 'sha256';

    my %hash = (
	version => Net::SSLeay::X509_get_version($cert),
	not_before => _asn1t2t(Net::SSLeay::X509_get_notBefore($cert)),
	not_after => _asn1t2t(Net::SSLeay::X509_get_notAfter($cert)),
	serial => Net::SSLeay::ASN1_INTEGER_get(
	    Net::SSLeay::X509_get_serialNumber($cert)),
	crl_uri  => [ Net::SSLeay::P_X509_get_crl_distribution_points($cert) ],
	keyusage => [ Net::SSLeay::P_X509_get_key_usage($cert) ],
	extkeyusage => {
	    oid => [ Net::SSLeay::P_X509_get_ext_key_usage($cert,0) ],
	    nid => [ Net::SSLeay::P_X509_get_ext_key_usage($cert,1) ],
	    sn  => [ Net::SSLeay::P_X509_get_ext_key_usage($cert,2) ],
	    ln  => [ Net::SSLeay::P_X509_get_ext_key_usage($cert,3) ],
	},
	"pubkey_digest_$digest_name" => Net::SSLeay::X509_pubkey_digest(
	    $cert,_digest($digest_name)),
	"x509_digest_$digest_name" => Net::SSLeay::X509_digest(
	    $cert,_digest($digest_name)),
	"fingerprint_$digest_name" => Net::SSLeay::X509_get_fingerprint(
	    $cert,_digest($digest_name)),
    );

    my $subj = Net::SSLeay::X509_get_subject_name($cert);
    my %subj;
    for ( 0..Net::SSLeay::X509_NAME_entry_count($subj)-1 ) {
	my $e = Net::SSLeay::X509_NAME_get_entry($subj,$_);
	my $o = Net::SSLeay::X509_NAME_ENTRY_get_object($e);
	$subj{ Net::SSLeay::OBJ_obj2txt($o) } =
	    Net::SSLeay::P_ASN1_STRING_get(
		Net::SSLeay::X509_NAME_ENTRY_get_data($e));
    }
    $hash{subject} = \%subj;

    if ( my @names = Net::SSLeay::X509_get_subjectAltNames($cert) ) {
	my $alt = $hash{subjectAltNames} = [];
	while (my ($t,$v) = splice(@names,0,2)) {
	    $t = $i2gen{$t} || die "unknown type $t in subjectAltName";
	    if ( $t eq 'IP' ) {
		if (length($v) == 4) {
		    $v = join('.',unpack("CCCC",$v));
		} elsif ( length($v) == 16 ) {
		    $v = join(':',map { sprintf( "%x",$_) } unpack("NNNN",$v));
		}
	    }
	    push @$alt,[$t,$v]
	}
    }

    my $issuer = Net::SSLeay::X509_get_issuer_name($cert);
    my %issuer;
    for ( 0..Net::SSLeay::X509_NAME_entry_count($issuer)-1 ) {
	my $e = Net::SSLeay::X509_NAME_get_entry($issuer,$_);
	my $o = Net::SSLeay::X509_NAME_ENTRY_get_object($e);
	$issuer{ Net::SSLeay::OBJ_obj2txt($o) } =
	    Net::SSLeay::P_ASN1_STRING_get(
		Net::SSLeay::X509_NAME_ENTRY_get_data($e));
    }
    $hash{issuer} = \%issuer;

    my @ext;
    for( 0..Net::SSLeay::X509_get_ext_count($cert)-1 ) {
	my $e = Net::SSLeay::X509_get_ext($cert,$_);
	my $o = Net::SSLeay::X509_EXTENSION_get_object($e);
	my $nid = Net::SSLeay::OBJ_obj2nid($o);
	push @ext, {
	    oid => Net::SSLeay::OBJ_obj2txt($o),
	    nid => ( $nid > 0 ) ? $nid : undef,
	    sn  => ( $nid > 0 ) ? Net::SSLeay::OBJ_nid2sn($nid) : undef,
	    critical => Net::SSLeay::X509_EXTENSION_get_critical($e),
	    data => Net::SSLeay::X509V3_EXT_print($e),
	}
    }
    $hash{ext} = \@ext;

    if ( defined(&Net::SSLeay::P_X509_get_ocsp_uri)) {
	$hash{ocsp_uri} = [ Net::SSLeay::P_X509_get_ocsp_uri($cert) ];
    } else {
	$hash{ocsp_uri} = [];
	for( @ext ) {
	    $_->{sn} or next;
	    $_->{sn} eq 'authorityInfoAccess' or next;
	    push @{ $hash{ocsp_uri}}, $_->{data} =~m{\bOCSP - URI:(\S+)}g;
	}
    }

    return \%hash;
}

sub CERT_create {
    my %args = @_%2 ? %{ shift() } :  @_;

    my $cert = Net::SSLeay::X509_new();
    my $digest_name = delete $args{digest} || 'sha256';

    Net::SSLeay::ASN1_INTEGER_set(
	Net::SSLeay::X509_get_serialNumber($cert),
	delete $args{serial} || rand(2**32),
    );

    # version default to 2 (V3)
    Net::SSLeay::X509_set_version($cert,
	delete $args{version} || 2 );

    # not_before default to now
    Net::SSLeay::ASN1_TIME_set(
	Net::SSLeay::X509_get_notBefore($cert),
	delete $args{not_before} || time()
    );

    # not_after default to now+365 days
    Net::SSLeay::ASN1_TIME_set(
	Net::SSLeay::X509_get_notAfter($cert),
	delete $args{not_after} || time() + 365*86400
    );

    # set subject
    my $subj_e = Net::SSLeay::X509_get_subject_name($cert);
    my $subj = delete $args{subject} || {
	organizationName => 'IO::Socket::SSL',
	commonName => 'IO::Socket::SSL Test'
    };
    while ( my ($k,$v) = each %$subj ) {
	# 0x1000 = MBSTRING_UTF8
	Net::SSLeay::X509_NAME_add_entry_by_txt($subj_e,
	    $k, 0x1000, $v, -1, 0)
	    or croak("failed to add entry for $k - ".
	    Net::SSLeay::ERR_error_string(Net::SSLeay::ERR_get_error()));
    }

    my @ext = (
	&Net::SSLeay::NID_subject_key_identifier => 'hash',
	&Net::SSLeay::NID_authority_key_identifier => 'keyid',
	&Net::SSLeay::NID_authority_key_identifier => 'issuer',
    );
    if ( my $altsubj = delete $args{subjectAltNames} ) {
	push @ext,
	    &Net::SSLeay::NID_subject_alt_name =>
	    join(',', map { "$_->[0]:$_->[1]" } @$altsubj)
    }

    my $key = delete $args{key} || KEY_create_rsa();
    Net::SSLeay::X509_set_pubkey($cert,$key);

    my $is = delete $args{issuer};
    my $issuer_cert = delete $args{issuer_cert} || $is && $is->[0] || $cert;
    my $issuer_key  = delete $args{issuer_key}  || $is && $is->[1] || $key;
    if ( delete $args{CA} ) {
	push @ext,
	    &Net::SSLeay::NID_basic_constraints => 'critical,CA:TRUE',
	    &Net::SSLeay::NID_key_usage => 'critical,digitalSignature,keyCertSign',
	    &Net::SSLeay::NID_netscape_cert_type => 'sslCA,emailCA,objCA';
    } else {
	push @ext,
	    &Net::SSLeay::NID_key_usage => 'critical,digitalSignature,keyEncipherment',
	    &Net::SSLeay::NID_basic_constraints => 'CA:FALSE',
	    &Net::SSLeay::NID_ext_key_usage => 'serverAuth,clientAuth',
	    &Net::SSLeay::NID_netscape_cert_type => 'server';
    }

    Net::SSLeay::P_X509_add_extensions($cert, $issuer_cert, @ext);
    Net::SSLeay::X509_set_issuer_name($cert,
	Net::SSLeay::X509_get_subject_name($issuer_cert));
    Net::SSLeay::X509_sign($cert,$issuer_key,_digest($digest_name));

    return ($cert,$key);
}



if ( defined &Net::SSLeay::ASN1_TIME_timet ) {
    *_asn1t2t = \&Net::SSLeay::ASN1_TIME_timet
} else {
    require Time::Local;
    my %mon2i = qw(
	Jan 0 Feb 1 Mar 2 Apr 3 May 4 Jun 5
	Jul 6 Aug 7 Sep 8 Oct 9 Nov 10 Dec 11
    );
    *_asn1t2t = sub {
	my $t = Net::SSLeay::P_ASN1_TIME_put2string( shift );
	my ($mon,$d,$h,$m,$s,$y,$tz) = split(/[\s:]+/,$t);
	defined( $mon = $mon2i{$mon} ) or die "invalid month in $t";
	$tz ||= $y =~s{^(\d+)([A-Z]\S*)}{$1} && $2;
	if ( ! $tz ) {
	    return Time::Local::timelocal($s,$m,$h,$d,$mon,$y)
	} elsif ( $tz eq 'GMT' ) {
	    return Time::Local::timegm($s,$m,$h,$d,$mon,$y)
	} else {
	    die "unexpected TZ $tz from ASN1_TIME_print";
	}
    }
}

{
    my %digest;
    sub _digest {
	my $digest_name = shift;
	return $digest{$digest_name} ||= do {
	    Net::SSLeay::SSLeay_add_ssl_algorithms();
	    Net::SSLeay::EVP_get_digestbyname($digest_name)
		or die "Digest algorithm $digest_name is not available";
	};
    }
}


1;

__END__

=head1 NAME

IO::Socket::SSL::Utils -- loading, storing, creating certificates and keys

=head1 SYNOPSIS

    use IO::Socket::SSL::Utils;
    my $cert = PEM_file2cert('cert.pem');
    my $string = PEM_cert2string($cert);
    CERT_free($cert);

    my $key = KEY_create_rsa(2048);
    PEM_string2file($key);
    KEY_free($key);


=head1 DESCRIPTION

This module provides various utility functions to work with certificates and
private keys, shielding some of the complexity of the underlying Net::SSLeay and
OpenSSL.

=head1 FUNCTIONS

=over 4

=item *

Functions converting between string or file and certificates and keys.
They croak if the operation cannot be completed.

=over 8

=item PEM_file2cert(file) -> cert

=item PEM_cert2file(cert,file)

=item PEM_string2cert(string) -> cert

=item PEM_cert2string(cert) -> string

=item PEM_file2key(file) -> key

=item PEM_key2file(key,file)

=item PEM_string2key(string) -> key

=item PEM_key2string(key) -> string

=back

=item *

Functions for cleaning up.
Each loaded or created cert and key must be freed to not leak memory.

=over 8

=item CERT_free(cert)

=item KEY_free(key)

=back

=item * KEY_create_rsa(bits) -> key

Creates an RSA key pair, bits defaults to 2048.

=item * CERT_asHash(cert,[digest_algo]) -> hash

Extracts the information from the certificate into a hash and uses the given
digest_algo (default: SHA-256) to determine digest of pubkey and cert.
The resulting hash contains:

=over 8

=item subject

Hash with the parts of the subject, e.g. commonName, countryName,
organizationName, stateOrProvinceName, localityName.

=item subjectAltNames

Array with list of alternative names. Each entry in the list is of
C<[type,value]>, where C<type> can be OTHERNAME, EMAIL, DNS, X400, DIRNAME,
EDIPARTY, URI, IP or RID.

=item issuer

Hash with the parts of the issuer, e.g. commonName, countryName,
organizationName, stateOrProvinceName, localityName.

=item not_before, not_after

The time frame, where the certificate is valid, as time_t, e.g. can be converted
with localtime or similar functions.

=item serial

The serial number

=item crl_uri

List if URIs for CRL distribution.

=item ocsp_uri

List if URIs for revocation checking using OCSP.

=item keyusage

List of keyUsage information in the certificate.

=item extkeyusage

List of extended key usage information from the certificate. Each entry in
this list consists of a hash with oid, nid, ln and sn.

=item pubkey_digest_xxx

Binary digest of the pubkey using the given digest algorithm, e.g.
pubkey_digest_sha256 if (the default) SHA-256 was used.

=item cert_digest_xxx

Binary digest of the certificate using the given digest algorithm, e.g.
cert_digest_sha256 if (the default) SHA-256 was used.

=item fingerprint_xxx

Fingerprint of the certificate using the given digest algorithm, e.g.
fingerprint_sha256 if (the default) SHA-256 was used. Contrary to digest_* this
is an ASCII string with a list if hexadecimal numbers, e.g.
"73:59:75:5C:6D...".

=item ext

List of extensions.
Each entry in the list is a hash with oid, nid, sn, critical flag (boolean) and
data (string representation given by X509V3_EXT_print).

=item version

Certificate version, usually 2 (x509v3)

=back

=item * CERT_create(hash) -> (cert,key)

Creates a certificate based on the given hash.
If the issuer is not specified the certificate will be self-signed.
The following keys can be given:

=over 8

=item subject

Hash with the parts of the subject, e.g. commonName, countryName, ... as
described in C<CERT_asHash>.
Default points to IO::Socket::SSL.

=item not_before

A time_t value when the certificate starts to be valid. Defaults to current
time.

=item not_after

A time_t value when the certificate ends to be valid. Defaults to current
time plus one 365 days.

=item serial

The serial number. If not given a random number will be used.

=item version

The version of the certificate, default 2 (x509v3).

=item CA true|false

if true declare certificate as CA, defaults to false

=item key key

use given key as key for certificate, otherwise a new one will be generated and
returned

=item issuer_cert cert

set issuer for new certificate

=item issuer_key key

sign new certificate with given key

=item issuer [ cert, key ]

Instead of giving issuer_key and issuer_cert as separate arguments they can be
given both together.

=item digest algorithm

specify the algorithm used to sign the certificate, default SHA-256.

=back

=back

=head1 AUTHOR

Steffen Ullrich
