# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::CGISetup;

=begin TML

---+ package Foswiki::Configure::Checkers::CGISetup

Foswiki::Configure::Checkers::AUDITGROUP for CGI & Environment

=cut

use strict;
use warnings;

use Foswiki::Configure qw/:cgi :auth/;

use Foswiki::Configure::Checkers::AUDITGROUP;
our @ISA = qw(Foswiki::Configure::Checkers::AUDITGROUP);

# This provides the webserver & environment audit items
#
# It is run on-demand.
# The output is divided into several buttons to keep the output manageable.
#
# The webserver button also automagically triggers the PATH_INFO provideFeedback
# method so that analysis can piggy-back on the main request.

sub provideFeedback {
    my $this = shift;
    my ( $valobj, $button, $buttonValue ) = @_;

    my $keys = $valobj->getKeys();

    if ( $button >= 0 && $button < 100 ) {

        # Auditor, let AUDITGROUP handle selections
        return $this->SUPER::provideFeedback(@_);
    }

    # $content should be the table rows for the results section.

    my $content = '';
    my $status  = '';
    $this->{results} ||= '';

    if ( $button == 101 ) {
        ( $status, $content ) = $this->analyzeWebserver;
    }
    elsif ( $button == 102 ) {
        $content = $this->analyzeFoswiki;
    }
    elsif ( $button == 103 ) {
        $content = $this->analyzeExtensions;
    }
    elsif ( $button == -1000 ) {

        # Collect ouput
        $content = $this->SUPER::provideFeedback( @_, 1 );
        $content = $this->{results} . $content;
        $content = $this->FB_GUI( '{ConfigureGUI}{AUDIT}{RESULTS}', $content );
        return wantarray ? ( $content, 0 ) : $content;
    }
    elsif ( $button < 0 ) {
        return $this->SUPER::provideFeedback(@_);
    }
    else {
        return $this->ERROR("Unknown type ($button) for CGI environment audit");
    }

    # Our contents (virtual buttons)

    $content = qq{<table class='configureSectionValues'>$content</table>};
    $this->{results} .= $content;

    return wantarray ? ( $status, 0 ) : $status unless ( $button == 101 );

    # Run PATHINFO only with webserver analysis

    return wantarray ? ( $status, ['{ConfigureGUI}{PATHINFO}'] ) : $status;
}

sub analyzeWebserver {
    my $this = shift;

    my $content =
      CGI::Tr( CGI::td( { colspan => 99 }, '<h4>Environment Variables</h4>' ) );

    # Check the execution environment

    my ( $e, $XENV ) = $this->getExecEnv();

    if ( $e =~ /Error:/ ) {
        $e = $this->WARN(
"Unable to query execution environment.<p>The analysis reflects only the configure environment."
        ) . $e;
        for my $key ( sort keys %ENV ) {
            my $value = $ENV{$key};
            if ( $key eq 'HTTP_COOKIE' ) {

                # url decode for readability
                $value =~ s/%7C/ | /go;
                $value =~ s/%3D/=/go;
                $value .= $this->NOTE('Cookie string decoded for readability.');
            }
            $content .= $this->setting( $key, $value );
        }
    }
    else {
        my %keys = map { $_ => 1 } ( keys %ENV, keys %$XENV );

        $content .= CGI::Tr(
            CGI::td('<b>Variable</b>'),
            CGI::td('<b>Environment</b>'),
            CGI::td('<b>Value</b>')
        );

        for my $key ( sort keys %keys ) {
            my ( $ce, $xe ) = ( exists $ENV{$key}, exists $XENV->{$key} );

            my ( $cv, $xv ) = ( $ENV{$key}, $XENV->{$key} );
            if ( $key eq 'HTTP_COOKIE' ) {
                foreach ( $cv, $xv ) {
                    next unless ( defined $_ );

                    # url decode for readability
                    s/%7C/ | /go;
                    s/%3D/=/go;
                }
                $key .= $this->NOTE('Cookie string decoded for readability.');
            }
            if ( $ce && $xe ) {
                if ( $cv eq $xv ) {
                    $content .=
                      CGI::Tr(
                        CGI::th($key) . CGI::td('&nbsp;') . CGI::td($cv) );
                }
                else {
                    $content .= CGI::Tr(
                        CGI::th(
                            { rowspan => 2, style => "vertical-align:middle" },
                            $key
                          )
                          . CGI::td('configure')
                          . CGI::td($cv)
                    );
                    $content .= CGI::Tr( CGI::td('execution') . CGI::td($xv) );
                }
            }
            elsif ($ce) {
                $content .=
                  CGI::Tr(
                    CGI::th($key) . CGI::td('configure') . CGI::td($cv) );
            }
            else {
                $content .=
                  CGI::Tr(
                    CGI::th($key) . CGI::td('execution') . CGI::td($xv) );
            }
        }
    }

    $content .=
        CGI::end_table()
      . CGI::start_table()
      . CGI::Tr( CGI::td( { colspan => 99 }, '<h4>General Environment</h4>' ) );

    # Check for writable install root.  This used to be (incorrectly)
    # associated with DOCUMENT_ROOT.
    # Some misbehaved extensions (GENPDFAddOn is one) drop files in
    # the install root.   See EXTEND.pm for the definition of install root.
    # UI.pm (now) computes the foswiki root the same way.

    $content .= $this->setting(
        "Foswiki root directory",
        join( '', $this->{root} =~ m,^(.*?)[\\/\]>]$, )
          . (
            -w $this->{root}
            ? ''
            : $this->WARN(<< "HERE") )
The Foswiki root directory is not writable.  This can cause issues when installing some
extensions that write files into the server root.  Writing to the server root is deprecated,
so this may not be an immediate concern.
HERE
          . ( $this->{rootWarning} ? $this->WARN(<< "DIFFS") : '' ) );
