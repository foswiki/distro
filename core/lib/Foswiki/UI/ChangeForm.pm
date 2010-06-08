# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::UI::ChangeForm

Service functions used by the UI packages

=cut

package Foswiki::UI::ChangeForm;

use strict;
use warnings;
use Error qw( :try );
use Assert;

use Foswiki       ();
use Foswiki::Form ();

=begin TML

---+ ClassMethod generate( $session, $web, $topic, $editaction )

Generate the page that supports selection of the form.

=cut

sub generate {
    my ( $session, $topicObject, $editaction ) = @_;
    ASSERT( $session->isa('Foswiki') ) if DEBUG;

    my $page = $session->templates->readTemplate('changeform');
    my $q    = $session->{request};

    my $formName = $q->param('formtemplate') || '';
    unless ($formName) {
        my $form = $topicObject->get('FORM');
        $formName = $form->{name} if $form;
    }
    $formName = 'none' if ( !$formName );

    my @forms = Foswiki::Form::getAvailableForms($topicObject);
    unshift( @forms, 'none' );

    my $formList      = '';
    my $formElemCount = 0;
    foreach my $form (@forms) {
        $formElemCount++;
        $formList .= CGI::br() if ($formList);
        my $formElemId = 'formtemplateelem' . $formElemCount;
        my $props      = {
            type  => 'radio',
            name  => 'formtemplate',
            id    => $formElemId,
            value => $form
        };
        $props->{checked} = 'checked' if $form eq $formName;
        $formList .= CGI::input($props);
        my ( $formWeb, $formTopic ) =
          $session->normalizeWebTopicName( $topicObject->web, $form );
        my $formLabelContent = '&nbsp;'
          . (
            $session->topicExists( $formWeb, $formTopic )
            ? '[[' . $formWeb . '.' . $formTopic . '][' . $form . ']]'
            : $form
          );
        $formList .= CGI::label( { for => $formElemId }, $formLabelContent );
    }
    $page =~ s/%FORMLIST%/$formList/go;

    my $parent = $q->param('topicparent') || '';
    $page =~ s/%TOPICPARENT%/$parent/go;

    my $redirectTo = $q->param('redirectto') || '';
    $page =~ s/%REDIRECTTO%/$redirectTo/go;

    my $text = '';
    $text = "<input type=\"hidden\" name=\"action\" value=\"$editaction\" />"
      if $editaction;
    $page =~ s/%EDITACTION%/$text/go;

    $page = $topicObject->expandMacros($page);
    $page = $topicObject->renderTML($page);

    $text = CGI::hidden( -name => 'text', -value => $q->param('text') );
    $page =~ s/%TEXT%/$text/go;

    return $page;
}
1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
