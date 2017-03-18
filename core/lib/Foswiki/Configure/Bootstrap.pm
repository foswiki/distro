# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Configure::Bootstrap

Inspects the system and makes guesses for the settings required for an
operational Foswiki.

=cut

package Foswiki::Configure::Bootstrap;

use strict;
use warnings;

use Cwd qw( abs_path );
use Assert;
use Encode;
use File::Basename;
use File::Spec;
use POSIX qw(locale_h);
use Unicode::Normalize;

use Foswiki::Configure::FileUtil;
use Foswiki::Configure::Load;

# Enable to trace auto-configuration (Bootstrap)
use constant TRAUTO => 1;

=begin TML
---++ workOutOS - Establish the OS and DetailsOS

These settings are saved into the configuration. However this method is made
public so that they can be set when missing from older configurations.

=cut

sub workOutOS {

    $Foswiki::cfg{DetailedOS} = $^O;
    unless ( $Foswiki::cfg{DetailedOS} ) {

        # SMELL: the perlvar doc for $^O says "The value is identical
        # to $Config{'osname'}" so this would appear redundant.
        require Config;
        $Foswiki::cfg{DetailedOS} = $Config::Config{'osname'};

        # SMELL: is it really worth continuing if we still can't
        # work it out? Proceed with a null string unless someone knows
        # better.
    }

    if ( $Foswiki::cfg{DetailedOS} =~ m/darwin/i ) {    # MacOS X
        $Foswiki::cfg{OS} = 'UNIX';
    }
    elsif ( $Foswiki::cfg{DetailedOS} =~ m/Win/i ) {
        $Foswiki::cfg{OS} = 'WINDOWS';
    }
    elsif ( $Foswiki::cfg{DetailedOS} =~ m/vms/i ) {
        $Foswiki::cfg{OS} = 'VMS';
    }
    elsif ( $Foswiki::cfg{DetailedOS} =~ m/bsdos/i ) {
        $Foswiki::cfg{OS} = 'UNIX';
    }
    elsif ( $Foswiki::cfg{DetailedOS} =~ m/solaris/i ) {
        $Foswiki::cfg{OS} = 'UNIX';
    }
    elsif ( $Foswiki::cfg{DetailedOS} =~ m/dos/i ) {
        $Foswiki::cfg{OS} = 'DOS';
    }
    elsif ( $Foswiki::cfg{DetailedOS} =~ m/^MacOS$/i ) {

        # MacOS 9 or earlier
        $Foswiki::cfg{OS} = 'MACINTOSH';
    }
    elsif ( $Foswiki::cfg{DetailedOS} =~ m/os2/i ) {
        $Foswiki::cfg{OS} = 'OS2';
    }
    else {

        # Erm.....
        $Foswiki::cfg{OS} = 'UNIX';
    }
}

=begin TML

---++ StaticMethod setBootstrap()

This routine is called to initialize the bootstrap process.   It sets the list of
configuration parameters that will need to be set and "protected" during bootstrap.

If any keys will be set during bootstrap / initial creation of LocalSite.cfg, they
should be added here so that they are preserved when the %Foswiki::cfg hash is
wiped and re-initialized from the Foswiki spec.

=cut

sub setBootstrap {

    # Bootstrap works out the correct values of these keys
    my @BOOTSTRAP =
      qw( {DataDir} {DefaultUrlHost} {ForceDefaultUrlHost} {DetailedOS} {OS} {PubUrlPath} {ToolsDir} {WorkingDir}
      {PubDir} {TemplateDir} {ScriptDir} {ScriptUrlPath} {ScriptUrlPaths}{view}
      {ScriptSuffix} {LocalesDir} {Store}{Implementation} {NFCNormalizeFilenames}
      {Store}{SearchAlgorithm} {Site}{Locale} );

    $Foswiki::cfg{isBOOTSTRAPPING} = 1;
    push( @{ $Foswiki::cfg{BOOTSTRAP} }, @BOOTSTRAP );
}

=begin TML

---++ StaticMethod bootstrapConfig()

