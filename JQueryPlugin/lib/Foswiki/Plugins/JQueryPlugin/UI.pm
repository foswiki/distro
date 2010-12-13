# See bottom of file for license and copyright information
package Foswiki::Plugins::JQueryPlugin::UI;
use strict;
use warnings;
use Foswiki::Plugins                        ();
use Foswiki::Plugins::JQueryPlugin::Plugins ();

use Foswiki::Plugins::JQueryPlugin::Plugin;
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::UI

This is the perl stub for the jquery.ui

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
            name        => 'UI',
            version     => '1.8.5',
            puburl      => '%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/ui',
            author      => 'see http://jqueryui.com/about',
            homepage    => 'http://docs.jquery.com/UI',
            javascript  => ['jquery-ui.js'],
            dependencies => [ 'metadata', 'livequery' ],
        ),
        $class
    );

    return $this;
}

=begin TML

---++ ClassMethod init( $this )

Initialize this plugin by adding the required static files to the page 

=cut

sub init {
    my $this = shift;

    return unless $this->SUPER::init();

    # add the base theme
    Foswiki::Func::addToZone( "head", "JQUERYPLUGIN::UI",
        <<HERE, "JQUERYPLUGIN::FOSWIKI" );
<link rel="stylesheet" href="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/themes/base/jquery-ui.css" type="text/css" media="all" />
HERE

    # load the custom theme
    Foswiki::Plugins::JQueryPlugin::Plugins::createTheme($Foswiki::cfg{JQueryPlugin}{JQueryTheme});

    # open matching localization file if it exists
    my $langTag = $this->{session}->i18n->language();
    my $messagePath =
        $Foswiki::cfg{SystemWebName}
      . '/JQueryPlugin/i18n/ui.datepicker-'
      . $langTag . '.js';

    my $messageFile = $Foswiki::cfg{PubDir} . '/' . $messagePath;
    if ( -f $messageFile ) {
        Foswiki::Func::addToZone(
            'script', "JQUERYPLUGIN::UI::LANG",
            <<"HERE", 'JQUERYPLUGIN::UI' );
<script type='text/javascript' src='$Foswiki::cfg{PubUrlPath}/$messagePath'></script>";
HERE
    }
}
1;

__END__
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
