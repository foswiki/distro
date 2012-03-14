# See bottom of file for license and copyright
package Unit::Request;

=begin TML

---+ package Unit::Request

=cut

use Assert;

# SMELL: this package should not be in Unit; it is a Foswiki class and
# should be in test/unit

use Foswiki::Request;
our @ISA = qw( Foswiki::Request );

sub new {
    my $class = shift;
    my $this  = $class->SUPER::new(@_);

    # Taint everything
    foreach my $k ( @{ $this->{param_list} } ) {
        foreach my $k ( @{ $this->{param_list} } ) {
            foreach ( @{ $this->{param}{$k} } ) {
                $_ = TAINT($_) if defined $_;
            }
        }
    }
    return $this;
}

sub finish {
    my ($this) = @_;

    if ( $this->SUPER::can('finish') ) {
        $this->SUPER::finish();
    }

    return;
}

sub setUrl {
    my ( $this, $queryString ) = @_;

    #print STDERR "---- setUrl($queryString)\n";

    my $path      = $queryString;
    my $urlParams = '';
    if ( $queryString =~ /(.*)\?(.*)/ ) {
        $path      = $1;
        $urlParams = $2;
    }

    if ($path =~ /(https?):\/\/(.*?)\//) {
        my $protocol = $1;
        my $host = $2;
        if ($protocol =~ /https/i) {
         $this->secure(1);
        } else {
            $this->secure(0);
        }
        print STDERR "setting Host to $host\n";
        $this->header(-name=>'Host', -value=>$host);
    }

    my @pairs = split /[&;]/, $urlParams;
    my ( $param, $value, %params, @plist );
    foreach (@pairs) {
        ( $param, $value ) =
          map { tr/+/ /; s/%([0-9a-fA-F]{2})/chr(hex($1))/oge; $_ }
          split '=', $_, 2;
        push @{ $params{$param} }, $value;
        push @plist, $param;
    }
    foreach my $param (@plist) {
        $this->queryParam( $param, $params{$param} );

        #print STDERR "\t setting $param, ".join(',', @{$params{$param}})."\n";
    }
    $this->path_info( Foswiki::Sandbox::untaintUnchecked($path) );

    #print STDERR "pathinfo = $path\n";
}

1;

__DATA__

Author: Gilmar Santos Jr

Copyright (C) 2008-2010 Foswiki Contributors

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
