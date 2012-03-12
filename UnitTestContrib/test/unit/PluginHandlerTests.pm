# Authors: Crawford Currie http://wikiring.com
#
# Make sure that all the right plugin handlers are called in the
# right places with the right parameters.
#
# We do this by actually writing a valid plugin implementation to the
# plugins area in the code, and removing it again when we are done. Each
# bespoke plugin has specialised handlers designed to interact with this
# test.
#
# The handlers that are not currently tested are represented in the code
# below using a function called "test_<handlername>". If you are going
# to write a test for the handler, rename it to "test_<handlername>" and
# start coding....
#
package PluginHandlerTests;
use strict;
use warnings;
use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use Foswiki();
use Error qw( :try );
use Foswiki::Func();
use Foswiki::Plugin();
use Symbol qw(delete_package);

my $systemWeb = "TemporaryPluginHandlersSystemWeb";

sub new {
    my ( $class, @args ) = @_;

    return $class->SUPER::new( "PluginHandlers", @args );
}

# Set up the test fixture.
sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    my $testWebObject = $this->populateNewWeb( $this->{test_web} );
    $testWebObject->finish();

    # Disable all plugins
    foreach my $key ( keys %{ $Foswiki::cfg{Plugins} } ) {
        next unless ref( $Foswiki::cfg{Plugins}{$key} ) eq 'HASH';
        $Foswiki::cfg{Plugins}{$key}{Enabled} = 0;
    }

    # Locate the code
    my $found;
    foreach my $inc (@INC) {
        if ( -e "$inc/Foswiki/Plugins/EmptyPlugin.pm" ) {

            # Found it
            $found = $inc;
            last;
        }
    }
    die "Can't find code" unless $found;
    $this->{code_root} = "$found/Foswiki/Plugins/";
    my $webObject =
      $this->populateNewWeb( $systemWeb, $Foswiki::cfg{SystemWebName} );
    $webObject->finish();
    $Foswiki::cfg{SystemWebName} = $systemWeb;
    $Foswiki::cfg{Plugins}{WebSearchPath} = $systemWeb;

    return;
}

sub tear_down {
    my $this = shift;

    $this->removeWebFixture( $this->{session}, $systemWeb );
    unlink( $this->{plugin_pm} );
    Symbol::delete_package("Foswiki::Foswiki::$this->{plugin_name}");
    $this->SUPER::tear_down();

    return;
}

# Build the plugin source, using the code passed in $code as the
# body of the plugin. $code will normally be at least one handler
# implementation, sometimes more than one.
sub makePlugin {
    my ( $this, $test, $code ) = @_;

    $this->{plugin_name} = ucfirst("${test}Plugin");
    $this->{plugin_pm}   = $this->{code_root} . $this->{plugin_name} . ".pm";

    $code = <<"HERE";
package Foswiki::Plugins::$this->{plugin_name};

use vars qw( \$called \$tester \$VERSION );
\$called = {};
\$VERSION = 999.911;

sub initPlugin {
    \$called->{initPlugin}++;
    return 1;
}
# line 11
$code
1;
HERE

# Dump the handler code with line numbers
# To help with debugging failures in the plugin handlers
#    my @tempCode = split /\n/, $code;
#    my $codeCount = 1;
#    foreach my $codeLine ( @tempCode ) {
#        print "$codeCount: $codeLine\n";
#        $codeCount++;
#    }

    $this->assert(
        open( my $F, ">$this->{plugin_pm}" ),
        "Failed to open $this->{plugin_pm}: $!"
    );
    print $F $code;
    $this->assert( close($F) );
    try {
        my ($topicObject) =
          Foswiki::Func::readTopic( $Foswiki::cfg{SystemWebName},
            $this->{plugin_name} );
        $topicObject->text(<<'EOF');
   * Set PLUGINVAR = Blah
EOF
        $topicObject->save();
        $topicObject->finish();
    }
    catch Foswiki::AccessControlException with {
        $this->assert( 0, shift->stringify() );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() );
    };
    $Foswiki::cfg{Plugins}{ $this->{plugin_name} }{Enabled} = 1;
    $Foswiki::cfg{Plugins}{ $this->{plugin_name} }{Module} =
      "Foswiki::Plugins::$this->{plugin_name}";
    $this->createNewFoswikiSession();    # default user
    eval "\$Foswiki::Plugins::$this->{plugin_name}::tester = \$this;";
    $this->checkCalls( 1, 'initPlugin' );

    return;
}

