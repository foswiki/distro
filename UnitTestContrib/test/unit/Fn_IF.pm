use strict;

# tests for the correct expansion of IF

package Fn_IF;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Error qw( :try );
use Assert;

sub new {
    my $self = shift()->SUPER::new( 'IF', @_ );
    return $self;
}

sub test_1 {
    my $this = shift;
    $this->simpleTest( test => "'A'='B'", then => 0, else => 1 );
}

sub test_2 {
    my $this = shift;
    $this->simpleTest( test => "'A'!='B'", then => 1, else => 0 );
}

sub test_3 {
    my $this = shift;
    $this->simpleTest( test => "'A'='A'", then => 1, else => 0 );
}

sub test_4 {
    my $this = shift;
    $this->simpleTest( test => "'A'='B'", then => 0, else => 1 );
}

sub test_5 {
    my $this = shift;
    $this->simpleTest( test => 'context test', then => 1, else => 0 );
}

sub test_5a {
    my $this = shift;
    $this->simpleTest( test => 'context \'test\'', then => 1, else => 0 );
}

sub test_6 {
    my $this = shift;
    $this->simpleTest( test => "{Fnargle}='Fleeble'", then => 1, else => 0 );
}

sub test_7 {
    my $this = shift;
    $this->simpleTest( test => "{A}{B}='C'", then => 1, else => 0 );
}

sub test_8 {
    my $this = shift;
    $this->simpleTest(
        test => '$ WIKINAME = \''
          . Foswiki::Func::getWikiName( $this->{session}->{user} ) . "'",
        then => 1,
        else => 0
    );
}

sub test_8a {
    my $this = shift;
    $this->simpleTest(
        test => '$ \'WIKINAME\' = \''
          . Foswiki::Func::getWikiName( $this->{session}->{user} ) . "'",
        then => 1,
        else => 0
    );
}

sub test_9 {
    my $this = shift;
    $this->simpleTest( test => 'defined EDITBOXHEIGHT', then => 1, else => 0 );
}

sub test_9a {
    my $this = shift;
    $this->simpleTest(
        test => 'defined \'EDITBOXHEIGHT\'',
        then => 1,
        else => 0
    );
}

sub test_10 {
    my $this = shift;
    $this->simpleTest( test => '0>1', then => 0, else => 1 );
}

sub test_11 {
    my $this = shift;
    $this->simpleTest( test => '1>0', then => 1, else => 0 );
}

sub test_12 {
    my $this = shift;
    $this->simpleTest( test => '1<0', then => 0, else => 1 );
}

sub test_13 {
    my $this = shift;
    $this->simpleTest( test => '0<1', then => 1, else => 0 );
}

sub test_14 {
    my $this = shift;
    $this->simpleTest( test => "0>=\t1", then => 0, else => 1 );
}

sub test_15 {
    my $this = shift;
    $this->simpleTest( test => '1>=0', then => 1, else => 0 );
}

sub test_16 {
    my $this = shift;
    $this->simpleTest( test => '1>=1', then => 1, else => 0 );
}

sub test_17 {
    my $this = shift;
    $this->simpleTest( test => '1<=0', then => 0, else => 1 );
}

sub test_18 {
    my $this = shift;
    $this->simpleTest( test => '0<=1', then => 1, else => 0 );
}

sub test_19 {
    my $this = shift;
    $this->simpleTest( test => '1<=1', then => 1, else => 0 );
}

sub test_20 {
    my $this = shift;
    $this->simpleTest( test => "not 'A'='B'", then => 1, else => 0 );
}

sub test_21 {
    my $this = shift;
    $this->simpleTest( test => "not NOT 'A'='B'", then => 0, else => 1 );
}

sub test_22 {
    my $this = shift;
    $this->simpleTest( test => "'A'='A' AND 'B'='B'", then => 1, else => 0 );
}

sub test_23 {
    my $this = shift;
    $this->simpleTest( test => "'A'='A' and 'B'='B'", then => 1, else => 0 );
}

sub test_24 {
    my $this = shift;
    $this->simpleTest( test => "'A'='A' and 'B'='B'", then => 1, else => 0 );
}

sub test_25 {
    my $this = shift;
    $this->simpleTest(
        test => "('A'='B' or 'A'='A') and ('B'='B')",
        then => 1,
        else => 0
    );
}

sub test_26 {
    my $this = shift;
    $this->simpleTest( test => "'A'='B' or 'B'='B'", then => 1, else => 0 );
}

sub test_27 {
    my $this = shift;
    $this->simpleTest( test => "'A'='A' or 'B'='A'", then => 1, else => 0 );
}

sub test_28 {
    my $this = shift;
    $this->simpleTest( test => "'A'='B' or 'B'='A'", then => 0, else => 1 );
}

sub test_29 {
    my $this = shift;
    $this->simpleTest(
        test => "\$PUBURLPATH='" . $Foswiki::cfg{PubUrlPath} . "'",
        then => 1,
        else => 0
    );
}

sub test_29a {
    my $this = shift;
    $this->simpleTest(
        test => "\$'PUBURLPATH'='" . $Foswiki::cfg{PubUrlPath} . "'",
        then => 1,
        else => 0
    );
}

sub test_30 {
    my $this = shift;
    $this->simpleTest( test => "'A'~'B'", then => 0, else => 1 );
}

sub test_31 {
    my $this = shift;
    $this->simpleTest( test => "'ABLABA'~'*B?AB*'", then => 1, else => 0 );
}

