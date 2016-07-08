# See bottom of file for license and copyright information
#
# See Plugin topic for history and plugin information

package Foswiki::Plugins::CommentPlugin::JQuery;
use v5.14;

use Moo;
extends qw( Foswiki::Plugins::JQueryPlugin::Plugin );

around BUILDARGS => sub {
    my $orig   = shift;
    my $class  = shift;
    my %params = @_;
    return $orig->(
        $class, @_,
        name          => 'Comment',
        version       => '3.0',
        author        => 'Crawford Currie',
        homepage      => 'http://foswiki.org/Extensions/CommentPlugin',
        puburl        => '%PUBURLPATH%/%SYSTEMWEB%/CommentPlugin',
        documentation => $params{app}->cfg->data->{SystemWebName}
          . ".CommentPlugin",
        css        => ["comment.css"],
        javascript => ["comment.js"]
    );
};

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2014 Foswiki Contributors. Foswiki Contributors
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
