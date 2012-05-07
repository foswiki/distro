######################################################################
# $Id: CacheTester.pm,v 1.20 2002/04/07 17:04:46 dclinton Exp $
# Copyright (C) 2001-2003 DeWitt Clinton  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################

package Cache::CacheTester;

use strict;
use Cache::BaseCacheTester;
use Cache::Cache;
use Error qw( :try );

use vars qw( @ISA $EXPIRES_DELAY );

@ISA = qw ( Cache::BaseCacheTester );

$EXPIRES_DELAY = 2;
$Error::Debug = 1;

sub test
{
  my ( $self, $cache ) = @_;

  try
  {
    $cache->Clear( );
    $self->_test_one( $cache );
    $self->_test_two( $cache );
    $self->_test_three( $cache );
    $self->_test_four( $cache );
    $self->_test_five( $cache );
    $self->_test_six( $cache );
    $self->_test_seven( $cache );
    $self->_test_eight( $cache );
    $self->_test_nine( $cache );
    $self->_test_ten( $cache );
    $self->_test_eleven( $cache );
    $self->_test_twelve( $cache );
    $self->_test_thirteen( $cache );
    $self->_test_fourteen( $cache );
    $self->_test_fifteen( $cache );
    $self->_test_sixteen( $cache );
    $self->_test_seventeen( $cache );
  }
  catch Error with
  {
    my $error = shift;

    print STDERR "\nError:\n";
    print STDERR $error->stringify( ) . "\n";
    print STDERR $error->stacktrace( ) . "\n";
    print STDERR "\n";
  }
}


# Test the getting, setting, and removal of a scalar

sub _test_one
{
  my ( $self, $cache ) = @_;

  $cache or
    croak( "cache required" );

  my $key = 'Test Key';

  my $value = 'Test Value';

  $cache->set( $key, $value );

  my $fetched_value = $cache->get( $key );

  ( $fetched_value eq $value ) ?
    $self->ok( ) : $self->not_ok( '$fetched_value eq $value' );

  $cache->remove( $key );

  my $fetched_removed_value = $cache->get( $key );

  ( not defined $fetched_removed_value ) ?
    $self->ok( ) : $self->not_ok( 'not defined $fetched_removed_value' );
}


# Test the getting, setting, and removal of a list

sub _test_two
{
  my ( $self, $cache ) = @_;

  $cache or
    croak( "cache required" );

  my $key = 'Test Key';

  my @value_list = ( 'One', 'Two', 'Three' );

  $cache->set( $key, \@value_list );

  my $fetched_value_list_ref = $cache->get( $key );

  if ( ( $fetched_value_list_ref->[0] eq 'One' ) and
       ( $fetched_value_list_ref->[1] eq 'Two' ) and
       ( $fetched_value_list_ref->[2] eq 'Three' ) )
  {
    $self->ok( );
  }
  else
  {
    $self->not_ok( 'fetched list does not match set list' );
  }

  $cache->remove( $key );

  my $fetched_removed_value = $cache->get( $key );

  ( not defined $fetched_removed_value ) ?
    $self->ok( ) : $self->not_ok( 'not defined $fetched_removed_value' );
}


# Test the getting, setting, and removal of a blessed object

sub _test_three
{
  my ( $self, $cache ) = @_;

  $cache or
    croak( "cache required" );

  my $key = 'Test Key';

  my $value = 'Test Value';

  $cache->set( $key, $value );

  my $cache_key = 'Cache Key';

  $cache->set( $cache_key, $cache );

  my $fetched_cache = $cache->get( $cache_key );

  ( defined $fetched_cache ) ?
    $self->ok( ) : $self->not_ok( 'defined $fetched_cache' );

  my $fetched_value = $fetched_cache->get( $key );

  ( $fetched_value eq $value ) ?
    $self->ok( ) : $self->not_ok( '$fetched_value eq $value' );
}


# Test the expiration of an object

sub _test_four
{
  my ( $self, $cache ) = @_;

  my $expires_in = $EXPIRES_DELAY;

  my $key = 'Test Key';

  my $value = 'Test Value';

  $cache->set( $key, $value, $expires_in );

  my $fetched_value = $cache->get( $key );

  ( $fetched_value eq $value ) ?
    $self->ok( ) : $self->not_ok( '$fetched_value eq $value' );

  sleep( $EXPIRES_DELAY + 1 );

  my $fetched_expired_value = $cache->get( $key );

  ( not defined $fetched_expired_value ) ?
    $self->ok( ) : $self->not_ok( 'not defined $fetched_expired_value' );
}



# Test that caches make deep copies of values

sub _test_five
{
  my ( $self, $cache ) = @_;

  $cache or
    croak( "cache required" );

  my $key = 'Test Key';

  my @value_list = ( 'One', 'Two', 'Three' );

  $cache->set( $key, \@value_list );

  @value_list = ( );

  my $fetched_value_list_ref = $cache->get( $key );

  if ( ( $fetched_value_list_ref->[0] eq 'One' ) and
       ( $fetched_value_list_ref->[1] eq 'Two' ) and
       ( $fetched_value_list_ref->[2] eq 'Three' ) )
  {
    $self->ok( );
  }
  else
  {
    $self->not_ok( 'fetched deep list does not match set deep list' );
  }
}



