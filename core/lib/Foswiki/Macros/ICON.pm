# See bottom of file for license and copyright information
package Foswiki;

use strict;

use Foswiki::Macros::ICONURL ();

# Uses:
# _ICONSPACE to reference the meta object of the %ICONTOPIC%,
# _EXT2ICON to record the mapping of file extensions to icon names
# _KNOWNICON to record the mapping for icons already used

# Maps from a "filename or extension" to the path of the
# attachment that contains the image for that file type.
# If there is no such icon, returns undef.
# The path returned is of the form web/topic/attachment, so can be
# used relative to a base URL or as a file path.
sub _lookupIcon {
    my ( $this, $choice ) = @_;

    return undef unless defined $choice;

    if (!defined $this->{_ICONSPACE}) {
        my $iconTopic = $this->{prefs}->getPreference('ICONTOPIC');
        if ( defined($iconTopic) ) {
            $iconTopic =~ s/\s+$//;
            my ( $w, $t ) =
              $this->normalizeWebTopicName( $this->{webName}, $iconTopic );
            $this->{_ICONSPACE} = new Foswiki::Meta($this, $w, $t);
        }
    }
    return undef unless $this->{_ICONSPACE};

    # Have we seen it before?
    $this->{_KNOWNICON} ||= {};
    my $path = $this->{_KNOWNICON}->{$choice};

    # First, try for a straight attachment name e.g. %ICON{"browse"}%
    # -> "System/FamFamFamGraphics/browse.gif"
    if (defined $path) {
        # Already known
    } elsif ($this->{_ICONSPACE}->hasAttachment("$choice.gif")) {
        # Found .gif attached to ICONTOPIC
        $path = $this->{_ICONSPACE}->getPath()."/$choice.gif";
    } elsif ($this->{_ICONSPACE}->hasAttachment("$choice.png")) {
        # Found .png attached to ICONTOPIC
        $path = $this->{_ICONSPACE}->getPath()."/$choice.png";
    } elsif ($choice =~ /\.([a-zA-Z0-9]+)$/) {
        my $ext = $1;
        if (!defined $this->{_EXT2ICON}) {
            # Load the file extension mapping
            $this->{_EXT2ICON} = {};
            local $/;
            try {
                my $icons =
                  $this->{_ICONSPACE}->openAttachment( '_filetypes.txt', '<' );
                %{ $this->{_EXT2ICON} } = split( /\s+/, <$icons> );
                $icons->close();
            } catch Error with {
                ASSERT( 0, $_[0] ) if DEBUG;
                $this->{_EXT2ICON} = {};
            };
        }

        my $icon = $this->{_EXT2ICON}->{$ext};
        if ( defined $icon ) {
            # For historical reasons these icons are always .gif files,
            # and can be assumed to exist.
            $path = $this->{_ICONSPACE}->getPath()."/$icon.gif";
        }
    }

    $this->{_KNOWNICON}->{$choice} = $path if defined $path;

    return $path;
}

sub _getIconUrl {
    my $this = shift;
    my $absolute = shift;
    my @path = split('/', shift);
    my $a = pop(@path);
    my $t = pop(@path);
    my $w = join('/', @path);
    return $this->getPubUrl($absolute, $w, $t, $a);
}

# %ICON{ "filename or icon name" [ default="filename or icon name" ]
#           [ alt="alt text to be added to the HTML img tag" ] }%
# If the main parameter refers to a non-existent icon, and default is not
# given, or also refers to a non-existent icon, then the else icon (else)
# will be used. The HTML alt attribute for the image will be taken from
# the alt parameter. If alt is not given, the main parameter will be used. 

sub ICON {
    my ( $this, $params ) = @_;

    my $path = $this->_lookupIcon($params->{_DEFAULT}) ||
      $this->_lookupIcon($params->{default}) ||
      $this->_lookupIcon('else');

    return $this->renderer->renderIconImage(
        $this->_getIconUrl( 0, $path ), $params->{alt} || $params->{_DEFAULT});
}

1;
__DATA__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2009-2010 Foswiki Contributors. Foswiki Contributors
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
