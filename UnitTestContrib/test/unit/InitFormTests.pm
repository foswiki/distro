package InitFormTests;
use strict;
use warnings;

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

use FoswikiTestCase();
our @ISA = qw( FoswikiTestCase );
use Error qw( :try );

use Foswiki::UI::Edit();
use Unit::Request();
use Error qw( :try );

my $testweb    = "TemporaryTestWeb";
my $testtopic1 = "InitTestTopic1";
my $testtopic2 = "InitTestTopic2";
my $testtopic3 = "InitTestTopic3";
my $testform   = "InitTestForm";
my $testtmpl   = "InitTestTemplate";

my $testuser1 = "TestUser1";
my $testuser2 = "TestUser2";

my $setup_failure = '';

my $aurl;    # Holds the %ATTACHURL%
my $surl;    # Holds the %SCRIPTURL%

my $testtmpl1 = <<'HERE';

-- Main.WikiGuest - 20 Aug 2005

HERE

my $testform1 = <<'HERE';
| *Name* | *Type* | *Size* | *Values* | *Tooltip messages* | *Mandatory* | *Default* |
| Issue Name | text | 73 | My first defect over-ridden | Illustrative name of issue | M | My first defect |
| Issue Description | textarea | 55x5 | Simple description of problem | Short description of issue |  |Simple description of problem |
| Issue Type | select | 1 | Defect, Enhancement, Other |  |  | |
| History1 | label | 1 | %ATTACHURL%	         	 |  | | %ATTACHURL%|
| History2 | text | 20 | %ATTACHURL%		         |  | | %ATTACHURL%|
| History3 | label | 1 | $percntATTACHURL%		 |  | |e |
| History4 | text | 2 | this will not be used as its over-ridden by the next line		 |  | | |
| History4 | text | 20 | $percntATTACHURL%		 |  | |$percntATTACHURL% |
| NewWithDefault | text | 20 | $percntATTACHURL%		 | the default col over-rides value | | is it a plane? |
| [[NewWithDefaultOnly][default only]] | text | 20 | 	 |  | | is it another plane? |
| Default To Hidden | select | 1 | Defect, Enhancement, Hidden, Other |  |  | Hidden |
| Default To Enhancement | radio | 1 | Defect, Enhancement, Hidden, Other |  |  | Enhancement |
| Enhancement Checkbox | checkbox | 4 | Defect, Enhancement, Hidden, Other |  |  | Enhancement |


HERE

my $testtext1 = <<'HERE';
Needs the following
   * TestFormInitFormA - Form to be attached
Then call <a href="%SCRIPTURL{"edit"}%/%WEB%/%TOPIC%?formtemplate=$testform">Edit</a>

HERE

my $testtext2 = <<'HERE';
Needs the following
   * TestFormInitFormA - Form to be attached
Then call <a href="%SCRIPTURL{"edit"}%/%WEB%/%TOPIC%?formtemplate=$testform">Edit</a>
HERE

my $testtext3 = <<'HERE';
...no text...
HERE

my $edittmpl1 = <<'HERE';
%FORMFIELDS%
HERE

