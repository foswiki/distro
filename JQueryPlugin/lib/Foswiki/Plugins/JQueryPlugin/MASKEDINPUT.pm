# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# 
# Copyright (C) 2006-2009 Michael Daum, http://michaeldaumconsulting.com
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. 
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::JQueryPlugin::MASKEDINPUT;
use strict;

use base 'Foswiki::Plugins::JQueryPlugin::Plugin';

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::MASKEDINPUT

This is the perl stub for the jquery.empty plugin.

=cut

=begin TML

---++ ClassMethod new( $class, $session, ... )

Constructor

=cut

sub new {
  my $class = shift;
  my $session = shift || $Foswiki::Plugins::SESSION;

  my $this = bless($class->SUPER::new( 
    $session,
    name => 'MaskedInput',
    version => '1.2.2',
    author => 'Josh Bush',
    homepage => 'http://digitalbush.com/projects/masked-input-plugin',
    javascript => ['jquery.maskedinput.js', 'jquery.maskedinput.init.js'],
  ), $class);

  $this->{summary} = <<'HERE';
This is a masked input plugin for the jQuery javascript library. It allows a
user to more easily enter fixed width input where you would like them to enter
the data in a certain format (dates,phone numbers, etc). It has been tested on
Internet Explorer 6/7, Firefox 1.5/2/3, Safari, Opera, and Chrome.   A mask is
defined by a format made up of mask literals and mask definitions. Any
character not in the definitions list below is considered a mask literal. Mask
literals will be automatically entered for the user as they type and will not
be able to be removed by the user. 

The following mask definitions are
predefined: 
  * a - Represents an alpha character (A-Z,a-z)
  * 9 - Represents a numeric character (0-9)
  * * - Represents an alphanumeric character (A-Z,a-z,0-9)

Examples:
<verbatim class="html">
$("#date").mask("99/99/9999");
$("#phone").mask("(999) 999-9999");
$("#tin").mask("99-9999999");
$("#ssn").mask("999-99-9999");
</verbatim>

Use a space instead of an underscore "_" character as a placeholder
<verbatim class="html">
$("#product").mask("99/99/9999",{
  placeholder:" "
});
</verbatim>

Adda "completed" callback:
<verbatim>
$("#product").mask("99/99/9999",{
  completed: function() {
    alert("You typed the following: "+this.val());
  }
});
</verbatim>

Define an own mask:
<verbatim>
$.mask.definitions['~']='[+-]';
$("#eyescript").mask("~9.99 ~9.99 999");
</verbatim>
HERE

  return $this;
}

1;