sub checkCalls {
    my ( $this, $number, $name ) = @_;
    my $saw =
      eval "\$Foswiki::Plugins::$this->{plugin_name}::called->{$name} || 0";
    $this->assert_equals( $number, $saw,
        "calls($name) $saw != $number " . join( ' ', caller ) );

    return;
}

sub test_saveHandlers {
    my $this = shift;

    my $user = $this->{session}->{user};
    $this->assert_not_null($user);
    my ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, 'Tropic' );
    my $text = $topicObject->text() || '';
    $text =~ s/^\s*\* Set BLAH =.*$//gm;
    $text .= "\n\t* Set BLAH = BEFORE\n";
    $text .= "\nNOCALL\n";
    $topicObject->text($text);
    try {
        $topicObject->save();
    }
    catch Foswiki::AccessControlException with {
        $this->assert( 0, shift->stringify() );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() || '' );
    };
    $topicObject->finish();

    my $q = Foswiki::Func::getRequestObject();
    $this->createNewFoswikiSession( $Foswiki::cfg{GuestUserLogin}, $q );

    $this->makePlugin( 'saveHandlers', <<'HERE');
sub beforeSaveHandler {
    #my( $text, $topic, $theWeb, $meta ) = @_;
    # ensure we have a loaded rev
    $tester->assert($_[3]->getLoadedRev());
     $tester->assert_str_equals('Tropic', $_[1], "TWO $_[1]");
    $tester->assert_str_equals($tester->{test_web}, $_[2], "THREE $_[2]");
    $tester->assert($_[3]->isa('Foswiki::Meta'), "FOUR $_[3]");
    $tester->assert_str_equals('Wibble', $_[3]->get('WIBBLE')->{wibble});
    Foswiki::Func::pushTopicContext( $this->{test_web}, 'Tropic' );
    $tester->assert_str_equals( "BEFORE",
            $_[3]->getPreference("BLAH"));
            #Foswiki::Func::getPreferencesValue("BLAH") );
    $_[0] =~ s/NOCALL/B4SAVE/g;
    $_[0] =~ s/BEFORE/AFTER/g;
    $called->{beforeSaveHandler}++;
}
sub afterSaveHandler {
    #my( $text, $topic, $theWeb, $error, $meta ) = @_;
    $tester->assert_str_equals('Tropic', $_[1]);
    $tester->assert_str_equals($tester->{test_web}, $_[2]);
    $tester->assert_null($_[3]);
    $tester->assert($_[4]->isa('Foswiki::Meta'), "OUCH $_[4]");
    # ensure we have a loaded rev
    $tester->assert($_[4]->getLoadedRev());
    $tester->assert_str_equals('Wibble', $_[4]->get('WIBBLE')->{wibble});
    $tester->assert_matches( qr/B4SAVE/, $_[0]);

    $tester->assert_str_equals( "AFTER",
            $_[4]->getPreference("BLAH"));

    #SMELL:  And for some reason this returns null instead of either BEFORE or AFTER
    # Foswiki::Func::pushTopicContext( $this->{test_web}, 'Tropic' );
    # $tester->assert_str_equals( "AFTER",
    #  Foswiki::Func::getPreferencesValue("BLAH") );

    $called->{afterSaveHandler}++;
}
HERE

# Test to ensure that the before and after save handlers are both called,
# and that modifications made to the text are actaully written to the topic file
    my ($meta) = Foswiki::Func::readTopic( $this->{test_web}, "Tropic" );
    $meta->text($text);

    # Crawford changed from Meta->load to Meta->new (above) in Foswikirev:13781;
    # so I'm holding off on eradicating the above Foswiki::Meta usage until I
    # better understand why
    # my ($meta) = Foswiki::Func::readTopic( $this->{test_web}, "Tropic" );
    $meta->put( 'WIBBLE', { wibble => 'Wibble' } );
    $meta->save();
    $meta->finish();
    $this->checkCalls( 1, 'beforeSaveHandler' );
    $this->checkCalls( 1, 'afterSaveHandler' );

    my ($newMeta) = Foswiki::Func::readTopic( $this->{test_web}, "Tropic" );
    $this->assert_matches( qr\B4SAVE\, $newMeta->text() );
    $this->assert_str_equals( 'Wibble', $newMeta->get('WIBBLE')->{wibble} );
    $this->assert_str_equals( "AFTER",  $newMeta->getPreference("BLAH") );
    $newMeta->finish();

    #SMELL: Without this call, getPreferences returns BEFORE
    Foswiki::Func::pushTopicContext( $this->{test_web}, 'Tropic' );

    $this->assert_str_equals( "AFTER",
        Foswiki::Func::getPreferencesValue("BLAH") );

    return;
}

