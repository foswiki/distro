use strict;

package RenderFormTests;

use base qw(FoswikiFnTestCase);

use strict;

use Foswiki::Meta;
use File::Temp;

my $testtopic1 = "TestTopic1";
my $testtopic2 = "TestTopic2";
use vars qw( $codedir );

BEGIN {
    # create a fabby little type, just to make sure it gets called
    $codedir = File::Temp::tempdir( CLEANUP => 1 );
    mkdir("$codedir/Foswiki") || die $!;
    mkdir("$codedir/Foswiki/Form") || die $!;
    open(F, ">$codedir/Foswiki/Form/Nuffin.pm") || die $!;

    my $code = <<CODE;
package Foswiki::Form::Nuffin;
use base 'Foswiki::Form::FieldDefinition';

sub renderForEdit {
    return ('EXTRA', 'SWEET');
}

sub renderForDisplay {
    return 'SOUR';
}

1;
CODE
    print F $code;
    close(F) || die $!;
    push(@INC, $codedir);
}

# Set up the test fixture
sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    Foswiki::Func::saveTopic( $this->{test_web}, "WebPreferences", undef, <<HERE );
   * Set WEBFORMS = InitializationForm
HERE

    my $meta = new Foswiki::Meta($this->{twiki}, $this->{test_web}, $testtopic1);
    $meta->put('FORM', { name=>"InitializationForm" });
    $meta->putKeyed(
        'FIELD',
        { name=>"IssueName",
          attributes=>"M", title=>"Issue Name", value=>"_An issue_"});
    $meta->putKeyed(
        'FIELD',
        { name=>"IssueDescription",
          attributes=>"", title=>"Issue Description", value=>"---+ Example problem"});
    $meta->putKeyed(
        'FIELD',
        { name=>"Issue1",
          attributes=>"", title=>"Issue 1:", value=>"*Defect*"});
    $meta->putKeyed(
        'FIELD',
        { name=>"Issue2",
          attributes=>"", title=>"Issue 2:", value=>"Enhancement"});
    $meta->putKeyed(
        'FIELD',
        { name=>"Issue3",
          attributes=>"", title=>"Issue 3:", value=>"Defect, None"});
    $meta->putKeyed(
        'FIELD',
        { name=>"Issue4",
          attributes=>"", title=>"Issue 4:", value=>"Defect"});
    $meta->putKeyed(
        'FIELD',
        { name=>"Issue5",
          attributes=>"", title=>"Issue 5:", value=>"Foo, Baz"});
    $meta->putKeyed(
        'FIELD',
        { name=>"State",
          attributes=>"H", title=>"State", value=>"Invisible"});
    $meta->putKeyed(
        'FIELD',
        { name=>"Anothertopic",
          attributes=>"", title=>"Another topic", value=>"GRRR "});

    Foswiki::Func::saveTopic( $this->{test_web}, $testtopic1, $meta, 'TT1' );

    $meta = new Foswiki::Meta($this->{twiki}, $this->{test_web}, $testtopic2);
    $meta->put('FORM', { name=>"InitializationForm",
                     });
    $meta->putKeyed(
        'FIELD',
        { name=>"IssueName",
          attributes=>"M", title=>"Issue Name", value=>"_An issue_"});
    $meta->putKeyed(
        'FIELD',
        { name=>"IssueDescription",
          attributes=>"", title=>"IssueDescription", value=>"| abc | 123 |\r\n| def | ghk |"});
    $meta->putKeyed(
        'FIELD',
        { name=>"Issue1",
          attributes=>"", title=>"Issue1", value=>"*no web*"});
    $meta->putKeyed(
        'FIELD',
        { name=>"Issue2",
          attributes=>"", title=>"Issue2", value=>",   * abc\r\n   * def\r\n      * geh\r\n   * ijk"});
    $meta->putKeyed(
        'FIELD',
        { name=>"Issue3",
          attributes=>"", title=>"Issue3", value=>"_hello world_"});
    $meta->putKeyed(
        'FIELD',
        { name=>"Issue4",
          attributes=>"", title=>"Issue4", value=>",   * high"});
    $meta->putKeyed(
        'FIELD',
        { name=>"Issue5",
          attributes=>"", title=>"Issue5", value=>"Foo, Baz"});
    $meta->putKeyed(
        'FIELD',
        { name=>"State",
          attributes=>"H", title=>"State", value=>"Invisible"});
    $meta->putKeyed(
        'FIELD',
        { name=>"Anothertopic",
          attributes=>"", title=>"Another topic", value=>"GRRR "});
    $meta->putKeyed( FIELD => { name=>'ZeroString', attributes=>'', title=>'Zero', value=>'0' } );
    $meta->putKeyed( FIELD => { name=>'ZeroNumber', attributes=>'', title=>'Zero', value=>0 } );
    Foswiki::Func::saveTopic( $this->{test_web}, $testtopic2, $meta, 'TT2' );
}

