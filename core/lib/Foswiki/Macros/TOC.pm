# See bottom of file for license and copyright information
package Foswiki;

use strict;
use warnings;

# Extract headings from $text and render them as a TOC table.
#    * =$text= - the text to extract the TOC from.
#    * =$topicObject= - the topic that is the context we are going to
#      place the TOC in
#    * =$args= - Foswiki::Attrs of args to the %TOC tag (see System.VarTOC2)
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
    my ( $session, $text, $topicObject, $args ) = @_;

    require Foswiki::Attrs;
    my $params    = new Foswiki::Attrs($args);
    my $isSameTopic = 1;                          # is the toc for this topic?

    my $tocTopic = $params->{_DEFAULT};
    my $tocWeb   = $params->{web};

    if ( $tocTopic || $tocWeb ) {
        $tocWeb   ||= $topicObject->web;
        $tocTopic ||= $topicObject->topic;
        ( $tocWeb, $tocTopic ) =
          $session->normalizeWebTopicName( $tocWeb, $tocTopic );

        if ( $tocWeb eq $topicObject->web && $tocTopic eq $topicObject->topic )
        {
            $isSameTopic = 1;
        }
        else {

            # Data for topic coming from another topic
            $params->{differentTopic} = 1;
            $topicObject = Foswiki::Meta->load( $session, $tocWeb, $tocTopic );
            if ( !$topicObject->haveAccess('VIEW') ) {
                return $session->inlineAlert(
                    'alerts', 'access_denied', $tocWeb, $tocTopic );
            }
            $text      = $topicObject->text;
            $isSameTopic = 0;
        }
    }

    my ( $defaultWeb, $defaultTopic ) =
      ( $topicObject->web, $topicObject->topic );

    my $topic = $params->{_DEFAULT} || $defaultTopic;
    $defaultWeb =~ s#/#.#g;
    my $web = $params->{web} || $defaultWeb;

    # throw away <verbatim> and <pre> blocks
    my %junk;
    $text = Foswiki::takeOutBlocks( $text, 'verbatim', \%junk );
    $text = Foswiki::takeOutBlocks( $text, 'pre',      \%junk );

    my $maxDepth = $params->{depth};
    $maxDepth ||= $session->{prefs}->getPreference('TOC_MAX_DEPTH')
      || 6;
    my $minDepth = $session->{prefs}->getPreference('TOC_MIN_DEPTH')
      || 1;

    # get the title attribute
    my $title =
         $params->{title}
      || $session->{prefs}->getPreference('TOC_TITLE')
      || '';
    $title = CGI::span( { class => 'foswikiTocTitle' }, $title ) if ($title);

    my $highest  = 99;
    my $result   = '';
    my $verbatim = {};
    $text = Foswiki::takeOutBlocks( $text, 'verbatim', $verbatim );
    $text = Foswiki::takeOutBlocks( $text, 'pre',      $verbatim );

    # Find URL parameters
    my $query   = $session->{request};
    my @qparams = ();
    foreach my $name ( $query->param ) {
        next if ( $name eq 'keywords' );
        next if ( $name eq 'validation_key' );
        next if ( $name eq 'topic' );
        next if ( $name eq 'text' );
        push @qparams, $name => $query->param($name);
    }

    # Extract anchor targets. This has to generate *identical* anchor
    # targets to normal rendering.

    # Normal rendering does some processing before generating anchor
    # targts. Do that processing here because it does affect the
    # anchor names.
    $text =~ s/\r//g;
    $text =~ s/\\\n//gs;

    # clear the set of unique anchornames in order to inhibit
    # the 'relabeling' of anchor names if the same topic is processed
    # more than once, cf. explanation in expandMacros()
    my $anchors = $session->renderer->getAnchorNames($topicObject);
    $anchors->clear();

    $text =~ s/^(\#$Foswiki::regex{wikiWordRegex})/
      $anchors->add( $1 ); $1/geom;

    # NB: While we're processing $text line by line here,
    # getRendereredVersion() 'allocates' unique anchor
    # names by first replacing regex{headerPatternHt} followed by
    # regex{headerPatternDa}. We have to adhere to this
    # order here as well.
    my @regexps =
      ( $Foswiki::regex{headerPatternHt}, $Foswiki::regex{headerPatternDa} );
    my @lines = split( /\r?\n/, $text );
    my @targets;
    my $lineno = 0;
  LINE: foreach my $line (@lines) {
        $lineno++;
        for my $i ( 0 .. $#regexps ) {
            if ( $line =~ m/$regexps[$i]/ ) {

                my ( $level, $text ) = ( $1, $2 );
                $text =~ s/^\s*//;
                $text =~ s/\s*$//;

                my $atext = $text;
                $text =~ s/\s*$Foswiki::regex{headerPatternNoTOC}.*//o;

                # Ignore empty headings
                next unless $text;

                # $i == 1 is $Foswiki::regex{headerPatternDa}
                $level = length($level) if ( $i == 1 );
                if ( ( $level >= $minDepth ) && ( $level <= $maxDepth ) ) {
                    my $anchor = $anchors->addUnique( $atext );
                    my $target = {
                        anchor => $anchor,
                        text   => $text,
                        level  => $level,
                    };
                    push( @targets, $target );

                    next LINE;
                }
            }
        }
    }

    foreach my $a (@targets) {
        my $text = $a->{text};
        $highest = $a->{level} if ( $a->{level} < $highest );
        my $tabs = "\t" x $a->{level};

        # Remove *bold*, _italic_ and =fixed= formatting
        $text =~ s/(^|[\s\(])\*([^\s]+?|[^\s].*?[^\s])\*
                   ($|[\s\,\.\;\:\!\?\)])/$1$2$3/gx;
        $text =~ s/(^|[\s\(])_+([^\s]+?|[^\s].*?[^\s])_+
                   ($|[\s\,\.\;\:\!\?\)])/$1$2$3/gx;
        $text =~ s/(^|[\s\(])=+([^\s]+?|[^\s].*?[^\s])=+
                   ($|[\s\,\.\;\:\!\?\)])/$1$2$3/gx;

        # Prevent manual links
        $text =~ s/<[\/]?a\b[^>]*>//gi;

        # Prevent WikiLinks
        $text =~ s/\[\[.*?\]\[(.*?)\]\]/$1/g;    # '[[...][...]]'
        $text =~ s/\[\[(.*?)\]\]/$1/ge;          # '[[...]]'
        $text =~ s/(^|[\s\(])($Foswiki::regex{webNameRegex})\.
                   ($Foswiki::regex{wikiWordRegex})/$1<nop>$3/gox;
        $text =~ s/(^|[\s\(])($Foswiki::regex{wikiWordRegex})/$1<nop>$2/gox;
        $text =~ s/(^|[\s\(])($Foswiki::regex{abbrevRegex})/$1<nop>$2/go;

        # Special case: 'Site:page' Interwiki link
        $text =~ s/(^|[\s\-\*\(])
                   ([$Foswiki::regex{mixedAlphaNum}]+\:)/$1<nop>$2/gox;

        # Prevent duplicating id attributes 
        $text =~ s/id=["'][^"']*?["']//gi;

        # create linked bullet item, using a relative link to anchor
        my $target =
          $isSameTopic
          ? Foswiki::make_params( @qparams ).'#' .$a->{anchor}
          : $session->getScriptUrl(
            0, 'view', $topicObject->web, $topicObject->topic,
            '#' => $a->{anchor},
            @qparams
          );
        $text = $tabs . '* ' . CGI::a( { href => $target }, " $text " );
        $result .= "\n" . $text;
    }

    if ($result) {
        if ( $highest > 1 ) {

            # left shift TOC
            $highest--;
            $result =~ s/^\t{$highest}//gm;
        }

        # add a anchor to be able to jump to the toc and add a outer div
        return CGI::a( { name => 'foswikiTOC' }, '' )
          . CGI::div( { class => 'foswikiToc' }, "$title$result\n" );

    }
    else {
        return '';
    }
}

1;
__END__
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
