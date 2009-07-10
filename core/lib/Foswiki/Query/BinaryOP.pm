package Foswiki::Query::BinaryOP;

sub new {
    my $class = shift;
    my $this = { @_, arity => 2 };
    return bless( $this, $class );
}

# Determine if a string represents a valid number
sub _isNumber {
    return shift =~ m/^[+-]?(\d+\.\d+|\d+\.|\.\d+|\d+)([eE][+-]?\d+)?$/;
}

# Static function to apply a comparison function to two data, tolerant
#  of whether they are numeric or not
sub compare {
    my ( $a, $b, $sub ) = @_;
    if ( _isNumber($a) && _isNumber($b) ) {
        return &$sub( $a <=> $b );
    }
    else {
        return &$sub( $a cmp $b );
    }
}

# Evaluate a node using the comparison function passed in. Extra parameters
# are passed on to the comparison function.
sub evalTest {
    my $this       = shift;
    my $node       = shift;
    my $clientData = shift;
    my $sub        = shift;
    my $a          = $node->{params}[0];
    my $b          = $node->{params}[1];
    my $ea         = $a->evaluate( @{$clientData} );
    my $eb         = $b->evaluate( @{$clientData} );
    $ea            = '' unless defined $ea;
    $eb            = '' unless defined $eb;
    if ( ref($ea) eq 'ARRAY' ) {
        my @res;
        foreach my $lhs (@$ea) {
            push( @res, $lhs ) if &$sub( $lhs, $eb, @_ );
        }
        if ( scalar(@res) == 0 ) {
            return undef;
        }
        elsif ( scalar(@res) == 1 ) {
            return $res[0];
        }
        return \@res;
    }
    else {
        return &$sub( $ea, $eb, @_ );
    }
}

1;