#  Verify that verbatim blocks are removed in both the including and included topics.
sub test_commonTagsHandlersINCLUDE {
    my $this = shift;
    $this->makePlugin( 'commonTagsHandlersINCLUDE', <<'HERE');
sub beforeCommonTagsHandler {
    #my( $text, $topic, $theWeb, $meta ) = @_;
    if ( $_[1] eq 'IncludedTopic') {
        $tester->assert_matches(qr/<verbatim>/, $_[0], "ONE $_[0]");
    }
    else {
        $tester->assert_matches(qr/Zero%INCLUDE/, $_[0], "ONE $_[0]");
    }
    $tester->assert_matches(qr/(Tropic|IncludedTopic)/, $_[1], "TWO $_[1]");
    $tester->assert($_[3]->isa('Foswiki::Meta'), "FOUR $_[3]");
    $_[0] =~ s/Zero/One/g;
    $called->{beforeCommonTagsHandler}++;
}
sub commonTagsHandler {
    #my( $text, $topic, $theWeb, $included, $meta ) = @_;
    if ( $_[1] eq 'Tropic') {
        $tester->assert_matches(qr/One/, $_[0]);
        $tester->assert( !$_[3] );
    }
    else {
        $tester->assert_does_not_match( qr/BOO/, $_[0]);
        $tester->assert( $_[3] );
    }
    $tester->assert_does_not_match(qr/<verbatim>/, $_[0] );
    $tester->assert_matches(qr/(Tropic|IncludedTopic)/, $_[1], "TWO $_[1]");
    $tester->assert($_[4]->isa('Foswiki::Meta'), "OUCH $_[4]");
    $_[0] =~ s/One/Two/g;
    $called->{commonTagsHandler}++;
}
sub afterCommonTagsHandler {
    #my( $text, $topic, $theWeb, $meta ) = @_;
    $tester->assert_matches(qr/(Tropic|IncludedTopic)/, $_[1], "TWO $_[1]");
    #$tester->assert_str_equals('Werb', $_[2]);
    $tester->assert($_[3]->isa('Foswiki::Meta'));
    $tester->assert_matches( qr/Two/, $_[0]);
    $called->{afterCommonTagsHandler}++;
}
HERE

    # Crude test to ensure all handlers are called, and in the right order.
    # Doesn't verify that they are called at the right time
    Foswiki::Func::saveTopic( $this->{test_web}, 'IncludedTopic', undef,
        '<verbatim>BOO</verbatim>' );
    my ($meta) = Foswiki::Func::readTopic( "Werb", "Tropic" );
    $meta->put( 'WIBBLE', { wibble => 'Wibble' } );
    my $expanded = Foswiki::Func::expandCommonVariables(
        "Zero%INCLUDE{\"$this->{test_web}.IncludedTopic\"}%",
        "Tropic", "Werb", $meta );
    $this->assert_str_equals( $expanded, "Two<verbatim>BOO</verbatim>" );
    $meta->finish();
    $this->checkCalls( 1, 'beforeCommonTagsHandler' );
    $this->checkCalls( 2, 'commonTagsHandler' );
    $this->checkCalls( 1, 'afterCommonTagsHandler' );

    return;
}

