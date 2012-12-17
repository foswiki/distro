# tests for the correct expansion of MAKETEXT

package Fn_MAKETEXT;
use strict;
use warnings;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Error qw( :try );

my $topicObject;

# Force reload of I18N in case it wasn't enabled
if ( delete $INC{'Foswiki/I18N.pm'} ) {

    # Clean the symbol table to remove loaded subs
    no strict 'refs';
    @Foswiki::I18N::ISA = ();
    my $symtab = "Foswiki::I18N::";
    foreach my $symbol ( keys %{$symtab} ) {
        next if $symbol =~ /\A[^:]+::\z/;
        delete $symtab->{$symbol};
    }
}

sub new {
    my $self = shift()->SUPER::new( 'MAKETEXT', @_ );
    return $self;
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, 'WebHome' );
}

sub loadExtraConfig {
    my $this = shift;
    $this->SUPER::loadExtraConfig();
    setLocalSite();
}

sub setLocalSite {
    $Foswiki::cfg{WebMasterEmail}                    = 'a.b@c.org';
    $Foswiki::cfg{UserInterfaceInternationalisation} = 1;
    $Foswiki::cfg{Languages}{de}{Enabled}            = 1;
}

sub test_simple {
    my $this = shift;

    my $result = $topicObject->expandMacros('%MAKETEXT{"edit"}%');
    $this->assert_str_equals( 'edit', $result );
}

sub test_doc_example_1 {
    my $this = shift;

    my $result = $topicObject->expandMacros('%MAKETEXT{string="Notes:"}%');
    $this->assert_str_equals( 'Notes:', $result );
}

sub test_doc_example_2 {
    my $this = shift;

    my $result = $topicObject->expandMacros(
        '%MAKETEXT{ 
"If you have any questions, please contact [_1]." 
args="%WIKIWEBMASTER%" 
}%'
    );
    $this->assert_str_equals(
        'If you have any questions, please contact a.b@c.org.', $result );
}

sub test_doc_example_3 {
    my $this = shift;

    my $result = $topicObject->expandMacros(
'%MAKETEXT{"Did you want to [[[_1]][reset [_2]\'s password]]?" args="%SYSTEMWEB%.ResetPassword,%WIKIUSERNAME%"}%'
    );

    $this->assert_str_equals(
'Did you want to [[System.ResetPassword][reset TemporaryMAKETEXTUsersWeb.WikiGuest\'s password]]?',
        $result
    );
}

sub test_single_arg {
    my $this = shift;

    my $result =
      $topicObject->expandMacros('%MAKETEXT{"edit [_1]" args="WebHome"}%');
    $this->assert_str_equals( 'edit WebHome', $result );
}

sub test_expand_variables_in_args {
    my $this = shift;

    my $result =
      $topicObject->expandMacros('%MAKETEXT{"edit [_1]" args="%HOMETOPIC%"}%');
    $this->assert_str_equals( 'edit WebHome', $result );
}

sub test_multiple_args {
    my $this = shift;

    my $result = $topicObject->expandMacros(
        '%MAKETEXT{"edit [_1] [_2]" args="WebHome, now"}%');
    $this->assert_str_equals( 'edit WebHome now', $result );
}

sub test_quant_plurals {
    my $this = shift;

    my $result = $topicObject->expandMacros(
        '%MAKETEXT{"edit [*,_1,file] in [_2]" args="1,here"}%');
    $this->assert_str_equals( 'edit 1 file in here', $result );

    $result = $topicObject->expandMacros(
        '%MAKETEXT{"edit [*,_1,file] in [_2]" args="2,WebHome"}%');
    $this->assert_str_equals( 'edit 2 files in WebHome', $result );
}

sub test_escaping {
    my $this = shift;

    # Make sure the real Locale::Maketext gets called
    $Foswiki::cfg{UserInterfaceInternationalisation} = 1;

    my $str =
' %MAKETEXT{"This \\\\\'.`echo A`.\\\\\'  [*,_1,\\\\\'.`echo A`.\\\\\' ]" args="1"}% ';

    my $result = $topicObject->expandMacros($str);
    $this->assert_str_equals(
        ' This \\\'.`echo A`.\\\'  1 \\\'.`echo A`.\\\'  ', $result );
}

sub test_invalid_args {
    my $this = shift;

    my $result = $topicObject->expandMacros(
        '%MAKETEXT{"edit [_0] [_222]" args="WebHome, now"}%');
    $this->assert_str_equals(
'edit <span class="foswikiAlert">Invalid parameter <code>"_0"</code>, MAKETEXT rejected.</span> <span class="foswikiAlert">Excessive parameter number 222, MAKETEXT rejected.</span>',
        $result
    );

    $result = $topicObject->expandMacros(
        '%MAKETEXT{"edit [_222] [_0]" args="WebHome, now"}%');
    $this->assert_str_equals(
'edit <span class="foswikiAlert">Excessive parameter number 222, MAKETEXT rejected.</span> <span class="foswikiAlert">Invalid parameter <code>"_0"</code>, MAKETEXT rejected.</span>',
        $result
    );
    $result =
      $topicObject->expandMacros('%MAKETEXT{"edit [*,_222,file]" args="2"}%');
    $this->assert_str_equals(
'edit <span class="foswikiAlert">Excessive parameter number 222, MAKETEXT rejected.</span>',
        $result
    );
}

sub test_multiple_args_one_empty {
    my $this = shift;

    my $result =
      $topicObject->expandMacros('%MAKETEXT{"edit [_1][_2]" args="WebHome"}%');
    $this->assert_str_equals( 'edit WebHome', $result );
}

sub test_multiple_args_forgot_to_reference_one {
    my $this = shift;

    my $result =
      $topicObject->expandMacros('%MAKETEXT{"edit [_1]" args="WebHome, now"}%');
    $this->assert_str_equals( 'edit WebHome', $result );
}

sub test_underscore {
    my $this = shift;

    # name starts with underscore: error
    my $result = $topicObject->expandMacros('%MAKETEXT{"_edit"}%');
    $this->assert_str_equals(
'<span class="foswikiAlert">Error: MAKETEXT argument\'s can\'t start with an underscore ("_").</span>',
        $result
    );
}

sub test_access_key {
    my $this = shift;

    my $result = $topicObject->expandMacros('%MAKETEXT{"ed&it"}%');
    $this->assert_str_equals( 'ed<span class=\'foswikiAccessKey\'>i</span>t',
        $result );
}

1;
