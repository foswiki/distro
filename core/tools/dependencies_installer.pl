#!/usr/bin/perl -w
# See bottom of file for default license and copyright information

# Check which Foswiki Perl modules are available and offer installation

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;

# Locations of the DEPENDENCIES files
my $dep_core_path = "../lib/DEPENDENCIES";
my $dep_ext_dir   = "../working/configure/pkgdata";
my $dep_tools_dir = ".";

# Configuration for Debian packages
#
# Hash holding exact mappings between CPAN module name and Debian package name
# We are using aptitude further down which resolves dependencies on its own
my %deb_install_direct_cpanmod = (
    'Algorithm::Diff'           => 'libalgorithm-diff-perl',
    'Apache::Htpasswd'          => 'libapache-htpasswd-perl',
    'Apache2::Request'          => 'libapache2-request-perl',
    'Archive::Tar'              => 'libarchive-tar-perl',
    'Archive::Zip'              => 'libarchive-zip-perl',
    'Authen::SASL'              => 'libauthen-sasl-perl',
    'Archive::Tar'              => 'libarchive-tar-perl',
    'Archive::Zip'              => 'libarchive-zip-perl',
    'BerkeleyDB'                => 'libberkeleydb-perl',
    'CGI'                       => 'libcgi-pm-perl',
    'CGI::Fast'                 => 'libcgi-fast-perl',
    'CGI::Session'              => 'libcgi-session-perl',
    'Class::MakeMethods'        => 'libclass-makemethods-perl',
    'Clone'                     => 'libclone-perl',
    'Config::JSON'              => 'libconfig-json-perl',
    'Date::Calc'                => 'libdate-calc-perl',
    'Date::Manip'               => 'libdate-manip-perl',
    'DateTime::Format::ICal'    => 'libdatetime-format-ical-perl',
    'DB_File'                   => 'libdb-file-lock-perl',
    'DBD::mysql'                => 'libdbd-mysql-perl',
    'DBD::SQLite'               => 'libdbd-sqlite3-perl',
    'DBIx::SQLEngine'           => 'libdbix-dbschema-perl',
    'Devel::Symdump'            => 'libdevel-symdump-perl',
    'Digest::MD5'               => 'libmd5-perl',
    'Digest::SHA'               => 'libdigest-sha-perl',
    'Digest::SHA1'              => 'libdigest-sha1-perl',
    'Email::Folder'             => 'libemail-folder-perl',
    'Email::MIME'               => 'libemail-mime-perl',
    'Error'                     => 'liberror-perl',
    'FCGI'                      => 'libfcgi-perl',
    'File::Find::Rule'          => 'libfile-find-rule-perl',
    'File::MMagic'              => 'libfile-mmagic-perl',
    'File::Path'                => 'libfile-path-perl',
    'File::Temp'                => 'libfile-temp-perl',
    'File::Spec'                => 'libfile-spec-perl',
    'GD'                        => 'libgd-gd2-perl',
    'Geo::IP'                   => 'libgeo-ip-perl',
    'Graphics::Magick'          => 'libgraphics-magick-perl',
    'HTML::CalendarMonthSimple' => 'libhtml-calendarmonthsimple-perl',
    'HTML::Tree'                => 'libhtml-tree-perl',
    'HTML::Parser'              => 'libhtml-parser-perl',
    'I18N::AcceptLanguage'      => 'libi18n-acceptlanguage-perl',
    'Image::Info'               => 'libimage-info-perl',
    'Image::Magick'             => 'perlmagick',
    'IO::Socket::SSL'           => 'libio-socket-ssl-perl',
    'IPC::Run'                  => 'libipc-run-perl',
    'JSON'                      => 'libjson-perl',
    'JSON::XS'                  => 'libjson-xs-perl',
    'Locale::Maketext::Lexicon' => 'liblocale-maketext-lexicon-perl',
    'mod_perl2'                 => 'libapache2-mod-perl2',
    'Module::Pluggable'         => 'libmodule-pluggable-perl',
    'Net::Jabber'               => 'libnet-jabber-perl',
    'Net::LDAP'                 => 'libnet-ldap-server-perl',
    'Net::SMTP'                 => 'libnet-smtp-server-perl',
    'Net::Telnet'               => 'libnet-telnet-perl',
    'Net::Twitter'              => 'libnet-twitter-perl',
    'Roman'                     => 'libroman-perl',
    'RPC::XML'                  => 'librpc-xml-perl',
    'SOAP::Lite'                => 'libsoap-lite-perl',
    'Spreadsheet::ParseExcel'   => 'libspreadsheet-parseexcel-perl',
    'Spreadsheet::WriteExcel'   => 'libspreadsheet-writeexcel-perl',
    'Sys::Hostname'             => 'libsys-hostname-long-perl',
    'Text::Diff'                => 'libtext-diff-perl',
    'Time::Local'               => 'libtime-local-perl',
    'Unicode::MapUTF8'          => 'libunicode-maputf8-perl',
    'XML::Generator'            => 'libxml-generator-perl',
    'XML::LibXML'               => 'libxml-libxml-perl',
    'XML::Simple'               => 'libxml-simple-perl',
);

