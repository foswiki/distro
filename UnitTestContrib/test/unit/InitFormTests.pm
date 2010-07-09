use strict;

package InitFormTests;

# TODO: Should we check untitled labels? There is some special processing there.

=pod

For the cairo release, we had agreed on the following algorithm: 

The order of priority of field initialization should be as follows: For a given form field 
   * If a value was passed in by a corresponding query parameter, that value should be taken, else 
   * If the existing topic has a corresponding field value, that value should be taken, else
   * If there is no existing topic and there is a templatetopic and there is a corresponding field value, that value should be taken, else 
   * If there is an initialization value defined in the formtemplate, that value should be taken, else 
   * The field value should be empty. 

There is some question as to what should happen to [[%SYSTEMWEB%.Macros][Macros]].
   * Of course the text is taken literally (i.e., variables are not expanded) when it is in the existing form of the topic being edited
   * When values are taken from a template topic, embedded variables are not expanded.
   * However, variables in values copied from a form are expanded.

The latter serves to, e.g., create timestamps when expanding =%<nop>SERVERTIME{"$day $mon $year $hour:$min"}%=. But there is currently now way of getting a variable unexpanded, so that it could be expanded later, from the form or template. (Note that EditTablePlugin allows the use of escapes, such as =$percnt=, =$dollar=, or =$nop= to prevent expansion.)

Secondly, it is maybe somewhat unintuitive that when text is taken from a template it is expanded.

Note further that a template is not used when an existing topic is edited, even if there is no form attached to that topic.

The testcases below assume that the correct interpretation is the one used in EditTablePlugin.

=cut

use FoswikiTestCase;
our @ISA = qw( FoswikiTestCase );
use Error qw( :try );

use Foswiki;
use Foswiki::UI::Edit;
use Foswiki::Form;
use Unit::Request;
use Unit::Response;
use Error qw( :try );

my $testweb    = "TemporaryTestWeb";
my $testtopic1 = "InitTestTopic1";
my $testtopic2 = "InitTestTopic2";
my $testtopic3 = "InitTestTopic3";
my $testform   = "InitTestForm";
my $testtmpl   = "InitTestTemplate";

my $user;
my $testuser1 = "TestUser1";
my $testuser2 = "TestUser2";

my $setup_failure = '';

my $aurl;    # Holds the %ATTACHURL%
my $surl;    # Holds the %SCRIPTURL%

my $testtmpl1 = <<'HERE';
%META:TOPICINFO{author="WikiGuest" date="1124568292" format="1.1" version="1.2"}%

-- Main.WikiGuest - 20 Aug 2005

%META:FORM{name="$testform"}%
%META:FIELD{name="IssueName" attributes="M" title="Issue Name" value="_An issue_"}%
%META:FIELD{name="IssueDescription" attributes="" title="Issue Description" value="---+ Example problem"}%
%META:FIELD{name="IssueType" attributes="" title="Issue Type" value="Defect"}%
%META:FIELD{name="History1" attributes="" title="History1" value="%SCRIPTURL%"}%
%META:FIELD{name="History2" attributes="" title="History2" value="%SCRIPTURL%"}%
%META:FIELD{name="History3" attributes="" title="History3" value="$percntSCRIPTURL%"}%
%META:FIELD{name="History4" attributes="" title="History4" value="$percntSCRIPTURL%"}%
HERE

my $testform1 = <<'HERE';
%META:TOPICINFO{author="guest" date="1025373031" format="1.0" version="1.3"}%
%META:TOPICPARENT{name="WebHome"}%
| *Name* | *Type* | *Size* | *Values* | *Tooltip messages* | *Mandatory* | 
| Issue Name | text | 73 | My first defect | Illustrative name of issue | M | 
| Issue Description | textarea | 55x5 | Simple description of problem | Short description of issue |  | 
| Issue Type | select | 1 | Defect, Enhancement, Other |  |  | 
| History1 | label | 1 | %ATTACHURL%	         	 |  | |
| History2 | text | 20 | %ATTACHURL%		         |  | |
| History3 | label | 1 | $percntATTACHURL%		 |  | |
| History4 | text | 20 | $percntATTACHURL%		 |  | |

