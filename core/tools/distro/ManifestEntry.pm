################################################################################

package ManifestEntry;

use File::Copy qw( cp );
use File::Path qw( mkpath );

################################################################################

sub fields {
    return qw( type mode owner group destination source options );
}

################################################################################

sub parseEntry {
    my $format = shift;
    my $parms  = {};

    # type mode owner group destination source options
    @$parms{ fields() } = split( / /, $format );

    return $parms;
}

################################################################################

sub new {
    my $class = shift;
    my $parms = shift || {};
    $parms = parseEntry($parms) unless ref($parms);
    my $self = bless( $parms, $class );

    die unless $self->{source};
    $self->{source} =~ s/\$/\$\$/g;

    unless ( $self->{type} ) {
        $self->{type} =
             -l $self->{source} && 'l'
          || -d $self->{source} && 'd'
          || 'f';
    }
    $self->{mode}  ||= '755';
    $self->{owner} ||= 'root';    #?

    #?    $self->{group} ||= 'twiki';
    $self->{options} ||= '';

    unless ( $self->{destination} ) {
        $self->{source} .= '/' if $self->{type} eq 'd';

# if filename starts with one of the standard twiki points, remap it to a variable name
        ( $self->{destination} = $self->{source} ) =~
          s#^((templates|lib|bin|pub|data)/)#\$$1#;
    }

    return $self;
}

################################################################################

sub install {
    my ( $self, $p ) = @_;
    $p->{basedir} ||= '';

    $self->{destination} =~ s#(\$([A-Za-z_]+)/)#$p->{paths}->{$2}/#g;

    # cleanup double slashes (not really necessary, just being pedantic)
    $self->{destination} =~ s#//#/#g;

    $self->{source} = "$p->{basedir}/$self->{source}";

    warn qq{source and destination files are the same "$self->{source}"\n},
      return
      if $self->{source} eq $self->{destination};

    if ( $self->{type} eq 'd' ) {

        #	mkdir $self->{destination};
        mkpath $self->{destination}, 0, oct( $self->{mode} );
    }
    elsif ( $self->{type} eq 'f' ) {
        print $self, "\n";
        cp( $self->{source}, $self->{destination} );
        chmod oct( $self->{mode} ), $self->{destination};
    }
    else {
        warn "unknown file type for $self\n";
    }

}

################################################################################

use overload ( '""' => \&stringify );

# format from EPM: http://www.easysw.com/epm/epm-manual.html#4_1
#--------------------------------------------------------------------------------
# Each file in the distribution is listed on a line starting with a letter. The format of all lines is:
# type mode owner group destination source options
# Regular files use the letter f for the type field:
# f 755 root sys /usr/bin/foo foo
# Configuration files use the letter c for the type field:
# c 644 root sys /etc/foo.conf foo.conf
# Directories use the letter d for the type field and use a source path of "-":
# d 755 root sys /var/spool/foo -
# Finally, symbolic links use the letter l (lowercase L) for the type field:
# l 000 root sys /usr/bin/foobar foo
# The source field specifies the file to link to and can be a relative path.

sub stringify {
    my $self = shift;
    my $text;
    foreach my $field ( fields() ) {
        my $f = $self->{$field};
        $f = '?' unless defined $f;
        $f =~ s/ /\\ /g;    # escape spaces
        $text .= "$f ";
    }
    return $text;
}

1;
################################################################################
