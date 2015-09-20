# See bottom of file for license and copyright information
package EditTablePluginTests;
use strict;
use warnings;

# tests for basic formatting

use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use strict;
use warnings;
use Foswiki::UI::Save();
use Foswiki::Plugins::EditTablePlugin();
use Foswiki::Plugins::EditTablePlugin::Core();
use Foswiki::Plugins::EditTablePlugin::EditTableData();
use Error qw( :try );

sub new {
    my ( $class, @args ) = @_;
    return $class->SUPER::new( 'EditTableFunctions', @args );
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    #    $this->{sup} = $this->{session}->getScriptUrl(0, 'view');
    $Foswiki::cfg{AntiSpam}{RobotsAreWelcome} = 1;
    $Foswiki::cfg{AllowInlineScript} = 0;
    $Foswiki::cfg{Plugins}{TablePlugin}{DefaultAttributes} =
'tableborder="1" valign="top" headercolor="#fff" headerbg="#687684" headerbgsorted="#334455" databg="#ddd,#edf4f9" databgsorted="#f1f7fc,#ddebf6" tablerules="rows" headerrules="cols"';

    local $ENV{SCRIPT_NAME} = ''; #  required by fake sort URLs in expected text

    return;
}

=pod

trimSpaces( $text ) -> $text

Removes spaces from both sides of the text.

=cut

sub trimSpaces {

    #my $text = $_[0]

    $_[0] =~ s/^[[:space:]]+//s;    # trim at start
    $_[0] =~ s/[[:space:]]+$//s;    # trim at end

    return;
}

=pod

This formats the text up to immediately before <nop>s are removed, so we
can see the nops.

=cut

sub do_testHtmlOutput {
    my ( $this, $expected, $actual, $doRender ) = @_;
    my $session   = $this->{session};
    my $webName   = $this->{test_web};
    my $topicName = $this->{test_topic};

    if ($doRender) {
        $actual =
          Foswiki::Func::expandCommonVariables( $actual, $webName, $topicName );
        $actual = Foswiki::Func::renderText( $actual, $webName, $topicName );
    }

    # remove ever changing bgcolors from table cells
    # as well as the rules property
    # these are not important for these tests now
    $expected =~ s/bgcolor\=\"*\#[a-z0-9]{6}\"*//go;
    $actual   =~ s/bgcolor\=\"*\#[a-z0-9]{6}\"*//go;
    $expected =~ s/rules\=\"*(cols|rows|all)\"*//go;
    $actual   =~ s/rules\=\"*(cols|rows|all)\"*//go;

    $this->assert_html_equals( $expected, $actual );

    return;
}

=pod

A simple edit table in view mode, with 'before' and 'after' text.

=cut

sub test_render_simple_before_after {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      Foswiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlSystemWeb =
        Foswiki::Func::getUrlHost()
      . Foswiki::Func::getPubUrlPath() . '/'
      . $Foswiki::cfg{SystemWebName};

    my $input    = 'BEFORE %EDITTABLE{}% AFTER';
    my $expected = <<"END";
BEFORE AFTER<a name="edittable1"></a>
<div class="editTable">
<form name="edittable1" action="$viewUrlAuth#edittable1" method="post">
<input type="hidden" name="ettablenr" value="1" />
<input type="hidden" name="etedit" value="on" />
<input type="hidden" name="ettablechanges" value="" />
<input type="hidden" name="etheaderrows" value="0" />
<input type="hidden" name="etfooterrows" value="0" />
<input class="editTableEditImageButton" type="image" src="$pubUrlSystemWeb/EditTablePlugin/edittable.gif" alt="Edit this table" />
</form>
</div><!-- /editTable -->
END
    my $result =
      Foswiki::Func::expandCommonVariables( $input, $topicName, $webName );
    $this->do_testHtmlOutput( $expected, $result, 0 );

    return;
}

=pod

A simple edit table in view mode, with spaces before table lines.

=cut

sub test_render_simple_pre {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewAuthUrl =
      Foswiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlSystemWeb =
        Foswiki::Func::getUrlHost()
      . Foswiki::Func::getPubUrlPath() . '/'
      . $Foswiki::cfg{SystemWebName};

    my $input = '%EDITTABLE{}%
   | ABCDEF |
   | QWERTY |';
    my $expected = <<"END";
<a name="edittable1"></a>
<div class="editTable">
<form name="edittable1" action="$viewAuthUrl#edittable1" method="post">
<input type="hidden" name="ettablenr" value="1" />
<input type="hidden" name="etedit" value="on" />
   | ABCDEF |
   | QWERTY |
<input type="hidden" name="ettablechanges" value="" />
<input type="hidden" name="etheaderrows" value="0" />
<input type="hidden" name="etfooterrows" value="0" />
<input class="editTableEditImageButton" type="image" src="$pubUrlSystemWeb/EditTablePlugin/edittable.gif" alt="Edit this table" />
</form>
</div><!-- /editTable -->
END
    my $result =
      Foswiki::Func::expandCommonVariables( $input, $topicName, $webName );
    $this->do_testHtmlOutput( $expected, $result, 0 );

    return;
}

=pod

A simple rendered edit table.

=cut

sub test_render_simple {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      Foswiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlSystemWeb =
        Foswiki::Func::getUrlHost()
      . Foswiki::Func::getPubUrlPath() . '/'
      . $Foswiki::cfg{SystemWebName};

    my $input    = '%EDITTABLE{}%';
    my $expected = <<"END";
<a name="edittable1"></a>
<div class="editTable">
<form name="edittable1" action="$viewUrlAuth#edittable1" method="post">
<input type="hidden" name="ettablenr" value="1" />
<input type="hidden" name="etedit" value="on" />
<input type="hidden" name="ettablechanges" value="" />
<input type="hidden" name="etheaderrows" value="0" />
<input type="hidden" name="etfooterrows" value="0" />
<input class="editTableEditImageButton" type="image" src="$pubUrlSystemWeb/EditTablePlugin/edittable.gif" alt="Edit this table" />
</form>
</div><!-- /editTable -->
END
    my $result =
      Foswiki::Func::expandCommonVariables( $input, $topicName, $webName );
    $this->do_testHtmlOutput( $expected, $result, 0 );

    return;
}

=pod

Test if saving does not add newlines after the table.

=cut

sub test_do_not_add_newline {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      Foswiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlSystemWeb =
        Foswiki::Func::getUrlHost()
      . Foswiki::Func::getPubUrlPath() . '/'
      . $Foswiki::cfg{SystemWebName};

    my $input = <<'INPUT';
%EDITTABLE{}%
| *text* |

LINE
INPUT
    my $query = Unit::Request->new(
        {
            etedit    => ['on'],
            ettablenr => ['1'],
        }
    );

    $query->path_info("/$webName/$topicName");

    $this->createNewFoswikiSession( undef, $query );

    $query = Unit::Request->new(
        {
            etsave    => ['on'],
            ettablenr => ['1'],
        }
    );

    $query->path_info("/$webName/$topicName");
    $query->method('POST');

    Foswiki::Func::saveTopic( $this->{test_web}, $this->{test_topic}, undef,
        $input );

    $this->createNewFoswikiSession( undef, $query );
    my $response = Unit::Response->new();

    my ( $saveResult, $ecode ) = $this->capture(
        sub {
            $response->print(
                Foswiki::Func::expandCommonVariables(
                    $input, $this->{test_topic}, $this->{test_web}, undef
                )
            );
        }
    );

    my ( $meta, $newtext ) = Foswiki::Func::readTopic( $webName, $topicName );

    my $expected = <<'NEWEXPECTED';
%EDITTABLE{}%
| *text* |

LINE
NEWEXPECTED
    $this->assert_str_equals( $expected, $newtext, 0 );

    return;
}

=pod

param editbutton.

=cut

sub test_param_editbutton {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      Foswiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlSystemWeb =
        Foswiki::Func::getUrlHost()
      . Foswiki::Func::getPubUrlPath() . '/'
      . $Foswiki::cfg{SystemWebName};

    Foswiki::Func::saveTopic( $webName, $topicName, undef, "XXX" );

    my $input    = '%EDITTABLE{editbutton="Edit me"}%';
    my $expected = <<"END";
<a name="edittable1"></a>
<div class="editTable">
<form name="edittable1" action="$viewUrlAuth#edittable1" method="post">
<input type="hidden" name="ettablenr" value="1" />
<input type="hidden" name="etedit" value="on" />
<input type="hidden" name="ettablechanges" value="" />
<input type="hidden" name="etheaderrows" value="0" />
<input type="hidden" name="etfooterrows" value="0" />
<input class="foswikiButton editTableEditButton" type="submit" value="Edit me" />
</form>
</div><!-- /editTable -->
END
    my $result =
      Foswiki::Func::expandCommonVariables( $input, $topicName, $webName );

    $this->do_testHtmlOutput( $expected, $result, 0 );

    return;
}

=pod

Editing a simple table.

=cut

sub test_editSimple {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      Foswiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlSystemWeb =
        Foswiki::Func::getUrlHost()
      . Foswiki::Func::getPubUrlPath() . '/'
      . $Foswiki::cfg{SystemWebName};

    my $query = Unit::Request->new(
        {
            etedit    => ['on'],
            ettablenr => ['1'],
        }
    );

    my $text = <<'INPUT';
%EDITTABLE{}%
INPUT

    my $result =
      Foswiki::Func::expandCommonVariables( $text, $topicName, $webName,
        undef );

    my $expected = <<"EXPECTED";
<a name="edittable1"></a>
<div class="editTable">
<form name="edittable1" action="$viewUrlAuth#edittable1" method="post">
<input type="hidden" name="ettablenr" value="1" />
<input type="hidden" name="etedit" value="on" />
<input type="hidden" name="ettablechanges" value="" />
<input type="hidden" name="etheaderrows" value="0" />
<input type="hidden" name="etfooterrows" value="0" />
<input class="editTableEditImageButton" type="image" src="$pubUrlSystemWeb/EditTablePlugin/edittable.gif" alt="Edit this table" />
</form>
</div><!-- /editTable -->
EXPECTED

    $this->do_testHtmlOutput( $expected, $result, 0 );

    return;
}

=pod

Pass param 'format' and edit the table.

=cut

sub test_param_format_edit {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      Foswiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlSystemWeb =
      Foswiki::Func::getPubUrlPath() . '/' . $Foswiki::cfg{SystemWebName};

    my $input = <<'INPUT';
%EDITTABLE{format="| row, -1 | text, 10, init | textarea, 3x10, init | select, 3, option 1, option 2, option 3 | radio, 3, A, B, C, D, E | checkbox, 3, A, B, C, D, E | label, 0, LABEL | date,11,,%d %b %Y |"}%
INPUT

    my $query = Unit::Request->new(
        {
            etedit    => ['on'],
            ettablenr => ['1'],
        }
    );

    $query->path_info("/$webName/$topicName");

    $this->createNewFoswikiSession( undef, $query );

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web}, undef );

    my $expected = <<"EXPECTED";
%TABLE{disableallsort="on" databg="#fff"}%
<noautolink>
<a name="edittable1"></a>
<div class="editTable editTableEdit">
<form name="edittable1" action="$viewUrlAuth#edittable1" method="post">
<input type="hidden" name="ettablenr" value="1" />
<input type="hidden" name="etedit" value="on" />
| <span class="et_rowlabel">0<input type="hidden" name="etcell1x1" value="0" /></span> |<input class="foswikiInputField editTableInput" type="text" name="etcell1x2" size="10" value="--EditTableEncodeStart--.i.n.i.t--EditTableEncodeEnd--" /> | <textarea class="foswikiTextarea editTableTextarea" rows="3" cols="10" name="etcell1x3">--EditTableEncodeStart--.i.n.i.t--EditTableEncodeEnd--</textarea> | <select class="foswikiSelect" name="etcell1x4" size="3"> <option selected="selected">option 1</option> <option>option 2</option> <option>option 3</option></select> | <table class="editTableInnerTable"><tr><td valign=top><input type="radio" name="etcell1x5" value="A" /> A <br /><input type="radio" name="etcell1x5" value="B" /> B </td><td valign=top><input type="radio" name="etcell1x5" value="C" /> C <br /><input type="radio" name="etcell1x5" value="D" /> D </td><td valign=top><input type="radio" name="etcell1x5" value="E" /> E <br /></td></tr></table> | <table class="editTableInnerTable"><tr><td valign=top><input type="checkbox" name="etcell1x6x2" value="A" checked="checked" /> A <br /> <input type="checkbox" name="etcell1x6x3" value="B" checked="checked" /> B </td><td valign=top> <input type="checkbox" name="etcell1x6x4" value="C" checked="checked" /> C <br /> <input type="checkbox" name="etcell1x6x5" value="D" checked="checked" /> D </td><td valign=top> <input type="checkbox" name="etcell1x6x6" value="E" checked="checked" /> E <br /></td></tr></table><input type="hidden" name="etcell1x6" value="Chkbx: etcell1x6x2 etcell1x6x3 etcell1x6x4 etcell1x6x5 etcell1x6x6" /> | LABEL <input type="hidden" name="etcell1x7" value="--EditTableEncodeStart--.L.A.B.E.L--EditTableEncodeEnd--" /> | <nobr><input type="text" name="etcell1x8"  size="11" class="foswikiInputField editTableInput" id="idetcell1x8" /><span class="foswikiMakeVisible"><input type="image" name="calendar" src="$pubUrlSystemWeb/JSCalendarContrib/img.gif" align="middle" alt="Calendar" onclick="return showCalendar('idetcell1x8','--edittableencodestart--.%.d. .%.b. .%.y--edittableencodeend--')" class="editTableCalendarButton" /></span></nobr> |
<input type="hidden" name="ettablechanges" value="1=1" />
<input type="hidden" name="etheaderrows" value="0" />
<input type="hidden" name="etfooterrows" value="0" />
<input type="submit" name="etsave" id="etsave" value="Save table" class="foswikiSubmit" />
<input type="submit" name="etqsave" id="etqsave" value="Quiet save" class="foswikiButton" />
<input type="submit" name="etaddrow" id="etaddrow" value="Add row" class="foswikiButton" />
<input type="submit" name="etdelrow" id="etdelrow" value="Delete last row" class="foswikiButton" />
<input type="submit" name="etcancel" id="etcancel" value="Cancel" class="foswikiButtonCancel" />
</form>
</div><!-- /editTable --></noautolink>
EXPECTED
    $this->do_testHtmlOutput( lc $expected, lc $result, 0 );

    return;
}

