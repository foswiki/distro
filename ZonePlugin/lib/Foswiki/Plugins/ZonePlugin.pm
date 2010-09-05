# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# ZonePlugin is Copyright (C) 2010 Michael Daum http://michaeldaumconsulting.com
#
# Based on core code of Foswiki-1.0.9
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
package Foswiki::Plugins::ZonePlugin;

use strict;
use warnings;
use Foswiki::Func    ();
use Foswiki::Plugins ();

our $VERSION = '$Rev$';
our $RELEASE = '3.0';
our $SHORTDESCRIPTION =
  'Gather content of a page in named zones while rendering it';
our $NO_PREFS_IN_TOPIC = 1;

# Note: the following marker is used in text to mark RENDERZONE
# macros that have been hoisted from the source text of a page. It is
# carefully chosen so that it is (1) not normally present in written
# text (2) does not combine with other characters to form valid
# wide-byte characters and (3) does not conflict with other markers used
# by Foswiki/Render.pm
our $RENDERZONE_MARKER = "\3";

# This allows us to basically copy-paste the code from trunk's Foswiki.pm
my $this;

# monkey-patch API ###########################################################
BEGIN {
    if ( $Foswiki::cfg{Plugins}{ZonePlugin}{Enabled}
        && !defined(&Foswiki::Func::addToZone) )
    {
        no warnings 'redefine';
        *Foswiki::Func::addToZone = \&Foswiki::Plugins::ZonePlugin::_addToZone;
        *Foswiki::Func::addToHEAD = \&Foswiki::Plugins::ZonePlugin::addToHEAD;
        use warnings 'redefine';
    }
    else {

        #print STDERR "suppressing monkey patching via ZonePlugin\n";
    }
}

##############################################################################
sub DEBUG { 0 }

sub expandStandardEscapes {
    my ($text) = @_;

    return Foswiki::expandStandardEscapes($text);
}

# Use earlyInitPlugin to avoid PluginsOrder mess in getting zones initialised
# for plugins
sub earlyInitPlugin {
    if ( $Foswiki::Plugins::VERSION < 2.1 ) {

        Foswiki::Func::registerTagHandler( 'ADDTOZONE',  \&ADDTOZONE );
        Foswiki::Func::registerTagHandler( 'RENDERZONE', \&RENDERZONE );

        # redefine
        Foswiki::Func::registerTagHandler( 'ADDTOHEAD', \&ADDTOHEAD );

       # This allows us to basically copy-paste the code from trunk's Foswiki.pm
        $this = bless(
            {
                _zones                 => undef,
                _renderZonePlaceholder => undef,
                _addedToHEAD           => undef,
            },
            'Foswiki::Plugins::ZonePlugin'
        );

        return '';
    }
}

sub initPlugin {
    my ( $topic, $web ) = @_;

    if ( $Foswiki::Plugins::VERSION >= 2.1 ) {
        Foswiki::Func::writeWarning(
            "ZonePlugin is not compatible with your Foswiki version");
        return 0;
    }

    # For _renderZone()
    $this->{webName}   = $web;
    $this->{topicName} = $topic;

    return 1;
}

##############################################################################
sub completePageHandler {
    my ( $text, $headers ) = @_;

    if ( $headers =~ /Content-Type: text\/html/m ) {
        $_[0] = $this->_renderZones($text);
    }

    return;
}

=begin TML

---+++ addToHEAD( $id, $data, $requires )

Adds =$data= to the HTML header (the <head> tag).

*Deprecated* 26 Mar 2010 - use =addZoZone('head', ...)=.

=cut

sub addToHEAD {
    $this->addToZone( 'head', @_ );

    return;
}

sub _addToZone {
    $this->addToZone(@_);

    return;
}

