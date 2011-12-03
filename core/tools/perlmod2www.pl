#!/usr/bin/perl

# -----------------------------------------------------------------------
# perlmod2www.pl - convert Perl mdoules tree to equivalent www tree with HTML format documentation.
#
# Use -h for help.
#
# Copyright 2000,2001,2002 Raphael Leplae raphael@ucmb.ul.ac.be
# All rights reserved.
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
# -----------------------------------------------------------------------
# Add the path where the Pdoc directory is located here if needed
#use lib '/some/where';

use strict;
use FileHandle;
use Carp qw(cluck confess);

# Need a Perl module parser
use Pdoc::Parsers::Files::PerlModule;

# A Tree
use Pdoc::Tree;

# Some renderers
use Pdoc::Html::Renderers::TreeFilesIndexer;
use Pdoc::Html::Renderers::TreeNodesIndexer;
use Pdoc::Html::Renderers::PerlModule;
use Pdoc::Html::Renderers::PerlToc;

# Need the document parser + modules
use Pdoc::Parsers::Documents::Parser;
use Pdoc::Parsers::Documents::Modules::WebCvs;

# Extra converters might required
use Pdoc::Html::Converters::Modules::WebCvs;
use Pdoc::Html::Converters::Modules::RawContent;
use Pdoc::Html::Tools::UrlMgr;

# Need highlighter
use Pdoc::Html::Tools::PerlHighlight;

# Define default global variables & values
use vars qw( $VERSION $RELEASE $_pdocUrl $psep $_scptConf $config
  $_authorName $_authorEmail );

