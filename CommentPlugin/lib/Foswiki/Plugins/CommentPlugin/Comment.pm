# See bottom of file for license and copyright information
#
# This version is specific to Foswiki::Plugins::VERSION > 1.026

use strict;
use warnings;

use Foswiki;
use Foswiki::Plugins;
use Foswiki::Store;
use Foswiki::Attrs;
use CGI qw( -any );

package Foswiki::Plugins::CommentPlugin::Comment;

# PUBLIC save the given comment.
sub save {

    #my ( $text, $topic, $web ) = @_;

    my $wikiName = Foswiki::Func::getWikiName();
    if (
        !Foswiki::Func::checkAccessPermission(
            'change', $wikiName, '', $_[1], $_[2]
        )
      )
    {

        # user has no permission to change the topic
        throw Foswiki::OopsException(
            'accessdenied',
            def   => 'topic_access',
            web   => $_[2],
            topic => $_[1]
        );
    }
    else {
        _buildNewTopic(@_);
    }
}

# PUBLIC STATIC convert COMMENT statements to form prompts
sub prompt {

    #my ( $previewing, $text, $web, $topic ) = @_;

    my $defaultType =
      Foswiki::Func::getPreferencesValue('COMMENTPLUGIN_DEFAULT_TYPE')
      || 'above';

    my $message = '';

    # Is commenting disabled?
    my $disable = '';
    if ( $_[0] ) {

        # We are in Preview mode
        $message = "(Edit - Preview)";
        $disable = 'disabled';
    }
    elsif ( Foswiki::Func::getContext->{static} ) {
        $message = "(Static view)";
        $disable = 'disabled';
    }

    my $idx = 0;
    $_[1] =~
s/%COMMENT({.*?})?%/_handleInput($1,$_[2],$_[3],\$idx,$message,$disable,$defaultType)/eg;
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

# PRIVATE generate an input form for a %COMMENT tag
sub _handleInput {
    my ( $attributes, $web, $topic, $pidx, $message, $disable, $defaultType ) =
      @_;

    $attributes =~ s/^{(.*)}$/$1/ if ($attributes);

    my $attrs = new Foswiki::Attrs( $attributes, 1 );
    my $type = $attrs->remove('type') || $attrs->remove('mode') || $defaultType;
    my $silent            = $attrs->remove('nonotify');
    my $location          = $attrs->remove('location');
    my $remove            = $attrs->remove('remove');
    my $nopost            = $attrs->remove('nopost');
    my $default           = $attrs->remove('default');
    my $attrtemplatetopic = $attrs->remove('templatetopic') || '';
    my $templatetopic     = _getTemplateLocation( $attrtemplatetopic, $web );

    $message ||= $default || '';
    $message ||= $default || '';
    $disable ||= '';

    # clean off whitespace
    $type =~ m/(\S*)/;
    $type = $1;

    # Expand the template in the context of the web where the comment
    # box is (not the target of the comment!)
    my $input = _getTemplate( "PROMPT:$type", $web, $topic, $templatetopic )
      || '';
    return $input if $input =~ m/^%RED%/so;

    # Expand special attributes as required
    $input =~ s/%([a-z]\w+)\|(.*?)%/_expandPromptParams($1, $2, $attrs)/ieg;

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

    my $url = '';
    if ( $disable eq '' ) {
        $url = Foswiki::Func::getScriptUrl( $web, $topic, 'save' );
    }

    # Note: Item10050: If CommentPlugin prompt adds newlines then it prevents
    # COMMENT inside TML tables so avoid cosmetic \n
    my $noform = $attrs->remove('noform') || '';
    if ( $input !~ m/^%RED%/ ) {
        $input =~ s/%DISABLED%/$disable/g;
        $input =~ s/%MESSAGE%/$message/g;
        my $n = $$pidx + 0;

        if ( $disable eq '' ) {
            my $hiddenFields = "";
            $hiddenFields .=
              CGI::hidden( -name => 'comment_action', -value => 'save' );
            $hiddenFields .=
              CGI::hidden( -name => 'comment_type', -value => $type );
            if ( defined($silent) ) {
                $hiddenFields .=
                  CGI::hidden( -name => 'comment_nonotify', value => 1 );
            }
            if ($templatetopic) {
                $hiddenFields .= CGI::hidden(
                    -name  => 'comment_templatetopic',
                    -value => $templatetopic
                );
            }
            if ($location) {
                $hiddenFields .= CGI::hidden(
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
                  CGI::hidden( -name => 'comment_index', -value => $$pidx );
            }
            if ($nopost) {
                $hiddenFields .=
                  CGI::hidden( -name => 'comment_nopost', -value => $nopost );
            }
            if ($remove) {
                $hiddenFields .=
                  CGI::hidden( -name => 'comment_remove', -value => $$pidx );
            }
            $input .= $hiddenFields;
        }
        if ($noform) {
            my $form =
              _getTemplate( "FORM:$type", $topic, $web, $templatetopic, 'off' )
              || '';
            if ($form) {
                $form =~ s/%COMMENTPROMPT%/$input/;
                $input = $form;
            }
        }
        unless ( $noform eq 'on' ) {
            my $startform = CGI::start_form(
                -name   => $type . $n,
                -id     => $type . $n,
                -action => $url,
                -method => 'post'
            );

            # Item10050: CGI may add a trailing new line.
            # This prevents using COMMENT inside TML tables
            $startform =~ s/\n$//;

            $input = $startform . $input . CGI::end_form();
        }
    }
    $$pidx++;
    return $input;
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

# PRIVATE STATIC Performs comment insertion in the topic.
sub _buildNewTopic {

    #my ( $text, $topic, $web ) = @_;
    my ( $topic, $web ) = ( $_[1], $_[2] );

    my $query = Foswiki::Func::getCgiQuery();
    return unless $query;

    my $type =
         $query->param('comment_type')
      || Foswiki::Func::getPreferencesValue('COMMENTPLUGIN_DEFAULT_TYPE')
      || 'above';
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
    # Note: because this is Dakar, and has sensible semantics for handling
    # the =text= parameter to =save=, there is no longer any need to re-read
    # the topic. The text is automatically defaulted to the existing topic
    # text if the =text= parameter isn't specified - which for comments,
    # it isn't.
    my $premeta  = '';
    my $postmeta = '';
    my $inpost   = 0;
    my $text     = '';
    foreach my $line ( split( /\r?\n/, $_[0] ) ) {
        if ( $line =~ /^%META:[A-Z]+{[^}]*}%/ ) {
            if ($inpost) {
                $postmeta .= $line . "\n";
            }
            else {
                $premeta .= $line . "\n";
            }
        }
        else {
            $text .= $line . "\n";
            $inpost = 1;
        }
    }

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

    $_[0] = $premeta . $text . $postmeta;
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
