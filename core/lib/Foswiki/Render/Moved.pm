# See bottom of file for license and copyright information
package Foswiki::Render::Moved;

use strict;
use warnings;

use Foswiki       ();
use Foswiki::Meta ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ StaticMethod render($session, $topicObject, $params) -> $text

Render moved meta-data. Support for %META%.

=cut

sub render {
    my ( $session, $topicObject, $params ) = @_;
    my $text   = '';
    my $moved  = $topicObject->get('TOPICMOVED');
    my $prefix = $params->{prefix} || '';
    my $suffix = $params->{suffix} || '';

    if ($moved) {
        my ( $fromWeb, $fromTopic ) =
          $session->normalizeWebTopicName( $topicObject->web, $moved->{from} );
        my ( $toWeb, $toTopic ) =
          $session->normalizeWebTopicName( $topicObject->web, $moved->{to} );
        my $by    = $moved->{by};
        my $u     = $by;
        my $users = $session->{users};
        $by = $users->webDotWikiName($u) if $u;
        my $date = Foswiki::Time::formatTime( $moved->{date}, '', 'gmtime' );

        # Only allow put back if current web and topic match
        # stored information
        my $putBack = '';
        if ( $topicObject->web eq $toWeb && $topicObject->topic eq $toTopic ) {
            $putBack = ' - '
              . CGI::a(
                {
                    title => (
                        $session->i18n->maketext(
'Click to move topic back to previous location, with option to change references.'
                        )
                    ),
                    href => $session->getScriptUrl(
                        0, 'rename', $topicObject->web, $topicObject->topic
                    ),
                    rel => 'nofollow'
                },
                $session->i18n->maketext('Put it back...')
              );
        }
        $text = $session->i18n->maketext(
            "[_1] was renamed or moved from [_2] on [_3] by [_4]",
            "<nop>$toWeb.<nop>$toTopic", "<nop>$fromWeb.<nop>$fromTopic",
            $date, $by
        ) . $putBack;
    }
    $text = "$prefix$text$suffix" if $text;
    return $text;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2001-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
