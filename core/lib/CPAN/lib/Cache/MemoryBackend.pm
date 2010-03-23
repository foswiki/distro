######################################################################
# $Id: MemoryBackend.pm,v 1.10 2003/01/16 18:10:16 dclinton Exp $
# Copyright (C) 2001-2003 DeWitt Clinton  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################

package Cache::MemoryBackend;

use strict;
use Cache::CacheUtils qw( Clone_Data );


my $Store_Ref = { };


sub new
{
  my ( $proto ) = @_;
  my $class = ref( $proto ) || $proto;
  my $self  = {};
  $self = bless( $self, $class );
  $self->_initialize_memory_backend( );
  return $self;
}


sub delete_key
{
  my ( $self, $p_namespace, $p_key ) = @_;

  delete $self->_get_store_ref( )->{ $p_namespace }{ $p_key };
}


sub delete_namespace
{
  my ( $self, $p_namespace ) = @_;

  delete $self->_get_store_ref( )->{ $p_namespace };
}


sub get_keys
{
  my ( $self, $p_namespace ) = @_;

  return keys %{ $self->_get_store_ref( )->{ $p_namespace } };
}


sub get_namespaces
{
  my ( $self ) = @_;

  return keys %{ $self->_get_store_ref( ) };
}


sub get_size
{
  my ( $self, $p_namespace, $p_key ) = @_;

  if ( exists $self->_get_store_ref( )->{ $p_namespace }{ $p_key } )
  {
    return length $self->_get_store_ref( )->{ $p_namespace }{ $p_key };
  }
  else
  {
    return 0;
  }
}


sub restore
{
  my ( $self, $p_namespace, $p_key ) = @_;

  return Clone_Data( $self->_get_store_ref( )->{ $p_namespace }{ $p_key } );
}


sub store
{
  my ( $self, $p_namespace, $p_key, $p_data ) = @_;

  $self->_get_store_ref( )->{ $p_namespace }{ $p_key } = $p_data;
}


sub _initialize_memory_backend
{
  my ( $self ) = @_;

  if ( not defined $self->_get_store_ref( ) )
  {
    $self->_set_store_ref( { } );
  }
}


sub _get_store_ref
{
  return $Store_Ref;
}


sub _set_store_ref
{
  my ( $self, $p_store_ref ) = @_;

  $Store_Ref = $p_store_ref;
}



1;

__END__

=pod

=head1 NAME

Cache::MemoryBackend -- a memory based persistance mechanism

=head1 DESCRIPTION

The MemoryBackend class is used to persist data to memory

=head1 SYNOPSIS

  my $backend = new Cache::MemoryBackend( );

  See Cache::Backend for the usage synopsis.

=head1 METHODS

See Cache::Backend for the API documentation.

=head1 SEE ALSO

Cache::Backend, Cache::FileBackend, Cache::ShareMemoryBackend

=head1 AUTHOR

Original author: DeWitt Clinton <dewitt@unto.net>

Last author:     $Author: dclinton $

Copyright (C) 2001-2003 DeWitt Clinton

=cut