sub test_32 {
    my $this = shift;
    $this->simpleTest( test => '\"BABBA\"~\"*BB?\"', then => 1, else => 0 );
}

sub test_33 {
    my $this = shift;
    $this->simpleTest( test => "lc('FRED')='fred'", then => 1, else => 0 );
}

sub test_34 {
    my $this = shift;
    $this->simpleTest( test => "('FRED')=uc 'fred'", then => 1, else => 0 );
}

sub test_35 {
    my $this = shift;
    $this->simpleTest(
        test => "d2n('2007-03-26')="
          . Foswiki::Time::parseTime( '2007-03-26', 1 ),
        then => 1,
        else => 0
    );
}

sub test_36 {
    my $this = shift;
    $this->simpleTest(
        test => "d2n('wibble')=1174863600",
        then => 0,
        else => 1
    );
}

sub test_37 {
    my $this = shift;
    $this->simpleTest( test => "1 = 1 > 0", then => 1, else => 0 );
}

sub test_38 {
    my $this = shift;
    $this->simpleTest( test => "1 > 1 = 0", then => 1, else => 0 );
}

sub test_39 {
    my $this = shift;
    $this->simpleTest( test => "not 1 = 2", then => 1, else => 0 );
}

sub test_40 {
    my $this = shift;
    $this->simpleTest( test => "not not 1 and 1", then => 1, else => 0 );
}

sub test_41 {
    my $this = shift;
    $this->simpleTest( test => "0 or not not 1 and 1", then => 1, else => 0 );
}

# ingroup test against a non-group that is a valid user wikiname
sub test_42 {
    my $this = shift;
    $this->simpleTest(
        test => "'"
          . Foswiki::Func::getWikiName( $this->{session}->{user} )
          . "' ingroup 'WikiGuest'",
        then => 0,
        else => 1
    );
}

sub test_42a {
    my $this = shift;
    $this->simpleTest(
        test => "'"
          . Foswiki::Func::wikiToUserName(
            Foswiki::Func::getWikiName( $this->{session}->{user} )
          )
          . "' ingroup 'WikiGuest'",
        then => 0,
        else => 1
    );
}

sub test_42b {
    my $this = shift;
    $this->simpleTest(
        test => "'" . $this->{session}->{user} . "' ingroup 'WikiGuest'",
        then => 0,
        else => 1
    );
}

# ingroup test against a non-group that is a non-existant group
sub test_43 {
    my $this = shift;
    $this->simpleTest(
        test => "'"
          . Foswiki::Func::getWikiName( $this->{session}->{user} )
          . "' ingroup 'ThereHadBetterBeNoSuchGroup'",
        then => 0,
        else => 1
    );
}

sub test_43a {
    my $this = shift;
    $this->simpleTest(
        test => "'"
          . Foswiki::Func::wikiToUserName(
            Foswiki::Func::getWikiName( $this->{session}->{user} )
          )
          . "' ingroup 'ThereHadBetterBeNoSuchGroup'",
        then => 0,
        else => 1
    );
}

sub test_43b {
    my $this = shift;
    $this->simpleTest(
        test => "'"
          . $this->{session}->{user}
          . "' ingroup 'ThereHadBetterBeNoSuchGroup'",
        then => 0,
        else => 1
    );
}

# ingroup test against a valid group the user is not a member of
sub test_44 {
    my $this = shift;
    $this->simpleTest(
        test => "'"
          . Foswiki::Func::wikiToUserName(
            Foswiki::Func::getWikiName( $this->{session}->{user} )
          )
          . "' ingroup '$Foswiki::cfg{SuperAdminGroup}'",
        then => 0,
        else => 1
    );
}

sub test_44a {
    my $this = shift;
    $this->simpleTest(
        test => "'"
          . Foswiki::Func::getWikiName( $this->{session}->{user} )
          . "' ingroup '$Foswiki::cfg{SuperAdminGroup}'",
        then => 0,
        else => 1
    );
}

sub test_44b {
    my $this = shift;
    $this->simpleTest(
        test => "'"
          . $this->{session}->{user}
          . "' ingroup '$Foswiki::cfg{SuperAdminGroup}'",
        then => 0,
        else => 1
    );
}

# ingroup test against a group the user is a member of
sub test_45 {
    my $this = shift;
    $this->simpleTest(
        test => "'"
          . Foswiki::Func::wikiToUserName(
            Foswiki::Func::getWikiName( $this->{session}->{user} )
          )
          . "' ingroup 'GropeGroup'",
        then => 1,
        else => 0
    );
}

sub test_45a {
    my $this = shift;
    $this->simpleTest(
        test => "'"
          . Foswiki::Func::getWikiName( $this->{session}->{user} )
          . "' ingroup 'GropeGroup'",
        then => 1,
        else => 0
    );
}

sub test_45b {
    my $this = shift;

    # Test using cUID should FAIL. Users of %IF should only use login and
    # display names, the cUID is internal use only.
    $this->simpleTest(
        test => "'" . $this->{session}->{user} . "' ingroup 'GropeGroup'",
        then => 0,
        else => 1
    );
}

sub test_46 {
    my $this = shift;
    $this->simpleTest(
        test => "'%USERNAME%' ingroup 'WikiGuest'",
        then => 0,
        else => 1
    );
}

sub test_47 {
    my $this = shift;
    $this->simpleTest(
        test => "'%USERNAME%' ingroup 'ThereHadBetterBeNoSuchGroup'",
        then => 0,
        else => 1
    );
}

