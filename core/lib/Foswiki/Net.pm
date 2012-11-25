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

our $LWPAvailable;
our $noHTTPResponse;    # if set, forces local impl of HTTP::Response

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
    my ( $this, $url ) = @_;

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
        return _GETUsingLWP( $this, $url );
    }

    # Fallback mechanism
    if ( $protocol ne 'http' ) {
        require Foswiki::Net::HTTPResponse;
        return new Foswiki::Net::HTTPResponse(
            "LWP not available for handling protocol: $url");
    }

    my $response;
    try {
        $url =~ s!^\w+://!!;    # remove protocol
        my ( $user, $pass );
        if ( $url =~ s!([^/\@:]+)(?::([^/\@:]+))?@!! ) {
            ( $user, $pass ) = ( $1, $2 || '' );
        }

        unless ( $url =~ s!([^:/]+)(?::([0-9]+))?!! ) {
            die "Bad URL: $url";
        }
        my ( $host, $port ) = ( $1, $2 || 80 );

        require Socket;
        import Socket qw(:all);

        $url = '/' unless ($url);
        my $req = "GET $url HTTP/1.0\r\n";

        $req .= "Host: $host:$port\r\n";
        if ($user) {

            # Use MIME::Base64 at run-time if using outbound proxy with
            # authentication
            require MIME::Base64;
            my $base64 = MIME::Base64::encode_base64( "$user:$pass", "\r\n" );
            $req .= "Authorization: Basic $base64";
        }

        # SMELL: Reference to Foswiki variables used for compatibility
        my ( $proxyHost, $proxyPort );
        if ( $this->{session} && $this->{session}->{prefs} ) {
            my $prefs = $this->{session}->{prefs};
            $proxyHost = $prefs->getPreference('PROXYHOST');
            $proxyPort = $prefs->getPreference('PROXYPORT');
        }

        # Do not use || so user can disable proxy using preferences
        $proxyHost = $Foswiki::cfg{PROXY}{HOST} unless defined $proxyHost;
        $proxyPort = $Foswiki::cfg{PROXY}{PORT} unless defined $proxyPort;
        if ( $proxyHost && $proxyPort ) {
            my ( $proxyUser, $proxyPass );
            if ( $proxyHost =~
                m#^http://(?:(.*?)(?::(.*?))?@)?(.*)(?::(\d+))?/*# )
            {
                $proxyUser = $1;
                $proxyPass = $2;
                $proxyHost = $3;
                $proxyPort = $4 if defined $4;
            }
            else {
                require Foswiki::Net::HTTPResponse;
                return new Foswiki::Net::HTTPResponse(
                    "Proxy settings are invalid, check configure ($proxyHost)");
            }
            $req  = "GET http://$host:$port$url HTTP/1.0\r\n";
            $host = $proxyHost;
            $port = $proxyPort;
            if ($proxyUser) {
                require MIME::Base64;
                my $base64 =
                  MIME::Base64::encode_base64( "$proxyUser:$proxyPass",
                    "\r\n" );
                $req .= "Proxy-Authorization: Basic $base64";
            }
        }

        $req .= 'User-Agent: Foswiki::Net/' . $Foswiki::VERSION . "\r\n";
        $req .= "\r\n\r\n";

        my ( $iaddr, $paddr, $proto );
        $iaddr = inet_aton($host);
        die "Could not find IP address for $host" unless $iaddr;

        $paddr = sockaddr_in( $port, $iaddr );
        $proto = getprotobyname('tcp');
        unless ( socket( *SOCK, &PF_INET, &SOCK_STREAM, $proto ) ) {
            die "socket failed: $!";
        }
        unless ( connect( *SOCK, $paddr ) ) {
            die "connect failed: $!";
        }
        select SOCK;
        $| = 1;
        local $/ = undef;
        print SOCK $req;
        my $result = '';
        $result = <SOCK>;
        unless ( close(SOCK) ) {
            die "close faied: $!";
        }
        select STDOUT;

        # No LWP, but may have HTTP::Response which would make life easier
        # (it has a much more thorough parser)
        eval 'require HTTP::Response';
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
    my ( $this, $url ) = @_;

    my ( $user, $pass );
    if ( $url =~ s!([^/\@:]+)(?::([^/\@:]+))?@!! ) {
        ( $user, $pass ) = ( $1, $2 );
    }
    my $request;
    require HTTP::Request;
    $request = HTTP::Request->new( GET => $url );
    $request->header( 'User-Agent' => 'Foswiki::Net/'
          . $Foswiki::VERSION
          . " libwww-perl/$LWP::VERSION" );
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
        print STDERR "MAIL " . uc($level) . " $msg\n";
    }
    else {
        my $logger;
        if ( $this->{session} ) {
            $logger = $this->{session}->logger;
        }
        else {
            $logger = $Foswiki::cfg{Log}{Implementation};
            unless ($logger) {
                print STDERR "MAIL " . uc($level) . " $msg\n";
                die "MAIL $level: $msg\n" if ($die);
                return;
            }
            eval "require $logger;";
            die "Can't load $logger: $!\n" if ($@);
            $logger = $logger->new();
        }
        $logger->log( $level, $msg ) if ($logger);
    }

    die "MAIL " . uc($level) . ": $msg\n" if ($die);

    return;
}

