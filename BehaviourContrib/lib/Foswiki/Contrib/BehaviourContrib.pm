package Foswiki::Contrib::BehaviourContrib;

use strict;

our $VERSION = '$Rev$';
our $RELEASE = '1.4';
our $SHORTDESCRIPTION = "'Behaviour' Javascript event library to create javascript based interactions that degrade well when javascript is not available";

=begin TML

---+++ Foswiki::Contrib::BehaviourContrib::addHEAD()

This function will automatically add the headers for the contrib to
the page being rendered. It is intended for use from Plugins and
other extensions. For example:

<verbatim>
sub commonTagsHandler {
  ....
  require Foswiki::Contrib::BehaviourContrib;
  Foswiki::Contrib::BehaviourContrib::addHEAD();
  ....
</verbatim>

=cut

sub addHEAD {
    my $base = '%PUBURLPATH%/%SYSTEMWEB%/BehaviourContrib';
    my $USE_SRC =
      Foswiki::Func::getPreferencesValue('BEHAVIOURCONTRIB_DEBUG')
      ? '_src'
      : '';
    my $head = <<HERE;
<script type='text/javascript' src='$base/behaviour$USE_SRC.js'></script>
HERE
    Foswiki::Func::addToHEAD( 'BEHAVIOURCONTRIB', $head );
}

1;
