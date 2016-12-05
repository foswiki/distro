# See bottom of file for license and copyright information

package Foswiki::Configure::Wizards::AutoConfigureEmail;

=begin TML

---++ package Foswiki::Configure::Wizards::AutoConfigureEmail

Wizard to try to autoconfigure email.

=cut

use strict;
use warnings;

use Foswiki::Configure::Wizard ();
use Foswiki::Aux::MuteOut      ();
use File::Temp                 ();

our @ISA = ('Foswiki::Configure::Wizard');

use constant DEBUG_SSL => 1;

use Foswiki::IP qw/$IPv6Avail :regexp :info/;

# N.B. Below the block comment are not enabled placeholders
# Search order (specify hash key).  Agents with custom sniffers
# ( code => keys ) should be tried first.
my @mtas = (qw/mailwrapper postfix ssmtp exim qmail sendmail/);

# Note: Standard sendmail options used:
#  -t      Read the message for recipients  To: Cc: ...
#  -oeq    Discard any error messages, just return on failure
#  -oi     Ignore dots alone on lines by themselves in incoming messages.
#          This should be set if you are reading data from a file.
#<<<
my %mtas = (
    sendmail => {
        name => 'sendmail',                 # Display name
        file => 'sendmail',                 # Executable file to look for in PATH
        regexp =>                           # Regexp to match basename from alias
          qr/^(?:sendmail\.)?sendmail$/,      # e.g. usr/sbin/sendmail -> ssmtp
        flags => '-t -oi -oeq',             # Flags used for sending mail
        debug => '-X /dev/stderr',          # Additional flags to enable debug logs
    },
    ssmtp => {
        name   => 'sSMTP',
        file   => 'ssmtp',
        regexp => qr/^(?:sendmail\.)?ssmtp$/,  # sendmail is alias for ssmtp
        flags  => '-t -oi -oeq',
        debug  => '-v',
    },
    mailwrapper => {
        name   => 'mailwrapper',
        file   => 'mailwrapper',
        regexp => qr/^mailwrapper$/,
        code   =>                           # Callout to find actual program
         sub { return _mailwrapperConfig( @_ ); },
    },
    postfix => {
        name   => 'postfix',
        file   => 'sendmail',
        regexp => qr/^sendmail$/,           # Postfix doesn't use an alias, provides own sendmail
        flags  => '-t -oi -oeq',
        debug  => '',                       # Postfix restricts debug to superuser, otherwise -vv
        code   =>
         sub { return _sniffPostfix( @_ ); },
    },
    exim => {
        name   => 'Exim4',
        file   => 'exim4',
        regexp => qr/^(?:sendmail\.)?exim4$/,
        flags  => '-t -oi -oeq',
        debug  => '-v',
    },
    qmail => {
        name   => 'qmail',
        file   => 'sendmail',
        regexp => qr/^(?:sendmail\.)?qmail-sendmail$/,
        flags  => '-t -oi -oeq',
        debug  => '',                       # Doesn't appear to have debug options
    },

# Below this comment, the keys aren't in @mtas, and hence aren't used (yet).  The data
# is almost certainly wrong - these are simply placeholders.
# As these are investigated, validated, add the keys to @mtas and move above this line.

    # ... etc
);
#>>>

use constant ACCEPTMSG =>
  "> Configuration accepted. Next step: Send a test email to {WebMasterEmail}.";

# Execute a function capturing all output.

sub _muteExec {
    my $sub      = shift;
    my $reporter = $_[0];

    my $rc;
    my ( $fh1, $outFile ) = File::Temp::tempfile(
        "STDOUT.$$.XXXXXXXXXX",
        DIR    => File::Spec->tmpdir(),
        UNLINK => 0
    );
    close $fh1;
    my ( $fh2, $errFile ) = File::Temp::tempfile(
        "STDERR.$$.XXXXXXXXXX",
        DIR    => File::Spec->tmpdir(),
        UNLINK => 0
    );
    close $fh2;

    {
        # Don't try to capture STDERR on FastCGI systems. it won't work.
        my $muter = Foswiki::Aux::MuteOut->new(
            outFile  => $outFile,
            errFile  => $errFile,
            reporter => $reporter,
        );

        $rc = $muter->exec( $sub, @_ );
    }

    my $out = _slurpFile( $outFile, $reporter );
    my $err = _slurpFile( $errFile, $reporter );

    unlink $outFile;
    unlink $errFile;

    return wantarray ? ( $rc, $out, $err ) : $rc;
}

