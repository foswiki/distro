# See bottom of file for license and copyright information
#
# See Plugin topic for history and plugin information

package Foswiki::Plugins::DropPlugin;

use strict;
use warnings;
use Assert;
use Error ':try';

use JSON        ();
use MIME::Types ();

use Foswiki::Func    ();
use Foswiki::Plugins ();

our $VERSION = '1.000';
our $RELEASE = '27 Oct 2018';
our $SHORTDESCRIPTION =
  'Support placeholders for drop and display of uploaded content';
our $NO_PREFS_IN_TOPIC = 1;
our $templateFile      = 'dropplugin';
our $registered        = 0;

sub initPlugin {

    my ( $topic, $web, $user, $installWeb ) = @_;

    Foswiki::Func::registerTagHandler( 'DROP', \&_DROP );

    return 1;
}

# Macro
sub _DROP {
    my ( $session, $params, $topic, $web ) = @_;

    # Check the context
    my $context = Foswiki::Func::getContext();
    my $disabled =
        $context->{command_line}   ? "command line"
      : $context->{static}         ? "static"
      : !$context->{view}          ? "not viewing"
      : !$context->{authenticated} ? "not authenticated"
      :                              0;

    unless ( Foswiki::Func::readTemplate($templateFile) ) {
        Foswiki::Func::writeWarning(
            "Could not read template file '$templateFile'");
        return "Could not read templates from '$templateFile'";
    }

    my $name = $params->{_DEFAULT};
    my $type = $params->{type};

    # Make a RE that matches all legal file extensions
    my $exts = '';
    if ( !$type ) {
        $type = MIME::Types->new()->mimeTypeOf($name);
    }

    if ( $type ne 'any' ) {

        # type="any" allows any type to be dropped
        $exts = join( '|', map { $_->[0] } MIME::Types::by_mediatype($type) );
    }

    my $template;
    if ($disabled) {

        # Disabled, so no drop target
        $template = Foswiki::Func::expandTemplate('DropPlugin:inner');
    }
    else {
        unless ($registered) {
            $registered = 1;

            Foswiki::Plugins::JQueryPlugin::registerPlugin( 'drop',
                'Foswiki::Plugins::DropPlugin::JQuery' );

            unless (
                Foswiki::Plugins::JQueryPlugin::createPlugin(
                    'drop', $Foswiki::Plugins::SESSION
                )
              )
            {
                die 'Failed to register JQuery plugin';
            }
        }

        # :outer will normally TMPL:P :inner
        $template = Foswiki::Func::expandTemplate('DropPlugin:outer');
    }
    $template =~ s/%ATTACHMENT%/$name/g;
    $template =~ s/%EXTENSIONS%/$exts/g;

    return $template;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2018 Foswiki Contributors. Foswiki Contributors
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