sub test_commonTagsHandlers {
    my $this = shift;
    $this->makePlugin( 'commonTagsHandlers', <<'HERE');
sub beforeCommonTagsHandler {
    #my( $text, $topic, $theWeb, $meta ) = @_;
    $tester->assert_str_equals('Zero<verbatim>blah</verbatim>', $_[0], "ONE $_[0]");
    $tester->assert_str_equals('Tropic', $_[1], "TWO $_[1]");
    $tester->assert_str_equals('Werb', $_[2], "THREE $_[2]");
    $tester->assert($_[3]->isa('Foswiki::Meta'), "FOUR $_[3]");
    $tester->assert_str_equals('Wibble', $_[3]->get('WIBBLE')->{wibble});
    $_[0] =~ s/Zero/One/g;
    $called->{beforeCommonTagsHandler}++;
}
sub commonTagsHandler {
    #my( $text, $topic, $theWeb, $included, $meta ) = @_;
    $tester->assert_matches('One', $_[0]);
    $tester->assert_does_not_match(qr/<verbatim>/, $_[0] );
    $tester->assert_str_equals('Tropic', $_[1]);
    $tester->assert_str_equals('Werb', $_[2]);
    $tester->assert($_[4]->isa('Foswiki::Meta'), "OUCH $_[4]");
    $tester->assert_str_equals('Wibble', $_[4]->get('WIBBLE')->{wibble});
    $_[0] =~ s/One/Two/g;
    $called->{commonTagsHandler}++;
}
sub afterCommonTagsHandler {
    #my( $text, $topic, $theWeb, $meta ) = @_;
    $tester->assert_str_equals('Two<verbatim>blah</verbatim>', $_[0]);
    $tester->assert_str_equals('Tropic', $_[1]);
    $tester->assert_str_equals('Werb', $_[2]);
    $tester->assert($_[3]->isa('Foswiki::Meta'));
    $tester->assert_str_equals('Wibble', $_[3]->get('WIBBLE')->{wibble});
    $_[0] = 'Zero';
    $called->{afterCommonTagsHandler}++;
}
HERE

    # Crude test to ensure all handlers are called, and in the right order.
    # Doesn't verify that they are called at the right time
    my ($meta) = Foswiki::Func::readTopic( "Werb", "Tropic" );
    $meta->put( 'WIBBLE', { wibble => 'Wibble' } );
    Foswiki::Func::expandCommonVariables( "Zero<verbatim>blah</verbatim>",
        "Tropic", "Werb", $meta );
    $meta->finish();
    $this->checkCalls( 1, 'beforeCommonTagsHandler' );
    $this->checkCalls( 1, 'commonTagsHandler' );
    $this->checkCalls( 1, 'afterCommonTagsHandler' );

    return;
}

sub test_earlyInit {
    my $this = shift;
    $this->makePlugin( 'earlyInitPlugin', <<'HERE');
sub earlyInitPlugin {
    # $tester not set up yet
    die "EIP $called->{earlyInitPlugin}" if  $called->{earlyInitPlugin};
    die "IP $called->{initPlugin}" if $called->{initPlugin};
    die "IUH $called->{initializeUserHandler}" if $called->{initializeUserHandler};
    $called->{earlyInitPlugin}++;
}

sub initializeUserHandler {
    # $tester not set up yet
    die "$called->{earlyInitPlugin}" unless $called->{earlyInitPlugin};
    die "$called->{initPlugin}" unless !$called->{initPlugin};
    die "$called->{initializeUserHandler}" unless !$called->{initializeUserHandler};
    $called->{initializeUserHandler}++;
    my $ru = $_[0] || 'undef';
    die "RU $ru" unless $ru eq ($Foswiki::Plugins::SESSION->{remoteUser}||'undef');
    my $url = $_[1] || 'undef';
    die "URL $url" unless $url eq (Foswiki::Func::getCgiQuery()->url() || undef);
    my $path = $_[2] || 'undef';
    die "PATH $path" unless $path eq (Foswiki::Func::getCgiQuery->path_info() || 'undef');
}
HERE
    $this->checkCalls( 1, 'earlyInitPlugin' );
    $this->checkCalls( 1, 'initPlugin' );
    $this->checkCalls( 1, 'initializeUserHandler' );

    return;
}

# Test that the rendering handlers are called in the correct sequence.
# The sequence is:
# 1 startRenderingHandler
# 2 preRenderingHandler
# -*- insidePreHandler and outsidePreHandler -*-
# 3 endRenderingHandler
# 4 postRenderingHandler
# Each handler checks its params and the state of the text, and prepends
# an id to the text to say its been called and make sure that text can be
# written.
use vars qw( @oprelines @iprelines );

