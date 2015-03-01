# See bottom of file for license and copyright information
package Foswiki::Render::ToolTip;

use strict;
use warnings;

use Foswiki       ();
use Foswiki::Meta ();
use Foswiki::Time ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ StaticMethod render($session, $web, $topic, $template) -> $text

Returns =title= tooltip info for a link to $web,$topic by filling
in $template. $template may contain:
   * $web
   * $topic
   * $rev
   * $date
   * $username
   * $wikiname
   * $wikiusername
   * $summary

=cut

# SMELL: should expand standard escapes
sub render {
    my ( $session, $web, $topic, $tooltip ) = @_;

    # FIXME: This is slow, it can be improved by caching topic rev
    # info and summary
    my $users = $session->{users};

    # These are safe to untaint blindly because this method is only
    # called when a regex matches a valid wikiword
    $web   = Foswiki::Sandbox::untaintUnchecked($web);
    $topic = Foswiki::Sandbox::untaintUnchecked($topic);
    my $topicObject = Foswiki::Meta->new( $session, $web, $topic );

    my $info = $topicObject->getRevisionInfo();
    $tooltip =~ s/\$web/<nop>$web/g;
    $tooltip =~ s/\$topic/<nop>$topic/g;
    $tooltip =~ s/\$rev/1.$info->{version}/g;
    $tooltip =~ s/\$date/Foswiki::Time::formatTime( $info->{date} )/ge;
    $tooltip =~ s/\$username/
      $users->getLoginName($info->{author}) || $info->{author}/ge;
    $tooltip =~ s/\$wikiname/
      $users->getWikiName($info->{author}) || $info->{author}/ge;
    $tooltip =~ s/\$wikiusername/
      $users->webDotWikiName($info->{author}) || $info->{author}/ge;

    if ( $tooltip =~ m/\$summary/ ) {
        my $summary;
        if ( $topicObject->haveAccess('VIEW') ) {
            $summary = $topicObject->text || '';
        }
        else {
            $summary =
              $session->inlineAlert( 'alerts', 'access_denied', "$web.$topic" );
        }
        $summary = $topicObject->summariseText();
        $summary =~
          s/[\"\']/<nop>/g;    # remove quotes (not allowed in title attribute)
        $tooltip =~ s/\$summary/$summary/g;
    }
    return $tooltip;
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
