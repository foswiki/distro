# See bottom of file for license and copyright information
=begin TML

---+ package Foswiki::Store::Listener;
Abstract base class (interface) for store listeners

---++ ObjectMethod insert(newmeta=>$obj[ , newattachment=>$string])
Event triggered when a new Meta object is inserted into the store

---++ ObjectMethod update(newmeta=>$obj[, oldmeta=>obj, newattachment=>$string, oldattachment=>$string])

We are updating the object. This is triggered when a meta-object
is saved. It should be logically equivalent to:
<verbatim>
remove($oldMetaObject)
insert($newMetaObject || $oldMetaObject)
</verbatim>
but listeners may optimise on this. The two parameter form is called when
a topic is moved.

---++ ObjectMethod remove(oldmeta=>obj [,  oldattachment=>$string])
We are removing the given object.

---++ ObjectMethod loadTopic($meta, $version) -> ($gotRev, $isLatest)
Patterned on =Foswiki::Store::readTopic=, this listener is called when
the store's =readTopic= method is called. The first listener to return
a $meta will be assumed to have loaded that meta object with
the requested revision.

Implementors do *not* need to provide this method; it is called only if
it's present in the listener.

Note that the listener may re-bless the $meta into a subclass
of =Foswiki::Meta=, should it be necessary to enhance that class.

Listeners can also use this callback as a means of monitoring topic loads
from a VC store.

=cut

1;
__END__

Author: Crawford Currie http://c-dot.co.uk

Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/, http://Foswiki.org/

Copyright (C) 2010 Foswiki Contributors. All Rights Reserved.
Foswiki Contributors are listed in the AUTHORS file in the root
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