# Init globals
$VERSION = do { my @r = ( q$Revision: 1.8 $ =~ /\d+/g ); sprintf "%d." . "%02d" x $#r, @r };
$RELEASE      = '1.0';
$_pdocUrl     = 'http://sourceforge.net/projects/pdoc';
$_authorName  = 'Raphael Leplae';
$_authorEmail = 'lp1@sanger.ac.uk';

# Do not buffer
$| = 1;

# Global variables
# Get -wroot value
my $wroot;

# Source path, default to pwd
my $source = $ENV{'PWD'};

# Target path (in httpd area)
my $target;

# Default header to add to html pages
my $doc_head;

# Default footer to add to html pages
my $doc_foot;

# Cross links (-xl or -xltable)
my @xl = ();

# Cross linked tree objects
my $xtrees;

# Get value from -webcvs
my $webCvs;

# Flag to add Document parser or not
my $parseDoc = 0;

# Flag, if 1 do not sort methods in perl module doc page
my $noSort = 0;

# Define default dir(s) to skip
my $to_skip = 'CVS';

# Flag to check ISA modules
my $isaCheck = 0;

# Flag to add file raw content
my $useRaw = 0;

# Hold config file
my $confFile;

# Default config:
$_scptConf->{'tocLevel'} = '#ee8700';

# Parse passed args
Get_args();

# Now create documentation for each module:
# Need the Perl module parser
my $mod_parser = Pdoc::Parsers::Files::PerlModule->new();

# Need the Perl module renderer
my $mod_renderer = Pdoc::Html::Renderers::PerlModule->new();

# Get doc converter
my $mod_converter = $mod_renderer->getConverter();

# If config file, load it now:
if ($confFile) {

    # Need config object
    $config = Pdoc::Config->new();

    # Try to load config file
    if ( !$config->load($confFile) ) {
        cluck("Failed to load config file $confFile\n");
    }
    else {

        # Assign config to various modules
        Pdoc::Html::Tools::PerlHighlight::config($config);

        $mod_renderer->config($config);

        # Also get config for this script:
        my $val = $config->getVal( 'HTML', 'PerlToc', 'level' );
        $_scptConf->{'tocLevel'} = $val if ( defined $val );
    }
}

# Check target path now
if ( !-d $target ) {
    print "Target dir $target is not a directory.\n";
    exit;
}

# Get doc head and foot
exit if ( !Get_head_foot() );

# Clean root url
if ( $wroot && $wroot =~ /.+\/$/ ) {
    chop $wroot;
}

# Get the tree
print "Getting tree from $source...\n";
my $tree = extractTree( $source, $wroot );
my $targetTree;

# If relative urls, use separate tree with target as path for proper linking
unless ($wroot) {
    $targetTree = Pdoc::Tree->new();
    $targetTree->name('Perl modules documentation.');
    $targetTree->path($target);
    $targetTree->root( $tree->root() );

    push( @{$xtrees}, $targetTree );
}
else {
    push( @{$xtrees}, $tree );
}

# Extract cross ref trees
if (@xl) {
    print "Getting trees for cross-linking:\n";
    foreach my $parts (@xl) {
        print "Extra tree from ", $parts->[0], "\n";
        my $extra = extractTree( $parts->[0], $parts->[1] );

        # If relative paths, redef path with path to Doc tree
        $extra->path( $parts->[1] ) unless ($wroot);
        push( @{$xtrees}, $extra );
    }
}

# Define target path correctly
$psep = $tree->path_separator();
$target =~ s/[\/\\:]/$psep/g;
$target =~ s/$psep$//;

# Renderer for TOC
my $tocRenderer = Pdoc::Html::Renderers::PerlToc->new();

# Assign config if present
$tocRenderer->config($config) if defined $config;

# Generate all index files
if ( !Generate_indexes($tree) ) {
    print "Failed generating indexes.\n";
    exit;
}

# Add extra trees to renderer
$mod_renderer->trees($xtrees);

# If no sorting of method names
if ($noSort) {
    $mod_renderer->sortMethods(0);
}

# Converter configuration:

# Assign check flag for isa modules
$mod_converter->checkIsa($isaCheck);

# Add raw content convertr if needed
if ($useRaw) {
    print "Raw content files will be added to the HTML tree.\n";
    my $rawConverter = Pdoc::Html::Converters::Modules::RawContent->new();
    $rawConverter->matchType('PerlPackage');
    $mod_converter->add($rawConverter);
}

# Create a document parser if needed
my $doc_parser;
if ( $parseDoc == 1 ) {
    $doc_parser = Pdoc::Parsers::Documents::Parser->new();

    # and add document parser + corresponding converter
    if ( defined $webCvs ) {
        print "Including WebCvs crosslink to $webCvs.\n";

        my $wcvs_pars = Pdoc::Parsers::Documents::Modules::WebCvs->new();

        # Set doc entry to match
        $wcvs_pars->matchType('PerlPackage');
        $doc_parser->add($wcvs_pars);

        my $wcvs_conv = Pdoc::Html::Converters::Modules::WebCvs->new();

        # Assign url and config
        $wcvs_conv->set( 'webcvs', $webCvs );

        $wcvs_conv->config($config) if defined $config;
        $mod_converter->add($wcvs_conv);
    }
}

# Start file for TOC with all levels
my $fname     = $target . $tree->path_separator() . 'tocAll.html';
my $tocAllFpt = FileHandle->new(">$fname");
confess("Can't create $fname!") if ( !$tocAllFpt );

initTocAll();

# Start the convertion!
Generate_doc( $tree->root() );

# Done with TOC all
print $tocAllFpt <<XXX;
</BODY></HTML>
XXX

# Generate initial main frame
Generate_main_frame($tree);

# 5) Generate final index file
Generate_frames();

print "Completed Perl modules documentation.\n";

exit;

# Check_dir: get a path and create all necessary directories

sub Check_dir {
    my $path = shift;

    my $sep    = quotemeta $tree->path_separator();
    my @dirs   = split( /$sep/, $path );
    my $pcheck = "";
    $pcheck = $tree->path_separator() if ( $path =~ /^$sep/ );

    foreach my $dir (@dirs) {
        next if ( !defined $dir || $dir eq "" || $dir eq '.' );
        $pcheck .= $dir . $tree->path_separator();
        if ( !-d $pcheck ) {
            unless ( mkdir( $pcheck, 0755 ) ) {
                print "Error: failed to create directory $pcheck\n";
                exit;
            }
        }
    }
}

# Generate_indexes: generate index files for all the directories

sub Generate_indexes {
    my $tree = shift;

    print "Generating indexes...\n";

    # 1st, index for Perl levels
    return 0 if ( !Generate_levels($tree) );

    # 2nd, index for Perl modules in each level
    return Generate_all_modules_index($tree);
}

# Generate_levels: create index file with all "Perl levels" (directories in the tree).

sub Generate_levels {
    my $tree = shift;

    # Need the renderer
    my $indexer = Pdoc::Html::Renderers::TreeNodesIndexer->new();

    # Set some params
    $indexer->target('modules');
    $indexer->index('modules.html');
    $indexer->url( $tree->url );
    $indexer->name_transform( \&PathToLevel );
    $indexer->config($config) if defined $config;

    # Create index file now
    my $html_file = $target . $tree->path_separator() . 'all_packages.html';

    print "Creating levels index file $html_file\n";

    my $fpt = FileHandle->new(">$html_file");
    if ( !defined $fpt ) {
        print "Unable to create $html_file!\n";
        return 0;
    }

    # Store index now
    print $fpt <<XXX;
<HEAD>
<!-- Generated by perlmod2www.pl -->
<TITLE>
Perl levels
</TITLE>
</HEAD>
<BODY BGCOLOR="WHITE">
XXX

    my $url = 'all_modules.html';
    print $fpt '<A HREF="', $url, '" TARGET="modules"><B>All Modules</B></A>',
      "\n";
    $url = 'tocAll.html';
    print $fpt '<A HREF="', $url, '" TARGET="main"><B>TOC All</B></A>', "\n";

    # Is there a better name than "Perl levels"?
    print $fpt "<BR><B>Perl levels</B><BR>\n";

    # Render index now
    $indexer->render( $fpt, $tree );

    print $fpt <<XXX;
</BODY>
</HTML>
XXX
    $fpt->close();

    return 1;
}

# Generate_all_modules_index: generate big index with all Perl modules in all directories
# then index for each directory.

sub Generate_all_modules_index {
    my $tree = shift;

    # Create renderer
    my $renderer = Pdoc::Html::Renderers::TreeFilesIndexer->new();

    # Set some params
    # Set the url
    $renderer->url( $tree->url() );
    $renderer->target('main');
    $renderer->name_transform( \&RmExt );
    $renderer->file_transform( \&RmExt );
    $renderer->usePath(1);
    $renderer->config($config) if defined $config;

    # Full indexing => need recursive flag on
    $renderer->set( 'recursive', 1 );

    # Create index file now
    my $html_file = $target . $tree->path_separator() . 'all_modules.html';
    print "Creating global Perl modules index file $html_file\n";

    my $fpt = FileHandle->new(">$html_file");
    if ( !defined $fpt ) {
        print "Unable to create $html_file!\n";
        return 0;
    }

    # Store main index now
    print $fpt <<XXX;
<HEAD>
<!-- Generated by perlmod2www.pl -->
<TITLE>
All Perl Modules
</TITLE>
</HEAD>
<BODY BGCOLOR="WHITE">
XXX

    print $fpt "<B>All Perl modules</B><BR>\n";

    # Generate full index
    $renderer->render( $fpt, $tree->root() );

    print $fpt <<XXX;
</BODY>
</HTML>
XXX
    $fpt->close;

    # Now generate index for individual directory
    # => recursive flag off
    $renderer->set( 'recursive', 0 );

    # Do not use paths in url now
    $renderer->usePath(0);

    if ( !Generate_modules_index( $tree->root(), $renderer ) ) {
        return 0;
    }

    return 1;
}

# Generate_modules_index: generate Perl modules index in a specific directory

sub Generate_modules_index {
    my $node     = shift;
    my $renderer = shift;

    # Define local url for the renderer
    $renderer->url( $tree->url() );

    # Define www dir path
    my $path = $target . $tree->path_separator();
    $path .= $node->path() if ( $node->path() );

    Check_dir($path);

    # Create index file now
    my $html_file = $path . $tree->path_separator() . 'modules.html';
    print "Creating Perl modules index file $html_file\n";

    my $fpt = FileHandle->new(">$html_file");
    if ( !defined $fpt ) {
        print "Unable to create $html_file!\n";
        return 0;
    }

    # Store main index now
    print $fpt <<XXX;
<HEAD>
<!-- Generated by perlmod2www.pl -->
<TITLE>
Perl Modules
</TITLE>
</HEAD>
<BODY BGCOLOR="WHITE">
XXX

    my $level = PathToLevel($node);

    print $fpt '<A HREF="toc.html" TARGET="main"><B>', $level, '</B></A><P>',
      "\n";
    if ( !$renderer->render( $fpt, $node ) ) {
        print $fpt "<B>No modules in this level.</B>\n";
    }

    print $fpt <<XXX;
</BODY>
</HTML>
XXX
    $fpt->close();

    # Process sub directories
    my $iter = $node->nodeIterator();
    my $sub_node;
    while ( $sub_node = $iter->() ) {
        last if ( !Generate_modules_index( $sub_node, $renderer ) );
    }

    return 1;
}

sub Generate_main_frame {
    my $tree = shift;

    print "Creating main frame.\n";

    # Define file name
    my $html_file = $target . $tree->path_separator() . 'main_index.html';

    my $fpt = FileHandle->new(">$html_file");
    if ( !defined $fpt ) {
        print "Unable to create $html_file!\n";
        return 0;
    }

    # Store main index now
    # Now make a nice web page!
    print $fpt <<XXX;
<HEAD>
<!-- Generated by perlmod2www.pl -->
<TITLE>
Perl Modules
</TITLE>
</HEAD>
<BODY BGCOLOR="WHITE">
XXX

    print $fpt "<H1>Perl modules documentation for ", $tree->root_name(),
      "</H1>\n";

    print $fpt <<XXX;
<table><tr><td>
These pages have been automatically generated by perlmod2www.pl release $RELEASE. For any problem or suggestion, please contact $_authorName <A HREF="mailto:$_authorEmail">lp1\@sanger.ac.uk</A>. <br>
</td><td>
See also<br><a href="$_pdocUrl" target="SF"><img src="http://sourceforge.net/sflogo.php?group_id=33199" alt="SourceForge" border="0" align="absmiddle"></a><br>for more information.
</td></tr></table>
<hr>
<h3>Navigation</h3>
<b>Top left frame</b> displays the directory tree with the Perl modules using &quot;Perl syntax&quot; for the paths. Click on one path to display in the bottom left frame the Perl modules available. 
The <b>All modules</b> link displays all the modules available in the bottom left frame (shown by default). 
The <b>TOC All</b> link displays the table of contents for the whole library in this frame. 
<p>
<b>Bottom left frame</b> displays the modules available in a particular directory level or all the modules available (shown by default). Click on one of the modules to display the documentation in the main (this) frame. Clicking on the library level name will display in the main frame the table of content for the level.
<p>
<b>Main frame</b> is used to display documentation about a particular Perl module. The documentation is subdivided in several parts (may vary) presenting the POD found in the file, information about included packages, inheritance, subroutines code, etc...<p>
<hr>
</body>
</html>
XXX

    $fpt->close();

    return 1;
}

# Generate_frames: creates the initial page with the frames definition
sub Generate_frames {
    print "Creating main page.\n";

    # Define file name
    my $html_file = $target . $tree->path_separator() . 'index.html';

    my $fpt = FileHandle->new(">$html_file");
    if ( !defined $fpt ) {
        print "Unable to create $html_file!\n";
        return 0;
    }

    # Store main index now
    # Now make a nice web page!
    print $fpt <<XXX;
<HEAD>
<!-- Generated by perlmod2www.pl -->
<TITLE>
XXX

    print $fpt "Perl modules documentation for ", $tree->root_name(), "\n";

    print $fpt <<XXX;
</TITLE>
</HEAD>
<FRAMESET cols="20%,80%">
<FRAMESET rows="30%,70%">
<FRAME src="all_packages.html" name="packages">
<FRAME src="all_modules.html" name="modules">
</FRAMESET>
<FRAME src="main_index.html" name="main">
</FRAMESET>
</BODY>
</HTML>
XXX

    $fpt->close;

    return 1;
}

# Generate_doc: generate Perl module documentation

sub Generate_doc {
    my $node = shift;

    my $fullPath = $tree->path() . $tree->path_separator();
    $fullPath .= $node->path() . $tree->path_separator() if ( $node->path() );

    print "Generating documentation from ", $fullPath, "\n";

    # Document for TOC
    my $nodeToc = Pdoc::Document->new();
    $nodeToc->name('TOC');
    $nodeToc->node($node);

    my $fname = $target . $tree->path_separator();
    $fname .= $node->path() . $tree->path_separator() if ( $node->path() );
    $fname .= 'toc.html';

    my $tocFpt = FileHandle->new(">$fname");
    confess("Can't create $fname!") if ( !$tocFpt );

    # Init toc
    my $title = PathToLevel($node);
    print $tocFpt <<XXX;
<html>
<HEAD>
<!-- Generated by perlmod2www.pl -->
<TITLE>
TOC for $title
</TITLE>
</HEAD>
<BODY BGCOLOR="WHITE">
<TABLE BORDER="0" WIDTH="100%">
<TR><TD BGCOLOR="$_scptConf->{'tocLevel'}"><B>TOC for $title</B></TD></TR>
</TABLE>
XXX

    my $fpt;
    my $file;

    # Iterate on files in the tree node
    my $iter = $node->fileIterator();
    while ( $file = $iter->() ) {
        my $fname = $tree->path() . $tree->path_separator();
        $fname .= $node->path() . $tree->path_separator()
          if ( defined $node->path() );
        $fname .= $file->name();

        print "# File $fname\n";
        $fpt = FileHandle->new($fname);
        if ( !defined $fpt ) {
            print "Failed opening $fname, skipped.\n";
            next;
        }

        # Let the file parser do the job
        my $parsed;
        my $count = 0;

        # Parse file
        $mod_parser->stream($fpt);
        while ( $parsed = $mod_parser->nextDocument($node) ) {

            # Set some values to the document
            $parsed->file( $file->name() );

            # Go through the document parser for eventual
            # extra work if needed
            $doc_parser->parse($parsed) if ($parseDoc);

            # Build Toc
            my $podName = $parsed->fetch( 'PodHead', 'NAME' );
            if ($podName) {
                my $tocEntry = Pdoc::DocEntry->new();
                $tocEntry->type('toc');
                $tocEntry->name( $parsed->name() );
                $tocEntry->content( $podName->content() );

                addTocEntry( $tocEntry, $nodeToc );
            }

            # Render document to an HTML page
            Render_doc( $node, $file, $parsed );

            $count++;
        }

        $fpt->close();

        # Warning if something wrong
        if ( !$count ) {
            print "Warning: failed to parse and/or convert file $fname!\n";
            print
              "Check if package name definition is correct ('package' line)\n";
            print "File skipped.\n";
            next;
        }
    }

    # Store TOC for this node
    $tocRenderer->render( $tocFpt, $nodeToc );
    print $tocFpt <<XXX;
</BODY>
</HTML>
XXX
    $tocFpt->close();

    # Add this part in TOC all
    print $tocAllFpt <<XXX;
<BR>
<A NAME="$title"></A>   
<TABLE BORDER="0" WIDTH="100%" CELLSPACING="0">
<TR BGCOLOR="$_scptConf->{'tocLevel'}"><TD><B>$title</B></TD><TD ALIGN="right"><A HREF="#top">Top</A></TD></TR>
</TABLE>
XXX

    # Update urls
    $iter = $nodeToc->iterator();
    my $entry;
    while ( $entry = $iter->() ) {
        $entry->set( 'url', $node->path() . '/' . $entry->name() . '.html' );
    }

    $tocRenderer->render( $tocAllFpt, $nodeToc );

    # Descend tree
    $iter = $node->nodeIterator();
    my $sub_node;
    while ( $sub_node = $iter->() ) {
        Generate_doc($sub_node);
    }

    return 1;
}

# Render_doc: transform a parsed Perl module to a web page

sub Render_doc {
    my $node     = shift;
    my $file_obj = shift;
    my $document = shift;

    # Fname for raw data
    my $rawFile;

    # Get document name
    my $name = $document->name();

    if ( !defined $name ) {
        print "No document name, not converted!\n";
        return 0;
    }

    # Get Perl level and module name
    #    my $level = $tree->root_name;
    my $level;
    if ( $name =~ /::/ ) {
        $name =~ /^(.*)::(.+)$/;
        $level = $1 if ( $1 ne "" );
        $name = $2;
    }

    $level = $tree->root_name() if ( $level eq "" );

    # Define HTML file name
    my $file  = RmExt($file_obj);
    my $fname = $target . $tree->path_separator();
    $fname .= $node->path() . $tree->path_separator()
      if ( defined $node->path() );

    # Handle raw format
    if ($useRaw) {
        $rawFile = $fname . $file . '_raw.html';
    }

    $fname .= $file . '.html';

    print "-> Rendering ", $document->name(), " in\n   $fname\n";

    # Dissociate convertion and rendition
    unless ( $mod_converter->convert($document) ) {
        print "Error: failed to convert the document!\n";
        return 0;
    }

    if ($useRaw) {
        return 0 unless addRawContent( $rawFile, $document );
    }

    # Write HTML file now
    my $fpt = FileHandle->new(">$fname");
    if ( !defined $fpt ) {
        print "Unable to create $fname!\n";
        return 0;
    }

    print $fpt <<XXX;
<head>
<!-- Generated by perlmod2www.pl -->
<title>
$name documentation.
</title>
</head>
<body bgcolor="white">
XXX
    print $fpt $doc_head if ( defined $doc_head );

    # Write page title
    print $fpt "<HR><H4>$level</H4>\n";
    print $fpt "<H3>$name</H3>\n";

    # Just delegate the job to the renderer
    $mod_renderer->render( $fpt, $document );

    print $fpt $doc_foot if ( defined $doc_foot );

    print $fpt <<XXX;
</body>
</html>
XXX
    $fpt->close();

    return 1;
}

sub addRawContent {
    my $rawFile  = shift;
    my $document = shift;

    # Check if raw content available
    my $rawEntry = $document->fetch('RawContent');

    # Stop here if nothing
    return 1 unless $rawEntry;

    print "Adding raw content in $rawFile\n";

    my $fpt = FileHandle->new(">$rawFile");
    if ( !defined $fpt ) {
        print "Unable to create $rawFile!\n";
        return 0;
    }

    my $title = 'Raw content of ' . $document->name();

    print $fpt <<XXX;
<head>
<!-- Generated by perlmod2www.pl -->
<title>
$title.
</title>
</head>
<body bgcolor="white">
<b>$title</b>
XXX

    # Add content (of 1st and unique element of returned list)
    print $fpt $rawEntry->[0]->converted();

    print $fpt <<XXX;
</body>
</html>
XXX

    $fpt->close();

    # Change entry converted content with proper url
    my $sep = $tree->path_separator();
    $rawFile =~ /([^$sep]+)$/;
    $rawEntry->[0]->converted( '<a href="' . $1 . '">Raw content</a>' );

    return 1;
}

# PathToLevel: convert dir path to Perl level name

sub PathToLevel {
    my $obj = shift;

    # First get root name of the tree
    my $ret = $tree->root_name();

    # Get path of the passed obj file
    my $name = $obj->path();

    # Return root name if no path in file object
    return $ret if ( !defined $name || $name eq "" );

    # Use path separator defined from tree
    my $sep = quotemeta $tree->path_separator();

    # Replace separator with Perl style
    $name =~ s/^$sep//;
    $name =~ s/$sep/::/g;

    $ret .= '::' . $name;

    return $ret;
}

# RmExt: Just remove the extension from a Pdoc::DocEntry object related to a file.

sub RmExt {
    my $obj = shift;

    my $name = $obj->name();

    $name =~ s/\..+$//;
    return $name;
}

sub Get_head_foot {
    local (*FPT);
    my $line;
    if ( defined $doc_head ) {
        if ( !open( FPT, '<', $doc_head ) ) {
            print "Failed opening documentation header file $doc_head.\n";
            return 0;
        }
        $doc_head = "";
        while ( $line = <FPT> ) {
            $doc_head .= $line;
        }
        close FPT;
    }

    if ( defined $doc_foot ) {
        if ( !open( FPT, '<', $doc_foot ) ) {
            print "Failed opening documentation footer file $doc_foot.\n";
            return 0;
        }

        $doc_foot = "";
        while ( $line = <FPT> ) {
            $doc_foot .= $line;
        }
        close FPT;
    }

    return 1;
}

sub loadXl {
    my $file = shift;

    if ( !-e $file ) {
        print "Cross link table file $file doesn't exists!\n";
        exit;
    }

    # Open file and start to extract lines
    my $fpt = FileHandle->new($file);
    my $line;
    while ( $line = <$fpt> ) {
        chomp($line);
        next if ( $line eq "" );

        # Extract XL definition
        my @parts = split( /\s+/, $line );
        if ( scalar(@parts) != 2 ) {
            print "Invalid cross link reference for $line in file $file!\n";
            $fpt->close();
            Help();
            exit;
        }

        print "Cross-link source: $parts[0] - $parts[1]\n";

        # Keep cross link
        push( @xl, \@parts );
    }

    $fpt->close();
}

sub extractTree {
    my $path = shift;
    my $url  = shift;

    my $ntree = Pdoc::Tree->new();
    $ntree->name('Perl modules documentation.');
    $ntree->path($path);

    # Define directories to exclude
    my @skip = split( ',', $to_skip );
    foreach my $dir (@skip) {
        $ntree->exclude($dir);
    }

    # Get only .pm files
    $ntree->add_filter('.pm$');

    # Get tree and check if successful
    if ( !defined $ntree->root() ) {
        print "Failed parsing tree.\n";
        exit;
    }

    # Define url or redefined path - as necessary
    if ( $url =~ /^http:\/\// ) {
        $ntree->url($url);
    }
    return $ntree;
}

sub addTocEntry {
    my $entry = shift;
    my $doc   = shift;

    # Clean stuff
    my $name = $entry->name();
    $name =~ /([^\:]+)$/;
    $name = $1;
    $entry->name($name);
    my $content = $entry->content();
    $content =~ s/\s*[^ ]+\s+-?\s*(.*)/$1/;
    $entry->content($content);
    $entry->set( 'url', $name . '.html' );
    $doc->add($entry);
}

sub initTocAll {

    # Init toc
    my $tocTitle = "TOC for all levels";
    print $tocAllFpt <<XXX;
<html>
<HEAD>
<!-- Generated by perlmod2www.pl -->
<TITLE>
$tocTitle
</TITLE>
</HEAD>
<BODY BGCOLOR="WHITE">
<A NAME="top"></A>
<TABLE BORDER="0" WIDTH="100%">
<TR><TD BGCOLOR="$_scptConf->{'tocLevel'}"><B>$tocTitle</B></TD></TR>
</TABLE>
<TABLE BORDER="1" WIDTH="100%">
XXX

    # Build index
    my $node = $tree->root();
    my $name = PathToLevel($node);
    print $tocAllFpt '<TR><TD BGCOLOR="', $_scptConf->{'tocLevel'},
      '"><A HREF="#',
      $name, '"><B>', $name, '</B></A></TD></TR>', "\n";

    nodeToc($node);

    print $tocAllFpt <<XXX;
</TABLE>
<HR>
XXX
}

sub nodeToc {
    my $node = shift;

    my $niter = $node->nodeIterator();
    my $nentry;
    while ( $nentry = $niter->() ) {
        my $name = PathToLevel($nentry);
        print $tocAllFpt '<TR><TD BGCOLOR="', $_scptConf->{'tocLevel'},
          '"><A HREF="#', $name, '"><B>', $name,
          '</B></A></TD></TR>', "\n";
    }

    $niter = $node->nodeIterator();
    while ( $nentry = $niter->() ) {
        nodeToc($nentry);
    }
}

# Get_args: process the arguments passed to the script.

sub Get_args {
    my $arg;

    while ( $arg = shift(@ARGV) ) {
        if ( $arg eq "-h" || $arg eq "-help" ) {
            Help();
            exit;
        }

        if ( $arg eq '-source' ) {
            $source = shift(@ARGV);
        }
        elsif ( $arg eq '-target' ) {
            $target = shift(@ARGV);
        }
        elsif ( $arg eq '-wroot' ) {
            $wroot = shift(@ARGV);
        }
        elsif ( $arg eq '-skip' ) {
            $to_skip .= ',' . shift(@ARGV);
        }
        elsif ( $arg eq '-doc_header' ) {
            $doc_head = shift(@ARGV);
        }
        elsif ( $arg eq '-doc_footer' ) {
            $doc_foot = shift(@ARGV);
        }
        elsif ( $arg eq '-nosort' ) {
            $noSort = 1;
        }
        elsif ( $arg eq '-conf' ) {
            $confFile = shift(@ARGV);
        }
        elsif ( $arg eq '-isa' ) {
            $isaCheck = 1;
        }
        elsif ( $arg eq '-webcvs' ) {
            $webCvs   = shift(@ARGV);
            $parseDoc = 1;
        }
        elsif ( $arg eq '-raw' ) {
            $useRaw = 1;
        }
        elsif ( $arg eq '-xl' ) {
            my $tmp = shift(@ARGV);
            my @parts = split( ',', $tmp );
            if ( scalar(@parts) != 2 ) {
                print "Invalid cross link reference for $tmp!\n";
                Help();
                exit;
            }

            push( @xl, \@parts );
        }
        elsif ( $arg eq '-xltable' ) {
            my $file = shift(@ARGV);
            loadXl($file);
        }
    }
}

# Help: -h

sub Help {
    print <<XXX;
perlmod2www.pl - a Perl modules tree documentation generator.

Mandatory arguments:
    -source <path>: Directory location of the tree with the Perl modules, must be existing.
    -target <path>: Directory location on the server side where the documentation tree will be generated, must be existing.
    -wroot <http>:  Url corresponding to the target directory.
Optional arguments:
    -skip dir1,dir2,dir3,...: skip the directory names separated by a comma (,). By default CVS directories are skipped.
    -doc_header <file name>: file with piece of HTML code that will be placed on top of every Perl module documentation (after <BODY>!).
    -doc_footer <file name>: file with piece of HTML code that will be placed at the end of every Perl module documentation (before </BODY>!).
    -xl <path>,<url>: used to cross linking documentation trees. Requires the root path and the root url of a second tree to cross link separated by a comma (,). Multiple instances are allowed (-xl <path1>,<url1> -xl <path2>,<url2> ...).
    -xltable <file>: refers to a file with a list of cross link definitions. The file must contain one line by cross link definition and the definition is composed of the root path and the root url separated by space(s).
    -webcvs <url>: allows to add cross link to webcvs in the toolbar area of the doc page.
    Note that the relative path of the modules will be appended to this url with modules in the root tree defined as /<module file name>.
    -nosort: disable the automatic sorting of the documented methods in the html page.
    -raw: use this argument to include a 'Raw content' link in the toolbar (to access file raw content in the documentation pages).
    -isa: will activate ISA modules check. When an inherited Perl module is not
    found, a warning will be issued.
XXX
}