sub setForm {
    my $this = shift;
    Foswiki::Func::saveTopic( $this->{test_web}, "InitializationForm", undef, <<HERE );
| *Name*            | *Type*       | *Size* | *Values*      |
| Issue Name        | text         | 40     |               |
| State             | radio        |        | none          |
| Issue Description | label        | 10     | 5             |
| Issue 1           | select       |        |               |
| Issue 2           | nuffin       |        |               |
| Issue 3           | checkbox     |        |               |
| Issue 4           | textarea     |        |               |
| Issue 5           | select+multi | 3      | Foo, Bar, Baz |
Topic is deliberately missing
HERE
}

# Simple test; no forms in place, just check value rendering
sub test_render_formfield_raw {

    my $this = shift;
    my($meta, $text) =
      $this->{twiki}->{store}->readTopic(undef, $this->{test_web}, $testtopic2);
    my $render = $this->{twiki}->renderer;
    my $res;

    $res = $meta->renderFormFieldForDisplay( "IssueDescription", '| $title | $value |', { newline=>'NL', bar=>"BAR" } );

    $this->assert_str_equals('| IssueDescription | BAR abc BAR 123 BARNLBAR def BAR ghk BAR |', $res);

    $res = $meta->renderFormFieldForDisplay( "Issue1", '$value > $title', { newline=>'NL', bar=>"BAR" } );
    $this->assert_str_equals('*no web* > Issue1', $res);
    $res = $meta->renderFormFieldForDisplay( "Issue2", '$value', { newline=>'NL', bar=>"BAR" } );
    $this->assert_str_equals(',   * abcNL   * defNL      * gehNL   * ijk', $res);
    $res = $meta->renderFormFieldForDisplay( "Issue3", '$value', { newline=>'NL', bar=>"BAR" } );
    $this->assert_str_equals('_hello world_', $res);
    $res = $meta->renderFormFieldForDisplay( "Issue4", '$value > $title', { newline=>'NL', bar=>"BAR" } );
    $this->assert_str_equals(',   * high > Issue4', $res);
    $res = $meta->renderFormFieldForDisplay( "State", '', { newline=>'NL', bar=>"BAR" } );
    $this->assert_str_equals('', $res);
    $res = $meta->renderFormFieldForDisplay( 'ZeroString', '$value' );
    $this->assert_str_equals('0', $res);
    $res = $meta->renderFormFieldForDisplay( 'ZeroNumber', '$value' );
    $this->assert_str_equals('0', $res);
}

