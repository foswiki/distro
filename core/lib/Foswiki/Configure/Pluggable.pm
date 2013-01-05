# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Configure::Pluggable

Support for placeholders in a configuration that represent a pluggable
UI block, i.e the blocks used for downloading extensions, managing
plugins, and managing languages.

A pluggable block may be a simple section with dynamically generated
configuration entries (e.g. generated programatically after inspecting
the disk) and/or may have special semantics, or may have a special UI which
may override the behaviors of a standard item. Normally pluggables
are sections, containing values and other sections. If this isn't
appropriate, you will have to implement a new visit() function for
iterating over the model.  visit() must expose all Value items for
checkers and saving configuration data.

=cut

package Foswiki::Configure::Pluggable;

use strict;
use warnings;

use Foswiki::Configure::Section ();
our @ISA = ('Foswiki::Configure::Section');

=begin TML

---++ StaticMethod load($id) -> $pluggableSection

Loads a pluggable section from Foswiki::Configure::Pluggables::

=cut

sub load {
    my $name = shift;
    my ( $file, $root, $settings ) = @_;

    my $modelName = 'Foswiki::Configure::Pluggables::' . $name;
    eval "use $modelName";
    Carp::confess $@ if $@;

    no strict 'refs';
    my $model = $modelName->new(@_);
    use strict 'refs';

    return $model;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