##############################################################################
sub ADDTOHEAD {
    my ( $foswiki, $args, $topicObject ) = @_;

    my $_DEFAULT = $args->{_DEFAULT};
    my $text     = $args->{text};
    my $topic    = $args->{topic};
    my $requires = $args->{requires};
    if ( defined $args->{topic} ) {
        my ( $web, $topic ) =
          $foswiki->normalizeWebTopicName( $topicObject->web, $args->{topic} );

        # prevent deep recursion
        $web =~ s/\//\./g;    # SMELL: unnecessary?
        unless ( $this->{_addedToHEAD}{"$web.$topic"} ) {
            my $atom = Foswiki::Meta->load( $foswiki, $web, $topic );
            $text = $atom->text();
            $this->{_addedToHEAD}{"$web.$topic"} = 1;
        }
    }
    $text = $_DEFAULT unless defined $text;
    $text = ''        unless defined $text;

    $this->addToZone( 'head', $_DEFAULT, $text, $requires );
    return '';
}

##############################################################################
sub ADDTOZONE {
    my ( $foswiki, $params, $topicObject ) = @_;

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
        ( $web, $topic ) = $foswiki->normalizeWebTopicName( $web, $topic );

        # generate TML only and delay expansion until the zone is rendered
        $text = '%INCLUDE{"' . $web . '.' . $topic . '"';
        $text .= ' section="' . $section . '"' if $section;
        $text .= ' warn="off"}%';
    }

    foreach my $zone ( split( /\s*,\s*/, $zones ) ) {
        $this->addToZone( $zone, $id, $text, $requires );
    }

    return (DEBUG) ? "<!--A2Z:$id-->" : '';
}

##############################################################################
# captures all RENDERZONE macros and inserts a token to finally insert the
# one's content at the end of the rendering pipeline
sub RENDERZONE {
    my ( $foswiki, $params, $topicObject ) = @_;

    # Note, that RENDERZONE is not expanded as soon as this function is called.
    # Instead, a placeholder is inserted into the page. Rendering the current
    # page continues as normal. That way all calls to ADDTOZONE will gather
    # content until the end of the rendering pipeline. Only then will all
    # of the zones' content be registered. The placeholder for RENDERZONE
    # will be expanded at the very end within the Foswiki::writeCompletePage
    # method.

    my $id = scalar( keys %{ $this->{_renderZonePlaceholder} } );

    $this->{_renderZonePlaceholder}{$id} = {
        params      => $params,
        topicObject => $topicObject,
    };

    return
        $Foswiki::RENDERZONE_MARKER
      . "RENDERZONE{$id}"
      . $Foswiki::RENDERZONE_MARKER;
}

=begin TML

---++ ObjectMethod addToZone($zone, $id, $data, $requires)

Add =$data= identified as =$id= to =$zone=, which will later be expanded (with
renderZone() - implements =%<nop>RENDERZONE%=). =$ids= are unique within
the zone that they are added - dependencies between =$ids= in different zones 
will not be resolved, except for the special case of =head= and =script= zones
when ={MergeHeadAndScriptZones}= is enabled.

In this case, they are treated as separate zones when adding to them, but as
one merged zone when rendering, i.e. a call to render either =head= or =script=
zones will actually render both zones in this one call. Both zones are undef'd
afterward to avoid double rendering of content from either zone, to support
proper behaviour when =head= and =script= are rendered with separate calls even
when ={MergeHeadAndScriptZones}= is set. See ZoneTests/explicit_RENDERZONE*.

This behaviour allows an addToZone('head') call to require an id that has been
added to =script= only.

   * =$zone=      - name of the zone
   * =$id=        - unique identifier
   * =$data=      - content
   * =$requires=  - optional, comma-separated string of =$id= identifiers
                    that should precede the content

<blockquote class="foswikiHelp">%X%
*Note:* Read the developer supplement at Foswiki:Development.AddToZoneFromPluginHandlers if you
are calling =addToZone()= from a rendering or macro/tag-related plugin handler
</blockquote>

Implements =%<nop>ADDTOZONE%=.

=cut

