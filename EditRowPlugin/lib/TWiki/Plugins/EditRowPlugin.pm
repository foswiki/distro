# See bottom of file for copyright
package TWiki::Plugins::EditRowPlugin;

use strict;

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $NO_PREFS_IN_TOPIC $headed );

use Assert;

$VERSION = '$Rev$';
$RELEASE = '$Date$';
$SHORTDESCRIPTION = 'Inline edit for tables';
$NO_PREFS_IN_TOPIC = 1;

my $pluginName = 'EditRowPlugin';
my $USE_SRC = '';

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.1 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    TWiki::Func::registerRESTHandler('save', \&save);
    $headed = 0;

    if (TWiki::Func::getPreferencesValue('EDITROWPLUGIN_DEBUG')) {
        $USE_SRC = '_src';
    }

    # Plugin correctly initialized
    return 1;
}

# Formerly this said:
# The handler has to be run from both beforeCommonTagsHandler and
# commonTagsHandler, because beforeCommonTagsHandler allows us to
# process tables before TWiki variables in their data are expanded,
# while the second call allows us to handle tables that have been
# included from other topics. Both handlers only fire when the topic
# text contains %EDITTABLE, thus constraining the problem.
# But since Item4970: disabled the beforeCommonTagsHandler because
# it pre-empts SpreadSheetPlugin, which uses a commonTagsHandler. This
# is consistent with EditTablePlugin, so fingers crossed.
#sub beforeCommonTagsHandler {
#   my ($text, $topic, $web, $meta) = @_;
#die $text if $text =~ /%EDITTABLE/;
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

    return 0 unless $text =~ /%EDITTABLE{.*}%/;

    my $context = TWiki::Func::getContext();
    return 0 unless $context->{view};

    unless ($headed) {
        $headed = 1; # recursion block
        my $header = "<script type='text/javascript' src='";
        $header .= TWiki::Func::getPubUrlPath().'/'.
          TWiki::Func::getTwikiWebname().
              "/EditRowPlugin/TableSort$USE_SRC.js'></script>";
        $header .= <<STYLE;
<style>
.erpSort {
   text-decoration: underline;
}
</style>
STYLE
        TWiki::Func::addToHEAD('EDITROWPLUGIN_JSSORT', $header);
    }

    my $query = TWiki::Func::getCgiQuery();
    return 0 unless $query;

    return 0 if TWiki::Func::getPreferencesFlag('EDITROWPLUGIN_DISABLE');

    require TWiki::Plugins::EditRowPlugin::Table;
    return 0 if $@;

    my $vars = $query->Vars();
    my $urps = {};
    while (my ($key, $value) = each %{$vars}) {
        $urps->{$key} = $value if $key =~ /^erp_/;
    }

    my $endsWithNewline = ($text =~ /\n$/) ? 1 : 0;

    my $content = TWiki::Plugins::EditRowPlugin::Table::parseTables(
        $text, $web, $topic, $meta, $urps);

    my $active_table = 0;
    my $active_topic = "$web.$topic";

    $urps->{erp_active_topic} ||= $active_topic;
    $urps->{erp_active_table} ||= $active_table;
    $urps->{erp_active_row} ||= 0;

    my $nlines = '';
    my $table = undef;

    my $displayOnly = 0;

    # Without change access, there is no way you can edit.
    if (!TWiki::Func::checkAccessPermission(
        'CHANGE', TWiki::Func::getWikiName(),
        $text, $topic, $web, $meta)) {
        $displayOnly = 1;
    }

    my $hasTables = 0;
    my $needHead = 0;
    foreach (@$content) {
        if (ref($_) eq 'TWiki::Plugins::EditRowPlugin::Table') {
            my $line = '';
            $table = $_;
            $active_table++;
            if (!$displayOnly
                  && $active_topic eq $urps->{erp_active_topic}
                    && $active_table == $urps->{erp_active_table}) {
                my $active_row = $urps->{erp_active_row};
                my $saveUrl =
                  TWiki::Func::getScriptUrl($pluginName, 'save', 'rest');
                $line = CGI::start_form(
                    -method=>'POST',
                    -name => 'erp_form_'.$active_table,
                    -action => $saveUrl);
                $line .= CGI::hidden('erp_active_topic', $active_topic);
                $line .= CGI::hidden('erp_active_table', $active_table);
                $line .= CGI::hidden('erp_active_row', $active_row);
                $line .= "\n".$table->renderForEdit($active_row)."\n";
                $line .= CGI::end_form();
                $needHead = 1;
            } else {
                $line = $table->renderForDisplay(!$displayOnly);
            }

            $table->finish();
            # If this is an included topic, mark the table as having
            # being included so we don't attempt to reprocess it
            my ($precruft, $postcruft) = ('', '');
            # NOTE: SESSION_TAGS is private to TWiki.pm, but the "official"
            # mechanism for accessing its value is just silly i.e.
            # TWiki::Func::expandCommonVariables("%INCLUDINGTOPIC%");
            if (defined $TWiki::Plugins::SESSION->{SESSION_TAGS}{INCLUDINGTOPIC}) {
                $precruft = "<!-- STARTINCLUDE $_[2].$_[1] -->\n";
                $postcruft = "\n<!-- STOPINCLUDE $_[2].$_[1] -->";
            }
            $_ = $precruft.$line.$postcruft;
            $hasTables = 1;
        }
    }

    if ($needHead) {
        eval {
            my $pub = TWiki::Func::getPubUrlPath();
            my $web = TWiki::Func::getTwikiWebname();
            require TWiki::Contrib::BehaviourContrib;
            if (defined(&TWiki::Contrib::BehaviourContrib::addHEAD)) {
                TWiki::Contrib::BehaviourContrib::addHEAD();
            } else {
                TWiki::Func::addToHEAD('BEHAVIOURCONTRIB', <<HEAD);
<script type='text/javascript' src='$pub/$web/BehaviourContrib/behaviour.compressed.js'></script>
HEAD
            }
            TWiki::Func::addToHEAD('EDITROWPLUGIN_JSVETO', <<HEAD);
<script type='text/javascript' src='$pub/$web/EditRowPlugin/twiki$USE_SRC.js'></script>
HEAD
        };
        if ($@) {
            TWiki::Func::writeDebug("EditRowPlugin: failed to add JS headers: $@");
        }
    }

    if ($hasTables) {
        $_[0] = join("\n", @$content).($endsWithNewline?"\n":'');
        return 1;
    }
    return 0;
}