# Set up the test fixture
sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    $this->createNewFoswikiSession( $Foswiki::cfg{AdminUserLogin},
        $this->{request} );
    Foswiki::Func::createWeb($testweb);
    $this->createNewFoswikiSession( undef, $this->{request} );
    $aurl = $this->{session}->getPubUrl( 1, $testweb, $testform );
    $surl = $this->{session}->getScriptUrl(1);

    my ($to) = Foswiki::Func::readTopic( $testweb, $testtopic1 );
    $to->put(
        'TOPICINFO',
        {
            author  => "WikiGuest",
            date    => "1159721050",
            format  => "1.1",
            reprev  => "1.3",
            version => "1.3"
        }
    );
    Foswiki::Func::saveTopic( $testweb, $testtopic1, $to, $testtext1 );

    ($to) = Foswiki::Func::readTopic( $testweb, $testtopic2 );
    $to->put(
        'TOPICINFO',
        {
            author  => "WikiGuest",
            date    => "1159721050",
            format  => "1.1",
            reprev  => "1.3",
            version => "1.3"
        }
    );
    $to->put( 'FORM', { name => "$testform" } );
    $to->putKeyed(
        'FIELD',
        {
            name       => "IssueName",
            attributes => "M",
            title      => "Issue Name",
            value      => "_An issue_"
        }
    );
    $to->putKeyed(
        'FIELD',
        {
            name       => "IssueDescription",
            attributes => "",
            title      => "Issue Description",
            value      => "---+ Example problem"
        }
    );
    $to->putKeyed(
        'FIELD',
        {
            name       => "IssueType",
            attributes => "",
            title      => "Issue Type",
            value      => "Defect"
        }
    );
    $to->putKeyed(
        'FIELD',
        {
            name       => "History1",
            attributes => "",
            title      => "History1",
            value      => "%SCRIPTURL%"
        }
    );
    $to->putKeyed(
        'FIELD',
        {
            name       => "History2",
            attributes => "",
            title      => "History2",
            value      => "%SCRIPTURL%"
        }
    );
    $to->putKeyed(
        'FIELD',
        {
            name       => "History3",
            attributes => "",
            title      => "History3",
            value      => '$percntSCRIPTURL%'
        }
    );
    $to->putKeyed(
        'FIELD',
        {
            name       => "History4",
            attributes => "",
            title      => "History4",
            value      => '$percntSCRIPTURL%'
        }
    );
    Foswiki::Func::saveTopic( $testweb, $testtopic2, $to, $testtext2 );

    ($to) = Foswiki::Func::readTopic( $testweb, $testtopic3 );
    $to->put(
        'TOPICINFO',
        {
            author  => "WikiGuest",
            date    => "1159721050",
            format  => "1.1",
            reprev  => "1.3",
            version => "1.3"
        }
    );
    $to->put( 'FORM', { name => "InitTestForm" } );
    $to->putKeyed(
        'FIELD',
        {
            name       => "IssueName",
            attributes => "M",
            title      => "Issue Name",
            value      => "My first defect"
        }
    );
    $to->putKeyed(
        'FIELD',
        {
            name       => "IssueDescription",
            attributes => "",
            title      => "Issue Description",
            value      => "Simple description of problem"
        }
    );
    $to->putKeyed(
        'FIELD',
        {
            name       => "IssueType",
            attributes => "",
            title      => "Issue Type",
            value      => "Defect"
        }
    );
    $to->putKeyed(
        'FIELD',
        {
            name       => "History1",
            attributes => "",
            title      => "History1",
            value      => "%SCRIPTURL%"
        }
    );
    $to->putKeyed(
        'FIELD',
        {
            name       => "History3",
            attributes => "",
            title      => "History3",
            value      => '$percntSCRIPTURL%'
        }
    );
    Foswiki::Func::saveTopic( $testweb, $testtopic3, $to, $testtext3 );

    ($to) = Foswiki::Func::readTopic( $testweb, $testform );
    $to->put(
        'TOPICINFO',
        {
            author  => "guest",
            date    => "1025373031",
            format  => "1.0",
            version => "1.3"
        }
    );
    $to->put( 'TOPICPARENT', { name => "WebHome" } );
    Foswiki::Func::saveTopic( $testweb, $testform, $to, $testform1 );

    ($to) = Foswiki::Func::readTopic( $testweb, $testtmpl );
    $to->put(
        'TOPICINFO',
        {
            author  => "WikiGuest",
            date    => "1124568292",
            format  => "1.1",
            version => "1.2"
        }
    );
    $to->put( 'FORM', { name => "$testform" } );
    $to->putKeyed(
        'FIELD',
        {
            name       => "IssueName",
            attributes => "M",
            title      => "Issue Name",
            value      => "_An issue_"
        }
    );
    $to->putKeyed(
        'FIELD',
        {
            name       => "IssueDescription",
            attributes => "",
            title      => "Issue Description",
            value      => "---+ Example problem"
        }
    );
    $to->putKeyed(
        'FIELD',
        {
            name       => "IssueType",
            attributes => "",
            title      => "Issue Type",
            value      => "Defect"
        }
    );
    $to->putKeyed(
        'FIELD',
        {
            name       => "History1",
            attributes => "",
            title      => "History1",
            value      => "%SCRIPTURL%"
        }
    );
    $to->putKeyed(
        'FIELD',
        {
            name       => "History2",
            attributes => "",
            title      => "History2",
            value      => "%SCRIPTURL%"
        }
    );
    $to->putKeyed(
        'FIELD',
        {
            name       => "History3",
            attributes => "",
            title      => "History3",
            value      => '$percntSCRIPTURL%'
        }
    );
    $to->putKeyed(
        'FIELD',
        {
            name       => "History4",
            attributes => "",
            title      => "History4",
            value      => '$percntSCRIPTURL%'
        }
    );
    Foswiki::Func::saveTopic( $testweb, $testtmpl, $to, $testtmpl1 );

    Foswiki::Func::saveTopic( $testweb, "MyeditTemplate", undef, $edittmpl1 );

    $this->{session}->enterContext('edit');

    return;
}

