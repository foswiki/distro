package TWiki::OopsException;
use base 'Foswiki::OopsException';

sub new {
    my $class = shift;
    return $class->SUPER::new(@_);
}

1;

