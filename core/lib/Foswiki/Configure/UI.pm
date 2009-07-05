# See bottom of file for license and copyright information

# This is both the factory for UIs and the base class of UI constructors.
# A UI is the V part of the MVC model used in configure.
#
# Each structural entity in a configure screen has a UI type, either
# stored directly in the entity or indirectly in the type associated
# with a value. The UI type is used to guide a visitor which is run
# over the structure to generate the UI.
#
package Foswiki::Configure::UI;

use strict;
use File::Spec ();
use FindBin    ();

our $totwarnings;
our $toterrors;

sub new {
    my ( $class, $item ) = @_;

    Carp::confess unless $item;

    my $this = bless( { item => $item }, $class );

    $FindBin::Bin =~ /(.*)/;
    $this->{bin} = $1;
    my @root = File::Spec->splitdir( $this->{bin} );
    pop(@root);
    $this->{root} = File::Spec->catfile( @root, '' );

    return $this;
}

sub findRepositories {
    my $this = shift;
    unless ( defined( $this->{repositories} ) ) {
        my $replist = '';
        $replist .= $Foswiki::cfg{ExtensionsRepositories}
          if defined $Foswiki::cfg{ExtensionsRepositories};
        $replist = ";$replist;";
        while (
            $replist =~ s/[;\s]+(.*?)=\((.*?),(.*?)(?:,(.*?),(.*?))?\)\s*;/;/ )
        {
            push(
                @{ $this->{repositories} },
                { name => $1, data => $2, pub => $3 }
            );
        }
    }
}

sub getRepository {
    my ( $this, $reponame ) = @_;
    foreach my $place ( @{ $this->{repositories} } ) {
        return $place if $place->{name} eq $reponame;
    }
    return;
}

# Static UI factory
# UIs *must* exist
sub loadUI {
    my ( $id, $item ) = @_;
    $id = 'Foswiki::Configure::UIs::' . $id;
    my $ui;

    eval "use $id (); \$ui = new $id(\$item);";

    return if ( !$ui && $@ );

    return $ui;
}

