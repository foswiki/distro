# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Configure::Checkers::BasicSanity

Checker that implements the basic sanity checks that configure performs.

=cut

package Foswiki::Configure::Checkers::BasicSanity;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
use Foswiki::Configure::Util    ();
our @ISA = ('Foswiki::Configure::Checker');

sub new {
    my ( $class, $item ) = @_;
    my $this = $class->SUPER::new($item);
    $this->{LocalSiteDotCfg} = undef;
    $this->{errors}          = 0;
    $this->{badLSC}          = 0;

    return $this;
}

=begin TML

---++ ObjectMethod insane() -> $boolean

Return true if we have fatal errors

=cut

sub insane() {
    my $this = shift;
    return $this->{errors};
}

=begin TML

---++ ObjectMethod lscIsBad() -> $boolean

Return true if LocalSite.cfg was found to be bad.

=cut

sub lscIsBad() {
    my $this = shift;
    return $this->{badLSC};
}

# Override Foswiki::Configure::Checker
# Perform basic sanity checks, returning a HTML condition statement.

sub check {
    my $this   = shift;
    my $result = '';
    $this->{badLSC} = 0;

    $this->{LocalSiteDotCfg} =
      Foswiki::Configure::Util::findFileOnPath('LocalSite.cfg');
    unless ( $this->{LocalSiteDotCfg} ) {
        $this->{LocalSiteDotCfg} =
          Foswiki::Configure::Util::findFileOnPath('Foswiki.spec')
          || '';
        $this->{LocalSiteDotCfg} =~ s/Foswiki\.spec/LocalSite.cfg/;
    }

    # Get default settings by reading .spec files
    require Foswiki::Configure::Load;
    Foswiki::Configure::Load::readDefaults(); #Foswiki.spec + plugins & contribs

    $Foswiki::defaultCfg = _copy( \%Foswiki::cfg );

    if ( !$this->{LocalSiteDotCfg} ) {
        $this->{errors}++;
        $result .= <<HERE;
Could not find where LocalSite.cfg is supposed to go.
Edit your LocalLib.cfg and set \$twikiLibPath to point to the 'lib' directory
for your install.
Please correct this error before continuing.
HERE
    }
    elsif ( -e $this->{LocalSiteDotCfg} ) {
        eval { Foswiki::Configure::Load::readConfig( 1, 1 ); }; # Don't expand or re-read Foswiki.spec.
        if ($@) {
            $this->{errors}++;
            $result .= <<HERE;
Existing configuration file has a problem
that is causing a Perl error - the following message(s) was generated:
<pre>$@</pre>
<b>You can continue, but configure will not pick up any of the existing
settings from this file and your previous configuration will be lost.</b>
Manually edit and correct your <tt>$this->{LocalSiteDotCfg}</tt> file if you
wish to preserve your prior configuration.
HERE
            $this->{badLSC} = 1;
        }
        elsif ( !-w $this->{LocalSiteDotCfg} ) {
            $this->{errors}++;
            $result .= <<HERE;
Cannot write to existing configuration file
$this->{LocalSiteDotCfg} is not writable.
You can view the configuration, but you will not be able to save.
Check the file permissions.
HERE
        }
        elsif ( ( my $mess = $this->_checkCfg( \%Foswiki::cfg ) ) ) {
            $this->{errors}++;
            $result .= <<HERE;
The existing configuration file
$this->{LocalSiteDotCfg} doesn't seem to contain a good configuration
for Foswiki. The following problems were found:<br>
$mess
<b>You can continue, but configure will not pick up any of the existing
settings from this file and your previous configuration will be lost.</b>
Manually edit and correct your <tt>$this->{LocalSiteDotCfg}</tt> file if you
wish to preserve your prior configuration.
HERE
        }

    }
    else {

        # Doesn't exist (yet)
        my $errs = $this->checkCanCreateFile( $this->{LocalSiteDotCfg} );

        if ($errs) {
            $this->{errors}++;
            $result .= <<HERE;
Configuration file $this->{LocalSiteDotCfg} does not exist, and I cannot
write a new configuration file due to these errors:
<pre/>$errs<pre>
You can view the default configuration, but you will not be able to save.
HERE
            $this->{badLSC} = 1;
        }
        else {
            $result .= <<HERE;
Could not find existing configuration file <code>$this->{LocalSiteDotCfg}</code>.
HERE
            $this->{badLSC} = 1;
        }
    }

    # If we got this far without definitions for key variables, then
    # we need to default them. otherwise we get peppered with
    # 'uninitialised variable' alerts later.
    foreach my $var (
        qw( DataDir DefaultUrlHost PubUrlPath
        PubDir TemplateDir ScriptUrlPath LocalesDir SafeEnvPath )
      )
    {

        # NOT SET tells the checker to try and guess the value later on
        $Foswiki::cfg{$var} = 'NOT SET' unless defined $Foswiki::cfg{$var};
    }

    # Make %ENV safer for CGI - Assign a safe default for SafeEnvPath
    $Foswiki::cfg{DETECTED}{originalPath} = $ENV{PATH} || '';

    if ( $Foswiki::cfg{SafeEnvPath} eq 'NOT SET' ) {

        # SMELL:  Untaint to get past the first run.  It will be
        # Overridden to the SafeEnvPath after first save
        ( $ENV{PATH} ) = $ENV{PATH} =~ m/^(.*)$/;
    }
    else {
        $ENV{PATH} = $Foswiki::cfg{SafeEnvPath};
    }

    delete @ENV{qw( IFS CDPATH ENV BASH_ENV )};

    return $result;
}

sub _copy {
    my $n = shift;

    return unless defined($n);

    if ( UNIVERSAL::isa( $n, 'ARRAY' ) ) {
        my @new;
        for ( 0 .. $#$n ) {
            push( @new, _copy( $n->[$_] ) );
        }
        return \@new;
    }
    elsif ( UNIVERSAL::isa( $n, 'HASH' ) ) {
        my %new;
        for ( keys %$n ) {
            $new{$_} = _copy( $n->{$_} );
        }
        return \%new;
    }
    elsif ( UNIVERSAL::isa( $n, 'Regexp' ) ) {
        return qr/$n/;
    }
    elsif ( UNIVERSAL::isa( $n, 'REF' ) || UNIVERSAL::isa( $n, 'SCALAR' ) ) {
        $n = _copy($$n);
        return \$n;
    }
    else {
        return $n;
    }
}

# Check that an existing LocalSite.cfg doesn't contain crap.

sub _checkCfg {
    my ( $this, $entry, $keys ) = @_;
    $keys ||= '';
    my $mess = '';

    if ( ref($entry) eq 'HASH' ) {
        foreach my $el ( keys %$entry ) {
            $mess .= $this->_checkCfg( $entry->{$el}, "$keys\{$el}" );
        }
    }
    elsif ( ref($entry) eq 'ARRAY' ) {
        foreach my $i ( 0 .. scalar(@$entry) ) {
            $mess .= $this->_checkCfg( $entry->[$i], "$keys\[$i]" );
        }
    }
    else {
        if ( defined $entry && $entry =~ /NOT SET/ ) {
            $mess .=
"<div>\$Foswiki::cfg::$keys has been guessed and may be incorrect</div>";
        }
    }
    return $mess;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
