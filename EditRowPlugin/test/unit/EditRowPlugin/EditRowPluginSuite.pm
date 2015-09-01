# See bottom of file for license and copyright information
package EditRowPluginSuite;

use strict;
use warnings;
use FoswikiFnTestCase;
our @ISA = 'FoswikiFnTestCase';

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
}

sub loadExtraConfig {
    my $this = shift;

    $this->SUPER::loadExtraConfig();
}

sub test_Item13352_unbalanced_verbatim {
    my $this = shift;
    my $in   = <<INPUT;
   * Set ENDCOLOR = </span></verbatim>
%RED%Some red text%ENDCOLOR%

| A | B |
%EDITTABLE{ format="| text, 5, init | text, 20, init |"
fool="cap"
}%
| A | B |

| A | B |
INPUT
    require Foswiki::Plugins::EditRowPlugin::TableParser;
    $this->assert( !$@, $@ );
    my $parser = Foswiki::Plugins::EditRowPlugin::TableParser->new();
    my $result = $parser->parse( $in, $this->{test_topicObject} );

    my $data = '';
    foreach my $r (@$result) {
        if ( ref($r) ) {
            $data .= $r->getID . ":\n" . $r->stringify();
        }
        else {
            $data .= "LL $r\n";
        }
    }
    $this->assert_equals( <<'EXPECTED', $data );
LL    * Set ENDCOLOR = </span></verbatim>
LL %RED%Some red text%ENDCOLOR%
LL 
TABLE_0:
| A | B |
TABLE_1:
%EDITTABLE{ format="| text, 5, init | text, 20, init |"
fool="cap"
}%
| A | B |
LL 
TABLE_2:
| A | B |
EXPECTED
}

sub test_parser {
    my $this = shift;
    my $in   = <<INPUT;
| A | B |
%EDITTABLE{ format="| text, 5, init | text, 20, init |"
fool="cap"
}%
| A | B |

| A | B |
INPUT
    require Foswiki::Plugins::EditRowPlugin::TableParser;
    $this->assert( !$@, $@ );
    my $parser = Foswiki::Plugins::EditRowPlugin::TableParser->new();
    my $result = $parser->parse( $in, $this->{test_topicObject} );

    my $data = '';
    foreach my $r (@$result) {
        if ( ref($r) ) {
            $data .= $r->getID . ":\n" . $r->stringify();
        }
        else {
            $data .= "LL $r\n";
        }
    }
    $this->assert_equals( <<'EXPECTED', $data );
TABLE_0:
| A | B |
TABLE_1:
%EDITTABLE{ format="| text, 5, init | text, 20, init |"
fool="cap"
}%
| A | B |
LL 
TABLE_2:
| A | B |
EXPECTED
}

sub test_simple_view {
    my $this = shift;
    require Foswiki::Plugins::EditRowPlugin::View;
    $this->assert( !$@, $@ );
    $this->{test_topicObject}->finish() if $this->{test_topicObject};
    $this->{session}->finish()          if $this->{session};
    my $query = Unit::Request->new( {} );
    $this->{session} =
      Foswiki->new( $this->{test_user_login}, $query, { view => 1 } );
    ( $this->{test_topicObject} ) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );

    my $in = <<INPUT;