sub _slurpFile {
    my ( $file, $reporter ) = @_;

    my $fh;
    unless ( open $fh, "<", $file ) {
        $reporter->WARN( "Cannot open capture file '$file': " . $! );
        return undef;
    }

    local $/;
    my $data = <$fh>;
    $reporter->WARN( "Read from capture file '$file' failed: " . $! )
      unless defined $data;
    close $fh;
    return $data;
}

# WIZARD
sub autoconfigure {
    my ( $this, $reporter ) = @_;

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
            $reporter->ERROR( <<NOCERT );
You have enabled \{Email\}\{EnableSMIME\}, so you obviously want to send
signed e-mail. For signed mail to work, Certificate and Key files must be
provided (or generated), but none were found. Correct the settings in
the *Signed Email* section before trying Auto Configure again.
NOCERT
            _setConfig( $reporter, '{EnableEmail}', 0 );
            return;
        }
    }

    my $ok = 0;
    my $out;
    my $err;

    if ( $Foswiki::cfg{SMTP}{MAILHOST} ) {

        if ( $Foswiki::cfg{Engine} && $Foswiki::cfg{Engine} =~ m/FastCGI$/ ) {
            $reporter->WARN(
'Debug log not captured in FCGI environments. Check web server error log for debugging information'
            );
            $ok = _autoconfigSMTP($reporter);
        }
        else {
            ( $ok, $out, $err ) = _muteExec( \&_autoconfigSMTP, $reporter );
        }
        $err =~ s/AUTH\s([^\s]+)\s.*$/AUTH $1 xxxxxxxxxxxxxxxx/mg if $err;

        unless ($ok) {
            $reporter->WARN(
"SMTP configuration using $Foswiki::cfg{SMTP}{MAILHOST} failed. Falling back to mail program"
            );
        }
    }
    else {
        $reporter->WARN(
"{SMTP}{MAILHOST} is not defined, so cannot use SMTP. Falling back to mail program"
        );
    }

    $reporter->NOTE($out) if defined $out;

    if ($err) {
        if ( $Foswiki::cfg{Engine} && $Foswiki::cfg{Engine} !~ m/CLI$/ ) {

            # Double-space the debug output so that it doesn't wrap.
            $err =~ s#\n#<br/>#sg;
            $err =~ s/\n$//g;
        }

        $reporter->NOTE( <<OUT ) if ($err);
=======  DEBUG MESSAGES ====
$err
OUT
    }

    if ( !$ok && _autoconfigProgram($reporter) ) {
        $ok = 1;
    }

    unless ($ok) {
        $reporter->ERROR(
            'Mail configuration failed. Foswiki will not be able to send mail.'
        );
    }

    _setConfig( $reporter, '{EnableEmail}', $ok );

    return undef;    # return the reporter content
}

# Return 0 on failure
# $smtpAvail = 0 if not available, -1 if tried and failed, 1 if tried and OK
sub _autoconfigProgram {
    my ($reporter) = @_;

    $reporter->NOTE("> Attempting to configure a mailer program");

    require Cwd;
    require File::Basename;

    my ( $mailp, $mailargs );
    my $path = $ENV{PATH};

# First, try special heuristics.   This tests each MTA that provides a custom sniffer
# through a coderef in the $cfg->{code} key.  If the sniffer code succeeds, it returns
# the program that should be used to send email.

    foreach my $mta (@mtas) {
        my $cfg = $mtas{$mta} or next;
        my $test = $cfg->{code};
        next unless ($test);
        ( $mailp, $mailargs ) = $test->($cfg);
        delete $mtas{$mta};
        next unless ($mailp);

        my ( $prog, $ppath ) = File::Basename::fileparse($mailp);
        $path = $ppath if ($ppath);
        $mailp = $prog;
        _setMailProgram( $cfg, $path, $reporter );
        return 1;
    }

    # Next, look for each mta on path
    # Identify it by it's realpath (/etc/alternatives...)

    unless ($mailp) {
        foreach my $mta (@mtas) {
            my $cfg = $mtas{$mta} or next;
            foreach my $p ( split( /:/, $path ) ) {
                if ( -x "$p/$cfg->{file}" ) {
                    my $prog = Cwd::realpath("$p/$cfg->{file}");
                    if ( ( File::Basename::fileparse($prog) )[0] =~
                        $cfg->{regexp} )
                    {
                        _setMailProgram( $cfg, $p, $reporter );
                        return 1;    # OK
                    }
                }
            }
        }

        # Not found, must map /usr/sbin/sendmail to the tool
        $reporter->NOTE(
            '> Unable to locate a known external mail program, trying sendmail'
        );

        $mailp = 'sendmail';
    }

    # Rummage through path including sbin, try to find a sendmail program
    # And see if it's masquerading as a different mailer.
    foreach my $p ( '/usr/sbin', split( /:/, $path ) ) {
        if ( -x "$p/$mailp" ) {
            my $cfg = $mtas{$mailp} or next;
            $mailp =
              ( File::Basename::fileparse( Cwd::realpath("$p/$mailp") ) )[0];
            foreach my $mta (@mtas) {
                my $cfg = $mtas{$mta} or next;
                if ( $mailp =~ $cfg->{regexp} ) {
                    $cfg->{flags} = '' unless ( defined $cfg->{flags} );
                    $cfg->{flags} = "$mailargs $cfg->{flags}"
                      if ( defined $mailargs );
                    _setMailProgram( $cfg, $p, $reporter );
                    return 1;    # OK
                }
            }
        }
        else {
            $reporter->NOTE("> Unable to identify $p/$mailp.");
        }
    }

    return 0;                    # failed
}

