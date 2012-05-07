######################################################################
# $Id: SizeAwareCache.pm,v 1.10 2002/04/07 17:04:46 dclinton Exp $
# Copyright (C) 2001-2003 DeWitt Clinton  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################


package Cache::SizeAwareCache;


use strict;
use Cache::Cache;
use vars qw( @ISA @EXPORT_OK $EXPIRES_NOW $EXPIRES_NEVER $NO_MAX_SIZE );
use Exporter;

@ISA = qw( Cache::Cache Exporter );

@EXPORT_OK = qw( $EXPIRES_NOW $EXPIRES_NEVER $NO_MAX_SIZE );

$EXPIRES_NOW = $Cache::Cache::EXPIRES_NOW;
$EXPIRES_NEVER = $Cache::Cache::EXPIRES_NEVER;
$NO_MAX_SIZE = -1;


sub limit_size;

sub get_max_size;

sub set_max_size;


1;


__END__


=pod

=head1 NAME

Cache::SizeAwareCache -- extends the Cache interface.

=head1 DESCRIPTION

The SizeAwareCache interface is implemented by classes that support
all of the Cache::Cache interface in addition to the limit_size and
max_size features of a size aware cache.

The default cache size limiting algorithm works by removing cache
objects in the following order until the desired limit is reached:

  1) objects that have expired
  2) objects that are least recently accessed
  3) objects that that expire next

=head1 SYNOPSIS

  use Cache::SizeAwareCache;
  use vars qw( @ISA );

  @ISA = qw( Cache::SizeAwareCache );

=head1 CONSTANTS

Please see Cache::Cache for standard constants

=over

=item I<$NO_MAX_SIZE>

The cache has no size restrictions

=back

=head1 METHODS

Please see Cache::Cache for the standard methods

=over

=item B<limit_size( $new_size )>

Attempt to resize the cache such that the total disk usage is under
the I<$new_size> parameter.  I<$new_size> represents t size (in bytes)
that the cache should be limited to.  Note that this is only a one
time adjustment.  To maintain the cache size, consider using the
I<max_size> option, although it is considered very expensive, and can
often be better achieved by peridocally calling I<limit_size>.

=back

=head1 OPTIONS

Please see Cache::Cache for the standard options

=over

=item I<max_size>

Sets the max_size property (size in bytes), which is described in
detail below.  Defaults to I<$NO_MAX_SIZE>.

=back

=head1 PROPERTIES

Please see Cache::Cache for standard properties

=over

=item B<(get|set)_max_size>

If this property is set, then the cache will try not to exceed the max
size value (in bytes) specified.  NOTE: This causes the size of the
cache to be checked on every set, and can be considered *very*
expensive in some implementations.  A good alternative approach is
leave max_size as $NO_MAX_SIZE and to periodically limit the size of
the cache by calling the limit_size( $size ) method.

=back

=head1 SEE ALSO

Cache::Cache

=head1 AUTHOR

Original author: DeWitt Clinton <dewitt@unto.net>

Last author:     $Author: dclinton $

Copyright (C) 2001-2003 DeWitt Clinton

=cut
