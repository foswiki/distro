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
use Foswiki::Func ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

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
    my $fqFormName;
    unless ($formName) {
        if ( not defined $topicObject->getLoadedRev() ) {
            $topicObject->load();
        }
        my $form = $topicObject->get('FORM');
        $formName = $form->{name} if $form;
    }
    if ( not $formName ) {
        $formName   = 'none';
        $fqFormName = $formName;
    }
    else {
        $fqFormName = _normalizeName( $topicObject, $formName );
    }

    my @webforms = Foswiki::Form::getAvailableForms($topicObject);
    unshift( @webforms, 'none' );

    my $formList      = '';
    my $formElemCount = 0;
    foreach my $webform (@webforms) {
        my $fqwebform = _normalizeName( $topicObject, $webform );

        $formElemCount++;
        $formList .= CGI::br() if ($formList);
        my $formElemId = 'formtemplateelem' . $formElemCount;
        my $props      = {
            type  => 'radio',
            name  => 'formtemplate',
            id    => $formElemId,
            value => $webform
        };
        $props->{checked} = 'checked' if $fqwebform eq $fqFormName;
        $formList .= CGI::input($props);
        my $formLabelContent = '&nbsp;'
          . (
            Foswiki::Func::topicExists(
                Foswiki::Func::normalizeWebTopicName(
                    $topicObject->web(), $fqwebform
                )
              )
            ? "[[$fqwebform][$webform]]"
            : $webform
          );
        $formList .= CGI::label( { for => $formElemId }, $formLabelContent );
    }
    $page =~ s/%FORMLIST%/$formList/g;

    my $parent = $q->param('topicparent') || '';
    $parent =
      Foswiki::Sandbox::untaint( $parent,
        \&Foswiki::Sandbox::validateTopicName )
      if $parent;
    $page =~ s/%TOPICPARENT%/$parent/g;

    my $redirectTo = $session->redirectto() || '';
    $page =~ s/%REDIRECTTO%/$redirectTo/g;

    my $text = '';
    $text = "<input type=\"hidden\" name=\"action\" value=\"$editaction\" />"
      if $editaction;
    $page =~ s/%EDITACTION%/$text/g;

    $page = $topicObject->expandMacros($page);
    $page = $topicObject->renderTML($page);

    my $val = scalar( $q->param('text') ) || '';
    $val =~ s/\"/&quot;/g;
    $text = "<input type=\"hidden\" name=\"text\" value=\"$val\" />";
    $page =~ s/%TEXT%/$text/g;

    return $page;
}

sub _normalizeName {
    my ( $topicObject, $name ) = @_;

    if ($name) {
        if ( $name ne 'none' ) {
            $name = join(
                '.',
                Foswiki::Func::normalizeWebTopicName(
                    $topicObject->web(), $name
                )
            );
        }
    }
    else {
        $name = 'none';
    }

    return $name;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2011 Foswiki Contributors. Foswiki Contributors
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
