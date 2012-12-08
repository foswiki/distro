# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::EnableEmail;

use strict;
use warnings;

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

    # There is no need to run check() for the currently-defined action buttons.

    #    my $e = $button ? $this->check($valobj) : '';
    my $e;

    my $keys = $valobj->getKeys();

    delete $this->{FeedbackProvided};

    # For button 1, try to autoconfigure the host

    if ( $button == 1 ) {
        my @optionList = $this->parseOptions();

        $optionList[0] = {} unless (@optionList);

        $e .=
          $this->ERROR(".SPEC error: multiple CHECK options for {EnableEmail}")
          if ( @optionList > 1 );

        $e .= $this->autoconfig( $optionList[0] );
    }

    return wantarray ? ( $e, 0 ) : $e;
}

sub autoconfig {
    my $this = shift;
    my ($options) = @_;

    my $e = '';

    # Prefer perl or program?

    my $preferPerl = ( $options->{prefer}[0] || 'perl' ) =~ /^perl$/i;

    my $perlAvail = eval "require Net::SMTP";

    unless ($perlAvail) {
        return ( $this->autoconfigProgram( $options, 0 ) )[1];
    }

    if ($preferPerl) {
        ( my $ok, $e ) = $this->autoconfigPerl( $options, 0 );
        return $e if ($ok);
        return $e . ( $this->autoconfigProgram( $options, -1 ) )[1];
    }
    ( my $ok, $e ) = $this->autoconfigProgram( $options, 1 );
    return $e if ($ok);
    return $e . ( $this->autoconfigPerl( $options, -1 ) )[1];
}

sub autoconfigProgram {
    my $this = shift;
    my ( $options, $perlAvail ) = @_;

    my $e = '';

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
                        return $this->setMailProgram( $cfg, $p );
                    }
                }
            }
        }

        # Not found, must map /usr/sbin/sendmail to the tool

        $mailp = 'sendmail';
        $e     = 'Unable to locate a known external mail program';
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
                    return $this->setMailProgram( $cfg, $p );
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

    my $selStatus = system("selinuxenabled");
    my $blameSEL  = 1
      unless ( $selStatus == -1
        || ( ( $selStatus >> 8 ) && !( $selStatus & 127 ) ) );

    my $e .= << "SELINUX";
<strong>Note:</strong> SELinux appears to be enabled on your system.
Please ensure that the SELinux policy permits SMTP connections from webserver processes
to at least one of these tcp ports: 587, 465 or 25.  Also ensure that your e-mail
client is permitted to be run under your webserver, and that it is premitted access to its
configuration data and temporary files in this security context.