# Simple test; form in place, just check value rendering
sub test_render_formfield_with_form {
    my $this = shift;

    $this->setForm();

    my($meta, $text) =
      $this->{twiki}->{store}->readTopic(undef, $this->{test_web}, $testtopic2);
    my $res = $meta->renderFormForDisplay();
    $this->assert_html_equals(<<HERE, $res);
<div class="foswikiForm">%IF{"context preview" then="<noautolink><h3>TemporaryRenderFormTestsTestWebRenderFormTests.InitializationForm</h3></noautolink> " else="<h3> TemporaryRenderFormTestsTestWebRenderFormTests.InitializationForm <span class='foswikiSmall'><a href='%SCRIPTURL{edit}%/%WEB%/%TOPIC%?t=%GMTIME{\$epoch}%;action=form'>%MAKETEXT{"edit"}%</a></span></h3>"}%<table class='foswikiFormTable' border='1'>%IF{"context preview" then="<noautolink>"}%<tr valign='top'><td class='foswikiFormTableRow foswikiFirstCol' align='right'> Issue Name </td><td>
_An issue_
</td></tr>%IF{"context preview" then="</noautolink>"}%%IF{"context preview" then="<noautolink>"}%<tr valign='top'><td class='foswikiFormTableRow foswikiFirstCol' align='right'> Issue Description </td><td>
&#124; abc &#124; 123 &#124;<br />&#124; def &#124; ghk &#124;
</td></tr>%IF{"context preview" then="</noautolink>"}%%IF{"context preview" then="<noautolink>"}%<tr valign='top'><td class='foswikiFormTableRow foswikiFirstCol' align='right'> Issue 1 </td><td>
*no web*
</td></tr>%IF{"context preview" then="</noautolink>"}%SOUR%IF{"context preview" then="<noautolink>"}%<tr valign='top'><td class='foswikiFormTableRow foswikiFirstCol' align='right'> Issue 3 </td><td>
_hello world_
</td></tr>%IF{"context preview" then="</noautolink>"}%%IF{"context preview" then="<noautolink>"}%<tr valign='top'><td class='foswikiFormTableRow foswikiFirstCol' align='right'> Issue 4 </td><td>
,   * high
</td></tr>%IF{"context preview" then="</noautolink>"}%%IF{"context preview" then="<noautolink>"}%<tr valign='top'><td class='foswikiFormTableRow foswikiFirstCol' align='right'> Issue 5 </td><td>
Foo, Baz
</td></tr>%IF{"context preview" then="</noautolink>"}%</table></div><!-- /foswikiForm -->
HERE
    ($meta, $text) =
      $this->{twiki}->{store}->readTopic(undef, $this->{test_web}, $testtopic1);
    $res = $meta->renderFormForDisplay();

    $this->assert_html_equals(<<HERE, $res);
<div class="foswikiForm">%IF{"context preview" then="<noautolink><h3>TemporaryRenderFormTestsTestWebRenderFormTests.InitializationForm</h3></noautolink> " else="<h3> TemporaryRenderFormTestsTestWebRenderFormTests.InitializationForm <span class='foswikiSmall'><a href='%SCRIPTURL{edit}%/%WEB%/%TOPIC%?t=%GMTIME{\$epoch}%;action=form'>%MAKETEXT{"edit"}%</a></span></h3>"}%<table class='foswikiFormTable' border='1'>%IF{"context preview" then="<noautolink>"}%<tr valign='top'><td class='foswikiFormTableRow foswikiFirstCol' align='right'> Issue Name </td><td>
_An issue_
</td></tr>%IF{"context preview" then="</noautolink>"}%%IF{"context preview" then="<noautolink>"}%<tr valign='top'><td class='foswikiFormTableRow foswikiFirstCol' align='right'> Issue Description </td><td>
---+ Example problem
</td></tr>%IF{"context preview" then="</noautolink>"}%%IF{"context preview" then="<noautolink>"}%<tr valign='top'><td class='foswikiFormTableRow foswikiFirstCol' align='right'> Issue 1 </td><td>
*Defect*
</td></tr>%IF{"context preview" then="</noautolink>"}%SOUR%IF{"context preview" then="<noautolink>"}%<tr valign='top'><td class='foswikiFormTableRow foswikiFirstCol' align='right'> Issue 3 </td><td>
Defect, None
</td></tr>%IF{"context preview" then="</noautolink>"}%%IF{"context preview" then="<noautolink>"}%<tr valign='top'><td class='foswikiFormTableRow foswikiFirstCol' align='right'> Issue 4 </td><td>
Defect
</td></tr>%IF{"context preview" then="</noautolink>"}%%IF{"context preview" then="<noautolink>"}%<tr valign='top'><td class='foswikiFormTableRow foswikiFirstCol' align='right'> Issue 5 </td><td>
Foo, Baz
</td></tr>%IF{"context preview" then="</noautolink>"}%</table></div><!-- /foswikiForm -->
HERE
}

