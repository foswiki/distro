# See bottom of file for copyright
package Foswiki::Plugins::EditRowPlugin;

use strict;

use Assert;

our $VERSION = '$Rev$';
our $RELEASE = '$Date$';
our $SHORTDESCRIPTION = 'Inline edit for tables';
our $NO_PREFS_IN_TOPIC = 1;
our $RECURSING = 0;

my $pluginName = 'EditRowPlugin';
my $USE_SRC = '';

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    Foswiki::Func::registerRESTHandler('save', \&save);

    if (Foswiki::Func::getPreferencesValue('EDITROWPLUGIN_DEBUG')) {
        $USE_SRC = '_src';
    }

    # Plugin correctly initialized
    return 1;
}

# Formerly this said:
# The handler has to be run from both beforeCommonTagsHandler and
# commonTagsHandler, because beforeCommonTagsHandler allows us to
# process tables before macros in their data are expanded,
# while the second call allows us to handle tables that have been
# included from other topics. Both handlers only fire when the topic
# text contains %EDITTABLE, thus constraining the problem.
#
# But since Item4970: disabled the beforeCommonTagsHandler because
# it pre-empts SpreadSheetPlugin, which uses a commonTagsHandler. This
# is consistent with EditTablePlugin, so fingers crossed.
#sub beforeCommonTagsHandler {
#   my ($text, $topic, $web, $meta) = @_;
#   if (_process($text, $web, $topic, $meta)) {
#       $_[0] = $text;
#   }
#}

sub commonTagsHandler {
    my ($text, $topic, $web, $included, $meta) = @_;
    if (_process($text, $web, $topic, $meta)) {
        $_[0] = $text;
    }
}