sub test_48 {
    my $this = shift;
    $this->simpleTest(
        test => "'%USERNAME%' ingroup '$Foswiki::cfg{SuperAdminGroup}'",
        then => 0,
        else => 1
    );
}

sub test_49 {
    my $this = shift;
    $this->simpleTest(
        test => "'%USERNAME%' ingroup 'GropeGroup'",
        then => 1,
        else => 0
    );
}

sub test_50 {
    my $this = shift;
    $this->simpleTest(
        test => "'%USERINFO{format=\"\$username\"}%' ingroup 'WikiGuest'",
        then => 0,
        else => 1
    );
}

sub test_51 {
    my $this = shift;
    $this->simpleTest(
        test =>
"'%USERINFO{format=\"\$username\"}%' ingroup 'ThereHadBetterBeNoSuchGroup'",
        then => 0,
        else => 1
    );
}

sub test52_ {
    my $this = shift;
    $this->simpleTest(
        test => "'%USERINFO{format=\"\$username\"}%' ingroup '"
          . $Foswiki::cfg{SuperAdminGroup} . "'",
        then => 0,
        else => 1
    );
}

sub test_53 {
    my $this = shift;
    $this->simpleTest(
        test => "'%USERINFO{format=\"\$username\"}%' ingroup 'GropeGroup'",
        then => 1,
        else => 0
    );
}

sub test_54 {
    my $this = shift;
    $this->simpleTest(
        test => "'%USERINFO{format=\"\$wikiname\"}%' ingroup 'WikiGuest'",
        then => 0,
        else => 1
    );
}

sub test_55 {
    my $this = shift;
    $this->simpleTest(
        test =>
"'%USERINFO{format=\"\$wikiname\"}%' ingroup 'ThereHadBetterBeNoSuchGroup'",
        then => 0,
        else => 1
    );
}

sub test_56 {
    my $this = shift;
    $this->simpleTest(
        test => "'%USERINFO{format=\"\$wikiname\"}%' ingroup '"
          . $Foswiki::cfg{SuperAdminGroup} . "'",
        then => 0,
        else => 1
    );
}

sub test_57 {
    my $this = shift;
    $this->simpleTest(
        test => "'%USERINFO{format=\"\$wikiname\"}%' ingroup 'GropeGroup'",
        then => 1,
        else => 0
    );
}

sub test_58 {
    my $this = shift;
    $this->simpleTest(
        test => "'%USERINFO{format=\"\$wikiusername\"}%' ingroup 'WikiGuest'",
        then => 0,
        else => 1
    );
}

sub test_59 {
    my $this = shift;
    $this->simpleTest(
        test =>
"'%USERINFO{format=\"\$wikiusername\"}%' ingroup 'ThereHadBetterBeNoSuchGroup'",
        then => 0,
        else => 1
    );
}

sub test_60 {
    my $this = shift;
    $this->simpleTest(
        test => "'%USERINFO{format=\"\$wikiusername\"}%' ingroup '"
          . $Foswiki::cfg{SuperAdminGroup} . "'",
        then => 0,
        else => 1
    );
}

sub test_61 {
    my $this = shift;
    $this->simpleTest(
        test => "'%USERINFO{format=\"\$wikiusername\"}%' ingroup 'GropeGroup'",
        then => 1,
        else => 0
    );
}

sub test_62 {
    my $this = shift;
    $this->simpleTest(
        test => "'"
          . Foswiki::Func::getWikiName( $this->{session}->{user} )
          . "' ingroup 'WikiGuest'",
        then => 0,
        else => 1
    );
}

sub test_63 {
    my $this = shift;
    $this->simpleTest(
        test => "'"
          . Foswiki::Func::getWikiName( $this->{session}->{user} )
          . "' ingroup 'ThereHadBetterBeNoSuchGroup'",
        then => 0,
        else => 1
    );
}

sub test_64 {
    my $this = shift;
    $this->simpleTest(
        test => "'"
          . Foswiki::Func::getWikiName( $this->{session}->{user} )
          . "' ingroup '"
          . $Foswiki::cfg{SuperAdminGroup} . "'",
        then => 0,
        else => 1
    );
}

sub test_65 {
    my $this = shift;
    $this->simpleTest(
        test => "'"
          . Foswiki::Func::getWikiName( $this->{session}->{user} )
          . "' ingroup 'GropeGroup'",
        then => 1,
        else => 0
    );
}

sub test_66 {
    my $this = shift;
    $this->simpleTest(
        test => "'"
          . $Foswiki::cfg{AdminUserWikiName}
          . "' ingroup 'WikiGuest'",
        then => 0,
        else => 1
    );
}

sub test_67 {
    my $this = shift;
    $this->simpleTest(
        test => "'"
          . $Foswiki::cfg{AdminUserWikiName}
          . "' ingroup 'ThereHadBetterBeNoSuchGroup'",
        then => 0,
        else => 1
    );
}

sub test_68 {
    my $this = shift;
    $this->simpleTest(
        test => "'"
          . $Foswiki::cfg{AdminUserWikiName}
          . "' ingroup '"
          . $Foswiki::cfg{SuperAdminGroup} . "'",
        then => 1,
        else => 0
    );
}

sub test_69 {
    my $this = shift;
    $this->simpleTest(
        test => "'"
          . $Foswiki::cfg{AdminUserWikiName}
          . "' ingroup 'GropeGroup'",
        then => 0,
        else => 1
    );
}

