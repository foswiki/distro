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

our @twikiFilters = (
    { RE => qr/\.pm$/,          filter => '_twikify_perl' },
    { RE => qr/\.pm$/,          filter => '_twikify_txt' },
    { RE => qr#/Config.spec$#,  filter => '_twikify_perl' },
    { RE => qr#/MANIFEST$#,     filter => '_twikify_manifest' },
    { RE => qr#/DEPENDENCIES$#, filter => '_twikify_perl' },
);

# Create a TWiki version of the extension by simple transformation of files.
# Useless for processing CSS, JS or anything else complex.
sub target_twiki {
    my $this = shift;

    print STDERR <<CAVEAT;
WARNING: This converter targets TWiki 4.2.3. Not all Foswiki APIs are
supported by TWiki, or TWiki may have changed since 4.2.3. You should
take great care to test the TWiki version. You cannot expect the
maintainer of this extension to support the TWiki version. Caveat emptor.
CAVEAT
    my $r = "$this->{libdir}/$this->{project}";
    $r =~ s#^$this->{basedir}/##;
    push( @{ $this->{files} }, { name => "$r/MANIFEST" } );
    push( @{ $this->{files} }, { name => "$r/DEPENDENCIES" } );
    push( @{ $this->{files} }, { name => "$r/build.pl" } );

    foreach my $file ( @{ $this->{files} } ) {
        my $nf = $file->{name};
        if ( $file->{name} =~ m#^(data|pub)/System/(.*)$# ) {
            $nf = "$1/TWiki/$2";
        }
        elsif ( $file->{name} =~ m#^lib/Foswiki/(.*)$# ) {
            $nf = "lib/TWiki/$1";
        }
        if ( $nf ne $file->{name} ) {
            my $filtered = 0;
            foreach my $filter (@twikiFilters) {
                if ( $file->{name} =~ /$filter->{RE}/ ) {
                    my $fn = $filter->{filter};
                    $this->$fn( $this->{basedir} . '/' . $file->{name},
                        $this->{basedir} . '/' . $nf );
                    $filtered = 1;
                    last;
                }
            }
            unless ($filtered) {
                $this->cp( $this->{basedir} . '/' . $file->{name},
                    $this->{basedir} . '/' . $nf );
            }
            $file->{name} = $nf;
            print "Created $file->{name}\n";
        }
    }
}

sub _twikify_perl {
    my ( $this, $from, $to ) = @_;

    $this->filter_file(
        $from, $to,
        sub {
            my ( $this, $text ) = @_;
            $text =~ s/Foswiki::/TWiki::/g;
            $text =~ s/new Foswiki\s*\(\s*\);/new TWiki();/g;
            $text =~ s/\b(use|require)\s+Foswiki/$1 TWiki/g;
            $text =~ s/foswiki\([A-Z][A-Za-z]\+\)/twiki$1/g;
            $text =~ s/'foswiki'/'twiki'/g;
            $text =~ s/FOSWIKI_/TWIKI_/g;
            $text =~ s/foswikiNewLink/twikiNewLink/g;           # CSS
            $text =~ s/foswikiAlert/twikiAlert/g;
            $text =~ s/new Foswiki/new TWiki/g;
            return <<'CAVEAT' . $text;
# This TWiki version was auto-generated from Foswiki sources by BuildContrib.
# Copyright (C) 2008-2010 Foswiki Contributors

CAVEAT

            # Note: the last blank line is to avoid mangling =pod
        }
    );
}

sub _twikify_manifest {
    my ( $this, $from, $to ) = @_;

    $this->filter_file(
        $from, $to,
        sub {
            my ( $this, $text ) = @_;
            $text =~ s#^data/System#data/TWiki#gm;
            $text =~ s#^pub/System#pub/TWiki#gm;
            $text =~ s#^lib/Foswiki#lib/TWiki#gm;
            return <<HERE;
# This TWiki version was auto-generated from Foswiki sources by BuildContrib.
# Copyright (C) 2008-2010 Foswiki Contributors
!option archive_prefix TWiki_
!option installers none
$text
HERE
        }
    );
}

sub _twikiify_txt {
    my ( $this, $from, $to ) = @_;

    $this->filter_file(
        $from, $to,
        sub {
            my ( $this, $text ) = @_;
            return <<HERE;
<blockquote>
This TWiki version was auto-generated from Foswiki sources by BuildContrib.
<br />
Copyright (C) 2008-2010 Foswiki Contributors
</blockquote>
$text
HERE
        }
    );
}

1;