sub _process {
    my ($text, $web, $topic, $meta) = @_;

    my $macro = $Foswiki::cfg{Plugins}{EditRowPlugin}{Macro} || 'EDITTABLE';

    return 0 unless $text =~ /%${macro}({.*})?%/;

    my $context = Foswiki::Func::getContext();
    return 0 unless $context->{view};

    unless ($RECURSING) {
        my $header = "<script type='text/javascript' src='";
        $header .= Foswiki::Func::getPubUrlPath().'/'.
          $Foswiki::cfg{SystemWebName}.
              "/EditRowPlugin/TableSort$USE_SRC.js'></script>";
        $header .= <<STYLE;
<style>
.erpSort {
   text-decoration: underline;
}
</style>
STYLE
        Foswiki::Func::addToHEAD('EDITROWPLUGIN_JSSORT', $header);
    }

    my $query = Foswiki::Func::getCgiQuery();
    return 0 unless $query;

    return 0 if Foswiki::Func::getPreferencesFlag('EDITROWPLUGIN_DISABLE');

    require Foswiki::Plugins::EditRowPlugin::TableParser;
    ASSERT(!$@) if DEBUG;
    return 0 if $@;

    # Flag our processing state
    local $RECURSING = 1;

    my @varnames = $query->param();
    my $urps = {};
    foreach my $key (@varnames) {
        $urps->{$key} = $query->param($key) if $key =~ /^erp_/;
    }

    my $endsWithNewline = ($text =~ /\n$/) ? 1 : 0;

    my $content = Foswiki::Plugins::EditRowPlugin::TableParser::parseTables(
        $text, $web, $topic, $meta, $urps);

    my $active_table = 0;
    my $active_topic = "$web.$topic";

    $urps->{erp_active_topic} ||= $active_topic;
    $urps->{erp_active_table} ||= "${macro}_$active_table";
    $urps->{erp_active_row} ||= 0;

    my $nlines = '';
    my $table = undef;

    my $displayOnly = 0;

    # Without change access, there is no way you can edit.
    if (!Foswiki::Func::checkAccessPermission(
        'CHANGE', Foswiki::Func::getWikiName(),
        $text, $topic, $web, $meta)) {
        $displayOnly = 1;
    }

    my $hasTables = 0;
    my $needHead = 0;
    # $real_table is the content re-read (on demand) from the raw topic.
    # This is used when the contents of the table have already been
    # processed by other plugins, but we want to get back to basics for an
    # edit.
    my $editable_content;
    foreach (@$content) {
        if (UNIVERSAL::isa($_, 'Foswiki::Plugins::EditRowPlugin::Table')) {
            my $line = '';
            $table = $_;
            $active_table++;
            if (!$displayOnly
                  && $active_topic eq $urps->{erp_active_topic}
                    && $urps->{erp_active_table} eq "${macro}_$active_table") {
                my $active_row = $urps->{erp_active_row};
                my $saveUrl =
                  Foswiki::Func::getScriptUrl($pluginName, 'save', 'rest');
                $line = CGI::start_form(
                    -method=>'POST',
                    -name => "erp_form_${macro}_$active_table",
                    -action => $saveUrl);
                $line .= CGI::hidden('erp_active_topic', $active_topic);
                $line .= CGI::hidden('erp_active_table', "${macro}_$active_table");
                $line .= CGI::hidden('erp_active_row', $active_row);
                # To avoid with the situation where macros like
                # %CALC% have already been processed and end up getting saved
                # in the table that way (processed), we need to read in the
                # topic again in raw format
                unless ($editable_content) {
                    my ($junkmeta, $raw) = Foswiki::Func::readTopic($web, $topic);
                    $editable_content =
                      Foswiki::Plugins::EditRowPlugin::TableParser::parseTables(
                          $raw, $web, $topic, $junkmeta, $urps);
                }
                # get the corresponding table in the editable content
                my $ea_table = 0;
                my $real_table = undef;
                foreach my $ee (@$editable_content) {
                    if (UNIVERSAL::isa(
                        $ee, 'Foswiki::Plugins::EditRowPlugin::Table')) {
                        $ea_table++;
                        if ($ea_table == $active_table) {
                            $real_table = $ee;
                            last;
                        }
                    }
                }
                $line .= "\n".$table->renderForEdit(
                    $active_row, $real_table)."\n";
                $line .= CGI::end_form();
                $needHead = 1;
            } else {
                $line = $table->renderForDisplay(!$displayOnly);
            }

            $table->finish();
            # If this is an included topic, mark the table as having
            # being included so we don't attempt to reprocess it
            my ($precruft, $postcruft) = ('', '');
            # NOTE: SESSION_TAGS is private to Foswiki.pm, but the "official"
            # mechanism for accessing its value is just silly i.e.
            # Foswiki::Func::expandCommonVariables("%INCLUDINGTOPIC%");
            if (defined $Foswiki::Plugins::SESSION->{SESSION_TAGS}{INCLUDINGTOPIC}) {
                $precruft = "<!-- STARTINCLUDE $_[2].$_[1] -->\n";
                $postcruft = "\n<!-- STOPINCLUDE $_[2].$_[1] -->";
            }
            $_ = $precruft.$line.$postcruft;
            $hasTables = 1;
        }
    }

    if ($needHead) {
        eval {
            my $pub = Foswiki::Func::getPubUrlPath();
            my $web = $Foswiki::cfg{SystemWebName};
            require Foswiki::Contrib::BehaviourContrib;
            ASSERT(!$@) if DEBUG;
            if (defined(&Foswiki::Contrib::BehaviourContrib::addHEAD)) {
                Foswiki::Contrib::BehaviourContrib::addHEAD();
            } else {
                Foswiki::Func::addToHEAD('BEHAVIOURCONTRIB', <<HEAD);
<script type='text/javascript' src='$pub/$web/BehaviourContrib/behaviour.compressed.js'></script>
HEAD
            }
            Foswiki::Func::addToHEAD('EDITROWPLUGIN_JSVETO', <<HEAD);
<script type='text/javascript' src='$pub/$web/EditRowPlugin/erp$USE_SRC.js'></script>
HEAD
        };
        if ($@) {
            Foswiki::Func::writeDebug("EditRowPlugin: failed to add JS headers: $@");
        }
    }

    if ($hasTables) {
        $_[0] = join("\n", @$content).($endsWithNewline?"\n":'');
        return 1;
    }
    return 0;
}

# Replace content with a marker to prevent it being munged by Foswiki
my @refs;
sub defend {
    my( $text ) = @_;
    my $n = scalar( @refs );
    push( @refs, $text );
    return "X\07$n\07X";
}

# Replace protected content.
sub postRenderingHandler {
    while( $_[0] =~ s/X\07([0-9]+)\07X/$refs[$1]/gi ) {
    }
}

