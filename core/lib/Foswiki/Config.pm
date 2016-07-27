# See bottom of file for license and copyright information

=begin TML

---+!! package Foswiki::Config

Class representing configuration data.

=cut

package Foswiki::Config;
use v5.14;

use Assert;
use Encode ();
use File::Basename;
use File::Spec;
use POSIX qw(locale_h);
use Unicode::Normalize;
use Cwd qw( abs_path );
use Try::Tiny;
use Foswiki qw(urlEncode urlDecode make_params);

use Moo;
use namespace::clean;
extends qw(Foswiki::Object);
with qw(Foswiki::AppObject);
with qw(Foswiki::Aux::Localize);

# Enable to trace auto-configuration (Bootstrap)
use constant TRAUTO => 1;

# This should be the one place in Foswiki that knows the syntax of valid
# configuration item keys. Only simple scalar hash keys are supported.
#
my $ITEMREGEX = qr/(?:\{(?:'(?:\\.|[^'])+'|"(?:\\.|[^"])+"|[A-Za-z0-9_]+)\})+/;

# Generic booleans, used in some older LSC's
our $TRUE  = 1;
our $FALSE = 0;

# Configuration items that have been deprecated and must be mapped to
# new configuration items. The value is mapped unchanged.
my %remap = (
    '{StoreImpl}'           => '{Store}{Implementation}',
    '{AutoAttachPubFiles}'  => '{RCS}{AutoAttachPubFiles}',
    '{QueryAlgorithm}'      => '{Store}{QueryAlgorithm}',
    '{SearchAlgorithm}'     => '{Store}{SearchAlgorithm}',
    '{Site}{CharSet}'       => '{Store}{Encoding}',
    '{RCS}{FgrepCmd}'       => '{Store}{FgrepCmd}',
    '{RCS}{EgrepCmd}'       => '{Store}{EgrepCmd}',
    '{RCS}{overrideUmask}'  => '{Store}{overrideUmask}',
    '{RCS}{dirPermission}'  => '{Store}{dirPermission}',
    '{RCS}{filePermission}' => '{Store}{filePermission}',
    '{RCS}{WorkAreaDir}'    => '{Store}{WorkAreaDir}'
);

=begin TML
---++ Attribute data

Contains configuration hash. =%Foswiki::cfg= is an alias to this attribute.

=cut

has data => (
    is      => 'rw',
    lazy    => 1,
    clearer => 1,
    isa     => Foswiki::Object::isaHASH( 'data', noUndef => 1, ),
    default => sub {
        my $this = shift;
        my $data = {};
        $this->assignGLOB($data);
        return $data;
    },
    trigger => sub {
        my $this = shift;
        $this->assignGLOB;
    },
);

=begin TML
---++ Attribute files

What files we read the config from in the order of reading.

=cut

has files => (
    is      => 'rw',
    lazy    => 1,
    default => sub { [] },
);

=begin TML

---++ ObjectAttribute lscFile

Default filename for local site configuration. Can be set from the following
sources (in the order from hight priority to lower):

   * corresponding constructor parameter
   * environment (or PSGI env) variable FOSWIKI_CONFIG
   * default constant 'LocalSite.cfg'
=cut

has lscFile => (
    is   => 'rwp',
    lazy => 1,
    default =>
      sub { return $_[0]->app->env->{FOSWIKI_CONFIG} || 'LocalSite.cfg'; },
);

=begin TML

---++ Attribute failedConfig

Keeps the name of the failed config or spec file.

=cut

has failedConfig     => ( is => 'rw', );
has bootstrapMessage => ( is => 'rw', );
has noExpand         => ( is => 'rw', default => 0, );
has noSpec           => ( is => 'rw', default => 0, );
has configSpec       => ( is => 'rw', default => 0, );
has noLocal          => ( is => 'rw', default => 0, );

# Configuration shortcut attributes.

=begin TML

---++ ClassMethod new([noExpand => 0/1][, noSpec => 0/1][, configSpec => 0/1][, noLoad => 0/1])
   
   * =noExpand= - suppress expansion of $Foswiki vars embedded in
     values.
   * =noSpec= - can be set when the caller knows that Foswiki.spec
     has already been read.
   * =configSpec= - if set, will also read Config.spec files located
     using the standard methods (iff !$nospec). Slow.
   * =noLocal= - if set, Load will not re-read an existing LocalSite.cfg.
     this is needed when testing the bootstrap.  If it rereads an existing
     config, it overlays all the bootstrapped settings.
=cut

sub BUILD {
    my $this = shift;
    my ($params) = @_;

    $this->_workOutOS;
    $this->_populatePresets;
    $this->_guessDefaults;

    $this->data->{isVALID} =
      $this->readConfig( $this->noExpand, $this->noSpec, $this->configSpec,
        $this->noLocal, );

    $this->_setupGlobals;
}

sub _workOutOS {
    my $this = shift;
    unless ( $this->data->{DetailedOS} ) {
        $this->data->{DetailedOS} = $^O;
    }
    return if $this->data->{OS};
    if ( $this->data->{DetailedOS} =~ m/darwin/i ) {    # Mac OS X
        $this->data->{OS} = 'UNIX';
    }
    elsif ( $this->data->{DetailedOS} =~ m/Win/i ) {
        $this->data->{OS} = 'WINDOWS';
    }
    elsif ( $this->data->{DetailedOS} =~ m/vms/i ) {
        $this->data->{OS} = 'VMS';
    }
    elsif ( $this->data->{DetailedOS} =~ m/bsdos/i ) {
        $this->data->{OS} = 'UNIX';
    }
    elsif ( $this->data->{DetailedOS} =~ m/solaris/i ) {
        $this->data->{OS} = 'UNIX';
    }
    elsif ( $this->data->{DetailedOS} =~ m/dos/i ) {
        $this->data->{OS} = 'DOS';
    }
    elsif ( $this->data->{DetailedOS} =~ m/^MacOS$/i ) {

        # MacOS 9 or earlier
        $this->data->{OS} = 'MACINTOSH';
    }
    elsif ( $this->data->{DetailedOS} =~ m/os2/i ) {
        $this->data->{OS} = 'OS2';
    }
    else {

        # Erm.....
        $this->data->{OS} = 'UNIX';
    }
}

=begin TML

---++ ObjectMethod localize( %init ) => $holder

This methods preserves current =data= attribute on =_dataStack= and sets =data=
to the values provided in =%init=.

See also: =Foswiki::Aux::Localize=

=cut

sub setLocalizableAttributes { return qw(data files); }

around localize => sub {
    my $orig = shift;
    my $this = shift;
    my %init = @_;

    return $orig->( $this, data => \%init, );
};

around doLocalize => sub {
    my $orig = shift;
    my $this = shift;

    $orig->( $this, @_ );

    $this->assignGLOB;
};

=begin TML

---++ ObjectMethod readConfig

In normal Foswiki operations as a web server this method is called by the
=BEGIN= block of =Foswiki.pm=.  However, when benchmarking/debugging it can be
replaced by custom code which sets the configuration hash.  To prevent us from
overriding the custom code again, we use an "unconfigurable" key
=$cfg{ConfigurationFinished}= as an indicator.

Note that this method is called by Foswiki and configure, and normally reads
=Foswiki.spec= to get defaults. Other spec files (those for extensions) are
*not* read unless the $config_spec flag is set.

The assumption is that =configure= will be run when an extension is installed,
and that will add the config values to LocalSite.cfg, so no defaults are
needed. Foswiki.spec is still read because so much of the core code doesn't
provide defaults, and it would be silly to have them in two places anyway.
=cut

sub readConfig {
    my $this = shift;
    my ( $noExpand, $noSpec, $configSpec, $noLocal ) = @_;

    # To prevent us from overriding the custom code in test mode
    return 1 if $this->data->{ConfigurationFinished};

    # Assume LocalSite.cfg is valid - will be set false if errors detected.
    my $validLSC = 1;

    # Read Foswiki.spec and LocalSite.cfg
    # (Suppress Foswiki.spec if already read)

    # Old configs might not bootstrap the OS settings, so set if needed.
    $this->_workOutOS unless ( $this->data->{OS} && $this->data->{DetailedOS} );

    unless ($noSpec) {
        push @{ $this->files }, 'Foswiki.spec';
    }
    if ( !$noSpec && $configSpec ) {
        foreach my $dir (@INC) {
            foreach my $subdir ( 'Foswiki/Plugins', 'Foswiki/Contrib' ) {
                my $d;
                next unless opendir( $d, "$dir/$subdir" );
                my %read;
                foreach
                  my $extension ( grep { !/^\./ && !/^Empty/ } readdir $d )
                {
                    next if $read{$extension};
                    $extension =~ m/(.*)/;    # untaint
                    my $file = "$dir/$subdir/$1/Config.spec";
                    next unless -e $file;
                    push( @{ $this->files }, $file );
                    $read{$extension} = 1;
                }
                closedir($d);
            }
        }
    }
    my $lscFile = $this->lscFile;
    unless ($noLocal) {
        push @{ $this->files }, $lscFile;
    }

    for my $file ( @{ $this->files } ) {
        my $return = do $file;

        unless ( defined $return && $return eq '1' ) {

            my $errorMessage;
            if ($@) {
                $errorMessage = "Failed to parse $file: $@";
                warn "couldn't parse $file: $@" if $@;
            }
            next if ( !DEBUG && ( $file =~ m/Config\.spec$/ ) );
            if ( not defined $return ) {
                unless ( $! == 2 && $file eq $lscFile ) {

                    # LocalSite.cfg doesn't exist, which is OK
                    warn "couldn't do $file: $!";
                    $errorMessage = "Could not do $file: $!";
                }
                $this->failedConfig($file);
                $validLSC = 0;
            }

            # Pointless (says CDot), Config.spec does not need 1; at the end
            #elsif ( not $return eq '1' ) {
            #   print STDERR
            #   "Running file $file returned  unexpected results: $return \n";
            #}
            if ($errorMessage) {

                # SMELL die has to be replaced with an exception.
                die <<GOLLYGOSH;
Content-type: text/plain

$errorMessage
Please inform the site admin.
GOLLYGOSH
                exit 1;
            }
        }
    }

    # Patch deprecated config settings
    # TODO: remove this in version 2.0
    if ( exists $this->data->{StoreImpl} ) {
        $this->data->{Store}{Implementation} =
          'Foswiki::Store::' . $this->data->{StoreImpl};
        delete $this->data->{StoreImpl};
    }
    foreach my $el ( keys %remap ) {

        # Only remap if the old key extsts, and the new key does NOT exist
        if ( ( eval("exists \$this->data->$el") ) ) {
            eval( <<CODE );
\$this->data->$remap{$el}=\$this->data->$el unless ( exists \$this->data->$remap{$el} );
delete \$this->data->$el;
CODE
            print STDERR "REMAP failed $@" if ($@);
        }
    }

    # Expand references to $this->data vars embedded in the values of
    # other $this->data vars.
    $this->expandValue( $this->data ) unless $noExpand;

    $this->data->{ConfigurationFinished} = 1;

    if ( $^O eq 'MSWin32' ) {

        #force paths to use '/'
        $this->data->{PubDir}      =~ s|\\|/|g;
        $this->data->{DataDir}     =~ s|\\|/|g;
        $this->data->{ToolsDir}    =~ s|\\|/|g;
        $this->data->{ScriptDir}   =~ s|\\|/|g;
        $this->data->{TemplateDir} =~ s|\\|/|g;
        $this->data->{LocalesDir}  =~ s|\\|/|g;
        $this->data->{WorkingDir}  =~ s|\\|/|g;
    }

    # Add explicit {Site}{CharSet} for older extensions. Default to utf-8.
    # Explanation is in http://foswiki.org/Tasks/Item13435
    $this->data->{Site}{CharSet} = 'utf-8';

    # Explicit return true if we've completed the load
    return $validLSC;
}

=begin TML

---++ ObjectMethod expandValue($datum [, $mode])

Expands references to Foswiki configuration items which occur in the
values configuration items contained within the datum, which may be a
hash or array reference, or a scalar value. The replacement is done in-place.

$mode - How to handle undefined values:
   * false:  'undef' (string) is returned when an undefined value is
     encountered.
   * 1 : return undef if any undefined value is encountered.
   * 2 : return  '' for any undefined value (including embedded)
   * 3 : die if an undefined value is encountered.

=cut

sub expandValue {
    my $this = shift;
    my $undef;
    $this->_expandValue( $_[0], ( $_[1] || 0 ), $undef );

    $_[0] = undef if ($undef);
}

# $_[0] - value being expanded
# $_[1] - $mode
# $_[2] - $undef (return)
sub _expandValue {
    my $this = shift;
    if ( ref( $_[0] ) eq 'HASH' ) {
        $this->expandValue( $_, $_[1] ) foreach ( values %{ $_[0] } );
    }
    elsif ( ref( $_[0] ) eq 'ARRAY' ) {
        $this->expandValue( $_, $_[1] ) foreach ( @{ $_[0] } );

        # Can't do this, because Windows uses an object (Regexp) for regular
        # expressions.
        #    } elsif (ref($_[0])) {
        #        die("Can't handle a ".ref($_[0]));
    }
    else {
        1 while ( defined( $_[0] )
            && $_[0] =~
            s/(\$Foswiki::cfg$ITEMREGEX)/_handleExpand($this, $1, @_[1,2])/ges
        );
    }
}

# Used to expand the $Foswiki::cfg variable in the expand* routines.
# $_[0] - $item
# $_[1] - $mode
# $_[2] - $undef
sub _handleExpand {
    my $this = shift;
    my $val  = eval( $_[0] );
    Foswiki::Exception::Fatal->throw( text => "Error expanding $_[0]: $@" )
      if ($@);

    return $val                                      if ( defined $val );
    return 'undef'                                   if ( !$_[1] );
    return ''                                        if ( $_[1] == 2 );
    die "Undefined value in expanded string $_[0]\n" if ( $_[1] == 3 );
    $_[2] = 1;
    return '';
}

=begin TML
---++ ObjectMethod bootstrapSystemSettings()

This method tries to determine mandatory configuration defaults to operate
when no LocalSite.cfg is found.

=cut

sub bootstrapSystemSettings {
    my $this = shift;

    # Strip off any occasional configuration data which might be a result of
    # previously failed readConfig.
    $this->clear_data;

    # Restore system-default state.
    $this->_workOutOS;
    $this->_populatePresets;
    $this->_guessDefaults;

    my $env    = $this->app->env;
    my $engine = $this->app->engine;

    print STDERR "AUTOCONFIG: Bootstrap Phase 1: " . Data::Dumper::Dumper($env)
      if (TRAUTO);

    # Try to create $Foswiki::cfg in a minimal configuration,
    # using paths and URLs relative to this request. If URL
    # rewriting is happening in the web server this is likely
    # to go down in flames, but it gives us the best chance of
    # recovering. We need to guess values for all the vars that

    # would trigger "undefined" errors
    my $bin;
    my $script = '';
    if ( defined $env->{FOSWIKI_SCRIPTS} ) {
        $bin = $env->{FOSWIKI_SCRIPTS};
    }
    else {
        eval('require FindBin');
        Foswiki::Exception::Fatal->throw( text =>
              "Could not load FindBin to support configuration recovery: $@" )
          if $@;
        FindBin::again();    # in case we are under mod_perl or similar
        $FindBin::Bin =~ m/^(.*)$/;
        $bin = $1;
        $FindBin::Script =~ m/^(.*)$/;
        $script = $1;
    }

    # Can't use Foswiki::decode_utf8 - this is too early in initialization
    # SMELL TODO The above must not be true anymore. Yet, why not use
    # Encode::decode_utf8?
    print STDERR "AUTOCONFIG: Found Bin dir: "
      . $bin
      . ", Script name: $script using FindBin\n"
      if (TRAUTO);

    $this->data->{ScriptSuffix} = ( fileparse( $script, qr/\.[^.]*/ ) )[2];
    $this->data->{ScriptSuffix} = ''
      if ( $engine->isa('Foswiki::Engine::FastCGI')
        || $engine->isa('Foswiki::Engine::PSGI') );
    print STDERR "AUTOCONFIG: Found SCRIPT SUFFIX "
      . $this->data->{ScriptSuffix} . "\n"
      if ( TRAUTO && $this->data->{ScriptSuffix} );

    my %rel_to_root = (
        DataDir    => { dir => 'data',   required => 0 },
        LocalesDir => { dir => 'locale', required => 0 },
        PubDir     => { dir => 'pub',    required => 0 },
        ToolsDir   => { dir => 'tools',  required => 0 },
        WorkingDir => {
            dir           => 'working',
            required      => 1,
            validate_file => 'README'
        },
        TemplateDir => {
            dir           => 'templates',
            required      => 1,
            validate_file => 'foswiki.tmpl'
        },
        ScriptDir => {
            dir           => 'bin',
            required      => 1,
            validate_file => 'setlib.cfg'
        }
    );

    # Note that we don't resolve x/../y to y, as this might
    # confuse soft links
    my $root = File::Spec->catdir( $bin, File::Spec->updir() );
    $root =~ s{\\}{/}g;
    my $fatal = '';
    my $warn  = '';
    while ( my ( $key, $def ) = each %rel_to_root ) {
        $this->data->{$key} = File::Spec->rel2abs( $def->{dir}, $root );
        $this->data->{$key} = abs_path( $this->data->{$key} );
        ( $this->data->{$key} ) = $this->data->{$key} =~ m/^(.*)$/;    # untaint

        # Need to decode utf8 back to perl characters.  The file path operations
        # all worked with bytes, but Foswiki needs characters.
        $this->data->{$key} = NFC( Encode::decode_utf8( $this->data->{$key} ) );

        print STDERR "AUTOCONFIG: $key = "
          . Encode::encode_utf8( $this->data->{$key} ) . "\n"
          if (TRAUTO);

        if ( -d $this->data->{$key} ) {
            if ( $def->{validate_file}
                && !-e $this->data->{$key} . "/$def->{validate_file}" )
            {
                $fatal .=
                    "\n{$key} (guessed "
                  . $this->data->{$key} . ") "
                  . $this->data->{$key}
                  . "/$def->{validate_file} not found";
            }
        }
        elsif ( $def->{required} ) {
            $fatal .= "\n{$key} (guessed " . $this->data->{$key} . ")";
        }
        else {
            $warn .=
              "\n      * Note: {$key} could not be guessed. Set it manually!";
        }
    }

    # Bootstrap the Site Locale and CharSet
    $this->_bootstrapSiteSettings();

    # Bootstrap the store related settings.
    $this->_bootstrapStoreSettings();

    if ($fatal) {
        my $lscFile = $this->lscFile;
        Foswiki::Exception::Fatal->throw( text => <<EPITAPH );
Unable to bootstrap configuration. $lscFile could not be loaded,
and Foswiki was unable to guess the locations of the following critical
directories: $fatal
EPITAPH
    }

# Re-read Foswiki.spec *and Config.spec*. We need the Config.spec's
# to get a true picture of our defaults (notably those from
# JQueryPlugin. Without the Config.spec, no plugins get registered)
# Don't load LocalSite.cfg if it exists (should normally not exist when bootstrapping)
    $this->readConfig( 0, 0, 1, 1 );
    print STDERR "AUTOCONFIG: Detected OS "
      . $this->data->{OS}
      . ":  DetailedOS: "
      . $this->data->{DetailedOS} . " \n"
      if (TRAUTO);

    $this->_setupGlobals;

    $this->data->{isVALID} = 1;
    $this->setBootstrap;

    # Note: message is not I18N'd because there is no point; there
    # is no localisation in a default cfg derived from Foswiki.spec
    my $system_message = <<BOOTS;
*WARNING !LocalSite.cfg could not be found* (This is normal for a new installation) %BR%
This Foswiki is running using a bootstrap configuration worked
out by detecting the layout of the installation.
BOOTS

    if ($warn) {
        chomp $system_message;
        $system_message .= $warn . "\n";
    }
    $this->bootstrapMessage( $system_message // '' );
}

=begin TML

---++ ObjectMethod bootstrapWebSettings($script)

Called by bootstrapConfig.  This handles the web environment specific settings only:

   * ={DefaultUrlHost}=
   * ={ScriptUrlPath}=
   * ={ScriptUrlPaths}{view}=
   * ={PubUrlPath}=

=cut

sub bootstrapWebSettings {
    my $this   = shift;
    my $script = shift;

    my $app    = $this->app;
    my $env    = $app->env;
    my $engine = $app->engine;

    print STDERR "AUTOCONFIG: Bootstrap Phase 2: "
      . Data::Dumper::Dumper( \%ENV )
      if (TRAUTO);

    # Cannot bootstrap the web side from CLI environments
    if ( !$engine->HTTPCompliant ) {
        $this->data->{DefaultUrlHost} = 'http://localhost';
        $this->data->{ScriptUrlPath}  = '/bin';
        $this->data->{PubUrlPath}     = '/pub';
        print STDERR
          "AUTOCONFIG: Bootstrap Phase 2 bypassed! n/a in the CLI Environment\n"
          if (TRAUTO);
        return 'Phase 2 boostrap bypassed - n/a in CLI environment\n';
    }

    $this->data->{Engine} //= ref($engine);

    my $protocol = $engine->secure ? 'https' : 'http';

    # Figure out the DefaultUrlHost
    if ( $env->{HTTP_HOST} ) {
        $this->data->{DefaultUrlHost} = "$protocol://" . $env->{HTTP_HOST};
        print STDERR "AUTOCONFIG: Set DefaultUrlHost "
          . $this->data->{DefaultUrlHost}
          . " from HTTP_HOST "
          . $env->{HTTP_HOST} . " \n"
          if (TRAUTO);
    }
    elsif ( $env->{SERVER_NAME} ) {
        $this->data->{DefaultUrlHost} = "$protocol://" . $env->{SERVER_NAME};
        print STDERR "AUTOCONFIG: Set DefaultUrlHost "
          . $this->data->{DefaultUrlHost}
          . " from SERVER_NAME "
          . $env->{SERVER_NAME} . " \n"
          if (TRAUTO);
    }
    elsif ( $env->{SCRIPT_URI} ) {
        ( $this->data->{DefaultUrlHost} ) =
          $env->{SCRIPT_URI} =~ m#^(https?://[^/]+)/#;
        print STDERR "AUTOCONFIG: Set DefaultUrlHost "
          . $this->data->{DefaultUrlHost}
          . " from SCRIPT_URI "
          . $env->{SCRIPT_URI} . " \n"
          if (TRAUTO);
    }
    else {

        # OK, so this is barfilicious. Think of something better.
        $this->data->{DefaultUrlHost} = "$protocol://localhost";
        say STDERR "AUTOCONFIG: barfilicious: Set DefaultUrlHost "
          . $this->data->{DefaultUrlHost}
          if (TRAUTO);
    }

# Examine the CGI path.   The 'view' script it typically removed from the
# URL when using "Short URLs.  If this BEGIN block is being run by
# 'view',  then $this->data->{ScriptUrlPaths}{view} will be correctly
# bootstrapped.   If run for any other script, it will be set to a
# reasonable though probably incorrect default.
#
# In order to recover the correct view path when the script is 'configure',
# the ConfigurePlugin stashes the path to the view script into a session variable.
# and then recovers it.  When the jsonrpc script is called to save the configuration
# it then has the VIEWPATH parameter available.  If "view" was never called during
# configuration, then it will not be set correctly.
    my $path_info = $engine->path_info
      || '';    #SMELL Sometimes PATH_INFO appears to be undefined.
    my $request_uri = $engine->request_uri;
    say STDERR "AUTOCONFIG: REQUEST_URI is " . ( $request_uri || '(undef)' )
      if (TRAUTO);
    say STDERR "AUTOCONFIG: SCRIPT_URI  is "
      . ( $env->{SCRIPT_URI} || '(undef)' )
      if (TRAUTO);
    say STDERR "AUTOCONFIG: PATH_INFO   is $path_info" if (TRAUTO);
    say STDERR "AUTOCONFIG: ENGINE      is " . $this->data->{Engine}
      if (TRAUTO);

# This code tries to break the url up into <prefix><script><path> ... The script may or may not
# be present.  Short URLs will omit the script from view operations, and *may* omit the
# <prefix> for all operations.   Examples of URLs and shortening.
#
#  Full:    /foswiki/bin/view/Main/WebHome   /foswiki/bin/edit/Main/WebHome
#  Full:    /bin/view/Main/WebHome           /bin/edit/Main/WebHome            omitting prefix
#  Short:   /foswiki/Main/WebHome            /foswiki/bin/edit/Main/WebHome    omitting bin/view
#  Short:   /Main/WebHome                    /bin/edit/Main/WebHome            omitting prefix and bin/view
#  Shorter: /Main/WebHome                    /edit/Main/WebHome                omitting prefix and bin in all cases.
#
# Note that some of this can't be done as part of the view script.  The only way to know if "bin" is omitted in
# all cases is when a script other than view runs,   like jsonrpc.

    my $pfx;

    my $suffix =
      ( defined $env->{SCRIPT_URL}
          && length( $env->{SCRIPT_URL} ) < length($path_info) )
      ? $env->{SCRIPT_URL}
      : $path_info;

    # Try to Determine the prefix of the script part of the URI.
    if ( $env->{SCRIPT_URI} && $env->{SCRIPT_URL} ) {
        if ( index( $env->{SCRIPT_URI}, $this->data->{DefaultUrlHost} ) eq 0 ) {
            $pfx =
              substr( $env->{SCRIPT_URI},
                length( $this->data->{DefaultUrlHost} ) );
            $pfx =~ s#$suffix$##;
            print STDERR
"AUTOCONFIG: Calculated prefix $pfx from SCRIPT_URI and SCRIPT_URL\n"
              if (TRAUTO);
        }
    }

    unless ( defined $pfx ) {
        if ( my $idx = index( $request_uri, $path_info ) ) {
            $pfx = substr( $request_uri, 0, $idx + 1 );
        }
        $pfx = '' unless ( defined $pfx );
        print STDERR "AUTOCONFIG: URI Prefix is $pfx\n" if (TRAUTO);
    }

    # Work out the URL path for Short and standard URLs
    if ( $request_uri =~ m{^(.*?)/$script(\b|$)} ) {
        my $spfx = $1;
        print STDERR
          "AUTOCONFIG: SCRIPT $script fully contained in REQUEST_URI "
          . $request_uri
          . ", Not short URLs\n"
          if (TRAUTO);

        # Conventional URLs   with path and script
        $this->data->{ScriptUrlPath} = $spfx;
        $this->data->{ScriptUrlPaths}{view} =
          $spfx . '/view' . $this->data->{ScriptSuffix};

        # This might not work, depending on the websrver config,
        # but it's the best we can do
        $this->data->{PubUrlPath} =
          ( length($spfx) ? "$spfx/.." : "" ) . "/pub";
    }
    else {
        print STDERR "AUTOCONFIG: Building Short URL paths using prefix $pfx \n"
          if (TRAUTO);
        $this->data->{ScriptUrlPath}        = $pfx . '/bin';
        $this->data->{ScriptUrlPaths}{view} = $pfx;
        $this->data->{PubUrlPath}           = $pfx . '/pub';
    }

    if (TRAUTO) {
        say STDERR "AUTOCONFIG: Using ScriptUrlPath ",
          $this->data->{ScriptUrlPath};
        say STDERR "AUTOCONFIG: Using {ScriptUrlPaths}{view} "
          . (
            ( defined $this->data->{ScriptUrlPaths}{view} )
            ? $this->data->{ScriptUrlPaths}{view}
            : 'undef'
          );
        say STDERR "AUTOCONFIG: Using PubUrlPath: ", $this->data->{PubUrlPath};
    }

    # Note: message is not I18N'd because there is no point; there
    # is no localisation in a default cfg derived from Foswiki.spec
    my $vp = '';
    $vp = '?VIEWPATH=' . $this->data->{ScriptUrlPaths}{view}
      if ( defined $this->data->{ScriptUrlPaths}{view} );
    my $system_message = <<BOOTS;
*WARNING !LocalSite.cfg could not be found* (This is normal for a new installation) %BR%
This Foswiki is running using a bootstrap configuration worked
out by detecting the layout of the installation.
To complete the bootstrap process you should either:
   * Restore the missing !LocalSite.cfg from a backup, *or*
   * Complete the new Foswiki installation:
      * visit [[%SCRIPTURL{configure}%$vp][configure]] and save a new configuration.
      * Register a user and add it to the %USERSWEB%.AdminGroup
%BR% *You have been logged in as a temporary administrator.*
Any requests made to this Foswiki will be treated as requests made by an administrator with full rights
Your temporary administrator rights will "stick" until you've logged out from this session.
BOOTS

    #'
    return ( $system_message || '' );
}

=begin TML

---++ ObjectMethod _bootstrapSiteSettings()

Called by bootstrapConfig.  This handles the {Site} settings.

=cut

sub _bootstrapSiteSettings {
    my $this = shift;

#   Guess a locale first.   This isn't necessarily used, but helps guess a CharSet, which is always used.

    require locale;
    $this->data->{Site}{Locale} = setlocale(LC_CTYPE);

    print STDERR "AUTOCONFIG: Set initial {Site}{Locale} to  "
      . $this->data->{Site}{Locale} . "\n";
}

=begin TML

---++ ObjectMethod _bootstrapStoreSettings()

Called by bootstrapConfig.  This handles the store specific settings.   This in turn
tests each Store Contib to determine if it's capable of bootstrapping.

=cut

sub _bootstrapStoreSettings {
    my $this = shift;

    # Ask each installed store to bootstrap itself.

    my @stores = Foswiki::Configure::FileUtil::findPackages(
        'Foswiki::Contrib::*StoreContrib');

    foreach my $store (@stores) {
        Foswiki::load_package($store);
        my $ok;
        eval('$ok = $store->can(\'bootstrapStore\')');
        if ($@) {
            print STDERR $@;
        }
        else {
            $store->bootstrapStore() if ($ok);
        }
    }

    # Handle the common store settings managed by Core.  Important ones
    # guessed/checked here include:
    #  - $Foswiki::cfg{Store}{SearchAlgorithm}

    # Set PurePerl search on Windows, or FastCGI systems.
    if (
        (
               $this->data->{Engine}
            && $this->data->{Engine} =~ m/(FastCGI|Apache)/
        )
        || $^O eq 'MSWin32'
      )
    {
        $this->data->{Store}{SearchAlgorithm} =
          'Foswiki::Store::SearchAlgorithms::PurePerl';
        print STDERR
"AUTOCONFIG: Detected FastCGI, mod_perl or MS Windows. {Store}{SearchAlgorithm} set to PurePerl\n"
          if (TRAUTO);
    }
    else {

        # SMELL: The fork to `grep goes into a loop in the unit tests
        # Not sure why, for now just default to pure perl bootstrapping
        # in the unit tests.
        if ( !$this->app->inUnitTestMode ) {

            # Untaint PATH so we can check for grep on the path
            my $x = $ENV{PATH} || '';
            $x =~ m/^(.*)$/;
            $ENV{PATH} = $1;
            `grep -V 2>&1`;
            if ($!) {
                print STDERR
"AUTOCONFIG: Unable to find a valid 'grep' on the path. Forcing PurePerl search\n"
                  if (TRAUTO);
                $this->data->{Store}{SearchAlgorithm} =
                  'Foswiki::Store::SearchAlgorithms::PurePerl';
            }
            else {
                $this->data->{Store}{SearchAlgorithm} =
                  'Foswiki::Store::SearchAlgorithms::Forking';
                print STDERR
                  "AUTOCONFIG: {Store}{SearchAlgorithm} set to Forking\n"
                  if (TRAUTO);
            }
            $ENV{PATH} = $x;    # re-taint
        }
        else {
            $this->data->{Store}{SearchAlgorithm} =
              'Foswiki::Store::SearchAlgorithms::PurePerl';
        }
    }

    # Detect the NFC / NDF normalization of the file system, and set
    # NFCNormalizeFilenames if needed.
    # SMELL: Really this should be done per web, both in data and pub.
    my $nfcok =
      Foswiki::Configure::FileUtil::canNfcFilenames( $Foswiki::cfg{DataDir} );
    if ( defined $nfcok && $nfcok == 1 ) {
        print STDERR "AUTOCONFIG: Data Storage allows NFC filenames\n"
          if (TRAUTO);
        $this->data->{NFCNormalizeFilenames} = 0;
    }
    elsif ( defined($nfcok) && $nfcok == 0 ) {
        print STDERR "AUTOCONFIG: Data Storage enforces NFD filenames\n"
          if (TRAUTO);
        $this->data->{NFCNormalizeFilenames} = 1
          ; #the configure's interface still shows unchecked - so, don't understand.. ;(
    }
    else {
        print STDERR "AUTOCONFIG: WARNING: Unable to detect Normalization.\n";
        $this->data->{NFCNormalizeFilenames} = 1;    #enable too - safer as none
    }
}

=begin TML

---++ ObjectMethod setBootstrap()

This routine is called to initialize the bootstrap process.   It sets the list of
configuration parameters that will need to be set and "protected" during bootstrap.

If any keys will be set during bootstrap / initial creation of LocalSite.cfg, they
should be added here so that they are preserved when the %Foswiki::cfg hash is
wiped and re-initialized from the Foswiki spec.

=cut

sub setBootstrap {
    my $this = shift;

    # Bootstrap works out the correct values of these keys
    my @BOOTSTRAP =
      qw( {DataDir} {DefaultUrlHost} {DetailedOS} {OS} {PubUrlPath} {ToolsDir} {WorkingDir}
      {PubDir} {TemplateDir} {ScriptDir} {ScriptUrlPath} {ScriptUrlPaths}{view}
      {ScriptSuffix} {LocalesDir} {Store}{Implementation} {NFCNormalizeFilenames}
      {Store}{SearchAlgorithm} {Site}{Locale} );

    $this->data->{isBOOTSTRAPPING} = 1;
    ASSERT( $this->data->{isBOOTSTRAPPING} );
    $this->data->{AisBOOTSTRAPPING} = 1;
    push( @{ $this->data->{BOOTSTRAP} }, @BOOTSTRAP );
}

=begin TML

---++ ObjectMethod get()

$app->cfg->get(Root => Branch => Leaf =>);
$app->cfg->get([qw(Root Branch Leaf)]);
$app->cfg->get("Root.Branch.Leaf");
$app->cfg->get("{Root}{Branch}{Leaf}");

=cut

sub _validateCfgKey {
    my $this = shift;
    my ($keyName) = @_;

    Foswiki::Exception::Cfg::InvalidKeyName->throw(
        text    => "Key name cannot be undef",
        keyName => undef,
    ) unless defined($keyName);

    Foswiki::Exception::Cfg::InvalidKeyName->throw(
        text => "Key name must be a scalar value, not "
          . ref($keyName)
          . " reference",
        keyName => $keyName,
    ) if ref($keyName);

    Foswiki::Exception::Cfg::InvalidKeyName->throw(
        text    => "Invalid config key name `$keyName`",
        keyName => $keyName,
    ) unless $keyName =~ /^[[:alnum:]_]+$/;
}

sub _arg2keys {
    my $this = shift;
    my @keys;

    if ( @_ == 1 ) {
        if ( ref( $_[0] ) ) {
            Foswiki::Exception::Fatal->throw(
                text => "Reference passed is not an arrayref but "
                  . ref( $_[0] ), )
              unless ref( $_[0] ) eq 'ARRAY';
            @keys = @{ $_[0] };
        }
        elsif ( $_[0] =~ /^(?:{[^{}]+})+$/ ) {
            @keys = $_[0] =~ /{([^{}]+)}/g;
        }
        else {
            @keys = split '.', $_[0];
        }
    }
    elsif ( @_ > 1 ) {
        @keys = @_;
    }

    Foswiki::Exception::Fatal->throw(
        text => "No valid config keys found in the method arguments" )
      unless @keys > 0;

    $this->_validateCfgKey($_) foreach @keys;

    return @keys;
}

sub _getSubHash {
    my $this = shift;
    my @keys = @_;

    my $subHash = $this->data;
    my $cfgPath;

    while ( @keys > 1 ) {
        my $key = shift @keys;
        $cfgPath = defined $cfgPath ? "$cfgPath.$key" : $key;
        $subHash = $subHash->{$key};
        Foswiki::Exception::Fatal->throw(
            text => "Not a hash ref value in $cfgPath", )
          unless ref($subHash) eq 'HASH';
    }

    return ( $subHash, $keys[0] );
}

sub get {
    my $this = shift;

    my ( $subHash, $leafName ) = $this->_getSubHash( $this->_arg2keys(@_) );

    return $subHash->{$leafName};
}

=begin TML

---++ ObjectMethod set($cfgPath => $value)

$app->cfg->set([qw(Root Branch Leaf)], $value);
$app->cfg->set("Root.Branch.Leaf", $value);
$app->cfg->set("{Root}{Branch}{Leaf}", $value);
=cut

sub set {
    my $this = shift;
    my ( $cfgPath, $value ) = @_;

    my ( $subHash, $leafName ) =
      $this->_getSubHash( $this->_arg2keys($cfgPath) );

    $subHash->{$leafName} = $value;
}

=begin TML

---++ ObjectMethod getAttachmentURL( $web, $topic, $attachment, %options ) -> $url

Get a URL that points at an attachment. The URL may be absolute, or
relative to the the page being rendered (if that makes sense for the
store implementation).
   * =$web= - name of the web for the URL
   * =$topic= - name of the topic
   * =$attachment= - name of the attachment, defaults to no attachment
   * %options - parameters to be attached to the URL

Supported %options are:
   * =topic_version= - version of topic to retrieve attachment from
   * =attachment_version= - version of attachment to retrieve
   * =absolute= - if the returned URL must be absolute, rather than relative

If =$web= is not given, =$topic= and =$attachment= are ignored/
If =$topic= is not given, =$attachment= is ignored.

If =topic_version= is not given, the most recent revision of the topic
should be linked. Similarly if attachment_version= is not given, the most recent
revision of the attachment will be assumed. If =topic_version= is specified
but =attachment_version= is not (or the specified =attachment_version= is not
present), then the most recent version of the attachment in that topic version
will be linked. Stores may not support =topic_version= and =attachment_version=.

The default implementation is suitable for use with stores that put
attachments in a web-visible directory, pointed at by
$Foswiki::cfg{PubUrlPath}. As such it may also be used as a
fallback for distributed topics (such as those in System) when content is not
held in the store itself (e.g. if the store doesn't recognise the web it
can call SUPER::getAttachmentURL)

As required by RFC3986, the returned URL may only contain the
allowed characters -A-Za-z0-9_.~!*\'();:@&=+$,/?%#[]

=cut

sub getAttachmentURL {
    my ( $this, $web, $topic, $attachment, %options ) = @_;

    ASSERT( !ref($web), "Old format of getAttachmentURL call" );

    my $url = $this->data->{PubUrlPath} || '';

    if ($topic) {
        ( $web, $topic ) = Foswiki::Func::normalizeWebTopicName( $web, $topic );
    }

    if ($web) {
        $url .= '/' . Foswiki::urlEncode($web);
        if ($topic) {
            if ( defined $options{topic_version} ) {

                # TODO: check that the given topic version exists
            }
            $url .= '/' . Foswiki::urlEncode($topic);
            if ($attachment) {
                if ( defined $options{attachment_version} ) {

                    # TODO: check that this attachment version actually
                    # exists on the requested topic version
                }

                # TODO: check that the attachment actually exists on the
                # topic at this revision
                $url .= '/' . Foswiki::urlEncode($attachment);
            }
        }
    }

    if ( $options{absolute} && $url !~ /^[a-z]+:/ ) {

        # See http://www.ietf.org/rfc/rfc2396.txt for the definition of
        # "absolute URI". Foswiki bastardises this definition by assuming
        # that all relative URLs lack the <authority> component as well.
        $url = $this->urlHost . $url;
    }

    return $url;
}

=begin TML

---++ ObjectMethod getPubURL($web, $topic, $attachment, %options) -> $url

Composes a pub url.
   * =$web= - name of the web for the URL, defaults to $session->{webName}
   * =$topic= - name of the topic, defaults to $session->{topicName}
   * =$attachment= - name of the attachment, defaults to no attachment
Supported %options are:
   * =topic_version= - version of topic to retrieve attachment from
   * =attachment_version= - version of attachment to retrieve
   * =absolute= - requests an absolute URL (rather than a relative path)

If =$web= is not given, =$topic= and =$attachment= are ignored.
If =$topic= is not given, =$attachment= is ignored.

If =topic_version= is not given, the most recent revision of the topic
will be linked. Similarly if attachment_version= is not given, the most recent
revision of the attachment will be assumed. If =topic_version= is specified
but =attachment_version= is not (or the specified =attachment_version= is not
present), then the most recent version of the attachment in that topic version
will be linked.

If Foswiki is running in an absolute URL context (e.g. the skin requires
absolute URLs, such as print or rss, or Foswiki is running from the
command-line) then =absolute= will automatically be set.

Note: for compatibility with older plugins, which use %PUBURL*% with
a constructed URL path, do not use =*= unless =web=, =topic=, and
=attachment= are all specified.

As required by RFC3986, the returned URL will only contain the
allowed characters -A-Za-z0-9_.~!*\'();:@&=+$,/?%#[]

=cut

sub getPubURL {
    my ( $this, $web, $topic, $attachment, %options ) = @_;

    $options{absolute} ||=
      (      $this->app->inContext('command_line')
          || $this->app->inContext('absolute_urls') );

    return $this->getAttachmentURL( $web, $topic, $attachment, %options );
}

=begin TML

---++ ObjectMethod getScriptUrl( $absolute, $script, $web, $topic, ... ) -> $scriptURL

Returns the URL to a Foswiki script, providing the web and topic as
"path info" parameters.  The result looks something like this:
"http://host/foswiki/bin/$script/$web/$topic".
   * =...= - an arbitrary number of name,value parameter pairs that will
be url-encoded and added to the url. The special parameter name '#' is
reserved for specifying an anchor. e.g.
=getScriptUrl('x','y','view','#'=>'XXX',a=>1,b=>2)= will give
=.../view/x/y?a=1&b=2#XXX=

If $absolute is set, generates an absolute URL. $absolute is advisory only;
Foswiki can decide to generate absolute URLs (for example when run from the
command-line) even when relative URLs have been requested.

The default script url is taken from {ScriptUrlPath}, unless there is
an exception defined for the given script in {ScriptUrlPaths}. Both
{ScriptUrlPath} and {ScriptUrlPaths} may be absolute or relative URIs. If
they are absolute, then they will always generate absolute URLs. if they
are relative, then they will be converted to absolute when required (e.g.
when running from the command line, or when generating rss). If
$script is not given, absolute URLs will always be generated.

If either the web or the topic is defined, will generate a full url (including web and topic). Otherwise will generate only up to the script name. An undefined web will default to the main web name.

As required by RFC3986, the returned URL will only contain the
allowed characters -A-Za-z0-9_.~!*\'();:@&=+$,/?%#[]

=cut

sub getScriptUrl {
    my ( $this, $absolute, $script, $web, $topic, @params ) = @_;

    my $app = $this->app;

    $absolute ||=
      ( $app->inContext('command_line') || $app->inContext('absolute_urls') );

    # SMELL: topics and webs that contain spaces?

    my $url;
    if ( defined $this->data->{ScriptUrlPaths} && $script ) {
        $url = $this->data->{ScriptUrlPaths}{$script};
    }
    unless ( defined($url) ) {
        $url = $this->data->{ScriptUrlPath};
        if ($script) {
            $url .= '/' unless $url =~ m/\/$/;
            $url .= $script;
            if (
                rindex( $url, $this->data->{ScriptSuffix} ) !=
                ( length($url) - length( $this->data->{ScriptSuffix} ) ) )
            {
                $url .= $this->data->{ScriptSuffix} if $script;
            }
        }
    }

    if ( $absolute && $url !~ /^[a-z]+:/ ) {

        # See http://www.ietf.org/rfc/rfc2396.txt for the definition of
        # "absolute URI". Foswiki bastardises this definition by assuming
        # that all relative URLs lack the <authority> component as well.
        $url = $this->urlHost . $url;
    }

    if ($topic) {
        ( $web, $topic ) = $app->request->normalizeWebTopicName( $web, $topic );

        $url .= urlEncode( '/' . $web . '/' . $topic );

    }
    elsif ($web) {
        $url .= urlEncode( '/' . $web );
    }
    $url .= make_params(@params);

    return $url;
}

=begin TML

---++ ObjectMethod patch(%cfgChunk) or patch(\%cfgChunk)

Patches the config object data with keys in =%cfgChunk=. Keys already existing
in the config data are overriden with those from the chunk.

=cut

sub patch {
    my $this = shift;
    my %cfgChunk;
    if ( @_ == 1 ) {
        %cfgChunk = %{ $_[0] };
    }
    else {
        %cfgChunk = @_;
    }
    my $data = $this->data;
    $data->{$_} = $cfgChunk{$_} foreach keys %cfgChunk;
}

=begin TML

---++ ObjectMethod urlHost

=cut

sub urlHost {
    my $this = shift;

    #{urlHost}  is needed by loadSession..
    my $url = $this->app->request->url;
    my $cfg = $this->app->cfg;
    my $urlHost;
    if (   $url
        && !$cfg->data->{ForceDefaultUrlHost}
        && $url =~ m{^([^:]*://[^/]*).*$} )
    {
        $urlHost = $1;

        if ( $cfg->data->{RemovePortNumber} ) {
            $urlHost =~ s/\:[0-9]+$//;
        }

        # If the urlHost in the url is localhost, this is a lot less
        # useful than the default url host. This is because new CGI("")
        # assigns this host by default - it's a default setting, used
        # when there is nothing better available.
        if ( $urlHost =~ m/^(https?:\/\/)localhost$/i ) {
            my $protocol = $1;

#only replace localhost _if_ the protocol matches the one specified in the DefaultUrlHost
            if ( $cfg->data->{DefaultUrlHost} =~ m/^$protocol/i ) {
                $urlHost = $cfg->data->{DefaultUrlHost};
            }
        }
    }
    else {
        $urlHost = $cfg->data->{DefaultUrlHost};
    }
    ASSERT($urlHost) if DEBUG;
    return $urlHost;
}

# Preset values that are hard-coded and not coming from external sources.
sub _populatePresets {
    my $this = shift;

    my $cfgData = $this->data;

    $cfgData->{SwitchBoard} //= {};

    # package - perl package that contains the method for this request
    # function - name of the function in package
    # context - hash of context vars to define
    # allow - hash of HTTP methods to allow (all others are denied)
    # deny - hash of HTTP methods that are denied (all others are allowed)
    # 'deny' is not tested if 'allow' is defined

    # The switchboard can contain entries either as hashes or as arrays.
    # The array format specifies [0] package, [1] function, [2] context
    # and should be used when declaring scripts from plugins that must work
    # with Foswiki 1.0.0 and 1.0.4.

    $cfgData->{SwitchBoard}{attach} = {
        package  => 'Foswiki::UI::Attach',
        request  => 'Foswiki::Request::Attachment',
        function => 'attach',
        context  => { attach => 1 },
    };
    $cfgData->{SwitchBoard}{changes} = {
        package  => 'Foswiki::UI::Changes',
        request  => 'Foswiki::Request',
        function => 'changes',
        context  => { changes => 1 },
    };
    $cfgData->{SwitchBoard}{configure} = {
        package => 'Foswiki::UI::Configure',
        request => 'Foswiki::Request',
        method  => 'configure',
    };
    $cfgData->{SwitchBoard}{edit} = {
        request  => 'Foswiki::Request',
        package  => 'Foswiki::UI::Edit',
        function => 'edit',
        context  => { edit => 1 },
    };
    $cfgData->{SwitchBoard}{jsonrpc} = {
        package => 'Foswiki::Contrib::JsonRpcContrib',
        request => 'Foswiki::Request::JSON',
        method  => 'dispatch',
        context => { jsonrpc => 1 },
    };
    $cfgData->{SwitchBoard}{login} = {
        package  => undef,
        function => 'logon',
        request  => 'Foswiki::Request',
        context  => { ( login => 1, logon => 1 ) },
    };
    $cfgData->{SwitchBoard}{logon} = {
        package  => undef,
        function => 'logon',
        request  => 'Foswiki::Request',
        context  => { ( login => 1, logon => 1 ) },
    };
    $cfgData->{SwitchBoard}{manage} = {
        package  => 'Foswiki::UI::Manage',
        request  => 'Foswiki::Request',
        function => 'manage',
        context  => { manage => 1 },
        allow    => { POST => 1 },
    };
    $cfgData->{SwitchBoard}{oops} = {
        package  => 'Foswiki::UI::Oops',
        function => 'oops_cgi',
        request  => 'Foswiki::Request',
        context  => { oops => 1 },
    };
    $cfgData->{SwitchBoard}{preview} = {
        package  => 'Foswiki::UI::Preview',
        request  => 'Foswiki::Request',
        function => 'preview',
        context  => { preview => 1 },
    };
    $cfgData->{SwitchBoard}{previewauth} = $cfgData->{SwitchBoard}{preview};
    $cfgData->{SwitchBoard}{rdiff}       = {
        package  => 'Foswiki::UI::RDiff',
        request  => 'Foswiki::Request',
        function => 'diff',
        context  => { diff => 1 },
    };
    $cfgData->{SwitchBoard}{rdiffauth} = $cfgData->{SwitchBoard}{rdiff};
    $cfgData->{SwitchBoard}{register}  = {
        package => 'Foswiki::UI::Register',
        request => 'Foswiki::Request',
        method  => 'register_cgi',
        context => { register => 1 },

        # method verify must allow GET; protect in Foswiki::UI::Register
        #allow => { POST => 1 },
    };
    $cfgData->{SwitchBoard}{rename} = {
        package  => 'Foswiki::UI::Rename',
        request  => 'Foswiki::Request',
        function => 'rename',
        context  => { rename => 1 },

        # Rename is 2 stage; protect in Foswiki::UI::Rename
        #allow => { POST => 1 },
    };
    $cfgData->{SwitchBoard}{resetpasswd} = {
        package  => 'Foswiki::UI::Passwords',
        request  => 'Foswiki::Request',
        function => 'resetPassword',
        context  => { resetpasswd => 1 },
        allow    => { POST => 1 },
    };
    $cfgData->{SwitchBoard}{rest} = {
        package  => 'Foswiki::UI::Rest',
        request  => 'Foswiki::Request::Rest',
        function => 'rest',
        context  => { rest => 1 },
    };
    $cfgData->{SwitchBoard}{restauth} = $cfgData->{SwitchBoard}{rest};
    $cfgData->{SwitchBoard}{save}     = {
        package  => 'Foswiki::UI::Save',
        request  => 'Foswiki::Request',
        function => 'save',
        context  => { save => 1 },
        allow    => { POST => 1 },
    };
    $cfgData->{SwitchBoard}{search} = {
        package  => 'Foswiki::UI::Search',
        request  => 'Foswiki::Request',
        function => 'search',
        context  => { search => 1 },
    };
    $cfgData->{SwitchBoard}{statistics} = {
        package  => 'Foswiki::UI::Statistics',
        request  => 'Foswiki::Request',
        function => 'statistics',
        context  => { statistics => 1 },
    };
    $cfgData->{SwitchBoard}{upload} = {
        package  => 'Foswiki::UI::Upload',
        request  => 'Foswiki::Request',
        function => 'upload',
        context  => { upload => 1 },
        allow    => { POST => 1 },
    };
    $cfgData->{SwitchBoard}{viewfile} = {
        package => 'Foswiki::UI::Viewfile',
        request => 'Foswiki::Request::Attachment',
        method  => 'viewfile',
        context => { viewfile => 1 },
    };
    $cfgData->{SwitchBoard}{viewfileauth} = $cfgData->{SwitchBoard}{viewfile};
    $cfgData->{SwitchBoard}{view}         = {
        package  => 'Foswiki::UI::View',
        function => 'view',
        context  => { view => 1 },
        request  => 'Foswiki::Request',
    };
    $cfgData->{SwitchBoard}{viewauth} = $cfgData->{SwitchBoard}{view};

    # List of supported engines. Used by =Foswiki::Engine::start()= method.
    $cfgData->{EngineList} = [
        'PSGI',
        'CGI',

        #'Apache',
        #'FastCGI',
        'CLI'
        , # CLI engine probe() method always return true because this is the last resort engine.
    ];
}

# Try to guess values which are not set.
sub _guessDefaults {
    my $this = shift;

    # Guess temporary files location if not preset.
    unless ( $this->data->{TempfileDir} ) {

        # Give it a sane default.
        if ( $this->data->{OS} eq 'WINDOWS' ) {

            # Windows default tmpdir is the C: root  use something sane.
            # Configure does a better job,  it should be run.
            $this->data->{TempfileDir} = $this->data->{WorkingDir};
        }
        else {
            $this->data->{TempfileDir} = File::Spec->tmpdir();
        }
    }

    # If not set, default to strikeone validation
    $this->data->{Validation}{Method} ||= 'strikeone';
    $this->data->{Validation}{ValidForTime} = $this->data->{LeaseLength}
      unless defined $this->data->{Validation}{ValidForTime};
    $this->data->{Validation}{MaxKeys} = 1000
      unless defined $this->data->{Validation}{MaxKeys};
}

# Setup global variables/structures dependant on configuration.
sub _setupGlobals {
    my $this = shift;

    # Set up pre-compiled regexes for use in rendering.
    # In the regex hash, all precompiled REs have "Regex" at the
    # end of the name. Anything else is a string, either intended
    # for use as a character class, or as a sub-expression in
    # another compiled RE.

    # Character class components for use in regexes.
    # (Pre-UTF-8 compatibility; not used in core)
    $Foswiki::regex{upperAlpha}    = '[:upper:]';
    $Foswiki::regex{lowerAlpha}    = '[:lower:]';
    $Foswiki::regex{numeric}       = '[:digit:]';
    $Foswiki::regex{mixedAlpha}    = '[:alpha:]';
    $Foswiki::regex{mixedAlphaNum} = '[:alnum:]';
    $Foswiki::regex{lowerAlphaNum} = '[:lower:][:digit:]';
    $Foswiki::regex{upperAlphaNum} = '[:upper:][:digit:]';

    # Compile regexes for efficiency and ease of use
    # Note: qr// locks in regex modes (i.e. '-xism' here) - see Friedl
    # book at http://regex.info/.

    $Foswiki::regex{linkProtocolPattern} = $this->data->{LinkProtocolPattern}
      || '(file|ftp|gopher|https|http|irc|mailto|news|nntp|telnet)';

    # Header patterns based on '+++'. The '###' are reserved for numbered
    # headers
    # '---++ Header', '---## Header'
    $Foswiki::regex{headerPatternDa} = qr/^---+(\++|\#+)(.*)$/m;

    # '<h6>Header</h6>
    $Foswiki::regex{headerPatternHt} = qr/^<h([1-6])>(.+?)<\/h\1>/mi;

    # '---++!! Header' or '---++ Header %NOTOC% ^top'
    $Foswiki::regex{headerPatternNoTOC} = '(\!\!+|%NOTOC%)';

    # Foswiki concept regexes
    $Foswiki::regex{wikiWordRegex} = qr(
            [[:upper:]]+
            [[:lower:][:digit:]]+
            [[:upper:]]+
            [[:alnum:]]*
       )xo;
    $Foswiki::regex{webNameBaseRegex} = qr/[[:upper:]]+[[:alnum:]_]*/;
    if ( $this->data->{EnableHierarchicalWebs} ) {
        $Foswiki::regex{webNameRegex} = qr(
                $Foswiki::regex{webNameBaseRegex}
                (?:(?:[\.\/]$Foswiki::regex{webNameBaseRegex})+)*
           )xo;
    }
    else {
        $Foswiki::regex{webNameRegex} = $Foswiki::regex{webNameBaseRegex};
    }
    $Foswiki::regex{defaultWebNameRegex} = qr/_[[:alnum:]_]+/;
    $Foswiki::regex{anchorRegex}         = qr/\#[[:alnum:]:._]+/;
    my $abbrevLength = $this->data->{AcronymLength} || 3;
    $Foswiki::regex{abbrevRegex} = qr/[[:upper:]]{$abbrevLength,}s?\b/;

    $Foswiki::regex{topicNameRegex} =
qr/(?:(?:$Foswiki::regex{wikiWordRegex})|(?:$Foswiki::regex{abbrevRegex}))/;

    # Email regex, e.g. for WebNotify processing and email matching
    # during rendering.

    my $emailAtom = qr([A-Z0-9\Q!#\$%&'*+-/=?^_`{|}~\E])i;    # Per RFC 5322 ]

    # Valid TLD's at http://data.iana.org/TLD/tlds-alpha-by-domain.txt
    # Version 2012022300, Last Updated Thu Feb 23 15:07:02 2012 UTC
    my $validTLD = $this->data->{Email}{ValidTLD};

    unless ( eval { qr/$validTLD/ } ) {
        $validTLD =
qr(AERO|ARPA|ASIA|BIZ|CAT|COM|COOP|EDU|GOV|INFO|INT|JOBS|MIL|MOBI|MUSEUM|NAME|NET|ORG|PRO|TEL|TRAVEL|XXX)i;

# Too early to log, should do something here other than die (which prevents fixing)
# warn is trapped and turned into a die...
#warn( "{Email}{ValidTLD} does not compile, using default" );
    }

    $Foswiki::regex{emailAddrRegex} = qr(
       (?:                            # LEFT Side of Email address
         (?:$emailAtom+                  # Valid characters left side of email address
           (?:\.$emailAtom+)*            # And 0 or more dotted atoms
         )
       |
         (?:"[\x21\x23-\x5B\x5D-\x7E\s]+?")   # or a quoted string per RFC 5322
       )
       @
       (?:                          # RIGHT side of Email address
         (?:                           # FQDN
           [a-z0-9-]+                     # hostname part
           (?:\.[a-z0-9-]+)*              # 0 or more alphanumeric domains following a dot.
           \.(?:                          # TLD
              (?:[a-z]{2,2})                 # 2 character TLD
              |
              $validTLD                      # TLD's longer than 2 characters
           )
         )
         |
           (?:\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])      # dotted triplets IP Address
         )
       )oxi;

    # Item11185: This is how things were before we began Operation Unicode:
    #
    # $Foswiki::regex{filenameInvalidCharRegex} = qr/[^[:alnum:]\. _-]/;
    #
    # It was only used in Foswiki::Sandbox::sanitizeAttachmentName(), which now
    # uses $Foswiki::cfg{NameFilter} instead.
    # See RobustnessTests::test_sanitizeAttachmentName
    #
    # Actually, this is used in GenPDFPrincePlugin; let's copy NameFilter
    $Foswiki::regex{filenameInvalidCharRegex} =
      qr/$Foswiki::cfg{AttachmentNameFilter}/;

    # Multi-character alpha-based regexes
    $Foswiki::regex{mixedAlphaNumRegex} = qr/[[:alnum:]]*/;

    # %TAG% name
    $Foswiki::regex{tagNameRegex} = '[A-Za-z][A-Za-z0-9_:]*';

    # Set statement in a topic
    $Foswiki::regex{bulletRegex} = '^(?:\t|   )+\*';
    $Foswiki::regex{setRegex} =
      $Foswiki::regex{bulletRegex} . '\s+(Set|Local)\s+';
    $Foswiki::regex{setVarRegex} =
        $Foswiki::regex{setRegex} . '('
      . $Foswiki::regex{tagNameRegex}
      . ')\s*=\s*(.*)$';

    # Character encoding regexes

    # Regex to match only a valid UTF-8 character, taking care to avoid
    # security holes due to overlong encodings by excluding the relevant
    # gaps in UTF-8 encoding space - see 'perldoc perlunicode', Unicode
    # Encodings section.  Tested against Markus Kuhn's UTF-8 test file
    # at http://www.cl.cam.ac.uk/~mgk25/ucs/examples/UTF-8-test.txt.
    $Foswiki::regex{validUtf8CharRegex} = qr{
                # Single byte - ASCII
                [\x00-\x7F]
                |

                # 2 bytes
                [\xC2-\xDF][\x80-\xBF]
                |

                # 3 bytes

                    # Avoid illegal codepoints - negative lookahead
                    (?!\xEF\xBF[\xBE\xBF])

                    # Match valid codepoints
                    (?:
                    ([\xE0][\xA0-\xBF])|
                    ([\xE1-\xEC\xEE-\xEF][\x80-\xBF])|
                    ([\xED][\x80-\x9F])
                    )
                    [\x80-\xBF]
                |

                # 4 bytes
                    (?:
                    ([\xF0][\x90-\xBF])|
                    ([\xF1-\xF3][\x80-\xBF])|
                    ([\xF4][\x80-\x8F])
                    )
                    [\x80-\xBF][\x80-\xBF]
                }xo;

    $Foswiki::regex{validUtf8StringRegex} =
      qr/^(?:$Foswiki::regex{validUtf8CharRegex})+$/;

    # Check for unsafe search regex mode (affects filtering in) - default
    # to safe mode
    $this->data->{ForceUnsafeRegexes} = 0
      unless defined $this->data->{ForceUnsafeRegexes};
}

=begin TML

---++ ObjectMethod assignGLOB()

Sets the global =%Foswiki::cfg= hash to be an alias to the config's object
=data= attribute.

=cut

sub assignGLOB {
    my $this = shift;
    my ($data) = @_;

    $data //= $this->data;

    # Alias ::cfg for compatibility. Though $app->cfg should be preferred
    # way of accessing config.
    *Foswiki::cfg = $data;
}

# Check if $Foswiki::cfg is an alias to this object's data attribute. Useful for
# debugging only.
sub _validateBindings {
    my $this    = shift;
    my $testKey = '__TEST_VALUE__';
    $this->data->{$testKey} = 'Test is OK';
    ASSERT(
        $Foswiki::cfg{$testKey} eq $this->data->{$testKey},
"%Foswiki::cfg is not mapped to the active Foswiki::Config object data attribute"
    );
    $testKey = '__TEST_ANOTHER__';
    $Foswiki::cfg{$testKey} = "Now it different";
    ASSERT(
        $Foswiki::cfg{$testKey} eq $this->data->{$testKey},
        "Foswiki::Config data attribute is not mapped to the %Foswiki::cfg hash"
    );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2016 Foswiki Contributors. Foswiki Contributors
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
