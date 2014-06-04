# vim: set sts=4 sw=4 ts=8 ai:
#
# IO::Socket::SSL:
# provide an interface to SSL connections similar to IO::Socket modules
#
# Current Code Shepherd: Steffen Ullrich <sullr at cpan.org>
# Code Shepherd before: Peter Behroozi, <behrooz at fas.harvard.edu>
#
# The original version of this module was written by
# Marko Asplund, <marko.asplund at kronodoc.fi>, who drew from
# Crypt::SSLeay (Net::SSL) by Gisle Aas.
#

package IO::Socket::SSL;

use IO::Socket;
use Net::SSLeay 1.46;
use IO::Socket::SSL::PublicSuffix;
use Exporter ();
use Errno qw( EAGAIN ETIMEDOUT );
use Carp;
use strict;

BEGIN {
    eval { require Scalar::Util; Scalar::Util->import("weaken"); 1 }
	|| eval { require WeakRef; WeakRef->import("weaken"); 1 }
	|| die "no support for weaken - please install Scalar::Util";
}



our $VERSION = '1.992';

use constant SSL_VERIFY_NONE => Net::SSLeay::VERIFY_NONE();
use constant SSL_VERIFY_PEER => Net::SSLeay::VERIFY_PEER();
use constant SSL_VERIFY_FAIL_IF_NO_PEER_CERT => Net::SSLeay::VERIFY_FAIL_IF_NO_PEER_CERT();
use constant SSL_VERIFY_CLIENT_ONCE => Net::SSLeay::VERIFY_CLIENT_ONCE();

# from openssl/ssl.h; should be better in Net::SSLeay
use constant SSL_SENT_SHUTDOWN => 1;
use constant SSL_RECEIVED_SHUTDOWN => 2;

use constant SSL_OCSP_NO_STAPLE   => 0b00001;
use constant SSL_OCSP_MUST_STAPLE => 0b00010;
use constant SSL_OCSP_FAIL_HARD   => 0b00100;
use constant SSL_OCSP_FULL_CHAIN  => 0b01000;
use constant SSL_OCSP_TRY_STAPLE  => 0b10000;

# capabilities of underlying Net::SSLeay/openssl
my $can_client_sni;  # do we support SNI on the client side
my $can_server_sni;  # do we support SNI on the server side
my $can_npn;         # do we support NPN
my $can_ecdh;        # do we support ECDH key exchange
my $can_ocsp;        # do we support OCSP
my $can_ocsp_staple; # do we support OCSP stapling
BEGIN {
    $can_client_sni = Net::SSLeay::OPENSSL_VERSION_NUMBER() >= 0x01000000;
    $can_server_sni = defined &Net::SSLeay::get_servername;
    $can_npn        = defined &Net::SSLeay::P_next_proto_negotiated;
    $can_ecdh       = defined &Net::SSLeay::CTX_set_tmp_ecdh && 
	# There is a regression with elliptic curves on 1.0.1d with 64bit
	# http://rt.openssl.org/Ticket/Display.html?id=2975
	( Net::SSLeay::OPENSSL_VERSION_NUMBER() != 0x1000104f
	|| length(pack("P",0)) == 4 );
    $can_ocsp        = defined &Net::SSLeay::OCSP_cert2ids;
    $can_ocsp_staple = $can_ocsp 
	&& defined &Net::SSLeay::set_tlsext_status_type;
}

my $algo2digest = do {
    my %digest;
    sub {
	my $digest_name = shift;
	return $digest{$digest_name} ||= do {
	    Net::SSLeay::SSLeay_add_ssl_algorithms();
	    Net::SSLeay::EVP_get_digestbyname($digest_name)
		or die "Digest algorithm $digest_name is not available";
	};
    }
};


# global defaults
my %DEFAULT_SSL_ARGS = (
    SSL_check_crl => 0,
    SSL_version => 'SSLv23:!SSLv2',
    SSL_verify_callback => undef,
    SSL_verifycn_scheme => undef,  # fallback cn verification
    SSL_verifycn_publicsuffix => undef,  # fallback default list verification
    #SSL_verifycn_name => undef,   # use from PeerAddr/PeerHost - do not override in set_args_filter_hack 'use_defaults'
    SSL_npn_protocols => undef,    # meaning depends whether on server or client side
    SSL_cipher_list =>
	'EECDH+AESGCM+ECDSA EECDH+AESGCM EECDH+ECDSA +AES256 EECDH EDH+AESGCM '.
	'EDH ALL +SHA +3DES +RC4 !LOW !EXP !eNULL !aNULL !DES !MD5 !PSK !SRP',
);

my %DEFAULT_SSL_CLIENT_ARGS = (
    %DEFAULT_SSL_ARGS,
    SSL_verify_mode => SSL_VERIFY_PEER,

    SSL_ca_file => undef,
    SSL_ca_path => undef,
    default_ca(),

    # older versions of F5 BIG-IP hang when getting SSL client hello >255 bytes
    # http://support.f5.com/kb/en-us/solutions/public/13000/000/sol13037.html
    # http://guest:guest@rt.openssl.org/Ticket/Display.html?id=2771
    # Debian works around this by disabling TLSv1_2 on the client side
    # Chrome and IE11 use TLSv1_2 but use only a few ciphers, so that packet
    # stays small enough
    # The following list is taken from IE11, except that we don't do RC4-MD5,
    # RC4-SHA is already bad enough. Also, we have a different sort order
    # compared to IE11, because we put ciphers supporting forward secrecy on top

    SSL_cipher_list => join(" ",
	qw(
	    ECDHE-ECDSA-AES128-GCM-SHA256
	    ECDHE-ECDSA-AES128-SHA256
	    ECDHE-ECDSA-AES256-GCM-SHA384
	    ECDHE-ECDSA-AES256-SHA384
	    ECDHE-ECDSA-AES128-SHA
	    ECDHE-ECDSA-AES256-SHA
	    ECDHE-RSA-AES128-SHA256
	    ECDHE-RSA-AES128-SHA
	    ECDHE-RSA-AES256-SHA
	    DHE-DSS-AES128-SHA256
	    DHE-DSS-AES128-SHA
	    DHE-DSS-AES256-SHA256
	    DHE-DSS-AES256-SHA
	    AES128-SHA256
	    AES128-SHA
	    AES256-SHA256
	    AES256-SHA
	    EDH-DSS-DES-CBC3-SHA
	    DES-CBC3-SHA
	    RC4-SHA
	),
	# just to make sure, that we don't accidentely add bad ciphers above
	"!EXP !LOW !eNULL !aNULL !DES !MD5 !PSK !SRP"
    )
);

my %DEFAULT_SSL_SERVER_ARGS = (
    %DEFAULT_SSL_ARGS,
    SSL_verify_mode => SSL_VERIFY_NONE,
    SSL_honor_cipher_order => 1,   # trust server to know the best cipher
    SSL_dh => do {
	my $bio = Net::SSLeay::BIO_new(Net::SSLeay::BIO_s_mem());
	# generated with: openssl dhparam 2048
	Net::SSLeay::BIO_write($bio,<<'DH');
-----BEGIN DH PARAMETERS-----
MIIBCAKCAQEAr8wskArj5+1VCVsnWt/RUR7tXkHJ7mGW7XxrLSPOaFyKyWf8lZht
iSY2Lc4oa4Zw8wibGQ3faeQu/s8fvPq/aqTxYmyHPKCMoze77QJHtrYtJAosB9SY
CN7s5Hexxb5/vQ4qlQuOkVrZDiZO9GC4KaH9mJYnCoAsXDhDft6JT0oRVSgtZQnU
gWFKShIm+JVjN94kGs0TcBEesPTK2g8XVHK9H8AtSUb9BwW2qD/T5RmgNABysApO
Ps2vlkxjAHjJcqc3O+OiImKik/X2rtBTZjpKmzN3WWTB0RJZCOWaLlDO81D01o1E
aZecz3Np9KIYey900f+X7zC2bJxEHp95ywIBAg==
-----END DH PARAMETERS-----
DH
	my $dh = Net::SSLeay::PEM_read_bio_DHparams($bio);
	Net::SSLeay::BIO_free($bio);
	$dh or die "no DH";
	$dh;
    },
    $can_ecdh ? ( SSL_ecdh_curve => 'prime256v1' ):(),
);

# global defaults which can be changed using set_defaults
# either key/value can be set or it can just be set to an external hash
my $GLOBAL_SSL_ARGS = {};
my $GLOBAL_SSL_CLIENT_ARGS = {};
my $GLOBAL_SSL_SERVER_ARGS = {};

# hack which is used to filter bad settings from used modules
my $FILTER_SSL_ARGS = undef;

# non-XS Versions of Scalar::Util will fail
BEGIN{
    local $SIG{__DIE__}; local $SIG{__WARN__}; # be silent
    eval { use Scalar::Util 'dualvar'; dualvar(0,'') };
    die "You need the XS Version of Scalar::Util for dualvar() support"
	if $@;
}

# get constants for SSL_OP_NO_* now, instead calling the releated functions
# every time we setup a connection
my %SSL_OP_NO;
for(qw( SSLv2 SSLv3 TLSv1 TLSv1_1 TLSv11:TLSv1_1 TLSv1_2 TLSv12:TLSv1_2 )) {
    my ($k,$op) = m{:} ? split(m{:},$_,2) : ($_,$_);
    my $sub = "Net::SSLeay::OP_NO_$op";
    $SSL_OP_NO{$k} = eval { no strict 'refs'; &$sub } || 0;
}

our $DEBUG;
use vars qw(@ISA $SSL_ERROR @EXPORT);

{
    # These constants will be used in $! at return from SSL_connect,
    # SSL_accept, generic_read and write, thus notifying the caller
    # the usual way of problems. Like with EAGAIN, EINPROGRESS..
    # these are especially important for non-blocking sockets

    my $x = Net::SSLeay::ERROR_WANT_READ();
    use constant SSL_WANT_READ  => dualvar( \$x, 'SSL wants a read first' );
    my $y = Net::SSLeay::ERROR_WANT_WRITE();
    use constant SSL_WANT_WRITE => dualvar( \$y, 'SSL wants a write first' );

    @EXPORT = qw(
	SSL_WANT_READ SSL_WANT_WRITE SSL_VERIFY_NONE SSL_VERIFY_PEER
	SSL_VERIFY_FAIL_IF_NO_PEER_CERT SSL_VERIFY_CLIENT_ONCE
	SSL_OCSP_NO_STAPLE SSL_OCSP_TRY_STAPLE SSL_OCSP_MUST_STAPLE
	SSL_OCSP_FAIL_HARD SSL_OCSP_FULL_CHAIN
	$SSL_ERROR GEN_DNS GEN_IPADD
    );
}

my @caller_force_inet4; # in case inet4 gets forced we store here who forced it

my $IOCLASS;
BEGIN {
    # declare @ISA depending of the installed socket class

    # try to load inet_pton from Socket or Socket6 and make sure it is usable
    local $SIG{__DIE__}; local $SIG{__WARN__}; # be silent
    my $ip6 = eval {
	require Socket;
	Socket->VERSION(1.95);
	my $ok = Socket::inet_pton( AF_INET6(),'::1') && AF_INET6();
	$ok && Socket->import( qw/inet_pton getnameinfo NI_NUMERICHOST NI_NUMERICSERV/ );
	$ok;
    } || eval {
	require Socket6;
	my $ok = Socket6::inet_pton( AF_INET6(),'::1') && AF_INET6();
	$ok && Socket6->import( qw/inet_pton getnameinfo NI_NUMERICHOST NI_NUMERICSERV/ );
	$ok;
    };

    # try IO::Socket::IP or IO::Socket::INET6 for IPv6 support
    if ( $ip6 ) {
	# if we have IO::Socket::IP >= 0.20 we will use this in preference
	# because it can handle both IPv4 and IPv6
	if ( eval { require IO::Socket::IP; IO::Socket::IP->VERSION(0.20); } ) {
	    @ISA = qw(IO::Socket::IP);
	    constant->import( CAN_IPV6 => "IO::Socket::IP" );
	    $IOCLASS = "IO::Socket::IP";

	# if we have IO::Socket::INET6 we will use this not IO::Socket::INET
	# because it can handle both IPv4 and IPv6
	# require at least 2.62 because of several problems before that version
	} elsif( eval { require IO::Socket::INET6; IO::Socket::INET6->VERSION(2.62) } ) {
	    @ISA = qw(IO::Socket::INET6);
	    constant->import( CAN_IPV6 => "IO::Socket::INET6" );
	    $IOCLASS = "IO::Socket::INET6";
	} else {
	    $ip6 = 0;
	}
    }

    # fall back to IO::Socket::INET for IPv4 only
    if ( ! $ip6 ) {
	@ISA = qw(IO::Socket::INET);
	$IOCLASS = "IO::Socket::INET";
	constant->import( CAN_IPV6 => '' );
    }

    #Make $DEBUG another name for $Net::SSLeay::trace
    *DEBUG = \$Net::SSLeay::trace;

    #Compatibility
    *ERROR = \$SSL_ERROR;

    # Do Net::SSLeay initialization
    Net::SSLeay::load_error_strings();
    Net::SSLeay::SSLeay_add_ssl_algorithms();
    Net::SSLeay::OpenSSL_add_all_digests();
    Net::SSLeay::randomize();
}

sub DEBUG {
    $DEBUG or return;
    my (undef,$file,$line) = caller;
    my $msg = shift;
    $file = '...'.substr( $file,-17 ) if length($file)>20;
    $msg = sprintf $msg,@_ if @_;
    print STDERR "DEBUG: $file:$line: $msg\n";
}

BEGIN {
    # import some constants from Net::SSLeay or use hard-coded defaults
    # if Net::SSLeay isn't recent enough to provide the constants
    my %const = (
	NID_CommonName => 13,
	GEN_DNS => 2,
	GEN_IPADD => 7,
    );
    while ( my ($name,$value) = each %const ) {
	no strict 'refs';
	*{$name} = UNIVERSAL::can( 'Net::SSLeay', $name ) || sub { $value };
    }

    *idn_to_ascii = \&IO::Socket::SSL::PublicSuffix::idn_to_ascii;
    *idn_to_unicode = \&IO::Socket::SSL::PublicSuffix::idn_to_unicode;
}

{
    my %default_ca;
    my $ca_detected; # 0: never detect, undef: need to (re)detect
    my $openssldir;
    sub default_ca {
	if (@_) {
	    # user defined default CA or reset
	    if ( @_ > 1 ) {
		%default_ca = @_;
		$ca_detected  = 0;
	    } elsif ( my $path = shift ) {
		%default_ca =
		    -d $path ? ( SSL_ca_path => $path ) :
		    -f $path ? ( SSL_ca_file => $path ) :
		    die "no such file or directory $path";
		$ca_detected  = 0;
	    } else {
		$ca_detected = undef;
	    }
	}
	return %default_ca if defined $ca_detected;

	$openssldir ||= Net::SSLeay::SSLeay_version(5)
	    =~m{^OPENSSLDIR: "(.+)"$} && $1 || '';

	# (re)detect according to openssl crypto/cryptlib.h
	my $dir = $ENV{SSL_CERT_DIR}
	    || ( $^O =~m{vms}i ? "SSLCERTS:":"$openssldir/certs" );
	if ( opendir(my $dh,$dir)) {
	    FILES: for my $f (  grep { m{^[a-f\d]{8}(\.\d+)?$} } readdir($dh) ) {
		open( my $fh,'<',"$dir/$f") or next;
		while (my $line = <$fh>) {
		    $line =~m{^-+BEGIN (X509 |TRUSTED |)CERTIFICATE-} or next;
		    $default_ca{SSL_ca_path} = $dir;
		    last FILES;
		}
	    }
	}
	my $file = $ENV{SSL_CERT_FILE}
	    || ( $^O =~m{vms}i ? "SSLCERTS:cert.pem":"$openssldir/cert.pem" );
	if ( open(my $fh,'<',$file)) {
	    while (my $line = <$fh>) {
		$line =~m{^-+BEGIN (X509 |TRUSTED |)CERTIFICATE-} or next;
		$default_ca{SSL_ca_file} = $file;
		last;
	    }
	}

	$default_ca{SSL_ca_file} = Mozilla::CA::SSL_ca_file()
	    if ! %default_ca && eval { require Mozilla::CA };

	$ca_detected = 1;
	return %default_ca;
    }
}


# Export some stuff
# inet4|inet6|debug will be handled by myself, everything
# else will be handled the Exporter way
sub import {
    my $class = shift;

    my @export;
    foreach (@_) {
	if ( /^inet4$/i ) {
	    # explicitly fall back to inet4
	    @ISA = 'IO::Socket::INET';
	    @caller_force_inet4 = caller(); # save for warnings for 'inet6' case
	} elsif ( /^inet6$/i ) {
	    # check if we have already ipv6 as base
	    if ( ! UNIVERSAL::isa( $class, 'IO::Socket::INET6')
		and ! UNIVERSAL::isa( $class, 'IO::Socket::IP' )) {
		# either we don't support it or we disabled it by explicitly
		# loading it with 'inet4'. In this case re-enable but warn
		# because this is probably an error
		if ( CAN_IPV6 ) {
		    @ISA = ( CAN_IPV6 );
		    warn "IPv6 support re-enabled in __PACKAGE__, got disabled in file $caller_force_inet4[1] line $caller_force_inet4[2]";
		} else {
		    die "INET6 is not supported, install IO::Socket::INET6";
		}
	    }
	} elsif ( /^:?debug(\d+)/ ) {
	    $DEBUG=$1;
	} else {
	    push @export,$_
	}
    }

    @_ = ( $class,@export );
    goto &Exporter::import;
}

my %SSL_OBJECT;
my %CREATED_IN_THIS_THREAD;
sub CLONE { %CREATED_IN_THIS_THREAD = (); }

# You might be expecting to find a new() subroutine here, but that is
# not how IO::Socket::INET works.  All configuration gets performed in
# the calls to configure() and either connect() or accept().

#Call to configure occurs when a new socket is made using
#IO::Socket::INET.  Returns false (empty list) on failure.
sub configure {
    my ($self, $arg_hash) = @_;
    return _invalid_object() unless($self);

    # force initial blocking
    # otherwise IO::Socket::SSL->new might return undef if the
    # socket is nonblocking and it fails to connect immediately
    # for real nonblocking behavior one should create a nonblocking
    # socket and later call connect explicitly
    my $blocking = delete $arg_hash->{Blocking};

    # because Net::HTTPS simple redefines blocking() to {} (e.g
    # return undef) and IO::Socket::INET does not like this we
    # set Blocking only explicitly if it was set
    $arg_hash->{Blocking} = 1 if defined ($blocking);

    $self->configure_SSL($arg_hash) || return;

    $self->SUPER::configure($arg_hash)
	|| return $self->error("@ISA configuration failed");

    $self->blocking(0) if defined $blocking && !$blocking;
    return $self;
}

sub configure_SSL {
    my ($self, $arg_hash) = @_;

    $arg_hash->{Proto} ||= 'tcp';
    my $is_server = $arg_hash->{SSL_server};
    if ( ! defined $is_server ) {
	$is_server = $arg_hash->{SSL_server} = $arg_hash->{Listen} || 0;
    }

    # add user defined defaults, maybe after filtering
    $FILTER_SSL_ARGS->($is_server,$arg_hash) if $FILTER_SSL_ARGS;
    my %defaults = (
	%$GLOBAL_SSL_ARGS,
	$is_server ? %$GLOBAL_SSL_SERVER_ARGS : %$GLOBAL_SSL_CLIENT_ARGS,
    );
    if ( $defaults{SSL_reuse_ctx} ) {
	# ignore default context if there are args to override it
	delete $defaults{SSL_reuse_ctx}
	    if grep { m{^SSL_(?!verifycn_name|hostname)$} } keys %$arg_hash;
    }
    %$arg_hash = ( %defaults, %$arg_hash ) if %defaults;

    my $ctx = $arg_hash->{'SSL_reuse_ctx'};
    if ($ctx) {
	if ($ctx->isa('IO::Socket::SSL::SSL_Context') and
	    $ctx->{context}) {
	    # valid context
	} elsif ( $ctx = ${*$ctx}{_SSL_ctx} ) {
	    # reuse context from existing SSL object
	}
    }

    # create context
    # this will fill in defaults in $arg_hash
    $ctx ||= IO::Socket::SSL::SSL_Context->new($arg_hash);

    ${*$self}{'_SSL_arguments'} = $arg_hash;
    ${*$self}{'_SSL_ctx'} = $ctx;
    ${*$self}{'_SSL_opened'} = 1 if $is_server;

    return $self;
}