# Test clearing a cache

sub _test_six
{
  my ( $self, $cache ) = @_;

  $cache or
    croak( "cache required" );

  my $key = 'Test Key';

  my $value = 'Test Value';

  $cache->set( $key, $value );

  $cache->clear( );

  my $fetched_cleared_value = $cache->get( $key );

  ( not defined $fetched_cleared_value ) ?
    $self->ok( ) : $self->not_ok( 'not defined $fetched_cleared_value' );
}


# Test sizing of the cache

sub _test_seven
{
  my ( $self, $cache ) = @_;

  my $empty_size = $cache->size( );

  ( $empty_size == 0 ) ?
    $self->ok( ) : $self->not_ok( '$empty_size == 0' );

  my $first_key = 'First Test Key';

  my $value = 'Test Value';

  $cache->set( $first_key, $value );

  my $first_size = $cache->size( );

  ( $first_size > $empty_size ) ?
    $self->ok( ) : $self->not_ok( '$first_size > $empty_size' );

  my $second_key = 'Second Test Key';

  $cache->set( $second_key, $value );

  my $second_size = $cache->size( );

  ( $second_size > $first_size ) ?
    $self->ok( ) : $self->not_ok( '$second_size > $first_size' );
}


# Test purging the cache

sub _test_eight
{
  my ( $self, $cache ) = @_;

  $cache->clear( );

  my $empty_size = $cache->size( );

  ( $empty_size == 0 ) ?
    $self->ok( ) : $self->not_ok( '$empty_size == 0' );

  my $expires_in = $EXPIRES_DELAY;

  my $key = 'Test Key';

  my $value = 'Test Value';

  $cache->set( $key, $value, $expires_in );

  my $pre_purge_size = $cache->size( );

  ( $pre_purge_size > $empty_size ) ?
    $self->ok( ) : $self->not_ok( '$pre_purge_size > $empty_size' );

  sleep( $EXPIRES_DELAY + 1 );

  $cache->purge( );

  my $post_purge_size = $cache->size( );

  ( $post_purge_size == $empty_size ) ?
    $self->ok( ) : $self->not_ok( '$post_purge_size == $empty_size' );
}


# Test the getting, setting, and removal of a scalar across cache instances

sub _test_nine
{
  my ( $self, $cache1 ) = @_;

  $cache1 or
    croak( "cache required" );

  my $cache2 = $cache1->new( ) or
    croak( "Couldn't construct new cache" );

  my $key = 'Test Key';

  my $value = 'Test Value';

  $cache1->set( $key, $value );

  my $fetched_value = $cache2->get( $key );

  ( $fetched_value eq $value ) ?
    $self->ok( ) : $self->not_ok( '$fetched_value eq $value' );
}


# Test Clear() and Size() as instance methods

sub _test_ten
{
  my ( $self, $cache ) = @_;

  $cache or
    croak( "cache required" );

  my $key = 'Test Key';

  my $value = 'Test Value';

  $cache->set( $key, $value );

  my $full_size = $cache->Size( );

  ( $full_size > 0 ) ?
    $self->ok( ) : $self->not_ok( '$full_size > 0' );

  $cache->Clear( );

  my $empty_size = $cache->Size( );

  ( $empty_size == 0 ) ?
    $self->ok( ) : $self->not_ok( '$empty_size == 0' );
}


# Test Purge(), Clear(), and Size() as instance methods

sub _test_eleven
{
  my ( $self, $cache ) = @_;

  $cache->Clear( );

  my $empty_size = $cache->Size( );

  ( $empty_size == 0 ) ?
    $self->ok( ) : $self->not_ok( '$empty_size == 0' );

  my $expires_in = $EXPIRES_DELAY;

  my $key = 'Test Key';

  my $value = 'Test Value';

  $cache->set( $key, $value, $expires_in );

  my $pre_purge_size = $cache->Size( );

  ( $pre_purge_size > $empty_size ) ?
    $self->ok( ) : $self->not_ok( '$pre_purge_size > $empty_size' );

  sleep( $EXPIRES_DELAY + 1 );

  $cache->Purge( );

  my $purged_object = $cache->get_object( $key );

  ( not defined $purged_object ) ?
    $self->ok( ) : $self->not_ok( 'not defined $purged_object' );
}


# Test Purge(), Clear(), and Size() as static methods

sub _test_twelve
{
  my ( $self, $cache ) = @_;

  my $class = ref $cache or
    croak( "Couldn't get ref \$cache" );

  no strict 'refs';

  &{"${class}::Clear"}( );

  my $empty_size = &{"${class}::Size"}( );

  ( $empty_size == 0 ) ?
    $self->ok( ) : $self->not_ok( '$empty_size == 0' );

  my $expires_in = $EXPIRES_DELAY;

  my $key = 'Test Key';

  my $value = 'Test Value';

  $cache->set( $key, $value, $expires_in );

  my $pre_purge_size = &{"${class}::Size"}( );

  ( $pre_purge_size > $empty_size ) ?
    $self->ok( ) : $self->not_ok( '$pre_purge_size > $empty_size' );

  sleep( $EXPIRES_DELAY + 1 );

  &{"${class}::Purge"}( );

  my $purged_object = $cache->get_object( $key );

  ( not defined $purged_object ) ?
    $self->ok( ) : $self->not_ok( 'not defined $purged_object' );

  use strict;
}



