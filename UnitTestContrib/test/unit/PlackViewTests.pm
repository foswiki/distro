# See bottom of file for license and copyright information

package PlackViewTests;
use v5.14;

use Assert;
use HTTP::Request::Common;

use Moo;
use namespace::clean;
extends qw(Unit::PlackTestCase);

around initialize => sub {
    my $orig = shift;
    my $this = shift;

    $orig->( $this, @_ );
};

around prepareTestClientList => sub {
    my $orig = shift;
    my $this = shift;

    my $tests = $orig->( $this, @_ );

    push @$tests, (
        {
            client => \&client_simple,
            name   => 'probe',
            init   => sub {
                my $this = shift;
                my %args = @_;
                my $app  = $args{data}{app};

                $app->cfg->data->{UsersWebName} = 'Sandbox';
            },
        },
    );

    return $tests;
};

sub client_simple {
    my $this = shift;
    my $test = shift;

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
