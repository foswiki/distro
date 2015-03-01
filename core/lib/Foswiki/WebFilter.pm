# See bottom of file for license and copyright information
package Foswiki::WebFilter;

use strict;
use warnings;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

# PH made these lazy getters rather than globals in Item11349
my $public;
my $user;
my $user_allowed;

#TODO: documentme
#TODO: should this be converted to a FilterIterator?

# spec in the $filter,
# which may include one of:
#    1 'user' (for only user webs)
#    2 'template' (for only template webs)
# $filter may also contain the word 'public' which will further filter
# webs on whether NOSEARCHALL is specified for them or not.
# 'allowed' filters out webs that the user is denied access to by a *WEBVIEW.

sub new {
    my ( $class, $filter ) = @_;
    my $this = bless( {}, $class );
    foreach my $f (qw(user template public allowed)) {
        $this->{$f} = ( $filter =~ m/\b$f\b/ );
    }
    return $this;
}

sub ok {
    my ( $this, $session, $web ) = @_;

    return 0 if $this->{template} && $web !~ /(?:^_|\/_)/;

    return 1 if ( $web eq $session->{webName} );

    return 0 if $this->{user} && $web =~ m/(?:^_|\/_)/;

    return 0 if !$session->webExists($web);

    my $webObject = Foswiki::Meta->new( $session, $web );
    my $thisWebNoSearchAll =
      Foswiki::isTrue( $webObject->getPreference('NOSEARCHALL') );

    return 0
      if $this->{public}
      && !$session->{users}->isAdmin( $session->{user} )
      && $thisWebNoSearchAll;

    return 0 if $this->{allowed} && !$webObject->haveAccess('VIEW');

    return 1;
}

sub public {
    my ($class) = @_;

    if ( !defined $public ) {
        $public = $class->new('public');
    }

    return $public;
}

sub user {
    my ($class) = @_;

    if ( !defined $public ) {
        $public = $class->new('user');
    }

    return $public;
}

sub user_allowed {
    my ($class) = @_;

    if ( !defined $public ) {
        $public = $class->new('user,allowed');
    }

    return $public;
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
