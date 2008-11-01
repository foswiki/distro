#!/usr/bin/perl -w
# $Id: install-cpan.pl 13664 2007-05-08 12:58:03Z WillNorris $
# Copyright 2004,2005 Will Norris.  All Rights Reserved.
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
sub mychomp { chomp $_[0]; $_[0] }

my $dirMirror = "file:$FindBin::Bin/MIRROR/MINICPAN/";
my $optsConfig = {
#
    baselibdir => $FindBin::Bin . "/../cgi-bin/lib/CPAN",
# SMELL: change into list   
    mirror => -d $dirMirror && $dirMirror || 'http://cpan.org',
#
    config => "~/.cpan/CPAN/MyConfig.pm",
#
    verbose => 0,
    debug => 0,
    help => 0,
    man => 0,
};

GetOptions( $optsConfig,
	    'baselibdir=s', 'mirror=s', 'config=s',
	    'force|f',
# miscellaneous/generic options
	    'help', 'man', 'debug', 'verbose|v',
	    );
pod2usage( 1 ) if $optsConfig->{help};
pod2usage({ -exitval => 1, -verbose => 2 }) if $optsConfig->{man};
print STDERR Dumper( $optsConfig ) if $optsConfig->{debug};

# fix up relative paths
foreach my $path qw( baselibdir mirror config )
{
    # expand tildes in paths (from Perl Cookbook: 7.3. Expanding Tildes in Filenames)
    $optsConfig->{$path} =~ s{ ^ ~ ( [^/]* ) }
    { $1 
	  ? (getpwnam($1))[7]
	  : ( $ENV{HOME} || $ENV{LOGDIR} || (getpwuid($>))[7] )
    }ex;

    $optsConfig->{$path} = File::Spec->rel2abs( $optsConfig->{$path} ) 
	unless $optsConfig->{$path} =~ /^[^:]{2,}:/;
    if ( $path eq 'mirror' )
    {
	# use file: unless some transport (eg, http:, ftp:, etc.) has already been specified
	$optsConfig->{$path} = 'file:' . $optsConfig->{$path} unless $optsConfig->{$path} =~ /^[^:]{2,}:/;
    }
}

print STDERR Dumper( $optsConfig ) if $optsConfig->{debug};

my @localLibs = ( "$optsConfig->{baselibdir}/lib", "$optsConfig->{baselibdir}/lib/arch" );
unshift @INC, @localLibs;
$ENV{PERL5LIB} = join( ':', @localLibs );
print STDERR Dumper( \@INC ) if $optsConfig->{debug};

################################################################################

-d $optsConfig->{baselibdir} or mkpath $optsConfig->{baselibdir};

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
    dir => $optsConfig->{baselibdir},
    config => {
	'HTML::Parser' => [ qw( no ) ],
	'XML::SAX' => [ qw( Y ) ],
	'Data::UUID' => [ qw( /var/tmp 0007 ) ],
#?	'GD' => [ qw( /usr/local/lib y y y ) ],
    },
    # TODO: update to use same output as =cpan/calc-twiki-deps.pl=
    modules => [ @ARGV ],
});
# Image::LibRSVG

# explicity call cleanup code (puts back MyConfig.pm)
$SIG{INT}();
exit 0;

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

install-cpan.pl - ...

=head1 SYNOPSIS

install-cpan.pl [options] [-baselibdir] [-mirror]

Copyright 2004, 2005 Will Norris.  All Rights Reserved.

  Options:
   -baselibdir         where to install the CPAN modules
   -mirror             location of the (mini) CPAN mirror
   -config             filename (~/.cpan/CPAN/MyConfig.pm)
   -verbose
   -debug
   -help               this documentation
   -man                full docs

=head1 OPTIONS

=over 8

=item B<-baselibdir>

=item B<-mirror>

=item B<-config>

=back

=head1 DESCRIPTION

B<install-cpan.pl> will ...

=head2 SEE ALSO

        http://twiki.org/cgi-bin/view/Codev/...

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
  'makepl_arg' => q[PREFIX=/Users/twiki/Sites/cgi-bin/lib/CPAN/],
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
