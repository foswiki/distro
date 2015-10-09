# See bottom of file for license and copyright information
package Foswiki;

# Detailed core and plugin dependency report - see
# System.VarPERLDEPENDENCYREPORT and System.PerlDependencyReport

use strict;
use warnings;

use Foswiki::Configure::Dependency ();
use Foswiki::Configure::FileUtil   ();
use Foswiki::Configure::Auth       ();

sub PERLDEPENDENCYREPORT {
    my ( $this, $params ) = @_;
    my $session = $Foswiki::Plugins::SESSION;

    Foswiki::Configure::Auth::checkAccess($session);

    my $inc = 'missing';

    $inc = 'all'
      if ( defined $params->{include} && $params->{include} eq 'all' );

    if ( defined $params->{_DEFAULT}
        && $params->{_DEFAULT} eq 'extensions' )
    {
        return _analyzeExtensions($inc);
    }
    else {
        return _analyzeFoswiki($inc);
    }

}

sub cliDependencyReport {
    my $inc = shift || 'missing';

    my $msg = '';
    $msg = '\t\t**POSSIBLE MISSING DEPENDENCY**' if ( $inc eq 'all' );

    my $content;

    $content = _analyzeFoswiki($inc);
    $content =~ s/^\|/\n/g;
    $content =~ s/\|/\t/g;
    $content =~ s#<br ?/>#\n\t\t#g;
    $content =~ s/CPAN://g;
    $content =~
s#\s*<span class="foswikiAlert">%X% Possible missing dependency!</span>#$msg#g;

    $content .= "\n\n";

    $content .= _analyzeExtensions($inc);
    $content =~ s/^\|/\n/g;
    $content =~ s/\|/\t/g;
    $content =~ s#<br ?/>#\n\t\t#g;
    $content =~ s/CPAN://g;
    $content =~
s#\s*<span class="foswikiAlert">%X% Possible missing dependency!</span>#$msg#g;

    $content =~ s/<.*?>//g;
    $content =~ s/[\[\]]//g;

    return $content;

}

sub _analyzeFoswiki {
    my $include = shift;

    my $content;

    $content = "   * *Perl version:* $]\n";

    # Check that each of the required Perl modules can be found
    # and read, and  print its version number.  Keep this section last
    # so it does not hide shorter and more frequently accessed information.

    # File DEPENDENCIES is in the lib dir (Item3478)
    my $from = Foswiki::Configure::FileUtil::findFileOnPath('Foswiki.spec');
    my @dir  = File::Spec->splitdir($from);
    pop(@dir);    # Cutting off trailing Foswiki.spec gives us lib dir
    $from =
      File::Spec->catfile( @dir, 'Foswiki', 'Contrib', 'core', 'DEPENDENCIES' );

    my %seen;
    my $perlModules = _loadDEPENDENCIES( $from, 'core', \%seen );
    $content .= _showDEPENDENCIES( 'core', $perlModules, 0, $include );

    return $content;
}

sub _analyzeExtensions {
    my $include = shift;

    my $content;

    # File DEPENDENCIES is in the lib dir (Item3478)

    my $from = Foswiki::Configure::FileUtil::findFileOnPath('Foswiki.spec');
    my @dir  = File::Spec->splitdir($from);
    pop(@dir);    # Cutting off trailing Foswiki.spec gives us lib dir
    $from =
      File::Spec->catfile( @dir, 'Foswiki', 'Contrib', 'core', 'DEPENDENCIES' );

    my %seen;
    my @mods;
    my $perlModules = \@mods;

    foreach my $info ( values %seen ) {
        if ( $info->{usage} ) {
            $info->{usage} =~ s,^\s?<br />,<br /><strong>Foswiki: </strong>,;
        }
    }
    my %extns = (
        $from => 1,
        File::Spec->catfile( @dir, 'Foswiki', 'Plugins', 'EmptyPlugin' ) => 1,
        File::Spec->catfile( @dir, 'TWiki',   'Plugins', 'EmptyPlugin' ) => 1,
    );
    foreach my $dir (@INC) {
        _findDependencies( $dir, '/Foswiki/Plugins', \%extns,
            $perlModules, \%seen );
        _findDependencies( $dir, '/Foswiki/Contrib', \%extns,
            $perlModules, \%seen );
        _findDependencies( $dir, '/TWiki/Plugins', \%extns,
            $perlModules, \%seen );
        _findDependencies( $dir, '/TWiki/Contrib', \%extns,
            $perlModules, \%seen );
    }

    $content .= _showDEPENDENCIES( 'Extensions', $perlModules, 1, $include );

    return $content;
}

