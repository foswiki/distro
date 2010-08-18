# See bottom of file for license and copyright information
package Foswiki::Plugins::JQueryPlugin::FOSWIKI;
use strict;
use warnings;
use Foswiki::Func;
use Foswiki::Plugins::JQueryPlugin::Plugin;
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::FOSWIKI

This is the perl stub for the jquery.foswiki plugin.

=cut

=begin TML

---++ ClassMethod new( $class, $session, ... )

Constructor

=cut

sub new {
    my $class = shift;
    my $session = shift || $Foswiki::Plugins::SESSION;

    my $this = bless(
        $class->SUPER::new(
            $session,
            name         => 'Foswiki',
            version      => '2.01',
            author       => 'Michael Daum',
            homepage     => 'http://foswiki.org/Extensions/JQueryPlugin',
            dependencies => ['livequery'],
            tags         => 'JQTHEME, JQREQUIRE, JQICON, JQICONPATH, JQPLUGINS',
        ),
        $class
    );

    return $this;
}

=begin TML

---++ ClassMethod init( $this )

Initialize this plugin by adding the required static files to the html header

=cut

sub init {
    my $this = shift;

    return unless $this->SUPER::init();

    my $js = 'jquery.foswiki';
    $js .= '.uncompressed' if $this->{debug};
    $js .= '.js?version=' . $this->{version};

    # Not used
    #my $header = '';
    #Foswiki::Func::addToZone('head', 'JQUERYPLUGIN::FOSWIKI',
    #                         $header, 'JQUERYPLUGIN');

    my $footer = <<FOOTER;
<script type='text/javascript' src='%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/foswiki/$js'></script>
FOOTER

    Foswiki::Func::addToZone( 'body', 'JQUERYPLUGIN::FOSWIKI', $footer,
        'JQUERYPLUGIN' );
}

1;
__END__
Author: Michael Daum, http://michaeldaumconsulting.com

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2006-2010 Michael Daum http://michaeldaumconsulting.com

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
