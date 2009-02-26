# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Configure::Load

---++ Purpose

This module consists of just a single subroutine =readConfig=.  It allows to
safely modify configuration variables _for one single run_ without affecting
normal Foswiki operation.

=cut

package Foswiki::Configure::Load;

our $TRUE = 1;

=begin TML

---++ StaticMethod readConfig()

In normal Foswiki operations as a web server this routine is called by the
=BEGIN= block of =Foswiki.pm=.  However, when benchmarking/debugging it can be
replaced by custom code which sets the configuration hash.  To prevent us from
overriding the custom code again, we use an "unconfigurable" key
=$cfg{ConfigurationFinished}= as an indicator.

Note that this method is called by Foswiki and configure, and *only* reads
Foswiki.spec= to get defaults. Other spec files (those for extensions) are
*not* read.

The assumption is that =configure= will be run when an extension is installed,
and that will add the config values to LocalSite.cfg, so no defaults are
needed. Foswiki.spec is still read because so much of the core code doesn't
provide defaults, and it would be silly to have them in two places anyway.

=cut

sub readConfig {
    return if $Foswiki::cfg{ConfigurationFinished};

    # Read LocalSite.cfg
    unless ( do 'Foswiki.spec' ) {
        die <<GOLLYGOSH;
Content-type: text/plain

Perl error when reading Foswiki.spec: $@
Please inform the site admin.
GOLLYGOSH
        exit 1;
    }

    # Read LocalSite.cfg
    unless ( do 'LocalSite.cfg' ) {
        die <<GOLLYGOSH;
Content-type: text/plain

Perl error when reading LocalSite.cfg: $@
Please inform the site admin.
GOLLYGOSH
        exit 1;
    }

    # If we got this far without definitions for key variables, then
    # we need to default them. otherwise we get peppered with
    # 'uninitialised variable' alerts later.

    foreach my $var qw( DataDir DefaultUrlHost PubUrlPath WorkingDir
      PubDir TemplateDir ScriptUrlPath LocalesDir ) {

        # We can't do this, because it prevents Foswiki being run without
        # a LocalSite.cfg, which we don't want
        # die "$var must be defined in LocalSite.cfg"
        #  unless( defined $Foswiki::cfg{$var} );
        $Foswiki::cfg{$var} = 'NOT SET' unless defined $Foswiki::cfg{$var};
      }

      # Expand references to $Foswiki::cfg vars embedded in the values of
      # other $Foswiki::cfg vars.
      expand( \%Foswiki::cfg );

    $Foswiki::cfg{ConfigurationFinished} = 1;

    # Alias TWiki cfg to Foswiki cfg for plugins and contribs
    *{'TWiki::cfg'} = *{'Foswiki::cfg'};
}

sub expand {
    my $hash = shift;

    foreach ( values %$hash ) {
        next unless $_;
        if ( ref($_) eq 'HASH' ) {
            expand( \%$_ );
        }
        else {
            s/(\$Foswiki::cfg{[[A-Za-z0-9{}]+})/eval $1||'undef'/ge;
        }
    }
}

=begin TML

---++ StaticMethod expandValue($string) -> $boolean

Expands references to Foswiki configuration items which occur in the
value of other configuration items.  Use expand($hashref) if the item
is not a plain scalar.

Happens to return true if something has been expanded, though I don't
know whether you would want that.  The replacement is done in-place,

=cut

sub expandValue {
    $_[0] =~ s/(\$Foswiki::cfg{[[A-Za-z0-9{}]+})/eval $1||'undef'/ge;
}

=begin TML

---++ StaticMethod readDefaults() -> \@errors

This is only called by =configure= to initialise the Foswiki config hash with
default values from the .spec files.

Normally all configuration values come from LocalSite.cfg. However when
=configure= runs it has to get default values for config vars that have not
yet been saved to =LocalSite.cfg=.

Returns a reference to a list of the errors it saw.

SEE ALSO: Foswiki::Configure::FoswikiCfg::load

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
        _loadDefaultsFrom( "$dir/Foswiki/Plugins", $root, \%read, \@errors );
        _loadDefaultsFrom( "$dir/Foswiki/Contrib", $root, \%read, \@errors );
        _loadDefaultsFrom( "$dir/TWiki/Plugins",   $root, \%read, \@errors );
        _loadDefaultsFrom( "$dir/TWiki/Contrib",   $root, \%read, \@errors );
    }
    if ( defined %TWiki::cfg ) {

        # We had some TWiki plugins, need to map their config to Foswiki
        sub mergeHash {

          # Merges the keys in the right hashref to the ones in the left hashref
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

                         # The item isn't in the current list, add it at the end
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
    }    # define %TWiki::cfg

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
__DATA__
# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 Foswiki Contributors. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 1999-2006 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution. NOTE: Please extend that file, not this notice.
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
