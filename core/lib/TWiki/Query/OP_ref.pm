# See bottom of file for copyright and license details

=begin twiki

---+ package TWiki::Query::OP_ref

=cut

package TWiki::Query::OP_ref;
use base 'TWiki::Query::BinaryOP';

use strict;
use Error qw( :try );

sub new {
    my $class = shift;
    return $class->SUPER::new( name => '/', prec => 700 );
}

sub evaluate {
    my $this   = shift;
    my $pnode  = shift;
    my %domain = @_;

    my $session = $domain{tom}->session;
    my $topic   = $domain{tom}->topic;

    my $a    = $pnode->{params}[0];
    my $node = $a->evaluate(@_);
    return undef unless defined $node;
    if ( ref($node) eq 'HASH' ) {
        return undef;
    }
    if ( !( ref($node) eq 'ARRAY' ) ) {
        $node = [$node];
    }
    my @result;
    foreach my $v (@$node) {
        next
          if $v !~
              /^($TWiki::regex{webNameRegex}\.)*$TWiki::regex{wikiWordRegex}$/;

        # Has to be relative to the web of the topic we are querying
        my ( $w, $t ) =
          $session->normalizeWebTopicName( $session->{webName}, $v );
        my $result = undef;
        try {
            my $submeta = $domain{tom}->getMetaFor( $w, $t );
            my $b       = $pnode->{params}[1];
            my $res     = $b->evaluate( tom => $submeta, data => $submeta );
            if ( ref($res) eq 'ARRAY' ) {
                push( @result, @$res );
            }
            else {
                push( @result, $res );
            }
        }
        catch Error::Simple with {};
    }
    return undef unless scalar(@result);
    return $result[0] if scalar(@result) == 1;
    return \@result;
}

1;

__DATA__

Module of Foswiki - The Free Open Source Wiki, http://foswiki.org/, http://TWiki.org/

Copyright (C) 2005-2007 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root of
this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

Author: Crawford Currie http://c-dot.co.uk