%EDITTABLE%
| A |
INPUT
    $this->assert(
        Foswiki::Plugins::EditRowPlugin::View::process(
            $in,                 $this->{test_web},
            $this->{test_topic}, $this->{test_topicObject}
        )
    );
    $this->assert( $in =~ s/<!-- STARTINCLUDE.*?-->\s*(.*)\s*<!--.*/$1/s, $in );

    $this->assert( $in =~ s/^(<form[^>]*>)\s*(.*?)<\/form>$/$2/s, $in );

    my $f = $1;
    $f =~ s/action=(["']).*?\1/action="valid"/;
    $this->assert_html_equals( <<HTML, "$f</form>" );
<form method="POST" action="valid" name="erp_form_TABLE_0"></form>
HTML

    # anchor
    $this->assert( $in =~ s/^<a name=(['"])erp_TABLE_0\1><\/a>\s*//s, $in );

    # edit button
    $this->assert( $in =~ s/(<a name=(['"])erp_TABLE_0\2>.*)$//s, $in );
    my $viewurl = Foswiki::Func::getScriptUrl(
        $this->{test_web}, $this->{test_topic}, "view",
        erp_topic => "$this->{test_web}.$this->{test_topic}",
        erp_table => "TABLE_0",
        erp_row   => -1,
        '#'       => "erp_TABLE_0"
    );
    my $expected = <<EXPECTED;
<a name='erp_TABLE_0'></a><a href='$viewurl' title='Edit full table'><button type="button" name="erp_edit_TABLE_0" title="Edit full table" class="erp-edittable"></button></a><br />
EXPECTED
    $this->assert_html_equals( $expected, $1 );
    $in =~ s/&quot;1_\d+&quot;/&quot;VERSION&quot;/gs;
    $in =~ s/version=1_\d+/version=VERSION/gs;
    my $loadurl = Foswiki::Func::getScriptUrl(
        "EditRowPlugin", "get", "rest",
        erp_version => "VERSION",
        erp_topic   => "$this->{test_web}.$this->{test_topic}",
        erp_table   => "TABLE_0",
        erp_row     => 0,
        erp_col     => 0
    );
    $viewurl = Foswiki::Func::getScriptUrl(
        $this->{test_web}, $this->{test_topic}, "view",
        erp_topic => "$this->{test_web}.$this->{test_topic}",
        erp_table => "TABLE_0",
        erp_row   => 0,
        '#'       => "erp_TABLE_0_0"
    );
    $this->assert( $in =~ s/(data-erp-tabledata)=(["'])(.*?)\2/$1/, $in );
    my $a_tabledata = JSON::from_json( HTML::Entities::decode_entities($3) );
    $this->assert( $in =~ s/(data-erp-trdata)=(["'])(.*?)\2/$1/, $in );
    my $a_trdata = JSON::from_json( HTML::Entities::decode_entities($3) );
    $this->assert( $in =~ s/(data-erp-data)=(["'])(.*?)\2/$1/, $in );
    my $a_celldata = JSON::from_json( HTML::Entities::decode_entities($3) );

    $expected = <<EXPECTED;
|<a href='$viewurl' class='erpJS_willDiscard ui-icon ui-icon-pencil' title="Edit this row">edit</a>| <div class="erpJS_cell" data-erp-data="data-erp-data" data-erp-trdata="data-erp-trdata" data-erp-tabledata="data-erp-tabledata"> A </div> <a name="erp_TABLE_0_0"></a> |
EXPECTED
    $this->assert_html_equals( $expected, $in );

    my $e_tabledata = {
        version => $a_tabledata->{version} || "VERSION",
        topic   => "$this->{test_web}.$this->{test_topic}",
        table   => "TABLE_0"
    };

    my $e_trdata = { row => 0 };

    my $e_celldata = {
        width   => "20em",
        loadurl => $loadurl,
        submit =>
'<button class="ui-icon ui-icon-disk erp-button" type="submit"></button>',
        name => "CELLDATA",
        type => "text",
        col  => 0,
        size => 20
    };
    $this->assert_deep_equals( $e_tabledata, $a_tabledata );
    $this->assert_deep_equals( $e_trdata,    $a_trdata );
    $this->assert_deep_equals( $e_celldata,  $a_celldata );
}

sub test_Item12953 {
    my $this = shift;
    require Foswiki::Plugins::EditRowPlugin::View;
    $this->assert( !$@, $@ );
    $this->{test_topicObject}->finish() if $this->{test_topicObject};
    $this->{session}->finish()          if $this->{session};
    my $query = Unit::Request->new( {} );
    $this->{session} =
      Foswiki->new( $this->{test_user_login}, $query, { view => 1 } );
    ( $this->{test_topicObject} ) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );

    my $in = <<INPUT;
%EDITTABLE{
   format="| row,1 | text,20,init |"
   header="|*Nr*|*Text*|"
}%
INPUT
    $this->assert(
        Foswiki::Plugins::EditRowPlugin::View::process(
            $in,                 $this->{test_web},
            $this->{test_topic}, $this->{test_topicObject}
        )
    );
    $this->assert( $in =~ s/<!-- STARTINCLUDE.*?-->\s*(.*)\s*<!--.*/$1/s, $in );

    $this->assert( $in =~ s/^(<form[^>]*>)\s*(.*?)<\/form>$/$2/s, $in );

    my $f = $1;
    $f =~ s/action=(["']).*?\1/action="valid"/;
    $this->assert_html_equals( <<HTML, "$f</form>" );
<form method="POST" action="valid" name="erp_form_TABLE_0"></form>
HTML

    # anchor
    $this->assert( $in =~ s/^<a name=(["'])erp_TABLE_0\1><\/a>\s*//s, $in );

    # edit button
    $this->assert( $in =~ s/(<a name=(['"])erp_TABLE_0\2>.*)$//s, $in );
    my $viewurl = Foswiki::Func::getScriptUrl(
        $this->{test_web}, $this->{test_topic}, "view",
        erp_topic => "$this->{test_web}.$this->{test_topic}",
        erp_table => "TABLE_0",
        erp_row   => -1,
        '#'       => "erp_TABLE_0"
    );
    my $expected = <<EXPECTED;
<a name='erp_TABLE_0'></a><a href='$viewurl' title='Edit full table'><button type="button" name="erp_edit_TABLE_0" title="Edit full table" class="erp-edittable"></button></a><br />
EXPECTED
    $this->assert_html_equals( $expected, $1 );
    $in =~ s/&quot;1_\d+&quot;/&quot;VERSION&quot;/gs;
    $in =~ s/version=1_\d+/version=VERSION/gs;
}

# Default is JS preferred
sub test_edit_view_default {
    my $this = shift;
    require Foswiki::Plugins::EditRowPlugin::View;
    $this->assert( !$@, $@ );
    $this->{test_topicObject}->finish() if $this->{test_topicObject};
    $this->{session}->finish()          if $this->{session};
    my $query = Unit::Request->new(
        {
            erp_topic => "$this->{test_web}.$this->{test_topic}",
            erp_table => 'TABLE_0'
        }
    );
    $this->{session} =
      Foswiki->new( $this->{test_user_login}, $query, { view => 1 } );
    ( $this->{test_topicObject} ) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );

    my $in = <<INPUT;
%EDITTABLE%
| A |
INPUT
    $this->assert(
        Foswiki::Plugins::EditRowPlugin::View::process(
            $in,                 $this->{test_web},
            $this->{test_topic}, $this->{test_topicObject}
        )
    );
    $this->assert( $in =~ s/<!-- STARTINCLUDE.*?-->\s*(.*)\s*<!--.*/$1/s, $in );
    $in =~ s/\b\d_\d{10}\b/VERSION/gs;
    $in =~ s/#\07(\d+)\07#/#REF$1#/g;
    my $viewurl = Foswiki::Func::getScriptUrl(
        $this->{test_web}, $this->{test_topic}, "view",
        erp_topic => "$this->{test_web}.$this->{test_topic}",
        erp_table => "TABLE_0",
        erp_row   => -1,
        '#'       => "erp_TABLE_0"
    );
    my $saveurl = Foswiki::Func::getScriptUrl(
        "EditRowPlugin", "save", "rest",
        erp_version => "VERSION",
        erp_topic   => "$this->{test_web}.$this->{test_topic}",
        erp_table   => "TABLE_0"
    );
    my $expected = <<EXPECTED;
<form method="POST" action="$saveurl" name="erp_form_TABLE_0">
<input type="hidden" name="erp_topic" value="$this->{test_web}.$this->{test_topic}"  /><input type="hidden" name="erp_version" value="VERSION"  /><input type="hidden" name="erp_table" value="TABLE_0"  /><input type="hidden" name="erp_row" value="0"  />
<a name='erp_TABLE_0'></a>
<input type="hidden" name="erp_TABLE_0_format" value=""  />
| #REF0# |
<input type="hidden" name="erp_action" value=""  />
<button type="submit" name="erp_action" value="saveTableCmd" title="Save" class="ui-icon ui-icon-disk erp-button" />
<button type="submit" name="erp_action" value="cancelCmd" title="Cancel" class="ui-icon ui-icon-cancel erp-button" />
<button class="ui-icon ui-icon-plusthick erp-button" name="erp_action" title="Add new row after this row / at the end" type="submit" value="addRowCmd" />
<button class="ui-icon ui-icon-minusthick erp-button" name="erp_action" title="Delete this row / last row" type="submit" value="deleteRowCmd" />
</form>
EXPECTED
    $this->assert_html_equals( $expected, $in );
}

sub test_edit_view_no_js {
    my $this = shift;
    require Foswiki::Plugins::EditRowPlugin::View;
    $this->assert( !$@, $@ );
    $this->{test_topicObject}->finish() if $this->{test_topicObject};
    $this->{session}->finish()          if $this->{session};
    my $query = Unit::Request->new(
        {
            erp_topic => "$this->{test_web}.$this->{test_topic}",
            erp_table => 'TABLE_0'
        }
    );
    $this->{session} =
      Foswiki->new( $this->{test_user_login}, $query, { view => 1 } );
    ( $this->{test_topicObject} ) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );

    my $in = <<INPUT;
%EDITTABLE{js="ignore"}%
| A |
INPUT
    $this->assert(
        Foswiki::Plugins::EditRowPlugin::View::process(
            $in,                 $this->{test_web},
            $this->{test_topic}, $this->{test_topicObject}
        )
    );
    $this->assert( $in =~ s/<!-- STARTINCLUDE.*?-->\s*(.*)\s*<!--.*/$1/s, $in );
    $in =~ s/\b\d_\d{10}\b/VERSION/gs;
    $in =~ s/#\07(\d+)\07#/#REF$1#/g;
    my $viewurl = Foswiki::Func::getScriptUrl(
        $this->{test_web}, $this->{test_topic}, "view",
        erp_topic => "$this->{test_web}.$this->{test_topic}",
        erp_table => "TABLE_0",
        erp_row   => -1,
        '#'       => "erp_TABLE_0"
    );
    my $saveurl = Foswiki::Func::getScriptUrl(
        "EditRowPlugin", "save", "rest",
        erp_version => "VERSION",
        erp_topic   => "$this->{test_web}.$this->{test_topic}",
        erp_table   => "TABLE_0"
    );
    Foswiki::Plugins::EditRowPlugin::postRenderingHandler($in);
    my $expected = <<EXPECTED;
<form method="POST" action="$saveurl" name="erp_form_TABLE_0">
<input type="hidden" name="erp_topic" value="$this->{test_web}.$this->{test_topic}"  /><input type="hidden" name="erp_version" value="VERSION"  /><input type="hidden" name="erp_table" value="TABLE_0"  /><input type="hidden" name="erp_row" value="0"  />
<a name='erp_TABLE_0'></a>
<input type="hidden" name="erp_TABLE_0_format" value=""  />
| #REF0# |
<input type="hidden" name="erp_action" value=""  />
<button class="ui-icon ui-icon-disk erp-button" name="erp_action" title="Save" type="submit" value="saveTableCmd"/>
<button class="ui-icon ui-icon-cancel erp-button" name="erp_action" title="Cancel" type="submit" value="cancelCmd"/>
<button class="ui-icon ui-icon-plusthick erp-button" name="erp_action" title="Add new row after this row / at the end" type="submit" value="addRowCmd">
</button>
<button class="ui-icon ui-icon-minusthick erp-button" name="erp_action" title="Delete this row / last row" type="submit" value="deleteRowCmd">
</button>
</form>
EXPECTED
    $this->assert_html_equals( $expected, $in );
}

sub gettit {
    my ( $this, $t, $r, $c ) = @_;
    $this->{session}->finish();
    my %qd = (
        erp_version => "VERSION",
        erp_topic   => "$this->{test_web}.$this->{test_topic}",
        erp_table   => "TABLE_$t"
    );
    $qd{erp_row} = $r if defined $r;
    $qd{erp_col} = $c if defined $c;
    my $query = Unit::Request->new( \%qd );
    $this->{session} = Foswiki->new( $this->{test_user_login}, $query );
    my $response = Foswiki::Response->new();
    $this->assert_null(
        Foswiki::Plugins::EditRowPlugin::Get::process(
            $this->{session}, "EditRowPlugin", "get", $response
        )
    );
    return $response->body();
}

sub test_rest_get {
    my $this = shift;
    require Foswiki::Plugins::EditRowPlugin::Get;
    $this->assert( !$@, $@ );

    $this->{test_topicObject}->finish() if $this->{test_topicObject};
    ( $this->{test_topicObject} ) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $this->{test_topicObject}->text(<<INPUT);
| 1 |

| A | B |
| C | D |
INPUT
    $this->{test_topicObject}->save();
    $this->{test_topicObject}->finish();
    $this->{session}->finish();

    $this->assert_equals( '"1"', $this->gettit( 0, 0, 0 ) );

    $this->assert_equals( '"A"', $this->gettit( 1, 0, 0 ) );
    $this->assert_equals( '"B"', $this->gettit( 1, 0, 1 ) );
    $this->assert_equals( '"C"', $this->gettit( 1, 1, 0 ) );
    $this->assert_equals( '"D"', $this->gettit( 1, 1, 1 ) );
    $this->assert_equals( '["A","B"]', $this->gettit( 1, 0 ) );
    $this->assert_equals( '["C","D"]', $this->gettit( 1, 1 ) );
    $this->assert_equals( '["A","C"]', $this->gettit( 1, undef, 0 ) );
    $this->assert_equals( '["B","D"]', $this->gettit( 1, undef, 1 ) );
    $this->assert_equals( '[["A","B"],["C","D"]]', $this->gettit(1) );

    #$this->assert_equals( '"C"', $this->gettit( 1, -1, 0 ) );
    #$this->assert_equals( '"D"', $this->gettit( 1, -1, -1 ) );
}

sub test_rest_save {
    my $this = shift;
    require Foswiki::Plugins::EditRowPlugin::Save;
    $this->assert( !$@, $@ );
    $this->{test_topicObject}->finish() if $this->{test_topicObject};
    ( $this->{test_topicObject} ) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $this->{test_topicObject}->text(<<INPUT);
| 1 |

| A | B |
| C | D |
INPUT
    $this->{test_topicObject}->save();
    $this->{test_topicObject}->finish();
    $this->{session}->finish();

    my %qd = (
        CELLDATA    => "Spitoon",
        erp_action  => "saveCellCmd",
        erp_col     => 0,
        erp_row     => 0,
        erp_version => "VERSION",
        erp_topic   => "$this->{test_web}.$this->{test_topic}",
        erp_table   => "TABLE_1",
        noredirect  => 1,                                         # for AJAX
    );
    my $query = Unit::Request->new( \%qd );
    $this->{session} = Foswiki->new( $this->{test_user_login}, $query );
    my $response = Foswiki::Response->new();
    $this->assert_null(
        Foswiki::Plugins::EditRowPlugin::Save::process(
            $this->{session}, "EditRowPlugin", "save", $response
        )
    );
    $this->assert_equals( "RESPONSESpitoon", $response->body() );
    $this->{test_topicObject}->finish() if $this->{test_topicObject};
    ( $this->{test_topicObject} ) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    my $expected = <<EXPECTED;
| 1 |

| Spitoon | B |
| C | D |
EXPECTED
    $this->assert_equals( $expected, $this->{test_topicObject}->text() );
}

sub test_parser_no_table {
    my $this = shift;
    my $in   = <<INPUT;
%EDITTABLE{ format="| text, 5, init | text, 20, init |"
fool="cap"
}%
INPUT
    require Foswiki::Plugins::EditRowPlugin::TableParser;
    $this->assert( !$@, $@ );
    my $parser = Foswiki::Plugins::EditRowPlugin::TableParser->new();
    my $result = $parser->parse( $in, $this->{test_topicObject} );

    my $data = '';
    foreach my $r (@$result) {
        if ( ref($r) ) {
            $data .= $r->getID . ":\n" . $r->stringify();
        }
        else {
            $data .= "LL $r\n";
        }
    }
    $this->assert_equals( <<'EXPECTED', $data );
TABLE_0:
%EDITTABLE{ format="| text, 5, init | text, 20, init |"
fool="cap"
}%
EXPECTED
}

1;
