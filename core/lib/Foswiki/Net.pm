# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Net

Object that brokers access to network resources.

=cut

# This module is used by configure, and as such must *not* 'use Foswiki',
# or any other module that uses it. Always run configure to test after
# changing the module.

package Foswiki::Net;

use strict;
use warnings;
use Assert;
use Error qw( :try );

use Foswiki::IP qw/:regexp :info $IPv6Avail/;

our $LWPAvailable;
our $noHTTPResponse;    # if set, forces local impl of HTTP::Response
our $SSLAvailable;      # Set to defined false to prevent using SSL

# note that the session is *optional*
sub new {
    my ( $class, $session ) = @_;
    my $this = bless( { session => $session }, $class );

    $this->{mailHandler} = undef;

    return $this;
}

=begin TML

---++ ObjectMethod finish()
Break circular references.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;
    undef $this->{mailHandler};
    undef $this->{HELLO_HOST};
    undef $this->{MAIL_HOST};
    undef $this->{session};
}

=begin TML

---+++ getExternalResource( $url ) -> $response

Get whatever is at the other end of a URL (using an HTTP GET request). Will
only work for encrypted protocols such as =https= if the =LWP= CPAN module is
installed.

Note that the =$url= may have an optional user and password, as specified by
the relevant RFC. Any proxy set in =configure= is honoured.

The =$response= is an object that is known to implement the following subset of
the methods of =LWP::Response=. It may in fact be an =LWP::Response= object,
but it may also not be if =LWP= is not available, so callers may only assume
the following subset of methods is available:
| =code()= |
| =message()= |
| =header($field)= |
| =content()= |
| =is_error()= |
| =is_redirect()= |

Note that if LWP is *not* available, this function:
   1 can only really be trusted for HTTP/1.0 urls. If HTTP/1.1 or another
     protocol is required, you are *strongly* recommended to =require LWP=.
   1 Will not parse multipart content
   1 Will not process redirects (configure relies on this)

In the event of the server returning an error, then =is_error()= will return
true, =code()= will return a valid HTTP status code
as specified in RFC 2616 and RFC 2518, and =message()= will return the
message that was received from
the server. In the event of a client-side error (e.g. an unparseable URL)
then =is_error()= will return true and =message()= will return an explanatory
message. =code()= will return 400 (BAD REQUEST).

Note: Callers can easily check the availability of other HTTP::Response methods
as follows:

<verbatim>
my $response = Foswiki::Func::getExternalResource($url);
if (!$response->is_error() && $response->isa('HTTP::Response')) {
    ... other methods of HTTP::Response may be called
} else {
    ... only the methods listed above may be called
}
</verbatim>

=cut

