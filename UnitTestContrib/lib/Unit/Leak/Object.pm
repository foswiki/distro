package Unit::Leak::Object;

use v5.14;

# We abuse refs a LOT
use strict qw{ vars subs };
use Carp         ();
use Scalar::Util ();
use Digest::SHA  ();

use vars qw{ $VERSION @ISA @EXPORT_OK };
use vars
  qw{ %OBJECT_COUNT %TRACKED %DESTROY_ORIGINAL %DESTROY_STUBBED %DESTROY_NEXT %IGNORE_CLASS %OBJECT_COUNT_CHECKPOINT };
use vars qw{ $TRACKSOURCELINES $TRACKSTACK };

BEGIN {
    $VERSION = '1.01';

    # Set up exports
    require Exporter;
    @ISA       = qw(Exporter);
    @EXPORT_OK = qw(track bless status checkpoint);

    # Set up state storage (primary for clarity)
    %OBJECT_COUNT            = ();
    %OBJECT_COUNT_CHECKPOINT = ();
    %TRACKED                 = ();
    %DESTROY_ORIGINAL        = ();
    %DESTROY_STUBBED         = ();
    %DESTROY_NEXT            = ();
    %IGNORE_CLASS            = ();
    $TRACKSOURCELINES        = 0;
    $TRACKSTACK              = 0;
}

sub import {
    my $class  = shift;
    my @import = ();
    while (@_) {
        my $function = shift;
        unless ( $function =~ /^GLOBAL_(.*)$/ ) {
            push @import, $function;
            next;
        }
        my $global = $1;
        no strict 'refs';
        *{ 'CORE::GLOBAL::' . $global } = \&{$global};
        use strict 'refs';
    }
    return $class->SUPER::import(@import);
}

sub bless {
    my $reference = shift;
    my $class     = @_ ? shift : scalar caller;
    my $object    = CORE::bless( $reference, $class );
    Unit::Leak::Object::track($object);
    return $object;
}

sub get_stack {
    my $level = shift // 2;

    my ( @frame, @trace );
    my ( $record, $frameCnt, $maxModLen ) = ( 0, 0, 0 );
    while ( @frame = caller($level) ) {

        # Start recording after new's frame.
        $record = $frame[3] =~ /::new$/ unless $record;
        if ($record) {
            $frameCnt++;
            push @trace, [ $frameCnt, $frame[0], $frame[1], $frame[2] ];
            $maxModLen = length( $frame[0] )
              if $maxModLen < length( $frame[0] );
        }
        $level++;
    }
    my $frameCntLen = length( "" . $frameCnt ) + 1;
    $maxModLen = 40 if $maxModLen > 40;
    return join( "\n",
        map { sprintf( "%${frameCntLen}d: %-${maxModLen}s %s, line %d", @$_ ) }
          @trace );
}