# Replace content with a marker to prevent it being munged by TWiki
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
# The noredirect URL parameter can be passed to prevent
# the redirection. If it is set, the request will respond with a 500
# status code with a human readable message. This allows the handler
# to be used by Javascript table editors.
sub save {
    my $query = TWiki::Func::getCgiQuery();

    unless ($query) {
        print CGI::header(-status => "500 failed");
    }

    # Report fatals if we are in debug mode
    eval "use CGI::Carp qw(fatalsToBrowser)" if DEBUG;

    my $saveType = $query->param('editrowplugin_save') || '';
    my $active_topic = $query->param('erp_active_topic');
    $active_topic =~ /(.*)/;
    my ($web, $topic) = TWiki::Func::normalizeWebTopicName(undef, $1);

    my ($meta, $text) = TWiki::Func::readTopic($web, $topic);
    my ($url, $mess);
    if (!TWiki::Func::checkAccessPermission(
        'CHANGE', TWiki::Func::getWikiName(), $text, $topic, $web, $meta)) {

        $url = TWiki::Func::getScriptUrl(
            $web, $topic, 'oops',
            template => 'oopsaccessdenied',
            def => 'topic_access',
            param1 => 'CHANGE',
            param2 => 'access not allowed on topic'
         );
        $mess = "TWIKI ACCESS DENIED";
    } else {
        $text =~ s/\\\n//gs;
        require TWiki::Plugins::EditRowPlugin::Table;
        die $@ if $@;
        my $urps = $query->Vars();
        my $content = TWiki::Plugins::EditRowPlugin::Table::parseTables(
            $text, $topic, $web, $meta, $urps);

        my $nlines = '';
        my $table = undef;
        my $active_table = 0;
        my $action = 'cancel';
        my $minor = 0;     # If true, this is a quiet save
        my $no_save = 0;   # if true, we are cancelling
        my $no_return = 0; # if true, we want to finish editing after the action

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
            if (ref($line) eq 'TWiki::Plugins::EditRowPlugin::Table') {
                $table = $line;
                $active_table++;
                if ($active_topic eq $urps->{erp_active_topic}
                      && $active_table == $urps->{erp_active_table}) {
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
            TWiki::Func::saveTopic($web, $topic, $meta, $nlines,
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
        if ($TWiki::Plugins::VERSION < 1.11) {
            my $p = '';
            unless ($no_return) {
                $p = "?erp_active_topic=$urps->{erp_active_topic}";
                $p .= ";erp_active_table=$urps->{erp_active_table}";
                $p .= ";erp_active_row=$urps->{erp_active_row}";
            }
            $url = TWiki::Func::getScriptUrl($web, $topic, 'view').
              "$p#$anchor";
        } else {
            my @p = ('#' => $anchor);
            unless ($no_return) {
                push(@p, erp_active_topic => $urps->{erp_active_topic});
                push(@p, erp_active_table => $urps->{erp_active_table});
                push(@p, erp_active_row => $urps->{erp_active_row});
            }
            $url = TWiki::Func::getScriptUrl( $web, $topic, 'view', @p);
        }
    }

    unless ($query->param('erp_noredirect')) {
        TWiki::Func::redirectCgiQuery(undef, $url);
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

Copyright (C) 2007 WindRiver Inc. and TWiki Contributors.
All Rights Reserved. TWiki Contributors are listed in the
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