=pod

Adding a row and saving the table.

=cut

sub test_editAddRow {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      Foswiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlSystemWeb =
        Foswiki::Func::getUrlHost()
      . Foswiki::Func::getPubUrlPath() . '/'
      . $Foswiki::cfg{SystemWebName};

    my $input = <<'INPUT';
%EDITTABLE{format="| row, -1 | text, 10, init|"}%
| 0 | init |
INPUT

    my $query = Unit::Request->new(
        {
            etedit    => ['on'],
            ettablenr => ['1'],
        }
    );

    $query->path_info("/$webName/$topicName");

    $this->createNewFoswikiSession( undef, $query );

    my $expected = '';
    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web}, undef );

    $expected = <<"EXPECTED";
%TABLE{disableallsort="on" databg="#fff"}%
<noautolink>
<a name="edittable1"></a>
<div class="editTable editTableEdit">
<form name="edittable1" action="$viewUrlAuth#edittable1" method="post">
<input type="hidden" name="ettablenr" value="1" />
<input type="hidden" name="etedit" value="on" />
| <span class="et_rowlabel">0<input type="hidden" name="etcell1x1" value="0" /></span> | <input class="foswikiInputField editTableInput" type="text" name="etcell1x2" size="10" value="--EditTableEncodeStart--.i.n.i.t--EditTableEncodeEnd--" /> |
<input type="hidden" name="ettablechanges" value="1=0" />
<input type="hidden" name="etheaderrows" value="0" />
<input type="hidden" name="etfooterrows" value="0" />
<input type="submit" name="etsave" id="etsave" value="Save table" class="foswikiSubmit" />
<input type="submit" name="etqsave" id="etqsave" value="Quiet save" class="foswikiButton" />
<input type="submit" name="etaddrow" id="etaddrow" value="Add row" class="foswikiButton" />
<input type="submit" name="etdelrow" id="etdelrow" value="Delete last row" class="foswikiButton" />
<input type="submit" name="etcancel" id="etcancel" value="Cancel" class="foswikiButtonCancel" />
</form>
</div><!-- /editTable --></noautolink>
EXPECTED

    $this->do_testHtmlOutput( $expected, $result, 0 );

    # Add 1 row
    $query = Unit::Request->new(
        {
            etedit    => ['on'],
            etaddrow  => ['1'],
            ettablenr => ['1'],
            etcell1x2 => ['test1'],
            etcell2x2 => ['test2'],
        }
    );

    $query->path_info("/$webName/$topicName");

    $this->createNewFoswikiSession( undef, $query );

    $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web}, undef );

    $expected = <<"EXPECTED";
<nop>
<noautolink>
<a name="edittable1"></a>
<div class="editTable editTableEdit">
<form name="edittable1" action="$viewUrlAuth#edittable1" method="post">
<input type="hidden" name="ettablenr" value="1" />
<input type="hidden" name="etedit" value="on" />
<nop>
<nop>
<table id="table$this->{test_topic}1" class="foswikiTable" rules="none" border="1">
	<tbody>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td bgcolor="#ffffff" class="foswikiTableCol0 foswikiFirstCol"> <span class="et_rowlabel">0<input type="hidden" name="etcell1x1" value="0" /></span> </td>
			<td bgcolor="#ffffff" class="foswikiTableCol1 foswikiLastCol"> <input class="foswikiInputField editTableInput" type="text" name="etcell1x2" size="10" value="test1" /> </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td bgcolor="#f2f3f6" class="foswikiTableCol0 foswikiFirstCol foswikiLast"> <span class="et_rowlabel">1<input type="hidden" name="etcell2x1" value="1" /></span> </td>
			<td bgcolor="#f2f3f6" class="foswikiTableCol1 foswikiLastCol foswikiLast"> <input class="foswikiInputField editTableInput" type="text" name="etcell2x2" size="10" value="test2" /> </td>
		</tr>
	</tbody></table>
<input type="hidden" name="ettablechanges" value="1=0,2=1" />
<input type="hidden" name="etheaderrows" value="0" />
<input type="hidden" name="etfooterrows" value="0" />
<input type="submit" name="etsave" id="etsave" value="Save table" class="foswikiSubmit" />
<input type="submit" name="etqsave" id="etqsave" value="Quiet save" class="foswikiButton" />
<input type="submit" name="etaddrow" id="etaddrow" value="Add row" class="foswikiButton" />
<input type="submit" name="etdelrow" id="etdelrow" value="Delete last row" class="foswikiButton" />
<input type="submit" name="etcancel" id="etcancel" value="Cancel" class="foswikiButtonCancel" />
</form>
</div><!-- /editTable --></noautolink>
EXPECTED

    $this->do_testHtmlOutput( $expected, $result, 1 );

    return;
}

sub test_delete_last_row {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      Foswiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlSystemWeb =
        Foswiki::Func::getUrlHost()
      . Foswiki::Func::getPubUrlPath() . '/'
      . $Foswiki::cfg{SystemWebName};

    my $input = <<'INPUT';
%TABLE{headerrows="1" footerrows="1"}%
%EDITTABLE{header="| *HEADER* |"}%
| *HEADER* |
| do |
| re |
| mi |
| *FOOTER* |
INPUT

    my $query = Unit::Request->new(
        {
            etedit    => ['on'],
            ettablenr => ['1'],
        }
    );

    # delete row
    $query = Unit::Request->new(
        {
            etedit    => ['on'],
            etdelrow  => ['1'],
            ettablenr => ['1'],
        }
    );

    $query->path_info("/$webName/$topicName");

    $this->createNewFoswikiSession( undef, $query );

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web}, undef );

    my $expected = <<"EXPECTED";
<nop>
<noautolink>
<a name="edittable1"></a>
<div class="editTable editTableEdit">
<form name="edittable1" action="$viewUrlAuth#edittable1" method="post">
<input type="hidden" name="ettablenr" value="1" />
<input type="hidden" name="etedit" value="on" />
<nop>
<nop>
<nop>
<nop>
<table id="table$this->{test_topic}1" class="foswikiTable" rules="none" border="1">
	<thead>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<th bgcolor="#687684" class="foswikiTableCol0 foswikiFirstCol foswikiLastCol">HEADER </th>
		</tr>
	</thead>
	<tfoot>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<th class="foswikiTableCol0 foswikiFirstCol foswikiLastCol foswikiLast">FOOTER</th>
		</tr>
	</tfoot>
	<tbody>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td bgcolor="#ffffff" class="foswikiTableCol0 foswikiFirstCol foswikiLastCol"> <input class="foswikiInputField editTableInput" type="text" name="etcell2x1" size="16" value="do" /> </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td bgcolor="#edf4f9" class="foswikiTableCol0 foswikiFirstCol foswikiLastCol"> <input class="foswikiInputField editTableInput" type="text" name="etcell3x1" size="16" value="re" /> </td>
		</tr>
	</tbody></table>
<input type="hidden" name="ettablechanges" value="1=0,2=0,3=0,4=-1,5=0" />
<input type="hidden" name="etheaderrows" value="1" />
<input type="hidden" name="etfooterrows" value="1" />
<input type="submit" name="etsave" id="etsave" value="Save table" class="foswikiSubmit" />
<input type="submit" name="etqsave" id="etqsave" value="Quiet save" class="foswikiButton" />
<input type="submit" name="etaddrow" id="etaddrow" value="Add row" class="foswikiButton" />
<input type="submit" name="etdelrow" id="etdelrow" value="Delete last row" class="foswikiButton" />
<input type="submit" name="etcancel" id="etcancel" value="Cancel" class="foswikiButtonCancel" />
</form>
</div><!-- /editTable --></noautolink>
EXPECTED

    $this->do_testHtmlOutput( $expected, $result, 1 );

    return;
}

=pod

Test select dropdown box

=cut

sub test_param_format_selectbox {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      Foswiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlSystemWeb =
        Foswiki::Func::getUrlHost()
      . Foswiki::Func::getPubUrlPath() . '/'
      . $Foswiki::cfg{SystemWebName};

    my $query = Unit::Request->new(
        {
            etedit    => ['on'],
            ettablenr => ['1'],
        }
    );
    $query->path_info("/$webName/$topicName");

    my $text = <<'INPUT';
%EDITTABLE{format="|select, 1, a, b, c, d|select,1,a,b,c,d|select,1 ,a , b, c, d|select, 1 , a , b , c , d |" }%
| c | c | c | c |
INPUT

    $this->createNewFoswikiSession( undef, $query );
    my $result =
      Foswiki::Func::expandCommonVariables( $text, $topicName, $webName,
        undef );

    my $expected = <<"END";
<nop>
<noautolink>
<a name="edittable1"></a>
<div class="editTable editTableEdit">
<form name="edittable1" action="$viewUrlAuth#edittable1" method="post">
<input type="hidden" name="ettablenr" value="1" />
<input type="hidden" name="etedit" value="on" />
<nop>
<table id="table$this->{test_topic}1" class="foswikiTable" rules="none" border="1">
	<tbody>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td bgcolor="#ffffff" class="foswikiTableCol0 foswikiFirstCol foswikiLast"> <select class="foswikiSelect" name="etcell1x1" size="1"> <option>a</option> <option>b</option> <option selected="selected">c</option> <option>d</option></select> </td>
			<td bgcolor="#ffffff" class="foswikiTableCol1 foswikiLast"> <select class="foswikiSelect" name="etcell1x2" size="1"> <option>a</option> <option>b</option> <option selected="selected">c</option> <option>d</option></select> </td>
			<td bgcolor="#ffffff" class="foswikiTableCol2 foswikiLast"> <select class="foswikiSelect" name="etcell1x3" size="1 "> <option>a </option> <option>b</option> <option selected="selected">c</option> <option>d</option></select> </td>
			<td bgcolor="#ffffff" class="foswikiTableCol3 foswikiLastCol foswikiLast"> <select class="foswikiSelect" name="etcell1x4" size="1 "> <option>a </option> <option>b </option> <option selected="selected">c </option> <option>d</option></select> </td>
		</tr>
	</tbody>
</table>
<input type="hidden" name="ettablechanges" value="1=0" />
<input type="hidden" name="etheaderrows" value="0" />
<input type="hidden" name="etfooterrows" value="0" />
<input type="submit" name="etsave" id="etsave" value="Save table" class="foswikiSubmit" />
<input type="submit" name="etqsave" id="etqsave" value="Quiet save" class="foswikiButton" />
<input type="submit" name="etaddrow" id="etaddrow" value="Add row" class="foswikiButton" />
<input type="submit" name="etdelrow" id="etdelrow" value="Delete last row" class="foswikiButton" />
<input type="submit" name="etcancel" id="etcancel" value="Cancel" class="foswikiButtonCancel" />
</form>
</div><!-- /editTable --></noautolink>
END

    $this->do_testHtmlOutput( $expected, $result, 1 );

    return;
}

=pod

Test variables inside checkboxes and radio buttons

=cut

sub test_param_format_variable_expansion_in_checkbox_and_radio_buttons {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      Foswiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubPathSystemWeb =
      Foswiki::Func::getPubUrlPath() . '/' . $Foswiki::cfg{SystemWebName};

    my $query = Unit::Request->new(
        {
            etedit    => ['on'],
            ettablenr => ['1'],
        }
    );
    $query->path_info("/$webName/$topicName");

    my $text = <<'INPUT';
%EDITTABLE{format="| radio, 1, :skull:, :cool: | checkbox, 1, :skull:, :cool: |"}%
INPUT

    $this->createNewFoswikiSession( undef, $query );
    my $result =
      Foswiki::Func::expandCommonVariables( $text, $topicName, $webName,
        undef );

    my $expected = <<"END";
<nop>
<noautolink>
<a name="edittable1"></a>
<div class="editTable editTableEdit">
<form name="edittable1" action="$viewUrlAuth#edittable1" method="post">
<input type="hidden" name="ettablenr" value="1" />
<input type="hidden" name="etedit" value="on" />
<nop>
<table id="table$this->{test_topic}1" class="foswikiTable" rules="none" border="1">
	<tbody>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td bgcolor="#ffffff" class="foswikiTableCol0 foswikiFirstCol foswikiLast"> <table class="editTableInnerTable"><tr><td valign="top"><input type="radio" name="etcell1x1" value=":skull:" /> <img alt="dead, deadly, doom" class="smily" src="$pubPathSystemWeb/SmiliesPlugin/skull.gif" title="dead, deadly, doom"> </img> <br /> <input type="radio" name="etcell1x1" value=":cool:" /> <img alt="cool" class="smily" src="$pubPathSystemWeb/SmiliesPlugin/emoticon-0103-cool.gif" title="cool"> </img> </td></tr></table> </td>
			<td bgcolor="#ffffff" class="foswikiTableCol1 foswikiLastCol foswikiLast"> <table class="editTableInnerTable"><tr><td valign="top"><input type="checkbox" name="etcell1x2x2" value=":skull:" checked="checked" /> <img alt="dead, deadly, doom" class="smily" src="$pubPathSystemWeb/SmiliesPlugin/skull.gif" title="dead, deadly, doom"> </img> <br /> <input type="checkbox" name="etcell1x2x3" value=":cool:" checked="checked" /> <img alt="cool" class="smily" src="$pubPathSystemWeb/SmiliesPlugin/emoticon-0103-cool.gif" title="cool"> </img> </td></tr></table><input type="hidden" name="etcell1x2" value="Chkbx: etcell1x2x2 etcell1x2x3" /> </td>
		</tr>
	</tbody>
</table>
<input type="hidden" name="ettablechanges" value="1=1" />
<input type="hidden" name="etheaderrows" value="0" />
<input type="hidden" name="etfooterrows" value="0" />
<input type="submit" name="etsave" id="etsave" value="Save table" class="foswikiSubmit" />
<input type="submit" name="etqsave" id="etqsave" value="Quiet save" class="foswikiButton" />
<input type="submit" name="etaddrow" id="etaddrow" value="Add row" class="foswikiButton" />
<input type="submit" name="etdelrow" id="etdelrow" value="Delete last row" class="foswikiButton" />
<input type="submit" name="etcancel" id="etcancel" value="Cancel" class="foswikiButtonCancel" />
</form>
</div><!-- /editTable --></noautolink>
END

    $this->do_testHtmlOutput( $expected, $result, 1 );

    return;
}

