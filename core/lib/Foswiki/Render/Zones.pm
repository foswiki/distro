# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Render::Zones

Support for rendering anchors. Objects of this class represent
a set of generated anchor names, which must be unique in a rendering
context (topic). The renderer maintains a set of these objects, one
for each topic, to ensure that anchor names are not re-used.

=cut

package Foswiki::Render::Zones;

use strict;
use warnings;
use Assert;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ ClassMethod new()

Construct a new zones set.

=cut

sub new {
    my ( $class, $session ) = @_;
    my $this = bless( { session => $session }, $class );

    # hash of zone records
    $this->{_zones} = ();

    # hash of occurences of RENDERZONE
    $this->{_renderZonePlaceholder} = ();

    return $this;
}

=begin TML

---++ ObjectMethod finish()
Break circular references.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;
    undef $this->{_zones};
    undef $this->{_renderZonePlaceholder};
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
*Note:* Read the developer supplement at Foswiki:Development.AddToZoneFromPluginHandlers
if you are calling =addToZone()= from a rendering or macro/tag-related plugin handler
</blockquote>
<blockquote class="foswikiHelp">%X%
*Note:* Macros will be expanded in all zones.  TML markup will not be expanded
in the =head= and =scripts= zones.  Any formatting in =head= and =scripts= zones
including [<nop>[TML links]] must be done directly using HTML. TML pseudo-tags like
=nop=. =verbatim=, =literal=.  and =noautolink= are removed from =head= and =script=
zones and have no influence on the markup.
All other zones will be rendered as a normal topic.
</blockquote>

Implements =%<nop>ADDTOZONE%=.

=cut

sub addToZone {
    my ( $this, $zone, $id, $data, $requires ) = @_;

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

    # add class to script and link data
    $data =~ s/<script\s+((?![^>]*class=))/<script class='\$zone \$id' $1/g;
    $data =~ s/<link\s+((?![^>]class=))/<link class='\$zone \$id' $1/g;
    $data =~ s/<style\s+((?![^>]*class=))/<style class='\$zone \$id' $1/g;

    # override previous properties
    $zoneID->{zone}            = $zone;
    $zoneID->{requires}        = \@requires;
    $zoneID->{missingrequires} = [];
    $zoneID->{text}            = $data;
    $zoneID->{populated}       = 1;

    #print STDERR "zoneID " . Data::Dumper::Dumper( \$zoneID);

    return;
}

sub _renderZoneById {
    my $this = shift;
    my $id   = shift;

    return '' unless defined $id;

    my $renderZone = $this->{_renderZonePlaceholder}{$id};

    return '' unless defined $renderZone;

    my $params      = $renderZone->{params};
    my $topicObject = $renderZone->{topicObject};
    my $zone        = $params->{_DEFAULT} || $params->{zone};

#return "\n<!--ZONE $id-->\n" . _renderZone( $this, $zone, $params, $topicObject ) . "\n<!--ENDZONE $id-->\n" ;
    return _renderZone( $this, $zone, $params, $topicObject );
}

# This private function is used in ZoneTests
sub _renderZone {
    my ( $this, $zone, $params, $topicObject ) = @_;

    my $session = $Foswiki::Plugins::SESSION;

    # Check the zone is defined and has not already been rendered
    return '' unless $zone && $this->{_zones}{$zone};

    $params->{header} ||= '';
    $params->{footer} ||= '';
    $params->{chomp}  ||= 'off';
    $params->{missingformat} = '$id: requires= missing ids: $missingids';
    $params->{format}        = '$item<!--<literal>$missing</literal>-->'
      unless defined $params->{format};
    $params->{separator} = '$n()' unless defined $params->{separator};

#print STDERR "_renderZone called with " . Data::Dumper::Dumper( \$topicObject );

    unless ( defined $topicObject ) {
        $topicObject =
          Foswiki::Meta->new( $session, $session->{webName},
            $session->{topicName} );
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
        my @zoneIDs =
          sort { $a->{id} cmp $b->{id} } values %{ $this->{_zones}{$zone} };

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
        push @result, $line if $line;
    }
    my $result =
      Foswiki::expandStandardEscapes( $params->{header}
          . join( $params->{separator}, @result )
          . $params->{footer} );

    # delay rendering the zone until now
    $result = $topicObject->expandMacros($result);

# TML should not be rendered in the HEAD, which includes the head & script zones.
# Other zones will be rendered normally.
    if ( $zone eq 'head' || $zone eq 'script' ) {
        $result =~ s#</?(:?literal|noautolink|nop|verbatim)>##g
          ;    # Clean up TML pseudo tags
    }
    else {
        $result = $topicObject->renderTML($result);
    }

    return $result;
}

sub _visitZoneID {
    my ( $this, $zoneID, $visited, $list ) = @_;

    return if $visited->{$zoneID};

    $visited->{$zoneID} = 1;

    foreach my $requiredZoneID ( sort { $a->{id} cmp $b->{id} }
        @{ $zoneID->{requires} } )
    {
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

    $text =~
s/${Foswiki::RENDERZONE_MARKER}RENDERZONE\{(.*?)\}${Foswiki::RENDERZONE_MARKER}/
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
