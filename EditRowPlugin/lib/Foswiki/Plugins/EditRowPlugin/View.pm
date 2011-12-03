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
sub process {
    my ( $text, $web, $topic, $meta ) = @_;

    my $macro = $Foswiki::cfg{Plugins}{EditRowPlugin}{Macro} || 'EDITTABLE';

    return 0 unless $text =~ /%${macro}({.*})?%/;

    my $context = Foswiki::Func::getContext();
    return 0 unless $context->{view};
    return 0 if $context->{static};

    my $query = Foswiki::Func::getCgiQuery();
    return 0 unless $query;

    return 0 if Foswiki::Func::getPreferencesFlag('EDITROWPLUGIN_DISABLE');

    Foswiki::Plugins::JQueryPlugin::registerPlugin(
	'EditRow',
	'Foswiki::Plugins::EditRowPlugin::JQuery');
    unless( Foswiki::Plugins::JQueryPlugin::createPlugin(
		"EditRow", $Foswiki::Plugins::SESSION )) {
	die 'Failed to register JQuery plugin';
    }

    require Foswiki::Plugins::EditRowPlugin::TableParser;

    my @varnames = $query->param();
    my $urps     = {};
    foreach my $key (@varnames) {
        $urps->{$key} = $query->param($key) if $key =~ /^erp_/;
    }

    my $endsWithNewline = ( $text =~ /\n$/ ) ? 1 : 0;

    # Parse tables to generate an array of interleaved content lines and
    # table objects.
    my $content =
      Foswiki::Plugins::EditRowPlugin::TableParser::parseTables( $text, $web,
        $topic, $meta, $urps );

    my $active_table = 0;
    my $active_topic = "$web.$topic";
    # Get the revision number of the topic; if the saving user is
    # different from the most recent saver, this will be used to
    # determine if there has been a save clash.
    my @ri = Foswiki::Func::getRevisionInfo($web, $topic);
    my $active_version = "$ri[2]_$ri[0]";

    $urps->{erp_active_topic} ||= $active_topic;
    $urps->{erp_active_table} ||= "${macro}_$active_table";
    $urps->{erp_active_row}   ||= 0;
    $urps->{erp_active_row}   =~ s/#.*$//; # workaround for Item10412

    my $nlines = '';
    my $table  = undef;

    # If this is set, the table isn't editable
    my $displayOnly = 0;

    # Without change access, there is no way you can edit.
    $displayOnly = 1 unless ( Foswiki::Func::checkAccessPermission(
				  'CHANGE', Foswiki::Func::getWikiName(),
				  $text, $topic, $web, $meta));

    my $hasTables = 0; # set to true if there is at least one table
    my $needHead  = 0; # set to true if we need JS included

    # $real_table is the content re-read (on demand) from the raw topic.
    # This is used when the contents of the table have already been
    # processed by other plugins, but we want to get back to basics for an
    # edit.
    my $editable_content;
    foreach (@$content) {
        next unless ( UNIVERSAL::isa( $_, 'Foswiki::Plugins::EditRowPlugin::Table' ) );
	my $line = '';
	$table = $_;
	$table->{editable} = !$displayOnly;
	$active_table++;
	if (  !$displayOnly
	      && $active_topic eq $urps->{erp_active_topic}
	      && $urps->{erp_active_table} eq "${macro}_$active_table" ) {

	    my $active_row = $urps->{erp_active_row};
	    unless ($table->{attrs}->{js} eq 'assumed') {
		my $saveUrl = Foswiki::Func::getScriptUrl(
		    'EditRowPlugin', 'save', 'rest', %{$_->getURLParams()});
		$line .= CGI::start_form(
		    -method => 'POST',
		    -name   => "erp_form_${macro}_$active_table",
		    -action => $saveUrl
		    );
		$line .= CGI::hidden( 'erp_active_topic', $active_topic );
		$line .= CGI::hidden( 'erp_active_version', $active_version );
		$line .=
		    CGI::hidden( 'erp_active_table', "${macro}_$active_table" );
		$line .= CGI::hidden( 'erp_active_row', $active_row );
	    }

	    # To avoid with the situation where macros like
	    # %CALC% have already been processed and end up getting saved
	    # in the table that way (processed), we need to read in the
	    # topic again in raw format
	    unless ($editable_content) {
		my ( $junkmeta, $raw ) =
		    Foswiki::Func::readTopic( $web, $topic );
		$editable_content =
		    Foswiki::Plugins::EditRowPlugin::TableParser::parseTables(
                        $raw, $web, $topic, $junkmeta, $urps );
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
		    $ea_table++;
		    if ( $ea_table == $active_table ) {
			$real_table = $ee;
			last;
		    }
		}
	    }
	    $line .= "\n"
		. $table->render({
		    for_edit => 1,
		    active_row => $active_row,
		    real_table => $real_table })
		. "\n";
	    $line .= CGI::end_form() unless $table->{attrs}->{js} eq 'assumed';
	    $needHead = 1;
	}
	else {
	    $line = $table->render({ with_controls => !$displayOnly });
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
	    $precruft  = "<!-- STARTINCLUDE $_[2].$_[1] -->\n";
	    $postcruft = "\n<!-- STOPINCLUDE $_[2].$_[1] -->";
	}
	$_ = $precruft . $line . $postcruft;
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

Copyright (c) 2008-2011 Foswiki Contributors
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