sub _set_rw_error {
    my ($self,$ssl,$rv) = @_;
    my $err = Net::SSLeay::get_error($ssl,$rv);
    $SSL_ERROR =
	$err == Net::SSLeay::ERROR_WANT_READ()  ? SSL_WANT_READ :
	$err == Net::SSLeay::ERROR_WANT_WRITE() ? SSL_WANT_WRITE :
	return;
    $! ||= EAGAIN;
    ${*$self}{'_SSL_last_err'} = $SSL_ERROR if ref($self);
    return 1;
}


#Call to connect occurs when a new client socket is made using
#IO::Socket::INET
sub connect {
    my $self = shift || return _invalid_object();
    return $self if ${*$self}{'_SSL_opened'};  # already connected

    if ( ! ${*$self}{'_SSL_opening'} ) {
	# call SUPER::connect if the underlying socket is not connected
	# if this fails this might not be an error (e.g. if $! = EINPROGRESS
	# and socket is nonblocking this is normal), so keep any error
	# handling to the client
	$DEBUG>=2 && DEBUG('socket not yet connected' );
	$self->SUPER::connect(@_) || return;
	$DEBUG>=2 && DEBUG('socket connected' );

	# IO::Socket works around systems, which return EISCONN or similar
	# on non-blocking re-connect by returning true, even if $! is set
	# but it does not clear $!, so do it here
	$! = undef;
    }
    return $self->connect_SSL;
}


sub connect_SSL {
    my $self = shift;
    my $args = @_>1 ? {@_}: $_[0]||{};

    my ($ssl,$ctx);
    if ( ! ${*$self}{'_SSL_opening'} ) {
	# start ssl connection
	$DEBUG>=2 && DEBUG('ssl handshake not started' );
	${*$self}{'_SSL_opening'} = 1;
	my $arg_hash = ${*$self}{'_SSL_arguments'};

	my $fileno = ${*$self}{'_SSL_fileno'} = fileno($self);
	return $self->error("Socket has no fileno") unless (defined $fileno);

	$ctx = ${*$self}{'_SSL_ctx'};  # Reference to real context
	$ssl = ${*$self}{'_SSL_object'} = Net::SSLeay::new($ctx->{context})
	    || return $self->error("SSL structure creation failed");
	$CREATED_IN_THIS_THREAD{$ssl} = 1;
	$SSL_OBJECT{$ssl} = [$self,0];
	weaken($SSL_OBJECT{$ssl}[0]);

	Net::SSLeay::set_fd($ssl, $fileno)
	    || return $self->error("SSL filehandle association failed");

	if ( $can_client_sni ) {
	    my $host;
	    if ( exists $arg_hash->{SSL_hostname} ) {
		# explicitly given
		# can be set to undef/'' to not use extension
		$host = $arg_hash->{SSL_hostname}
	    } elsif ( $host = $arg_hash->{PeerAddr} || $arg_hash->{PeerHost} ) {
		# implicitly given
		$host =~s{:[a-zA-Z0-9_\-]+$}{};
		# should be hostname, not IPv4/6
		$host = undef if $host !~m{[a-z_]} or $host =~m{:};
	    }
	    # define SSL_CTRL_SET_TLSEXT_HOSTNAME 55
	    # define TLSEXT_NAMETYPE_host_name 0
	    if ($host) {
		$DEBUG>=2 && DEBUG("using SNI with hostname $host");
		Net::SSLeay::ctrl($ssl,55,0,$host);
	    } else {
		$DEBUG>=2 && DEBUG("not using SNI because hostname is unknown");
	    }
	} elsif ( $arg_hash->{SSL_hostname} ) {
	    return $self->error(
		"Client side SNI not supported for this openssl");
	} else {
	    $DEBUG>=2 && DEBUG("not using SNI because openssl is too old");
	}

	$arg_hash->{PeerAddr} || $self->_update_peer;
	if ( $ctx->{verify_name_ref} ) {
	    # need target name for update
	    my $host = $arg_hash->{SSL_verifycn_name}
		|| $arg_hash->{SSL_hostname};
	    if ( ! defined $host ) {
		if ( $host = $arg_hash->{PeerHost} || $arg_hash->{PeerAddr} ) {
		    $host =~s{:[a-zA-Z0-9_\-]+$}{};
		}
	    }
	    ${$ctx->{verify_name_ref}} = $host;
	}

	my $ocsp = $ctx->{ocsp_mode};
	if ( $ocsp & SSL_OCSP_NO_STAPLE ) { 
	    # don't try stapling
	} elsif ( ! $can_ocsp_staple ) {
	    croak("OCSP stapling not support") if $ocsp & SSL_OCSP_MUST_STAPLE;
	} elsif ( $ocsp & (SSL_OCSP_TRY_STAPLE|SSL_OCSP_MUST_STAPLE)) {
	    # staple by default if verification enabled
	    ${*$self}{_SSL_ocsp_verify} = undef;
	    Net::SSLeay::set_tlsext_status_type($ssl, 
		Net::SSLeay::TLSEXT_STATUSTYPE_ocsp());
	    $DEBUG>=2 && DEBUG("request OCSP stapling");
	}

	my $session = $ctx->session_cache( $arg_hash->{SSL_session_key} ?
	    ( $arg_hash->{SSL_session_key},1 ) :
	    ( $arg_hash->{PeerAddr}, $arg_hash->{PeerPort} )
	);
	Net::SSLeay::set_session($ssl, $session) if ($session);
    }

    $ssl ||= ${*$self}{'_SSL_object'};

    $SSL_ERROR = $! = undef;
    my $timeout = exists $args->{Timeout}
	? $args->{Timeout}
	: ${*$self}{io_socket_timeout}; # from IO::Socket
    if ( defined($timeout) && $timeout>0 && $self->blocking(0) ) {
	$DEBUG>=2 && DEBUG( "set socket to non-blocking to enforce timeout=$timeout" );
	# timeout was given and socket was blocking
	# enforce timeout with now non-blocking socket
    } else {
	# timeout does not apply because invalid or socket non-blocking
	$timeout = undef;
    }

    my $start = defined($timeout) && time();
    for my $dummy (1) {
	#DEBUG( 'calling ssleay::connect' );
	my $rv = Net::SSLeay::connect($ssl);
	$DEBUG>=3 && DEBUG("Net::SSLeay::connect -> $rv" );
	if ( $rv < 0 ) {
	    unless ( $self->_set_rw_error( $ssl,$rv )) {
		$self->error("SSL connect attempt failed with unknown error");
		delete ${*$self}{'_SSL_opening'};
		${*$self}{'_SSL_opened'} = -1;
		$DEBUG>=1 && DEBUG( "fatal SSL error: $SSL_ERROR" );
		return $self->fatal_ssl_error();
	    }

	    $DEBUG>=2 && DEBUG('ssl handshake in progress' );
	    # connect failed because handshake needs to be completed
	    # if socket was non-blocking or no timeout was given return with this error
	    return if ! defined($timeout);

	    # wait until socket is readable or writable
	    my $rv;
	    if ( $timeout>0 ) {
		my $vec = '';
		vec($vec,$self->fileno,1) = 1;
		$DEBUG>=2 && DEBUG( "waiting for fd to become ready: $SSL_ERROR" );
		$rv =
		    $SSL_ERROR == SSL_WANT_READ ? select( $vec,undef,undef,$timeout) :
		    $SSL_ERROR == SSL_WANT_WRITE ? select( undef,$vec,undef,$timeout) :
		    undef;
	    } else {
		$DEBUG>=2 && DEBUG("handshake failed because no more time" );
		$! = ETIMEDOUT
	    }
	    if ( ! $rv ) {
		$DEBUG>=2 && DEBUG("handshake failed because socket did not became ready" );
		# failed because of timeout, return
		$! ||= ETIMEDOUT;
		delete ${*$self}{'_SSL_opening'};
		${*$self}{'_SSL_opened'} = -1;
		$self->blocking(1); # was blocking before
		return
	    }

	    # socket is ready, try non-blocking connect again after recomputing timeout
	    $DEBUG>=2 && DEBUG("socket ready, retrying connect" );
	    my $now = time();
	    $timeout -= $now - $start;
	    $start = $now;
	    redo;

	} elsif ( $rv == 0 ) {
	    delete ${*$self}{'_SSL_opening'};
	    $DEBUG>=2 && DEBUG("connection failed - connect returned 0" );
	    $self->error("SSL connect attempt failed because of handshake problems" );
	    ${*$self}{'_SSL_opened'} = -1;
	    return $self->fatal_ssl_error();
	}
    }

    $DEBUG>=2 && DEBUG('ssl handshake done' );
    # ssl connect successful
    delete ${*$self}{'_SSL_opening'};
    ${*$self}{'_SSL_opened'}=1;
    $self->blocking(1) if defined($timeout); # was blocking before

    $ctx ||= ${*$self}{'_SSL_ctx'};

    if ( my $ocsp_result = ${*$self}{_SSL_ocsp_verify} ) {
	# got result from OCSP stapling
	if ( $ocsp_result->[0] > 0 ) {
	    $DEBUG>=3 && DEBUG("got OCSP success with stapling");
	    # successful validated
	} elsif ( $ocsp_result->[0] < 0 ) {
	    # Permanent problem with validation because certificate
	    # is either self-signed or the issuer cannot be found.
	    # Ignore here, because this will cause other errors too.
	    $DEBUG>=3 && DEBUG("got OCSP failure with stapling: %s",
		$ocsp_result->[1]);
	} else {
	    # definitly revoked
	    $DEBUG>=3 && DEBUG("got OCSP revocation with stapling: %s",
		$ocsp_result->[1]);
	    $self->error($ocsp_result->[1]);
	    return $self->fatal_ssl_error();
	}
    } elsif ( $ctx->{ocsp_mode} & SSL_OCSP_MUST_STAPLE ) {
	$self->error("did not receive the required stapled OCSP response");
	return $self->fatal_ssl_error();
    }

    if ( $ctx->has_session_cache
	and my $session = Net::SSLeay::get1_session($ssl)) {
	my $arg_hash = ${*$self}{'_SSL_arguments'};
	$arg_hash->{PeerAddr} || $self->_update_peer;
	$ctx->session_cache( $arg_hash->{SSL_session_key} ?
	    ( $arg_hash->{SSL_session_key},1 ) :
	    ( $arg_hash->{PeerAddr},$arg_hash->{PeerPort} ),
	    $session
	);
    }

    tie *{$self}, "IO::Socket::SSL::SSL_HANDLE", $self;

    return $self;
}

# called if PeerAddr is not set in ${*$self}{'_SSL_arguments'}
# this can be the case if start_SSL is called with a normal IO::Socket::INET
# so that PeerAddr|PeerPort are not set from args
sub _update_peer {
    my $self = shift;
    my $arg_hash = ${*$self}{'_SSL_arguments'};
    eval {
	my $sockaddr = getpeername( $self );
	my $af = sockaddr_family($sockaddr);
	if( CAN_IPV6 && $af == AF_INET6 ) {
	    my ($host, $port) = getnameinfo($sockaddr,
		NI_NUMERICHOST | NI_NUMERICSERV);
	    $arg_hash->{PeerAddr} = $host;
	    $arg_hash->{PeerPort} = $port;
	} else {
	    my ($port,$addr) = sockaddr_in( $sockaddr);
	    $arg_hash->{PeerAddr} = inet_ntoa( $addr );
	    $arg_hash->{PeerPort} = $port;
	}
    }
}

#Call to accept occurs when a new client connects to a server using
#IO::Socket::SSL
sub accept {
    my $self = shift || return _invalid_object();
    my $class = shift || 'IO::Socket::SSL';

    my $socket = ${*$self}{'_SSL_opening'};
    if ( ! $socket ) {
	# underlying socket not done
	$DEBUG>=2 && DEBUG('no socket yet' );
	$socket = $self->SUPER::accept($class) || return;
	$DEBUG>=2 && DEBUG('accept created normal socket '.$socket );
    }

    $self->accept_SSL($socket) || return;
    $DEBUG>=2 && DEBUG('accept_SSL ok' );

    return wantarray ? ($socket, getpeername($socket) ) : $socket;
}

sub accept_SSL {
    my $self = shift;
    my $socket = ( @_ && UNIVERSAL::isa( $_[0], 'IO::Handle' )) ? shift : $self;
    my $args = @_>1 ? {@_}: $_[0]||{};

    my $ssl;
    if ( ! ${*$self}{'_SSL_opening'} ) {
	$DEBUG>=2 && DEBUG('starting sslifying' );
	${*$self}{'_SSL_opening'} = $socket;
	my $arg_hash = ${*$self}{'_SSL_arguments'};
	${*$socket}{'_SSL_arguments'} = { %$arg_hash, SSL_server => 0 };
	my $ctx = ${*$socket}{'_SSL_ctx'} = ${*$self}{'_SSL_ctx'};

	my $fileno = ${*$socket}{'_SSL_fileno'} = fileno($socket);
	return $socket->error("Socket has no fileno") unless (defined $fileno);

	$ssl = ${*$socket}{'_SSL_object'} = Net::SSLeay::new($ctx->{context})
	    || return $socket->error("SSL structure creation failed");
	$CREATED_IN_THIS_THREAD{$ssl} = 1;
	$SSL_OBJECT{$ssl} = [$socket,1];
	weaken($SSL_OBJECT{$ssl}[0]);

	Net::SSLeay::set_fd($ssl, $fileno)
	    || return $socket->error("SSL filehandle association failed");
    }

    $ssl ||= ${*$socket}{'_SSL_object'};

    $SSL_ERROR = $! = undef;
    #$DEBUG>=2 && DEBUG('calling ssleay::accept' );

    my $timeout = exists $args->{Timeout}
	? $args->{Timeout}
	: ${*$self}{io_socket_timeout}; # from IO::Socket
    if ( defined($timeout) && $timeout>0 && $socket->blocking(0) ) {
	# timeout was given and socket was blocking
	# enforce timeout with now non-blocking socket
    } else {
	# timeout does not apply because invalid or socket non-blocking
	$timeout = undef;
    }

    my $start = defined($timeout) && time();
    for my $dummy (1) {
	my $rv = Net::SSLeay::accept($ssl);
	$DEBUG>=3 && DEBUG( "Net::SSLeay::accept -> $rv" );
	if ( $rv < 0 ) {
	    unless ( $socket->_set_rw_error( $ssl,$rv )) {
		$socket->error("SSL accept attempt failed with unknown error");
		delete ${*$self}{'_SSL_opening'};
		${*$socket}{'_SSL_opened'} = -1;
		return $socket->fatal_ssl_error();
	    }

	    # accept failed because handshake needs to be completed
	    # if socket was non-blocking or no timeout was given return with this error
	    return if ! defined($timeout);

	    # wait until socket is readable or writable
	    my $rv;
	    if ( $timeout>0 ) {
		my $vec = '';
		vec($vec,$socket->fileno,1) = 1;
		$rv =
		    $SSL_ERROR == SSL_WANT_READ ? select( $vec,undef,undef,$timeout) :
		    $SSL_ERROR == SSL_WANT_WRITE ? select( undef,$vec,undef,$timeout) :
		    undef;
	    } else {
		$! = ETIMEDOUT
	    }
	    if ( ! $rv ) {
		# failed because of timeout, return
		$! ||= ETIMEDOUT;
		delete ${*$self}{'_SSL_opening'};
		${*$socket}{'_SSL_opened'} = -1;
		$socket->blocking(1); # was blocking before
		return
	    }

	    # socket is ready, try non-blocking accept again after recomputing timeout
	    my $now = time();
	    $timeout -= $now - $start;
	    $start = $now;
	    redo;

	} elsif ( $rv == 0 ) {
	    $socket->error("SSL connect accept failed because of handshake problems" );
	    delete ${*$self}{'_SSL_opening'};
	    ${*$socket}{'_SSL_opened'} = -1;
	    return $socket->fatal_ssl_error();
	}
    }

    $DEBUG>=2 && DEBUG('handshake done, socket ready' );
    # socket opened
    delete ${*$self}{'_SSL_opening'};
    ${*$socket}{'_SSL_opened'} = 1;
    $socket->blocking(1) if defined($timeout); # was blocking before

    tie *{$socket}, "IO::Socket::SSL::SSL_HANDLE", $socket;

    return $socket;
}


####### I/O subroutines ########################

sub generic_read {
    my ($self, $read_func, undef, $length, $offset) = @_;
    my $ssl = $self->_get_ssl_object || return;
    my $buffer=\$_[2];

    $SSL_ERROR = $! = undef;
    my $data = $read_func->($ssl, $length);
    if ( !defined($data)) {
	$self->_set_rw_error( $ssl,-1 ) || $self->error("SSL read error");
	return;
    }

    $length = length($data);
    $$buffer = '' if !defined $$buffer;
    $offset ||= 0;
    if ($offset>length($$buffer)) {
	$$buffer.="\0" x ($offset-length($$buffer));  #mimic behavior of read
    }

    substr($$buffer, $offset, length($$buffer), $data);
    return $length;
}

sub read {
    my $self = shift;
    return $self->generic_read(
	$self->blocking ? \&Net::SSLeay::ssl_read_all : \&Net::SSLeay::read,
	@_
    );
}

# contrary to the behavior of read sysread can read partial data
sub sysread {
    my $self = shift;
    return $self->generic_read( \&Net::SSLeay::read, @_ );
}

sub peek {
    my $self = shift;
    return $self->generic_read(\&Net::SSLeay::peek, @_);
}


sub generic_write {
    my ($self, $write_all, undef, $length, $offset) = @_;

    my $ssl = $self->_get_ssl_object || return;
    my $buffer = \$_[2];

    my $buf_len = length($$buffer);
    $length ||= $buf_len;
    $offset ||= 0;
    return $self->error("Invalid offset for SSL write") if ($offset>$buf_len);
    return 0 if ($offset == $buf_len);

    $SSL_ERROR = $! = undef;
    my $written;
    if ( $write_all ) {
	my $data = $length < $buf_len-$offset ? substr($$buffer, $offset, $length) : $$buffer;
	($written, my $errs) = Net::SSLeay::ssl_write_all($ssl, $data);
	# ssl_write_all returns number of bytes written
	$written = undef if ! $written && $errs;
    } else {
	$written = Net::SSLeay::write_partial( $ssl,$offset,$length,$$buffer );
	# write_partial does SSL_write which returns -1 on error
	$written = undef if $written < 0;
    }
    if ( !defined($written) ) {
	$self->_set_rw_error( $ssl,-1 )
	    || $self->error("SSL write error");
	return;
    }

    return $written;
}

# if socket is blocking write() should return only on error or
# if all data are written
sub write {
    my $self = shift;
    return $self->generic_write( scalar($self->blocking),@_ );
}

# contrary to write syswrite() returns already if only
# a part of the data is written
sub syswrite {
    my $self = shift;
    return $self->generic_write( 0,@_ );
}

sub print {
    my $self = shift;
    my $string = join(($, or ''), @_, ($\ or ''));
    return $self->write( $string );
}

sub printf {
    my ($self,$format) = (shift,shift);
    return $self->write(sprintf($format, @_));
}

sub getc {
    my ($self, $buffer) = (shift, undef);
    return $buffer if $self->read($buffer, 1, 0);
}