# Test the expiration of an object with extended syntax

sub _test_thirteen
{
  my ( $self, $cache ) = @_;

  my $expires_in = $EXPIRES_DELAY;

  my $key = 'Test Key';

  my $value = 'Test Value';

  $cache->set( $key, $value, $expires_in );

  my $fetched_value = $cache->get( $key );

  ( $fetched_value eq $value ) ?
    $self->ok( ) : $self->not_ok( '$fetched_value eq $value' );

  sleep( $EXPIRES_DELAY + 1 );

  my $fetched_expired_value = $cache->get( $key );

  ( not defined $fetched_expired_value ) ?
    $self->ok( ) : $self->not_ok( 'not defined $fetched_expired_value' );
}


# test the get_keys method

sub _test_fourteen
{
  my ( $self, $cache ) = @_;

  $cache->Clear( );

  my $empty_size = $cache->Size( );

  ( $empty_size == 0 ) ?
    $self->ok( ) : $self->not_ok( '$empty_size == 0' );

  my @keys = sort ( 'John', 'Paul', 'Ringo', 'George' );

  my $value = 'Test Value';

  foreach my $key ( @keys )
  {
    $cache->set( $key, $value );
  }

  my @cached_keys = sort $cache->get_keys( );

  my $arrays_equal = Arrays_Are_Equal( \@keys, \@cached_keys );

  ( $arrays_equal == 1 ) ?
    $self->ok( ) : $self->not_ok( '$arrays_equal == 1' );
}


# test the auto_purge on set functionality

sub _test_fifteen
{
  my ( $self, $cache ) = @_;

  $cache->Clear( );

  my $expires_in = $EXPIRES_DELAY;

  $cache->set_auto_purge_interval( $expires_in );

  $cache->set_auto_purge_on_set( 1 );

  my $key = 'Test Key';

  my $value = 'Test Value';

  $cache->set( $key, $value, $expires_in );

  my $fetched_value = $cache->get( $key );

  ( $fetched_value eq $value ) ?
    $self->ok( ) : $self->not_ok( '$fetched_value eq $value' );

  sleep( $EXPIRES_DELAY + 1 );

  $cache->set( "Trigger auto_purge", "Empty" );

  my $fetched_expired_object = $cache->get_object( $key );

  ( not defined $fetched_expired_object ) ?
    $self->ok( ) : $self->not_ok( 'not defined $fetched_expired_object' );

  $cache->Clear( );
}



# test the auto_purge_interval functionality

sub _test_sixteen
{
  my ( $self, $cache ) = @_;

  my $expires_in = $EXPIRES_DELAY;

  eval
  {
    $cache = $cache->new( { 'auto_purge_interval' => $expires_in } );
  };

  ( not defined @$ ) ?
    $self->ok( ) : $self->not_ok( "couldn't create autopurge cache" );
}


# test the get_namespaces method

sub _test_seventeen
{
  my ( $self, $cache ) = @_;

  $cache->set( 'a', '1' );
  $cache->set_namespace( 'namespace' );
  $cache->set( 'b', '2' );

  if ( Arrays_Are_Equal( [ sort( $cache->get_namespaces( ) ) ],
                         [ sort( 'Default', 'namespace' ) ] ) )
  {
    $self->ok( );
  }
  else
  {
    $self->not_ok( "get_namespaces returned the wrong namespaces" );
  }

  $cache->Clear( );
}



sub Arrays_Are_Equal
{
  my ( $first_array_ref, $second_array_ref ) = @_;

  local $^W = 0;  # silence spurious -w undef complaints

  return 0 unless @$first_array_ref == @$second_array_ref;

  for (my $i = 0; $i < @$first_array_ref; $i++)
  {
    return 0 if $first_array_ref->[$i] ne $second_array_ref->[$i];
  }

  return 1;
}


1;


__END__

=pod

=head1 NAME

Cache::CacheTester -- a class for regression testing caches

=head1 DESCRIPTION

The CacheTester is used to verify that a cache implementation honors
its contract.

=head1 SYNOPSIS

  use Cache::MemoryCache;
  use Cache::CacheTester;

  my $cache = new Cache::MemoryCache( );

  my $cache_tester = new Cache::CacheTester( 1 );

  $cache_tester->test( $cache );

=head1 METHODS

=over

=item B<new( $initial_count )>

Construct a new CacheTester object, with the counter starting at
I<$initial_count>.

=item B<test( )>

Run the tests.

=back

=head1 SEE ALSO

Cache::Cache, Cache::BaseCacheTester

=head1 AUTHOR

Original author: DeWitt Clinton <dewitt@unto.net>

Last author:     $Author: dclinton $

Copyright (C) 2001-2003 DeWitt Clinton

=cut

