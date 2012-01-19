use strict;

# tests for basic formatting

package RenderListPluginTests;

use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use Foswiki();
use Foswiki::Func();
use Benchmark qw( :hireswallclock);
use Error qw( :try );

sub TRACE { 0 }

sub new {
    my $self = shift()->SUPER::new( 'RenderListPlugin', @_ );
    return $self;
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
}

sub tear_down {
    my $this = shift;

    $this->SUPER::tear_down();
}

sub loadExtraConfig {
    my $this = shift;
    $this->SUPER::loadExtraConfig();

}

# This formats the text up to immediately before <nop>s are removed, so we
# can see the nops.
sub do_test {
    my ( $this, $expected, $actual, $noHtml ) = @_;
    my $session = $this->{session};

    $this->{test_topicObject}->expandMacros($actual);
    $expected = Foswiki::Func::expandCommonVariables($expected);

    $actual = $this->{test_topicObject}->renderTML($actual);
    if ($noHtml) {
        $this->assert_equals( $expected, $actual );
    }
    else {
        $this->assert_html_equals( $expected, $actual );
    }
}

sub test_thread {
    my $this     = shift;
    my $expected = <<EXPECTED;
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_udr.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" > one </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ud.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_udr.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" > one.a </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ud.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ud.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ur.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" > one.a.x </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ud.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ur.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" > one.b </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ud.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_udr.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" > one.b.x </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ud.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ud.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" > continue </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ud.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ur.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" > one.b.y </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ud.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_udr.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/person.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; Tim </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ud.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ur.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/person.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; Mico </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_udr.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" > two </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ur.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" > three </td>
</tr></table>
<p></p>
EXPECTED
    my $actual = <<ACTUAL;
%RENDERLIST{"thread"}%
   * one
      * one.a
         * one.a.x
      * one.b
         * one.b.x
           continue
         * one.b.y
            * icon:person Tim
            * icon:person Mico
   * two
   * three
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_themes_0First {
    my $this = shift;

    foreach my $theme (qw( org group email trend file )) {
        my $iconname = ( $theme eq 'org' ) ? 'home.gif' : "$theme.gif";
        my $expected = <<EXPECTED;
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/$iconname" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; one </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_udr.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/$iconname" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; one.a </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ud.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ur.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/$iconname" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; one.a.x </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ur.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/$iconname" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; one.b </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_udr.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/$iconname" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; one.b.x </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ud.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; continue </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ur.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/$iconname" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; one.b.y </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_udr.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/person.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; Tim </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ur.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/person.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; Mico </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/$iconname" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; two </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/$iconname" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; three </td>
</tr></table>
<p></p>
EXPECTED
        my $actual = <<ACTUAL;
%RENDERLIST{"$theme"}%
   * one
      * one.a
         * one.a.x
      * one.b
         * one.b.x
           continue
         * one.b.y
            * icon:person Tim
            * icon:person Mico
   * two
   * three
ACTUAL
        $this->do_test( $expected, $actual );
    }
}

sub test_focus {
    my $this     = shift;
    my $iconname = 'home.gif';
    my $expected = <<EXPECTED;
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/$iconname" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; one </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ur.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/$iconname" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; <b> one.b </b> </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_udr.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/$iconname" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; one.b.x </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ud.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; continue </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ur.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/$iconname" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; one.b.y </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_udr.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/person.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; Tim </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ur.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/person.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; Mico </td>
</tr></table>
<p></p>
EXPECTED
    my $actual = <<ACTUAL;
%RENDERLIST{ "org" focus="one.b" }%
   * one
      * one.a
         * one.a.x
      * one.b
         * one.b.x
           continue
         * one.b.y
            * icon:person Tim
            * icon:person Mico
   * two
   * three
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_focus_depth {
    my $this     = shift;
    my $iconname = 'home.gif';
    my $expected = <<EXPECTED;
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/$iconname" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; one </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ur.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/$iconname" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; <b> one.b </b> </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_udr.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/$iconname" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; one.b.x </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ud.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; continue </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ur.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/$iconname" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; one.b.y </td>
</tr></table>
<p></p>
EXPECTED
    my $actual = <<ACTUAL;
%RENDERLIST{ "org" focus="one.b" depth="1" }%
   * one
      * one.a
         * one.a.x
      * one.b
         * one.b.x
           continue
         * one.b.y
            * icon:person Tim
            * icon:person Mico
   * two
      * two.a
         * two.a.x
   * three
ACTUAL
    $this->do_test( $expected, $actual );

    $expected = <<EXPECTED;
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/$iconname" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; two </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ur.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/$iconname" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; <b> two.a </b> </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ur.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/$iconname" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; two.a.x </td>
</tr></table>
<p></p>
EXPECTED

    $actual = <<ACTUAL;
%RENDERLIST{ "org" focus="two.a" depth="1" }%
   * one
      * one.a
         * one.a.x
      * one.b
         * one.b.x
           continue
         * one.b.y
            * icon:person Tim
            * icon:person Mico
   * two
      * two.a
         * two.a.x
   * three
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_group {
    my $this     = shift;
    my $expected = <<EXPECTED;
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/group.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; one </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_udr.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/group.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; one.a </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ud.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ur.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/group.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; one.a.x </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ur.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/group.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; one.b </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_udr.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/group.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; one.b.x </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ud.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; continue </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ur.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/group.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; one.b.y </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_udr.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/person.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; Tim </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ur.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/person.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; Mico </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/group.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; two </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/group.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; three </td>
</tr></table>
<p></p>
EXPECTED
    my $actual = <<ACTUAL;
%RENDERLIST{theme="group"}%
   * one
      * one.a
         * one.a.x
      * one.b
         * one.b.x
           continue
         * one.b.y
            * icon:person Tim
            * icon:person Mico
   * two
   * three
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_home {
    my $this     = shift;
    my $iconname = 'home.gif';
    my $expected = <<EXPECTED;
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_udr.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/$iconname" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; one </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ud.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_udr.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/$iconname" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; one.a </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ud.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ud.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ur.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/$iconname" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; one.a.x </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ud.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ur.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/$iconname" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; one.b </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ud.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_udr.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/$iconname" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; one.b.x </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ud.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ud.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; continue </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ud.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ur.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/$iconname" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; one.b.y </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ud.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_udr.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/person.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; Tim </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ud.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/empty.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ur.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/person.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; Mico </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_udr.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/$iconname" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; two </td>
</tr></table>
<table border="0" cellspacing="0" cellpadding="0"><tr>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/dot_ur.gif" width="16" height="16" alt="" border="0" /></td>
<td valign="top"><img src="%PUBURL%/System/RenderListPlugin/$iconname" width="16" height="16" alt="" border="0" /></td>
<td valign="top" class="foswikiNoBreak" >&nbsp; three </td>
</tr></table>
<p></p>
EXPECTED
    my $actual = <<ACTUAL;
%RENDERLIST{theme="home"}%
   * one
      * one.a
         * one.a.x
      * one.b
         * one.b.x
           continue
         * one.b.y
            * icon:person Tim
            * icon:person Mico
   * two
   * three
ACTUAL
    $this->do_test( $expected, $actual );
}

1;
