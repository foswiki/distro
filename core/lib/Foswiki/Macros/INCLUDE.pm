# See bottom of file for license and copyright information
package Foswiki;

use strict;
use warnings;

use Foswiki::Render;
use Foswiki::Func;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

# applyPatternToIncludedText( $text, $pattern ) -> $text
# Apply a pattern on included text to extract a subset
# Package-private; used by IncludeHandlers.
sub applyPatternToIncludedText {
    my ( $text, $pattern ) = @_;

    $pattern = Foswiki::Sandbox::untaint( $pattern, \&validatePattern );

    my $ok = 0;
    eval {

        # The eval acts as a try block in case there is anything evil in
        # the pattern.

        # The () ensures that $1 is defined if $pattern matches
        # but does not capture anything
        if ( $text =~ m/$pattern()/is ) {
            $text = $1;
        }
        else {

            # The pattern did not match, so return nothing
            $text = '';
        }
        $ok = 1;
    };
    $text = '' unless $ok;

    return $text;
}

# Replace web references in a topic. Called from forEachLine, applying to
# each non-verbatim and non-literal line.   The in_noautolink option is
# set by Foswiki::Render when processing a line inside a noautolink block.
sub _fixupIncludedTopic {
    my ( $text, $options ) = @_;

    my $fromWeb = $options->{web};

    unless ( $options->{Pref_NOAUTOLINK} || $options->{in_noautolink} ) {

        # 'TopicName' to 'Web.TopicName'
        $text =~ s{
              $Foswiki::Render::STARTWW
              (
               (:? $Foswiki::regex{wikiWordRegex})    # Wikiword
               (:?$Foswiki::regex{anchorRegex})?      # Optional anchor
              )
              $Foswiki::Render::ENDWW
           }
           {$fromWeb.$1}gx;

        # 'ACRONYM' to 'Web.ACRONYM' but only if the topic exists.
        $text =~ s{
              $Foswiki::Render::STARTWW
               ($Foswiki::regex{abbrevRegex})      # Acronym
               ($Foswiki::regex{anchorRegex})?     # Optional anchor
              $Foswiki::Render::ENDWW
           }
           {_fixAcronymLink($fromWeb,$1,$2)}gex;
    }

    # Handle explicit [[]] everywhere
    # '[[TopicName][...]]' to '[[Web.TopicName][...]]'
    $text =~ s/\[\[([^]]+)\](?:\[([^]]+)\])?\]/
      _fixIncludeLink( $fromWeb, $1, $2 )/geo;

    return $text;
}

# Acronyms only link if the topic exists.
sub _fixAcronymLink {

    my $anchor = $_[2] || '';

    if ( Foswiki::Func::topicExists( $_[0], $_[1] ) ) {
        return "$_[0].$_[1]$anchor";
    }
    else {
        return "$_[1]$anchor";
    }
}

# Add a web reference to a [[...][...]] link in an included topic
sub _fixIncludeLink {
    my ( $web, $link, $label ) = @_;

    # Detect absolute and relative URLs and web-qualified wikinames
    if ( $link =~
m#^($Foswiki::regex{webNameRegex}\.|$Foswiki::regex{defaultWebNameRegex}\.|$Foswiki::regex{linkProtocolPattern}:|/)#
      )
    {
        if ($label) {
            return "[[$link][$label]]";
        }
        else {
            return "[[$link]]";
        }
    }
    elsif ( !$label ) {

        # Must be wikiword or spaced-out wikiword (or illegal link :-/)
        $label = $link;
    }

    # If link is only an anchor, leave it as is (Foswikitask:Item771)
    return "[[$link][$label]]" if $link =~ m/^#/;

    # Collapse a spaced out wikiword
    $link = ucfirst($link);
    $link =~ s/\s([[:alnum:]])/\U$1/g;

    if ( Foswiki::isValidTopicName( $link, 1 ) ) {
        return "[[$web.$link][$label]]";
    }
    else {
        # Just leave it alone,  not a valid topic, might be a Interwiki link.
        return "[[$link][$label]]";
    }
}