# REST handler for table row edit save with redirect on completion.
# The erp_noredirect URL parameter can be passed to prevent
# the redirection. If it is set, the request will respond with a 500
# status code with a human readable message. This allows the handler
# to be used by Javascript table editors.
sub save {
    my $query = Foswiki::Func::getCgiQuery();

    unless ($query) {
        print CGI::header(-status => "500 failed");
    }

    # Report fatals if we are in debug mode
    eval "use CGI::Carp qw(fatalsToBrowser)" if DEBUG;

    my $saveType = $query->param('editrowplugin_save') || '';
    my $active_topic = $query->param('erp_active_topic');
    $active_topic =~ /(.*)/;
    my ($web, $topic) = Foswiki::Func::normalizeWebTopicName(undef, $1);

    my ($meta, $text) = Foswiki::Func::readTopic($web, $topic);
    my ($url, $mess);
    if (!Foswiki::Func::checkAccessPermission(
        'CHANGE', Foswiki::Func::getWikiName(), $text, $topic, $web, $meta)) {

        $url = Foswiki::Func::getScriptUrl(
            $web, $topic, 'oops',
            template => 'oopsaccessdenied',
            def => 'topic_access',
            param1 => 'CHANGE',
            param2 => 'access not allowed on topic'
         );
        $mess = "ACCESS DENIED";
    } else {
        $text =~ s/\\\n//gs;
        my @ps = $query->param();
        my $urps = { map { $_ => $query->param($_) } @ps };
        require Foswiki::Plugins::EditRowPlugin::TableParser;
        ASSERT(!$@) if DEBUG;
        my $content =
          Foswiki::Plugins::EditRowPlugin::TableParser::parseTables(
              $text, $topic, $web, $meta, $urps);

        my $nlines = '';
        my $table = undef;
        my $active_table = 0;
        my $action = 'cancel';
        my $minor = 0;     # If true, this is a quiet save
        my $no_save = 0;   # if true, we are cancelling
        my $no_return = 0; # if true, we want to finish editing after the action
        my $macro = $Foswiki::cfg{Plugins}{EditRowPlugin}{Macro}
          || 'EDITTABLE';

        # The submit buttons are image buttons. The only way with IE to tell
        # which one was clicked is by looking at the x coordinate of the
        # press.
        if ($query->param('erp_save.x')) {
            $action = 'change';
            $no_return = 1;
        } elsif ($query->param('erp_quietSave.x')) {
            $action = 'change';
            $minor = 1;
            $no_return = 1;
        } elsif ($query->param('erp_upRow.x')) {
            $action = 'moveUp';
        } elsif ($query->param('erp_downRow.x')) {
            $action = 'moveDown';
        } elsif ($query->param('erp_addRow.x')) {
            $action = 'addRow';
        } elsif ($query->param('erp_deleteRow.x')) {
            $action = 'deleteRow';
        } elsif ($query->param('erp_cancel.x')) {
            $no_save = 1;
            $no_return = 1;
        }
        foreach my $line (@$content) {
            if (UNIVERSAL::isa($line, 'Foswiki::Plugins::EditRowPlugin::Table')) {
                $table = $line;
                $active_table++;
                if ($active_topic eq $urps->{erp_active_topic}
                      && $urps->{erp_active_table} eq
                        "${macro}_$active_table") {
                    $table->$action($urps);
                }
                $line = $table->stringify();
                $table->finish();
                $nlines .= $line;
            } else {
                $nlines .= "$line\n";
            }
        }
        unless ($no_save) {
            Foswiki::Func::saveTopic($web, $topic, $meta, $nlines,
                                   { minor => $minor });
        }

        # Use a row anchor within range of the row being edited as
        # the goto target
        my $anchor = 'erp_'.$urps->{erp_active_table};
        if ($urps->{erp_active_row} > 5) {
            my $before = $urps->{erp_active_row} - 1;
            $anchor .= '_'.$before;
        } else {
            $anchor .= '_1';
        }
        my @p = ('#' => $anchor);
        unless ($no_return) {
            push(@p, erp_active_topic => $urps->{erp_active_topic});
            push(@p, erp_active_table => $urps->{erp_active_table});
            push(@p, erp_active_row => $urps->{erp_active_row});
        }
        $url = Foswiki::Func::getScriptUrl( $web, $topic, 'view', @p);
    }

    unless ($query->param('erp_noredirect')) {
        Foswiki::Func::redirectCgiQuery(undef, $url);
    } elsif ($mess) {
        print CGI::header(-status => "500 $mess");
    } else {
        print CGI::header(-status => 200);
    }

    return 0; # Suppress standard redirection mechanism
}

1;
__END__

Author: Crawford Currie http://c-dot.co.uk

Copyright (c) 2009 Foswiki Contributors
Copyright (C) 2007 WindRiver Inc. and TWiki Contributors.
All Rights Reserved. Foswiki Contributors are listed in the
AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

Do not remove this copyright notice.

This plugin supports editing of a table row-by-row.

It uses a fairly generic table object, and employs a REST handler
for saving.