sub getExternalResource {
    my ( $this, $url ) = splice( @_, 0, 2 );

    my $protocol;
    if ( $url =~ m!^([a-z]+):! ) {
        $protocol = $1;
    }
    else {
        require Foswiki::Net::HTTPResponse;
        return new Foswiki::Net::HTTPResponse("Bad URL: $url");
    }

    # Don't remove $LWPAvailable; it is required to disable LWP when unit
    # testing
    unless ( defined $LWPAvailable ) {
        eval 'require LWP';
        $LWPAvailable = ($@) ? 0 : 1;
    }
    if ($LWPAvailable) {
        return _GETUsingLWP( $this, $url, @_ );
    }

    # Fallback mechanism
    if ( $protocol ne 'http' ) {
        if ( $protocol eq 'https' && !defined $SSLAvailable ) {
            eval 'require IO::Socket::SSL';
            $SSLAvailable = $@ ? 0 : 1;
        }
        unless ( $protocol eq 'https' && $SSLAvailable ) {
            require Foswiki::Net::HTTPResponse;
            return new Foswiki::Net::HTTPResponse(
                "LWP not available for handling protocol: $url");
        }
    }

    my $response;
    my @headers = @_;
    try {
        $url =~ s!^\w+://!!;    # remove protocol
        my ( $user, $pass );
        if ( $url =~ s!([^/\@:]+)(?::([^/\@:]+))?@!! ) {
            ( $user, $pass ) = ( $1, $2 || '' );
        }

        unless ( $url =~ s!([^:/]+)(?::([0-9]+))?!! ) {
            die "Bad URL: $url";
        }
        my ( $host, $port ) = ( $1, $2 || ( $protocol eq 'https' ? 443 : 80 ) );

        my $sclass;
        eval {
            require IO::Socket::IP;
            $sclass = 'IO::Socket::IP';
        };
        if ($@) {
            require IO::Socket::INET;
            $sclass = 'IO::Socket::INET';
        }
        my @ssloptions;
        if ( $protocol eq 'https' ) {
            $sclass     = 'IO::Socket::SSL';
            @ssloptions = (
                SSL_hostname    => $host,
                SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE(),
            );
        }

        $url = '/' unless ($url);
        my $req = "GET $url HTTP/1.0\r\nHost: $host:$port\r\n";

        my ( $proxyHost, $proxyPort );
        $proxyHost = $this->{PROXYHOST} || $Foswiki::cfg{PROXY}{HOST};
        $proxyPort = $this->{PROXYPORT} || $Foswiki::cfg{PROXY}{PORT};
        if ( $proxyHost && $proxyPort ) {
            my ( $proxyProtocol, $proxyUser, $proxyPass );
            if ( $proxyHost =~
                m#^(https?)://(?:(.*?)(?::(.*?))?@)?(.*)(?::(\d+))?/*# )
            {
                $proxyProtocol = $1;
                $proxyUser     = $2;
                $proxyPass     = $3;
                $proxyHost     = $4;
                $proxyPort     = $5 if defined $5;
                if ( $proxyProtocol eq 'https' ) {
                    $proxyPort = 443 if ( !$proxyPort );
                    if ( !defined $SSLAvailable ) {
                        eval 'require IO::Socket::SSL';
                        $SSLAvailable = $@ ? 0 : 1;
                    }
                    $sclass = 'IO::Socket::SSL';
                }
                elsif ( !$proxyPort ) {
                    $proxyPort = 8080;
                }
            }
            if ( !defined $proxyProtocol
                || $proxyProtocol eq 'https' && !$SSLAvailable )
            {
                require Foswiki::Net::HTTPResponse;
                return new Foswiki::Net::HTTPResponse(
                    "Proxy settings are invalid, check configure ($proxyHost)");
            }
            $req      = "GET $protocol://$host:$port$url HTTP/1.0\r\n";
            $protocol = $proxyProtocol;
            $host     = $proxyHost;
            $port     = $proxyPort;
            if ($proxyUser) {
                require MIME::Base64;
                my $base64 =
                  MIME::Base64::encode_base64( "$proxyUser:$proxyPass", '' );
                $req .= "Proxy-Authorization: Basic $base64\n";
            }
        }
        if ($user) {
            require MIME::Base64;
            my $base64 = MIME::Base64::encode_base64( "$user:$pass", '' );
            $req .= "Authorization: Basic $base64\n";
        }

        $req .= 'User-Agent: Foswiki::Net/' . $Foswiki::VERSION . "\r\n";
        while (@headers) {
            my ( $name, $value ) = splice( @headers, 0, 2 );
            $name =~ s/_/-/g;
            $req .= "$name: $value\r\n";
        }
        $req .= "\r\n";

        my $sock = $sclass->new(
            PeerAddr => $host,
            PeerPort => $port,
            Proto    => 'tcp',
            Timeout  => 120,
            @ssloptions,
        );
        unless ($sock) {
            die "Unable to connect to $host: $!"
              . ( @ssloptions ? ' - ' . IO::Socket::SSL::errstr() : '' ) . "\n";
        }
        $sock->autoflush(1);

        local $/ = undef;
        print $sock $req;
        my $result;
        $result = <$sock>;
        $result = '' unless ( defined $result );
        unless ( close($sock) ) {
            die "close failed: $!";
        }

        # No LWP, but may have HTTP::Response which would make life easier
        # (it has a much more thorough parser)
        eval 'require HTTP::Response' unless ($noHTTPResponse);
        if ( $@ || $noHTTPResponse ) {

            # Nope, no HTTP::Response, have to do things the hard way :-(
            require Foswiki::Net::HTTPResponse;
            $response = Foswiki::Net::HTTPResponse->parse($result);
        }
        else {
            $response = HTTP::Response->parse($result);
        }
    }
    catch Error::Simple with {
        require Foswiki::Net::HTTPResponse;
        $response = new Foswiki::Net::HTTPResponse(shift);
    };
    return $response;
}

sub _GETUsingLWP {
    my ( $this, $url ) = splice( @_, 0, 2 );

    my ( $user, $pass );
    if ( $url =~ s!([^/\@:]+)(?::([^/\@:]+))?@!! ) {
        ( $user, $pass ) = ( $1, $2 );
    }
    my $request;
    require HTTP::Request;
    $request = HTTP::Request->new( GET => $url );
    $request->header(
        'User-Agent' => 'Foswiki::Net/'
          . $Foswiki::VERSION
          . " libwww-perl/$LWP::VERSION",
        @_
    );
    require Foswiki::Net::UserCredAgent;
    my $ua = new Foswiki::Net::UserCredAgent( $user, $pass );
    my $response = $ua->request($request);
    return $response;
}

# Centralized logger for mail-related errors
#
# Logs at specified level to Foswiki logs
#  'die-level' (e.g. 'die-critical') will log at specified level
#  then die.  'die' defaults to 'error'.
#
# Respects {SMTP}{Debug}

sub _logMailError {
    my $this  = shift;
    my $level = shift;

    my $msg = join( '', @_ );
    chomp $msg;

    my $die;
    if ( $level eq 'die' ) {
        $die = $level = 'error';
    }
    elsif ( $level =~ s/^die-// ) {
        $die = 1;
    }

    if ( $Foswiki::cfg{SMTP}{Debug} ) {
        _throwMsg( $level, $msg ) if ($die);
        chomp $msg;
        $msg =~ s,\n,\n -- ,g;
        $msg = ucfirst($level) . ": $msg\n";
        print STDERR $msg;
        return;
    }
    my $logger;
    if ( $this->{session} ) {
        $logger = $this->{session}->logger;
    }
    else {
        $logger = $Foswiki::cfg{Log}{Implementation};
        if ($logger) {
            eval "require $logger;";
            die "Can't load $logger: $!\n" if ($@);
            $logger = $logger->new();
        }
    }
    if ($logger) {
        my $first = 1;
        foreach my $line ( split( /\n/, $msg ) ) {
            if ( $line =~ s/^Foswiki MAIL:// ) {
                $first = 1;
            }
            else {
                $line = " -- $line" unless ($first);
                undef $first;
            }
            $logger->log( $level, "MAIL $line" );
        }
    }
    else {
        print STDERR "MAIL " . uc($level) . " $msg\n";
    }

    _throwMsg( $level, $msg ) if ($die);
    return;
}

sub _throwMsg {
    my $level = shift;

    my $msg = '';
    my @lines = split( /\n/, $_[0] );

    foreach my $line (@lines) {
        next unless ( length $line );
        if ( length $msg ) {
            $msg .= " -- $line\n";
        }
        else {
            $msg = "Foswiki MAIL:" . uc($level) . ": $line\n";
        }
    }
    chomp $msg;
    die "$msg\n";
}

# pick a default mail handler
sub _installMailHandler {
    my $this    = shift;
    my $handler = 0;       # Not undef

    $this->{MAIL_HOST}  ||= $Foswiki::cfg{SMTP}{MAILHOST};
    $this->{HELLO_HOST} ||= $Foswiki::cfg{SMTP}{SENDERHOST};

    $this->{MAIL_METHOD} = $Foswiki::cfg{Email}{MailMethod};

    unless ( $this->{MAIL_METHOD} ) {
        $this->{MAIL_METHOD} = 'Net::SMTP' if ( $this->{MAIL_HOST} );
    }
    $this->{MAIL_METHOD} = 'Net::SMTP (SSL)'
      if ( $this->{MAIL_METHOD} eq 'Net::SMTP::SSL' );

    #_logMailError('debug', "Set MAIL_METHOD to ($this->{MAIL_METHOD})" );

    if (   $this->{MAIL_HOST}
        && $this->{MAIL_METHOD} ne 'MailProgram' )
    {

#_logMailError('debug', "Testing $this->{MAIL_HOST} with $this->{MAIL_METHOD}");

        # See Codev.RegisterFailureInsecureDependencyCygwin for why
        # this must be untainted
        # SMELL: That topic tells me nothing - AFAICT this untaint is not
        # required.

        $this->{MAIL_HOST} ||= '';
        $this->{MAIL_HOST} =~ /^(.*)$/;
        $this->{MAIL_HOST} = $1;

        $this->{MAIL_METHOD} =~ /^([\w:_()\s]+)$/ or    # Config or intruder
          die "Invalid {Email}{MailMethod} $this->{MAIL_METHOD}\n";
        $this->{MAIL_METHOD} = $1;

        require Foswiki::IP;
        eval {
            require Net::SMTP;
            @Net::SMTP::ISA = (
                grep( $_ !~ /^IO::Socket::I(?:NET|P)$/, @Net::SMTP::ISA ),
                'IO::Socket::IP'
            ) if ($Foswiki::IP::IPv6Avail);

            require IO::Socket::SSL
              if ( $this->{MAIL_METHOD} =~ /\((?:TLS|SSL|STARTTLS)\)/ );
        };
        if ($@) {
            $this->_logMailError( 'error', "Failed to load module: $@" );
        }
        else {
            $handler = \&_sendEmailByNetSMTP;

          #_logMailError('debug', "Set EMAIL HANDLER to $this->{MAIL_METHOD}" );
        }
    }

    if ( !$handler && $Foswiki::cfg{MailProgram} ) {
        $handler = \&_sendEmailBySendmail;

#_logMailError('debug', "Set EMAIL HANDLER to $this->{MAIL_METHOD} $Foswiki::cfg{MailProgram}" );
    }

    $this->setMailHandler($handler) if $handler;
}

=begin TML

---++ setMailHandler( \&fn )

   * =\&fn= - reference to a function($) (see _sendEmailBySendmail for proto)
Install a handler function to take over mail sending from the default
SMTP or sendmail methods. This is provided mainly for tests that
need to be told when a mail is sent, without actually sending it. It
may also be useful in the event that someone needs to plug in an
alternative mail handling method.

=cut

sub setMailHandler {
    my ( $this, $fnref ) = @_;
    $this->{mailHandler} = $fnref;
}

=begin TML

---++ ObjectMethod sendEmail ( $text, $retries ) -> $error

   * =$text= - text of the mail, including MIME headers
   * =$retries= - number of times to retry the send (default 1)

Send an email specified as MIME format content.
Date: ...\nFrom: ...\nTo: ...\nCC: ...\nSubject: ...\n\nMailBody...

=cut

sub sendEmail {
    my ( $this, $text, $retries ) = @_;
    $retries ||= 1;

    #_logMailError('debug', "sendEmail Entered");

    unless ( $Foswiki::cfg{EnableEmail} ) {
        return 'Can not send mail: Foswiki email is disabled';
    }

    unless ( defined $this->{mailHandler} ) {
        _installMailHandler($this);
    }

    return 'No mail handler available' unless $this->{mailHandler};

    # Put in a Date header, mainly for Qmail
    # Do NOT use Foswiki::Time, as it includes Foswiki, which
    # is bad for configure.  Use RFC822-compliant date, which
    # requires a US (or C) locale for time (e.g month and day of week names).

    require POSIX;
    POSIX->import(qw(locale_h));

    my $old_locale = POSIX::setlocale( LC_TIME() );
    POSIX::setlocale( LC_TIME(), 'C' );
    my $dateStr;
    if ( $Foswiki::cfg{Email}{Servertime} ) {
        $dateStr = POSIX::strftime( '%a, %d %b %Y %T %z', localtime(time) );
    }
    else {
        $dateStr = POSIX::strftime( '%a, %d %b %Y %T ', gmtime(time) ) . 'GMT';
    }
    setlocale( LC_TIME(), $old_locale );

    $text = "Date: " . $dateStr . "\n" . $text;
    my $errors   = '';
    my $back_off = 1;    # seconds, doubles on each retry
    my $try      = 0;
    while ( $retries-- ) {
        $try++;
        try {
            &{ $this->{mailHandler} }( $this, $text );
            $retries = 0;
        }
        catch Error::Simple with {
            my $msg = shift->stringify();
            ( my $to ) = $text =~ /^To:\s*(.*?)$/im;

            # Lines we threw are marked, already logged, and safe to return.
            # Unmarked lines came from SMTP or perl, and need to be logged.
            # They may reveal information about the installation, so they
            # are not returned to the user.

            my @lines = split( /\n/, $msg );
            ( $msg, my $log ) = ('') x 2;
            while (@lines) {
                my $line = shift @lines;
                if ( $line =~ s/^Foswiki MAIL:// ) {
                    $msg .= "$line\n";
                    while ( @lines && $lines[0] =~ /^ -- / ) {
                        $msg .= shift(@lines) . "\n";
                    }
                }
                else {
                    $log .= "$line\n";
                }
            }
            chomp $msg;
            unless ($msg) {

                # SMELL: maketext (but not in configure!)
                # and WIKIWEBMASTER is an email address

                $msg =
"Mail could not be sent to $to due to an unhandled error. Please contact %WIKIWEBMASTER%, who can obtain details from the Foswiki warning log.";
            }

            # Log any lines that we didn't generate.
            # Return those we did in the error message.

            $this->_logMailError( 'error', "Error sending email to $to\n$log" )
              if ($log);
            $errors .= "Sending email to $to\n$msg\n";
            if ($retries) {
                sleep($back_off);
                $back_off *= 2;
            }
            else {
                $errors .= "Stopped after $try attempt";
                $errors .= 's' if ( $try != 1 );
                $errors .= ".\n";
            }
        };
    }

    return $errors;
}

sub _fixLineLength {
    my ($addrs) = @_;

    # split up header lines that are too long
    $addrs =~ s/(.{60}[^,]*,\s*)/$1\n        /go;
    $addrs =~ s/\n\s*$//gos;
    return $addrs;
}

# Inhale an entire file (certificate, key)

sub _slurpFile( $$ ) {
    my $this = shift;
    my $file = shift;

    my $fh;
    unless ( open( $fh, '<', $file ) ) {
        $this->_logMailError( 'die', "Failed to open $file: $!\n" );
    }

    my $text = do { local ($/); <$fh> };

    unless ( close $fh ) {
        $this->_logMailError( 'die', "Failed to close $file: $!\n" );
    }

    return $text;
}

# =======================================
# Sign & replace message text

sub _smimeSignMessage {
    my $this = shift;

    my ( $certFile, $keyFile ) = (
        $Foswiki::cfg{Email}{SmimeCertificateFile},
        $Foswiki::cfg{Email}{SmimeKeyFile}
    );
    unless ( $certFile && $keyFile ) {
        ( $certFile, $keyFile ) = (
            "$Foswiki::cfg{DataDir}/SmimeCertificate.pem",
            "$Foswiki::cfg{DataDir}/SmimePrivateKey.pem"
        );

        unless ( $certFile && $keyFile && -r $certFile && -r $keyFile ) {
            $this->_logMailError( 'die',
"Signed (S/MIME) mail is enabled, but certificate or key is not specified and no self-signed certificate is available."
            );
        }
    }

    eval { require Crypt::SMIME; };
    if ($@) {
        $this->_logMailError( 'die',
                "Cypt::SMIME is not available"
              . ( $@ =~ /Can't locate/ ? '' : ": $@" )
              . ".  Mail will not be sent" );
    }

    my $smime = Crypt::SMIME->new();

    my $key = $this->_slurpFile($keyFile);

    # Decrypt key if password specified and file has encryption header.

    if (   exists $Foswiki::cfg{Email}{SmimeKeyPassword}
        && length $Foswiki::cfg{Email}{SmimeKeyPassword}
        && $key =~ /^-----BEGIN RSA PRIVATE KEY-----\n(?:(.*?\n)\n)?/s )
    {
        my %h;
        %h = map { split( /:\s*/, $_, 2 ) } split( /\n/, $1 )
          if ( defined $1 );
        if (   $h{'Proc-Type'}
            && $h{'Proc-Type'} eq '4,ENCRYPTED'
            && $h{'DEK-Info'}
            && $h{'DEK-Info'} =~ /^DES-EDE3-CBC,/ )
        {

 #<<<
           require Convert::PEM;
            my $pem = Convert::PEM->new( Name => 'RSA PRIVATE KEY',
                                             ASN  => qq(
               RSAPrivateKey SEQUENCE {
                  version INTEGER, n INTEGER, e INTEGER, d INTEGER,
                  p INTEGER, q INTEGER, dp INTEGER, dq INTEGER,
                  iqmp INTEGER
               }                                   ) );
#>>>
            $key = $pem->decode(
                Content  => $key,
                Password => $Foswiki::cfg{Email}{SmimeKeyPassword}
            );
            unless ($key) {
                $this->_logMailError( 'die',
                        "Unable to decrypt "
                      . $Foswiki::cfg{Email}{SmimeKeyFile} . ": "
                      . $pem->errstr
                      . ".  Mail will not be sent." );
                return;
            }
            $key = $pem->encode( Content => $key );
        }
    }

    # Provide decrypted private key & certificate - trapping exceptions

    eval { $smime->setPrivateKey( $key, $this->_slurpFile($certFile) ); };
    if ($@) {
        $this->_logMailError( 'die',
                "Key or Certificate problem sending email"
              . $@
              . ".  Mail will not be sent" );
        return;
    }

    $_[0] = $smime->sign( $_[0] );
}

# =======================================
sub _sendEmailBySendmail {
    my ( $this, $text ) = @_;

    # send with sendmail
    my ( $header, $body ) = split( "\n\n", $text, 2 );
    $header =~
s/([\n\r])(From|To|CC|BCC)(\:\s*)([^\n\r]*)/$1.$2.$3._fixLineLength($4)/geois;

    $text = "$header\n\n$body";    # rebuild message

    if ( $Foswiki::cfg{Email}{EnableSMIME} ) {
        $this->_smimeSignMessage($text);

        if ( $Foswiki::cfg{SMTP}{Debug} ) {    # Log only headers
            $text =~ /^(.*?\r?\n\r?\n)/s;
            $header = "$1 ... Message contents ...\n";
        }
    }

    # With feedback, unsaved values are tainted.
    # We don't have special priveleges (or shouldn't), and
    # MailProgram allows specifying an arbitrary command - e.g. rm.
    # So there's not much point in trying to be defensive here.

    my $mailer = $Foswiki::cfg{MailProgram} || '';
    $mailer .= ' ' . ( $Foswiki::cfg{SMTP}{DebugFlags} || '' )
      if ( $Foswiki::cfg{SMTP}{Debug} && $Foswiki::cfg{SMTP}{DebugFlags} );
    $mailer =~ m/^(.*)$/;
    $mailer = $1;

    $this->_logMailError( 'debug',
        "====== Sending to $mailer ======\n$header\n======EOM======" );

    my $MAIL;
    open( $MAIL, '|-', $mailer )
      || $this->_logMailError( 'die', "Can't send mail using $mailer" );
    print $MAIL $text;
    close($MAIL);

    # If you see 67 (17152) (== EX_NOUSER), then the mail is probably
    # queued and will eventually reach the user, despite the error.
    # The chances are good that you are seeing the same problem as we
    # had on foswiki.org, finally solved by Olivier Raginel viz. The
    # source address is:
    #     From: webmaster@foswiki.org
    # but sendmail thinks it's running on foswiki.org, and knows there is no
    # 'webmaster' user, so it gets confused. The 'From:' in the mail must
    # refer to a user account that exists locally. After we created a dummy
    # 'webmaster' user, the error went away.
    $this->_logMailError( 'die',
        "Mail failure exit code " . ( $? >> 8 ) . " ($?) from $mailer" )
      if $?;

    return;
}

sub _sendEmailByNetSMTP {
    ( our $this, my $text ) = @_;

    my $debug = $Foswiki::cfg{SMTP}{Debug} || 0;

    my $from = '';
    my @to   = ();

    my ( $header, $body ) = split( "\n\n", $text, 2 );

    my @headerlines = split( /\r?\n/, $header );
    $header =~ s/\nBCC\:[^\n]*//os;    #remove BCC line from header
    $header =~
s/([\n\r])(From|To|CC|BCC)(\:\s*)([^\n\r]*)/$1 . $2 . $3 . _fixLineLength( $4 )/geois;

    $text = "$header\n\n$body";        # rebuild message

    $this->_smimeSignMessage($text) if ( $Foswiki::cfg{Email}{EnableSMIME} );

    # extract 'From:'
    my @arr = grep( /^From: /i, @headerlines );
    if ( scalar(@arr) ) {
        $from = $arr[0];
        $from =~ s/^From:\s*//io;
        $from =~
          s/.*<(.*?)>.*/$1/o;    # extract "user@host" out of "Name <user@host>"
    }
    unless ($from) {

        # SMELL: should be a Foswiki::inlineAlert
        $this->_logMailError( 'die', "Can't send mail, missing 'From:'" );
    }

    # extract @to from 'To:', 'CC:', 'BCC:'
    @arr = grep( /^To: /i, @headerlines );
    my $tmp = '';
    if ( scalar(@arr) ) {
        $tmp = $arr[0];
        $tmp =~ s/^To:\s*//io;
        @arr = split( /,\s*/, $tmp );
        push( @to, @arr );
    }
    @arr = grep( /^CC: /i, @headerlines );
    if ( scalar(@arr) ) {
        $tmp = $arr[0];
        $tmp =~ s/^CC:\s*//io;
        @arr = split( /,\s*/, $tmp );
        push( @to, @arr );
    }
    @arr = grep( /^BCC: /i, @headerlines );
    if ( scalar(@arr) ) {
        $tmp = $arr[0];
        $tmp =~ s/^BCC:\s*//io;
        @arr = split( /,\s*/, $tmp );
        push( @to, @arr );
    }
    if ( !( scalar(@to) ) ) {

        # SMELL: should be a Foswiki::inlineAlert
        $this->_logMailError( 'die', "Can't send mail, missing recipient" );
    }

    return unless ( scalar @to );

    # Change SMTP protocol recipient format from
    # "User Name <userid@domain>" to "userid@domain"
    # for those SMTP hosts that need it just that way.
    foreach (@to) {
        s/^.*<(.*)>$/$1/;
    }

    my $smtp = 0;
    my ( $ssl, $tls, $starttls );
    if ( $this->{MAIL_METHOD} =~ /\((SSL)|(TLS)|(STARTTLS)\)/ ) {
        ( $ssl, $tls, $starttls ) = ( $1, $2, $3 );
    }

    my $host = $this->{MAIL_HOST};
    $this->_logMailError( 'die',
        "{SMTP}{MAILHOST} must be specified to use Net::SMTP" )
      unless ($host);

    my $hi = hostInfo( $host, {} );
    if ( $hi->{error} ) {
        $this->_logMailError( 'die',
            "{SMTP}{MAILHOST} is not valid: " . $hi->{error} );
    }
    my $port = $hi->{port};
    $host = $hi->{name};

    unless ($port) {
        $port =
            ( $ssl || $tls ) ? 'smtps(465)'
          : $starttls ? 'submission(587)'
          :             'smtp(25)';
    }

    my @addrs;
    if ($IPv6Avail) {

        # IO::Socket::IP will handle multiple addresses/address families
        # in the right order if we pass $host, but passing the list lets
        # us log which addresses work and which don't for debugging.
        push @addrs, @{ $hi->{addrs} };
    }
    else {
        # Net::SMTP will iterate
        @addrs = @{ $hi->{v4addrs} };
        if ( @{ $hi->{v6addrs} } && $debug ) {
            $this->_logMailError( 'warning',
"$host has an IPv6 address, but IO::Socket::IP is not installed.  IPv6 can not be used."
            );
        }
    }
    scalar @addrs
      or $this->_logMailError( 'die',
        "{SMTP}{MAILHOST} $host is invalid: server has no IP address" );

    my @options = (
        Host    => [@addrs],
        Port    => $port,
        Debug   => $debug,
        Timeout => ( @addrs >= 2 ? 20 : 120 ),
    );
    push @options, Hello => $this->{HELLO_HOST} if ( $this->{HELLO_HOST} );

    Foswiki::Net::Mail::SSL::setup( $this, $ssl, $tls, $starttls, $debug );

    $this->_logMailError(
        'debug',
        ( scalar gmtime ),
        " UTC: Connecting to $host on port $port"
    ) if ($debug);

    # Manage carp in libnet with debug > 0
    local $SIG{__WARN__} = sub {
        my $msg = $_[0];
        $msg =~ s/^.*GLOB\(0x[[:xdigit:]]+\): //;
        $msg =~ s/ at .*$//ms if (1);    # Turn off for debugging caller.
        chomp $msg;
        $this->_logMailError( 'error', "Failed: $msg\n" );
        return undef;
    };

    # IGNORE SIGPIPE caused by errors that cause Net::Cmd to close
    # the TCP connection - then write to it.
    local $SIG{PIPE} = 'IGNORE';

    $smtp = Foswiki::Net::Mail->new(@options)
      or $this->_logMailError( 'die',
        "Failed to connect to '$this->{MAIL_HOST}' using $this->{MAIL_METHOD}"
      );

    $smtp->startTLS( $this, $host ) if ($starttls);

    my ( $username, $password ) =
      ( $Foswiki::cfg{SMTP}{Username}, $Foswiki::cfg{SMTP}{Password} );
    $username = '' unless ( defined $username );
    $password = '' unless ( defined $password );

    my $ok =
      $smtp->authenticateCx( $this, $host, $username, $password,
        ( $starttls || $tls || $ssl ), $debug );

    $ok &&= $smtp->mail($from);
    $ok &&= $smtp->to( @to, { SkipBad => 1 } );

    if ( $ok && $debug ) {
        my $dbg = $smtp->debug(0);
        $ok &&= $smtp->data($text);
        $smtp->debug_print( 1, " ... Message contents ...\n" );
        $smtp->debug($dbg);
    }
    else {
        $ok &&= $smtp->data($text);
    }
    $ok &&= $smtp->dataend();
    my ( $code, $msg ) = ( $smtp->code, $smtp->message );
    $smtp->quit();
    unless ($ok) {
        my $mess =
            "Failed to send mail to "
          . join( ', ', @to )
          . " using $this->{MAIL_METHOD}.\n";
        $this->_logMailError( 'die', $mess . $code . ' ' . $msg );
    }
}

# Support routines for Net::SMTP extensions
#
# The internal packages allow overriding NET::SMTP's
# methods  to permit enhanced logging & transport
# protocol, as well as working around bugs.

package Foswiki::Net::Mail;

our @ISA = (qw/Net::SMTP/);

our $inAuth;

# See https://rt.cpan.org/Public/Bug/Display.html?id=80846
# and https://rt.cpan.org/Public/Bug/Display.html?id=81594
# which this works-around...and also enables STARTTLS & IPv6 support

# Override Net:SMTP/Net::Cmd methods

require MIME::Base64;

my $pad = ' ' x length('Net::SMTpXXX ');

sub debug_text {
    my $cmd = shift;
    my $out = shift;

    my $text = join( '', @_ );

    # Can't tell what's sensitive; masks text but allows
    # dialog to be followed.  Protect length in case log
    # is posted/sent for support.
    # Assume first output is AUTH method, so don't mask that.
    if ($inAuth) {
        if ($out) {
            $text = '*' x ( 8 + int( rand(16) ) )
              unless ( $inAuth++ == 1 );
        }
        else {
            my ( $code, $d, $b64 ) = split( /([ -])/, $text, 2 );
            $code ||= 0;
            if ( $code eq '334' ) {
                $b64 = '' unless ( defined $b64 );
                chomp $b64;
                my $b64text = MIME::Base64::decode_base64($b64);
                my $cont    = "\n${pad}    ";
                my $multi;
                if ( $b64 =~ s/(.{76})/$1$cont/gms ) {
                    $multi = 1;
                }
                if ( $b64text =~ /[[:^print:]]/ ) {
                    my $n = 0;
                    $b64text =~
s/(.)/sprintf('%02x', ord $1) . (++$n % 32 == 0? $cont : ' ')/gmse;
                    $b64text =~ s/([[:xdigit:]]{2}) ([[:xdigit:]]{2})/$1$2/g;
                    if ( $n % 32 ) {
                        chop $b64text;
                        $b64text .= $cont;
                    }
                    unless ( $multi && $b64 =~ /$cont\z/ ) {
                        $b64 .= $cont;
                        $multi = 1;
                    }
                    chop $b64;
                    $b64 .= '[';
                    $b64text =~ s/$cont\z/]/;
                }
                else {
                    if ( $multi && $b64 !~ /$cont\z/ ) {
                        $b64 .= $cont;
                    }
                    if ($multi) {
                        chop $b64;
                    }
                    else {
                        $b64 .= ' ';
                    }
                    $b64text = "[$b64text]";
                }
                $text = join( '', $code, $d, $b64, $b64text );
            }
        }
    }
    return $text;
}

sub debug_print {
    my ( $cmd, $out, $text ) = @_;

    chomp $text;
    my $tag = $ISA[0] . ( $out ? '>>> ' : '<<< ' );
    $text = $tag
      . join( "\n$tag -- ",
        map $cmd->debug_text( $out, $_ ),
        split( /\r?\n/, $text, -1 ) )
      . "\n";

    $text =~ s/([&'"<>])/'&#'.ord( $1 ) .';'/ge;
    print STDERR $text;
}

# Extension for setting up authentication
#
# Here to keep logic out-of-line, and also so
# we can easily filter credentials from debug output.

sub authenticateCx {
    my $smtp = shift;
    my ( $this, $host, $username, $password, $secure, $debug ) = @_;

    return 1 unless ( length($username) || length($password) );

    if ( defined $smtp->supports('AUTH') ) {
        if ($debug) {
            $this->_logMailError( 'warning',
                "Authentication is using a null password" )
              unless ( length $password );
        }

        local $inAuth = 1;
        unless ( $smtp->auth( $username, $password ) ) {
            $inAuth = 0;
            $this->_logMailError( 'error',
                    "Authentication failed:\n"
                  . $smtp->code() . ' '
                  . $smtp->message()
                  . "Verify that the configured username and password are valid for $host"
            );
            return 0;
        }
        return 1;
    }
    return 1 unless ($debug);

    $this->_logMailError(
        'warning',
        (
            length($username)
            ? "A username ($username)"
              . ( length($password) ? " and password are" : " is" )
            : 'A password is'
        ),
        " configured, but "
          . (
            $secure
            ? "$host does not offer authentication."
            : (
"$host either does not require authentication or it requires a secure (SSL/TLS) connection to authenticate."
                  . (
                    defined $smtp->supports('STARTTLS')
                    ? "  Since STARTTLS is offered, you should select Net::SMTP (STARTTLS)."
                    : "  Since STARTTLS is not offered, you should try Net::SMTP (TLS) or Net::SMTP (SSL)."
                  )
            )
          )
          . "  You should remove username and password from the configuration if they are not used."
    );
    return 1;
}

package Foswiki::Net::Mail::SSL;

BEGIN {
    Foswiki::IP->import(qw/$IPv6Avail/);
}

our @ISA;

our ( $usessl, $logcx, @sockopts, @sslopts );

# Arrange interception of Net::SMTP socket creation
# Possible because it inherits from a socket
# method and uses SUPER::new to create its socket.
# By putting this package first in its @ISA, it inherits
# from this package instead.  This mechanism replaces
# Net::SMTP::SSL (and Net::SMTP::TLs).
#
# Mail objects inherit from several classes, and act as
# sockets, Net::Cmd and SMTP objects.
#
# All SSL goes through IO::Socket::SSL, loaded only for SSL.
# SSL options are selected here, and applied in new(), which
# must deal with multiple calls.
#
# socket options come from mail->new and Net::SMTP internals,
# and are saved in case they are needed for STARTTLS.

sub setup {
    ( my ( $this, $ssl, $tls, $starttls ), $logcx ) = @_;

    @ISA = @Net::SMTP::ISA;

    $usessl = $ssl || $tls;

    if ( $usessl || $starttls ) {
        push @sslopts,
          SSL_version => ( ( $tls || $starttls ) ? 'TLSv1' : 'SSLv3' ),
          setupSSLoptions($this);
    }

    if ($usessl) {
        @ISA = (
            grep( $_ !~ /^IO::Socket::I(?:NET|P)$/, @Net::SMTP::ISA ),
            'IO::Socket::SSL'
        );
    }
    @Net::SMTP::ISA = __PACKAGE__;

    return;
}

# Intercept socket creation by Net::SMTP

sub new {
    my $class = shift;

    @sockopts = ( @_, @sslopts );

    my ( $log, %opts );
    $log = bless {}, $class;
    if ( $logcx && $usessl ) {
        %opts = @sockopts;
        $log->logSSLoptions( \%opts );
    }

    my $sclass =
        $usessl    ? 'IO::Socket::SSL'
      : $IPv6Avail ? 'IO::Socket::IP'
      :              'IO::Socket::INET';
    $! = 0;
    $@ = '';
    my $sock = $sclass->new(@sockopts);
    if ($sock) {
        bless $sock, $class;
        if ($logcx) {
            my $peer = $sock->peerhost . ':' . $sock->peerport;
            if ($usessl) {
                $log->debug_print( 0,
                        "Connected with $peer using "
                      . $opts{SSL_version} . ' and '
                      . $sock->get_cipher
                      . " encryption\nServer Certificate:\n"
                      . fmtcertnames( $sock->dump_peer_certificate ) );
            }
            else {
                $log->debug_print( 0,
                    "Connected with $peer using no encryption\n" );
            }
        }
    }
    else {
        my $peer = $opts{PeerHost}    || $opts{PeerAddr} || '';
        my $port = $opts{PeerService} || $opts{PeerPort} || '';
        $peer = "$peer on $port" if ($port);
        $log->debug_print(
            0,
            "Unable to establish connection with $peer: "
              . (
                     ( ($!) ? $@ || $! : 0 )
                  || ( $usessl && IO::Socket::SSL::errstr() )
              )
              . "\n"
        );
    }
    return $sock;
}

# Create socket options list for TSL/SSL/STARTTLS connections

sub setupSSLoptions {
    my ($this) = @_;

    # Accurate SSL error reporting requires setting this hook.

    my @sslopts = (
        SSL_error_trap => sub {
            my ( $sock, $msg ) = @_;
            $this->_logMailError(
                'die',
                (
                    $sock->connected
                    ? "Failed to initialize SSL with "
                      . $sock->peerhost . ':'
                      . $sock->peerport
                      . " - $msg"
                    : "SSL error while not connected - $msg"
                )
            );
            $sock->close;
            return;
        },
    );

    # Peer (server) verification

    if ( $Foswiki::cfg{Email}{SSLVerifyServer} ) {
        my ( $file, $path ) =
          ( $Foswiki::cfg{Email}{SSLCaFile}, $Foswiki::cfg{Email}{SSLCaPath} );
        Foswiki::Configure::Load::expandValue($file);
        Foswiki::Configure::Load::expandValue($path);

        $this->_logMailError( 'die',
"{Email}{SSLVerifyServer} requires host verification but neither {Email}{SSLCaFile} nor {Email}{SSLCaPath} is set."
        ) unless ( $file || $path );

        push @sslopts,
          (
            SSL_verify_mode   => IO::Socket::SSL::SSL_VERIFY_PEER(),
            SSL_verify_scheme => {
                check_cn         => 'when_only',
                wildcards_in_alt => 'leftmost',
                wildcards_in_cn  => 'leftmost',
            },
            SSL_ca_file => $file || undef,
            SSL_ca_path => $path || undef,
          );

        if ( $Foswiki::cfg{Email}{SSLCheckCRL} ) {
            ( $file, $path ) = (
                $Foswiki::cfg{Email}{SSLCrlFile},
                $Foswiki::cfg{Email}{SSLCaPath}
            );
            Foswiki::Configure::Load::expandValue($file);
            Foswiki::Configure::Load::expandValue($path);

            $this->_logMailError( 'die',
"{Email}{SSLCheckCRL} requires CRL verification but neither {Email}{SSLCrlFile} nor {Email}{SSLCaPath} is set."
            ) unless ( $file || $path );

            push @sslopts, SSL_check_crl => 1;
            push @sslopts, SSL_crl_file  => $file
              if ($file);
        }
    }
    else {
        push @sslopts, SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE();
    }

    # Client verification

    if (   $Foswiki::cfg{Email}{SSLClientCertFile}
        || $Foswiki::cfg{Email}{SSLClientKeyFile} )
    {
        my ( $certFile, $keyFile ) = (
            $Foswiki::cfg{Email}{SSLClientCertFile},
            $Foswiki::cfg{Email}{SSLClientKeyFile}
        );
        Foswiki::Configure::Load::expandValue($certFile);
        Foswiki::Configure::Load::expandValue($keyFile);

        $this->_logMailError( 'die',
"Client verification requires both {Email}{SSLClientCertFile} and {Email}{SSLClientKeyFile} to be set."
        ) unless ( $certFile && $keyFile );

        push @sslopts,
          (
            SSL_use_cert  => 1,
            SSL_cert_file => $certFile,
            SSL_key_file  => $keyFile
          );
        if ( $Foswiki::cfg{Email}{SSLClientKeyPassword} ) {
            push @sslopts, SSL_passwd_cb => sub {
                return $Foswiki::cfg{Email}{SSLClientKeyPassword};
            };
        }
    }

    return @sslopts;
}

# Log actual SSL options for connection

sub logSSLoptions {
    my $log = shift;
    my ($opts) = @_;

    if ( $opts->{SSL_verify_mode} == IO::Socket::SSL::SSL_VERIFY_NONE() ) {
        $log->debug_print( 1, "SSL peer verification: off\n" );
    }
    else {
        $log->debug_print( 1, "SSL peer verification: on\n" );
        $log->debug_print( 1, "Verify Server CA_File: $opts->{SSL_ca_file}\n" )
          if ( $opts->{SSL_ca_file} );
        $log->debug_print( 1, "Verify Server CA_Path: $opts->{SSL_ca_path}\n" )
          if ( $opts->{SSL_ca_path} );

        if ( $opts->{SSL_check_crl} ) {
            $log->debug_print( 1, "Verify server against CRL: on\n" );
            $log->debug_print( 1,
                "Verify Server CRL CRL_File: $opts->{SSL_crl_file}\n" )
              if ( $opts->{SSL_crl_file} );
        }
        else {
            $log->debug_print( 1, "Verify server against CRL: off\n" );
        }
    }

    if ( $opts->{SSL_use_cert} ) {
        $log->debug_print( 1, "Provide Client Certificate: on\n" );
        $log->debug_print( 1,
            "Client Certificate File: $opts->{SSL_cert_file}\n" )
          if ( $opts->{SSL_cert_file} );
        $log->debug_print( 1,
            "Client Certificate Key File: $opts->{SSL_key_file}\n" )
          if ( $opts->{SSL_key_file} );
        $log->debug_print( 1,
            "Client Certificate key Password: "
              . ( $opts->{SSL_passwd_cb} ? "*****\n" : "None\n" ) );
    }
    else {
        $log->debug_print( 1, "Provide Client Certificate: off\n" );
    }
    return;
}

# use STARTTLS to upgrade a connection

sub startTLS {
    my $smtp = shift;
    my ( $this, $host ) = @_;

    my $mailobj = ref $smtp;

    $this->_logMailError( 'die', "$host does not support STARTTLS" )
      unless ( defined $smtp->supports('STARTTLS') );

    unless ( $smtp->command('STARTTLS')->response() == 2 ) {
        my ( $code, $msg ) = ( $smtp->code, $smtp->message );
        $smtp->quit();
        $this->_logMailError(
            'die',
            "$host did not accept STARTTLS: ",
            $code . ' ' . $msg
        );
    }

    our ( @sockopts, $logcx );
    $smtp->logSSLoptions( {@sockopts} ) if ($logcx);

    # N.B. Successful upgrade will change @Foswiki::Net::Mail::ISA
    unless ( IO::Socket::SSL->start_SSL( $smtp, @sockopts ) ) {
        my $errs = IO::Socket::SSL::errstr();
        $smtp->debug_print( 0, "Failed to start TLS: $errs\n" ) if ($logcx);

        #$smtp->quit();
        $this->_logMailError( 'die',
            "Unable to upgrade connection to TLS in STARTTLS: $errs" );
    }

    @ISA =
      ( grep( $_ !~ /^IO::Socket::I(?:NET|P)$/, @ISA ), 'IO::Socket::SSL' );
    bless $smtp, $mailobj;

    $smtp->debug_print( 0,
            "Started TLS using "
          . $smtp->get_cipher
          . " encryption\nServer Certificate:\n"
          . fmtcertnames( $smtp->dump_peer_certificate ) )
      if ($logcx);

    unless ( $smtp->hello( $this->{HELLO_HOST} ) ) {
        my ( $code, $msg ) = ( $smtp->code, $smtp->message );
        $smtp->quit();
        $this->_logMailError(
            'die',
            "$host rejected HELLO after STARTTLS: ",
            $code . ' ' . $msg
        );
    }
    return;

}

# Format certificate names for display.

sub fmtcertnames {
    my $names = shift;

    my $out  = '';
    my $wrap = ( ' ' x length('Subject Name: ') );

    foreach my $name ( split( /\n/, $names ) ) {
        my @parts = split( m~/~, $name );
        my $line = '';
        while (@parts) {
            my $part = shift @parts;
            next unless ( defined $part );
            while ( length( $line . $part ) < 80 ) {
                $line .= "$part/";
                $part = shift @parts;
                last unless ( defined $part );
            }
            if ( defined $part ) {
                if ( length($line) ) {
                    $line =~ s~/$~~;
                    $out .= "$line\n";
                    $line = "$wrap/$part/";
                }
                else {
                    $out .= "$part\n";
                    if (@parts) {
                        $line = "$wrap/";
                    }
                    else {
                        $line = '';
                        last;
                    }
                }
            }
        }
        chomp $line;
        $out .= "$line\n" if ( length($line) );
        $out =~ s~/\Z~~;
    }

    return $out;
}

1;
__END__

Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/, http://Foswiki.org/

Copyright (C) 2008-2009 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.

NOTE: Please extend that file, not this notice.
Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2001-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
