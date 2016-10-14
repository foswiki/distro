# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::IncludeHandlers::doc

This package is designed to be lazy-loaded when Foswiki sees
an INCLUDE macro with the doc: protocol. It implements a single
method INCLUDE which generates perl documentation for a Foswiki class.

=cut

package Foswiki::IncludeHandlers::doc;
use v5.14;

use strict;
use warnings;

use File::Spec ();
use Foswiki    ();

use constant PUBLISHED_API_TOPIC => 'PublishedAPI';
use constant USE_LEXICAL_PARSER  => 1;

# Include embedded doc in a core module
sub INCLUDE {
    my ( $includeMacro, $control, $params ) = @_;

    my $app           = $includeMacro->app;
    my %removedblocks = ();
    my $class         = $control->{_DEFAULT} || 'doc:Foswiki';
    my $publicOnly    = ( $params->{publicOnly} || '' ) eq 'on';
    $app->prefs->setSessionPreferences( 'SMELLS', '' );

    # SMELL This is no longer being used in PerlDoc ...
    #    $app->prefs->setSessionPreferences( 'DOC_PARENT', '' );
    $app->prefs->setSessionPreferences( 'DOC_CHILDREN', '' );
    $app->prefs->setSessionPreferences( 'DOC_TITLE',    '---++ !! !%TOPIC%' );
    $class =~ s/[a-z]+://;    # remove protocol
    $class ||= 'Foswiki';     # provide a reasonable default

    #    return '' unless $class && $class =~ m/^Foswiki/;
    $class =~ s/[^\w:]//g;

    my %publicPackages = map { $_ => 1 } _loadPublishedAPI($app);
    my $visibility = exists $publicPackages{$class} ? 'public' : 'internal';
    _setNavigation( $app, $class, $publicOnly, \%publicPackages );
    $app->prefs->setSessionPreferences( 'DOC_TITLE',
        "---++ !! =$visibility package= " . _renderTitle( $app, $class ) );

    my $pmfile = _getPmFile( $app, $class );
    return '' unless $pmfile;

    my $PMFILE;
    open( $PMFILE, '<', $pmfile ) || return '';
    my $inPod      = 0;
    my $pod        = '';
    my $howSmelly  = 0;
    my $showSmells = !$app->isGuest();
    local $/ = undef;
    my $perl = <$PMFILE>;
    my $isa;
    state $extendsRx = qr/(?<=;)\s*(?:extends\s+|our\s+\@ISA\s*=\s*)/;
    state $withRx    = qr/(?<=;)\s*with\s+(?=q|\()/;
    state $fwClassRx = qr/(?<=;)\s*use\s+Foswiki::Class\s+/;
    my %baseType2Text = (
        extends    => 'IS A',
        with       => 'ROLES',
        classAttrs => _doclink( $app, 'Foswiki::Class' ) . ' ATTRIBUTES',
    );
    my %classAttributes2Roles = (
        app       => 'Foswiki::AppObject',
        callbacks => 'Foswiki::Aux::Callbacks',
    );

    if (USE_LEXICAL_PARSER) {
        my %modInfo
          ;    # Here we keep base classes, roles and other perl-class info.
        my $suppressedMethodLevel =
          0;    # 1+ means we're in suppressed private method.

        my $paramsRx = '(?<params>[^;]+);';
        my $ctxCode  = _makeCtx(
            $perl,
            {
                _Package =>
                  '(?:(?<=\n)\bpackage|\Apackage)\s+(?<packageName>[\w:]+);',
                _Doc =>
'\n=(?:begin(?:\h+(?:twiki|TML|html))?|pod)\h*\n(?<docText>.+?\n)=cut\h*?(?=\n)',
                _Extends      => $extendsRx . $paramsRx,
                _With         => $withRx . $paramsRx,
                _FoswikiClass => $fwClassRx . $paramsRx,
                (
                    $publicOnly # Don't even parse FIXME comments if public only mode.
                    ? ()
                    : ( _FixmeComment =>
'\n\h*?(?<commentLine>#\h*?(?<commentType>SMELL|TODO|FIXME)\h+?)(?=\n)'
                    )
                ),
            },
        );

        my ( $curPackage, $curMethod );
        my $docRaw = '';
        pos($perl) = 0;
        while ( _nextLexeme($ctxCode) ) {
            my $lType = $ctxCode->{type};
            if ( $lType eq '_Package' ) {
                $curPackage = $ctxCode->{lexemes}{packageName};
                $modInfo{$curPackage} = {};
            }
            elsif ( $lType =~ '^_(Extends|With)$' ) {
                Foswiki::Exception::Fatal->throw( text =>
                      'Found class modifiers before a package declaration.' )
                  if !defined($curPackage);
                my $miKey     = lc($1);
                my $params    = $ctxCode->{lexemes}{params};
                my @classList = eval($params);
                push @classList, $@ if $@;
                push @{ $modInfo{$curPackage}{$miKey} }, @classList;
            }
            elsif ( $lType eq '_FoswikiClass' ) {
                my @attrs = eval $ctxCode->{lexemes}{params};
                push @attrs, $@ if $@;
                push @{ $modInfo{$curPackage}{with} },
                  ( $classAttributes2Roles{$_} // () )
                  foreach @attrs;
                $modInfo{$curPackage}{classAttrs} = \@attrs;
            }
            elsif ( $lType eq '_FixmeComment' ) {
                $howSmelly++;
                $docRaw .=
                    "<blockquote class=\"foswikiAlert\">"
                  . $ctxCode->{lexemes}{commentLine}
                  . "</blockquote>\n\n";
            }
            elsif ( $lType eq '_Doc' ) {
                $docRaw .= $ctxCode->{lexemes}{docText};
            }
        }

        $docRaw =
          Foswiki::takeOutBlocks( $docRaw, 'verbatim', \%removedblocks );

        my $ctxDoc = _makeCtx(
            $docRaw,
            {
                _Section =>
'(?<secPrefix>\n|\A)(?<secLine>(?<secDef>---(?<secDepth>\++))(?:!!)?\h+(.+?))(?=\n)',
            }
        );

      DOC_SECTION:
        while ( _nextLexeme($ctxDoc) ) {
            my $dType = $ctxDoc->{type};
            $pod .= _modLink( $app, $ctxDoc->{lexemes}{skipped} // '' )
              unless $suppressedMethodLevel;
            if ( $dType eq '_Section' ) {
                my ( $secPrefix, $secLine, $secDef ) =
                  @{ $ctxDoc->{lexemes} }{qw(secPrefix secLine secDef)};
                my $secDepth = length( $ctxDoc->{lexemes}{secDepth} );

                my $ctxSection = _makeCtx(
                    $secLine,
                    {
                        _package =>
'^(?:---\++)(?:!!)?\h+(?<pkgType>(?i:package|class|role))\h+(?<pkgName>.+?)\h*?$',
                        _method =>
'^(---\++\h+(?<methodAccess>Object|Static|Class)(?<methodType>Method|Attribute)\h+(?<methodName>(?<methodPriv>_?).+?))\h*?$',
                    },
                );
                if ( _nextLexeme($ctxSection) ) {
                    my $secType = $ctxSection->{type};
                    if ( $secType eq '_package' ) {
                        my ( $pkgType, $pkgName ) =
                          @{ $ctxSection->{lexemes} }{qw(pkgType pkgName)};
                        if ( defined $modInfo{$pkgName} ) {
                            $pkgType = ucfirst $pkgType;
                            $visibility =
                              exists $publicPackages{$class}
                              ? 'public'
                              : 'internal';
                            $pod .=
                              "\n$secDef =$visibility $pkgType= $pkgName\n";
                            foreach my $baseType (qw(extends with classAttrs)) {
                                my $baseText = $baseType2Text{$baseType};
                                if ( my $classList =
                                    $modInfo{$pkgName}{$baseType} )
                                {
                                    $pod .= "|*$baseText*|"
                                      . join(
                                        ", ",
                                        map { "=" . _doclink( $app, $_ ) . "=" }
                                          @$classList
                                      ) . "|\n";
                                }
                            }
                            $app->prefs->setSessionPreferences( 'DOC_TITLE',
                                "---+ !! =$visibility $pkgType= "
                                  . _renderTitle( $app, $class ) )
                              if $class eq $pkgName;
                        }
                    }
                    elsif ( $secType eq '_method' ) {
                        my (
                            $methodAccess, $methodType,
                            $methodName,   $methodPriv
                          )
                          = @{ $ctxSection->{lexemes} }
                          {qw(methodAccess methodType methodName methodPriv)};
                        $methodName = Foswiki::entityEncode($methodName);
                        if ( $publicOnly && $methodPriv ) {
                            $suppressedMethodLevel = $secDepth;
                        }
                        else {
                            # Starting a non-suppressed method section.
                            $suppressedMethodLevel = 0;
                            $pod .=
"\n$secDef =[[$methodAccess$methodType]]= ==$methodName==\n";
                        }
                    }
                    else {    # Just plain simple heading.
                        if ( $secDepth <= $suppressedMethodLevel ) {

                            # It is not a sub-heading of a supressed method.
                            $suppressedMethodLevel = 0;
                        }
                        $pod .= "\n$secLine\n"
                          unless $suppressedMethodLevel;
                    }
                }
                else {
                    Foswiki::Exception::Fatal->throw(
                            text => 'Failed to get lexemes for section line `'
                          . $secLine
                          . "'" );
                }
            }
            else {
              # For unhandled lexemes just pass over their text into the output.
                $pod .= $ctxDoc->{text} // '';
            }
        }

        Foswiki::putBackBlocks( \$pod, \%removedblocks, 'verbatim',
            'verbatim' );
    }
    else {    # Use the old parsing method.
        my $inSuppressedMethod;

        if (   $perl =~ m/our\s+\@ISA\s*=\s*\(\s*['"](.*?)['"]\s*\)/
            || $perl =~ m/extends\s+(?:qw\(|'|")(.+?)(?:\)|'|");/ )
        {
            $isa = " ==is a== $1";
            $isa =~ s#\s(\w+?(?:::[A-Z]\w+)+)#' ' . _doclink($app, $1)#ge;
        }
        $perl = Foswiki::takeOutBlocks( $perl, 'verbatim', \%removedblocks );
        foreach my $line ( split( /\r?\n/, $perl ) ) {
            if ( $line =~ m/^=(begin (twiki|TML|html)|pod)/ ) {
                $inPod              = 1;
                $inSuppressedMethod = 0;
            }
            elsif ( $line =~ m/^=cut/ ) {
                $inPod = 0;
            }
            elsif ($inPod) {
                if ( $line =~ m/^---\+(!!)?\s+(?i:package|class)\s+\S+\s*$/ ) {
                    if ($isa) {
                        $line .= $isa;
                        $isa = undef;
                    }
                    $line =~
s/^---\+(?:!!)?\s+((?i)package|class)\s*(.*)/---+ =$visibility $1= $2/;
                    $app->prefs->setSessionPreferences( 'DOC_TITLE',
                        "---++ !! =$visibility $1= "
                          . _renderTitle( $app, $class ) );
                }
                else {
                 # Check for module names not prefixed with colon or left square
                 # bracket.
                    $line =~
                      s#(?<![\[:])\b(\w+?(?:::[A-Z]\w+)+)#_doclink($app, $1)#ge;
                }
                if ( $line =~
                    s/^(---\++\s+)(\w+(?:Method|Attribute))\s+/$1=$2= / )
                {
                    $line =~ s/\s+[-=]>\s+/ &rarr; /;
                    if ( $publicOnly && $line =~ m/Method=\s+_/ ) {
                        $inSuppressedMethod = 1;
                    }
                }
                elsif ( $line =~ m/^---/ ) {
                    $inSuppressedMethod = 0;
                }
                $pod .= "$line\n"
                  unless $inSuppressedMethod;
            }
            if (  !$inSuppressedMethod
                && $line =~ m/(SMELL|FIXME|TODO)/
                && $showSmells )
            {
                $howSmelly++;
                $pod .= "<blockquote class=\"foswikiAlert\">$line</blockquote>";
            }
        }
        close($PMFILE);
        Foswiki::putBackBlocks( \$pod, \%removedblocks, 'verbatim',
            'verbatim' );
    }

    $pod =~ s/.*?%STARTINCLUDE%//s;
    $pod =~ s/%(?:END|STOP)INCLUDE%.*//s;
    if ($howSmelly) {
        my $podSmell =
            '<blockquote class="foswikiAlert">'
          . " *SMELL / FIX / TODO count: $howSmelly*\n"
          . '</blockquote>';
        $pod .= $podSmell;
        $app->prefs->setSessionPreferences( 'SMELLS', $podSmell );
    }

    $pod =
      $includeMacro->applyPatternToIncludedText( $pod, $control->{pattern} )
      if ( $control->{pattern} );

    # Adjust the root heading level
    if ( $params->{level} ) {
        my $minhead = '+' x 100;
        $pod =~ s/^---(\++)/
          $minhead = $1 if length($1) < length($minhead); "---$1"/gem;
        return $pod if length($minhead) == 100;
        my $newroot = '+' x $params->{level};
        $minhead =~ s/\+/\\+/g;
        $pod     =~ s/^---$minhead/---$newroot/gm;
    }
    return $pod;
}

sub _makeCtx {
    my ( $source, $ctxRxStrings ) = @_;

    my %ctxData = ( source => $source, );

    my $rxStr = "(?<lexText>"
      . join( "|",
        map { "(?:" . $ctxRxStrings->{$_} . ")(?{\$ctxData{type} = '$_';})" }
          keys %$ctxRxStrings )
      . "|(?:\\Z)(?{\$ctxData{type} = '_EOF_';}))(?{\@ctxData{qw(pos text)} = (pos(\$_), \$+{lexText}); \$ctxData{lexemes} = {\%+};})";
    $ctxData{regex} = eval "qr/$rxStr/s";
    Foswiki::Exception::Fatal->throw( text => 'Failed to compile regex: /'
          . $rxStr . "/\n"
          . Foswiki::Exception::errorStr($@) )
      if $@;
    return \%ctxData;
}

sub _nextLexeme {
    my ($ctx) = @_;

    @{$ctx}{qw(type pos text lexemes )} = ( '_NONE_', -1, undef, {} );

    my $regex = $ctx->{regex};

    #say STDERR "POS(source):", (pos($ctx->{source}) // '*undef*');

    return scalar( $ctx->{source} =~ /\G(?<skipped>.*?)$regex/gcs );
}

sub _modLink {
    my ( $app, $txt ) = @_;
    $txt =~ s/(?<![\[:])(\b\w+(?:::\w+)+)/_doclink($app, $1)/gse;
    return $txt;
}

sub _getPmFile {
    my ( $app, $class ) = @_;
    state %cachedPMs;
    state $fwPath;

    unless ( defined $fwPath ) {
        $fwPath = ( File::Spec->splitpath( $INC{'Foswiki.pm'} ) )[1];
    }

    return $cachedPMs{$class} if $cachedPMs{$class};

    my $pmfile = '';
    ( my $classFile = $class ) =~ s#::#/#g;
    $classFile = File::Spec->catfile( $fwPath, "$classFile.pm" );
    $pmfile = $classFile if ( -f $classFile );
    $cachedPMs{$class} = $pmfile;
    return $pmfile;
}

# set DOC_CHILDREN preference value to a list of sub-packages.
sub _setNavigation {
    my ( $app, $class, $publicOnly, $publicPackages ) = @_;
    my @children;
    my %childrenDesc;
    my $classPrefix = $class . '::';

#    my $classParent = $class;
#    $classParent =~ s/::[^:]+$//;
#    $app->prefs->setSessionPreferences( 'DOC_PARENT', _doclink($app, $classParent) );
    $class =~ s#::#/#g;

    foreach my $inc (@INC) {
        if ( -d "$inc/$class" and opendir my $dh, "$inc/$class" ) {
            my @dir = grep { !/^\./ } readdir($dh);
            push @children,
              map { -d "$inc/$class/$_" ? "$classPrefix$_" : () } @dir;
            for my $d (@dir) {
                if ( $d =~ s/\.pm$// ) {
                    push @children, "$classPrefix$d";
                    $childrenDesc{"$classPrefix$d"} =
                      _getPackSummary("$inc/$class/$d.pm");
                }
            }
            closedir $dh;
        }
    }
    if ($publicOnly) {
        @children = grep { exists $publicPackages->{$_} } @children;
    }
    my $children = '<ul>';
    if (@children) {
        my %children = map { $_ => 1 } @children;
        @children = sort keys %children;
        foreach my $child (@children) {
            my $desc =
              $childrenDesc{$child} ? ' - ' . $childrenDesc{$child} : '';
            $children .= '<li>' . _doclink( $app, $child ) . "$desc</li>\n";
        }
    }
    $children .= '</ul>';
    $app->prefs->setSessionPreferences( 'DOC_CHILDREN', $children );
}

# get a summary of the pod documentation by looking directly after the ---+ package TML.
sub _getPackSummary ($) {
    my $pmfile = $_[0];
    my @summary;

    my $PMFILE;
    open( $PMFILE, '<', $pmfile ) || return '';
    my $inPod     = 0;
    my $inPackage = 0;
    while ( my $line = <$PMFILE> ) {
        if ( $line =~ m/^=(begin (twiki|TML|html)|pod)/ ) {
            $inPod = 1;
        }
        elsif ( $line =~ m/^=cut/ ) {
            @summary
              and last;
            $inPod = 0;
        }
        elsif ($inPod) {
            if ($inPackage) {
                chomp($line);
                push @summary, $line;
            }
            if ( $line =~ m/^---\+(!!)?\s+(?i:package|class)\s+\S+\s*$/ ) {
                $inPackage = 1;
            }
        }
    }
    close($PMFILE);

    while (@summary) {
        if ( $summary[0] =~ m/^\s*$/ ) {
            shift @summary;
        }
        else {
            last;
        }
    }
    if ( !@summary ) {
        return '';
    }
    my $emptyLine = 0;
    while ( $emptyLine < @summary && $summary[$emptyLine] !~ /^\s*$/ ) {
        $emptyLine++;
    }
    return join ' ', @summary[ 0 .. $emptyLine - 1 ];
}

sub _loadPublishedAPI {
    my $app = shift;
    my ( $meta, $text ) =
      $app->readTopic( $app->cfg->data->{SystemWebName}, PUBLISHED_API_TOPIC );
    my @ret;
    for my $line ( split /\r?\n/, $text ) {

#| [[%SYSTEMWEB%.PerlDoc?module=Foswiki::Func][Foswiki::Func]] | 1.1.5 | Main API. |
        $line =~ m/^\|\s*\[\[.*?PerlDoc.*?\]\[(.*?)\]\]/
          and push @ret, $1;
    }
    return @ret;
}

# Make each intermediate package into a doc link.
sub _renderTitle {
    my $app       = shift;
    my $pack      = $_[0];
    my @packComps = split '::', $pack;
    my @packLinks =
      map {
        _doclink( $app, ( join '::', @packComps[ 0 .. $_ ] ), $packComps[$_] )
      } 0 .. $#packComps - 1;
    my $packageTitle = join '::', @packLinks, $packComps[$#packComps];
    return $packageTitle;
}

sub _doclink {
    my $app    = shift;
    my $module = $_[0];
    $module =~ /^/;                # Do it to reset $n match variables.
    $module =~ s/^_(.+)(_)$/$1/;
    my $formatChar = $2 // '';
    my $title = $_[1] || $module;

    my $pmfile = _getPmFile( $app, $module );

    return "$formatChar$module$formatChar"
      unless $module !~ /^Foswiki:/ || $pmfile;

    # SMELL relying on TML to set publicOnly
    return $formatChar
      . (
        $pmfile
        ? ( "[[%SCRIPTURL{view}%/%SYSTEMWEB%/PerlDoc?module="
              . $module
              . "%IF{\"\$publicOnly = 'on'\" then=\";publicOnly=on\"}%]["
              . $title
              . "]]" )
        : "[[CPAN:$module][$title]]"
      ) . $formatChar;
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
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
