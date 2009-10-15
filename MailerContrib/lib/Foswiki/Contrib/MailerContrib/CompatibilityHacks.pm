# Hack for older TWiki versions
package CompatibilityHacks;

package IteratorHack;

use strict;

sub new {
    my ( $class, $list ) = @_;
    my $this = bless( { list => $list, index => 0, next => undef }, $class );
    return $this;
}

sub hasNext {
    my ($this) = @_;
    return 1 if $this->{next};
    if ( $this->{index} < scalar( @{ $this->{list} } ) ) {
        $this->{next} = $this->{list}->[ $this->{index}++ ];
        return 1;
    }
    return 0;
}

sub next {
    my $this = shift;
    $this->hasNext();
    my $n = $this->{next};
    $this->{next} = undef;
    return $n;
}

package Foswiki::Func;

sub eachChangeSince {
    my ( $web, $since ) = @_;

    my $changes;
    if ( open( F, '<', "$Foswiki::cfg{DataDir}/$web/.changes" ) ) {
        local $/ = undef;
        $changes = <F>;
        close(F);
    }

    $changes ||= '';

    my @changes =
      map {

        # Create a hash for this line
        {
            topic    => $_->[0],
            user     => $_->[1],
            time     => $_->[2],
            revision => $_->[3],
            more     => $_->[4]
        };
      }
      grep {

        # Filter on time
        $_->[2] && $_->[2] >= $since
      }
      map {

        # Split line into an array
        my @row = split( /\t/, $_, 5 );
        \@row;
      }
      reverse split( /[\r\n]+/, $changes );

    return new IteratorHack( \@changes );
}

1;