# CPAN modules not identified as deb packages or listed due to
# other potentially interesting data:
my %deb_unidentified = (
    'Apache::Request'  => 'only Apache 1.x',
    'APR::Base64'      => '',
    'Bio::NEXUS'       => '',
    'Cal::DAV'         => '',
    'CharsetDetector'  => '',
    'Class::Pluggable' => 'maybe: libclass-pluggable-perl',
    'CSS::Minifier'    => '',
    'Date::Calc' => 'duplicate: libdate-pcalc-perl; we use: libdate-calc-perl',
    'Date::Handler'          => '',
    'Date::Parse'            => '',
    'Email::FolderType::Net' => 'insufficient: libemail-foldertype-perl',
    'Email::Delete'          => '',
    'Encode::compat'         => '',
    'ExtUtils::MakeMaker'    => '',
    'File::Basename'         => '',
    'GD' =>
'duplicates: libgd-gd2-noxpm-perl, libgd-graph-perl; we use: libgd-gd2-perl',
    'Geo::GeoNames'        => '',
    'HTML::Entities'       => '',
    'HTTP::Cookies::Find'  => '',
    'HTTPD::Authen'        => '',
    'HTTPD::UserAdmin'     => '',
    'HTTPD::GroupAdmin'    => '',
    'IO::File'             => '',
    'JavaScript::Minifier' => '',
    'KinoSearch'           => '',
    'Lingua::EN::Sentence' => '',
    'LWP::UserAgent'       => '',
    'mod_perl'             => 'only Apache 1.x',
    'Net::FTP'             => '',
    'Spreadsheet::XLSX'    => '',
    'Time::ParseDate '     => '',
    'WordPress::Post'      => '',
    'WWW::Shorten::Bitly'  => 'insufficient: libwww-shorten-perl',
);

# Other global variables
#
my @modules_prereq = qw (
  CPANPLUS
);

# Default logfile location
my $log_dir = "../working/logs";

my $start_time = localtime();
my @modules_core_required;
my @modules_core_optional;
my @modules_ext_required;
my @modules_ext_recommended;
my @modules_ext_optional;
my @modules_ext_unspecified;
my @modules_tools_optional;
my @modules_unavailable;    # All non-existing (no version number) modules
my @modules_apache1;
my @modules_apache2;
my @modules_install;
my @modules_cpan_only;
my $mod_ver;
my $tab;
my $file;
my $myname = $0;
$myname =~ s/^(\.\/)?([^.]*)\..*/$2/;
my $cpanplus = 1;
my $show_special;
my $selection;
my $install_sum;
my $install_bool;
my $count_success = 0;
my $count_error   = 0;
my $count_skipped = 0;
my $in;

# Parse options and print usage if there is a syntax error,
# or if usage was explicitly requested.
# Also consider perldoc availability.
my $help          = 0;
my $man           = 0;
my $print_modules = 0;
my $questions     = 0;
my $verbose       = 0;
my $perldoc       = qx| perldoc 2>&1 1>/dev/null |;
GetOptions(
    'questions|q' => \$questions,
    'help|?'      => \$help,
    'man'         => \$man,
    'verbose|v'   => \$verbose,
    'print|p'     => \$print_modules,
) or pod2usage(2);
pod2usage(1) if $help;

if ( $perldoc =~ /^Usage: perldoc.*/ ) {
    pod2usage( -verbose => 2 ) if $man;
}
else {
    pod2usage( -verbose => 2, -noperldoc => 1 ) if $man;
}

