#
# Copyright (C) 2004-2012 C-Dot Consultants - All rights reserved
# Copyright (C) 2008-2010 Foswiki Contributors
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

our $DEFAULTCUSTOMERDB = "$ENV{HOME}/customerDB";

sub _tracked_filter_file {
    my ( $this, $from, $to ) = @_;
    $this->filter_file(
        $from, $to,
        sub {
            my ( $this, $text ) = @_;
            $text =~ s/%\$RELEASE%/$this->{RELEASE}/gm;
            if ( $text =~ s/%\$TRACKINGCODE%/$this->{TRACKINGCODE}/gm ) {
                print "TRACKINGCODE expanded in $to\n";
            }
            return $text;
        }
    );
}

sub target_tracked {
    my $this = shift;
    local $/ = "\n";
    my %customers;
    my @cuss;
    my $db = prompt( "Location of customer database", $DEFAULTCUSTOMERDB );
    if ( open( F, '<', $db ) ) {
        while ( my $customer = <F> ) {
            chomp($customer);
            if ( $customer =~ /^(.+)\s(\S+)\s*$/ ) {
                $customers{$1} = $2;
            }
        }
        close(F);
        @cuss = sort keys %customers;
        my $i = 0;
        print join( "\n", map { $i++; "$i. $_" } @cuss ) . "\n";
    }
    else {
        print "$db not found: $@\n";
        print "Creating new customer DB\n";
    }

    my $customer = prompt("Number (or name) of customer");
    if ( $customer =~ /^\d+$/i && $customer <= scalar(@cuss) ) {
        $customer = $cuss[ $customer - 1 ];
    }

    if ( $customers{$customer} ) {
        $this->{TRACKINGCODE} = $customers{$customer};
    }
    else {
        print "Customer '$customer' not known\n";
        exit 0 unless ask("Would you like to add a new customer?");

        $this->{TRACKINGCODE} = Digest::MD5::md5_base64( $customer . $db );
        $customers{$customer} = $this->{TRACKINGCODE};

        open( F, '>', $db ) || die $!;
        print F join( "\n", map { "$_ $customers{$_}" } keys %customers )
          . "\n";
        close(F);
    }

    print STDERR "$customer tracking code $customers{$customer}\n";
    $this->{RELEASE} =~ s/%\$TRACKINGCODE%/$this->{TRACKINGCODE}/g;

    # Assume that target_stage is going to be run, and push new filters
    push( @Foswiki::Contrib::Build::stageFilters,
        { RE => qr/\.pm$/, filter => '_tracked_filter_file' } );
    push( @Foswiki::Contrib::Build::stageFilters,
        { RE => qr/\.txt$/, filter => '_tracked_filter_file' } );
    push( @Foswiki::Contrib::Build::stageFilters,
        { RE => qr/\.(css|js)$/, filter => '_tracked_filter_file' } );
    $this->build('release');
}

1;
