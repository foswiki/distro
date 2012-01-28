package RenderFormTests;
use strict;
use warnings;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki::Meta;
use File::Temp;
use Benchmark ':hireswallclock';

my $testtopic1 = 'TestTopic1';
my $testtopic2 = 'TestTopic2';
use vars qw( $codedir );

BEGIN {

    # create a fabby little type, just to make sure it gets called
    $codedir = File::Temp::tempdir( CLEANUP => 1 );
    mkdir("$codedir/Foswiki")      || die $!;
    mkdir("$codedir/Foswiki/Form") || die $!;

    my $code = <<'CODE';
package Foswiki::Form::Nuffin;
use Foswiki::Form::FieldDefinition;
our @ISA = qw( Foswiki::Form::FieldDefinition );

sub renderForEdit {
    return ('EXTRA', 'SWEET');
}

sub renderForDisplay {
    return 'SOUR';
}

1;
CODE

    open( my $F, '>', "$codedir/Foswiki/Form/Nuffin.pm" ) || die $!;
    print $F $code;
    close($F) || die $!;
    push( @INC, $codedir );
}

# Set up the test fixture
sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    Foswiki::Func::saveTopic( $this->{test_web}, "WebPreferences", undef,
        <<'HERE' );
   * Set WEBFORMS = InitializationForm
HERE

    my ($meta) = Foswiki::Func::readTopic( $this->{test_web}, $testtopic1 );
    $meta->put( 'FORM', { name => 'InitializationForm' } );
    $meta->putKeyed(
        'FIELD',
        {
            name       => 'IssueName',
            attributes => 'M',
            title      => 'Issue Name',
            value      => '_An issue_'
        }
    );
    $meta->putKeyed(
        'FIELD',
        {
            name       => 'IssueDescription',
            attributes => '',
            title      => 'Issue Description',
            value      => '---+ Example problem'
        }
    );
    $meta->putKeyed(
        'FIELD',
        {
            name       => 'Issue1',
            attributes => '',
            title      => 'Issue 1:',
            value      => '*Defect*'
        }
    );
    $meta->putKeyed(
        'FIELD',
        {
            name       => 'Issue2',
            attributes => '',
            title      => 'Issue 2:',
            value      => 'Enhancement'
        }
    );
    $meta->putKeyed(
        'FIELD',
        {
            name       => 'Issue3',
            attributes => '',
            title      => 'Issue 3:',
            value      => 'Defect, None'
        }
    );
    $meta->putKeyed(
        'FIELD',
        {
            name       => 'Issue4',
            attributes => '',
            title      => 'Issue 4:',
            value      => 'Defect'
        }
    );
    $meta->putKeyed(
        'FIELD',
        {
            name       => 'Issue5',
            attributes => '',
            title      => 'Issue 5:',
            value      => 'Foo, Baz'
        }
    );
    $meta->putKeyed(
        'FIELD',
        {
            name       => 'Issue6',
            attributes => '',
            title      => 'Issue 6',
            value      => '2'
        }
    );
    $meta->putKeyed(
        'FIELD',
        {
            name       => 'Issue7',
            attributes => '',
            title      => 'Issue 7',
            value      => '2'
        }
    );
    $meta->putKeyed(
        'FIELD',
        {
            name       => 'Issue8',
            attributes => '',
            title      => 'Issue 8',
            value      => '2'
        }
    );
    $meta->putKeyed(
        'FIELD',
        {
            name       => 'State',
            attributes => 'H',
            title      => 'State',
            value      => 'Invisible'
        }
    );
    $meta->putKeyed(
        'FIELD',
        {
            name       => 'Anothertopic',
            attributes => '',
            title      => 'Another topic',
            value      => 'GRRR '
        }
    );

    Foswiki::Func::saveTopic( $this->{test_web}, $testtopic1, $meta, 'TT1' );

    $meta->finish();
    ($meta) = Foswiki::Func::readTopic( $this->{test_web}, $testtopic2 );
    $meta->put( 'FORM', { name => 'InitializationForm', } );
    $meta->putKeyed(
        'FIELD',
        {
            name       => 'IssueName',
            attributes => 'M',
            title      => 'Issue Name',
            value      => '_An issue_'
        }
    );
    $meta->putKeyed(
        'FIELD',
        {
            name       => 'IssueDescription',
            attributes => '',
            title      => 'IssueDescription',
            value      => "| abc | 123 |\r\n| def | ghk |"
        }
    );
    $meta->putKeyed(
        'FIELD',
        {
            name       => 'Issue1',
            attributes => '',
            title      => 'Issue1',
            value      => '*no web*'
        }
    );
    $meta->putKeyed(
        'FIELD',
        {
            name       => 'Issue2',
            attributes => '',
            title      => 'Issue2',
            value      => ",   * abc\r\n   * def\r\n      * geh\r\n   * ijk"
        }
    );
    $meta->putKeyed(
        'FIELD',
        {
            name       => 'Issue3',
            attributes => '',
            title      => 'Issue3',
            value      => '_hello world_'
        }
    );
    $meta->putKeyed(
        'FIELD',
        {
            name       => 'Issue4',
            attributes => '',
            title      => 'Issue4',
            value      => ',   * high'
        }
    );
    $meta->putKeyed(
        'FIELD',
        {
            name       => 'Issue5',
            attributes => '',
            title      => 'Issue5',
            value      => 'Foo, Baz'
        }
    );
    $meta->putKeyed(
        'FIELD',
        {
            name       => 'Issue6',
            attributes => '',
            title      => 'Issue6',
            value      => '3'
        }
    );
    $meta->putKeyed(
        'FIELD',
        {
            name       => 'State',
            attributes => 'H',
            title      => 'State',
            value      => 'Invisible'
        }
    );
    $meta->putKeyed(
        'FIELD',
        {
            name       => 'Anothertopic',
            attributes => '',
            title      => 'Another topic',
            value      => 'GRRR '
        }
    );
    $meta->putKeyed(
        FIELD => {
            name       => 'ZeroString',
            attributes => '',
            title      => 'Zero',
            value      => '0'
        }
    );
    $meta->putKeyed(
        FIELD => {
            name       => 'ZeroNumber',
            attributes => '',
            title      => 'Zero',
            value      => 0
        }
    );

    Foswiki::Func::saveTopic( $this->{test_web}, $testtopic2, $meta, 'TT2' );
    return;
}