# mailwrapper uses a config file
# look for the traditional 'sendmail' verb
# return program and its args - wrapper prepends
# these to the "user" args.

sub _mailwrapperConfig {
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

# postfix provides a mostly compatible sendmail.  The debug flags
# are NOT compatible, so need to detect a specifc postfix sendmail.
#
# Postfix docs recommend using postconf to find the correct location
# for the sendmail command which can vary by installation.

sub _sniffPostfix {
    my $cfg = shift;
    my $smprog;

    if ( -x '/usr/sbin/postconf' ) {
        $smprog = `/usr/sbin/postconf sendmail_path`;
        if ( $smprog =~ m/sendmail_path\s?=\s?(.*)$/ ) {
            $smprog = $1;
            return $smprog if ( -x $smprog );
        }
    }
    return;
}

sub _sniffSELinux {
    my $reporter = shift;
    no warnings 'exec';

    my $selStatus = system("selinuxenabled");
    unless ( $selStatus == -1
        || ( ( $selStatus >> 8 ) && !( $selStatus & 127 ) ) )
    {
        $reporter->NOTE(<<SELINUX);
> SELinux appears to be enabled on your system.
Please ensure that the SELinux policy permits SMTP connections from webserver processes to at least one of these tcp ports: 587, 465 or 25.  Also ensure that your e-mail client is permitted to be run under your webserver, and that it is permitted access to its configuration data and temporary files in this security context.
Check the audit log for specific errors, as policies vary.
SELINUX
        return 1;
    }
    return 0;
}

sub _setMailProgram {
    my ( $cfg, $path, $reporter ) = @_;

    $reporter->NOTE(<<ID);
> Identified $cfg->{name} ( =$path/$cfg->{file}= ) as your mail program
ID

    _setConfig( $reporter, '{Email}{MailMethod}', 'MailProgram' );
    _setConfig( $reporter, '{SMTP}{DebugFlags}',  $cfg->{debug} );
    _setConfig( $reporter,
        '{MailProgram}', "$path/$cfg->{file} $cfg->{flags}" );

    # MailProgram probes don't send mail, so just a generic message if
    # isSELinux is enabled.
    _sniffSELinux($reporter);

    $reporter->NOTE(ACCEPTMSG);
}

# autoconfig loosely parallels Net.pm
# Setup the best available connection to the e-mail server

# autoconfiguration for Net::SMTP

# Global variables (yes, really. Barf.)

our (
    $host,     $hInfo,     $port,       $hello,
    $inAuth,   $noconnect, $allconnect, $tlog,
    $tlsSsl,   $startTls,  $verified,   @sslopts,
    @sockopts, %systemAuthMethods,
);
our $pad = ' ' x length('Net::SMTpXXX ');

my @Net_SMTP_default_ISA;

# Return 0 on failure
sub _autoconfigSMTP {
    my ($reporter) = @_;

    $SIG{__DIE__} = sub {
        Carp::confess(@_);
    };

    $host = $Foswiki::cfg{SMTP}{MAILHOST};

    foreach my $module ( 'Net::SMTP', 'IO::Handle' ) {
        eval("require $module");
        if ($@) {
            $reporter->WARN("$module is required to auto configure SMTP mail");
            return 0;
        }
    }

    # Kinda simulate state variables.
    @Net_SMTP_default_ISA = @Net::SMTP::ISA unless @Net_SMTP_default_ISA;

    my $trySSL = 1;

    # Make sure all SSL dependencies are available. If any fail, don't try SSL.
    foreach my $module ( 'Net::SSLeay', 'IO::Socket::SSL' ) {
        eval("require $module");
        if ($@) {
            $reporter->WARN(
"$module is required to auto configure SMTP mail over SSL, but it could not be loaded"
            );
            $trySSL = 0;
        }
    }

    if ( $trySSL
        && !(  $Foswiki::cfg{Email}{SSLCaFile}
            || $Foswiki::cfg{Email}{SSLCaPath} ) )
    {
        $reporter->NOTE(
"No SSL CA certificate path set.  Running SSLCertificates wizard to guess ={SSLCaFile}= and ={SSLCaPath}=."
        );
        require Foswiki::Configure::Wizards::SSLCertificates;
        my $certWiz = Foswiki::Configure::Wizards::SSLCertificates->new;
        $certWiz->guess_locations($reporter);
    }

    IO::Socket::SSL->import('debug3') if ( $trySSL && DEBUG_SSL );

# If Dependencies for IPv6 are available, This changes the ISA of Net::SMTP to IO::Socket::IP
# which supports both IPv6 and IP V4
    if ($IPv6Avail) {

        # Enable IPv6 if it's available
        @Net::SMTP::ISA = (
            grep( $_ !~ /^IO::Socket::I(?:NET|P)$/, @Net_SMTP_default_ISA ),
            'IO::Socket::IP'
        );
    }

    $hInfo = hostInfo($host);
    if ( $hInfo->{error} ) {
        $reporter->( "{SMTP}{MAILHOST} is not valid " . $hInfo->{error} );
        return 0;
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
            $reporter->NOTE(
"> $host has an IPv6 address, but IO::Socket::IP is not installed.  IPv6 can not be used."
            );
        }
    }
    unless (@addrs) {
        $reporter->NOTE(
            "> {SMTP}{MAILHOST} $host is invalid: server has no IP address");
        return 0;
    }

    my @options = (
        Debug => 1,

        # SMELL: Code used to pass [@addrs} here to be able to log IP addresses
        # But that breaks certificate validation.  Always need to use hostname!
        #Host  => [@addrs],
        Host => $hInfo->{name},

        # Shorten timeout if > 2 Addresses to test
        Timeout => ( @addrs >= 2 ? 10 : 30 ),
    );

    if ( ( $hello = $Foswiki::cfg{SMTP}{SENDERHOST} ) ) {
        push @options, Hello => ($hello);
    }
    else {
        # Figure out a hostname to use in the HELO
        require Net::Domain;
        $hello = Net::Domain::hostfqdn();
        $hello = "[$hello]"
          if ( $hello =~ m/^(?:$IPv4Re|$IPv6ZidRe)$/ );
        push @options, Hello => $hello;
    }

    $inAuth     = 0;
    $noconnect  = 1;
    $allconnect = 1;

    my $log = bless {},
      'Foswiki::Configure::Wizards::AutoConfigureEmail::Mailer';

    # Get SSL options common to all secure connection methods

    my @methods;
    my $sslNoVerify;
    my $sslVerify;

    if ($trySSL) {
        ( $sslNoVerify, $sslVerify ) = _setupSSLoptions( $log, $reporter );

        # Connection methods in priority order
        @methods = (qw/starttls-v starttls tls-v tls ssl-v ssl smtp/);
    }
    else {
        @methods = (qw/smtp/);
    }

    # Configuration data for each method.  Ports in priority order.

    my $sockSSLisa = [
        grep( $_ !~ /^IO::Socket::I(?:NET|P)$/, @Net_SMTP_default_ISA ),
        'IO::Socket::SSL'
    ];

    my %config = (
        starttls => {
            ports    => [qw/submission(587) smtp(25)/],
            method   => 'Net::SMTP (STARTTLS)',
            isa      => [@Net_SMTP_default_ISA],
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
            isa    => [@Net_SMTP_default_ISA],
        },
    );
    @Net::SMTP::ISA = 'Foswiki::Configure::Wizards::AutoConfigureEmail::SSL';

    # Generate configurations with peer verification

    if ($trySSL) {
        foreach my $method (@methods) {
            if ( $method =~ m/^(.*)-v$/ ) {
                if (@$sslVerify) {
                    die "Invalid config for $method\n"
                      unless ( exists $config{$1} );

                    $config{$method} = { %{ $config{$1} } };
                    $config{$method}{ssl} =
                      [ @{ $config{$method}{ssl} }, @$sslVerify ];
                    $config{$method}{id} = uc($1) . " WITH host verification";
                    $config{$method}{verify} = 1;
                }
                else {
                    delete $config{$method};
                }
            }
        }
    }

    # Generate methods without peer verification

    foreach my $method (@methods) {
        next unless ( exists $config{$method} );
        next if ( !$trySSL && exists $config{$method}{ssl} );
        if ( $method !~ /-v$/ && exists $config{$method}{ssl} ) {
            push @{ $config{$method}{ssl} }, @$sslNoVerify;
            $config{$method}{id} = uc($method) . " with NO host verification";
        }
    }

    # If port forced, try to find name.
    # The smtp names are secondary for some traditional ports, so
    # use the primary for those.  For others, consult /etc/services.

    $port = $hInfo->{port};
    if ( $port && $port =~ m/^\d+$/ ) {
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
                $name =~ m/^(.*)$/;
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

    $tlog = '';

    # Loop over methods - output %use if one succeeds

    # This code loops over the @methods list.  It configures each method
    # per the %config hash for that method, and tests the connection.
    # The first connection that succeeds in sending a message is used.
    #
    # The methods are tried in order of the most secure / modern to the least
    # secure,  so STARTTLS on Submission (587) would be preferred over SSL which
    # is preferred over plain SMTP port 25.
    #
    # The configuration  that worked is in %use:
    #    $use{cfg} Configuration hash
    #    $use{port} Port
    #    $use{authOK} Flag if authentication worked
    #     0 - Test incomplete
    #     1 - Succeeded
    #     2 - Bad credentials
    #     3 - Some other error
    #     4 - Auth not required, remove credentials
    #    $use{authMsg} Message from the authentication test

    my %use;
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

            @Foswiki::Configure::Wizards::AutoConfigureEmail::SSL::ISA = ();
            @Foswiki::Configure::Wizards::AutoConfigureEmail::SSL::ISA =
              @{ $cfg->{isa} };

            $tlog = '' unless (DEBUG_SSL); # Reset log so only report last test.
            my $testmsg =
                "${pad}Testing "
              . ( $cfg->{id} || uc($method) ) . " on "
              . (
                  $port =~ m/^\d+$/           ? "port $port\n"
                : $port =~ m/^(.*)\((\d+)\)$/ ? "$1 port ($2)\n"
                : "$port port\n"
              );

            $tlog .= $testmsg;
            print STDERR $testmsg;

            $verified = $cfg->{verify} || -1;

            my $smtp =
              Foswiki::Configure::Wizards::AutoConfigureEmail::Mailer->new(
                @options, Port => $port );
            unless ($smtp) {
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
                    next;
                }
            }
            if ($startTls) {
                next unless ( $smtp->starttls( $log, $reporter ) );
            }
            $use{cfg}  = $cfg;
            $use{port} = $port;
            my @res = $smtp->testServer( $host, $username, $password );
            $use{authOK}  = $res[0];
            $use{authMsg} = $res[1];
            $smtp->quit;

            last METHOD if ( $use{authOK} >= 0 );
            $tlog .= $use{authMsg};
            %use = ();
        }
    }
    $tlog =~ s/AUTH\s([^\s]+)\s.*$/AUTH $1 xxxxxxxxxxxxxxxx/mg;
    $reporter->NOTE("<verbatim>$tlog</verbatim>");

    unless ( scalar( keys %use ) ) {
        _diagnoseFailure( $noconnect, $allconnect, $reporter );
        return 0;
    }

    #  %use{ cfg, port, authOK, authMsg }
    if ( $use{authOK} == 0 ) {    # Incomplete
        $reporter->NOTE(
"> This configuration appears to be acceptable, but testing is incomplete."
        );
        $reporter->NOTE( $use{authMsg} );
        return 0;
    }
    if ( $use{authOK} == 1 || $use{authOK} == 4 ) {    # OK, Not required
        $reporter->NOTE( $use{authMsg}, ACCEPTMSG );
    }
    elsif ( $use{authOK} == 2 ) {                      # Bad credentials
            # Authentication failed, perl is OK, don't try program.
        $reporter->NOTE( $use{authMsg} );
        return 0;
    }
    else {    # Other failure
        $reporter->NOTE( $use{authMsg},
"> Although a connection was established with $host on port $use{port}, it did not accept mail."
        );
        return 0;
    }

    $use{port} =~ s/^.*\((\d+)\)$/$1/;
    $host = "[$host]" if ( $hInfo->{ipv6addr} );
    my $cfg = $use{cfg};

    _setConfig( $reporter, '{Email}{MailMethod}', $cfg->{method} );
    _setConfig( $reporter, '{SMTP}{SENDERHOST}',  $hello );
    _setConfig( $reporter, '{SMTP}{Username}',    $username );
    _setConfig( $reporter, '{SMTP}{Password}',    $password );
    _setConfig( $reporter, '{SMTP}{MAILHOST}',    $host . ':' . $use{port} );
    _setConfig( $reporter, '{Email}{SSLVerifyServer}',
        ( $cfg->{verify} || 0 ) );

    return 1;
}

