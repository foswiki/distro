# See bottom of file for license and copyright information
package Foswiki;

use strict;

#
# SMELL: this is _not_ a tag handler in the sense of other builtin tags,
# because it requires far more context information (the text of the topic)
# than any handler.
# SMELL: as a tag handler that also semi-renders the topic to extract the
# headings, this handler would be much better as a preRenderingHandler in
# a plugin (where head, script and verbatim sections are already protected)
#
#    * $text  : ref to the text of the current topic
#    * $topic : the topic we are in
#    * $web   : the web we are in
#    * $args  : 'Topic' [web='Web'] [depth='N']
# Return value: $tableOfContents
# Handles %<nop>TOC{...}% syntax.  Creates a table of contents
# using Foswiki bulleted
# list markup, linked to the section headings of a topic. A section heading is
# entered in one of the following forms:
#    * $headingPatternSp : \t++... spaces section heading
#    * $headingPatternDa : ---++... dashes section heading
#    * $headingPatternHt : &lt;h[1-6]> HTML section heading &lt;/h[1-6]>
sub TOC {
    my ( $this, $text, $topicObject, $args ) = @_;

    require Foswiki::Attrs;
    my $params    = new Foswiki::Attrs($args);
    my $sameTopic = 1;                           # is the toc for this topic?

    my $tocTopic = $params->{_DEFAULT};
    my $tocWeb   = $params->{web};

    if ( $tocTopic || $tocWeb ) {
        $tocWeb   ||= $topicObject->web;
        $tocTopic ||= $topicObject->topic;
        ( $tocWeb, $tocTopic ) =
          $this->normalizeWebTopicName( $tocWeb, $tocTopic );

        if ( $tocWeb eq $topicObject->web && $tocTopic eq $topicObject->topic )
        {
            $sameTopic = 1;
        }
        else {

            # Data for topic coming from another topic
            $params->{differentTopic} = 1;
            $topicObject = Foswiki::Meta->load( $this, $tocWeb, $tocTopic );
            if ( !$topicObject->haveAccess('VIEW') ) {
                return $this->inlineAlert( 'alerts', 'access_denied', $tocWeb,
                    $tocTopic );
            }
            $text      = $topicObject->text;
            $sameTopic = 0;
        }
    }

    return $this->renderer->renderTOC( $text, $topicObject, $params,
        $sameTopic );
}

1;
__DATA__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2009 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.
Based on parts of Ward Cunninghams original Wiki and JosWiki.
Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