sub test_70 {
    my $this = shift;
    $this->simpleTest(
        test => "'"
          . $Foswiki::cfg{DefaultUserWikiName}
          . "' ingroup 'WikiGuest'",
        then => 0,
        else => 1
    );
}

sub test_71 {
    my $this = shift;
    $this->simpleTest(
        test => "'"
          . $Foswiki::cfg{DefaultUserWikiName}
          . "' ingroup 'ThereHadBetterBeNoSuchGroup'",
        then => 0,
        else => 1
    );
}

sub test_72 {
    my $this = shift;
    $this->simpleTest(
        test => "'"
          . $Foswiki::cfg{DefaultUserWikiName}
          . "' ingroup '"
          . $Foswiki::cfg{SuperAdminGroup} . "'",
        then => 0,
        else => 1
    );
}

sub test_73 {
    my $this = shift;
    $this->simpleTest(
        test => "'$Foswiki::cfg{DefaultUserWikiName}' ingroup 'GropeGroup'",
        then => 1,
        else => 0
    );
}

sub test_74 {
    my $this = shift;
    $this->simpleTest(
        test => "'" . $Foswiki::cfg{AdminUserLogin} . "' ingroup 'WikiGuest'",
        then => 0,
        else => 1
    );
}

sub test_75 {
    my $this = shift;
    $this->simpleTest(
        test => "'"
          . $Foswiki::cfg{AdminUserLogin}
          . "' ingroup 'ThereHadBetterBeNoSuchGroup'",
        then => 0,
        else => 1
    );
}

sub test_76 {
    my $this = shift;
    $this->simpleTest(
        test => "'"
          . $Foswiki::cfg{AdminUserLogin}
          . "' ingroup '"
          . $Foswiki::cfg{SuperAdminGroup} . "'",
        then => 1,
        else => 0
    );
}

sub test_77 {
    my $this = shift;
    $this->simpleTest(
        test => "'" . $Foswiki::cfg{AdminUserLogin} . "' ingroup 'GropeGroup'",
        then => 0,
        else => 1
    );
}

sub test_78 {
    my $this = shift;
    $this->simpleTest(
        test => "'" . $Foswiki::cfg{DefaultUserLogin} . "' ingroup 'WikiGuest'",
        then => 0,
        else => 1
    );
}

sub test_79 {
    my $this = shift;
    $this->simpleTest(
        test => "'"
          . $Foswiki::cfg{DefaultUserLogin}
          . "' ingroup 'ThereHadBetterBeNoSuchGroup'",
        then => 0,
        else => 1
    );
}

sub test_80 {
    my $this = shift;
    $this->simpleTest(
        test => "'"
          . $Foswiki::cfg{DefaultUserLogin}
          . "' ingroup '"
          . $Foswiki::cfg{SuperAdminGroup} . "'",
        then => 0,
        else => 1
    );
}

sub test_81 {
    my $this = shift;
    $this->simpleTest(
        test => "'"
          . $Foswiki::cfg{DefaultUserLogin}
          . "' ingroup 'GropeGroup'",
        then => 1,
        else => 0
    );
}

sub test_82 {
    my $this = shift;
    $this->simpleTest(
        test => "'" . $Foswiki::cfg{AdminUserLogin} . "' ingroup 'WikiGuest'",
        then => 0,
        else => 1
    );
}

sub test_83 {
    my $this = shift;
    $this->simpleTest(
        test => "'"
          . $Foswiki::cfg{AdminUserLogin}
          . "' ingroup 'ThereHadBetterBeNoSuchGroup'",
        then => 0,
        else => 1
    );
}

sub test_84 {
    my $this = shift;
    $this->simpleTest(
        test => "'"
          . $Foswiki::cfg{AdminUserLogin}
          . "' ingroup '"
          . $Foswiki::cfg{SuperAdminGroup} . "'",
        then => 1,
        else => 0
    );
}

sub test_85 {
    my $this = shift;
    $this->simpleTest(
        test => "'" . $Foswiki::cfg{AdminUserLogin} . "' ingroup 'GropeGroup'",
        then => 0,
        else => 1
    );
}

sub test_86 {
    my $this = shift;
    $this->simpleTest(
        test => "'" . $Foswiki::cfg{DefaultUserLogin} . "' ingroup 'WikiGuest'",
        then => 0,
        else => 1
    );
}

sub test_87 {
    my $this = shift;
    $this->simpleTest(
        test => "'"
          . $Foswiki::cfg{DefaultUserLogin}
          . "' ingroup 'ThereHadBetterBeNoSuchGroup'",
        then => 0,
        else => 1
    );
}

sub test_88 {
    my $this = shift;
    $this->simpleTest(
        test => "'"
          . $Foswiki::cfg{DefaultUserLogin}
          . "' ingroup '"
          . $Foswiki::cfg{SuperAdminGroup} . "'",
        then => 0,
        else => 1
    );
}

sub test_89 {
    my $this = shift;
    $this->simpleTest(
        test => "'"
          . $Foswiki::cfg{DefaultUserLogin}
          . "' ingroup 'GropeGroup'",
        then => 1,
        else => 0
    );
}

sub test_90 {
    my $this = shift;
    $this->simpleTest( test => "isweb 'System'", then => 1, else => 0 );
}

sub test_91 {
    my $this = shift;
    $this->simpleTest( test => "isweb 'Not a web'", then => 0, else => 1 );
}

sub test_92 {
    my $this = shift;
    $this->simpleTest( test => "istopic \$'System'", then => 0, else => 1 );
}