sub addToZone {
    my ( $foswiki, $zone, $id, $data, $requires ) = @_;

    $requires ||= '';

    # get a random one
    unless ($id) {
        $id = int( rand(10000) ) + 1;
    }

    # get zone, or create record
    my $thisZone = $this->{_zones}{$zone};
    unless ( defined $thisZone ) {
        $this->{_zones}{$zone} = $thisZone = {};
    }

    my @requires;
    foreach my $req ( split( /\s*,\s*/, $requires ) ) {
        unless ( $thisZone->{$req} ) {
            $thisZone->{$req} = {
                id              => $req,
                zone            => $zone,
                requires        => [],
                missingrequires => [],
                text            => '',
                populated       => 0
            };
        }
        push( @requires, $thisZone->{$req} );
    }

    # store record within zone
    my $zoneID = $thisZone->{$id};
    unless ($zoneID) {
        $zoneID = { id => $id };
        $thisZone->{$id} = $zoneID;
    }

    # override previous properties
    $zoneID->{zone}            = $zone;
    $zoneID->{requires}        = \@requires;
    $zoneID->{missingrequires} = [];
    $zoneID->{text}            = $data;
    $zoneID->{populated}       = 1;

    return;
}

sub _renderZoneById {
    my ( $foswiki, $id ) = @_;

    return '' unless defined $id;

    my $renderZone = $this->{_renderZonePlaceholder}{$id};

    return '' unless defined $renderZone;

    my $params      = $renderZone->{params};
    my $topicObject = $renderZone->{topicObject};
    my $zone        = $params->{_DEFAULT} || $params->{zone};

    return $this->_renderZone( $zone, $params, $topicObject );
}

# This private function is used in ZoneTests
sub _renderZone {
    my ( $this, $zone, $params, $topicObject ) = @_;

    # Check the zone is defined and has not already been rendered
    return '' unless $zone && $this->{_zones}{$zone};

    $params->{header} ||= '';
    $params->{footer} ||= '';
    $params->{chomp}  ||= 'off';
    $params->{missingformat} = '$id: requires= missing ids: $missingids';
    $params->{format}        = '$item<!--<literal>$missing</literal>-->'
      unless defined $params->{format};
    $params->{separator} = '$n()' unless defined $params->{separator};

    unless ( defined $topicObject ) {
        $topicObject =
          Foswiki::Meta->new( $this, $this->{webName}, $this->{topicName} );
    }

    # Loop through the vertices of the graph, in any order, initiating
    # a depth-first search for any vertex that has not already been
    # visited by a previous search. The desired topological sorting is
    # the reverse postorder of these searches. That is, we can construct
    # the ordering as a list of vertices, by adding each vertex to the
    # start of the list at the time when the depth-first search is
    # processing that vertex and has returned from processing all children
    # of that vertex. Since each edge and vertex is visited once, the
    # algorithm runs in linear time.
    my %visited;
    my @total;

    # When {MergeHeadAndScriptZones} is set, try to treat head and script
    # zones as merged for compatibility with ADDTOHEAD usage where requirements
    # have been moved to the script zone. See ZoneTests/Item9317
    if ( $Foswiki::cfg{MergeHeadAndScriptZones}
        and ( ( $zone eq 'head' ) or ( $zone eq 'script' ) ) )
    {
        my @zoneIDs = (
            values %{ $this->{_zones}{head} },
            values %{ $this->{_zones}{script} }
        );

        foreach my $zoneID (@zoneIDs) {
            $this->_visitZoneID( $zoneID, \%visited, \@total );
        }
        undef $this->{_zones}{head};
        undef $this->{_zones}{script};
    }
    else {
        my @zoneIDs = values %{ $this->{_zones}{$zone} };

        foreach my $zoneID (@zoneIDs) {
            $this->_visitZoneID( $zoneID, \%visited, \@total );
        }

        # kill a zone once it has been rendered, to prevent it being
        # added twice (e.g. by duplicate %RENDERZONEs or by automatic
        # zone expansion in the head or script)
        undef $this->{_zones}{$zone};
    }

    # nothing rendered for a zone with no ADDTOZONE calls
    return '' unless scalar(@total) > 0;

    my @result        = ();
    my $missingformat = $params->{missingformat};
    foreach my $item (@total) {
        my $text       = $item->{text};
        my @missingids = @{ $item->{missingrequires} };
        my $missingformat =
          ( scalar(@missingids) ) ? $params->{missingformat} : '';

        if ( $params->{'chomp'} ) {
            $text =~ s/^\s+//g;
            $text =~ s/\s+$//g;
        }

        # ASSERT($text, "No content for zone id $item->{id} in zone $zone")
        # if DEBUG;

        next unless $text;
        my $id = $item->{id} || '';
        my $line = $params->{format};
        if ( scalar(@missingids) ) {
            $line =~ s/\$missing\b/$missingformat/g;
            $line =~ s/\$missingids\b/join(', ', @missingids)/ge;
        }
        else {
            $line =~ s/\$missing\b/\$id/g;
        }
        $line =~ s/\$item\b/$text/g;
        $line =~ s/\$id\b/$id/g;
        $line =~ s/\$zone\b/$item->{zone}/g;
        $line = expandStandardEscapes($line);
        push @result, $line if $line;
    }
    my $result =
      expandStandardEscapes( $params->{header}
          . join( $params->{separator}, @result )
          . $params->{footer} );

    # delay rendering the zone until now
    $result = Foswiki::Func::expandCommonVariables($result);
    $result = Foswiki::Func::renderText($result);
######## Looked like this on trunk
    #    $result = $topicObject->expandMacros($result);
    #    $result = $topicObject->renderTML($result);
    #

    return $result;
}

