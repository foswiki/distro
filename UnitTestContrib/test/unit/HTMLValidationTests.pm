package HTMLValidationTests;
use v5.14;

#this has been quickly copied from the UICompilation tests
#TODO: need to pick a list of topics, actions, opps's and add detection of installed skins

use Foswiki();
use Foswiki::Func();
use Foswiki::UI::View();
use HTML::Tidy();
use Try::Tiny;

use Moo;
use namespace::clean;
extends qw( FoswikiFnTestCase );

has script_name => ( is => 'rw' );
has skin_name   => ( is => 'rw' );
my %expected_status = (
    search => 302,
    save   => 302,

    # SMELL The old non-OO version was handling viewfile completely differently!
    viewfile     => 404,
    viewfileauth => 404,
);

#TODO: this is beause we're calling the UI::function, not UI:Execute - need to re-write it to use the full engine
my %expect_non_html = (
    rest         => 1,
    restauth     => 1,
    viewfile     => 1,
    viewfileauth => 1,
    register     => 1,    #TODO: missing action make it throw an exception
    manage       => 1,    #TODO: missing action make it throw an exception
    upload       => 1,    #TODO: zero size upload
    resetpasswd  => 1,
);

# Thanks to Foswiki::Form::Radio, and a default -columns attribute = 4,
# CGI::radio_group() uses HTML3 tables (missing summary attribute) for layout
# and this makes HTMLTidy cry.
my %expect_table_summary_warnings = ( edit => 1 );

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;
    return $orig->( $class, @_, testSuite => "UIFnCompile" );
};

sub BUILD {
    my $this = shift;
    $this->app->cfg->data->{EnableHierarchicalWebs} = 1;
}

around loadExtraConfig => sub {
    my $orig = shift;
    my $this = shift;

    # $this - the Test::Unit::TestCase object
    $this->app->cfg->data->{JQueryPlugin}{Plugins}{PopUpWindow}{Enabled} = 1;
    $this->app->cfg->data->{FeatureAccess}{Configure} = 'ScumBag';

    $orig->( $this, @_ );

    return;
};

has tidy => (
    is      => 'rw',
    isa     => Foswiki::Object::isaCLASS( 'tidy', 'HTML::Tidy', noUndef => 1 ),
    lazy    => 1,
    default => sub {

#see http://tidy.sourceforge.net/docs/quickref.html for parameters - be warned that some cause HTML::Tidy to crash
        return HTML::Tidy->new(
            {

                #turn off warnings until we have fixed errors
                'show-warnings' => 1,

                #'accessibility-check'	=> 3,
                'drop-empty-paras' => 0
            }
        );

    },
);

# Set up the test fixture
around set_up => sub {
    my $orig = shift;
    my $this = shift;

    #print STDERR "HTML::Tidy Version: ".$HTML::Tidy::VERSION."\n";
    #print STDERR "libtidy Version: ".HTML::Tidy::libtidy_version()."\n";

    $orig->( $this, @_ );

    #the test web is made using the '_empty' web - not so useful here
    my $webObject = $this->populateNewWeb(
        $this->test_web,
        '_default',
        {
            ALLOWWEBCHANGE => '',
            ALLOWWEBRENAME => ''
        }
    );

    return;
};

