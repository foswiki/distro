# See bottom of file for license and copyright information
package Foswiki::Plugins::EditTablePlugin::EditTableData;

use strict;
use warnings;
use Assert;

sub new {
    my ($class) = @_;
    my $this = {
        pretag         => undef, # text before EDITTABLE tag
        tag            => undef, # full EDITTABLE{} tag
        posttag        => undef, # text after EDITTABLE tag
        lines          => undef, # ref of array of text lines
        rowCount       => 0,     # number of rows
        headerRowCount => 0,     # number of rows in header (set by TablePlugin)
        footerRowCount => 0,     # number of rows in footer (set by TablePlugin)
    };
    bless $this, $class;
    return $this;
}

=begin TML

getTableStatistics( $changesMap ) -> \$statistics

Creates a 'statistics' hash that shows the result of applying changes to the EditTableData object:
   * {rowCount} : the total number of rows, including header and footer rows
   * {added} : the added rows
   * {deleted} : the deleted rows
   * {bodyRowCount} : the number of body rows

=cut

sub getTableStatistics {
    my ( $this, $inChangesMap ) = @_;

    my $stats = {};

    my $changeStats = _getTableChangeStatistics($inChangesMap);
    $stats->{rowCount} =
      $this->{rowCount} + $changeStats->{added} - $changeStats->{deleted};
    $stats->{added}   = $changeStats->{added};
    $stats->{deleted} = $changeStats->{deleted};

    my $bodyRowCount = $this->{rowCount};
    $bodyRowCount += $stats->{added};
    $bodyRowCount -= $stats->{deleted};
    $bodyRowCount -= $this->{footerRowCount};
    $bodyRowCount -= $this->{headerRowCount};
    $bodyRowCount = 0 if $bodyRowCount < 0;
    $stats->{bodyRowCount} = $bodyRowCount;

    $stats->{headerRowCount} = $this->{headerRowCount};
    $stats->{footerRowCount} = $this->{footerRowCount};

    return $stats;
}

=begin TML

=cut

sub applyChangesToChangesMap {
    my ( $inChangesMap, $inNewChangesMap ) = @_;

    return _mergeHashes( $inChangesMap, $inNewChangesMap );
}

=begin TML

StaticMethod _mergeHashes (\%a, \%b ) -> \%merged

Merges 2 hash references.

=cut

sub _mergeHashes {
    my ( $A, $B ) = @_;

    my %merged = ();
    while ( my ( $k, $v ) = each(%$A) ) {
        $merged{$k} = $v;
    }
    while ( my ( $k, $v ) = each(%$B) ) {
        $merged{$k} = $v;
    }
    return \%merged;
}

=begin TML

StaticMethod createTableChangesMap( $paramString ) -> \%map

Parses the paramString to a hash.
paramString can contain a list of key-value pairs using the structure (rowNumber_1=rowState_1,rowNumber_2=rowState_2,...), for example:

	0=0,1=0,2=1

Row states are:
	-1: row deleted
	0: nothing changed
	1: row added
	2: reset (no action)

Not all rows have to be present in the param.

=cut

sub createTableChangesMap {
    my ($inParamString) = @_;

    my $map = {};
    return $map if !$inParamString;

    my @keyValues = split( /\s*,\s*/, $inParamString );

    foreach my $keyValue (@keyValues) {
        my ( $key, $value ) = $keyValue =~ m/^\s*(.*?)\s*=\s*(.*?)\s*$/;
        $map->{$key} = $value;
    }
    return $map;
}

=begin TML

StaticMethod tableChangesMapToParamString( \%tableChanges ) -> $paramString

In the reverse operation to createTableChangesMap, converts a tableChanges hash to a param string.

For example, 
{
	'0' => '0',
	'3' => '1'
}
will be converted to:
'0=0,3=1'

=cut

sub tableChangesMapToParamString {
    my ($inTableChanges) = @_;

    my @params = ();
    for my $key ( sort keys %{$inTableChanges} ) {
        my $value = $inTableChanges->{$key};
        push( @params, "$key=$value" );
    }
    return join( ',', @params );
}

=begin TML

StaticMethod _getTableChangeStatistics

=cut

sub _getTableChangeStatistics {
    my ($inTableChanges) = @_;

    my $stats = {};

    # added
    $stats->{added} = 0;
    for my $key ( keys %{$inTableChanges} ) {
        my $value = $inTableChanges->{$key};
        $stats->{added}++ if $value == 1;
    }

    # deleted
    $stats->{deleted} = 0;
    for my $key ( keys %{$inTableChanges} ) {
        my $value = $inTableChanges->{$key};
        $stats->{deleted}++ if $value == -1;
    }

    return $stats;
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2008-2009 Arthur Clemens, arthur@visiblearea.com
and Foswiki contributors
Copyright (C) 2002-2007 Peter Thoeny, peter@thoeny.org and
TWiki Contributors.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
