# See bottom of file for license and copyright information
#
# This version is specific to Foswiki::Plugins::VERSION > 1.026

use strict;
use warnings;
use Assert;
use Error ':try';

use Foswiki;
use Foswiki::Plugins;
use Foswiki::Store;

use CGI qw( -any );

package Foswiki::Plugins::CommentPlugin::Comment;

# PUBLIC STATIC convert COMMENT statements to form prompts
sub prompt {
    my ( $attrs, $web, $topic, $disabled ) = @_;

    my $type = $attrs->remove('type')
      || $attrs->remove('mode')
        || Foswiki::Func::getPreferencesValue('COMMENTPLUGIN_DEFAULT_TYPE')
          || 'above';
    my $silent            = $attrs->remove('nonotify');
    my $location          = $attrs->remove('location');
    my $remove            = $attrs->remove('remove');
    my $nopost            = $attrs->remove('nopost');
    my $default           = $attrs->remove('default');
    my $attrtemplatetopic = $attrs->remove('templatetopic') || '';
    my $templatetopic     = _getTemplateLocation( $attrtemplatetopic, $web );

    my $message = $default || '';
    $message = $disabled if $disabled;

    # clean off whitespace
    $type =~ s/\s+//;

    # Expand the template in the context of the web where the comment
    # box is (not the target of the comment!)
    my $input = _getTemplate( "PROMPT:$type", $web, $topic, $templatetopic )
      || '';
    return $input if $input =~ m/^%RED%/so;

    # Expand special attributes as required
    $input =~ s/%([a-z]\w+)\|(.*?)%/_expandPromptParams($1, $2, $attrs)/ieg;

    # Build the endpoint before we munge the web and topic
    my $endPoint = "$web.$topic";

    # see if this comment is targeted at a different topic, and
    # change the url if it is.
    my $anchor = undef;
    my $target = $attrs->remove('target');
    if ($target) {

        # extract web and anchor
        if ( $target =~ s/^(\w+)\.// ) {
            $web = $1;
        }
        if ( $target =~ s/(#\w+)$// ) {
            $anchor = $1;
        }
        if ( $target ne '' ) {
            $topic = $target;
        }
    }

    # See if a save url has been defined in the template
    my $url = Foswiki::Func::expandTemplate('save_url');

    # Default it to a rest url if not
    $url ||= Foswiki::Func::getScriptUrl('CommentPlugin', 'comment', 'rest' );

    $url = '' if $disabled;

    my $noform = $attrs->remove('noform') || '';
    if ( $input !~ m/^%RED%/ ) {
        $input =~ s/%DISABLED%/$disabled ? 'disabled' : '' /ge;
        $input =~ s/%MESSAGE%/$message/g;
        my $idx = $attrs->{comment_index};

        unless( $disabled ) {
            my $hiddenFields = "";
            $hiddenFields .=
              CGI::hidden( -name => 'topic', -value => "$web.$topic");

            $hiddenFields .=
              CGI::hidden( -name => 'comment_action', -value => 'save' );

            $hiddenFields .=
              CGI::hidden( -name => 'endPoint', -value => $endPoint );

            $hiddenFields .=
              CGI::hidden( -name => 'comment_type', -value => $type );

            if ( defined($silent) ) {
                $hiddenFields .=
                  CGI::hidden( -name => 'comment_nonotify', value => 1 );
            }
            if ($templatetopic) {
                $hiddenFields .= 
                  CGI::hidden(
                      -name  => 'comment_templatetopic',
                      -value => $templatetopic
                     );
            }
            if ($location) {
                $hiddenFields .=
                  CGI::hidden(
                      -name  => 'comment_location',
                      -value => $location
                     );
            }
            elsif ($anchor) {
                $hiddenFields .=
                  CGI::hidden( -name => 'comment_anchor', -value => $anchor );
            }
            else {
                $hiddenFields .=
                  CGI::hidden( -name => 'comment_index', -value => $idx );
            }
            if ($nopost) {
                $hiddenFields .=
                  CGI::hidden( -name => 'comment_nopost', -value => $nopost );
            }
            if ($remove) {
                $hiddenFields .=
                  CGI::hidden( -name => 'comment_remove', -value => $idx );
            }
            $input .= $hiddenFields;
        }

        # SMELL: would have been more elegant to split this into
        # FORM:head:type and FORM:tail:type. Too late now :-(
        my $form =
          _getTemplate( "FORM:$type", $topic, $web, $templatetopic, 'off' );

        if ( $noform || $form) {
            if ($form) {
                $form =~ s/%COMMENTPROMPT%/$input/;
                $input = $form;
            } else {
                $input = "NOFORM $form $input";
            }
        } else {
            $input = CGI::start_form(
                -name   => $type . $idx,
                -id     => $type . $idx,
                -action => $url,
                -method => 'post'
               )
              . $input
                . CGI::end_form();
        }
    }
    return $input;
}

=pod

Parses a templatetopic attribute and returns a "Web.Topic" string.

=cut

sub _getTemplateLocation {
    my ( $attrtemplatetopic, $web ) = @_;

    my $templatetopic = '';
    my $templateweb = $web || '';
    if ($attrtemplatetopic) {
        my ( $templocweb, $temploctopic ) =
          Foswiki::Func::normalizeWebTopicName( $templateweb,
                                                $attrtemplatetopic );
        $templatetopic = "$templocweb.$temploctopic";
    }
    return $templatetopic;
}

# PRIVATE get the given template and do standard expansions
sub _getTemplate {
    my ( $name, $topic, $web, $templatetopic, $warn ) = @_;

    $warn ||= '';

    # Get the templates.
    my $templateFile =
      $templatetopic
        || Foswiki::Func::getPreferencesValue('COMMENTPLUGIN_TEMPLATES')
          || 'comments';

    my $templates = Foswiki::Func::loadTemplate($templateFile);
    if ( !$templates ) {
        Foswiki::Func::writeWarning(
            "Could not read template file '$templateFile'");
        return;
    }

    my $t = Foswiki::Func::expandTemplate($name);
    return "%RED%No such template def TMPL:DEF{$name}%ENDCOLOR%"
      unless ( defined($t) && $t ne '' ) || $warn eq 'off';

    return $t;
}

# PRIVATE expand special %param|default% parameters in PROMPT template
sub _expandPromptParams {
    my ( $name, $default, $attrs ) = @_;

    my $val = $attrs->{$name};
    return $val if defined($val);
    return $default;
}

# PUBLIC build new topic text
sub save {

    my ( $text, $web, $topic ) = @_;

    my $wikiName = Foswiki::Func::getWikiName();

    my $access = Foswiki::Func::checkAccessPermission(
        $Foswiki::cfg{Plugins}{CommentPlugin}{RequiredForSave} || 'change',
        $wikiName, $text, $topic, $web);
    unless ($access) {
        # user has no permission to change the topic
        throw Foswiki::OopsException(
            'accessdenied',
            def   => 'topic_access',
            web   => $web,
            topic => $topic
           );
    }

    my $query = Foswiki::Func::getCgiQuery();
    return unless $query;

    # The type of the comment dictates where in the target topic it
    # will be saved.
    my $type =
      $query->param('comment_type')
        || Foswiki::Func::getPreferencesValue('COMMENTPLUGIN_DEFAULT_TYPE')
          || 'above';

    # Indexing comment instances depends on macro expansion 
    # inside-out-left-right order and INCLUDE and SECTION expansion
    # being correctly handled. Only relevant if the comment is being
    # inserted relative to the instance, of course.
    my $index         = $query->param('comment_index') || 0;

    my $anchor        = $query->param('comment_anchor');
    my $location      = $query->param('comment_location');
    my $remove        = $query->param('comment_remove');
    my $nopost        = $query->param('comment_nopost');
    my $templatetopic = $query->param('comment_templatetopic') || '';

    my $output = _getTemplate( "OUTPUT:$type", $topic, $web, $templatetopic );
    if ( $output =~ m/^%RED%/ ) {
        die $output;
    }

    # Expand the template
    my $position = 'AFTER';
    if ( $output =~ s/%POS:(.*?)%//g ) {
        $position = $1;
    }

    # Expand common variables in the template, but don't expand other
    # tags.
    $output = Foswiki::Func::expandVariablesOnTopicCreation($output);

    $output = '' unless defined($output);

    # SMELL: Reverse the process that inserts meta-data just performed
    # by the Foswiki core, but this time without the support of the
    # methods in the core. Fortunately this will work even if there is
    # no embedded meta-data.
    my $premeta  = '';
    my $postmeta = '';
    my $inpost   = 0;
    my $innerText     = '';
    foreach my $line ( split( /\r?\n/, $text ) ) {
        if ( $line =~ /^%META:[A-Z]+{[^}]*}%$/ ) {
            if ($inpost) {
                $postmeta .= $line . "\n";
            }
            else {
                $premeta .= $line . "\n";
            }
        }
        else {
            $innerText .= $line . "\n";
            $inpost = 1;
        }
    }
    $text = $innerText;

    #make sure the anchor or location exits
    if ( defined($location) and not( $text =~ /(?<!location\=\")($location)/ ) )
    {
        undef $location;
    }
    if ( defined($anchor) and $text !~ /^$anchor\s*$/m ) {
        undef $anchor;
    }

    unless ($nopost) {
        if ( $position eq 'TOP' ) {
            $text = $output . $text;
        }
        elsif ( $position eq 'BOTTOM' ) {

            # Awkward newlines here, to avoid running into meta-data.
            # This should _not_ be a problem.
            $text =~ s/[\r\n]+$//;
            $text .= "\n" unless $output =~ m/^\n/s;
            $text .= $output;
            $text .= "\n" unless $text   =~ m/\n$/s;
        }
        else {
            if ($location) {
                if ( $position eq 'BEFORE' ) {
                    $text .= $output
                      unless (
                        $text =~ s/(?<!location\=\")($location)/$output$1/m );
                }
                else {    # AFTER
                    $text .= $output
                      unless (
                        $text =~ s/(?<!location\=\")($location)/$1$output/m );

                }
                $text .= "\n" unless $text =~ m/\n$/s;
            }
            elsif ($anchor) {

                # position relative to anchor
                if ( $position eq 'BEFORE' ) {
                    $text .= $output
                      unless ( $text =~ s/^($anchor\s)/$output$1/m );
                }
                else {    # AFTER
                    $text .= $output
                      unless ( $text =~ s/^($anchor\s)/$1$output/m );
                }
                $text .= "\n" unless $text =~ m/\n$/s;
            }
            else {

                # Position relative to index'th comment
                my $idx = 0;
                unless (
                    $text =~ s((%COMMENT({.*?})?%.*\n))
                          (&_nth($1,\$idx,$position,$index,$output))eg
                  )
                {

                    # If there was a problem adding relative to the comment,
                    # add to the end of the topic
                    $text .= $output;
                }
                $text .= "\n" unless $text =~ m/\n$/s;
            }
        }
    }

    if ( defined $remove ) {

        # remove the index'th comment box
        my $idx = 0;
        $text =~ s/(%COMMENT({.*?})?%)/_remove_nth($1,\$idx,$remove)/eg;
    }

    return $premeta . $text . $postmeta;
}

# PRIVATE embed output if this comment is the interesting one
sub _nth {
    my ( $tag, $pidx, $position, $index, $output ) = @_;

    if ( $$pidx == $index ) {
        if ( $position eq 'BEFORE' ) {
            $tag = $output . $tag;
        }
        else {    # AFTER
            $tag .= $output;
        }
    }
    $$pidx++;
    return $tag;
}

# PRIVATE remove the nth comment box
sub _remove_nth {
    my ( $tag, $pidx, $index ) = @_;
    $tag = '' if ( $$pidx == $index );
    $$pidx++;
    return $tag;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2004 Crawford Currie
Copyright (C) 2001-2006 TWiki Contributors.

Original author David Weller, reimplemented by Peter Masiar
and again by Crawford Currie

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