if ($print_modules) {
    print "
Perl modules with their directly related Debian/Ubuntu (deb) package:\n\n";
    foreach ( sort %deb_install_direct_cpanmod ) {
        &tabs;
        if ( defined $deb_install_direct_cpanmod{$_} ) {
            print "  $_" . "$tab" . "$deb_install_direct_cpanmod{$_}\n";
        }
    }
    print "
Perl modules for which no Debian/Ubuntu (deb) package has been identified
or which are listed due to other potentially interesting data:\n\n";
    foreach ( sort %deb_unidentified ) {
        &tabs;
        if ( defined $deb_unidentified{$_} ) {
            print "  $_" . "$tab" . "$deb_unidentified{$_}\n";
        }
    }
    print "
====================================================================

If you want to uninstall manually from aptitude (Debian/Ubuntu) use:
--------------------------------------------------------------------
aptitude remove <package_name(s)>

This results for all the packages in (most likely with broken dependencies):
----------------------------------------------------------------------------
aptitude remove ";
    foreach ( sort %deb_install_direct_cpanmod ) {
        if ( defined $deb_install_direct_cpanmod{$_} ) {
            print "$deb_install_direct_cpanmod{$_} ";
        }
    }
    print "

For an aptitude test deinstallation this should be better while incomplete:
---------------------------------------------------------------------------
aptitude remove ";
    my @deb_incomplete;
    foreach ( sort %deb_install_direct_cpanmod ) {
        if ( defined $deb_install_direct_cpanmod{$_} ) {
            unless (
                ( $deb_install_direct_cpanmod{$_} eq "libalgorithm-diff-perl" )
                or
                ( $deb_install_direct_cpanmod{$_} eq "libio-socket-ssl-perl" )
                or ( $deb_install_direct_cpanmod{$_} eq "libauthen-sasl-perl" )
                or ( $deb_install_direct_cpanmod{$_} eq "libhtml-tree-perl" )
                or ( $deb_install_direct_cpanmod{$_} eq "librpc-xml-perl" )
                or ( $deb_install_direct_cpanmod{$_} eq "libhtml-parser-perl" )
                or ( $deb_install_direct_cpanmod{$_} eq "libhtml-tree-perl" ) )
            {
                push( @deb_incomplete, $deb_install_direct_cpanmod{$_} );
            }
        }
    }
    print "@deb_incomplete

===================================================================

If you want to unistall manually from CPANPLUS (all platforms) use:
-------------------------------------------------------------------
cpanp u <package_name(s)> --verbose

It results for CPAN packages also *covered* by a deb package in:
----------------------------------------------------------------
cpanp u ";
    foreach ( sort %deb_install_direct_cpanmod ) {
        if ( defined $deb_install_direct_cpanmod{$_} ) {
            print "$_ ";
        }
    }
    print "--verbose

It results for CPAN packages *not covered* by a deb package in:
---------------------------------------------------------------
cpanp u ";
    foreach ( sort %deb_unidentified ) {
        if ( defined $deb_unidentified{$_} ) {
            print "$_ ";
        }
    }
    print "--verbose

It results for *all* CPAN packages in:
--------------------------------------
cpanp u ";
    my @allcpan;
    foreach (%deb_unidentified) {
        if ( defined $deb_unidentified{$_} ) {
            push( @allcpan, $_ );
        }
    }
    foreach ( sort %deb_install_direct_cpanmod ) {
        if ( defined $deb_install_direct_cpanmod{$_} ) {
            push( @allcpan, $_ );
        }
    }
    my @sorted = sort @allcpan;
    print "@allcpan --verbose\n\n";
    exit 0;
}

# Print console output also to logfile
if ( -w "$log_dir" ) {
    &open_stdout("$log_dir");
}
else {
    if ( mkdir "$log_dir", 0755 ) {
        print "\nCreated directory \"$log_dir\"\n\n";
        &open_stdout("$log_dir");
    }
    else {
        if ( -w "." ) {
            &open_stdout(".");
        }
        else {
            &open_stdout("~");
        }
    }
}

# Called just from above
sub open_stdout {
    open( STDOUT, "| tee -ai $_[0]/$myname.log" );
    print ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\nStarted: $start_time\n";
    unless ( $_[0] eq "$log_dir" ) {
        print "\nWARNING: Could not write to \"$log_dir/$myname.log\".\n";
        $log_dir = "$_[0]";
        print "Using \"$log_dir/$myname.log\" instead.\n\n";
    }
}

if ($print_modules) {
    foreach ( sort %deb_install_direct_cpanmod ) {
        &tabs;
        if ( defined $deb_install_direct_cpanmod{$_} ) {
            print "  $_" . "$tab" . "(deb: $deb_install_direct_cpanmod{$_})\n";
        }
    }
    exit 0;
}

# Called from: install_deb
sub undefine_arrays {

    # Undefine this if starting over
    undef(@modules_core_required);
    undef(@modules_core_optional);
    undef(@modules_ext_required);
    undef(@modules_ext_recommended);
    undef(@modules_ext_optional);
    undef(@modules_ext_unspecified);
    undef(@modules_tools_optional);
    undef(@modules_unavailable);
    undef(@modules_apache1);
    undef(@modules_apache2);
    undef(@modules_install);
    undef(@modules_cpan_only);
    undef($show_special);
    undef($selection);
}

# Main
# ----
&main;

# Also called from: install_deb
sub main {
    print "\nAnalysing environment...\n" unless ($verbose);
    &getmod_core_and_extensions;
    &getmod_tools;
    &module_availability;
    &automatic_install;
}

# Called from: main
sub getmod_core_and_extensions {

    # Get Foswiki core dependencies (fill related arrays)
    &get_dependencies( "$dep_core_path", "Required", \@modules_core_required );
    &get_dependencies( "$dep_core_path", "Optional", \@modules_core_optional );

    # Get Foswiki extension dependencies (fill related arrays)
    if ( -r $dep_ext_dir ) {
        opendir( DIR, $dep_ext_dir )
          or warn $!;
        while ( $file = readdir(DIR) ) {
            next unless ( -f "$dep_ext_dir/$file" );
            &get_dependencies( "$dep_ext_dir/$file", "Required",
                \@modules_ext_required );
            &get_dependencies( "$dep_ext_dir/$file", "Recommended",
                \@modules_ext_recommended );
            &get_dependencies( "$dep_ext_dir/$file", "Optional",
                \@modules_ext_optional );
            &get_dependencies( "$dep_ext_dir/$file", "Unspecified",
                \@modules_ext_unspecified );
        }
        closedir(DIR);
    }
    else {
        print "
WARNING: Unable to open \"$dep_ext_dir\".
Cannot analyse dependencies of extensions. Please run the script later again
after having installed an extension.\n";
    }
}

