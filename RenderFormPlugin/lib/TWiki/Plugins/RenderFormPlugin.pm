package TWiki::Plugins::RenderFormPlugin;

use strict;

use vars qw( $VERSION $RELEASE $REVISION $debug $pluginName );

$VERSION = '$Rev: 17581 (05 Oct 2008) $';

$RELEASE = 'Dakar';


$REVISION = '1.002'; #dro# added layout feature; fixed date field bug; added missing docs;
#$REVISION = '1.001'; #dro# changed topicparent default; added and fixed docs; fixed date field bug; fixed non-word character in field names bug;
#$REVISION = '1.000'; #dro# initial version

$pluginName = 'RenderFormPlugin';

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Plugin correctly initialized
    return 1;
}

sub commonTagsHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    ## !! does not work: deep recursion bug:
    ## use TWiki::Contrib::JSCalendarContrib;
    ## TWiki::Contrib::JSCalendarContrib::addHEAD( 'twiki' );

    ## eval {
	use TWiki::Plugins::RenderFormPlugin::Core;
	$_[0] =~ s/\%RENDERFORM{(.*?)}\%/TWiki::Plugins::RenderFormPlugin::Core::render($1,$_[1],$_[2])/ge;
	$_[0] =~ s/\%STARTRENDERFORMLAYOUT(.*?)STOPRENDERFORMLAYOUT\%//sg;
	### workaround for date fields:
	$_[0] =~ s/<\/body>/%INCLUDE{"%TWIKIWEB%\/JSCalendarContribInline"}%<\/body>/i if ($TWiki::Plugins::VERSION > 1.1) && ($_[0] !~ /JSCalendarContrib\twiki.js/);
    ##};
    ##TWiki::Func::writeWarning($@) if $@;
}