sub track {
    my $object = shift;
    my $class  = Scalar::Util::blessed($object);
    unless ( defined $class ) {
        Carp::carp( __PACKAGE__ . "::track was passed a non-object" );
    }
    return if ( defined( $IGNORE_CLASS{$class} ) );
    my $address = Scalar::Util::refaddr($object);
    if ( $TRACKED{$address} ) {
        $TRACKED{$address}->{class} ||=
          '';    # avoid warnings about uninitialised strings
        if ( $class eq $TRACKED{$address}->{class} ) {

            # Reblessing into the same class, ignore
            return $OBJECT_COUNT{$class};
        }
        else {
            # Reblessing into a different class
            $OBJECT_COUNT{ $TRACKED{$address}->{class} }--;
        }
    }

    # Set or over-write the class name for the tracked object
    my ( $package, $srcfile, $srcline, $subroutine );
    if ( $object->isa('Foswiki::Object') ) {
        ( $package, $srcfile, $srcline, $subroutine ) = Foswiki::Object->__orig;
    }

    # If not Foswiki::Object or Foswiki::Object::__orig failed.
    unless ( defined $srcfile ) {
        ( $package, $srcfile, $srcline, $subroutine ) = caller(1);
        $package    ||= '';
        $subroutine ||= '';

        #don't just tell us that we called it from our own new..
        if ( $package eq $class ) {
            my ( $next_package, $next_srcfile, $next_srcline, $next_subroutine )
              = caller(2);
            if ( $next_subroutine eq $class . '::new' ) {
                ( $package, $srcfile, $srcline, $subroutine ) = (
                    $next_package, $next_srcfile,
                    $next_srcline, $next_subroutine
                );
            }
        }
    }

    my @stack = ();
    if ($TRACKSTACK) {
        @stack = ( stack => get_stack );
    }
    $TRACKED{$address} = {
        class      => $class,
        file       => $srcfile,
        line       => $srcline,
        package    => $package,
        subroutine => $subroutine,
        @stack
    };

    # If needed, initialise the new class
    unless ( $DESTROY_STUBBED{$class} ) {
        no strict 'refs';
        if ( exists ${ $class . '::' }{DESTROY}
            and *{ $class . '::DESTROY' }{CODE} )
        {
            # Stash the pre-existing DESTROY function
            $DESTROY_ORIGINAL{$class} = \&{ $class . '::DESTROY' };
        }
        use strict 'refs';
        $DESTROY_STUBBED{$class} = 1;
        eval <<"END_DESTROY";
package $class;\
no warnings;
sub DESTROY {
    my \$class   = Scalar::Util::blessed(\$_[0]);
    my \$address = Scalar::Util::refaddr(\$_[0]);
    unless ( defined \$class ) {
        Carp::carp("Unexpected error: First param to DESTROY is no an object");
        return;
    }
    unless ( defined \$class ) {
        die "Unexpected error: First param to DESTROY is no an object";
    }

    # Don't do anything unless tracking for the specific object is set
    my \$original = \$Unit::Leak::Object::TRACKED{\$address}->{class};
    if ( \$original ) {
        ### TODO - We COULD add a check that $class eq
        #          \$Unit::Leak::Object::TRACKED{\$address}->{class}
        #          and then not decrement unless it is the same.
        #          However, in practice it should ALWAYS be the same if
        #          we already have \$Unit::Leak::Object::TRACKED{\$address}
        #          true still, and if for some reason this is wrong, we get
        #          a false positive in the leak counting.
        #          This additional check may be able to be added at a later
        #          date if it turns out to be needed.
        #          if ( \$class eq \$Unit::Leak::Object::TRACKED{\$address} ) { ... }
        if ( \$class ne \$original ) {
            warn "Object class '\$class' does not match original ".\$Unit::Leak::Object::TRACKED{\$address}->{class};
        }
        \$Unit::Leak::Object::OBJECT_COUNT{\$original}--;
        if ( \$Unit::Leak::Object::OBJECT_COUNT{\$original} < 0 ) {
            warn "Object count for ".\$Unit::Leak::Object::TRACKED{\$address}->{class}." negative (\$Unit::Leak::Object::OBJECT_COUNT{\$original})";
        }
        delete \$Unit::Leak::Object::TRACKED{\$address};

        # Hand of to the regular DESTROY method, or pass up to the SUPERclass if there isn't one
        if ( \$Unit::Leak::Object::DESTROY_ORIGINAL{\$original} ) {
            goto \&{\$Unit::Leak::Object::DESTROY_ORIGINAL{\$original}};
        }
    } else {
        \$original = \$class;
    }

    # If we don't have the DESTROY_NEXT for this class, populate it
    unless ( \$Unit::Leak::Object::DESTROY_NEXT{\$original} ) {
        Unit::Leak::Object::make_next(\$original);
    }
    my \$super = \$Unit::Leak::Object::DESTROY_NEXT{\$original}->{'$class'};
    unless (( defined \$super ) or (defined(\$Unit::Leak::Object::IGNORE_CLASS{\$class}))) {
        warn "Failed to find super-method for class \$class in package $class";
        \$Unit::Leak::Object::IGNORE_CLASS{\$class} = 1;
    }
    if ( \$super ) {
        goto \&{\$super.'::DESTROY'};
    }
    return;
}
END_DESTROY
        if ($@) {
            die "Failed to generate DESTROY method for $class: $@";
        }

        # Pre-emptively populate the DESTROY_NEXT map
        unless ( $DESTROY_NEXT{$class} ) {
            make_next($class);
        }
    }

    $OBJECT_COUNT{ $TRACKED{$address}->{class} }++;
}

sub make_next {
    my $class = shift;

    no strict 'refs';

    # Build the %DESTROY_NEXT entries to support DESTROY_stub
    $DESTROY_NEXT{$class} = {};
    my @stack = ($class);
    my %seen  = ( UNIVERSAL => 1 );
    my @queue = ();
    while ( my $c = shift @stack ) {
        next if $seen{$c}++;

        # Does the class have it's own DESTROY method
        my $has_destroy =
          $DESTROY_STUBBED{$c}
          ? !!exists $DESTROY_ORIGINAL{$c}
          : !!( exists ${"${c}::"}{DESTROY} and *{"${c}::DESTROY"}{CODE} );
        if ($has_destroy) {

            # Everything in the queue has this class as it's next call
            while (@queue) {
                $DESTROY_NEXT{$class}->{ shift(@queue) } = $c;
            }
        }
        else {
            # This class goes onto the queue
            push @queue, $c;
        }

        # Add the @ISA to the search stack.
        unshift @stack, @{"${c}::ISA"};
    }

    # Any else has no target to go to
    while (@queue) {
        $DESTROY_NEXT{$class}->{ shift @queue } = '';
    }

    use strict 'refs';

    return 1;
}

