# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Configure::SaveLSC

This is a serialisation visitor for writing out changes
to LocalSite.cfg

=cut

package Foswiki::Configure::SaveLSC;

use strict;
use warnings;

use Foswiki::Configure       ();
use Foswiki::Configure::Load ();

use Data::Dumper ();

use Foswiki::Configure::Visitor ();
our @ISA = ('Foswiki::Configure::Visitor');

our @errors;    # For external parsers.
our @warnings;

my %dupItem;

=begin TML

---++ ClassMethod new()

Used in saving, when we need a callback. Otherwise the methods here are
all static.

=cut

sub new {
    my $class = shift;

    return bless( {}, $class );
}

=begin TML

---++ StaticMethod save($root, $valuer, $logger, $insane)
   * $root is a Foswiki::Configure::Root
   * $valuer is a Foswiki::Configure::Valuer
   * $logger an object that implements a logChange($keys,$value) method,
     called to record the changes.
   * $insane set to true if existing LocalSite.cfg should be overwritten

Generate .cfg file format output

=cut

sub save {
    my ( $root, $valuer, $logger, $insane ) = @_;

    # Object used to act as a visitor to hold the output
    my $this = new Foswiki::Configure::SaveLSC();
    $this->{logger}  = $logger;
    $this->{valuer}  = $valuer;
    $this->{root}    = $root;
    $this->{content} = '';

    my $lsc = Foswiki::Configure::FileUtil::lscFileName();

    my ( @backups, $backup );

    # while loop used just so it can use 'last' :-(
    while ( -f $lsc ) {
        if ( open( F, '<', $lsc ) ) {
            local $/ = undef;
            $this->{content} = <F>;
            close(F);
        }
        else {
            last if ( $!{ENOENT} );    # Race: file disappeared
            die "Unable to read $lsc: $!\n";    # Serious error
        }

        $Foswiki::cfg{MaxLSCBackups} ||= 0;

        last unless ( $Foswiki::cfg{MaxLSCBackups} );

        # Save backup copy of current configuration (even if insane)

        require Errno;
        require Fcntl;
        Fcntl->import(qw/:DEFAULT/);
        require File::Spec;

        my ( $mode, $uid, $gid, $atime, $mtime ) = ( stat(_) )[ 2, 4, 5, 8, 9 ];

        # Find a reasonable starting point for the new backup's name

        my $n = 0;
        my ( $vol, $dir, $file ) = File::Spec->splitpath($lsc);
        $dir = File::Spec->catpath( $vol, $dir, 'x' );
        chop $dir;
        if ( opendir( my $d, $dir ) ) {
            @backups =
              sort { $b <=> $a }
              map { /^$file\.(\d+)$/ ? ($1) : () } readdir($d);
            my $last = $backups[0];
            $n = $last if ( defined $last );
            $n++;
            closedir($d);
        }
        else {
            $n = 1;
            unshift @backups, $n++ while ( -e "$lsc.$n" );
        }

        # Find the actual filename and open for write

        my $open;
        my $um = umask(0);
        unshift @backups, $n++
          while (
            !(
                $open = sysopen( F, "$lsc.$n",
                    O_WRONLY() | O_CREAT() | O_EXCL(), $mode & 07777
                )
            )
            && $!{EEXIST}
          );
        if ($open) {
            $backup = "$lsc.$n";
            unshift @backups, $n;
            print F $this->{content};
            close(F);
            utime $atime, $mtime, $backup;
            chown $uid, $gid, $backup;
        }
        else {
            die "Unable to open $lsc.$n for write: $!\n";
        }
        umask($um);
        last;
    }

    $this->{oldContent} = $this->{content} || '';

    if ( $insane || !-f $lsc ) {
        $this->{content} = <<'HERE';
# Local site settings for Foswiki. This file is managed by the 'configure'
# CGI script, though you can also make (careful!) manual changes with a
# text editor.  See the Foswiki.spec file in this directory for documentation
# Extensions are documented in the Config.spec file in the Plugins/<extension>
# or Contrib/<extension> directories  (Do not remove the following blank line.)

HERE
    }

    # Clean out deprecated settings, so they don't occlude the
    # replacements
    {
        no warnings 'once';
        foreach my $key ( keys %Foswiki::Configure::Load::remap ) {
            $this->{content} =~ s/\$Foswiki::cfg$key\s*=.*?;\s*//sg;
        }
    }

    # Sort keys so it's possible to diff LSC files.
    local $Data::Dumper::Sortkeys = 1;

    $this->_save();

    my $msg = '';

    if ( ( $this->{content} || '' ) ne $this->{oldContent} ) {
        my $um = umask(007);   # Contains passwords, no world access to new file
        open( F, '>', $lsc )
          || die "Could not open $lsc for write: $!\n";
        print F $this->{content};
        close(F) or die "Close failed for $lsc: $!\n";
        umask($um);
        if ( $backup && ( my $max = $Foswiki::cfg{MaxLSCBackups} ) >= 0 ) {
            while ( @backups > $max ) {
                my $n = pop @backups;
                unlink "$lsc.$n";
            }
            $msg = "<br />Previous configuration saved in $backup\n";
        }
        $msg = "New configuration saved in $lsc\n$msg";
    }
    else {
        unlink $backup if ($backup);
        $msg = "No change made to $lsc\n";
    }
    delete $this->{oldContent};
    return $msg;
}