=pod

=cut

sub test_param_format_with_variables {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      Foswiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );

    # SMELL: the following variable is needed cause the test simulate the
    # rendering of %TOPIC%. Core generates a relative URL for that, but the
    # interface provided to plugins only generates absolute URLs, so it's
    # needed to take out the urlHost from the beginning of the got URL.
    my $viewUrl = Foswiki::Func::getScriptUrl( $webName, $topicName, 'view' );
    my $urlHost = Foswiki::Func::getUrlHost();
    $viewUrl =~ s/^$urlHost//;
    my $pubUrlSystemWeb =
        Foswiki::Func::getUrlHost()
      . Foswiki::Func::getPubUrlPath() . '/'
      . $Foswiki::cfg{SystemWebName};

    my $text = <<'INPUT';
%EDITTABLE{format="| text, 30, %Y% | text, 30, %TOPIC% |"}%
| %Y% | %TOPIC% |
INPUT

    my $result =
      Foswiki::Func::expandCommonVariables( $text, $topicName, $webName,
        undef );

    my $expected = <<"END";
<a name="edittable1"></a>
<div class="editTable">
<form name="edittable1" action="$viewUrlAuth#edittable1" method="post">
<input type="hidden" name="ettablenr" value="1" />
<input type="hidden" name="etedit" value="on" />
<nop>
<table border="1" class="foswikiTable" rules="none">
	<tbody>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td bgcolor="#ffffff" class="foswikiTableCol0 foswikiFirstCol foswikiLast"> <img alt=DONE height=16 src=%PUBURLPATH%/%SYSTEMWEB%/DocumentGraphics/choice-yes.png title=DONE width=16></img> </td>
			<td bgcolor="#ffffff" class="foswikiTableCol1 foswikiLastCol foswikiLast"> <a href="$viewUrl" class="foswikiCurrentTopicLink">$topicName</a> </td>
		</tr>
	</tbody>
</table>
<input type="hidden" name="ettablechanges" value="" />
<input type="hidden" name="etheaderrows" value="0" />
<input type="hidden" name="etfooterrows" value="0" />
<input class="editTableEditImageButton" type="image" src="$pubUrlSystemWeb/EditTablePlugin/edittable.gif" alt="Edit this table" /></form>
</div><!-- /editTable -->
END

    $expected =~ s/%PUBURLPATH%/$Foswiki::cfg{PubUrlPath}/e;
    $expected =~ s/%SYSTEMWEB%/$Foswiki::cfg{SystemWebName}/g;

    $this->do_testHtmlOutput( $expected, $result, 1 );

    return;
}

=pod

Format parameter with $percntY$percnt macros. Edit the table.

=cut

sub test_param_format_with_macro_placeholders_edit {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      Foswiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlSystemWeb =
        Foswiki::Func::getUrlHost()
      . Foswiki::Func::getPubUrlPath() . '/'
      . $Foswiki::cfg{SystemWebName};
    my $userName = $this->{users_web} . '.' . 'WikiGuest';

    my $text = <<"INPUT";
%EDITTABLE{format="| text, 30, \$percntY\$percnt | text, 30, \$percntTOPIC\$percnt |"}%
INPUT

    my $query = Unit::Request->new(
        {
            etedit    => ['on'],
            ettablenr => ['1'],
        }
    );
    $query->path_info("/$webName/$topicName");

    $this->createNewFoswikiSession( undef, $query );
    my $result =
      Foswiki::Func::expandCommonVariables( $text, $topicName, $webName,
        undef );

    my $expected = <<"END";
<nop>
<noautolink>
<a name="edittable1"></a>
<div class="editTable editTableEdit">
<form name="edittable1" action="$viewUrlAuth#edittable1" method="post">
<input type="hidden" name="ettablenr" value="1" />
<input type="hidden" name="etedit" value="on" />
<nop>
<table id="table$this->{test_topic}1" class="foswikiTable" rules="none" border="1">
	<tbody>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td bgcolor="#ffffff" class="foswikiTableCol0 foswikiFirstCol foswikiLast"> <input class="foswikiInputField editTableInput" type="text" name="etcell1x1" size="30" value="%Y%" /> </td>
			<td bgcolor="#ffffff" class="foswikiTableCol1 foswikiLastCol foswikiLast"> <input class="foswikiInputField editTableInput" type="text" name="etcell1x2" size="30" value="%TOPIC%" /> </td>
		</tr>
	</tbody>	
</table>
<input type="hidden" name="ettablechanges" value="1=1" />
<input type="hidden" name="etheaderrows" value="0" />
<input type="hidden" name="etfooterrows" value="0" />
<input type="submit" name="etsave" id="etsave" value="Save table" class="foswikiSubmit" />
<input type="submit" name="etqsave" id="etqsave" value="Quiet save" class="foswikiButton" />
<input type="submit" name="etaddrow" id="etaddrow" value="Add row" class="foswikiButton" />
<input type="submit" name="etdelrow" id="etdelrow" value="Delete last row" class="foswikiButton" />
<input type="submit" name="etcancel" id="etcancel" value="Cancel" class="foswikiButtonCancel" />
</form>
</div><!-- /editTable --></noautolink>
END

    $this->do_testHtmlOutput( $expected, $result, 1 );

    return;
}

=pod

Saving a simple table.

=cut

sub test_save {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      Foswiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlSystemWeb =
        Foswiki::Func::getUrlHost()
      . Foswiki::Func::getPubUrlPath() . '/'
      . $Foswiki::cfg{SystemWebName};

    my $input = <<'INPUT';
%EDITTABLE{}%
| *URL* | *Name* | *By* | *Comment* |
| http://foswiki.org | Foswiki | me | dodo |
INPUT
    my $query = Unit::Request->new(
        {
            etedit    => ['on'],
            ettablenr => ['1'],
        }
    );

    $query->path_info("/$webName/$topicName");

    $this->createNewFoswikiSession( undef, $query );

    $query = Unit::Request->new(
        {
            etsave    => ['on'],
            ettablenr => ['1'],
        }
    );

    $query->path_info("/$webName/$topicName");
    $query->method('POST');

    Foswiki::Func::saveTopic( $this->{test_web}, $this->{test_topic}, undef,
        $input );

    $this->createNewFoswikiSession( undef, $query );
    my $response = Unit::Response->new();

    my ( $saveResult, $ecode ) = $this->capture(
        sub {
            $response->print(
                Foswiki::Func::expandCommonVariables(
                    $input, $this->{test_topic}, $this->{test_web}, undef
                )
            );
        }
    );

    my ( $meta, $newtext ) = Foswiki::Func::readTopic( $webName, $topicName );

    my $expected = <<'NEWEXPECTED';
%EDITTABLE{}%
| *URL* | *Name* | *By* | *Comment* |
| http://foswiki.org | Foswiki | me | dodo |
NEWEXPECTED
    $this->assert_str_equals( $expected, $newtext, 0 );

    return;
}

=pod

Saving a table with params headerrows and footerrows.

DEPRECATED: saving a table with changes through params will be changed

=cut

sub _DEPRECATED_test_param_headerrows_and_footerrows_save {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      Foswiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlSystemWeb =
        Foswiki::Func::getUrlHost()
      . Foswiki::Func::getPubUrlPath() . '/'
      . $Foswiki::cfg{SystemWebName};

    my $input = <<'INPUT';
%TABLE{columnwidths="80,80,50,110,150,50,50,50,50,50,70,70,50" dataalign="left,left,center,left,left,center,center,center,center,center,center,right,right,center" headeralign="center" headerrows="1" footerrows="1" headerislabel="on"}%%EDITTABLE{format="|text,10|text,10|text,3|text,15|text,15|text,3|text,3|text,3|text,3|text,3|text,3|text,10|label,0|text,5|" }%
| *Project* | *Customer* | *Pass* | *Type* | *Purpose* | *Qty* | *Radios* | *Controllers* | *Hubs* | *Tuners* | *Hybrid* | *Unit Cost (USD)* | *Total Cost (USD)* | *When (Q)* |
| Project A | Engineering | A | PK2 | Eng Test | 2 | 4 || 2 | 2 || 6214 | %CALC{"\$EVAL(\$T(R\$ROW():C6) * \$T(R\$ROW():C\$COLUMN(-1)))"}% | Q1 |
| Project B | Factory | A | PC2 | Fact Test | 1 | 4 || 2 | 2 || 6214 | %CALC{"\$EVAL(\$T(R\$ROW():C6) * \$T(R\$ROW():C\$COLUMN(-1)))"}% | Q2 |
| Project C | Eng | P1 | CT5 | Eng Test | 1 | 2 | 1 ||| 1 | 3502 | %CALC{"\$EVAL(\$T(R\$ROW():C6) * \$T(R\$ROW():C\$COLUMN(-1)))"}% | Q3 |
| Project D | SW | P1 | CT5 | SW Dev | 2 | 4 | 2 || 2 || 6345 | %CALC{"\$EVAL(\$T(R\$ROW():C6) * \$T(R\$ROW():C\$COLUMN(-1)))"}% | Q4 |
| Total ||||| *%CALC{"\$SUM(\$ABOVE())"}%* | *%CALC{"\$SUMPRODUCT(R2:C6..R\$ROW(-1):C6, R2:C\$COLUMN(0)..R\$ROW(-1):C\$COLUMN(0))"}%* | *%CALC{"\$SUMPRODUCT(R2:C6..R\$ROW(-1):C6, R2:C\$COLUMN(0)..R\$ROW(-1):C\$COLUMN(0))"}%* | *%CALC{"\$SUMPRODUCT(R2:C6..R\$ROW(-1):C6, R2:C\$COLUMN(0)..R\$ROW(-1):C\$COLUMN(0))"}%* | *%CALC{"\$SUMPRODUCT(R2:C6..R\$ROW(-1):C6, R2:C\$COLUMN(0)..R\$ROW(-1):C\$COLUMN(0))"}%* | *%CALC{"\$SUMPRODUCT(R2:C6..R\$ROW(-1):C6, R2:C\$COLUMN(0)..R\$ROW(-1):C\$COLUMN(0))"}%* || *%CALC{"\$SUM(\$ABOVE())"}%* ||
INPUT
    my $query = Unit::Request->new(
        {
            etedit    => ['on'],
            ettablenr => ['1'],
        }
    );

    $query->path_info("/$webName/$topicName");

    $this->createNewFoswikiSession( undef, $query );

    $query = Unit::Request->new(
        {
            etsave    => ['on'],
            etaddrow  => ['1'],
            ettablenr => ['1'],
        }
    );

    $query->path_info("/$webName/$topicName");
    $query->method('POST');

    Foswiki::Func::saveTopic( $this->{test_web}, $this->{test_topic}, undef,
        $input );

    $this->createNewFoswikiSession( undef, $query );
    my $response = Unit::Response->new();

    my ( $saveResult, $ecode ) = $this->capture(
        sub {
            $response->print(
                Foswiki::Func::expandCommonVariables(
                    $input, $this->{test_topic}, $this->{test_web}, undef
                )
            );
        }
    );

    my ( $meta, $newtext ) = Foswiki::Func::readTopic( $webName, $topicName );

# Expected is that saving causes the TABLE and EDITTABLE tags to be saved on two lines.
    my $expected = <<'NEWEXPECTED';
%TABLE{columnwidths="80,80,50,110,150,50,50,50,50,50,70,70,50" dataalign="left,left,center,left,left,center,center,center,center,center,center,right,right,center" headeralign="center" headerrows="1" footerrows="1" headerislabel="on"}%
%EDITTABLE{format="|text,10|text,10|text,3|text,15|text,15|text,3|text,3|text,3|text,3|text,3|text,3|text,10|label,0|text,5|" }%
| *Project* | *Customer* | *Pass* | *Type* | *Purpose* | *Qty* | *Radios* | *Controllers* | *Hubs* | *Tuners* | *Hybrid* | *Unit Cost (USD)* | *Total Cost (USD)* | *When (Q)* |
| Project A | Engineering | A | PK2 | Eng Test | 2 | 4 | | 2 | 2 | | 6214 | %CALC{"\$EVAL(\$T(R\$ROW():C6) * \$T(R\$ROW():C\$COLUMN(-1)))"}% | Q1 |
| Project B | Factory | A | PC2 | Fact Test | 1 | 4 | | 2 | 2 | | 6214 | %CALC{"\$EVAL(\$T(R\$ROW():C6) * \$T(R\$ROW():C\$COLUMN(-1)))"}% | Q2 |
| Project C | Eng | P1 | CT5 | Eng Test | 1 | 2 | 1 | | | 1 | 3502 | %CALC{"\$EVAL(\$T(R\$ROW():C6) * \$T(R\$ROW():C\$COLUMN(-1)))"}% | Q3 |
| Project D | SW | P1 | CT5 | SW Dev | 2 | 4 | 2 | | 2 | | 6345 | %CALC{"\$EVAL(\$T(R\$ROW():C6) * \$T(R\$ROW():C\$COLUMN(-1)))"}% | Q4 |
| | | | | | | | | | | | | | |
| Total | | | | | *%CALC{"\$SUM(\$ABOVE())"}%* | *%CALC{"\$SUMPRODUCT(R2:C6..R\$ROW(-1):C6, R2:C\$COLUMN(0)..R\$ROW(-1):C\$COLUMN(0))"}%* | *%CALC{"\$SUMPRODUCT(R2:C6..R\$ROW(-1):C6, R2:C\$COLUMN(0)..R\$ROW(-1):C\$COLUMN(0))"}%* | *%CALC{"\$SUMPRODUCT(R2:C6..R\$ROW(-1):C6, R2:C\$COLUMN(0)..R\$ROW(-1):C\$COLUMN(0))"}%* | *%CALC{"\$SUMPRODUCT(R2:C6..R\$ROW(-1):C6, R2:C\$COLUMN(0)..R\$ROW(-1):C\$COLUMN(0))"}%* | *%CALC{"\$SUMPRODUCT(R2:C6..R\$ROW(-1):C6, R2:C\$COLUMN(0)..R\$ROW(-1):C\$COLUMN(0))"}%* | | *%CALC{"\$SUM(\$ABOVE())"}%* | |
NEWEXPECTED
    $this->assert_str_equals( $expected, $newtext, 0 );

    return;
}

