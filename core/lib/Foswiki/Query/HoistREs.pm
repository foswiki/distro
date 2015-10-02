# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Query::HoistREs

Static functions to extract regular expressions from queries. The REs can
be used in caching stores that use the Foswiki standard inline meta-data
representation to pre-filter topic lists for more efficient query matching.

See =Store/QueryAlgorithms/BruteForce.pm= for an example of usage.

=cut

package Foswiki::Query::HoistREs;

use strict;
use warnings;

use Foswiki::Infix::Node ();
use Foswiki::Query::Node ();

# Try to optimise a query by hoisting regular expression searches
# out of the query
#
# patterns we need to look for:
#
# top level is defined by a sequence of AND and OR conjunctions
# second level, = and ~ and =~
# second level LHS is a field access
# second level RHS is a static string or number

use constant MONITOR_HOIST => 0;

=begin TML

---++ ObjectMethod collatedHoist($query) -> $hasRef

retuns a hashRef where the keys are the node's (web|name|text) 
for which we have hoisted regex's
and who's values are a list of regex's

and also keys of "(web|name|text)_source" where the list contains 
the non-regex version (ie what the user entered)

=cut

sub collatedHoist {
    my $node = shift;

    my %collation;

    my @ops = hoist($node);
    foreach my $op (@ops) {
        push( @{ $collation{ $op->{node} } },             $op->{regex} );
        push( @{ $collation{ $op->{node} . '_source' } }, $op->{source} );
    }

    #use Data::Dumper;
    #print STDERR "--- hoisted: ".Dumper(%collation)."\n" if MONITOR_HOIST;

    return \%collation;
}

=begin TML

---++ ObjectMethod hoist($query) -> @hashRefs

Extract useful filter REs from the given query. The list returned is a list
of filter expressions that can be used with a cache search to refine the
list of topics. The full query should still be applied to topics that remain
after the filter match has been applied; this is purely an optimisation.

each hash in the array contains the node the regex is for, and a regex string

{
    node => 'web|name|text',
    regex => 'Web.*'
    source => 'Web*'
}

=cut

sub hoist {
    my $node = shift;

    return () unless ref( $node->{op} );

    if ( $node->{op}->{name} eq '(' ) {
        return hoist( $node->{params}[0] );
    }

    print STDERR "hoist ", $node->stringify(), "\n" if MONITOR_HOIST;
    if ( $node->{op}->{name} eq 'and' ) {
        my @lhs = hoist( $node->{params}[0] );
        my $rhs = _hoistOR( $node->{params}[1] );
        if ( scalar(@lhs) && $rhs ) {
            return ( @lhs, $rhs );
        }
        elsif ( scalar(@lhs) ) {
            return @lhs;
        }
        elsif ($rhs) {
            return ($rhs);
        }
    }
    else {
        my $or = _hoistOR($node);
        return ($or) if $or;
    }

    print STDERR "\tFAILED\n" if MONITOR_HOIST;
    return ();
}

# depth 1; we can handle a sequence of ORs
sub _hoistOR {
    my $node = shift;

    return unless ref( $node->{op} );

    if ( $node->{op}->{name} eq '(' ) {
        return _hoistOR( $node->{params}[0] );
    }

    if ( $node->{op}->{name} eq 'or' ) {
        print STDERR "hoistOR ", $node->stringify(), "\n" if MONITOR_HOIST;
        my $lhs = _hoistOR( $node->{params}[0] );
        my $rhs = _hoistEQ( $node->{params}[1] );
        if ( $lhs && $rhs ) {
            if ( $lhs->{node} eq $rhs->{node} ) {
                return {
                    node   => $lhs->{node},
                    regex  => $lhs->{regex} . '|' . $rhs->{regex},
                    source => $lhs->{source} . ',' . $rhs->{source}
                };
            }
            return ( $lhs, $rhs );
        }
    }
    else {
        return _hoistEQ($node);
    }

    print STDERR "\tFAILED\n" if MONITOR_HOIST;
    return;
}

