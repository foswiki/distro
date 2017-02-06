# See bottom of file for license and copyright information
package Foswiki::Contrib::JEditableContrib;

use strict;
use warnings;

our $VERSION = '1.72';
our $RELEASE = '06 Feb 2017';
our $SHORTDESCRIPTION =
  'The JQuery "JEditable" plugin, packaged for use in Foswiki';

=begin TML

Call this from any other extension to include this plugin. For example,
<verbatim>
require Foswiki::Contrib::JEditableContrib;
Foswiki::Contrib::JEditableContrib::init();
</verbatim>

=cut

sub init {
    unless (
        Foswiki::Plugins::JQueryPlugin::registerPlugin(
            'JEditable', 'Foswiki::Contrib::JEditableContrib::JEDITABLE'
        )
      )
    {
        die 'Failed to register JEditable plugin';
    }
    unless ( Foswiki::Plugins::JQueryPlugin::createPlugin("JEditable") ) {
        die 'Failed to create JEditable plugin';
    }
    return 1;
}

1;
__END__
Author: Crawford Currie http://c-dot.co.uk

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2011-2017 Foswiki Contributors. Foswiki Contributors
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