sub test_renderingHandlers {
    my $this = shift;
    $this->makePlugin( 'renderingHandlers', <<'HERE');
# Called after verbatim, literal, head, textareas, script have
# all been removed, but *before* PRE is removed
sub startRenderingHandler {
    my ($text, $web, $topic ) = @_;
    $called->{startRenderingHandler}++;
    $tester->assert_str_equals("Gruntfos", $_[1]);
    $tester->assert_str_equals("WebHome", $_[2]);
    $text =~ s/\d+${Foswiki::TranslationToken}--/NUMBERx--/g;
    $text =~ s/${Foswiki::TranslationToken}/x/g;
    $tester->assert_str_equals(<<INNER, $text);
<!--xliteralNUMBERx-->
<!--xverbatimNUMBERx-->
<pre>
PRE
</pre>
<!--xheadNUMBERx-->
<!--xscriptNUMBERx-->
<!--xtextareaNUMBERx-->
<nop>
INNER
   $_[0] = "startRenderingHandler\n".$_[0];
}
# Called after all blocks have been removed
sub preRenderingHandler {
    my ($text, $removed ) = @_;
    $called->{preRenderingHandler}++;
    $text =~ s/\d+${Foswiki::TranslationToken}--/NUMBERx--/g;
    $text =~ s/${Foswiki::TranslationToken}/x/g;
    $tester->assert_str_equals(<<INNER, $text);
startRenderingHandler
<!--xliteralNUMBERx-->
<!--xverbatimNUMBERx-->
<!--xpreNUMBERx-->
<!--xheadNUMBERx-->
<!--xscriptNUMBERx-->
<!--xtextareaNUMBERx-->
<nop>
INNER
    # Check the removed blocks (which have unpredictable numbers, as the
    # keys are generated when they are added to the removed hash)
    foreach my $k ( keys %{$removed} ) {
        if ($k =~ /^literal/) {
            $tester->assert_str_equals("\nLITERAL\n", $removed->{$k}{'text'});
        } elsif ($k =~ /^verbatim/) {
            $tester->assert_str_equals("\nVERBATIM\n", $removed->{$k}{'text'});
        } elsif ($k =~ /^pre/) {
            $tester->assert_str_equals("\nPRE\n", $removed->{$k}{'text'});
        } elsif ($k =~ /^head/) {
            $tester->assert_str_equals("<head>\nHEAD\n</head>",
                 $removed->{$k}{'text'});
        } elsif ($k =~ /^script/) {
            $tester->assert_str_equals("<script>\nSCRIPT\n</script>",
                 $removed->{$k}{'text'});
        } elsif ($k =~ /^textarea/) {
            $tester->assert_str_equals("<textarea>\nTEXTAREA\n</textarea>",
                  $removed->{$k}{'text'});
        }
    }
    $_[0] = "preRenderingHandler\n$_[0]";
}

# Called after PRE blocks have been re-inserted, but *before* any other block
# types have been reinserted (so markers are still present)
sub endRenderingHandler {
    my ( $text ) = @_;
    $text =~ s/^\n//s;
    $text =~ s/\d+${Foswiki::TranslationToken}--/NUMBERx--/g;
    $text =~ s/${Foswiki::TranslationToken}/x/g;
    $tester->assert_str_equals(<<INNER, $text);
preRenderingHandler
startRenderingHandler
<!--xliteralNUMBERx-->
<!--xverbatimNUMBERx-->
<pre>
PRE
</pre>
<!--xheadNUMBERx-->
<!--xscriptNUMBERx-->
<!--xtextareaNUMBERx-->
<nop>
INNER
    $called->{endRenderingHandler}++;
    $_[0] = "endRenderingHandler\n$_[0]";
}

# Called after all blocks have been re-inserted
sub postRenderingHandler {
    my ($text) = @_;
    $tester->assert_str_equals(<<INNER, "$text\n");
endRenderingHandler
preRenderingHandler
startRenderingHandler

LITERAL

<pre>
VERBATIM
</pre>
<pre>
PRE
</pre>
<head>
HEAD
</head>
<script>
SCRIPT
</script>
<textarea>
TEXTAREA
</textarea>
INNER
    $called->{postRenderingHandler}++;
    $_[0] = "postRenderingHandler\n$_[0]";
}

# Should only be called on one line
sub insidePREHandler {
    my( $text ) = @_;
    $text =~ s/\d+${Foswiki::TranslationToken}--/NUMBERx--/g;
    $text =~ s/${Foswiki::TranslationToken}/x/g;
    push(@PluginHandlerTests::iprelines, $text);
    $called->{insidePREHandler}++;
}

# Should be called on every line that the inside handler is *not*
# called on
sub outsidePREHandler {
    my( $text ) = @_;
    $text =~ s/\d+${Foswiki::TranslationToken}--/NUMBERx--/g;
    $text =~ s/${Foswiki::TranslationToken}/x/g;
    push(@PluginHandlerTests::oprelines, $text);
    $called->{outsidePREHandler}++;
}
HERE
    my $text = <<'HERE';
<literal>
LITERAL
</literal>
<verbatim>
VERBATIM
</verbatim>
<pre>
PRE
</pre>
<head>
HEAD
</head>
<script>
SCRIPT
</script>
<textarea>
TEXTAREA
</textarea>
HERE
    @oprelines = ();
    @iprelines = ();
    my $out = Foswiki::Func::renderText( $text, "Gruntfos" ) . "\n";
    $this->assert_str_equals( <<'HERE', $out );
postRenderingHandler
endRenderingHandler
preRenderingHandler
startRenderingHandler

LITERAL

<pre>
VERBATIM
</pre>
<pre>
PRE
</pre>
<head>
HEAD
</head>
<script>
SCRIPT
</script>
<textarea>
TEXTAREA
</textarea>
HERE
    $this->assert_str_equals( '',                        $iprelines[0] );
    $this->assert_str_equals( 'PRE',                     $iprelines[1] );
    $this->assert_str_equals( 'preRenderingHandler',     $oprelines[0] );
    $this->assert_str_equals( 'startRenderingHandler',   $oprelines[1] );
    $this->assert_str_equals( '<!--xliteralNUMBERx-->',  $oprelines[2] );
    $this->assert_str_equals( '<!--xverbatimNUMBERx-->', $oprelines[3] );
    $this->assert_str_equals( '<!--xpreNUMBERx-->',      $oprelines[4] );
    $this->assert_str_equals( '<!--xheadNUMBERx-->',     $oprelines[5] );
    $this->assert_str_equals( '<!--xscriptNUMBERx-->',   $oprelines[6] );
    $this->assert_str_equals( '<!--xtextareaNUMBERx-->', $oprelines[7] );
    $this->assert_str_equals( '<nop>',                   $oprelines[8] );
    $this->checkCalls( 1, 'preRenderingHandler' );
    $this->checkCalls( 1, 'startRenderingHandler' );
    $this->checkCalls( 1, 'endRenderingHandler' );
    $this->checkCalls( 1, 'postRenderingHandler' );

    return;
}

