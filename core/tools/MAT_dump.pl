#!env perl

use v5.14;
use strict;
use warnings;

package OutLevel;

use Moo;
use namespace::clean;

our $level = 0;

sub BUILD {
    $level++;
}

sub DEMOLISH {
    $level--;
}

sub out {
    my $this = shift;

    my $prefix = sprintf( "%03d: ", $level ) . "| " x $level;
    my @lines = map { $prefix . $_ . "\n" } split /\n/s, join( '', @_ );
    return print @lines;
}

sub level {
    return $level;
}

package ObjDumper;

use Moo;
use namespace::clean;

use constant MAX_OUT_LEVELS => 60;

has obj          => ( is => 'rw' );
has level        => ( is => 'ro', default => sub { return OutLevel->new; }, );
has checkedAddrs => ( is => 'rw', lazy => 1, default => sub { {} }, );

sub dump {
    my $this = shift;

    my $checkedAddrs = $this->checkedAddrs;

    my $objAddr = sprintf( "%016x", $this->obj->addr );

    my $type = ref( $this->obj );
    $type =~ s/^Devel::MAT::SV:://;
    $this->level->out( ">>> OBJECT TYPE: ", $type, " ADDR:", $objAddr );

    if ( $checkedAddrs->{$objAddr} ) {
        $this->level->out(
            "!!! ADDR ", $objAddr,
            " has been seen before at level ",
            $checkedAddrs->{$objAddr}
        );
        return;
    }

    $checkedAddrs->{$objAddr} = $this->level->level;

    if ( $this->level->level > MAX_OUT_LEVELS ) {
        $this->level->out( "Cut off by max number of out levels ",
            MAX_OUT_LEVELS );
        return;
    }

    $type ||= "SV";

    my $s_method = "stringify_" . $type;
    my $d_method = "dump_" . $type;

    unless ( $this->can($s_method) ) {
        $this->level->out( "!!! No dump method for object type ",
            $type, ", using default SV" );
        $s_method = "stringify_SV";
    }
    $this->level->out( $this->$s_method );
    if ( $this->can($d_method) ) {
        $this->$d_method;
    }
    $this->dump_inrefs;
}

sub stringify_SV {
    my $this = shift;

    my $obj   = $this->obj;
    my $stash = $obj->blessed;

    my $backrefs = $obj->backrefs;
    my $elems =
      $backrefs
      ? ( $backrefs->isa('Devel::MAT::SV::AV') ? $backrefs->elems : 1 )
      : 0;
    my ($name) = ('');
    if ($stash) {
        $name = "NAME: " . $stash->name . "; " . ( $stash ? "BLESSED; " : "" );
    }
    return
        $name
      . "REFCNT: "
      . $obj->refcnt
      . "; adjusted REFCNT: "
      . $obj->refcount_adjusted
      . "; by elements in backrefs: "
      . $elems
      . "; INREFS: "
      . scalar( $obj->inrefs )
      . " (direct:"
      . scalar( $obj->inrefs_direct )
      . "; strong: "
      . scalar( $obj->inrefs_strong )
      . "; weak: "
      . scalar( $obj->inrefs_weak ) . ")";
}

sub stringify_ARRAY {
    my $this = shift;
    my $obj  = $this->obj;

    my @elems = $obj->elems;
    return $this->stringify_SV . "; ", ( $obj->is_unreal ? "UNREAL" : "REAL" ),
      ( $obj->is_backrefs ? ", BACKREFS" : "" ), "; ELEMS: ", scalar(@elems);
}

