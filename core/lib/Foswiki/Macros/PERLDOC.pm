# See bottom of file for license and copyright information
package Foswiki::Macros::PERLDOC;

use Try::Tiny;
use Data::Dumper;

use Foswiki::Class qw(app);
extends qw<Foswiki::Object>;
with qw<Foswiki::Macro>;

sub expand {
    my $this = shift;
    my ( $params, $topicObject ) = @_;

    Foswiki::load_package('Foswiki::IncludeHandlers::doc');

    #my $anchor = Foswiki::IncludeHandlers::doc::_makeAnchor

    my $result = "";

    my $module = $params->{_DEFAULT} || 'Foswiki';
    my ( $anchor, $type, $linkText ) = ( "", "", $module );

  TYPE: foreach $type (qw<method attr attribute>) {
        if ( defined $params->{$type} ) {
            $anchor =
              Foswiki::IncludeHandlers::doc::_makeAnchor( $this->app,
                $type => $params->{$type} );
            $linkText = $module . "::" . $params->{$type};
            $linkText .= "()" if ( $type eq 'method' );
            $linkText = "$linkText";
            last TYPE;
        }
    }

    $linkText = $params->{text}   if $params->{text};
    $anchor   = $params->{anchor} if $params->{anchor};
    $anchor = "#$anchor" unless $anchor =~ /^#/;

    my $cfgData = $this->app->cfg->data;
    my $sysWeb  = $cfgData->{SystemWebName};
    my $viewUrl =
      $this->app->getScriptUrl( $sysWeb, "PerlDoc", "view", module => $module );

    $result .= "[[" . $viewUrl . $anchor . "][" . $linkText . "]]";

    return $result;
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2017 Foswiki Contributors. Foswiki Contributors
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