# Called from: getmod_core_and_extensions
sub get_dependencies {
    open( FILE, "$_[0]" ) or print "
Could not open file \"$dep_ext_dir/$file\".
Please verify read permissions. You may want to adjust group affiliation of the
current user. This could make sense if:
  1. You want to use this user for analysing the modules and maybe use sudo
     only later for module installation.
  2. You want to install from CPAN for a *local* CPAN installation.
In any other case, please invoke the script as root or use sudo initially.\n
Logfile \"$log_dir/$myname.log\" was written.\n\n" and exit 1;
    while (<FILE>) {
        if ( $_[1] ne "Unspecified" ) {
            if ( $_ =~ /^.*,cpan.*($_[1]).*/i ) {
                $_ =~ s/^([^,]*),.*/$1/;
                chomp $_;
                &push_no_dup( \@{ $_[2] }, $_ );
            }
        }
        else {
            if ( $_ =~ /^.*,cpan.*/i ) {
                unless ( $_ =~ /.*(Required|Recommended|Optional).*/i ) {
                    $_ =~ s/^([^,]*),.*/$1/;
                    chomp $_;
                    &push_no_dup( \@modules_ext_unspecified, $_ );
                }
            }
        }
    }
    close FILE;
}

# Called from: main
sub getmod_tools {

    # Also check for optional dependencies in tools directory
    opendir( DIR, "$dep_tools_dir" ) or die $!;
    while ( $file = readdir(DIR) ) {
        next unless ( -f "$dep_tools_dir/$file" );
        open( FILE, "$dep_tools_dir/$file" ) or die $!;
        while (<FILE>) {
            if ( $_ =~ /^use .*/ ) {

                # s/^([^ ]*) *([^ ]*)/$2 $1/; # swap first two words
                $_ =~ s/^use *([^ ;(]*).*/$1/;
                if ( $_ =~ /^(Foswiki.*|strict|warning|diagnostics).*/ ) {
                    next;
                }
                chomp $_;
                &push_no_dup( \@modules_tools_optional, $_ );
            }
        }
        close FILE;
    }
    closedir(DIR);
}

# Called from: main
sub module_availability {

    # Verify availability of modules
    &modules_available( "Required Core Modules:",    \@modules_core_required );
    &modules_available( "Optional Core Modules:",    \@modules_core_optional );
    &modules_available( "Tools Modules (optional):", \@modules_tools_optional );
    &modules_available( "Required Extension Modules:", \@modules_ext_required );
    &modules_available( "Recommended Extension Modules:",
        \@modules_ext_recommended );
    &modules_available( "Optional Extension Modules:", \@modules_ext_optional );
    &modules_available( "Unspecified Extension Modules:",
        \@modules_ext_unspecified );
    &modules_available( "Prerequisites Automatic Module Installation:",
        \@modules_prereq );
    print "\n" unless $verbose;
}

# Called from: module_availability
#
# Here modules are pre-sorted
sub modules_available {
    my @final_print;
    if ($verbose) {
        if ( $^O eq "MSWin32" ) {
            print "\n";
        }
        print "\n$_[0]\n--------------------------------------------\n";
    }
    else {
        print "...";
    }
    foreach ( @{ $_[1] } ) {
        if ( $^O eq "MSWin32" ) {

            # Windows command for ActivePerl
            # perl -MFile::Path -e "print \"$File::Path::VERSION\";" 2> NUL
            my $tmp = $_ . "::VERSION";
            $mod_ver = qx| perl -M$_ -e "print \"\$$tmp\";" 2> NUL |;
        }
        else {
            $mod_ver = qx| perl -le 'use $_; print "$_"->VERSION' 2>/dev/null |;
        }
        &tabs;

        # Depending if we found a version number or not...
        unless ($mod_ver) {
            if ( $^O eq "MSWin32" ) {
                $mod_ver = "UNAVAILABLE";
            }
            else {
                $mod_ver = "UNAVAILABLE\n";
            }
            if ( "$_" eq "Config" ) {
                &mod_config_av;    # Call here on Windows
            }
            elsif ( "$_" eq "CPANPLUS" ) {
                $mod_ver =
"$mod_ver: Please install CPANPLUS if you want to use this program for module installation.\n";
                $cpanplus = 0;
            }
            elsif ( ( "$_" eq "Apache::Request" ) or ( "$_" eq "mod_perl" ) ) {

                # Make special to inform the user about his options;
                # only push at @modules_unavailable
                $show_special = 1;
                &push_no_dup( \@modules_unavailable, $_ );
                &push_no_dup( \@modules_apache1,     $_ );
            }
            elsif ( ( $_ eq "Apache2::Request" ) or ( "$_" eq "mod_perl2" ) ) {

                # Make special to inform the user about his options;
                # only push at @modules_unavailable
                $show_special = 1;
                &push_no_dup( \@modules_unavailable, $_ );
                &push_no_dup( \@modules_apache2,     $_ );
            }
            elsif ( "$_" eq "Graphics::Magick" ) {

                # Push here because it can be installed via package manager
                # although not from CPAN, therefore special
                $show_special = 1;
                &push_no_dup( \@modules_install, $_ );
            }
            elsif ( "$_" eq "Unicode::MapUTF8" ) {
                $show_special = 1;
                if ( $] < 5.007 ) {
                    &push_no_dup( \@modules_install, $_ );
                }
            }
            elsif ( "$_" eq "Win32::Console" ) {
                $show_special = 1;
                if ( $^O eq "MSWin32" ) {
                    &push_no_dup( \@modules_install, $_ );
                }
            }
            else {
                &push_no_dup( \@modules_install, $_ );
            }

            # Don't add Config as it is available even without version number.
            # The Config module contains all the information that was available
            # to the Configure program at Perl build time (over 900 values).
            &push_no_dup( \@modules_unavailable, $_ ) unless $_ eq "Config";
        }

        # Handle even if version number exists
        if ( "$_" eq "CGI" ) {

            # Check for problematic CGI versions
            if ( ( $mod_ver =~ /(3.37|3.43|3.47)/ ) or ( $mod_ver < 3.11 ) ) {
                $show_special = 1;
                &push_no_dup( \@modules_install, $_ );
            }
        }
        elsif ( "$_" eq "Config" ) {
            &mod_config_av;    # Call here on Unix
        }

        # Prepare print
        if ( $^O eq "MSWin32" ) {

            # On Windows put missing linebreak only here
            # or $mod_ver would be defined too early
            $mod_ver = "$mod_ver\n";
        }
        push( @final_print, "  $_" . "$tab" . "$mod_ver" );
    }
    print( sort @final_print ) if $verbose;
}

