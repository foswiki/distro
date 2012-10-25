# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Configure::UIs::CGISetup

Specialised UI for the CGI Setup section. This provides a renderHtml method
that generates the bespokse screen for this section. This *could* all be
done in a specialised Foswiki::Configure::Section type, but since all the
data is read only, it was easier this way (if somewhat less elegant).

=cut

package Foswiki::Configure::UIs::CGISetup;

use strict;
use warnings;

use Foswiki::Configure::Util         ();
use Foswiki::Configure::UIs::Section ();
our @ISA = ('Foswiki::Configure::UIs::Section');

use File::Spec ();

# See Foswiki::Configure::UIs::Section
sub renderHtml {
    my ( $this, $section, $root ) = @_;

    my $contents = '';

    my $erk = 0;
    my $num = 0;
    for my $key ( sort keys %ENV ) {
        my $value = $ENV{$key};
        if ( $key eq 'DOCUMENT_ROOT' ) {
            unless ( -w $this->{root} ) {
                $value .= $this->WARN(<<"HERE");
Could not write to the Foswiki root directory.  This is not necessarily a big problem, but can
cause issues installing some extensions that write files into the server root.
HERE
            }
        }
        if ( $key eq 'HTTP_COOKIE' ) {

            # url decode for readability
            $value =~ s/%7C/ | /go;
            $value =~ s/%3D/=/go;
            $value .= $this->NOTE('Cookie string decoded for readability.');
        }
        $contents .= $this->setting( $key, $value );
        $num++;
    }

    # Report the Umask
    my $pUmask = sprintf( '%03o', umask() );
    $contents .= $this->setting( 'UMASK', $pUmask );
    $num++;

    # Detect whether mod_perl was loaded into Apache
    $Foswiki::cfg{DETECTED}{ModPerlLoaded} =
      ( exists $ENV{SERVER_SOFTWARE}
          && ( $ENV{SERVER_SOFTWARE} =~ /mod_perl/ ) );

    # Detect whether we are actually running under mod_perl
    # - test for MOD_PERL alone, which is enough.
    $Foswiki::cfg{DETECTED}{UsingModPerl} = ( exists $ENV{MOD_PERL} );

    $Foswiki::cfg{DETECTED}{ModPerlVersion} =
      eval 'use mod_perl; return $mod_perl::VERSION';

    # Get the version of mod_perl if it's being used
    if ( $Foswiki::cfg{DETECTED}{UsingModPerl} ) {
        $contents .= $this->setting( '', $this->WARN(<<HERE) );
You are running <tt>configure</tt> with <tt>mod_perl</tt>. This
is risky because mod_perl will remember old values of configuration
variables. You are *highly* recommended not to run configure under
mod_perl (though the rest of Foswiki can be run with mod_perl, of course)
HERE
        $erk++;
    }

    my $cgiver = $CGI::VERSION;
    if ( "$cgiver" =~ m/^(2\.89|3\.37|3\.43|3\.47)$/ ) {
        $contents .= $this->setting( '', $this->WARN( <<HERE ) );
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
            $contents .= $this->setting( '', $this->WARN( <<HERE ) );
Perl CGI version 3.11 or higher is recommended to avoid problems with
attachment uploads on Cygwin Perl.
HERE
            $erk++;
        }
        elsif ($Foswiki::cfg{DETECTED}{ModPerlVersion}
            && $Foswiki::cfg{DETECTED}{ModPerlVersion} >= 1.99 )
        {

            # Recommend CGI.pm upgrade if using mod_perl 2.0, which
            # is reported as version 1.99 and implies Apache 2.0
            $contents .= $this->setting( '', $this->WARN( <<HERE ) );
Perl CGI version 3.11 or higher is recommended to avoid problems with
mod_perl.
HERE
            $erk++;
        }
    }

    #OS
    my $n =
        ucfirst( lc( $Config::Config{osname} ) ) . ' '
      . $Config::Config{osvers} . ' ('
      . $Config::Config{archname} . ')';
    $contents .= $this->setting( "Operating system", $n );

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
        $erk++;
    }

    $contents .= $this->setting( 'Perl version', $n );

    # Perl @INC (lib path)
    $contents .= $this->setting( '@INC library path',
        join( CGI::br(), @INC ) . $this->NOTE(<<HERE) );
