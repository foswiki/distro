# See bottom of file for license and copyright information
package Foswiki::Plugins::JQueryPlugin::VALIDATE;
use strict;
use warnings;

use Foswiki::Plugins::JQueryPlugin::Plugin;
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::VALIDATE

This is the perl stub for the jquery.validate plugin.

=cut

=begin TML

---++ ClassMethod new( $class, ... )

Constructor

=cut

sub new {
    my $class = shift;

    my $this = bless(
        $class->SUPER::new(
            name         => 'Validate',
            version      => '1.21.1',
            author       => 'Joern Zaefferer',
            homepage     => 'http://jqueryvalidation.org/',
            javascript   => ['pkg.js'],
            dependencies => ['form'],
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

    # open matching localization file if it exists
    my $session = $Foswiki::Plugins::SESSION;
    my $langTag = $session->i18n->language();
    my $messagePath =
        $Foswiki::cfg{SystemWebName}
      . '/JQueryPlugin/plugins/validate/localization/messages_'
      . $langTag . '.js';
    my $messageFile = $Foswiki::cfg{PubDir} . '/' . $messagePath;
    if ( -f $messageFile ) {
        my $text =
          "<script src='$Foswiki::cfg{PubUrlPath}/$messagePath'></script>\n";
        Foswiki::Func::addToZone(
            'script', "JQUERYPLUGIN::VALIDATE::LANG",
            $text,    'JQUERYPLUGIN::VALIDATE'
        );
    }

}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010-2025 Foswiki Contributors. Foswiki Contributors
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