# depth 2: can handle = and ~ expressions
sub _hoistEQ {
    my $node = shift;

    return unless ref( $node->{op} );

    if ( $node->{op}->{name} eq '(' ) {
        return _hoistEQ( $node->{params}[0] );
    }

    print STDERR "hoistEQ ", $node->stringify(), "\n" if MONITOR_HOIST;

    # \000RHS\001 is a placholder for the RHS term
    if ( $node->{op}->{name} eq '=' ) {
        my $lhs = _hoistDOT( $node->{params}[0] );
        my $rhs = _hoistConstant( $node->{params}[1] );
        if ( $lhs && defined $rhs ) {
            $rhs = quotemeta($rhs);
            $lhs->{regex} =~ s/\000RHS\001/$rhs/g;
            $lhs->{source} = _hoistConstant( $node->{params}[1] );
            return $lhs;
        }

        # = is symmetric, so try the other order
        $lhs = _hoistDOT( $node->{params}[1] );
        $rhs = _hoistConstant( $node->{params}[0] );
        if ( $lhs && defined $rhs ) {
            $rhs = quotemeta($rhs);
            $lhs->{regex} =~ s/\000RHS\001/$rhs/g;
            $lhs->{source} = _hoistConstant( $node->{params}[0] );
            return $lhs;
        }
    }
    elsif ( $node->{op}->{name} eq '~' ) {
        my $lhs = _hoistDOT( $node->{params}[0] );
        my $rhs = _hoistConstant( $node->{params}[1] );
        if ( $lhs && defined $rhs ) {
            $rhs = quotemeta($rhs);
            $rhs          =~ s/\\\?/./g;
            $rhs          =~ s/\\\*/.*/g;
            $lhs->{regex} =~ s/\000RHS\001/$rhs/g;
            $lhs->{source} = _hoistConstant( $node->{params}[1] );
            return $lhs;
        }
    }
    elsif ( $node->{op}->{name} eq '=~' ) {
        my $lhs = _hoistDOT( $node->{params}[0] );
        my $rhs = _hoistConstant( $node->{params}[1] );
        if ( $lhs && defined $rhs ) {

#need to detect if its a field, or in a text, and if its a field, remove the ^$ chars...
#or if there are no ^$, add .*'s if they are not present
            if ( $lhs->{regex} ne "\000RHS\001" ) {
                if (    ( not( $rhs =~ /^\^/ ) )
                    and ( not( $rhs =~ /^\.\*/ ) ) )
                {
                    $rhs = '.*' . $rhs;
                }

                if (    ( not( $rhs =~ /\$$/ ) )
                    and ( not( $rhs =~ /\.\*$/ ) ) )
                {
                    $rhs = $rhs . '.*';
                }

                #if we're embedding the regex into another, then remove the ^'s
                $rhs =~ s/^\^//;
                $rhs =~ s/\$$//;
            }
            $lhs->{regex} =~ s/\000RHS\001/$rhs/g;
            $lhs->{source} = _hoistConstant( $node->{params}[1] );
            return $lhs;
        }
    }

    print STDERR "\tFAILED\n" if MONITOR_HOIST;
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

    print STDERR "hoistDOT ", $node->stringify(), "\n" if MONITOR_HOIST;
    if ( ref( $node->{op} ) && $node->{op}->{name} eq '.' ) {
        my $lhs = $node->{params}[0];
        my $rhs = $node->{params}[1];
        if (   !ref( $lhs->{op} )
            && !ref( $rhs->{op} )
            && $lhs->{op} eq $Foswiki::Infix::Node::NAME
            && $rhs->{op} eq $Foswiki::Infix::Node::NAME )
        {
            $lhs = $lhs->{params}[0];
            $rhs = $rhs->{params}[0];
            if ( $Foswiki::Query::Node::aliases{$lhs} ) {
                $lhs = $Foswiki::Query::Node::aliases{$lhs};
            }
            if ( $lhs =~ /^META:/ ) {

                # \000RHS\001 is a placholder for the RHS term
                return {
                    node  => 'text',
                    regex => '^%'
                      . $lhs
                      . '\\{.*\\b'
                      . $rhs
                      . "=\\\"\000RHS\001\\\""
                };
            }

            # Otherwise assume the term before the dot is the form name
            if ( $rhs eq 'text' ) {

                # Special case for the text body
                return { node => 'text', regex => "\000RHS\001" };
            }
            else {
                return {
                    node => 'text',
                    regex =>
"^%META:FIELD\\{name=\\\"$rhs\\\".*\\bvalue=\\\"\000RHS\001\\\""
                };
            }

        }
    }
    elsif ( !ref( $node->{op} ) && $node->{op} eq $Foswiki::Infix::Node::NAME )
    {
        if ( $node->{params}[0] eq 'name' ) {

            # Special case for the topic name
            return { node => 'name', regex => "\000RHS\001" };
            return;
        }
        elsif ( $node->{params}[0] eq 'web' ) {

            # Special case for the web name
            return { node => 'web', regex => "\000RHS\001" };
            return;
        }
        elsif ( $node->{params}[0] eq 'text' ) {

            # Special case for the text body
            return { node => 'text', regex => "\000RHS\001" };
        }
        else {
            return {
                node => 'text',
                regex =>
"^%META:FIELD\\{name=\\\"$node->{params}[0]\\\".*\\bvalue=\\\"\0RHS\1\\\""
            };
        }
    }

    print STDERR "\tFAILED\n" if MONITOR_HOIST;
    return;
}

# Expecting a constant
sub _hoistConstant {
    my $node = shift;

    print STDERR "hoistCONST ", $node->stringify(), "\n" if MONITOR_HOIST;
    if (
        !ref( $node->{op} )
        && (   $node->{op} eq $Foswiki::Infix::Node::STRING
            || $node->{op} eq $Foswiki::Infix::Node::NUMBER )
      )
    {
        return $node->{params}[0];
    }
    return;
}

1;
__END__
Author: Crawford Currie http://c-dot.co.uk
          Sven Dowideit http://fosiki.com

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