sub readline {
    my $self = shift;

    if ( not defined $/ or wantarray) {
	# read all and split

	my $buf = '';
	while (1) {
	    my $rv = $self->sysread($buf,2**16,length($buf));
	    if ( ! defined $rv ) {
		next if $!{EINTR};                     # retry
		last if $!{EAGAIN} || $!{EWOULDBLOCK}; # use everything so far
		return;                                # return error
	    } elsif ( ! $rv ) {
		last
	    }
	}

	if ( ! defined $/ ) {
	    return $buf
	} elsif ( ref($/)) {
	    my $size = ${$/};
	    die "bad value in ref \$/: $size" unless $size>0;
	    return $buf=~m{\G(.{1,$size})}g;
	} elsif ( $/ eq '' ) {
	    return $buf =~m{\G(.*\n\n+|.+)}g;
	} else {
	    return $buf =~m{\G(.*$/|.+)}g;
	}
    }

    # read only one line
    if ( ref($/) ) {
	my $size = ${$/};
	# read record of $size bytes
	die "bad value in ref \$/: $size" unless $size>0;
	my $buf = '';
	while ( $size>length($buf)) {
	    my $rv = $self->sysread($buf,$size-length($buf),length($buf));
	    if ( ! defined $rv ) {
		next if $!{EINTR};                     # retry
		last if $!{EAGAIN} || $!{EWOULDBLOCK}; # use everything so far
		return;                                # return error
	    } elsif ( ! $rv ) {
		last
	    }
	}
	return $buf;
    }

    my ($delim0,$delim1) = $/ eq '' ? ("\n\n","\n"):($/,'');

    # find first occurrence of $delim0 followed by as much as possible $delim1
    my $buf = '';
    my $eod = 0;  # pointer into $buf after $delim0 $delim1*
    my $ssl = $self->_get_ssl_object or return;
    while (1) {

	# wait until we have more data or eof
	my $poke = Net::SSLeay::peek($ssl,1);
	if ( ! defined $poke or $poke eq '' ) {
	    next if $!{EINTR};
	}

	my $skip = 0;

	# peek into available data w/o reading
	my $pending = Net::SSLeay::pending($ssl);
	if ( $pending and
	    ( my $pb = Net::SSLeay::peek( $ssl,$pending )) ne '' ) {
	    $buf .= $pb
	} else {
	    return $buf eq '' ? ():$buf;
	};
	if ( !$eod ) {
	    my $pos = index( $buf,$delim0 );
	    if ( $pos<0 ) {
		$skip = $pending
	    } else {
		$eod = $pos + length($delim0); # pos after delim0
	    }
	}

	if ( $eod ) {
	    if ( $delim1 ne '' ) {
		# delim0 found, check for as much delim1 as possible
		while ( index( $buf,$delim1,$eod ) == $eod ) {
		    $eod+= length($delim1);
		}
	    }
	    $skip = $pending - ( length($buf) - $eod );
	}

	# remove data from $self which I already have in buf
	while ( $skip>0 ) {
	    if ($self->sysread(my $p,$skip,0)) {
		$skip -= length($p);
		next;
	    }
	    $!{EINTR} or last;
	}

	if ( $eod and ( $delim1 eq '' or $eod < length($buf))) {
	    # delim0 found and there can be no more delim1 pending
	    last
	}
    }
    return substr($buf,0,$eod);
}

sub close {
    my $self = shift || return _invalid_object();
    my $close_args = (ref($_[0]) eq 'HASH') ? $_[0] : {@_};

    return if ! $self->stop_SSL(
	SSL_fast_shutdown => 1,
	%$close_args,
	_SSL_ioclass_downgrade => 0,
    );

    if ( ! $close_args->{_SSL_in_DESTROY} ) {
	untie( *$self );
	undef ${*$self}{_SSL_fileno};
	return $self->SUPER::close;
    }
    return 1;
}

sub stop_SSL {
    my $self = shift || return _invalid_object();
    my $stop_args = (ref($_[0]) eq 'HASH') ? $_[0] : {@_};
    $stop_args->{SSL_no_shutdown} = 1 if ! ${*$self}{_SSL_opened};

    if (my $ssl = ${*$self}{'_SSL_object'}) {
	if ( ! $stop_args->{SSL_no_shutdown} ) {
	    my $status = Net::SSLeay::get_shutdown($ssl);

	    my $timeout = 
		not($self->blocking) ? undef :
		exists $stop_args->{Timeout} ? $stop_args->{Timeout} : 
		${*$self}{io_socket_timeout}; # from IO::Socket
	    if ($timeout) {
		$self->blocking(0);
		$timeout += time();
	    }

	    while (1) {
		if ( $status & SSL_SENT_SHUTDOWN and
		    # don't care for received if fast shutdown
		    $status & SSL_RECEIVED_SHUTDOWN
			|| $stop_args->{SSL_fast_shutdown}) {
		    # shutdown complete
		    last;
		}

		# initiate or complete shutdown
		local $SIG{PIPE} = 'IGNORE';
		my $rv = Net::SSLeay::shutdown($ssl);
		if ( $rv < 0 ) {
		    # non-blocking socket?
		    if ( ! $timeout ) {
			$self->_set_rw_error( $ssl,$rv );
			# need to try again
			return;
		    }
	
		    # don't use _set_rw_error so that existing error does
		    # not get cleared
		    my $wait = $timeout - time();
		    last if $wait<=0;
		    vec(my $vec = '',fileno($self),1) = 1;
		    my $err = Net::SSLeay::get_error($ssl,$rv);
		    if ( $err == Net::SSLeay::ERROR_WANT_READ()) {
			select($vec,undef,undef,$wait)
		    } elsif ( $err == Net::SSLeay::ERROR_WANT_READ()) {
			select(undef,$vec,undef,$wait)
		    } else {
			last;
		    }
		}

		$status |= SSL_SENT_SHUTDOWN;
		$status |= SSL_RECEIVED_SHUTDOWN if $rv>0;
	    }
	    $self->blocking(1) if $timeout;
	}
	Net::SSLeay::free($ssl);
	delete ${*$self}{_SSL_object};
    }

    if ($stop_args->{'SSL_ctx_free'}) {
	my $ctx = delete ${*$self}{'_SSL_ctx'};
	$ctx && $ctx->DESTROY();
    }

    if (my $cert = delete ${*$self}{'_SSL_certificate'}) {
	Net::SSLeay::X509_free($cert);
    }

    ${*$self}{'_SSL_opened'} = 0;

    if ( ! $stop_args->{_SSL_in_DESTROY} ) {

	my $downgrade = $stop_args->{_SSL_ioclass_downgrade};
	if ( $downgrade || ! defined $downgrade ) {
	    # rebless to original class from start_SSL
	    if ( my $orig_class = delete ${*$self}{'_SSL_ioclass_upgraded'} ) {
		bless $self,$orig_class;
		untie(*$self);
		# FIXME: if original class was tied too we need to restore the tie
	    }
	    # remove all _SSL related from *$self
	    my @sslkeys = grep { m{^_?SSL_} } keys %{*$self};
	    delete @{*$self}{@sslkeys} if @sslkeys;
	}
    }
    return 1;
}


sub fileno {
    my $self = shift;
    my $fn = ${*$self}{'_SSL_fileno'};
	return defined($fn) ? $fn : $self->SUPER::fileno();
}


####### IO::Socket::SSL specific functions #######
# _get_ssl_object is for internal use ONLY!
sub _get_ssl_object {
    my $self = shift;
    my $ssl = ${*$self}{'_SSL_object'};
    return IO::Socket::SSL->error("Undefined SSL object") unless($ssl);
    return $ssl;
}

# _get_ctx_object is for internal use ONLY!
sub _get_ctx_object {
    my $self = shift;
    my $ctx_object = ${*$self}{_SSL_ctx};
    return $ctx_object && $ctx_object->{context};
}

# default error for undefined arguments
sub _invalid_object {
    return IO::Socket::SSL->error("Undefined IO::Socket::SSL object");
}


sub pending {
    my $ssl = shift()->_get_ssl_object || return;
    return Net::SSLeay::pending($ssl);
}

sub start_SSL {
    my ($class,$socket) = (shift,shift);
    return $class->error("Not a socket") unless(ref($socket));
    my $arg_hash = (ref($_[0]) eq 'HASH') ? $_[0] : {@_};
    my %to = exists $arg_hash->{Timeout} ? ( Timeout => delete $arg_hash->{Timeout} ) :();
    my $original_class = ref($socket);
    my $original_fileno = (UNIVERSAL::can($socket, "fileno"))
	? $socket->fileno : CORE::fileno($socket);
    return $class->error("Socket has no fileno") unless defined $original_fileno;

    bless $socket, $class;
    $socket->configure_SSL($arg_hash) or bless($socket, $original_class) && return;

    ${*$socket}{'_SSL_fileno'} = $original_fileno;
    ${*$socket}{'_SSL_ioclass_upgraded'} = $original_class;

    my $start_handshake = $arg_hash->{SSL_startHandshake};
    if ( ! defined($start_handshake) || $start_handshake ) {
	# if we have no callback force blocking mode
	$DEBUG>=2 && DEBUG( "start handshake" );
	my $was_blocking = $socket->blocking(1);
	my $result = ${*$socket}{'_SSL_arguments'}{SSL_server}
	    ? $socket->accept_SSL(%to)
	    : $socket->connect_SSL(%to);
	if ( $result ) {
	    $socket->blocking(0) if ! $was_blocking;
	    return $socket;
	} else {
	    # upgrade to SSL failed, downgrade socket to original class
	    if ( $original_class ) {
		bless($socket,$original_class);
		$socket->blocking(0) if ! $was_blocking
		    && $socket->can('blocking');
	    }
	    return;
	}
    } else {
	$DEBUG>=2 && DEBUG( "dont start handshake: $socket" );
	return $socket; # just return upgraded socket
    }

}

sub new_from_fd {
    my ($class, $fd) = (shift,shift);
    # Check for accidental inclusion of MODE in the argument list
    if (length($_[0]) < 4) {
	(my $mode = $_[0]) =~ tr/+<>//d;
	shift unless length($mode);
    }
    my $handle = $ISA[0]->new_from_fd($fd, '+<')
	|| return($class->error("Could not create socket from file descriptor."));

    # Annoying workaround for Perl 5.6.1 and below:
    $handle = $ISA[0]->new_from_fd($handle, '+<');

    return $class->start_SSL($handle, @_);
}


sub dump_peer_certificate {
    my $ssl = shift()->_get_ssl_object || return;
    return Net::SSLeay::dump_peer_certificate($ssl);
}

if ( defined &Net::SSLeay::get_peer_cert_chain
    && $Net::SSLeay::VERSION >= 1.58 ) {
    *peer_certificates = sub {
	my $self = shift;
	my $ssl = $self->_get_ssl_object || return;
	my @chain = Net::SSLeay::get_peer_cert_chain($ssl);
	@chain = () if @chain && !$self->peer_certificate; # work around #96013
	if ( ${*$self}{_SSL_arguments}{SSL_server} ) {
	    # in the client case the chain contains the peer certificate,
	    # in the server case not
	    # this one has an increased reference counter, the other not
	    if ( my $peer = Net::SSLeay::get_peer_certificate($ssl)) {
		Net::SSLeay::X509_free($peer);
		unshift @chain, $peer;
	    }
	}
	return @chain;
	    
    }
} else {
    *peer_certificates = sub {
	die "peer_certificates needs Net::SSLeay>=1.58";
    }
}

{
    my %dispatcher = (
	issuer =>  sub { Net::SSLeay::X509_NAME_oneline( Net::SSLeay::X509_get_issuer_name( shift )) },
	subject => sub { Net::SSLeay::X509_NAME_oneline( Net::SSLeay::X509_get_subject_name( shift )) },
	commonName => sub {
	    my $cn = Net::SSLeay::X509_NAME_get_text_by_NID(
		Net::SSLeay::X509_get_subject_name( shift ), NID_CommonName);
	    $cn;
	},
	subjectAltNames => sub { Net::SSLeay::X509_get_subjectAltNames( shift ) },
    );

    # alternative names
    $dispatcher{authority} = $dispatcher{issuer};
    $dispatcher{owner}     = $dispatcher{subject};
    $dispatcher{cn}        = $dispatcher{commonName};

    sub peer_certificate {
	my ($self, $field) = @_;
	my $ssl = $self->_get_ssl_object or return;

	my $cert = ${*$self}{_SSL_certificate}
	    ||= Net::SSLeay::get_peer_certificate($ssl)
	    or return $self->error("Could not retrieve peer certificate");

	if ($field) {
	    my $sub = $dispatcher{$field} or croak
		"invalid argument for peer_certificate, valid are: ".join( " ",keys %dispatcher ).
		"\nMaybe you need to upgrade your Net::SSLeay";
	    return $sub->($cert);
	} else {
	    return $cert
	}
    }

    # known schemes, possible attributes are:
    #  - wildcards_in_alt (0, 'full_label', 'anywhere')
    #  - wildcards_in_cn (0, 'full_label', 'anywhere')
    #  - check_cn (0, 'always', 'when_only')
    # unfortunately there are a lot of different schemes used, see RFC 6125 for a
    # summary, which references all of the following except RFC4217/ftp

    my %scheme = (
	none => {}, # do not check
	# default set is a superset of all the others and thus worse than a more
	# specific set, but much better than not verifying name at all
	default => {
	    wildcards_in_cn  => 'anywhere',
	    wildcards_in_alt => 'anywhere',
	    check_cn         => 'always',
	    ip_in_cn         => 1,
	},
    );

    for(qw(
	rfc2818
	rfc3920 xmpp
	rfc4217 ftp
    )) {
	$scheme{$_} = {
	    wildcards_in_cn  => 'anywhere',
	    wildcards_in_alt => 'anywhere',
	    check_cn         => 'when_only',
	}
    }

    for(qw(www http)) {
	$scheme{$_} = {
	    wildcards_in_cn  => 'anywhere',
	    wildcards_in_alt => 'anywhere',
	    check_cn         => 'when_only',
	    ip_in_cn         => 4,
	}
    }

    for(qw(
	rfc4513 ldap
    )) {
	$scheme{$_} = {
	    wildcards_in_cn  => 0,
	    wildcards_in_alt => 'full_label',
	    check_cn         => 'always',
	};
    }

    for(qw(
	rfc2595 smtp
	rfc4642 imap pop3 acap
	rfc5539 nntp
	rfc5538 netconf
	rfc5425 syslog
	rfc5953 snmp
    )) {
	$scheme{$_} = {
	    wildcards_in_cn  => 'full_label',
	    wildcards_in_alt => 'full_label',
	    check_cn         => 'always'
	};
    }
    for(qw(
	rfc5971 gist
    )) {
	$scheme{$_} = {
	    wildcards_in_cn  => 'full_label',
	    wildcards_in_alt => 'full_label',
	    check_cn         => 'when_only',
	};
    }

    for(qw(
	rfc5922 sip
    )) {
	$scheme{$_} = {
	    wildcards_in_cn  => 0,
	    wildcards_in_alt => 0,
	    check_cn         => 'always',
	};
    }


    # function to verify the hostname
    #
    # as every application protocol has its own rules to do this
    # we provide some default rules as well as a user-defined
    # callback

    sub verify_hostname_of_cert {
	my $identity = shift;
	my $cert = shift;
	my $scheme = shift || 'default';
	my $publicsuffix = shift;
	if ( ! ref($scheme) ) {
	    $DEBUG>=3 && DEBUG( "scheme=$scheme cert=$cert" );
	    $scheme = $scheme{$scheme} or croak "scheme $scheme not defined";
	}

	return 1 if ! %$scheme; # 'none'
	$identity =~s{\.+$}{}; # ignore absolutism

	# get data from certificate
	my $commonName = $dispatcher{cn}->($cert);
	my @altNames = $dispatcher{subjectAltNames}->($cert);
	$DEBUG>=3 && DEBUG("identity=$identity cn=$commonName alt=@altNames" );

	if ( my $sub = $scheme->{callback} ) {
	    # use custom callback
	    return $sub->($identity,$commonName,@altNames);
	}

	# is the given hostname an IP address? Then we have to convert to network byte order [RFC791][RFC2460]

	my $ipn;
	if ( CAN_IPV6 and $identity =~m{:} ) {
	    # no IPv4 or hostname have ':'  in it, try IPv6.
	    $ipn = inet_pton(AF_INET6,$identity) or return; # invalid name
	} elsif ( $identity =~m{^\d[\d\.]*\.\d+$} ) {
	    $ipn = inet_aton($identity) or return; # invalid name
	} else {
	    # assume hostname, check for umlauts etc
	    if ( $identity =~m{[^a-zA-Z0-9_.\-]} ) {
		$identity =~m{\0} and return; # $identity has \\0 byte
		$identity = idn_to_ascii($identity) 
		    or return; # conversation to IDNA failed
		$identity =~m{[^a-zA-Z0-9_.\-]}
		    and return; # still junk inside
	    }
	}

	# do the actual verification
	my $check_name = sub {
	    my ($name,$identity,$wtyp,$publicsuffix) = @_;
	    $name =~s{\.+$}{}; # ignore absolutism
	    $name eq '' and return;
	    $wtyp ||= '';
	    my $pattern;
	    ### IMPORTANT!
	    # We accept only a single wildcard and only for a single part of the FQDN
	    # e.g *.example.org does match www.example.org but not bla.www.example.org
	    # The RFCs are in this regard unspecific but we don't want to have to
	    # deal with certificates like *.com, *.co.uk or even *
	    # see also http://nils.toedtmann.net/pub/subjectAltName.txt .
	    # Also, we fall back to full_label matches if the identity is an IDNA
	    # name, see RFC6125 and the discussion at
	    # http://bugs.python.org/issue17997#msg194950
	    if ( $wtyp eq 'anywhere' and $name =~m{^([a-zA-Z0-9_\-]*)\*(.+)} ) {
		return if $1 ne '' and substr($identity,0,4) eq 'xn--'; # IDNA
		$pattern = qr{^\Q$1\E[a-zA-Z0-9_\-]+\Q$2\E$}i;
	    } elsif ( $wtyp =~ m{^(?:full_label|leftmost)$} 
		and $name =~m{^\*(\..+)$} ) {
		$pattern = qr{^[a-zA-Z0-9_\-]+\Q$1\E$}i;
	    } else {
		return lc($identity) eq lc($name);
	    }
	    if ( $identity =~ $pattern ) {
		$publicsuffix = IO::Socket::SSL::PublicSuffix->default
		    if ! defined $publicsuffix;
		return 1 if $publicsuffix eq '';
		my @labels = split( m{\.+}, $identity );
		my $tld = $publicsuffix->public_suffix(\@labels,+1);
		return 1 if @labels > ( $tld ? 0+@$tld : 1 );
	    }
	    return;
	};


	my $alt_dnsNames = 0;
	while (@altNames) {
	    my ($type, $name) = splice (@altNames, 0, 2);
	    if ( $ipn and $type == GEN_IPADD ) {
		# exact match needed for IP
		# $name is already packed format (inet_xton)
		return 1 if $ipn eq $name;

	    } elsif ( ! $ipn and $type == GEN_DNS ) {
		$name =~s/\s+$//; $name =~s/^\s+//;
		$alt_dnsNames++;
		$check_name->($name,$identity,$scheme->{wildcards_in_alt},$publicsuffix)
		    and return 1;
	    }
	}

	if ( $scheme->{check_cn} eq 'always' or
	    $scheme->{check_cn} eq 'when_only' and !$alt_dnsNames ) {
	    if ( ! $ipn ) {
		$check_name->($commonName,$identity,$scheme->{wildcards_in_cn},$publicsuffix)
		    and return 1;
	    } elsif ( $scheme->{ip_in_cn} ) {
		if ( $identity eq $commonName ) {
		    return 1 if 
			$scheme->{ip_in_cn} == 4 ? length($ipn) == 4 :
			$scheme->{ip_in_cn} == 6 ? length($ipn) == 8 :
			1;
		}
	    }
	}

	return 0; # no match
    }
}

sub verify_hostname {
    my $self = shift;
    my $host = shift;
    my $cert = $self->peer_certificate;
    return verify_hostname_of_cert( $host,$cert,@_ );
}


sub get_servername {
    my $self = shift;
    return ${*$self}{_SSL_servername} ||= do {
	my $ssl = $self->_get_ssl_object or return;
	Net::SSLeay::get_servername($ssl);
    };
}

sub get_fingerprint_bin {
    my $cert = shift()->peer_certificate;
    return Net::SSLeay::X509_digest($cert, $algo2digest->(shift() || 'sha256'));
}

sub get_fingerprint {
    my ($self,$algo) = @_;
    $algo ||= 'sha256';
    my $fp = get_fingerprint_bin($self,$algo) or return;
    return $algo.'$'.unpack('H*',$fp);
}

sub get_cipher {
    my $ssl = shift()->_get_ssl_object || return;
    return Net::SSLeay::get_cipher($ssl);
}

sub get_sslversion {
    my $ssl = shift()->_get_ssl_object || return;
    my $version = Net::SSLeay::version($ssl) or return;
    return
	$version == 0x0303 ? 'TLSv1_2' :
	$version == 0x0302 ? 'TLSv1_1' :
	$version == 0x0301 ? 'TLSv1'   :
	$version == 0x0300 ? 'SSLv3'   :
	$version == 0x0002 ? 'SSLv2'   :
	$version == 0xfeff ? 'DTLS1'   :
	undef;
}

sub get_sslversion_int {
    my $ssl = shift()->_get_ssl_object || return;
    return Net::SSLeay::version($ssl);
}

