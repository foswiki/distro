# See bottom of file for license and copyright information

package Foswiki::UI::Preview;

use strict;
use Error qw( :try );

require Foswiki;
require Foswiki::UI::Save;
require Foswiki::OopsException;

require Assert;

sub preview {
    my $session = shift;

    my $query = $session->{request};
    my $web   = $session->{webName};
    my $topic = $session->{topicName};
    my $user  = $session->{user};

    my ( $meta, $text, $saveOpts, $merged ) =
      Foswiki::UI::Save::buildNewTopic( $session, 'preview' );

    # Note: param(formtemplate) has already been decoded by buildNewTopic
    # so the $meta entry reflects if it was used.
    my $formFields = '';
    my $form = $meta->get('FORM') || '';
    if ($form) {
        $form = $form->{name};    # used later on as well
        require Foswiki::Form;
        my $formDef = new Foswiki::Form( $session, $web, $form );
        unless ($formDef) {
            throw Foswiki::OopsException(
                'attention',
                def    => 'no_form_def',
                web    => $session->{webName},
                topic  => $session->{topicName},
                params => [ $web, $form ]
            );
        }
        $formFields = $formDef->renderHidden( $meta, 0 );
    }

    $session->{plugins}->dispatch( 'afterEditHandler', $text, $topic, $web );

    my $skin = $session->getSkin();
    my $template =
      $session->{prefs}->getPreferencesValue('VIEW_TEMPLATE')
      || 'preview';
    my $tmpl = $session->templates->readTemplate( $template, $skin );

    # if a VIEW_TEMPLATE is set, but does not exist or is not readable,
    # revert to 'preview' template (same code as View.pm)
    if ( !$tmpl && $template ne 'preview' ) {
        $tmpl = $session->templates->readTemplate( 'preview', $skin );
    }

    if ( $saveOpts->{minor} ) {
        $tmpl =~ s/%DONTNOTIFYCHECKBOX%/checked="checked"/go;
    }
    else {
        $tmpl =~ s/%DONTNOTIFYCHECKBOX%//go;
    }
    if ( $saveOpts->{forcenewrevision} ) {
        $tmpl =~ s/%FORCENEWREVISIONCHECKBOX%/checked="checked"/go;
    }
    else {
        $tmpl =~ s/%FORCENEWREVISIONCHECKBOX%//go;
    }
    my $saveCmd = $query->param('cmd') || '';
    $tmpl =~ s/%CMD%/$saveCmd/go;

    my $redirectTo = $query->param('redirectto') || '';
    $tmpl =~ s/%REDIRECTTO%/$redirectTo/go;

    $tmpl =~ s/%FORMTEMPLATE%/$form/g;

    my $parent = $meta->get('TOPICPARENT');
    $parent = $parent->{name} if ($parent);
    $parent ||= '';
    $tmpl =~ s/%TOPICPARENT%/$parent/g;

    $session->enterContext( 'can_render_meta', $meta );

    my $dispText = $text;
    $dispText = $session->handleCommonTags( $dispText, $web, $topic, $meta );
    $dispText =
      $session->renderer->getRenderedVersion( $dispText, $web, $topic );

    # Disable links and inputs in the text
    $dispText =~
      s#<a\s[^>]*>(.*?)</a>#<span class="twikiEmulatedLink">$1</span>#gis;
    $dispText =~ s/<(input|button|textarea) /<$1 disabled="disabled" /gis;
    $dispText =~ s(</?form(|\s.*?)>)()gis;
    $dispText =~ s/(<[^>]*\bon[A-Za-z]+=)('[^']*'|"[^"]*")/$1''/gis;

    $tmpl = $session->handleCommonTags( $tmpl, $web, $topic, $meta );
    $tmpl = $session->renderer->getRenderedVersion( $tmpl, $web, $topic );
    $tmpl =~ s/%TEXT%/$dispText/go;
    $tmpl =~ s/%FORMFIELDS%/$formFields/go;

    # SMELL: this should be done using CGI::hidden
    $text = Foswiki::entityEncode( $text, "\n" );

    $tmpl =~ s/%HIDDENTEXT%/$text/go;

    $tmpl =~ s/<\/?(nop|noautolink)\/?>//gis;

 #I don't know _where_ these should be done, so I'll do them as late as possible
    my $originalrev = $query->param('originalrev');    # rev edit started on
         #ASSERT($originalrev ne '%ORIGINALREV%') if DEBUG;
    $tmpl =~ s/%ORIGINALREV%/$originalrev/go;
    my $templatetopic = $query->param('templatetopic');

    #ASSERT($templatetopic ne '%TEMPLATETOPIC%') if DEBUG;
    $tmpl =~ s/%TEMPLATETOPIC%/$templatetopic/go;

    #this one's worrying, its special, and not set much at all
    #$tmpl =~ s/%SETTINGSTOPIC%/$settingstopic/go;
    my $newtopic = $query->param('newtopic');

    #ASSERT($newtopic ne '%NEWTOPIC%') if DEBUG;
    $tmpl =~ s/%NEWTOPIC%/$newtopic/go;

    $session->writeCompletePage($tmpl);
}

1;
__DATA__
# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 Foswiki Contributors. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
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
#
# As per the GPL, removal of this notice is prohibited.