sub setForm {
    my $this = shift;
    Foswiki::Func::saveTopic( $this->{test_web}, "InitializationForm", undef,
        <<'HERE' );
| *Name*            | *Type*       | *Size* | *Values*      |
| Issue Name        | text         | 40     |               |
| State             | radio        |        | none          |
| Issue Description | label        | 10     | 5             |
| Issue 1           | select       |        |               |
| Issue 2           | nuffin       |        |               |
| Issue 3           | checkbox     |        |               |
| Issue 4           | textarea     |        |               |
| Issue 5           | select+multi | 3      | Foo, Bar, Baz |
| Issue 6           | select+values | 1     | One=1, Two=2, Three=3, Four=4 | 
| Issue 7           | checkbox+values | 1   | One=1, Two=2, Three=3, Four=4 | 
| Issue 8           | radio+values | 1      | One=1, Two=2, Three=3, Four=4 | 
Topic is deliberately missing
HERE
    return;
}

# Simple test; no forms in place, just check value rendering
sub test_render_formfield_raw {

    my $this = shift;
    my ($meta) = Foswiki::Func::readTopic( $this->{test_web}, $testtopic2 );
    my $text   = $meta->text;
    my $render = $this->{session}->renderer;
    my $res;

    $res = $meta->renderFormFieldForDisplay(
        "IssueDescription",
        '| $title | $value |',
        { newline => 'NL', bar => "BAR" }
    );

    $this->assert_str_equals(
        '| IssueDescription | BAR abc BAR 123 BARNLBAR def BAR ghk BAR |',
        $res );

    $res = $meta->renderFormFieldForDisplay(
        "Issue1",
        '$value > $title',
        { newline => 'NL', bar => "BAR" }
    );
    $this->assert_str_equals( '*no web* > Issue1', $res );
    $res =
      $meta->renderFormFieldForDisplay( "Issue2", '$value',
        { newline => 'NL', bar => "BAR" } );
    $this->assert_str_equals( ',   * abcNL   * defNL      * gehNL   * ijk',
        $res );
    $res =
      $meta->renderFormFieldForDisplay( "Issue3", '$value',
        { newline => 'NL', bar => "BAR" } );
    $this->assert_str_equals( '_hello world_', $res );
    $res = $meta->renderFormFieldForDisplay(
        "Issue4",
        '$value > $title',
        { newline => 'NL', bar => "BAR" }
    );
    $this->assert_str_equals( ',   * high > Issue4', $res );
    $res =
      $meta->renderFormFieldForDisplay( "State", '',
        { newline => 'NL', bar => "BAR" } );
    $this->assert_str_equals( '', $res );
    $res = $meta->renderFormFieldForDisplay( 'ZeroString', '$value' );
    $this->assert_str_equals( '0', $res );
    $res = $meta->renderFormFieldForDisplay( 'ZeroNumber', '$value' );
    $this->assert_str_equals( '0', $res );
    return;
}