sub _findDependencies {
    my ( $dir, $path, $extns, $perlModules, $seen ) = @_;

    my $dh;
    my $dpath = File::Spec->catdir( $dir, $path );

    return unless ( opendir( $dh, $dpath ) );

    foreach my $extn ( grep !/^\./, readdir $dh ) {
        $extn =~ m/^(.*)$/;
        $extn = $1;
        my $dfile = File::Spec->catfile( $dpath, $extn, 'DEPENDENCIES' );
        next if ( $extns->{$dfile} || !-e $dfile );
        push @$perlModules, @{ _loadDEPENDENCIES( $dfile, $extn, $seen ) };
        $extns->{$dfile} = 1;
    }
    closedir($dh);
}

sub _showDEPENDENCIES {
    my $who         = shift;
    my $perlModules = shift;
    my $users       = shift;
    my $inc         = shift;

 # I suppose this needs a word of explanation:
 # The primary sort is by module name (multi-level split by ::)
 # If $users is false, we are processing the core, which the UI calls 'Foswiki'.
 # No user information is necessary, as only core data is present.
 # Otherwise, we have both the core and extensions dependencies.  We
 # skip modules used only by the core, but have merged core and all extensions.
 # So a module used by extensions and the core is also displayed with the
 # extensions, as either may have the highest version constraint.  The highest
 # version constraint is underlined (unless there's only one user)

    my $set;
    my @list = map {
        my $mvu = $_->[0]{minVersionUser};
        $mvu = 'Foswiki' if ( $mvu eq 'core' );
        my $mu = @{ $_->[0]{users} } > 1;
        $_->[0]{usage} .= ' <br><b>Used by:</b> '
          . join( ', ',
            map { $_ eq $mvu && $mu ? "<u>[[$_]]</u>" : "[[$_]]" }
              sort map { $_ eq 'core' ? '%WIKITOOLNAME%' : $_ }
              @{ $_->[0]{users} } )
          if ($users);
        $_->[0]
      } sort {
        my @a = @{ $a->[1] };
        my @b = @{ $b->[1] };
        while ( @a && @b ) {
            my $na = shift @a;
            my $nb = shift @b;
            my $c  = $na cmp $nb;
            return $c if ($c);
        }
        return @a <=> @b;
      } map {
        ( $users && @{ $_->{users} } == 1 && $_->{users}[0] eq 'core' )
          ? ()
          : [ $_, [ split( /::/, $_->{name} ) ] ]
      } @$perlModules;

    Foswiki::Configure::Dependency::checkPerlModules(@list);

    foreach (@list) {

        my $linkname =
          ( $_->{name} =~ m/^Foswiki::/ )
          ? "$_->{name}"
          : "CPAN:$_->{name}";
        if ( $linkname =~ m/^Foswiki::(?:[^:]+)::(.*)$/ ) {
            $linkname = "[[http://foswiki.org/Extensions/$1][$1]]";
        }

     #SMELL: Something is inserting newlines, breaking the table. This fixes it.
        $_->{check_result} =~
          s/(?>\x0D\x0A?|[\x0A-\x0C\x85\x{2028}\x{2029}])//sg;
        my $ok = '<br/>';
        $ok .=
          ( $_->{ok} )
          ? "Location: $_->{location}"
          : '<span class="foswikiAlert">%X% Possible missing dependency!</span>';
        $set .= "| $linkname | $_->{check_result}$ok |\n"
          unless ( $inc ne 'all' && $_->{ok} );
    }

    if ( $who eq 'core' ) {
        return "Perl modules used by Foswiki:\n" . $set;
    }
    else {
        return "Extensions and Perl modules used by installed Extensions:\n"
          . $set;
    }
}

