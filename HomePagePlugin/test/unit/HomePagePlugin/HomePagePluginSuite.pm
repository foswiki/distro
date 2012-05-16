# See bottom of file for license and copyright information
package HomePagePluginSuite;

use strict;
use warnings;
use FoswikiTestCase;
use Foswiki::UI::View;
our @ISA = 'FoswikiTestCase';

sub set_up {
    my $this = shift;

    $this->{test_web}   = 'TemporaryHomePagePluginTestWeb';
    $this->{test_topic} = 'TestTopic';

    $this->SUPER::set_up();
}

sub loadExtraConfig {
    my $this = shift;

    $this->SUPER::loadExtraConfig();

    $Foswiki::cfg{HomePagePlugin}{SiteDefaultTopic} =
      "$this->{test_web}.$this->{test_topic}";
    $Foswiki::cfg{HomePagePlugin}{GotoHomePageOnLogin} = 1;
    $Foswiki::cfg{HomePagePlugin}{HostnameMapping}     = {
        'http://home.org'     => 'Home',
        'http://www.home.org' => 'Home.Www',
        'http://blog.org'     => 'Blog',
        'http://www.blog.org' => 'Blog.Www',
    };
}

sub test_siteDefaultTopic {
    my $this = shift;

    my $query = Unit::Request->new( {} );
    $query->path_info("");

    $this->createNewFoswikiSession( $this->{test_user_login},
        $query, { view => 1 } );

    $this->assert_equals( $this->{test_topic},
        $Foswiki::Plugins::SESSION->{topicName} );
    $this->assert_equals( $this->{test_web},
        $Foswiki::Plugins::SESSION->{webName} );
}

sub test_login {
    my $this = shift;

    my $query = Unit::Request->new(
        {
            username => ['dogbert'],
            origurl  => ['spam']
        }
    );
    $query->path_info("");
    $query->header( 'Host' => 'www.home.org' );

    $this->{test_topicObject}->finish() if $this->{test_topicObject};
    $this->{session}->finish()          if $this->{session};
    $this->{session} =
      Foswiki->new( $this->{test_user_login}, $query, { login => 1 } );

    $this->assert_equals( 'Www',  $Foswiki::Plugins::SESSION->{topicName} );
    $this->assert_equals( 'Home', $Foswiki::Plugins::SESSION->{webName} );
}

sub test_view {
    my $this = shift;

    my $query = Unit::Request->new(
        {
            username => ['dogbert'],
            origurl  => ['spam']
        }
    );
    $query->path_info("");
    $query->header( 'Host' => 'www.home.org' );

    $this->{test_topicObject}->finish() if $this->{test_topicObject};
    $this->{session}->finish()          if $this->{session};
    $this->{session} =
      Foswiki->new( $this->{test_user_login}, $query, { view => 1 } );

    $this->assert_equals( 'Www',  $Foswiki::Plugins::SESSION->{topicName} );
    $this->assert_equals( 'Home', $Foswiki::Plugins::SESSION->{webName} );
}

sub test_invalid_redirect {
    my $this = shift;

    $Foswiki::cfg{HomePagePlugin}{SiteDefaultTopic} = "http://foswiki.com";

    my $query = Unit::Request->new(
        {
            username => ['dogbert'],
            origurl  => ['spam']
        }
    );
    $query->path_info("");

    $this->{test_topicObject}->finish() if $this->{test_topicObject};
    $this->{session}->finish()          if $this->{session};

    $this->{session} =
      Foswiki->new( $this->{test_user_login}, $query, { view => 1 } );

    $this->assert_equals( $Foswiki::cfg{HomeTopicName},
        $Foswiki::Plugins::SESSION->{topicName} );
    $this->assert_equals( $Foswiki::cfg{UsersWebName},
        $Foswiki::Plugins::SESSION->{webName} );
}

sub test_save {
    my $this = shift;

    my $query = Unit::Request->new(
        {
            username => ['dogbert'],
            origurl  => ['spam']
        }
    );
    $query->path_info("/System/WebHome");
    $query->header( 'Host' => 'www.home.org' );

    $this->{test_topicObject}->finish() if $this->{test_topicObject};
    $this->{session}->finish()          if $this->{session};
    $this->{session} =
      Foswiki->new( $this->{test_user_login}, $query, { save => 1 } );

    $this->assert_equals( 'WebHome', $Foswiki::Plugins::SESSION->{topicName} );
    $this->assert_equals( 'System',  $Foswiki::Plugins::SESSION->{webName} );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2012 Foswiki Contributors. Foswiki Contributors
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