# generate an include warning
# SMELL: varying number of parameters idiotic to handle for customized $warn
sub _includeWarning {
    my $this    = shift;
    my $warn    = shift;
    my $message = shift;

    if ( $warn eq 'on' ) {
        return $this->inlineAlert( 'alerts', $message, @_ );
    }
    elsif ( isTrue($warn) ) {

        # different inlineAlerts need different argument counts
        my $argument = '';
        if ( $message eq 'topic_not_found' ) {
            my ( $web, $topic ) = @_;
            $argument = "$web.$topic";
        }
        else {
            $argument = shift;
        }
        $warn =~ s/\$topic/$argument/g if $argument;
        return Foswiki::expandStandardEscapes($warn);
    }    # else fail silently
    return '';
}

sub _includeProtocol {
    my ( $this, $handler, $control, $params ) = @_;

    eval 'use Foswiki::IncludeHandlers::' . $handler . ' ()';
    if ($@) {
        return $this->_includeWarning( $control->{warn}, 'bad_include_path',
            "BROKEN $handler for " . $control->{_DEFAULT} );
    }
    else {
        $handler = 'Foswiki::IncludeHandlers::' . $handler;
        return $handler->INCLUDE( $this, $control, $params );
    }
}

sub _includeTopic {
    my ( $this, $includingTopicObject, $control, $params ) = @_;

    my $includedWeb;
    my $includedTopic = $control->{_DEFAULT};
    $includedTopic =~ s/\.txt$//;    # strip optional (undocumented) .txt

    ( $includedWeb, $includedTopic ) =
      $this->normalizeWebTopicName( $includingTopicObject->web,
        $includedTopic );

    if ( !Foswiki::isValidTopicName( $includedTopic, 1 ) ) {
        return $this->_includeWarning(
            $control->{warn}, 'bad_include_path', $control->{_DEFAULT}
          ),
          'bad_include_path';
    }

    # See Codev.FailedIncludeWarning for the history.
    unless ( $this->{store}->topicExists( $includedWeb, $includedTopic ) ) {
        return _includeWarning( $this, $control->{warn}, 'topic_not_found',
            $includedWeb, $includedTopic ),
          'topic_not_found';
    }

    # prevent recursive includes. Note that the inclusion of a topic into
    # itself is not blocked; however subsequent attempts to include the
    # topic will fail. There is a hard block of 99 on any recursive include.
    my $key = $includingTopicObject->web . '.' . $includingTopicObject->topic;
    my $count = grep( $key, keys %{ $this->{_INCLUDES} } );
    $key .= $control->{_sArgs};
    if ( $this->{_INCLUDES}->{$key} || $count > 99 ) {
        return $this->_includeWarning( $control->{warn}, 'already_included',
            "$includedWeb.$includedTopic", '' ),
          'already_included';
    }

    # Push the topic context to the included topic, so we can create
    # local (SESSION) macro definitions without polluting the including
    # topic namespace.
    $this->{prefs}->pushTopicContext( $this->{webName}, $this->{topicName} );

    my $includedTopicObject =
      Foswiki::Meta->load( $this, $includedWeb, $includedTopic,
        $control->{rev} );
    unless ( $includedTopicObject->haveAccess('VIEW') ) {
        $this->{prefs}->popTopicContext();    # Undo the push if access denied
        if ( isTrue( $control->{warn} ) ) {
            return $this->_includeWarning( $control->{warn}, 'access_denied',
                "$includedWeb.$includedTopic", '' ),
              'access_denied';
        }                                     # else fail silently
        return '', 'access_denied';
    }
    $this->{_INCLUDES}->{$key} = 1;

    my $memWeb   = $this->{prefs}->getPreference('INCLUDINGWEB');
    my $memTopic = $this->{prefs}->getPreference('INCLUDINGTOPIC');

    my $text       = '';
    my $error      = '';
    my $verbatim   = {};
    my $dirtyAreas = {};
    try {

        # Copy params into session level preferences. That way finalisation
        # will apply to them. These preferences will be popped when the topic
        # context is restored after the include.
        $this->{prefs}->setSessionPreferences(%$params);

        # Set preferences that finalisation does *not* apply to
        $this->{prefs}->setInternalPreferences(
            INCLUDINGWEB   => $includingTopicObject->web,
            INCLUDINGTOPIC => $includingTopicObject->topic
        );

        $text = $includedTopicObject->text;

        # Simplify leading, and remove trailing, newlines. If we don't remove
        # trailing, it becomes impossible to %INCLUDE a topic into a table.
        $text =~ s/^[\r\n]+/\n/;
        $text =~ s/[\r\n]+$//;

        # remove everything before and after the default include block unless
        # a section is explicitly defined
        if ( !$control->{section} ) {
            $text =~ s/.*?%STARTINCLUDE%//s;
            $text =~ s/%(?:END|STOP)INCLUDE%.*//s;
        }

        # prevent dirty areas in included topics from being parsed
        $text = takeOutBlocks( $text, 'dirtyarea', $dirtyAreas )
          if $Foswiki::cfg{Cache}{Enabled};

        # handle sections
        my ( $ntext, $sections ) = Foswiki::parseSections($text);

        my $interesting = ( defined $control->{section} );
        if ( $interesting || scalar(@$sections) ) {

            # Rebuild the text from the interesting sections
            $text = '';
            foreach my $s (@$sections) {
                my $process_this_section;
                if (   $control->{section}
                    && $s->{type} eq 'section'
                    && $s->{name} eq $control->{section} )
                {
                    $interesting          = 1;
                    $process_this_section = 1;
                }
                elsif ( $s->{type} eq 'include' && !$control->{section} ) {
                    $interesting          = 1;
                    $process_this_section = 1;
                }

                if ($process_this_section) {
                    $text .=
                      substr( $ntext, $s->{start}, $s->{end} - $s->{start} );

                    my %defaults;
                    foreach my $key ( keys(%$s) ) {

    #remove the section parsing specific keys (probably should add a _ to them?)
                        next
                          if ( ( $key eq 'name' )
                            || ( $key eq 'type' )
                            || ( $key eq 'start' )
                            || ( $key eq 'stop' ) );

#don't over-ride existing INCLUDE params and settings (so that nested INCLUDEs pass on their values as they used to), and to avoid FINALISE issues
                        next if ( $this->{prefs}->getPreference($key) );
                        $defaults{$key} = $s->{$key};
                    }
                    $this->{prefs}->setSessionPreferences(%defaults);

                    #we only process the first named section
                    last if ( $control->{section} );
                }
            }
        }

        if ( $interesting and ( length($text) eq 0 ) ) {
            $text =
              _includeWarning( $this, $control->{warn},
                'topic_section_not_found', $includedWeb, $includedTopic,
                $control->{section} );
            $error = 'topic_section_not_found';
        }
        else {

            # If there were no interesting sections, restore the whole text
            $text = $ntext unless $interesting;

            $text = applyPatternToIncludedText( $text, $control->{pattern} )
              if ( $control->{pattern} );

            # Do not show TOC in included topic if TOC_HIDE_IF_INCLUDED
            # preference has been set
            if ( isTrue( $this->{prefs}->getPreference('TOC_HIDE_IF_INCLUDED') )
              )
            {
                $text =~ s/%TOC(?:{(.*?)})?%//g;
            }

            $this->innerExpandMacros( \$text, $includedTopicObject );

        # Item9569: remove verbatim blocks from text passed to commonTagsHandler
            $text = takeOutBlocks( $text, 'verbatim', $verbatim );

            # 4th parameter tells plugin that its called for an included file
            $this->{plugins}
              ->dispatch( 'commonTagsHandler', $text, $includedTopic,
                $includedWeb, 1, $includedTopicObject );
            putBackBlocks( \$text, $verbatim, 'verbatim' );

            # We have to expand tags again, because a plugin may have inserted
            # additional tags.
            $this->innerExpandMacros( \$text, $includedTopicObject );

            # If needed, fix all 'TopicNames' to 'Web.TopicNames' to get the
            # right context so that links continue to work properly
            if ( $includedWeb ne $includingTopicObject->web ) {
                my $noautolink = Foswiki::isTrue(
                    $this->{prefs}->getPreference('NOAUTOLINK') );

          # pre and noautolink parms are used by Foswiki::Render to determine
          # whether or not to process those blocks.
          # Pref_NOAUTOLINK passes the preference setting to _fixupIncludedTopic
                $text = $this->renderer->forEachLine(
                    $text,
                    \&_fixupIncludedTopic,
                    {
                        web             => $includedWeb,
                        pre             => 1,
                        noautolink      => 1,
                        Pref_NOAUTOLINK => $noautolink,
                    }
                );

                # handle tags again because of plugin hook
                innerExpandMacros( $this, \$text, $includedTopicObject );
            }
        }
    }
    finally {

        # always restore the context, even in the event of an error
        delete $this->{_INCLUDES}->{$key};

        $this->{prefs}->setInternalPreferences(
            INCLUDINGWEB   => $memWeb,
            INCLUDINGTOPIC => $memTopic
        );

        # restoring dirty areas
        putBackBlocks( \$text, $dirtyAreas, 'dirtyarea' )
          if $Foswiki::cfg{Cache}{Enabled};

        ( $this->{webName}, $this->{topicName} ) =
          $this->{prefs}->popTopicContext();
    };

    return ( $text, $error );
}