# Called from: modules_available, getmod_tools, get_dependencies
#
# Only pushes to the array if the element to push isn't yet there
sub push_no_dup {

    # Do not add duplicates, use hash to check
    #
    # Example code while not yet in sub:
    # my %h_modules_install = ();
    # for (@modules_install) { $h_modules_install{$_} = 1 }
    # unless ( $h_modules_install{$_} ) {
    #     push( @modules_install, $_ );
    # }
    my %hash = ();
    for ( @{ $_[0] } ) {
        $hash{$_} = 1;
    }
    unless ( $hash{ $_[1] } ) {
        push( @{ $_[0] }, $_[1] );
    }
}

# Called from: modules_available
#
# Have to call this from different places on Unix and Windows
sub mod_config_av {
    if ( $^O eq "MSWin32" ) {
        $mod_ver = "AVAILABLE";
    }
    else {
        $mod_ver = "AVAILABLE\n";
    }
}

# Called from: modules_available, automatic_install, if defined $print_modules
#
# Subroutine to decide about the number of tabs for better print output
sub tabs {
    if ( length "  $_" < 8 ) {
        $tab = "\t\t\t\t";
    }
    elsif ( length "  $_" < 16 ) {
        $tab = "\t\t\t";
    }
    elsif ( length "  $_" < 24 ) {
        $tab = "\t\t";
    }
    else {
        $tab = "\t";
    }
}