sub test_93 {
    my $this = shift;
    $this->simpleTest( test => "istopic \$'Not a web'", then => 0, else => 1 );
}

sub test_93a {
    my $this = shift;
    $this->simpleTest(
        test => "istopic fields[name='nonExistantField']",
        then => 0,
        else => 1
    );
}

sub test_93b {
    my $this = shift;
    $this->simpleTest(
        test => "istopic fields[name='nonExistantField'].value",
        then => 0,
        else => 1
    );
}

sub test_93c {
    my $this = shift;
    $this->simpleTest(
        test => "defined fields[name='nonExistantField']",
        then => 0,
        else => 1
    );
}

sub test_93d {
    my $this = shift;
    $this->simpleTest(
        test => "defined fields[name='nonExistantField'].value",
        then => 0,
        else => 1
    );
}

sub test_94 {
    my $this = shift;
    $this->simpleTest( test => "isweb \$ 'SYSTEMWEB'", then => 1, else => 0 );
}

sub test_95 {
    my $this = shift;
    $this->simpleTest( test => 'defined \'SYSTEMWEB\'', then => 1, else => 0 );
}

sub test_96 {
    my $this = shift;
    $this->simpleTest( test => 'defined SYSTEMWEB', then => 1, else => 0 );
}

sub test_97 {
    my $this = shift;
    $this->simpleTest( test => 'defined \'IF\'', then => 1, else => 0 );
}

sub test_98 {
    my $this = shift;
    $this->simpleTest( test => 'defined IF', then => 1, else => 0 );
}

sub test_99 {
    my $this = shift;
    $this->simpleTest( test => "'A'=~'B'", then => 0, else => 1 );
}

sub test_99 {
    my $this = shift;
    $this->simpleTest( test => "'A'=~'A'", then => 1, else => 0 );
}

sub test_100 {
    my $this = shift;
    $this->simpleTest( test => "'AA'=~'A'", then => 1, else => 0 );
}

sub test_101 {
    my $this = shift;
    $this->simpleTest( test => "'foo bar baz'=~'\\bbar\\b'", then => 1, else => 0 );
}

sub test_102 {
    my $this = shift;
    $this->simpleTest( test => "'foo bar baz'=~'\\bbam\\b'", then => 0, else => 1 );
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up(@_);

    my $topicObject = Foswiki::Meta->new(
        $this->{session},
        $this->{users_web},
        "GropeGroup",
        "   * Set GROUP = "
          . Foswiki::Func::getWikiName( $this->{session}->{user} ) . "\n"
    );
    $topicObject->save();

    # Create WebHome topic to trap existance errors related to
    # normalizeWebTopicName
    $topicObject = Foswiki::Meta->new(
        $this->{session}, $this->{test_web},
        "WebHome",        "Gormless gimboid\n"
    );
    $topicObject->save();
}

sub simpleTest {
    my ( $this, %test ) = @_;
    $this->{session}->enterContext('test');
    $Foswiki::cfg{Fnargle} = 'Fleeble';
    $Foswiki::cfg{A}{B} = 'C';
    $this->{request}->param( 'notempty', 'v' );
    $this->{request}->param( 'empty',    '' );
    $this->{request}->param( 'notempty', 'v' );
    $this->{request}->param( 'empty',    '' );
    $this->{session}->{prefs}
      ->setInternalPreferences( 'NOTEMPTY' => 'V', 'EMPTY' => '' );
    $this->{session}->{prefs}
      ->setSessionPreferences( 'SNOTEMPTY' => 'V', 'SEMPTY' => '' );
    my $text = '%IF{"'
      . $test{test}
      . '" then="'
      . $test{then}
      . '" else="'
      . $test{else} . '"}%';
    my $result = $this->{test_topicObject}->expandMacros($text);

    #print STDERR "$text => $result\n";
    $this->assert_equals( '1', $result, $text . " => " . $result );
}

sub test_INCLUDEparams {
    my $this = shift;

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, "DeadHerring",
        <<'SMELL');
one %IF{ "defined NAME" then="1" else="0" }%
two %IF{ "$ NAME='%NAME%'" then="1" else="0" }%
three %IF{ "$ NAME=$ 'NAME{}'" then="1" else="0" }%
SMELL
    $topicObject->save();
    my $text = <<'PONG';
%INCLUDE{"DeadHerring" NAME="Red" warn="on"}%
PONG
    my $result = $this->{test_topicObject}->expandMacros($text);
    $this->assert_matches( qr/^\s*one 1\s+two 1\s+three 1\s*$/s, $result );
}

# check parse failures
sub test_badIF {
    my $this  = shift;
    my @tests = (
        { test => "'A'=?",   expect => "Syntax error in ''A'=?' at '?'" },
        { test => "'A'==",   expect => "Excess operators (= =) in ''A'=='" },
        { test => "'A' 'B'", expect => "Missing operator in ''A' 'B''" },
        { test => ' ',       expect => "Empty expression" },
    );

    foreach my $test (@tests) {
        my $text   = '%IF{"' . $test->{test} . '" then="1" else="0"}%';
        my $result = $this->{test_topicObject}->expandMacros($text);
        $result =~ s/^.*foswikiAlert'>\s*//s;
        $result =~ s/\s*<\/span>\s*//s;
        $this->assert( $result =~ s/^.*}:\s*//s );
        $this->assert_str_equals( $test->{expect}, $result );
    }
}

