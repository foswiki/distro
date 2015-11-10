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

use CGI ();

package Foswiki::Plugins::CommentPlugin::Comment;

sub _hidden {
    my ( $name, $value ) = @_;
    return "<input type=\"hidden\" name=\"$name\" value=\"$value\" />";
}

# PUBLIC STATIC convert COMMENT statements to form prompts
sub prompt {
    my ( $attrs, $web, $topic, $disabled ) = @_;

    my $type =
         $attrs->{type}
      || $attrs->{mode}
      || Foswiki::Func::getPreferencesValue('COMMENTPLUGIN_DEFAULT_TYPE')
      || 'above';

    my $templatetopic;
    if ( $attrs->{templatetopic} ) {
        my ( $templocweb, $temploctopic ) =
          Foswiki::Func::normalizeWebTopicName( $web, $attrs->{templatetopic} );
        $templatetopic = "$templocweb.$temploctopic";
    }

    # Get the templates.
    my $templateFile =
         $templatetopic
      || Foswiki::Func::getPreferencesValue('COMMENTPLUGIN_TEMPLATES')
      || 'comments';

    unless ( Foswiki::Func::loadTemplate($templateFile) ) {
        Foswiki::Func::writeWarning(
            "Could not read template file '$templateFile'");
        return _alert("Could not read templates from '$templateFile'");
    }

    my $message = $attrs->{default} || '';
    $message = $disabled if $disabled;

    # clean off whitespace
    $type =~ s/\s+//;

    # Expand the template in the context of the web where the comment
    # box is (not the target of the comment!)
    my $input = Foswiki::Func::expandTemplate("PROMPT:$type");
    return _alert("No such template def 'PROMPT:$type'")
      unless ( defined($input) && $input ne '' );

    # Expand special attributes as required
    $input =~ s/%([a-z]\w+)\|(.*?)%/_expandPromptParams($1, $2, $attrs)/ieg;

    # see if this comment is targeted at a different topic, and
    # change the url if it is.
    my $anchor = undef;
    my $target = $attrs->{target};
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
    return _alert("Target web does not exist: '$web'")
      unless ( Foswiki::Func::webExists($web) );

    # see if an alternate return is specified.  Sanitize and set the endpoint
    # if set.
    my $endPointReq = $attrs->{redirectto} || '';
    my $endPoint = "$web.$topic";

    if ($endPointReq) {
        my $epParam = '';

        # extract ur
        if ( $endPointReq =~ s/([\?\#].*)$// ) {
            $epParam = $1;
        }
        my ( $epWeb, $epTopic ) =
          Foswiki::Func::normalizeWebTopicName( $web, $endPointReq );

        if ( Foswiki::Func::topicExists( $epWeb, $epTopic ) ) {
            $endPoint = $epWeb . '/' . $epTopic . $epParam;
        }
        else {
            return _alert(
                "redirectto location does not exist: '$epWeb.$epTopic'");
        }
    }

    # See if a save url has been defined in the template
    my $url = Foswiki::Func::expandTemplate('save_url');

    # Default it to a rest url if not
    $url ||= Foswiki::Func::getScriptUrl( 'CommentPlugin', 'comment', 'rest' );

    $url = '' if $disabled;

    my $noform = $attrs->{noform} || '';

    # Note: Item10050: If CommentPlugin prompt adds newlines then it prevents
    # COMMENT inside TML tables so avoid cosmetic \n
    if ( $input !~ m/^%RED%/ ) {
        $input =~ s/%DISABLED%/$disabled ? 'disabled' : '' /ge;
        $input =~ s/%MESSAGE%/$message/g;
        my $idx = $attrs->{comment_index};

        unless ($disabled) {
            my $hiddenFields = "";
            my $s            = "$web.$topic";
            $hiddenFields .= _hidden( "topic",          "$web.$topic" );
            $hiddenFields .= _hidden( "comment_action", "save" );

            if ($endPointReq) {
                $hiddenFields .= _hidden( "redirectto", $endPoint );
            }

            $hiddenFields .= _hidden( 'comment_type', $type );

            if ( defined( $attrs->{nonotify} ) ) {
                $hiddenFields .= _hidden( 'comment_nonotify', 1 );
            }
            if ($templatetopic) {
                $hiddenFields .=
                  _hidden( 'comment_templatetopic', $templatetopic );
            }
            if ( $attrs->{location} ) {
                $hiddenFields .=
                  _hidden( 'comment_location', $attrs->{location} );
            }
            elsif ($anchor) {
                $hiddenFields .= _hidden( 'comment_anchor', $anchor );
            }
            else {
                $hiddenFields .= _hidden( 'comment_index', $idx );
            }
            if ( $attrs->{nopost} ) {
                $hiddenFields .= _hidden( 'comment_nopost', $attrs->{nopost} );
            }
            if ( $attrs->{remove} ) {
                $hiddenFields .= _hidden( 'comment_remove', $idx );
            }
            $input .= $hiddenFields;
        }

        # SMELL: would have been more elegant to split this into
        # FORM:head:type and FORM:tail:type. Too late now :-(
        my $form = Foswiki::Func::expandTemplate("FORM:$type");

        if ( $noform || $form ) {
            if ($form) {
                $form =~ s/%COMMENTPROMPT%/$input/;
                $input = $form;
            }
            else {
                $input = "$form $input";
            }
        }
        else {
            my $startform = CGI::start_form(
                -name   => $type . $idx,
                -class  => 'commentPluginForm',
                -id     => $type . $idx,
                -action => $url,
                -method => 'post'
            );

            # Item10050: CGI may add a trailing new line.
            # This prevents using COMMENT inside TML tables
            $startform =~ s/\n$//;

            $input = $startform . $input . CGI::end_form();
        }
    }
    return $input;
}

sub _alert {
    my $mess = shift;
    return "<span class='foswikiAlert'> $mess </span>";
}

# PRIVATE expand special %param|default% parameters in PROMPT template
sub _expandPromptParams {
    my ( $name, $default, $attrs ) = @_;

    my $val = $attrs->{$name};
    return $val if defined($val);
    return $default;
}

# PUBLIC build new topic text using exsting topic text and URL params
# Return the full new topic text, and the position and output for
# sending back in response to a REST request.
sub comment {

    my ( $query, $web, $topic ) = @_;

    return ( undef, undef ) unless $query;

    my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );

    $text = '' unless defined $text;

    my $wikiName = Foswiki::Func::getWikiName();
    my $mode     = $Foswiki::cfg{Plugins}{CommentPlugin}{RequiredForSave}
      || 'change';
    my $access =
      Foswiki::Func::checkAccessPermission( $mode, $wikiName, $text, $topic,
        $web );

    unless ($access) {

        # user has no permission to change the topic
        throw Foswiki::AccessControlException( $mode, $wikiName, $web, $topic,
            'Comment on topic not permitted' );
    }

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
    my $index = $query->param('comment_index') || 0;

    my $anchor        = $query->param('comment_anchor');
    my $location      = $query->param('comment_location');
    my $remove        = $query->param('comment_remove');
    my $nopost        = $query->param('comment_nopost');
    my $templatetopic = $query->param('comment_templatetopic');

    if ($templatetopic) {
        my ( $templocweb, $temploctopic ) =
          Foswiki::Func::normalizeWebTopicName( $web, $templatetopic );
        $templatetopic = "$templocweb.$temploctopic";
    }

    # Get the templates.
    my $templateFile =
         $templatetopic
      || Foswiki::Func::getPreferencesValue('COMMENTPLUGIN_TEMPLATES')
      || 'comments';

    Foswiki::Func::loadTemplate($templateFile);

    my $output = Foswiki::Func::expandTemplate("OUTPUT:$type");
    die _alert("No such template def 'OUTPUT:$type'") unless $output;

    # Expand the template
    my $position = 'AFTER';
    if ( $output =~ s/%POS:(.*?)%//g ) {
        $position = $1;
    }

    my $encodeguest = ( Foswiki::Func::isGuest() ) ? 'entity' : 'off';
    $output =~ s/\$encodeguest/$encodeguest/g;

    # Expand common variables in the template, but don't expand other
    # tags.
    $output = Foswiki::Func::expandVariablesOnTopicCreation($output);

    $output = '' unless defined($output);

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

                # When matching an arbitrary location, we make sure
                # the location isn't preceded by location=", which
                # would indicate a match in the COMMENT macro. Not a
                # cast-iron solution, but it mostly works.
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

    return ( $meta, $text, $position, $output );
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

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
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