sub _save {
    my $this = shift;

    %dupItem = ();
    my %requires;

    $this->{content} =~ s/^\s*1;\s*\n//msg;
    $this->{content} =~ s/^\s*require\s+([^;]+);\n/$requires{$1} = 1; ''/msge;

    $this->{requires} = \%requires;

    # Sort the resulting data by hash key.  Attaches any comments to the
    # following item.  Requires blank line after header to differentiate
    # file block comment from comment on first item.  Alternate (old
    # standard) is to leave (mostly) in .spec file order.
    # Turning this on may have compatibility issues, and I'm not sure what
    # it gains. The consequences are more worrisome than the mechanics...

    if (0) {
        my $header = '';
        my @content = split( /\r?\n/, $this->{content} );

        while ( @content && $content[0] =~ /^\s*#/ ) {
            $header .= "$content[0]\n";
            shift @content;
        }
        if ( @content && $content[0] =~ /^\s*$/ ) {
            $header .= "$content[0]\n";
            shift @content;
        }

        my $content;
        if (@content) {
            $content = join( "\n", @content ) . "\n";
        }
        else {
            $content = '';
        }
        $this->{content} = $content;
        @content = ();

        $this->{root}->visit($this);

        my %content;
        $content = $this->{content};
        $content =~
s/\A(.*?^\s*?\$(?:Foswiki::)?cfg($Foswiki::Configure::Load::ITEMREGEX)\s*=.*?;\n)/push @content, $2; $content{$2} = $1;''/msge;

        my $trailer = $content;

        $content = $header;
        $content .= "require $_;\n" foreach ( sort keys %requires );
        $content .= $content{$_} foreach ( sortHashkeyList(@content) );
        $this->{content} = "$content${trailer}1;\n";
    }
    else {
        $this->{root}->visit($this);
        my $requires = '';
        $requires .= "require $_;\n" foreach ( sort keys %requires );
        $this->{content} =~ s/\A((?:^#[^\n]*\n)*)/$1$requires/ms if ($requires);
        $this->{content} .= "1;\n";
    }
    delete $this->{requires};
}

# Visitor method called by node traversal during save. Incrementally modify
# values, unless a value is reverting to undefined, in which case remove it.
sub startVisit {
    my ( $this, $visitee ) = @_;

    return 1 unless ( $visitee->isa('Foswiki::Configure::Value') );

    my $keys     = $visitee->{keys};
    my $typeName = $visitee->{typename};

    return 1
      if ( $keys =~ /^\{ConfigureGUI\}/
        || $typeName eq 'NULL' );

    my $value = $this->{valuer}->currentValue($visitee);

    my $logValue;
    if ( defined $value ) {
        $logValue = $visitee->stringify($value)
          if ( $this->{logger} );
        my $type =
          Foswiki::Configure::TypeUI::load( $visitee->{typename},
            $visitee->{keys} );

        my ( $txt, $require ) = $type->value2string( $keys, $value );
        if ( defined $require ) {
            if ( ref $require ) {
                $this->{requires}{$_} = 1 foreach (@$require);
            }
            else {
                $this->{requires}{$require} = 1;
            }
        }

        # Substitute any existing value, or append if not there

        $this->{content} .= $txt
          unless ( $this->{content} =~
s/^\s*\$(?:Foswiki::)?cfg$keys\s*=.*?;\n/_updateEntry($keys,$txt)/msge
          );
    }
    else {
        $logValue = '<--undefined-->';
        $this->{content} =~ s/^\s*?\$(?:Foswiki::)?cfg$keys\s*=.*?;\n//msg;
    }

    $this->{logger}->logChange( $keys, $logValue )
      if ( $this->{logger} );

    return 1;
}

sub _updateEntry {
    my $keys     = shift;
    my $newentry = shift;
    return '' if $dupItem{"$keys"};
    $dupItem{"$keys"} = 1;
    return $newentry;
}

sub endVisit {
    my ( $this, $visitee ) = @_;

    return 1;
}

1;
__END__

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