# Called from: main
#
# Automatic Perl module installation
sub automatic_install {
    if (@modules_unavailable) {
        my $package = "";    # should be initialized
        print
"\nThe following Perl modules are not installed but are present in a Foswiki
DEPENDENCIES file or are used by a script in the tools directory:\n";
        foreach ( sort @modules_unavailable ) {
            print "  $_\n";
        }
        if ($questions) {
            if ( (@modules_apache1) or (@modules_apache2) ) {
                while (1) {
                    my @prompt;
                    print "
Apache related modules have been found, which are depending on your Apache
version. For what Apache version(s) do you want to install for? Please select:";
                    if (@modules_apache1) {
                        push( @prompt, "1" );
                        print "
  1 for 1.x";
                    }
                    if (@modules_apache2) {
                        push( @prompt, "2" );
                        print "
  2 for 2.x";
                    }
                    print "
  A(ll) to install all
  n(o) to not install any from this list
[";
                    if (@prompt) {
                        foreach (@prompt) {
                            print "$_/";
                        }
                    }
                    print "A/n] ";
                    $in = <>;
                    chomp $in;
                    if ( $in eq "1" ) {
                        push @modules_install, @modules_apache1;
                        last;
                    }
                    elsif ( $in eq "2" ) {
                        push @modules_install, @modules_apache2;
                        last;
                    }
                    elsif ( $in =~ /^A(l){0,2}$/i ) {
                        push @modules_install, @modules_apache1;
                        push @modules_install, @modules_apache2;
                        last;
                    }
                    elsif ( $in =~ /^n(o)?$/i ) {
                        last;
                    }
                }
            }
        }
        else {
            print "\nDefault is to just use Apache version 2 modules\n";
            push @modules_install, @modules_apache2;
        }
        if ($show_special) {
            print "\nIf found we are taking special care of:
  Apache::Request       can be selected with option -q 
  Apache::Request2      installed by default or use -q
  mod_perl              can be selected with option -q
  mod_perl2             installed by default or use -q
  Unicode::MapUTF8      installed only if Perl <=5.6.x
  Win32::Console        installed only on Windows
  Graphics::Magick      install manually (not in CPAN) unless you now select a
                        package manager (deb: libgraphics-magick-perl)
  CGI			install also if <3.11 or 3.37, 3.43, 3.47
";
        }
        print "***********************************************************
Please find here the final list of modules to be installed:\n";
        if (@modules_install) {
            foreach ( sort @modules_install ) {
                &tabs;
                if (    ( defined $deb_install_direct_cpanmod{$_} )
                    and ( $^O ne "MSWin32" ) )
                {
                    print "  $_" . "$tab"
                      . "(deb: $deb_install_direct_cpanmod{$_})\n";
                }
                else {
                    print "  $_\n";
                    push( @modules_cpan_only, $_ );
                }
            }
        }
        else {
            print "  Nothing to install
***********************************************************
Exiting because there is nothing to do.
\nLogfile \"$log_dir/$myname.log\" was written.\n\n" and exit 0;
        }
        print "***********************************************************
If supported, it is recommended to first select the format of your package
manager. If some modules cannot be installed via the package manager, then
we will automatically offer to install them from CPAN using CPANPLUS.

Do you want to install them automatically using one of the following methods?\n";
        if ( $^O eq "linux" ) {
            open( FILE, "/etc/issue" )
              or print "\nWARNING: Could not open file \"/etc/issue\".\n";
            while (<FILE>) {
                if (   ( $_ =~ /^Debian GNU\/Linux.*/ )
                    or ( $_ =~ /^Ubuntu.*/ ) )
                {
                    $package = "deb";
                }
            }
            close FILE;
        }
      PROMPT: while (1) {
            my @prompt;
            if ( $cpanplus == 0 ) {
                print
"CPANPLUS is not  installed. Cannot offer it for installation.\n";
            }
            else {
                push( @prompt, "c" );
                print
                  "Select \"c\" for CPAN based installation with CPANPLUS.\n";
            }
            if ( $package eq "deb" ) {
                push( @prompt, "d" );
                print "Select \"d\" to install Debian/Ubuntu packages (deb).\n";
            }
            print "Put \"no\" to cancel.\n[";
            if (@prompt) {
                foreach (@prompt) {
                    print "$_/";
                }
            }
            print "no] ";
            $in = <>;
            chomp $in;
            &cancel_installation;
            $selection = $in;
            if (@prompt) {
                foreach (@prompt) {
                    last PROMPT if $in =~ /^($_)$/i;
                }
            }
        }
        if ( $selection eq "d" ) {
            &install_deb;
        }
        elsif ( $selection eq "c" ) {
            &install_cpanp;
        }
        else {
            if ( $cpanplus == 0 ) {
                print
"\nCPANPLUS is not  installed. Cannot offer it for installation.\n";
            }
            else {
                print
"\nUnsupported package manager, only offering CPANPLUS installation.\n";
                &install_cpanp;
            }
        }
    }
}

# Called from: automatic_install
#
# Automatic installation via CPANPLUS
sub install_cpanp {
    my $sel_cpan_inst_method;
    $install_sum = scalar( grep $_, @modules_install );

    # Only show if not root otherwise set to 1
    unless ( $> == 0 || $< == 0 ) {
        while (1) {
            print "
You are not root. Please chose one of the following options:
1. Install system wide (use sudo if required).
2. Do a local CPAN installation, not being available system wide!
   Only provide a passwort to sudo in case cpanp triggers it and if you are
   sure it still will not do a system wide installation.
Select \"n\" to cancel.
[1/2/n] ";
            $in = <>;
            chomp $in;
            &cancel_installation;
            $sel_cpan_inst_method = $in;
            last if $in =~ /^(1|2)$/i;
        }
    }
    else {
        $sel_cpan_inst_method = 1;
    }

    # Only show if I am not root
    if ( $sel_cpan_inst_method == 2 ) {
        while (1) {
            print "
Note:
-----
Within this program I am not (yet) supporting local module installation into a
specific directory of your choice. You may just give it a try now anyway. Also
there are other methods like e.g. using perlbrew:
  http://foswiki.org/Support/HowToUseFoswikiWithLocalPerlInstallation
If you want to pre-configure your local directory in \"cpanp\" (used if
proceeding) before running this program, then perform these steps:
.......
1. Run command \"cpanp\"
2. Within cpanp run command \"s reconfigure\"
3. Select item 6 (6> Setup installer settings)
4. Answer the questions and when asked for \"Makefile.PL\" put your settings.
   The entry for system wide installation is \"INSTALLDIRS=site\".
a. Alternatively to ExtUtils::MakeMaker and Makefile.PL move on to
  \"Build.PL and Build flags?\" using Module::Build. The entry for system
   wide installation is \"--installdirs=site\". To localize it use e.g.:
  \"install_base=/my/private/path\" (set \@localPerlLibPath in LocalLib.cfg)
  \"install_base=/path/to/foswiki/lib/CPAN/lib (no need for \@localPerlLibPath)
5. Answer \"Prefer Makefile.PL over Build.PL? [Y/n]:\" accordingly.
6. Answer the remaining questions and finally exit configuration by saving it.
......
If using \"cpanp\" like this, you should generally configure it according to
your requirements. Do you want to proceed now? [Y/n] ";
            $in = <>;
            chomp $in;
            &cancel_installation;
            last if $in =~ /^y/i;
        }
    }

    # Install from CPAN
    # -----------------
    # Aquivalent to the following command but without --verbose:
    # cpanp i Apache::Htpasswd --verbose
    use CPANPLUS;
    foreach ( sort @modules_install ) {

        # Maybe consider displaying this only in case installation indeed failed
        # by utilizing $install_bool and results of: system "sudo cpanp i";
        if ( $_ eq "Image::Magick" ) {
            print "
About Image::Magick Installation
********************************
If installation of Image::Magick (PerlMagick) fails try:
  1. Install PerlMagick from your package manager
     (will be in line with your ImageMagick version)
  2. Make sure the basic ImageMagick is installed with the required version or
     PerlMagick will not build properly 
  3. Consider compiling all manually using e.g. ImageMagick.tar.gz
     The following *example* of a configure line for Image::Magick worked:
     ./configure --with-perl=/opt/perl_local/perl5/perlbrew/perls/perl-5.12.2/bin/perl --prefix=/home/foswiki/local

CPANPLUS and CPAN installations of the module Image::Magick may fail.
Do you want to run a harmeless try? [y/n] ";
            $in = <>;
            chomp $in;
            if ( $in =~ /^n/i ) {
                $count_skipped++;
                next;
            }
        }
        if ( $_ eq "Graphics::Magick" ) {
            print
"\nModule Graphics::Magick cannot be installed because it is not available in CPAN.\n";
            $count_skipped++;
            next;
        }

        # Actual CPAN installation
        if ( $sel_cpan_inst_method == 2 ) {
            print
"\n\nInstalling (locally) $_\n****************************************\n";
            $install_bool = install($_);
            &count_cpan_inst;
        }
        elsif ( ( $sel_cpan_inst_method == 1 )
            and ( $> == 0 || $< == 0 ) )
        {
            print
"\n\nInstalling (system wide) $_\n****************************************\n";
            $install_bool = install($_);
            &count_cpan_inst;
        }
        else {
            print
"\n\nInstalling (system wide) $_\n****************************************\n";
            if (`which sudo`) {
                system "sudo cpanp i $_";
                if ( $? >> 8 == 0 ) {
                    $count_success++;
                }
                else {
                    $count_error++;
                }
            }
            else {
                print "
ERROR: \"sudo\" is not available!
You must be root to use the package manager!\n
Logfile \"$log_dir/$myname.log\" was written.\n\n";
                exit 1;
            }
        }
    }

    # Call only if sudo was indeed used
    unless ( ( $sel_cpan_inst_method == 2 )
        or ( ( $sel_cpan_inst_method == 1 ) and ( $> == 0 || $< == 0 ) ) )
    {
        &remove_sudo;
    }

    print "
Successfully installed: $count_success
                Failed: $count_error
               Skipped: $count_skipped
      Selected modules: $install_sum (without dependencies)

Installation finished\n";
}