=pod

Saving a table with params headerrows and footerrows, with TABLE above EDITTABLE

DEPRECATED: saving a table with changes through params will be changed

=cut

sub _DEPRECATED_test_param_headerrows_and_footerrows_save_table_above {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      Foswiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlSystemWeb =
        Foswiki::Func::getUrlHost()
      . Foswiki::Func::getPubUrlPath() . '/'
      . $Foswiki::cfg{SystemWebName};

    my $input = <<'INPUT';
BEFORE_TABLE %TABLE{columnwidths="80,80,50,110,150,50,50,50,50,50,70,70,50" dataalign="left,left,center,left,left,center,center,center,center,center,center,right,right,center" headeralign="center" headerrows="1" footerrows="1" headerislabel="on"}%
BEFORE_EDITTABLE %EDITTABLE{format="|text,10|text,10|text,3|text,15|text,15|text,3|text,3|text,3|text,3|text,3|text,3|text,10|label,0|text,5|" }%
| *Project* | *Customer* | *Pass* | *Type* | *Purpose* | *Qty* | *Radios* | *Controllers* | *Hubs* | *Tuners* | *Hybrid* | *Unit Cost (USD)* | *Total Cost (USD)* | *When (Q)* |
| Project A | Engineering | A | PK2 | Eng Test | 2 | 4 || 2 | 2 || 6214 | %CALC{"\$EVAL(\$T(R\$ROW():C6) * \$T(R\$ROW():C\$COLUMN(-1)))"}% | Q1 |
| Project B | Factory | A | PC2 | Fact Test | 1 | 4 || 2 | 2 || 6214 | %CALC{"\$EVAL(\$T(R\$ROW():C6) * \$T(R\$ROW():C\$COLUMN(-1)))"}% | Q2 |
| Project C | Eng | P1 | CT5 | Eng Test | 1 | 2 | 1 ||| 1 | 3502 | %CALC{"\$EVAL(\$T(R\$ROW():C6) * \$T(R\$ROW():C\$COLUMN(-1)))"}% | Q3 |
| Project D | SW | P1 | CT5 | SW Dev | 2 | 4 | 2 || 2 || 6345 | %CALC{"\$EVAL(\$T(R\$ROW():C6) * \$T(R\$ROW():C\$COLUMN(-1)))"}% | Q4 |
| Total ||||| *%CALC{"\$SUM(\$ABOVE())"}%* | *%CALC{"\$SUMPRODUCT(R2:C6..R\$ROW(-1):C6, R2:C\$COLUMN(0)..R\$ROW(-1):C\$COLUMN(0))"}%* | *%CALC{"\$SUMPRODUCT(R2:C6..R\$ROW(-1):C6, R2:C\$COLUMN(0)..R\$ROW(-1):C\$COLUMN(0))"}%* | *%CALC{"\$SUMPRODUCT(R2:C6..R\$ROW(-1):C6, R2:C\$COLUMN(0)..R\$ROW(-1):C\$COLUMN(0))"}%* | *%CALC{"\$SUMPRODUCT(R2:C6..R\$ROW(-1):C6, R2:C\$COLUMN(0)..R\$ROW(-1):C\$COLUMN(0))"}%* | *%CALC{"\$SUMPRODUCT(R2:C6..R\$ROW(-1):C6, R2:C\$COLUMN(0)..R\$ROW(-1):C\$COLUMN(0))"}%* || *%CALC{"\$SUM(\$ABOVE())"}%* ||
INPUT
    my $query = Unit::Request->new(
        {
            etedit    => ['on'],
            ettablenr => ['1'],
        }
    );

    $query->path_info("/$webName/$topicName");

    $this->createNewFoswikiSession( undef, $query );

    $query = Unit::Request->new(
        {
            etsave    => ['on'],
            etrows    => ['5'],
            ettablenr => ['1'],
        }
    );

    $query->path_info("/$webName/$topicName");
    $query->method('POST');

    Foswiki::Func::saveTopic( $this->{test_web}, $this->{test_topic}, undef,
        $input );

    $this->createNewFoswikiSession( undef, $query );
    my $response = Unit::Response->new();

    my ( $saveResult, $ecode ) = $this->capture(
        sub {
            $response->print(
                Foswiki::Func::expandCommonVariables(
                    $input, $this->{test_topic}, $this->{test_web}, undef
                )
            );
        }
    );

    my ( $meta, $newtext ) = Foswiki::Func::readTopic( $webName, $topicName );

    my $expected = <<"NEWEXPECTED";
BEFORE_TABLE %TABLE{columnwidths="80,80,50,110,150,50,50,50,50,50,70,70,50" dataalign="left,left,center,left,left,center,center,center,center,center,center,right,right,center" headeralign="center" headerrows="1" footerrows="1" headerislabel="on"}%
BEFORE_EDITTABLE %EDITTABLE{format="|text,10|text,10|text,3|text,15|text,15|text,3|text,3|text,3|text,3|text,3|text,3|text,10|label,0|text,5|" }%
| *Project* | *Customer* | *Pass* | *Type* | *Purpose* | *Qty* | *Radios* | *Controllers* | *Hubs* | *Tuners* | *Hybrid* | *Unit Cost (USD)* | *Total Cost (USD)* | *When (Q)* |
| Project A | Engineering | A | PK2 | Eng Test | 2 | 4 | | 2 | 2 | | 6214 | %CALC{"\$EVAL(\$T(R\$ROW():C6) * \$T(R\$ROW():C\$COLUMN(-1)))"}% | Q1 |
| Project B | Factory | A | PC2 | Fact Test | 1 | 4 | | 2 | 2 | | 6214 | %CALC{"\$EVAL(\$T(R\$ROW():C6) * \$T(R\$ROW():C\$COLUMN(-1)))"}% | Q2 |
| Project C | Eng | P1 | CT5 | Eng Test | 1 | 2 | 1 | | | 1 | 3502 | %CALC{"\$EVAL(\$T(R\$ROW():C6) * \$T(R\$ROW():C\$COLUMN(-1)))"}% | Q3 |
| Project D | SW | P1 | CT5 | SW Dev | 2 | 4 | 2 | | 2 | | 6345 | %CALC{"\$EVAL(\$T(R\$ROW():C6) * \$T(R\$ROW():C\$COLUMN(-1)))"}% | Q4 |
| | | | | | | | | | | | | | |
| Total | | | | | *%CALC{"\$SUM(\$ABOVE())"}%* | *%CALC{"\$SUMPRODUCT(R2:C6..R\$ROW(-1):C6, R2:C\$COLUMN(0)..R\$ROW(-1):C\$COLUMN(0))"}%* | *%CALC{"\$SUMPRODUCT(R2:C6..R\$ROW(-1):C6, R2:C\$COLUMN(0)..R\$ROW(-1):C\$COLUMN(0))"}%* | *%CALC{"\$SUMPRODUCT(R2:C6..R\$ROW(-1):C6, R2:C\$COLUMN(0)..R\$ROW(-1):C\$COLUMN(0))"}%* | *%CALC{"\$SUMPRODUCT(R2:C6..R\$ROW(-1):C6, R2:C\$COLUMN(0)..R\$ROW(-1):C\$COLUMN(0))"}%* | *%CALC{"\$SUMPRODUCT(R2:C6..R\$ROW(-1):C6, R2:C\$COLUMN(0)..R\$ROW(-1):C\$COLUMN(0))"}%* | | *%CALC{"\$SUM(\$ABOVE())"}%* | |
NEWEXPECTED
    $this->assert_str_equals( $expected, $newtext, 0 );

    return;
}

=pod

Test if cells with a space do not voided (and rendered with a colspan): text fields

=cut

sub test_keepSpacesInEmptyCellsWithTexts {
    my $this      = shift;
    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      Foswiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlSystemWeb =
        Foswiki::Func::getUrlHost()
      . Foswiki::Func::getPubUrlPath() . '/'
      . $Foswiki::cfg{SystemWebName};
    my $input = <<'INPUT';
%EDITTABLE{format="|text,40|text,10|"}% 
| *Milestone* | *Plan* |
| ABC | X |
| DEF | |
INPUT
    my $query = Unit::Request->new(
        {
            etedit    => ['on'],
            ettablenr => ['1'],
        }
    );
    $query->path_info("/$webName/$topicName");
    $this->createNewFoswikiSession( undef, $query );
    $query = Unit::Request->new(
        {
            etsave    => ['on'],
            ettablenr => ['1'],
        }
    );
    $query->path_info("/$webName/$topicName");
    $query->method('POST');
    Foswiki::Func::saveTopic( $this->{test_web}, $this->{test_topic}, undef,
        $input );
    $this->createNewFoswikiSession( undef, $query );
    my $response = Unit::Response->new();
    my ( $saveResult, $ecode ) = $this->capture(
        sub {
            $response->print(
                Foswiki::Func::expandCommonVariables(
                    $input, $this->{test_topic}, $this->{test_web}, undef
                )
            );
        }
    );
    my ( $meta, $newtext ) = Foswiki::Func::readTopic( $webName, $topicName );
    my $expected = <<'NEWEXPECTED';
%EDITTABLE{format="|text,40|text,10|"}% 
| *Milestone* | *Plan* |
| ABC | X |
| DEF | |
NEWEXPECTED
    $this->assert_str_equals( $expected, $newtext, 0 );

    return;
}

=pod

Test if cells with a space do not voided (and rendered with a colspan): date fields

=cut

sub test_keepSpacesInEmptyCellsWithDates {
    my $this      = shift;
    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      Foswiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlSystemWeb =
        Foswiki::Func::getUrlHost()
      . Foswiki::Func::getPubUrlPath() . '/'
      . $Foswiki::cfg{SystemWebName};
    my $input = <<'INPUT';
%EDITTABLE{format="|text,40|date,10,,%d %b %Y|date,10,,%d %b %Y|date,10,,%d %b %Y|"}% 
%TABLE{columnwidths="300,130,130,130" dataalign="left,center,center,center" tablerules="all"}%
| *Milestone* | *Plan* | *Forecast* | *Actual* |
| Blabla 1 | 07 Sep 2007 | | 07 Sep 2007 |
| Blabla 5 | 16 Nov 2007 | 21 Nov 2007 | |
INPUT
    my $query = Unit::Request->new(
        {
            etedit    => ['on'],
            ettablenr => ['1'],
        }
    );
    $query->path_info("/$webName/$topicName");
    $this->createNewFoswikiSession( undef, $query );
    $query = Unit::Request->new(
        {
            etsave    => ['on'],
            ettablenr => ['1'],
        }
    );
    $query->path_info("/$webName/$topicName");
    $query->method('POST');
    Foswiki::Func::saveTopic( $this->{test_web}, $this->{test_topic}, undef,
        $input );
    $this->createNewFoswikiSession( undef, $query );
    my $response = Unit::Response->new();
    my ( $saveResult, $ecode ) = $this->capture(
        sub {
            $response->print(
                Foswiki::Func::expandCommonVariables(
                    $input, $this->{test_topic}, $this->{test_web}, undef
                )
            );
        }
    );
    my ( $meta, $newtext ) = Foswiki::Func::readTopic( $webName, $topicName );
    my $expected = <<'NEWEXPECTED';
%EDITTABLE{format="|text,40|date,10,,%d %b %Y|date,10,,%d %b %Y|date,10,,%d %b %Y|"}% 
%TABLE{columnwidths="300,130,130,130" dataalign="left,center,center,center" tablerules="all"}%
| *Milestone* | *Plan* | *Forecast* | *Actual* |
| Blabla 1 | 07 Sep 2007 | | 07 Sep 2007 |
| Blabla 5 | 16 Nov 2007 | 21 Nov 2007 | |
NEWEXPECTED
    $this->assert_str_equals( $expected, $newtext, 0 );

    return;
}

