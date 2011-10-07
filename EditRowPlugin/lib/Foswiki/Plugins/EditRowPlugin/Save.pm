# See bottom of file for copyright
package Foswiki::Plugins::EditRowPlugin::Save;

use strict;
use warnings;
use Assert;
use Error ':try';

use Foswiki ();
use Foswiki::Func ();

# REST handler for table row edit save with redirect on completion.
# The noredirect URL parameter can be passed to prevent
# the redirection. If it is set, the request will respond with a 500
# status code with a human readable message. This allows the handler
# to be used by Javascript table editors.
sub process {
    my ( $session, $plugin, $verb, $response ) = @_;
    my $query = Foswiki::Func::getCgiQuery();

    unless ($query) {
        print CGI::header( -status => 500 );
        return undef;
    }

    my $ajax = $query->param('noredirect');

    my $active_topic = $query->param('erp_active_topic');
    $active_topic =~ /(.*)/;
    my ( $web, $topic ) = Foswiki::Func::normalizeWebTopicName( undef, $1 );

    my $ri = $query->param('erp_active_version');
    my ($active_version, $active_date);
    if ($ri && $ri =~ /(\d+)_(\d+)$/) {
	($active_version, $active_date) = ($1, $2);
    }
    my $active_user = Foswiki::Func::getWikiName();

    my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );
    my ( $url, $mess, $result );

    my ($curr_date, $curr_user, $curr_rev);
    if ($active_version) {
	($curr_date, $curr_user, $curr_rev) =
	    Foswiki::Func::getRevisionInfo($web, $topic);
    }

    # Find the action
    my $action;
    my $minor        = 0;          # If true, this is a quiet save
    my $no_return = 0; # if true, we want to finish editing after the action
    my $no_save      = 0;          # if true, we are cancelling
    my $clicked = $query->param('erp_action') || '';
    if ( $clicked =~ /^#?(save(Table|Row|Cell))(Quietly)?$/ ) {
	$action    = $1;
	$minor     = ($3 && $3 eq 'Quietly');
	$no_return = 1;
    }
    elsif ( $clicked =~ /^#?((up|down|add|move|delete)Row)$/ ) {
	$action = $1;
    }
    else {
	$action = 'cancel';
	$no_save   = 1;
	$no_return = 1;
    }

    if ( $action ne 'cancel' &&
        !Foswiki::Func::checkAccessPermission(
            'CHANGE', $active_user, $text, $topic, $web, $meta
        )
      )
    {
        $url = Foswiki::Func::getScriptUrl(
            $web, $topic, 'oops',
            template => 'oopsaccessdenied',
            def      => 'topic_access',
            param1   => 'CHANGE',
            param2   => 'access not allowed to topic'
        );
        $result = $mess = "ACCESS DENIED";
    }
    elsif ($action ne 'cancel' &&
	   (!$active_user || !$curr_user || $active_user ne $curr_user)
	   && ($active_version && $curr_rev && $curr_rev ne $active_version
	       || $active_date && $curr_date && $curr_date ne $active_date)) {
        $mess = "Cannot save because it would overwrite changes made by $curr_user (revision $curr_rev).\nRefresh the view and try again.";
        $url = Foswiki::Func::getScriptUrl(
            $web, $topic, 'oops',
            template => 'oopsaccessdenied',
            def      => 'topic_access',
            param1   => 'CHANGE',
            param2   => $mess
        );
     } else {
        $text =~ s/\\\n//gs;
        my @ps   = $query->param();
	my $urps = {};
        foreach my $p (@ps) {
            my @vals = $query->param($p);
            # We interpreted multi-value parameters as comma-separated
            # lists. This is what checkboxes, select+multi etc. use.
            $urps->{$p} = join( ',', grep { defined $_ } @vals );
        }
	#die join(' ',map { "'$_'=>'$urps->{$_}'"} keys %$urps);
        require Foswiki::Plugins::EditRowPlugin::TableParser;
        ASSERT( !$@ ) if DEBUG;
        my $content =
          Foswiki::Plugins::EditRowPlugin::TableParser::parseTables( $text,
            $web, $topic, $meta, $urps );

        my $nlines       = '';
        my $table        = undef;
        my $active_table = 0;
        my $macro = $Foswiki::cfg{Plugins}{EditRowPlugin}{Macro}
          || 'EDITTABLE';

	# Turn off editing if the erp_stop_edit flag is set in the request
	$no_return = 1 if $query->param('erp_stop_edit');

      LINE:
	foreach my $line (@$content) {
            if (
                UNIVERSAL::isa(
                    $line, 'Foswiki::Plugins::EditRowPlugin::Table'
                )
              )
            {
                $table = $line;
                $active_table++;
                if (   $active_topic eq $urps->{erp_active_topic}
                    && $urps->{erp_active_table} eq "${macro}_$active_table" )
                {
		    eval {
			$result = $table->$action($urps);
		    };
		    if ($@) {
			throw Error::Simple $@ unless $ajax;
			$mess = $@;
			$no_save = 1;
			last LINE;
		    }
                }
                $line = $table->stringify();
                $table->finish();
                $nlines .= $line;
            }
            else {
                $nlines .= "$line\n";
            }
        }
        unless ($no_save) {
            Foswiki::Func::saveTopic( $web, $topic, $meta, $nlines,
                { minor => $minor } );
        }
	# $url will be set if there's been an error
	# Use a row anchor within range of the row being edited as
	# the goto target
	my $anchor = 'erp_' . $urps->{erp_active_table};
	if ( $urps->{erp_active_row} > 5 ) {
	    my $before = $urps->{erp_active_row} - 1;
	    $anchor .= '_' . $before;
	}
	else {
	    $anchor .= '_1';
	}
	my @p = ( '#' => $anchor );
	unless ($no_return) {
	    push( @p, erp_active_topic => $urps->{erp_active_topic} );
	    push( @p, erp_active_table => $urps->{erp_active_table} );
	    push( @p, erp_active_row   => $urps->{erp_active_row} );
	}
	$url = Foswiki::Func::getScriptUrl( $web, $topic, 'view', @p );
    }

    if ( $ajax ) {
	# $mess will be set if there's been an error
	my $status = $mess ? 500 : 200;
	$response->header(
	    -status  => $status,
	    -type    => 'text/html',
	    -charset => 'UTF-8'
	    );
	if (defined $result) {
	    if ($result) {
		# renderText("0") clears the output, so don't do it.
		$result = Foswiki::Func::expandCommonVariables($result, $topic, $web);
		$result = Foswiki::Func::renderText($result, $web, $topic);
		$result =~ s/<nop>//gs;
		$result =~ s/\s+/ /gs;
	    }
	} else {
	    $result = $mess || '';
	}
	# The leading text RESPONSE is done so that a single 0 value can
	# be returned - see Item10794
	$response->body("RESPONSE$result");

    } else {
        Foswiki::Func::redirectCgiQuery( undef, $url );
    }
    return undef;
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