# pick a default mail handler
sub _installMailHandler {
    my $this    = shift;
    my $handler = 0;       # Not undef
    if ( $this->{session} && $this->{session}->{prefs} ) {
        my $prefs = $this->{session}->{prefs};
        $this->{MAIL_HOST}  = $prefs->getPreference('SMTPMAILHOST');
        $this->{HELLO_HOST} = $prefs->getPreference('SMTPSENDERHOST');
    }

    $this->{MAIL_HOST}  ||= $Foswiki::cfg{SMTP}{MAILHOST};
    $this->{HELLO_HOST} ||= $Foswiki::cfg{SMTP}{SENDERHOST};

    $this->{MAIL_METHOD} = $Foswiki::cfg{Email}{MailMethod};

    unless ( $this->{MAIL_METHOD} ) {
        $this->{MAIL_METHOD} = 'Net::SMTP' if ( $this->{MAIL_HOST} );
    }

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

        $this->{MAIL_METHOD} =~ /^([\w:_]+)$/ or    # Config or intruder
          die "Invalid {Email}{MailMethod} $this->{MAIL_METHOD}\n";
        $this->{MAIL_METHOD} = $1;

        eval "require $this->{MAIL_METHOD};";
        if ($@) {
            $this->_logMailError( 'error',
                "Failed to load $this->{MAIL_METHOD}: $@" );
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
    # requires a US locale for time (e.g month and day of week names).

    require POSIX;
    POSIX->import(qw(locale_h));

    my $old_locale = POSIX::setlocale( LC_TIME() );
    POSIX::setlocale( LC_TIME(), 'en_US.ISO8859-1' );
    my $dateStr;
    if ( $Foswiki::cfg{Email}{Servertime} ) {
        $dateStr = POSIX::strftime( '%a, %d %b %Y %T %z"', localtime(time) );
    }
    else {
        $dateStr = POSIX::strftime( '%a, %d %b %Y %T ', gmtime(time) ) . 'GMT';
    }
    setlocale( LC_TIME(), $old_locale );

    $text = "Date: " . $dateStr . "\n" . $text;
    my $errors   = '';
    my $back_off = 1;    # seconds, doubles on each retry
    while ( $retries-- ) {
        try {
            &{ $this->{mailHandler} }( $this, $text );
            $retries = 0;
        }
        catch Error::Simple with {
            my $e = shift->stringify();
            ( my $to ) = $text =~ /^To:\s*(.*?)$/im;
            $this->_logMailError( 'error', "Error sending email $to - $e" );

            # be nasty to errors that we didn't throw. They may be
            # caused by SMTP or perl, and give away info about the
            # install that we don't want to share.
            $e = join( "\n", grep( /^ERROR/, split( /\n/, $e ) ) );

            unless ( $e =~ /^ERROR/ ) {

                # SMELL: maketext; and WIKIWEBMASTER is an email address
                $e =
"Mail could not be sent to $to - please ask your %WIKIWEBMASTER% to look at the Foswiki warning log.";
            }
            $errors .= "Emailing $to - $e\n";
            if ($retries) {
                sleep($back_off);
                $back_off *= 2;
            }
            else {
                $errors .= "Too many failures sending mail";
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

    unless ( $Foswiki::cfg{Email}{SmimeCertificateFile}
        && $Foswiki::cfg{Email}{SmimeKeyFile} )
    {
        $this->_logMailError( 'die',
"Signed (S/MIME) mail is enabled, but certificate or key is not specified."
        );
    }

    eval { require Crypt::SMIME; };
    if ($@) {
        $this->_logMailError( 'die',
                "Cypt::SMIME is not available"
              . ( $@ =~ /Can't locate/ ? '' : ": $@" )
              . ".  Mail will not be sent" );
    }

    my $smime = Crypt::SMIME->new();

    my $key = $this->_slurpFile( $Foswiki::cfg{Email}{SmimeKeyFile} );

    # Decrypt key if password specified and file has encryption header.

    if (   exists $Foswiki::cfg{Email}{SmimeKeyPassword}
        && length $Foswiki::cfg{Email}{SmimeKeyPassword}
        && $key =~ /^-----BEGIN RSA PRIVATE KEY-----\n(?:(.*?\n)\n)?/s )
    {
        my %h = map { split( /:\s*/, $_, 2 ) } split( /\n/, $1 )
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

    eval {
        $smime->setPrivateKey( $key,
            $this->_slurpFile( $Foswiki::cfg{Email}{SmimeCertificateFile} ) );
    };
    if ($@) {
        $this->_logMailError( 'die',
                "Key or Certificate problem sending email"
              . ( $@ =~ /Can't locate/ ? '' : ": $@" )
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
    my ( $this, $text ) = @_;

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

    my ( $host, $port ) = $this->{MAIL_HOST} =~ m/(.*):([0-9]{2-5})$/;
    my @options = ( Host => $host, );

    push @options, Port => $port if ($port);

    push @options, Hello => $this->{HELLO_HOST} if ( $this->{HELLO_HOST} );

#if ($this->{MAIL_METHOD} eq 'Net::SMTP::TLS' && $Foswiki::cfg{SMTP}{Username}) {
#    push @options,
#      User => $Foswiki::cfg{SMTP}{Username},
#      Password => $Foswiki::cfg{SMTP}{Password};
#}

    push @options, Debug => $Foswiki::cfg{SMTP}{Debug} || 0;

    #if ($this->{MAIL_METHOD} eq 'Net::SMTP::TLS') {
    #$this-> _logMailError('debug', "Creating new TLS Object with @options");
    #}

    if (1) {    # See https://rt.cpan.org/Public/Bug/Display.html?id=80846
                # which this works-around...

        package Foswiki::Configure::Net::Mail;
        our @ISA = ( $this->{MAIL_METHOD} );

        sub debug_print {
            my ( $cmd, $out, $text ) = @_;
            print STDERR $ISA[0], ( $out ? '>>> ' : '<<< ' ),
              $cmd->debug_text( $out, $text );
        }
        $smtp =
          Foswiki::Configure::Net::Mail->new( $this->{MAIL_HOST}, @options );
    }
    else {
        $smtp = $this->{MAIL_METHOD}->new( $this->{MAIL_HOST}, @options );
    }

    my $status = '';
    my $mess   = "ERROR: Can't send mail using $this->{MAIL_METHOD}. ";
    $this->_logMailError( 'die',
        $mess . "Can't connect to '$this->{MAIL_HOST}'" )
      unless $smtp;

    $this->_logMailError( 'debug',
        "SMTP auth: Attempting authentication for $Foswiki::cfg{SMTP}{Username}"
    ) if ( $Foswiki::cfg{SMTP}{Debug} && $Foswiki::cfg{SMTP}{Username} );

    if ( $Foswiki::cfg{SMTP}{Username}
        && !( $this->{MAIL_METHOD} eq 'Net::SMTP::TLS' ) )
    {
        unless ( $Foswiki::cfg{SMTP}{Password} ) {
            my $errmsg =
"SMTP auth: AUTH requested for $Foswiki::cfg{SMTP}{Username} but no password provided";
            $this->_logMailError( 'warning', "$errmsg" )
              if $Foswiki::cfg{SMTP}{Debug};
        }

        unless (
            $smtp->auth(
                $Foswiki::cfg{SMTP}{Username},
                $Foswiki::cfg{SMTP}{Password}
            )
          )
        {
            my $errmsg =
              'SMTP auth: ' . $smtp->code() . ': ' . $smtp->message();
            chomp($errmsg);
            $errmsg .= ' - Trying to send without authentication';
            $this->_logMailError( 'warning', "$errmsg" );
        }
    }
    $smtp->mail($from) || $this->_logMailError( 'die', $mess . $smtp->message );
    $smtp->to( @to, { SkipBad => 1 } )
      || $this->_logMailError( 'die', $mess . $smtp->message );

    if ( $Foswiki::cfg{SMTP}{Debug} ) {
        my $debug = $smtp->debug(0);
        $smtp->data($text)
          || $this->_logMailError( 'die', $mess . $smtp->message );
        $smtp->debug_print( 1, " ... Message contents ...\n" );
        $smtp->debug($debug);
    }
    else {
        $smtp->data($text)
          || $this->_logMailError( 'die', $mess . $smtp->message );
    }
    $smtp->dataend() || $this->_logMailError( 'die', $mess . $smtp->message );
    $smtp->quit();
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
