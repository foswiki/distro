# See bottom of file for license and copyright information
package Foswiki;

use strict;
use warnings;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

# Uses:
# _ICONSPACE to reference the meta object of the %ICONTOPIC%,
# _EXT2ICON to record the mapping of file extensions to icon names
# _KNOWNICON to record the mapping for icons already used
# _ICONSTEMPLATE to reference the 'icons' template

# Maps from a "filename or extension" to the path of the
# attachment that contains the image for that file type.
# If there is no such icon, returns undef.
# The path returned is of the form web/topic/attachment, so can be
# used relative to a base URL or as a file path.
sub _lookupIcon {
    my ( $this, $choice ) = @_;

    return undef unless defined $choice;

    if ( !defined $this->{_ICONSPACE} ) {
        my $iconTopic = $this->{prefs}->getPreference('ICONTOPIC');
        if ( defined($iconTopic) ) {
            $iconTopic =~ s/\s+$//;
            my ( $w, $t ) =
              $this->normalizeWebTopicName( $this->{webName}, $iconTopic );
            if ( $this->topicExists( $w, $t ) ) {
                $this->{_ICONSPACE} = new Foswiki::Meta( $this, $w, $t );
            }
            else {
                $this->logger->log( 'warning',
                    'ICONTOPIC $w.$t does not exist' );
            }
        }
    }
    return undef unless $this->{_ICONSPACE};

    # Have we seen it before?
    $this->{_KNOWNICON} ||= {};
    my $path = $this->{_KNOWNICON}->{$choice};

    # First, try for a straight attachment name e.g. %ICON{"browse"}%
    # -> "System/FamFamFamGraphics/browse.gif"
    if ( defined $path ) {

        # Already known
    }
    elsif ( $this->{_ICONSPACE}->hasAttachment("$choice.png") ) {

        # Found .png attached to ICONTOPIC
        $path = $this->{_ICONSPACE}->getPath() . "/$choice.png";
    }
    elsif ( $this->{_ICONSPACE}->hasAttachment("$choice.gif") ) {

        # Found .gif attached to ICONTOPIC
        $path = $this->{_ICONSPACE}->getPath() . "/$choice.gif";
    }
    elsif ( $choice =~ m/\.([a-zA-Z0-9]+)$/ ) {

        #TODO: need to give this usage a chance at tmpl based icons too
        my $ext = $1;
        if ( !defined $this->{_EXT2ICON} ) {

            # Load the file extension mapping
            $this->{_EXT2ICON} = {};
            local $/;
            try {
                my $icons =
                  $this->{_ICONSPACE}->openAttachment( '_filetypes.txt', '<' );

                # Validate the file types as we read them.
                %{ $this->{_EXT2ICON} } = map {
                    Foswiki::Sandbox::untaint(
                        $_,
                        sub {
                            my $tok = shift;
                            die "Bad filetype $tok"
                              unless $tok =~ m/^[[:alnum:]]+$/;
                            return $tok;
                        }
                    );
                } split( /\s+/, <$icons> );
                $icons->close();
            }
            catch Error with {
                ASSERT( 0, $_[0] ) if DEBUG;
                $this->{_EXT2ICON} = {};
            };
        }

        my $icon = $this->{_EXT2ICON}->{$ext};
        if ( defined $icon ) {
            if ( $this->{_ICONSPACE}->hasAttachment("$icon.png") ) {

                # Found .png attached to ICONTOPIC
                $path = $this->{_ICONSPACE}->getPath() . "/$icon.png";
            }
            else {
                $path = $this->{_ICONSPACE}->getPath() . "/$icon.gif";
            }
        }
    }

    $this->{_KNOWNICON}->{$choice} = $path if defined $path;

    return $path;
}

# Private method shared with ICONURL and ICONURLPATH
sub _getIconURL {
    my ( $this, $params ) = @_;
    my $path = $this->_lookupIcon( $params->{_DEFAULT} );
    $path ||= $this->_lookupIcon( $params->{default} );
    $path ||= $this->_lookupIcon('else');
    return unless $path && $path =~ s/\/([^\/]+)$//;
    my $a = $1;
    my ( $w, $t ) =
      $this->normalizeWebTopicName( $Foswiki::cfg{SystemWebName}, $path );
    return $this->getPubURL( $w, $t, $a, %$params );
}

=begin TML

---++ ObjectMethod ICON($params) -> $html

ICONURLPATH macro implementation

   * %ICON{ "filename or icon name" [ default="filename or icon name" ]
           [ alt="alt text to be added to the HTML img tag" ] }%
If the main parameter refers to a non-existent icon, and default is not
given, or also refers to a non-existent icon, then the else icon (else)
will be used. The HTML alt attribute for the image will be taken from
the alt parameter. If alt is not given, the main parameter will be used. 

=cut

sub ICON {
    my ( $this, $params ) = @_;

    if ( !defined( $this->{_ICONSTEMPLATE} ) ) {

        #if we fail to load once, don't try again.
        $this->{_ICONSTEMPLATE} = $this->templates->readTemplate('icons');
    }

    #use icons.tmpl
    if ( defined( $this->{_ICONSTEMPLATE} ) ) {

       #can't test for default&else here - need to allow the 'old' way a chance.
       #foreach my $iconName ($params->{_DEFAULT}, $params->{default}, 'else') {
        my $iconName =
             $params->{_DEFAULT}
          || $params->{default}
          || 'else';    #can default the values if things are undefined though
                        #next unless (defined($iconName));
        my $html = $this->templates->expandTemplate( "icon:" . $iconName );
        return $html if ( defined($html) and $html ne '' );

        #}
    }

    #fall back to using the traditional brute force attachment method.
    require Foswiki::Render::IconImage;
    return Foswiki::Render::IconImage::render(
        $this,
        $this->_getIconURL($params),
        $params->{alt} || $params->{_DEFAULT} || $params->{default} || 'else',
        $params->{quote},
    );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2009-2014 Foswiki Contributors. Foswiki Contributors
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