# Simple test; form in place, just check value rendering
# presumes pattern skin.
sub test_render_formfield_with_form {
    my $this = shift;

    $this->setForm();

    my ($meta) = Foswiki::Func::readTopic( $this->{test_web}, $testtopic2 );
    my $text   = $meta->text;
    my $res    = $meta->renderFormForDisplay();
    $this->assert_html_equals( <<"HERE", $res );
<div class="foswikiForm foswikiFormStep">%IF{"context preview" then="<noautolink><h3>TemporaryRenderFormTestsTestWebRenderFormTests.InitializationForm</h3></noautolink> " else="<h3> TemporaryRenderFormTestsTestWebRenderFormTests.InitializationForm <span class='foswikiSmall'><a href='%SCRIPTURL{edit}%/%WEB%/%TOPIC%?t=%GMTIME{\$epoch}%;action=form'>%MAKETEXT{"edit"}%</a></span></h3>"}%<table class='foswikiFormTable' border='1' summary='%MAKETEXT{"Form data"}%'>%IF{"context preview" then="<noautolink>"}%<tr valign='top'><td class='foswikiFormTableRow foswikiFirstCol' align='right'> Issue Name </td><td>
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
</td></tr>%IF{"context preview" then="</noautolink>"}%%IF{"context preview" then="<noautolink>"}%<tr valign='top'><td class='foswikiFormTableRow foswikiFirstCol' align='right'> Issue 6 </td><td>
Three </td></tr>%IF{"context preview" then="</noautolink>"}%</table></div>
HERE
    $meta->finish();
    ($meta) = Foswiki::Func::readTopic( $this->{test_web}, $testtopic1 );
    $text = $meta->text;
    $res  = $meta->renderFormForDisplay();

    $this->assert_html_equals( <<"HERE", $res );
<div class="foswikiForm foswikiFormStep">%IF{"context preview" then="<noautolink><h3>TemporaryRenderFormTestsTestWebRenderFormTests.InitializationForm</h3></noautolink> " else="<h3> TemporaryRenderFormTestsTestWebRenderFormTests.InitializationForm <span class='foswikiSmall'><a href='%SCRIPTURL{edit}%/%WEB%/%TOPIC%?t=%GMTIME{\$epoch}%;action=form'>%MAKETEXT{"edit"}%</a></span></h3>"}%<table class='foswikiFormTable' border='1' summary='%MAKETEXT{"Form data"}%'>%IF{"context preview" then="<noautolink>"}%<tr valign='top'><td class='foswikiFormTableRow foswikiFirstCol' align='right'> Issue Name </td><td>
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
</td></tr>%IF{"context preview" then="</noautolink>"}%%IF{"context preview" then="<noautolink>"}%<tr valign='top'><td class='foswikiFormTableRow foswikiFirstCol' align='right'> Issue 6 </td><td>
Two 
</td></tr>%IF{"context preview" then="</noautolink>"}%%IF{"context preview" then="<noautolink>"}%<tr valign='top'><td class='foswikiFormTableRow foswikiFirstCol' align='right'> Issue 7 </td><td>
Two 
</td></tr>%IF{"context preview" then="</noautolink>"}%%IF{"context preview" then="<noautolink>"}%<tr valign='top'><td class='foswikiFormTableRow foswikiFirstCol' align='right'> Issue 8 </td><td>
Two 
</td></tr>%IF{"context preview" then="</noautolink>"}%
</table></div>
HERE
    return;
}

