# See bottom of file for license and copyright information

package PlackPostTests;
use v5.14;
use utf8;

use HTTP::Request::Common;
use HTML::Parser ();
use Data::Dumper;
use Encoding;

use Foswiki::Class;
extends qw(Unit::PlackTestCase);

use constant SIMPLE_CONTENT =>
  "Simple Text File\nАбо просто текст у файлі\n";

around prepareTestClientList => sub {
    my $orig  = shift;
    my $this  = shift;
    my $tests = $orig->( $this, @_ );

    push @$tests, (
        {
            name      => 'attach_simple',
            client    => \&_test_attach_simple,
            appParams => { env => { FOSWIKI_TEST_NOP => 'Simple env test', }, },
            testWebs  => {
                $this->testWebName('AttachSimple') =>
                  { TopicForAttach => 'Some topic text', },
            },
            testUsers => [
                {
                    login    => 'user1',
                    forename => 'User1',
                    surname  => 'SurUser1',
                    email    => 'user1@example.com',
                    group    => 'TestGroup',
                },
                {
                    login    => 'user2',
                    forename => 'User2',
                    surname  => 'SurUser2',
                    email    => 'user2@example.com',
                    group    => 'TestGroup',
                },
            ],
            initRequest => sub {
                my $this = shift;
                my %args = @_;
                my $app  = $args{serverApp};
                $app->cfg->data->{Validation}{Method} = 'none';
                $app->cfg->data->{DisableAllPlugins} = 1;
            },
        },
    );
    return $tests;
};

sub _test_attach_simple {
    my $this = shift;
    my %args = @_;

    my $app  = $this->app;
    my $test = $args{plackTestObj};

    my $web   = ( keys %{ $args{testParams}{testWebs} } )[0];
    my $topic = ( keys %{ $args{testParams}{testWebs}{$web} } )[0];

    my $viewUrl = $app->getScriptUrlPath( $web, $topic, "view" );

    my $res     = $test->request( GET $viewUrl);
    my $content = $res->content;

    my $matchedA = $this->findHTMLTag(
        $content,
        tag   => 'a',
        text  => 'Attach',
        class => qr/^foswikiReq/,
    );

    $this->assert( defined($matchedA), "Attach link not found in output" );

    my $attachUrl = $matchedA->{attrs}{href};
    $res     = $test->request( GET $attachUrl);
    $content = $res->content;

    my $attachForm = $this->findHTMLTag(
        $content,
        tag  => 'form',
        text => qr/Attach new file/,
        name => 'main',
    );

    $this->assert( defined($attachForm),
        "Cannot find attachment form in response to $attachUrl request" );

    my $method = $attachForm->{attrs}{method};

    $this->assert_equals( 'post', lc($method),
        "Expected form method POST but received $method" );

    my $contentEnc = $attachForm->{attrs}{enctype};
    my $uploadUrl  = $attachForm->{attrs}{action};

    my $attachFileName = "TestAttachFile.txt";

    $res = $test->request(
        POST $uploadUrl,
        Content_Type     => 'form-data',
        Content_Encoding => $contentEnc,
        Content          => [
            attach => [
                undef, $attachFileName,
                Content => Encode::encode( 'utf-8', SIMPLE_CONTENT ),
            ],
        ],
    );

    $this->assert( $res->is_redirect,
        "Upload must have finished with redirect response." );

    my $redirUrl = $res->header('Location');

    $this->assert_equals( $viewUrl, $redirUrl,
        "Redirect doesn't point back to $viewUrl" );

    $res = $test->request( GET $redirUrl);

    $this->assert( $res->code == 200, "Bad request status code " . $res->code );

    $content = $res->content;

    my $attachmentsTable = $this->findHTMLTag(
        $content,
        tag   => 'table',
        class => qr/foswikiTable/,
        text  => $attachFileName,
    );

    $this->assert( defined($attachmentsTable),
            "The topic "
          . $web . "."
          . $topic
          . " doesn't contain attachments table with test attachment "
          . $attachFileName );

    my $filePath = File::Spec->catfile( $this->app->cfg->data->{PubDir},
        $web, $topic, $attachFileName );

    my $fh;
    $this->assert(
        open( $fh, "<:encoding(utf8)", $filePath ),
        "Cannot open $filePath for reading: $!"
    );

    local $/;
    my $fileContent = <$fh>;
    close $fh;

    $this->assert_equals( SIMPLE_CONTENT, $fileContent,
        "Actual attachment content differs from what's been uploaded" );
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
