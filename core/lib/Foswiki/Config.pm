# See bottom of file for license and copyright information

package Foswiki::Config;
use v5.14;

use Assert;
use Foswiki ();

use Moo;
use namespace::clean;
extends qw(Foswiki::Object);

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

has data => (
    is      => 'rw',
    default => sub { {} },
);

# What files we read the config from in the order of reading.
has files => (
    is      => 'rw',
    default => sub { [] },
);

# failedConfig keeps the name of the failed config or spec file.
has failedConfig => ( is => 'rw', );
has noExpand     => ( is => 'rw', default => 0, );
has noSpec       => ( is => 'rw', default => 0, );
has configSpec   => ( is => 'rw', default => 0, );
has noLocal      => ( is => 'rw', default => 0, );

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

    # Alias ::cfg for compatibility. Though $app->cfg should be preferred way of
    # accessing config.
    *Foswiki::cfg = $this->data;
    *TWiki::cfg   = $this->data;

    $this->data->{isVALID} = $this->readConfig;
}

sub _workOutOS {
    my $this = shift;
    unless ( $this->data->{DetailedOS} ) {
        $this->data->{DetailedOS} = $^O;
    }
    return if $this->data->{OS};
    if ( $this->data->{DetailedOS} =~ m/darwin/i ) {    # MacOS X
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

    # To prevent us from overriding the custom code in test mode
    return 1 if $this->data->{ConfigurationFinished};

    # Assume LocalSite.cfg is valid - will be set false if errors detected.
    my $validLSC = 1;

    # Read Foswiki.spec and LocalSite.cfg
    # (Suppress Foswiki.spec if already read)

    # Old configs might not bootstrap the OS settings, so set if needed.
    $this->_workOutOS unless ( $this->data->{OS} && $this->data->{DetailedOS} );

    unless ( $this->noSpec ) {
        push @{ $this->files }, 'Foswiki.spec';
    }
    if ( !$this->noSpec && $this->configSpec ) {
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
    unless ( $this->noLocal ) {
        push @{ $this->files }, 'LocalSite.cfg';
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
                unless ( $! == 2 && $file eq 'LocalSite.cfg' ) {

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
    $this->expandValue( $this->data ) unless $this->noExpand;

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
