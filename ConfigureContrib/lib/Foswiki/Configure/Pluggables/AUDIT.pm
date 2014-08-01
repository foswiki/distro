# See bottom of file for license and copyright information

package Foswiki::Configure::Pluggables::AUDIT;

# Audit definitions
#
# Audits are composite checks, involving multiple items and possibly
# large output.

use strict;
use warnings;

use File::Basename ();

use Foswiki::Configure::FileUtil ();
use Foswiki::Configure::Load     ();

# Audit categories.  Keep to a reasonable number; use multiple buttons
# rather than more headings; order by impact/cost.

# Built-in items
#
# *** DO NOT add audits to this table - see AUDIT.spec for the "built-in"
# audits.  This is for the AUDIT infrastructure, such as the magical
# results area.

my @functions = (
    'Analysis results' => {
        auditType     => 'results',
        auditWindowId => '{ConfigureGUI}{AUDIT}{RESULTS}status',
        items         => [
            {
                type => 'AUDIT',
                opts => 'NOLABEL',
                keys => '{ConfigureGUI}{AUDIT}{RESULTS}',
            },
        ],
    },
);

sub construct {
    my ( $settings, $file, $line ) = @_;

    my @items;

    # Load AUDIT.spec from the same directory as this module
    my $path = __PACKAGE__;
    $path =~ s/::/\//g;
    my $specFile = Foswiki::Configure::FileUtil::findFileOnPath("$path.spec");
    if ($specFile) {
        my $value = _parseFile($specFile);
        if ( ref $value ) {
            push @$settings, @$value;
        }
    }
    else {
        Foswiki::Configure::LoadSpec::error( $file, $line,
            "Unable to find AUDIT.spec" );
    }

    # Add built-in items.

    while ( my $head = shift @functions ) {
        my $contents = shift @functions;

        my $sect = Foswiki::Configure::Section->new( headline => $head );
        foreach my $key ( grep $_ ne 'items', keys %$contents ) {
            $sect->set( $key => $contents->{$key} );
        }
        push @items, $sect;

        foreach my $item ( @{ $contents->{items} } ) {
            my $value =
              Foswiki::Configure::Value->new( ( $item->{type} || 'UNKNOWN' ) );
            foreach my $key ( grep $_ ne 'type', keys %$item ) {
                eval { $value->set( $key => $item->{$key} ); };
                die "$specFile, $., $@" if $@;
            }
            $sect->addChild($value);
        }
    }
    die "Bad function table\n" if (@functions);

    return [@items];
}

sub _parseFile {
    my ($specFile) = @_;

    my $sfile;
    unless ( open( $sfile, '<', $specFile ) ) {
        Foswiki::Configure::LoadSpec::error( $specFile, 0,
            "Failed to open audit specification file: $!" );
        return 0;
    }
    local $/ = "\n";

    my ( $open, $section, @sections, @sectionStack );

    while ( my $line = <$sfile> ) {
        chomp $line;

        # Continuation lines

        while ( $line =~ s/\\$// && !eof $sfile ) {
            my $cont = <$sfile>;
            chomp $cont;
            $cont =~ s/^#// if ( $line =~ /^#/ );
            $cont =~ s/^\s+/ /;
            unless ( $cont =~ /^#/ ) {
                $line .= $cont;
            }
        }
        last if ( $line =~ /^__END__$/ );
        next if ( $line =~ /^\s*$/ || $line =~ /^\s*#!/ );

        # Sections: ---+ (+ x depth) headline -- options

        if ( $line =~ /^\s*#\s*---\+(\+*) *(.*?)(?:\s+--\s+(.*$))?$/ ) {
            my ( $depth, $headline, $options ) = ( length $1, $2, $3 || '' );

            $section = Foswiki::Configure::Section->new(
                headline => $headline,
                opts     => $options
            );
            $section->{depth}     = $depth;
            $section->{auditType} = 'action';

            while ( @sectionStack && $sectionStack[0]->{depth} >= $depth ) {
                shift @sectionStack;
            }
            if (@sectionStack) {
                my $prevDepth = $sectionStack[0]->{depth};
                unless ( $prevDepth >= $depth || $depth == $prevDepth + 1 ) {
                    Foswiki::Configure::LoadSpec::error( $specFile, $.,
"Depth ($depth) of section \"$headline\" skips one or more levels from ($prevDepth)"
                    );
                    undef $section;
                    undef $open;
                    next;
                }
                $sectionStack[0]->addChild($section);
            }
            else {
                unless ( $depth == 1 ) {
                    Foswiki::Configure::LoadSpec::error( $specFile, $.,
                        "Depth of section \"$headline\" is not 1" );
                    undef $section;
                    undef $open;
                    next;
                }
                push @sections, $section;
            }
            unshift @sectionStack, $section;
            $open = $section;
            next;
        }

        # Descriptions

        if ( $line =~ /^\s*#\s?(.*)$/ ) {
            $open->append( 'desc', $1 ) if ($open);
            next;
        }

        # Audit specifiers: {Key}{s} [G:b+] [type] options

        if ( $line =~
/^\s*($Foswiki::Configure::Load::ITEMREGEX)\s+\[\s*((?:[_\w]+(?::\d+)?)(?:\s+(?:[_\w]+(?::\d+)?))*)\s*\](?:\s+\[(\w+)\])?\s+(.*)$/
          )
        {
            my ( $keys, $groups, $type, $options ) = ( $1, $2, $3, $4 );
            unless ($section) {
                Foswiki::Configure::LoadSpec::error( $specFile, $.,
                    "$keys requires a heading" );
                undef $section;
                undef $open;
                next;
            }
            my $value = eval {
                Foswiki::Configure::Value->new(
                    $type || 'NULL',
                    keys => $keys,
                    opts => $options
                );
            };
            Foswiki::Configure::LoadSpec::error( $specFile, $., $@ ) if $@;

            $section->addChild($value);
            eval {
                $value->{AUDIT_GROUPS} = [
                    map {
                        /^(\w+)(?::(\d+))?$/
                          or die "Bad audit group: $_\n";
                        my ( $g, $b ) = ( $1, $2 );
                        $b = 1 unless defined $b;
                        { group => $g, button => $b };
                    } grep { !/^_none/ } split( /\s+/, $groups )
                ];
            };
            die "$specFile:$. $@" if $@;
            $open = $value;
            next;
        }

        # Unknown

        Foswiki::Configure::LoadSpec::error( $specFile, $.,
            "Unrecognized specification: $line" );
        undef $section;
        undef $open;
    }
    close($sfile);

    return \@sections;
}

1;
__END__

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
