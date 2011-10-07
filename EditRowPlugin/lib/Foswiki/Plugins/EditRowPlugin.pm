# See bottom of file for copyright
package Foswiki::Plugins::EditRowPlugin;

use strict;

our $VERSION          = '$Rev$';
our $RELEASE          = '2.2.9';
our $SHORTDESCRIPTION = 'Inline edit for tables';
our $NO_PREFS_IN_TOPIC = 1;

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    Foswiki::Func::registerRESTHandler( 'save', \&save );

    return 1;
}

# Formerly this said:
# The handler has to be run from both beforeCommonTagsHandler and
# commonTagsHandler, because beforeCommonTagsHandler allows us to
# process tables before macros in their data are expanded,
# while the second call allows us to handle tables that have been
# included from other topics. Both handlers only fire when the topic
# text contains %EDITTABLE, thus constraining the problem.
#
# But since Item4970: disabled the beforeCommonTagsHandler because
# it pre-empts SpreadSheetPlugin, which uses a commonTagsHandler. This
# is consistent with EditTablePlugin, so fingers crossed.
#sub beforeCommonTagsHandler {
#   my ($text, $topic, $web, $meta) = @_;
#   if (_process($text, $web, $topic, $meta)) {
#       $_[0] = $text;
#   }
#}

sub commonTagsHandler {
    my ( $text, $topic, $web, $included, $meta ) = @_;
    require Foswiki::Plugins::EditRowPlugin::View;
    if ( Foswiki::Plugins::EditRowPlugin::View::process(
        $text, $web, $topic, $meta ) ) {
        $_[0] = $text;
    }
}

sub save {
    require Foswiki::Plugins::EditRowPlugin::Save;
    Foswiki::Plugins::EditRowPlugin::Save::process(@_);
}

# Replace content with a marker to prevent it being munged by Foswiki
our @refs;

sub defend {
    my ($text, $dequote) = @_;
    my $n = scalar(@refs);
    $text =~ s/"/&quot;/g if $dequote;
    push( @refs, $text );
    return "#\07$n\07#";
}

# Replace protected content.
sub postRenderingHandler {
    while ( $_[0] =~ s/#\07([0-9]+)\07#/$refs[$1]/g ) {
    }
}

1;
__END__

Author: Crawford Currie http://c-dot.co.uk

Copyright (c) 2008-2011 Foswiki Contributors
Copyright (c) 2007 WindRiver Inc. and TWiki Contributors.
All Rights Reserved. Foswiki Contributors are listed in the
AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

Do not remove this copyright notice.

This plugin supports editing of a table row-by-row.

It uses a fairly generic table object, and employs a REST handler
for saving.
