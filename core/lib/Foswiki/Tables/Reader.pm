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
        return undef unless $text =~ /\%${macro}[%{]/s;
        my @queue = split( /(%[A-Za-z0-9_]*{|}%|\%${macro}\%)/, $text );
        my $eat   = 0;
        my $eaten = '';
        while ( scalar(@queue) ) {
            my $token = shift @queue;
            if ($eat) {
                if ( $token =~ /^%[A-Za-z0-9_]*{$/ ) {
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
        table_class => $table_class,
        macro       => $table_class->getMacro()
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
    $this->{pending_spec} = undef;    # table attributes from EDITTABLE
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
# Detect and process the macro recognised by the table class (e.g. EDITTABLE).
# This is recorded as "pending" so it can be applied to the next table read.
sub early_line {
    my ( $this, $line ) = @_;
    @{ $this->{waiting} } = ();

    return 0 unless $this->{meta};

    # Can we get a balanced macro expression from the text?
    my $args = Foswiki::Attrs::findFirstOccurenceAttrs( $this->{macro}, $line );
    return 0 unless ( defined $args );

    my $attrs = Foswiki::Attrs->new($args);

    # Remember leading and trailing junk
    my $ok = $line =~ /^(.*?)(\%$this->{macro}(?:\Q{$args}\E)?%)(.*)$/s;
    ASSERT($ok) if DEBUG;

    push( @{ $this->{waiting} }, $1 ) if defined($1) && length($1);
    my $spec = $2;
    push( @{ $this->{waiting} }, $3 ) if defined($3) && length($3);

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
                  Foswiki::Attrs::findFirstOccurenceAttrs( $this->{macro},
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

    $this->adjustSpec($attrs);

    # Remember what we just discovered for when the next table is
    # created.
    $this->{pending_spec} = [ $spec, $attrs ];

    return 1;    # processing complete, goto next line
}

# Intended to be implemented by subclasses
sub adjustSpec {
    my ( $this, $attrs ) = @_;
}

# Parser event handler
sub line {
    my ( $this, $line ) = @_;
    push( @{ $this->{result} }, $line );
    push( @{ $this->{result} }, @{ $this->{waiting} } );
}

# Parser event handler
sub open_table {
    my ( $this, $line ) = @_;

    push( @{ $this->{result} }, @{ $this->{waiting} } );
    @{ $this->{waiting} } = ();
    if ( !$this->{pending_spec} ) {

        # [ bHasMacro, spec, attrs ]
        $this->{pending_spec} = [ undef, Foswiki::Attrs->new('') ];
    }

    $this->{active_table} =
      $this->{table_class}->new( @{ $this->{pending_spec} } );

    # Throw away the %EDITTABLE params
    $this->{pending_spec} = undef;
}

# Parser event handler
sub close_table {
    my ($this) = @_;
    push( @{ $this->{result} }, $this->{active_table} );
    push( @{ $this->{result} }, @{ $this->{waiting} } );
    @{ $this->{waiting} } = ();
    $this->{active_table}->number( $this->{nTables}++ );
    undef $this->{activeTable};
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
