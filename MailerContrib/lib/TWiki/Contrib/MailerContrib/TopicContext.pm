# Replacement for pushTopicContext in older TWikis. Does the minimum needed
# by MailerContrib.

sub TWiki::Func::pushTopicContext {
    my( $web, $topic ) = @_;
    my $twiki = $TWiki::Plugins::SESSION;
    my( $web, $topic ) = $twiki->normalizeWebTopicName( @_ );
    my $old = {
        web => $twiki->{webName},
        topic => $twiki->{topicName},
        mark => $twiki->{prefs}->mark() };

    push( @{$twiki->{_FUNC_PREFS_STACK}}, $old );
    $twiki->{webName} = $web;
    $twiki->{topicName} = $topic;
    $twiki->{prefs}->pushWebPreferences( $web );
    $twiki->{prefs}->pushPreferences( $web, $topic, 'TOPIC' );
    $twiki->{prefs}->pushPreferenceValues(
        'SESSION', $twiki->{loginManager}->getSessionValues() );
}

sub TWiki::Func::popTopicContext {
    my $twiki = $TWiki::Plugins::SESSION;
    my $old = pop( @{$twiki->{_FUNC_PREFS_STACK}} );
    $twiki->{prefs}->restore( $old->{mark});
    $twiki->{webName} = $old->{web};
    $twiki->{topicName} = $old->{topic};
}

1;