HERE

my $testtext1 = <<'HERE';
%META:TOPICINFO{author="WikiGuest" date="1159721050" format="1.1" reprev="1.3" version="1.3"}%
Needs the following
   * TestFormInitFormA - Form to be attached
Then call <a href="%SCRIPTURL{"edit"}%/%WEB%/%TOPIC%?formtemplate=$testform">Edit</a>

HERE

my $testtext2 = <<'HERE';
%META:TOPICINFO{author="WikiGuest" date="1159721050" format="1.1" reprev="1.3" version="1.3"}%
Needs the following
   * TestFormInitFormA - Form to be attached
Then call <a href="%SCRIPTURL{"edit"}%/%WEB%/%TOPIC%?formtemplate=$testform">Edit</a>

%META:FORM{name="$testform"}%
%META:FIELD{name="IssueName" attributes="M" title="Issue Name" value="_An issue_"}%
%META:FIELD{name="IssueDescription" attributes="" title="Issue Description" value="---+ Example problem"}%
%META:FIELD{name="IssueType" attributes="" title="Issue Type" value="Defect"}%
%META:FIELD{name="History1" attributes="" title="History1" value="%SCRIPTURL%"}%
%META:FIELD{name="History2" attributes="" title="History2" value="%SCRIPTURL%"}%
%META:FIELD{name="History3" attributes="" title="History3" value="$percntSCRIPTURL%"}%
%META:FIELD{name="History4" attributes="" title="History4" value="$percntSCRIPTURL%"}%
HERE

my $testtext3 = <<'HERE';
%META:TOPICINFO{author="WikiGuest" date="1159721050" format="1.1" reprev="1.3" version="1.3"}%
...no text...
%META:FORM{name="InitTestForm"}%
%META:FIELD{name="IssueName" attributes="M" title="Issue Name" value="My first defect"}%
%META:FIELD{name="IssueDescription" attributes="" title="Issue Description" value="Simple description of problem"}%
%META:FIELD{name="IssueType" attributes="" title="Issue Type" value="Defect"}%
%META:FIELD{name="History1" attributes="" title="History1" value="%SCRIPTURL%"}%
%META:FIELD{name="History3" attributes="" title="History3" value="$percntSCRIPTURL%"}%
HERE

my $edittmpl1 = <<'HERE';
%FORMFIELDS%
HERE

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    my $query = new Unit::Request();
    $this->{session}  = new Foswiki( undef, $query );
    $this->{request}  = $query;
    $this->{response} = new Unit::Response();
    $user             = $this->{session}->{user};

    $aurl = $this->{session}->getPubUrl( 1, $testweb, $testform );
    $surl = $this->{session}->getScriptUrl(1);

    my $webObject = Foswiki::Meta->new( $this->{session}, $testweb );
    $webObject->populateNewWeb();

    $Foswiki::Plugins::SESSION = $this->{session};
    Foswiki::Func::saveTopicText( $testweb, $testtopic1, $testtext1, 1, 1 );
    Foswiki::Func::saveTopicText( $testweb, $testtopic2, $testtext2, 1, 1 );
    Foswiki::Func::saveTopicText( $testweb, $testtopic3, $testtext3, 1, 1 );
    Foswiki::Func::saveTopicText( $testweb, $testform,   $testform1, 1, 1 );
    Foswiki::Func::saveTopicText( $testweb, $testtmpl,   $testtmpl1, 1, 1 );
    Foswiki::Func::saveTopicText( $testweb, "MyeditTemplate", $edittmpl1, 1,
        1 );
    $this->{session}->enterContext('edit');
}

sub tear_down {
    my $this = shift;
    $this->removeWebFixture( $this->{session}, $testweb );
    $this->{session}->finish();
    $this->SUPER::tear_down();
}

# The right form values are created

sub get_formfield {

    # Not done at this point. Could walk the form to the right field and then
    # do a more precise comparison.
    my ( $fld, $text ) = @_;
    return $text;
}