# Called from: install_cpanp
sub count_cpan_inst {
    if ( defined $install_bool == 1 ) {
        $count_success++;
    }
    else {
        $count_error++;
    }
}

# Called from: automatic_install
#
# Automatic installation of "Debian" packages
sub install_deb {
    my @deb_inst_dir_fin;
    my $sel_inst_prog;

    # If not root and command sudo doesn't exist, exit
    unless ( $> == 0 || $< == 0 ) {
        unless (`which sudo`) {
            print "
ERROR: \"sudo\" is not available!
You must be root to use the package manager!\n
Logfile \"$log_dir/$myname.log\" was written.\n\n";
            exit 1;
        }
    }

    # Shall aptitude be installed if not available?
    unless (`which aptitude`) {
        while (1) {
            print "
Aptitude is not available.
1. Do you want to install it via apt-get? This is recommended on Debian.
2. Shall I fall back to apt-get for installation? This appears quite ok on Ubuntu.
Chose \"n\" to cancel. [1/2/n] ";
            $in = <>;
            chomp $in;
            &cancel_installation;
            $sel_inst_prog = $in;
            last if $in =~ /^(1|2)$/;
        }

        # Install aptitude using apt-get, exit if apt-get isn't available either
        if ( $sel_inst_prog == 1 ) {
            if (`which apt-get`) {
                print "\nInstalling \"aptitude\" using \"apt-get\".\n\n";
                unless ( $> == 0 || $< == 0 ) {
                    my @args = ( "sudo", "apt-get", "install", "aptitude" );
                    system(@args);
                }
                else {
                    my @args = ( "apt-get", "install", "aptitude" );
                    system(@args);
                }
            }
            else {
                print "
ERROR: apt-get is not available, unable to install aptitude.
Please install programs manually or use another install method.
\nLogfile \"$log_dir/$myname.log\" was written.\n\n"
                  and exit 1;
            }

            # Restart module installation after aptitude installation
            &install_deb;
        }
    }

    # Build final list
    foreach (@modules_install) {
        if ( $deb_install_direct_cpanmod{$_} ) {
            push( @deb_inst_dir_fin, $deb_install_direct_cpanmod{$_} );
        }
    }

    # Real installation
    print "\nInstalling \"deb\" packages using command:\n";
    if (`which aptitude`) {
        print "aptitude install [packages]\n\n";
        unless ( $> == 0 || $< == 0 ) {
            my @args = ( "sudo", "aptitude", "install", @deb_inst_dir_fin );
            system(@args);
            &remove_sudo;
        }
        else {
            my @args = ( "aptitude", "install", @deb_inst_dir_fin );
            system(@args);
        }
    }
    elsif (`which apt-get`) {
        print "apt-get install [packages]\n\n";
        unless ( $> == 0 || $< == 0 ) {
            my @args = ( "sudo", "apt-get", "install", @deb_inst_dir_fin );
            system(@args);
            &remove_sudo;
        }
        else {
            my @args = ( "apt-get", "install", @deb_inst_dir_fin );
            system(@args);
        }
    }
    else {
        print "\nERROR: aptitude nor apt-get were found.\n";
    }
    &ask_cpan_install;
}

