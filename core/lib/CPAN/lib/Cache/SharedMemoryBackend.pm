######################################################################
# $Id: SharedMemoryBackend.pm,v 1.7 2003/04/15 14:46:23 dclinton Exp $
# Copyright (C) 2001-2003 DeWitt Clinton  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################

package Cache::SharedMemoryBackend;

use strict;
use Cache::CacheUtils qw( Assert_Defined Freeze_Data Static_Params Thaw_Data );
use Cache::MemoryBackend;
use IPC::ShareLite qw( LOCK_EX LOCK_UN );

use vars qw( @ISA );

@ISA = qw ( Cache::MemoryBackend );


my $IPC_IDENTIFIER = 'ipcc';


sub new
{
  my ( $proto ) = @_;
  my $class = ref( $proto ) || $proto;
  return $class->SUPER::new( );
}


sub delete_key
{
  my ( $self, $p_namespace, $p_key ) = @_;

  my $store_ref = $self->_get_locked_store_ref( );

  delete $store_ref->{ $p_namespace }{ $p_key };

  $self->_set_locked_store_ref( $store_ref );
}


sub delete_namespace
{
  my ( $self, $p_namespace ) = @_;

  my $store_ref = $self->_get_locked_store_ref( );

  delete $store_ref->{ $p_namespace };

  $self->_set_locked_store_ref( $store_ref );
}


sub store
{
  my ( $self, $p_namespace, $p_key, $p_data ) = @_;

  my $store_ref = $self->_get_locked_store_ref( );

  $store_ref->{ $p_namespace }{ $p_key } = $p_data;

  $self->_set_locked_store_ref( $store_ref );
}


# create a IPC::ShareLite share under the ipc_identifier

sub _Instantiate_Share
{
  my ( $p_ipc_identifier ) = Static_Params( @_ );

  Assert_Defined( $p_ipc_identifier );

  my %ipc_options = (
                     -key       =>  $p_ipc_identifier,
                     -create    => 'yes',
                     -destroy   => 'no',
                     -exclusive => 'no'
                    );

  my $share = new IPC::ShareLite( %ipc_options ) or
    throw Error::Simple( "Couldn't instantiate IPC::ShareLite: $!" );

  return $share;
}


# this method uses the shared created by Instantiate_Share to
# transparently retrieve a reference to a shared hash structure

sub _Restore_Shared_Hash_Ref
{
  my ( $p_ipc_identifier ) = Static_Params( @_ );

  Assert_Defined( $p_ipc_identifier );

  my $frozen_hash_ref = _Instantiate_Share( $p_ipc_identifier )->fetch( ) or
    return { };

  return Thaw_Data( $frozen_hash_ref );
}


# this method uses the shared created by Instantiate_Share to
# transparently retrieve a reference to a shared hash structure, and
# additionally exlusively locks the share

sub _Restore_Shared_Hash_Ref_With_Lock
{
  my ( $p_ipc_identifier ) = Static_Params( @_ );

  Assert_Defined( $p_ipc_identifier );

  my $share = _Instantiate_Share( $p_ipc_identifier );

  $share->lock( LOCK_EX );

  my $frozen_hash_ref = $share->fetch( ) or
    return { };

  return Thaw_Data( $frozen_hash_ref );
}


# this method uses the shared created by Instantiate_Share to
# transparently persist a reference to a shared hash structure

sub _Store_Shared_Hash_Ref
{
  my ( $p_ipc_identifier, $p_hash_ref ) = @_;

  Assert_Defined( $p_ipc_identifier );
  Assert_Defined( $p_hash_ref );

  _Instantiate_Share( $p_ipc_identifier )->store( Freeze_Data( $p_hash_ref ) );
}


# this method uses the shared created by Instantiate_Share to
# transparently persist a reference to a shared hash structure and
# additionally unlocks the share

sub _Store_Shared_Hash_Ref_And_Unlock
{
  my ( $p_ipc_identifier, $p_hash_ref ) = @_;

  Assert_Defined( $p_ipc_identifier );
  Assert_Defined( $p_hash_ref );

  my $share = _Instantiate_Share( $p_ipc_identifier );

  $share->store( Freeze_Data( $p_hash_ref ) );

  $share->unlock( LOCK_UN );
}


sub _get_locked_store_ref
{
  return _Restore_Shared_Hash_Ref_With_Lock( $IPC_IDENTIFIER );
}


sub _set_locked_store_ref
{
  my ( $self, $p_store_ref ) = @_;

  _Store_Shared_Hash_Ref_And_Unlock( $IPC_IDENTIFIER, $p_store_ref );
}


sub _get_store_ref
{
  return _Restore_Shared_Hash_Ref( $IPC_IDENTIFIER );
}


sub _set_store_ref
{
  my ( $self, $p_store_ref ) = @_;

  _Store_Shared_Hash_Ref( $IPC_IDENTIFIER, $p_store_ref );
}



1;


__END__

=pod

=head1 NAME

Cache::SharedMemoryBackend -- a shared memory based persistance mechanism

=head1 DESCRIPTION

The SharedMemoryBackend class is used to persist data to shared memory

=head1 SYNOPSIS

  my $backend = new Cache::SharedMemoryBackend( );

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