sub test_afterAttachmentSaveHandler {
    my $this = shift;
    $this->makePlugin( 'afterAttachmentSaveHandler', <<'HERE');
sub afterAttachmentSaveHandler {
    my ($attachmentAttrHash, $topic, $web, $error) = @_;
    $called->{afterAttachmentSaveHandler}++;
}
HERE

    return;
}

sub test_afterUploadHandler {
    my $this = shift;
    $this->makePlugin( 'afterUploadHandler', <<'HERE');
sub afterUploadHandler {
    my ($attachmentAttrHash, $meta) = @_;
    # ensure we have a loaded rev
    $tester->assert($meta->getLoadedRev());
    $called->{afterUploadHandler}++;
}
HERE

    return;
}

sub test_afterEditHandler {
    my $this = shift;
    $this->makePlugin( 'afterEditHandler', <<'HERE');
sub afterEditHandler {
    my( $text, $topic, $web ) = @_;
    $called->{afterEditHandler}++;
}
HERE

    return;
}

sub test_afterRenameHandler {
    my $this = shift;
    $this->makePlugin( 'afterRenameHandler', <<'HERE');
sub afterRenameHandler {
    my ($oldWeb, $oldTopic, $oldAttachment, $newWeb,
        $newTopic, $newAttachment) = @_;
    $called->{afterRenameHandler}++;
}
HERE

    return;
}