# Extract a list of the perl modules that are required by a DEPENDENCIES file.
# We also keep track of who uses each module, and the maximum version
# constraint.  Multiple user notes are labeled and merged.

sub _loadDEPENDENCIES {
    my $from = shift;
    my $who  = shift;
    my $seen = shift;
    my $trig = 1;

    my $dwho = $who;
    $dwho = 'Foswiki' if ( $who eq 'core' );
    $dwho = "<strong>$dwho</strong>";

    my $d;
    open( $d, '<', $from ) || return "Failed to load $from: $!";
    my @perlModules;

    foreach my $line (<$d>) {
        next unless $line;

        if ( $line =~ /^ONLYIF\s+(.+)$/ ) {
            $trig = $1;
            next;
        }

        my $required = eval($trig);
        if ($@) {
            print STDERR
"**ERROR** -- ONLYIF \"$trig\" condition failed to compile: contact developer -- $@\n";
            next;
        }
        $trig = 1;
        next unless $required;    # Skip the module - trigger was false

        my @row = split( /,\s*/, $line, 4 );
        next
          unless ( scalar(@row) == 4
            && ( $row[2] eq 'cpan' || $row[2] eq 'perl' ) );
        my ( $cond, $ver ) = $row[1] =~ m/^([=<>!]*)(.*)$/;
        $cond ||= '>=';
        $row[0] =~ m/([\w:]+)/;    # check and untaint
        my $modname = $1;

        my ( $dispo, $usage ) = $row[3] =~ m/^\s*(\w+)(?:[.,]\s*)?(.*)$/;

        # There's weird stuff in DEPENDENCIES...
        # required => ERROR; recommended => WARN; default is NOTE
        #
        # If not one of the expected keywords, make it a WARN so the
        # file can be corrected without instilling too much fear.
        # Also, it's probably part of the usage sentence, so re-combine it.

        if ( $dispo !~ m/^(required|optional|recommended)$/i ) {
            $dispo = 'recommended';
            $usage = $row[3];
        }
        $usage ||= '';

        # Activate links found in DEPENDENCIES notes.

        my $dlink =
          '<a class="configureDependenciesLink" target="_blank" href=';
        $usage =~
s,\[\[(https?://[^\]]+)\]\[([^\]]+)\](?:\[[^\]]*\])?\],$dlink"$1">$2</a>,gms;
        $usage =~ s,\[\[(https?://[^\]]+)\]\],$dlink"$1">$1</a>,gms;
        $usage =~ s,(^|[^"])(https?://.*?)(\s|$),$1$dlink"$2">$2</a>$3,gms;

        if ( ( my $info = $seen->{$modname} ) ) {
            push @{ $info->{users} }, $who;
            my $prevVer = $info->{minimumVersion};
            $prevVer =~ s/(\d+(\.\d*)?).*/$1/;
            $ver     =~ s/(\d+(\.\d*)?).*/$1/;
            if ( $ver > $prevVer ) {
                $info->{minimumVersion} = $ver;
                $info->{minVersionUser} = $who;
            }
            $info->{usage} .= " <br />$dwho: $usage" if ($usage);
            next;
        }
        if ($usage) {
            if ( $who eq 'core' ) {
                $usage = " <br />" . ucfirst( lc($dispo) ) . " $usage";
            }
            else {
                $usage = "<br />$dwho: " . ucfirst( lc($dispo) ) . " $usage";
            }
        }
        push(
            @perlModules,
            {
                name           => $modname,
                usage          => $usage,
                minimumVersion => $ver || 0,
                minVersionUser => $who,
                condition      => $cond,
                disposition    => lc($dispo),
                users          => [$who],
            }
        );
        $seen->{$modname} = $perlModules[-1];
    }
    close($d);
    return \@perlModules;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2014 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
