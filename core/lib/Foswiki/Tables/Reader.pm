# See bottom of file for copyright and license information

=begin TML

---+ package Foswiki::Tables::Reader

Abstract reader for tables; builds tables using the default table model classes.

The reader is provided with the name of the table_class, which defaults to
Foswiki::Tables::Table. This class provides a =row_class= method which is
used to get the factory for a row (default: Foswiki::Tables::Row), which in turn
can be interrogated for the =cell_class= (default: Foswiki::Tables::Cell).

=cut

package Foswiki::Tables::Reader;

use strict;
use Assert;

use Foswiki::Attrs          ();
use Foswiki::Tables::Parser ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

# Foswiki 1.1.9 didn't define findFirstOccurenceAttrs. Monkey-patch it.
unless ( defined &Foswiki::Attrs::findFirstOccurenceAttrs ) {
    *Foswiki::Attrs::findFirstOccurenceAttrs = sub {
        my ( $macro, $text ) = @_;
        return undef unless $text =~ m/\%${macro}[%{]/s;
        my @queue = split( /(%[A-Za-z0-9_]*{|}%|\%${macro}\%)/, $text );
        my $eat   = 0;
        my $eaten = '';
        while ( scalar(@queue) ) {
            my $token = shift @queue;
            if ($eat) {
                if ( $token =~ m/^%[A-Za-z0-9_]*{$/ ) {
                    $eat++;
                }
                elsif ( $eat && $token eq '}%' ) {
                    $eat--;
                    return $eaten if ( !$eat );
                }
                $eaten .= $token;
            }
            else {
                if ( $token eq "\%${macro}%" ) {
                    return '';
                }
                elsif ( $token eq "\%${macro}\{" ) {
                    $eat = 1;
                }
            }
        }
        return '';
      }
}

=begin TML

---++ ClassMethod new($table_class) -> $parser
   * =$table_class= - name of table factory class. Defaults to
     Foswiki::Tables::Table

The parser can be used to parse tables from text using =parse=.
 
=cut

sub new {
    my ( $class, $table_class ) = @_;

    unless ($table_class) {
        require Foswiki::Tables::Table;
        ASSERT( !$@ ) if DEBUG;
        $table_class = 'Foswiki::Tables::Table';
    }

    my $this = {

        # Class used to construct tables
        table_class => $table_class,

        # 'extra' macro, besides TABLE
        macro_re => join( '|', $table_class->getMacros() )
    };

    return bless( $this, $class );
}

=begin TML

---++ ObjectMethod finish()
Clean up for disposal

=cut

sub finish {
    my $this = shift;

    undef $this->{active_table};
    undef $this->{active_row};
    undef $this->{result};
}

=begin TML

---++ ObjectMethod parse($text [, $topicObject]) -> \@list
Extract a topic into a list of lines and embedded table definitions.

Each table definition is an object of type =$table_class=, and contains
a set of attrs (read from the macro) and a list of rows. You can
spot the tables in the list by doing:
<verbatim>
if (UNIVERSAL::isa($line, $table_class)) {
</verbatim>
text lines are scalars, so will also return false to =ref($line)=

The =$topicObject= is an instance of Foswiki::Meta, and is required to
provide an expansion context for macros embedded in parameters. If it
is not provided, then macros will be passed on unexpanded, and support
for table decorators (such as %EDITTABLE) will be unavailable.

=cut

sub parse {
    my ( $this, $text, $meta ) = @_;

    $this->{meta}         = $meta;
    $this->{active_table} = undef;    # Open table
    $this->{active_row}   = undef;    # Open row
    $this->{pending_spec} = [];       # attributes
    $this->{nTables}      = 0;        # number of tables read so far
    $this->{result}       = [];       # tables and lines of text

    # Dispatch Foswiki::Parser::Table events to this "class"
    my $dispatch = sub {
        my $event = shift;
        $this->$event(@_);
    };

    Foswiki::Tables::Parser::parse( $text, $dispatch );

    return $this->{result};
}

# Parser event handler
# Detect and process macros recognised as being associated with tables.
# This is recorded as "pending" so it can be applied to the next table read.
# Also process and remember attributes from the generic TABLE macro.
sub early_line {
    my ( $this, $line ) = @_;

    return 0 unless $this->{meta};

    # Process recognised macros
    my $result = 0;
    while ( $_[1] =~ /%($this->{macro_re})(\{.*?\})?%/s ) {
        my $res = $this->_early_line( $_[1], $1 );
        $result = $res if ( $result == 0 || $res < 0 );
    }

    return $result;
}

sub _early_line {
    my ( $this, $line, $macro ) = @_;

    my $args = Foswiki::Attrs::findFirstOccurenceAttrs( $macro, $line );
    return 0 unless defined $args;    # whoops

    # Remember leading and trailing
    unless ( $_[1] =~ s/^(.*?)(\%$macro(?:\Q{$args}\E)?%)/$1/s ) {
        ASSERT( 0, "$macro in $line" ) if DEBUG;
    }

    my $spec = $2;

    $args = $this->{meta}->expandMacros($args);

    my $attrs = Foswiki::Attrs->new($args);

    my %read = ( $this->{meta}->getPath() => 1 );
    my $session = $this->{meta}->session;
    while ( $attrs->{include} ) {
        my ( $iw, $it ) =
          $session->normalizeWebTopicName( $this->{meta}->web,
            $attrs->{include} );
        if ( $session->topicExists( $iw, $it ) ) {
            if ( $read{"$iw.$it"} ) {
                $line = CGI::span( { class => 'foswikiAlert' },
                    "Recursive include of $attrs->{include}" );
                last;
            }
            else {
                $read{"$iw.$it"} = 1;
                my $meta = Foswiki::Meta->load( $session, $iw, $it );

               # Replace attrs with the first matching macro in the include text
               # If there is none, we're done
                my $params =
                  Foswiki::Attrs::findFirstOccurenceAttrs( $macro,
                    $meta->text() );
                last unless $params;
                $params = $meta->expandMacros($params);
                $attrs  = Foswiki::Attrs->new($params);

                # and go around again
            }
        }
        else {
            $line = CGI::span( { class => 'foswikiAlert' },
                "Could not find format topic $attrs->{include}" );
            last;
        }
    }

    my $make_table = $this->adjustSpec( $macro, $attrs );

    # Remember what we just discovered for when the next table is
    # encountered.
    push(
        @{ $this->{pending_spec} },
        { raw => $spec, tag => $macro, attrs => $attrs }
    );

    return $make_table;    # processing complete, goto next line
}

# Intended to be implemented by subclasses
sub adjustSpec {
    my ( $this, $macro, $attrs ) = @_;
    return -1;             # don't make a table, just grab attributes
}

# Parser event handler
sub line {
    my ( $this, $line ) = @_;
    push( @{ $this->{result} }, $line );
}

# Parser event handler
sub open_table {
    my ( $this, $line ) = @_;

    $this->{active_table} = $this->{table_class}->new( $this->{pending_spec} );

    # Throw away the params
    $this->{pending_spec} = [];
}

# Parser event handler
sub close_table {
    my ($this) = @_;
    push( @{ $this->{result} }, $this->{active_table} );
    $this->{active_table}->number( $this->{nTables}++ );
    undef $this->{active_table};
}

# Parser event handler
sub open_tr {
    my ( $this, $precruft ) = @_;
    my $row_class = $this->{active_table}->row_class;
    $this->{active_row} =
      $row_class->new( $this->{active_table}, $precruft, '' )
      ;    # postcruft not known yet
}

# Parser event handler
sub close_tr {
    my ( $this, $postcruft ) = @_;
    $this->{active_row}->{postcruft} = $postcruft if defined $postcruft;
    $this->{active_table}->pushRow( $this->{active_row} );
    undef $this->{active_row};
}

# Parser event handler
sub td {
    my ( $this, $prec, $val, $postc, $ish ) = @_;
    my $row = $this->{active_row};
    ASSERT($row) if DEBUG;
    my $cell_class = $row->cell_class;
    my $cell = $cell_class->new( $row, $prec, $val, $postc, $ish || 0 );
    $row->pushCell($cell);
}

# Parser event handler
sub th {
    td( @_, 1 );
}

sub end_of_input {
}

1;
__END__

Author: Crawford Currie http://c-dot.co.uk

Copyright (c) 2012 Foswiki Contributors
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
