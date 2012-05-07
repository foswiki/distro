######################################################################
# $Id: MemoryCache.pm,v 1.27 2002/04/07 17:04:46 dclinton Exp $
# Copyright (C) 2001-2003 DeWitt Clinton  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################


package Cache::MemoryCache;


use strict;
use vars qw( @ISA );
use Cache::BaseCache;
use Cache::Cache qw( $EXPIRES_NEVER );
use Cache::CacheUtils qw( Assert_Defined Static_Params );
use Cache::MemoryBackend;

@ISA = qw ( Cache::BaseCache );


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


sub _Get_Backend
{
  return new Cache::MemoryBackend( );
}


sub _Namespaces
{
  return _Get_Backend( )->get_namespaces( );
}


sub _Get_Cache
{
  my ( $p_namespace ) = Static_Params( @_ );

  Assert_Defined( $p_namespace );

  return new Cache::MemoryCache( { 'namespace' => $p_namespace } );
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
  $self->_set_backend( new Cache::MemoryBackend( ) );
  return $self;
}


1;


__END__

=pod

=head1 NAME

Cache::MemoryCache -- implements the Cache interface.

=head1 DESCRIPTION

The MemoryCache class implements the Cache interface.  This cache
stores data on a per-process basis.  This is the fastest of the cache
implementations, but data can not be shared between processes with the
MemoryCache.  However, the data will remain in the cache until
cleared, it expires, or the process dies.  The cache object simply
going out of scope will not destroy the data.

=head1 SYNOPSIS

  use Cache::MemoryCache;

  my $cache = new Cache::MemoryCache( { 'namespace' => 'MyNamespace',
                                        'default_expires_in' => 600 } );

  See Cache::Cache for the usage synopsis.

=head1 METHODS

See Cache::Cache for the API documentation.

=head1 OPTIONS

See Cache::Cache for standard options.

=head1 PROPERTIES

See Cache::Cache for default properties.

=head1 SEE ALSO

Cache::Cache

=head1 AUTHOR

Original author: DeWitt Clinton <dewitt@unto.net>

Last author:     $Author: dclinton $

Copyright (C) 2001-2003 DeWitt Clinton

=cut
