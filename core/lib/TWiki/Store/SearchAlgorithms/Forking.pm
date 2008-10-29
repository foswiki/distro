# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2002 John Talintyre, john.talintyre@btinternet.com
# Copyright (C) 2002-2007 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.

package TWiki::Store::SearchAlgorithms::Forking;

use strict;

=pod

---+ package TWiki::Store::SearchAlgorithms::Forking

Forking implementation of the RCS cache search.

---++ search($searchString, $topics, $options, $sDir) -> \%seen
Search .txt files in $dir for $searchString. See RcsFile::searchInWebContent
for details.

=cut

sub search {
    my( $searchString, $topics, $options, $sDir, $sandbox ) = @_;

    # Default (Forking) search

    # SMELL: I18N: 'grep' must use locales if needed,
    # for case-insensitive searching.
    my $program = '';

    if( $options->{type} &&
          ( $options->{type} eq 'regex' || $options->{wordboundaries} )) {
        $program = $TWiki::cfg{RCS}{EgrepCmd};
    } else {
        $program = $TWiki::cfg{RCS}{FgrepCmd};
    }

    if( $options->{casesensitive} ) {
        $program =~ s/%CS{(.*?)\|.*?}%/$1/g;
    } else {
        $program =~ s/%CS{.*?\|(.*?)}%/$1/g;
    }
    if( $options->{files_without_match} ) {
        $program =~ s/%DET{.*?\|(.*?)}%/$1/g;
    } else {
        $program =~ s/%DET{(.*?)\|.*?}%/$1/g;
    }
    if ($options->{wordboundaries} ) {
        # Item5529: Can't use quotemeta because $searchString may be UTF8 encoded
        $searchString =~ s#([][|/\\$^*()+{};@?.{}])#\\$1#g;
        $searchString = '\b'.$searchString.'\b';
    }

    if ($TWiki::cfg{DetailedOS} eq 'MSWin32') {
    	#try to escape the ^ ad "" for native windows grep and apache
        $searchString =~ s/\[\^/[^^/g;
        $searchString =~ s/"/""/g;
    }

    # process topics in sets, fix for Codev.ArgumentListIsTooLongForSearch
    my $maxTopicsInSet = 512; # max number of topics for a grep call
    #TODO: the number is actually dependant on the length of the path to each file
    #SMELL: the following while loop should probably be made by sysCommand, as this is a leaky abstraction.
    ##heck, on pre WinXP its only 2048, post XP its 8192 - http://support.microsoft.com/kb/830473
    $maxTopicsInSet = 128 if ($TWiki::cfg{DetailedOS} eq 'MSWin32');
    my @take = @$topics;
    my @set = splice( @take, 0, $maxTopicsInSet );
    my $matches = '';

    while( @set ) {
        @set = map { "$sDir/$_.txt" } @set;
        my ($m, $exit ) = $sandbox->sysCommand(
            $program,
            TOKEN => $searchString,
            FILES => \@set);
        # man grep: "Normally, exit status is 0 if selected lines are found
        # and 1 otherwise. But the exit status is 2 if an error occurred,
        # unless the -q or --quiet or --silent option is used and a selected
        # line is found."
        throw Error::Simple("$program Grep for '$searchString' returned error")
          if $exit > 1;
        $matches .= $m unless $exit;
        @set = splice( @take, 0, $maxTopicsInSet );
    }
    my %seen;
    # Note use of / and \ as dir separators, to support Winblows
    $matches =~ s/([^\/\\]*)\.txt(:(.*))?$/push( @{$seen{$1}}, ($3||'') ); ''/gem;

    return \%seen;
}

1;
