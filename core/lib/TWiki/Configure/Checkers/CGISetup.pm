#
# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2006 TWiki Contributors.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
#
package TWiki::Configure::Checkers::CGISetup;

use strict;

use base 'TWiki::Configure::Checker';

use File::Spec;

sub untaintUnchecked {
    my ( $string ) = @_;

    if ( defined( $string) && $string =~ /^(.*)$/ ) {
        return $1;
    }
    return $string;            # Can't happen.
}

sub ui {
    my $this = shift;
    my $block = '';

    # Detect whether mod_perl was loaded into Apache
    $TWiki::cfg{DETECTED}{ModPerlLoaded} =
      ( exists $ENV{SERVER_SOFTWARE} &&
          ( $ENV{SERVER_SOFTWARE} =~ /mod_perl/ ));

    # Detect whether we are actually running under mod_perl
    # - test for MOD_PERL alone, which is enough.
    $TWiki::cfg{DETECTED}{UsingModPerl} = ( exists $ENV{MOD_PERL} );

    $TWiki::cfg{DETECTED}{ModPerlVersion} =
      eval 'use mod_perl; return $mod_perl::VERSION';

    # Get the version of mod_perl if it's being used
    if ( $TWiki::cfg{DETECTED}{UsingModPerl} ) {
        $block .= $this->setting(
            '', $this->WARN(<<HERE));
You are running <tt>configure</tt> with <tt>mod_perl</tt>. This
is risky because mod_perl will remember old values of configuration
variables. You are *highly* recommended not to run configure under
mod_perl (though the rest of TWiki can be run with mod_perl, of course)
HERE
    }

    # Check for potential CGI.pm module upgrade
    # CGI.pm version, on some platforms - actually need CGI 2.93 for
    # mod_perl 2.0 and CGI 2.90 for Cygwin Perl 5.8.0.  See 
    # http://perl.apache.org/products/apache-modules.html#Porting_CPAN_modules_to_mod_perl_2_0_Status
    if( $CGI::VERSION < 2.93 ) {
        if ( $Config::Config{osname} eq 'cygwin' && $] >= 5.008 ) {
            # Recommend CGI.pm upgrade if using Cygwin Perl 5.8.0
            $block .= $this->setting(
                '', $this->WARN( <<HERE ));
Perl CGI version 3.11 or higher is recommended to avoid problems with
attachment uploads on Cygwin Perl.
HERE
        } elsif( $TWiki::cfg{DETECTED}{ModPerlVersion} &&
                   $TWiki::cfg{DETECTED}{ModPerlVersion} >= 1.99 ) {
            # Recommend CGI.pm upgrade if using mod_perl 2.0, which
            # is reported as version 1.99 and implies Apache 2.0
            $block .= $this->setting(
                '', $this->WARN( <<HERE ));
Perl CGI version 3.11 or higher is recommended to avoid problems with
mod_perl.
HERE
        }
    }

    #OS
    my $n = ucfirst(lc($Config::Config{osname})).' '.
      $Config::Config{osvers}.' ('.
        $Config::Config{archname}.')';
    $block .= $this->setting("Operating system", $n);

    # Perl version and type
    $n = $];
    $n .= " ($Config::Config{osname})";
    $n .= $this->NOTE(<<HERE);
