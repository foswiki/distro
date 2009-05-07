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

package Foswiki::Plugins::JQueryPlugin::COOKIE;
use strict;

use base 'Foswiki::Plugins::JQueryPlugin::Plugin';

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::COOKIE

This is the perl stub for the jquery.cookie plugin.

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
    name => 'Cookie',
    version => '20070917', # based on the blog posting on the homepage
    author => 'Klaus Hartl',
    homepage => 'http://www.stilbuero.de/2006/09/17/cookie-plugin-for-jquery',
    javascript => ['jquery.cookie.js'],
  ), $class);

  $this->{summary} = <<'HERE';
Easy cookie handling using jQuery.

Example usage:
   * =$.cookie('the_cookie');=: return the value of the cookie
   * =$.cookie('the_cookie', 'the_value');=: set the value of a cookie
   * =$.cookie('the_cookie', 'the_value', { expires: 7, path: '/', domain: 'jquery.com', secure: true });=: 
     create a cookie with all available options.
   * =$.cookie('the_cookie', null);=: delete a cookie by passing null as value. 
      Keep in mind that you have to use the same path and domain used when the cookie was set.

Options: 
   * expires: either an integer specifying the expiration date from now on in days or a Date object.
     If a negative value is specified (e.g. a date in the past), the cookie will
     be deleted.  If set to null or omitted, the cookie will be a session cookie and
     will not be retained when the the browser exits.
   * path: the value of the path atribute of the cookie (default: path of page that created the cookie).
   * domain: the value of the domain attribute of the cookie (default: domain of page that created the cookie).
   * secure: if true, the secure attribute of the cookie will be set and the cookie transmission will
     require a secure protocol (like HTTPS).
HERE

  return $this;
}

1;
