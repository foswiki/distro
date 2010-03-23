######################################################################
# $Id: SizeAwareMemoryCache.pm,v 1.18 2002/04/07 17:04:46 dclinton Exp $
# Copyright (C) 2001-2003 DeWitt Clinton  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################


package Cache::SizeAwareMemoryCache;


use strict;
use vars qw( @ISA );
use Cache::Cache;
use Cache::CacheSizer;
use Cache::MemoryCache;
use Cache::SizeAwareCache qw( $NO_MAX_SIZE );


@ISA = qw ( Cache::MemoryCache Cache::SizeAwareCache );


my $DEFAULT_MAX_SIZE = $NO_MAX_SIZE;


sub Clear
{
  return Cache::MemoryCache::Clear( );
}


sub Purge
{
  return Cache::MemoryCache::Purge( );
}


sub Size
{
  return Cache::MemoryCache::Size( );
}


sub new
{
  my ( $self ) = _new( @_ );
  $self->_complete_initialization( );
  return $self;
}


sub get
{
  my ( $self, $p_key ) = @_;

  $self->_get_cache_sizer( )->update_access_time( $p_key );
  return $self->SUPER::get( $p_key );
}


sub limit_size
{
  my ( $self, $p_new_size ) = @_;

  $self->_get_cache_sizer( )->limit_size( $p_new_size );
}


sub set
{
  my ( $self, $p_key, $p_data, $p_expires_in ) = @_;

  $self->SUPER::set( $p_key, $p_data, $p_expires_in );
  $self->_get_cache_sizer( )->limit_size( $self->get_max_size( ) );
}


sub _new
{
  my ( $proto, $p_options_hash_ref ) = @_;
  my $class = ref( $proto ) || $proto;
  my $self  =  $class->SUPER::_new( $p_options_hash_ref );
  $self->_initialize_cache_sizer( );
  return $self;
}


sub _initialize_cache_sizer
{
  my ( $self ) = @_;

  my $max_size = $self->_read_option( 'max_size', $DEFAULT_MAX_SIZE );
  $self->_set_cache_sizer( new Cache::CacheSizer( $self, $max_size ) );
}


sub get_max_size
{
  my ( $self ) = @_;

  return $self->_get_cache_sizer( )->get_max_size( );
}


sub set_max_size
{
  my ( $self, $p_max_size ) = @_;

  $self->_get_cache_sizer( )->set_max_size( $p_max_size );
}


sub _get_cache_sizer
{
  my ( $self ) = @_;

  return $self->{_Cache_Sizer};
}


sub _set_cache_sizer
{
  my ( $self, $p_cache_sizer ) = @_;

  $self->{_Cache_Sizer} = $p_cache_sizer;
}


1;



__END__

=pod

=head1 NAME

Cache::SizeAwareMemoryCache -- extends Cache::MemoryCache

=head1 DESCRIPTION

The SizeAwareMemoryCache class adds the ability to dynamically limit
the size (in bytes) of a memory based cache.  This class also
implements the SizeAwareCache interface, providing the 'max_size'
option and the 'limit_size( $size )' method.

=head1 SYNOPSIS

  use Cache::SizeAwareMemoryCache;

  my $cache = 
    new Cache::SizeAwareMemoryCache( { 'namespace' => 'MyNamespace',
                                       'default_expires_in' => 600,
                                       'max_size' => 10000 } );

=head1 METHODS

See Cache::Cache and Cache::SizeAwareCache for the API documentation.

=head1 OPTIONS

See Cache::Cache and Cache::SizeAwareCache for the standard options.

=head1 PROPERTIES

See Cache::Cache and Cache::SizeAwareCache for the default properties.

=head1 SEE ALSO

Cache::Cache, Cache::SizeAwareCache, Cache::MemoryCache

=head1 AUTHOR

Original author: DeWitt Clinton <dewitt@unto.net>

Last author:     $Author: dclinton $

Copyright (C) 2001-2003 DeWitt Clinton

=cut