sub test_ContentAccessSyntax {
    my $this = shift;

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, "DeadHerring",
        <<'SMELL');
one %IF{ "BleaghForm.Wibble='Woo'" then="1" else="0" }%
%META:FORM{name="BleaghForm"}%
%META:FIELD{name="Wibble" title="Wobble" value="Woo"}%
SMELL
    $topicObject->save();
    my $text = <<'PONG';
%INCLUDE{"DeadHerring" NAME="Red" warn="on"}%
PONG
    my $result = $this->{test_topicObject}->expandMacros($text);
    $this->assert_matches( qr/^\s*one 1\s*$/s, $result );
}

sub test_ALLOWS_and_EXISTS {
    my $this = shift;
    my $wn   = Foswiki::Func::getWikiName( $this->{session}->{user} );
    my $meta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, "DeadDog",
        <<PONG);
   * Set ALLOWTOPICVIEW = WibbleFloon
   * Set ALLOWTOPICCHANGE = $wn
PONG
    $meta->save();

    my @tests;
    push(
        @tests,
        {
            test   => "'%TOPIC%' allows 'change'",
            expect => "1"
        }
    );
    push(
        @tests,
        {
            test   => "istopic '%TOPIC%'",
            expect => "1"
        }
    );
    push(
        @tests,
        {
            test   => "'%TOPIC%' allows 'view'",
            expect => "1",
        }
    );
    push(
        @tests,
        {
            test   => "'%WEB%.%TOPIC%' ALLOWS 'change'",
            expect => "1",
        }
    );
    push(
        @tests,
        {
            test   => "'%WEB%.%TOPIC%' allows 'view'",
            expect => "1",
        }
    );
    push(
        @tests,
        {
            test   => "'DeadDog' ALLOWS 'view'",
            expect => "0",
        }
    );
    push(
        @tests,
        {
            test   => "'$this->{test_web}' allows 'view'",
            expect => "1"
        }
    );
    push(
        @tests,
        {
            test   => '\'' . $this->{test_web} . '.DeadDog\' allows \'change\'',
            expect => "1"
        }
    );
    push(
        @tests,
        {
            test => '\''
              . $this->{test_web}
              . '.NonExitantLazyFox\' allows \'change\'',
            expect => "1"
        }
    );
    push(
        @tests,
        {
            test   => '\'NonExistantWeb.WebHome\' allows \'change\'',
            expect => "0"
        }
    );
    push(
        @tests,
        {
            test   => '\'NonExistantWeb.NonExitantLazyFox\' allows \'change\'',
            expect => "0"
        }
    );
    push(
        @tests,
        {
            test   => "istopic 'LazyFox'",
            expect => "0"
        }
    );
    push(
        @tests,
        {
            test   => "istopic '$this->{test_web}.LazyFox'",
            expect => "0"
        }
    );
    push(
        @tests,
        {
            test   => "istopic '$this->{test_web}.DeadDog'",
            expect => "1"
        }
    );
    push(
        @tests,
        {
            test   => "isweb '$this->{test_web}'",
            expect => "1"
        }
    );
    push(
        @tests,
        {
            test   => "isweb '%WEB%'",
            expect => "1"
        }
    );
    push(
        @tests,
        {
            test   => "isweb 'NotAHopeInHellPal'",
            expect => "0"
        }
    );
    push(
        @tests,
        {
            test   => "'NotAHopeInHellPal' allows 'view'",
            expect => "1"
        }
    );
    push(
        @tests,
        {
            test   => "'NotAHopeInHellPal.WebHome' allows 'view'",
            expect => "0"
        }
    );
    $this->{session}->finish();
    my $request = new Unit::Request( {} );
    $request->path_info("/$this->{test_web}/$this->{test_topic}");
    $this->{session} = new Foswiki( undef, $request );
    $meta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic} );

    foreach my $test (@tests) {
        my $text   = '%IF{"' . $test->{test} . '" then="1" else="0"}%';
        my $result = $meta->expandMacros($text);
        $this->assert_str_equals( $test->{expect}, $result,
            "$text: '$result'" );
    }
}

sub test_DOS {
    my $this = shift;
    my $text = <<'PONG';
   * Set LOOP = %IF{"$ LOOP = '1'" then="ping" else="pong"}%
PONG
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic}, $text );
    $topicObject->save();
    my $result = $this->{test_topicObject}->expandMacros($text);
    $this->assert_str_equals( "   * Set LOOP = pong\n", $result );
}

sub test_TOPICINFO {
    my $this = shift;

    my $topicName = 'TopicInfo';

    my $meta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, $topicName,
        <<PONG);
oneapeny twoapenny we all fall down
PONG
    $meta->save();

    $meta =
      Foswiki::Meta->load( $this->{session}, $this->{test_web}, $topicName );
    my $ti = $meta->get('TOPICINFO');

    $this->assert_str_equals( $ti->{version}, '1.1' );
    $this->assert(
        $this->{session}->topicExists( $this->{test_web}, $topicName ) );

