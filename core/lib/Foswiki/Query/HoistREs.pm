# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Query::HoistREs

Static functions to extract regular expressions from queries. The REs can
be used in caching stores that use the Foswiki standard inline meta-data
representation to pre-filter topic lists for more efficient query matching.

See =Store/QueryAlgorithms/BruteForce.pm= for an example of usage.

Note that this hoisting is very crude. At this point of time the
functions don't attempt to do anything complicated, like re-ordering
the query. They simply hoist up expressions on either side of an AND,
where the expressions apply to a single domain.

The ideal would be to rewrite the query for AND/OR evaluation i.e. an
expression of the form (A and B) or (C and D). However this is
complicated by the fact that there are three search domains (the web
name, the topic name, and the topic text) that may be freely
intermixed in the query, but cannot be mixed in the generated search
expressions. The problem becomes one of rewriting the query to
separate these three sets. For example, a query such as:

name='Topic' OR Field='maes' OR web='Trash'

requires three searches. We have to filter on name='Topic', and
separately filter on Field='maes' and then union the sets.

This gets complicated when the sets are intermixed; for example,

(name='Topic' OR Field='maes') AND (web='Trash' OR Maes="field")

Because the Field= terms on each side of the AND could potentially
match any topic, we can't usefully hoist the name= or web= sub-terms.
We can, however, hoist the Field subqueries. Now, what happens when we
have an expression like this?

(name='Topic' OR Field='maes') AND (web='Trash')

Obviously we can pre-filter on the web='Trash' term, but we can't
filter on name="Topic" because it is part of an OR.

If you think I'm making this too complicated, please feel free to
implement your own superior heuristics!

=cut

package Foswiki::Query::HoistREs;

use strict;
use warnings;

use Foswiki::Infix::Node ();
use Foswiki::Query::Node ();

use constant MONITOR_HOIST => 0;

our $indent = 0;

sub _monitor {
    my @p = map { ref($_) ? $_->stringify() : $_ } @_;
    print STDERR ( ' ' x $indent ) . join( ' ', @p ) . "\n";
}

=begin TML

---++ StaticMethod hoist($query) -> \%regex_lists

Main entry point for the hoister.

Returns a hash where the keys are the aspects to be tested
(web|name|text) and the AND terms represented as lists of regexes,
each of which is one OR term.

There are also keys named "(web|name|text)_source" where the list
contains what the user entered for that term.

=cut

sub hoist {
    my $node = shift;
    my %collation;

    # Gather up all the terms applicable to a particular field
    my @terms = _hoistAND($node);
    foreach my $term (@terms) {
        push( @{ $collation{ $term->{field} } },             $term->{regex} );
        push( @{ $collation{ $term->{field} . '_source' } }, $term->{source} );
    }

    #use Data::Dumper;
    #print STDERR "--- hoisted: ".Dumper(%collation)."\n" if MONITOR_HOIST;
    return \%collation;
}

# Used for MONITOR_HOIST
sub _monTerm {
    my $term = shift;
    return "$term->{field} => /$term->{regex}/";
}

# Each collection object in the result contains the field the regex is for, a
# regex string, and the source string that the user entered. e.g.
# {
#     field => 'web|name|text',
#     regex => 'Web.*'
#     source => 'Web*'
# }
sub _hoistAND {
    my $node = shift;

    return () unless ref( $node->{op} );

    if ( $node->{op}->{name} eq '(' ) {
        return _hoistAND( $node->{params}[0] );
    }

    if ( $node->{op}->{name} eq 'and' ) {

        # An 'and' conjunction yields a set of individual expressions,
        # each of which must match the data
        my @list = @{ $node->{params} };
        $indent++;
        my @collect = _hoistAND( shift(@list) );
        while ( scalar(@list) ) {
            my $term = _hoistOR( shift @list );
            next unless $term;
            push( @collect, $term );
        }
        $indent--;
        _monitor( "hoistAND ", $node,
            join( ', ', map { _monTerm($_) } @collect ) )
          if MONITOR_HOIST;
        return @collect;
    }
    else {
        my $or = _hoistOR($node);
        return ($or) if $or;
    }

    _monitor( "hoistAND ", $node, " FAILED" ) if MONITOR_HOIST;
    return ();
}