The parent directory of {ScriptDir} differs from the parent of {DataDir}.
<p>$this->{rootWarning}<p>This may have caused some confusion.  Please use a single
parent directory (symbolic links from the parent to the child directories are OK.)
DIFFS

    # Report the Umask
    my $pUmask = sprintf( '%03o', umask() );
    $content .= $this->setting( 'UMASK', $pUmask );

    # Detect whether mod_perl was loaded into Apache
    # This won't work is most places because ServerTokens defaults to OS or less
    # in current distributions.

    $Foswiki::cfg{DETECTED}{ModPerlLoaded} =
      ( exists $ENV{SERVER_SOFTWARE}
          && ( $ENV{SERVER_SOFTWARE} =~ /mod_perl/ ) );

    # Detect whether we are actually running under mod_perl
    # - test for MOD_PERL alone, which is enough.
    $Foswiki::cfg{DETECTED}{UsingModPerl} = ( exists $ENV{MOD_PERL} );

    $Foswiki::cfg{DETECTED}{ModPerlVersion} =
      eval 'use mod_perl2; return $mod_perl2::VERSION';
    $Foswiki::cfg{DETECTED}{ModPerlVersion} =
      eval 'use mod_perl; return $mod_perl::VERSION'
      if ($@);

    # Get the version of mod_perl if it's being used
    if ( $Foswiki::cfg{DETECTED}{UsingModPerl} ) {
        $content .= $this->setting( '', $this->WARN(<<HERE) );
You are running <tt>configure</tt> with <tt>mod_perl</tt>. This
is risky because mod_perl will remember old values of configuration
variables. You are *highly* recommended not to run configure under
mod_perl (though the rest of Foswiki can be run with mod_perl)
HERE
    }

    my $cgiver = $CGI::VERSION;
    if ( "$cgiver" =~ m/^(2\.89|3\.37|3\.43|3\.47)$/ ) {
        $content .= $this->setting( '', $this->WARN( <<HERE ) );
You are using a version of \$CGI that is known to have issues with Foswiki.
CGI should be upgraded to a version > 3.11, avoiding 3.37, 3.43, and 3.47.
HERE
    }