This routine is called from Foswiki.pm BEGIN block to discover the mandatory
settings for operation when a LocalSite.cfg could not be found.

=cut

sub bootstrapConfig {

    local $Data::Dumper::Sortkeys = 1;
    local $Data::Dumper::Varname  = 'ENV';
    print STDERR "AUTOCONFIG: Bootstrap Phase 1: "
      . Data::Dumper::Dumper( \%ENV )
      if (TRAUTO);

    # Failed to read LocalSite.cfg
    # Clear out $Foswiki::cfg to allow variable expansion to work
    # when reloading Foswiki.spec et al.
    # SMELL: have to keep {Engine} as this is defined by the
    # script (smells of a hack).
    %Foswiki::cfg = ( Engine => $Foswiki::cfg{Engine} );

    # Try to create $Foswiki::cfg in a minimal configuration,
    # using paths and URLs relative to this request. If URL
    # rewriting is happening in the web server this is likely
    # to go down in flames, but it gives us the best chance of
    # recovering. We need to guess values for all the vars that

    # would trigger "undefined" errors
    my $bin;
    my $script = '';
    if ( defined $ENV{FOSWIKI_SCRIPTS} ) {
        $bin = $ENV{FOSWIKI_SCRIPTS};
    }
    else {
        eval('require FindBin');
        die "Could not load FindBin to support configuration recovery: $@"
          if $@;
        FindBin::again();    # in case we are under mod_perl or similar
        $FindBin::Bin =~ m/^(.*)$/;
        $bin = $1;
        $FindBin::Script =~ m/^(.*)$/;
        $script = $1;
    }

    # Can't use Foswiki::decode_utf8 - this is too early in initialization
    print STDERR "AUTOCONFIG: Found Bin dir: "
      . $bin
      . ", Script name: $script using FindBin\n"
      if (TRAUTO);

    $Foswiki::cfg{ScriptSuffix} = ( fileparse( $script, qr/\.[^.]*/ ) )[2];
    $Foswiki::cfg{ScriptSuffix} = ''
      if ( $Foswiki::cfg{ScriptSuffix} eq '.fcgi' );
    print STDERR
      "AUTOCONFIG: Found SCRIPT SUFFIX $Foswiki::cfg{ScriptSuffix} \n"
      if ( TRAUTO && $Foswiki::cfg{ScriptSuffix} );

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
        $Foswiki::cfg{$key} = File::Spec->rel2abs( $def->{dir}, $root );
        $Foswiki::cfg{$key} = abs_path( $Foswiki::cfg{$key} );
        ( $Foswiki::cfg{$key} ) = $Foswiki::cfg{$key} =~ m/^(.*)$/;    # untaint

        # Need to decode utf8 back to perl characters.  The file path operations
        # all worked with bytes, but Foswiki needs characters.
        # Can't use Foswiki::decode_utf8 - this is too early in initialization
        $Foswiki::cfg{$key} = NFC( Encode::decode_utf8( $Foswiki::cfg{$key} ) );

        print STDERR "AUTOCONFIG: $key = "
          . Encode::encode_utf8( $Foswiki::cfg{$key} ) . "\n"
          if (TRAUTO);

        if ( -d $Foswiki::cfg{$key} ) {
            if ( $def->{validate_file}
                && !-e "$Foswiki::cfg{$key}/$def->{validate_file}" )
            {
                $fatal .=
"\n{$key} (guessed $Foswiki::cfg{$key}) $Foswiki::cfg{$key}/$def->{validate_file} not found";
            }
        }
        elsif ( $def->{required} ) {
            $fatal .= "\n{$key} (guessed $Foswiki::cfg{$key})";
        }
        else {
            $warn .=
              "\n      * Note: {$key} could not be guessed. Set it manually!";
        }
    }

    # Bootstrap the Site Locale and CharSet
    _bootstrapSiteSettings();

    # Bootstrap the store related settings.
    _bootstrapStoreSettings();

    if ($fatal) {
        die <<EPITAPH;
Unable to bootstrap configuration. LocalSite.cfg could not be loaded,
and Foswiki was unable to guess the locations of the following critical
directories: $fatal
EPITAPH
    }

