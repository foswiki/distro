#!/usr/bin/env perl
# See bottom of file for license and copyright information
use strict;
use warnings;

use re 'taint';
use File::Path();
use File::Copy();
use File::Spec();
use FindBin();
use Cwd();
use Carp;
use Error;
$Error::Debug = 1;

my $usagetext = <<'EOM';
pseudo-install extensions into a git checkout

This is done by a link or copy of the files listed in the MANIFEST for the
extension. The installer script is *not* called. It should be almost equivalent
to a tar zx of the packaged extension over the dev tree, except that the use
of links enable a much more useable development environment.

It picks up extensions to be installed from a search path compiled from (1) the
environment variable $FOSWIKI_EXTENSIONS, then (2) the extensions_path array
defined under the key 'pseudo-install' in the config file ($HOME/.buildcontrib
by default). The default path includes current working directory & its parent.

Usage: pseudo-install.pl -[G|C][feA][l|c|u] [-E<cfg> <module>] [all|default|
              developer|<module>|git://a.git/url, a@g.it:/url etc.]
  -A[utoconf]  - make a simplistic LocalSite.cfg, using just the defaults in
                 lib/Foswiki.spec
  -C[onfig]    - path to config file (default $HOME/.buildcontrib, or envar
                                              $FOSWIKI_PSEUDOINSTALL_CONFIG)
  -E<c> <extn> - include extra configuration values into LocalSite.cfg. <c>.cfg
                 file must exist in the same dir as <extn>'s Config.spec file
  -G[enerate]  - generate default psuedo-install config in $HOME/.buildcontrib
  -L[ist]      - list all the foswiki extensions that could be installed by 
                 listing the repositories under the foswiki github account.
                 Takes an optional case insensitive filter parameter.
                 -L ldap would find all extensions containing ldap in their name.
                 Note: requires Net::GitHub::V3, any may require a github access token
  -N[ohooks]   - Disable linking of git hooks. Not for foswiki repositories!
  -c[opy]      - copy instead of linking %copyByDefault%
  -d[ebug]     - print an activity trace
  -e[nable]    - automatically enable installed plugins in LocalSite.cfg
  -f[orce]     - force an action to complete even if there are warnings
  -l[ink]      - create links %linkByDefault%
  -m[anual]    - do not automatically enable installed plugins in LocalSite.cfg
  -u[ninstall] - self explanatory (doesn't remove dirs)
  core         - install core (create and link derived objects)
  all          - install core + all extensions (big job)
  default      - install core + extensions listed in lib/MANIFEST
  developer    - core + default + key developer environment
  <module>...  - one or more extensions to install (by name or git URL)

The -L option uses the github API, and is subject to github rate limiting.
If you get "API rate limit exceeded" errors, you need to get a github access token
for higher limits.  Assign it to the ENV variable FOSWIKI_GITHUB_TOKEN. 
export FOSWIKI_GITHUB_TOKEN=the-hex-token-from-github
See https://help.github.com/articles/creating-an-access-token-for-command-line-use/

Examples:
  softlink and enable FirstPlugin and SomeContrib
      perl pseudo-install.pl -force -enable -link FirstPlugin SomeContrib

  Create a git-repo-per-extension checkout: start by cloning core,
      git clone git://github.com/foswiki/core.git
      cd core
      cd trunk/core
  Then, install extensions (missing modules automatically cloned & configured
      ./pseudo-install.pl developer
  Install & enable an extension from an abritrary git repo without enabling hooks
      ./pseudo-install.pl -e -N git@github.com:/me/MyPlugin.git
  Install an extension from a local file based git repo, without hooks
      ./pseudo-install.pl  -N file:///home/git/LocalDataContrib
  Install UnitTestContrib and include config values into LocalSite.cfg from
  lib/Foswiki/Contrib/UnitTestContrib/AutoBuildSelenium.cfg
      ./pseudo-install.pl -EAutoBuildSelenium UnitTestContrib

  * When using git clean, add the -x modifier to clean ignored files.  See [1]
  * Each module's root has a .gitignore maintained w/list of derived files [1]
  * [1] http://foswiki.org/Development/GitAndPseudoInstall
EOM
my %generated_files;
my $install;
my $basedir;
my $CAN_LINK;
my $force;
my $parentdir;
my $fetchedExtensionsPath;
my @error_log;
my %config;
my $do_genconfig;
my @extensions_path;
my %extensions_extra_config;
my $autoenable     = 0;
my $debug          = 0;
my $githooks       = 1;
my $installing     = 1;
my $autoconf       = 0;
my $listextensions = 0;
my $config_file    = $ENV{FOSWIKI_PSEUDOINSTALL_CONFIG};
my $github_token   = $ENV{FOSWIKI_GITHUB_TOKEN};
my $internal_gzip  = eval { require Compress::Zlib; 1; };
my $filter         = '';
my %arg_dispatch   = (
    '-E' => sub {
        my ($cfg)  = @_;
        my ($extn) = shift(@ARGV);

        push( @{ $extensions_extra_config{$extn} }, $cfg );
    },
    '-f' => sub { $force   = 1 },
    '-l' => sub { $install = \&just_link },
    '-c' => sub {
        $install  = \&copy_in;
        $CAN_LINK = 0;
    },
    '-u' => sub {
        $install    = \&uninstall;
        $installing = 0;
    },
    '-d' => sub {
        $debug = 1;
    },
    '-e' => sub {
        $autoenable = 1;
    },
    '-m' => sub {
        $autoenable = 0;
    },
    '-N' => sub {
        $githooks = 0;
    },
    '-A' => sub {
        $autoconf = 1;
    },
    '-C' => sub {
        $config_file = shift(@ARGV);
    },
    '-G' => sub {
        $do_genconfig = 1;
    },
    '-L' => sub {
        $listextensions = 1;
        $filter         = shift(@ARGV);
    }
);
my %default_config = (
    repos => [
        {
            type => 'git',
            url  => 'https://github.com/foswiki',
            bare => 1,
            note => <<'HERE'
This is the default Foswiki github repository.
HERE
        }
    ],
    extensions_path => [ '$basedir/twikiplugins', '.', '$parentdir' ],
    clone_dir       => '$parentdir'
);

sub init {
    no re 'taint';
    $FindBin::Bin =~ /(.*)/;    # core dir
    $basedir = $1;
    use re 'taint';
    $parentdir = File::Spec->catdir( $basedir, '..' );
    $fetchedExtensionsPath = $parentdir;
    my $n = 0;
    $n++ while ( -e "testtgt$n" || -e "testlink$n" );
    open( my $testfile, '>', "testtgt$n" )
      or die "$basedir is not writable: $!";
    print $testfile "";
    close $testfile;
    $CAN_LINK = eval {
        symlink( "testtgt$n", "testlink$n" );
        1;
    };
    if ($CAN_LINK) {
        $install = \&just_link;
    }
    else {
        $install = \&copy_in;
    }
    unlink( "testtgt$n", "testlink$n" );

    return;
}

sub init_config {
    if ( !$config_file ) {
        if ( $ENV{HOME} ) {
            $config_file = File::Spec->catfile( $ENV{HOME}, '.buildcontrib' );
        }
    }
    if ( $config_file && -f $config_file ) {
        my $buildconfig;

        $config_file = untaint($config_file);
        $buildconfig = do "$config_file";
        die "Malformed config: '$config_file'"
          unless ref($buildconfig) eq 'HASH';
        if ( exists $buildconfig->{'pseudo-install'} ) {
            die "Malformed config: '$config_file'"
              unless ref( $buildconfig->{'pseudo-install'} ) eq 'HASH';
            %config = %{ $buildconfig->{'pseudo-install'} };
        }
    }
    if ($do_genconfig) {
        genconfig();
    }
    if ( !scalar( keys %config ) ) {
        %config = %default_config;
    }
    if ( $config{extensions_path} ) {
        die "Malformed config: '$config_file'"
          unless ref( $config{extensions_path} ) eq 'ARRAY';
        @{ $config{extensions_path} } =
          map { expandConfigPathTokens($_) } @{ $config{extensions_path} };
    }
    if ( $config{clone_dir} ) {
        $config{clone_dir} = expandConfigPathTokens( $config{clone_dir} );
    }

    return;
}

sub init_extensions_path {
    my %paths;

    if ( $ENV{FOSWIKI_EXTENSIONS} ) {
        my @filtered = filterpaths( \%paths, $ENV{FOSWIKI_EXTENSIONS} );

        # Only put FOSWIKI_EXTENSIONS first in the search path if that dir is
        # not already in the search path
        if ( scalar(@filtered) ) {
            unshift( @extensions_path, @filtered );
        }
    }
    push( @extensions_path,
        filterpaths( \%paths, @{ $config{extensions_path} } ) );

    return;
}

sub genconfig {
    my $buildconfig;
    my $needforce;

    # Detect if we're about to clobber some stuff in the existsing buildconfig
    if ( -f $config_file ) {
        $buildconfig = do "$config_file";
        if ( exists $buildconfig->{'pseudo-install'} ) {
            foreach my $key ( keys %default_config ) {
                if ( exists $buildconfig->{'pseudo-install'}{$key} ) {
                    $needforce = 1;
                }
            }
        }
    }
    if ( $needforce && !$force ) {
        die <<"HERE";
Not writing a default pseudo-install config into '$config_file': already
contains a pseudo-install config, and -f (force) not specified.
HERE
    }
    elsif ( !-f $config_file || -w $config_file ) {
        foreach my $key ( keys %default_config ) {
            $buildconfig->{'pseudo-install'}{$key} = $default_config{$key};
        }
        $config_file = untaint($config_file);
        if ( open( my $fh, '>', $config_file ) ) {
            require Data::Dumper;
            print $fh Data::Dumper->Dump( [$buildconfig] );
            if ( close($fh) ) {
                print <<"HERE";
Successfully wrote a default 'pseudo-install' config into
'$config_file'
HERE
            }
        }
        else {
            die <<"HERE";
Failed to write a default pseudo-install config into
'$config_file': error opening for write
HERE
        }
    }
    else {
        die <<"HERE";
Failed to write a default pseudo-install config into
'$config_file': not writeable
HERE
    }

    return;
}

# Remove duplicates and missing dirs
sub filterpaths {
    my ( $map, @paths ) = @_;
    my @result;

    foreach my $p ( grep { -d $_ } @paths ) {
        if ( !exists $map->{$p} ) {
            $map->{$p} = 1;
            push( @result, $p );
        }
    }

    return @result;
}

sub expandConfigPathTokens {
    my ($path) = @_;

    $path =~ s/\$parentdir/$parentdir/g;
    $path =~ s/\$basedir/$basedir/g;

    return $path;
}

sub untaint {
    no re 'taint';
    $_[0] =~ /^(.*)$/;
    use re 'taint';

    return $1;
}

sub error {
    my @errors = @_;

    push @error_log, @errors;
    warn 'ERROR: ', @errors;

    return;
}

sub trace {

    warn "...", @_, "\n" if $debug;

    return;
}

sub usage {
    my $def           = '(default behaviour on this platform)';
    my $linkByDefault = $CAN_LINK ? $def : "";
    my $copyByDefault = $CAN_LINK ? "" : $def;

    $usagetext =~ s/%linkByDefault%/$linkByDefault/g;
    $usagetext =~ s/%copyByDefault%/$copyByDefault/g;
    print $usagetext;

    return;
}

sub findRelativeTo {
    my ( $startdir, $name ) = @_;
    my @path = File::Spec->splitdir($startdir);

    while ( scalar(@path) > 0 ) {
        my $found = File::Spec->catfile( @path, $name );
        return $found if -e $found;
        pop(@path);
    }

    return;
}

sub findModuleDir {
    my ($module) = @_;
    my $moduleDir;

    foreach my $dir (@extensions_path) {
        my $testDir = File::Spec->catdir( $dir, $module );

        if ( -d $testDir ) {
            $moduleDir = $testDir;
            last;
        }
    }

    return $moduleDir;
}

sub urlToModuleName {
    my ($url) = @_;

    $url =~ /^.*\/([^\.\/]+)(\.git)?\/?$/;

    return $1;
}

sub installModule {
    my ($module) = @_;

    # Assume that only URLs will have '.' or '/', never module names
    if ( $installing && $module =~ /[\/\.]/ ) {
        cloneModuleByURL( $config{clone_dir}, $module );
        $module = urlToModuleName($module);
    }

    return installModuleByName($module);
}

sub isContrib {
    my ($module) = @_;

    return $module =~ /(Contrib|Skin|AddOn|^core)$/;
}

sub installModuleByName {
    my $module = shift;
    my $subdir = 'Plugins';
    my $libDir = 'Foswiki';
    my $moduleDir;
    my $manifest;

    # If $ignoreBlock is true, will ignore blocking files (not complain
    # if a file it is trying to copy in / link already exists)
    my $ignoreBlock = 0;

    $module =~ s#/+$##;    #remove trailing slashes
    print "Processing $module\n";
    $subdir = 'Contrib' if isContrib($module);

    if ( $module eq 'core' ) {

        # Special install procedure for core, processes manifest
        # and checks for missing files
        $moduleDir   = '.';
        $ignoreBlock = 1;
    }
    else {
        $moduleDir = findModuleDir($module);
    }

    if ( $installing && !defined $moduleDir ) {
        $moduleDir = cloneModuleByName($module);
    }

    unless ( defined $moduleDir && -d $moduleDir ) {
        warn "--> Could not find $module\n";
        return;
    }
    $moduleDir = Cwd::realpath($moduleDir);
    $manifest  = findRelativeTo(
        File::Spec->catdir( $moduleDir, 'lib', 'Foswiki', $subdir, $module ),
        'MANIFEST' );
    unless ( $manifest && -e $manifest ) {
        $manifest = findRelativeTo(
            File::Spec->catdir( $moduleDir, 'lib', 'TWiki', $subdir, $module ),
            'MANIFEST'
        );
        $libDir = 'TWiki';
    }
    if ( $manifest && -e $manifest ) {
        installFromMANIFEST( $module, $moduleDir, $manifest, $ignoreBlock );
    }
    else {
        $libDir = undef;
        warn "---> No MANIFEST in $module"
          . ( $manifest ? "(at $manifest)" : '' ) . "\n";
    }
    update_githooks_dir( $moduleDir, $module ) if ($githooks);

    return $libDir;
}

sub ListGitExtensions {
    require Net::GitHub::V3;

    my %gh_opts;
    $gh_opts{version} = 3;
    $gh_opts{access_token} = $github_token if $github_token;

    my $gh = Net::GitHub::V3->new(%gh_opts);

    my $ghAccount = 'foswiki';
    my $ghrepos;
    my @rp;

    $ghrepos = $gh->repos;

    @rp = $ghrepos->list_org($ghAccount);

    while ( $gh->repos->has_next_page ) {
        push @rp, $gh->repos->next_page;
    }

    my @extensions;

    foreach my $r (@rp) {
        my $rname = $r->{'name'};
        next unless $rname =~ m/(Plugin|Contrib|AddOn|Skin)$/;
        if ($filter) {
            next unless $rname =~ m/$filter/i;
        }
        push @extensions, $rname;
    }

    print "Extensions available: \n\t"
      . join( "\n\t", sort(@extensions) ) . "\n\n";
}

sub do_commands {
    my ($commands) = @_;

    # print $commands . "\n";
    local $ENV{PATH} = untaint( $ENV{PATH} );

    return `$commands`;
}

sub cloneModuleByName {
    my ($module)  = @_;
    my $cloned    = 0;
    my $repoIndex = 0;
    my $moduleDir = File::Spec->catdir( $config{clone_dir}, $module );

    while ( !$cloned && ( $repoIndex < scalar( @{ $config{repos} } ) ) ) {
        if ( $config{repos}->[$repoIndex]->{type} eq 'git' ) {
            my $curUrl = do_commands(<<"HERE");
git config --get remote.origin.url
HERE

            my ( $repoPfx, $rest ) = split( /:/, $curUrl );

            # Prefix is either git@github.com, https or git

            my $url = $config{repos}->[$repoIndex]->{url} . "/$module";

            if ( $repoPfx eq 'git@github.com' ) {
                $url =~ s#(?:https|git)://github.com/#git\@github.com:#;
            }
            elsif ( $repoPfx eq 'https' ) {
                $url =~ s#^git:#https:#;
            }

            if ( $config{repos}->[$repoIndex]->{bare} ) {
                $url .= '.git';
            }
            cloneModuleByURL( $config{clone_dir}, $url );
            if ( -d $moduleDir ) {
                $cloned = 1;
                print "Cloned $module OK\n";
            }
            else {
                $repoIndex = $repoIndex + 1;
            }
        }
        else {
            $repoIndex = $repoIndex + 1;
        }
    }

    return $moduleDir;
}

sub cloneModuleByURL {
    my ( $target, $source ) = @_;

    return gitCloneFromURL( $target, $source );
}

sub gitCloneFromURL {
    my ( $target, $source ) = @_;
    my $command = "cd $target && git clone $source";
    my $moduleDir = File::Spec->catdir( $target, urlToModuleName($source) );

    if ( !-d $moduleDir ) {
        print "Trying clone from $source...\n";
        local $ENV{PATH} = untaint( $ENV{PATH} );
        trace `$command`;
    }
    else {
        print STDERR "$moduleDir already exists\n";
    }

    return;
}

sub installFromMANIFEST {
    my ( $module, $moduleDir, $manifest, $ignoreBlock, $nodeps ) = @_;

    trace "Using manifest from $manifest";

    open( my $df, '<', $manifest )
      or die "Cannot open manifest $manifest for reading: $!";
    my @files = (<$df>);
    close $df;

    my $depfile = $manifest;
    $depfile =~ s/MANIFEST/DEPENDENCIES/;
    if ( -f $depfile ) {
        $depfile =~ s/^$moduleDir\///;
        push @files, $depfile . " 0644 \n";
    }

    foreach my $file (@files) {
        chomp($file);
        if ( $file =~ /^!include\s+(\S+)\s*$/ ) {
            my $incfile = $1;
            trace
              "Found include MANIFEST $incfile, process $moduleDir/$incfile";
            if ( -f $incfile ) {
                installFromMANIFEST( $module, $moduleDir,
                    $moduleDir . '/' . $incfile,
                    $ignoreBlock, 1 );
                next;
            }
        }
        next unless $file =~ /^\w+/;
        $file =~ s/\s.*$//;
        next if -d File::Spec->catdir( $moduleDir, $file );
        $file = untaint($file);
        my ( undef, $dir ) = File::Spec->splitpath($file);
        $install->( $moduleDir, $dir, $file, $ignoreBlock );

        # Unlink zip generated by compression. This is inefficient, but
        # the alternative is comparing file dates, which is hard work.
        if ( -f File::Spec->catfile( $moduleDir, $file ) && $file =~ /\.gz$/ ) {
            unlink _cleanPath( File::Spec->catfile( $moduleDir, $file ) );
        }

        if ($installing) {

            # Special cases for derived objects created by compression and/or
            # zipping.
            my $found = -f File::Spec->catfile( $moduleDir, $file );

            unless ($found) {

                # Generate alternate version *in the $moduleDir*
                $found = generateAlternateVersion( $moduleDir, $dir, $file,
                    $CAN_LINK );
                if ($found) {
                    $install->( $moduleDir, $dir, $file, $ignoreBlock );
                }
            }
            unless ($found) {
                warn 'WARNING: Cannot find or generate source file for '
                  . File::Spec->catfile( $moduleDir, $file ) . "\n";
            }
        }
    }

    if ( -d File::Spec->catdir( $moduleDir, 'test', 'unit', $module ) ) {
        opendir( $df,
            File::Spec->catdir( $moduleDir, 'test', 'unit', $module ) );
        foreach my $f ( grep { /\.pm$/ } readdir($df) ) {
            $f = untaint($f);
            $install->(
                $moduleDir,
                File::Spec->catdir( 'test', 'unit', $module ),
                File::Spec->catfile( 'test', 'unit', $module, $f ),
                $ignoreBlock
            );
        }
        closedir $df;
    }

    # process dependencies, if we are installing
    if ( $installing && !$nodeps ) {
        my $deps = $manifest;
        $deps =~ s/MANIFEST/DEPENDENCIES/;
        if ( open( $df, '<', $deps ) ) {
            trace "read deps from $deps";
            my $skipnext = 0;
            foreach my $dep (<$df>) {
                chomp($dep);
                if ($skipnext) {
                    $skipnext = 0;
                    next;
                }
                next unless $dep =~ /^\w+/;

                # Evaluate the ONLYIF. It applies to the next dependency line.
                if ( $dep =~ /^ONLYIF\s+(.+)$/ ) {
                    my $cond = untaint($1);

                    # We may need to require to check if modules are
                    # already installed.
                    unshift( @INC, 'lib' );

                    # Hack to require a referenced Foswiki:: module.
                    # Required for $Foswiki::Plugins::VERSION type references
                    if ( $cond =~ /\$(Foswiki[\w:]*)::\w+/ ) {
                        my $p = $1;
                        unless (
                            do { local $SIG{__WARN__}; eval "require $p; 1" }
                          )
                        {
                            print STDERR
                              "require '$p' for ONLYIF $cond failed: $@\n";
                            $skipnext = 1;
                            next;
                        }
                    }
                    unless (
                        do { local $SIG{__WARN__}; eval $cond }
                      )
                    {
                        $skipnext = 1;
                        next;
                    }
                    next;
                }
                satisfyDependency( split( /\s*,\s*/, $dep ) );
            }
            close $df;
        }
        else {
            error "*** Could not open $deps\n";
        }
    }

    if ( $installing && $autoconf ) {

        # Read current LocalSite.cfg to see if the current module is enabled
        my $localSiteCfg =
          File::Spec->catfile( $basedir, 'lib', 'LocalSite.cfg' );
        open my $lsc, '<', $localSiteCfg
          or die "Cannot open $localSiteCfg for reading: $!";
        my $enabled = 0;
        my $spec;
        my $localConfiguration = '';
        while (<$lsc>) {

            # Can't $_ eq '1;' because /^1;$/ is less picky about newlines
            next if /^1;$/;
            $localConfiguration .= $_;
            if (m/^\$Foswiki::cfg\{Plugins\}\{$module\}\{(\S+)\}\s+=\s+(\S+);/)
            {
                if ( $1 eq 'Enabled' ) {
                    $enabled = $2;
                }
                elsif ( $1 eq 'Module' ) {
                    my $moduleName = $2;
                    $moduleName =~ s#'##g;
                    $spec =
                      File::Spec->catfile( $basedir, 'lib',
                        split( '::', $moduleName ),
                        'Config.spec' );
                }
            }
        }
        close $lsc;
        if ( !$spec && isContrib($module) ) {
            $spec = File::Spec->catfile( $basedir, 'lib', 'Foswiki', 'Contrib',
                $module, 'Config.spec' );
        }
        if ( ( $enabled || isContrib($module) ) && $spec && -f $spec ) {
            if ( open( my $pluginSpec, '<', $spec ) ) {
                $localConfiguration .= "# $module specific configuration\n";
                while (<$pluginSpec>) {
                    next if /^(?:1;|\s*|#.*)$/;
                    $localConfiguration .= $_;
                }
                close $pluginSpec;
                $localConfiguration .= "1;\n";
                if ( open( my $lsc, '>', $localSiteCfg ) ) {
                    print $lsc $localConfiguration;
                    close $lsc;
                    warn "Added ${module}'s Config.spec to $localSiteCfg\n";
                }
                else {
                    warn "Could not write new $localSiteCfg: $!\n";
                }
            }
            else {
                warn "Could not open spec file $spec for $module: $!\n";
            }
        }
    }

    return;
}

sub package_exists {
    my ($mod) = @_;
    local @INC = @INC;
    my @curdir = File::Spec->splitdir( File::Spec->curdir() );

    # Add ./lib to front of INC path
    unshift( @INC, File::Spec->catdir( @curdir, 'lib' ) );

    # Add ./lib/CPAN/lib to end of INC path
    push( @INC, File::Spec->catdir( @curdir, qw(lib CPAN lib) ) );
    no re 'taint';
    $mod =~ /^([\w:]+)$/;
    $mod = $1;
    use re 'taint';

    {
        local $SIG{__WARN__};
        return eval "require $mod; 1"
    }
}

sub satisfyDependency {
    my ( $mod, $cond, $type, $mess ) = @_;

    # First see if we can find it in the install or @INC path
    if ( package_exists($mod) ) {
        trace "$mod is already installed";
    }
    else {
        trace "$mod is not installed";

        # Not found, is it required?
        if ( $mess !~ /^required/i ) {
            warn "$mod is an optional dependency, but is not installed\n";
            return;
        }
        if ( $type eq 'perl' && $mod =~ /^Foswiki/ ) {
            error
"**** $mod is a required Foswiki dependency, but it is not installed\n";
        }
        else {
            error
              "**** $mod is a required dependency, but it is not installed\n";
        }
    }

    return;
}

sub linkOrCopy {
    my ( $moduleDir, $source, $target, $link ) = @_;
    my $srcfile = File::Spec->catfile( $moduleDir, $source );
    my $dstfile = File::Spec->catfile( $moduleDir, $target );

    trace '...' . ( $link ? 'link' : 'copy' ) . " $srcfile to $dstfile";
    if ($link) {
        $srcfile = _cleanPath($srcfile);
        $dstfile = _cleanPath($dstfile);
        symlink( $srcfile, $dstfile )
          or carp "Failed to link $srcfile as $dstfile: $!";
        print "Linked $source as $target\n";
        $generated_files{$basedir}{$target} = 1;
    }
    else {
        if ( -e $srcfile ) {
            File::Copy::copy( $srcfile, $target )
              || die "Couldn't install $target: $!";
        }
        print "Copied $source as $target\n";
    }
    $generated_files{$moduleDir}{$target} = 1;

    return;
}

# The source of a file listed in the MANIFEST was not found
# Try to find a source or alternate, using file naming rules.
# X.gz can be generated from X
# X.Y can be linked to any of
#    X.uncompressed.Y
#    X_src.Y
#    X.compressed.Y
#    X.min.Y
#    X.Y
# (preference in that order)
# $file is the file being looked for e.g. blah.js.gz
# return 1 if the file was able to be generated
sub generateAlternateVersion {
    my ( $moduleDir, $dir, $file, $link ) = @_;

    trace( File::Spec->catfile( $moduleDir, $file )
          . ' not found, trying to generate alternate' );

    if ( $file =~ /(.*)\.gz$/ ) {
        my $zource = $1;
        unless ( -f File::Spec->catfile( $moduleDir, $zource )
            || generateAlternateVersion( $moduleDir, $dir, $zource, $link ) )
        {
            # Failed
            return 0;
        }
        $zource =
          untaint( _cleanPath( File::Spec->catfile( $moduleDir, $zource ) ) );
        trace "...compressing $zource to create $file";
        if ($internal_gzip) {
            open( my $if, '<', $zource )
              or die "Failed to open $zource to zip: $!";
            local $/ = undef;
            my $text = <$if>;
            close($if);

            $text = Compress::Zlib::memGzip($text);

            my $dezt =
              untaint( _cleanPath( File::Spec->catfile( $moduleDir, $file ) ) );
            open( my $of, '>', $dezt )
              or die "Failed to open $dezt to write: $!";
            binmode $of;
            print $of $text;
            close($of);
        }
        else {

            # Try gzip as a backup, if Compress::Zlib is not available
            my $command = "gzip -c $file > $file.gz";
            local $ENV{PATH} = untaint( $ENV{PATH} );
            trace $command . ' -> ' . `$command`;
        }

        $generated_files{$moduleDir}{$file} = 1;
        return 1;
    }

    # otherwise, try and link to a matching .uncompressed, .min etc
    if ( $file =~ /^(.+?)(.uncompressed|_src|.min|.compressed|)(\.[^.]+)$/ ) {
        my ( $root, $mid, $ext ) = ( $1, $2 || '', $3 );
        foreach my $type ( grep { $_ ne $mid }
            ( '.uncompressed', '_src', '.min', '' ) )
        {
            if ( -f File::Spec->catfile( $moduleDir, "$root$type$ext" ) ) {
                linkOrCopy $moduleDir, "$root$type$ext", $file, $link;
                return 1;
            }
        }
    }

    return 0;
}

# See also: just_link
sub copy_in {
    my ( $moduleDir, $dir, $file, $ignoreBlock ) = @_;

    # For core manifest, ignore copy if target exists.
    return if -e $file && $ignoreBlock;
    File::Path::mkpath( _cleanPath($dir) );
    $generated_files{$moduleDir}{$dir} = 1;
    if ( -e File::Spec->catfile( $moduleDir, $file ) ) {
        File::Copy::copy( File::Spec->catfile( $moduleDir, $file ), $file )
          or die "Couldn't install $file: $!";
        print "Copied $file\n";
        $generated_files{$moduleDir}{$file} = 1;
    }

    return;
}

sub _cleanPath {
    my ( $path, $base ) = @_;

    # Convert relative paths to absolute
    if ( $path !~ /^\// ) {
        $path = "$base/$path" if $base;
        $path = File::Spec->rel2abs( $path, $basedir );
    }
    $path = File::Spec->canonpath($path);
    while ( $path =~ s#/[^/]+/\.\.## ) { }

    return untaint($path);
}

# Check that $path$c links to $moduleDir/$path$c
sub _checkLink {
    my ( $moduleDir, $path, $c ) = @_;
    my $expected;
    my $dest = _cleanPath( readlink( $path . $c ), $path );

    $dest =~ m#/([^/]*)$#;    # Remove slashes
    unless ( $1 eq $c ) {
        warn <<"HERE";
WARNING Confused by
     $path -> '$dest' doesn't point to the expected place
     (should be $moduleDir$path$c)
HERE
    }

    $expected = _cleanPath("$moduleDir/$path$c");
    if ( $dest ne $expected ) {
        warn <<"HERE";
WARNING Confused by
     $path$c -> '$dest' doesn't point to the expected place
     (should be $expected)
HERE
        return 0;
    }

    return 1;
}

# See also: copy_in
# Will try to link as high in the dir structure as it can
sub just_link {
    my ( $moduleDir, $dir, $file, $ignoreBlock ) = @_;
    my @components = _components($file);
    my $base       = "$moduleDir/";
    my $path       = '';

    foreach my $c (@components) {
        if ( -l $path . $c ) {
            _checkLink( $moduleDir, $path, $c ) unless $ignoreBlock;
            last;
        }
        elsif ( -d "$path$c" ) {
            $path .= "$c/";
        }
        elsif ( -e "$path$c" ) {
            error "$path$c is in the way\n" unless $ignoreBlock;
            last;
        }
        elsif (( $c eq 'TWiki' )
            || ( $c eq 'Plugins' && $path =~ m#/(Fosw|TW)iki/$# ) )
        {    # Special case
            my $relpath = $path . $c;
            my $abspath;

            $path .= "$c/";
            $abspath = _cleanPath($path);
            print "mkdir $abspath\n";
            if ( !mkdir($abspath) ) {
                warn "Could not mkdir $abspath: $!\n";
                last;
            }
            $generated_files{$basedir}{$relpath} = 1;
        }
        else {
            my $tgt = _cleanPath("$base$path$c");
            if ( -e $tgt ) {
                my $relpath  = $path . $c;
                my $linkpath = _cleanPath( $path . $c );

                die "Failed to link $linkpath to $tgt: $!"
                  unless symlink( $tgt, $linkpath );
                print "Linked $relpath\n";
                $generated_files{$basedir}{$relpath} = 1;
            }
            last;
        }
    }

    return;
}

sub _components {
    my ($file) = @_;
    my ( undef, $dirpart, $filepart ) = File::Spec->splitpath($file);

    $dirpart =~ s/[\/\\]$//g;
    return ( File::Spec->splitdir($dirpart), $filepart );
}

sub uninstall {
    my ( $moduleDir, $dir, $file ) = @_;
    my @components = _components($file);
    my $base       = $moduleDir;
    my $path       = '';

    # link handling that detects valid linking path components higher in the
    # tree so it unlinks the directories, and not the leaf files.
    # Special case when install created symlink to (un)?compressed version
    if ( -l File::Spec->catfile( $moduleDir, $file ) ) {
        unlink _cleanPath( File::Spec->catfile( $moduleDir, $file ) );
        print 'Unlinked symlink '
          . File::Spec->catfile( $moduleDir, $file ) . "\n";
        $generated_files{$basedir}{$file} = 0;
    }

    foreach my $c (@components) {
        if ( -l "$path$c" ) {
            return unless _checkLink( $moduleDir, $path, $c ) || $force;
            unlink _cleanPath("$path$c");
            print "Unlinked $path$c\n";
            $generated_files{$basedir}{ $path . $c } = 0;
            return;
        }
        else {
            $path .= "$c/";
        }
    }
    if ( -e $file ) {
        unlink _cleanPath($file);
        print "Removed $file\n";
        $generated_files{$basedir}{$file} = 0;
    }

    return;
}

sub Autoconf {
    my $foswikidir = $basedir;
    my $localSiteCfg =
      File::Spec->catfile( $foswikidir, 'lib', 'LocalSite.cfg' );

    if ( $force || ( !-e $localSiteCfg ) ) {
        unlink $localSiteCfg;    # So we can easily append
        local $ENV{PATH} = untaint( $ENV{PATH} );
        trace `tools/configure -save -noprompt`;
    }
    else {
        error "won't overwrite $localSiteCfg without -force\n\n";
    }

    return;
}

sub getLocalSite {
    my $cfg = '';

    print "Updating LocalSite.cfg\n";
    if ( open( my $lsc, '<', File::Spec->catfile( 'lib', 'LocalSite.cfg' ) ) ) {
        local $/;
        $cfg = <$lsc>;
        $cfg =~ s/\r//g;
        close $lsc;
    }

    return $cfg;
}

sub updateLocalSite {
    my ($cfg) = @_;

    if ( open( my $lsc, '>', File::Spec->catfile( 'lib', 'LocalSite.cfg' ) ) ) {
        print $lsc $cfg;
        close $lsc;
    }
    else {
        warn 'WARNING: failed to write'
          . File::Spec->catfile( 'lib', 'LocalSite.cfg' ) . "\n";
    }

    return;
}

sub enablePlugin {
    my ( $module, $installingModule, $libDir ) = @_;
    my $cfg     = getLocalSite();
    my $changed = 0;

    if ( $cfg =~
        s/\$Foswiki::cfg\{Plugins\}\{$module\}\{Enabled\}\s*=\s*(\d+)[\s;]+//sg
      )
    {
        $cfg =~ s/\$Foswiki::cfg\{Plugins\}\{$module\}\{Module\}\s*=.*?;\s*//sg;

        # Removed old setting
        $changed = 1;
    }
    if ($installingModule) {
        $cfg =
            "\$Foswiki::cfg{Plugins}{$module}{Enabled} = 1;\n"
          . "\$Foswiki::cfg{Plugins}{$module}{Module} = '${libDir}::Plugins::$module';\n"
          . $cfg;
        $changed = 1;
    }
    if ($changed) {
        updateLocalSite($cfg);
        print(
            ( $installingModule ? 'En' : 'Dis' ),
            "abled $module in LocalSite.cfg\n"
        );
    }

    return;
}

# Applies all the named <foo>.cfg's queued up for the $module to LocalSite.cfg
sub applyExtraConfig {
    my ( $module, $libDir ) = @_;
    my @configs = @{ $extensions_extra_config{$module} };
    local @INC = ( @INC, File::Spec->catfile( $basedir, 'lib' ) );
    my $LocalSitecfg = File::Spec->catfile( $basedir, 'lib', 'LocalSite.cfg' );
    die "'$LocalSitecfg' not exist" unless -f $LocalSitecfg;
    require Foswiki::Configure::Load;
    require Foswiki::Configure::Valuer;
    require Foswiki::Configure::Root;
    require Foswiki::Configure::FoswikiCfg;

    foreach my $conf (@configs) {
        my $what = ( $module =~ /Plugin$/ ) ? 'Plugins' : 'Contrib';
        my $cfg =
          File::Spec->catfile( $basedir, 'lib', 'Foswiki', $what, $module,
            "$conf.cfg" );
        die "'$cfg' not found" unless -f $cfg;
        no re 'taint';
        $cfg =~ /^(.*)$/;
        use re 'taint';
        do $1;
    }
    my %NewCfg = %Foswiki::cfg;
    %Foswiki::cfg = ();
    do $LocalSitecfg;
    my $valuer =
      Foswiki::Configure::Valuer->new( {}, { %Foswiki::cfg, %NewCfg } );
    my $root = Foswiki::Configure::Root->new();
    Foswiki::Configure::FoswikiCfg::_parse( $LocalSitecfg, $root, 1 );
    foreach my $conf (@configs) {
        my $what = ( $conf =~ /Plugin$/ ) ? 'Plugins' : 'Contrib';
        my $cfg =
          File::Spec->catfile( $basedir, 'lib', 'Foswiki', $what, $module,
            "$conf.cfg" );
        print "Parsing '$cfg' into LocalSite.cfg\n";
        Foswiki::Configure::FoswikiCfg::_parse( $cfg, $root, 1 );
    }
    my $saver = Foswiki::Configure::FoswikiCfg->new();
    $saver->{valuer}  = $valuer;
    $saver->{root}    = $root;
    $saver->{content} = '';
    updateLocalSite( $saver->_save() );

    return;
}

sub run {
    if ($autoconf) {
        Autoconf();
        exit 0 unless ( scalar(@ARGV) );
    }
    if ($listextensions) {
        ListGitExtensions();
        exit 0 unless ( scalar(@ARGV) );
    }
    unless ( $do_genconfig
        || scalar(@ARGV)
        || scalar( keys %extensions_extra_config ) )
    {
        usage();
        exit 1;
    }

    my @modules;
    for my $arg (@ARGV) {
        if ( $arg eq 'all' ) {
            push( @modules, 'core' );
            require JSON;
            my $page = 1;
            print "Getting list of Foswiki extensions\n";
            my $list = do_commands(
"curl --compressed -L -s http://foswiki.org/Extensions/JsonReport?skin=text"
            );
            $list = JSON::decode_json($list);
            push @modules, map { $_->{name} } @$list;
        }
        elsif ( $arg eq 'default' || $arg eq 'developer' ) {
            open my $f, '<', File::Spec->catfile( 'lib', 'MANIFEST' )
              or die "Could not open MANIFEST: $!";
            local $/ = "\n";
            @modules =
              map { /(\w+)$/; untaint($1) }
              grep { /^!include/ } <$f>;
            close $f;
            push @modules, 'BuildContrib', 'TestFixturePlugin',
              'UnitTestContrib'
              if $arg eq 'developer';
        }
        else {
            push @modules, untaint($arg);
        }

    }

    # *Never* uninstall 'core'
    @modules = grep { $_ ne 'core' } @modules unless $installing;

    print(
        ( $installing ? 'I' : 'Uni' ),
        'nstalling extensions: ',
        join( ', ', @modules ), "\n"
    );

    my @installedModules;
    my %unique_modules =
      ( map { $_ => 1 } @modules, keys %extensions_extra_config );
    @modules = sort keys %unique_modules;
    foreach my $module (@modules) {
        my $libDir = installModule($module);
        if ($libDir) {
            push( @installedModules, $module );
            if ( exists $extensions_extra_config{$module} && $installing ) {
                applyExtraConfig( $module, $libDir ) if $installing;
                enablePlugin( $module, $installing, $libDir )
                  if $module =~ /Plugin$/;
            }
            if ( ( !$installing || $autoenable ) && $module =~ /Plugin$/ ) {
                enablePlugin( $module, $installing, $libDir );
            }
        }
    }

    print ' '
      . (
        scalar(@installedModules)
        ? join( ', ', @installedModules )
        : 'No modules'
      )
      . ' '
      . ( $installing ? 'i' : 'uni' )
      . "nstalled\n";

    if ( scalar(@error_log) ) {
        print "\n----\nError log:\n" . join( '', @error_log );
    }

    return scalar @installedModules;
}

sub exec_opts {
    while ( scalar(@ARGV) && $ARGV[0] =~ /^(-.)(.*)/ ) {
        shift(@ARGV);
        if ( exists $arg_dispatch{$1} ) {
            $arg_dispatch{$1}->($2);
        }
        else {
            die "Don't know how to process '$1'";
        }
    }

    return;
}

# install the githooks.  If called with a module name  (ie.  "CommentPlugin")
# then we might be in a .git "superproject" structure,  so look for a .git/modules/$module/hooks
# directory.   otherwise a final call at the end will install into the primary .git/hooks location

sub update_githooks_dir {
    my ( $moduleDir, $module ) = @_;
    $module ||= '';
    use Cwd;

    # "just in case"  core becomes a separate repo.
    my @locations = qw(./.git);
    if ($module) {

        # Conventional and "submodule" repository locations
        push @locations, ( "../$module/.git", "../.git/modules/$module" );
    }
    else {
        # Root ('distro') repository location
        push @locations, ("../.git");
    }

    trace
"UPDATE_GITHOOKS_DIR:  Called with   ($moduleDir)   module:  ($module)  current dir: "
      . Cwd::cwd() . "\n";

    my $hooks_src =
      File::Spec->catdir( Cwd::cwd(), 'tools', 'develop', 'githooks' );

    # Check for .git directories,  and copy in hooks if needed
    foreach my $gitdir (@locations) {
        my $repo_hooks_tgt = File::Spec->catdir( $gitdir, 'hooks' );
        my $repo_target_dir =
          File::Spec->catdir( $moduleDir, $gitdir, 'hooks' );

        next unless ( -d $gitdir );

# Examine upstream for repo.
# SMELL: We would do better to somehow detect repos that are forks from foswiki repos
# So that when they submit git pull requests, the commit messages and tidy state is
# hopefully complete.
        my $curUrl;
        if ( -d $gitdir ) {
            $curUrl = do_commands(<<"HERE");
git --git-dir $gitdir config --list
HERE
            unless ( $curUrl =~
                m#^.*(.*?remote\..*\.url=.*?github\.com[:/]foswiki.*?)$#ms )
            {
                $curUrl =~ m/^.*(.*?remote\..*\.url=.*?)$/ms;
                print STDERR
"SKIPPING hooks for $gitdir,  Not a Foswiki project repository $1 \n";
                next;
            }
            $curUrl = $1;

        }

        print STDERR "Installing hooks for repo: "
          . _cleanPath($gitdir)
          . " Git origin URL: $curUrl \n";
        foreach my $hook (
            qw( applypatch-msg commit-msg post-commit post-update pre-applypatch pre-commit pre-rebase prepare-commit-msg post-receive update)
          )
        {
            next unless ( -f File::Spec->catfile( $hooks_src, $hook ) );
            trace "Installing hook: "
              . File::Spec->catfile( $hooks_src, $hook ) . "\n";

            trace "Checking for conventional repo:  $repo_target_dir\n";
            if ( -d $repo_target_dir ) {
                trace " Trying to unlink "
                  . _cleanPath( File::Spec->catfile( $repo_target_dir, $hook ) )
                  . "\n";
                unlink _cleanPath(
                    File::Spec->catfile( $repo_target_dir, $hook ) )
                  if ( -e File::Spec->catfile( $repo_target_dir, $hook ) );
                linkOrCopy '',
                  File::Spec->catfile( $hooks_src,       $hook ),
                  File::Spec->catfile( $repo_target_dir, $hook ),
                  $CAN_LINK;
            }
        }
    }
}

init();
exec_opts();
init_config();
init_extensions_path();
my $installed = run();

if ($installed) {
    update_githooks_dir($basedir) if ($githooks);

    my $geout = do_commands("perl $basedir/tools/git_excludes.pl");
    print "\n\n$geout\n";
}
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2016 Foswiki Contributors. Foswiki Contributors
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