This is the Perl library path, used to load Foswiki modules,
third-party modules used by some plugins, and Perl built-in modules.
HERE

    $contents .= $this->setting( 'CGI bin directory', $this->_getBinDir() );

    # Turn off fatalsToBrowser while checking module loads, to avoid
    # load errors in browser in some environments.
    $CGI::Carp::WRAP = 0;    # Avoid warnings...

    # Check that the Foswiki.pm module can be found, but don't croak on
    # bogus configuration settings
    $Foswiki::cfg{ConfigurationFinished} = 1;
    eval 'require Foswiki';
    my $mess = '';
    if ($@) {
        $mess = $@;
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
        $erk++;
    }
    else {
        $mess =
            'Foswiki.pm (Version: <strong>'
          . $Foswiki::VERSION
          . '</strong>) found';
    }
    $contents .= $this->setting( 'Foswiki module in @INC path', $mess );

    # Check that each of the required Perl modules can be loaded, and
    # print its version number.
    my $set;
    my $perlModules = $this->_loadDEPENDENCIES();
    if ( ref($perlModules) ) {
        $set = $this->checkPerlModules( 1, $perlModules );
    }
    else {
        $set = $this->ERROR($perlModules);
        $erk++;
    }

    $contents .= $this->setting(
        "Perl modules",
        CGI::start_table( { class => 'configureNestedTable' } )
          . $set
          . CGI::end_table()
    );

    # All module checks done, OK to enable fatalsToBrowser
    import CGI::Carp qw( fatalsToBrowser );

    # PATH_INFO
    my $url = $Foswiki::query->url();
    $contents .= $this->setting(
        CGI::a( { name => 'PATH_INFO' }, 'PATH_INFO' ),
        $Foswiki::query->path_info() . $this->NOTE(<<HERE) );
For a URL such as <strong>$url/foo/bar</strong>,
the correct PATH_INFO is <strong>/foo/bar</strong>, without any prefixed path
components. <a rel="nofollow" href="$url/foo/bar#PATH_INFO">
<strong>Test PATH_INFO now</strong></a>
- particularly if you are using mod_perl, Apache or IIS, or are using
a web hosting provider.
Look at the new path info here. It should be <strong>/foo/bar</strong>.
HERE

    # mod_perl
    if ( $Foswiki::cfg{DETECTED}{UsingModPerl} ) {
        $n = $this->WARN("Used for this script - it should not be");
    }
    else {
        $n =
"Not used for this script (correct). mod_perl may be enabled for the other scripts. You can check this by visiting System.WebHome in your wiki.";
    }
    $n .= $this->NOTE(
        'mod_perl is ',
        $Foswiki::cfg{DETECTED}{ModPerlLoaded} ? '' : 'not',
        ' loaded into Apache'
    );
    if ( $Foswiki::cfg{DETECTED}{ModPerlVersion} ) {
        $n .= $this->NOTE( 'mod_perl version ',
            $Foswiki::cfg{DETECTED}{ModPerlVersion} );
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
        $erk++;
    }
    $contents .= $this->setting( 'mod_perl', $n );

    my $groups = $::WebServer_gid;
    $groups =~ s/,/, /go;    # improve readability with linebreaks
    $contents .= $this->setting(
        'CGI user',
        'userid = <strong>'
          . $::WebServer_uid
          . '</strong> groups = <strong>'
          . $groups
          . '</strong>'
          . $this->NOTE('Your CGI scripts are executing as this user.')
    );

    $contents .= $this->setting( 'Original PATH',
        $Foswiki::cfg{DETECTED}{originalPath} . $this->NOTE(<<HERE) );
This is the PATH value passed in from the web server to this
script - it is reset by Foswiki scripts to the PATH below, and
is provided here for comparison purposes only.
HERE

    my $currentPath = $ENV{PATH} || '';    # As re-set earlier in this routine
    $contents .=
      $this->setting( "Current PATH", $currentPath, $this->NOTE(<<HERE) );
This is the actual PATH setting that will be used by Perl to run
programs. It is normally identical to {SafeEnvPath}, unless
that variable is empty, in which case this will be the webserver user's
standard path..
HERE

    $contents = $this->renderValueBlock($contents) if $contents;
    $contents = $this->SUPER::renderHtml( $section, $root, $contents );

    return $contents;
}

sub _getBinDir {
    my $dir = $ENV{SCRIPT_FILENAME} || '.';
    $dir =~ s(/+configure[^/]*$)();
    return $dir;
}

# The perl modules that are required by Foswiki.
sub _loadDEPENDENCIES {
    my $this = shift;

    # File DEPENDENCIES is in the lib dir (Item3478)
    my $from = Foswiki::Configure::Util::findFileOnPath('Foswiki.spec');
    my @dir  = File::Spec->splitdir($from);
    pop(@dir);    # Cutting off trailing Foswiki.spec gives us lib dir
    push( @dir, 'Foswiki', 'Contrib', 'core' );
    $from = File::Spec->catfile( @dir, 'DEPENDENCIES' );
    my $d;
    open( $d, '<', $from ) || return 'Failed to load DEPENDENCIES: ' . $!;
    my @perlModules;

    foreach my $line (<$d>) {
        next unless $line;
        my @row = split( /,\s*/, $line, 4 );
        next unless ( scalar(@row) == 4 && $row[2] eq 'cpan' );
        my $ver = $row[1];
        $ver =~ s/[<>=]//g;
        $row[0] =~ /([\w:]+)/;    # check and untaint
        my $modname = $1;
        my ( $dispo, $usage ) = $row[3] =~ /^\s*(\w+).?(.*)$/;
        push(
            @perlModules,
            {
                name           => $modname,
                usage          => $usage,
                minimumVersion => $ver,
                disposition    => lc($dispo)
            }
        );
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

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