sub fixture_groups {
    my $this = shift;
    my @scripts;

    my $cfg = $this->app->cfg;

    foreach my $script ( keys( %{ $cfg->data->{SwitchBoard} } ) ) {
        next
          unless $script =~
m/^(attach|changes|compare|compareauth|configure|edit|jsonrpc|login|logon|manage|oops|preview|previewauth|rdiff|rdiffauth|register|rename|resetpasswd|rest|restauth|save|search|statistics|upload|viewauth|viewfile|viewfileauth)$/;
        push( @scripts, $script );
        next if ( defined( &{$script} ) );

        #print STDERR "defining sub $script()\n";
        my $dispatcher = $cfg->data->{SwitchBoard}{$script};
        if ( ref($dispatcher) eq 'ARRAY' ) {

            # Old-style array entry in switchboard from a plugin
            my @array = @{$dispatcher};
            $dispatcher = {
                package => $array[0],
                method  => $array[1],
                context => $array[2],
            };
        }
        next unless ( ref($dispatcher) eq 'HASH' );    #bad switchboard entry.

        my $package = $dispatcher->{package} || 'Foswiki::UI';
        my $method = $dispatcher->{method} // $dispatcher->{function};
        my $sub = $package . '::' . $method;

        $this->script_name($script);

        #print STDERR "call $sub\n";
        #if (
        #    not(
        #        eval {
        #            no strict 'refs';
        #            *{$script} = sub {
        #                Foswiki::load_package( $package, method => $sub )
        #                  if ( defined($package) );
        #                $UI_FN       = $sub;
        #                $SCRIPT_NAME = $script;
        #            };
        #            use strict 'refs';
        #            1;
        #        }
        #    )
        #  )
        #{
        #    die $@;
        #}
        try {
            no strict 'refs';
            *{$script} = sub {
                my $this = shift;
                $this->script_name($script);
            };
            use strict 'refs';
        }
        catch {
            Foswiki::Exception::Fatal->rethrow($_);
        };
    }

    my @skins;

    #TODO: detect installed skins..
    foreach my $skin (qw/default pattern plain print/) {
        push( @skins, $skin );
        next if ( defined( &{$skin} ) );

        #print STDERR "defining sub $skin()\n";
        eval {
            no strict 'refs';
            *{$skin} = sub {
                $this->skin_name($skin);
            };
            use strict 'refs';
        };
    }

    my @groups;
    push( @groups, \@scripts );
    push( @groups, \@skins );
    return @groups;
}

sub call_UI_FN {
    my ( $this, $web, $topic, $tmpl, $params ) = @_;
    my %constructor = (
        webName   => [$web],
        topicName => [$topic],
        skin      => $this->skin_name,
    );
    if ($params) {
        %constructor = ( %constructor, %{$params} );
    }

#turn off ASSERTS so we get less plain text erroring - the user should always see html
    local $ENV{FOSWIKI_ASSERTS} = 0;
    $this->createNewFoswikiApp(
        user          => $this->test_user_login,
        env           => \%ENV,
        requestParams => { initializer => \%constructor, },
        engineParams  => {
            initialAttributes => {
                path_info => "/$web/$topic",
                method    => "GET",
                action    => $this->script_name,
            },
        },
    );
    my ( $responseText, $result, $stdout, $stderr );
    $responseText = 'Status: 500';    #errr, boom
    try {
        ( $responseText, $result, $stdout, $stderr ) = $this->captureWithKey(
            $this->script_name => sub {
                return $this->app->handleRequest;
            }
        );
    }
    catch {
        my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );
        unless ( $e->isa('Foswiki::OopsException')
            || $e->isa('Foswiki::EngineException') )
        {
            Foswiki::Exception::Fatal->rethrow($e);
        }
        $responseText = $e->stringify;
    };

    $this->assert($responseText);
    $this->assert(
        defined($result),
        "Undefined return from "
          . $this->script_name
          . " script."
          . (
            $stderr
            ? " script error output:\n" . $stderr
            : ( $stdout ? " script output:\n" . $stdout : '' )
          )
    );
    $this->assert( ref($result) eq 'ARRAY',
        "Capture returned " . ( ref($result) // $result // '*undef*' ) );

    # Item11945: Foswiki now logs when bad or missing form types are used, so
    # check STDERR is only a single line & that it contains that warning
    $this->assert(
        (
            !$stderr || ( scalar( $stderr =~ m/([\r\n]+)/g ) == 1
                && $stderr =~ m/error compiling class Foswiki::Form::Nuffin/ )
        ),
        $this->script_name . " errored: '$stderr'"
    ) if defined $stderr;

    my $engine = $this->app->engine;

    my ( $header, $body ) =
      ( $engine->stringifyHeaders($result), $engine->stringifyBody($result) );

    #if ( $responseText =~ m/^(.*?)$CRLF$CRLF(.+)$/s
    #    or ( $stdout && $stdout =~ m/^(.*?)$CRLF$CRLF(.*)$/s ) )
    #{
    #
    #    # Response can be in stdout if the request is split, like for
    #    # statistics
    #    $header = $1;    # untaint is OK, it's a test
    #    $body   = $2;
    #}
    #else {
    #    $header = '';
    #    $body   = $responseText;
    #}

    return ( $result->[0], $header, $body, $stdout, $stderr );
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
        open(
            $save_params{stream}, '>',
            $this->app->cfg->data->{TempfileDir} . $name
        )
    );
    my $size = do_create_file( $save_params{stream}, $data );
    $this->assert( close( $save_params{stream} ) );
    $save_params{filesize} = $size;
    $this->assert(
        open(
            $save_params{stream}, '<',
            $this->app->cfg->data->{TempfileDir} . $name
        )
    );
    do_save_attachment( $web, $topic, $name, \%save_params );
    $this->assert( close( $save_params{stream} ) );

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
    my ( $meta, $name, $title, $value ) = @_;

    $meta->putKeyed(
        'FIELD',
        {
            name  => $name,
            title => $title,
            value => $value
        }
    );

    return;
}