if ($can_ocsp) {
    no warnings 'once';
    *ocsp_resolver = sub {
	my $self = shift;
	my $ssl = $self->_get_ssl_object || return;
	my $ctx = ${*$self}{_SSL_ctx};
	return IO::Socket::SSL::OCSP_Resolver->new(
	    $ssl,
	    $ctx->{ocsp_cache} ||= IO::Socket::SSL::OCSP_Cache->new,
	    $ctx->{ocsp_mode} & SSL_OCSP_FAIL_HARD,
	    @_ ? \@_ : 
		$ctx->{ocsp_mode} & SSL_OCSP_FULL_CHAIN ? [ $self->peer_certificates ]: 
		[ $self->peer_certificate ]
	);
    };
}

sub errstr {
    my $self = shift;
    return (ref($self) ? ${*$self}{'_SSL_last_err'} : $SSL_ERROR) || '';
}

sub fatal_ssl_error {
    my $self = shift;
    my $error_trap = ${*$self}{'_SSL_arguments'}->{'SSL_error_trap'};
    $@ = $self->errstr;
    if (defined $error_trap and ref($error_trap) eq 'CODE') {
	$error_trap->($self, $self->errstr()."\n".$self->get_ssleay_error());
    } elsif ( ${*$self}{'_SSL_ioclass_upgraded'} ) {
	# downgrade only
	$self->stop_SSL;
    } else {
	# kill socket
	$self->close
    }
    return;
}

sub get_ssleay_error {
    #Net::SSLeay will print out the errors itself unless we explicitly
    #undefine $Net::SSLeay::trace while running print_errs()
    local $Net::SSLeay::trace;
    return Net::SSLeay::print_errs('SSL error: ') || '';
}

sub error {
    my ($self, $error, $destroy_socket) = @_;
    my @err;
    while ( my $err = Net::SSLeay::ERR_get_error()) {
	push @err, Net::SSLeay::ERR_error_string($err);
	$DEBUG>=2 && DEBUG( $error."\n".$self->get_ssleay_error());
    }
    # if no new error occurred report last again
    if ( ! @err and my $err =
	ref($self) ? ${*$self}{'_SSL_last_err'} : $SSL_ERROR ) {
	push @err,$err;
    }
    $error .= ' '.join(' ',@err) if @err;
    if ($error) {
	$SSL_ERROR = dualvar( -1, $error );
	${*$self}{'_SSL_last_err'} = $SSL_ERROR if (ref($self));
    }
    return;
}

sub can_client_sni { return $can_client_sni }
sub can_server_sni { return $can_server_sni }
sub can_npn        { return $can_npn }
sub can_ecdh       { return $can_ecdh }
sub can_ipv6       { return CAN_IPV6 }
sub can_ocsp       { return $can_ocsp }

sub DESTROY {
    my $self = shift or return;
    my $ssl = ${*$self}{_SSL_object} or return;
    delete $SSL_OBJECT{$ssl};
    if ($CREATED_IN_THIS_THREAD{$ssl}) {
	$self->close(_SSL_in_DESTROY => 1, SSL_no_shutdown => 1)
	    if ${*$self}{'_SSL_opened'};
	delete(${*$self}{'_SSL_ctx'});
    }
}


#######Extra Backwards Compatibility Functionality#######
sub socket_to_SSL { IO::Socket::SSL->start_SSL(@_); }
sub socketToSSL { IO::Socket::SSL->start_SSL(@_); }
sub kill_socket { shift->close }

sub issuer_name { return(shift()->peer_certificate("issuer")) }
sub subject_name { return(shift()->peer_certificate("subject")) }
sub get_peer_certificate { return shift() }

sub context_init {
    return($GLOBAL_SSL_ARGS = (ref($_[0]) eq 'HASH') ? $_[0] : {@_});
}

sub set_default_context {
    $GLOBAL_SSL_ARGS->{'SSL_reuse_ctx'} = shift;
}

sub set_default_session_cache {
    $GLOBAL_SSL_ARGS->{SSL_session_cache} = shift;
}


{
    my $set_defaults = sub {
	my $args = shift;
	for(my $i=0;$i<@$args;$i+=2 ) {
	    my ($k,$v) = @{$args}[$i,$i+1];
	    if ( $k =~m{^SSL_} ) {
		$_->{$k} = $v for(@_);
	    } elsif ( $k =~m{^(name|scheme)$} ) {
		$_->{"SSL_verifycn_$k"} = $v for (@_);
	    } elsif ( $k =~m{^(callback|mode)$} ) {
		$_->{"SSL_verify_$k"} = $v for(@_);
	    } else {
		$_->{"SSL_$k"} = $v for(@_);
	    }
	}
    };
    sub set_defaults {
	my %args = @_;
	$set_defaults->(\@_,
	    $GLOBAL_SSL_ARGS,
	    $GLOBAL_SSL_CLIENT_ARGS,
	    $GLOBAL_SSL_SERVER_ARGS
	);
    }
    { # deprecated API
	no warnings;
	*set_ctx_defaults = \&set_defaults;
    }
    sub set_client_defaults {
	my %args = @_;
	$set_defaults->(\@_, $GLOBAL_SSL_CLIENT_ARGS );
    }
    sub set_server_defaults {
	my %args = @_;
	$set_defaults->(\@_, $GLOBAL_SSL_SERVER_ARGS );
    }
}

sub set_args_filter_hack {
    my $sub = shift;
    if ( ref $sub ) {
	$FILTER_SSL_ARGS = $sub;
    } elsif ( $sub eq 'use_defaults' ) {
	# override args with defaults
	$FILTER_SSL_ARGS = sub {
	    my ($is_server,$args) = @_;
	    %$args = ( %$args, $is_server
		? ( %DEFAULT_SSL_SERVER_ARGS, %$GLOBAL_SSL_SERVER_ARGS )
		: ( %DEFAULT_SSL_CLIENT_ARGS, %$GLOBAL_SSL_CLIENT_ARGS )
	    );
	}
    }
}

sub next_proto_negotiated {
    my $self = shift;
    return $self->error("NPN not supported in Net::SSLeay") if ! $can_npn;
    my $ssl = $self->_get_ssl_object || return;
    return Net::SSLeay::P_next_proto_negotiated($ssl);
}

sub opened {
    my $self = shift;
    return IO::Handle::opened($self) && ${*$self}{'_SSL_opened'};
}

sub opening {
    my $self = shift;
    return ${*$self}{'_SSL_opening'};
}

sub want_read  { shift->errstr == SSL_WANT_READ }
sub want_write { shift->errstr == SSL_WANT_WRITE }


#Redundant IO::Handle functionality
sub getline { return(scalar shift->readline()) }
sub getlines {
    return(shift->readline()) if wantarray();
    croak("Use of getlines() not allowed in scalar context");
}

#Useless IO::Handle functionality
sub truncate { croak("Use of truncate() not allowed with SSL") }
sub stat     { croak("Use of stat() not allowed with SSL" ) }
sub setbuf   { croak("Use of setbuf() not allowed with SSL" ) }
sub setvbuf  { croak("Use of setvbuf() not allowed with SSL" ) }
sub fdopen   { croak("Use of fdopen() not allowed with SSL" ) }

#Unsupported socket functionality
sub ungetc { croak("Use of ungetc() not implemented in IO::Socket::SSL") }
sub send   { croak("Use of send() not implemented in IO::Socket::SSL; use print/printf/syswrite instead") }
sub recv   { croak("Use of recv() not implemented in IO::Socket::SSL; use read/sysread instead") }

package IO::Socket::SSL::SSL_HANDLE;
use strict;
use Errno 'EBADF';
*weaken = *IO::Socket::SSL::weaken;

sub TIEHANDLE {
    my ($class, $handle) = @_;
    weaken($handle);
    bless \$handle, $class;
}

sub READ     { ${shift()}->sysread(@_) }
sub READLINE { ${shift()}->readline(@_) }
sub GETC     { ${shift()}->getc(@_) }

sub PRINT    { ${shift()}->print(@_) }
sub PRINTF   { ${shift()}->printf(@_) }
sub WRITE    { ${shift()}->syswrite(@_) }

sub FILENO   { ${shift()}->fileno(@_) }

sub TELL     { $! = EBADF; return -1 }
sub BINMODE  { return 0 }  # not perfect, but better than not implementing the method

sub CLOSE {                          #<---- Do not change this function!
    my $ssl = ${$_[0]};
    local @_;
    $ssl->close();
}


package IO::Socket::SSL::SSL_Context;
use Carp;
use strict;

my %CTX_CREATED_IN_THIS_THREAD;
*DEBUG = *IO::Socket::SSL::DEBUG;

use constant SSL_MODE_ENABLE_PARTIAL_WRITE => 1;
use constant SSL_MODE_ACCEPT_MOVING_WRITE_BUFFER => 2;

use constant FILETYPE_PEM => Net::SSLeay::FILETYPE_PEM();
use constant FILETYPE_ASN1 => Net::SSLeay::FILETYPE_ASN1();