# Static checker factory
# Checkers *need not* exist
sub loadChecker {
    my ( $id, $item ) = @_;
    $id =~ s/}{/::/g;
    $id =~ s/[}{]//g;
    $id =~ s/'//g;
    $id =~ s/-/_/g;
    my $checkClass = 'Foswiki::Configure::Checkers::' . $id;
    my $checker;

    eval "use $checkClass; \$checker = new $checkClass(\$item);";

    # Can't locate errors are OK
    die $@ if ( $@ && $@ !~ /Can't locate / );

    return $checker;
}

# Returns a response object as described in Foswiki::Net
sub getUrl {
    my ( $this, $url ) = @_;

    require Foswiki::Net;
    my $tn       = new Foswiki::Net();
    my $response = $tn->getExternalResource($url);
    $tn->finish();
    return $response;
}

# STATIC Used by a whole bunch of things that just need to show a key-value row
# in a table (called as a method, i.e. with class as first parameter)
sub setting {
    my $this = shift;
    my $key  = shift;

    my $data = join( ' ', @_ ) || ' ';

    return CGI::Tr( CGI::th( $key) . CGI::td( $data) );
}

# encode a string to make a simplified unique ID useable
# as an HTML id or anchor
sub makeID {
    my ( $this, $str ) = @_;

    $str =~ s/\s(\w)/uc($1)/ge;
    $str =~ s/\W//g;
    return $str;
}

sub NOTE {
    my $this = shift;
    return CGI::div(
        { class => 'configureInfo' },
        CGI::span(
            join( "\n", @_ )
        )
    );    
}

# a warning
sub WARN {
    my $this = shift;
    $this->{item}->inc('warnings');
    $totwarnings++;
    return CGI::div(
        { class => 'configureWarn' },
        CGI::span(
            CGI::strong('Warning: ') . join( "\n", @_ )
        )
    );
}

# an error
sub ERROR {
    my $this = shift;
    $this->{item}->inc('errors');
    $toterrors++;
    return CGI::div(
        CGI::span(
            { class => 'configureError' },
            CGI::strong('Error: ') . join( "\n", @_ )
        )
    );
}

# Used in place of CGI::hidden, which is broken in some versions.
# Assumes $name does not need to be encoded
# HTML encodes the value
sub hidden {
    my ( $this, $name, $value ) = @_;
    $value ||= '';
    $value =~
      s/([[\x01-\x09\x0b\x0c\x0e-\x1f"%&'*<=>@[_\|])/'&#'.ord($1).';'/ge;
    return
        "<input type='hidden' name='$name' value='$value' />";
}

# Invoked to confirm authorisation, and handle password changes. The password
# is changed in $Foswiki::cfg, a change which is then detected and written when
# the configuration file is actually saved.
sub authorised {
    my $pass = $Foswiki::query->param('cfgAccess');

    # The first time we get here is after the "next" button is hit. A password
    # won't have been defined yet; so the authorisation must fail to force
    # a prompt.
    if ( !defined($pass) ) {
        return 0;
    }

    # If we get this far, a password has been given. Check it.
    if ( !$Foswiki::cfg{Password} && !$Foswiki::query->param('confCfgP') ) {

        # No password passed in, and Foswiki::cfg doesn't contain a password
        print CGI::div( { class => 'configureError' }, <<'HERE');
WARNING: You have not defined a password. You must define a password before
you can save.
HERE
        return 0;
    }

    # If a password has been defined, check that it has been used
    if ( $Foswiki::cfg{Password}
        && crypt( $pass, $Foswiki::cfg{Password} ) ne $Foswiki::cfg{Password} )
    {
        print CGI::div( { class => 'configureError' }, "Password incorrect" );
        return 0;
    }

    # Password is correct, or no password defined
    # Change the password if so requested
    my $newPass = $Foswiki::query->param('newCfgP');

    if ($newPass) {
        my $confPass = $Foswiki::query->param('confCfgP') || '';
        if ( $newPass ne $confPass ) {
            print CGI::div( { class => 'configureError' },
                'New password and confirmation do not match' );
            return 0;
        }
        $Foswiki::cfg{Password} = _encode($newPass);
        print CGI::div( { class => 'configureError' }, 'Password changed' );
    }

    return 1;
}

sub collectMessages {
    my $this = shift;
    my ($item) = @_;

    my $warnings = $item->{warnings} || 0;
    my $errors   = $item->{errors}   || 0;
    my $errorsMess   = "$errors error" .     ( ( $errors > 1 )   ? 's' : '' );
    my $warningsMess = "$warnings warning" . ( ( $warnings > 1 ) ? 's' : '' );
    my $mess         = '';
    $mess .= ' ' . CGI::div( { class => 'configureError' }, $errorsMess )
      if $errors;
    $mess .= ' ' . CGI::div( { class => 'configureWarn' }, $warningsMess )
      if $warnings;

    return $mess;
}

sub _encode {
    my $pass = shift;
    my @saltchars = ( 'a' .. 'z', 'A' .. 'Z', '0' .. '9', '.', '/' );
    my $salt =
        $saltchars[ int( rand( $#saltchars + 1 ) ) ]
      . $saltchars[ int( rand( $#saltchars + 1 ) ) ];
    return crypt( $pass, $salt );
}

# Return a string of settingBlocks giving the status of various
# required modules.
# Either takes an array of hashes, or parameters in a hash.
# Each module hash needs:
# name - e.g. Car::Wreck
# usage - description of what it's for
# dispostion - 'required', 'recommended'
# minimumVersion - lowest acceptable $Module::VERSION
#
sub checkPerlModules {
    my ( $this, $useTR, $mods) = @_;

    my $e = '';
    foreach my $mod (@$mods) {
        $mod->{minimumVersion} ||= 0;
        $mod->{disposition}    ||= '';
        my $n = '';
        my $mod_version;

        # require instead of use = see Bugs:Item4585
        eval 'require ' . $mod->{name};
        if ($@) {
            $n = 'Not installed. ' . $mod->{usage};
        }
        else {
            no strict 'refs';
            eval '$mod_version = $' . $mod->{name} . '::VERSION';
            $mod_version ||= 0;
            $mod_version =~ s/(\d+(\.\d*)?).*/$1/;    # keep 99.99 style only
            use strict 'refs';
            if ( $mod_version < $mod->{minimumVersion} ) {
                $n = $mod_version || 'Unknown version';
                $n .=
                    ' installed. Version '
                  . $mod->{minimumVersion} . ' '
                  . $mod->{disposition};
                $n .= ' ' . $mod->{usage} if $mod->{usage};
            }
        }
        if ($n) {
            if ( $mod->{disposition} eq 'required' ) {
                $n = $this->ERROR($n);
            }
            elsif ( $mod->{disposition} eq 'recommended' ) {
                $n = $this->WARN($n);
            }
            else {
                $n = $this->NOTE($n);
            }
        }
        else {
            $mod_version ||= 'Unknown version';
            $n = $this->NOTE( $mod_version . ' installed' );
            $n .= ' Description: ' . $mod->{usage} if $mod->{usage};
        }
        if ($useTR) {
            $e .= $this->setting( $mod->{name}, $n );
        } else {
            $e .= "<strong><code>$mod->{name}:</code></strong> $n<br />";
        }
    }
    return $e;
}

1;
__DATA__
#
# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
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
