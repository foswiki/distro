# See bottom of file for license and copyright information
#
# See Plugin topic for history and plugin information

package Foswiki::Plugins::CommentPlugin::JQuery;
use strict;
use warnings;

use Foswiki::Plugins::JQueryPlugin::Plugin ();
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

sub new {
    my $class = shift;
    my $session = shift || $Foswiki::Plugins::SESSION;

    my $this = $class->SUPER::new(
        $session,
        name          => 'Comment',
        version       => '3.0',
        author        => 'Crawford Currie',
        homepage      => 'http://foswiki.org/Extensions/CommentPlugin',
        puburl        => '%PUBURLPATH%/%SYSTEMWEB%/CommentPlugin',
        documentation => "$Foswiki::cfg{SystemWebName}.CommentPlugin",
        css           => ["comment.css"],
        javascript    => ["comment.js"]
    );

    return $this;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2014-2020 Foswiki Contributors. Foswiki Contributors
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
