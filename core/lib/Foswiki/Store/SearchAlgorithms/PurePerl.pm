# See bottom of file for license and copyright information

package Foswiki::Store::SearchAlgorithms::PurePerl;

=begin TML

---+ package Foswiki::Store::SearchAlgorithms::PurePerl

Pure perl implementation of the RCS cache search.

---++ search($searchString, $topics, $options, $sDir) -> \%seen
Search .txt files in $dir for $string. See RcsFile::searchInWebContent
for details.

=cut

sub search {
    my ( $searchString, $topics, $options, $sDir ) = @_;

    local $/ = "\n";
    my %seen;
    if ( $options->{type} && $options->{type} eq 'regex' ) {

        # Escape /, used as delimiter. This also blocks any attempt to use
        # the search string to execute programs on the server.
        $searchString =~ s!/!\\/!g;
    }
    else {

        # Escape non-word chars in search string for plain text search
        $searchString =~ s/(\W)/\\$1/g;
    }

    # Convert GNU grep \< \> syntax to \b
    $searchString =~ s/(?<!\\)\\[<>]/\\b/g;
    $searchString =~ s/^(.*)$/\\b$1\\b/go if $options->{'wordboundaries'};
    my $doMatch;
    if ($options->{casesensitive}) {
        $doMatch = sub { $_[0] =~ m/$searchString/ };
    } else {
        $doMatch = sub { $_[0] =~ m/$searchString/i };
    }
  FILE:
    foreach my $file (@$topics) {
        next unless open( FILE, '<', "$sDir/$file.txt" );
        while ( my $line = <FILE> ) {
            if ( &$doMatch($line) ) {
                chomp($line);
                push( @{ $seen{$file} }, $line );
                if ( $options->{files_without_match} ) {
                    close(FILE);
                    next FILE;
                }
            }
        }
        close(FILE);
    }
    return \%seen;
}

1;
__DATA__
#
# Copyright (C) 2008-2009 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2007 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
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
#