# Check for potential CGI.pm module upgrade
# CGI.pm version, on some platforms - actually need CGI 2.93 for
# mod_perl 2.0 and CGI 2.90 for Cygwin Perl 5.8.0.  See
# http://perl.apache.org/products/apache-modules.html#Porting_CPAN_modules_to_mod_perl_2_0_Status
    if ( $CGI::VERSION < 2.93 ) {
        if ( $Config::Config{osname} eq 'cygwin' && $] >= 5.008 ) {

            # Recommend CGI.pm upgrade if using Cygwin Perl 5.8.0
            $content .= $this->setting( '', $this->WARN( <<HERE ) );
Perl CGI version 3.11 or higher is recommended to avoid problems with
attachment uploads on Cygwin Perl.
HERE
        }
        elsif ($Foswiki::cfg{DETECTED}{ModPerlVersion}
            && $Foswiki::cfg{DETECTED}{ModPerlVersion} >= 1.99 )
        {

            # Recommend CGI.pm upgrade if using mod_perl 2.0, which
            # is reported as version 1.99 and implies Apache 2.0
            $content .= $this->setting( '', $this->WARN( <<HERE ) );
Perl CGI version 3.11 or higher is recommended to avoid problems with
mod_perl.
HERE
        }
    }

    #OS
    my $n =
        ucfirst( lc( $Config::Config{osname} ) ) . ' '
      . $Config::Config{osvers} . ' ('
      . $Config::Config{archname} . ')';
    $content .= $this->setting( "Operating system", $n );

    # Perl version and type
    $n = $];
    $n .= " ($Config::Config{osname})";
    $n .= $this->NOTE(<<HERE);
Note that by convention "Perl version 5.008" is referred to as "Perl version 5.8" and "Perl 5.008004" as "Perl 5.8.4" (i.e. ignore the leading zeros after the .)
HERE

    if ( $] < 5.008 ) {
        $n .= $this->WARN(<<HERE);
Perl version is older than 5.8.0. Recommended version 5.8.4 or later.
Foswiki is tested on Perl 5.8.X and 5.10.X.  Older versions may
work, but you may need to upgrade Perl libraries and tweak the
Foswiki code.
HERE
    }

    $content .= $this->setting( 'Perl version', $n );

    # Perl @INC (lib path)
    $content .= $this->setting( '@INC library path',
        join( CGI::br(), @INC ) . $this->NOTE(<<HERE) );
This is the Perl library path, used to load Foswiki modules,
third-party modules used by some plugins, and Perl built-in modules.
HERE

    $content .= $this->setting( 'CGI bin directory', $this->_getBinDir() );

    # mod_perl
    if ( $Foswiki::cfg{DETECTED}{UsingModPerl} ) {
        $n = $this->WARN("Used for this script - it should not be");
    }
    else {
        $n =
qq{Not used for this script (correct). mod_perl may be enabled for the other scripts. You can check this by visiting <a href="$Foswiki::cfg{ScriptUrlPath}/view$Foswiki::cfg{ScriptSuffix}/System/InstalledPlugins" target="_blank" class="configureWikiLink">System.InstalledPlugins</a> in your wiki.};
    }
    if ( $Foswiki::cfg{DETECTED}{ModPerlLoaded} ) {
        $n .= $this->NOTE("mod_perl is loaded into Apache");
    }
    else {
        $n .= $this->NOTE( << "MODPERL" );
mod_perl may not be loaded into Apache.  It is not reported present in the
SERVER_SOFTWARE environment variable, but this is not definitive because
the ServerTokens directive often is used to suppress this information.
MODPERL
    }

    if ( $Foswiki::cfg{DETECTED}{ModPerlVersion} ) {
        $n .= $this->NOTE( 'mod_perl version ',
            $Foswiki::cfg{DETECTED}{ModPerlVersion} . " is installed" );
    }

    # Check for a broken version of mod_perl 2.0
    if (   $Foswiki::cfg{DETECTED}{UsingModPerl}
        && $Foswiki::cfg{DETECTED}{ModPerlVersion} =~ /1\.99_?11/ )
    {

        # Recommend mod_perl upgrade if using a mod_perl 2.0 version
        # with PATH_INFO bug (see Support.RegistryCookerBadFileDescriptor
        # and Bugs:Item82)
        $n .= $this->ERROR(<<HERE);
Version $Foswiki::cfg{DETECTED}{ModPerlVersion} of mod_perl is known to have major bugs that prevent
its use with Foswiki. 1.99_12 or higher is recommended.
HERE
    }
    $content .= $this->setting( 'mod_perl', $n );

    # Defined in configure, used once here
    my $groups = $::WebServer_gid || $::WebServer_gid;

    $groups =~ s/,/, /go;    # improve readability with linebreaks
    $content .= $this->setting(
        'CGI user',
        'userid = <strong>'
          . $::WebServer_uid
          . '</strong> groups = <strong>'
          . $groups
          . '</strong>'
          . $this->NOTE('Your CGI scripts are executing as this user.')
    );

    return ( $e, $content );
}