sub setup_formtests {
    my ( $this, $web, $topic, $params ) = @_;

    $this->{session}->{webName}   = $web;
    $this->{session}->{topicName} = $topic;
    my $render = $this->{session}->renderer;

    use Foswiki::Attrs;
    my $attr = new Foswiki::Attrs($params);
    foreach my $k ( keys %$attr ) {
        next if $k eq '_RAW';
        $this->{request}->param( -name => $k, -value => $attr->{$k} );
    }

    # Now generate the form. We pass a template which throws everything away
    # but the form to allow for simpler analysis.
    my ( $text, $tmpl ) =
      Foswiki::UI::Edit::init_edit( $this->{session}, 'myedit' );

    return $tmpl;

}

sub test_form {
    my $this = shift;

    my $text = setup_formtests( $this, $testweb, $testtopic1,
        "formtemplate=\"$testweb.$testform\"" );

    $this->assert_html_matches(
'<input type="text" name="IssueName" value="My first defect" size="73" class="foswikiInputField foswikiMandatory" />',
        get_formfield( 1, $text )
    );
    $this->assert_html_matches(
'<textarea name="IssueDescription"  rows="5" cols="55" class="foswikiTextarea">
Simple description of problem</textarea>', get_formfield( 2, $text )
    );
    $this->assert_html_matches(
'<select name="IssueType" class="foswikiSelect" size="1"><option class="foswikiOption">Defect</option><option class="foswikiOption">Enhancement</option><option class="foswikiOption">Other</option></select>',
        get_formfield( 3, $text )
    );
    $this->assert_html_matches(
        '<input type="hidden" name="History1" value="' . $aurl . '"  />',
        get_formfield( 4, $text ) );
    $this->assert_html_matches(
        '<input type="text" name="History2" value="' 
          . $aurl
          . '" size="20" class="foswikiInputField" />',
        get_formfield( 5, $text )
    );
    $this->assert_html_matches(
        '<input type="hidden" name="History3" value="%ATTACHURL%"  />',
        get_formfield( 6, $text ) );
    $this->assert_html_matches(
'<input type="text" name="History4" value="%ATTACHURL%" size="20" class="foswikiInputField" />',
        get_formfield( 7, $text )
    );
}

sub test_tmpl_form {

    # Pass formTemplate and templateTopic
    my $this = shift;

    my $text = setup_formtests( $this, $testweb, $testtopic1,
"formtemplate=\"$testweb.$testform\" templatetopic=\"$testweb.$testtmpl\""
    );

    $this->assert_html_matches(
'<input type="text" name="IssueName" value="My first defect" size="73" class="foswikiInputField foswikiMandatory" />',
        get_formfield( 1, $text )
    );
    $this->assert_html_matches(
'<textarea name="IssueDescription"  rows="5" cols="55" class="foswikiTextarea">
Simple description of problem</textarea>', get_formfield( 2, $text )
    );
    $this->assert_html_matches(
'<select name="IssueType" class="foswikiSelect" size="1"><option class="foswikiOption">Defect</option><option class="foswikiOption">Enhancement</option><option class="foswikiOption">Other</option></select>',
        get_formfield( 3, $text )
    );
    $this->assert_html_matches(
        '<input type="hidden" name="History1" value="' . $aurl . '" />',
        get_formfield( 4, $text ) );
    $this->assert_html_matches(
        '<input type="text" name="History2" value="' 
          . $aurl
          . '" size="20" class="foswikiInputField" />',
        get_formfield( 5, $text )
    );
    $this->assert_html_matches(
        '<input type="hidden" name="History3" value="%ATTACHURL%"  />',
        get_formfield( 6, $text ) );
    $this->assert_html_matches(
'<input type="text" name="History4" value="%ATTACHURL%" size="20" class="foswikiInputField" />',
        get_formfield( 7, $text )
    );

}