sub stringify_HASH {
    my $this = shift;

    my $obj  = $this->obj;
    my @keys = $obj->keys;
    my ( $file, $line );
    foreach my $key (@keys) {
        if ( $key =~ /^(__orig_file|__orig_line)$/ ) {
            my $val         = $obj->value($key);
            my $valIsSCALAR = $val->isa('Devel::MAT::SV::SCALAR');

            #$this->level->out( $key, ":",
            #    ( $valIsSCALAR ? "" : " non-scalar value (" . ref($val) . ")" )
            #);
            #my $dumper = ObjDumper->new( obj => $obj->value($key) );
            #$dumper->dump;
            if ($valIsSCALAR) {
                if ( $key eq '__orig_file' ) {
                    $file = $val->pv;
                }
                if ( $key eq '__orig_line' ) {
                    $line = $obj->value($key)->uv;
                }
            }
        }
    }
    return
        $this->stringify_SV . "\n"
      . "KEYS: "
      . join( ", ", @keys )
      . (
        defined $file
        ? "\nORIG: " . $file . ( defined $line ? ":$line" : "" )
        : ""
      );
}

sub stringify_SCALAR {
    my $this = shift;

    my $obj   = $this->obj;
    my $svStr = $this->stringify_SV . "\n";

    foreach my $field (qw(uv iv nv pv pvlen qq_pv)) {
        my $method = $obj->can($field);
        if ($method) {
            my $val = $method->($obj) // '*undef*';
            $svStr .= uc($field) . ": " . $val . "; ";
        }
    }
    return $svStr;
}

sub stringify_GLOB {
    my $this = shift;

    my $obj   = $this->obj;
    my $stash = $obj->stash;

    return
        $this->stringify_SV
      . "\nAT: "
      . $obj->file . ":"
      . $obj->line
      . "; STASH "
      . (
          $stash
        ? $obj->stash->type . "(" . $obj->stash->desc . ")"
        : "*NONE*"
      );
}

sub stringify_REF {
    my $this = shift;

    my $obj = $this->obj;

    my $rv = $obj->rv;

    return
        $this->stringify_SV . "; "
      . ( $obj->is_weak ? "WEAK" : "STRONG" )
      . " to object type "
      . $rv->type . "("
      . ref($rv) . ")";
}

sub dump_inrefs {
    my $this = shift;

    my $obj = $this->obj;

    my @strongRef = $obj->inrefs_strong;

    $this->level->out( "+++ INREFS:", scalar(@strongRef) );

    my %seen;
    my $count = 0;
    foreach my $sref (@strongRef) {
        my $sref_sv = $sref->sv;
        next unless defined $sref_sv;

        my $objAddr = sprintf( "%016x", $this->obj->addr );

        if ( $seen{$objAddr} ) {
            $this->level->out( "!!! OBJECT ADDR ",
                $objAddr, " has been seen already on this level." );
            next;
        }
        $seen{$objAddr} = 1;

        my %checkedAddrs = %{ $this->checkedAddrs };
        my $dumper =
          ObjDumper->new( obj => $sref_sv, checkedAddrs => \%checkedAddrs, );
        $dumper->dump;
    }
}

package main;
use Devel::MAT;
use Devel::MAT::Tool;
use Devel::MAT::Tool::Inrefs;
use Data::Dumper;
use Getopt::Long;
use Carp;

$| = 1;

my %args;

GetOptions( \%args, "stash=s" );

my $pmat_file = shift @ARGV
  // $ENV{FOSWIKI_HOME} . '/working/logs/FOSWIKI.pmat';

$SIG{__DIE__} = sub {
    Carp::confess(@_);
};

my $pattern = $args{stash} // '.';

say "Loading $pmat_file ...";

my $pmat = Devel::MAT->load($pmat_file);
$pmat->load_tool('Inrefs');
$pmat->load_tool('Identify');
my $df = $pmat->dumpfile;

my $count = 0;
my $found = 0;
foreach my $sv ( $df->heap ) {
    my $stash;
    next unless $stash = $sv->blessed;
    next unless $stash->name =~ /$pattern/;
    $found++;
    my $dumper = ObjDumper->new( obj => $sv );
    $dumper->dump;
}

print " " x 80, "\r";

say "Total found: ", $found;

exit;
