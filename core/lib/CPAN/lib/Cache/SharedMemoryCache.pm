######################################################################
# $Id: SharedMemoryCache.pm,v 1.24 2004/04/24 15:46:47 dclinton Exp $
# Copyright (C) 2001-2003 DeWitt Clinton  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################


package Cache::SharedMemoryCache;


use strict;
use vars qw( @ISA );
use Cache::Cache;
use Cache::MemoryCache;
use Cache::CacheUtils qw( Assert_Defined Static_Params );
use Cache::SharedMemoryBackend;
use Error;


@ISA = qw ( Cache::MemoryCache );


sub Clear
{
  foreach my $namespace ( _Namespaces( ) )
  {
    _Get_Backend( )->delete_namespace( $namespace );
  }
}


sub Purge
{
  foreach my $namespace ( _Namespaces( ) )
  {
    _Get_Cache( $namespace )->purge( );
  }
}


sub Size
{
  my $size = 0;

  foreach my $namespace ( _Namespaces( ) )
  {
    $size += _Get_Cache( $namespace )->size( );
  }

  return $size;
}


sub _Namespaces
{
  return _Get_Backend( )->get_namespaces( );
}



sub _Get_Backend
{
  return new Cache::SharedMemoryBackend( );
}


sub _Get_Cache
{
  my ( $p_namespace ) = Static_Params( @_ );

  Assert_Defined( $p_namespace );

  return new Cache::SharedMemoryCache( { 'namespace' => $p_namespace } );
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



=pod

=head1 NAME

Cache::SharedMemoryCache -- extends the MemoryCache.

=head1 DESCRIPTION

The SharedMemoryCache extends the MemoryCache class and binds the data
store to shared memory so that separate process can use the same
cache.

The official recommendation is now to use FileCache instead of
SharedMemoryCache.  The reasons for this include:

1) FileCache provides equal or better performance in all cases that
we've been able to test.  This is due to all modern OS's ability to
buffer and cache file system accesses very well.

2) FileCache has no real limits on cached object size or the number of
cached objects, whereas the SharedMemoryCache has limits, and rather
low ones at that.

3) FileCache works well on every OS, whereas the SharedMemoryCache
works only on systems that support IPC::ShareLite.  And IPC::ShareLite
is an impressive effort -- but think about how hard it is to get
shared memory working properly on *one* system.  Now imagine writing a
wrapper around shared memory for many operating systems.


=head1 SYNOPSIS

  use Cache::SharedMemoryCache;

  my %cache_options_= ( 'namespace' => 'MyNamespace',
			'default_expires_in' => 600 );

  my $shared_memory_cache = 
    new Cache::SharedMemoryCache( \%cache_options ) or
      croak( "Couldn't instantiate SharedMemoryCache" );

=head1 METHODS

See Cache::Cache for the API documentation.

=head1 OPTIONS

See Cache::Cache for the standard options.

=head1 PROPERTIES

See Cache::Cache for the default properties.

=head1 SEE ALSO

Cache::Cache, Cache::MemoryCache

=head1 AUTHOR

Original author: DeWitt Clinton <dewitt@unto.net>

Last author:     $Author: dclinton $

Copyright (C) 2001-2003 DeWitt Clinton

=cut
