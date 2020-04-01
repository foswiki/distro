# See bottom of file for license and copyright information
package ERP_HTML;

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
    $Foswiki::cfg{Plugins}{EditRowPlugin}{Enabled}   = 1;
    $Foswiki::cfg{Plugins}{EditRowPlugin}{Macro}     = 'EDITTABLE';
    $Foswiki::cfg{Plugins}{EditTablePlugin}{Enabled} = 0;
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

    $this->assert( $in =~ s/^\s*(<form[^>]*>)\s*(.*?)<\/form>$/$2/s, $in );

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
<a name='erp_TABLE_0'></a><a class='erp-edittable' href='$viewurl' name='erp_edit_TABLE_0' title='Edit full table'></a><br />
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
| <div class="erpJS_cell" data-erp-data="data-erp-data" data-erp-trdata="data-erp-trdata" data-erp-tabledata="data-erp-tabledata"> A </div> <a name="erp_TABLE_0_0"></a> |<a href='$viewurl' class='erpJS_willDiscard ui-icon ui-icon-pencil' title="Edit this row">edit</a>|
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
"<button class='ui-icon ui-icon-disk erp-button' type='submit'></button>",
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
    $this->assert( $in =~ s/\s*<!-- STARTINCLUDE.*?-->\s*(.*)\s*<!--.*/$1/s,
        $in );

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
<a name='erp_TABLE_0'></a><a class='erp-edittable' href='$viewurl' name='erp_edit_TABLE_0' title='Edit full table'></a><br />
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

        # SMELL: Item13672 - POST with querystring duplicates the Form input
        #        erp_version => "VERSION",
        #        erp_topic   => "$this->{test_web}.$this->{test_topic}",
        #        erp_table   => "TABLE_0"
    );
    my $expected = <<EXPECTED;
<form action='$saveurl' method='POST' name='erp_form_TABLE_0'>
<input name='erp_topic' type='hidden' value='$this->{test_web}.$this->{test_topic}'></input>
<input name='erp_version' type='hidden' value='VERSION'></input>
<input name='erp_table' type='hidden' value='TABLE_0'></input>
<input name='erp_row' type='hidden' value='0'></input>
<a name='erp_TABLE_0'></a>
<input name='erp_TABLE_0_format' type='hidden' value=''></input>
| #REF0# |
<input name='erp_action' type='hidden' value=''></input>
<button class='ui-icon ui-icon-disk erp-button' name='erp_action' title='Save' type='submit' value='saveRowCmd'></button>
<button class='ui-icon ui-icon-cancel erp-button' name='erp_action' title='Cancel' type='submit' value='cancelCmd'></button>
<button class='ui-icon ui-icon-plusthick erp-button' name='erp_action' title='Add new row after this row / at the end' type='submit' value='addRowCmd'></button>
<button class='ui-icon ui-icon-minusthick erp-button' name='erp_action' title='Delete this row / last row' type='submit' value='deleteRowCmd'></button>
<a name='erp_TABLE_0_0'></a>|

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

        # SMELL: Item13672 - POST with querystring duplicates the Form input
        #       erp_version => "VERSION",
        #       erp_topic   => "$this->{test_web}.$this->{test_topic}",
        #       erp_table   => "TABLE_0"
    );
    Foswiki::Plugins::EditRowPlugin::postRenderingHandler($in);
    my $expected = <<EXPECTED;
<form action='$saveurl' method='POST' name='erp_form_TABLE_0'>
<input name='erp_topic' type='hidden' value='$this->{test_web}.$this->{test_topic}'></input>
<input name='erp_version' type='hidden' value='VERSION'></input>
<input name='erp_table' type='hidden' value='TABLE_0'></input>
<input name='erp_row' type='hidden' value='0'></input>
<a name='erp_TABLE_0'></a>
<input name='erp_TABLE_0_format' type='hidden' value=''></input>
| #REF0# |
<input name='erp_action' type='hidden' value=''></input>
<button class='ui-icon ui-icon-disk erp-button' name='erp_action' title='Save' type='submit' value='saveRowCmd'></button>
<button class='ui-icon ui-icon-cancel erp-button' name='erp_action' title='Cancel' type='submit' value='cancelCmd'></button>
<button class='ui-icon ui-icon-plusthick erp-button' name='erp_action' title='Add new row after this row / at the end' type='submit' value='addRowCmd'></button>
<button class='ui-icon ui-icon-minusthick erp-button' name='erp_action' title='Delete this row / last row' type='submit' value='deleteRowCmd'></button>
<a name='erp_TABLE_0_0'></a>|

</form>
EXPECTED
    $this->assert_html_equals( $expected, $in );
}

1;
