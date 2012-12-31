# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::EnableEmail;

use strict;
use warnings;

use Foswiki::IP qw/:regexp :info $IPv6Avail/;

require Foswiki::Configure::Checker;
our @ISA = ('Foswiki::Configure::Checker');

# N.B. Below the block comment are not enabled placeholders
# Search order (specify hash key):
my @mtas = (qw/mailwrapper ssmtp sendmail/);
#<<<
my %mtas = (
    sendmail => {
        name => 'sendmail',                 # Display name
        file => 'sendmail',                 # Executable file to look for in PATH
        regexp =>                           # Regexp to match basename from alias
          qr/^(?:sendmail\.)?sendmail$/,
        flags => '-t -oi -oeq',             # Flags used for sending mail
        debug => '-X /dev/stderr',          # Additional flags to enable debug logs
    },
    ssmtp => {
        name   => 'sSMTP',
        file   => 'ssmtp',
        regexp => qr/^(?:sendmail\.)?ssmtp$/,
        flags  => '-t -oi -oeq',
        debug  => '-v',
    },
    mailwrapper => {
        name   => 'mailwrapper',
        file   => 'mailwrapper',
        regexp => qr/^mailwrapper$/,
        code   =>                           # Callout to find actual program
         sub { return mailwrapperConfig( @_ ); },
    },
# Below this comment, the keys aren't in @mtas, and hence aren't used (yet).  The data
# is almost certainly wrong - these are simply placeholders.
# As these are investigated, validated, add the keys to @mtas and move above this line.

    postfix => {
        name   => 'sendmail',
        file   => 'postfix',
        regexp => qr/^(?:sendmail\.)?postfix$/,
        flags  => '',
        debug  => '', #?? -v??
    },
    qmail => {
        name   => 'qmail',
        file   => 'qmail',
        regexp => qr/^(?:sendmail\.)?qmail$/,
        flags  => '',
        debug  => '',
    },
    exim => {
        name   => 'Exim',
        file   => 'exim',
        regexp => qr/^(?:sendmail\.)?exim$/,
        flags  => '',
        debug  => '-v',
    },

    # ... etc
);
#>>>

my $acceptMsg =
"Configuration accepted.<br />Next step:Setup and test {WebMasterEmail} using the action button above.\n";