sub test_render_for_edit {
    my $this = shift;

    # Force a site charset that will generate _ in the header
    $Foswiki::cfg{Site}{CharSet} = 'iso-8859-1';

    # Switch off compatible anchors
    $Foswiki::cfg{RequireCompatibleAnchors} = 0;

    $this->setForm();
    my ($meta) = Foswiki::Func::readTopic( $this->{test_web}, $testtopic1 );
    my $text = $meta->text;
    my $formDef =
      Foswiki::Form->new( $this->{session}, $this->{test_web},
        "InitializationForm" );
    my $res = $formDef->renderForEdit($meta);

    my $expected = <<'HERE';
<div class="foswikiForm foswikiEditForm">
<h3>Topic data</h3>
<table class="foswikiFormTable" summary="Topic data">

<tr><th>Issue Name</th><td align="left"><input type="text" name="IssueName" value="_An issue_" size="40" class="foswikiInputField" /></td></tr>
<tr><th>State</th><td align="left"><table><tr><td><label><input type="radio" name="State" value="none"  title="none" class="foswikiRadioButton"/>none</label></td></tr></table></td></tr>
<tr><th>Issue Description</th><td align="left"><input type="hidden" name="IssueDescription" value="---+ Example problem"  /><div><nop><h1>
<a name="Example_problem"> </a> Example problem </h1></div></td></tr>
<tr><th>Issue 1</th><td align="left"><select name="Issue1" class="foswikiSelect" size="1"></select></td></tr>
<tr><th>Issue 2EXTRA</th><td align="left">SWEET</td></tr>
<tr><th>Issue 3</th><td align="left"><table></table><input type="hidden" name="Issue3" value="" /></td></tr>
<tr><th>Issue 4</th><td align="left"><textarea name="Issue4"  rows="4" cols="50" class="foswikiTextarea">
Defect</textarea></td></tr>
<tr><th>Issue 5</th><td align="left"><select name="Issue5" multiple="multiple" class="foswikiSelect" size="3"><option class="foswikiOption" selected="selected">Foo</option><option class="foswikiOption">Bar</option><option class="foswikiOption" selected="selected">Baz</option></select><input type="hidden" name="Issue5" value="" /></td></tr>
<tr><th>Issue 6</th><td align="left"><select name="Issue6" class="foswikiSelect" size="1"><option value="1" class="foswikiOption">One</option><option value="2" selected="selected" class="foswikiOption">Two</option><option value="3" class="foswikiOption">Three</option><option value="4" class="foswikiOption">Four</option></select></td></tr>
<tr><th>Issue 7</th><td align="left"><table><tr><td><label><input type="checkbox" name="Issue7" value="1"  title="1" class="foswikiCheckbox"/>One</label></td></tr><tr><td><label><input type="checkbox" name="Issue7" value="2" checked="checked" title="2" class="foswikiCheckbox"/>Two</label></td></tr><tr><td><label><input type="checkbox" name="Issue7" value="3"  title="3" class="foswikiCheckbox"/>Three</label></td></tr><tr><td><label><input type="checkbox" name="Issue7" value="4"  title="4" class="foswikiCheckbox"/>Four</label></td></tr></table><input type="hidden" name="Issue7" value="" /></td></tr>
<tr><th>Issue 8</th><td align="left"><table><tr><td><label><input type="radio" name="Issue8" value="1"  title="1" class="foswikiRadioButton"/>One</label></td></tr><tr><td><label><input type="radio" name="Issue8" value="2" checked="checked" title="2" class="foswikiRadioButton"/>Two</label></td></tr><tr><td><label><input type="radio" name="Issue8" value="3"  title="3" class="foswikiRadioButton"/>Three</label></td></tr><tr><td><label><input type="radio" name="Issue8" value="4"  title="4" class="foswikiRadioButton"/>Four</label></td></tr></table></td></tr> 
<tr><th>Form definition</th><td><a rel="nofollow" target="InitializationForm" href="%VIEWURL%/TemporaryRenderFormTestsTestWebRenderFormTests/InitializationForm" title="Details in separate window">TemporaryRenderFormTestsTestWebRenderFormTests.InitializationForm</a> <input type="submit" name="action_replaceform" value='Replace form...' class="foswikiChangeFormButton foswikiButton" /></td></tr></table></div>
HERE

    #Foswiki::Func::writeDebug("-----------------\n$res\n------------------");

    my $viewUrl = $this->{session}->getScriptUrl( 0, 'view' );
    $expected =~ s/%VIEWURL%/$viewUrl/g;

    $this->assert_html_equals( $expected, $res );
    return;
}