# Note that the final object will actually be a reference to the scalar
# (C-style pointer) returned by Net::SSLeay::CTX_*_new() so that
# it can be blessed.
sub new {
    my $class = shift;
    #DEBUG( "$class @_" );
    my $arg_hash = (ref($_[0]) eq 'HASH') ? $_[0] : {@_};

    # common problem forgetting to set SSL_use_cert
    # if client cert is given by user but SSL_use_cert is undef, assume that it
    # should be set
    my $is_server = $arg_hash->{SSL_server};
    if ( ! $is_server && ! defined $arg_hash->{SSL_use_cert}
	&& ( grep { $arg_hash->{$_} } qw(SSL_cert SSL_cert_file))
	&& ( grep { $arg_hash->{$_} } qw(SSL_key SSL_key_file)) ) {
	$arg_hash->{SSL_use_cert} = 1
    }

    # if any of SSL_ca* is set don't set the other SSL_ca*
    # from defaults
    if ( $arg_hash->{SSL_ca} ) {
	$arg_hash->{SSL_ca_file} ||= undef
	$arg_hash->{SSL_ca_path} ||= undef
    } elsif ( $arg_hash->{SSL_ca_path} ) {
	$arg_hash->{SSL_ca_file} ||= undef
    } elsif ( $arg_hash->{SSL_ca_file} ) {
	$arg_hash->{SSL_ca_path} ||= undef;
    }

    # add library defaults
    %$arg_hash = (
	SSL_use_cert => $is_server,
	$is_server ? %DEFAULT_SSL_SERVER_ARGS : %DEFAULT_SSL_CLIENT_ARGS,
	%$arg_hash
    );

    # Avoid passing undef arguments to Net::SSLeay
    defined($arg_hash->{$_}) or delete($arg_hash->{$_}) for(keys %$arg_hash);

    # check SSL CA, cert etc arguments
    # some apps set keys '' to signal that it is not set, replace with undef
    for (qw( SSL_cert SSL_cert_file SSL_key SSL_key_file
	SSL_ca SSL_ca_file SSL_ca_path
	SSL_fingerprint )) {
	$arg_hash->{$_} = undef if defined $arg_hash->{$_}
	    and $arg_hash->{$_} eq '';
    }
    for(qw(SSL_cert_file SSL_key_file)) {
	 defined( my $file = $arg_hash->{$_} ) or next;
	for my $f (ref($file) eq 'HASH' ? values(%$file):$file ) {
	    die "$_ $f does not exist" if ! -f $f;
	    die "$_ $f is not accessible" if ! -r _;
	}
    }

    my $verify_mode = $arg_hash->{SSL_verify_mode};
    if ( $verify_mode != Net::SSLeay::VERIFY_NONE()) {
	if ( defined( my $f = $arg_hash->{SSL_ca_file} )) {
	    if ( ! ref($f) || $$f ) {
		die "SSL_ca_file $f does not exist" if ! -f $f;
		die "SSL_ca_file $f is not accessible" if ! -r _;
	    }
	}
	if ( defined( my $d = $arg_hash->{SSL_ca_path} )) {
	    if ( ! ref($d) || $$d ) {
		die "SSL_ca_path $d does not exist" if ! -d $d;
		die "SSL_ca_path $d is not accessible" if ! -r _;
	    }
	}
    }

    my $self = bless {},$class;

    my $vcn_scheme = delete $arg_hash->{SSL_verifycn_scheme};
    my $vcn_publicsuffix = delete $arg_hash->{SSL_verifycn_publicsuffix};
    if ( ! $is_server and $verify_mode & 0x01 and
	! $vcn_scheme || $vcn_scheme ne 'none' ) {

	# gets updated during configure_SSL
	my $verify_name;
	$self->{verify_name_ref} = \$verify_name;

	my $vcb = $arg_hash->{SSL_verify_callback};
	$arg_hash->{SSL_verify_callback} = sub {
	    my ($ok,$ctx_store,$certname,$error,$cert) = @_;
	    $ok = $vcb->($ok,$ctx_store,$certname,$error,$cert) if $vcb;
	    $ok or return 0;

	    return $ok if
		Net::SSLeay::X509_STORE_CTX_get_error_depth($ctx_store) !=0;

	    my $host = $verify_name || ref($vcn_scheme) && $vcn_scheme->{callback} && 'unknown';
	    if ( ! $host ) {
		if ( $vcn_scheme ) {
		    IO::Socket::SSL->error(
			"Cannot determine peer hostname for verification" );
		    return 0;
		}
		warn "Cannot determine hostname of peer for verification. ".
		    "Disabling default hostname verification for now. ".
		    "Please specify hostname with SSL_verifycn_name and better set SSL_verifycn_scheme too.\n";
		return $ok;
	    } elsif ( ! $vcn_scheme && $host =~m{^[\d.]+$|:} ) {
		# don't try to verify IP by default
		return $ok;
	    }


	    # verify name
	    my $rv = IO::Socket::SSL::verify_hostname_of_cert(
		$host,$cert,$vcn_scheme,$vcn_publicsuffix );
	    if ( ! $rv && ! $vcn_scheme ) {
		# For now we use the default hostname verification if none
		# was specified and complain loudly but return ok if it does
		# not match. In the future we will enforce checks and users
		# should better specify and explicite verification scheme.
		warn <<WARN;

The verification of cert '$certname'
failed against the host '$host' with the default verification scheme.

   THIS MIGHT BE A MAN-IN-THE-MIDDLE ATTACK !!!!

To stop this warning you might need to set SSL_verifycn_name to
the name of the host you expect in the certificate.

WARN
		return $ok;
	    }
	    if ( ! $rv ) {
		IO::Socket::SSL->error(
		    "hostname verification failed" );
	    }
	    return $rv;
	};
    }

    my $ssl_op = Net::SSLeay::OP_ALL();

    my $ver;
    for (split(/\s*:\s*/,$arg_hash->{SSL_version})) {
	m{^(!?)(?:(SSL(?:v2|v3|v23|v2/3))|(TLSv1(?:_?[12])?))$}i
	or croak("invalid SSL_version specified");
	my $not = $1;
	( my $v = lc($2||$3) ) =~s{^(...)}{\U$1};
	if ( $not ) {
	    $ssl_op |= $SSL_OP_NO{$v};
	} else {
	    croak("cannot set multiple SSL protocols in SSL_version")
		if $ver && $v ne $ver;
	    $ver = $v;
	    $ver =~s{/}{}; # interpret SSLv2/3 as SSLv23
	    $ver =~s{(TLSv1)(\d)}{$1\_$2}; # TLSv1_1
	}
    }

    my $ctx_new_sub =  UNIVERSAL::can( 'Net::SSLeay',
	$ver eq 'SSLv2'   ? 'CTX_v2_new' :
	$ver eq 'SSLv3'   ? 'CTX_v3_new' :
	$ver eq 'TLSv1'   ? 'CTX_tlsv1_new' :
	$ver eq 'TLSv1_1' ? 'CTX_tlsv1_1_new' :
	$ver eq 'TLSv1_2' ? 'CTX_tlsv1_2_new' :
	'CTX_new'
    ) or return IO::Socket::SSL->error("SSL Version $ver not supported");
    my $ctx = $ctx_new_sub->() or return
	IO::Socket::SSL->error("SSL Context init failed");

    # SSL_OP_CIPHER_SERVER_PREFERENCE
    $ssl_op |= 0x00400000 if $arg_hash->{SSL_honor_cipher_order};

    Net::SSLeay::CTX_set_options($ctx,$ssl_op);

    # if we don't set session_id_context if client certificate is expected
    # client session caching will fail
    # if user does not provide explicit id just use the stringification
    # of the context
    if ( my $id = $arg_hash->{SSL_session_id_context}
	|| ( $arg_hash->{SSL_verify_mode} & 0x01 ) && "$ctx" ) {
	Net::SSLeay::CTX_set_session_id_context($ctx,$id,length($id));
    }

    # SSL_MODE_ACCEPT_MOVING_WRITE_BUFFER makes syswrite return if at least one
    # buffer was written and not block for the rest
    # SSL_MODE_ENABLE_PARTIAL_WRITE can be necessary for non-blocking because we
    # cannot guarantee, that the location of the buffer stays constant
    Net::SSLeay::CTX_set_mode( $ctx,
	SSL_MODE_ACCEPT_MOVING_WRITE_BUFFER|SSL_MODE_ENABLE_PARTIAL_WRITE);

    if ( my $proto_list = $arg_hash->{SSL_npn_protocols} ) {
	return IO::Socket::SSL->error("NPN not supported in Net::SSLeay")
	    if ! $can_npn;
	if($arg_hash->{SSL_server}) {
	    # on server side SSL_npn_protocols means a list of advertised protocols
	    Net::SSLeay::CTX_set_next_protos_advertised_cb($ctx, $proto_list);
	} else {
	    # on client side SSL_npn_protocols means a list of preferred protocols
	    # negotiation algorithm used is "as-openssl-implements-it"
	    Net::SSLeay::CTX_set_next_proto_select_cb($ctx, $proto_list);
	}
    }

    if ( $verify_mode != Net::SSLeay::VERIFY_NONE()) {
	if ( $arg_hash->{SSL_ca}
	    || defined $arg_hash->{SSL_ca_file}
	    || defined $arg_hash->{SSL_ca_path} ) {
	    my $file = $arg_hash->{SSL_ca_file};
	    $file = undef if ref($file) && ! $$file;
	    my $dir = $arg_hash->{SSL_ca_path};
	    $dir = undef if ref($dir) && ! $$dir;
	    if ( $arg_hash->{SSL_ca} ) {
		my $store = Net::SSLeay::CTX_get_cert_store($ctx);
		for (@{$arg_hash->{SSL_ca}}) {
		    Net::SSLeay::X509_STORE_add_cert($store,$_) or
			return IO::Socket::SSL->error(
			    "Failed to add certificate to CA store");
		}
	    }
	    if ( $file || $dir and ! Net::SSLeay::CTX_load_verify_locations(
		$ctx, $file || '', $dir || '')) {
		return IO::Socket::SSL->error(
		    "Invalid certificate authority locations")
	    }
	} elsif ( my %ca = IO::Socket::SSL::default_ca()) {
	    # no CA path given, continue with system defaults
	    return IO::Socket::SSL->error(
		"Invalid default certificate authority locations")
		if ! Net::SSLeay::CTX_load_verify_locations( $ctx,
		    $ca{SSL_ca_file} || '',$ca{SSL_ca_path} || '');
	}
    }

    if ($arg_hash->{'SSL_check_crl'}) {
	Net::SSLeay::X509_STORE_set_flags(
	    Net::SSLeay::CTX_get_cert_store($ctx),
	    Net::SSLeay::X509_V_FLAG_CRL_CHECK()
	);
	if ($arg_hash->{'SSL_crl_file'}) {
	    my $bio = Net::SSLeay::BIO_new_file($arg_hash->{'SSL_crl_file'}, 'r');
	    my $crl = Net::SSLeay::PEM_read_bio_X509_CRL($bio);
	    if ( $crl ) {
		Net::SSLeay::X509_STORE_add_crl(Net::SSLeay::CTX_get_cert_store($ctx), $crl);
	    } else {
		return IO::Socket::SSL->error("Invalid certificate revocation list");
	    }
	}
    }

    if ($arg_hash->{'SSL_server'} || $arg_hash->{'SSL_use_cert'}) {

	if ($arg_hash->{'SSL_passwd_cb'}) {
	    Net::SSLeay::CTX_set_default_passwd_cb($ctx, $arg_hash->{'SSL_passwd_cb'});
	}

	my %sni;
	for my $opt (qw(SSL_key SSL_key_file SSL_cert SSL_cert_file)) {
	    my $val  = $arg_hash->{$opt} or next;
	    if ( ref($val) eq 'HASH' ) {
		# SNI
		while ( my ($host,$v) = each %$val ) {
		    $sni{lc($host)}{$opt} = $v;
		}
	    } else {
		$sni{''}{$opt} = $val;
	    }
	}

	$sni{''}{ctx} = $ctx if exists $sni{''}; # default if no SNI
	for my $sni (values %sni) {
	    # we need a new context for each server
	    my $snictx = $sni->{ctx} ||= $ctx_new_sub->() or return
		IO::Socket::SSL->error("SSL Context init failed");

	    my ($havekey,$havecert);
	    if ( my $x509 = $sni->{SSL_cert} ) {
		# binary, e.g. X509*
		# we have either a single certificate or a list with
		# a chain of certificates
		my @x509 = ref($x509) eq 'ARRAY' ? @$x509: ($x509);
		my $cert = shift @x509;
		Net::SSLeay::CTX_use_certificate( $snictx,$cert )
		    || return IO::Socket::SSL->error("Failed to use Certificate");
		foreach my $ca (@x509) {
		    Net::SSLeay::CTX_add_extra_chain_cert( $snictx,$ca )
			|| return IO::Socket::SSL->error("Failed to use Certificate");
		}
		$havecert = 'OBJ';
	    } elsif ( my $f = $sni->{SSL_cert_file} ) {
		# try to load chain from PEM or certificate from ASN1
		if (Net::SSLeay::CTX_use_certificate_chain_file($snictx,$f)) {
		    $havecert = 'PEM';
		} elsif (Net::SSLeay::CTX_use_certificate_file($snictx,$f,FILETYPE_ASN1)) {
		    $havecert = 'DER';
		} else {
		    # try to load certificate, key and chain from PKCS12 file
		    my ($key,$cert,@chain) = Net::SSLeay::P_PKCS12_load_file($f,1);
		    if (!$cert and $arg_hash->{SSL_passwd_cb}
			and defined( my $pw = $arg_hash->{SSL_passwd_cb}->(0))) {
			($key,$cert,@chain) = Net::SSLeay::P_PKCS12_load_file($f,1,$pw);
		    }
		    PKCS12: while ($cert) {
			Net::SSLeay::CTX_use_certificate($snictx,$cert) or last;
			for my $ca (@chain) {
			    Net::SSLeay::CTX_add_extra_chain_cert($snictx,$ca)
				or last PKCS12;
			}
			last if $key && ! Net::SSLeay::CTX_use_PrivateKey($snictx,$key);
			$havecert = 'PKCS12';
			last;
		    }
		    $havekey = 'PKCS12' if $key;
		    Net::SSLeay::X509_free($cert) if $cert;
		    Net::SSLeay::EVP_PKEY_free($key) if $key;
		    # don't free @chain, because CTX_add_extra_chain_cert
		    # did not duplicate the certificates
		}
		$havecert or return	
		    IO::Socket::SSL->error("Failed to use certificate file");
	    }

	    if ($havekey) {
		# skip SSL_key_*
	    } elsif ( my $pkey = $sni->{SSL_key} ) {
		# binary, e.g. EVP_PKEY*
		Net::SSLeay::CTX_use_PrivateKey($snictx, $pkey)
		    || return IO::Socket::SSL->error("Failed to use Private Key");
		$havekey = 'MEM';
	    } elsif ( my $f = $sni->{SSL_key_file} 
		|| (($havecert eq 'PEM') ? $sni->{SSL_cert_file}:undef) ) {
		for my $ft ( FILETYPE_PEM, FILETYPE_ASN1 ) {
		    if (Net::SSLeay::CTX_use_PrivateKey_file($snictx,$f,$ft)) {
			$havekey = ($ft == FILETYPE_PEM) ? 'PEM':'DER';
			last;
		    }
		}
	    }
	    $havekey or return 
		IO::Socket::SSL->error("Failed to use private key");
	}

	if ( keys %sni > 1 or ! exists $sni{''} ) {
	    # we definitely want SNI support
	    $can_server_sni or return IO::Socket::SSL->error(
		"Server side SNI not supported for this openssl/Net::SSLeay");
	    $_ = $_->{ctx} for( values %sni);
	    Net::SSLeay::CTX_set_tlsext_servername_callback($ctx, sub {
		my $ssl = shift;
		my $host = Net::SSLeay::get_servername($ssl);
		$host = '' if ! defined $host;
		my $snictx = $sni{lc($host)} || $sni{''} or do {
		    $DEBUG>1 and DEBUG(
			"cannot get context from servername '$host'");
		    return 0;
		};
		$DEBUG>1 and DEBUG("set context from servername $host");
		Net::SSLeay::set_SSL_CTX($ssl,$snictx) if $snictx != $ctx;
		return 1;
	    });
	}

	if ( my $f = $arg_hash->{SSL_dh_file} ) {
	    my $bio = Net::SSLeay::BIO_new_file( $f,'r' )
		|| return IO::Socket::SSL->error( "Failed to open DH file $f" );
	    my $dh = Net::SSLeay::PEM_read_bio_DHparams($bio);
	    Net::SSLeay::BIO_free($bio);
	    $dh || return IO::Socket::SSL->error( "Failed to read PEM for DH from $f - wrong format?" );
	    my $rv = Net::SSLeay::CTX_set_tmp_dh( $ctx,$dh );
	    Net::SSLeay::DH_free( $dh );
	    $rv || return IO::Socket::SSL->error( "Failed to set DH from $f" );
	} elsif ( my $dh = $arg_hash->{SSL_dh} ) {
	    # binary, e.g. DH*
	    Net::SSLeay::CTX_set_tmp_dh( $ctx,$dh )
		|| return IO::Socket::SSL->error( "Failed to set DH from SSL_dh" );
	}

	if ( my $curve = $arg_hash->{SSL_ecdh_curve} ) {
	    return IO::Socket::SSL->error(
		"ECDH curve needs Net::SSLeay>=1.56 and OpenSSL>=1.0")
		if ! $can_ecdh;
	    if ( $curve !~ /^\d+$/ ) {
		# name of curve, find NID
		$curve = Net::SSLeay::OBJ_txt2nid($curve)
		    || return IO::Socket::SSL->error(
		    "cannot find NID for curve name '$curve'");
	    }
	    my $ecdh = Net::SSLeay::EC_KEY_new_by_curve_name($curve) or
		return IO::Socket::SSL->error(
		"cannot create curve for NID $curve");
	    Net::SSLeay::CTX_set_tmp_ecdh($ctx,$ecdh) or
		return IO::Socket::SSL->error(
		"failed to set ECDH curve context");
	    Net::SSLeay::EC_KEY_free($ecdh);
	}
    }

    my $verify_cb = $arg_hash->{SSL_verify_callback};
    my @accept_fp;
    if ( my $fp = $arg_hash->{SSL_fingerprint} ) {
	for( ref($fp) ? @$fp : $fp) {
	    my ($algo,$digest) = m{^([\w-]+)\$([a-f\d:]+)$}i;
	    return IO::Socket::SSL->error("invalid fingerprint '$_'")
		if ! $algo;
	    $algo = lc($algo);
	    ( $digest = lc($digest) ) =~s{:}{}g;
	    push @accept_fp,[ $algo, pack('H*',$digest) ]
	}
    }
    my $verify_callback = ( $verify_cb || @accept_fp) && sub {
	my ($ok, $ctx_store) = @_;
	my ($certname,$cert,$error);
	if ($ctx_store) {
	    $cert = Net::SSLeay::X509_STORE_CTX_get_current_cert($ctx_store);
	    $error = Net::SSLeay::X509_STORE_CTX_get_error($ctx_store);
	    $certname = Net::SSLeay::X509_NAME_oneline(Net::SSLeay::X509_get_issuer_name($cert)).
		Net::SSLeay::X509_NAME_oneline(Net::SSLeay::X509_get_subject_name($cert));
	    $error &&= Net::SSLeay::ERR_error_string($error);
	}
	$DEBUG>=3 && DEBUG( "ok=$ok cert=$cert" );
	if ( $cert && @accept_fp ) {
	    my %fp;
	    for(@accept_fp) {
		my $fp = $fp{$_->[0]} ||=
		    Net::SSLeay::X509_digest($cert,$algo2digest->($_->[0]));
		return 1 if $fp eq $_->[1];
	    }
	}
	return $ok if ! $verify_cb;
	return $verify_cb->($ok,$ctx_store,$certname,$error,$cert);
    };

    if ( $^O eq 'darwin' ) {
	# explicitely set error code to disable use of apples TEA patch
	# https://hynek.me/articles/apple-openssl-verification-surprises/
	my $vcb = $verify_callback;
	$verify_callback = sub {
	    my $rv = $vcb ? &$vcb : $_[0];
	    if ( $rv != 1 ) {
		# 50 - X509_V_ERR_APPLICATION_VERIFICATION: application verification failure
		Net::SSLeay::X509_STORE_CTX_set_error($_[1], 50);
	    }
	    return $rv;
	};
    }
    Net::SSLeay::CTX_set_verify($ctx, $verify_mode, $verify_callback);

    my $staple_callback = $arg_hash->{SSL_ocsp_staple_callback};
    if ( !$is_server && $can_ocsp_staple ) {
	$self->{ocsp_cache} = $arg_hash->{SSL_ocsp_cache};
	Net::SSLeay::CTX_set_tlsext_status_cb($ctx,sub {
	    my ($ssl,$resp) = @_;
	    my $iossl = $SSL_OBJECT{$ssl} or 
		die "no IO::Socket::SSL object found for SSL $ssl";
	    $iossl->[1] and do {
		# we must return with 1 or it will be called again
		# and beause we have no SSL object we must make the error global
		Carp::cluck($IO::Socket::SSL::SSL_ERROR 
		    = "OCSP callback on server side");
		return 1;
	    };
	    $iossl = $iossl->[0];

	    # if we have a callback use this
	    # callback must not free or copy $resp !!
	    if ( $staple_callback ) {
		$staple_callback->($iossl,$resp);
		return 1;
	    }

	    # default callback does verification
	    if ( ! $resp ) {
		$DEBUG>=3 && DEBUG("did not get stapled OCSP response");
		return 1;
	    }
	    $DEBUG>=3 && DEBUG("got stapled OCSP response");
	    my $status = Net::SSLeay::OCSP_response_status($resp);
	    if ($status != Net::SSLeay::OCSP_RESPONSE_STATUS_SUCCESSFUL()) {
		$DEBUG>=3 && DEBUG("bad status of stapled OCSP response: ".
		    Net::SSLeay::OCSP_response_status_str($status));
		return 1;
	    }
	    if (!eval { Net::SSLeay::OCSP_response_verify($ssl,$resp) }) {
		$DEBUG>=3 && DEBUG("verify of stapled OCSP response failed");
		return 1;
	    }
	    my (@results,$hard_error);
	    my @chain = $iossl->peer_certificates;
	    for my $cert (@chain) {
		my $certid = eval { Net::SSLeay::OCSP_cert2ids($ssl,$cert) };
		if (!$certid) {
		    $DEBUG>=3 && DEBUG("cannot create OCSP_CERTID: $@");
		    push @results,[-1,$@];
		    last;
		}
		($status) = Net::SSLeay::OCSP_response_results($resp,$certid);
		if ($status && $status->[2]) {
		    my $cache = ${*$iossl}{_SSL_ctx}{ocsp_cache};
		    if (!$status->[1]) {
			push @results,[1,$status->[2]{nextUpdate}];
			$cache && $cache->put($certid,$status->[2]);
		    } elsif ( $status->[2]{statusType} == 
			Net::SSLeay::V_OCSP_CERTSTATUS_GOOD()) {
			push @results,[1,$status->[2]{nextUpdate}];
			$cache && $cache->put($certid,{ 
			    %{$status->[2]},
			    expire => time()+120,
			    soft_error => $status->[1],
			});
		    } else {
			push @results,($hard_error = [0,$status->[1]]);
			$cache && $cache->put($certid,{ 
			    %{$status->[2]},
			    hard_error => $status->[1],
			});
		    }
		}
	    }
	    # return result of lead certificate, this should be in chain[0] and
	    # thus result[0], but we better check. But if we had any hard_error
	    # return this instead
	    if ($hard_error) {
		${*$iossl}{_SSL_ocsp_verify} = $hard_error;
	    } elsif (@results and $chain[0] == $iossl->peer_certificate) {
		${*$iossl}{_SSL_ocsp_verify} = $results[0];
	    }
	    return 1;
	});
    }

    if ( my $cl = $arg_hash->{SSL_cipher_list} ) {
	Net::SSLeay::CTX_set_cipher_list($ctx, $cl )
	    || return IO::Socket::SSL->error("Failed to set SSL cipher list");
    }

    if ( my $cb = $arg_hash->{SSL_create_ctx_callback} ) {
	$cb->($ctx);
    }

    $self->{context} = $ctx;
    $self->{verify_mode} = $arg_hash->{SSL_verify_mode};
    $self->{ocsp_mode} = 
	defined($arg_hash->{SSL_ocsp_mode}) ? $arg_hash->{SSL_ocsp_mode} :
	$self->{verify_mode} ? IO::Socket::SSL::SSL_OCSP_TRY_STAPLE() :
	0;
    $DEBUG>=3 && DEBUG( "new ctx $ctx" );
    $CTX_CREATED_IN_THIS_THREAD{$ctx} = 1;

    if ( my $cache = $arg_hash->{SSL_session_cache} ) {
	# use predefined cache
	$self->{session_cache} = $cache
    } elsif ( my $size = $arg_hash->{SSL_session_cache_size}) {
	$self->{session_cache} = IO::Socket::SSL::Session_Cache->new( $size );
    }

    return $self;
}


sub session_cache {
    my $self = shift;
    my $cache = $self->{session_cache} || return;
    my ($addr,$port,$session) = @_;
    $port ||= $addr =~s{:(\w+)$}{} && $1; # host:port
    my $key = "$addr:$port";
    return defined($session)
	? $cache->add_session($key, $session)
	: $cache->get_session($key);
}

sub has_session_cache {
    return defined shift->{session_cache};
}


sub CLONE { %CTX_CREATED_IN_THIS_THREAD = (); }
sub DESTROY {
    my $self = shift;
    if ( my $ctx = $self->{context} ) {
	$DEBUG>=3 && DEBUG("free ctx $ctx open=".join( " ",keys %CTX_CREATED_IN_THIS_THREAD ));
	if ( %CTX_CREATED_IN_THIS_THREAD and
	    delete $CTX_CREATED_IN_THIS_THREAD{$ctx} ) {
	    # remove any verify callback for this context
	    if ( $self->{verify_mode}) {
		$DEBUG>=3 && DEBUG("free ctx $ctx callback" );
		Net::SSLeay::CTX_set_verify($ctx, 0,undef);
	    }
	    if ( $self->{ocsp_error_ref}) {
		$DEBUG>=3 && DEBUG("free ctx $ctx tlsext_status_cb" );
		Net::SSLeay::CTX_set_tlsext_status_cb($ctx,undef);
	    }
	    $DEBUG>=3 && DEBUG("OK free ctx $ctx" );
	    Net::SSLeay::CTX_free($ctx);
	}
    }
    delete(@{$self}{'context','session_cache'});
}

package IO::Socket::SSL::Session_Cache;
use strict;

sub new {
    my ($class, $size) = @_;
    $size>0 or return;
    return bless { _maxsize => $size }, $class;
}


sub get_session {
    my ($self, $key) = @_;
    my $session = $self->{$key} || return;
    return $session->{session} if ($self->{'_head'} eq $session);
    $session->{prev}->{next} = $session->{next};
    $session->{next}->{prev} = $session->{prev};
    $session->{next} = $self->{'_head'};
    $session->{prev} = $self->{'_head'}->{prev};
    $self->{'_head'}->{prev} = $self->{'_head'}->{prev}->{next} = $session;
    $self->{'_head'} = $session;
    return $session->{session};
}

sub add_session {
    my ($self, $key, $val) = @_;
    return if ($key eq '_maxsize' or $key eq '_head');

    if ( my $have = $self->{$key} ) {
	Net::SSLeay::SESSION_free( $have->{session} );
	$have->{session} = $val;
	return get_session($self,$key); # will put key on front
    }

    my $session = $self->{$key} = { session => $val, key => $key };

    if ( keys(%$self) > $self->{_maxsize}+2) {
	my $last = $self->{'_head'}->{prev};
	Net::SSLeay::SESSION_free($last->{session});
	delete($self->{$last->{key}});
	$self->{'_head'}->{prev} = $self->{'_head'}->{prev}->{prev};
	delete($self->{'_head'}) if ($self->{'_maxsize'} == 1);
    }

    if ($self->{'_head'}) {
	$session->{next} = $self->{'_head'};
	$session->{prev} = $self->{'_head'}->{prev};
	$self->{'_head'}->{prev}->{next} = $session;
	$self->{'_head'}->{prev} = $session;
    } else {
	$session->{next} = $session->{prev} = $session;
    }
    $self->{'_head'} = $session;
    return $session;
}

sub DESTROY {
    my $self = shift;
    delete(@{$self}{'_head','_maxsize'});
    for (values %$self) {
	Net::SSLeay::SESSION_free($_->{session} || next);
    }
}



package IO::Socket::SSL::OCSP_Cache;

sub new {
    my ($class,$size) = @_;
    return bless { 
	'' => { _lru => 0, size => $size || 100 } 
    },$class;
}
sub get {
    my ($self,$id) = @_;
    my $e = $self->{$id} or return;
    $e->{_lru} = $self->{''}{_lru}++;
    if ( $e->{expire} && time()<$e->{expire}) {
	delete $self->{$id};
	return;
    }
    if ( $e->{nextUpdate} && time()<$e->{nextUpdate} ) {
	delete $self->{$id};
	return;
    }
    return $e;
}

sub put {
    my ($self,$id,$e) = @_;
    $self->{$id} = $e;
    $e->{_lru} = $self->{''}{_lru}++;
    my $del = keys(%$self) - $self->{''}{size};
    if ($del>0) {
	my @k = sort { $self->{$a}{_lru} <=> $self->{$b}{_lru} } keys %$self;
	delete @{$self}{ splice(@k,0,$del) };
    }
    return $e;
}

package IO::Socket::SSL::OCSP_Resolver;
*DEBUG = *IO::Socket::SSL::DEBUG;

# create a new resolver
# $ssl - the ssl object
# $cache - OCSP_Cache object (put,get)
# $failhard - flag if we should fail hard on OCSP problems
# $certs - list of certs to verify
sub new {
    my ($class,$ssl,$cache,$failhard,$certs) = @_;
    my (%todo,$done,$hard_error,@soft_error);
    for my $cert (@$certs) {
	# skip entries which have no OCSP uri or where we cannot get a certid
	# (e.g. self-signed or where we don't have the issuer)
	my $subj = Net::SSLeay::X509_NAME_oneline(Net::SSLeay::X509_get_subject_name($cert));
	my $uri = Net::SSLeay::P_X509_get_ocsp_uri($cert) or do {
	    $DEBUG>2 && DEBUG("no URI for certificate $subj");
	    push @soft_error,"no ocsp_uri for $subj";
	    next;
	};
	my $certid = eval { Net::SSLeay::OCSP_cert2ids($ssl,$cert) } or do {
	    $DEBUG>2 && DEBUG("no OCSP_CERTID for certificate $subj: $@");
	    push @soft_error,"no certid for $subj: $@";
	    next;
	};
	if (!($done = $cache->get($certid))) {
	    push @{ $todo{$uri}{ids} }, $certid;
	} elsif ( $done->{hard_error} ) {
	    # one error is enough to fail validation
	    $hard_error = $done->{hard_error};
	    %todo = ();
	    last;
	} elsif ( $done->{soft_error} ) {
	    push @soft_error,$done->{soft_error};
	}
    }
    while ( my($uri,$v) = each %todo) {
	my $ids = $v->{ids};
	$v->{req} = Net::SSLeay::i2d_OCSP_REQUEST(
	    Net::SSLeay::OCSP_ids2req(@$ids));
    }
    $hard_error ||= '' if ! %todo;
    return bless {
	ssl => $ssl,
	cache => $cache,
	failhard => $failhard,
	hard_error => $hard_error,
	soft_error => @soft_error ? join("; ",@soft_error) : undef,
	todo => \%todo,
    },$class;
}

# return current result, e.g. '' for no error, else error
# if undef we have no final result yet
sub hard_error { return shift->{hard_error} }
sub soft_error { return shift->{soft_error} }

# return hash with uri => ocsp_request_data for open requests
sub requests {
    my $todo = shift()->{todo};
    return map { ($_,$todo->{$_}{req}) } keys %$todo;
}

