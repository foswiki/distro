# Copyright (C) 2012 Sven Dowideit
#
# these tests are to ensure the topic file format works out
#
# during future development they will pertubate on the Foswiki::Serialise::* impls
# initially they test the ancient Embedded code

package SerialiseTests;
use strict;
use warnings;
require 5.006;

use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use Assert;
use Foswiki;
use Foswiki::Meta;
use Foswiki::Plugin();
use Foswiki::Func();
use File::Temp();
use Foswiki::AccessControlException();
use Error qw( :try );

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    return;
}

sub tear_down {
    my $this = shift;

    $this->SUPER::tear_down();

    return;
}

sub set_up_for_verify {

    use Foswiki::Serialise::Embedded;

    return;
}

sub NO_IMPLEMENTED_YETfixture_groups {
    my $this = shift;
    my @groups;

    foreach my $dir (@INC) {
        my ( $volume, $directories ) = File::Spec->splitpath( $dir, 1 );

        $directories = File::Spec->catdir( File::Spec->splitdir($directories),
            qw(Foswiki Serialise) );
        if (
            opendir( my $D, File::Spec->catpath( $volume, $directories, '' ) ) )
        {
            foreach my $alg ( readdir $D ) {
                next unless $alg =~ s/^(.*)\.pm$/$1/;
                next if $alg =~ /RcsWrap/ && !rcs_is_installed();
                ($alg) = $alg =~ /^(.*)$/ms;    # untaint
                $this->assert( eval "require Foswiki::Store::$alg; 1;" );
                my $algname = ref($this) . '_' . $alg;
                next if defined &{$algname};
                no strict 'refs';
                *{$algname} = sub {
                    my $self = shift;
                    $Foswiki::cfg{Store}{Implementation} =
                      'Foswiki::Store::' . $alg;
                    $self->set_up_for_verify();
                };
                use strict 'refs';
                push( @groups, $algname );
            }
            closedir($D);
        }
    }

    # Uncomment below to test one store in isolation
    #    return [ ref($this) . '_PlainFile' ];
    #    return [ ref($this) . '_RcsWrap' ];
    #    return [ ref($this) . '_RcsLite' ];
    return \@groups;
}

# Create a simple topic containing meta-data
sub test_SimpleMetaTopic {
    my $this = shift;

    my $meta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'TestTopic' );

    $meta->text("\n\n onceler \n \n\n \n\n\n");
    $meta->putKeyed( 'FIELD', { name => 'fieldname', value => 'meta' } );
    $meta->putKeyed( 'FIELD', { name => 'fieldname', value => 'meta' } );
    $meta->putKeyed( 'FIELD', { name => 'fieldname', value => 'meta' } );

    $meta->put( 'ARRAY', { name => 'fieldname', value => 'meta' } );
    $meta->put( 'ARRAY', { name => 'fieldname', value => 'meta' } );
    $meta->put( 'ARRAY', { name => 'fieldname', value => 'meta' } );

    my $text = $meta->getEmbeddedStoreForm();

    my $metaFromSerialised =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'TestTopic' );
    $metaFromSerialised->setEmbeddedStoreForm($text);

    my $textAgain = $metaFromSerialised->getEmbeddedStoreForm();

    $this->assert_equals( $text, $textAgain );

    return;
}

1;