sub test_render_hidden {
    my $this = shift;
    $this->setForm();
    my ($meta) = Foswiki::Func::readTopic( $this->{test_web}, $testtopic1 );
    my $text = $meta->text;
    my $formDef =
      Foswiki::Form->new( $this->{session}, $this->{test_web},
        "InitializationForm" );
    my $res = $formDef->renderHidden($meta);
    $this->assert_html_equals( <<'HERE', $res );
<input type="hidden" name="IssueName" value="_An issue_"  /><input type="hidden" name="State" value="Invisible"  /><input type="hidden" name="IssueDescription" value="---+ Example problem"  /><input type="hidden" name="Issue1" value="*Defect*"  /><input type="hidden" name="Issue2" value="Enhancement"  /><input type="hidden" name="Issue3" value="Defect"  /><input type="hidden" name="Issue3" value="None"  /><input type="hidden" name="Issue4" value="Defect"  /><input type="hidden" name="Issue5" value="Foo"  /><input type="hidden" name="Issue5" value="Baz"  /><input type="hidden" name="Issue6" value="2"  /><input type="hidden" name="Issue7" value="2"  /><input type="hidden" name="Issue8" value="2"  />
HERE
    return;
}

sub test_nondefined_form {
    my $this  = shift;
    my $web   = $this->{test_web};
    my $topic = 'FormDoesntExist';

    my $rawtext = <<'TOPIC';
%META:FORM{name="NonExistantPluginTestForm"}%
%META:FIELD{name="ExtensionName" attributes="" title="ExtensionName" value="Example"}%
%META:FIELD{name="TopicClassification" attributes="" title="TopicClassification" value="SkinPackage"}%
%META:FIELD{name="TestedOnFoswiki" attributes="" title="TestedOnFoswiki" value=""}%
%META:FIELD{name="TestedOnTWiki" attributes="" title="TestedOnTWiki" value=""}%
%META:FIELD{name="TestedOnOS" attributes="" title="TestedOnOS" value="AnyOS"}%
%META:FIELD{name="ShouldRunOnOS" attributes="" title="ShouldRunOnOS" value="AnyOS"}%
%META:FIELD{name="DemoUrl" attributes="" title="DemoUrl" value="http://"}%
%META:FIELD{name="DevelopedInSVN" attributes="" title="DevelopedInSVN" value="No"}%
%META:FIELD{name="ModificationPolicy" attributes="" title="ModificationPolicy" value="ContactAuthorFirst"}%
TOPIC

    Foswiki::Func::saveTopic( $web, $topic, undef, $rawtext );

    my ($meta) = Foswiki::Func::readTopic( $web, $topic );
    my $text   = $meta->text;
    my $res    = $meta->renderFormForDisplay();

    $this->assert_html_equals( <<'HERE', $res );
<span class='foswikiAlert'>
Form definition 'NonExistantPluginTestForm' not found
</span>
<div class="foswikiForm foswikiFormStep">
%IF{"context preview" then="<noautolink><h3>TemporaryRenderFormTestsTestWebRenderFormTests.NonExistantPluginTestForm</h3></noautolink> " else="<h3> TemporaryRenderFormTestsTestWebRenderFormTests.NonExistantPluginTestForm <span class='foswikiSmall'><a href='%SCRIPTURL{edit}%/%WEB%/%TOPIC%?t=%GMTIME{$epoch}%;action=form'>%MAKETEXT{"edit"}%</a></span></h3>"}%
<table class='foswikiFormTable' border='1' summary='%MAKETEXT{"Form data"}%'>%IF{"context preview" then="<noautolink>"}%
 <tr valign='top'>
  <td class='foswikiFormTableRow foswikiFirstCol' align='right'> ExtensionName </td>
  <td> Example </td>
 </tr>%IF{"context preview" then="</noautolink>"}%%IF{"context preview" then="<noautolink>"}%
 <tr valign='top'>
  <td class='foswikiFormTableRow foswikiFirstCol' align='right'> TopicClassification </td>
  <td> SkinPackage </td>
 </tr>%IF{"context preview" then="</noautolink>"}%%IF{"context preview" then="<noautolink>"}%
 <tr valign='top'>
  <td class='foswikiFormTableRow foswikiFirstCol' align='right'> TestedOnFoswiki </td>
  <td>  </td>
 </tr>%IF{"context preview" then="</noautolink>"}%%IF{"context preview" then="<noautolink>"}%
 <tr valign='top'>
  <td class='foswikiFormTableRow foswikiFirstCol' align='right'> TestedOnTWiki </td>
  <td>  </td>
 </tr>%IF{"context preview" then="</noautolink>"}%%IF{"context preview" then="<noautolink>"}%
 <tr valign='top'>
  <td class='foswikiFormTableRow foswikiFirstCol' align='right'> TestedOnOS </td>
  <td> AnyOS </td>
 </tr>%IF{"context preview" then="</noautolink>"}%%IF{"context preview" then="<noautolink>"}%
 <tr valign='top'>
  <td class='foswikiFormTableRow foswikiFirstCol' align='right'> ShouldRunOnOS </td>
  <td> AnyOS </td>
 </tr>%IF{"context preview" then="</noautolink>"}%%IF{"context preview" then="<noautolink>"}%
 <tr valign='top'>
  <td class='foswikiFormTableRow foswikiFirstCol' align='right'> DemoUrl </td>
  <td> http:// </td>
 </tr>%IF{"context preview" then="</noautolink>"}%%IF{"context preview" then="<noautolink>"}%
 <tr valign='top'>
  <td class='foswikiFormTableRow foswikiFirstCol' align='right'> DevelopedInSVN </td>
  <td> No </td>
 </tr>%IF{"context preview" then="</noautolink>"}%%IF{"context preview" then="<noautolink>"}%
 <tr valign='top'>
  <td class='foswikiFormTableRow foswikiFirstCol' align='right'> ModificationPolicy </td>
  <td> ContactAuthorFirst </td>
 </tr>%IF{"context preview" then="</noautolink>"}%
</table>
</div>

HERE

    return;
}