sub test_tmpl_form_new {

    # Pass formTemplate and templateTopic to empty topic
    my $this = shift;

    my $text = setup_formtests( $this, $testweb, "${testtopic1}XXXXXXXXXX",
"formtemplate=\"$testweb.$testform\" templatetopic=\"$testweb.$testtmpl\""
    );

    $this->assert_html_matches(
'<input type="text" name="IssueName" value="_An issue_" size="73" class="foswikiInputField foswikiMandatory" />',
        get_formfield( 1, $text )
    );
    $this->assert_html_matches(
'<textarea name="IssueDescription"  rows="5" cols="55" class="foswikiTextarea">
---+ Example problem</textarea>', get_formfield( 2, $text )
    );
    $this->assert_html_matches(
'<select name="IssueType" class="foswikiSelect" size="1"><option class="foswikiOption" selected="selected">Defect</option><option class="foswikiOption">Enhancement</option><option class="foswikiOption">Other</option></select>',
        get_formfield( 3, $text )
    );
    $this->assert_html_matches(
        '<input type="hidden" name="History1" value="%SCRIPTURL%"  />',
        get_formfield( 4, $text ) );
    $this->assert_html_matches(
'<input type="text" name="History2" value="%SCRIPTURL%" size="20" class="foswikiInputField" />',
        get_formfield( 5, $text )
    );
    $this->assert_html_matches(
        '<input type="hidden" name="History3" value="%SCRIPTURL%"  />',
        get_formfield( 6, $text ) );
    $this->assert_html_matches(
'<input type="text" name="History4" value="%SCRIPTURL%" size="20" class="foswikiInputField" />',
        get_formfield( 7, $text )
    );

}

sub test_tmpl_form_existingform {

    # Pass formTemplate and templateTopic to topic with form
    my $this = shift;

    my $text = setup_formtests( $this, $testweb, "$testtopic2",
"formtemplate=\"$testweb.$testform\" templatetopic=\"$testweb.$testtmpl\""
    );

    $this->assert_html_matches(
'<input type="text" name="IssueName" value="_An issue_" size="73" class="foswikiInputField foswikiMandatory" />',
        get_formfield( 1, $text )
    );
    $this->assert_html_matches(
'<textarea name="IssueDescription"  rows="5" cols="55" class="foswikiTextarea">
---+ Example problem</textarea>', get_formfield( 2, $text )
    );
    $this->assert_html_matches(
'<select name="IssueType" class="foswikiSelect" size="1"><option class="foswikiOption" selected="selected">Defect</option><option class="foswikiOption">Enhancement</option><option class="foswikiOption">Other</option></select>',
        get_formfield( 3, $text )
    );
    $this->assert_html_matches(
        '<input type="hidden" name="History1" value="%SCRIPTURL%"  />',
        get_formfield( 4, $text ) );
    $this->assert_html_matches(
'<input type="text" name="History2" value="%SCRIPTURL%" size="20" class="foswikiInputField" />',
        get_formfield( 5, $text )
    );
    $this->assert_html_matches(
        '<input type="hidden" name="History3" value="%SCRIPTURL%"  />',
        get_formfield( 6, $text ) );
    $this->assert_html_matches(
'<input type="text" name="History4" value="%SCRIPTURL%" size="20" class="foswikiInputField" />',
        get_formfield( 7, $text )
    );

}

sub test_tmpl_form_params {

    # Pass query parameters
    my $this = shift;

    my $text = setup_formtests( $this, $testweb, "$testtopic1",
"formtemplate=\"$testweb.$testform\" templatetopic=\"$testweb.$testtmpl\" IssueName=\"_An issue_\" IssueDescription=\"---+ Example problem\" IssueType=\"Defect\" History1=\"%SCRIPTURL%\" History2=\"%SCRIPTURL%\" History3=\"\$percntSCRIPTURL%\" History4=\"\$percntSCRIPTURL%\" "
    );

    $this->assert_html_matches(
'<input type="text" name="IssueName" value="_An issue_" size="73" class="foswikiInputField foswikiMandatory" />',
        get_formfield( 1, $text )
    );
    $this->assert_html_matches(
'<textarea name="IssueDescription"  rows="5" cols="55" class="foswikiTextarea">
---+ Example problem</textarea>', get_formfield( 2, $text )
    );
    $this->assert_html_matches(
'<select name="IssueType" class="foswikiSelect" size="1"><option class="foswikiOption" selected="selected">Defect</option><option class="foswikiOption">Enhancement</option><option class="foswikiOption">Other</option></select>',
        get_formfield( 3, $text )
    );
    $this->assert_html_matches(
        '<input type="hidden" name="History1" value="%SCRIPTURL%"  />',
        get_formfield( 4, $text ) );
    $this->assert_html_matches(
'<input type="text" name="History2" value="%SCRIPTURL%" size="20" class="foswikiInputField" />',
        get_formfield( 5, $text )
    );
    $this->assert_html_matches(
        '<input type="hidden" name="History3" value="%SCRIPTURL%"  />',
        get_formfield( 6, $text ) );
    $this->assert_html_matches(
'<input type="text" name="History4" value="%SCRIPTURL%" size="20" class="foswikiInputField" />',
        get_formfield( 7, $text )
    );

}

