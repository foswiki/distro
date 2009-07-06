#!/usr/bin/perl -w
# $Id: install-cpan.pl 13664 2007-05-08 12:58:03Z WillNorris $
# Copyright 2004,2005,2009 Will Norris.  All Rights Reserved.
# License: GPL
################################################################################

use strict;
use Data::Dumper qw( Dumper );
++$|;
#open(STDERR,'>&STDOUT'); # redirect error to browser
use CPAN;
use File::Path qw( mkpath rmtree );
use File::Spec qw( rel2abs );
use File::Basename qw( dirname );
use Getopt::Long;
use FindBin;
use Config;
use Pod::Usage;
use Cwd qw( cwd );

my $dirMirror = "$FindBin::Bin/MIRROR/MINICPAN/";
my $optsConfig = {
#
    installdir => $FindBin::Bin . "/../cgi-bin/lib/CPAN",
# SMELL: change into list   
    mirror => -d $dirMirror && "file:$dirMirror" || 'http://cpan.org',
#
    config => "~/.cpan/CPAN/MyConfig.pm",
#
    status => 0,
    verbose => 0,
    debug => 0,
    help => 0,
    man => 0,
};

GetOptions( $optsConfig,
	    'installdir=s', 'mirror=s', 'config=s',
	    'force|f',
	    'status',
# miscellaneous/generic options
	    'help', 'man', 'debug', 'verbose|v',
	    );
pod2usage( 1 ) if $optsConfig->{help};
pod2usage({ -exitval => 1, -verbose => 2 }) if $optsConfig->{man};
print STDERR Dumper( $optsConfig ) if $optsConfig->{debug};

# fix up relative paths
foreach my $path qw( installdir mirror config ) {
    $optsConfig->{$path} = absolutePath( $optsConfig->{$path} );

    if ( $path eq 'mirror' ) {
	# use file: unless some transport (eg, http:, ftp:, etc.) has already been specified
	$optsConfig->{$path} = 'file:' . $optsConfig->{$path} unless $optsConfig->{$path} =~ /^[^:]{2,}:/;
    }
}

my @localLibs = ( "$optsConfig->{installdir}/lib", "$optsConfig->{installdir}/lib/arch" );
unshift @INC, @localLibs;
$ENV{PERL5LIB} = join( ':', @localLibs );
print STDERR Dumper( \@INC ) if $optsConfig->{debug};

if ( $optsConfig->{status} ) {
    print Dumper( $optsConfig );
}
#print STDERR Dumper( $optsConfig ) if $optsConfig->{debug};

################################################################################

-d $optsConfig->{installdir} or mkpath $optsConfig->{installdir};

# eg
#installLocalModules({
#    dir => $cpan,
#    config => {
#	'XML::SAX' => [ ( 'Do you want XML::SAX to alter ParserDetails.ini? [Y]' => 'Y' ) ],
#(or)	'XML::SAX' => [ ( 'Do you want XML::SAX to alter ParserDetails.ini?' => 'Y' ) ],
#(or)	'XML::SAX' => [ ( qr/^Do you want XML::SAX to alter ParserDetails.ini\?/ => 'Y' ) ],
#    },
#    modules => [ qw( XML::SAX ) ],
#});

installLocalModules({
    dir => $optsConfig->{installdir},
    config => {
	'HTML::Parser' => [ qw( no ) ],
	'XML::SAX' => [ qw( Y ) ],
	'Data::UUID' => [ qw( /var/tmp 0007 ) ],
#?	'GD' => [ qw( /usr/local/lib y y y ) ],
    },
    # TODO: update to use same output as =cpan/calc-foswiki-deps.pl=
    modules => [ @ARGV ],
});
# Image::LibRSVG

# explicity call cleanup code (puts back MyConfig.pm)
$SIG{INT}();
exit 0;

################################################################################

sub absolutePath {
    my $filename = shift;

    # expand tildes in paths (from Perl Cookbook: 7.3. Expanding Tildes in Filenames)
    $filename =~ s{ ^ ~ ( [^/]* ) }
    { $1 
	  ? (getpwnam($1))[7]
	  : ( $ENV{HOME} || $ENV{LOGDIR} || (getpwuid($>))[7] )
    }ex;

    # 
    $filename = File::Spec->rel2abs( $filename ) 
	unless $filename=~ /^[^:]{2,}:/;

    return $filename;
}

################################################################################
################################################################################

