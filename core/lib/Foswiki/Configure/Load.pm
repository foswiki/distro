# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Configure::Load

Handling for loading configuration information (Foswiki.spec, Config.spec and
LocalSite.cfg) as efficiently and flexibly as possible.

This reads *values* from these files and does *not* parse the
structured comments or build a spec database. For that, see LoadSpec.pm

=cut

package Foswiki::Configure::Load;

use strict;
use warnings;
use Cwd qw( abs_path );
use File::Basename;
use File::Spec;

# Enable to trace auto-configuration (Bootstrap)
use constant TRAUTO => 1;

# This should be the one place in Foswiki that knows the syntax of valid
# configuration item keys. Only simple scalar hash keys are supported.
#
our $ITEMREGEX = qr/(?:\{(?:'(?:\\.|[^'])+'|"(?:\\.|[^"])+"|[A-Za-z0-9_]+)\})+/;

# Generic booleans, used in some older LSC's
our $TRUE  = 1;
our $FALSE = 0;

# Bootstrap works out the correct values of these keys
my @BOOTSTRAP =
  qw( {DataDir} {DefaultUrlHost} {PubUrlPath} {ToolsDir} {WorkingDir}
  {PubDir} {TemplateDir} {ScriptDir} {ScriptUrlPath} {ScriptUrlPaths}{view} {ScriptSuffix} {LocalesDir} );

# Configuration items that have been deprecated and must be mapped to
# new configuration items. The value is mapped unchanged.
our %remap = (
    '{StoreImpl}'           => '{Store}{Implementation}',
    '{AutoAttachPubFiles}'  => '{RCS}{AutoAttachPubFiles}',
    '{QueryAlgorithm}'      => '{Store}{QueryAlgorithm}',
    '{SearchAlgorithm}'     => '{Store}{SearchAlgorithm}',
    '{RCS}{FgrepCmd}'       => '{Store}{FgrepCmd}',
    '{RCS}{EgrepCmd}'       => '{Store}{EgrepCmd}',
    '{RCS}{overrideUmask}'  => '{Store}{overrideUmask}',
    '{RCS}{dirPermission}'  => '{Store}{dirPermission}',
    '{RCS}{filePermission}' => '{Store}{filePermission}',
    '{RCS}{WorkAreaDir}'    => '{Store}{WorkAreaDir}'
);

=begin TML

---++ StaticMethod readConfig([$noexpand][,$nospec][,$config_spec])

In normal Foswiki operations as a web server this method is called by the
=BEGIN= block of =Foswiki.pm=.  However, when benchmarking/debugging it can be
replaced by custom code which sets the configuration hash.  To prevent us from
overriding the custom code again, we use an "unconfigurable" key
=$cfg{ConfigurationFinished}= as an indicator.

Note that this method is called by Foswiki and configure, and *only* reads
=Foswiki.spec= to get defaults. Other spec files (those for extensions) are
*not* read.

The assumption is that =configure= will be run when an extension is installed,
and that will add the config values to LocalSite.cfg, so no defaults are
needed. Foswiki.spec is still read because so much of the core code doesn't
provide defaults, and it would be silly to have them in two places anyway.

   * =$noexpand= - suppress expansion of $Foswiki vars embedded in
     values.
   * =$nospec= - can be set when the caller knows that Foswiki.spec
     has already been read.
   * =$config_spec - if set, will also read Config.spec files located
     using the standard methods (iff !$nospec). Slow.
=cut

sub readConfig {
    my ( $noexpand, $nospec, $config_spec ) = @_;

    # To prevent us from overriding the custom code in test mode
    return if $Foswiki::cfg{ConfigurationFinished};

    # Assume LocalSite.cfg is valid - will be set false if errors detected.
    my $validLSC = 1;

    # Read Foswiki.spec and LocalSite.cfg
    # (Suppress Foswiki.spec if already read)

    my @files = qw( Foswiki.spec LocalSite.cfg );
    if ($nospec) {
        shift @files;
    }
    elsif ($config_spec) {
        foreach my $dir (@INC) {
            foreach my $subdir ( 'Foswiki/Plugins', 'Foswiki/Contrib' ) {
                my $d;
                next unless opendir( $d, "$dir/$subdir" );
                my %read;
                foreach
                  my $extension ( grep { !/^\./ && !/^Empty/ } readdir $d )
                {
                    next if $read{$extension};
                    $extension =~ /(.*)/;    # untaint
                    my $file = "$dir/$subdir/$1/Config.spec";
                    next unless -e $file;
                    push( @files, $file );
                    $read{$extension} = 1;
                }
                closedir($d);
            }
        }
    }

    for my $file (@files) {
        unless ( my $return = do $file ) {
            my $errorMessage;
            if ($@) {
                $errorMessage = "Failed to 'do' $file: $@";
                print STDERR "$errorMessage \n";
                next;
            }
            next if $file =~ /Config\.spec$/;
            if ( not defined $return ) {
                print STDERR
"Could not 'do' $file: $! \n - This might be okay if file LocalSite.cfg does not exist in a new installation.\n";
                unless ( $! == 2 && $file eq 'LocalSite.cfg' ) {

                    # LocalSite.cfg doesn't exist, which is OK
                    $errorMessage = "Could not 'do' $file: $!";
                }
                $validLSC = 0;
            }
            elsif ( not $return eq '1' ) {
                print STDERR
                  "Running file $file returned  unexpected results: $return \n";
                $errorMessage = "Could not 'do' $file" unless $return;
            }
            if ($errorMessage) {
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
    if ( exists $Foswiki::cfg{StoreImpl} ) {
        $Foswiki::cfg{Store}{Implementation} =
          'Foswiki::Store::' . $Foswiki::cfg{StoreImpl};
        delete $Foswiki::cfg{StoreImpl};
    }
    foreach my $el ( keys %remap ) {
        if ( eval 'exists $Foswiki::cfg' . $el ) {
            eval <<CODE;
\$Foswiki::cfg$remap{$el}=\$Foswiki::cfg$el;
delete \$Foswiki::cfg$el;
CODE
        }
    }

    # Expand references to $Foswiki::cfg vars embedded in the values of
    # other $Foswiki::cfg vars.
    expandValue( \%Foswiki::cfg ) unless $noexpand;

    $Foswiki::cfg{ConfigurationFinished} = 1;

    if ( $^O eq 'MSWin32' ) {

        #force paths to use '/'
        $Foswiki::cfg{PubDir}      =~ s|\\|/|g;
        $Foswiki::cfg{DataDir}     =~ s|\\|/|g;
        $Foswiki::cfg{ToolsDir}    =~ s|\\|/|g;
        $Foswiki::cfg{ScriptDir}   =~ s|\\|/|g;
        $Foswiki::cfg{TemplateDir} =~ s|\\|/|g;
        $Foswiki::cfg{LocalesDir}  =~ s|\\|/|g;
        $Foswiki::cfg{WorkingDir}  =~ s|\\|/|g;
    }

    # Alias TWiki cfg to Foswiki cfg for plugins and contribs
    *TWiki::cfg = \%Foswiki::cfg;

    # Explicit return true if we've completed the load
    return $validLSC;
}

=begin TML

---++ StaticMethod expandValue($datum [, $mode])

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
    my $undef;
    _expandValue( $_[0], ( $_[1] || 0 ), $undef );

    $_[0] = undef if ($undef);
}

# $_[0] - value being expanded
# $_[1] - $mode
# $_[2] - $undef (return)
sub _expandValue {
    if ( ref( $_[0] ) eq 'HASH' ) {
        expandValue( $_, $_[1] ) foreach ( values %{ $_[0] } );
    }
    elsif ( ref( $_[0] ) eq 'ARRAY' ) {
        expandValue( $_, $_[1] ) foreach ( @{ $_[0] } );

        # Can't do this, because Windows uses an object (Regexp) for regular
        # expressions.
        #    } elsif (ref($_[0])) {
        #        die("Can't handle a ".ref($_[0]));
    }
    else {
        1 while ( defined( $_[0] )
            && $_[0] =~
            s/(\$Foswiki::cfg$ITEMREGEX)/_handleExpand($1, @_[1,2])/geso );
    }
}

# Used to expand the $Foswiki::cfg variable in the expand* routines.
# $_[0] - $item
# $_[1] - $mode
# $_[2] - $undef
sub _handleExpand {
    my $val = eval $_[0];
    die "Error expanding $_[0]: $@" if ($@);

    return $val                                      if ( defined $val );
    return 'undef'                                   if ( !$_[1] );
    return ''                                        if ( $_[1] == 2 );
    die "Undefined value in expanded string $_[0]\n" if ( $_[1] == 3 );
    $_[2] = 1;
    return '';
}

=begin TML

---++ StaticMethod readDefaults() -> \@errors

This is only called by =configure= to initialise the Foswiki config hash with
default values from the .spec files.

Normally all configuration values come from LocalSite.cfg. However when
=configure= runs it has to get default values for config vars that have not
yet been saved to =LocalSite.cfg=.

Returns a reference to a list of the errors it saw.

SEE ALSO: Foswiki::Configure::LoadSpec

=cut

sub readDefaults {
    my %read = ();
    my @errors;

    eval {
        do 'Foswiki.spec';
        $read{'Foswiki.spec'} = $INC{'Foswiki.spec'};
    };
    push( @errors, $@ ) if ($@);
    foreach my $dir (@INC) {
        my $root;    # SMELL: Not used
        _loadDefaultsFrom( "$dir/Foswiki/Plugins", $root, \%read, \@errors );
        _loadDefaultsFrom( "$dir/Foswiki/Contrib", $root, \%read, \@errors );
        _loadDefaultsFrom( "$dir/TWiki/Plugins",   $root, \%read, \@errors );
        _loadDefaultsFrom( "$dir/TWiki/Contrib",   $root, \%read, \@errors );
    }

    # SMELL: This will create the %TWiki::cfg
    # But as it ought to be aliased to %Foswiki::cfg, it's not a big deal
    # XXX: Do we still need this code?
    if ( %TWiki::cfg && \%TWiki::cfg != \%Foswiki::cfg ) {

        # We had some TWiki plugins, need to map their config to Foswiki
        sub mergeHash {

            # Merges the keys in the right hashref to the ones in the
            # left hashref
            my ( $left, $right, $errors ) = @_;
            while ( my ( $key, $value ) = each %$right ) {
                if ( exists $left->{$key} ) {
                    if ( ref($value) ne ref( $left->{$key} ) ) {
                        push @$errors,
                            'Trying to overwrite $Foswiki::cfg{'
                          . $key
                          . '} with its $TWiki::cfg version ('
                          . $value . ')';
                    }
                    elsif ( ref($value) eq 'SCALAR' ) {
                        $left->{$key} = $value;
                    }
                    elsif ( ref($value) eq 'HASH' ) {
                        $left->{$key} =
                          mergeHash( $left->{$key}, $value, $errors );
                    }
                    elsif ( ref($value) eq 'ARRAY' ) {

                        # It's an array. try to be smart
                        # SMELL: Ideally, it should keep order too
                        foreach my $item (@$value) {
                            unless ( grep /^$item$/, @{ $left->{$key} } ) {

                                # The item isn't in the current list,
                                # add it at the end
                                unshift @{ $left->{$key} }, $item;
                            }
                        }
                    }
                    else {

                        # It's something else (GLOB, coderef, ...)
                        push @$errors,
                            '$TWiki::cfg{'
                          . $key
                          . '} is a reference to a'
                          . ref($value)
                          . '. No idea how to merge that, sorry.';
                    }
                }
                else {

                    # We don't already have such a key in the Foswiki scope
                    $left->{$key} = $value;
                }
            }
            return $left;
        }
        mergeHash \%Foswiki::cfg, \%TWiki::cfg, \@errors;
    }

    return \@errors;
}

sub _loadDefaultsFrom {
    my ( $dir, $root, $read, $errors ) = @_;

    return unless opendir( D, $dir );
    foreach my $extension ( grep { !/^\./ } readdir D ) {
        $extension =~ /(.*)/;
        $extension = $1;    # untaint
        next if $read->{$extension};
        my $file = "$dir/$extension/Config.spec";
        next unless -e $file;
        eval { do $file; };
        push( @$errors, $@ ) if ($@);
        $read->{$extension} = $file;
    }
    closedir(D);
}

=begin TML

---++ StaticMethod bootstrapConfig()

This routine is called from Foswiki.pm BEGIN block to discover the mandatory
settings for operation when a LocalSite.cfg could not be found.

=cut

sub bootstrapConfig {
    my $noload = shift;

    # Failed to read LocalSite.cfg
    # Clear out $Foswiki::cfg to allow variable expansion to work
    # when reloading Foswiki.spec et al.
    # SMELL: have to keep {Engine} as this is defined by the
    # script (smells of a hack).
    %Foswiki::cfg = ( Engine => $Foswiki::cfg{Engine} );

    # Try to repair $Foswiki::cfg to a minimal configuration,
    # using paths and URLs relative to this request. If URL
    # rewriting is happening in the web server this is likely
    # to go down in flames, but it gives us the best chance of
    # recovering. We need to guess values for all the vars that
    # woudl trigger "undefined" errors
    eval "require FindBin";
    die "Could not load FindBin to support configuration recovery: $@"
      if $@;
    FindBin::again();    # in case we are under mod_perl or similar
    $FindBin::Bin =~ /^(.*)$/;
    my $bin = $1;
    $FindBin::Script =~ /^(.*)$/;
    my $script = $1;
    print STDERR
      "AUTOCONFIG: Found Bin dir: $bin, Script name: $script using FindBin\n"
      if (TRAUTO);

    $Foswiki::cfg{ScriptSuffix} = ( fileparse( $script, qr/\.[^.]*/ ) )[2];
    print STDERR
      "AUTOCONFIG: Found SCRIPT SUFFIX $Foswiki::cfg{ScriptSuffix} \n"
      if ( TRAUTO && $Foswiki::cfg{ScriptSuffix} );

    my $protocol = $ENV{HTTPS} ? 'https' : 'http';
    if ( $ENV{HTTP_HOST} ) {
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
    if ( $ENV{SCRIPT_NAME} ) {
        print STDERR "AUTOCONFIG: Found SCRIPT $ENV{SCRIPT_NAME} \n"
          if (TRAUTO);

        if ( $ENV{SCRIPT_NAME} =~ m{^(.*?)/$script(\b|$)} ) {

            # Conventional URLs   with path and script
            $Foswiki::cfg{ScriptUrlPath} = $1;
            $Foswiki::cfg{ScriptUrlPaths}{view} =
              $1 . '/view' . $Foswiki::cfg{ScriptSuffix};

            # This might not work, depending on the websrver config,
            # but it's the best we can do
            $Foswiki::cfg{PubUrlPath} = "$1/../pub";
        }
        else {
            # Short URLs but with a path
            print STDERR "AUTOCONFIG: Found path, but no script. short URLs \n"
              if (TRAUTO);
            $Foswiki::cfg{ScriptUrlPath}        = $ENV{SCRIPT_NAME} . '/bin';
            $Foswiki::cfg{ScriptUrlPaths}{view} = $ENV{SCRIPT_NAME};
            $Foswiki::cfg{PubUrlPath}           = $ENV{SCRIPT_NAME} . '/pub';
        }
    }
    else {
        #  No script, no path,  shortest URLs
        print STDERR "AUTOCONFIG: No path, No script, probably shorter URLs \n"
          if (TRAUTO);
        $Foswiki::cfg{ScriptUrlPaths}{view} = '';
        $Foswiki::cfg{ScriptUrlPath}        = '/bin';
        $Foswiki::cfg{PubUrlPath}           = '/pub';
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
            validate_file => 'configure.tmpl'
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

        print STDERR "AUTOCONFIG: $key = $Foswiki::cfg{$key} \n"
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
    Foswiki::Configure::Load::readConfig( 0, 0, 1 ) unless ($noload);

    Foswiki::_workOutOS();

    $Foswiki::cfg{isVALID}         = 1;
    $Foswiki::cfg{isBOOTSTRAPPING} = 1;
    push( @{ $Foswiki::cfg{BOOTSTRAP} }, @BOOTSTRAP );
    eval 'require Foswiki::Plugins::ConfigurePlugin';
    die
      "LocalSite.cfg load failed, and ConfigurePlugin could not be loaded: $@"
      if $@;

    # Note: message is not I18N'd because there is no point; there
    # is no localisation in a default cfg derived from Foswiki.spec
    my $system_message = <<BOOTS;
 *WARNING !LocalSite.cfg could not be found, or failed to load.* %BR%This
Foswiki is running using a bootstrap configuration worked
out by detecting the layout of the installation. Any requests made to this
Foswiki will be treated as requests made by an administrator with full rights
to make changes! You should either:
   * correct any permissions problems with an existing !LocalSite.cfg (see the webserver error logs for details), or
   * visit [[%SCRIPTURL{configure}%?VIEWPATH=$Foswiki::cfg{ScriptUrlPaths}{view}][configure]] as soon as possible to generate a new one.
BOOTS

    if ($warn) {
        chomp $system_message;
        $system_message .= $warn . "\n";
    }
    return ( $system_message || '' );

}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
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