# Re-read Foswiki.spec *and Config.spec*. We need the Config.spec's
# to get a true picture of our defaults (notably those from
# JQueryPlugin. Without the Config.spec, no plugins get registered)
# Don't load LocalSite.cfg if it exists (should normally not exist when bootstrapping)
    Foswiki::Configure::Load::readConfig( 0, 0, 1, 1 );

    # Detect the OS and DetailedOS
    workOutOS();
    print STDERR
"AUTOCONFIG: Detected OS $Foswiki::cfg{OS}:  DetailedOS: $Foswiki::cfg{DetailedOS} \n"
      if (TRAUTO);

    $Foswiki::cfg{isVALID} = 1;
    setBootstrap();

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
    return ( $system_message || '' );

}

=begin TML

---++ StaticMethod _bootstrapSiteSettings()

Called by bootstrapConfig.  This handles the {Site} settings.

=cut

sub _bootstrapSiteSettings {

#   Guess a locale first.   This isn't necessarily used, but helps guess a CharSet, which is always used.

    require locale;
    $Foswiki::cfg{Site}{Locale} = setlocale(LC_CTYPE);

    print STDERR
"AUTOCONFIG: Set initial {Site}{Locale} to  $Foswiki::cfg{Site}{Locale}\n";
}

=begin TML

---++ StaticMethod _bootstrapStoreSettings()

Called by bootstrapConfig.  This handles the store specific settings.   This in turn
tests each Store Contib to determine if it's capable of bootstrapping.

=cut

sub _bootstrapStoreSettings {

    # Ask each installed store to bootstrap itself.

    my @stores = Foswiki::Configure::FileUtil::findPackages(
        'Foswiki::Contrib::*StoreContrib');

    foreach my $store (@stores) {
        eval("require $store");
        print STDERR $@ if ($@);
        unless ($@) {
            my $ok;
            eval('$ok = $store->can(\'bootstrapStore\')');
            if ($@) {
                print STDERR $@;
            }
            else {
                $store->bootstrapStore() if ($ok);
            }
        }
    }

    # Handle the common store settings managed by Core.  Important ones
    # guessed/checked here include:
    #  - $Foswiki::cfg{Store}{SearchAlgorithm}

    # Set PurePerl search on Windows, or FastCGI systems.
    if (
        (
               $Foswiki::cfg{Engine}
            && $Foswiki::cfg{Engine} =~ m/(FastCGI|Apache)/
        )
        || $^O eq 'MSWin32'
      )
    {
        $Foswiki::cfg{Store}{SearchAlgorithm} =
          'Foswiki::Store::SearchAlgorithms::PurePerl';
        print STDERR
"AUTOCONFIG: Detected FastCGI, mod_perl or MS Windows. {Store}{SearchAlgorithm} set to PurePerl\n"
          if (TRAUTO);
    }
    else {

        # SMELL: The fork to `grep goes into a loop in the unit tests
        # Not sure why, for now just default to pure perl bootstrapping
        # in the unit tests.
        if ( !$Foswiki::inUnitTestMode ) {

            # Untaint PATH so we can check for grep on the path
            my $x = $ENV{PATH} || '';
            $x =~ m/^(.*)$/;
            $ENV{PATH} = $1;
            my $resp = `grep -V 2>&1`;
            unless ( defined $resp ) {
                print STDERR
"AUTOCONFIG: Unable to find a valid 'grep' on the path. Forcing PurePerl search\n"
                  if (TRAUTO);
                $Foswiki::cfg{Store}{SearchAlgorithm} =
                  'Foswiki::Store::SearchAlgorithms::PurePerl';
            }
            else {
                print STDERR "AUTOCONFIG: Detected  "
                  . substr( $resp, 0, index( $resp, "\n" ) ) . "\n"
                  if (TRAUTO);
                $Foswiki::cfg{Store}{SearchAlgorithm} =
                  'Foswiki::Store::SearchAlgorithms::Forking';
                print STDERR
                  "AUTOCONFIG: {Store}{SearchAlgorithm} set to Forking\n"
                  if (TRAUTO);
            }
            $ENV{PATH} = $x;    # re-taint
        }
        else {
            $Foswiki::cfg{Store}{SearchAlgorithm} =
              'Foswiki::Store::SearchAlgorithms::PurePerl';
        }
    }

    # Detect the NFC / NDF normalization of the file system, and set
    # NFCNormalizeFilenames if needed.
    # SMELL: Really this should be done per web, both in data and pub.
    my $nfcok;
    if ( Foswiki::Configure::FileUtil->can('canNfcFilenames') ) {
        $nfcok =
          Foswiki::Configure::FileUtil::canNfcFilenames(
            $Foswiki::cfg{DataDir} );
    }
    if ( defined $nfcok && $nfcok == 1 ) {
        print STDERR "AUTOCONFIG: Data Storage allows NFC filenames\n"
          if (TRAUTO);
        $Foswiki::cfg{NFCNormalizeFilenames} = 0;
    }
    elsif ( defined($nfcok) && $nfcok == 0 ) {
        print STDERR "AUTOCONFIG: Data Storage enforces NFD filenames\n"
          if (TRAUTO);
        $Foswiki::cfg{NFCNormalizeFilenames} = 1
          ; #the configure's interface still shows unchecked - so, don't understand.. ;(
    }
    else {
        print STDERR "AUTOCONFIG: WARNING: Unable to detect Normalization.\n";
        $Foswiki::cfg{NFCNormalizeFilenames} = 1;    #enable too - safer as none
    }
}

