# See bottom of file for license and copyright information

package CommentPluginTests;

use strict;
use warnings;
use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use Unit::Request();
use Unit::Response();
use Foswiki();
use Foswiki::UI::Save();
use Foswiki::Plugins::CommentPlugin();
use Foswiki::Plugins::CommentPlugin::Comment();
use CGI;

# Set up the test fixture
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $this->{target_web}   = "$this->{test_web}Target";
    $this->{target_topic} = "$this->{test_topic}Target";
    my $webObject = $this->populateNewWeb( $this->{target_web} );
    $webObject->finish();

    return;
}

sub tear_down {
    my $this = shift;
    $this->removeWeb( $this->{target_web} );
    $this->SUPER::tear_down();

    return;
}

sub fixture_groups {
    return ( [ 'viewContext', 'staticContext' ], );
}

sub viewContext {
    Foswiki::Func::getContext()->{view} = 1;
}

sub staticContext {
    Foswiki::Func::getContext()->{view}   = 1;
    Foswiki::Func::getContext()->{static} = 1;
}

sub writeTopic {
    my ( $this, $web, $topic, $text ) = @_;
    my $meta = Foswiki::Meta->new( $this->{session}, $web, $topic, $text );
    $meta->save();

    return;
}

sub trim {
    my $s = shift;
    $s =~ s/^\s*(.*?)\s*$/$1/sgo;
    return $s;
}

sub removeEscapes {
    my ($string) = @_;

    $string =~ s/\\[\r\n]//g;

    return $string;
}