sub check {
    my $this   = shift;
    my $valobj = shift;

    my $e = '';

    unless ( $Foswiki::cfg{EnableEmail} ) {
        return $this->WARN(
"You should configure and enable e-mail so that Foswiki can provide topic change notifications and user registration services."
        );
    }

    if ( !$this->{item}->feedback && !$this->{FeedbackProvided} ) {

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

    my $keys = $valobj->getKeys();

    delete $this->{FeedbackProvided};

    # For button 2, try to autoconfigure the host

    if ( $button == 2 ) {
        my @optionList = $this->parseOptions();

        $optionList[0] = {} unless (@optionList);

        $e .=
          $this->ERROR(".SPEC error: multiple CHECK options for {EnableEmail}")
          if ( @optionList > 1 );

        $e .= $this->autoconfig( $optionList[0] );
    }
    elsif ( $button == 3 ) {

        # Reset (most) mail configuration to defaults

        # Keep host if valid, but remove port
        my $host = $this->getCfg('{SMTP}{MAILHOST}');
        $host = '' if ( $host =~ /^ ---/ );
        if ($host) {
            $host = hostInfo($host);
            if ( $host->{error} ) {
                $host = '';
            }
            elsif ( $host->{ipv6addr} ) {
                $host = "[$host->{name}]";
            }
            else {
                $host = $host->{name};
            }
        }
        $host ||= ' ---- Enter e-mail server name to configure Net::SMTP ---';

        # Leave any username/password as they are probably
        # right - or if not, will show as obvious errors
        # Leave S/MIME (it doesn't impact autoconfig)
        # DebugFlags will be autoconfigured if program selected

        $e .= join(
            '',
            $this->FB_VALUE( $this->setItemValue( 0, '{EnableEmail}' ) ),
            $this->FB_VALUE(
                $this->setItemValue(
                    'Net::SMTP (STARTTLS)',
                    '{Email}{MailMethod}'
                )
            ),
            $this->FB_VALUE( $this->setItemValue( 0,     '{SMTP}{Debug}' ) ),
            $this->FB_VALUE( $this->setItemValue( $host, '{SMTP}{MAILHOST}' ) ),
            $this->FB_VALUE( $this->setItemValue( '', '{SMTP}{SENDERHOST}' ) ),
            $this->FB_VALUE(
                $this->setItemValue( 1, '{Email}{SSLVerifyServer}' )
            ),
            $this->FB_VALUE( $this->setItemValue( '', '{Email}{SSLCaFile}' ) ),
            $this->FB_VALUE( $this->setItemValue( '', '{Email}{SSLCaPath}' ) ),
            $this->FB_VALUE( $this->setItemValue( 0, '{Email}{SSLCheckCRL}' ) ),
            $this->FB_VALUE(
                $this->setItemValue( '', '{Email}{SSLClientCertFile}' )
            ),
            $this->FB_VALUE(
                $this->setItemValue( '', '{Email}{SSLClientKeyFile}' )
            ),
            $this->FB_VALUE(
                $this->setItemValue( '', '{Email}{SSLClientKeyPassword}' )
            ),
        );
        $e .= $this->FB_ACTION( '{SMTP}{MAILHOST}', 's' )
          if ( $host =~ /^ ---/ );

        return
          wantarray
          ? ( $e, [qw/{SMTP}{MAILHOST} {Email}{SSLVerifyServer}/] )
          : $e;
    }

    return wantarray ? ( $e, 0 ) : $e;
}

sub autoconfig {
    my $this = shift;
    my ($options) = @_;

    my $e  = '';
    my $sm = '';

    if ( $Foswiki::cfg{Email}{EnableSMIME} ) {
        my ( $certFile, $keyFile ) = (
            $Foswiki::cfg{Email}{SmimeCertificateFile},
            $Foswiki::cfg{Email}{SmimeKeyFile},
        );
        unless ( $certFile && $keyFile ) {
            ( $certFile, $keyFile ) = (
                '$Foswiki::cfg{DataDir}/SmimeCertificate.pem',
                '$Foswiki::cfg{DataDir}/SmimePrivateKey.pem',
            );
        }
        Foswiki::Configure::Load::expandValue($certFile);
        Foswiki::Configure::Load::expandValue($keyFile);

        unless ( $certFile && $keyFile && -r $certFile && -r $keyFile ) {
            $e .= $this->ERROR(
"We recommend configuring Foswiki to send S/MIME signed e-mail.<p>
To do this, either Certificate and Key files must be provided, or a self-signed certificate can be generated.<p>
To generate a self-signed certificate or generate a signing request, use the respective WebmasterName action button.<p>
Because no certificate is present, S/MIME his been disabled to allow basic autoconfiguration to continue."
            );
            $sm .=
              $this->FB_VALUE(
                $this->setItemValue( 0, '{Email}{EnableSMIME}' ) );
        }
    }

    # Prefer perl or program?

    my $preferPerl = ( $options->{prefer}[0] || 'perl' ) =~ /^perl$/i;

    my $perlAvail = eval "require Net::SMTP";

    unless ($perlAvail) {
        return ( $this->autoconfigProgram( $options, 0 ) )[1];
    }

    if ($preferPerl) {
        my ( $ok, $ae ) = $this->autoconfigPerl( $options, 0 );
        return $e . $ae . $sm if ($ok);
        return $e . $ae . ( $this->autoconfigProgram( $options, -1 ) )[1] . $sm;
    }
    my ( $ok, $ae ) = $this->autoconfigProgram( $options, 1 );
    return $e . $ae . $sm if ($ok);
    return $e . $ae . ( $this->autoconfigPerl( $options, -1 ) )[1] . $sm;
}

sub autoconfigProgram {
    my $this = shift;
    my ( $options, $perlAvail ) = @_;

    my $e = $this->NOTE("Attempting to configure a mailer program");

    require Cwd;
    Cwd->import(qw/realpath/);
    require File::Basename;
    File::Basename->import(qw/fileparse/);

    my ( $mailp, $mailargs );
    my $path = $ENV{PATH};

    # First, try special heuristics

    foreach my $mta (@mtas) {
        my $cfg = $mtas{$mta} or next;
        my $test = $cfg->{code};
        next unless ($test);
        ( $mailp, $mailargs ) = $test->($cfg);
        delete $mtas{$mta};
        next unless ($mailp);

        my ( $prog, $ppath ) = fileparse($mailp);
        $path = "$ppath:$path" if ($ppath);
        $mailp = $prog;
    }

    # Next, look for each mta on path
    # Identify it by it's realpath (/etc/alternatives...)

    unless ($mailp) {
        foreach my $mta (@mtas) {
            my $cfg = $mtas{$mta} or next;
            foreach my $p ( split( /:/, $path ) ) {
                if ( -x "$p/$cfg->{file}" ) {
                    my $prog = realpath("$p/$cfg->{file}");
                    if ( ( fileparse($prog) )[0] =~ $cfg->{regexp} ) {
                        return $this->setMailProgram( $e, $cfg, $p );
                    }
                }
            }
        }

        # Not found, must map /usr/sbin/sendmail to the tool

        $mailp = 'sendmail';
        $e .= 'Unable to locate a known external mail program';
    }

    my $seen = '';
    foreach my $p ( '/usr/sbin', split( /:/, $path ) ) {
        if ( -x "$p/$mailp" ) {
            $mailp = ( fileparse( realpath("$p/$mailp") ) )[0];
            foreach my $mta (@mtas) {
                my $cfg = $mtas{$mta} or next;
                if ( $mailp =~ $cfg->{regexp} ) {
                    $cfg->{flags} = '' unless ( defined $cfg->{flags} );
                    $cfg->{flags} = "$mailargs $cfg->{flags}"
                      if ( defined $mailargs );
                    return $this->setMailProgram( $e, $cfg, $p );
                }
            }
            $seen .= "Unable to identify $p/$mailp.<br />";
            next;
        }
    }

    my $scroll = $this->FB_ACTION( '#{EnableEmail}status', 'b' );

    if ( $seen && !$perlAvail ) {
        return (
            0,
            $this->NOTE($seen)
              . $this->ERROR(
"Please configure a mail program manually, or install Net::SMTP."
              )
              . $scroll
        );
    }
    if ( $seen && $perlAvail < 0 ) {
        return (
            0,
            $this->ERROR(
                $seen
                  . " and Net::SMTP configuration failed.  Please correct the Net::SMTP parameters, or configure a mail program manually."
              )
              . $scroll
              . $this->FB_VALUE( '{Email}{MailMethod}', 'Net::SMTP' )
        );
    }
    if ( $seen && $perlAvail ) {
        return ( 0, $this->NOTE($seen) );
    }

    # No program found
    unless ($perlAvail) {
        return ( 0,
            $this->ERROR( $e . ".  Please install one, or install Net::SMTP." )
              . $scroll );
    }
    return ( 0, $this->NOTE("$e.") ) if ( $perlAvail > 0 );

    return (
        0,
        $this->ERROR(
            $e
              . ". and Net::SMTP configuration failed.  Please correct the Net::SMTP parameters, or install a mail program."
          )
          . $scroll
          . $this->FB_VALUE( '{Email}{MailMethod}', 'Net::SMTP' )
    );
}

# mailwrapper uses a config file
# look for the traditional 'sendmail' verb
# return program and its args - wrapper prepends
# these to the "user" args.

sub mailwrapperConfig {
    my $cfg = shift;

    open( my $cnf, '<', '/etc/mail/mailer.conf' )
      or return;
    while (<$cnf>) {
        next if (/^\s*#/);
        s/^\s+//g;
        chomp;
        my ( $cmd, $prog, $args ) = split( /\s+/, $_, 3 );
        if ( $cmd && $cmd eq 'sendmail' ) {
            close $cnf;
            return ( $prog, $args );
        }
    }
    close $cnf;
    return;
}

sub diagnoseFailure {
    my ( $noconnect, $allconnect ) = @_;

    my $blameSEL;
    {
        no warnings 'exec';

        my $selStatus = system("selinuxenabled");
        $blameSEL = 1
          unless ( $selStatus == -1
            || ( ( $selStatus >> 8 ) && !( $selStatus & 127 ) ) );
    }

    my $e = << "SELINUX";
<strong>Note:</strong> SELinux appears to be enabled on your system.
Please ensure that the SELinux policy permits SMTP connections from webserver processes
to at least one of these tcp ports: 587, 465 or 25.  Also ensure that your e-mail
client is permitted to be run under your webserver, and that it is permitted access to its
configuration data and temporary files in this security context.

Check the audit log for specific errors, as policies vary.</pre>
SELINUX

    # MailProgram probes don't send mail, so just a generic message if
    # SELinux is enabled.

    unless (@_) {
        return "<pre>$e" if ($blameSEL);
        return '';
    }

    # If no connection went through, there's probably a block

    if ($noconnect) {
        my $cx = "
<pre>No connection was established on any port, so if the e-mail server is
up, it is likely that a firewall";
        $cx .= "and/or SELINUX" if ($blameSEL);
        $cx .= " is blocking TCP connections
to e-mail submission ports.\n";

        return $cx . '</pre>' unless ($blameSEL);
        return "$cx\n$e";
    }

    # Some worked, some didn't

    unless ($allconnect) {
        my $cx = "
<pre>At least one connection was blocked, but others succeeded.  It is possible
that that a firewall";
        $cx .= "and/or SELINUX" if ($blameSEL);
        $cx .= " is blocking TCP connections to some e-mail submission port(s).
However, only one connection type needs to work, so you should focus on the\
issues logged on the ports where connections succeeded.\n\n";

        return $cx . '</pre>' unless ($blameSEL);
        return "$cx\n$e";
    }

    # All connections worked, but the protocol didn't.

    return <<"SMTP";
<pre>Although all connections were successful, the service is not speaking SMTP.
The most likely causes are that the server uses a non-standard port for SMTP,
or your configuration erroneously specifies a non-SMTP port.  Check your
configuration; then check with your server support.
SMTP
}

sub setMailProgram {
    my $this = shift;
    my ( $e, $cfg, $path ) = @_;

    $e .= $this->NOTE(
"Identified $cfg->{name} (<tt>$path/$cfg->{file}</tt>) as your mail program"
    );
    return (
        1,
        join(
            '', $e,
            diagnoseFailure(),
            $this->NOTE($acceptMsg),
            $this->FB_ACTION( '#{EnableEmail}status', 'b' ),
            $this->FB_VALUE( '{SMTP}{Debug}',       0 ),
            $this->FB_VALUE( '{Email}{MailMethod}', 'MailProgram' ),
            $this->FB_VALUE(
                '{MailProgram}', "$path/$cfg->{file} $cfg->{flags}"
            ),
            $this->FB_VALUE( '{SMTP}{DebugFlags}', $cfg->{debug} ),
            $this->FB_VALUE( '{EnableEmail}',      1 ),
            $this->FB_VALUE(
                '{SMTP}{MAILHOST}',
                ' ---- Unused when MailProgram selected ---'
            ),
        )
    );
}

# autoconfig loosely parallels Net.pm
# Setup the best available connection to the e-mail server

sub perlFailed {
    my $this = shift;
    my ( $e, $msg, $options, $progTried ) = @_;

    if ($progTried) {
        return ( 0,
                $this->ERROR($e)
              . $this->FB_ACTION( '#{EnableEmail}status', 'b' )
              . $this->ERROR($msg)
              . $this->FB_VALUE( '{EnableEmail}', 0 )
              . $this->FB_VALUE( '{SMTP}{Debug}', 0 ) );
    }
    return ( 0, $e . $this->NOTE($msg) );
}

# autoconfiguration for Net::SMTP

# Global variables

our (
    $host,     $hInfo,     $port,       $hello,
    $inAuth,   $noconnect, $allconnect, $tlog,
    $tlsSsl,   $startTls,  $verified,   @sslopts,
    @sockopts, %systemAuthMethods,
);
our $pad = ' ' x length('Net::SMTpXXX ');

sub autoconfigPerl {
    my $this = shift;
    my ( $options, $progTried ) = @_;

    $SIG{__DIE__} = sub {
        Carp::confess($@);
    };

    my $e = $this->NOTE("Attempting to configure Net::SMTP");

    eval {
        require IO::Handle;
        require IO::Socket::SSL;
        IO::Socket::SSL->import('debug2')
          if ( $options->{debugssl}[0] );
    };
    return $this->perlFailed( $e,
        "Net::SMTP and IO::Socket::SSL are required to autoconfigure mail", @_ )
      if ($@);

    # Enable IPv6 if it's available

    @Net::SMTP::ISA = (
        grep( $_ !~ /^IO::Socket::I(?:NET|P)$/, @Net::SMTP::ISA ),
        'IO::Socket::IP'
    ) if ($IPv6Avail);

    $host = $Foswiki::cfg{SMTP}{MAILHOST};
    return $this->perlFailed( $e,
        "{SMTP}{MAILHOST} must be specified to use Net::SMTP", @_ )
      unless ( $host && $host !~ /^ ---/ );

    $hInfo = hostInfo($host);
    if ( $hInfo->{error} ) {
        return $this->perlFailed( $e,
            "{SMTP}{MAILHOST} is not valid: " . $hInfo->{error}, @_ );
    }
    $host = $hInfo->{name};

    my @addrs;
    if ($IPv6Avail) {

        # IO::Socket::IP will handle multiple addresses/address families
        # in the right order if we pass $host, but passing the list lets
        # us log which addresses work and which don't.
        push @addrs, @{ $hInfo->{addrs} };
    }
    else {
        # Net::SMTP will iterate
        @addrs = @{ $hInfo->{v4addrs} };
        if ( @{ $hInfo->{v6addrs} } ) {
            $e .= $this->WARN(
"$host has an IPv6 address, but IO::Socket::IP is not installed.  IPv6 can not be used."
            );
        }
    }
    @addrs
      or return $this->perlFailed( $e,
        "{SMTP}{MAILHOST} $host is invalid: server has no IP address", @_ );

    my @options = (
        Debug   => 1,
        Host    => [@addrs],
        Timeout => ( @addrs >= 2 ? 10 : 30 ),
    );

    if ( ( $hello = $Foswiki::cfg{SMTP}{SENDERHOST} ) ) {
        push @options, Hello => ($hello);
    }
    else {
        require Net::Domain;
        $hello = Net::Domain::hostfqdn();
        $hello = "[$hello]"
          if ( $hello =~ /^(?:$IPv4Re|$IPv6ZidRe)$/ );
        push @options, Hello => $hello;
    }

    $inAuth     = 0;
    $noconnect  = 1;
    $allconnect = 1;

    my $log = bless {}, 'Foswiki::Configure::Checkers::EnableEmail::Mailer';

    # Get SSL options common to all secure connection methods

    ( $e, my ( $sslNoVerify, $sslVerify ) ) =
      setupSSLoptions( $log, $this, $e );

    # Connection methods in priority order
    my @methods = (qw/starttls-v starttls tls-v tls ssl-v ssl smtp/);

    # Configuration data for each method.  Ports in priority order.

    my $sockSSLisa = [
        grep( $_ !~ /^IO::Socket::I(?:NET|P)$/, @Net::SMTP::ISA ),
        'IO::Socket::SSL'
    ];

    my %config = (
        starttls => {
            ports    => [qw/submission(587) smtp(25)/],
            method   => 'Net::SMTP (STARTTLS)',
            isa      => [@Net::SMTP::ISA],
            ssl      => [ SSL_version => 'TLSv1' ],
            starttls => 1,
        },
        tls => {
            ports  => [qw/smtps(465)/],
            method => 'Net::SMTP (TLS)',
            isa    => $sockSSLisa,
            ssl    => [ SSL_version => 'TLSv1' ],
        },
        ssl => {
            ports  => [qw/smtps(465)/],
            method => 'Net::SMTP (SSL)',
            isa    => $sockSSLisa,
            ssl    => [ SSL_version => 'SSLv3' ],
        },
        smtp => {
            ports  => [qw/submission(587) smtp(25)/],
            method => 'Net::SMTP',
            isa    => [@Net::SMTP::ISA],
        },
    );
    @Net::SMTP::ISA = 'Foswiki::Configure::Checkers::EnableEmail::SSL';

    # Generate configurations with peer verification

    foreach my $method (@methods) {
        if ( $method =~ /^(.*)-v$/ ) {
            if (@$sslVerify) {
                die "Invalid config for $method\n"
                  unless ( exists $config{$1} );

                $config{$method} = { %{ $config{$1} } };
                $config{$method}{ssl} =
                  [ @{ $config{$method}{ssl} }, @$sslVerify ];
                $config{$method}{id}     = uc($1) . " WITH host verification";
                $config{$method}{verify} = 1;
            }
            else {
                delete $config{$method};
            }
        }
    }

    # Generate methods without peer verification

    foreach my $method (@methods) {
        next unless ( exists $config{$method} );
        if ( $method !~ /-v$/ && exists $config{$method}{ssl} ) {
            push @{ $config{$method}{ssl} }, @$sslNoVerify;
            $config{$method}{id} = uc($method) . " with NO host verification";
        }
    }

    # If port forced, try to find name.
    # The smtp names are secondary for some traditional ports, so
    # use the primary for those.  For others, consult /etc/services.

    $port = $hInfo->{port};
    if ( $port && $port =~ /^\d+$/ ) {
        my $name = {
            25  => 'smtp(25)',
            587 => 'submission(587)',
            465 => 'smtps(465)',
        }->{$port};
        unless ( defined $name ) {
            $name = getservbyport( $port, 'tcp' );

            #            $name = "$name($port)" if ( defined $name );
            if ( defined $name ) {
                $name = "$name($port)";
                $name =~ /^(.*)$/;
                $name = $1;
            }
        }
        $port = $name if ( defined $name );
    }

    # Authentication data

    my $username = $Foswiki::cfg{SMTP}{Username};
    $username = '' unless ( defined $username );
    my $password = $Foswiki::cfg{SMTP}{Password};
    $password = '' unless ( defined $password );

    # SSL logging -- N.B. fd 2 is NOT STDERR from here down

    open( my $stderr, ">&STDERR" ) or die "STDERR: $!\n";
    close STDERR;
    open( my $fd2, ">/dev/null" ) or die "fd2: $!\n";
    $tlog = '';
    open( STDERR, '+>>', \$tlog ) or die "SSL logging: $!\n";
    STDERR->autoflush(1);

    # Loop over methods - output @use if one succeeds

    my @use;
  METHOD:
    foreach my $method (@methods) {
        my $cfg = $config{$method};
        next unless ($cfg);

        my @ports = $port ? ($port) : @{ $cfg->{ports} };

        # Manage carp in libnet with debug > 0
        # This gives us hidden errors such as Timeout, EOF,
        # and unsupported commands.

        local $SIG{__WARN__} = sub {
            my $msg = $_[0];
            $msg =~ s/^.*GLOB\(0x[[:xdigit:]]+\): //;
            if (0) {    # Turn on for debuging
                Carp::confess($msg);
            }
            else {
                $msg =~ s/ at .*$//ms;
            }
            chomp $msg;
            $tlog .= "${pad}Failed: $msg\n";
            return undef;
        };

        # IGNORE SIGPIPE caused by errors that cause Net::Cmd to close
        # the TCP connection - then write to it.
        local $SIG{PIPE} = 'IGNORE';

        foreach our $port (@ports) {
            $tlsSsl  = $cfg->{ssl};
            @sslopts = $tlsSsl ? ( @$tlsSsl, SSL_verifycn_name => $host, ) : ();
            $tlsSsl  = 0
              if ( $startTls = $cfg->{starttls} );

            @Foswiki::Configure::Checkers::EnableEmail::SSL::ISA =
              @{ $cfg->{isa} };

            $tlog = '<pre>'
              . "${pad}Testing "
              . ( $cfg->{id} || uc($method) ) . " on "
              . (
                  $port =~ /^\d+$/           ? "port $port\n"
                : $port =~ /^(.*)\((\d+)\)$/ ? "$1 port ($2)\n"
                : "$port port\n"
              );
            $verified = $cfg->{verify} || -1;

            my $smtp =
              Foswiki::Configure::Checkers::EnableEmail::Mailer->new( @options,
                Port => $port );
            unless ($smtp) {
                $e .= $this->NOTE( $tlog . "</pre>" );
                next;
            }
            if ($tlsSsl) {
                $tlog .= $pad
                  . (
                      $verified < 0 ? "Server verification is disabled"
                    : $verified     ? "Server certificate verified"
                    : "Unable to verify server certificate"
                  ) . "\n";
                if ( $verified == 0 ) {
                    $smtp->close;
                    $e .= $this->NOTE( $tlog . '</pre>' );
                    next;
                }
            }
            if ($startTls) {
                next unless ( $smtp->starttls( $log, $this, \$e ) );
            }
            @use = ( $cfg, $port );
            push @use, $smtp->testServer( $host, $username, $password );
            $smtp->quit;

            last METHOD if ( $use[2] >= 0 );
            $e .= $tlog . '</pre>' . $use[3];
            @use = ();
        }
    }
    close STDERR;
    close $fd2;
    open( STDERR, '>&', $stderr ) or die "stderr:$!\n";
    close $stderr;

    unless (@use) {
        $e .= Foswiki::Configure::Checkers::EnableEmail::diagnoseFailure(
            $noconnect, $allconnect );
        return $this->perlFailed( $e, "Autoconfiguration failed", @_ );
    }

    #  @use[ cfg, port, authOK, authMsg ]
    if ( $use[2] == 0 ) {    # Incomplete
        $e .=
          $this->NOTE( $tlog
              . "</pre>This configuration appears to be acceptable, but testing is incomplete."
          )
          . $this->ERROR( $use[3] )
          . $this->FB_VALUE( '{EnableEmail}', 0 );
    }
    elsif ( $use[2] == 1 || $use[2] == 4 ) {    # OK, Not required
        $e .=
            $this->NOTE( $tlog . $use[3], "</pre>$acceptMsg" )
          . $this->FB_VALUE( '{EnableEmail}', 1 );
    }
    elsif ( $use[2] == 2 ) {                    # Bad credentials
            # Authentication failed, perl is OK, don't try program.
        return ( 1, $e . $tlog . "</pre>" . $this->ERROR( $use[3] ) );
    }
    else {    # Other failure
        return $this->perlFailed(
            $e,
            $tlog
              . '</pre>'
              . $this->ERROR( $use[3] )
              . "Although a connection was established with $host on port $use[1], it did not accept mail.",
            @_
        );
    }

    $use[1] =~ s/^.*\((\d+)\)$/$1/;
    $host = "[$host]" if ( $hInfo->{ipv6addr} );
    my $cfg = $use[0];
    $e .= join( '',
        $this->FB_ACTION( '#{EnableEmail}status', 'b' ),
        $this->FB_VALUE( '{SMTP}{Debug}',       0 ),
        $this->FB_VALUE( '{Email}{MailMethod}', $cfg->{method} ),
        $this->FB_VALUE( '{SMTP}{SENDERHOST}',  $hello ),
        $this->FB_VALUE( '{SMTP}{Username}',    $username ),
        $this->FB_VALUE( '{SMTP}{Password}',    $password ),
        $this->FB_VALUE( '{SMTP}{MAILHOST}',    $host . ':' . $use[1] ),
    );
    $e .= $this->FB_VALUE( '{Email}{SSLVerifyServer}', ( $cfg->{verify} || 0 ) )
      if ( $cfg->{ssl} );

    return ( 1, $e );
}

# Support routines

# Compute SSL options lists for both peer verification on and off.
# If on is disabled, its list will be empty.

sub setupSSLoptions {
    my ( $log, $this, $e ) = @_;

    # Baseline: must trap errors to get accurate error reporting

    my @sslCommon = (
        SSL_error_trap => sub {
            my ( $sock, $msg ) = @_;
            if ( $sock->connected ) {
                $tlog .=
                    $pad
                  . "Failed to initialize SSL with "
                  . $sock->peerhost . ':'
                  . $sock->peerport
                  . " - $msg"
                  if ($verified);
            }
            else {
                $tlog .= "SSL error while not connected - $msg";
            }
            $sock->close;
            return;
        },
    );

    # Client verification data

    if (   $Foswiki::cfg{Email}{SSLClientCertFile}
        || $Foswiki::cfg{Email}{SSLClientKeyFile} )
    {
        my ( $certFile, $keyFile ) = (
            $Foswiki::cfg{Email}{SSLClientCertFile},
            $Foswiki::cfg{Email}{SSLClientKeyFile}
        );
        Foswiki::Configure::Load::expandValue($certFile);
        Foswiki::Configure::Load::expandValue($keyFile);

        if ( $certFile && $keyFile ) {
            push @sslCommon,
              (
                SSL_use_cert  => 1,
                SSL_cert_file => $certFile,
                SSL_key_file  => $keyFile
              );
            if ( $Foswiki::cfg{Email}{SSLClientKeyPassword} ) {
                push @sslCommon, SSL_passwd_cb => sub {
                    return $Foswiki::cfg{Email}{SSLClientKeyPassword};
                };
            }
        }
        else {
            $e .= $this->WARN(
"Client verification requires both {Email}{SSLClientCertFile} and {Email}{SSLClientKeyFile} to be set."
            );
        }
    }

    # SSL options lists with and without peer verification

    my ( @sslVerify, @sslNoVerify );
    @sslNoVerify =
      ( @sslCommon, SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE() );

    if ( $Foswiki::cfg{Email}{SSLVerifyServer} ) {
        my ( $file, $path ) =
          ( $Foswiki::cfg{Email}{SSLCaFile}, $Foswiki::cfg{Email}{SSLCaPath} );
        Foswiki::Configure::Load::expandValue($file);
        Foswiki::Configure::Load::expandValue($path);

        if ( $file || $path ) {
            push @sslVerify, (
                @sslCommon,
                SSL_verify_mode     => IO::Socket::SSL::SSL_VERIFY_PEER(),
                SSL_verify_scheme   => undef,
                SSL_verify_callback => sub {
                    my ( $ok, $ctx, $names, $errs, $peerCert ) = @_;

                    return
                      Foswiki::Configure::Checkers::EnableEmail::SSL::sslVerifyCert(
                        $log, $ok, $ctx, $peerCert );
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

                if ( $file || $path ) {
                    push @sslVerify, SSL_check_crl => 1;
                    push @sslVerify, SSL_crl_file  => $file
                      if ($file);
                }
                else {
                    $e .= $this->WARN(
"{Email}{SSLCheckCRL} requires CRL verification but neither {Email}{SSLCrlFile} nor {Email}{SSLCaPath} is set."
                    );
                }
            }
        }
        else {
            $e .= $this->WARN(
"{Email}{SSLVerifyServer} requires host verification but neither {Email}{SSLCaFile} nor {Email}{SSLCaPath} is set."
            );
        }
    }

    return ( $e, [@sslNoVerify], [@sslVerify] );
}

# Net::SMTP extensions
#
# Package for extended logging

package Foswiki::Configure::Checkers::EnableEmail::Mailer;

require MIME::Base64;

our @ISA = (qw/Net::SMTP/);

sub debug_text {
    my $cmd = shift;
    my $out = shift;

    my $text = join( '', @_ );
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
    my ( $cmd, $out, $text, $hok ) = @_;

    chomp $text;
    my $tag = $ISA[0] . ( $out ? '>>> ' : '<<< ' );
    $text = $tag
      . join( "\n$tag -- ",
        map $cmd->debug_text( $out, $_ ),
        split( /\r?\n/, $text, -1 ) )
      . "\n";

    $text =~ s/([&'"<>])/'&#'.ord( $1 ) .';'/ge unless ($hok);
    $tlog .= $text;
}

# Package for extended SSL functions

package Foswiki::Configure::Checkers::EnableEmail::SSL;

BEGIN {
    Foswiki::IP->import(qw/$IPv6Avail/);
}

our @ISA;

# Intercept new() socket issued by Net::SMTP

sub new {
    my $class = shift;

    @sockopts = ( @_, @sslopts );

    my ( $log, %opts );
    $log = bless {}, $class;
    if ( $tlsSsl || $startTls ) {
        %opts = @sockopts;
        $log->logSSLoptions( \%opts );
    }

    my $sclass =
        $tlsSsl    ? 'IO::Socket::SSL'
      : $IPv6Avail ? 'IO::Socket::IP'
      :              'IO::Socket::INET';
    $! = 0;
    $@ = '';
    my $sock = $sclass->new(@sockopts);
    if ($sock) {
        bless $sock, $class;
        $noconnect = 0;
        my $peer = $sock->peerhost . ':' . $sock->peerport;
        if ($tlsSsl) {
            $sock->debug_print( 0,
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
    else {
        my $peer = $opts{PeerHost}    || $opts{PeerAddr} || '';
        my $port = $opts{PeerService} || $opts{PeerPort} || '';
        $peer = "$peer on $port" if ($port);
        $log->debug_print(
            0,
            "Unable to establish connection with $peer: "
              . (
                     ( ($!) ? $@ || $! : 0 )
                  || ( $tlsSsl && IO::Socket::SSL::errstr() )
              )
              . "\n"
        ) if ($verified);
        $allconnect = 0;
    }
    return $sock;
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

# STARTTLS connection upgrade

sub starttls {
    my $smtp = shift;
    my ( $log, $this, $e ) = @_;

    unless ( defined $smtp->supports('STARTTLS') ) {
        $smtp->quit;
        $$e .= $this->NOTE( $tlog,
            "${pad}STARTTLS is not supported by $host</pre>" );
        return 0;
    }
    unless ( $smtp->command('STARTTLS')->response() == 2 ) {
        $smtp->quit;
        $$e .= $this->NOTE( $tlog . "${pad}STARTTLS command failed</pre>" );
        return 0;
    }

    my $mailobj = ref $smtp;

    unless ( IO::Socket::SSL->start_SSL( $smtp, @sockopts, ) ) {
        $tlog .= $pad . IO::Socket::SSL::errstr() . "\n" if ($verified);
        $$e .= $this->NOTE( $tlog . "${pad}Upgrade to TLS failed</pre>" );

        # Note: The server may still be trying to talk SSL; we can't quit.
        $smtp->close;
        return 0;
    }
    @ISA =
      ( grep( $_ !~ /^IO::Socket::I(?:NET|P)$/, @ISA ), 'IO::Socket::SSL' );
    bless $smtp, $mailobj;
    $smtp->debug_print( 0,
            "Started TLS using "
          . $smtp->get_cipher
          . " encryption\nServer Certificate:\n"
          . fmtcertnames( $smtp->dump_peer_certificate ) );

    $tlog .= $pad
      . (
          $verified < 0 ? "Server verification is disabled"
        : $verified     ? "Server certificate verified"
        : "Unable to verify server certificate"
      ) . "\n";
    if ( $verified == 0 ) {
        $$e .= $this->NOTE( $tlog . '</pre>' );
        $smtp->close;
        return 0;
    }

    unless ( $smtp->hello($hello) ) {
        $$e .= $this->NOTE( $tlog . "${pad}Hello failed</pre>" );
        $smtp->quit();
        return 0;
    }
    return 1;

}

# Handle host verification manually so we can report issues

my %verifyErrors = (
    2 =>
"The issuer of a looked-up certificate could not be found.  This is probably a root certificate that is not in {Email}{SSLCaFile} or {Email}{SSLCaPath}..\n",
    18 => "The server certificate is self-signed, but not trusted.\n"
      . "Verify that it is valid, then add it to {Email}{SSLCaFile} or {Email}{SSLCaPath}\n",
    19 =>
"A self-signed certificate is in the chain, but that certificate is not trusted.\n"
      . "Verify that it is valid, then add it to {Email}{SSLCaFile} or {Email}{SSLCaPath}\n",
    20 =>
"The issuer's certificate could not be found.  The server may not be providing an intermediate CA certificate, or if the issuer is a root CA, the root certificate is not in {Email}{SSLCaFile} or {Email}{SSLCaPath}.\n",
    21 =>
"The server only provided one certificate, and it's issuer is not trusted\n"
      . "The server may need to supply intermediate CA certificates, use a trusted CA, or you may need to add the issuer certificate to {Email}{SSLCaFile} or {Email}{SSLCaPath}\n",
    22 =>
"The chain of certificates required to validate this server is more than 20 deep.  The certificate chain is too expensive to verify.",
    24 =>
"An intermediate or root certificate must be a CA certificate, and must be authorized to issue server certificates.\n"
      . "A certificate was encountered that failed one of these tests.\n",
    26 => "The server certificate is not authorized to identify a TLS Server\n",
    27 =>
      "The root CA is not marked trusted for issuing TLS server certificates\n",
    28 => "The root CA does not allow TLS server certificates\n",
);

sub sslVerifyCert {
    my ( $log, $ok, $ctx, $peerCert ) = @_;

    # A server must have a certificate, so this shouldn't happen.

    unless ( $ctx && $peerCert ) {
        $log->debug_print( 0, "Verify:   No certificate was supplied" );
        return 0;
    }

    # Get certificate at current level of chain
    # Note: The chain is built from the server up to the root,
    #       then verified from the root down to the server.
    #       Depth increases from 0 (the server) to n (the root)

    my $cert  = Net::SSLeay::X509_STORE_CTX_get_current_cert($ctx);
    my $error = Net::SSLeay::X509_STORE_CTX_get_error($ctx);
    my $depth = Net::SSLeay::X509_STORE_CTX_get_error_depth($ctx);

    my $issuerName =
      Net::SSLeay::X509_NAME_oneline(
        Net::SSLeay::X509_get_issuer_name($cert) );
    my $subjectName =
      Net::SSLeay::X509_NAME_oneline(
        Net::SSLeay::X509_get_subject_name($cert) );

    if ( $depth > 20 ) {
        $error = 22;    #X509_V_ERR_CERT_CHAIN_TOO_LONG
        Net::SSLeay::X509_STORE_CTX_set_error( $ctx, $error );
        $ok = 0;
    }
    if ($ok) {
        $verified = 1 if ( $verified < 0 );
        $log->debug_print( 0,
            "Verified: " . fmtcertnames( "$subjectName\n", 'Verified: ', -4 ) );

        if ( $depth == 0 ) {
            my $host = {@sockopts}->{SSL_verifycn_name};

            my $rv = IO::Socket::SSL::verify_hostname_of_cert(
                $host,
                $peerCert,
                {
                    check_cn         => 'when_only',
                    wildcards_in_alt => 'leftmost',
                    wildcards_in_cn  => 'leftmost',
                }
            );
            if ($rv) {
                $log->debug_print( 0,
                    "Verified: $host is a subject of this certificate\n" );
            }
            else {
                $verified = $ok = 0;
                my $msg =
"Verify:   $host is not a commonName or subjectAltName of this certificate\n";
                my $indent = ' ' x ( length('Verify:   ') - length(' -- ') );
                my @alt = Net::SSLeay::X509_get_subjectAltNames($peerCert);
                if (@alt) {
                    $msg .= "${indent}Certificate subjectAltName"
                      . ( @alt != 1 ? 's' : '' ) . ":\n";
                    while (@alt) {
                        my ( $type, $name ) = splice( @alt, 0, 2 );
                        if ( $type == IO::Socket::SSL::GEN_IPADD() ) {
                            if ( length($name) == 16 ) {
                                eval {
                                    require Socket;
                                    $name =
                                      Socket::inet_ntop( Socket::AF_INET6(),
                                        $name );
                                    return $name;
                                };
                                $name = 'IPv6 address' unless ( defined $name );
                            }
                            elsif ( length($name) == 4 ) {
                                require Socket;
                                $name = Socket::inet_ntoa($name);
                            }
                            else {
                                $name = "Unknown IP address";
                            }
                            $msg .= "${indent}    IP: $name\n";
                        }
                        elsif ( $type == IO::Socket::SSL::GEN_DNS() ) {
                            $msg .= "${indent}    DNS: $name\n";
                        }
                    }
                }
                $log->debug_print( 0, $msg );
            }
        }
    }
    else {
        $verified = 0;
        my $msg =
            "Verify:   "
          . Net::SSLeay::X509_verify_cert_error_string($error) . "\n"
          . fmtcertnames(
            "Subject Name: $subjectName\nIssuer  Name: $issuerName\n")
          . ( $verifyErrors{$error} || '' );
        $log->debug_print( 0, $msg, 0 );

        my $port = $port;
        $port = $1 if ( $port =~ m,\((\d+)\)$, );
        $msg =
"Verify:   The server certificate may be viewed with the openssl command\n<i>openssl s_client -connect $host:$port"
          . ( $startTls ? " -starttls smtp" : '' )
          . " -showcerts</i>\n"
          . "The <i>openssl verify</i> command may provide more information.\n";
        $log->debug_print( 0, $msg, 1 );
    }
    return $ok;
}

# Return enhanced status code if available

sub rspCode {
    my $smtp = shift;

    my $code = $smtp->code;
    if ( $code =~ /^[245]/ && defined $smtp->supports('ENHANCEDSTATUSCODES') ) {
        my $msg = $smtp->message;
        if ( $msg =~ /^([245]\.\d{1,3}\.\d{1,3})\b/ ) {
            return ( $code, $1 );
        }
    }
    return ( $code, '' );
}

# Test server to determine authentication requirements
# Ensures it will relay.

sub testServer {
    my $smtp = shift;
    my ( $host, $username, $password ) = @_;
    shift;

    # Attempt a DSN-style send to another domain.
    # If authentication is required to relay, the
    # server will indicate that here.  If not,
    # authentication is not required.
    # The session is reset so no mail is actually sent.

    my ( $fromTestAddr, $toTestAddr ) =
      (qw/postmaster@example.net postmaster@example.com/);
    my ( @code, $requires );

    my $noAuthOk = $smtp->mail($fromTestAddr) && $smtp->to($toTestAddr);
    unless ($noAuthOk) {
        @code = $smtp->rspCode;
        $smtp->reset;

        # 530 5.7.0 Auth req 540/550 5.7.1 no relay
        if ( !( $code[0] =~ /^5[345]0$/ || $code[1] =~ /^(?:5\.7\.[01])$/ ) ) {
            $tlog .=
"${pad}Message setup failed, but authentication was not requested.\n";
            return ( -1, '' );
        }
    }
    if ($noAuthOk) {
        $smtp->reset;
        my $m = "${pad}Authentication is not required";
        unless ( $username || $password ) {
            $m .= ".";
            @_[ 0, 1 ] = ( '', '' );
            return ( 4, "$m\n" );
        }
        $m .=
", but you have configured credentials.\n${pad}If you do not want to use these credentials, remove them from the configuration.\n${pad}Attempting to authenticate.\n";
        $tlog .= $m;
        $requires = 'supports';
    }
    else {
        $requires = 'requires';
    }

    # Get authentication methods server offers

    my $serverAuth;
    if (   !defined( $serverAuth = $smtp->supports('AUTH') )
        || !length $serverAuth )
    {
        if ($noAuthOk) {
            @_[ 0, 1 ] = ( '', '' );
            return ( 4,
"${pad}Server does not offer authentication.  Please remove the credentials.\n"
            );
        }
        if ( defined $hInfo->{port} ) {
            if ( $tlsSsl || $startTls ) {
                return ( 3,
"Authentication is required by $host, but not offered, although this is a secure connection.  Try removing the port specification in {SMTP}{MAILHOST} to allow testing other ports, or obtain the correct port number from the operators of $host\n"
                );
            }
            return ( 3,
"Authentication is required by $host, but not offered.  This is not a secure connection, which can cause this condition.  Secure connection methods have already been tested.  Try removing the port specification in {SMTP}{MAILHOST} to allow testing other ports, or obtain the correct port number from the operators of $host\n"
            );
        }

        $tlog .=
          "${pad}Authentication is required by $host, but not offered.\n";
        return ( -1, '' );
    }

    # Find intersection with methods we support

    my @serverAuth = split( /\s+/, $serverAuth );
    my $ok = 0;

    # Obtain and cache system's authentication methods.

    %systemAuthMethods = ( none => 1, map { uc($_) => 1 } $smtp->authValid() )
      unless ( keys %systemAuthMethods );

    foreach my $method (@serverAuth) {
        if ( $systemAuthMethods{ uc($method) } ) {
            $ok = 1;
            last;
        }
    }
    unless ($ok) {
        $tlog .=
"${pad}You can proceed without authentication by removing the credentials.\n"
          if ($noAuthOk);

        return ( 3,
"<strong>$host</strong> $requires authentication, but your system doesn't support any authentication methods.  Either Authen::SASL is not installed, or it is not in \@INC.\n"
        ) unless (@serverAuth);
        return ( 3,
"<strong>$host</strong> $requires authentication, but will not accept any authentication method that your system supports.<pre>$host will accept "
              . ( @serverAuth > 1 ? "these methods: " : "only:" )
              . join( ', ', sort @serverAuth )
              . "\nYour system supports: "
              . join( ', ', sort grep $_ ne 'none', keys %systemAuthMethods )
              . ".\nEither the server needs to be reconfigured to accept one of these methods, or you need to install a SASL::Authen module for a mechanism that the server will accept.\n"
        );
    }

    # See if we have credentials to use

    unless ( length $username && length $password ) {
        return (
            0,
            'Unable to test authentication: '
              . (
                  length $username ? "Password is"
                : length $password ? "Username is"
                : "Username and password are"
              )
              . " required.\n"
        );
    }

    # Provide the credentials and see if they are accepted.

    local $inAuth = 1;
    unless ( $smtp->auth( $username, $password ) ) {
        @code = $smtp->rspCode;

        # 535 5.7.8 Authentication credentials invalid

        if ( ( $code[0] =~ /^535$/ || $code[1] =~ /^(?:5\.7\.8)$/ ) ) {
            return (
                2,
                "$host rejected the supplied username and password.
Please verify that configured username and password are valid for $host.\n"
            );
        }

        # 454 4.7.0 Temporary authentication failure
        if ( ( $code[0] =~ /^454$/ || $code[1] =~ /^(?:4\.7\.0)$/ ) ) {
            return ( 3,
"$host is unable to validate your credentials at this time.  Please try again later.\n"
            );
        }

        return ( 0, "Authentication failed\n" );
    }
    $inAuth = 0;

    # Retry the null DSN

    $ok = $smtp->mail($fromTestAddr) && $smtp->to($toTestAddr);
    $smtp->reset;
    if ($ok) {
        return ( 1,
            "${pad}$host is willing to accept mail with these credentials.\n" );
    }

    # Demanded authentication, but won't accept mail.

    return (
        3,
"$host accepted username and password, but will not accept mail with these credentials.<br />
It probably needs to be configured to accept mail from your system, or your system may need a different (probably static) IP address, or it may be on a block list.  The preceding log should provide more detail."
    );
}

# Return list of mechanisms that this system supports.
# These are implemented by Authen::SASL plugins, which
# live in @INC/Authen/SASL and its perl directory.
# There may be duplicates, but that's handled by the
# caller.

sub authValid {
    my $smtp = shift;

    my @auths;
    foreach my $path (@INC) {
        my $authdir = "$path/Authen/SASL";
        next unless ( -d "$path/Authen/SASL" );
        push @auths, $smtp->authScan($authdir);
        push @auths, $smtp->authScan("$authdir/Perl");
    }
    return @auths;
}

# Find Auth::SASL mechanism (method) modules
# The are filenames in all upper case, plus
# digits and underscore.

sub authScan {
    my $smtp = shift;
    my ($path) = @_;

    my @found;
    opendir( my $dh, $path ) or return @found;
    while ( defined( my $file = readdir($dh) ) ) {
        next if ( $file =~ /^\./ );
        next unless ( $file =~ /^([A-Z0-9_]+)\.pm$/ );
        push @found, $1;
    }
    closedir $dh;
    return @found;
}

# Format certificate names for display

sub fmtcertnames {
    my ( $names, $label, $offset ) = @_;

    my $out = '';
    my $wrap =
      ( ' ' x ( length( $label || 'Subject Name: ' ) + ( $offset || 0 ) ) );

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
