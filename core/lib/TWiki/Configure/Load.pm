# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2006 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
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

=pod

---+ package TWiki::Configure::Load

---++ Purpose

This module consists of just a single subroutine =readConfig=.  It allows to
safely modify configuration variables _for one single run_ without affecting
normal TWiki operation.

=cut

package TWiki::Configure::Load;

our $TRUE = 1;

=pod

---++ StaticMethod readConfig()

In normal TWiki operations as a web server this routine is called by the
=BEGIN= block of =TWiki.pm=.  However, when benchmarking/debugging it can be
replaced by custom code which sets the configuration hash.  To prevent us from
overriding the custom code again, we use an "unconfigurable" key
=$cfg{ConfigurationFinished}= as an indicator.

Note that this method is called by TWiki and configure, and *only* reads
TWiki.spec= to get defaults. Other spec files (those for extensions) are
*not* read.

The assumption is that =configure= will be run when an extension is installed,
and that will add the config values to LocalSite.cfg, so no defaults are
needed. TWiki.spec is still read because so much of the core code doesn't
provide defaults, and it would be silly to have them in two places anyway.

=cut

sub readConfig {
    return if $TWiki::cfg{ConfigurationFinished};

    # Read LocalSite.cfg
    unless (do 'TWiki.spec') {
        die <<GOLLYGOSH;
Content-type: text/plain

Perl error when reading TWiki.spec: $@
Please inform the site admin.
GOLLYGOSH
        exit 1;
    }

    # Read LocalSite.cfg
    unless (do 'LocalSite.cfg') {
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
        # We can't do this, because it prevents TWiki being run without
        # a LocalSite.cfg, which we don't want
        # die "$var must be defined in LocalSite.cfg"
        #  unless( defined $TWiki::cfg{$var} );
        $TWiki::cfg{$var} = 'NOT SET' unless defined $TWiki::cfg{$var};
    }

    # Expand references to $TWiki::cfg vars embedded in the values of
    # other $TWiki::cfg vars.
    expand(\%TWiki::cfg);

    $TWiki::cfg{ConfigurationFinished} = 1;
}

sub expand {
    my $hash = shift;

    foreach ( values %$hash ) {
        next unless $_;
        if (ref($_) eq 'HASH') {
            expand(\%$_);
        } else {
            s/(\$TWiki::cfg{[[A-Za-z0-9{}]+})/eval $1||'undef'/ge;
        }
    }
}


=pod

---++ StaticMethod expandValue($string) -> $boolean

Expands references to TWiki configuration items which occur in the
value of other configuration items.  Use expand($hashref) if the item
is not a plain scalar.

Happens to return true if something has been expanded, though I don't
know whether you would want that.  The replacement is done in-place,

=cut

sub expandValue {
    $_[0] =~ s/(\$TWiki::cfg{[[A-Za-z0-9{}]+})/eval $1||'undef'/ge;
}

=pod

---++ StaticMethod readDefaults() -> \@errors

This is only called by =configure= to initialise the TWiki config hash with
default values from the .spec files.

Normally all configuration values come from LocalSite.cfg. However when
=configure= runs it has to get default values for config vars that have not
yet been saved to =LocalSite.cfg=.

Returns a reference to a list of the errors it saw.

SEE ALSO: TWiki::Configure::TWikiCfg::load

=cut

sub readDefaults {
    my %read = ( );
    my @errors;

    eval {
        do 'TWiki.spec';
        $read{'TWiki.spec'}  =  $INC{'TWiki.spec'};
    };
    push(@errors, $@) if ($@);
    foreach my $dir (@INC) {
        _loadDefaultsFrom("$dir/TWiki/Plugins", $root, \%read, \@errors);
        _loadDefaultsFrom("$dir/TWiki/Contrib", $root, \%read, \@errors);
    }
    return \@errors;
}

sub _loadDefaultsFrom {
    my ($dir, $root, $read, $errors) = @_;

    return unless opendir(D, $dir);
    foreach my $extension ( grep { !/^\./ } readdir D) {
        $extension =~ /(.*)/; $extension = $1; # untaint
        next if $read->{$extension};
        my $file = "$dir/$extension/Config.spec";
        next unless -e $file;
        eval {
            do $file;
        };
        push(@$errors, $@) if ($@);
        $read->{$extension} = $file;
    }
    closedir(D);
}

1;