# Processes a specific instance %<nop>INCLUDE{...}% syntax.
# Returns the text to be inserted in place of the INCLUDE command.
# $includingTopicObject should be for the immediate parent topic in the
# include hierarchy. Works for both URLs and absolute server paths.
sub INCLUDE {
    my ( $this, $params, $includingTopicObject ) = @_;

    # remember args for the key before mangling the params
    my $args = $params->stringify();

    # Remove params, so they don't get expanded in the included page
    my %control;
    for my $p (qw(_DEFAULT pattern rev section raw warn)) {
        $control{$p} = $params->remove($p);
    }
    $control{_sArgs} = $args;

    $control{warn} ||= $this->{prefs}->getPreference('INCLUDEWARNING');

    my $text;

    # make sure we have something to include. If we don't do this, then
    # normalizeWebTopicName will default to WebHome. TWikibug:Item2209.
    unless ( $control{_DEFAULT} ) {
        $text =
          $this->_includeWarning( $control{warn}, 'bad_include_path', '' );
    }

    # Filter out '..' from path to prevent includes of '../../file'
    elsif ( $Foswiki::cfg{DenyDotDotInclude} && $control{_DEFAULT} =~ m/\.\./ )
    {
        $text =
          $this->_includeWarning( $control{warn}, 'bad_include_path',
            $control{_DEFAULT} );
    }

    else {

        # no sense in considering an empty string as an unfindable section
        delete $control{section}
          if ( defined( $control{section} ) && $control{section} eq '' );
        $control{raw} ||= '';
        $control{inWeb}   = $includingTopicObject->web;
        $control{inTopic} = $includingTopicObject->topic;

        # Protocol links e.g. http:, https:, doc:
        if ( $control{_DEFAULT} =~ m/^([a-z]+):/ ) {
            $text = $this->_includeProtocol( $1, \%control, $params );
        }
        else {
            my @topics = split( /,\s*/, $control{_DEFAULT} );
            my $error;
            foreach my $t (@topics) {
                $control{_DEFAULT} = $t;
                ( $text, $error ) =
                  $this->_includeTopic( $includingTopicObject, \%control,
                    $params );
                last if ( $error eq '' );
            }
        }
    }

    # Apply any heading offset
    my $hoff = $params->{headingoffset};
    if ( $hoff && $hoff =~ m/^([-+]?\d+)$/ && $1 != 0 ) {
        my ( $off, $noff ) = ( 0 + $1, 0 - $1 );
        $text = "<ho off=\"$off\"/>\n$text\n<ho off=\"$noff\">";
    }

    return $text;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2009 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.
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
