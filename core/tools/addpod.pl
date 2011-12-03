#!/usr/bin/perl -w

# addpod.pl - tool to add TWiki-style POD function doc headers
#
# Copyright (C) 1999-2004 Peter Thoeny, peter@thoeny.com
#
# For licensing info read license.txt file in the TWiki root.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

use strict;

undef $/;
$_ = <ARGV>;
$/ = "\n";

@subs = /^sub (\w*)\s*{?\s*$/gm;
foreach $sub (@subs) {
    print STDERR "Processing $sub...";
    $space = "[\n[:space:]]";
    if (
        /^=cut[^\n]*[\n]                # =cut (end of POD)
	(?: $space* \# [^\n]* [\n] )*   # comments
	$space*                         # spacing
	[\n]sub \s* $sub\s*{?\s*$/mx
      )
    {    # subroutine declaration
        print STDERR "already has doc header.\n";
        next;
    }
    else {
        print STDERR "adding doc header.\n";
    }
    if (
        /^sub \s* $sub $space*           # sub blah
          { $space*                      # {
	     (?: $space* \# [^\n]* \n )* # comments
	     $space*                     # spacing
	     my \s* \( (.*) \)/mx
      )
    {    # parameters
        $params = "( $1 )";
    }
    else {
        $params = "()";
    }
    $pod = <<ENDPOD;
=pod

---++ sub $sub $params

Not yet documented.

=cut

ENDPOD
    s/^sub $sub(\s*{?\s*)$/${pod}sub $sub$1/m;
}

print $_;