sub _setConfig {
    my ( $reporter, $setting, $value ) = @_;

    my $old = eval("\$Foswiki::cfg$setting");

    if (   defined $old && !defined $value
        || !defined $old && defined $value
        || defined $value && $value ne $old )
    {
        eval("\$Foswiki::cfg$setting=\$value");
        $reporter->CHANGED($setting);
    }
    return;
}

# Support routines

sub _diagnoseFailure {
    my ( $noconnect, $allconnect, $reporter ) = @_;

    my $isSELinux = _sniffSELinux($reporter);

    # If no connection went through, there's probably a block
    if ($noconnect) {
        my $mess =
"> No connection was established on any port, so if the e-mail server is up, it is likely that a firewall";
        $mess .= " and/or SELINUX" if ($isSELinux);
        $mess .= " is blocking TCP connections to e-mail submission ports.";

        $reporter->NOTE($mess);
        return;
    }

    # Some worked, some didn't
    unless ($allconnect) {
        my $mess =
"> At least one connection was blocked, but others succeeded.  It is possible that that a firewall";
        $mess .= " and/or SELINUX" if ($isSELinux);
        $mess .=
          " is blocking TCP connections to some e-mail submission port(s).
However, only one connection type needs to work, so you should focus on the\
issues logged on the ports where connections succeeded.";

        $reporter->NOTE($mess);
        return;
    }

    # All connections worked, but the protocol didn't.

    $reporter->NOTE(<<"SMTP");
> Although all connections were successful, the service is not speaking SMTP.
The most likely causes are that the server uses a non-standard port for SMTP,
or your configuration erroneously specifies a non-SMTP port.  Check your
configuration; then check with your server support.
SMTP
}