sub tear_down {
    my $this = shift;

    $this->removeWebFixture( $this->{session}, $testweb );
    $this->SUPER::tear_down();

    return;
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
    my $q = Unit::Request->new();

    $q->path_info("/$web/$topic");

    #$this->{session}->{webName}   = $web;
    #$this->{session}->{topicName} = $topic;

    require Foswiki::Attrs;
    my $attr = Foswiki::Attrs->new($params);
    foreach my $k ( keys %{$attr} ) {
        next if $k eq '_RAW';
        $q->param( -name => $k, -value => $attr->{$k} );
    }
    $this->createNewFoswikiSession( undef, $q );
    $this->{session}->enterContext('edit');

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

    my $value = 'My first defect';
    $value = 'My first defect over-ridden'
      if ( $this->check_dependency('Foswiki,<,1.2') );
    $this->assert_html_matches(
        '<input type="text" name="IssueName" value="'
          . $value
          . '" size="73" class="foswikiInputField foswikiMandatory" />',
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

    $value = 'e';
    $value = '%ATTACHURL%' if ( $this->check_dependency('Foswiki,<,1.2') );
    $this->assert_html_matches(
        '<input type="hidden" name="History3" value="' . $value . '" />',

#.'<div class="foswikiFormLabel">http://quiet/~sven/core/pub/TemporaryTestWeb/InitTestTopic1</div>',
        get_formfield( 6, $text )
    );

    if ( $this->check_dependency('Foswiki,<,1.2') ) {

#TODO: SMELL: in 1.1 (need to test 1.0), duplicate fields in the form will result in duplicate html,
        $this->assert_html_matches(
'<input type="text" name="History4" value="this will not be used as its over-ridden by the next line" size="2" class="foswikiInputField" />',
            get_formfield( 8, $text )
        );
    }
    else {
#    $this->assert_html_not_matches(
#'<input type="text" name="History4" value="this will not be used as its over-ridden by the next line" size="2" class="foswikiInputField" />',
#        get_formfield( 8, $text )
#    );
    }
    $this->assert_html_matches(
'<input type="text" name="History4" value="%ATTACHURL%" size="20" class="foswikiInputField" />',
        get_formfield( 9, $text )
    );

#| NewWithDefault | text | 20 | $percntATTACHURL%		 | the default col over-rides value | | is it a plane? |
    $value = 'is it a plane?';
    $value = '%ATTACHURL%' if ( $this->check_dependency('Foswiki,<,1.2') );

    $this->assert_html_matches(
        '<input type="text" name="NewWithDefault" value="'
          . $value
          . '" size="20" class="foswikiInputField" />',
        get_formfield( 10, $text )
    );

#| [[NewWithDefaultOnly][default only]] | text | 20 | 	 |  | | is it another plane? |
    $value = ' value="is it another plane?"';
    $value = '' if ( $this->check_dependency('Foswiki,<,1.2') );
    $this->assert_html_matches(
        '<input type="text" name="defaultonly"'
          . $value
          . ' size="20" class="foswikiInputField" />',
        get_formfield( 11, $text )
    );

#| Default To Hidden | select | 1 | Defect, Enhancement, Hidden, Other |  |  | Hidden |
    $value = ' selected="selected"';
    $value = '' if ( $this->check_dependency('Foswiki,<,1.2') );
    $this->assert_html_matches(
'<select name="DefaultToHidden" class="foswikiSelect" size="1"><option class="foswikiOption">Defect</option><option class="foswikiOption">Enhancement</option><option class="foswikiOption"'
          . $value
          . '>Hidden</option><option class="foswikiOption">Other</option></select>',
        get_formfield( 12, $text )
    );

#| Default To Enhancement | radio | 1 | Defect, Enhancement, Hidden, Other |  |  | Enhancement |
    $value = 'checked="checked" ';
    $value = '' if ( $this->check_dependency('Foswiki,<,1.2') );
    $this->assert_html_matches(
'<input type="radio" name="DefaultToEnhancement" value="Defect"  title="Defect" class="foswikiRadioButton"/>Defect</label></td></tr><tr><td><label><input type="radio" name="DefaultToEnhancement" value="Enhancement" '
          . $value
          . ' title="Enhancement" class="foswikiRadioButton"/>Enhancement</label></td></tr><tr><td><label><input type="radio" name="DefaultToEnhancement" value="Hidden"  title="Hidden" class="foswikiRadioButton"/>Hidden</label></td></tr><tr><td><label><input type="radio" name="DefaultToEnhancement" value="Other"  title="Other" class="foswikiRadioButton"/>Other</label>',
        get_formfield( 13, $text )
    );

#| Enhancement Checkbox | checkbox | 4 | Defect, Enhancement, Hidden, Other |  |  | Enhancement |
    $value = 'checked="checked" ';
    $value = '' if ( $this->check_dependency('Foswiki,<,1.2') );
    $this->assert_html_matches(
'<input type="checkbox" name="EnhancementCheckbox" value="Defect"  title="Defect" class="foswikiCheckbox"/>Defect</label></td><td><label><input type="checkbox" name="EnhancementCheckbox" value="Enhancement" '
          . $value
          . ' title="Enhancement" class="foswikiCheckbox"/>Enhancement</label></td><td><label><input type="checkbox" name="EnhancementCheckbox" value="Hidden"  title="Hidden" class="foswikiCheckbox"/>Hidden</label></td><td><label><input type="checkbox" name="EnhancementCheckbox" value="Other"  title="Other" class="foswikiCheckbox"/>Other</label>',
        get_formfield( 14, $text )
    );

    return;
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
    my $value = 'e';
    $value = '%ATTACHURL%' if ( $this->check_dependency('Foswiki,<,1.2') );
    $this->assert_html_matches(
        '<input type="hidden" name="History3" value="' . $value . '" />',

#.'<div class="foswikiFormLabel">http://quiet/~sven/core/pub/TemporaryTestWeb/InitTestTopic1</div>',
        get_formfield( 6, $text )
    );

    $this->assert_html_matches(
'<input type="text" name="History4" value="%ATTACHURL%" size="20" class="foswikiInputField" />',
        get_formfield( 7, $text )
    );

    return;
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

    return;
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

    return;
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

    return;
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

    return;
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

    return;
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

    return;
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

    return;
}

# Item10874, originally Item10446
# Test that ?formtemplate=MyForm works without web prefix on an unsaved topic
sub test_unsavedtopic_rendersform {
    my $this  = shift;
    my $query = Unit::Request->new(
        {
            webName      => [$testweb],
            topicName    => ['MissingTopic'],
            formtemplate => ["$testform"]
        }
    );
    $query->path_info("/$testweb/MissingTopic");
    $query->method('POST');
    my $fatwilly =
      $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    my ($text) = $this->capture(
        sub {
            no strict 'refs';
            &{ $this->getUIFn('edit') }($fatwilly);
            use strict 'refs';
            $Foswiki::engine->finalize( $fatwilly->{response},
                $fatwilly->{request} );
        }
    );
    $this->assert_html_matches(
'<input type="text" name="IssueName" value="My first defect" size="73" class="foswikiInputField foswikiMandatory" />',
        get_formfield( 6, $text )
    );

    return;
}

1;