sub test_render_for_edit {
    my $this = shift;
    $this->setForm();
    my ($meta, $text) =
      $this->{twiki}->{store}->readTopic(undef, $this->{test_web}, $testtopic1);
    my $formDef = new Foswiki::Form(
        $this->{twiki}, $this->{test_web}, "InitializationForm" );
    my $res = $formDef->renderForEdit($this->{test_web}, $testtopic1, $meta);
my $expected = <<HERE;
<div class="foswikiForm foswikiEditForm"><table class="foswikiFormTable">
<tr>
<th class="foswikiFormTableHRow" colspan="2"><a rel="nofollow" target="InitializationForm" href="%VIEWURL%/TemporaryRenderFormTestsTestWebRenderFormTests/InitializationForm" title="Details in separate window">TemporaryRenderFormTestsTestWebRenderFormTests.InitializationForm</a> <input type="submit" name="action_replaceform" value='Replace form...' class="foswikiChangeFormButton foswikiButton" /></th>
</tr> 
<tr><th align="right">Issue Name</th><td align="left"><input type="text" name="IssueName" value="_An issue_" size="40" class="foswikiInputField" /></td></tr>
<tr><th align="right">State</th><td align="left"><table><tr><td><label><input type="radio" name="State" value="none"  label="none" class="foswikiRadioButton"/>none</label></td></tr></table></td></tr>
<tr><th align="right">Issue Description</th><td align="left"><input type="hidden" name="IssueDescription" value="---+ Example problem"  /><div><nop><h1>
<a name="Example_problem"> </a> Example problem </h1></div></td></tr>
<tr><th align="right">Issue 1</th><td align="left"><select name="Issue1" class="foswikiSelect" size="1"></select></td></tr>
<tr><th align="right">Issue 2EXTRA</th><td align="left">SWEET</td></tr>
<tr><th align="right">Issue 3</th><td align="left"><table></table><input type="hidden" name="Issue3" value="" /></td></tr>
<tr><th align="right">Issue 4</th><td align="left"><textarea name="Issue4"  rows="4" cols="50" class="foswikiTextarea">
Defect</textarea></td></tr>
<tr><th align="right">Issue 5</th><td align="left"><select name="Issue5" multiple="on" class="foswikiSelect" size="3"><option class="foswikiOption" selected="selected">Foo</option><option class="foswikiOption">Bar</option><option class="foswikiOption" selected="selected">Baz</option></select><input type="hidden" name="Issue5" value="" /></td></tr> </table>  </div>
HERE

    #Foswiki::Func::writeDebug("-----------------\n$res\n------------------");

    my $viewUrl = $this->{twiki}->getScriptUrl(0, 'view');
    $expected =~ s/%VIEWURL%/$viewUrl/g;

    $this->assert_html_equals($expected, $res);
}

sub test_render_hidden {
    my $this = shift;
    $this->setForm();
    my ($meta, $text) =
      $this->{twiki}->{store}->readTopic(undef, $this->{test_web}, $testtopic1);
    my $formDef = new Foswiki::Form(
        $this->{twiki}, $this->{test_web}, "InitializationForm" );
    my $res = $formDef->renderHidden($meta);
    $this->assert_html_equals(<<'HERE', $res);
<input type="hidden" name="IssueName" value="_An issue_"  /><input type="hidden" name="State" value="Invisible"  /><input type="hidden" name="IssueDescription" value="---+ Example problem"  /><input type="hidden" name="Issue1" value="*Defect*"  /><input type="hidden" name="Issue2" value="Enhancement"  /><input type="hidden" name="Issue3" value="Defect"  /><input type="hidden" name="Issue3" value="None"  /><input type="hidden" name="Issue4" value="Defect"  /><input type="hidden" name="Issue5" value="Foo"  /><input type="hidden" name="Issue5" value="Baz"  />
HERE
}