=pod

Test if colspan cells do get split to avoid that users get unwanted cell merges
when they delete the content of a cell.
Note that EditTablePlugin does not support merged cells using the ||| syntax.
If a merge feature is added please pay attention to Item5217

=cut

sub test_addSpacesToEmptyCells {
    my $this      = shift;
    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      Foswiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlSystemWeb =
        Foswiki::Func::getUrlHost()
      . Foswiki::Func::getPubUrlPath() . '/'
      . $Foswiki::cfg{SystemWebName};
    my $input = <<'INPUT';
%EDITTABLE{format="|text,40|text,10|"}% 
|| X |
| DEF ||
INPUT
    my $query = Unit::Request->new(
        {
            etedit    => ['on'],
            ettablenr => ['1'],
        }
    );
    $query->path_info("/$webName/$topicName");
    $this->createNewFoswikiSession( undef, $query );
    $query = Unit::Request->new(
        {
            etsave    => ['on'],
            ettablenr => ['1'],
        }
    );
    $query->path_info("/$webName/$topicName");
    $query->method('POST');
    Foswiki::Func::saveTopic( $this->{test_web}, $this->{test_topic}, undef,
        $input );
    $this->createNewFoswikiSession( undef, $query );
    my $response = Unit::Response->new();
    my ( $saveResult, $ecode ) = $this->capture(
        sub {
            $response->print(
                Foswiki::Func::expandCommonVariables(
                    $input, $this->{test_topic}, $this->{test_web}, undef
                )
            );
        }
    );
    my ( $meta, $newtext ) = Foswiki::Func::readTopic( $webName, $topicName );
    my $expected = <<'NEWEXPECTED';
%EDITTABLE{format="|text,40|text,10|"}% 
| | X |
| DEF | |
NEWEXPECTED
    $this->assert_str_equals( $expected, $newtext, 0 );

    return;
}

=pod

Test if TML formatting is rendered.

=cut

sub test_TMLFormattingInsideCell_BR {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      Foswiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlSystemWeb =
        Foswiki::Func::getUrlHost()
      . Foswiki::Func::getPubUrlPath() . '/'
      . $Foswiki::cfg{SystemWebName};

    my $input = <<'INPUT';
%EDITTABLE{}%
| blablabla%BR%there's still a bug%BR%lurking around%BR%_italic_%BR%*bold* %EDITCELL{textarea,6x40,}% |
INPUT

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $topicName, $webName,
        undef );

    my $expected = <<"NEWEXPECTED";
<a name="edittable1"></a>
<div class="editTable">
<form name="edittable1" action="$viewUrlAuth#edittable1" method="post">
<input type="hidden" name="ettablenr" value="1" />
<input type="hidden" name="etedit" value="on" />
<nop>
<table border="1" class="foswikiTable" rules="none">
	<tbody>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td bgcolor="#ffffff" class="foswikiTableCol0 foswikiFirstCol foswikiLastCol foswikiLast"> blablabla <br /> there's still a bug <br /> lurking around <br /> <em>italic</em> <br /> <strong>bold</strong> </td>
		</tr>
	</tbody></table>
<input type="hidden" name="ettablechanges" value="" />
<input type="hidden" name="etheaderrows" value="0" />
<input type="hidden" name="etfooterrows" value="0" />
<input class="editTableEditImageButton" type="image" src="$pubUrlSystemWeb/EditTablePlugin/edittable.gif" alt="Edit this table" /> </form>
</div><!-- /editTable -->
NEWEXPECTED

    $this->do_testHtmlOutput( $expected, $result, 1 );

    return;
}

=pod

Test if TML formatting is rendered with <br /> tags.

=cut

sub test_TMLFormattingInsideCell_tag_br {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      Foswiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlSystemWeb =
        Foswiki::Func::getUrlHost()
      . Foswiki::Func::getPubUrlPath() . '/'
      . $Foswiki::cfg{SystemWebName};

    my $input = <<'INPUT';
%EDITTABLE{}%
| blablabla<br />there's still a bug<br />lurking around<br />_italic_<br />*bold* %EDITCELL{textarea,6x40,}% |
INPUT

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $topicName, $webName,
        undef );

    my $expected = <<"NEWEXPECTED";
<a name="edittable1"></a>
<div class="editTable">
<form name="edittable1" action="$viewUrlAuth#edittable1" method="post">
<input type="hidden" name="ettablenr" value="1" />
<input type="hidden" name="etedit" value="on" />
<nop>
<table class="foswikiTable" rules="none" border="1">
	<tbody>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td bgcolor="#ffffff" class="foswikiTableCol0 foswikiFirstCol foswikiLastCol foswikiLast"> blablabla <br /> there's still a bug <br /> lurking around <br /> <em>italic</em> <br /> <strong>bold</strong> </td>
		</tr>
	</tbody></table>
<input type="hidden" name="ettablechanges" value="" />
<input type="hidden" name="etheaderrows" value="0" />
<input type="hidden" name="etfooterrows" value="0" />
<input class="editTableEditImageButton" type="image" src="$pubUrlSystemWeb/EditTablePlugin/edittable.gif" alt="Edit this table" /> </form>
</div><!-- /editTable -->
NEWEXPECTED

    $this->do_testHtmlOutput( $expected, $result, 1 );

    return;
}

=pod

Test if stars are preserved after saving.

=cut

sub test_keepStars {
    my $this      = shift;
    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      Foswiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlSystemWeb =
        Foswiki::Func::getUrlHost()
      . Foswiki::Func::getPubUrlPath() . '/'
      . $Foswiki::cfg{SystemWebName};
    my $input = <<'INPUT';
%EDITTABLE{}%
| * <small>Name of the client (prefilled)</small> |
INPUT
    my $query = Unit::Request->new(
        {
            etedit    => ['on'],
            ettablenr => ['1'],
        }
    );
    $query->path_info("/$webName/$topicName");
    $this->createNewFoswikiSession( undef, $query );
    $query = Unit::Request->new(
        {
            etsave    => ['on'],
            ettablenr => ['1'],
        }
    );
    $query->path_info("/$webName/$topicName");
    $query->method('POST');
    Foswiki::Func::saveTopic( $this->{test_web}, $this->{test_topic}, undef,
        $input );
    $this->createNewFoswikiSession( undef, $query );
    my $response = Unit::Response->new();
    my ( $saveResult, $ecode ) = $this->capture(
        sub {
            $response->print(
                Foswiki::Func::expandCommonVariables(
                    $input, $this->{test_topic}, $this->{test_web}, undef
                )
            );
        }
    );
    my ( $meta, $newtext ) = Foswiki::Func::readTopic( $webName, $topicName );
    my $expected = <<'NEWEXPECTED';
%EDITTABLE{}%
| * <small>Name of the client (prefilled)</small> |
NEWEXPECTED
    $this->assert_str_equals( $expected, $newtext, 0 );

    return;
}

=pod

Test if linebreaks inside input fields are kept.

=cut

sub test_lineBreaksInsideInputField {
    my $this      = shift;
    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      Foswiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlSystemWeb =
        Foswiki::Func::getUrlHost()
      . Foswiki::Func::getPubUrlPath() . '/'
      . $Foswiki::cfg{SystemWebName};
    my $input = <<'INPUT';
%EDITTABLE{ changerows="off" quietsave="off"  }%
| <small><table><tr><td>TD...Technical Documentation <br />TM...Translation Management <br />PC...Product Catalogs </td><td>PS...Processes and Systems <br />FM...Feedback Management <br />KL...Knowledge Logistics</td></tr></table></small> |
INPUT
    my $query = Unit::Request->new(
        {
            etedit    => ['on'],
            ettablenr => ['1'],
        }
    );
    $query->path_info("/$webName/$topicName");
    $this->createNewFoswikiSession( undef, $query );
    $query = Unit::Request->new(
        {
            etsave    => ['on'],
            ettablenr => ['1'],
        }
    );
    $query->path_info("/$webName/$topicName");
    $query->method('POST');
    Foswiki::Func::saveTopic( $this->{test_web}, $this->{test_topic}, undef,
        $input );
    $this->createNewFoswikiSession( undef, $query );
    my $response = Unit::Response->new();
    my ( $saveResult, $ecode ) = $this->capture(
        sub {
            $response->print(
                Foswiki::Func::expandCommonVariables(
                    $input, $this->{test_topic}, $this->{test_web}, undef
                )
            );
        }
    );
    my ( $meta, $newtext ) = Foswiki::Func::readTopic( $webName, $topicName );
    my $expected = <<'NEWEXPECTED';
%EDITTABLE{ changerows="off" quietsave="off"  }%
| <small><table><tr><td>TD...Technical Documentation <br />TM...Translation Management <br />PC...Product Catalogs </td><td>PS...Processes and Systems <br />FM...Feedback Management <br />KL...Knowledge Logistics</td></tr></table></small> |
NEWEXPECTED
    $this->assert_str_equals( $expected, $newtext, 0 );

    return;
}

=pod

=cut

sub test_param_buttonrow_top {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      Foswiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlSystemWeb =
        Foswiki::Func::getUrlHost()
      . Foswiki::Func::getPubUrlPath() . '/'
      . $Foswiki::cfg{SystemWebName};

    Foswiki::Func::saveTopic( $webName, $topicName, undef, "XXX" );

    my $input    = '%EDITTABLE{buttonrow="top"}%';
    my $expected = <<"END";
<a name="edittable1"></a>
<div class="editTable">
<form name="edittable1" action="$viewUrlAuth#edittable1" method="post">
<input class="editTableEditImageButton" type="image" src="$pubUrlSystemWeb/EditTablePlugin/edittable.gif" alt="Edit this table" />
<input type="hidden" name="ettablenr" value="1" />
<input type="hidden" name="etedit" value="on" />
<input type="hidden" name="ettablechanges" value="" />
<input type="hidden" name="etheaderrows" value="0" />
<input type="hidden" name="etfooterrows" value="0" />
</form>
</div><!-- /editTable -->
END
    my $result =
      Foswiki::Func::expandCommonVariables( $input, $topicName, $webName );
    $this->do_testHtmlOutput( $expected, $result, 0 );

    return;
}

sub test_param_buttonrow_top_edit {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      Foswiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlSystemWeb =
        Foswiki::Func::getUrlHost()
      . Foswiki::Func::getPubUrlPath() . '/'
      . $Foswiki::cfg{SystemWebName};

    my $query = Unit::Request->new(
        {
            etedit    => ['on'],
            ettablenr => ['1'],
        }
    );

    my $text = <<'INPUT';
%EDITTABLE{buttonrow="top"}%
INPUT

    $query->path_info("/$webName/$topicName");

    $this->createNewFoswikiSession( undef, $query );
    my $result =
      Foswiki::Func::expandCommonVariables( $text, $topicName, $webName,
        undef );

    my $expected = <<"EXPECTED";
%TABLE{disableallsort="on" databg="#fff"}%
<noautolink>
<a name="edittable1"></a>
<div class="editTable editTableEdit">
<form name="edittable1" action="$viewUrlAuth#edittable1" method="post">
<input type="submit" name="etsave" id="etsave" value="Save table" class="foswikiSubmit" />
<input type="submit" name="etqsave" id="etqsave" value="Quiet save" class="foswikiButton" />
<input type="submit" name="etaddrow" id="etaddrow" value="Add row" class="foswikiButton" />
<input type="submit" name="etdelrow" id="etdelrow" value="Delete last row" class="foswikiButton" />
<input type="submit" name="etcancel" id="etcancel" value="Cancel" class="foswikiButtonCancel" />
<input type="hidden" name="ettablenr" value="1" />
<input type="hidden" name="etedit" value="on" />
| <input class="foswikiInputField editTableInput" type="text" name="etcell1x1" size="16" value="" /> |
<input type="hidden" name="ettablechanges" value="1=1" />
<input type="hidden" name="etheaderrows" value="0" />
<input type="hidden" name="etfooterrows" value="0" />
</form>
</div><!-- /editTable --></noautolink>
EXPECTED

    $this->do_testHtmlOutput( $expected, $result, 0 );

    return;
}

=pod

Test if saving is keeping <verbatim> tags inside table.

=cut

sub test_save_with_verbatim_inside_table {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      Foswiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlSystemWeb =
        Foswiki::Func::getUrlHost()
      . Foswiki::Func::getPubUrlPath() . '/'
      . $Foswiki::cfg{SystemWebName};

    my $input = <<'INPUT';
%EDITTABLE{}%
| *text* |
| <verbatim class="foswikiAlert">inside verbatim</verbatim> |
INPUT
    my $query = Unit::Request->new(
        {
            etedit    => ['on'],
            ettablenr => ['1'],
        }
    );

    $query->path_info("/$webName/$topicName");

    $this->createNewFoswikiSession( undef, $query );

    $query = Unit::Request->new(
        {
            etsave    => ['on'],
            ettablenr => ['1'],
        }
    );

    $query->path_info("/$webName/$topicName");
    $query->method('POST');

    Foswiki::Func::saveTopic( $this->{test_web}, $this->{test_topic}, undef,
        $input );

    $this->createNewFoswikiSession( undef, $query );
    my $response = Unit::Response->new();

    my ( $saveResult, $ecode ) = $this->capture(
        sub {
            $response->print(
                Foswiki::Func::expandCommonVariables(
                    $input, $this->{test_topic}, $this->{test_web}, undef
                )
            );
        }
    );

    my ( $meta, $newtext ) = Foswiki::Func::readTopic( $webName, $topicName );

    my $expected = <<'NEWEXPECTED';
%EDITTABLE{}%
| *text* |
| <verbatim class="foswikiAlert">inside verbatim</verbatim> |
NEWEXPECTED
    $this->assert_str_equals( $expected, $newtext, 0 );

    return;
}

