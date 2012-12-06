# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::EnableEmail;

use strict;
use warnings;

require Foswiki::Configure::Checker;
our @ISA = ('Foswiki::Configure::Checker');

# N.B. sendmail is correct.  The others are placeholders.
# Search order (specify hash key):
my @mtas = (qw/sendmail/);
my %mtas = (
    sendmail => {
        name => 'sendmail',    # Display name
        file => 'sendmail',    # Executable file to look for in PATH
        regexp =>
          qr/^sendmail(?:\.sendmail)?$/,   # Regexp to match basename from alias
        flags => '-t -oi -oeq',     # Flags used for sending mail
        debug => '-X /dev/stderr',  # Additional flags used to enable debug logs
    },

# Below this comment, the keys aren't in @mtas, and hence aren't used (yet).  The data
# is almost certainly wrong - these are simply placeholders.
# As these are investigated, validated, add the keys to @mtas and move above this line.

    postfix => {
        name   => 'sendmail',
        file   => 'postfix',
        regexp => qr/^postfix$/,
        flags  => '',
        debug  => '',
    },
    qmail => {
        name   => 'qmail',
        regexp => qr/^qmail$/,
        flags  => '',
        debug  => '',
    },
    sSMTP => {
        name   => 'sSMTP',
        regexp => qr/^ssmtp$/,
        flags  => '',
        debug  => '',
    },

    # ... etc
);

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

    my $mailp;

    # First, look for each mta on path
    # Identify it by it's realpath (/etc/alternatives...)
    my $path = $ENV{PATH};
    foreach my $mta (@mtas) {
        my $cfg = $mtas{$mta};
        foreach my $p ( split( /:/, $path ) ) {
            if ( -x "$p/$cfg->{file}" ) {
                $mailp = realpath("$p/$cfg->{file}");
                if ( ( fileparse($mailp) )[0] =~ $cfg->{regexp} ) {
                    return $this->setMailProgram( $cfg, $p );
                }
            }
        }
    }

    # Not found, most map /usr/sbin/sendmail to the tool

    $mailp = 'sendmail';
    $e     = 'Unable to locate a known external mail program';

    my $seen = '';
    foreach my $p ( '/usr/sbin', split( /:/, $path ) ) {
        if ( -x "$p/$mailp" ) {
            $mailp = ( fileparse( realpath("$p/$mailp") ) )[0];
            foreach my $mta (@mtas) {
                my $cfg = $mtas{$mta};
                if ( $mailp =~ $cfg->{regexp} ) {
                    return $this->setMailProgram( $cfg, $p );
                }
            }
            $seen .= "Unable to identify $p/$mailp.<br />";
            next;
        }
    }

    if ( $seen && !$perlAvail ) {
        return (
            0,
            $this->NOTE($seen)
              . $this->ERROR(
"Please configure a mail program manually, or install Net::SMTP."
              )
        );
    }
    if ( $seen && $perlAvail < 0 ) {
        return (
            0,
            $this->ERROR(
                $seen
                  . " and Net::SMTP configuration failed.  Please correct the Net::SMTP parameters, or configure a mail program manually."
            )
        );
    }
    if ( $seen && $perlAvail ) {
        return ( 0, $this->NOTE($seen) );
    }

    # No program found
    unless ($perlAvail) {
        return ( 0,
            $this->ERROR( $e . ".  Please install one, or install Net::SMTP." )
        );
    }
    return ( 0, $this->NOTE("$e.") ) if ( $perlAvail > 0 );

    return (
        0,
        $this->ERROR(
            $e
              . ". and Net::SMTP configuration failed.  Please correct the Net::SMTP parameters, or install a mail program."
        )
    );
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
                $e
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
          if (0);
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
        require Sys::Hostname;
        push @options, Hello => ( $hello = Sys::Hostname::hostname() );
    }

    our $inAuth = 0;

    package Foswiki::Configure::Checkers::SMTP::MAILHOST::CONFIG;
    our @ISA = (qw/Net::SMTP/);

    our $t;
    my $mailobj = __PACKAGE__;

    require MIME::Base64;

    sub debug_text {
        my $cmd = shift;
        my $out = shift;

        my $text = join( '', @_ );

        # Can't tell what's sensitive; mask text but show
        # spaces & length - still reveals something of
        # passwords, but allows dialog to be followed.
        # Assume first output is AUTH method, so don't mask that.
        if ($inAuth) {
            if ($out) {
                $text =~ s/[^\s]/*/g unless ( $inAuth++ == 1 );
            }
            else {
                my ( $code, $b64 ) = split( ' ', $text, 2 );
                $code ||= 0;
                $b64  ||= '';
                $text =
                  join( ' ', $code, MIME::Base64::decode_base64($b64) ) . "\n"
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
        $t .= $text;
    }

    package Foswiki::Configure::Checkers::SMTP::MAILHOST::SSL;

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
        unless ($sock) {
            $t .= ( $! || ( $ssl && IO::Socket::SSL::errstr() ) ) . "\n";
        }
        return $sock;
    }

    sub testAuth {
        my $smtp = shift;
        my ( $username, $password ) = @_;

        unless ( defined $smtp->supports('AUTH') ) {
            @_[ 0, 1 ] = ( '', '' );
            return ( 2, "Authentication is not required" );
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
'Authentication failed - verify that configured username and password are valid for this server'
            );
        }
        return ( 1, 'Server accepted username and password' );
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
    open( STDERR, '+>>', \$t ) or die "SSL logging: $!\n";
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

            $t = '<pre>';
            $t .=
                "Testing "
              . uc($method) . " on "
              . (
                  $port =~ /^\d+$/           ? "port $port\n"
                : $port =~ /^(.*)\((\d+)\)$/ ? "$1 port ($2)\n"
                : "$port port\n"
              ) . "Please scroll to the end of this box for conclusions.\n";

            my $smtp = $mailobj->new(
                Debug => 1,
                @options,
                Port => $port,
            );
            unless ($smtp) {
                $e .= $this->NOTE( $t . "Connect failed</pre>" );
                next;
            }
            $t .=
              "Connected to " . $smtp->peerhost . ':' . $smtp->peerport . "\n";

            if ( $method eq 'starttls' ) {
                if ( defined $smtp->supports('STARTTLS') ) {
                    @use = ( $cfg->{method}, $port );
                    unless ( $smtp->command('STARTTLS')->response() == 2 ) {
                        $smtp->quit;
                        $e .= $this->NOTE( $t . "STARTTLS failed</pre>" );
                        next;
                    }
                    unless ( IO::Socket::SSL->start_SSL( $smtp, @sockopts ) ) {
                        $t .= IO::Socket::SSL::errstr() . "\n";
                        $e .= $this->NOTE( $t . "START SSL failed</pre>" );
                        $smtp->quit;
                        next;
                    }
                    @ISA = (
                        grep( $_ ne 'IO::Socket::INET', @ISA ),
                        'IO::Socket::SSL'
                    );
                    bless $smtp, $mailobj;
                    $t .= "TLS connection established\n";

                    unless ( $smtp->hello( $this->{HELLO_HOST} ) ) {
                        $e .= $this->NOTE( $t . "Hello failed</pre>" );
                        $smtp->quit();
                        next;
                    }
                    push @use, $smtp->testAuth( $username, $password );
                    $smtp->quit;
                    last METHOD;
                }
            }
            else {
                @use = ( $cfg->{method}, $port );
                push @use, $smtp->testAuth( $username, $password );
                $smtp->quit;
                last METHOD;
            }
        }
    }
    close STDERR;
    open( STDERR, '>&', $stderr ) or die "stderr:$!\n";
    close $stderr;

    return $this->perlFailed( $e, "Autoconfiguration failed", @_ )
      unless (@use);

    #  @use[ method, port, authOK, authMsg ]
    if ( $use[2] ) {
        $e .= $this->NOTE(
            $t . $use[3],
"</pre>Configuration accepted.<br />Next step:Setup and test {WebMasterEmail} on the <strong>Email General</strong> tab.\n"
        ) . $this->FB_VALUE( '{EnableEmail}', 1 );
    }
    else {
        $e .=
            $this->NOTE( $t . "</pre>Configuration accepted." )
          . $this->ERROR( $use[3] )
          . $this->FB_VALUE( '{EnableEmail}', 0 );
    }

    $use[1] =~ s/^.*\((\d+)\)$/$1/;
    return (
        1,
        join( '',
            $e,
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