# add new response
sub add_response {
    my ($self,$uri,$resp) = @_;
    my $todo = delete $self->{todo}{$uri};
    return $self->{error} if ! $todo || $self->{error};

    my ($req,@soft_error,@hard_error);

    # do we have a response
    if (!$resp) {
	@soft_error = "http request failed"

    # is it an valid OCSP_RESPONSE
    } elsif ( ! eval { $resp = Net::SSLeay::d2i_OCSP_RESPONSE($resp) }) {
	@soft_error = "invalid response (no OCSP_RESPONSE)";
	# hopefully short-time error
	$self->{cache}->put($_,{
	    soft_error => "@soft_error",
	    expire => time()+10,
	}) for (@{$todo->{ids}});
    # is the OCSP response status success
    } elsif ( 
	( my $status = Net::SSLeay::OCSP_response_status($resp)) 
	    != Net::SSLeay::OCSP_RESPONSE_STATUS_SUCCESSFUL() 
    ){
	@soft_error = "OCSP response failed: ".
	    Net::SSLeay::OCSP_response_status_str($status);
	# hopefully short-time error
	$self->{cache}->put($_,{
	    soft_error => "@soft_error",
	    expire => time()+10,
	}) for (@{$todo->{ids}});

    # does nonce match the request and can the signature be verified
    } elsif ( ! eval { 
	$req = Net::SSLeay::d2i_OCSP_REQUEST($todo->{req});
	Net::SSLeay::OCSP_response_verify($self->{ssl},$resp,$req);
    }) {
	if ($@) {
	    @soft_error = $@
	} else {
	    my @err;
	    while ( my $err = Net::SSLeay::ERR_get_error()) {
		push @soft_error, Net::SSLeay::ERR_error_string($err);
	    }
	    @soft_error = 'failed to verify OCSP response' if ! @soft_error;
	}
	# configuration problem or we don't know the signer
	$self->{cache}->put($_,{
	    soft_error => "@soft_error",
	    expire => time()+120,
	}) for (@{$todo->{ids}});

    # extract results from response
    } elsif ( my @result = 
	Net::SSLeay::OCSP_response_results($resp,@{$todo->{ids}})) {
	my (@found,@miss);
	for my $rv (@result) {
	    if ($rv->[2]) {
		push @found,$rv->[0];
		if (!$rv->[1]) { 
		    # no error
		    $self->{cache}->put($rv->[0],$rv->[2]);
		} elsif ( $rv->[2]{statusType} == 
		    Net::SSLeay::V_OCSP_CERTSTATUS_GOOD()) {
		    # soft error, like response after nextUpdate
		    push @soft_error,$rv->[1];
		    $self->{cache}->put($rv->[0],{
			%{$rv->[2]},
			soft_error => "@soft_error",
			expire => time()+120,
		    });
		} else {
		    # hard error
		    $self->{cache}->put($rv->[0],$rv->[2]);
		    push @hard_error, $rv->[1];
		}
	    } else {
		push @miss,$rv->[0];
	    }
	}
	if (@miss && @found) {
	    # we sent multiple responses, but server answered only to one
	    # try again
	    $self->{todo}{$uri} = $todo;
	    $todo->{ids} = \@miss;
	    $todo->{req} = Net::SSLeay::i2d_OCSP_REQUEST(
		Net::SSLeay::OCSP_ids2req(@miss));
	    $DEBUG>=2 && DEBUG("$uri just answered ".@found." of ".(@found+@miss)." requests");
	}
    } else {
	@soft_error = "no data in response";
	# probably configuration problem 
	$self->{cache}->put($_,{
	    soft_error => "@soft_error",
	    expire => time()+120,
	}) for (@{$todo->{ids}});
    }

    Net::SSLeay::OCSP_REQUEST_free($req) if $req;
    if ($self->{failhard}) {
	push @hard_error,@soft_error;
	@soft_error = ();
    }
    if (@soft_error) {
	$self->{soft_error} .= "; " if $self->{soft_error};
	$self->{soft_error} .= "$uri: ".join('; ',@soft_error);
    }
    if (@hard_error) {
	$self->{hard_error} = "$uri: ".join('; ',@hard_error);
	%{$self->{todo}} = ();
    } elsif ( ! %{$self->{todo}} ) {
	$self->{hard_error} = ''
    }
    return $self->{hard_error};
}

# make all necessary requests to get OCSP responses blocking
sub resolve_blocking {
    my ($self,%args) = @_;
    while ( my %todo = $self->requests ) {
	eval { require HTTP::Tiny } or die "need HTTP::Tiny installed";
	# OCSP responses have their own signature, so we don't need SSL verification
	my $ua = HTTP::Tiny->new(verify_SSL => 0,%args);
	while (my ($uri,$reqdata) = each %todo) {
	    $DEBUG && DEBUG("sending OCSP request to $uri");
	    my $resp = $ua->request('POST',$uri, {
		headers => { 'Content-type' => 'application/ocsp-request' },
		content => $reqdata
	    });
	    $DEBUG && DEBUG("got  OCSP response from $uri code=$resp->{code}");
	    defined ($self->add_response($uri,
		$resp->{success} && $resp->{content}))
		&& last;
	}
    }
    $DEBUG>=2 && DEBUG("no more open OCSP requests");
    return $self->{hard_error};
}

1;

__END__

=head1 NAME

IO::Socket::SSL -- SSL sockets with IO::Socket interface

=head1 SYNOPSIS

    use strict;
    use IO::Socket::SSL;

    # simple HTTP client ------------------------------------------------------
    my $client = IO::Socket::SSL->new(
	# where to connect
	PeerHost => "www.example.com",
	PeerPort => "https",

	# certificate verification
	SSL_verify_mode => SSL_VERIFY_PEER,

	# location of CA store
	SSL_ca_path => '/etc/ssl/certs', # typical CA path on Linux
	SSL_ca_file => '/etc/ssl/cert.pem', # typical CA file on BSD
	# or just use default path on system:
	IO::Socket::SSL::default_ca(), # either explicitly
	# or implicitly by not giving SSL_ca_*

	# easy hostname verification
	SSL_verifycn_name => 'foo.bar', # defaults to PeerHost
	SSL_verifycn_scheme => 'http',

	# SNI support
	SSL_hostname => 'foo.bar', # defaults to PeerHost

    ) or die "failed connect or ssl handshake: $!,$SSL_ERROR";

    # send and receive over SSL connection
    print $client "GET / HTTP/1.0\r\n\r\n";
    print <$client>;

    # simple server ------------------------------------------------------------
    my $server = IO::Socket::SSL->new(
	# where to listen
	LocalAddr => '127.0.0.1',
	LocalPort => 8080,
	Listen => 10,

	# which certificate to offer
	# with SNI support there can be different certificates per hostname
	SSL_cert_file => 'cert.pem',
	SSL_key_file => 'key.pem',
    ) or die "failed to listen: $!";

    # accept client
    my $client = $server->accept or die
	"failed to accept or ssl handshake: $!,$SSL_ERROR";

    # Upgrade existing socket to SSL -------------------------------------------
    my $sock = IO::Socket::INET->new('imap.example.com:imap');
    # ... receive greeting, send STARTTLS, receive ok ...
    IO::Socket::SSL->start_SSL($sock,
	SSL_verify_mode => SSL_VERIFY_PEER,
	SSL_ca_path => '/etc/ssl/certs',
	...
    ) or die "failed to upgrade to SSL: $SSL_ERROR";

    # manual name verification, could also be done in start_SSL with
    # SSL_verifycn_name etc
    $client->verify_hostname( 'imap.example.com','imap' )
	or die "hostname verification failed";

    # all data are now SSL encrypted
    print $sock ....

    # check with OCSP for certificate revocation -------------------------------
    # only available with OpenSSL 1.0.0 or higher

    # default will try OCSP stapling and check only leaf certificate
    my $client = IO::Socket::SSL->new($dst);

    # better yet: require checking of full chain
    my $client = IO::Socket::SSL->new(
	PeerAddr => $dst,
	SSL_ocsp_mode => SSL_OCSP_FULL_CHAIN,
    );

    # even better: make OCSP errors fatal
    # also use common OCSP response cache
    my $ocsp_cache = IO::Socket::SSL::OCSP_Cache->new;
    my $client = IO::Socket::SSL->new(
	PeerAddr => $dst,
	SSL_ocsp_mode => SSL_OCSP_FULL_CHAIN|SSL_OCSP_FAIL_HARD,
	SSL_ocsp_cache => $ocsp_cache,
    );

    # disable OCSP stapling in case server has problems with it
    my $client = IO::Socket::SSL->new(
	PeerAddr => $dst,
	SSL_ocsp_mode => SSL_OCSP_NO_STAPLE,
    );

    # check any certificates which are not yet checked by OCSP stapling or
    # where we have already cached results. For your own resolving combine
    # $ocsp->requests with $ocsp->add_response(uri,response).
    my $ocsp = $client->ocsp_resolver();
    my $errors = $ocsp->resolve_blocking();
    if ($errors) {
	warn "OCSP verification failed: $errors";
	close($client);
    }

    # use non-blocking socket (BEWARE OF SELECT!) ------------------------------
    my $cl = IO::Socket::SSL->new($dst);
    $cl->blocking(0);
    my $sel = IO::Select->new($cl);
    while (1) {
	# with SSL a call for reading n bytes does not result in reading of n
	# bytes from the socket, but instead it must read at least one full SSL
	# frame. If the socket has no new bytes, but there are unprocessed data
	# from the SSL frame can_read will block!

	# wait for data on socket
	$sel->can_read();

	# new data on socket or eof
	READ:
	# this does not read only 1 byte from socket, but reads the complete SSL
	# frame and then just returns one byte. On subsequent calls it than
	# returns more byte of the same SSL frame until it needs to read the
	# next frame.
	my $n = sysread( $cl,my $buf,1);
	if ( ! defined $n ) {
	    die $! if not ${EAGAIN};
	    next if $SSL_ERROR == SSL_WANT_READ;
	    if ( $SSL_ERROR == SSL_WANT_WRITE ) {
		# need to write data on renegotiation
		$sel->can_write;
		next;
	    }
	    die "something went wrong: $SSL_ERROR";
	} elsif ( ! $n ) {
	    last; # eof
	} else {
	    # read next bytes
	    # we might have still data within the current SSL frame
	    # thus first process these data instead of waiting on the underlying
	    # socket object
	    goto READ if $self->pending;  # goto sysread
	    next;                         # goto $sel->can_read
	}
    }



=head1 DESCRIPTION

This module provides an interface to SSL sockets, similar to other IO::Socket
modules. Because of that, it can be used to make existing programs using
IO::Socket::INET or similar modules to provide SSL encryption without much
effort.
IO::Socket::SSL supports all the extra features that one needs to write a
full-featured SSL client or server application: multiple SSL contexts, cipher
selection, certificate verification, Server Name Indication (SNI), Next
Protocol Negotiation (NPN), SSL version selection and more.

If you have never used SSL before, you should read the section 'Using SSL'
before attempting to use this module.

If you used IO::Socket before you should read the following section
'Differences to IO::Socket'.

If you want to use SSL with non-blocking sockets and/or within an event loop
please read very carefully the sections about non-blocking I/O and polling of SSL
sockets.

If you are trying to use it with threads see the BUGS section.

=head2 Differences to IO::Socket

Although L<IO::Socket::SSL> tries to behave similar to L<IO::Socket> there are
some important differences due to the way SSL works:

=over 4

=item * buffered input

Data are transmitted inside the SSL protocol using encrypted frames, which can
only be decrypted once the full frame is received. So if you use C<read> or
C<sysread> to receive less data than the SSL frame contains, it will read the
whole frame, return part of it and buffer the rest for later reads.
This does not make a difference for simple programs, but if you use
select-loops or polling or non-blocking I/O please read the related sections.

=item * SSL handshakes

Before any encryption can be done the peers have to agree to common algorithms,
verify certificates etc. So a handshake needs to be done before any payload is
send or received and might additionally happen later in the connection again.

This has important implications when doing non-blocking or event-based I/O
(please read the related sections), but means also, that connect and accept
calls include the SSL handshake and thus might block or fail, if the peer does
not behave like expected. For instance accept will wait infinitly if a TCP
client connects to the socket but does not initiate an SSL handshake.

=back

=head1 METHODS

IO::Socket::SSL inherits from another IO::Socket module.
The choice of the super class depends on the installed modules:

=over 4

=item *

If IO::Socket::IP with at least version 0.20 is installed it will use this
module as super class, transparently providing IPv6 and IPv4 support.

=item *

If IO::Socket::INET6 is installed it will use this module as super class,
transparently providing IPv6 and IPv4 support.

=item *

Otherwise it will fall back to IO::Socket::INET, which is a perl core module.
With IO::Socket::INET you only get IPv4 support.

=back

Please be aware, that with the IPv6 capable super classes, it will lookup first
for the IPv6 address of a given hostname. If the resolver provides an IPv6
address, but the host cannot be reached by IPv6, there will be no automatic
fallback to IPv4.
To avoid these problems you can either force IPv4 by specifying and AF_INET
as C<Domain> of the socket or globally enforce IPv4 by loading IO::Socket::SSL
with the option 'inet4'.

IO::Socket::SSL will provide all of the methods of its super class, but
sometimes it will override them to match the behavior expected from SSL or to
provide additional arguments.

The new or changed methods are described below, but please read also the
section about SSL specific error handling.

=over 4

=item B<new(...)>

Creates a new IO::Socket::SSL object.  You may use all the friendly options
that came bundled with the super class (e.g. IO::Socket::IP,
IO::Socket::INET, ...) plus (optionally) the ones described below.
If you don't specify any SSL related options it will do it's best in using
secure defaults, e.g. chosing good ciphers, enabling proper verification etc.

=over 2

=item SSL_hostname

This can be given to specify the hostname used for SNI, which is needed if you
have multiple SSL hostnames on the same IP address. If not given it will try to
determine hostname from PeerAddr, which will fail if only IP was given or if
this argument is used within start_SSL.

If you want to disable SNI set this argument to ''.

Currently only supported for the client side and will be ignored for the server
side.

See section "SNI Support" for details of SNI the support.

=item SSL_version

Sets the version of the SSL protocol used to transmit data.
'SSLv23' auto-negotiates between SSLv2 and SSLv3, while 'SSLv2', 'SSLv3',
'TLSv1', 'TLSv1_1' or 'TLSv1_2' restrict the protocol to the specified version.
All values are case-insensitive.  Instead of 'TLSv1_1' and 'TLSv1_2' one can
also use 'TLSv11' and 'TLSv12'.  Support for 'TLSv1_1' and 'TLSv1_2' requires
recent versions of Net::SSLeay and openssl.

You can limit to set of supported protocols by adding !version separated by ':'.

The default SSL_version is 'SSLv23:!SSLv2' which means, that SSLv2, SSLv3 and
TLSv1 are supported for initial protocol handshakes, but SSLv2 will not be
accepted, leaving only SSLv3 and TLSv1. You can also use !TLSv1_1 and !TLSv1_2
to disable TLS versions 1.1 and 1.2 while allowing TLS version 1.0.

Setting the version instead to 'TLSv1' will probably break interaction with
lots of clients which start with SSLv2 and then upgrade to TLSv1. On the other
side some clients just close the connection when they receive a TLS version 1.1
request. In this case setting the version to 'SSLv23:!SSLv2:!TLSv1_1:!TLSv1_2'
might help.

=item SSL_cipher_list

If this option is set the cipher list for the connection will be set to the
given value, e.g. something like 'ALL:!LOW:!EXP:!aNULL'. Look into the OpenSSL
documentation (L<http://www.openssl.org/docs/apps/ciphers.html#CIPHER_STRINGS>)
for more details.

Unless you fail to contact your peer because of no shared ciphers it is
recommended to leave this option at the default setting. The default setting
prefers ciphers with forward secrecy, disables anonymous authentication and
disables known insecure ciphers like MD5, DES etc. This gives a grade A result
at the tests of SSL Labs.
To use the less secure OpenSSL builtin default (whatever this is) set
SSL_cipher_list to ''.

=item SSL_honor_cipher_order

If this option is true the cipher order the server specified is used instead
of the order proposed by the client. This option defaults to true to make use of
our secure cipher list setting.

=item SSL_use_cert

If this is true, it forces IO::Socket::SSL to use a certificate and key, even if
you are setting up an SSL client.  If this is set to 0 (the default), then you will
only need a certificate and key if you are setting up a server.

SSL_use_cert will implicitly be set if SSL_server is set.
For convenience it is also set if it was not given but a cert was given for use
(SSL_cert_file or similar).

=item SSL_server

Set this option to a true value, if the socket should be used as a server.
If this is not explicitly set it is assumed, if the Listen parameter is given
when creating the socket.

=item SSL_cert_file | SSL_cert | SSL_key_file | SSL_key

If you create a server you usually need to specify a server certificate which
should be verified by the client. Same is true for client certificates, which
should be verified by the server.
The certificate can be given as a file with SSL_cert_file or as an internal 
representation of a X509* object with SSL_cert.
If given as a file it will automatically detect the format. 
Supported file formats are PEM, DER and PKCS#12, where PEM and PKCS#12 can
contain the certicate and the chain to use, while DER can only contain a single
certificate.

If given as a list of X509* please note, that the all the chain certificates
(e.g. all except the first) will be "consumed" by openssl and will be freed
if the SSL context gets destroyed - so you should never free them yourself. But
the servers certificate (e.g. the first) will not be consumed by openssl and
thus must be freed by the application.

For each certificate a key is need, which can either be given as a file with
SSL_key_file or as an internal representation of a EVP_PKEY* object with
SSL_key.
If a key was already given within the PKCS#12 file specified by SSL_cert_file
it will ignore any SSL_key or SSL_key_file.
If no SSL_key or SSL_key_file was given it will try to use the PEM file given
with SSL_cert_file again, maybe it contains the key too.

If your SSL server should be able to use different certificates on the same IP
address, depending on the name given by SNI, you can use a hash reference
instead of a file with C<<hostname => cert_file>>.

In case certs and keys are needed but not given it might fall back to builtin
defaults, see "Defaults for Cert, Key and CA".

Examples:

 SSL_cert_file => 'mycert.pem',
 SSL_key_file => 'mykey.pem',

 SSL_cert_file => {
    "foo.example.org" => 'foo-cert.pem',
    "bar.example.org" => 'bar-cert.pem',
    # used when nothing matches or client does not support SNI
    '' => 'default-cert.pem',
 }
 SSL_key_file => {
    "foo.example.org" => 'foo-key.pem',
    "bar.example.org" => 'bar-key.pem',
    # used when nothing matches or client does not support SNI
    '' => 'default-key.pem',
 }


=item SSL_dh_file

If you want Diffie-Hellman key exchange you need to supply a suitable file here
or use the SSL_dh parameter. See dhparam command in openssl for more information.
To create a server which provides forward secrecy you need to either give the DH
parameters or (better, because faster) the ECDH curve.

If neither C<SSL_dh_file> not C<SSL_dh> is set a builtin DH parameter with a
length of 2048 bit is used to offer DH key exchange by default. If you don't
want this (e.g. disable DH key exchange) explicitly set this or the C<SSL_dh>
parameter to undef.

=item SSL_dh

Like SSL_dh_file, but instead of giving a file you use a preloaded or generated DH*.

=item SSL_ecdh_curve

If you want Elliptic Curve Diffie-Hellmann key exchange you need to supply the
OID or NID of a suitable curve (like 'prime256v1') here.
To create a server which provides forward secrecy you need to either give the DH
parameters or (better, because faster) the ECDH curve.

This parameter defaults to 'prime256v1' (builtin of OpenSSL) to offer ECDH key
exchange by default. If you don't want this explicitly set it to undef.

You can check if ECDH support is available by calling C<IO::Socket::SSL->can_ecdh>.

=item SSL_passwd_cb

If your private key is encrypted, you might not want the default password prompt from
Net::SSLeay.  This option takes a reference to a subroutine that should return the
password required to decrypt your private key.

=item SSL_ca | SSL_ca_file | SSL_ca_path

Usually you want to verify that the peer certificate has been signed by a
trusted certificate authority. In this case you should use this option to
specify the file (C<SSL_ca_file>) or directory (C<SSL_ca_path>) containing the
certificateZ<>(s) of the trusted certificate authorities.
Also you can give X509* certificate handles (from L<Net::SSLeay> or
L<IO::Socket::SSL::Utils>) as a list with C<SSL_ca>. These will be added to the
CA store before path and file and thus take precedence.
If neither SSL_ca, nor SSL_ca_file or SSL_ca_path are set it will use
C<default_ca()> to determine the user-set or system defaults.
If you really don't want to set a CA set SSL_ca_file or SSL_ca_path to
C<\undef> or SSL_ca to an empty list. (unfortunatly C<''> is used by some
modules using IO::Socket::SSL when CA is not exlicitly given).

=item SSL_fingerprint

Sometimes you have a self-signed certificate or a certificate issued by an
unknown CA and you really want to accept it, but don't want to disable
verification at all. In this case you can specify the fingerprint of the
certificate as C<'algo$hex_fingerprint'>. C<algo> is a fingerprint algorithm
supported by OpenSSL, e.g. 'sha1','sha256'... and C<hex_fingerprint> is the
hexadecimal representation of the binary fingerprint.
To get the fingerprint of an established connection you can use
C<get_fingerprint>.

You can specify a list of fingerprints in case you have several acceptable
certificates.
If a fingerprint matches no additional verification of the certificate will be
done.

=item SSL_verify_mode

This option sets the verification mode for the peer certificate.
You may combine SSL_VERIFY_PEER (verify_peer), SSL_VERIFY_FAIL_IF_NO_PEER_CERT
(fail verification if no peer certificate exists; ignored for clients),
SSL_VERIFY_CLIENT_ONCE (verify client once; ignored for clients).
See OpenSSL man page for SSL_CTX_set_verify for more information.

The default is SSL_VERIFY_NONE for server  (e.g. no check for client
certificate) and SSL_VERIFY_PEER for client (check server certificate).

=item SSL_verify_callback

If you want to verify certificates yourself, you can pass a sub reference along
with this parameter to do so.  When the callback is called, it will be passed:

=over 4

=item 1.
a true/false value that indicates what OpenSSL thinks of the certificate,

=item 2.
a C-style memory address of the certificate store,

=item 3.
a string containing the certificate's issuer attributes and owner attributes, and

=item 4.
a string containing any errors encountered (0 if no errors).

=item 5.
a C-style memory address of the peer's own certificate (convertible to
PEM form with Net::SSLeay::PEM_get_string_X509()).