# Item11088 - the aim of this test is to measure the performance of the
# select+multi+values formfield type when its default values are a static list
sub test_timing_static_multivalues {
    my ($this) = @_;
    my @topics = Foswiki::Func::getTopicList( $Foswiki::cfg{SystemWebName} );
    my @list;

    foreach my $topic (@topics) {
        push( @list, Foswiki::Func::spaceOutWikiWord($topic) . '=' . $topic );
    }
    $this->timing_multivalues( 20, join( ', ', @list ) );

    return;
}

sub test_timing_dynamic_multivalues {
    my ($this) = @_;

    $this->timing_multivalues( 20,
'%SEARCH{ "1" type="query" web="%SYSTEMWEB%" nonoise="on" nofinalnewline="on" format="$percntSPACEOUT{$topic}$percnt=$topic" separator=", " }%'
    );

    return;
}

sub timing_multivalues {
    my ( $this, $numcycles, $values ) = @_;
    my ($formTopicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, "$this->{test_topic}Form" );
    $formTopicObject->text(<<"HERE");
| *Name* | *Type*              | *Size* | *Values* | *Tooltip* | *Attributes* |
| Topics | select+multi+values | 10     | $values  | Topic     |              |
HERE
    $formTopicObject->save();
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $topicObject->put( 'FORM',
        { name => $this->{test_web} . '.' . $this->{test_topic} . 'Form' } );
    $topicObject->put( 'FIELD',
        { name => 'Topics', value => $Foswiki::cfg{HomeTopicName} } );
    $topicObject->save();
    my $benchmark = timeit(
        $numcycles,
        sub {
            $topicObject->expandMacros(<<"HERE");
%META{"form"}%
HERE
        }
    );
    my $timestr = timestr($benchmark);

    print <<"HERE";
Timing for $numcycles cycles of %META{"form"}%
    $timestr
HERE

    return;
}

1;
