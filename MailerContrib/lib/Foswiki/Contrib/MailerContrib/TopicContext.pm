# Replacement for pushTopicContext in older TWikis. Does the minimum needed
# by MailerContrib.

use strict;

sub Foswiki::Func::pushTopicContext {
    my ( $web, $topic ) = @_;
    my $session = $Foswiki::Plugins::SESSION;
    my ( $web, $topic ) = $session->normalizeWebTopicName(@_);
    my $old = {
        web   => $session->{webName},
        topic => $session->{topicName},
        mark  => $session->{prefs}->mark()
    };

    push( @{ $session->{_FUNC_PREFS_STACK} }, $old );
    $session->{webName}   = $web;
    $session->{topicName} = $topic;
    $session->{prefs}->pushWebPreferences($web);
    $session->{prefs}->pushPreferences( $web, $topic, 'TOPIC' );
    $session->{prefs}->pushPreferenceValues( 'SESSION',
        $session->{loginManager}->getSessionValues() );
}

sub Foswiki::Func::popTopicContext {
    my $session = $Foswiki::Plugins::SESSION;
    my $old     = pop( @{ $session->{_FUNC_PREFS_STACK} } );
    $session->{prefs}->restore( $old->{mark} );
    $session->{webName}   = $old->{web};
    $session->{topicName} = $old->{topic};
}

1;