Note that by convention "Perl version 5.008" is referred to as "Perl version 5.8" and "Perl 5.008004" as "Perl 5.8.4" (i.e. ignore the leading zeros after the .)
HERE

    if ( $] < 5.006 ) {
        $n .= $this->WARN(<<HERE);
Perl version is older than 5.6.0.
TWiki has only been successfully tested on Perl 5.6.X and 5.8.X,
and there have been reports that it does not run on 5.5.
You will need to upgrade Perl libraries and tweak the TWiki
code to make TWiki work on older versions of Perl
HERE
    }
    
    
    {
        #from http://search.cpan.org/src/ASH/DBIx-Class-0.08010/lib/DBIx/Class/StartupCheck.pm
        { package TestRHBug; use overload bool => sub { 0 } }

        sub _has_bug_34925 {
            my %thing;
            my $r1 = \%thing;
            my $r2 = \%thing;
            bless $r1 => 'TestRHBug';
            return !!$r2;
        }

        sub _possibly_has_bad_overload_performance {
            return $] < 5.008009 && ! _has_bug_34925();
        }

        if (!_possibly_has_bad_overload_performance()) {
            $n .= "<br /> This version of Perl is likely to exhibit " .
            "extremely slow performance for certain critical operations. <br />" .
            "Please consider recompiling Perl.  For more information, see <br />" .
            "http://twiki.org/cgi-bin/view/Codev/PerlOnRedHatIsSlow <br />" .
            "https://bugzilla.redhat.com/show_bug.cgi?id=196836 and/or <br />" .
            "http://blog.vipul.net/2008/08/24/redhat-perl-what-a-tragedy/ <br />" .
            "http://lists.scsys.co.uk/pipermail/dbix-class/2007-October/005119.html.  <br />" .
            "<br />";
        }
    }


    $block .= $this->setting('Perl version', $n);

    # Perl @INC (lib path)
    $block .= $this->setting(
        '@INC library path', join(CGI::br(), @INC ).
          $this->NOTE(<<HERE));
This is the Perl library path, used to load TWiki modules,
third-party modules used by some plugins, and Perl built-in modules.
HERE



    $block .= $this->setting(
        'CGI bin directory', $this->_checkBinDir());

    # Turn off fatalsToBrowser while checking module loads, to avoid
    # load errors in browser in some environments.
    $CGI::Carp::WRAP = 0;    # Avoid warnings...

    # Check that the TWiki.pm module can be found, but don't croak on
    # bogus configuration settings
    $TWiki::cfg{ConfigurationFinished}  =  1;
    eval 'require TWiki';
    my $mess = '';
    if ($@) {
        $mess = $@;
        $mess = $this->ERROR(
            'TWiki.pm could not be loaded. The error was:').
              CGI::pre($mess).
                  $this->ERROR(<<HERE);
Check path to <code>twiki/lib</code> and check that LocalSite.cfg is
present and readable
HERE
    } else {
        $mess = 'TWiki.pm (Version: <strong>'.$TWiki::VERSION.'</strong>) found';
    }
    $block .= $this->setting(
        'TWiki module in @INC path', $mess);

    # Check that each of the required Perl modules can be loaded, and
    # print its version number.
    my $set;
    my $perlModules = $this->_loadDEPENDENCIES();
    if (ref($perlModules)) {
        $set = $this->checkPerlModules( $perlModules );
    } else {
        $set = $this->ERROR($perlModules);
    }

    $block .= $this->setting("Perl modules",
                       CGI::start_table({width=>'100%'}).
                       $set.CGI::end_table());

    # All module checks done, OK to enable fatalsToBrowser
    import CGI::Carp qw( fatalsToBrowser );

    # PATH_INFO
    my $url = $TWiki::query->url();
    $block .= $this->setting(CGI::a({name=>'PATH_INFO'},'PATH_INFO'),
                             $TWiki::query->path_info().
              $this->NOTE(<<HERE
For a URL such as <strong>$url/foo/bar</strong>,
the correct PATH_INFO is <strong>/foo/bar</strong>, without any prefixed path
components. <a rel="nofollow" href="$url/foo/bar#PATH_INFO">
<strong>Test PATH_INFO now</strong></a>
- particularly if you are using mod_perl, Apache or IIS, or are using
a web hosting provider.
Look at the new path info here. It should be <strong>/foo/bar</strong>.
HERE
                  ));

    # mod_perl
    if( $TWiki::cfg{DETECTED}{UsingModPerl} ) {
        $n = "Used for this script";
    } else {
        $n = "Not used for this script";
    }
    $n .= $this->NOTE(
        'mod_perl is ', $TWiki::cfg{DETECTED}{ModPerlLoaded} ? '' : 'not',
        ' loaded into Apache' );
    if ( $TWiki::cfg{DETECTED}{ModPerlVersion} ) {
        $n .= $this->NOTE( 'mod_perl version ', $TWiki::cfg{DETECTED}{ModPerlVersion} );
    }

    # Check for a broken version of mod_perl 2.0
    if ( $TWiki::cfg{DETECTED}{UsingModPerl} && $TWiki::cfg{DETECTED}{ModPerlVersion} =~ /1\.99_?11/ ) {
        # Recommend mod_perl upgrade if using a mod_perl 2.0 version
        # with PATH_INFO bug (see Support.RegistryCookerBadFileDescriptor
        # and Bugs:Item82)
        $n .= $this->ERROR(<<HERE);
Version $TWiki::cfg{DETECTED}{ModPerlVersion} of mod_perl is known to have major bugs that prevent
its use with TWiki. 1.99_12 or higher is recommended.
HERE
    }
    $block .= $this->setting('mod_perl', $n);

    $block .= $this->setting(
        'CGI user', 'userid = <strong>'.$::WebServer_uid.'</strong> groups = <strong>'.
          $::WebServer_gid.'</strong>'.
            $this->NOTE(
                'Your CGI scripts are executing as this user.'));

    $block .= $this->setting(
        'Original PATH', $TWiki::cfg{DETECTED}{originalPath}.
          $this->NOTE(<<HERE));