sub test_beforeAttachmentSaveHandler {
    my $this = shift;
    $this->makePlugin( 'beforeAttachmentSaveHandler', <<'HERE');
sub beforeAttachmentSaveHandler {
    my( $attrHashRef, $topic, $web ) = @_;
    $called->{beforeAttachmentSaveHandler}++;
}
HERE

    return;
}

sub test_beforeUploadHandler {
    my $this = shift;
    $this->makePlugin( 'beforeUploadHandler', <<'HERE');
sub beforeUploadHandler {
    my( $attrHashRef, $meta ) = @_;
    # ensure we have a loaded rev
    $tester->assert($meta->getLoadedRev());
    $called->{beforeUploadHandler}++;
}
HERE

    return;
}

sub test_beforeEditHandler {
    my $this = shift;
    $this->makePlugin( 'beforeEditHandler', <<'HERE');
sub beforeEditHandler {
    my( $text, $topic, $web, $meta ) = @_;
    $called->{beforeEditHandler}++;
}
HERE

    return;
}

sub test_modifyHeaderHandler {
    my $this = shift;
    $this->makePlugin( 'modifyHeaderHandler', <<'HERE');
sub modifyHeaderHandler {
    my ($headers, $query) = @_;
    $called->{modifyHeaderHandler}++;
}
HERE

    return;
}

sub test_mergeHandler {
    my $this = shift;
    $this->makePlugin( 'mergeHandler', <<'HERE');
sub mergeHandler {
    my ($diff, $old, $new, $info) = @_;
    $called->{mergeHandler}++;
}
HERE

    return;
}

sub test_redirectrequestHandler {
    my $this = shift;
    $this->makePlugin( 'redirectrequestHandler', <<'HERE');
sub redirectrequestHandler {
    my ( $query, $url ) = @_;
    $called->{redirectrequestHandler}++;
}
HERE

    return;
}

sub test_registrationHandler {
    my $this = shift;
    $this->makePlugin( 'registrationHandler', <<'HERE');
sub registrationHandler {
    my ( $web, $wikiName, $loginName ) = @_;
    $called->{registrationHandler}++;
}
HERE

    return;
}

sub test_renderFormFieldForEditHandler {
    my $this = shift;
    $this->makePlugin( 'renderFormFieldForEditHandler', <<'HERE');
sub renderFormFieldForEditHandler {
    my ($name, $type, $size, $value, $attributes, $possibleValues) = @_;
    $called->{renderFormFieldForEditHandler}++;
}
HERE

    return;
}

