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

package Foswiki::Plugins::JQueryPlugin::SHRINKURLS;
use strict;

use base 'Foswiki::Plugins::JQueryPlugin::Plugin';

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::SHRINKURLS

This is the perl stub for the jquery.shrinkurl plugin.

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
    name => 'ShrinkUrls',
    version => '1.1',
    author => 'Michael Daum',
    homepage => 'http://michaeldaumconsulting.com',
    javascript => ['jquery.shrinkurls.js'],
  ), $class);

  $this->{summary} = <<'HERE';
Shrinks all urls in a given container whose link text exceeds
a given size and have no white spaces in it, that is don't
wrap around nicely. If the text is skrunk, the original text
is appended to the title attribute of the anchor.

Usage:
<verbatim class="html">
 $("#container a").shrinkUrls({
   size:<number>,           // max size (default 25)
   include:'<regex>'       // regular expression a link text must
                           // match to be considered
   exclude:'<regex>'       // regular expression a link text must
                           // not match to be considered
   whitespace:<boolean>,   // true: even shrink if there's whitespace
                           // in the link text (default false)
   trunc:<head|middle|tail> // position where to insert the ellipsis
 });
</verbatim>

HERE

  return $this;
}

1;
