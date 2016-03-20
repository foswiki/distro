# See bottom of file for copyright
package Foswiki::Plugins::EditRowPlugin::View;

use strict;
use warnings;
use Assert;

use Foswiki ();
use Foswiki::Func();

# Process the text of a topic through the plugin. Usually this involves
# re-loading the raw topic content (as not yet processed by macros and
# other plugins) parsing tables out, and instrumenting those tables with
# the edit controls.
# URL params:
#    * erp_topic
#    * erp_table
#    * erp_row
sub process {
    my ( $text, $web, $topic, $meta ) = @_;

    my $macro = $Foswiki::cfg{Plugins}{EditRowPlugin}{Macro} || 'EDITTABLE';

    return 0 unless $text =~ /%${macro}(\{.*?\})?%/s;

    my $context = Foswiki::Func::getContext();
    return 0 unless $context->{view};

    if ( $context->{static} ) {
        $_[0] =~ s/%${macro}(\{.*?\})?%//s;
        return 1;
    }

    my $query = Foswiki::Func::getCgiQuery();
    return 0 unless $query;

    return 0
      if Foswiki::Func::getPreferencesFlag('EDITROWPLUGIN_DISABLE') =~ /full/;

    Foswiki::Plugins::JQueryPlugin::registerPlugin( 'EditRow',
        'Foswiki::Plugins::EditRowPlugin::JQuery' );
    unless (
        Foswiki::Plugins::JQueryPlugin::createPlugin(
            "EditRow", $Foswiki::Plugins::SESSION
        )
      )
    {
        die 'Failed to register JQuery plugin';
    }

    require Foswiki::Plugins::EditRowPlugin::TableParser;

    my @varnames = $query->param();
    my $urps     = {};

    # Load erp_ params in to local hash
    foreach my $key (@varnames) {
        $urps->{$key} = $query->param($key) if $key =~ /^erp_/;
    }

    my $endsWithNewline = ( $text =~ /\n$/ ) ? 1 : 0;

    # Parse tables to generate an array of interleaved content lines and
    # table objects, skipping over %EDITTABLE instructions.
    my $parser = Foswiki::Plugins::EditRowPlugin::TableParser->new();
    my $content = $parser->parse( $text, $meta, $urps );

    my $active_topic = "$web.$topic";

    # Get the revision number of the topic; if the saving user is
    # different from the most recent saver, this will be used to
    # determine if there has been a save clash.
    my @ri = Foswiki::Func::getRevisionInfo( $web, $topic );
    my $active_version = "$ri[2]_$ri[0]";

    # Defaults only useful when viewing in non-JS editing mode
    $urps->{erp_topic} ||= $active_topic;
    $urps->{erp_table} ||= "NONE";

    $urps->{erp_row} ||= 0;
    $urps->{erp_row} =~ s/#.*$//;    # workaround for Item10412

    my $nlines = '';
    my $table  = undef;

    # Without change access, there is no way you can edit.
    my $editIsDisabled =
      Foswiki::Func::checkAccessPermission( 'CHANGE',
        Foswiki::Func::getWikiName(),
        $text, $topic, $web, $meta ) ? 0 : 1;

    # If rest is in AuthScripts and we are not authenticated, cannot jsedit
    my $jsIsDisabled =
      ( $Foswiki::cfg{AuthScripts} =~ /\brest\b/
          && !Foswiki::Func::getContext()->{authenticated} );

    # If we are denied change permission, cannot edit

    my $hasTables = 0;    # set to true if there is at least one table
    my $needHead  = 0;    # set to true if we need JS included

    # $real_table is the content re-read (on demand) from the raw topic.
    # This is used when the contents of the table have already been
    # processed by other plugins, but we want to get back to basics for an
    # edit.
    my $editable_content;
    foreach (@$content) {
        next
          unless (
            UNIVERSAL::isa( $_, 'Foswiki::Plugins::EditRowPlugin::Table' ) );
        my $line = '';
        $table = $_;
        $table->{editable} = 0 if $editIsDisabled;
        $table->{attrs}->{js} = 'ignored' if $jsIsDisabled;

        # spit out macros eaten by early_line, but not processed by
        # this plugin, so other plugins can detect and process
        # them (e.g. %TABLE)
        foreach my $spec ( @{ $table->{specs} } ) {
            next
              if $spec->{tag} eq $Foswiki::cfg{Plugins}{EditRowPlugin}{Macro};
            $line .= $spec->{raw};
        }

        if (   $table->{editable}
            && $active_topic   eq $urps->{erp_topic}
            && $table->getID() eq $urps->{erp_table} )
        {

            my $active_row = $urps->{erp_row};

            my $saveUrl =
              Foswiki::Func::getScriptUrl( 'EditRowPlugin', 'save', 'rest' );

            $line .= "<form action='$saveUrl' method='POST' name='erp_form_"
              . $table->getID() . "'>";

            # js="assumed" doesn't actually use the form, except as a
            # vehicle for validation. js="assumed" extracts the necessary
            # from the erp-data attached to the table.
            unless ( $table->{attrs}->{js} eq 'assumed' ) {
                $line .= Foswiki::Render::html(
                    'input',
                    {
                        type  => 'hidden',
                        name  => 'erp_topic',
                        value => $active_topic
                    }
                );
                $line .= Foswiki::Render::html(
                    'input',
                    {
                        type  => 'hidden',
                        name  => 'erp_version',
                        value => $active_version
                    }
                );
                $line .= Foswiki::Render::html(
                    'input',
                    {
                        type  => 'hidden',
                        name  => 'erp_table',
                        value => $table->getID()
                    }
                );
                $line .= Foswiki::Render::html(
                    'input',
                    {
                        type  => 'hidden',
                        name  => 'erp_row',
                        value => $active_row
                    }
                );
            }

            # To avoid with the situation where macros like
            # %CALC% have already been processed and end up getting saved
            # in the table that way (processed), we need to read in the
            # topic again in raw format
            unless ($editable_content) {
                my ( $rawmeta, $raw ) =
                  Foswiki::Func::readTopic( $web, $topic );
                $editable_content = $parser->parse( $raw, $rawmeta, $urps );
            }

            # get the corresponding table in the editable content
            my $ea_table   = 0;
            my $real_table = undef;
            foreach my $ee (@$editable_content) {
                if (
                    UNIVERSAL::isa(
                        $ee, 'Foswiki::Plugins::EditRowPlugin::Table'
                    )
                  )
                {
                    if ( $ee->getID() eq $table->getID() ) {
                        $real_table = $ee;
                        last;
                    }
                }
            }
            $line .= "\n"
              . $table->render(
                {
                    for_edit   => 1,
                    active_row => $active_row,
                    real_table => $real_table
                }
              ) . "\n";
            $line .= '</form>';
            $needHead = 1;
        }
        else {
            if ( $table->{attrs}->{js} ne 'ignored' ) {

                # Action-less form just used to hang validation from
                $line .= "<form action='valid' method='POST' name='erp_form_"
                  . $table->getID() . "'>\n";
            }
            $line .= $table->render( { with_controls => $table->{editable} } );
            $line .= '</form>' if $table->{attrs}->{js} ne 'ignored';
        }

        $table->finish();

        # If this is an included topic, mark the table as having
        # being included so we don't attempt to reprocess it
        my ( $precruft, $postcruft ) = ( '', '' );
        if (
            defined Foswiki::Func::getPreferencesValue('INCLUDINGTOPIC')

            # NOTE: SESSION_TAGS used to be private to Foswiki.pm, but
            # the "official" mechanism for accessing its value was
            # just silly i.e.
            # Foswiki::Func::expandCommonVariables("%INCLUDINGTOPIC%");
            || defined $Foswiki::Plugins::SESSION->{SESSION_TAGS}
            && defined $Foswiki::Plugins::SESSION->{SESSION_TAGS}
            {INCLUDINGTOPIC}
          )
        {
            my $id = "!$_[1].$_[2]:T" . $table->number();
            $precruft  = "<!-- STARTINCLUDE $id -->\n";
            $postcruft = "\n<!-- ENDINCLUDE $id -->";
        }
        $_         = $precruft . $line . $postcruft;
        $hasTables = 1;
    }

    if ($hasTables) {
        $_[0] = join( "\n", @$content ) . ( $endsWithNewline ? "\n" : '' );
        return 1;
    }
    return 0;
}

1;
__END__
Author: Crawford Currie http://c-dot.co.uk

Copyright (c) 2008-2016 Foswiki Contributors
Copyright (c) 2007 WindRiver Inc. and TWiki Contributors.
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
