#
# Copyright (C) 2004-2012 C-Dot Consultants - All rights reserved
# Copyright (C) 2008-2019 Foswiki Contributors
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
package Foswiki::Contrib::Build;

use strict;
use warnings;

use POSIX qw(strftime locale_h);

=begin TML

---++++ target_release
Release target, builds release zip by creating a full release directory
structure in /tmp and then zipping it in one go. Only files explicitly listed
in the MANIFEST are released. Automatically runs =filter= on all =.txt= files
in the MANIFEST.

=cut

sub target_release {
    my $this = shift;

    setlocale( LC_TIME, "en_US.UTF-8" );
    $this->{RELEASE} = strftime( "%d %b %Y", localtime );

    push( @Foswiki::Contrib::Build::stageFilters,
        { RE => qr/\.pm$/, filter => '_date_filter_file' } );
    push( @Foswiki::Contrib::Build::stageFilters,
        { RE => qr/\.txt$/, filter => '_date_filter_file' } );
    push( @Foswiki::Contrib::Build::stageFilters,
        { RE => qr/\.(css|js)$/, filter => '_date_filter_file' } );

    print <<GUNK;

Building release $this->{RELEASE} of $this->{project}, from version $this->{VERSION}
GUNK
    if ( $this->{-v} ) {
        print 'Package name will be ', $this->{project}, "\n";
        print 'Topic name will be ', $this->getTopicName(), "\n";
    }

    $this->build('compress');
    $this->build('build');
    $this->build('installer');
    $this->build('stage');
    $this->build('archive');
}

sub _date_filter_file {
    my ( $this, $from, $to ) = @_;

    $this->filter_file(
        $from, $to,
        sub {
            my ( $this, $text ) = @_;

            if ( $text =~ s/%(25)?\$RELEASE%(25)?/$this->{RELEASE}/gm ) {
                print "RELEASE updated to $this->{RELEASE} in $to\n";
            }

            return $text;
        }
    );
}

1;
