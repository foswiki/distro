######################################################################
# $Id: CacheMetaData.pm,v 1.12 2002/04/07 17:04:46 dclinton Exp $
# Copyright (C) 2001-2003 DeWitt Clinton  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################

package Cache::CacheMetaData;

use strict;
use Cache::Cache qw( $EXPIRES_NOW $EXPIRES_NEVER );

#
# the cache meta data structure looks something like the following:
#
# %meta_data_hash =
#  (
#   $key_1 => [ $expires_at, $accessed_at, $object_size ],
#   $key_2 => [ $expires_at, $accessed_at, $object_size ],
#   ...
#  )
#

my $_EXPIRES_AT_OFFSET = 0;
my $_ACCESS_AT_OFFSET = 1;
my $_SIZE_OFFSET = 2;


sub new
{
  my ( $proto ) = @_;
  my $class = ref( $proto ) || $proto;
  my $self  = {};
  bless( $self, $class );
  $self->_set_meta_data_hash_ref( { } );
  $self->_set_cache_size( 0 );
  return $self;
}


sub insert
{
  my ( $self, $p_object ) = @_;

  $self->_insert_object_expires_at( $p_object );
  $self->_insert_object_accessed_at( $p_object );
  $self->_insert_object_size( $p_object );
  $self->_set_cache_size( $self->get_cache_size( ) + $p_object->get_size( ) );
}


sub remove
{
  my ( $self, $p_key ) = @_;

  $self->_set_cache_size( $self->get_cache_size( ) -
                          $self->build_object_size( $p_key ) );

  delete $self->_get_meta_data_hash_ref( )->{ $p_key };
}


sub build_removal_list
{
  my ( $self ) = @_;

  my $meta_data_hash_ref = $self->_get_meta_data_hash_ref( );

  return
    sort
    {
      my $a_expires_at  = $meta_data_hash_ref->{ $a }->[ $_EXPIRES_AT_OFFSET ];
      my $b_expires_at  = $meta_data_hash_ref->{ $b }->[ $_EXPIRES_AT_OFFSET ];
      my $a_accessed_at = $meta_data_hash_ref->{ $a }->[ $_ACCESS_AT_OFFSET  ];
      my $b_accessed_at = $meta_data_hash_ref->{ $b }->[ $_ACCESS_AT_OFFSET  ];

      if ( $a_expires_at eq $b_expires_at )
      {
        return ( $a_accessed_at <=> $b_accessed_at );
      }

      return -1 if $a_expires_at eq $EXPIRES_NOW;
      return  1 if $b_expires_at eq $EXPIRES_NOW;
      return  1 if $a_expires_at eq $EXPIRES_NEVER;
      return -1 if $b_expires_at eq $EXPIRES_NEVER;

      return ( $a_expires_at <=> $b_expires_at );

    } keys %$meta_data_hash_ref;
}



sub build_object_size
{
  my ( $self, $p_key  ) = @_;

  return $self->_get_meta_data_hash_ref( )->{ $p_key }->[ $_SIZE_OFFSET ];
}


sub _insert_object_meta_data
{
  my ( $self, $p_object, $p_offset, $p_value ) = @_;

  $self->_get_meta_data_hash_ref( )->{ $p_object->get_key( ) }->[ $p_offset ] =
    $p_value;
}


sub _insert_object_expires_at
{
  my ( $self, $p_object ) = @_;

  $self->_insert_object_meta_data( $p_object,
                                   $_EXPIRES_AT_OFFSET,
                                   $p_object->get_expires_at( ) );
}


sub _insert_object_accessed_at
{
  my ( $self, $p_object ) = @_;

  $self->_insert_object_meta_data( $p_object,
                                   $_ACCESS_AT_OFFSET,
                                   $p_object->get_accessed_at( ) );
}


sub _insert_object_size
{
  my ( $self, $p_object ) = @_;

  $self->_insert_object_meta_data( $p_object,
                                   $_SIZE_OFFSET,
                                   $p_object->get_size( ) );
}


sub get_cache_size
{
  my ( $self ) = @_;

  return $self->{_Cache_Size};
}


sub _set_cache_size
{
  my ( $self, $cache_size ) = @_;

  $self->{_Cache_Size} = $cache_size;
}


sub _get_meta_data_hash_ref
{
  my ( $self ) = @_;

  return $self->{_Meta_Data_Hash_Ref};
}


sub _set_meta_data_hash_ref
{
  my ( $self, $meta_data_hash_ref ) = @_;

  $self->{_Meta_Data_Hash_Ref} = $meta_data_hash_ref;
}


1;


__END__

=pod

=head1 NAME

Cache::CacheMetaData -- data about objects in the cache

=head1 DESCRIPTION

The CacheMetaData object is used by size aware caches to keep track of
the state of the cache and effeciently return information such as an
objects size or an ordered list of indentifiers to be removed when a
cache size is being limited.  End users will not normally use
CacheMetaData directly.

=head1 SYNOPSIS

 use Cache::CacheMetaData;

 my $cache_meta_data = new Cache::CacheMetaData( );

 foreach my $key ( $cache->get_keys( ) )
 {
    my $object = $cache->get_object( $key ) or
      next;

    $cache_meta_data->insert( $object );
  }

 my $current_size = $cache_meta_data->get_cache_size( );

 my @removal_list = $cache_meta_data->build_removal_list( );

=head1 METHODS

=over

=item B<new(  )>

Construct a new Cache::CacheMetaData object

=item B<insert( $object )>

Inform the CacheMetaData about the object I<$object> in the cache.

=item B<remove( $key )>

Inform the CacheMetaData that the object specified by I<$key> is no
longer in the cache.

=item B<build_removal_list( )>

Create a list of the keys in the cache, ordered as follows:

1) objects that expire now

2) objects expiring at a particular time, with ties broken by the time
at which they were least recently accessed

3) objects that never expire, sub ordered by the time at which they
were least recently accessed

NOTE: This could be improved further by taking the size into account
on accessed_at ties.  However, this type of tie is unlikely in normal
usage.

=item B<build_object_size( $key )>

Return the size of an object specified by I<$key>.

=back

=head1 PROPERTIES

=over

=item B<get_cache_size>

The total size of the objects in the cache

=back

=head1 SEE ALSO

Cache::Cache, Cache::CacheSizer, Cache::SizeAwareCache

=head1 AUTHOR

Original author: DeWitt Clinton <dewitt@unto.net>

Last author:     $Author: dclinton $

Copyright (C) 2001-2003 DeWitt Clinton

=cut