=back

The function should return 1 or 0, depending on whether it thinks the certificate
is valid or invalid.  The default is to let OpenSSL do all of the busy work.

The callback will be called for each element in the certificate chain.

See the OpenSSL documentation for SSL_CTX_set_verify for more information.

=item SSL_verifycn_scheme

The scheme is used to correctly verify the identity inside the certificate
by using the hostname of the peer.
See the information about the verification schemes in B<verify_hostname>.

If you don't specify a scheme it will use 'default', but only complain loudly if
the name verification fails instead of letting the whole certificate
verification fail. THIS WILL CHANGE, e.g. it will let the certificate
verification fail in the future if the hostname does not match the certificate !!!!
To override the name used in verification use B<SSL_verifycn_name>.

The scheme 'default' is a superset of the usual schemes, which will accept the
hostname in common name and subjectAltName and allow wildcards everywhere.
While using this scheme is way more secure than no name verification at all you
better should use the scheme specific to your application protocol, e.g. 'http',
'ftp'...

If you are really sure, that you don't want to verify the identity using the
hostname  you can use 'none' as a scheme. In this case you'd better have
alternative forms of verification, like a certificate fingerprint or do a manual
verification later by calling B<verify_hostname> yourself.

=item SSL_verifycn_publicsuffix

This option is used to specify the behavior when checking wildcards certificates
for public suffixes, e.g. no wildcard certificates for *.com or *.co.uk should
be accepted, while *.example.com or *.example.co.uk is ok.

If not specified it will simply use the builtin default of
L<IO::Socket::SSL::PublicSuffix>, you can create another object with
from_string or from_file of this module.

To disable verification of public suffix set this option to C<''>.

=item SSL_verifycn_name

Set the name which is used in verification of hostname. If SSL_verifycn_scheme
is set and no SSL_verifycn_name is given it will try to use SSL_hostname or
PeerHost and PeerAddr settings and fail if no name can be determined.
If SSL_verifycn_scheme is not set it will use a default scheme and warn if it
cannot determine a hostname, but it will not fail.

Using PeerHost or PeerAddr works only if you create the connection directly
with C<< IO::Socket::SSL->new >>, if an IO::Socket::INET object is upgraded
with B<start_SSL> the name has to be given in B<SSL_verifycn_name> or
B<SSL_hostname>.

=item SSL_check_crl

If you want to verify that the peer certificate has not been revoked
by the signing authority, set this value to true. OpenSSL will search
for the CRL in your SSL_ca_path, or use the file specified by
SSL_crl_file.  See the Net::SSLeay documentation for more details.
Note that this functionality appears to be broken with OpenSSL <
v0.9.7b, so its use with lower versions will result in an error.

=item SSL_crl_file

If you want to specify the CRL file to be used, set this value to the
pathname to be used.  This must be used in addition to setting
SSL_check_crl.

=item SSL_ocsp_mode

Defines how certificate revocation is done using OCSP (Online Status Revocation
Protocol). The default is to send a request for OCSP stapling to the server and
if the server sends an OCSP response back the result will be used.

Any other OCSP checking needs to be done manually with C<ocsp_resolver>.

The following flags can be combined with C<|>:

=over 8

=item SSL_OCSP_NO_STAPLE 

Don't ask for OCSP stapling.
This is the default if SSL_verify_mode is VERIFY_NONE.

=item SSL_OCSP_TRY_STAPLE 

Try OCSP stapling, but don't complain if it gets no stapled response back.
This is the default if SSL_verify_mode is VERIFY_PEER (the default).

=item SSL_OCSP_MUST_STAPLE

Consider it a hard error, if the server does not send a stapled OCSP response
back. Most servers currently send no stapled OCSP response back.

=item SSL_OCSP_FAIL_HARD 

Fail hard on response errors, default is to fail soft like the browsers do.
Soft errors mean, that the OCSP response is not usable, e.g. no response, 
error response, no valid signature etc.
Certificate revocations inside a verified response are considered hard errors
in any case.

Soft errors inside a stapled response are never considered hard, e.g. it is
expected that in this case an OCSP request will be send to the responsible
OCSP responder.

=item SSL_OCSP_FULL_CHAIN

This will set up the C<ocsp_resolver> so that all certificates from the peer
chain will be checked, otherwise only the leaf certificate will be checked
against revocation.

=back

=item SSL_ocsp_staple_callback

If this callback is defined, it will be called with the SSL object and the OCSP
response handle obtained from the peer, e.g. C<<$cb->($ssl,$resp)>>.
If the peer did not provide a stapled OCSP response the function will be called
with C<$resp=undef>. 
Because the OCSP response handle is no longer valid after leaving this function
it should not by copied or freed. If access to the response is necessary after
leaving this function it can be serialized with
L<Net::SSLeay::i2d_OCSP_RESPONSE>.

If no such callback is provided, it will use the default one, which verifies the
response and uses it to check if the certificate(s) of the connection got
revoked.

=item SSL_ocsp_cache

With this option a cache can be given for caching OCSP responses, which could
be shared between different SSL contextes. If not given a cache specific to the
SSL context only will be used.

You can either create a new cache with
C<<IO::Socket::SSL::OCSP_Cache->new([size]) >> or implement your own cache,
which needs to have methods C<put($key,\%entry)> and C<get($key)->\%entry>
where entry is the hash representation of the OCSP response with fields like
C<nextUpdate>. The default implementation of the cache will consider responses
valid as long as C<nextUpdate> is less then the current time.

=item SSL_reuse_ctx

If you have already set the above options for a previous instance of
IO::Socket::SSL, then you can reuse the SSL context of that instance by passing
it as the value for the SSL_reuse_ctx parameter.  You may also create a
new instance of the IO::Socket::SSL::SSL_Context class, using any context options
that you desire without specifying connection options, and pass that here instead.

If you use this option, all other context-related options that you pass
in the same call to new() will be ignored unless the context supplied was invalid.
Note that, contrary to versions of IO::Socket::SSL below v0.90, a global SSL context
will not be implicitly used unless you use the set_default_context() function.

=item SSL_create_ctx_callback

With this callback you can make individual settings to the context after it
got created and the default setup was done.
The callback will be called with the CTX object from Net::SSLeay as the single
argument.

Example for limiting the server session cache size:

  SSL_create_ctx_callback => sub {
      my $ctx = shift;
      Net::SSLeay::CTX_sess_set_cache_size($ctx,128);
  }

=item SSL_session_cache_size

If you make repeated connections to the same host/port and the SSL renegotiation time
is an issue, you can turn on client-side session caching with this option by specifying a
positive cache size.  For successive connections, pass the SSL_reuse_ctx option to
the new() calls (or use set_default_context()) to make use of the cached sessions.
The session cache size refers to the number of unique host/port pairs that can be
stored at one time; the oldest sessions in the cache will be removed if new ones are
added.

This option does not effect the session cache a server has for it's clients, e.g. it
does not affect SSL objects with SSL_server set.

=item SSL_session_cache

Specifies session cache object which should be used instead of creating a new.
Overrules SSL_session_cache_size.
This option is useful if you want to reuse the cache, but not the rest of
the context.

A session cache object can be created using
C<< IO::Socket::SSL::Session_Cache->new( cachesize ) >>.

Use set_default_session_cache() to set a global cache object.

=item SSL_session_key

Specifies a key to use for lookups and inserts into client-side session cache.
Per default ip:port of destination will be used, but sometimes you want to
share the same session over multiple ports on the same server (like with FTPS).

=item SSL_session_id_context

This gives an id for the servers session cache. It's necessary if you want
clients to connect with a client certificate. If not given but SSL_verify_mode
specifies the need for client certificate a context unique id will be picked.

=item SSL_error_trap

When using the accept() or connect() methods, it may be the case that the
actual socket connection works but the SSL negotiation fails, as in the case of
an HTTP client connecting to an HTTPS server.  Passing a subroutine ref attached
to this parameter allows you to gain control of the orphaned socket instead of having it
be closed forcibly.	 The subroutine, if called, will be passed two parameters:
a reference to the socket on which the SSL negotiation failed and the full
text of the error message.

=item SSL_npn_protocols

If used on the server side it specifies list of protocols advertised by SSL
server as an array ref, e.g. ['spdy/2','http1.1'].
On the client side it specifies the protocols offered by the client for NPN
as an array ref.
See also method L<next_proto_negotiated>.

Next Protocol Negotioation (NPN) is available with Net::SSLeay 1.46+ and openssl-1.0.1+.
To check support you might call C<IO::Socket::SSL->can_npn()>.
If you use this option with an unsupported Net::SSLeay/OpenSSL it will
throw an error.

=back

=item B<accept>

This behaves similar to the accept function of the underlying socket class, but
additionally does the initial SSL handshake. But because the underlying socket
class does return a blocking file handle even when accept is called on a
non-blocking socket, the SSL handshake on the new file object will be done in a
blocking way. Please see the section about non-blocking I/O for details.
If you don't like this behavior you should do accept on the TCP socket and then
upgrade it with C<start_SSL> later.

=item B<connect(...)>

This behaves similar to the connnect function but also does an SSL handshake.
Because you cannot give SSL specific arguments to this function, you should
better either use C<new> to create a connect SSL socket or C<start_SSL> to
upgrade an established TCP socket to SSL.

=item B<close(...)>

There are a number of nasty traps that lie in wait if you are not careful about using
close().  The first of these will bite you if you have been using shutdown() on your
sockets.  Since the SSL protocol mandates that a SSL "close notify" message be
sent before the socket is closed, a shutdown() that closes the socket's write channel
will cause the close() call to hang.  For a similar reason, if you try to close a
copy of a socket (as in a forking server) you will affect the original socket as well.
To get around these problems, call close with an object-oriented syntax
(e.g. $socket->close(SSL_no_shutdown => 1))
and one or more of the following parameters:

=over 2

=item SSL_no_shutdown

If set to a true value, this option will make close() not use the SSL_shutdown() call
on the socket in question so that the close operation can complete without problems
if you have used shutdown() or are working on a copy of a socket.

Not using a real ssl shutdown on a socket will make session caching unusable.

=item SSL_fast_shutdown

If set to true only a unidirectional shutdown will be done, e.g. only the
close_notify (see SSL_shutdown(3)) will be sent. Otherwise a bidirectional
shutdown will be done where it waits for the close_notify of the peer too.

Because a unidirectional shutdown is enough to keep session cache working it
defaults to fast shutdown inside close.

=item SSL_ctx_free

If you want to make sure that the SSL context of the socket is destroyed when
you close it, set this option to a true value.

=back

=item B<sysread( BUF, LEN, [ OFFSET ] )>

This function behaves from the outside the same as B<sysread> in other
L<IO::Socket> objects, e.g. it returns at most LEN bytes of data.
But in reality it reads not only LEN bytes from the underlying socket, but at
a single SSL frame. It then returns up to LEN bytes it decrypted from this SSL
frame. If the frame contained more data than requested it will return only LEN
data, buffer the rest and return it on further read calls.
This means, that it might be possible to read data, even if the underlying
socket is not readable, so using poll or select might not be sufficient.

sysread will only return data from a single SSL frame, e.g. either the pending
data from the already buffered frame or it will read a frame from the underlying
socket and return the decrypted data. It will not return data spanning several
SSL frames in a single call.

Also, calls to sysread might fail, because it must first finish an SSL
handshake.

To understand these behaviors is essential, if you write applications which use
event loops and/or non-blocking sockets. Please read the specific sections in
this documentation.

=item B<syswrite( BUF, [ LEN, [ OFFSET ]] )>

This functions behaves from the outside the same as B<syswrite> in other
L<IO::Socket> objects, e.g. it will write at most LEN bytes to the socket, but
there is no guarantee, that all LEN bytes are written. It will return the number
of bytes written.
syswrite will write all the data within a single SSL frame, which means, that
no more than 16.384 bytes, which is the maximum size of an SSL frame, can be
written at once.

For non-blocking sockets SSL specific behavior applies.
Pease read the specific section in this documentation.

=item B<peek( BUF, LEN, [ OFFSET ])>

This function has exactly the same syntax as B<sysread>, and performs nearly the
same task but will not advance the read position so that successive calls to
peek() with the same arguments will return the same results.  This function
requires OpenSSL 0.9.6a or later to work.

=item B<pending()>

This function gives you the number of bytes available without reading from the
underlying socket object. This function is essential if you work with event
loops, please see the section about polling SSL sockets.

=item B<get_fingerprint([algo])>

This methods returns the fingerprint of the peer certificate in the form
C<algo$digest_hex>, where C<algo> is the used algorithm, default 'sha256'.

=item B<get_fingerprint_bin([algo])>

This methods returns the binary fingerprint of the peer certificate by using the
algorithm C<algo>, default 'sha256'.

=item B<get_cipher()>

Returns the string form of the cipher that the IO::Socket::SSL object is using.

=item B<get_sslversion()>

Returns the string representation of the SSL version of an established
connection.

=item B<get_sslversion_int()>

Returns the integer representation of the SSL version of an established
connection.

=item B<dump_peer_certificate()>

Returns a parsable string with select fields from the peer SSL certificate.	 This
method directly returns the result of the dump_peer_certificate() method of Net::SSLeay.

=item B<peer_certificate($field)>

If a peer certificate exists, this function can retrieve values from it.
If no field is given the internal representation of certificate from Net::SSLeay is
returned.
The following fields can be queried:

=over 8

=item authority (alias issuer)

The certificate authority which signed the certificate.

=item owner (alias subject)

The owner of the certificate.

=item commonName (alias cn) - only for Net::SSLeay version >=1.30

The common name, usually the server name for SSL certificates.

=item subjectAltNames - only for Net::SSLeay version >=1.33

Alternative names for the subject, usually different names for the same
server, like example.org, example.com, *.example.com.

It returns a list of (typ,value) with typ GEN_DNS, GEN_IPADD etc (these
constants are exported from IO::Socket::SSL).
See Net::SSLeay::X509_get_subjectAltNames.

=back

=item B<peer_certificates>

This returns all the certificates send by the peer, e.g. first the peers own
certificate and then the rest of the chain. You might use B<CERT_asHash> from
L<IO::Socket::SSL::Utils> to inspect each of the certificates.

This function depends on a version of Net::SSLeay >= 1.58 .

=item B<get_servername>

This gives the name requested by the client if Server Name Indication
(SNI) was used.

=item B<verify_hostname($hostname,$scheme,$publicsuffix)>

This verifies the given hostname against the peer certificate using the
given scheme. Hostname is usually what you specify within the PeerAddr.
See the C<SSL_verifycn_publicsuffix> parameter for an explanation of suffix
checking and for the possible values.

Verification of hostname against a certificate is different between various
applications and RFCs. Some scheme allow wildcards for hostnames, some only
in subjectAltNames, and even their different wildcard schemes are possible.
RFC 6125 provides a good overview.

To ease the verification the following schemes are predefined (both protocol
name and rfcXXXX name can be used):

=over 8

=item rfc2818, xmpp (rfc3920), ftp (rfc4217)

Extended wildcards in subjectAltNames and common name are possible, e.g.
*.example.org or even www*.example.org. The common
name will be only checked if no DNS names are given in subjectAltNames.

=item http (alias www)

While name checking is defined in rfc2818 the current browsers usually accept
also an IP address (w/o wildcards) within the common name as long as no
subjectAltNames are defined. Thus this is rfc2818 extended with this feature.


=item smtp (rfc2595), imap, pop3, acap (rfc4642), netconf (rfc5538), syslog (rfc5425), snmp (rfc5953)

Simple wildcards in subjectAltNames are possible, e.g. *.example.org matches
www.example.org but not lala.www.example.org. If nothing from subjectAltNames
match it checks against the common name, where wildcards are also allowed to
match the full leftmost label.

=item ldap (rfc4513)

Simple wildcards are allowed in subjectAltNames, but not in common name.
Common name will be checked even if subjectAltNames exist.

=item sip (rfc5922)

No wildcards are allowed and common name is checked even if subjectAltNames
exist.

=item gist (rfc5971)

Simple wildcards are allowed in subjectAltNames and common name, but common name
will only be checked if their are no DNS names in subjectAltNames.

=item default

This is a superset of all the rules and is automatically used if no scheme is
given but a hostname (instead of IP) is known.
Extended wildcards are allowed in subjectAltNames and common name and common
name is checked always.

=item none

No verification will be done.
Actually is does not make any sense to call verify_hostname in this case.

=back

The scheme can be given either by specifying the name for one of the above predefined
schemes, or by using a hash which can have the following keys and values:

=over 8

=item check_cn:  0|'always'|'when_only'

Determines if the common name gets checked. If 'always' it will always be checked
(like in ldap), if 'when_only' it will only be checked if no names are given in
subjectAltNames (like in http), for any other values the common name will not be checked.

=item wildcards_in_alt: 0|'full_label'|'anywhere'

Determines if and where wildcards in subjectAltNames are possible. If 'full_label'
only cases like *.example.org will be possible (like in ldap), for 'anywhere'
www*.example.org is possible too (like http), dangerous things like but www.*.org
or even '*' will not be allowed.
For compatibility with older versions 'leftmost' can be given instead of
'full_label'.

=item wildcards_in_cn: 0|'full_label'|'anywhere'

Similar to wildcards_in_alt, but checks the common name. There is no predefined
scheme which allows wildcards in common names.

=item ip_in_cn: 0|1|4|6

Determines if an IP address is allowed in the common name (no wildcards are
allowed). If set to 4 or 6 it only allows IPv4 or IPv6 addresses, any other
true value allows both.

=item callback: \&coderef

If you give a subroutine for verification it will be called with the arguments
($hostname,$commonName,@subjectAltNames), where hostname is the name given for
verification, commonName is the result from peer_certificate('cn') and
subjectAltNames is the result from peer_certificate('subjectAltNames').

All other arguments for the verification scheme will be ignored in this case.

=back

=item B<next_proto_negotiated()>

This method returns the name of negotiated protocol - e.g. 'http/1.1'. It works
for both client and server side of SSL connection.

NPN support is available with Net::SSLeay 1.46+ and openssl-1.0.1+.
To check support you might call C<IO::Socket::SSL->can_npn()>.

=item B<errstr()>

Returns the last error (in string form) that occurred.	If you do not have a real
object to perform this method on, call IO::Socket::SSL::errstr() instead.

For read and write errors on non-blocking sockets, this method may include the string
C<SSL wants a read first!> or C<SSL wants a write first!> meaning that the other side
is expecting to read from or write to the socket and wants to be satisfied before you
get to do anything. But with version 0.98 you are better comparing the global exported
variable $SSL_ERROR against the exported symbols SSL_WANT_READ and SSL_WANT_WRITE.

=item B<opened()>