Check the audit log for specific errors, as policies vary.</pre>
SELINUX

    # MailProgram probes don't send may, so just a generic message if
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
    my ( $cfg, $path ) = @_;

    my $e = "";

    $e .= $this->NOTE("Identified $cfg->{name} as your mail program");
    return (
        1,
        join(
            '', $e,
            diagnoseFailure(),
            $this->FB_ACTION( '#{EnableEmail}status', 'b' ),
            $this->FB_VALUE( '{SMTP}{Debug}',       0 ),
            $this->FB_VALUE( '{Email}{MailMethod}', 'MailProgram' ),
            $this->FB_VALUE(
                '{MailProgram}', "$path/$cfg->{file} $cfg->{flags}"
            ),
            $this->FB_VALUE( '{SMTP}{DebugFlags}', $cfg->{debug} ),
            $this->FB_VALUE( '{EnableEmail}',      1 ),
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

sub autoconfigPerl {
    my $this = shift;
    my ( $options, $progTried ) = @_;

    my $e = '';

    eval {
        require IO::Handle;
        require IO::Socket::SSL;
        IO::Socket::SSL->import('debug2')
          if ( $options->{debugssl}[0] );
    };
    return $this->perlFailed( $e,
        "Net::SMTP and IO::Socket::SSL are required to autoconfigure mail", @_ )
      if ($@);

    return $this->perlFailed( $e,
        "{SMTP}{MAILHOST} must be specified to use Net::SMTP", @_ )
      unless ( $Foswiki::cfg{SMTP}{MAILHOST} );

    my ( $host, $port ) =
      $Foswiki::cfg{SMTP}{MAILHOST} =~ m/^([^:]+)(?::([0-9]{2,5}))?$/
      or return $this->perlFailed( $e,
        "Invalid syntax for {SMTP}{MAILHOST} host:port", @_ );

    my ( undef, undef, undef, undef, @addrs ) = gethostbyname($host);
    scalar @addrs
      or return $this->perlFailed( $e,
        "{SMTP}{MAILHOST} $host is invalid: server has no IP address", @_ );

    my @options = (
        Host => [ map { sprintf "%vd", $_ } @addrs ],
        Timeout => ( @addrs >= 2 ? 10 : 30 )
    );
    my $hello;
    if ( $this->{HELLO_HOST} ) {
        push @options, Hello => ( $hello = $this->{HELLO_HOST} );
    }
    else {
        require Net::Domain;
        $hello = Net::Domain::hostfqdn();
#<<<
        $hello = "[$hello]"
          if ( # IPv4 - IPv6 broken - see Regexp::Ipv6
            $hello =~ /^(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[1-9])\.
                        (?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[1-9])\.
                        (?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[1-9])\.
                        (?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[1-9])$/x
          );
#>>>
        push @options, Hello => $hello;
    }

    our $inAuth     = 0;
    our $noconnect  = 1;
    our $allconnect = 1;

    package Foswiki::Configure::Checkers::EnableEmail::Config;
    our @ISA = (qw/Net::SMTP/);

    our $tlog;
    my $mailobj = __PACKAGE__;

    require MIME::Base64;

    sub debug_text {
        my $cmd = shift;
        my $out = shift;

        my $text = join( '', @_ );
        if ($inAuth) {
            if ($out) {
                $text =~ s/[^\s]/*/g unless ( $inAuth++ == 1 );
            }
            else {
                my ( $code, $b64 ) = split( ' ', $text, 2 );
                $code ||= 0;
                $b64  ||= '';
                chomp $b64;
                $text = join( '',
                    $code, ' ', $b64, ' [', MIME::Base64::decode_base64($b64),
                    "]\n" )
                  if ( $code == 334 );
            }
        }
        return $text;
    }

    sub debug_print {
        my ( $cmd, $out, $text ) = @_;

        $text =
            $ISA[0]
          . ( $out ? '>>> ' : '<<< ' )
          . $cmd->debug_text( $out, $text );
        $text =~ s/([&'"<>])/'&#'.ord( $1 ) .';'/ge;
        $tlog .= $text;
    }

    package Foswiki::Configure::Checkers::EnableEmail::SSL;

    our @ISA;

    our ( $ssl, $tls, @sslopts, @sockopts );

    sub new {
        my $class = shift;

        @sockopts = ( @_, @sslopts );
        my $sock;
        $! = 0;
        $sock =
          $ssl
          ? IO::Socket::SSL->new(@sockopts)
          : IO::Socket::INET->new(@sockopts)
          and bless $sock, $class;
        if ($sock) {
            $noconnect = 0;
        }
        else {
            $tlog .= ( $! || ( $ssl && IO::Socket::SSL::errstr() ) ) . "\n";
            $allconnect = 0;
        }
        return $sock;
    }

    # Find Auth::SASL mechanism (method) modules

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

    # Return list of mechanisms that this system supports.

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

    our %systemAuthMethods;

    sub testAuth {
        my $smtp = shift;
        my ( $host, $username, $password ) = @_;

        my $serverAuth;
        unless ( defined( $serverAuth = $smtp->supports('AUTH') ) ) {
            @_[ 0, 1 ] = ( '', '' );
            return ( 2, "Authentication is not required" );
        }

        my @serverAuth = split( /\s+/, $serverAuth );
        my $ok;
        my %systemAuthMethods =
          ( none => 1, map { uc($_) => 1 } $smtp->authValid() )
          unless ( keys %systemAuthMethods );
        foreach my $method (@serverAuth) {
            if ( $systemAuthMethods{ uc($method) } ) {
                $ok = 1;
                last;
            }
        }
        unless ($ok) {
            return ( 0,
"<strong>$host</strong> requires authentication, but will not accept any authentication method that your system supports.<pre>This server will accept "
                  . ( @serverAuth > 1 ? "these methods: " : "only:" )
                  . join( ', ', sort @serverAuth )
                  . "\nYour system supports: "
                  . join( ', ', sort grep $_ ne 'none',
                    keys %systemAuthMethods )
                  . ".\n</pre>Either the server needs to be reconfigured to accept one of these methods, or you need to install a SASL::Authen module for a mechanism that the server will accept."
            );
        }

        unless ( length $username && length $password ) {
            return (
                0,
                'Unable to test authentication: '
                  . (
                      length $username ? "Password is"
                    : length $password ? "Username is"
                    : "Username and password are"
                  )
                  . " required"
            );
        }
        local $inAuth = 1;
        unless ( $smtp->auth( $username, $password ) ) {
            return ( 0,
"Authentication failed - verify that configured username and password are valid for $host"
            );
        }
        return ( 1, "$host accepted username and password" );
    }

    # Connection methods in priority order
    my @methods = (qw/starttls tls ssl smtp/);

    # Configuration data for each method.  Ports in priority order.
    my %config = (
        starttls => {
            ports  => [qw/submission(587) smtp(25)/],
            method => 'Net::SMTP (STARTTLS)',
            isa    => [@Net::SMTP::ISA],
            ssl    => [ SSL_version => 'TLSv1' ],
        },
        tls => {
            ports  => [qw/smtps(465)/],
            method => 'Net::SMTP (TLS)',
            isa    => [
                grep( $_ ne 'IO::Socket::INET', @Net::SMTP::ISA ),
                'IO::Socket::SSL'
            ],
            ssl => [ SSL_version => 'TLSv1' ],
        },
        ssl => {
            ports  => [qw/smtps(465)/],
            method => 'Net::SMTP (SSL)',
            isa    => [
                grep( $_ ne 'IO::Socket::INET', @Net::SMTP::ISA ),
                'IO::Socket::SSL'
            ],
            ssl => [ SSL_version => 'SSLv3' ],
        },
        smtp => {
            ports  => [qw/submission(587) smtp(25)/],
            method => 'Net::SMTP',
            isa    => [@Net::SMTP::ISA],
            ssl    => [],
        },
    );
    @Net::SMTP::ISA = __PACKAGE__;

    if ( $port && $port =~ /^\d+$/ ) {
        $port = {
            25  => 'smtp(25)',
            587 => 'submission(587)',
            465 => 'smtps(465)',
          }->{$port}
          || $port;
    }

    my $username = $Foswiki::cfg{SMTP}{Username};
    $username = '' unless ( defined $username );
    my $password = $Foswiki::cfg{SMTP}{Password};
    $password = '' unless ( defined $password );

    # SSL logging
    open( my $stderr, ">&STDERR" ) or die "STDERR: $!\n";
    close STDERR;
    open( STDERR, '+>>', \$tlog ) or die "SSL logging: $!\n";
    STDERR->autoflush(1);

    my @use;
  METHOD:
    foreach my $method (@methods) {
        my $cfg = $config{$method};
        my @ports = $port ? ($port) : @{ $cfg->{ports} };

        # Suppress carp in libnet with debug > 0
        local $SIG{__WARN__} = sub { };

        foreach my $port (@ports) {
            @sslopts = (
                @{ $cfg->{ssl} },
                SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE()
            );
            $ssl = $method =~ /^(tls|ssl)$/;
            @ISA = @{ $cfg->{isa} };

            $tlog = '<pre>';
            $tlog .=
                "Testing "
              . uc($method) . " on "
              . (
                  $port =~ /^\d+$/           ? "port $port\n"
                : $port =~ /^(.*)\((\d+)\)$/ ? "$1 port ($2)\n"
                : "$port port\n"
              );

            my $smtp = $mailobj->new(
                Debug => 1,
                @options,
                Port => $port,
            );
            unless ($smtp) {
                $e .= $this->NOTE( $tlog . "Connect failed</pre>" );
                next;
            }
            $tlog .=
              "Connected to " . $smtp->peerhost . ':' . $smtp->peerport . "\n";

            if ( $method eq 'starttls' ) {
                unless ( defined $smtp->supports('STARTTLS') ) {
                    $smtp->quit;
                    $e .= $this->NOTE( $tlog,
                        "STARTTLS is not supported by $host" );
                    next;
                }
                unless ( $smtp->command('STARTTLS')->response() == 2 ) {
                    $smtp->quit;
                    $e .= $this->NOTE( $tlog . "STARTTLS failed</pre>" );
                    next;
                }
                unless ( IO::Socket::SSL->start_SSL( $smtp, @sockopts ) ) {
                    $tlog .= IO::Socket::SSL::errstr() . "\n";
                    $e .= $this->NOTE( $tlog . "START SSL failed</pre>" );
                    $smtp->quit;
                    next;
                }
                @ISA =
                  ( grep( $_ ne 'IO::Socket::INET', @ISA ), 'IO::Socket::SSL' );
                bless $smtp, $mailobj;
                $tlog .= "TLS connection established\n";

                unless ( $smtp->hello( $this->{HELLO_HOST} ) ) {
                    $e .= $this->NOTE( $tlog . "Hello failed</pre>" );
                    $smtp->quit();
                    next;
                }
                @use = ( $cfg->{method}, $port );
                push @use, $smtp->testAuth( $host, $username, $password );
                $smtp->quit;
                last METHOD;
            }
            else {
                @use = ( $cfg->{method}, $port );
                push @use, $smtp->testAuth( $host, $username, $password );
                $smtp->quit;
                last METHOD;
            }
        }
    }
    close STDERR;
    open( STDERR, '>&', $stderr ) or die "stderr:$!\n";
    close $stderr;

    unless (@use) {
        $e .= Foswiki::Configure::Checkers::EnableEmail::diagnoseFailure(
            $noconnect, $allconnect );
        return $this->perlFailed( $e, "Autoconfiguration failed", @_ );
    }

    #  @use[ method, port, authOK, authMsg ]
    if ( $use[2] ) {
        $e .= $this->NOTE(
            $tlog . $use[3],
"</pre>Configuration accepted.<br />Next step:Setup and test {WebMasterEmail} on the <strong>Email General</strong> tab.\n"
        ) . $this->FB_VALUE( '{EnableEmail}', 1 );
    }
    else {
        $e .=
          $this->NOTE( $tlog
              . "</pre>This configuration appears to be acceptable, but testing is incomplete."
          )
          . $this->ERROR( $use[3] )
          . $this->FB_VALUE( '{EnableEmail}', 0 );
    }

    $use[1] =~ s/^.*\((\d+)\)$/$1/;
    return (
        1,
        join( '',
            $e,
            $this->FB_ACTION( '#{EnableEmail}status', 'b' ),
            $this->FB_VALUE( '{SMTP}{Debug}',       0 ),
            $this->FB_VALUE( '{Email}{MailMethod}', $use[0] ),
            $this->FB_VALUE( '{SMTP}{SENDERHOST}',  $hello ),
            $this->FB_VALUE( '{SMTP}{Username}',    $username ),
            $this->FB_VALUE( '{SMTP}{Password}',    $password ),
            $this->FB_VALUE( '{SMTP}{MAILHOST}',    $host . ':' . $use[1] ),
        )
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