#TODO: these need to be moved into Fn_META and then implemented (its a really simple change in Foswiki.pm
#    $this->assert_str_equals(
#        $meta->expandMacros'%META{"info.rev"}%'),
#        '1'
#    );
#    $this->assert_str_equals(
#        $meta->expandMacros{'%META{"info.rev"}%'),
#        '1'
#    );
#    $this->assert_str_equals(
#        $meta->expandMacros('%META{"' . $this->{test_web} . '.' . $topicName . '/info.rev"}%'),
#        '1'
#    );

    my @tests;
    push(
        @tests,
        {
            test   => "info.version = '1.1'",
            expect => "1",
        }
    );
    push(
        @tests,
        {
            test   => "info.rev = '1'",
            expect => "1",
        }
    );

    push(
        @tests,
        {
            test   => "'$this->{test_web}.$topicName'/info.version = '1.1'",
            expect => "1"
        }
    );
    push(
        @tests,
        {
            test   => "'$this->{test_web}.$topicName'/info.rev = '1'",
            expect => "1"
        }
    );

    push(
        @tests,
        {
            test   => "istopic fields[name='nonExistantField']",
            expect => "0"
        }
    );
    push(
        @tests,
        {
            test   => "defined('Sandbox.TestTopic0NotExist'/info.rev)",
            expect => "0"
        }
    );
    push(
        @tests,
        {
            test   => "'Sandbox.TestTopic0NotExist'/info.rev = 'rev'",
            expect => "0"
        }
    );

    foreach my $test (@tests) {
        my $text   = '%IF{"' . $test->{test} . '" then="1" else="0"}%';
        my $result = $meta->expandMacros($text);

        #print STDERR "RUN $text => $result\n";
        $this->assert_str_equals( $test->{expect}, $result,
            "$text: '$result'" );
    }
}

sub test_ISEMPTY_PARAM_NOTTHERE {
    my $this = shift;
    $this->simpleTest( test => 'isempty notthere', then => 1, else => 0 );
}

sub test_ISEMPTY_PARAM_EMPTY {
    my $this = shift;
    $this->simpleTest( test => 'defined empty', then => 1, else => 0 );
    $this->simpleTest( test => 'isempty empty', then => 1, else => 0 );
}

sub test_ISEMPTY_PARAM_NOTEMPTY {
    my $this = shift;
    $this->simpleTest( test => 'isempty notempty', then => 0, else => 1 );
}

sub test_ISEMPTY_PREF_NOTTHERE {
    my $this = shift;
    $this->simpleTest( test => 'isempty NOTTHERE', then => 1, else => 0 );
}

sub test_ISEMPTY_PREF_EMPTY {
    my $this = shift;
    $this->simpleTest( test => 'defined EMPTY', then => 1, else => 0 );
    $this->simpleTest( test => 'isempty EMPTY', then => 1, else => 0 );
}

sub test_ISEMPTY_PREF_NOTEMPTY {
    my $this = shift;
    $this->simpleTest( test => 'isempty SNOTEMPTY', then => 0, else => 1 );
}

sub test_ISEMPTY_SESSION_NOTTHERE {
    my $this = shift;
    $this->simpleTest( test => 'isempty SNOTTHERE', then => 1, else => 0 );
}

sub test_ISEMPTY_SESSION_EMPTY {
    my $this = shift;
    $this->simpleTest( test => 'defined SEMPTY', then => 1, else => 0 );
    $this->simpleTest( test => 'isempty SEMPTY', then => 1, else => 0 );
}

sub test_ISEMPTY_SESSION_NOTEMPTY {
    my $this = shift;
    $this->simpleTest( test => 'isempty NOTEMPTY', then => 0, else => 1 );
}

sub test_ISEMPTY_EXPR_EMPTY {
    my $this = shift;
    $this->simpleTest( test => "isempty ''", then => 1, else => 0 );
}

sub test_ISEMPTY_EXPR_UNDEF {
    my $this = shift;
    $this->simpleTest( test => "isempty undef", then => 1, else => 0 );
}

