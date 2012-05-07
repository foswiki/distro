######################################################################
# $Id: NullCache.pm,v 1.7 2002/07/18 06:15:18 dclinton Exp $
# Copyright (C) 2001 Jay Sachs, 2002 DeWitt Clinton All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################


package Cache::NullCache;

use strict;
use vars qw( @ISA );
use Cache::BaseCache;
use Cache::Cache qw( $EXPIRES_NOW  );

@ISA = qw ( Cache::BaseCache );


sub Clear
{
}


sub Purge
{
}


sub Size
{
  return 0;
}


sub new
{
  my ( $proto ) = @_;

  return bless( {}, ref( $proto ) || $proto );
}


sub clear
{
}


sub get
{
  return undef;
}


sub get_object
{
  return undef;
}


sub purge
{
}


sub remove
{
}


sub set
{
}


sub set_object
{
}


sub size
{
  return 0;
}


sub get_default_expires_in
{
  return $EXPIRES_NOW;
}


sub get_keys
{
  return ( );
}


sub get_identifiers
{
  warn( "get_identifiers has been marked deprepricated.  use get_keys" );

  return ( );
}


sub get_auto_purge_interval
{
  return 0;
}


sub set_auto_purge_interval
{
}


sub get_auto_purge_on_set
{
  return 0;
}


sub set_auto_purge_on_set
{
}


sub get_auto_purge_on_get
{
  return 0;
}


sub set_auto_purge_on_get
{
}


__END__

=pod

=head1 NAME

Cache::NullCache -- implements the Cache interface.

=head1 DESCRIPTION

The NullCache class implements the Cache::Cache interface, but does
not actually persist data.  This is useful when developing and
debugging a system and you wish to easily turn off caching.  As a
result, all calls to get and get_object will return undef.

=head1 SYNOPSIS

  use Cache::NullCache;

  my $cache = new Cache::NullCache( );

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

Original author: Jay Sachs

Last author:     $Author: dclinton $

Copyright (C) 2001 Jay Sachs, 2002 DeWitt Clinton

=cut