=begin TML

---++ StaticMethod bootstrapWebSettings($script)

Called by bootstrapConfig.  This handles the web environment specific settings only:

   * ={DefaultUrlHost}=
   * ={ForceDefaultUrlHost}=
   * ={ScriptUrlPath}=
   * ={ScriptUrlPaths}{view}=
   * ={PubUrlPath}=

=cut

sub bootstrapWebSettings {
    my $script = shift;

    local $Data::Dumper::Sortkeys = 1;
    local $Data::Dumper::Varname  = 'ENV';
    print STDERR "AUTOCONFIG: Bootstrap Phase 2: "
      . Data::Dumper::Dumper( \%ENV )
      if (TRAUTO);

    # Cannot bootstrap the web side from CLI environments
    if ( $Foswiki::cfg{Engine} eq 'Foswiki::Engine::CLI' ) {
        $Foswiki::cfg{DefaultUrlHost} = 'http://localhost';
        $Foswiki::cfg{ScriptUrlPath}  = '/bin';
        $Foswiki::cfg{PubUrlPath}     = '/pub';
        print STDERR
          "AUTOCONFIG: Bootstrap Phase 2 bypassed! n/a in the CLI Environment\n"
          if (TRAUTO);
        return 'Phase 2 boostrap bypassed - n/a in CLI environment\n';
    }

    my $protocol = $ENV{HTTPS} ? 'https' : 'http';
    $Foswiki::cfg{ForceDefaultUrlHost} = 0;

# Figure out the DefaultUrlHost - First check if there is a proxy forwarding requests
# SMELL: This fails to account for multiple proxies where the forwarded_host is a list of proxies.
    if ( $ENV{HTTP_X_FORWARDED_HOST} ) {

# Detect if HTTPS in use.  Browsers appear to set the UPGRADE flag, and the json requests
# for configure all come in with a https referer.
        if (
            ( $ENV{QUERY_STRING} && $ENV{QUERY_STRING} =~ m/\bSSL=1\b/i )
            || (   $ENV{HTTP_REFERER}
                && $ENV{HTTP_REFERER} =~
                m#^https://\Q$ENV{HTTP_X_FORWARDED_HOST}\E# )
          )
        {
        # Browser is asking for https or refered from https, so override protcol
            $protocol = 'https';
            print STDERR "AUTOCONFIG: Detected HTTPS\n";
        }

        $Foswiki::cfg{DefaultUrlHost} =
          "$protocol://" . $ENV{HTTP_X_FORWARDED_HOST};
        $Foswiki::cfg{ForceDefaultUrlHost} =
          1;    # Force the URL host when behind a proxy

        print STDERR "AUTOCONFIG: Forcing DefaultUrlHost "
          . $Foswiki::cfg{DefaultUrlHost}
          . " from Proxy HTTP_X_FORWARDED_HOST "
          . $ENV{HTTP_X_FORWARDED_HOST} . " \n"
          if (TRAUTO);
    }
    elsif ( $ENV{HTTP_HOST} ) {
        $Foswiki::cfg{DefaultUrlHost} = "$protocol://$ENV{HTTP_HOST}";
        print STDERR
"AUTOCONFIG: Set DefaultUrlHost $Foswiki::cfg{DefaultUrlHost} from HTTP_HOST $ENV{HTTP_HOST} \n"
          if (TRAUTO);
    }
    elsif ( $ENV{SERVER_NAME} ) {
        $Foswiki::cfg{DefaultUrlHost} = "$protocol://$ENV{SERVER_NAME}";
        print STDERR
"AUTOCONFIG: Set DefaultUrlHost $Foswiki::cfg{DefaultUrlHost} from SERVER_NAME $ENV{SERVER_NAME} \n"
          if (TRAUTO);
    }
    elsif ( $ENV{SCRIPT_URI} ) {
        ( $Foswiki::cfg{DefaultUrlHost} ) =
          $ENV{SCRIPT_URI} =~ m#^(https?://[^/]+)/#;
        print STDERR
"AUTOCONFIG: Set DefaultUrlHost $Foswiki::cfg{DefaultUrlHost} from SCRIPT_URI $ENV{SCRIPT_URI} \n"
          if (TRAUTO);
    }
    else {

        # OK, so this is barfilicious. Think of something better.
        $Foswiki::cfg{DefaultUrlHost} = "$protocol://localhost";
        print STDERR
"AUTOCONFIG: barfilicious: Set DefaultUrlHost $Foswiki::cfg{DefaultUrlHost} \n"
          if (TRAUTO);
    }

# Examine the CGI path.   The 'view' script it typically removed from the
# URL when using "Short URLs.  If this BEGIN block is being run by
# 'view',  then $Foswiki::cfg{ScriptUrlPaths}{view} will be correctly
# bootstrapped.   If run for any other script, it will be set to a
# reasonable though probably incorrect default.
#
# In order to recover the correct view path when the script is 'configure',
# the ConfigurePlugin stashes the path to the view script into a session variable.
# and then recovers it.  When the jsonrpc script is called to save the configuration
# it then has the VIEWPATH parameter available.  If "view" was never called during
# configuration, then it will not be set correctly.
    my $path_info = $ENV{'PATH_INFO'}
      || '';    #SMELL Sometimes PATH_INFO appears to be undefined.
    print STDERR "AUTOCONFIG: REQUEST_URI is "
      . ( $ENV{REQUEST_URI} || '(undef)' ) . "\n"
      if (TRAUTO);

    # SCRIPT_URI is only present when mod_rewrite is enabled.
    print STDERR "AUTOCONFIG: SCRIPT_URI  is "
      . ( $ENV{SCRIPT_URI} || '(undef)' ) . " \n"
      if (TRAUTO);
    print STDERR "AUTOCONFIG: PATH_INFO   is $path_info \n" if (TRAUTO);
    print STDERR "AUTOCONFIG: ENGINE      is $Foswiki::cfg{Engine}\n"
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

# Detect any unwanted trailing path info,  to be stripped.  eg. bin/view/Main/WebHome
    my $suffix =
      ( defined $ENV{REQUEST_URI}
          && length( $ENV{REQUEST_URI} ) < length($path_info) )
      ? $ENV{REQUEST_URI}
      : $path_info;

    print STDERR "AUTOCONFIG: Detected suffix ($suffix)\n" if (TRAUTO);

    # Try to Determine the prefix of the script part of the URI.
    if ( $ENV{SCRIPT_URI} ) {
        if ( index( $ENV{SCRIPT_URI}, $Foswiki::cfg{DefaultUrlHost} ) eq 0 ) {
            $pfx =
              substr( $ENV{SCRIPT_URI},
                length( $Foswiki::cfg{DefaultUrlHost} ) );
            print STDERR "AUTOCONFIG: Calculated prefix $pfx from SCRIPT_URI\n"
              if (TRAUTO);
        }
    }

    # SCRIPT_URI is not set when mod_rewrite is not enabled
    elsif ( index( $ENV{REQUEST_URI}, $script ) == -1 ) {
        $pfx = $ENV{REQUEST_URI};
        print STDERR
          "AUTOCONFIG: Short URLs: Calculated Prefix $pfx from REQUEST_URI\n"
          if (TRAUTO);
    }
    else {
        $pfx =
          substr( $ENV{REQUEST_URI}, 0,
            length( $ENV{REQUEST_URI} ) - length($path_info) );
        print STDERR
          "AUTOCONFIG: Full URLs: Setting Prefix $pfx from REQUEST_URI \n"
          if (TRAUTO);
    }
    $pfx =~ s#\Q$suffix\E$## if ( defined $pfx );    # Strip any path_info

    unless ( defined $pfx ) {
        if ( my $idx = index( $ENV{REQUEST_URI}, $path_info ) ) {
            $pfx = substr( $ENV{REQUEST_URI}, 0, $idx + 1 );
        }
        $pfx = '' unless ( defined $pfx );
        print STDERR "AUTOCONFIG: URI Prefix is $pfx\n" if (TRAUTO);
    }

    # Work out the URL path for Short and standard URLs
    if ( $ENV{REQUEST_URI} =~ m{^(.*?)/$script(\b|$)} ) {
        print STDERR
"AUTOCONFIG: SCRIPT $script fully contained in REQUEST_URI $ENV{REQUEST_URI}, Not short URLs\n"
          if (TRAUTO);

        # Conventional URLs   with path and script
        $Foswiki::cfg{ScriptUrlPath} = $1;
        $Foswiki::cfg{ScriptUrlPaths}{view} =
          $1 . '/view' . $Foswiki::cfg{ScriptSuffix};

        # This might not work, depending on the websrver config,
        # but it's the best we can do
        my $lslash = rindex( $1, '/' );
        if ( $lslash >= 0 ) {
            $Foswiki::cfg{PubUrlPath} = $1;
            substr( $Foswiki::cfg{PubUrlPath}, $lslash + 1 ) = 'pub';
        }
        else {
            $Foswiki::cfg{PubUrlPath} = "$1/../pub";
        }
    }
    else {
        print STDERR "AUTOCONFIG: Building Short URL paths using prefix $pfx \n"
          if (TRAUTO);
        $Foswiki::cfg{ScriptUrlPath}        = $pfx . '/bin';
        $Foswiki::cfg{ScriptUrlPaths}{view} = $pfx;
        $Foswiki::cfg{PubUrlPath}           = $pfx . '/pub';
    }

    if (TRAUTO) {
        print STDERR
          "AUTOCONFIG: Using ScriptUrlPath $Foswiki::cfg{ScriptUrlPath} \n";
        print STDERR "AUTOCONFIG: Using {ScriptUrlPaths}{view} "
          . (
            ( defined $Foswiki::cfg{ScriptUrlPaths}{view} )
            ? $Foswiki::cfg{ScriptUrlPaths}{view}
            : 'undef'
          ) . "\n";
        print STDERR
          "AUTOCONFIG: Using PubUrlPath: $Foswiki::cfg{PubUrlPath} \n";
    }

    # Note: message is not I18N'd because there is no point; there
    # is no localisation in a default cfg derived from Foswiki.spec
    my $vp = '';
    $vp = '?VIEWPATH=' . $Foswiki::cfg{ScriptUrlPaths}{view}
      if ( defined $Foswiki::cfg{ScriptUrlPaths}{view} );
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

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2015 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root of
this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
