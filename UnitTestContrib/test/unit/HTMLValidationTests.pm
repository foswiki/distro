package HTMLValidationTests;
use strict;
use warnings;

#this has been quickly copied from the UICompilation tests
#TODO: need to pick a list of topics, actions, opps's and add detection of installed skins

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use strict;
use Foswiki;
use Foswiki::UI::View;
use Error qw( :try );
use HTML::Tidy;

our $UI_FN;
our $SCRIPT_NAME;
our $SKIN_NAME;
our %expected_status = (
    search => 302,
    save   => 302
);

#TODO: this is beause we're calling the UI::function, not UI:Execute - need to re-write it to use the full engine
our %expect_non_html = (
    rest        => 1,
    viewfile    => 1,
    register    => 1,    #TODO: missing action make it throw an exception
    manage      => 1,    #TODO: missing action make it throw an exception
    upload      => 1,    #TODO: zero size upload
    resetpasswd => 1,
);

# Thanks to Foswiki::Form::Radio, and a default -columns attribute = 4,
# CGI::radio_group() uses HTML3 tables (missing summary attribute) for layout
# and this makes HTMLTidy cry.
our %expect_table_summary_warnings = ( edit => 1 );

sub new {
    my ( $class, @args ) = @_;
    $Foswiki::cfg{EnableHierarchicalWebs} = 1;
    my $self = $class->SUPER::new( "UIFnCompile", @args );
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;

#see http://tidy.sourceforge.net/docs/quickref.html for parameters - be warned that some cause HTML::Tidy to crash
    $this->{tidy} = HTML::Tidy->new(
        {

            #turn off warnings until we have fixed errors
            'show-warnings' => 1,

            #'accessibility-check'	=> 3,
            'drop-empty-paras' => 0
        }
    );

    #print STDERR "HTML::Tidy Version: ".$HTML::Tidy::VERSION."\n";
    #print STDERR "libtidy Version: ".HTML::Tidy::libtidy_version()."\n";

    $this->SUPER::set_up();

    #the test web is made using the '_empty' web - not so useful here
    my $webObject = Foswiki::Meta->new( $this->{session}, $this->{test_web} );
    $webObject->populateNewWeb(
        '_default',
        {
            ALLOWWEBCHANGE => '',
            ALLOWWEBRENAME => ''
        }
    );

    return;
}

sub fixture_groups {
    my @scripts;

    foreach my $script ( keys( %{ $Foswiki::cfg{SwitchBoard} } ) ) {
        push( @scripts, $script );
        next if ( defined(&$script) );

        #print STDERR "defining sub $script()\n";
        my $dispatcher = $Foswiki::cfg{SwitchBoard}{$script};
        if ( ref($dispatcher) eq 'ARRAY' ) {

            # Old-style array entry in switchboard from a plugin
            my @array = @$dispatcher;
            $dispatcher = {
                package  => $array[0],
                function => $array[1],
                context  => $array[2],
            };
        }

        my $package  = $dispatcher->{package} || 'Foswiki::UI';
        my $function = $dispatcher->{function};
        my $sub      = $package . '::' . $function;

        #print STDERR "call $sub\n";
        my $evalsub = <<"SUB";
            sub $script {
                eval "require \$package" if (defined(\$package));
                    \$UI_FN = \$sub;
                    \$SCRIPT_NAME = \$script;
            }
            1;
SUB
        if ( not( eval $evalsub ) ) {
            die $@;
        }
    }

    my @skins;

    #TODO: detect installed skins..
    foreach my $skin (qw/default pattern plain print/) {
        push( @skins, $skin );
        next if ( defined(&$skin) );

        #print STDERR "defining sub $skin()\n";
        eval <<SUB;
		sub $skin {
			\$SKIN_NAME = \$skin;
		}
SUB
    }

    my @groups;
    push( @groups, \@scripts );
    push( @groups, \@skins );
    return @groups;
}