sub add_form_and_data {
    my ( $this, $web, $topic, $form ) = @_;
    my ($meta) = Foswiki::Func::readTopic( $web, $topic );
    $meta->put( 'FORM', { name => $form } );
    put_field( $meta, 'IssueName', 'Issue Name', '_An issue_' );
    put_field(
        $meta, 'IssueDescription', '',
        'Issue Description',
        '---+ Example problem'
    );
    put_field( $meta, 'Issue1',       'Issue 1:',      '*Defect*' );
    put_field( $meta, 'Issue2',       'Issue 2:',      'Enhancement' );
    put_field( $meta, 'Issue3',       'Issue 3:',      'Defect, None' );
    put_field( $meta, 'Issue4',       'Issue 4:',      'Defect' );
    put_field( $meta, 'Issue5',       'Issue 5:',      'Foo, Baz' );
    put_field( $meta, 'State',        'State',         'Invisible' );
    put_field( $meta, 'Anothertopic', 'Another topic', 'GRRR ' );
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

    my $SCRIPT_NAME = $this->script_name;
    my $SKIN_NAME   = $this->skin_name;
    my $testcase    = 'HTMLValidation_' . $SCRIPT_NAME . '_' . $SKIN_NAME;

    create_form_topic( $this, $this->test_web, 'MyForm' );
    add_form_and_data( $this, $this->test_web, $this->test_topic, 'MyForm' );
    add_attachments( $this, $this->test_web, $this->test_topic );

    my ( $status, $header, $text ) =
      $this->call_UI_FN( $this->test_web, $this->test_topic );

    unless ( $header =~ m/Content-type: text\/html\b/i ) {

        # non-HTML script, no HTML to validate
        $this->tidy->clear_messages();
        return;
    }

    $this->assert_num_equals( $expected_status{ $this->script_name } || 200,
        $status );
    if ( $status != 302 ) {
        $this->assert_num_not_equals( 500, $status,
            'exception thrown, or status not set properly' );
        $this->assert( $text,
            "no body for $SCRIPT_NAME\nSTATUS: $status\nHEADER: $header" );
        $this->assert_str_not_equals( '', $text,
            "no body for $SCRIPT_NAME\nHEADER: $header" );
        try {
            $this->tidy->parse( $testcase, $text );
        }
        catch {

            #{tidy}->parse() dies ungracefully on some of the REST output.
        };

        #$this->assert_null($this->tidy->messages());
        my $output = join( "\n", $this->tidy->messages() );

        #TODO: disable missing DOCTYPE issues - we've been
        if ( defined( $expect_non_html{$SCRIPT_NAME} )
            and ( $output =~ m/missing <\!DOCTYPE> declaration/ ) )
        {

            #$this->expect_failure();
            $this->annotate(
"MISSING DOCTYPE - we're returning a messy text error\n$output\n"
            );
        }
        else {
            my $warn = qr/$testcase \(\d+:\d+\) Warning:/;
            for ($output) {

                # Remove OK warnings
                # Empty title, no easy fix and harmless
                # Empty style, see Item11608
s/^$warn trimming empty <(?:h1|span|style|ins|noscript)>\n?$//gm;
                s/^$warn inserting implicit <(?:ins)>\n?$//gm;

                # Remove warnings about HTML5 not being covered by
                # HTML::Tidy properly, see Item13134
                s/^$warn <a> proprietary attribute "data-.*$//gm;
                s/^$warn <textarea> proprietary attribute "data-.*$//gm;
                s/^$warn <input> proprietary attribute "placeholder".*$//gm;
                s/^$warn <meta> proprietary attribute "charset".*$//gm;
                s/^$warn <meta> lacks "content" attribute.*$//gm;
                s/^$warn <[^>]+> proprietary attribute "class".*$//gm;

                # These elements are no longer suppported in HTML5
                s/^$warn <table> lacks "summary" attribute$//gm;

                if ($Foswiki::UNICODE) {

                    # With unicode core, links may include unicode
                    # characters that *should* be url-encoded, but
                    # often are not (though it's not seen as an
                    # error by modern browsers)
                    s/^$warn <a> escaping malformed.*$//gm;
                }
                s/^\s*$//s;
            }

            if ( defined( $expect_table_summary_warnings{$SCRIPT_NAME} )
                and ( $output =~ m/<table> lacks "summary" attribute/ ) )
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
                print $fh Encode::encode_utf8($text);
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
    $this->tidy->clear_messages();
    return;
}

# assert bool($got) == bool($expected) with $message and return true if true
sub expected_in_scan {
    my ( $this, $expected, $got, $message ) = @_;
    my $_got      = 0;
    my $_expected = 0;

    if ($got) {
        $_got = 1;
    }
    if ( $expected or not( defined $expected ) ) {
        $_expected = 1;
    }
    if ( $_expected != $_got ) {
        my $sensestr;
        if ($_expected) {
            $sensestr = 'Expected ';
        }
        else {
            $sensestr = 'Did not expect ';
        }
        $this->assert_equals( $_expected, $_got, $sensestr . $message );
    }

    return ( $_expected == $_got );
}

# Scan for a checked $value belonging to an <input> with $name
# Return true if found and success was expected
# or true if not found and absence was expected
# Asserts an <input of $name with $value exists unless $expected->{input} false
# Asserts the <input is checked unless $expected->{checked} is false
sub scan_for_checked {
    my ( $this, $text, $name, $value, $expected ) = @_;
    my $fragment;
    my $checked;
    my $success = 0;

    # The construction \Q${variable}\E matches a literal string, preventing
    # special characters being interpreted as part of the regex
    ($fragment) =
      ( $text =~
m/<input([^>]*?(name|id)=['"]$name['"][^>]*?value=['"]\Q${value}\E['"][^>]*?)\/>/
      );
    $success =
      $success +
      $this->expected_in_scan( $expected->{input}, $fragment,
        "to find <input (name|id)='$name' with value '$value'" );
    ($checked) = ( $fragment =~ m/checked=[\'"]checked[\'"]/ );
    $success =
      $success +
      $this->expected_in_scan( $expected->{checked}, $checked,
        "to find <input (name|id)='$name' with checked value '$value'" );

    return ( $success == 2 );
}

# Scan for a selected $option belonging to a <select with $name
# Return true if found and success was expected
# or true if not found and absence was expected
# Asserts a <select exists with $name unless $expected->{select} is false
# Asserts contains an <option with $option unless $expected->{option} is false
# Asserts <option is selected unless $expected->{selected} is false
sub scan_for_selected {
    my ( $this, $text, $name, $option, $expected ) = @_;
    my $fragment;
    my $success = 0;
    my $optattributes;

    # The construction \Q${variable}\E matches a literal string, preventing
    # special characters being interpreted as part of the regex
    ( undef, $fragment ) = ( $text =~
          m/<select[^>]*?(name|id)=['"]\Q${name}\E['"][^>]*?>(.*?)<\/select>/ );
    $success =
      $success +
      $this->expected_in_scan( $expected->{select}, $fragment,
        "to find <select (name|id)='$name'" );

    # Match contents of the option markup
    ($optattributes) =
      ( $fragment =~ m/<option([^>]*?)>\s*\Q${option}\E\s*<\/option>/ );
    if ( not $optattributes ) {

        # Otherwise match a 'forced' value attribute
        ($optattributes) =
          ( $fragment =~
m/<option([^>]*?value=[\'"]\Q${option}\E[\'"][^>]*?)>[^<]*?<\/option>/
          );
    }
    $success =
      $success +
      $this->expected_in_scan( $expected->{option}, $optattributes,
        "to find <select (name|id)='$name' with <option '$option'" );
    my $selected;
    if ( $optattributes =~ m/selected=[\'"]selected[\'"]/ ) {
        $selected = 1;
    }
    else {
        $selected = 0;
    }
    $success =
      $success +
      $this->expected_in_scan( $expected->{selected}, $selected,
        "to find <select (name|id)='$name' with selected <option '$option'" );

    return ( $success == 3 );
}

# Testing multivalue items present in the test topic's dataform
sub test_edit_without_urlparam_presets {
    my ($this) = @_;

    require Foswiki::UI::Edit;
    $this->script_name('edit');
    $this->skin_name('default');

    create_form_topic( $this, $this->test_web, 'MyForm' );
    add_form_and_data( $this, $this->test_web, $this->test_topic, 'MyForm' );

    my ( $status, $header, $text ) =
      $this->call_UI_FN( $this->test_web, $this->test_topic );
    $this->assert_num_not_equals( 500, $status,
        'exception thrown, or status not set properly' );
    my $notchecked  = { checked  => 0 };
    my $notselected = { selected => 0 };

    $this->assert( $this->scan_for_checked( $text, 'State', 'Invisible' ) );
    $this->assert(
        $this->scan_for_checked( $text, 'State', '1', $notchecked ) );
    $this->assert(
        $this->scan_for_checked( $text, 'State', '3', $notchecked ) );
    $this->assert( $this->scan_for_selected( $text, 'Issue1', '*Defect*' ) );
    $this->assert(
        $this->scan_for_selected( $text, 'Issue1', 'x', $notselected ) );
    $this->assert(
        $this->scan_for_selected( $text, 'Issue1', 'y', $notselected ) );
    $this->assert(
        $this->scan_for_checked( $text, 'Issue3', 'c', $notchecked ) );
    $this->assert( $this->scan_for_checked( $text, 'Issue3', 'Defect' ) );
    $this->assert( $this->scan_for_checked( $text, 'Issue3', 'None' ) );
    $this->assert( $this->scan_for_selected( $text, 'Issue5', 'Foo' ) );
    $this->assert( $this->scan_for_selected( $text, 'Issue5', 'Baz' ) );
    $this->assert(
        $this->scan_for_selected( $text, 'Issue5', 'Bar', $notselected ) );

    return;
}

# SMELL: This test created because a fix to Item9007 in Foswiki::Form::Checkbox
# lost us the ability to set checkbox values from url parameters. However, this
# test still passed against the faulty code, where a real web browser
# demonstrated the fault...
sub test_edit_with_urlparam_presets {
    my ($this) = @_;

    $this->script_name('edit');
    $this->skin_name('default');

    $this->create_form_topic( $this->test_web, 'MyForm' );
    $this->add_form_and_data( $this->test_web, $this->test_topic, 'MyForm' );

    my ( $status, $header, $text ) = $this->call_UI_FN(
        $this->test_web,
        $this->test_topic,
        undef,
        { Issue3 => ['c'], State => ['1'], Issue1 => ['y'], Issue5 => ['Bar'] }
    );
    $this->assert_num_not_equals( 500, $status,
        'exception thrown, or status not set properly' );

    my $notchecked  = { checked  => 0 };
    my $notselected = { selected => 0 };

    $this->assert(
        $this->scan_for_checked( $text, 'State', 'Invisible', $notchecked ) );
    $this->assert( $this->scan_for_checked( $text, 'State', '1' ) );
    $this->assert(
        $this->scan_for_checked( $text, 'State', '3', $notchecked ) );
    $this->assert(
        $this->scan_for_selected( $text, 'Issue1', '*Defect*', $notselected ) );
    $this->assert(
        $this->scan_for_selected( $text, 'Issue1', 'x', $notselected ) );
    $this->assert( $this->scan_for_selected( $text, 'Issue1', 'y' ) );
    $this->assert( $this->scan_for_checked( $text, 'Issue3', 'c' ) );
    $this->assert(
        $this->scan_for_checked( $text, 'Issue3', 'Defect', $notchecked ) );
    $this->assert(
        $this->scan_for_checked( $text, 'Issue3', 'None', $notchecked ) );
    $this->assert(
        $this->scan_for_selected( $text, 'Issue5', 'Foo', $notselected ) );
    $this->assert(
        $this->scan_for_selected( $text, 'Issue5', 'Baz', $notselected ) );
    $this->assert( $this->scan_for_selected( $text, 'Issue5', 'Bar' ) );

    return;
}

1;