# Compute SSL options lists for both peer verification on and off.
# If on is disabled, its list will be empty.

sub _setupSSLoptions {
    my ( $log, $reporter ) = @_;

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
            $reporter->WARN(
"Client verification requires both {Email}{SSLClientCertFile} and {Email}{SSLClientKeyFile} to be set."
            );
        }
    }

    # SSL options lists with and without peer verification

    my ( @sslVerify, @sslNoVerify );
    @sslNoVerify =
      ( @sslCommon, SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE(), );

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
                  Foswiki::Configure::Wizards::AutoConfigureEmail::SSL::sslVerifyCert(
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
                $reporter->WARN(
"{Email}{SSLCheckCRL} requires CRL verification but neither {Email}{SSLCrlFile} nor {Email}{SSLCaPath} is set."
                );
            }
        }
    }
    else {
        $reporter->WARN(
"{Email}{SSLVerifyServer} requires host verification but neither {Email}{SSLCaFile} nor {Email}{SSLCaPath} is set."
        );
    }

    return ( [@sslNoVerify], [@sslVerify] );
}

# Net::SMTP extensions
#
# Package for extended logging

package Foswiki::Configure::Wizards::AutoConfigureEmail::Mailer;

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
                if ( $b64text =~ m/[[:^print:]]/ ) {
                    my $n = 0;
                    $b64text =~
s/(.)/sprintf('%02x', ord $1) . (++$n % 32 == 0? $cont : ' ')/gmse;
                    $b64text =~ s/([[:xdigit:]]{2}) ([[:xdigit:]]{2})/$1$2/g;
                    if ( $n % 32 ) {
                        chop $b64text;
                        $b64text .= $cont;
                    }
                    unless ( $multi && $b64 =~ m/$cont\z/ ) {
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
    $tlog .= "$text\n";
}

# Package for extended SSL functions
#
# The reason for this is that Net::SMTP::SSL and Net::SMTP::TLS don't work and
# don't appear to be maintained.  By intercepting Net::SMTP, it's reasonably straight
# forward to open the correct socket type for SSL or TLS right at the start.
# Net::SMTP::SSL doesn't work with recent versions of SSL due to changes in
# certificate verification.  See https://rt.cpan.org/Ticket/Display.html?id=81594
#
# Net::SMTP::TLS is an incomplete implementation, totally unusable by Foswiki, It
# was forked into Net::SMPT::TLS::ButMaintained.  Neither can sent to multiple To:
# addresses.  First failure kills the session.
#
# The overrides below support SMTP, SSL, and START_TLS on ports 25, 465 and 587
#
# CHANGES IN THESE FUNCTIONS ALSO NEED TO BE MADE TO Foswiki::Net!
#
package Foswiki::Configure::Wizards::AutoConfigureEmail::SSL;

our @ISA;

# Intercept new() socket issued by Net::SMTP
#
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
        $tlsSsl                 ? 'IO::Socket::SSL'
      : $Foswiki::IP::IPv6Avail ? 'IO::Socket::IP'
      :                           'IO::Socket::INET';
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
    my ( $smtp, $log, $reporter ) = @_;

    unless ( defined $smtp->supports('STARTTLS') ) {
        $smtp->quit;
        $reporter->NOTE( "<verbatim>$tlog</verbatim>",
            "> ${pad}STARTTLS is not supported by $host" );
        return 0;
    }
    unless ( $smtp->command('STARTTLS')->response() == 2 ) {
        $smtp->quit;
        $reporter->NOTE( "<verbatim>$tlog</verbatim>",
            "${pad}STARTTLS command failed" );
        return 0;
    }

    my $mailobj = ref $smtp;

    unless ( IO::Socket::SSL->start_SSL( $smtp, @sockopts, ) ) {
        $tlog .= $pad . IO::Socket::SSL::errstr() . "\n" if ($verified);
        $reporter->NOTE( "<verbatim>$tlog</verbatim>",
            "${pad}Upgrade to TLS failed" );

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
        $reporter->NOTE("<verbatim>$tlog</verbatim>");
        $smtp->close;
        return 0;
    }

    unless ( $smtp->hello($hello) ) {
        $reporter->NOTE( "<verbatim>$tlog</verbatim>", "${pad}Hello failed" );
        $smtp->quit();
        return 0;
    }
    return 1;

}

