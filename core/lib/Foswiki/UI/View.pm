# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::UI::View

UI delegate for view function

=cut

package Foswiki::UI::View;

use strict;
use warnings;
use integer;
use Monitor ();
use Assert;

use Foswiki                ();
use Foswiki::UI            ();
use Foswiki::Sandbox       ();
use Foswiki::OopsException ();
use Foswiki::Store         ();

=begin TML

---++ StaticMethod view( $session )

=view= command handler.
This method is designed to be
invoked via the =UI::run= method.

Generate a complete HTML page that represents the viewed topics.
The view is controlled by CGI parameters as follows:

| =rev= | topic revision to view |
| =section= | restrict view to a named section |
| =raw= | no format body text if set |
| =skin= | comma-separated list of skin(s) to use |
| =contenttype= | Allows you to specify an alternate content type |

=cut

sub view {
    my $session = shift;

    my $query = $session->{request};
    my $web   = $session->{webName};
    my $topic = $session->{topicName};

    my $cache = $session->{cache};
    my $cachedPage;
    $cachedPage = $cache->getPage( $web, $topic ) if $cache;
    if ($cachedPage) {
        print STDERR "found $web.$topic in cache\n"
          if $Foswiki::cfg{Cache}{Debug};
        Monitor::MARK("found page in cache");

        # render uncacheable areas
        my $text = $cachedPage->{text};
        $cache->renderDirtyAreas( \$text ) if $cachedPage->{isDirty};

        # set status
        my $status = $cachedPage->{status};
        if ( $status == 302 ) {
            $session->{response}->redirect( $cachedPage->{location} );
        }
        else {

            # See Item9941 to understand why do not set status when 200
            $session->{response}->status($status) unless $status eq 200;
        }

        # set headers
        $session->generateHTTPHeaders( 'view', $cachedPage->{contentType},
            $text, $cachedPage );

        # send it out
        $session->{response}->print($text);

        Monitor::MARK('Wrote HTML');
        $session->logEvent( 'view', $web . '.' . $topic, '(cached)' );

        return;
    }

    print STDERR "computing page for $web.$topic\n"
      if $Foswiki::cfg{Cache}{Debug};

    my $raw = $query->param('raw') || '';
    my $contentType = $query->param('contenttype');

    my $logEntry = '';

    # is this view indexable by search engines? Default yes.
    my $indexableView = 1;
    my $viewTemplate;

    Foswiki::UI::checkWebExists( $session, $web, 'view' );

    my $requestedRev;
    if ( defined $query->param('rev') ) {
        $requestedRev = Foswiki::Store::cleanUpRevID( $query->param('rev') );
        unless ($requestedRev) {

            # Invalid request, remove it from the query.
            $requestedRev = undef;
            $query->delete('rev');
        }
    }

    my $showLatest = !$requestedRev;
    my $showRev;

    my $topicObject;    # the stub of the topic we are to display
    my $text;           # the text to display, *not* necessarily
                        # the same as $topicObject->text
    my $revIt;          # Iterator over the range of available revs
    my $maxRev;

    if ( $session->topicExists( $web, $topic ) ) {

        # Load the most recent rev. This *should* be maxRev, but may
        # not say it is because the TOPICINFO could be up the spout
        $topicObject = Foswiki::Meta->load( $session, $web, $topic );
        Foswiki::UI::checkAccess( $session, 'VIEW', $topicObject );

        $revIt = $topicObject->getRevisionHistory();

        # The topic exists; it must have at least one rev
        ASSERT( $revIt->hasNext() ) if DEBUG;
        $maxRev = $revIt->next();

        if ( defined $requestedRev ) {

            # Is the requested rev id known?
            $revIt->reset();
            while ( $revIt->hasNext() ) {
                if ( $requestedRev eq $revIt->next() ) {
                    $showRev = $requestedRev;
                    last;
                }
            }

            # if rev was not found; show max rev
            $showRev = $maxRev unless ( defined $showRev );

            if ( $showRev ne $maxRev ) {

                # Load the old revision instead
                $topicObject =
                  Foswiki::Meta->load( $session, $web, $topic, $showRev );
                if ( !$topicObject->haveAccess('VIEW') ) {
                    throw Foswiki::AccessControlException( 'VIEW',
                        $session->{user}, $web, $topic,
                        $Foswiki::Meta::reason );
                }
                $logEntry .= 'r' . $requestedRev;
            }
        }
        else {
            $showRev = $maxRev;
        }

        if ( my $section = $query->param('section') ) {

            # Apply the 'section' selection (and maybe others in the
            # future as well).  $text is cleared unless a named section
            # matching the 'section' URL parameter is found.
            my ( $ntext, $sections ) =
              Foswiki::parseSections( $topicObject->text() );
            $text = '';    # in the beginning, there was ... NO section
          FINDSECTION:
            for my $s (@$sections) {
                if ( $s->{type} eq 'section' && $s->{name} eq $section ) {
                    $text =
                      substr( $ntext, $s->{start}, $s->{end} - $s->{start} );
                    last FINDSECTION;
                }
            }
        }
        else {

            # Otherwise take the full topic text
            $text = $topicObject->text();
        }
    }
    else {    # Topic does not exist yet
        $topicObject = Foswiki::Meta->new( $session, $web, $topic );
        $indexableView = 0;
        $session->enterContext('new_topic');
        $session->{response}->status(404);
        $showRev      = 1;
        $maxRev       = 0;
        $viewTemplate = 'TopicDoesNotExistView';
        $logEntry .= ' (not exist)';
        $raw = '';    # There is no raw view of a topic that doesn't exist
        $revIt = new Foswiki::ListIterator( [1] );
    }

    if ($raw) {
        $indexableView = 0;
        $logEntry .= ' raw=' . $raw;
        if ( $raw eq 'debug' || $raw eq 'all' ) {

            # We want to see the embedded store form
            $text = $topicObject->getEmbeddedStoreForm();
        }
    }

    $text = '' unless defined $text;

    $session->logEvent( 'view', $topicObject->web . '.' . $topicObject->topic,
        $logEntry );

    # Note; must enter all contexts before the template is read, as
    # TMPL:P is expanded on the fly in the template reader. :-(
    my ( $revTitle, $revArg ) = ( '', '' );
    $revIt->reset();
    if ( $showRev && $showRev != $revIt->next() ) {
        $session->enterContext('inactive');

        # disable edit of previous revisions
        $revTitle = '(r' . $showRev . ')';
        $revArg   = '&rev=' . $showRev;
    }

    my $template =
         $viewTemplate
      || $query->param('template')
      || $session->{prefs}->getPreference('VIEW_TEMPLATE')
      || 'view';

    # Always use default view template for raw=debug, raw=all and raw=on
    if ( $raw =~ /^(debug|all|on)$/ ) {
        $template = 'view';
    }

    my $tmpl = $session->templates->readTemplate( $template, no_oops => 1 );

    # If the VIEW_TEMPLATE (or other) doesn't exist, default to view.
    $tmpl = $session->templates->readTemplate('view') unless defined($tmpl);

    $tmpl =~ s/%REVTITLE%/$revTitle/g;
    $tmpl =~ s/%REVARG%/$revArg/g;

    if (   $indexableView
        && $Foswiki::cfg{AntiSpam}{RobotsAreWelcome}
        && !$query->param() )
    {

        # it's an indexable view type, there are no parameters
        # on the url, and robots are welcome. Remove the NOINDEX meta tag
        $tmpl =~ s/<meta name="robots"[^>]*>//goi;
    }

    # Show revisions around the one being displayed.
    $tmpl =~ s/%REVISIONS%/
      revisionsAround(
          $session, $topicObject, $requestedRev, $showRev, $maxRev)/e;

    ## SMELL: This is also used in Foswiki::_TOC. Could insert a tag in
    ## TOC and remove all those here, finding the parameters only once
    my @qparams = ();
    foreach my $name ( $query->param ) {
        next if ( $name eq 'keywords' );
        next if ( $name eq 'topic' );
        push @qparams, $name => $query->param($name);
    }
    $tmpl =~ s/%QUERYPARAMSTRING%/Foswiki::_make_params(1,@qparams)/geo;

    # extract header and footer from the template, if there is a
    # %TEXT% tag marking the split point. The topic text is inserted
    # in place of the %TEXT% tag. The text before this tag is inserted
    # as header, the text after is inserted as footer. If there is a
    # %STARTTEXT% tag present, the header text between %STARTTEXT% and
    # %TEXT is rendered together, as is the footer text between %TEXT%
    # and %ENDTEXT%, if present. This allows correct handling of Foswiki
    # markup in header or footer if those do require examination of the
    # topic text to work correctly (e.g., %TOC%).
    # Note: This feature is experimental and may be replaced by an
    # alternative solution not requiring additional tags.
    my ( $start, $end );

    # SMELL: unchecked implicit untaint of data that *may* be coming from
    # a topic (topics can be templates)
    if ( $tmpl =~ m/^(.*)%TEXT%(.*)$/s ) {
        my @starts = split( /%STARTTEXT%/, $1 );
        if ( $#starts > 0 ) {

            # we know that there is something before %STARTTEXT%
            $start = $starts[0];
            $text  = $starts[1] . $text;
        }
        else {
            $start = $1;
        }
        my @ends = split( /%ENDTEXT%/, $2 );
        if ( $#ends > 0 ) {

            # we know that there is something after %ENDTEXT%
            $text .= $ends[0];
            $end = $ends[1];
        }
        else {
            $end = $2;
        }
    }
    else {
        my @starts = split( /%STARTTEXT%/, $tmpl );
        if ( $#starts > 0 ) {

            # we know that there is something before %STARTTEXT%
            $start = $starts[0];
            $text  = $starts[1];
        }
        else {
            $start = $tmpl;
            $text  = '';
        }
        $end = '';
    }

    # If minimalist is set, images and anchors will be stripped from text
    my $minimalist = 0;
    if ($contentType) {
        $minimalist = ( $session->getSkin() =~ /\brss/ );
    }
    elsif ( $session->getSkin() =~ /\brss/ ) {
        $contentType = 'text/xml';
        $minimalist  = 1;
    }
    elsif ( $session->getSkin() =~ /\bxml/ ) {
        $contentType = 'text/xml';
        $minimalist  = 1;
    }
    elsif ( $raw eq 'text' || $raw eq 'all' ) {
        $contentType = 'text/plain';
    }
    else {
        $contentType = 'text/html';
    }
    $session->{prefs}->setSessionPreferences(
        MAXREV  => $maxRev,
        CURRREV => $showRev
    );

    # Set page generation mode to RSS if using an RSS skin
    $session->enterContext('rss') if $session->getSkin() =~ /\brss/;

    my $page;

    # Legacy: If the _only_ skin is 'text' it is used like this:
    # http://.../view/Codev/MyTopic?skin=text&contenttype=text/plain&raw=on
    # which shows the topic as plain text; useful for those who want
    # to download plain text for the topic. So when the skin is 'text'
    # we do _not_ want to create a textarea.
    # raw=on&skin=text is deprecated; use raw=text instead.
    Monitor::MARK('Ready to render');
    if (   $raw eq 'text'
        || $raw eq 'all'
        || ( $raw && $session->getSkin() eq 'text' ) )
    {

        # use raw text
        $page = $text;
    }
    else {
        my @args = ( $topicObject, $minimalist );

        $session->enterContext('header_text');
        $page = _prepare( $start, @args );
        $session->leaveContext('header_text');
        Monitor::MARK('Rendered header');

        if ($raw) {
            if ($text) {
                my $p = $session->{prefs};
                $page .= CGI::textarea(
                    -readonly => 'readonly',
                    -rows     => $p->getPreference('EDITBOXHEIGHT'),
                    -cols     => $p->getPreference('EDITBOXWIDTH'),
                    -style    => $p->getPreference('EDITBOXSTYLE'),
                    -class    => 'foswikiTextarea foswikiTextareaRawView',
                    -id       => 'topic',
                    -default  => $text
                );
            }
        }
        else {
            $session->enterContext('body_text');
            $page .= _prepare( $text, @args );
            $session->leaveContext('body_text');
        }

        Monitor::MARK('Rendered body');
        $session->enterContext('footer_text');
        $page .= _prepare( $end, @args );
        $session->leaveContext('footer_text');
        Monitor::MARK('Rendered footer');
    }

    # Output has to be done in one go, because if we generate the header and
    # then redirect because of some later constraint, some browsers fall over
    $session->writeCompletePage( $page, 'view', $contentType );
    Monitor::MARK('Wrote HTML');
}

