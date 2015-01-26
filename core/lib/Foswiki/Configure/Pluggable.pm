# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Configure::Pluggable

A Pluggable is a code module that generates items for a hard-coded block
in a configuration, marked by *NAME* in the .spec.

Pluggables are used for blocks in the configuration that cannot be handled
by the configuration abstraction, for example blocks used for
downloading extensions, managing plugins, and managing languages.

A pluggable block will normally inject programatically
generated configuration entries (subclasses of Foswiki::Configure::Item) into
the configuration, usually by appending to the $open configuration item
(which will normally be a Foswiki::Configure::Section).

Pluggable implementations are loaded by the parser by calling the
=load= static method in this class. The implementations are packages
in Foswiki::Configure::Pluggables, and must provide at least the following
function:

---++ StaticMethod construct( \@settings, $file, $line )

Implemented by subclasses to create the pluggable. Pluggables are
created in-place, by generating and adding Foswiki::Configure::Item
objects and adding them to the settings array.

   * =\@settings= - ref to the top level array of settings
   * =$file=, =$line= - file and line in the .spec that triggered the pluggable

Note that there is no need for constructors to worry about the hierarchical
structure of .spec. The structure is only generated after all items have
been generated, by analysis of section markers placed in the settings array.
So items should be added by simply pushing them into @$settings. However,
should a pluggable require a structure within the containing section, it is
OK to push new =Foswiki::Configure::Section= objects to @$settings and
populate them using =->addChild=.

Note also that values added by pluggables should *NOT* have defined_at
set. The presence of this field is used to indicate whether a field was
defined explicitly, or in a pluggable.

=cut

package Foswiki::Configure::Pluggable;

use strict;
use warnings;

use Assert;

=begin TML

---++ StaticMethod load($id)

Loads a pluggable section from =Foswiki::Configure::Pluggables::$id=

Will die if there's a problem.

Returns the result from the Pluggable class's =construct=

=cut

sub load {
    my $name = shift;

    my $modelName = 'Foswiki::Configure::Pluggables::' . $name;
    eval("require $modelName; ${modelName}::construct(\@_);");
    die $@ if $@;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
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