# Not a test, a helper.
sub inputTest {
    my ( $this, $type, $web, $topic, $anchor, $location ) = @_;

    my $eidx   = 1;
    my $sattrs = "";

    $web   ||= $this->{test_web};
    $topic ||= $this->{test_topic};

    if ( $web ne $this->{test_web} || $topic ne $this->{test_topic} || $anchor )
    {

        $sattrs = 'target="';

        $sattrs .= "$web." unless ( $web   eq $this->{test_web} );
        $sattrs .= $topic  unless ( $topic eq $this->{test_topic} );

        if ($anchor) {
            $anchor = '#' . $anchor;
            $sattrs .= $anchor;
        }
        $sattrs .= '" ';
    }

    my $url = Foswiki::Func::getScriptUrl( $web, $topic, 'save' );

    if ($location) {
        $sattrs .= ' location="' . $location . '" ';
    }

    $type = "bottom" unless ($type);
    $sattrs .= 'type="' . $type . '" ';

    my $commentref = '%COMMENT{' . $sattrs . ' refmark="here"}%';

    # Build the target topic
    my $sample = <<"HERE";
TopOfTopic
%COMMENT{$sattrs}%
HERE
    if ($anchor) {
        $sample .= <<"HERE";
BeforeAnchor
$anchor
AfterAnchor
HERE
    }
    $sample .= <<"HERE";
BeforeLocation
HereIsTheLocation
AfterLocation
$commentref
BottomOfTopic
HERE

    $this->writeTopic( $web, $topic, $sample );
    my $pidx = $eidx;
    my $html =
      Foswiki::Plugins::CommentPlugin::Comment::_handleInput( $sattrs,
        $this->{test_web}, $this->{test_topic}, \$pidx, "The Message", "",
        "bottom" );

    $html = removeEscapes($html);
    $this->assert( $pidx == $eidx + 1, $html );

    $this->assert( scalar( $html =~ s/^<form(.*?)>//sio ) );
    my $dattrs = $1;
    $this->assert( scalar( $html =~ s/<\/form>\s*$//sio ) );
    $this->assert( scalar( $dattrs =~ s/\s+name=\"(.*?)\"// ), $dattrs );
    $this->assert_str_equals( "${type}$eidx", $1 );
    $this->assert( scalar( $dattrs =~ s/\s+method\s*=\s*\"post\"//i ),
        $dattrs );
    $this->assert( scalar( $dattrs =~ s/\s+action=\"(.*?)\"// ), $dattrs );
    $this->assert_str_equals( $url, $1 );
    $dattrs =~ s#application/x-www-form-urlencoded#multipart/form-data#;
    $this->assert_str_equals(
        'enctype="multipart/form-data" id="' . $type . '1"',
        trim($dattrs) );

    # no hiddens should be generated if disabled
    $this->assert(
        scalar( $html =~ s/<input ([^>]*\bname="comment_type".*?)\/>//i ),
        $html );
    $dattrs = $1;
    $this->assert( scalar( $dattrs =~ s/\s*type=\"hidden\"//io ), $dattrs );
    $this->assert( scalar( $dattrs =~ s/\s*value=\"$type\"// ),   $dattrs );
    $this->assert_str_equals( 'name="comment_type"', trim($dattrs) );

    if ($anchor) {
        $this->assert(
            $html =~ s/<input ([^>]*name=\"comment_anchor".*?)\s*\/>//i,
            $html );
        $dattrs = $1;
        $this->assert( scalar( $dattrs =~ s/\s*name=\"comment_anchor\"//io ),
            $dattrs );
        $this->assert( scalar( $dattrs =~ s/\s*type=\"hidden\"//io ), $dattrs );
        $this->assert( scalar( $dattrs =~ s/\s*value=\"(.*?)\"//o ),  $dattrs );
        $this->assert_str_equals( $anchor, $1 );
        $this->assert_str_equals( "",      trim($dattrs) );
        $this->assert_does_not_match( qr/<input name=\"comment_index/, $html );
        $this->assert_does_not_match( qr/<input name=\"comment_location/,
            $html );
    }
    elsif ($location) {
        $this->assert_matches(
            qr/<input [^>]*name="comment_location"(.*?)\s*\/>/i, $html );
        $this->assert(
            $html =~ s/<input ([^>]*name="comment_location".*?)\s*\/>//i );
        $dattrs = $1;
        $this->assert( scalar( $dattrs =~ s/\s*type=\"hidden\"//io ), $dattrs );
        $this->assert( scalar( $dattrs =~ s/\s*name=\"comment_location\"//io ),
            $dattrs );
        $this->assert( scalar( $dattrs =~ s/\s*value=\"(.*?)\"//o ), $dattrs );
        $this->assert_str_equals( $location, $1 );
        $this->assert_str_equals( "",        trim($dattrs) );
        $this->assert_does_not_match( qr/<input name=\"comment_index/,  $html );
        $this->assert_does_not_match( qr/<input name=\"comment_anchor/, $html );
    }
    else {
        $this->assert( $html =~ /<input ([^>]*name=\"comment_index".*?)\s*\/>/i,
            $html );
        $dattrs = $1;
        $this->assert( scalar( $dattrs =~ s/\s*name=\"comment_index\"//io ),
            $dattrs );
        $this->assert( scalar( $dattrs =~ s/\s*type=\"hidden\"//io ), $dattrs );
        $this->assert( scalar( $dattrs =~ s/\s*value=\"(.*?)\"//io ), $dattrs );
        $this->assert_str_equals( $eidx, $1 );
        $this->assert_str_equals( "",    trim($dattrs) );
        $this->assert_does_not_match( qr/<input name=\"comment_anchor/, $html );
        $this->assert_does_not_match( qr/<input name=\"comment_location/,
            $html );
    }

    $this->assert( $html =~ s/<input ([^>]*name=\"comment_action\".*?)\s*\/>//,
        $html );
    $dattrs = $1;
    $this->assert( $dattrs =~ s/name=\"comment_action\"//i, $dattrs );
    $this->assert( scalar( $dattrs =~ s/\s*type=\"hidden\"//io ), $dattrs );
    $this->assert( scalar( $dattrs =~ s/\s*value=\"save\"//io ),  $dattrs );
    $this->assert_str_equals( "", trim($dattrs) );
    $html =~ s/<textarea (.*?)>(.*?)<\/textarea>//i;
    $dattrs = $1;
    $this->assert_matches( qr/name=\"comment\"/, $dattrs );
    my $mess = $2;
    $this->assert_str_equals( "The Message", $mess );
    $this->assert_matches( qr/<input\s+\s*type="submit"\s*value=\".*?"\s*\/>/i,
        $html );

    # Compose the query
    my $comm  = "This is the comment";
    my $query = Unit::Request->new(
        {
            'comment_action' => 'save',
            'comment_type'   => $type,
            'comment'        => $comm,
        }
    );
    $query->path_info("/$web/$topic");
    if ($anchor) {
        $query->param( -name => 'comment_anchor', -value => $anchor );
    }
    elsif ($location) {
        $query->param( -name => 'comment_location', -value => $location );
    }
    else {
        $query->param( -name => 'comment_index', -value => $eidx );
    }

    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLoginName},
        $query );
    my $text = "Ignore this text";

    # invoke the save handler
    $this->captureWithKey( save => $this->getUIFn('save'), $this->{session} );

    $text = Foswiki::Func::readTopicText( $web, $topic );
    $this->assert_matches( qr/$comm/, $text, "$web.$topic: $text" );

    #uncomment this to debug what the actual output looks like.
    #$this->assert_str_equals($sample, $text);

    my $refexpr;
    if ($anchor) {
        $refexpr = $anchor;
    }
    elsif ($location) {
        $refexpr = $location;
    }
    else {
        $refexpr = $commentref;
    }

    if ( $topic eq $this->{test_topic} && $web eq $this->{test_web} ) {
        if ( $type eq "top" ) {
            $this->assert_matches( qr/^$comm.*^TopOfTopic/ms, $text );
        }
        elsif ( $type eq "bottom" ) {
            $this->assert_matches( qr/^BottomOfTopic.*^$comm/ms, $text );
        }
        elsif ( $type eq "above" ) {
            $this->assert_matches( qr/^TopOfTopic.*^$comm.*$refexpr/ms, $text );
        }
        elsif ( $type eq "below" ) {
            $this->assert_matches( qr/$refexpr.*$comm.*^BottomOfTopic/ms,
                $text );
        }
    }

    return;
}

sub test_above {
    my $this = shift;
    $this->inputTest( "above", undef, undef, undef, undef, 0 );

    return;
}

sub test_below {
    my $this = shift;
    $this->inputTest( "below", undef, undef, undef, undef, 0 );

    return;
}

sub test_targetTopic {
    my $this = shift;
    $this->inputTest( "bottom", undef, $this->{target_topic}, undef, undef, 0 );

    return;
}

sub test_targetWebTopic {
    my $this = shift;
    $this->inputTest( "bottom", $this->{target_web}, $this->{target_topic},
        undef, undef, 0 );

    return;
}

sub test_targetWebTopicAnchorTop {
    my $this = shift;
    $this->inputTest( "top", $this->{target_web}, $this->{target_topic},
        "TargetAnchor", undef, 0 );

    return;
}

sub test_targetWebTopicAnchorBottom {
    my $this = shift;
    $this->inputTest( "bottom", $this->{target_web}, $this->{target_topic},
        "TargetAnchor", undef, 0 );

    return;
}

sub test_location {
    my $this = shift;
    $this->inputTest( "below", undef, undef, undef, "HereIsTheLocation", 0 );

    return;
}

sub test_LocationRE {
    my $this = shift;

    $this->inputTest( "above", undef, undef, undef, "^He.*on\$", 0 );

    return;
}

sub test_reverseCompat {
    my $this = shift;

# rows: Any number > 0 will set the rows of the text area (default is 5)
# cols: Any number > 10 will set the columns of the textarea (default is 70)
# mode: The word "after" tells Comment to put the posted data after the form in reverse chronological order (default = "normal" chronological order)
# button: This lets you change the text of the submit button (default is "Add Comment")
# id: This gives a unique name for a COMMENT, in case you have more than one COMMENT tag in a topic (mandatory with > 1 COMMENT)

    my $pidx = 0;
    my $html = Foswiki::Plugins::CommentPlugin::Comment::_handleInput(
        "rows=99 cols=104 mode=after button=HoHo id=sausage",
        , $this->{test_topic}, $this->{test_web}, \$pidx, "The Message", "",
        "bottom" );
    $html = removeEscapes($html);
    $this->assert_matches( qr/form [^>]*name=\"after0\"/,        $html );
    $this->assert_matches( qr/rows=\"99\"/,                      $html );
    $this->assert_matches( qr/cols=\"104\"/,                     $html );
    $this->assert_matches( qr/type=\"submit\"\s+value=\"HoHo\"/, $html );

    return;
}

sub test_locationOverridesAnchor {
    my $this = shift;
    my $pidx = 0;
    my $html = Foswiki::Plugins::CommentPlugin::Comment::_handleInput(
        "target=\"$this->{test_web}.ATopic#AAnchor\" location=\"AnRE\"",
        $this->{test_topic},
        $this->{test_web},
        \$pidx,
        "The Message",
        "",
        "bottom"
    );
    $this->assert_matches( qr/<input ([^>]*name="comment_location".*?)\s*\/>/,
        $html );

    return;
}

sub test_nopost {
    my $this = shift;

    my $sample = <<"HERE";
before
%COMMENT{nopost="on"}%
after
HERE
    $this->writeTopic( $this->{test_web}, $this->{test_topic}, $sample );
    my $pidx = 0;
    my $html =
      Foswiki::Plugins::CommentPlugin::Comment::_handleInput( 'nopost="on"',
        $this->{test_web}, $this->{test_topic}, \$pidx, "The Message", "",
        "bottom" );
    $this->assert_matches(
        qr/<input type="hidden" name="comment_nopost" value="on"/, $html );

    # Compose the query
    my $comm  = "This is the comment";
    my $query = Unit::Request->new(
        {
            'comment_action' => 'save',
            'comment_type'   => 'above',
            'comment'        => $comm,
            'comment_nopost' => 'on',
        }
    );
    $query->path_info("/$this->{test_web}/$this->{test_topic}");

    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLoginName},
        $query );
    my $text = "Ignore this text";

    # invoke the save handler
    $this->captureWithKey( save => $this->getUIFn('save'), $this->{session} );

    $text =
      Foswiki::Func::readTopicText( $this->{test_web}, $this->{test_topic} );

    # make sure it hasn't changed
    $text =~ s/^%META.*?\n//gm;
    $this->assert_str_equals( $sample, $text );

    return;
}

sub test_remove {
    my $this = shift;

    my $sample = <<"HERE";
before
%COMMENT{remove="on"}%
after
HERE
    $this->writeTopic( $this->{test_web}, $this->{test_topic}, $sample );
    my $pidx = 99;
    my $html =
      Foswiki::Plugins::CommentPlugin::Comment::_handleInput( 'remove="on"',
        $this->{test_web}, $this->{test_topic}, \$pidx, "The Message", "",
        "bottom" );
    $this->assert_matches(
        qr/<input type="hidden" name="comment_remove" value="99"/, $html );

    # Compose the query
    my $comm  = "This is the comment";
    my $query = Unit::Request->new(
        {
            'comment_action' => 'save',
            'comment_type'   => 'above',
            'comment'        => $comm,
            'comment_remove' => '0',
            'comment_index'  => '99',
        }
    );
    $query->path_info("/$this->{test_web}/$this->{test_topic}");

    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLoginName},
        $query );
    my $text = "Ignore this text";

    # invoke the save handler
    $this->captureWithKey( save => $this->getUIFn('save'), $this->{session} );

    $text =
      Foswiki::Func::readTopicText( $this->{test_web}, $this->{test_topic} );

    # make sure it hasn't changed
    $text =~ s/^%META.*?\n//gm;
    $this->assert_str_equals(
        <<'HERE',
before

after
HERE
        $text
    );

    return;
}

sub test_default {
    my $this   = shift;
    my $sample = <<'HERE';
before
%COMMENT{remove="on"}%
after
HERE
    $this->writeTopic( $this->{test_web}, $this->{test_topic}, $sample );
    my $pidx = 99;
    my $html = Foswiki::Plugins::CommentPlugin::Comment::_handleInput(
        'default="wibble"', $this->{test_web}, $this->{test_topic}, \$pidx,
        undef, "", "bottom" );
    $this->assert_matches( qr#>wibble</textarea>#, $html );

    return;
}

sub verify_targetWebTopicAboveAnchor_Missing_Item727 {
    my $this = shift;

    my $sample = <<'HERE';
before
%COMMENT{type="above" cols="100" target="%INCLUDINGTOPIC%#LatestComment"}%
after
HERE
    $this->writeTopic( $this->{test_web}, $this->{test_topic}, $sample );
    my $pidx = 99;

    my $message = "The Message";
    my $disable = '';
    if ( Foswiki::Func::getContext()->{static} ) {
        $message = "(Static view)";
        $disable = 'disabled';
    }

    my $html =
      Foswiki::Plugins::CommentPlugin::Comment::_handleInput( 'remove="on"',
        $this->{test_web}, $this->{test_topic}, \$pidx, $message, $disable,
        "bottom" );
    if ( Foswiki::Func::getContext()->{static} ) {
        $this->assert_matches(
            qr/\(Static view\)<\/textarea><\/td><td>&nbsp;<input disabled/,
            $html );
    }
    else {
        $this->assert_matches(
            qr/<input type="hidden" name="comment_remove" value="99"/, $html );
    }

    # Compose the query
    my $comm  = "This is the comment";
    my $query = Unit::Request->new(
        {
            'comment_action' => 'save',
            'comment_type'   => 'above',
            'comment'        => $comm,
            'comment_anchor' => '#LatestComment',
        }
    );
    $query->path_info("/$this->{test_web}/$this->{test_topic}");

    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLoginName},
        $query );
    my $text = "Ignore this text";

    # invoke the save handler
    $this->captureWithKey( save => $this->getUIFn('save'), $this->{session} );

    $text =
      Foswiki::Func::readTopicText( $this->{test_web}, $this->{test_topic} );

    # make sure it hasn't changed
    $text =~ s/^%META.*?\n//gm;
    $text = removeEscapes($text);
    my $date = Foswiki::Time::formatTime( time(), '$day $mon $year' );
    $this->assert_str_equals( <<"HERE", $text );
before


This is the comment

-- TemporaryCommentPluginTestsUsersWeb.WikiGuest - $date
%COMMENT{type="above" cols="100" target="%INCLUDINGTOPIC%#LatestComment"}%
after
HERE

    return;
}

sub verify_targetWebTopicBelowAnchor_Missing_Item727 {
    my $this = shift;

    my $sample = <<'HERE';
before
%COMMENT{type="below" target="%INCLUDINGTOPIC%#LatestComment"}%
after
HERE
    $this->writeTopic( $this->{test_web}, $this->{test_topic}, $sample );
    my $pidx = 99;

    my $message = "The Message";
    my $disable = '';
    if ( Foswiki::Func::getContext()->{static} ) {
        $message = "(Static view)";
        $disable = 'disabled';
    }

    my $html =
      Foswiki::Plugins::CommentPlugin::Comment::_handleInput( 'remove="on"',
        $this->{test_web}, $this->{test_topic}, \$pidx, $message, $disable,
        "bottom" );
    $html = removeEscapes($html);
    if ( Foswiki::Func::getContext()->{static} ) {
        $this->assert_matches(
            qr/\(Static view\)<\/textarea><\/td><td>&nbsp;<input disabled/,
            $html );
    }
    else {
        $this->assert_matches(
            qr/<input type="hidden" name="comment_remove" value="99"/, $html );
    }

    # Compose the query
    my $comm  = "This is the comment";
    my $query = Unit::Request->new(
        {
            'comment_action' => 'save',
            'comment_type'   => 'below',
            'comment'        => $comm,
            'comment_anchor' => '#LatestComment',

        }
    );
    $query->path_info("/$this->{test_web}/$this->{test_topic}");

    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLoginName},
        $query );
    my $text = "Ignore this text";

    # invoke the save handler
    $this->captureWithKey( save => $this->getUIFn('save'), $this->{session} );

    $text =
      Foswiki::Func::readTopicText( $this->{test_web}, $this->{test_topic} );

    # make sure it hasn't changed
    $text =~ s/^%META.*?\n//gm;
    $text = removeEscapes($text);
    my $date = Foswiki::Time::formatTime( time(), '$day $mon $year' );
    $this->assert_str_equals(
        <<"HERE",
before
%COMMENT{type="below" target="%INCLUDINGTOPIC%#LatestComment"}%
   * This is the comment -- TemporaryCommentPluginTestsUsersWeb.WikiGuest - $date
after
HERE
        $text
    );

    return;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