sub test_renderWikiWordHandler {
    my $this = shift;
    $this->makePlugin( 'renderWikiWordHandler', <<'HERE');
#($linkText, $hasExplicitLinkLabel, $web, $topic) -> $linkText
sub renderWikiWordHandler {
    my ($linkText, $hasExplicitLinkLabel, $web, $topic) = @_;
    $called->{renderWikiWordHandler}++;
    $called->{renderWikiWordHandlerLinks}->{$web.'___'.$topic} = $linkText.'___'.($hasExplicitLinkLabel||'undef');
    #die $topic if ($topic eq 'ALLOWTOPICVIEW');
}
HERE
    $this->checkCalls( 0, 'renderWikiWordHandler' );
    my $tmlText = <<'HERE';
    This is AWikiWord and some NoSuchWeb.NoTopic that we CANNOT
   * Set ALLOWTOPICCHANGE=guest
 %ATTACHURL%/Foswiki-1.1.4.tar.gz
 
 %ATTACHURL%/releases/Foswiki-1.0.4.tar.gz
 %ATTACHURL%/releases/other/file-3.0.4.tar.gz

 %SYSTEMWEB%.WebHome
 %SYSTEMWEB%.WikiWords
 
 %USERSWEB%.%SYSTEMWEB%Topic
 
 %ATTACHURL%/Foswiki-1.1.4.tar.gz
 
 %ATTACHURL%/releases/Foswiki-1.0.4.tar.gz
 [[%ATTACHURL%/releases/other/file-3.0.4.tar.gz]]

 [[%SYSTEMWEB%.WebHome]]
 [[%SYSTEMWEB%.WikiWords]]
 
 [[%USERSWEB%.%SYSTEMWEB%Topic]]

[[some test link]] [[text][link text]]
HERE
    {
        my $html =
          Foswiki::Func::renderText( $tmlText, 'Sandbox', 'TestThisCarefully' );
        $this->checkCalls( 10, 'renderWikiWordHandler' );
        my $hashRef = eval
"\$Foswiki::Plugins::$this->{plugin_name}::called->{renderWikiWordHandlerLinks}";
        use Data::Dumper;
        print STDERR "------ $html\n";
        print STDERR "------ " . Dumper($hashRef) . "\n";

#this is what we have - and it shows that you need to call expandMacros before calling renderText
        $this->assert_deep_equals(
            {
                'ATTACHURL/releases/other/file-3/0/4/tar___gz' =>
                  '%ATTACHURL%/releases/other/file-3.0.4.tar.gz___undef',
                'SYSTEMWEB___WikiWords'      => '%SYSTEMWEB%.WikiWords___undef',
                'Sandbox___Text'             => 'link text___1',
                'SYSTEMWEB___WebHome'        => '%SYSTEMWEB%.WebHome___undef',
                'NoSuchWeb___NoTopic'        => 'NoTopic___undef',
                'Sandbox___ALLOWTOPICCHANGE' => 'ALLOWTOPICCHANGE___undef',
                'USERSWEB___SYSTEMWEBTopic' =>
                  '%USERSWEB%.%SYSTEMWEB%Topic___undef',
                'Sandbox___AWikiWord'    => 'AWikiWord___undef',
                'Sandbox___SomeTestLink' => 'some test link___undef',
                'Sandbox___CANNOT'       => 'CANNOT___undef'
            },
            $hashRef
        );
    }

    #lets do it again, this time with expandMacros first
    eval
"delete \$Foswiki::Plugins::$this->{plugin_name}::called->{renderWikiWordHandler}";
    eval
"delete \$Foswiki::Plugins::$this->{plugin_name}::called->{renderWikiWordHandlerLinks}";
    my $expandedText =
      Foswiki::Func::expandCommonVariables( $tmlText, 'Sandbox',
        'TestThisCarefully' );
    $this->checkCalls( 0, 'renderWikiWordHandler' );
    my $html = Foswiki::Func::renderText( $expandedText, 'Sandbox',
        'TestThisCarefully' );
    $this->checkCalls( 12, 'renderWikiWordHandler' );
    my $hashRef = eval
"\$Foswiki::Plugins::$this->{plugin_name}::called->{renderWikiWordHandlerLinks}";
    use Data::Dumper;
    print STDERR "------ $html\n";
    print STDERR "------ " . Dumper($hashRef) . "\n";

#this is what we have - and it shows that you need to call expandMacros before calling renderText
    $this->assert_deep_equals(
        {
'TemporaryPluginHandlersUsersWeb___TemporaryPluginHandlersSystemWebTopic'
              => 'TemporaryPluginHandlersSystemWebTopic___undef',
            'Sandbox___Text' => 'link text___1',
            'TemporaryPluginHandlersSystemWeb___WebHome' =>
              'TemporaryPluginHandlersSystemWeb___undef',
            'NoSuchWeb___NoTopic'        => 'NoTopic___undef',
            'Sandbox___ALLOWTOPICCHANGE' => 'ALLOWTOPICCHANGE___undef',
            'Sandbox___AWikiWord'        => 'AWikiWord___undef',
            'Sandbox___SomeTestLink'     => 'some test link___undef',
            'Sandbox___CANNOT'           => 'CANNOT___undef',
            'TemporaryPluginHandlersSystemWeb___WikiWords' =>
              'WikiWords___undef'
        },
        $hashRef
    );

    return;
}

sub test_writeHeaderHandler {
    my $this = shift;
    $this->makePlugin( 'writeHeaderHandler', <<'HERE');
sub writeHeaderHandler {
    my ($query) = @_;
    $called->{writeHeaderHandler}++;
}
HERE

    return;
}

sub test_finishPlugin {
    my $this = shift;
    $this->makePlugin( 'finishPlugin', <<'HERE');
sub finishPlugin {
    $called->{finishPlugin}++;
}
HERE

    $this->finishFoswikiSession();
    $this->checkCalls( 1, 'finishPlugin' );
    $this->createNewFoswikiSession();

    return;
}

1;
