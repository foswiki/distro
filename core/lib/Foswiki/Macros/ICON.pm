# See bottom of file for license and copyright information
package Foswiki::Macros::ICON;
use v5.14;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

use Try::Tiny;
use Assert;

use Moo;
use namespace::clean;
extends qw(Foswiki::Object);
with qw(Foswiki::AppObject);
with qw(Foswiki::Macro);

has ICONSPACE => (
    is      => 'rw',
    lazy    => 1,
    isa     => Foswiki::Object::isaCLASS( 'ICONSPACE', 'Foswiki::Meta' ),
    default => sub {
        my $this = shift;

        # SMELL Behaviour change! Before Moo-fication _lookupIcon was trying to
        # initialize ICONSPACE on each call. But it is likely that this
        # behaviour was simple waste of CPU.
        my $app       = $this->app;
        my $iconTopic = $app->prefs->getPreference('ICONTOPIC');
        if ( defined($iconTopic) ) {
            $iconTopic =~ s/\s+$//;
            my ( $w, $t ) =
              $app->request->normalizeWebTopicName( $app->request->web,
                $iconTopic );
            if ( $app->store->topicExists( $w, $t ) ) {
                return $this->create(
                    'Foswiki::Meta',
                    web   => $w,
                    topic => $t
                );
            }
            else {
                $app->logger->log( 'warning',
                    'ICONTOPIC $w.$t does not exist' );
            }
        }
        return undef;
    },
);
has EXT2ICON => (
    is        => 'ro',
    predicate => 1,
    lazy      => 1,
    default   => sub {
        my $this     = shift;
        my $ext2icon = {};
        if ( $this->ICONSPACE ) {

            local $/;
            try {
                my $icons =
                  $this->ICONSPACE->openAttachment( '_filetypes.txt', '<' );

                # Validate the file types as we read them.
                %{$ext2icon} = map {
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
            catch {
                ASSERT( 0, $_[0] ) if DEBUG;
                $ext2icon = {};
            };
        }
        return $ext2icon;
    },
);
has KNOWNICON => (
    is        => 'rw',
    lazy      => 1,
    predicate => 1,
    default   => sub { {} },
);
has ICONSTEMPLATE => (
    is      => 'rw',
    lazy    => 1,
    default => sub {

        #if we fail to load once, don't try again.
        $_[0]->app->templates->readTemplate('icons');
    },
);

# Uses:
# ICONSPACE to reference the meta object of the %ICONTOPIC%,
# EXT2ICON to record the mapping of file extensions to icon names
# KNOWNICON to record the mapping for icons already used
# ICONSTEMPLATE to reference the 'icons' template

# Maps from a "filename or extension" to the path of the
# attachment that contains the image for that file type.
# If there is no such icon, returns undef.
# The path returned is of the form web/topic/attachment, so can be
# used relative to a base URL or as a file path.
sub _lookupIcon {
    my ( $this, $choice ) = @_;

    my $app = $this->app;

    return undef unless defined $choice;
    return undef unless $this->ICONSPACE;

    # Have we seen it before?
    my $path = $this->KNOWNICON->{$choice};

    # First, try for a straight attachment name e.g. %ICON{"browse"}%
    # -> "System/FamFamFamGraphics/browse.gif"
    if ( defined $path ) {

        # Already known
    }
    elsif ( $this->ICONSPACE->hasAttachment("$choice.png") ) {

        # Found .png attached to ICONTOPIC
        $path = $this->ICONSPACE->getPath() . "/$choice.png";
    }
    elsif ( $this->ICONSPACE->hasAttachment("$choice.gif") ) {

        # Found .gif attached to ICONTOPIC
        $path = $this->ICONSPACE->getPath() . "/$choice.gif";
    }
    elsif ( $choice =~ m/\.([a-zA-Z0-9]+)$/ ) {

        #TODO: need to give this usage a chance at tmpl based icons too
        my $ext  = $1;
        my $icon = $this->EXT2ICON->{$ext};
        if ( defined $icon ) {
            if ( $this->ICONSPACE->hasAttachment("$icon.png") ) {

                # Found .png attached to ICONTOPIC
                $path = $this->ICONSPACE->getPath() . "/$icon.png";
            }
            else {
                $path = $this->ICONSPACE->getPath() . "/$icon.gif";
            }
        }
    }

    $this->KNOWNICON->{$choice} = $path if defined $path;

    return $path;
}

# Private method shared with ICONURL and ICONURLPATH
sub _getIconURL {
    my ( $this, $params ) = @_;
    my $path = $this->_lookupIcon( $params->{_DEFAULT} );
    $path ||= $this->_lookupIcon( $params->{default} );
    $path ||= $this->_lookupIcon('else');
    return unless $path && $path =~ s/\/([^\/]+)$//;
    my $a   = $1;
    my $app = $this->app;
    my ( $w, $t ) =
      $app->request->normalizeWebTopicName( $Foswiki::cfg{SystemWebName},
        $path );
    return $app->cfg->getPubURL( $w, $t, $a, %$params );
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

sub expand {
    my ( $this, $params ) = @_;

    my $app = $this->app;

    #use icons.tmpl
    if ( defined( $this->ICONSTEMPLATE ) ) {

       #can't test for default&else here - need to allow the 'old' way a chance.
       #foreach my $iconName ($params->{_DEFAULT}, $params->{default}, 'else') {
        my $iconName =
             $params->{_DEFAULT}
          || $params->{default}
          || 'else';    #can default the values if things are undefined though
                        #next unless (defined($iconName));
        my $html = $app->templates->expandTemplate( "icon:" . $iconName );
        return $html if ( defined($html) and $html ne '' );

        #}
    }

    #fall back to using the traditional brute force attachment method.
    require Foswiki::Render::IconImage;
    return Foswiki::Render::IconImage::render(
        $app,
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
