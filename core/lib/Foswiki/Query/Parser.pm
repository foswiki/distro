# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Query::Parser

Parser for queries

=cut

package Foswiki::Query::Parser;

use strict;
use warnings;
use Assert;

use Foswiki::Infix::Parser ();
our @ISA = ('Foswiki::Infix::Parser');

use Foswiki::Query::Node ();

# Operators
#
# In the following, the standard InfixParser node structure is extended by
# one field, 'exec'.
#
# exec is the name of a member function of the 'Query' class that evaluates
# the node. It is called on the node and is passed a $domain. The $domain
# is a reference to a hash that contains the data being operated on, and a
# reference to the meta-data of the topic being worked on (this is
# effectively the "topic object"). The data being operated on can be a
# Meta object, a reference to an array (such as attachments), a reference
# to a hash (such as TOPICINFO) or a scalar. Arrays can contain other arrays
# and hashes.

sub new {
    my ( $class, $options ) = @_;

    $options->{words}     ||= qr/([A-Z][A-Z0-9_:]*|({[A-Z][A-Z0-9_]*})+)/i;
    $options->{nodeClass} ||= 'Foswiki::Query::Node';
    my $this = $class->SUPER::new($options);
    die "{Operators}{Query} is undefined; re-run configure"
      unless defined( $Foswiki::cfg{Operators}{Query} );
    foreach my $op ( @{ $Foswiki::cfg{Operators}{Query} } ) {
        eval "require $op";
        ASSERT( !$@, $@ ) if DEBUG;
        $this->addOperator( $op->new() );
    }
    return $this;
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
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
