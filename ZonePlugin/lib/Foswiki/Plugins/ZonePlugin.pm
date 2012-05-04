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
use Foswiki::Func    ();
use Foswiki::Plugins ();

our $VERSION = '$Rev$';
our $RELEASE = '3.1';
our $SHORTDESCRIPTION =
  'Gather content of a page in named zones while rendering it';
our $NO_PREFS_IN_TOPIC = 1;

# hash of all content posted to the named zone using ADDTOZONE
our %ZONES;

# hash tracking occurences of RENDERZONE, that are replaced with a token during
# first pass, then expanded showing all gathered content in completePageHandler
our %RENDERZONE;

# token used to generate the RENDERZONE placeholder while parsing
our $translationToken = "\03";

# monkey-patch API ###########################################################
BEGIN {
    if ( $Foswiki::cfg{Plugins}{ZonePlugin}{Enabled}
        && !defined(&Foswiki::Func::addToZone) )
    {
        no warnings 'redefine';
        *Foswiki::Func::addToZone = \&Foswiki::Plugins::ZonePlugin::addToZone;
        *Foswiki::Func::addToHEAD = \&Foswiki::Plugins::ZonePlugin::addToHead;
        use warnings 'redefine';
    }
    else {

        #print STDERR "suppressing monkey patching via ZonePlugin\n";
    }
}

##############################################################################
sub initPlugin {

    if ( $Foswiki::Plugins::VERSION >= 2.1 ) {
        Foswiki::Func::writeWarning(
            "ZonePlugin is not compatible with your Foswiki version");
        return 0;
    }

    Foswiki::Func::registerTagHandler( 'ADDTOZONE',  \&ADDTOZONE );
    Foswiki::Func::registerTagHandler( 'RENDERZONE', \&RENDERZONE );

    # redefine
    Foswiki::Func::registerTagHandler( 'ADDTOHEAD', \&ADDTOHEAD );

    Foswiki::Func::writeWarning(
        "running in backwards compatibility mode ... page layout suboptimal")
      if $Foswiki::cfg{ZonePlugin}{Warnings};

    return 1;
}

##############################################################################
sub completePageHandler {

    # my ($text, $hdr)

    $_[0] =~
s/${translationToken}RENDERZONE{(.*?)}${translationToken}/renderZoneById($1)/ge;

    # get the head zone ones again and insert it at </head>
    my $headZone = renderZone( 'head', { chomp => "on" } ) || '';
    $_[0] =~ s!(</head>)!$headZone\n$1!i if $headZone;

    # get the script zone ones again and insert it at </body>
    my $scriptZone = renderZone( 'script', { chomp => "on" } ) || '';
    $_[0] =~ s!(</head>)!$scriptZone\n$1!i;

    # finally forget it
    %ZONES      = ();
    %RENDERZONE = ();

}

##############################################################################
sub ADDTOHEAD {
    my ( $sessions, $params, $theTopic, $theWeb ) = @_;

    my $id       = $params->{_DEFAULT} || '';
    my $topic    = $params->{topic}    || '';
    my $text     = $params->{text}     || '';
    my $requires = $params->{requires} || '';

    # SMELL: strange use case
    $text = $id unless $text;

    Foswiki::Func::writeWarning(
        "use of deprecated ADDTOHEAD in $theWeb.$theTopic")
      if $Foswiki::cfg{ZonePlugin}{Warnings};

    addToHead( $id, $text, $requires, 1 );
    return '';
}

##############################################################################
sub ADDTOZONE {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    my $zones = $params->{_DEFAULT} || $params->{zone} || 'head';
    my $id    = $params->{id}       || $params->{tag}  || '';
    my $topic = $params->{topic}    || '';
    my $section  = $params->{section}  || '';
    my $requires = $params->{requires} || '';
    my $text     = $params->{text}     || '';
    my $web      = $theWeb;

    if ( $topic || $section ) {
        $web   ||= $theWeb;
        $topic ||= $theTopic;
        ( $web, $topic ) = Foswiki::Func::normalizeWebTopicName( $web, $topic );
        $text = '%INCLUDE{"' . $web . '.' . $topic . '"';
        $text .= ' section="' . $section . '"' if $section;
        $text .= ' warn="off"}%';
    }

    foreach my $zone ( split( /\s*,\s*/, $zones ) ) {
        if ( $zone eq 'body' ) {

#print STDERR "WARNING: ADDTOZONE was called for zone 'body' ... rerouting it to zone 'script' ... please fix your templates\n";
            $zone = 'script';
        }
        addToZone( $zone, $id, $text, $requires );
    }

    return '';
}

