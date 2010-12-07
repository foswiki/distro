# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Query::OP_unaryat
Unary @; get versions of current topic.

=cut

package Foswiki::Query::OP_unaryat;

use strict;
use warnings;
use Foswiki::Query::UnaryOP ();
our @ISA = ('Foswiki::Query::UnaryOP');

use Error qw( :try );
use Assert;

sub new {
    my $class = shift;
    return $class->SUPER::new( name => '@', prec => 960 );
}

sub evaluate {
    my $this   = shift;
    my $pnode  = shift;
    my %domain = @_;

    eval "require $Foswiki::cfg{Store}{QueryAlgorithm}";
    die $@ if $@;

    my $rhs = $pnode->{params}[0]->evaluate(@_);
    ASSERT( !ref $rhs || ref($rhs) eq 'ARRAY' ) if DEBUG;
    $rhs = [ $rhs ] unless ref $rhs;

    my @result;

    if (scalar(@$rhs)) {
	# For each version on the RHS
	foreach my $version ( @$rhs ) {
	    ASSERT(!ref $version) if DEBUG;
	    ASSERT($version =~ /^\d+$/) if DEBUG;
	    my $submeta = $Foswiki::cfg{Store}{QueryAlgorithm}->getRefTopic(
		$domain{tom}, $domain{tom}->web(),
		$domain{tom}->topic(), $version );
	    push(@result, $submeta);
	}
    } else {
	# Empty array; get all revisions
	my $m = $Foswiki::cfg{Store}{QueryAlgorithm}->getRefTopic(
	    $domain{tom}, $domain{tom}->web(), $domain{tom}->topic());
	my $it = $m->getRevisionHistory();
	while ($it->hasNext()) {
	    my $id = $it->next();
	    $m = $Foswiki::cfg{Store}{QueryAlgorithm}->getRefTopic(
		$domain{tom}, $domain{tom}->web(),
		$domain{tom}->topic(), $id);
	    push(@result, $m);
	}
    }
    return \@result;
}

sub evaluatesToConstant {
    my ($this, $node) = @_;
    # Operator depends on the context; can't fold it.
    return 0;
}

1;
__END__
Author: Crawford Currie http://c-dot.co.uk

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