sub ask_cpan_install {
    if ( ( $selection eq "d" ) and (@modules_cpan_only) ) {
        while (1) {
            print "
Installation from your package manager is finished but some modules are only
available from CPAN. Do you want to start over to install missing modules from
CPAN? [Y/n] ";
            $in = <>;
            chomp $in;
            print "\nLogfile \"$log_dir/$myname.log\" was written.\n\n"
              and exit 0
              if $in =~ /^n/i;
            last if $in =~ /^y/i;
        }
        &undefine_arrays;
        &main;
    }
}

sub remove_sudo {

    # Remove sudo permissions, so we don't fool if a local installation should
    # be done afterwards and within the 15 minutes sudo normally won't ask for
    # a password again.
    print "\nRemoving the user's sudo timestamp entirely.\n";
    system "sudo -K";
}

sub cancel_installation {
    print
"\nInstallation was cancelled.\n\nLogfile \"$log_dir/$myname.log\" was written.\n\n"
      and exit 0
      if $in =~ /^n(o)?$/i;
}

print "\nLogfile \"$log_dir/$myname.log\" was written.\n\n";
close(STDOUT);
exit 0;

__END__

=head1 NAME

dependencies_installer.pl - Searches missing Perl modules and offers installation via CPANPLUS or a supported package management system.
Currently only CPANPLUS and Debian packages using suffix "deb" are supported.

=head1 SYNOPSIS

dependencies_installer.pl [-h|?|--help] [-m|--man] [-p|--print] [-q|--questions] [-v|--verbose]

Options:

B<-h> or B<-?> or B<--help> brief help message

B<-m> or B<--man> full documentation

B<-p> or B<--print> list all Perl modules we are aware of, plus uninstall commands

B<-q> or B<--questions> ask additional questions instead of using default

B<-v> or B<--verbose> lists installed Perl modules with version numbers

=head1 OPTIONS

=over 8

=item B<-h|--help>

Prints a brief help message and exits.

=item B<-m|--man>

Prints the manual page and exits.

=item B<-p> or B<--print>

List all Perl modules this program is currently aware of. Also reflect which are covered by a package manager versus the ones only available from CPAN.

=item B<-q> or B<--questions>

Ask additional questions instead of just using the default. Currently this only applies to Apache related modules, being available for Apache 1.x and 2.x. By default modules for 2.x are installed. Use this option if the default isn't matching for you.

=item B<-v|--verbose>

Lists installed Perl modules with version numbers.

=back

=head1 DESCRIPTION

B<This Perl program> will analyse if the core Foswiki, a shipped tool in the tools directory or any of the installed extensions use Perl modules which are not yet available in the system. All identified modules can be listed with their version number (--verbose). Finally an overview is presented about which should be installed.

Currently the following installation methods are supported:

1. Directly from CPAN using CPANPLUS

2. Debian packages using suffix "deb"

On all systems it should be possible to install modules from CPAN. This program offers to install missing modules by using CPANPLUS (cpanp). Recent Perl versions ship with CPANPLUS and have it pre-configured allowing to install immediately. If its configuration hasn't been tweaked to your local needs, upon first run it may take a bit until it indeed starts installation but it should work. On Windows the script was tested with ActivePerl (5.12.1; initially a missing C compiler and make utility was installed automatically). 

On Debian and Ubuntu the system related package management can be used to install required modules. Since on Debian aptitude is the recommended installer, the program prefers it if available. Otherwise it offers to install it or to use apt-get instead. Some modules might only be available from CPAN. If so, the program asks you to start over to complete installation of remaining modules by using CPANPLUS additionally.

If a module isn't mapped correctly to an existing package or not considered although a package exists for the related package manager, then please raise it as an issue on foswiki.org (e.g. as task), so it can be addressed.

=cut

------------------------------------------------------------
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
