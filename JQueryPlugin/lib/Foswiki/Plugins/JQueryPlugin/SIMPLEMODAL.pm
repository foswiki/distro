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

package Foswiki::Plugins::JQueryPlugin::SIMPLEMODAL;
use strict;

use base 'Foswiki::Plugins::JQueryPlugin::Plugin';

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::SIMPLEMODAL

This is the perl stub for the jquery.maskedinput plugin.

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
    name => 'SimpleModal',
    version => '1.2.3',
    author => 'Eric Martin',
    homepage => 'http://ericmmartin.com',
    css => ['jquery.simplemodal.css'],
    javascript => ['jquery.simplemodal.js'],
  ), $class);

  $this->{summary} = <<'HERE';
SimpleModal is a lightweight jQuery plugin that provides a simple
interface to create a modal dialog.

The goal of SimpleModal is to provide developers with a cross-browser
overlay and container that will be populated with data provided to
SimpleModal.

There are two ways to call SimpleModal:
1) As a chained function on a jQuery object, like $('#myDiv').modal();.
This call would place the DOM object, #myDiv, inside a modal dialog.
Chaining requires a jQuery object. An optional options object can be
passed as a parameter.

Examples:
<verbatim class="html">
$('<div>my data</div>').modal({options});
$('#myDiv').modal({options});
jQueryObject.modal({options});
</verbatim>

2) As a stand-alone function, like $.modal(data). The data parameter
is required and an optional options object can be passed as a second
parameter. This method provides more flexibility in the types of data
that are allowed. The data could be a DOM object, a jQuery object, HTML
or a string.

<verbatim>
$.modal('<div>my data</div>', {options});
$.modal('my data', {options});
$.modal($('#myDiv'), {options});
$.modal(jQueryObject, {options});
$.modal(document.getElementById('myDiv'), {options});
</verbatim>

A SimpleModal call can contain multiple elements, but only one modal
dialog can be created at a time. Which means that all of the matched
elements will be displayed within the modal container.

SimpleModal internally sets the CSS needed to display the modal dialog
properly in all browsers, yet provides the developer with the flexibility
to easily control the look and feel. The styling for SimpleModal can be
done through external stylesheets, or through SimpleModal, using the
overlayCss and/or containerCss options.

SimpleModal has been tested in the following browsers:
   * IE 6, 7
   * Firefox 2, 3
   * Opera 9
   * Safari 3
HERE

  return $this;
}

1;

