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

# This should be the one place in Foswiki that knows the syntax of valid
# configuration item keys. Only simple scalar hash keys are supported.
#
our $ITEMREGEX = qr/(?:\{(?:'(?:\\.|[^'])+'|"(?:\\.|[^"])+"|[A-Za-z0-9_]+)\})+/;

# Generic booleans, used in some older LSC's
our $TRUE  = 1;
our $FALSE = 0;

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

---++ StaticMethod readConfig([$noexpand][,$nospec])

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

=cut

sub readConfig {
    my $noexpand = shift;
    my $nospec   = shift;

    return if $Foswiki::cfg{ConfigurationFinished};

    # Assume LocalSite.cfg is valid - will be set false if errors detected.
    my $validLSC = 1;

    # Read Foswiki.spec and LocalSite.cfg
    # (Suppress Foswiki.spec if already read)

    my @files = qw( Foswiki.spec LocalSite.cfg );
    shift @files if ($nospec);

    for my $file (@files) {
        unless ( my $return = do $file ) {
            my $errorMessage;
            if ($@) {
                $errorMessage = "Could not parse $file: $@";
                print STDERR "$errorMessage \n";
            }
            elsif ( not defined $return ) {
                print STDERR
"Could not 'do' $file: $! \n - This might be okay if file LocalSite.cfg does not exist in a new installation.\n";
                unless ( $! == 2 && $file eq 'LocalSite.cfg' ) {

                    # LocalSite.cfg doesn't exist, which is OK
                    $errorMessage = "Could not do $file: $!";
                }
                $validLSC = 0;
            }
            elsif ( not $return eq '1' ) {
                print STDERR
                  "Running file $file returned  unexpected results: $return \n";
                $errorMessage = "Could not run $file" unless $return;
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

    # If we got this far without definitions for key variables, then
    # we need to default them. Otherwise we get peppered with
    # 'uninitialised variable' alerts later.

    foreach my $var (
        qw( DataDir DefaultUrlHost PubUrlPath ToolsDir WorkingDir
        PubDir TemplateDir ScriptDir ScriptUrlPath LocalesDir )
      )
    {

        # We can't do this, because it prevents Foswiki being run without
        # a LocalSite.cfg, which we don't want
        # die "$var must be defined in LocalSite.cfg"
        #  unless( defined $Foswiki::cfg{$var} );
        unless ( defined $Foswiki::cfg{$var} ) {
            $Foswiki::cfg{$var} = 'NOT SET';
            $validLSC = 0;
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

---++ StaticMethod expandValue($datum, $mode)

Expands references to Foswiki configuration items which occur in the
values configuration items contained within the datum, which may be a
hash reference or a scalar value. The replacement is done in-place.

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