sub checkpoint {
    my $first;
    for ( sort keys %OBJECT_COUNT ) {
        next unless $OBJECT_COUNT{$_};    # Don't list class with count zero
        $OBJECT_COUNT_CHECKPOINT{$_} ||= 0;
        next unless ( $OBJECT_COUNT{$_} > $OBJECT_COUNT_CHECKPOINT{$_} );

        print STDERR "checkpoint:\n" unless ( $first++ );
        printf STDERR "\t%-40s %d\n", $_,
          $OBJECT_COUNT{$_} - $OBJECT_COUNT_CHECKPOINT{$_};

        $OBJECT_COUNT_CHECKPOINT{$_} = $OBJECT_COUNT{$_};
    }
}

sub status {
    print STDERR "Tracked objects by class:\n";
    for ( sort keys %OBJECT_COUNT ) {
        next if ( $_ eq '' );    #Don't know what these are..
        next unless $OBJECT_COUNT{$_};    # Don't list class with count zero
        printf STDERR "\t%-40s %d\n", $_, $OBJECT_COUNT{$_};
    }
    if ($Unit::Leak::Object::TRACKSOURCELINES) {
        print STDERR "\nSources of leaks:\n";
        my %classes = ();
        my ( %stacks, %stackHashes );
        foreach my $obj ( values(%TRACKED) ) {

            #TODO: no, I don't know why there are some undefined
            next unless defined( $obj->{class} );
            $classes{ $obj->{class} } ||= {};
            my $line =
                $obj->{file}
              . ' line: '
              . $obj
              ->{line};    #.' ('.$obj->{package}.' -> '.$obj->{subroutine}.')';
            $classes{ $obj->{class} }->{$line}++;
            if ( $TRACKSTACK && $obj->{stack} ) {
                my $sha = Digest::SHA::sha256( $obj->{stack} );
                unless ( defined $stackHashes{$sha} ) {
                    push @{ $stacks{ $obj->{class} } }, $obj->{stack};
                    $stackHashes{$sha} = 1;
                }
            }
        }
        foreach my $class ( sort keys(%classes) ) {
            printf STDERR "%s\n", $class;
            my %lines = %{ $classes{$class} };
            foreach my $line ( sort keys(%lines) ) {
                printf STDERR "%6d from %s\n", $lines{$line}, $line;
            }
        }
        if ($TRACKSTACK) {
            foreach my $class ( keys %stacks ) {
                print STDERR "\nStack traces for ", $class, ":\n";
                foreach my $trace ( @{ $stacks{$class} } ) {
                    print STDERR $trace, "\n\n";
                }
            }
        }
    }
}

END {
    status();
}

1;

__END__


=head1 NAME

Unit::Leak::Object - Detect leaks of objects 

=head1 SYNOPSIS

  # Track a single object
  use Unit::Leak::Object;
  my $obj = Foo::Bar->new;
  Unit::Leak::Object::track($obj);
  
  # Track every object
  use Unit::Leak::Object qw{ GLOBAL_bless };

  # Track every object including where they're created
  use Unit::Leak::Object qw{ GLOBAL_bless };
  $Unit::Leak::Object::TRACKSOURCELINES = 1;

=head1 DESCRIPTION

This module provides tracking of objects, for the purpose of detecting memory
leaks due to circular references or innappropriate caching schemes.

Object tracking can be enabled on a per object basis. Any objects
thus tracked are remembered until DESTROYed; details of any objects
left are printed out to STDERR at END-time.

  use Unit::Leak::Object qw(GLOBAL_bless);

This form overloads B<bless> to track construction and destruction of all
objects. As an alternative, by importing bless, you can just track the
objects of the caller code that is doing the use.

If you use GLOBAL_bless to overload the bless function, please note that
it will ONLY apply to bless for modules loaded AFTER Unit::Leak::Object
has enabled the hook.

Any modules already loaded will have already bound to CORE::bless and will
not be impacted.

Setting the global variable $Unit::Leak::Object::TRACKSOURCELINES makes the
report at the end include where (filename and line number) each leaked object
originates (or where call to the ::new is made).

=head1 BUGS

Please report bugs to http://rt.cpan.org

=head1 AUTHOR

Adam Kennedy <adamk@cpan.org>

With some additional contributions from David Cantrell E<lt>david@cantrell.org.ukE<gt>
and Sven Dowideit <svendowideit@home.org.au>

=head1 SEE ALSO

L<Devel::Leak>

=head1 COPYRIGHT

Copyright 2007 - 2010 Adam Kennedy.

Rewritten from original copyright 2004 Ivor Williams.

Some documentation also copyright 2004 Ivor Williams.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
