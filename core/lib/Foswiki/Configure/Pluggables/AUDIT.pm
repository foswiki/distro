# -*- mode: CPerl; -*-

# See bottom of file for license and copyright information

package Foswiki::Configure::Pluggables::AUDIT;

# Audit definitions
#
# Audits are composite checks, involving multiple items and possibly
# large output.

use strict;
use warnings;

use Foswiki::Configure(qw/:DEFAULT :config :keys :util/);
use File::Basename;

use Foswiki::Configure::Pluggable;
our @ISA = (qw/Foswiki::Configure::Pluggable/);

use Foswiki::Configure::AUDIT;

# Audit categories.  Keep to a reasonable number; use multiple buttons
# rather than more headings; order by impact/cost.

# Built-in items
#
# *** DO NOT add audits to this table - see AUDIT.spec for the "built-in"
# audits.  This is for the AUDIT infrasctucture, such as the magical
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

sub new {
    my $class = shift;
    my ( $file, $root, $settings ) = @_;

    my $fileLine = $.;
    my @items;

    my $specFile = join( '', ( fileparse( __FILE__, qr/\.pm/ ) )[0], '.spec' );
    my $specDir = ( fileparse(__FILE__) )[1];
    if ( opendir( my $dh, $specDir ) ) {
        foreach my $file ( $specFile, grep !/^$specFile$/, readdir($dh) ) {
            next if ( $file =~ /^\./ );
            next unless ( $file =~ /\.spec$/ );
            my $value = $class->parseFile( @_, "${specDir}$file" );
            if ( ref $value ) {
                push @items, @$value;
            }
        }
        closedir $dh;
    }
    else {
        push @Foswiki::Configure::FoswikiCfg::errors,
          [ $specFile, $., "Unable to read audit specification directory: $!" ];
    }

    # Add built-in items.

    while ( @functions >= 2 ) {
        my ( $head, $contents ) = splice( @functions, 0, 2 );

        my $sect =
          Foswiki::Configure::AUDIT->new( $head, '' );    # Headline, options
        foreach my $key ( grep $_ ne 'items', keys %$contents ) {
            $sect->set( $key, $contents->{$key} );
        }
        push @items, $sect;

        foreach my $item ( @{ $contents->{items} } ) {
            my $value =
              Foswiki::Configure::Value->new( ( $item->{type} || 'UNKNOWN' ) );
            foreach my $key ( grep $_ ne 'type', keys %$item ) {
                $value->set( $key, $item->{$key} );
            }
            $sect->addChild($value);
        }
    }
    die "Bad function table\n" if (@functions);

    return [@items];
}

sub parseFile {
    my $class = shift;
    my ( $file, $root, $settings, $specFile ) = @_;

    my $sfile;
    unless ( open( $sfile, '<', $specFile ) ) {
        push @Foswiki::Configure::FoswikiCfg::errors,
          [ $specFile, 0, "Failed to open audit specification file: $!" ];
        return 0;
    }
    local $/ = "\n";

    my ( $open, $section, @sections, @sectionStack );

    while ( my $line = <$sfile> ) {
        $line =~ s/\r+\n//g;

        # Continuation lines

        while ( $line =~ /\\$/ && !eof $sfile ) {
            my $cont = <$sfile>;
            $cont =~ s/\r+\n//g;
            $cont =~ s/^#// if ( $line =~ /^#/ );
            $cont =~ s/^\s*//;
            chomp $line;
            $line .= $cont unless ( $line =~ /^#/ );
        }
        if ( $line =~ /\\$/ ) {
            push @Foswiki::Configure::FoswikiCfg::errors,
              [ $specFile, $., "Reached end-of-file, continuation expected" ];
            next;
        }
        last if ( $line =~ /^__END__$/ );
        next if ( $line =~ /^\s*$/ || $line =~ /^\s*#!/ );

        # Sections: ---+ (+ x depth) headline -- options

        if ( $line =~ /^\s*#\s*---\+(\+*) *(.*?)(?:\s+--\s+(.*$))?$/ ) {
            my ( $depth, $headline, $options ) = ( length $1, $2, $3 );

            $section = Foswiki::Configure::AUDIT->new( $headline, $options );
            $section->{_depth}    = $depth;
            $section->{auditType} = 'action';

            while ( @sectionStack && $sectionStack[0]->{_depth} >= $depth ) {
                shift @sectionStack;
            }
            if (@sectionStack) {
                my $prevDepth = $sectionStack[0]->{_depth};
                unless ( $prevDepth >= $depth || $depth == $prevDepth + 1 ) {
                    push @Foswiki::Configure::FoswikiCfg::errors,
                      [
                        $specFile,
                        $.,
"Depth ($depth) of section \"$headline\" skips one or more levels from ($prevDepth)"
                      ];
                    undef $section;
                    undef $open;
                    next;
                }
                $sectionStack[0]->addChild($section);
            }
            else {
                unless ( $depth == 1 ) {
                    push @Foswiki::Configure::FoswikiCfg::errors,
                      [
                        $specFile, $.,
                        "Depth of section \"$headline\" is not 1"
                      ];
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
            $open->addToDesc($1) if ($open);
            next;
        }

        # Audit specifiers: {Key}{s} [G:b+] [type] options

        if ( $line =~
/^\s*($configItemRegex)\s+\[\s*((?:[_\w]+(?::\d+)?)(?:\s+(?:[_\w]+(?::\d+)?))*)\s*\](?:\s+\[(\w+)\])?\s+(.*)$/
          )
        {
            my ( $keys, $groups, $type, $options ) = ( $1, $2, $3, $4 );
            unless ($section) {
                push @Foswiki::Configure::FoswikiCfg::errors,
                  [ $specFile, $., "$keys requires a heading" ];
                undef $section;
                undef $open;
                next;
            }
            my $value = Foswiki::Configure::Value->new( $type || 'NULL' );
            $section->addChild($value);
            $value->set( keys => $keys, opts => $options );
            $value->{auditGroups} = [ grep !/^_none/, split( /\s+/, $groups ) ];
            $open = $value;
            next;
        }

        # Unknown

        push @Foswiki::Configure::FoswikiCfg::errors,
          [ $specFile, $., "Unrecognized specification" ];
        undef $section;
        undef $open;
    }
    close($sfile);

    return \@sections;
}

1;
__END__

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
