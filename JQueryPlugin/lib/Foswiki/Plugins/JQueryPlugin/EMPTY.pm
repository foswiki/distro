# See bottom of file for license and copyright information
package Foswiki::Plugins::JQueryPlugin::EMPTY;
use strict;
use warnings;

use Foswiki::Plugins::JQueryPlugin::Plugin;
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::EMPTY

This is the perl stub for the jquery.empty plugin.

=cut

=begin TML

---++ ClassMethod new( $class, ... )

Constructor

=cut

sub new {
    my $class = shift;

    my $this = bless(
        $class->SUPER::new(
            name     => 'Empty',
            version  => '1.0',
            author   => 'First Last',
            homepage => 'http://...',
            tags     => 'EMPTY',
            i18n     => $Foswiki::cfg{SystemWebName}
              . "/JQueryPlugin/plugins/empty/i18n",
            css        => ['jquery.empty.css'],
            javascript => ['jquery.empty.js'],

            #dependencies => ['some other plugin'],
        ),
        $class
    );

    return $this;
}

=begin TML

---++ ClassMethod init( $this )

Initialize this plugin by adding the required static files to the html header

=cut

sub DISinit {
    my $this = shift;

    return unless $this->SUPER::init();
}

=begin TML

---++ ClassMethod handleEMPTY( $this, $params, $topic, $web ) -> $result

Tag handler for =%<nop>EMPTY%=. You might need to add 
to Foswiki::Plugins::JQueryPlugin::initPlugin() the following:

<verbatim>
  Foswiki::Func::registerTagHandler('EMPTY', \&handleEMPTY );
</verbatim>

and also

<verbatim>
sub handleEMPTY {
  my $session = shift;
  my $plugin = createPlugin('Empty', $session);
  return $plugin->handleEMPTY(@_) if $plugin;
  return '';
}
</verbatim>

=cut

sub handleEMPTY {
    my ( $this, $params, $topic, $web ) = @_;

    return "<span class='foswikiAlert'>This is empty.</span>";
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010-2016 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
