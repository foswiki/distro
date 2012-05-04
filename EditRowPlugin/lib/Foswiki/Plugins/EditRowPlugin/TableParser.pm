# See bottom of file for copyright and license information
package Foswiki::Plugins::EditRowPlugin::TableParser;

use strict;
use Assert;

use Foswiki::Attrs ();
use Foswiki::Func  ();
use CGI            ();

=begin TML

---++ parseTables($text, $web, $topic, $meta, $urps, $table_class) -> \@list
   * =$text= - text to parse tables from
   * =$web= - web
   * =$topic= - topic
   * =$meta= - meta-data for web.topic
   * =$urps= - URL parameter hash, may be undef
   * =$table_class= - name of table factory class. Defaults to
     Foswiki::Plugins::EditRowPlugin::Table

Static function to extract a topic into a list of lines and embedded table
definitions.

Each table definition is an object of type $table_class, and contains
a set of attrs (read from the macro) and a list of rows. You can
spot the tables in the list by doing:
<verbatim>
if (UNIVERSAL::isa($line, $table_class)) {
</verbatim>

=cut

sub parseTables {
    my ( $text, $web, $topic, $meta, $urps, $table_class ) = @_;

    unless ($table_class) {
        require Foswiki::Plugins::EditRowPlugin::Table;
        ASSERT( !$@ ) if DEBUG;
        $table_class = 'Foswiki::Plugins::EditRowPlugin::Table';
    }
    my $macro = $table_class->getMacro();

    my $active_table = undef;
    my $hasRows      = 0;
    my @tables;
    my $nTables = 0;
    my $disable = 0;
    my $openRow = undef;
    my @comments;

    $text =~ s/(<!--.*?-->)/
      push(@comments, $1); "\001-".scalar(@comments)."-\001"/seg;

    foreach my $line ( split( /\r?\n/, $text ) ) {
        if ( $line =~ /<(verbatim|literal)>/ ) {
            $disable++;
        }
        if ( $line =~ m#</(verbatim|literal)># ) {
            $disable-- if $disable;
        }

        # Remove the marks that highlight included tables, and omit
        # them from processing
        if ( $line =~ s/^<!-- STARTINCLUDE .* -->$// ) {
            $disable++;
            next;
        }
        if ( $line =~ s/^<!-- STOPINCLUDE .* -->$// ) {
            $disable-- if $disable;
            next;
        }
        if ( defined $openRow ) {
            $line    = "$openRow$line";
            $openRow = undef;
        }

        # Process an EDITTABLE. The tag will be associated with the
        # next table encountered in the topic.
        if ( !$disable && $line =~ s/(%$macro(?:{(.*)})?%)// ) {
            my $spec  = $1;
            my $attrs = Foswiki::Attrs->new(
                Foswiki::Func::expandCommonVariables(
                    defined $2 ? $2 : '',
                    $web, $topic
                )
            );
            push( @tables, $line ) if $line =~ /\S/;

            # Editable table
            $nTables++;
            my %read = ( "$web.$topic" => 1 );
            while ( $attrs->{include} ) {
                my ( $iw, $it ) =
                  Foswiki::Func::normalizeWebTopicName( $web,
                    $attrs->{include} );
                unless ( Foswiki::Func::topicExists( $iw, $it ) ) {
                    $line = CGI::span( { class => 'foswikiAlert' },
                        "Could not find format topic $attrs->{include}" );
                }
                if ( $read{"$iw.$it"} ) {
                    $line = CGI::span( { class => 'foswikiAlert' },
                        "Recursive include of $attrs->{include}" );
                }
                $read{"$iw.$it"} = 1;
                my ( $meta, $text ) = Foswiki::Func::readTopic( $iw, $it );
                my $params = '';
                if ( $text =~ m/%$macro(?:{([^\n]*)})?%/s ) {
                    $params = $1;
                }
                if ($params) {
                    $params =
                      Foswiki::Func::expandCommonVariables( $params, $iw, $it );
                }
                $attrs = Foswiki::Attrs->new($params);
            }

            # is there a format in the query? if there is,
            # override the format we just parsed
            if ($urps) {
                my $format = $urps->{"erp_${nTables}_format"};
                if ( defined($format) ) {

                    # undo the encoding
                    $format =~ s/-([a-z\d][a-z\d])/chr(hex($1))/gie;
                    $attrs->{format} = $format;
                }
                if ( defined( $urps->{"erp_${nTables}_headerrows"} ) ) {
                    $attrs->{headerrows} = $urps->{"erp_${nTables}_headerrows"};
                }
                if ( defined( $urps->{"erp_${nTables}_footerrows"} ) ) {
                    $attrs->{footerrows} = $urps->{"erp_${nTables}_footerrows"};
                }
            }
            $active_table =
              $table_class->new( $nTables, 1, $spec, $attrs, $web, $topic );
            push( @tables, $active_table );
            $hasRows = 0;
            next;
        }

        elsif ( !$disable && $line =~ /^\s*\|.*(\|\s*|\\)$/ && $active_table ) {
            if ( $line =~ s/\\$// ) {

                # Continuation
                $openRow = $line;
                next;
            }
            my $precruft = '';
            $precruft = $1 if $line =~ s/^(\s*\|)//;
            my $postcruft = '';
            $postcruft = $1 if $line =~ s/(\|\s*)$//;
            if ( !$active_table ) {

                # Uneditable table
                $nTables++;
                my $attrs => Foswiki::Attrs->new('');
                $active_table =
                  $table_class->new( $nTables, 0, $line, $attrs, $web, $topic );
                push( @tables, $active_table );
            }

            # Note use of LIMIT=-1 on the split so we don't lose empty columns
            my @cols;
            if ( length($line) ) {

                # Expand comments again after we split
                @cols =
                  map { $_ =~ s/\001-(\d+)-\001/$comments[$1 - 1]/ges; $_ }
                  split( /\|/, $line, -1 );
            }
            else {

                # Splitting an EXPR that evaluates to the empty string always
                # returns the empty list, regardless of the LIMIT specified.
                @cols = ('');
            }
            my $row =
              $active_table->newRow( scalar( @{ $active_table->{rows} } ) + 1,
                $precruft, $postcruft, \@cols );
            push( @{ $active_table->{rows} }, $row );
            $hasRows = 1;
            next;
        }

        elsif ( !$disable && $hasRows ) {

            # associated table has been terminated
            $active_table = undef;
        }

        push( @tables, $line );
    }

    my @result;
    foreach my $t (@tables) {
        if ( UNIVERSAL::isa( $t, $table_class ) ) {
            if (  !scalar( @{ $t->{rows} } )
                && defined( $t->{attrs}->{header} ) )
            {

                # Legacy: add a header if the header param is defined and
                # the table has no rows.
                my $line     = $t->{attrs}->{header};
                my $precruft = '';
                $precruft = $1 if $line =~ s/^(\s*\|)//;
                my $postcruft = '';
                $postcruft = $1 if $line =~ s/(\|\s*)$//;
                my @cols = split( /\|/, $line, -1 );
                my $row = $t->newRow( 1, $precruft, $postcruft, \@cols );
                push( @{ $t->{rows} }, $row );
            }
        }
        else {

            # Expand comments again
            $t =~ s/\001-(\d+)-\001/$comments[$1 - 1]/ges;
        }
        push( @result, $t );
    }

    return \@result;
}

1;
__END__

Author: Crawford Currie http://c-dot.co.uk

Copyright (c) 2009 Foswiki Contributors
Copyright (C) 2007 WindRiver Inc. and TWiki Contributors.
All Rights Reserved. Foswiki Contributors are listed in the
AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

Do not remove this copyright notice.
