# See bottom of file for license and copyright information

package Foswiki::UI::Preview;

use strict;
use warnings;
use Error qw( :try );

use Foswiki                ();
use Foswiki::UI::Save      ();
use Foswiki::OopsException ();

use Assert;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

sub preview {
    my $session = shift;

    my $query = $session->{request};
    my $web   = $session->{webName};
    my $topic = $session->{topicName};
    my $user  = $session->{user};

    if ( $session->{invalidTopic} ) {
        throw Foswiki::OopsException(
            'accessdenied',
            status => 404,
            def    => 'invalid_topic_name',
            web    => $web,
            topic  => $topic,
            params => [ $session->{invalidTopic} ]
        );
    }

    # SMELL: it's probably not good to do this here, because a preview may
    # give enough time for a new topic with the same name to be created.
    # It would be better to do it only on an actual save.

    $topic = Foswiki::UI::Save::expandAUTOINC( $session, $web, $topic );

    my $topicObject = Foswiki::Meta->new( $session, $web, $topic );

    my ( $saveOpts, $merged ) =
      Foswiki::UI::Save::buildNewTopic( $session, $topicObject, 'preview' );

    # Note: param(formtemplate) has already been decoded by buildNewTopic
    # so the $meta entry reflects if it was used.
    # get form fields to pass on
    my $formFields = '';
    my $form = $topicObject->get('FORM') || '';
    my $formName;
    if ($form) {
        $formName = $form->{name};    # used later on as well
        require Foswiki::Form;
        my $formDef = new Foswiki::Form( $session, $web, $formName );
        unless ($formDef) {
            throw Foswiki::OopsException(
                'attention',
                def    => 'no_form_def',
                web    => $session->{webName},
                topic  => $session->{topicName},
                params => [ $web, $formName ]
            );
        }
        $formFields = $formDef->renderHidden( $topicObject, 0 );
    }

    my $text = $topicObject->text() || '';
    $session->{plugins}
      ->dispatch( 'afterEditHandler', $text, $topic, $web, $topicObject );

    # Load the template for the view
    my $content  = $text;
    my $template = $session->{prefs}->getPreference('VIEW_TEMPLATE');
    if ($template) {
        my $vt = $session->templates->readTemplate( $template, no_oops => 1 );
        if ($vt) {

            # We can't just use a VIEW_TEMPLATE directly because it
            # describes an entire HTML page. But the bit we
            # need is defined by the %TMPL:DEF{"content"}% within it, so
            # we can just pull it out and instantiate that small bit.

            $content = $session->templates->expandTemplate('content');
            $content =~ s/%TEXT%/$text/g;
        }
    }

    my $tmpl = $session->templates->readTemplate('preview');

    if ( $saveOpts->{minor} ) {
        $tmpl =~ s/%DONTNOTIFYCHECKBOX%/checked="checked"/g;
    }
    else {
        $tmpl =~ s/%DONTNOTIFYCHECKBOX%//g;
    }
    if ( $saveOpts->{forcenewrevision} ) {
        $tmpl =~ s/%FORCENEWREVISIONCHECKBOX%/checked="checked"/g;
    }
    else {
        $tmpl =~ s/%FORCENEWREVISIONCHECKBOX%//g;
    }
    my $saveCmd = Foswiki::entityEncode( $query->param('cmd') || '' );
    $tmpl =~ s/%CMD%/$saveCmd/g;

    my $redirectTo = Foswiki::entityEncode( $query->param('redirectto') || '' );
    $tmpl =~ s/%REDIRECTTO%/$redirectTo/g;

    $formName ||= '';
    $tmpl =~ s/%FORMTEMPLATE%/$formName/g;

    my $parent = $topicObject->get('TOPICPARENT');
    $parent = $parent->{name} if ($parent);
    $parent ||= '';
    $tmpl =~ s/%TOPICPARENT%/$parent/g;

    my $displayText = $content;
    $displayText = $topicObject->expandMacros($displayText);
    $displayText = $topicObject->renderTML($displayText);

    # Disable links and inputs in the text
    # SMELL: This will break on <a name="blah />
    # XXX - Use a real HTML parser like HTML::Parser
    $displayText =~ s#(<a\s[^>]*>)(.*?)(</a>)#_disableLink($1, $2, $3)#gies
      ;    # Disables base relative links
    $displayText =~ s#(<a\s[^>]*>)(.*?)(</a>)#_reTargetLink($1, $2, $3)#gies
      ;    # Retargets remaining links
    $displayText =~ s/<(input|button|textarea) /<$1 disabled="disabled" /gis;
    $displayText =~ s(</?form(|\s.*?)>)()gis;
    $displayText =~ s/(<[^>]*\bon[A-Za-z]+=)('[^']*'|"[^"]*")/$1''/gis;

    # let templates know the context so they can act on it
    $session->enterContext( 'preview', 1 );

    # note: preventing linkage in rendered form can only happen in templates
    # see formtables.tmpl

    my $originalrev =
      Foswiki::entityEncode( $query->param('originalrev') || '' )
      ;    # rev edit started on

    #ASSERT($originalrev ne '%ORIGINALREV%') if DEBUG;
    $tmpl =~ s/%ORIGINALREV%/$originalrev/g;

    my $templatetopic =
      Foswiki::entityEncode( $query->param('templatetopic') || '' );

    #ASSERT($templatetopic ne '%TEMPLATETOPIC%') if DEBUG;
    $tmpl =~ s/%TEMPLATETOPIC%/$templatetopic/g;

    #this one's worrying, its special, and not set much at all
    #$tmpl =~ s/%SETTINGSTOPIC%/$settingstopic/g;
    my $newtopic = Foswiki::entityEncode( $query->param('newtopic') || '' );

    #ASSERT($newtopic ne '%NEWTOPIC%') if DEBUG;
    $tmpl =~ s/%NEWTOPIC%/$newtopic/g;

# CAUTION: Once expandMacros executes, any template tokens that are expanded
# inside a %ENCODE will be corrupted.  So do token substitution before this point.
    $tmpl = $topicObject->expandMacros($tmpl);
    $tmpl = $topicObject->renderTML($tmpl);
    $tmpl =~ s/%TEXT%/$displayText/g;

    # write the hidden form fields
    $tmpl =~ s/%FORMFIELDS%/$formFields/g;

    # SMELL: this should be done using CGI::hidden
    $text = Foswiki::entityEncode( $text, "\n" );

    $tmpl =~ s/%HIDDENTEXT%/$text/g;

    $tmpl =~ s/<\/?(nop|noautolink)\/?>//gis;

###
    $session->writeCompletePage($tmpl);
}

sub _reTargetLink {
    my ( $one, $two, $three ) = @_;

    unless ( $one =~ m/foswikiEmulatedLink/ ) {
        if ( $one =~ m/\btarget=/i ) {
            $one =~
s/\btarget=(?:(?: \'[^\']*\' | \"[^\"]*\" | [^\'\"\s]+ )+)(.*?>)/target="_blank"$1/xi;
        }
        else {
            $one =~ s/\bhref=/target="_blank" href=/;
        }
    }
    return $one . $two . $three;
}

sub _disableLink {
    my ( $one, $two, $three ) = @_;

    if ( $one =~ m/\bhref=['"][#?]/i ) {    #Anchors or relative links
        $one   = "<span class=\"foswikiEmulatedLink\">";
        $three = "</span>";
    }
    return $one . $two . $three;
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
