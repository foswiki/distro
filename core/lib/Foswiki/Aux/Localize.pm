# See bottom of file for license and copyright information

=begin TML

---++ Role Foswiki::Aux::Localize

This role determines classes which are able to simulate =local= Perl operator
using OO approach. They do it by providing two methods: =localize()= and
=restore()=. The first one cleans up object to some desired state. For example –
by cleaning up all attributes or by settings some/all of them to user-provided
values. Then it creates a instance of =Foswiki::Aux::Holder= class and passes it
a refernce to the object being localized. The holder is supposed to be stored in
a =my= variable within same scope for where we would like the =local= operator
to be active. When we leaving the scope the holder object destroyer method calls
the =restore()= method of the localized object. After that we expect that the
object is been restored to its pre-localized state.

Though it may sound a bit complicated the actual use is as simple as:

<verbatim>
sub someMethod {
    my $localizableObj = Foswiki::Localizable->new( attr => 'attr string' );
    if ($some_condition) {
        my $holder = $localizableObj->localize( attr => 'another string' );
        
        ...; # Do something here
    }
    # At this point $localizableObj is in the same state as it was before the
    # if() clause.
}
</verbatim>

Note that =$holder->object= is equal to =$localizedObj=; in other words it's not
the object in its pre-localized state but in its current state. It's not
recommended to use the holder object other than in the last code sample.

This role HAS to be considered temporary compatibility solution. In the future
use of the =localize()= method must be replaced by temporary objects of the same
class.

=cut

package Foswiki::Aux::Localize;
use v5.14;

use Foswiki::Aux::Holder ();

use Moo::Role;

=begin TML

---++ ObjectMethod localize() => $holder

Returns a newly created =Foswiki::Aux::Holder= instance. The actual localization
shall be done by the class with this role.

=cut

sub localize {
    return Foswiki::Aux::Holder->new( object => $_[0] );
}

=begin TML

---++ Required ObjectMethod restore()

This method shall restore a object to its state before the last call to the
=localize()= method.

=cut

requires 'restore';

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2016 Foswiki Contributors. Foswiki Contributors
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