# depth 1; we can handle a sequence of ORs, which we collapse into
# a common regular expression when they apply to the same field.
sub _hoistOR {
    my $node = shift;

    return unless ref( $node->{op} );

    if ( $node->{op}->{name} eq '(' ) {
        return _hoistOR( $node->{params}[0] );
    }

    if ( $node->{op}->{name} eq 'or' ) {
        my @list = @{ $node->{params} };
        $indent++;
        my %collection;
        while ( scalar(@list) ) {
            my $term = _hoistEQ( shift(@list) );

            # If we fail to hoist the subexpression then it can't
            # be expressed using simple regexes. In this event we can't
            # account for this term in a top-level and, so we have
            # to abort the entire hoist.
            unless ($term) {
                %collection = ();
                last;
            }
            my $collect = $collection{ $term->{field} };
            if ($collect) {

                # Combine with previous
                $collect->{regex}  .= '|' . $term->{regex};
                $collect->{source} .= ',' . $term->{source};
            }
            else {
                $collection{ $term->{field} } = $term;
            }
        }
        $indent--;
        _monitor( "hoistOR ", $node,
            join( ', ', map { _monTerm($_) } values %collection ) )
          if MONITOR_HOIST;

        # At this point we have collected terms for all the domains, and
        # if there is only one we can just return it. However if the
        # expression involved more than one domain, we have a "mixed or"
        # and we can't hoist.
        if ( scalar( keys %collection ) == 1 ) {
            return ( values(%collection) )[0];
        }
    }
    else {
        return _hoistEQ($node);
    }

    _monitor( "hoistOR ", $node, " FAILED" ) if MONITOR_HOIST;
    return;
}

our $PHOLD = "\000RHS\001";

# depth 2: can handle = and ~ expressions
sub _hoistEQ {
    my $node = shift;

    return unless ref( $node->{op} );

    if ( $node->{op}->{name} eq '(' ) {
        return _hoistEQ( $node->{params}[0] );
    }

    # $PHOLD is a placeholder for the RHS term in the regex
    if ( $node->{op}->{name} eq '=' ) {
        $indent++;
        my $lhs = _hoistDOT( $node->{params}[0] );
        my $rhs = _hoistConstant( $node->{params}[1] );
        $indent--;
        if ( $lhs && defined $rhs ) {
            $rhs = quotemeta($rhs);
            $lhs->{regex} =~ s/$PHOLD/$rhs/g;
            $lhs->{source} = _hoistConstant( $node->{params}[1] );
            _monitor( "hoistEQ ", $node, " =>" ) if MONITOR_HOIST;
            return $lhs;
        }

        # = is symmetric, so try the other order
        $indent++;
        $lhs = _hoistDOT( $node->{params}[1] );
        $rhs = _hoistConstant( $node->{params}[0] );
        $indent--;
        if ( $lhs && defined $rhs ) {
            $rhs = quotemeta($rhs);
            $lhs->{regex} =~ s/$PHOLD/$rhs/g;
            $lhs->{source} = _hoistConstant( $node->{params}[0] );
            _monitor( "hoistEQ ", $node, " <=" )
              if MONITOR_HOIST;
            return $lhs;
        }
    }
    elsif ( $node->{op}->{name} eq '~' ) {
        $indent++;
        my $lhs = _hoistDOT( $node->{params}[0] );
        my $rhs = _hoistConstant( $node->{params}[1] );
        $indent--;
        if ( $lhs && defined $rhs ) {
            $rhs = quotemeta($rhs);
            $rhs          =~ s/\\\?/./g;
            $rhs          =~ s/\\\*/.*/g;
            $lhs->{regex} =~ s/$PHOLD/$rhs/g;
            $lhs->{source} = _hoistConstant( $node->{params}[1] );
            _monitor( "hoistEQ ", $node, " ~" )
              if MONITOR_HOIST;
            return $lhs;
        }
    }
    elsif ( $node->{op}->{name} eq '=~' ) {
        $indent++;
        my $lhs = _hoistDOT( $node->{params}[0] );
        my $rhs = _hoistConstant( $node->{params}[1] );
        $indent--;
        if ( $lhs && defined $rhs ) {

#need to detect if its a field, or in a text, and if its a field, remove the ^$ chars...
#or if there are no ^$, add .*'s if they are not present
            if ( $lhs->{regex} ne $PHOLD ) {
                if (    ( not( $rhs =~ m/^\^/ ) )
                    and ( not( $rhs =~ m/^\.\*/ ) ) )
                {
                    $rhs = '.*' . $rhs;
                }

                if (    ( not( $rhs =~ m/\$$/ ) )
                    and ( not( $rhs =~ m/\.\*$/ ) ) )
                {
                    $rhs = $rhs . '.*';
                }

                #if we're embedding the regex into another, then remove the ^'s
                $rhs =~ s/^\^//;
                $rhs =~ s/\$$//;
            }
            $lhs->{regex} =~ s/$PHOLD/$rhs/g;
            $lhs->{source} = _hoistConstant( $node->{params}[1] );
            _monitor( "hoistEQ ", $node, " =~" )
              if MONITOR_HOIST;
            return $lhs;
        }
    }

    _monitor( "hoistEQ ", $node, "  FAILED" ) if MONITOR_HOIST;
    return;
}

