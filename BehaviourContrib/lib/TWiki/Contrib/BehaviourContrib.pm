package TWiki::Contrib::BehaviourContrib;
use vars qw( $VERSION );
$VERSION = '$Rev$';
$RELEASE = '1.3.1';

=begin twiki

---+++ TWiki::Contrib::BehaviourContrib::addHEAD()

This function will automatically add the headers for the contrib to
the page being rendered. It is intended for use from Plugins and
other extensions. For example:

<verbatim>
sub commonTagsHandler {
  ....
  require TWiki::Contrib::BehaviourContrib;
  TWiki::Contrib::BehaviourContrib::addHEAD();
  ....
</verbatim>

=cut

sub addHEAD {
    my $base = '%PUBURLPATH%/%SYSTEMWEB%/BehaviourContrib';
    my $USE_SRC =
      TWiki::Func::getPreferencesValue('BEHAVIOURCONTRIB_DEBUG') ?
          '_src' : '';
    my $head = <<HERE;
<script type='text/javascript' src='$base/behaviour$USE_SRC.js'></script>
HERE
    TWiki::Func::addToHEAD( 'BEHAVIOURCONTRIB', $head );
}

1;