##############################################################################
# backwards compatibility
sub addToHead {
    my ( $id, $text, $requires, $nowarn ) = @_;

    if ( $Foswiki::cfg{ZonePlugin}{Warnings} && !$nowarn ) {

        # suppress warning of when it has already been emited during ADDTOHEAD
        my ( $package, $filename, $line ) = caller;
        Foswiki::Func::writeWarning(
            "use of deprecated API addToHEAD at $package line $line");
    }

    addToZone( 'head', $id, $text, $requires );

    return '';
}

##############################################################################
sub addToZone {
    my ( $zone, $id, $text, $requires ) = @_;

    return unless $text;
    $requires ||= '';

    unless ($id) {

        # get a random one
        $id = int( rand(10000) ) + 1;
    }

    # get zone, or create record
    my $thisZone = $ZONES{$zone};
    unless ( defined $thisZone ) {
        $ZONES{$zone} = $thisZone = {};
    }

    my @requires;
    foreach my $req ( split( /\s*,\s*/, $requires ) ) {
        unless ( $thisZone->{$req} ) {
            $thisZone->{$req} = {
                id       => $req,
                requires => [],
                text     => '',
            };
        }
        push( @requires, $thisZone->{$req} );
    }

    # store records
    my $record = $thisZone->{$id};
    unless ($record) {
        $record = { id => $id };
        $thisZone->{$id} = $record;
    }

    # override previous properties
    $record->{requires} = \@requires;
    $record->{text}     = $text;
}

##############################################################################
# captures all RENDERZONE macros and inserts a token to finally insert the
# one's content at the end of the rendering pipeline
sub RENDERZONE {
    my ( $sessions, $params, $topic, $web ) = @_;

    my $id = scalar( keys %RENDERZONE );

    $RENDERZONE{$id} = {
        params => $params,
        topic  => $topic,
        web    => $web,
    };

    return $translationToken . "RENDERZONE{$id}" . $translationToken;
}

##############################################################################
sub renderZoneById {
    my $id = shift;

    return '' unless defined $id;

    my $renderZone = $RENDERZONE{$id};

    return '' unless defined $renderZone;

    my $web    = $renderZone->{web};
    my $topic  = $renderZone->{topic};
    my $params = $renderZone->{params};
    my $zone   = $params->{_DEFAULT} || $params->{zone};

    return renderZone( $zone, $params, $web, $topic );
}

##############################################################################
sub renderZone {
    my ( $zone, $params, $web, $topic ) = @_;

    return '' unless $zone && $ZONES{$zone};

    $params->{header} ||= '';
    $params->{footer} ||= '';
    $params->{chomp}  ||= 'off';

    $params->{format} = '$item <!-- $id -->' unless defined $params->{format};
    $params->{separator} = '$n' unless defined $params->{separator};

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
    foreach my $v ( values %{ $ZONES{$zone} } ) {
        visit( $v, \%visited, \@total );
    }

    # kill a zone ones it has been rendered
    undef $ZONES{$zone};

    my @result = ();
    foreach my $item (@total) {
        my $text = $item->{text};
        if ( $params->{'chomp'} ) {
            $text =~ s/^\s+//g;
            $text =~ s/\s+$//g;
        }
        next unless $text;
        my $id = $item->{id} || '';
        my $line = $params->{format};
        $line =~ s/\$item\b/$text/g;
        $line =~ s/\$id\b/$id/g;
        $line =~ s/\$zone\b/$zone/g;
        next unless $line;
        push @result, $line if $line;
    }

    my $result =
      Foswiki::Func::decodeFormatTokens( $params->{header}
          . join( $params->{separator}, @result )
          . $params->{footer} );

    $result = Foswiki::Func::expandCommonVariables( $result, $topic, $web );
    $result = Foswiki::Func::renderText( $result, $web, $topic );

    return $result;
}

##############################################################################
sub visit {
    my ( $v, $visited, $list ) = @_;

    return if $visited->{$v};
    $visited->{$v} = 1;

    foreach my $r ( @{ $v->{requires} } ) {
        visit( $r, $visited, $list );
    }

    push( @$list, $v );
}

1;
