# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Query::OP_ref

=cut

package Foswiki::Query::OP_ref;

use strict;
use warnings;
use Foswiki::Query::OP ();
our @ISA = ('Foswiki::Query::OP');

use Error qw( :try );
use Assert;

sub new {
    my $class = shift;
    return $class->SUPER::new( arity => 2, name => '/', prec => 800 );
}

sub evaluate {
    my $this   = shift;
    my $pnode  = shift;
    my %domain = @_;

    eval "require $Foswiki::cfg{Store}{QueryAlgorithm}";
    die $@ if $@;

    my $a    = $pnode->{params}[0];
    my $node = $a->evaluate(@_);
    return unless defined $node;
    if ( ref($node) eq 'HASH' ) {
        return;
    }
    if ( !( ref($node) eq 'ARRAY' ) ) {
        $node = [$node];
    }
    my @result;
    foreach my $v (@$node) {

        # Has to be relative to the web of the topic we are querying
        my ( $w, $t ) =
          $Foswiki::Plugins::SESSION->normalizeWebTopicName(
            $Foswiki::Plugins::SESSION->{webName}, $v );
        try {
            my $submeta =
              $Foswiki::cfg{Store}{QueryAlgorithm}
              ->getRefTopic( $domain{tom}, $w, $t );
            my $b = $pnode->{params}[1];
            my $res = $b->evaluate( tom => $submeta, data => $submeta );
            if ( ref($res) eq 'ARRAY' ) {
                push( @result, @$res );
            }
            else {
                push( @result, $res );
            }
        }
        catch Error with {
            print STDERR "ERROR IN OP_ref: $_[0]->{-text}" if DEBUG;
        };
    }
    return unless scalar(@result);
    return $result[0] if scalar(@result) == 1;
    return \@result;
}

sub evaluatesToConstant {
    my $this = shift;
    my $node = shift;
    return 1 if $node->{params}[0]->evaluatesToConstant(@_);

    # param[1] may contain non-constant terms, but that's OK because
    # they are evaluated relative to the (constant) param[0]
    return 0;
}

1;
__END__
Author: Crawford Currie http://c-dot.co.uk

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2011 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2005-2007 TWiki Contributors. All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
