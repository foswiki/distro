#!/usr/bin/perl
use strict;

use File::Path;
use File::Copy;
use File::Spec;
use Cwd;
use Config;
use FindBin;

our $install;
our $basedir;
our @extensions_path;
our $CAN_LINK;
our $force;
our $parentdir;

BEGIN {
    $basedir   = $FindBin::Bin;    # core dir
    $parentdir = "$basedir/..";
    my $path = $ENV{FOSWIKI_EXTENSIONS} || '';
    $path .=
        $Config::Config{path_sep}
      . "$basedir/twikiplugins"
      . $Config::Config{path_sep} . '.'
      . $Config::Config{path_sep}
      . $parentdir;
    @extensions_path =
      grep( -d $_, split( /$Config::Config{path_sep}/, $path ) );

    my $n = 0;
    $n++ while ( -e "testtgt$n" || -e "testlink$n" );
    open( F, ">testtgt$n" ) || die "$basedir is not writeable: $!";
    print F "";
    close(F);
    eval {
        symlink( "testtgt$n", "testlink$n" );
        $CAN_LINK = 1;
    };
    unlink( "testtgt$n", "testlink$n" );
}

sub usage {
    my $def           = '(default behaviour on this platform)';
    my $linkByDefault = $CAN_LINK ? $def : "";
    my $copyByDefault = $CAN_LINK ? "" : $def;
    print <<EOM;
 Must be run from the root of a SVN checkout tree

 pseudo-install extensions in a SVN checkout tree

 This is done by a link or copy of the files listed in the MANIFEST
 for the extension. The installer script is *not* called.
 It should be almost equivalent to a tar zx of the packaged extension
 over the dev tree, except that the use of links enable a much
 more useable development environment.

 It picks up the extensions to be installed from a path defined in the
 environment variable FOSWIKI_EXTENSIONS, or if it is not defined,
 from the parent directory of the current checkout.

 Usage: pseudo-install.pl -[feA][l|c|u] [all|default|developer|<module>...]
    -f[orce] - force an action to complete even if there are warnings
    -e[nable] - automatically enable installed plugins in LocalSite.cfg
                (default)
    -m[anual] - no not automatically enable installed plugins in LocalSite.cfg
    -l[ink] - create links $linkByDefault
    -c[opy] - copy instead of linking $copyByDefault
    -u[ninstall] - self explanatory (doesn't remove dirs)
    all - install all extensions
    default - install extensions listed in lib/MANIFEST
    developer - default + key developer environment
    <module>... one or more extensions to install
    -[A]utoconf - make a simplistic LocalSite.cfg, using just the defaults in lib/Foswiki.spec

 Example:
    softlink and enable FirstPlugin and SomeContrib
        perl pseudo-install.pl -force -enable -link FirstPlugin SomeContrib
    
    
    check out a new trunk, create a default LocalSite.cfg, install and enable
    all the plugins for the default distribution (and then run the unit tests)
        svn co http://svn.foswiki.org/trunk
        cd trunk/core
        ./pseudo-install -A developer
        cd test/unit
        ../bin/TestRunner -clean FoswikiSuite.pm

EOM

}

sub findRelativeTo {
    my ( $startdir, $name ) = @_;

    my @path = split( /[\\\/]+/, $startdir );

    while ( scalar(@path) > 0 ) {
        my $found = join( '/', @path ) . '/' . $name;
        return $found if -e $found;
        pop(@path);
    }
    return undef;
}

sub installModule {
    my $module = shift;
    $module =~ s#/+$##; #remove trailing slash's
    print "Processing $module\n";
    my $subdir = 'Plugins';
    $subdir = 'Contrib' if $module =~ /(Contrib|Skin|AddOn)$/;
    $subdir = 'Tags'    if $module =~ /Tag$/;
    my $moduleDir;

    foreach my $dir (@extensions_path) {
        if ( -d "$dir/$module/" ) {
            $moduleDir = "$dir/$module";
            last;
        }
    }

    unless ( -d $moduleDir ) {
        print STDERR "--> Could not find $module\n";
        return;
    }

    my $manifest =
      findRelativeTo( "$moduleDir/lib/Foswiki/$subdir/$module/", 'MANIFEST' );
    my $libDir = "Foswiki";

    if ( !-e $manifest ) {
        $manifest =
          findRelativeTo( "$moduleDir/lib/TWiki/$subdir/$module/", 'MANIFEST' );
        $libDir = "TWiki";
    }

    if ( -e "$manifest" ) {
        open( F, "<$manifest" ) || die $!;
        foreach my $file (<F>) {
            chomp($file);
            next unless $file =~ /^\w+/;
            $file =~ s/\s.*$//;
            next if -d "$moduleDir/$file";
            my $dir = $file;
            $dir =~ s/\/[^\/]*$//;
            &$install( $moduleDir, $dir, $file );
        }
        close(F);
    }
    else {
        $libDir = undef;
        print STDERR "---> No MANIFEST in $module (at $manifest)\n";
    }
    if ( -d "$moduleDir/test/unit/$module" ) {
        opendir( D, "$moduleDir/test/unit/$module" );
        foreach my $f ( grep( /\.pm$/, readdir(D) ) ) {
            &$install( $moduleDir, "test/unit/$module",
                "test/unit/$module/$f" );
        }
        closedir(D);
    }
    return $libDir;
}

sub copy_in {
    my ( $moduleDir, $dir, $file ) = @_;
    File::Path::mkpath($dir);
    if( -e "$moduleDir/$file" ) {
        File::Copy::copy( "$moduleDir/$file", $file )
        || die "Couldn't install $file: $!";
    }
    print "Copied $file\n";
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
    return $path;
}

# Check that $path$c links to $moduleDir/$path$c
sub _checkLink {
    my ( $moduleDir, $path, $c ) = @_;

    my $dest = _cleanPath( readlink( $path . $c ), $path );
    $dest =~ m#/([^/]*)$#;
    unless ( $1 eq $c ) {
        print STDERR <<HERE;
WARNING Confused by
     $path -> '$dest' doesn't point to the expected place
     (should be $moduleDir$path$c)
HERE
    }

    my $expected = _cleanPath("$moduleDir/$path$c");
    if ( $dest ne $expected ) {
        print STDERR <<HERE;
WARNING Confused by
     $path$c -> '$dest' doesn't point to the expected place
     (should be $expected)
HERE
        return 0;
    }
    return 1;
}

# Will try to link as high in the dir structure as it can
sub just_link {
    my ( $moduleDir, $dir, $file ) = @_;

    my $base       = "$moduleDir/";
    my @components = split( /\/+/, $file );
    my $path       = '';
    foreach my $c (@components) {
        if ( -l $path . $c ) {
            _checkLink( $moduleDir, $path, $c );

            #print STDERR "$path$c already linked\n";
            last;
        }
        elsif ( -d "$path$c" ) {
            $path .= "$c/";
        }
        elsif ( -e "$path$c" ) {
            print STDERR "ERROR $path$c is in the way\n";
            last;
        }
        elsif (( $c eq 'TWiki' )
            or ( $c eq 'Plugins' && $path =~ m#/(Fosw|TW)iki/$# ) )
        {

            # Special case
            $path .= "$c/";
            print STDERR "mkdir $path\n";
            if ( !mkdir( _cleanPath($path) ) ) {
                print STDERR "Could not mkdir $path: $!\n";
                last;
            }
        }
        else {
            my $tgt = _cleanPath("$base$path$c");
            if ( -e $tgt ) {
                die "Failed to link $path$c to $tgt: $!"
                  unless symlink( $tgt, _cleanPath( $path . $c ) );
            }
            else {
                print STDERR "WARNING: no such file $tgt\n";
            }
            print "Linked $path$c\n";
            last;
        }
    }
}

sub uninstall {
    my ( $moduleDir, $dir, $file ) = @_;

    # link handling that detects valid linking path components higher in the
    # tree so it unlinks the directories, and not the leaf files.
    my @components = split( /\/+/, $file );
    my $base       = $moduleDir;
    my $path       = '';
    foreach my $c (@components) {
        if ( -l "$path$c" ) {
            return unless _checkLink( $moduleDir, $path, $c ) || $force;
            unlink "$path$c";
            print "Unlinked $path$c\n";
            return;
        }
        else {
            $path .= "$c/";
        }
    }
    if ( -e $file ) {
        unlink $file;
        print "Removed $file\n";
    }
}

sub Autoconf {
    my ( $moduleDir, $dir, $file ) = @_;

    my $foswikidir   = $basedir;
    my $localSiteCfg = $foswikidir . '/lib/LocalSite.cfg';
    if ( $force || ( !-e $localSiteCfg ) ) {
        my $grep = 'grep';
        $grep = 'find' if ($^O eq 'MSWin32');   #let windows play too
            my $localsite = `$grep "Foswiki::cfg" $foswikidir/lib/Foswiki.spec`;
            if ($^O eq 'MSWin32') {
            #oh wow, windows find is retarded
            $localsite =~ s|^(-------.*)$||m;
            #prefer non-grep SEARCH
            $localsite =~ s|^(.*)SearchAlgorithms::Forking(.*)$|$1SearchAlgorithms::PurePerl$2|m;
            #RscLite
            $localsite =~ s|^(.*)RcsWrap(.*)$|$1RcsLite$2|m;
        }

        $localsite =~ s|/home/httpd/foswiki|$foswikidir|g;

        # single # seems to denote an important param that needs to be set
        $localsite =~ s|# \$Foswiki|\$Foswiki|g;

        if ( open( LS, '>', $localSiteCfg ) ) {
            print LS $localsite;
            close(LS);
            print STDERR "wrote simple config to $localSiteCfg\n\n";
        }
        else {
            print STDERR "ERROR: failed to write to $localSiteCfg\n\n";
        }
    }
    else {
        print "ERROR: won't overwrite $localSiteCfg without -force\n\n";
    }
}

sub enablePlugin {
    my ( $module, $installing, $libDir ) = @_;
    my $cfg = '';
    print "Updating LocalSite.cfg\n";
    if ( open( F, "<lib/LocalSite.cfg" ) ) {
        local $/;
        $cfg = <F>;
        $cfg =~ s/\r//g;
    }
    my $changed = 0;
    if ( $cfg =~
        s/\$Foswiki::cfg{Plugins}{$module}{Enabled}\s*=\s*(\d+)[\s;]+//sg )
    {
        $cfg =~ s/\$Foswiki::cfg{Plugins}{$module}{Module}\s*=.*?;\s*//sg;

        # Removed old setting
        $changed = 1;
    }
    if ($installing) {
        $cfg =
            "\$Foswiki::cfg{Plugins}{$module}{Enabled} = 1;\n"
          . "\$Foswiki::cfg{Plugins}{$module}{Module} = '${libDir}::Plugins::$module';\n"
          . $cfg;
        $changed = 1;
    }

    if ($changed) {
        if ( open( F, ">lib/LocalSite.cfg" ) ) {
            print F $cfg;
            close(F);
            print(
                ( $installing ? 'En' : 'Dis' ),
                "abled $module in LocalSite.cfg\n"
            );
        }
        else {
            print STDERR "WARNING: failed to write lib/LocalSite.cfg\n";
        }
    }
}

my $autoenable = 0;
my $installing = 1;
my $autoconf   = 0;
$install = $CAN_LINK ? \&just_link : \&copy_in;

while ( scalar(@ARGV) && $ARGV[0] =~ /^-/ ) {
    my $arg = shift(@ARGV);
    if ( $arg eq '-force' ) {
        $force = 1;
    }
    elsif ( $arg =~ /^-l/ ) {
        $install = \&just_link;
    }
    elsif ( $arg =~ /^-c/ ) {
        $install = \&copy_in;
    }
    elsif ( $arg =~ /^-u/ ) {
        $install    = \&uninstall;
        $installing = 0;
    }
    elsif ( $arg =~ /^-e/ ) {
        $autoenable = 1;
    }
    elsif ( $arg =~ /^-m/ ) {
        $autoenable = 0;
    }
    elsif ( $arg =~ /^-A/ ) {
        $autoconf = 1;
    }
}

if ($autoconf) {
    Autoconf();
    exit 0 unless ( scalar(@ARGV) );
}

unless ( scalar(@ARGV) ) {
    usage();
    exit 1;
}

my @modules;
for my $arg ( @ARGV ) {
	if ( $arg eq "all" ) {
	    foreach my $dir (@extensions_path) {
    		opendir D, $dir or next;
	    	push @modules,
		      grep { /(?:Tag|Plugin|Contrib|Skin|AddOn)$/ && -d "$dir/$_" } readdir D;
            closedir D;
        }
    }
    elsif ( $arg eq 'default' || $arg eq 'developer' ) {
        open F, "<", "lib/MANIFEST" or die "Could not open MANIFEST: $!";
        local $/ = "\n";
        @modules =
            map { /(\w+)$/; $1 }
            grep { /^!include/ } <F>;
        close F;
        push @modules, 'BuildContrib', 'TestFixturePlugin', 'UnitTestContrib'
            if $arg eq 'developer';
    }
    else {
        push @modules, $arg;
    }
}

print(
    ( $installing ? 'I' : 'Uni' ),
    "nstalling extensions: ",
    join( ", ", @modules ), "\n"
);

foreach my $module (@modules) {
    my $libDir = installModule($module);
    if ( ( !$installing || $autoenable ) && $libDir && $module =~ /Plugin$/ ) {
        enablePlugin( $module, $installing, $libDir );
    }
}

print join( ", ", @modules ), ' ', ( $installing ? 'i' : 'uni' ), "nstalled\n";
