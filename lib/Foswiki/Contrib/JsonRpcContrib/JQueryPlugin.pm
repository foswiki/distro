# See bottom of file for license and copyright information

package Foswiki::Contrib::JsonRpcContrib::JQueryPlugin;
use strict;
use warnings;

use Foswiki::Plugins::JQueryPlugin::Plugin ();
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

=begin TML

---+ package Foswiki::Contrib::JsonRpcContrib::JQueryPlugin

This is the perl stub for the JSON-RPC jquery plugin.

=cut

=begin TML

---++ ClassMethod new( $class, ... )

Constructor

=cut

sub new {
    my $class = shift;

    my $this = bless(
        $class->SUPER::new(
            name         => 'JsonRpc',
            version      => '1.0',
            author       => 'Michael Daum',
            homepage     => 'http://foswiki.org/Extensions/JsonRpcContrib',
            javascript   => ['jquery.jsonrpc.js'],
            puburl       => '%PUBURLPATH%/%SYSTEMWEB%/JsonRpcContrib',
            dependencies => ['JQUERYPLUGIN::JSON2'],
        ),
        $class
    );

    return $this;
}

=begin TML

---++ ClassMethod init()

add json2 for browsers <= IE7

=cut

sub init {
    my $this = shift;
    return 0 if $this->{isInit};

    $this->SUPER::init();

    my $text = '';

    # disabled support for < IE7
    if (0) {

        $text .= <<"HERE";
<literal><!--[if lte IE 7]>
$this->renderJS("json2.js").
<![endif]--></literal>
HERE

    }

    Foswiki::Func::addToZone( 'script', 'JQUERYPLUGIN::JSON2', $text );
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2011-2012 Michael Daum http://michaeldaumconsulting.com

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.


