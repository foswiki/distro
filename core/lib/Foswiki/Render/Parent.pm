# See bottom of file for license and copyright information
package Foswiki::Render::Parent;

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

Render parent meta-data. Support for %META%.

=cut

sub render {
    my ( $session, $topicObject, $ah ) = @_;
    my $dontRecurse = $ah->{dontrecurse} || 0;
    my $depth       = $ah->{depth}       || 0;
    my $noWebHome   = $ah->{nowebhome}   || 0;
    my $prefix      = $ah->{prefix}      || '';
    my $suffix      = $ah->{suffix}      || '';
    my $usesep      = $ah->{separator}   || ' &gt; ';
    my $format      = $ah->{format}      || '[[$web.$topic][$topic]]';

    my ( $web, $topic ) = ( $topicObject->web, $topicObject->topic );
    return '' unless $web && $topic;

    my %visited;
    $visited{ $web . '.' . $topic } = 1;

    my $pWeb = $web;
    my $pTopic;
    my $text       = '';
    my $parentMeta = $topicObject->get('TOPICPARENT');
    my $parent;

    $parent = $parentMeta->{name} if $parentMeta;

    my @stack;
    my $currentDepth = 0;
    $depth = 1 if $dontRecurse;

    while ($parent) {
        $currentDepth++;
        ( $pWeb, $pTopic ) = $session->normalizeWebTopicName( $pWeb, $parent );
        $parent = $pWeb . '.' . $pTopic;
        last
          if ( $noWebHome && ( $pTopic eq $Foswiki::cfg{HomeTopicName} )
            || $visited{$parent} );
        $visited{$parent} = 1;
        $text = $format;
        $text =~ s/\$web/$pWeb/g;
        $text =~ s/\$topic/$pTopic/g;

        if ( !$depth or $currentDepth == $depth ) {
            unshift( @stack, $text );
        }
        last if $currentDepth == $depth;

        # Compromise; rather than supporting a hack in the store to support
        # rapid access to parent meta (as in TWiki) accept the hit
        # of reading the whole topic.
        my $topicObject = Foswiki::Meta->load( $session, $pWeb, $pTopic );
        my $parentMeta = $topicObject->get('TOPICPARENT');
        $parent = $parentMeta->{name} if $parentMeta;
    }
    $text = join( $usesep, @stack );

    if ($text) {
        $text = $prefix . $text if ($prefix);
        $text .= $suffix if ($suffix);
    }

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
