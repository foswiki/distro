package Foswiki::Prefs::Stack;
use strict;

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $this  = {
        'final'  => {},
        'levels' => [],
        'map'    => {},
    };
    return bless $this, $class;
}

sub finish {
    my $this = shift;
    undef $this->{'final'};
    undef $this->{'levels'};
    undef $this->{'map'};
}

sub size {
    return scalar @{ $_[0]->{levels} };
}

sub backAtLevel {
    return $_[0]->{levels}->[ $_[1] ];
}

sub finalizedBefore {
    my ( $this, $key, $level ) = @_;
    $level += @{ $this->{levels} } if $level < 0;
    return exists $this->{final}{$key} && $this->{final}{$key} < $level;
}

sub finalized {
    my ( $this, $key ) = @_;
    return exists $this->{final}{$key};
}

sub prefs {
    return keys %{ $_[0]->{'map'} };
}

sub existsPreference {
    return exists $_[0]->{'map'}{ $_[1] };
}

sub insert {
    my $this = shift;

    my $back = $this->{levels}->[-1];
    my $num  = $back->insert(@_);

    my $key = $_[1];
    $this->{'map'}{$key} = '' unless exists $this->{'map'}{$key};

    my $level = $#{ $this->{levels} };
    vec( $this->{'map'}{$key}, $level, 1 ) = 1;

    return $num;
}

sub newLevel {
    my ( $this, $back, $prefix ) = @_;

    push @{ $this->{levels} }, $back;
    my $level = $#{ $this->{levels} };
    $prefix ||= '';
    foreach ( map { $prefix . $_ } $back->prefs ) {
        next if exists $this->{final}{$_};
        $this->{'map'}{$_} = '' unless exists $this->{'map'}{$_};
        vec( $this->{'map'}{$_}, $level, 1 ) = 1;
    }

    my @finalPrefs = split /[,\s]+/, ( $back->get('FINALPREFERENCES') || '' );
    foreach (@finalPrefs) {
        $this->{final}{$_} = $level
          unless exists $this->{final}{$_};
    }

    return $back;
}

sub getDefinitionLevel {
    my ( $this, $pref ) = @_;
    return _getLevel( $this->{'map'}{$pref} );
}

sub _getLevel {
    my $map = shift;
    return
      int( log( ord( substr( $map, -1 ) ) ) / log(2) ) +
      ( ( length($map) - 1 ) * 8 );
}

sub getPreference {
    my ( $this, $key, $level ) = @_;
    my $map = $this->{'map'}{$key};
    return undef unless defined $map;
    if ( defined $level ) {
        my $mask =
          ( chr(0xFF) x int( $level / 8 ) )
          . chr( ( 2**( ( $level % 8 ) + 1 ) ) - 1 );
        $map &= $mask;
        substr( $map, -1 ) = ''
          while length($map) > 0 && ord( substr( $map, -1 ) ) == 0;
        return undef unless length($map) > 0;
    }
    return $this->{levels}->[ _getLevel($map) ]->get($key);
}

sub clone {
    my ( $this, $level ) = @_;

    my $clone = $this->new();
    $clone->{'map'}    = { %{ $this->{'map'} } };
    $clone->{'levels'} = [ @{ $this->{levels} } ];
    $clone->{'final'}  = { %{ $this->{final} } };
    $clone->restore($level) if defined $level;

    return $clone;
}

sub restore {
    my ( $this, $level ) = @_;

    my @keys = grep { $this->{final}{$_} > $level } keys %{ $this->{final} };
    delete @{ $this->{final} }{@keys};
    splice @{ $this->{levels} }, $level + 1;

    my $mask =
      ( chr(0xFF) x int( $level / 8 ) )
      . chr( ( 2**( ( $level % 8 ) + 1 ) ) - 1 );
    foreach ( keys %{ $this->{'map'} } ) {
        $this->{'map'}{$_} &= $mask;
        substr( $this->{'map'}{$_}, -1 ) = ''
          while length( $this->{'map'}{$_} ) > 0
              && ord( substr( $this->{'map'}{$_}, -1 ) ) == 0;
        delete $this->{'map'}{$_} if length( $this->{'map'}{$_} ) == 0;
    }
}

1;