=pod

Test if saving is keeping <verbatim> tags outside of tables.

=cut

sub test_save_with_verbatim_in_topic {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      Foswiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlSystemWeb =
        Foswiki::Func::getUrlHost()
      . Foswiki::Func::getPubUrlPath() . '/'
      . $Foswiki::cfg{SystemWebName};

    my $input = <<'INPUT';
%EDITTABLE{}%
| *text* |

<verbatim>
INSIDE VERBATIM
</verbatim>
INPUT
    my $query = Unit::Request->new(
        {
            etedit    => ['on'],
            ettablenr => ['1'],
        }
    );

    $query->path_info("/$webName/$topicName");

    $this->createNewFoswikiSession( undef, $query );

    $query = Unit::Request->new(
        {
            etsave    => ['on'],
            ettablenr => ['1'],
        }
    );

    $query->path_info("/$webName/$topicName");
    $query->method('POST');

    Foswiki::Func::saveTopic( $this->{test_web}, $this->{test_topic}, undef,
        $input );

    $this->createNewFoswikiSession( undef, $query );
    my $response = Unit::Response->new();

    my ( $saveResult, $ecode ) = $this->capture(
        sub {
            $response->print(
                Foswiki::Func::expandCommonVariables(
                    $input, $this->{test_topic}, $this->{test_web}, undef
                )
            );
        }
    );

    my ( $meta, $newtext ) = Foswiki::Func::readTopic( $webName, $topicName );

    my $expected = <<'NEWEXPECTED';
%EDITTABLE{}%
| *text* |

<verbatim>
INSIDE VERBATIM
</verbatim>
NEWEXPECTED
    $this->assert_str_equals( $expected, $newtext, 0 );

    return;
}

=pod

Test if an included table from a different topic is displayed.

=cut

sub test_INCLUDE_view {
    my $this = shift;

    # Create topic to include
    my $includedTopic = "TopicToInclude";
    Foswiki::Func::saveTopic( $this->{test_web}, $includedTopic, undef,
        <<'THIS');
%EDITTABLE{ format="| row, -1 | text, 20, init | select, 1, not started, starting, ongoing, completed | checkbox, 3,:-),:-I,:-( | date, 20 |" changerows="on" quietsave="on"}%
| *URL* | *Name* | *By* | *Comment* | *Timestamp* |
| 1 | Unified field theory | not started | :-) , :-I , :-( | 1 Apr 2012 |
| 2 | *Sliced* yoghourt | not started | :-) , :-I , :-( | 1 Jun 2002 |
| 3 | Cubical turkeys | not started | :-I | 1 Oct 2007 |
| 4 | Self-eating burritos | completed | :-I | 1 Apr 2008 |
THIS

    # include this in our test topic
    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuthTestTopic =
      Foswiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $viewUrlAuthOtherTopic =
      Foswiki::Func::getScriptUrl( $webName, $includedTopic, 'viewauth' );
    my $pubUrlSystemWeb =
        Foswiki::Func::getUrlHost()
      . Foswiki::Func::getPubUrlPath() . '/'
      . $Foswiki::cfg{SystemWebName};

    my $input = '%EDITTABLE{}%

%INCLUDE{"TopicToInclude"}%

%EDITTABLE{}%';

    my $expected = <<"END";
<a name="edittable1"></a>
<div class="editTable">
<form name="edittable1" action="$viewUrlAuthTestTopic#edittable1" method="post">
<input type="hidden" name="ettablenr" value="1" />
<input type="hidden" name="etedit" value="on" />
<input type="hidden" name="ettablechanges" value="" />
<input type="hidden" name="etheaderrows" value="0" />
<input type="hidden" name="etfooterrows" value="0" />
<input class="editTableEditImageButton" type="image" src="$pubUrlSystemWeb/EditTablePlugin/edittable.gif" alt="Edit this table" /> </form>
</div><!-- /editTable -->


<div class="editTable">
<form name="edittable1_TemporaryEditTableFunctionsTestWebEditTableFunctions_TestTopicEditTableFunctions" action="$viewUrlAuthOtherTopic#edittable1" method="post">
<input type="hidden" name="ettablenr" value="1" />
<input type="hidden" name="etedit" value="on" />
| *URL* | *Name* | *By* | *Comment* | *Timestamp* |
| 1 | Unified field theory | not started | :-) , :-I , :-( | 1 Apr 2012 |
| 2 | *Sliced* yoghourt | not started | :-) , :-I , :-( | 1 Jun 2002 |
| 3 | Cubical turkeys | not started | :-I | 1 Oct 2007 |
| 4 | Self-eating burritos | completed | :-I | 1 Apr 2008 |
<input type="hidden" name="ettablechanges" value="" />
<input type="hidden" name="etheaderrows" value="0" />
<input type="hidden" name="etfooterrows" value="0" />
<input class="editTableEditImageButton" type="image" src="$pubUrlSystemWeb/EditTablePlugin/edittable.gif" alt="Edit this table" /> </form>
</div><!-- /editTable -->


<a name="edittable2"></a>
<div class="editTable">
<form name="edittable2" action="$viewUrlAuthTestTopic#edittable2" method="post">
<input type="hidden" name="ettablenr" value="2" />
<input type="hidden" name="etedit" value="on" />
<input type="hidden" name="ettablechanges" value="" />
<input type="hidden" name="etheaderrows" value="0" />
<input type="hidden" name="etfooterrows" value="0" />
<input class="editTableEditImageButton" type="image" src="$pubUrlSystemWeb/EditTablePlugin/edittable.gif" alt="Edit this table" /> </form>
</div><!-- /editTable -->
END

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $topicName, $webName );
    $this->do_testHtmlOutput( $expected, $result, 0 );

    return;
}

=pod

Includes a topic that has an EDITTABLE with param 'include' set: the table definition is in a third topic.

=cut

sub test_INCLUDE_include {
    my $this = shift;

    # Create topic with table definition
    my $tableDefTopic = "QmsCommentTable";
    Foswiki::Func::saveTopic( $this->{test_web}, $tableDefTopic, undef,
        <<'THIS');
%EDITTABLE{ header="|* Section *|* Description *|* Severity *|*  Status *|* Originator & Date *|" format="| text, 10 | textarea, 10x60  | select, 1, Major, Minor, Note | select, 1, Originated, Assessed, Performed, Rejected | text, 20 |" changerows="on" }%
THIS

    my $includeTopic = "ProcedureSysarch000Comments";
    Foswiki::Func::saveTopic( $this->{test_web}, $includeTopic, undef,
        <<'THIS');
%EDITTABLE{ include="QmsCommentTable" }%
|*Section*|*Description*|*Severity*|*Status*|*Originator & Date*|
THIS

    # include this in our test topic
    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuthTestTopic =
      Foswiki::Func::getScriptUrl( $webName, $includeTopic, 'viewauth' );

    my $viewUrlAuthOtherTopic =
      Foswiki::Func::getScriptUrl( $webName, $includeTopic, 'viewauth' );

    my $pubUrlSystemWeb =
        Foswiki::Func::getUrlHost()
      . Foswiki::Func::getPubUrlPath() . '/'
      . $Foswiki::cfg{SystemWebName};

    my $input = '%INCLUDE{"ProcedureSysarch000Comments"}%';

    my $expected = <<"END";
<div class="editTable">
<form name="edittable1_TemporaryEditTableFunctionsTestWebEditTableFunctions_TestTopicEditTableFunctions" action="$viewUrlAuthTestTopic#edittable1" method="post">
<input type="hidden" name="ettablenr" value="1" />
<input type="hidden" name="etedit" value="on" />
|*Section*|*Description*|*Severity*|*Status*|*Originator & Date*|
<input type="hidden" name="ettablechanges" value="" />
<input type="hidden" name="etheaderrows" value="0" />
<input type="hidden" name="etfooterrows" value="0" />
<input class="editTableEditImageButton" type="image" src="$pubUrlSystemWeb/EditTablePlugin/edittable.gif" alt="Edit this table" /> </form>
</div><!-- /editTable -->
END

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $topicName, $webName );
    $this->do_testHtmlOutput( $expected, $result, 0 );

    return;
}

=pod

Test if macro EDITCELL is preserved after saving

=cut

sub test_macro_EDITCELL_save {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      Foswiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlSystemWeb =
        Foswiki::Func::getUrlHost()
      . Foswiki::Func::getPubUrlPath() . '/'
      . $Foswiki::cfg{SystemWebName};

    my $input = <<'INPUT';
%EDITTABLE{}% 
| a | Some text |
| b | More text |

%EDITTABLE{ format="| label | text, 40 |" changerows="off" }%
| *Key* | *Value* |
| Gender: | F %EDITCELL{select, 1, , F, M}% |
| DOB: | 8 February 2009 %EDITCELL{date, 10}% |
INPUT
    my $query = Unit::Request->new(
        {
            etedit    => ['on'],
            ettablenr => ['1'],
        }
    );

    $query->path_info("/$webName/$topicName");

    $this->createNewFoswikiSession( undef, $query );

    $query = Unit::Request->new(
        {
            etsave    => ['on'],
            ettablenr => ['1'],
        }
    );

    $query->path_info("/$webName/$topicName");
    $query->method('POST');

    Foswiki::Func::saveTopic( $this->{test_web}, $this->{test_topic}, undef,
        $input );

    $this->createNewFoswikiSession( undef, $query );
    my $response = Unit::Response->new();

    my ( $saveResult, $ecode ) = $this->capture(
        sub {
            $response->print(
                Foswiki::Func::expandCommonVariables(
                    $input, $this->{test_topic}, $this->{test_web}, undef
                )
            );
        }
    );

    my ( $meta, $newtext ) = Foswiki::Func::readTopic( $webName, $topicName );

    my $expected = <<'NEWEXPECTED';
%EDITTABLE{}% 
| a | Some text |
| b | More text |

%EDITTABLE{ format="| label | text, 40 |" changerows="off" }%
| *Key* | *Value* |
| Gender: | F %EDITCELL{select, 1, , F, M}% |
| DOB: | 8 February 2009 %EDITCELL{date, 10}% |
NEWEXPECTED
    $this->assert_str_equals( $expected, $newtext, 0 );

    return;
}

=pod

Tests if CALC is rendered in view mode, if CALC is outside an EditTable

=cut

sub test_CALC_in_table_other_than_EDITTABLE {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      Foswiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlSystemWeb =
        Foswiki::Func::getUrlHost()
      . Foswiki::Func::getPubUrlPath() . '/'
      . $Foswiki::cfg{SystemWebName};

    my $input = '
| *Item Description* | *Qty* | *Reason* | *Unit Price* | *Total Price* |
| Hej Ho | 4 | Hello | 50000 | %CALC{"$PRODUCT(R$ROW():C$COLUMN(-3)..R$ROW():C$COLUMN(-1))"}% |
| Jah No | 2 | Hello | 150000 | %CALC{"$PRODUCT(R$ROW():C$COLUMN(-3)..R$ROW():C$COLUMN(-1))"}% |
| | | | 0 | %CALC{"$PRODUCT(R$ROW():C$COLUMN(-3)..R$ROW():C$COLUMN(-1))"}% |
| *Total* | | | | *%CALC{"$SUM($ABOVE())"}%* |

%EDITTABLE{ format="| label | text, 40 |" changerows="off" }%
| *Key* | *Value* |
| Gender: | F %EDITCELL{select, 1, , F, M}% |
| DOB: | 8 February 2009 %EDITCELL{date, 10}% |
';

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web}, undef );
    my $expected = '
| *Item Description* | *Qty* | *Reason* | *Unit Price* | *Total Price* |
| Hej Ho | 4 | Hello | 50000 | 200000 |
| Jah No | 2 | Hello | 150000 | 300000 |
| | | | 0 | 0 |
| *Total* | | | | *500000* |


<a name="edittable1"></a>
<div class="editTable">
<form name="edittable1" action="' . $viewUrlAuth . '#edittable1" method="post">
<input type="hidden" name="ettablenr" value="1" />
<input type="hidden" name="etedit" value="on" />
| *Key* | *Value* |
| Gender: | F  |
| DOB: | 8 February 2009  |
<input type="hidden" name="ettablechanges" value="" />
<input type="hidden" name="etheaderrows" value="0" />
<input type="hidden" name="etfooterrows" value="0" />
<input class="editTableEditImageButton" type="image" src="'
      . $pubUrlSystemWeb
      . '/EditTablePlugin/edittable.gif" alt="Edit this table" /> </form>
</div><!-- /editTable -->
';

    trimSpaces($expected);
    trimSpaces($result);

    $this->assert_str_equals( $expected, $result, 0 );

    return;
}

=pod

Test if TablePlugin parameters are read if the tag is on the same line as EDITTABLE: TABLE after EDITTABLE

=cut