sub _prepare {
    my ( $text, $topicObject, $minimalist ) = @_;

    $text = $topicObject->expandMacros($text);
    $text = $topicObject->renderTML($text);
    $text =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;

    if ($minimalist) {
        $text =~ s/<img [^>]*>//gi;    # remove image tags
        $text =~ s/<a [^>]*>//gi;      # remove anchor tags
        $text =~ s/<\/a>//gi;          # remove anchor tags
    }

    return $text;
}

=begin TML

---++ StaticMethod revisionsAround($session, $topicObject, $requestedRev, $showRev, $maxRev) -> $output

Calculate the revisions spanning the current one for display in the bottom
bar.

=cut

sub revisionsAround {
    my ( $session, $topicObject, $requestedRev, $showRev, $maxRev ) = @_;

    my $revsToShow = $Foswiki::cfg{NumberOfRevisions} + 1;

    # Soak up the revision iterator
    my $revIt          = $topicObject->getRevisionHistory();
    my @revs           = $revIt->all();
    my $maxRevDisjoint = 0;

    if ( $Foswiki::cfg{NumberOfRevisions} ) {

        # Locate the preferred rev in the array
        my $showIndex = $#revs;
        my $left      = 0;
        my $right     = $Foswiki::cfg{NumberOfRevisions};
        if ($requestedRev) {
            while ( $showIndex && $revs[$showIndex] != $showRev ) {
                $showIndex--;
            }
            $right = $showIndex + $Foswiki::cfg{NumberOfRevisions} - 1;
            $right = scalar(@revs) if $right > scalar(@revs);
            $left  = $right - $Foswiki::cfg{NumberOfRevisions};
            if ( $left < 0 ) {
                $left  = 0;
                $right = $Foswiki::cfg{NumberOfRevisions};
            }
        }
        splice( @revs, $right ) if ( $right < scalar(@revs) );
        splice( @revs, 0, $left );
        if ( $left > 0 ) {

            # Put the max rev back in at the front, and flag
            # special treatment
            $maxRevDisjoint = 1;
            unshift( @revs, $maxRev );
        }
    }

    my $output = '';
    my $r      = 0;
    while ( $r < scalar(@revs) ) {
        if ( $revs[$r] == $showRev ) {
            $output .= 'r' . $showRev;
        }
        else {
            $output .= CGI::a(
                {
                    href => $session->getScriptUrl(
                        0,                 'view',
                        $topicObject->web, $topicObject->topic,
                        rev => $revs[$r]
                    ),
                    rel => 'nofollow'
                },
                'r' . $revs[$r]
            );
        }
        if ( $r == 0 && $maxRevDisjoint ) {
            $output .= ' | ';
        }
        elsif ( $r < $#revs ) {
            $output .= '&nbsp;'
              . CGI::a(
                {
                    href => $session->getScriptUrl(
                        0, 'rdiff', $topicObject->web, $topicObject->topic,
                        rev1 => $revs[ $r + 1 ],
                        rev2 => $revs[$r]
                    ),
                    rel => 'nofollow'
                },
                '&lt;'
              ) . '&nbsp;';
        }
        $r++;
    }
    return $output;
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
and TWiki Contributors. All Rights Reserved.
Based on parts of Ward Cunninghams original Wiki and JosWiki.
Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