sub installLocalModules
{
    my $parm = shift;
    my $cpan = $parm->{dir};

    createMyConfigDotPm({ cpan => $cpan, config => $optsConfig->{config} });

    my @modules = @{$parm->{modules}};
    print "Installing the following modules: ", Dumper( \@modules ) if $optsConfig->{debug};
    foreach my $module ( @modules )
    {
	print "Installing $module\n" if $optsConfig->{verbose};

	my $obj = CPAN::Shell->expand( Module => $module ) or warn qq{can't find CPAN module "$module" (is it misspelled?)\n};
	next unless $obj;
	$obj->force;
	$obj->install; # or warn "Error installing $module\n"; 
print STDERR Dumper( $obj );
    }

#    print Dumper( $CPAN::Config );
}

################################################################################

sub createMyConfigDotPm
{
    my $parm = shift;
    my $cpan = $parm->{cpan} or die "no cpan directory?";

    my $cpanConfig = $parm->{config} or die "no config file specified?";

    # save the existing config file
    # install a sig handler to restore it
    if ( -e $cpanConfig )
    {
	open( CONFIG, "<$cpanConfig" ) or die $!;
	local $/ = undef;
	my $OLD_CONFIG = <CONFIG>;
	close( CONFIG );

	$SIG{INT} = sub {
	    open( CONFIG, ">$cpanConfig" ) or die $!;
	    print CONFIG $OLD_CONFIG;
	    close( CONFIG );
	};
    }

    -d dirname( $cpanConfig ) or mkpath( dirname( $cpanConfig ) );

    open( FH, ">$cpanConfig" ) or die "$!: Can't create $cpanConfig";
    $CPAN::Config = {
	'build_cache' => q[0],
	'build_dir' => "$cpan/.cpan/build",
	'cache_metadata' => q[1],
	'cpan_home' => "$cpan/.cpan",
	'ftp' => q[/bin/ftp],
	'ftp_proxy' => q[],
	'getcwd' => q[cwd],
	'gpg' => q[],
	'gzip' => q[/bin/gzip],
	'histfile' => "$cpan/.cpan/histfile",
	'histsize' => q[0],
	'http_proxy' => q[],
	'inactivity_timeout' => q[0],
	'index_expire' => q[1],
	'inhibit_startup_message' => q[1],
	'keep_source_where' => "$cpan/.cpan/sources",
	'lynx' => q[],
	'make' => q[/usr/bin/make],
	'make_arg' => "-I$cpan/",
	'make_install_arg' => "-I$cpan/lib/",
	'makepl_arg' => "install_base=$cpan LIB=$cpan/lib INSTALLPRIVLIB=$cpan/lib INSTALLARCHLIB=$cpan/lib/arch INSTALLSITEARCH=$cpan/lib/arch INSTALLSITELIB=$cpan/lib INSTALLSCRIPT=$cpan/bin INSTALLBIN=$cpan/bin INSTALLSITEBIN=$cpan/bin INSTALLMAN1DIR=$cpan/man/man1 INSTALLSITEMAN1DIR=$cpan/man/man1 INSTALLMAN3DIR=$cpan/man/man3 INSTALLSITEMAN3DIR=$cpan/man/man3",
	'ncftp' => q[],
	'ncftpget' => q[],
	'no_proxy' => q[],
	'pager' => q[],
	'prerequisites_policy' => q[follow],
	'scan_cache' => q[atstart],
	'shell' => q[/bin/bash],
	'tar' => q[/bin/tar],
	'term_is_latin' => q[1],
	'unzip' => q[/usr/bin/unzip],
	'wget' => q[/usr/bin/wget],
    };
    print FH "\$CPAN::Config = {\n";
    foreach my $key ( sort keys %$CPAN::Config )
    {
	print FH qq{\t'$key' => q[$CPAN::Config->{$key}],\n};
    }
    print FH qq{\t'urllist' => [ q[$optsConfig->{mirror}] ],\n};
    print FH "};\n",
    "1;\n",
    "__END__\n";
    close FH;
}

################################################################################
################################################################################

__DATA__
=head1 NAME

install-cpan.pl - install local version of CPAN modules

=head1 SYNOPSIS

install-cpan.pl [options] [-installdir] [-mirror]

Copyright 2004, 2005, 2009 Will Norris.  All Rights Reserved.

  Options:
   -installdir         where to install the CPAN modules and documentation
   -mirror             location of the (mini) CPAN mirror [http://cpan.org]
   -config             specify CPAN configuration [~/.cpan/CPAN/MyConfig.pm]
   -status             show configuration
   -verbose
   -debug
   -help               this documentation
   -man                full docs

=head1 OPTIONS

=over 8

=item B<-installdir>

=item B<-mirror>

=item B<-config>

=item B<-status>

=back

=head1 DESCRIPTION

B<install-cpan.pl> is designed to easily install CPAN modules and their accompanying
documentation and support files to a local (not system-wide) location that you specify.

You don't need to configure CPAN installation manually nor will this script clobber any existing CPAN =MyConfig.pm=

Note that the =installdir= is the root of the locally-installed CPAN libraries *and* documentation.
Directories such as =lib= and =man= (and sometimes =bin=) will be created below =installdir=.
This means that when you specificy this additional library path, you have to specify the base directory *plus* =/lib=.

(There might also be library files installed in the computer architecture-specific directory =arch=)

Examples:

export PERL5LIB=~/lib/CPAN/lib/:~/lib/CPAN/lib/arch

use lib qw( /path/to/foswiki/lib/CPAN/lib /path/to/foswiki/lib/CPAN/lib/arch );



=head2 EXAMPLES

This was determined through time-consuming incremental installation attempts:

perl install-cpan.pl --installdir=~/lib/CPAN/ Scalar::Util Test::Exception Params::Util Sub::Install Sub::Exporter Data::OptList Sub::Uplevel Test::Exception Scope::Guard Devel::GlobalDestruction Algorithm::C3 Class::C3 MRO::Compat Class::MOP ExtUtils::MakeMaker Sub::Exporter Sub::Name Data::OptList Test::More Task::Weaken Moose MooseX::MultiInitArg Variable::Magic B::Hooks::EndOfScope namespace::clean namespace::autoclean Digest::HMAC_SHA1 Net::OAuth Net::Twitter


Whereas this will do all of the magic for you:

perl install-cpan.pl --installdir=~/lib/CPAN `perl calc-cpan-deps.pl Net::Twitter`


=head2 CAVEATS

*PREFER YOUR PACAKGE MANAGER!*  Whether it be apt-get, yum, ports, or anything else.  

the =calc-cpan-deps.pl= script includes *all* CPAN module dependencies and as such, some of the lower-level library files will actually cause a perl upgrade itself!  Use its output with cautioin.


=head2 SEE ALSO

        http://foswiki.org/Extensions/CpanContrib

=cut

__END__
################################################################################
[~/.cpan/CPAN/MyConfig.pm]:

$CPAN::Config = {
  'cache_metadata' => q[1],
  'ftp_proxy' => q[],
  'http_proxy' => q[],
  'make_arg' => q[],
  'make_install_arg' => q[],
  'makepl_arg' => q[PREFIX=/Users/foswiki/Sites/bin/lib/CPAN/],
  'no_proxy' => q[],
  'pager' => q[/usr/bin/less],
  'prerequisites_policy' => q[follow],
  'scan_cache' => q[atstart],
  'shell' => q[/bin/bash],
  'term_is_latin' => q[1],
};
1;
__END__
    $VAR1 = bless( {
                 'ID' => 'Carp::Assert',
                 'RO' => {
                           'userid' => 'YVES',
                           'stats' => 'd',
                           'stati' => 'f',
                           'description' => 'Stating the obvious to let the computer know',
                           'CPAN_VERSION' => '0.20',
                           'chapterid' => '3',
                           'CPAN_FILE' => 'M/MS/MSCHWERN/Carp-Assert-0.20.tar.gz',
                           'CPAN_USERID' => 'MSCHWERN',
                           'statd' => 'a',
                           'statl' => 'p',
                           'statp' => 'p'
			   }
	     }, 'CPAN::Module' );


---- Unsatisfied dependencies detected during [C/CM/CMOORE/Archive-Any-0.093.tar.gz] -----
    MIME::Types
    Test::Warn
    Module::Find
    File::MMagic
Running make test
  Delayed until after prerequisites
Running make install
  Delayed until after prerequisites
    $VAR1 = bless( {
                 'ID' => 'Archive::Any',
                 'RO' => {
                           'CPAN_FILE' => 'C/CM/CMOORE/Archive-Any-0.093.tar.gz',
                           'CPAN_USERID' => 'CMOORE',
                           'CPAN_VERSION' => '0.093'
			   }
	     }, 'CPAN::Module' );

(success:)
$VAR1 = bless( {
                 'ID' => 'Class::Data::Inheritable',
                 'RO' => {
                           'CPAN_FILE' => 'T/TM/TMTM/Class-Data-Inheritable-0.06.tar.gz',
                           'CPAN_USERID' => 'TMTM',
                           'CPAN_VERSION' => '0.06'
			   }
	     }, 'CPAN::Module' );

(also success:)
    $VAR1 = bless( {
                 'ID' => 'Module::Build',
                 'RO' => {
                           'userid' => 'KWILLIAMS',
                           'stats' => 'd',
                           'stati' => 'O',
                           'description' => 'Build, test, and install Perl modules',
                           'CPAN_VERSION' => '0.2808',
                           'chapterid' => '2',
                           'CPAN_FILE' => 'K/KW/KWILLIAMS/Module-Build-0.2808.tar.gz',
                           'CPAN_USERID' => 'KWILLIAMS',
                           'statd' => 'b',
                           'statl' => 'p',
                           'statp' => 'p'
			   }
	     }, 'CPAN::Module' );
