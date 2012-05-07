######################################################################
# $Id: SizeAwareSharedMemoryCache.pm,v 1.22 2002/04/07 17:04:46 dclinton Exp $
# Copyright (C) 2001-2003 DeWitt Clinton  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################


package Cache::SizeAwareSharedMemoryCache;


use strict;
use vars qw( @ISA @EXPORT_OK $NO_MAX_SIZE );
use Cache::Cache qw( $EXPIRES_NEVER );
use Cache::SharedMemoryBackend;
use Cache::SizeAwareMemoryCache;
use Cache::SharedMemoryCache;
use Exporter;


@ISA = qw ( Cache::SizeAwareMemoryCache Exporter );


@EXPORT_OK = qw( $NO_MAX_SIZE );


$NO_MAX_SIZE = $Cache::SizeAwareMemoryCache::NO_MAX_SIZE;


sub Clear
{
  return Cache::SharedMemoryCache::Clear( );
}


sub Purge
{
  return Cache::SharedMemoryCache::Purge( );
}


sub Size
{
  return Cache::SharedMemoryCache::Size( );
}


sub new
{
  my ( $self ) = _new( @_ );

  $self->_complete_initialization( );

  return $self;
}


sub _new
{
  my ( $proto, $p_options_hash_ref ) = @_;
  my $class = ref( $proto ) || $proto;
  my $self = $class->SUPER::_new( $p_options_hash_ref );
  $self->_set_backend( new Cache::SharedMemoryBackend( ) );
  return $self;
}


1;




__END__

=pod

=head1 NAME

Cache::SizeAwareSharedMemoryCache -- extends Cache::SizeAwareMemoryCache

=head1 DESCRIPTION

The SizeAwareSharedMemoryCache class adds the ability to dynamically
limit the size (in bytes) of a shared memory based cache.  This class
also implements the SizeAwareCache interface, providing the 'max_size'
option and the 'limit_size( $size )' method.

=head1 SYNOPSIS

  use Cache::SizeAwareSharedMemoryCache;

  my $cache = 
    new Cache::SizeAwareSharedMemoryCache( { 'namespace' => 'MyNamespace',
                                             'default_expires_in' => 600,
                                             'max_size' => 10000 } );

=head1 METHODS

See Cache::Cache and Cache::SizeAwareCache for the API documentation.

=head1 OPTIONS

See Cache::Cache and Cache::SizeAwareCache for the standard options.

=head1 PROPERTIES

See Cache::Cache and Cache::SizeAwareCache for the default properties.

=head1 SEE ALSO

Cache::Cache, Cache::SizeAwareCache, Cache::SharedMemoryCache

=head1 AUTHOR

Original author: DeWitt Clinton <dewitt@unto.net>

Last author:     $Author: dclinton $

Copyright (C) 2001-2003 DeWitt Clinton

=cut