sub _visitZoneID {
    my ( $this, $zoneID, $visited, $list ) = @_;

    return if $visited->{$zoneID};

    $visited->{$zoneID} = 1;

    foreach my $requiredZoneID ( @{ $zoneID->{requires} } ) {
        my $zoneIDToVisit;

        if ( $Foswiki::cfg{MergeHeadAndScriptZones}
            and not $requiredZoneID->{populated} )
        {

            # Compatibility mode, where we are trying to treat head and script
            # zones as merged, and a required ZoneID isn't populated. Try
            # opposite zone to see if it exists there instead. Item9317
            if ( $requiredZoneID->{zone} eq 'head' ) {
                $zoneIDToVisit =
                  $this->{_zones}{script}{ $requiredZoneID->{id} };
            }
            else {
                $zoneIDToVisit = $this->{_zones}{head}{ $requiredZoneID->{id} };
            }
            if ( not $zoneIDToVisit->{populated} ) {

                # Oops, the required ZoneID doesn't exist there either; reset
                $zoneIDToVisit = $requiredZoneID;
            }
        }
        else {
            $zoneIDToVisit = $requiredZoneID;
        }
        $this->_visitZoneID( $zoneIDToVisit, $visited, $list );

        if ( not $zoneIDToVisit->{populated} ) {

            # Finally, we got to here and the required ZoneID just cannot be
            # found in either head or script (or other) zones, so record it for
            # diagnostic purposes ($missingids format token)
            push( @{ $zoneID->{missingrequires} }, $zoneIDToVisit->{id} );
        }
    }
    push( @{$list}, $zoneID );

    return;
}

# This private function is used in ZoneTests
sub _renderZones {
    my ( $this, $text ) = @_;

    # Render zones that were pulled out by Foswiki/Macros/RENDERZONE.pm
    # NOTE: once a zone has been rendered it is cleared, so cannot
    # be rendered again.

    $text =~ s/${RENDERZONE_MARKER}RENDERZONE{(.*?)}${RENDERZONE_MARKER}/
      _renderZoneById($this, $1)/geo;

    # get the head zone and insert it at the end of the </head>
    # *if it has not already been rendered*
    my $headZone = _renderZone( $this, 'head', { chomp => "on" } );
    $text =~ s!(</head>)!$headZone\n$1!i if $headZone;

  # SMELL: Item9480 - can't trust that _renderzone(head) above has truly
  # flushed both script and head zones empty when {MergeHeadAndScriptZones} = 1.
    my $scriptZone = _renderZone( $this, 'script', { chomp => "on" } );
    $text =~ s!(</head>)!$scriptZone\n$1!i if $scriptZone;

    chomp($text);

    return $text;
}

1;