sub test_nondefined_form {
    my $this = shift;
    my $web = $this->{test_web};
    my $topic = 'FormDoesntExist';
   
    my $rawtext = '
%META:FORM{name="NonExistantPluginTestForm"}%
%META:FIELD{name="ExtensionName" attributes="" title="ExtensionName" value="Example"}%
%META:FIELD{name="TopicClassification" attributes="" title="TopicClassification" value="SkinPackage"}%
%META:FIELD{name="TestedOnFoswiki" attributes="" title="TestedOnFoswiki" value=""}%
%META:FIELD{name="TestedOnTWiki" attributes="" title="TestedOnTWiki" value=""}%
%META:FIELD{name="TestedOnOS" attributes="" title="TestedOnOS" value="AnyOS"}%
%META:FIELD{name="ShouldRunOnOS" attributes="" title="ShouldRunOnOS" value="AnyOS"}%
%META:FIELD{name="DemoUrl" attributes="" title="DemoUrl" value="http://"}%
%META:FIELD{name="DevelopedInSVN" attributes="" title="DevelopedInSVN" value="No"}%
%META:FIELD{name="ModificationPolicy" attributes="" title="ModificationPolicy" value="ContactAuthorFirst"}%';

    Foswiki::Func::saveTopic( $web, $topic, undef, $rawtext );
        
    my ($meta, $text) =
      $this->{twiki}->{store}->readTopic(undef, $web, $topic);
    my $res = $meta->renderFormForDisplay();

    $this->assert_html_equals(<<'HERE', $res);
<span class="foswikiAlert">%MAKETEXT{"Form definition '[_1]' not found" args="NonExistantPluginTestForm"}%</span><div class="foswikiForm">%IF{"context preview" then="<noautolink><h3>TemporaryRenderFormTestsTestWebRenderFormTests.NonExistantPluginTestForm</h3></noautolink> " else="<h3> TemporaryRenderFormTestsTestWebRenderFormTests.NonExistantPluginTestForm <span class='foswikiSmall'><a href='%SCRIPTURL{edit}%/%WEB%/%TOPIC%?t=%GMTIME{$epoch}%;action=form'>%MAKETEXT{"edit"}%</a></span></h3>"}%<table class='foswikiFormTable' border='1'>%IF{"context preview" then="<noautolink>"}%<tr valign='top'><td class='foswikiFormTableRow foswikiFirstCol' align='right'> ModificationPolicy </td><td>
ContactAuthorFirst
</td></tr>%IF{"context preview" then="</noautolink>"}%%IF{"context preview" then="<noautolink>"}%<tr valign='top'><td class='foswikiFormTableRow foswikiFirstCol' align='right'> ExtensionName </td><td>
Example
</td></tr>%IF{"context preview" then="</noautolink>"}%%IF{"context preview" then="<noautolink>"}%<tr valign='top'><td class='foswikiFormTableRow foswikiFirstCol' align='right'> TopicClassification </td><td>
SkinPackage
</td></tr>%IF{"context preview" then="</noautolink>"}%%IF{"context preview" then="<noautolink>"}%<tr valign='top'><td class='foswikiFormTableRow foswikiFirstCol' align='right'> TestedOnFoswiki </td><td>

</td></tr>%IF{"context preview" then="</noautolink>"}%%IF{"context preview" then="<noautolink>"}%<tr valign='top'><td class='foswikiFormTableRow foswikiFirstCol' align='right'> TestedOnTWiki </td><td>

</td></tr>%IF{"context preview" then="</noautolink>"}%%IF{"context preview" then="<noautolink>"}%<tr valign='top'><td class='foswikiFormTableRow foswikiFirstCol' align='right'> TestedOnOS </td><td>
AnyOS
</td></tr>%IF{"context preview" then="</noautolink>"}%%IF{"context preview" then="<noautolink>"}%<tr valign='top'><td class='foswikiFormTableRow foswikiFirstCol' align='right'> ShouldRunOnOS </td><td>
AnyOS
</td></tr>%IF{"context preview" then="</noautolink>"}%%IF{"context preview" then="<noautolink>"}%<tr valign='top'><td class='foswikiFormTableRow foswikiFirstCol' align='right'> DemoUrl </td><td>
http://
</td></tr>%IF{"context preview" then="</noautolink>"}%%IF{"context preview" then="<noautolink>"}%<tr valign='top'><td class='foswikiFormTableRow foswikiFirstCol' align='right'> DevelopedInSVN </td><td>
No
</td></tr>%IF{"context preview" then="</noautolink>"}%</table></div><!-- /foswikiForm -->
HERE
    
}

1;
