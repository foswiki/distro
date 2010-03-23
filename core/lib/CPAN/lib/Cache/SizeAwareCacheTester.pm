######################################################################
# $Id: SizeAwareCacheTester.pm,v 1.11 2002/04/07 17:04:46 dclinton Exp $
# Copyright (C) 2001-2003 DeWitt Clinton  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################

package Cache::SizeAwareCacheTester;

use strict;
use Cache::BaseCacheTester;
use Cache::Cache;

use vars qw( @ISA );

@ISA = qw ( Cache::BaseCacheTester );


sub test
{
  my ( $self, $cache ) = @_;

  $self->_test_one( $cache );
  $self->_test_two( $cache );
  $self->_test_three( $cache );
}


# Test the limit_size( ) method, which should automatically purge the
# first object added (with the closer expiration time)

sub _test_one
{
  my ( $self, $cache ) = @_;

  $cache or
    croak( "cache required" );

  $cache->clear( );

  my $empty_size = $cache->size( );

  ( $empty_size == 0 ) ?
    $self->ok( ) : $self->not_ok( '$empty_size == 0' );

  my $first_key = 'Key 1';

  my $first_expires_in = '10';

  my $value = $self;

  $cache->set( $first_key, $value, $first_expires_in );

  my $first_size = $cache->size( );

  ( $first_size > $empty_size ) ?
    $self->ok( ) : $self->not_ok( '$first_size > $empty_size' );

  my $size_limit = $first_size;

  my $second_key = 'Key 2';

  my $second_expires_in = $first_expires_in * 2;

  $cache->set( $second_key, $value, $second_expires_in );

  my $second_size = $cache->size( );

  ( $second_size > $first_size ) ?
    $self->ok( ) : $self->not_ok( '$second_size > $first_size' );

  $cache->limit_size( $size_limit );

  my $first_value = $cache->get( $first_key );

  ( not defined $first_value ) ?
    $self->ok( ) : $self->not_ok( 'not defined $first_value' );

  my $third_size = $cache->size( );

  ( $third_size <= $size_limit ) ?
    $self->ok( ) : $self->not_ok( '$third_size <= $size_limit' );
}



# Test the limit_size method when a number of objects can expire
# simultaneously

sub _test_two
{
  my ( $self, $cache ) = @_;

  $cache or
    croak( "cache required" );

  $cache->clear( );

  my $empty_size = $cache->size( );

  ( $empty_size == 0 ) ?
    $self->ok( ) : $self->not_ok( '$empty_size == 0' );

  my $value = "A very short string";

  my $first_key = 'Key 0';

  my $first_expires_in = 20;

  $cache->set( $first_key, $value, $first_expires_in );

  my $first_size = $cache->size( );

  ( $first_size > $empty_size ) ?
    $self->ok( ) : $self->not_ok( '$first_size > $empty_size' );

  my $second_expires_in = $first_expires_in / 2;

  my $num_keys = 5;

  for ( my $i = 1; $i <= $num_keys; $i++ )
  {
    my $key = 'Key ' . $i;

    sleep ( 1 );

    $cache->set( $key, $value, $second_expires_in );
  }

  my $second_size = $cache->size( );

  ( $second_size > $first_size ) ?
    $self->ok( ) : $self->not_ok( '$second_size > $first_size' );

  my $size_limit = $first_size;

  $cache->limit_size( $size_limit );

  my $third_size = $cache->size( );

  ( $third_size <= $size_limit ) ?
    $self->ok( ) : $self->not_ok( '$third_size <= $size_limit' );

  my $first_value = $cache->get( $first_key );

  ( $first_value eq $value ) ?
    $self->ok( ) : $self->not_ok( '$first_value eq $value' );

}


# Test the max_size( ) method, which should keep the cache under
# the given size

sub _test_three
{
  my ( $self, $cache ) = @_;

  $cache or
    croak( "cache required" );

  $cache->clear( );

  my $empty_size = $cache->size( );

  ( $empty_size == 0 ) ?
    $self->ok( ) : $self->not_ok( '$empty_size == 0' );

  my $first_key = 'Key 1';

  my $value = $self;

  $cache->set( $first_key, $value );

  my $first_size = $cache->size( );

  ( $first_size > $empty_size ) ?
    $self->ok( ) : $self->not_ok( '$first_size > $empty_size' );

  my $max_size = $first_size;

  $cache->set_max_size( $max_size );

  my $second_key = 'Key 2';

  $cache->set( $second_key, $value );

  my $second_size = $cache->size( );

  ( $second_size <= $max_size ) ?
    $self->ok( ) : $self->not_ok( '$second_size <= $max_size' );
}


1;


__END__

=pod

=head1 NAME

Cache::SizeAwareCacheTester -- a class for regression testing size aware caches

=head1 DESCRIPTION

The SizeCacheTester is used to verify that a cache implementation honors
its contract with respect to resizing capabilities

=head1 SYNOPSIS

  use Cache::SizeAwareMemoryCache;
  use Cache::SizeAwareCacheTester;

  my $cache = new Cache::SizeAwareMemoryCache( );

  my $cache_tester = new Cache::SizeAwareCacheTester( 1 );

  $cache_tester->test( $cache );

=head1 METHODS

=over

=item B<new( $initial_count )>

Construct a new SizeAwareCacheTester object, with the counter starting
at I<$initial_count>.

=item B<test( )>

Run the tests.

=back

=head1 SEE ALSO

Cache::Cache, Cache::BaseCacheTester, Cache::CacheTester

=head1 AUTHOR

Original author: DeWitt Clinton <dewitt@unto.net>

Last author:     $Author: dclinton $

Copyright (C) 2001-2003 DeWitt Clinton

=cut
