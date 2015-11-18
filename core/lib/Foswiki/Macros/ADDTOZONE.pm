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

sub ADDTOZONE {
    my ( $this, $params, $topicObject ) = @_;

    my $zones = $params->{_DEFAULT} || $params->{zone} || 'head';
    my $id    = $params->{id}       || $params->{tag}  || '';
    my $topic = $params->{topic}    || '';
    my $section  = $params->{section}  || '';
    my $requires = $params->{requires} || '';
    my $text     = $params->{text}     || '';

    # when there's a topic or a section parameter, then create an include
    # this overrides the text parameter
    if ( $topic || $section ) {
        my $web = $topicObject->web;
        $topic ||= $topicObject->topic;
        ( $web, $topic ) = $this->normalizeWebTopicName( $web, $topic );

        # generate TML only and delay expansion until the zone is rendered
        $text = '%INCLUDE{"' . $web . '.' . $topic . '"';
        $text .= ' section="' . $section . '"' if $section;
        $text .= ' warn="off"}%';
    }

    foreach my $zone ( split( /\s*,\s*/, $zones ) ) {
        if ( $zone eq 'body' ) {

#print STDERR "WARNING: ADDTOZONE was called for zone 'body' ... rerouting it to zone 'script' ... please fix your templates\n";
            $zone = 'script';
        }
        $this->zones()->addToZone( $zone, $id, $text, $requires );
    }

    return (DEBUG) ? "<!--A2Z:$id-->" : '';
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010 Foswiki Contributors. Foswiki Contributors
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