sub test_TABLE_on_same_line_as_EDITTABLE_TABLE_last {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $cgi       = $this->{request};
    my $url       = $cgi->url( -absolute => 1 );

    my $viewUrlAuth =
      Foswiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubPathSystemWeb =
      Foswiki::Func::getPubUrlPath() . '/' . $Foswiki::cfg{SystemWebName};

    my $input = '   * Set MYNAMES = Ed, Kenneth,Benny 
   * Set EXTRACT = %CALC{ $LISTJOIN( - , $LISTIF($NOT($EXACT($item,)),$LEFT())) }% 

%EDITTABLE{ quietsave="off" editbutton="Update table" format="| date,,%SERVERTIME{"$day $mon $year"}%,%e %b %Y | date,,,%e %b %Y | select,4,%MYNAMES% | text,20 | radio, 7, , :-), :cool:, :-I, :D, :mad:, :( | label,1,$percntEXTRACT$percnt |" }%%TABLE{initsort="1"}%
| *Startdate* | *Stopdate* | *Who* | *What/Where* | *Icon* | *Details* |
| 3 Jan 2008 | 22 Jan 2008 | Benny | Vacation | :-) | %EXTRACT% |';

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $topicName, $webName );

    my $expected = <<"EXPECTED";
 <ul>
<li> Set MYNAMES = Ed, Kenneth,Benny 
</li> <li> Set EXTRACT =  R0:C1..R0:C-1
</li></ul> 
<p />
<nop>
<a name="edittable1"></a>
<div class="editTable">
<form name="edittable1" action="$viewUrlAuth#edittable1" method="post">
<input type="hidden" name="ettablenr" value="1" />
<input type="hidden" name="etedit" value="on" />
<nop>
<nop>
<table id="table$this->{test_topic}1" class="foswikiTable" border="1" rules="none">
	<thead>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<th class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol"> <a rel="nofollow" href="$url/$webName/$topicName?sortcol=0;table=1;up=1#sorted_table" title="Sort by this column">Startdate</a><span class="tableSortIcon tableSortUp"><img width="11" alt="Sorted ascending" src="$pubPathSystemWeb/DocumentGraphics/tablesortup.gif" title="Sorted ascending" height="13" border="0" /></span> </th>
			<th class="foswikiTableCol1"> <a rel="nofollow" href="$url/$webName/$topicName?sortcol=1;table=1;up=0#sorted_table" title="Sort by this column">Stopdate</a> </th>
			<th class="foswikiTableCol2"> <a rel="nofollow" href="$url/$webName/$topicName?sortcol=2;table=1;up=0#sorted_table" title="Sort by this column">Who</a> </th>
			<th class="foswikiTableCol3"> <a rel="nofollow" href="$url/$webName/$topicName?sortcol=3;table=1;up=0#sorted_table" title="Sort by this column">What/Where</a> </th>
			<th class="foswikiTableCol4"> <a rel="nofollow" href="$url/$webName/$topicName?sortcol=4;table=1;up=0#sorted_table" title="Sort by this column">Icon</a> </th>
			<th class="foswikiTableCol5 foswikiLastCol"> <a rel="nofollow" href="$url/$webName/$topicName?sortcol=5;table=1;up=0#sorted_table" title="Sort by this column">Details</a> </th>
		</tr>
	</thead>
	<tbody>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td  rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLast"> 3 Jan 2008 </td>
			<td  rowspan="1" class="foswikiTableCol1 foswikiLast"> 22 Jan 2008 </td>
			<td  rowspan="1" class="foswikiTableCol2 foswikiLast"> Benny </td>
			<td  rowspan="1" class="foswikiTableCol3 foswikiLast"> Vacation </td>
			<td  rowspan="1" class="foswikiTableCol4 foswikiLast"> <img alt="smile" class="smily" src="$pubPathSystemWeb/SmiliesPlugin/emoticon-0100-smile.gif" title="smile"> </img> </td>
			<td  rowspan="1" class="foswikiTableCol5 foswikiLastCol foswikiLast"> %EXTRACT% </td>
		</tr>
	</tbody></table>
<input type="hidden" name="ettablechanges" value="" />
<input type="hidden" name="etheaderrows" value="0" />
<input type="hidden" name="etfooterrows" value="0" />
<input class="foswikiButton editTableEditButton" type="submit" value="Update table" /> </form>
</div><!-- /editTable -->
EXPECTED

    $this->do_testHtmlOutput( $expected, $result, 1 );

    return;
}

=pod

Test if TablePlugin parameters are read if the tag is on the same line as EDITTABLE: TABLE before EDITTABLE

=cut

sub test_TABLE_on_same_line_as_EDITTABLE_TABLE_first {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $cgi       = $this->{request};
    my $url       = $cgi->url( -absolute => 1 );

    my $viewUrlAuth =
      Foswiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubPathSystemWeb =
      Foswiki::Func::getPubUrlPath() . '/' . $Foswiki::cfg{SystemWebName};

    my $input = '   * Set MYNAMES = Ed, Kenneth,Benny 
   * Set EXTRACT = %CALC{ $LISTJOIN( - , $LISTIF($NOT($EXACT($item,)),$LEFT())) }% 

%TABLE{initsort="1"}%%EDITTABLE{ quietsave="off" editbutton="Update table" format="| date,,%SERVERTIME{"$day $mon $year"}%,%e %b %Y | date,,,%e %b %Y | select,4,%MYNAMES% | text,20 | radio, 7, , :-), :cool:, :-I, :D, :mad:, :( | label,1,$percntEXTRACT$percnt |" }%
| *Startdate* | *Stopdate* | *Who* | *What/Where* | *Icon* | *Details* |
| 3 Jan 2008 | 22 Jan 2008 | Benny | Vacation | :-) | %EXTRACT% |';

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $topicName, $webName );

    my $expected = <<"EXPECTED";
 <ul>
<li> Set MYNAMES = Ed, Kenneth,Benny 
</li> <li> Set EXTRACT =  R0:C1..R0:C-1
</li></ul> 
<p />
<nop>
<a name="edittable1"></a>
<div class="editTable">
<form name="edittable1" action="$viewUrlAuth#edittable1" method="post">
<input type="hidden" name="ettablenr" value="1" />
<input type="hidden" name="etedit" value="on" />
<nop>
<nop>
<table id="table$this->{test_topic}1" class="foswikiTable" border="1" rules="none">
	<thead>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<th class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol"> <a rel="nofollow" href="$url/$webName/$topicName?sortcol=0;table=1;up=1#sorted_table" title="Sort by this column">Startdate</a><span class="tableSortIcon tableSortUp"><img width="11" alt="Sorted ascending" src="$pubPathSystemWeb/DocumentGraphics/tablesortup.gif" title="Sorted ascending" height="13" border="0" /></span> </th>
			<th class="foswikiTableCol1"> <a rel="nofollow" href="$url/$webName/$topicName?sortcol=1;table=1;up=0#sorted_table" title="Sort by this column">Stopdate</a> </th>
			<th class="foswikiTableCol2"> <a rel="nofollow" href="$url/$webName/$topicName?sortcol=2;table=1;up=0#sorted_table" title="Sort by this column">Who</a> </th>
			<th class="foswikiTableCol3"> <a rel="nofollow" href="$url/$webName/$topicName?sortcol=3;table=1;up=0#sorted_table" title="Sort by this column">What/Where</a> </th>
			<th class="foswikiTableCol4"> <a rel="nofollow" href="$url/$webName/$topicName?sortcol=4;table=1;up=0#sorted_table" title="Sort by this column">Icon</a> </th>
			<th class="foswikiTableCol5 foswikiLastCol"> <a rel="nofollow" href="$url/$webName/$topicName?sortcol=5;table=1;up=0#sorted_table" title="Sort by this column">Details</a> </th>
		</tr>
	</thead>
	<tbody>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td  rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLast"> 3 Jan 2008 </td>
			<td  rowspan="1" class="foswikiTableCol1 foswikiLast"> 22 Jan 2008 </td>
			<td  rowspan="1" class="foswikiTableCol2 foswikiLast"> Benny </td>
			<td  rowspan="1" class="foswikiTableCol3 foswikiLast"> Vacation </td>
			<td  rowspan="1" class="foswikiTableCol4 foswikiLast"> <img alt="smile" class="smily" src="$pubPathSystemWeb/SmiliesPlugin/emoticon-0100-smile.gif" title="smile"> </img> </td>
			<td  rowspan="1" class="foswikiTableCol5 foswikiLastCol foswikiLast"> %EXTRACT% </td>
		</tr>
	</tbody></table>
<input type="hidden" name="ettablechanges" value="" />
<input type="hidden" name="etheaderrows" value="0" />
<input type="hidden" name="etfooterrows" value="0" />
<input class="foswikiButton editTableEditButton" type="submit" value="Update table" /> </form>
</div><!-- /editTable -->
EXPECTED

    $this->do_testHtmlOutput( $expected, $result, 1 );

    return;
}

=pod

Tests the substitution of SpreadSheetPlugin formulas by 'CALC' in edit mode.

=cut

sub test_CALC_substitution {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      Foswiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlSystemWeb =
      Foswiki::Func::getPubUrlPath() . '/' . $Foswiki::cfg{SystemWebName};

    my $input = <<"INPUT";
%EDITTABLE{}%
| Project A | SW | P1 | CT5 | SW Dev | 2 | 4 | 2 || 2 || 6345 | %CALC{"\$EVAL(\$T(R\$ROW():C6) * \$T(R\$ROW():C\$COLUMN(-1)))"}% | Q4 |
| Total ||||| *%CALC{"\$SUM(\$ABOVE())"}%* | *%CALC{"\$SUMPRODUCT(R2:C6..R\$ROW(-1):C6, R2:C\$COLUMN(0)..R\$ROW(-1):C\$COLUMN(0))"}%* | *%CALC{"\$SUMPRODUCT(R2:C6..R\$ROW(-1):C6, R2:C\$COLUMN(0)..R\$ROW(-1):C\$COLUMN(0))"}%* | *%CALC{"\$SUMPRODUCT(R2:C6..R\$ROW(-1):C6, R2:C\$COLUMN(0)..R\$ROW(-1):C\$COLUMN(0))"}%* | *%CALC{"\$SUMPRODUCT(R2:C6..R\$ROW(-1):C6, R2:C\$COLUMN(0)..R\$ROW(-1):C\$COLUMN(0))"}%* | *%CALC{"\$SUMPRODUCT(R2:C6..R\$ROW(-1):C6, R2:C\$COLUMN(0)..R\$ROW(-1):C\$COLUMN(0))"}%* || *%CALC{"\$SUM(\$ABOVE())"}%* ||
INPUT

    my $query = Unit::Request->new(
        {
            etedit    => ['on'],
            ettablenr => ['1'],
        }
    );

    $query->path_info("/$webName/$topicName");

    $this->createNewFoswikiSession( undef, $query );

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web}, undef );

    my $expected = '