This returns false if the socket could not be opened, 1 if the socket could be opened
and the SSL handshake was successful done and -1 if the underlying IO::Handle is open,
but the SSL handshake failed.

=item B<< IO::Socket::SSL->start_SSL($socket, ... ) >>

This will convert a glob reference or a socket that you provide to an IO::Socket::SSL
object.	 You may also pass parameters to specify context or connection options as with
a call to new().  If you are using this function on an accept()ed socket, you must
set the parameter "SSL_server" to 1, i.e. IO::Socket::SSL->start_SSL($socket, SSL_server => 1).
If you have a class that inherits from IO::Socket::SSL and you want the $socket to be blessed
into your own class instead, use MyClass->start_SSL($socket) to achieve the desired effect.

Note that if start_SSL() fails in SSL negotiation, $socket will remain blessed in its
original class.	 For non-blocking sockets you better just upgrade the socket to
IO::Socket::SSL and call accept_SSL or connect_SSL and the upgraded object. To
just upgrade the socket set B<SSL_startHandshake> explicitly to 0. If you call start_SSL
w/o this parameter it will revert to blocking behavior for accept_SSL and connect_SSL.

If given the parameter "Timeout" it will stop if after the timeout no SSL connection
was established. This parameter is only used for blocking sockets, if it is not given the
default Timeout from the underlying IO::Socket will be used.

=item B<stop_SSL(...)>

This is the opposite of start_SSL(), e.g. it will shutdown the SSL connection
and return to the class before start_SSL(). It gets the same arguments as close(),
in fact close() calls stop_SSL() (but without downgrading the class).

Will return true if it succeeded and undef if failed. This might be the case for
non-blocking sockets. In this case $! is set to EAGAIN and the ssl error to
SSL_WANT_READ or SSL_WANT_WRITE. In this case the call should be retried again with
the same arguments once the socket is ready.

For calling from C<stop_SSL> C<SSL_fast_shutdown> default to false, e.g. it
waits for the close_notify of the peer. This is necesarry in case you want to
downgrade the socket and continue to use it as a plain socket.

=item B<ocsp_resolver>

This will create an OCSP resolver object, which can be used to create OCSP
requests for the certificates of the SSL connection. Which certificates are
verified depends on the setting of C<SSL_ocsp_mode>: by default only the leaf
certificate will be checked, but with SSL_OCSP_FULL_CHAIN all chain
certificates will be checked.

Because to create an OCSP request the certificate and its issuer certificate
need to be known it is not possible to check certificates when the trust chain
is incomplete or if the certificate is self-signed.

The OCSP resolver gets created by calling C<$ssl->ocsp_resolver> and provides
the following methods:

=over 8

=item hard_error

This returns the hard error when checking the OCSP response.
Hard errors are certificate revocations. With the C<SSL_ocsp_mode> of
SSL_OCSP_FAIL_HARD any soft error (e.g. failures to get signed information
about the certificates) will be considered a hard error too.

The OCSP resolving will stop on the first hard error.

The method will return undef as long as no hard errors occured and still
requests to be resolved. If all requests got resolved and no hard errors
occured the method will return C<''>.

=item soft_error

This returns the soft error(s) which occured when asking the OCSP responders.

=item requests

This will return a hash consisting of C<(url,request)>-tuples, e.g. which
contain the OCSP request string and the URL where it should be sent too. The
usual way to send such a request is as HTTP POST request with an content-type
of C<application/ocsp-request> or as a GET request with the base64 and
url-encoded request is added to the path of the URL.

After you've handled all these requests and added the response with
C<add_response> you should better call this method again to make sure, that no
more requests are outstanding. IO::Socket::SSL will combine multiple OCSP
requests for the same server inside a single request, but some server don't
give an response to all these requests, so that one has to ask again with the
remaining requests.

=item add_response($uri,$response)

This method takes the HTTP body of the response which got received when sending
the OCSP request to C<$uri>. If no response was received or an error occured
one should either retry or consider C<$response> as empty which will trigger a
soft error. 

The method returns the current value of C<hard_error>, e.g. a defined value
when no more requests need to be done.

=item resolve_blocking(%args)

This combines C<requests> and C<add_response> which L<HTTP::Tiny> to do all
necessary requests in a blocking way. C<%args> will be given to L<HTTP::Tiny>
so that you can put proxy settings etc here. L<HTTP::Tiny> will be called with
C<verify_SSL> of false, because the OCSP responses have their own signatures so
no extra SSL verification is needed.

If you don't want to use blocking requests you need to roll your own user agent
with C<requests> and C<add_response>.

=back

=item B<< IO::Socket::SSL->new_from_fd($fd, [mode], %sslargs) >>

This will convert a socket identified via a file descriptor into an SSL socket.
Note that the argument list does not include a "MODE" argument; if you supply one,
it will be thoughtfully ignored (for compatibility with IO::Socket::INET). Instead,
a mode of '+<' is assumed, and the file descriptor passed must be able to handle such
I/O because the initial SSL handshake requires bidirectional communication.

Internally the given $fd will be upgraded to a socket object using the
C<new_from_fd> method of the super class (L<IO::Socket::INET> or similar) and then
C<start_SSL> will be called using the given C<%sslargs>.
If C<$fd> is already an IO::Socket object you should better call C<start_SSL>
directly.

=item B<IO::Socket::SSL::default_ca([ path|dir| SSL_ca_file => ..., SSL_ca_path => ... ])>

Determines or sets the default CA path.
If existing path or dir or a hash is given it will set the default CA path to
this value and never try to detect it automatically.
If C<undef> is given it will forget any stored defaults and continue with
detection of system defaults.
If no arguments are given it will start detection of system defaults, unless it
has already stored user-set or previously detected values.

The detection of system defaults works similar to OpenSSL, e.g. it will check
the directory specified in environment variable SSL_CERT_DIR or the path
OPENSSLDIR/certs (SSLCERTS: on VMS) and the file specified in environment
variable SSL_CERT_FILE or the path OPENSSLDIR/cert.pem (SSLCERTS:cert.pem on
VMS). Contrary to OpenSSL it will check if the SSL_ca_path contains PEM files
with the hash as file name and if the SSL_ca_file looks like PEM.
If no usable system default can be found it will try to load and use
L<Mozilla::CA> and if not available give up detection.
The result of the detection will be saved to speed up future calls.

The function returns the saved default CA as hash with SSL_ca_file and
SSL_ca_path.

=item B<IO::Socket::SSL::set_default_context(...)>

You may use this to make IO::Socket::SSL automatically re-use a given context (unless
specifically overridden in a call to new()).  It accepts one argument, which should
be either an IO::Socket::SSL object or an IO::Socket::SSL::SSL_Context object.	See
the SSL_reuse_ctx option of new() for more details.	 Note that this sets the default
context globally, so use with caution (esp. in mod_perl scripts).

=item B<IO::Socket::SSL::set_default_session_cache(...)>

You may use this to make IO::Socket::SSL automatically re-use a given session cache
(unless specifically overridden in a call to new()).  It accepts one argument, which should
be an IO::Socket::SSL::Session_Cache object or similar (e.g something which implements
get_session and add_session like IO::Socket::SSL::Session_Cache does).
See the SSL_session_cache option of new() for more details.	 Note that this sets the default
cache globally, so use with caution.

=item B<IO::Socket::SSL::set_defaults(%args)>

With this function one can set defaults for all SSL_* parameter used for creation of
the context, like the SSL_verify* parameter. Any SSL_* parameter can be given
or the following short versions:

=over 8

=item mode - SSL_verify_mode

=item callback - SSL_verify_callback

=item scheme - SSL_verifycn_scheme

=item name - SSL_verifycn_name

=back

=item B<IO::Socket::SSL::set_client_defaults(%args)>

Similar to C<set_defaults>, but only sets the defaults for client mode.

=item B<IO::Socket::SSL::set_server_defaults(%args)>

Similar to C<set_defaults>, but only sets the defaults for server mode.

=item B<IO::Socket::SSL::set_args_filter_hack(\&code|'use_defaults')>

Sometimes one has to use code which uses unwanted or invalid arguments for SSL,
typically disabling SSL verification or setting wrong ciphers or SSL versions.
With this hack it is possible to override these settings and restore sanity.
Example:

    IO::Socket::SSL::set_args_filter_hack( sub {
	my ($is_server,$args) = @_;
	if ( ! $is_server ) {
	    # client settings - enable verification with default CA
	    # and fallback hostname verification etc
	    delete @{$args}{qw(
		SSL_verify_mode
		SSL_ca_file
		SSL_ca_path
		SSL_verifycn_scheme
		SSL_version
	    )};
	    # and add some fingerprints for known certs which are signed by
	    # unknown CAs or are self-signed
	    $args->{SSL_fingerprint} = ...
	}
    });

With the short setting C<set_args_filter_hack('use_defaults')> it will prefer
the default settings in all cases. These default settings can be modified with
C<set_defaults>, C<set_client_defaults> and C<set_server_defaults>.

=back

The following methods are unsupported (not to mention futile!) and IO::Socket::SSL
will emit a large CROAK() if you are silly enough to use them:

=over 4

=item truncate

=item stat

=item ungetc

=item setbuf

=item setvbuf

=item fdopen

=item send/recv

Note that send() and recv() cannot be reliably trapped by a tied filehandle (such as
that used by IO::Socket::SSL) and so may send unencrypted data over the socket.	 Object-oriented
calls to these functions will fail, telling you to use the print/printf/syswrite
and read/sysread families instead.

=back


=head1 ERROR HANDLING

If an SSL specific error occurs the global variable C<$SSL_ERROR> will be set.
If the error occurred on an existing SSL socket the method C<errstr> will
give access to the latest socket specific error.
Both C<$SSL_ERROR> and C<errstr> method give a dualvar similar to C<$!>, e.g.
providing an error number in numeric context or an error description in string
context.

=head1 Polling of SSL Sockets (e.g. select, poll and other event loops)

If you sysread one byte on a normal socket it will result in a syscall to read
one byte. Thus, if more than one byte is available on the socket it will be kept
in the network stack of your OS and the next select or poll call will return the
socket as readable.
But, with SSL you don't deliver single bytes. Multiple data bytes are packet
and encrypted together in an SSL frame. Decryption can only be done on the whole
frame, so a sysread for one byte actually reads the complete SSL frame from the
socket, decrypts it and returns the first decrypted byte. Further sysreads will
return more bytes from the same frame until all bytes are returned and the
next SSL frame will be read from the socket.

Thus, in order to decide if you can read more data (e.g. if sysread will block)
you must check, if there are still data in the current SSL frame by calling
C<pending> and if there are no data pending you might check the underlying
socket with select or poll.
Another way might be if you try to sysread at least 16k all the time. 16k is the
maximum size of an SSL frame and because sysread returns data from only a single
SSL frame you guarantee this way, that there are no pending data.
Please see the example on top of this documentation on how to use SSL within a
select loop.

=head1 Non-blocking I/O

If you have a non-blocking socket, the expected behavior on read, write, accept
or connect is to set C<$!> to EAGAIN if the operation can not be completed
immediately.

With SSL handshakes might occure at any time, even within an established
connections. In this cases it is necessary to finish the handshake, before
you can read or write data. This might result in situations, where you want to
read but must first finish the write of a handshake or where you want to write
but must first finish a read.
In these cases C<$!> is set to EGAIN like expected, and additionally
C<$SSL_ERROR> is set to either SSL_WANT_READ or SSL_WANT_WRITE.
Thus if you get EAGAIN on a SSL socket you must check C<$SSL_ERROR> for
SSL_WANT_* and adapt your event mask accordingly.

Using readline on non-blocking sockets does not make much sense and I would
advise against using it.
And, while the behavior is not documented for other L<IO::Socket> classes, it
will try to emulate the behavior seen there, e.g. to return the received data
instead of blocking, even if the line is not complete. If an unrecoverable error
occurs it will return nothing, even if it already received some data.

Also, I would advise against using C<accept> with a non-blocking SSL object,
because it might block and this is not what most would expect. The reason for
this is that accept on a non-blocking TCP socket (e.g. IO::Socket::IP,
IO::Socket::INET..) results in a new TCP socket, which does not inherit the
non-blocking behavior of the master socket. And thus the initial SSL handshake
on the new socket inside C<IO::Socket::SSL::accept> will be done in a blocking
way. To work around it you should better do an TCP accept and later upgrade the
TCP socket in a non-blocking way with C<start_SSL> and C<accept_SSL>.

=head1 SNI Support

Newer extensions to SSL can distinguish between multiple hostnames on the same
IP address using Server Name Indication (SNI).

Support for SNI on the client side was added somewhere in the OpenSSL 0.9.8
series, but only with 1.0 a bug was fixed when the server could not decide about
its hostname. Therefore client side SNI is only supported with OpenSSL 1.0 or
higher in L<IO::Socket::SSL>.
With a supported version, SNI is used automatically on the client side, if it can
determine the hostname from C<PeerAddr> or C<PeerHost>. On unsupported OpenSSL
versions it will silently not use SNI.
The hostname can also be given explicitly given with C<SSL_hostname>, but in
this case it will throw in error, if SNI is not supported.
To check for support you might call C<IO::Socket::SSL->can_client_sni()>.

On the server side earlier versions of OpenSSL are supported, but only together
with L<Net::SSLeay> version >= 1.50.
To check for support you might call C<IO::Socket::SSL->can_server_sni()>.
If server side SNI is supported, you might specify different certificates per
host with C<SSL_cert*> and C<SSL_key*>, and check the requested name using
C<get_servername>.

=head1 RETURN VALUES

A few changes have gone into IO::Socket::SSL v0.93 and later with respect to
return values.	The behavior on success remains unchanged, but for I<all> functions,
the return value on error is now an empty list.	 Therefore, the return value will be
false in all contexts, but those who have been using the return values as arguments
to subroutines (like C<mysub(IO::Socket::SSL(...)->new, ...)>) may run into problems.
The moral of the story: I<always> check the return values of these functions before
using them in any way that you consider meaningful.


=head1 DEBUGGING

If you are having problems using IO::Socket::SSL despite the fact that can recite backwards
the section of this documentation labelled 'Using SSL', you should try enabling debugging.	To
specify the debug level, pass 'debug#' (where # is a number from 0 to 3) to IO::Socket::SSL
when calling it.
The debug level will also be propagated to Net::SSLeay::trace, see also L<Net::SSLeay>:

=over 4

=item use IO::Socket::SSL qw(debug0);

No debugging (default).

=item use IO::Socket::SSL qw(debug1);

Print out errors from IO::Socket::SSL and ciphers from Net::SSLeay.

=item use IO::Socket::SSL qw(debug2);

Print also information about call flow from IO::Socket::SSL and progress
information from Net::SSLeay.

=item use IO::Socket::SSL qw(debug3);

Print also some data dumps from IO::Socket::SSL and from Net::SSLeay.

=back

=head1 EXAMPLES

See the 'example' directory.

=head1 BUGS

IO::Socket::SSL depends on Net::SSLeay.  Up to version 1.43 of Net::SSLeay
it was not thread safe, although it did probably work if you did not use
SSL_verify_callback and SSL_password_cb.

If you use IO::Socket::SSL together with threads you should load it (e.g. use or
require) inside the main thread before creating any other threads which use it.
This way it is much faster because it will be initialized only once. Also there
are reports that it might crash the other way.

Creating an IO::Socket::SSL object in one thread and closing it in another
thread will not work.

IO::Socket::SSL does not work together with Storable::fd_retrieve/fd_store.
See BUGS file for more information and how to work around the problem.

Non-blocking and timeouts (which are based on non-blocking) are not
supported on Win32, because the underlying IO::Socket::INET does not support
non-blocking on this platform.

If you have a server and it looks like you have a memory leak you might
check the size of your session cache. Default for Net::SSLeay seems to be
20480, see the example for SSL_create_ctx_callback for how to limit it.

The default for SSL_verify_mode on the client is currently SSL_VERIFY_NONE,
which is a very bad idea, thus the default will change in the near future.
See documentation for SSL_verify_mode for more information.

=head1 LIMITATIONS

IO::Socket::SSL uses Net::SSLeay as the shiny interface to OpenSSL, which is
the shiny interface to the ugliness of SSL.	 As a result, you will need both Net::SSLeay
and OpenSSL on your computer before using this module.

If you have Scalar::Util (standard with Perl 5.8.0 and above) or WeakRef, IO::Socket::SSL
sockets will auto-close when they go out of scope, just like IO::Socket::INET sockets.	If
you do not have one of these modules, then IO::Socket::SSL sockets will stay open until the
program ends or you explicitly close them.	This is due to the fact that a circular reference
is required to make IO::Socket::SSL sockets act simultaneously like objects and glob references.

=head1 DEPRECATIONS

The following functions are deprecated and are only retained for compatibility:

=over 2

=item context_init()

use the SSL_reuse_ctx option if you want to re-use a context


=item socketToSSL() and socket_to_SSL()

use IO::Socket::SSL->start_SSL() instead

=item kill_socket()

use close() instead

=item get_peer_certificate()

use the peer_certificate() function instead.
Used to return X509_Certificate with methods subject_name and issuer_name.
Now simply returns $self which has these methods (although deprecated).

=item issuer_name()

use peer_certificate( 'issuer' ) instead

=item subject_name()

use peer_certificate( 'subject' ) instead

=back

=head1 SEE ALSO

IO::Socket::INET, IO::Socket::INET6, IO::Socket::IP, Net::SSLeay.

=head1 AUTHORS

Steffen Ullrich, <steffen at genua.de> is the current maintainer.

Peter Behroozi, <behrooz at fas.harvard.edu> (Note the lack of an "i" at the end of "behrooz")

Marko Asplund, <marko.asplund at kronodoc.fi>, was the original author of IO::Socket::SSL.

Patches incorporated from various people, see file Changes.

=head1 COPYRIGHT

The original versions of this module are Copyright (C) 1999-2002 Marko Asplund.

The rewrite of this module is Copyright (C) 2002-2005 Peter Behroozi.

Versions 0.98 and newer are Copyright (C) 2006-2013 Steffen Ullrich.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.


=head1 Appendix: Using SSL

If you are unfamiliar with the way OpenSSL works, good references may be found in
both the book "Network Security with OpenSSL" (Oreilly & Assoc.) and the web site
L<http://www.tldp.org/HOWTO/SSL-Certificates-HOWTO/>.  Read on for a quick overview.

=head2 The Long of It (Detail)

The usual reason for using SSL is to keep your data safe.  This means that not only
do you have to encrypt the data while it is being transported over a network, but
you also have to make sure that the right person gets the data, e.g. you need to
authenticate the person.
To accomplish this with SSL, you have to use certificates.
A certificate closely resembles a Government-issued ID (at least in places where
you can trust them). The ID contains some sort of identifying information such
as a name and address, and is usually stamped with a seal of Government
Approval. Theoretically, this means that you may trust the information on the
card and do business with the owner of the card.
The same ideas apply to SSL certificates, which have some identifying
information and are "stamped" (signed) by someone (a CA, e.g. Certificate
Authority) who you trust will adequately verify the identifying information. In
this case, because of some clever number theory, it is extremely difficult to
falsify the signing process. Another useful consequence of number theory is that
the certificate is linked to the encryption process, so you may encrypt data
(using information on the certificate) that only the certificate owner can
decrypt.

What does this mean for you?
So most common case is that at least the server has a certificate which the
client can verify, but the server may also ask back for a certificate to
authenticate the client.
To verify that a certificate is trusted, one checks if the certificate is signed
by the expected CA (Certificate Authority), which often means any CA installed
on the system (IO::Socket::SSL tries to use the CAs installed on the system by
default). So if you trust the CA, trust the number theory and trust the
used algorithms you can be confident, that no-one is reading your data.

Beside the authentication using certificates there is also anonymous
authentication, which effectivly means no authentication. In this case it is
easy for somebody in between to intercept the connection, e.g. playing man in
the middle and nobody notices.
By default IO::Socket::SSL uses only ciphers which require certificates and
which are safe enough, but if you want to set your own cipher_list make sure,
that you explicitly exclude anonymous authentication. E.g. setting the cipher
list to HIGH is not enough, you should use at least HIGH:!aNULL.

=head2 The Short of It (Summary)

For servers, you will need to generate a cryptographic private key and a certificate
request.  You will need to send the certificate request to a Certificate Authority to
get a real certificate back, after which you can start serving people.	For clients,
you will not need anything unless the server wants validation, in which case you will
also need a private key and a real certificate.	 For more information about how to
get these, see L<http://www.modssl.org/docs/2.8/ssl_faq.html#ToC24>.

=cut
