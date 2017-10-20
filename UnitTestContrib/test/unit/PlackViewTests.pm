# See bottom of file for license and copyright information

package PlackViewTests;

use Assert;
use HTTP::Request::Common;

use Foswiki::Class;
extends qw(Unit::PlackTestCase);

around prepareTestClientList => sub {
    my $orig = shift;
    my $this = shift;

    my $tests = $orig->( $this, @_ );

    push @$tests, (
        {
            # This is intentional use of client-prefixed function to demonstrate
            # both methods of defining a test. What makes these tests different
            # is initRequest key.
            client      => \&clientSimple,
            name        => 'probe',
            initRequest => sub {
                my $this = shift;
                my %args = @_;
                my $app  = $args{serverApp};

                $app->cfg->data->{UsersWebName} = 'Sandbox';
            },
        },
    );

    return $tests;
};

sub clientSimple {
    my $this = shift;
    my %args = @_;

    my $test = $args{plackTestObj};

    my $expected =
      '<h1 id="Welcome_to_the_Main_web">  Welcome to the Main web </h1>
Congratulations, you have finished installing Foswiki.
<p>';

    my $res = $test->request( GET "/" );

    my $content = $res->content;

    $this->assert_html_matches( $expected, $content );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2016 Foswiki Contributors. Foswiki Contributors
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
