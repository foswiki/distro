# See bottom of file for license and copyright information
package Foswiki::Infix::OP;

=begin TML

---+ package Foswiki::Infix::OP

Base class of operators recognised by the Foswiki::Infix::Parser. Predefined fields
in this object used by Foswiki::Infix::Parser are:
   * =name= - operator string.
   * =prec= - operator precedence, positive non-zero integer.
     Larger number => higher precedence.
   * =arity= - set to 1 if this operator is unary, 2 for binary. Arity 0
     is legal, should you ever need it. Use arity=2 and canfold=1 for
     n-ary operators.
   * =close= - used with bracket operators. =name= should be the open
     bracket string, and =close= the close bracket. The existance of =close=
     marks this as a bracket operator.
   * =casematters== - indicates that the parser should check case in the
     operator name (i.e. treat 'AND' and 'and' as different).
     By default operators are case insensitive. *Note* that operator
     names must be caselessly unique i.e. you can't define 'AND' and 'and'
     as different operators in the same parser. Does not affect the
     interpretation of non-operator terminals (names).
   * =canfold= - means that adjacent nodes with identical operators
     can be folded together i.e. the operands of the second node can
     be pushed onto the parameter list of the first. This is used (for
     example) for comma lists.
Other fields in the object can be used for other purposes. However field
names in the hash starting with =InfixParser_= are reserved for use
by the parser.

=cut

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

sub new {
    my ( $class, %opts ) = @_;
    return bless( \%opts, $class );
}

1;
__END__
Author: Crawford Currie http://c-dot.co.uk

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010-2011 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