sub call_UI_FN {
    my ( $this, $web, $topic, $tmpl ) = @_;
    my $query = Unit::Request->new(
        {
            webName   => [$web],
            topicName => [$topic],

   #            template  => [$tmpl],
   #debugenableplugins => 'TestFixturePlugin,SpreadSheetPlugin,InterwikiPlugin',
            skin => $SKIN_NAME
        }
    );
    $query->path_info("/$web/$topic");
    $query->method('GET');

#turn off ASSERTS so we get less plain text erroring - the user should always see html
    local $ENV{FOSWIKI_ASSERTS} = 0;
    my $fatwilly = Foswiki->new( $this->{test_user_login}, $query );
    my ( $responseText, $result, $stdout, $stderr );
    $responseText = "Status: 500";    #errr, boom
    try {
        ( $responseText, $result, $stdout, $stderr ) = $this->captureWithKey(
            $SCRIPT_NAME => sub {
                no strict 'refs';
                &${UI_FN}($fatwilly);
                use strict 'refs';
                $Foswiki::engine->finalize( $fatwilly->{response},
                    $fatwilly->{request} );
            }
        );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $responseText = $e->stringify();
    }
    catch Foswiki::EngineException with {
        my $e = shift;
        $responseText = $e->stringify();
    };
    $fatwilly->finish();

    $this->assert($responseText);
    $this->assert_matches(qr/^1?$/, $result, "$SCRIPT_NAME returned '$result'")
        if defined $result;
    $this->assert_equals('', $stderr, "$SCRIPT_NAME errored: '$stderr'")
        if defined $stderr;

    # Remove CGI header
    my $CRLF = "\015\012";    # "\r\n" is not portable
    my ( $header, $body );
    if ( $responseText =~ /^(.*?)$CRLF$CRLF(.+)$/s
         or ($stdout && $stdout =~ /^(.*?)$CRLF$CRLF(.+)$/s) ) {

        # Response can be in stdout if the request is split, like for
        # statistics
        $header = $1;         # untaint is OK, it's a test
        $body   = $2;
    }
    else {
        $header = '';
        $body   = $responseText;
    }

    my $status = 666;
    if ( $header =~ /Status: (\d*)./ ) {
        $status = $1;
    }

    # aparently we allow the web server to add a 200 status thus risking that
    # an error situation is marked as 200
    # $this->assert_num_not_equals(666, $status,
    #     "no response Status set in probably valid reply\nHEADER: $header\n");
    if ( $status == 666 ) {
        $status = 200;
    }
    $this->assert_num_not_equals( 500, $status,
        'exception thrown, or status not set properly' );

    return ( $status, $header, $body, $stdout, $stderr );
}

sub do_save_attachment {
    my ( $web, $topic, $name, $params ) = @_;

    binmode( $params->{stream} );
    Foswiki::Func::saveAttachment( $web, $topic, $name, $params );

    return;
}

sub do_create_file {
    my ( $stream, $data ) = @_;

    binmode($stream);
    print $stream $data;

    return length $data;
}

sub add_attachment {
    my ( $this, $web, $topic, $name, $data, $params ) = @_;
    my %save_params = (
        dontlog    => $params->{dontlog}    || 1,
        comment    => $params->{comment}    || 'default comment for ' . $name,
        filepath   => $params->{filepath}   || '/local/file/' . $name,
        filedate   => $params->{filedata}   || time(),
        createlink => $params->{createlink} || 1,
    );
    $this->assert(
        open( $save_params{stream}, '>', $Foswiki::cfg{TempfileDir} . $name ) );
    my $size = do_create_file( $save_params{stream}, $data );
    close( $save_params{stream} );
    $save_params{filesize} = $size;
    $this->assert(
        open( $save_params{stream}, '<', $Foswiki::cfg{TempfileDir} . $name ) );
    do_save_attachment( $web, $topic, $name, \%save_params );
    close( $save_params{stream} );

    return length $data;
}

sub add_attachments {
    my ( $this, $web, $topic ) = @_;

    add_attachment( $this, $web, $topic, 'blahblahblah.gif',
        "\0b\1l\2a\3h\4b\5l\6a\7h", { comment => 'Feasgar Bha' } );
    add_attachment( $this, $web, $topic, 'bleagh.sniff',
        "\0h\1a\2l\3b\4h\5a\6l\7b", { comment => 'Feasgar Bha2' } );

    return;
}

sub put_field {
    my ( $meta, $name, $attributes, $title, $value ) = @_;

    $meta->putKeyed(
        'FIELD',
        {
            name       => $name,
            attributes => $attributes,
            title      => $title,
            value      => $value
        }
    );

    return;
}

