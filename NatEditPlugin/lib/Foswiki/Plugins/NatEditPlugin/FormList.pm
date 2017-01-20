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

package Foswiki::Plugins::NatEditPlugin::FormList;

use strict;
use warnings;

use Foswiki::Func                  ();
use Foswiki::Plugins::JQueryPlugin ();

=begin TML

---+ package Foswiki::Plugins::NatEditPlugin::FormList

taken from Foswiki::UI::ChangeForm and leveraged to normal formatting standards

SMELL: should be added to the core

=cut

sub handle {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    my $theFormat =
         $params->{_DEFAULT}
      || $params->{format}
      || '<label><input type="radio" name="formtemplate" id="formtemplateelem$index" $checked value="$name">'
      . '&nbsp;$formTopic</input></label>';

    $theWeb   = $params->{web}   if defined $params->{web};
    $theTopic = $params->{topic} if defined $params->{topic};
    my $theSeparator = $params->{separator};
    my $theHeader    = $params->{header} || '';
    my $theFooter    = $params->{footer} || '';
    my $theSelected  = $params->{selected};

    my $request = Foswiki::Func::getCgiQuery();
    $theSelected = $request->param('formtemplate') unless defined $theSelected;
    $theSeparator = '<br />' unless defined $theSeparator;

    unless ($theSelected) {
        my ($meta) = Foswiki::Func::readTopic( $theWeb, $theTopic );
        my $form = $meta->get('FORM');
        $theSelected = $form->{name} if $form;
    }
    $theSelected = 'none' unless $theSelected;
    $theSelected =~ s/\//\./g;

    my $legalForms = Foswiki::Func::getPreferencesValue( 'WEBFORMS', $theWeb );
    $legalForms =~ s/^\s*//;
    $legalForms =~ s/\s*$//;
    my %forms = map {
        my ( $formWeb, $formTopic ) =
          $session->normalizeWebTopicName( $theWeb, $_ );
        $_ => {
            web   => $formWeb,
            topic => $formTopic,
            name  => $_
          }
    } split( /[,\s]+/, $legalForms );
    my @forms = sort { $a->{topic} cmp $b->{topic} } values %forms;
    push @forms,
      {
        web   => '',
        topic => 'none',
        name  => 'none',
      };

    my @formList = '';
    my $index    = 0;
    foreach my $form (@forms) {
        $index++;
        my $text    = $theFormat;
        my $checked = '';
        $checked = 'checked' if $form->{name} eq $theSelected;

        $text =~ s/\$index/$index/g;
        $text =~ s/\$checked/$checked/g;
        $text =~ s/\$name/$form->{name}/g;
        $text =~ s/\$formWeb/$form->{web}/g;
        $text =~ s/\$formTopic/$form->{topic}/g;

        push @formList, $text;
    }
    my $result = $theHeader . join( $theSeparator, @formList ) . $theFooter;
    $result =~ s/\$count/$index/g;
    $result =~ s/\$web/$theWeb/g;
    $result =~ s/\$topic/$theTopic/g;

    return Foswiki::Func::decodeFormatTokens($result);
}

1;