sub test_tmpl_form_existingform_params {

    # Pass query parameters, with field values present
    my $this = shift;

    my $text = setup_formtests( $this, $testweb, "$testtopic2",
"formtemplate=\"$testweb.$testform\" templatetopic=\"$testweb.$testtmpl\" IssueName=\"My first defect\" IssueDescription=\"Simple description of problem\" IssueType=\"Enhancement\" History1=\"%ATTACHURL%\" History2=\"%ATTACHURL%\" History3=\"\$percntATTACHURL%\" History4=\"\$percntATTACHURL%\" "
    );

    $this->assert_html_matches(
'<input type="text" name="IssueName" value="My first defect" size="73" class="foswikiInputField foswikiMandatory" />',
        get_formfield( 1, $text )
    );
    $this->assert_html_matches(
'<textarea name="IssueDescription"  rows="5" cols="55" class="foswikiTextarea">
Simple description of problem</textarea>', get_formfield( 2, $text )
    );
    $this->assert_html_matches(
'<select name="IssueType" class="foswikiSelect" size="1"><option class="foswikiOption">Defect</option><option class="foswikiOption" selected="selected">Enhancement</option><option class="foswikiOption">Other</option></select>',
        get_formfield( 3, $text )
    );
    $this->assert_html_matches(
        '<input type="hidden" name="History1" value="%ATTACHURL%"  />',
        get_formfield( 4, $text ) );
    $this->assert_html_matches(
'<input type="text" name="History2" value="%ATTACHURL%" size="20" class="foswikiInputField" />',
        get_formfield( 5, $text )
    );
    $this->assert_html_matches(
        '<input type="hidden" name="History3" value="%ATTACHURL%"  />',
        get_formfield( 6, $text ) );
    $this->assert_html_matches(
'<input type="text" name="History4" value="%ATTACHURL%" size="20" class="foswikiInputField" />',
        get_formfield( 7, $text )
    );

}

sub test_tmpl_form_new_params {

    # Pass query parameters, new topic
    my $this = shift;

    my $text = setup_formtests( $this, $testweb, "${testtopic1}XXXXXXXXXX",
"formtemplate=\"$testweb.$testform\" templatetopic=\"$testweb.$testtmpl\" IssueName=\"My first defect\" IssueDescription=\"Simple description of problem\" IssueType=\"Enhancement\" History1=\"%ATTACHURL%\" History2=\"%ATTACHURL%\" History3=\"\$percntATTACHURL%\" History4=\"\$percntATTACHURL%\" "
    );

    $this->assert_html_matches(
'<input type="text" name="IssueName" value="My first defect" size="73" class="foswikiInputField foswikiMandatory" />',
        get_formfield( 1, $text )
    );
    $this->assert_html_matches(
'<textarea name="IssueDescription"  rows="5" cols="55" class="foswikiTextarea">
Simple description of problem</textarea>', get_formfield( 2, $text )
    );
    $this->assert_html_matches(
'<select name="IssueType" class="foswikiSelect" size="1"><option class="foswikiOption">Defect</option><option class="foswikiOption" selected="selected">Enhancement</option><option class="foswikiOption">Other</option></select>',
        get_formfield( 3, $text )
    );
    $this->assert_html_matches(
        '<input type="hidden" name="History1" value="%ATTACHURL%"  />',
        get_formfield( 4, $text ) );
    $this->assert_html_matches(
'<input type="text" name="History2" value="%ATTACHURL%" size="20" class="foswikiInputField" />',
        get_formfield( 5, $text )
    );
    $this->assert_html_matches(
        '<input type="hidden" name="History3" value="%ATTACHURL%"  />',
        get_formfield( 6, $text ) );
    $this->assert_html_matches(
'<input type="text" name="History4" value="%ATTACHURL%" size="20" class="foswikiInputField" />',
        get_formfield( 7, $text )
    );

}