%TABLE{disableallsort="on" databg="#fff"}%
<noautolink>
<a name="edittable1"></a>
<div class="editTable editTableEdit">
<form name="edittable1" action="' . $viewUrlAuth . '#edittable1" method="post">
<input type="hidden" name="ettablenr" value="1" />
<input type="hidden" name="etedit" value="on" />
| <input class="foswikiInputField editTableInput" type="text" name="etcell1x1" size="16" value="--EditTableEncodeStart--.P.r.o.j.e.c.t. .A--EditTableEncodeEnd--" /> | <input class="foswikiInputField editTableInput" type="text" name="etcell1x2" size="16" value="--EditTableEncodeStart--.S.W--EditTableEncodeEnd--" /> | <input class="foswikiInputField editTableInput" type="text" name="etcell1x3" size="16" value="--EditTableEncodeStart--.P.1--EditTableEncodeEnd--" /> | <input class="foswikiInputField editTableInput" type="text" name="etcell1x4" size="16" value="--EditTableEncodeStart--.C.T.5--EditTableEncodeEnd--" /> | <input class="foswikiInputField editTableInput" type="text" name="etcell1x5" size="16" value="--EditTableEncodeStart--.S.W. .D.e.v--EditTableEncodeEnd--" /> | <input class="foswikiInputField editTableInput" type="text" name="etcell1x6" size="16" value="--EditTableEncodeStart--.2--EditTableEncodeEnd--" /> | <input class="foswikiInputField editTableInput" type="text" name="etcell1x7" size="16" value="--EditTableEncodeStart--.4--EditTableEncodeEnd--" /> | <input class="foswikiInputField editTableInput" type="text" name="etcell1x8" size="16" value="--EditTableEncodeStart--.2--EditTableEncodeEnd--" /> | <input class="foswikiInputField editTableInput" type="text" name="etcell1x9" size="16" value="" /> | <input class="foswikiInputField editTableInput" type="text" name="etcell1x10" size="16" value="--EditTableEncodeStart--.2--EditTableEncodeEnd--" /> | <input class="foswikiInputField editTableInput" type="text" name="etcell1x11" size="16" value="" /> | <input class="foswikiInputField editTableInput" type="text" name="etcell1x12" size="16" value="--EditTableEncodeStart--.6.3.4.5--EditTableEncodeEnd--" /> | <input class="foswikiInputField editTableInput" type="text" name="etcell1x13" size="16" value="--EditTableEncodeStart--.%.C.A.L.C.{.".$.E.V.A.L.(.$.T.(.R.$.R.O.W.(.).:.C.6.). .*. .$.T.(.R.$.R.O.W.(.).:.C.$.C.O.L.U.M.N.(.-.1.).).).".}.%--EditTableEncodeEnd--" /> | <input class="foswikiInputField editTableInput" type="text" name="etcell1x14" size="16" value="--EditTableEncodeStart--.Q.4--EditTableEncodeEnd--" /> |
| <input class="foswikiInputField editTableInput" type="text" name="etcell2x1" size="16" value="--EditTableEncodeStart--.T.o.t.a.l--EditTableEncodeEnd--" /> | <input class="foswikiInputField editTableInput" type="text" name="etcell2x2" size="16" value="" /> | <input class="foswikiInputField editTableInput" type="text" name="etcell2x3" size="16" value="" /> | <input class="foswikiInputField editTableInput" type="text" name="etcell2x4" size="16" value="" /> | <input class="foswikiInputField editTableInput" type="text" name="etcell2x5" size="16" value="" /> | *<span class=\'editTableCalc\'>CALC</span>* <input type="hidden" name="etcell2x6" value="--EditTableEncodeStart--.*.%.C.A.L.C.{.".$.S.U.M.(.$.A.B.O.V.E.(.).).".}.%.*--EditTableEncodeEnd--" /> | *<span class=\'editTableCalc\'>CALC</span>* <input type="hidden" name="etcell2x7" value="--EditTableEncodeStart--.*.%.C.A.L.C.{.".$.S.U.M.P.R.O.D.U.C.T.(.R.2.:.C.6.%.d.o.t.%.%.d.o.t.%.R.$.R.O.W.(.-.1.).:.C.6.,. .R.2.:.C.$.C.O.L.U.M.N.(.0.).%.d.o.t.%.%.d.o.t.%.R.$.R.O.W.(.-.1.).:.C.$.C.O.L.U.M.N.(.0.).).".}.%.*--EditTableEncodeEnd--" /> | *<span class=\'editTableCalc\'>CALC</span>* <input type="hidden" name="etcell2x8" value="--EditTableEncodeStart--.*.%.C.A.L.C.{.".$.S.U.M.P.R.O.D.U.C.T.(.R.2.:.C.6.%.d.o.t.%.%.d.o.t.%.R.$.R.O.W.(.-.1.).:.C.6.,. .R.2.:.C.$.C.O.L.U.M.N.(.0.).%.d.o.t.%.%.d.o.t.%.R.$.R.O.W.(.-.1.).:.C.$.C.O.L.U.M.N.(.0.).).".}.%.*--EditTableEncodeEnd--" /> | *<span class=\'editTableCalc\'>CALC</span>* <input type="hidden" name="etcell2x9" value="--EditTableEncodeStart--.*.%.C.A.L.C.{.".$.S.U.M.P.R.O.D.U.C.T.(.R.2.:.C.6.%.d.o.t.%.%.d.o.t.%.R.$.R.O.W.(.-.1.).:.C.6.,. .R.2.:.C.$.C.O.L.U.M.N.(.0.).%.d.o.t.%.%.d.o.t.%.R.$.R.O.W.(.-.1.).:.C.$.C.O.L.U.M.N.(.0.).).".}.%.*--EditTableEncodeEnd--" /> | *<span class=\'editTableCalc\'>CALC</span>* <input type="hidden" name="etcell2x10" value="--EditTableEncodeStart--.*.%.C.A.L.C.{.".$.S.U.M.P.R.O.D.U.C.T.(.R.2.:.C.6.%.d.o.t.%.%.d.o.t.%.R.$.R.O.W.(.-.1.).:.C.6.,. .R.2.:.C.$.C.O.L.U.M.N.(.0.).%.d.o.t.%.%.d.o.t.%.R.$.R.O.W.(.-.1.).:.C.$.C.O.L.U.M.N.(.0.).).".}.%.*--EditTableEncodeEnd--" /> | *<span class=\'editTableCalc\'>CALC</span>* <input type="hidden" name="etcell2x11" value="--EditTableEncodeStart--.*.%.C.A.L.C.{.".$.S.U.M.P.R.O.D.U.C.T.(.R.2.:.C.6.%.d.o.t.%.%.d.o.t.%.R.$.R.O.W.(.-.1.).:.C.6.,. .R.2.:.C.$.C.O.L.U.M.N.(.0.).%.d.o.t.%.%.d.o.t.%.R.$.R.O.W.(.-.1.).:.C.$.C.O.L.U.M.N.(.0.).).".}.%.*--EditTableEncodeEnd--" /> | <input class="foswikiInputField editTableInput" type="text" name="etcell2x12" size="16" value="" /> | *<span class=\'editTableCalc\'>CALC</span>* <input type="hidden" name="etcell2x13" value="--EditTableEncodeStart--.*.%.C.A.L.C.{.".$.S.U.M.(.$.A.B.O.V.E.(.).).".}.%.*--EditTableEncodeEnd--" /> | <input class="foswikiInputField editTableInput" type="text" name="etcell2x14" size="16" value="" /> |
<input type="hidden" name="ettablechanges" value="1=0,2=0" />
<input type="hidden" name="etheaderrows" value="0" />
<input type="hidden" name="etfooterrows" value="0" />
<input type="submit" name="etsave" id="etsave" value="Save table" class="foswikiSubmit" />
<input type="submit" name="etqsave" id="etqsave" value="Quiet save" class="foswikiButton" />
<input type="submit" name="etaddrow" id="etaddrow" value="Add row" class="foswikiButton" />
<input type="submit" name="etdelrow" id="etdelrow" value="Delete last row" class="foswikiButton" />
<input type="submit" name="etcancel" id="etcancel" value="Cancel" class="foswikiButtonCancel" />
</form>
</div><!-- /editTable --></noautolink>';

    $this->do_testHtmlOutput( lc $expected, lc $result, 0 );

    return;
}

=pod

Parameter changerows

=cut

sub test_param_changerows_off {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      Foswiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlSystemWeb =
      Foswiki::Func::getPubUrlPath() . '/' . $Foswiki::cfg{SystemWebName};

    my $input = <<'INPUT';
%EDITTABLE{changerows="off"}%
INPUT

    my $query = Unit::Request->new(
        {
            etedit    => ['on'],
            ettablenr => ['1'],
        }
    );

    $query->path_info("/$webName/$topicName");

    $this->createNewFoswikiSession( undef, $query );

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web}, undef );

    my $expected = <<"EXPECTED";
%TABLE{disableallsort="on" databg="#fff"}%
<noautolink>
<a name="edittable1"></a>
<div class="editTable editTableEdit">
<form name="edittable1" action="$viewUrlAuth#edittable1" method="post">
<input type="hidden" name="ettablenr" value="1" />
<input type="hidden" name="etedit" value="on" />
| <input class="foswikiinputfield edittableinput" type="text" name="etcell1x1" size="16" value="" /> |
<input type="hidden" name="ettablechanges" value="1=1" />
<input type="hidden" name="etheaderrows" value="0" />
<input type="hidden" name="etfooterrows" value="0" />
<input type="submit" name="etsave" id="etsave" value="save table" class="foswikisubmit" />
<input type="submit" name="etqsave" id="etqsave" value="quiet save" class="foswikibutton" />
<input type="submit" name="etcancel" id="etcancel" value="cancel" class="foswikibuttoncancel" />
</form>
</div><!-- /editTable --></noautolink>
EXPECTED
    $this->do_testHtmlOutput( lc $expected, lc $result, 0 );

    return;
}

=pod

Test if saving is keeping ENCODE parameters

=cut

sub test_save_with_encode_param_and_footerrows {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      Foswiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlSystemWeb =
        Foswiki::Func::getUrlHost()
      . Foswiki::Func::getPubUrlPath() . '/'
      . $Foswiki::cfg{SystemWebName};

    my $input = <<'INPUT';
%TABLE{columnwidths="%ENCODE{"80"}%,80" dataalign="left,center" headeralign="left,center" headerrows="1" footerrows="1"}%
%EDITTABLE{}%
| *Customer* | *Pass* |
| A | B |
| *Customer* | *Pass* |
INPUT
    my $query = Unit::Request->new(
        {
            etedit    => ['on'],
            ettablenr => ['1'],
        }
    );

    $query->path_info("/$webName/$topicName");

    $this->createNewFoswikiSession( undef, $query );

    $query = Unit::Request->new(
        {
            etsave    => ['on'],
            etaddrow  => ['1'],
            ettablenr => ['1'],
        }
    );

    $query->path_info("/$webName/$topicName");
    $query->method('POST');

    Foswiki::Func::saveTopic( $this->{test_web}, $this->{test_topic}, undef,
        $input );

    $this->createNewFoswikiSession( undef, $query );
    my $response = Unit::Response->new();

    my ( $saveResult, $ecode ) = $this->capture(
        sub {
            $response->print(
                Foswiki::Func::expandCommonVariables(
                    $input, $this->{test_topic}, $this->{test_web}, undef
                )
            );
        }
    );

    my ( $meta, $newtext ) = Foswiki::Func::readTopic( $webName, $topicName );

    my $expected = <<'NEWEXPECTED';
%TABLE{columnwidths="%ENCODE{"80"}%,80" dataalign="left,center" headeralign="left,center" headerrows="1" footerrows="1"}%
%EDITTABLE{}%
| *Customer* | *Pass* |
| A | B |
| *Customer* | *Pass* |
NEWEXPECTED
    $this->assert_str_equals( $expected, $newtext, 0 );

    return;
}

=pod

This TML has caused infinite recursion in Foswiki 1.0.4.

=cut

sub test_render_simple_with_verbatim_and_unfinished_table_rows {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      Foswiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlSystemWeb =
        Foswiki::Func::getUrlHost()
      . Foswiki::Func::getPubUrlPath() . '/'
      . $Foswiki::cfg{SystemWebName};

    my $input = '%EDITTABLE{format="textarea, 4x20"}%
| x | <verbatim> y
z </verbatim> |';

    my $expected = <<"END";
<a name="edittable1"></a>
<div class="editTable">
<form name="edittable1" action="$viewUrlAuth#edittable1" method="post">
<input type="hidden" name="ettablenr" value="1" />
<input type="hidden" name="etedit" value="on" />
| x | <verbatim> y
z </verbatim> |
<input type="hidden" name="ettablechanges" value="" />
<input type="hidden" name="etheaderrows" value="0" />
<input type="hidden" name="etfooterrows" value="0" />
<input class="editTableEditImageButton" type="image" src="$pubUrlSystemWeb/EditTablePlugin/edittable.gif" alt="Edit this table" />
</form>
</div><!-- /editTable -->
END
    my $result =
      Foswiki::Func::expandCommonVariables( $input, $topicName, $webName );
    $this->do_testHtmlOutput( $expected, $result, 0 );

    return;
}

# EditTableData tests

=pod

=cut

sub test_createTableChangesMap {
    my $this = shift;

    my $map =
      Foswiki::Plugins::EditTablePlugin::EditTableData::createTableChangesMap(
        ' 0 = 0 , 1 = 1 , 3 = -1 ');
    $this->assert_equals( $map->{0}, 0 );
    $this->assert_equals( $map->{1}, 1 );
    $this->assert_equals( $map->{3}, -1 );

    return;
}

=pod

=cut

sub test_tableChangesMapToParamString {
    my $this = shift;

    my $map = {
        '0' => '0',
        '1' => '-1',
        '5' => '1',
    };

    my $paramString =
      Foswiki::Plugins::EditTablePlugin::EditTableData::tableChangesMapToParamString(
        $map);
    $this->assert_equals( $paramString, '0=0,1=-1,5=1' );

    return;
}

=pod

=cut

sub test_getTableStatistics {
    my $this = shift;

    my $editTableData = Foswiki::Plugins::EditTablePlugin::EditTableData->new();
    $editTableData->{rowCount}       = 3;
    $editTableData->{headerRowCount} = 1;
    $editTableData->{footerRowCount} = 0;

    my $changesMap = {
        '0' => '0',
        '5' => '1',
    };

    my $stats = $editTableData->getTableStatistics($changesMap);

    $this->assert_equals( $stats->{rowCount},     4 );
    $this->assert_equals( $stats->{added},        1 );
    $this->assert_equals( $stats->{deleted},      0 );
    $this->assert_equals( $stats->{bodyRowCount}, 3 );
}

=pod

=cut

sub test_applyChangesToChangesMap {
    my $this = shift;

    my $editTableData = Foswiki::Plugins::EditTablePlugin::EditTableData->new();

    my $changesMap    = {};
    my $newChangesMap = {
        '0' => '1',
        '1' => '1',
    };

    $changesMap =
      Foswiki::Plugins::EditTablePlugin::EditTableData::applyChangesToChangesMap(
        $changesMap, $newChangesMap );

    my $stats = $editTableData->getTableStatistics($changesMap);

    $this->assert_equals( $stats->{rowCount},     2 );
    $this->assert_equals( $stats->{added},        2 );
    $this->assert_equals( $stats->{deleted},      0 );
    $this->assert_equals( $stats->{bodyRowCount}, 2 );
}

=pod

Tests to add:

test_SETTING_CHANGEROWS
test_SETTING_QUIETSAVE
test_SETTING_EDIT_BUTTON
test_SETTING_SAVE_BUTTON
test_SETTING_QUIET_SAVE_BUTTON
test_SETTING_ADD_ROW_BUTTON
test_SETTING_DELETE_LAST_ROW_BUTTON
test_SETTING_CANCEL_BUTTON
test_SETTING_INCLUDED_TOPIC_DOES_NOT_EXIST

test_param_javascriptinterface_off
test_spreadsheet_formula_in_label (code not yet complete)

%EDITTABLE{}%
| *Title* |
| Static entry |
%SEARCH{
"name~'*Web*'"
type="query"
format="| $topic |"
nonoise="on"
limit="5"
}%

=cut

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