sub test_d2n {
    my $this = shift;

    #TRUE cases
    $this->simpleTest(
        test => "d2n('2007-03-26') = d2n('2007-03-26')",
        then => 1,
        else => 0
    );

    $this->simpleTest(
        test => "d2n('2007-03-27') != d2n('2007-03-26')",
        then => 1,
        else => 0
    );
    $this->simpleTest(
        test => "d2n('2007-04-26') != d2n('2007-03-26')",
        then => 1,
        else => 0
    );
    $this->simpleTest(
        test => "d2n('2008-03-26') != d2n('2007-03-26')",
        then => 1,
        else => 0
    );
    $this->simpleTest(
        test => "d2n('2007-03-26') != d2n('2007-03-27')",
        then => 1,
        else => 0
    );
    $this->simpleTest(
        test => "d2n('2007-03-26') != d2n('2007-04-26')",
        then => 1,
        else => 0
    );
    $this->simpleTest(
        test => "d2n('2007-03-26') != d2n('2008-03-26')",
        then => 1,
        else => 0
    );

    $this->simpleTest(
        test => "d2n('2007-03-27') > d2n('2007-03-26')",
        then => 1,
        else => 0
    );
    $this->simpleTest(
        test => "d2n('2007-04-26') > d2n('2007-03-26')",
        then => 1,
        else => 0
    );
    $this->simpleTest(
        test => "d2n('2008-03-26') > d2n('2007-03-26')",
        then => 1,
        else => 0
    );
    $this->simpleTest(
        test => "d2n('2007-03-26') >= d2n('2007-03-26')",
        then => 1,
        else => 0
    );
    $this->simpleTest(
        test => "d2n('2007-03-27') >= d2n('2007-03-26')",
        then => 1,
        else => 0
    );
    $this->simpleTest(
        test => "d2n('2007-04-26') >= d2n('2007-03-26')",
        then => 1,
        else => 0
    );
    $this->simpleTest(
        test => "d2n('2008-03-26') >= d2n('2007-03-26')",
        then => 1,
        else => 0
    );
    $this->simpleTest(
        test => "d2n('2007-03-26') < d2n('2007-03-27')",
        then => 1,
        else => 0
    );
    $this->simpleTest(
        test => "d2n('2007-03-26') < d2n('2007-04-26')",
        then => 1,
        else => 0
    );
    $this->simpleTest(
        test => "d2n('2007-03-26') < d2n('2008-03-26')",
        then => 1,
        else => 0
    );
    $this->simpleTest(
        test => "d2n('2007-03-26') <= d2n('2007-03-26')",
        then => 1,
        else => 0
    );
    $this->simpleTest(
        test => "d2n('2007-03-26') <= d2n('2007-03-27')",
        then => 1,
        else => 0
    );
    $this->simpleTest(
        test => "d2n('2007-03-26') <= d2n('2007-04-26')",
        then => 1,
        else => 0
    );
    $this->simpleTest(
        test => "d2n('2007-03-26') <= d2n('2008-03-26')",
        then => 1,
        else => 0
    );

    #FALSE cases
    $this->simpleTest(
        test => "d2n('2007-03-26') != d2n('2007-03-26')",
        then => 0,
        else => 1
    );

    $this->simpleTest(
        test => "d2n('2007-03-27') = d2n('2007-03-26')",
        then => 0,
        else => 1
    );
    $this->simpleTest(
        test => "d2n('2007-04-26') = d2n('2007-03-26')",
        then => 0,
        else => 1
    );
    $this->simpleTest(
        test => "d2n('2008-03-26') = d2n('2007-03-26')",
        then => 0,
        else => 1
    );
    $this->simpleTest(
        test => "d2n('2007-03-26') = d2n('2007-03-27')",
        then => 0,
        else => 1
    );
    $this->simpleTest(
        test => "d2n('2007-03-26') = d2n('2007-04-26')",
        then => 0,
        else => 1
    );
    $this->simpleTest(
        test => "d2n('2007-03-26') = d2n('2008-03-26')",
        then => 0,
        else => 1
    );

    $this->simpleTest(
        test => "d2n('2007-03-27') < d2n('2007-03-26')",
        then => 0,
        else => 1
    );
    $this->simpleTest(
        test => "d2n('2007-04-26') < d2n('2007-03-26')",
        then => 0,
        else => 1
    );
    $this->simpleTest(
        test => "d2n('2008-03-26') < d2n('2007-03-26')",
        then => 0,
        else => 1
    );

#    $this->simpleTest(test => "d2n('2007-03-26') <= d2n('2007-03-26')", then => 0, else => 1);
    $this->simpleTest(
        test => "d2n('2007-03-27') <= d2n('2007-03-26')",
        then => 0,
        else => 1
    );
    $this->simpleTest(
        test => "d2n('2007-04-26') <= d2n('2007-03-26')",
        then => 0,
        else => 1
    );
    $this->simpleTest(
        test => "d2n('2008-03-26') <= d2n('2007-03-26')",
        then => 0,
        else => 1
    );
    $this->simpleTest(
        test => "d2n('2007-03-26') > d2n('2007-03-27')",
        then => 0,
        else => 1
    );
    $this->simpleTest(
        test => "d2n('2007-03-26') > d2n('2007-04-26')",
        then => 0,
        else => 1
    );
    $this->simpleTest(
        test => "d2n('2007-03-26') > d2n('2008-03-26')",
        then => 0,
        else => 1
    );

#    $this->simpleTest(test => "d2n('2007-03-26') >= d2n('2007-03-26')", then => 0, else => 1);
    $this->simpleTest(
        test => "d2n('2007-03-26') >= d2n('2007-03-27')",
        then => 0,
        else => 1
    );
    $this->simpleTest(
        test => "d2n('2007-03-26') >= d2n('2007-04-26')",
        then => 0,
        else => 1
    );
    $this->simpleTest(
        test => "d2n('2007-03-26') >= d2n('2008-03-26')",
        then => 0,
        else => 1
    );

#try to examine the root of my looking into this - d2n('13 Oct 2008') >= d2n('2008/12/1')
    $this->simpleTest(
        test => "d2n('2008/10/13') >= d2n('2008/12/1')",
        then => 0,
        else => 1
    );
    $this->simpleTest(
        test => "d2n('13 Oct 2008') >= d2n('2008/12/1')",
        then => 0,
        else => 1
    );

}

sub test_atomic {
    my $this = shift;
    
    #nope, parse failure (empty Expression) :/
    $this->simpleTest( test => "0", then => 0, else => 1 );
    
    $this->simpleTest( test => "1", then => 1, else => 0 );
    $this->simpleTest( test => "9", then => 1, else => 0 );

    $this->simpleTest( test => "-1", then => 1, else => 0 );
    $this->simpleTest( test => "-0", then => 0, else => 1 );

    $this->simpleTest( test => "0.0", then => 0, else => 1 );
    
    ##and again as strings..
    $this->simpleTest( test => "'1'", then => 1, else => 0 );
    $this->simpleTest( test => "'9'", then => 1, else => 0 );
    #surprisingly..
    $this->simpleTest( test => "'-1'", then => 1, else => 0 );
    $this->simpleTest( test => "'-0'", then => 1, else => 0 );

    $this->simpleTest( test => "'0.0'", then => 1, else => 0 );
    $this->simpleTest( test => "''", then => 0, else => 1 );
}

1;