sub test_tmpl_form_notext_params {

    # Pass query parameters, no text
    my $this = shift;

    my $text = setup_formtests( $this, $testweb, $testtopic1,
"formtemplate=\"$testweb.$testform\" templatetopic=\"$testweb.$testtmpl\" IssueName=\"My first defect\" IssueDescription=\"Simple description of problem\" IssueType=\"Enhancement\" History1=\"%ATTACHURL%\" History2=\"%ATTACHURL%\" History3=\"\$percntATTACHURL%\" History4=\"\$percntATTACHURL%\" text=\"\""
    );

    $this->assert_html_matches(
'<input type="text" name="IssueName" value="My first defect" size="73" class="foswikiInputField foswikiMandatory" />',
        get_formfield( 1, $text )
    );
    $this->assert_html_matches(
'<textarea name="IssueDescription"  rows="5" cols="55" class="foswikiTextarea">
Simple description of problem</textarea>', get_formfield( 2, $text )
    );
    $this->assert_html_matches(
'<select name="IssueType" class="foswikiSelect" size="1"><option class="foswikiOption">Defect</option><option class="foswikiOption" selected="selected">Enhancement</option><option class="foswikiOption">Other</option></select>',
        get_formfield( 3, $text )
    );
    $this->assert_html_matches(
        '<input type="hidden" name="History1" value="%ATTACHURL%"  />',
        get_formfield( 4, $text ) );
    $this->assert_html_matches(
'<input type="text" name="History2" value="%ATTACHURL%" size="20" class="foswikiInputField" />',
        get_formfield( 5, $text )
    );
    $this->assert_html_matches(
        '<input type="hidden" name="History3" value="%ATTACHURL%"  />',
        get_formfield( 6, $text ) );
    $this->assert_html_matches(
'<input type="text" name="History4" value="%ATTACHURL%" size="20" class="foswikiInputField" />',
        get_formfield( 7, $text )
    );

}

# Purpose:  Just edit the form topic, do not provide any init values
# Verifies: All values are kept intact, in particular:
#              * No expansion of Foswiki variables (%SCRIPTURL%)
#              * No expansion if $percnt
sub test_dont_expand_on_edit {
    my $this = shift;

    my $text = setup_formtests( $this, $testweb, $testtopic3 );

    $this->assert_html_matches(
'<input type="text" name="IssueName" value="My first defect" size="73" class="foswikiInputField foswikiMandatory" />',
        get_formfield( 1, $text )
    );
    $this->assert_html_matches(
'<textarea name="IssueDescription"  rows="5" cols="55" class="foswikiTextarea">
Simple description of problem</textarea>', get_formfield( 2, $text )
    );

#  $this->assert_matches(qr/<select [^>]+><option ([^>]+| selected)>Defect<\/option>/, get_formfield(3, $text));
    $this->assert_html_matches(
'<select name="IssueType" class="foswikiSelect" size="1"><option class="foswikiOption" selected="selected">Defect</option><option class="foswikiOption">Enhancement</option><option class="foswikiOption">Other</option></select>',
        get_formfield( 3, $text )
    );
    $this->assert_html_matches(
        '<input type="hidden" name="History1" value="%SCRIPTURL%"  />',
        get_formfield( 4, $text ) );
    $this->assert_html_matches(
        '<input type="hidden" name="History3" value="$percntSCRIPTURL%"  />',
        get_formfield( 6, $text ) );
}

1;