# Return %XENV = env from the execution environment

sub getExecEnv {
    my $this = shift;

    my $e    = '';
    my $xenv = {};

    require Foswiki::Net;
    my $cookie = Foswiki::newCookie($session);
    my $net    = Foswiki::Net->new;

    # Flags must be defined and false.  Avoid 'used once' warnings.

    local $Foswiki::Net::LWPAvailable = 0 && $Foswiki::Net::LWPAvailable;
    local $Foswiki::Net::noHTTPResponse = 1 || $Foswiki::Net::noHTTPResponse;
    unless ( defined $Foswiki::VERSION ) {
        ( my $fwi, $Foswiki::VERSION ) = Foswiki::Configure::UI::extractModuleVersion( 'Foswiki', 1 );
        $Foswiki::Version = '0.0' unless ($fwi);
    }

    # 'attach' chosen because it is unlikely to be redirected.

    my $test = '/Web/Topic/Env/Echo?configurationTest=yes';
    my $target =
        '$Foswiki::cfg{ScriptUrlPath}/'
      . 'attach'
      . '$Foswiki::cfg{ScriptSuffix}';

    Foswiki::Configure::Load::expandValue($target);

    my $url = $Foswiki::cfg{DefaultUrlHost} . $target . $test;

    my ( $limit, $try ) = (10);
    my @headers = ( Cookie => join( '=', $cookie->name, $cookie->value ), );

    if ( ( my $user = $query->param('{ConfigureGUI}{AuditUsername}') ) ) {
        my $password = $query->param('{ConfigureGUI}{AuditPassword}') || '';
        require MIME::Base64;
        my $auth = MIME::Base64::encode_base64( "$user:$password", '' );
        push @headers, Authorization => "Basic $auth";
    }

    for ( $try = 1 ; $try <= $limit ; $try++ ) {
        my $response = $net->getExternalResource( $url, @headers );
        if ( $response->is_error ) {
            my $content = $response->content || '';
            $content =~ s/<([^>]*)>/&lt;$1&gt;/g;
            $e .=
              $this->ERROR( "Failed to access \"<tt>$url</tt>\"<pre>"
                  . $response->code . ' '
                  . $response->message . "\n\n"
                  . $content
                  . "</pre>" );
            last;
        }
        if ( $response->is_redirect ) {
            $url = $response->header('location') || '';
            unless ($url) {
                $e .=
                  $this->ERROR( "Redirected ("
                      . $response->code . ") "
                      . 'without a <i>location</i> header' );
                last;
            }
            next;
        }
        my @data = split( /\r?\n/, ( $response->content || '' ) );
        unless ( $url =~ m,^(https?://([^:/]+)(:\d+)?)(/.*)?\Q$test\E$, ) {
            $e .= $this->ERROR("\"<tt>$url</tt>\" does not match request");
            last;
        }
        my ( $host, $hname, $port, $path ) = ( $1, $2, $3, $4 );
        if ( $host ne $Foswiki::cfg{DefaultUrlHost} ) {
            $e .= $this->WARN(
"\"<tt>$host</tt>\" does not match {DefaultUrlHost} (<tt>$Foswiki::cfg{DefaultUrlHost}</tt>)"
            );
        }

        $path ||= '';
        my @server = split( /\|/, $data[0], 3 );
        if ( @server != 3 ) {
            $e .= $this->ERROR(
                "Server returned incorrect diagnostic data:<pre>$data[0]</pre>"
            );
        }

        shift @data;
        foreach my $line (@data) {
            my ( $key, $value ) = split( /\|/, $line, 2 );
            unless ( defined $key && defined $value ) {
                $e .= $this->ERROR(
                    "Server returned incorrect diagnostic data:<pre>$line</pre>"
                );
                next;
            }
            $value =~ s/%(..)/chr(oct("0x$1"))/ge;
            $xenv->{$key} = $value;
        }
        last;
    }
    if ( $try > $limit ) {
        $e .=
          $this->ERROR("Excessive redirects (&gt;$limit) stopped diagnostic.");
    }
    return ( $e, $xenv );
}

sub analyzeFoswiki {
    my $this = shift;

    my $content = '';

    my $lsc = Foswiki::Configure::FoswikiCfg::lscFileName();
    if ( -f $lsc ) {
        $content .= $this->setting(
            "Foswiki configuration",
            "$lsc"
              . $this->NOTE(
                "Last saved on " . localtime( ( stat $lsc )[9] || 0 )
              )
        );
    }
    else {
        $content .= $this->setting( "Foswiki configuration",
            "$lsc" . $this->WARN("Configuration has not been saved") );
    }

    $Foswiki::cfg{ConfigurationFinished} = 1;    # Necessary?

    my ( $fwinst, $fwver ) =
      Foswiki::Configure::UI::extractModuleVersion( 'Foswiki', 'magic' );
    my $mess;
    if ($fwinst) {
        $mess = "Foswiki.pm (Version: <strong>$fwver</strong>) found";
    }
    else {
        $mess = $this->ERROR(
            'Foswiki.pm could not be found in @INC<br />' . << "HERE");
Check in your installation directory that:<ol>
<li><code>bin/setlib.cfg</code> is present and readable</li>
<li><code>bin/LocalLib.cfg</code> is present and readable, and sets up a correct <code>\$foswikiLibPath</code></li>
<li><code>lib/LocalSite.cfg</code> is present and readable</li>
<li>All files are readable by the webserver user ($::WebServer_uid).</li></ol>
HERE

    }

    $content .= $this->setting( 'Foswiki module in @INC path', $mess );

    # To avoid bloating our memory fooprint or death by corruption, we'll fork
    # to test loading Foswiki.pm

    my $fh;
    my $pid = open( $fh, '-|' );
    if ( defined $pid ) {
        if ($pid) {
            local $/;
            $mess = <$fh>;
            close $fh;
        }
        else {
            $Foswiki::cfg{ConfigurationFinished} = 1;
            eval 'require Foswiki';
            if ($@) {
                $mess = $@;

  #		 Why bother with @INC? - it was just displayed and formatted or,
  #		 it's redundant.  So we'll just remove it.
  #                $mess =~ s#\(\@INC\s+contains:\s+(.*?)\)#"(\@INC contains:\n"
  #                  . join( "\n", split( /\s+/, $1 )) . ")"#mse;
                $mess =~ s#\(\@INC\s+contains:\s+(.*?)\)##ms;
                $mess =
                  $this->ERROR('Foswiki.pm could not be loaded. The error was:')
                  . CGI::pre( {}, $mess )
                  . $this->ERROR(<<HERE);
Check in your installation directory that:<ol>
<li><code>bin/setlib.cfg</code> is present and readable</li>
<li><code>bin/LocalLib.cfg</code> is present and readable, and sets up a correct <code>\$foswikiLibPath</code></li>
<li><code>lib/LocalSite.cfg</code> is present and readable</li>
All files must be readable by the webserver user ($::WebServer_uid).</ol>
HERE
            }
            else {
                $mess = 'loads successfully';
            }
            print $mess;
            exit(0);
        }
    }
    else {
        $mess = $this->ERROR("Unable to fork: $!");
    }
    $content .= $this->setting( "Foswiki module status", $mess );

    $content .= $this->setting( 'Original PATH',
        $Foswiki::cfg{DETECTED}{originalPath} . $this->NOTE(<< "HERE") );
This is the PATH value passed in from the web server to this
script - it is reset by Foswiki scripts to the PATH below, and
is provided here for comparison purposes only.
HERE

    my $currentPath = $ENV{PATH} || '';    # As re-set earlier in this routine
    $content .=
      $this->setting( "Current PATH", $currentPath, $this->NOTE(<< "HERE") );
This is the actual PATH setting that will be used by Perl to run
programs. It is normally identical to {SafeEnvPath}, unless
that variable is empty, in which case this will be the webserver user's
standard path..
HERE

    # Check that each of the required Perl modules can be found
    # and read, and  print its version number.  Keep this section last
    # so it does not hide shorter and more frequently accessed information.

    # File DEPENDENCIES is in the lib dir (Item3478)
    my $from = Foswiki::Configure::Util::findFileOnPath('Foswiki.spec');
    my @dir  = File::Spec->splitdir($from);
    pop(@dir);    # Cutting off trailing Foswiki.spec gives us lib dir
    $from =
      File::Spec->catfile( @dir, 'Foswiki', 'Contrib', 'core', 'DEPENDENCIES' );

    my %seen;
    my $perlModules = $this->_loadDEPENDENCIES( $from, 'core', \%seen );
    $content .= $this->_showDEPENDENCIES( 'core', $perlModules );

    return $content;
}

sub analyzeExtensions {
    my $this = shift;

    my $content = '';

    if ($Foswiki::badLSC) {
        $content = $this->setting( '',
            $this->ERROR("Can't audit extensions until configuration is saved")
        );
    }
    else {
        # File DEPENDENCIES is in the lib dir (Item3478)

        my $from = Foswiki::Configure::Util::findFileOnPath('Foswiki.spec');
        my @dir  = File::Spec->splitdir($from);
        pop(@dir);    # Cutting off trailing Foswiki.spec gives us lib dir
        $from =
          File::Spec->catfile( @dir, 'Foswiki', 'Contrib', 'core',
            'DEPENDENCIES' );

        my %seen;
        my $perlModules = $this->_loadDEPENDENCIES( $from, 'core', \%seen );

        foreach my $info ( values %seen ) {
            if ( $info->{usage} ) {
                $info->{usage} =~ s,^<br />,<br /><strong>Foswiki: </strong>,;
            }
        }
        my %extns = (
            $from => 1,
            File::Spec->catfile( @dir, 'Foswiki', 'Plugins', 'EmptyPlugin' ) =>
              1,
            File::Spec->catfile( @dir, 'TWiki', 'Plugins', 'EmptyPlugin' ) => 1,
        );
        foreach my $dir (@INC) {
            $this->_findDependencies( $dir, '/Foswiki/Plugins', \%extns,
                $perlModules, \%seen );
            $this->_findDependencies( $dir, '/Foswiki/Contrib', \%extns,
                $perlModules, \%seen );
            $this->_findDependencies( $dir, '/TWiki/Plugins', \%extns,
                $perlModules, \%seen );
            $this->_findDependencies( $dir, '/TWiki/Contrib', \%extns,
                $perlModules, \%seen );
        }

        $content .= $this->_showDEPENDENCIES( 'Extensions', $perlModules, 1 );
    }

    return $content;
}

sub _getBinDir {
    my $dir = $ENV{SCRIPT_FILENAME} || '.';
    $dir =~ s(/+configure[^/]*$)();
    return $dir;
}

sub _findDependencies {
    my ( $this, $dir, $path, $extns, $perlModules, $seen ) = @_;

    my $dh;
    my $dpath = File::Spec->catdir( $dir, $path );

    return unless ( opendir( $dh, $dpath ) );

    foreach my $extn ( grep !/^\./, readdir $dh ) {
        $extn =~ /^(.*)$/;
        $extn = $1;
        my $dfile = File::Spec->catfile( $dpath, $extn, 'DEPENDENCIES' );
        next if ( $extns->{$dfile} || !-e $dfile );
        push @$perlModules,
          @{ $this->_loadDEPENDENCIES( $dfile, $extn, $seen ) };
        $extns->{$dfile} = 1;
    }
    closedir($dh);
}

sub _showDEPENDENCIES {
    my $this        = shift;
    my $who         = shift;
    my $perlModules = shift;
    my $users       = shift;

 # I suppose this needs a word of explanation:
 # The primary sort is by module name (multi-level split by ::)
 # If $users is false, we are processing the core, which the UI calls 'Foswiki'.
 # No user information is necessary, as only core data is present.
 # Otherwise, we have both the core and extensions dependencies.  We
 # skip modules used only by the core, but have merged core and all extensions.
 # So a module used by extensions and the core is also displayed with the
 # extensions, as either may have the highest version constraint.  The highest
 # version constraint is underlined (unless there's only one user)

    my $set;
    if ( ref($perlModules) ) {
        my @list = map {
            my $mvu = $_->[0]{minVersionUser};
            $mvu = 'Foswiki' if ( $mvu eq 'core' );
            my $mu = @{ $_->[0]{users} } > 1;
            $_->[0]{usage} .= '<br><b>Used by: </b>'
              . join( ', ',
                map { $_ eq $mvu && $mu ? "<u>$_</u>" : $_ }
                  sort map { $_ eq 'core' ? 'Foswiki' : $_ }
                  @{ $_->[0]{users} } )
              if ($users);
            $_->[0]
          } sort {
            my @a = @{ $a->[1] };
            my @b = @{ $b->[1] };
            while ( @a && @b ) {
                my $na = shift @a;
                my $nb = shift @b;
                my $c  = $na cmp $nb;
                return $c if ($c);
            }
            return @a <=> @b;
          } map {
            ( $users && @{ $_->{users} } == 1 && $_->{users}[0] eq 'core' )
              ? ()
              : [ $_, [ split( /::/, $_->{name} ) ] ]
          } @$perlModules;

        $set = $this->checkPerlModules( 2, \@list );
    }
    else {
        $set = $this->ERROR($perlModules);
    }

    $who = 'Foswiki' if ( $who eq 'core' );
    return $this->setting(
        "Perl modules used by $who",
        CGI::start_table( { class => 'configureNestedTable' } )
          . $set
          . CGI::end_table()
    );
}

# Extract a list of the perl modules that are required by a DEPENDENCIES file.
# We also keep track of who uses each module, and the maximum version
# constraint.  Multiple user notes are labeled and merged.

sub _loadDEPENDENCIES {
    my $this = shift;
    my $from = shift;
    my $who  = shift;
    my $seen = shift;

    my $dwho = $who;
    $dwho = 'Foswiki' if ( $who eq 'core' );
    $dwho = "<strong>$dwho</strong>";

    my $d;
    open( $d, '<', $from ) || return "Failed to load $from: $!";
    my @perlModules;

    foreach my $line (<$d>) {
        next unless $line;
        my @row = split( /,\s*/, $line, 4 );
        next unless ( scalar(@row) == 4 && $row[2] eq 'cpan' );
        my $ver = $row[1];
        $ver =~ s/[<>=]//g;
        $row[0] =~ /([\w:]+)/;    # check and untaint
        my $modname = $1;

        my ( $dispo, $usage ) = $row[3] =~ /^\s*(\w+)(?:[.,]\s*)?(.*)$/;

        # There's weird stuff in DEPENDENCIES...
        # required => ERROR; recommended => WARN; default is NOTE
        #
        # If not one of the expected keywords, make it a WARN so the
        # file can be corrected without instilling too much fear.
        # Also, it's probably part of the usage sentence, so re-combine it.

        if ( $dispo !~ m/^(required|optional|recommended)$/i ) {
            $dispo = 'recommended';
            $usage = $row[3];
        }
        $usage ||= '';

        # Activate links found in DEPENDENCIES notes.

        my $dlink =
          '<a class="configureDependenciesLink" target="_blank" href=';
        $usage =~
s,\[\[(https?://[^\]]+)\]\[([^\]]+)\](?:\[[^\]]*\])?\],$dlink"$1">$2</a>,gms;
        $usage =~ s,\[\[(https?://[^\]]+)\]\],$dlink"$1">$1</a>,gms;
        $usage =~ s,(^|[^"])(https?://.*?)(\s|$),$1$dlink"$2">$2</a>$3,gms;

        if ( ( my $info = $seen->{$modname} ) ) {
            push @{ $info->{users} }, $who;
            my $prevVer = $info->{minimumVersion};
            $prevVer =~ s/(\d+(\.\d*)?).*/$1/;
            $ver     =~ s/(\d+(\.\d*)?).*/$1/;
            if ( $ver > $prevVer ) {
                $info->{minimumVersion} = $ver;
                $info->{minVersionUser} = $who;
            }
            $info->{usage} .= "<br />$dwho: $usage" if ($usage);
            next;
        }
        if ($usage) {
            if ( $who eq 'core' ) {
                $usage = "<br />" . ucfirst( lc($dispo) ) . " $usage";
            }
            else {
                $usage = "<br />$dwho: " . ucfirst( lc($dispo) ) . " $usage";
            }
        }
        push(
            @perlModules,
            {
                name           => $modname,
                usage          => $usage,
                minimumVersion => $ver || 0,
                minVersionUser => $who,
                disposition    => lc($dispo),
                users          => [$who],
            }
        );
        $seen->{$modname} = $perlModules[-1];
    }
    close($d);
    return \@perlModules;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