# Expecting a (root level) field access expression. This must be of the form
# <name>
# or
# <rootfield>.<name>
# <rootfield> may be aliased
sub _hoistDOT {
    my $node = shift;

    if ( ref( $node->{op} ) && $node->{op}->{name} eq '(' ) {
        return _hoistDOT( $node->{params}[0] );
    }

    if ( ref( $node->{op} ) && $node->{op}->{name} eq '.' ) {
        my $lhs = $node->{params}[0];
        my $rhs = $node->{params}[1];
        if (   !ref( $lhs->{op} )
            && !ref( $rhs->{op} )
            && $lhs->{op} eq Foswiki::Infix::Node::NAME
            && $rhs->{op} eq Foswiki::Infix::Node::NAME )
        {
            $lhs = $lhs->{params}[0];
            $rhs = $rhs->{params}[0];
            if ( $Foswiki::Query::Node::aliases{$lhs} ) {
                $lhs = $Foswiki::Query::Node::aliases{$lhs};
            }
            if ( $lhs =~ m/^META:/ ) {

                _monitor( "hoist DOT ", $node, " => $rhs" )
                  if MONITOR_HOIST;

                # $PHOLD is a placholder for the RHS term
                return {
                    field => 'text',
                    regex => '^%'
                      . $lhs
                      . '\\{.*\\b'
                      . $rhs
                      . "=\\\"$PHOLD\\\""
                };
            }

            # Otherwise assume the term before the dot is the form name
            if ( $rhs eq 'text' ) {

                _monitor( "hoist DOT ", $node, " => formname" )
                  if MONITOR_HOIST;

                # Special case for the text body
                return { field => 'text', regex => $PHOLD };
            }
            else {
                _monitor( "hoist DOT ", $node, " => fieldname" )
                  if MONITOR_HOIST;
                return {
                    field => 'text',
                    regex =>
"^%META:FIELD\\{name=\\\"$rhs\\\".*\\bvalue=\\\"$PHOLD\\\""
                };
            }

        }
    }
    elsif ( !ref( $node->{op} ) && $node->{op} eq Foswiki::Infix::Node::NAME ) {
        if ( $node->{params}[0] eq 'name' ) {

            # Special case for the topic name
            _monitor( "hoist DOT ", $node, " => topic" )
              if MONITOR_HOIST;
            return { field => 'name', regex => $PHOLD };
        }
        elsif ( $node->{params}[0] eq 'web' ) {

            # Special case for the web name
            _monitor( "hoist DOT ", $node, " => web" )
              if MONITOR_HOIST;
            return { field => 'web', regex => $PHOLD };
        }
        elsif ( $node->{params}[0] eq 'text' ) {

            # Special case for the text body
            _monitor( "hoist DOT ", $node, " => text" )
              if MONITOR_HOIST;
            return { field => 'text', regex => $PHOLD };
        }
        else {
            _monitor( "hoist DOT ", $node, " => field" )
              if MONITOR_HOIST;
            return {
                field => 'text',
                regex =>
"^%META:FIELD\\{name=\\\"$node->{params}[0]\\\".*\\bvalue=\\\"$PHOLD\\\""
            };
        }
    }

    _monitor( "hoistDOT ", $node, "  FAILED" ) if MONITOR_HOIST;
    return;
}

# Expecting a constant
sub _hoistConstant {
    my $node = shift;

    if (
        !ref( $node->{op} )
        && (   $node->{op} eq Foswiki::Infix::Node::STRING
            || $node->{op} eq Foswiki::Infix::Node::NUMBER )
      )
    {
        _monitor( "hoist CONST ", $node, " => $node->{params}[0]" )
          if MONITOR_HOIST;
        return $node->{params}[0];
    }
    return;
}

1;
__END__
Author: Crawford Currie http://c-dot.co.uk
          Sven Dowideit http://fosiki.com

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2011 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2005-2007 TWiki Contributors. All Rights Reserved.
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