sub add_form_and_data {
    my ( $this, $web, $topic, $form ) = @_;
    my $meta = Foswiki::Meta->new( $this->{session}, $web, $topic );
    $meta->put( 'FORM', { name => $form } );
    put_field( $meta, 'IssueName', 'M', 'Issue Name', '_An issue_' );
    put_field(
        $meta, 'IssueDescription', '',
        'Issue Description',
        '---+ Example problem'
    );
    put_field( $meta, 'Issue1',       '',  'Issue 1:',      '*Defect*' );
    put_field( $meta, 'Issue2',       '',  'Issue 2:',      'Enhancement' );
    put_field( $meta, 'Issue3',       '',  'Issue 3:',      'Defect, None' );
    put_field( $meta, 'Issue4',       '',  'Issue 4:',      'Defect' );
    put_field( $meta, 'Issue5',       '',  'Issue 5:',      'Foo, Baz' );
    put_field( $meta, 'State',        'H', 'State',         'Invisible' );
    put_field( $meta, 'Anothertopic', '',  'Another topic', 'GRRR ' );
    $meta->save();

    return;
}

sub create_form_topic {
    my ( $this, $web, $topic ) = @_;
    Foswiki::Func::saveTopic( $web, $topic, undef, <<'HERE' );
| *Name*            | *Type*       | *Size* | *Values*        |
| Issue Name        | text         | 40     |                 |
| State             | radio        |        | 1, Invisible, 3 |
| Issue Description | label        | 10     | 5               |
| Issue 1           | select       |        | x, y, *Defect*  |
| Issue 2           | nuffin       |        |                 |
| Issue 3           | checkbox     |        | None, Defect, c |
| Issue 4           | textarea     |        |                 |
| Issue 5           | select+multi | 3      | Foo, Bar, Baz   |
HERE

    return;
}

#TODO: work out why some 'Use of uninitialised vars' don't crash the test (see preview)
#this verifies that the code called by default 'runs' with ASSERTs on
#which would have been enough to pick up Item2342
#and that the switchboard still works.
sub verify_switchboard_function {
    my $this = shift;

    my $testcase = 'HTMLValidation_' . $SCRIPT_NAME . '_' . $SKIN_NAME;

    create_form_topic( $this, $this->{test_web}, 'MyForm' );
    add_form_and_data( $this, $this->{test_web}, $this->{test_topic},
        'MyForm' );
    add_attachments( $this, $this->{test_web}, $this->{test_topic} );

    my ( $status, $header, $text ) =
      $this->call_UI_FN( $this->{test_web}, $this->{test_topic} );

    $this->assert_num_equals( $expected_status{$SCRIPT_NAME} || 200, $status );
    if ( $status != 302 ) {
        $this->assert( $text,
            "no body for $SCRIPT_NAME\nSTATUS: $status\nHEADER: $header" );
        $this->assert_str_not_equals( '', $text,
            "no body for $SCRIPT_NAME\nHEADER: $header" );
        try {
            $this->{tidy}->parse( $testcase, $text );
        }
        otherwise {

            #{tidy}->parse() dies ungracefully on some of the REST output.
        };

        #$this->assert_null($this->{tidy}->messages());
        my $output = join( "\n", $this->{tidy}->messages() );

        #TODO: disable missing DOCTYPE issues - we've been
        if ( defined( $expect_non_html{$SCRIPT_NAME} )
            and ( $output =~ /missing <\!DOCTYPE> declaration/ ) )
        {

            #$this->expect_failure();
            $this->annotate(
"MISSING DOCTYPE - we're returning a messy text error\n$output\n"
            );
        }
        else {
            for ($output) {    # Remove OK warnings
                               # Empty title, no easy fix and harmless
s/^$testcase \(\d+:\d+\) Warning: trimming empty <(?:h1|span)>\n?$//gm;
                s/^\s*$//;
            }
            if ( defined( $expect_table_summary_warnings{$SCRIPT_NAME} )
                and ( $output =~ /<table> lacks "summary" attribute/ ) )
            {
                for ($output) { # Remove missing table summary attribute warning
s/^$testcase \(\d+:\d+\) Warning: <table> lacks "summary" attribute\n?$//gm;
                    s/^\s*$//;
                }
            }
            my $outfile = "${testcase}_run.html";
            if ( $output eq '' ) {
                unlink $outfile;    # Remove stale output file
            }
            else {                  # save the output html..
                open( my $fh, '>', $outfile ) or die "Can't open $outfile: $!";
                print $fh $text;
                close $fh;
            }
            $this->assert_equals( '', $output,
"Script $SCRIPT_NAME, skin $SKIN_NAME gave errors, output in $outfile:\n$output"
            );
        }
    }
    else {

        #$this->assert_null($text);
    }

    #clean up messages for next run..
    $this->{tidy}->clear_messages();
    return;
}

1;