# Handle host verification manually so we can report issues

our %verifyErrors = (
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
    if ( $code =~ m/^[245]/ && defined $smtp->supports('ENHANCEDSTATUSCODES') )
    {
        my $msg = $smtp->message;
        if ( $msg =~ m/^([245]\.\d{1,3}\.\d{1,3})\b/ ) {
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

    my $fromTestAddr = $Foswiki::cfg{Email}{WikiAgentEmail}
      || $Foswiki::cfg{WebMasterEmail};
    my $toTestAddr = $Foswiki::cfg{WebMasterEmail};
    my ( @code, $requires );

    my $noAuthOk = $smtp->mail($fromTestAddr) && $smtp->to($toTestAddr);
    unless ($noAuthOk) {
        @code = $smtp->rspCode;
        $smtp->reset;

        # 530 5.7.0 Auth req 540/550 5.7.1 no relay
        if ( !( $code[0] =~ m/^5[345]0$/ || $code[1] =~ m/^(?:5\.7\.[01])$/ ) )
        {
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

        if ( ( $code[0] =~ m/^535$/ || $code[1] =~ m/^(?:5\.7\.8)$/ ) ) {
            return (
                2,
                "$host rejected the supplied username and password.
Please verify that configured username and password are valid for $host.\n"
            );
        }

        # 454 4.7.0 Temporary authentication failure
        if ( ( $code[0] =~ m/^454$/ || $code[1] =~ m/^(?:4\.7\.0)$/ ) ) {
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
        next if ( $file =~ m/^\./ );
        next unless ( $file =~ m/^([A-Z0-9_]+)\.pm$/ );
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

Copyright (C) 2014 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
