package Foswiki::Query::UnaryOP;

sub new {
    my $class = shift;
    my $this = { @_, arity => 1 };
    return bless( $this, $class );
}

sub evalUnary {
    my $this = shift;
    my $node = shift;
    my $sub  = shift;
    my $a    = $node->{params}[0];
    my $val  = $a->evaluate(@_);
    $val     = '' unless defined $val;
    if ( ref($val) eq 'ARRAY' ) {
        my @res = map { &$sub($_) } @$val;
        return \@res;
    }
    else {
        return &$sub($val);
    }
}

1;