This is the PATH value passed in from the web server to this
script - it is reset by TWiki scripts to the PATH below, and
is provided here for comparison purposes only.
HERE

    my $currentPath = $ENV{PATH} || '';     # As re-set earlier in this routine
    $block .= $this->setting("Current PATH", $currentPath,
              $this->NOTE(<<HERE
This is the actual PATH setting that will be used by Perl to run
programs. It is normally identical to {SafeEnvPath}, unless
that variable is empty, in which case this will be the webserver user's
standard path..
HERE
                  ));

    return $this->foldableBlock(
        CGI::em( 'CGI Setup' ), '(read only) ',
        $block);
};

sub _checkBinDir {
    my $this = shift;
    my $dir = $ENV{SCRIPT_FILENAME} || '.';
    $dir =~ s(/+configure[^/]*$)();
    my $ext = $TWiki::cfg{ScriptSuffix} || '';
    my $errs = '';
    opendir(D, $dir) ||
      return $this->ERROR(<<HERE);
Cannot open '$dir' for read ($!) - check it exists, and that permissions are correct.
HERE
    foreach my $script (grep { -f "$dir/$_" && /^\w+(\.\w+)?$/ } readdir D) {
        next if( $ext && $script !~ /\.$ext$/ );
        if( $TWiki::cfg{OS} !~ /^Windows$/i &&
              $script !~ /\.cfg$/ && !-x "$dir/$script" ) {
            $errs .= $this->WARN(<<HERE);
$script might not be an executable script - please check it (and its
permissions) manually.
HERE
        }
    }
    closedir(D);
    return $dir.CGI::br().$errs;
}

# The perl modules that are required by TWiki.
sub _loadDEPENDENCIES {
    my $this = shift;
    
    # File DEPENDENCIES is in the lib dir (Item3478)
    my $from = TWiki::findFileOnPath('TWiki.spec');
    my @dir = File::Spec->splitdir( $from );
    pop(@dir); # Cutting off trailing TWiki.spec gives us lib dir
    $from = File::Spec->catfile(@dir, 'DEPENDENCIES');
    my $d;
    open($d, '<'.$from) || return 'Failed to load DEPENDENCIES: '.$!;
    my @perlModules;
    foreach my $line ( <$d> ) {
        next unless $line;
        my @row = split(/,\s*/, $line, 4);
        next unless (scalar(@row) == 4 && $row[2] eq 'cpan');
        my $ver = $row[1];
        $ver =~ s/[<>=]//g;
        $row[0] =~ /([\w:]+)/; # check and untaint
        my $modname = $1;
        my ($dispo,$usage) = $row[3] =~ /^\s*(\w+).?(.*)$/;
        push(@perlModules, {
            name => $modname,
            usage => $usage,
            minimumVersion => $ver,
            disposition => lc($dispo)
           });
    }
    close($d);
    return \@perlModules;
}

1;
