# Copyright (C) 2007-2017 Michael Daum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

package Foswiki::Plugins::NatEditPlugin::FormButton;

use strict;
use warnings;

use Foswiki::Func                  ();
use Foswiki::Plugins::JQueryPlugin ();

=begin TML

---+ package Foswiki::Plugins::NatEditPlugin::FormButton

render a button to add/change the form while editing
returns
   * the empty string if there's no WEBFORM
   * or "Add form" if there is no form attached to a topic yet
   * or "Change form" otherwise

there are no native means besides the "addform" template being used
to render the FORMFIELDS. but this is not what we need here at all. infact
we need an empty addform.nat.tmp to switch off this feature of FORMFIELDS

=cut

sub handle {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    Foswiki::Plugins::JQueryPlugin::createPlugin("natedit");

    my $saveCmd = '';
    my $request = Foswiki::Func::getCgiQuery();
    $saveCmd = $request->param('cmd') || '' if $request;
    return '' if $saveCmd eq 'repRev';

    my $form = $request->param('formtemplate') || '';

    unless ($form) {
        my ( $meta, $dumy ) = Foswiki::Func::readTopic( $theWeb, $theTopic );
        my $formMeta = $meta->get('FORM');
        $form = $formMeta->{"name"} if $formMeta;
    }

    $form = '' if $form eq 'none';

    my $action;
    my $actionTitle;
    my $actionText;

    if ($form) {
        $action = 'replaceform';
    }
    else {
        $action = 'addform';
    }

    if ($form) {
        $actionText = $session->{i18n}->maketext("Change form");
        $actionTitle =
          $session->{i18n}->maketext( "Change the current form of <nop>[_1]",
            "$theWeb.$theTopic" );
    }
    elsif ( Foswiki::Func::getPreferencesValue( 'WEBFORMS', $theWeb ) ) {
        $actionText = $session->{i18n}->maketext("Add form");
        $actionTitle =
          $session->{i18n}
          ->maketext( "Add a new form to <nop>[_1]", "$theWeb.$theTopic" );
    }
    else {
        return '';
    }
    $actionText  =~ s/&&/\&/g;
    $actionTitle =~ s/&&/\&/g;

    my $theFormat = $params->{_DEFAULT} || $params->{format} || '$link';
    $theFormat =~
s/\$link/<a href='\$url' accesskey='f' title='\$title'><span>\$acton<\/span><\/a>/g;
    $theFormat =~ s/\$url/javascript:\$script/g;
    $theFormat =~ s/\$script/submitEditForm('save', '$action');/g;
    $theFormat =~ s/\$title/$actionTitle/g;
    $theFormat =~ s/\$action/$actionText/g;
    $theFormat =~ s/\$id/$action/g;

    return Foswiki::Func::decodeFormatTokens($theFormat);
}

1;
