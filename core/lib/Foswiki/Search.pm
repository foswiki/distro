# See bottom of file for license and copyright information
package Foswiki::Search;

=begin TML

---+ package Foswiki::Search

This module implements all the search functionality.

=cut

use strict;
use Assert;
use Error qw( :try );

use Foswiki                           ();
use Foswiki::Sandbox                  ();
use Foswiki::Search::InfoCache        ();
use Foswiki::ListIterator             ();
use Foswiki::Iterator::FilterIterator ();
use Foswiki::WebFilter                ();

#TODO: move these into a more appropriate place - they are function objects so can persist for a _long_ time
my $queryParser;
my $searchParser;

BEGIN {

    # 'Use locale' for internationalisation of Perl sorting and searching -
    # main locale settings are done in Foswiki::setupLocale
    # Do a dynamic 'use locale' for this module
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ ClassMethod new ($session)

Constructor for the singleton Search engine object.

=cut

sub new {
    my ( $class, $session ) = @_;
    my $this = bless( { session => $session }, $class );

    return $this;
}

=begin TML

---++ ObjectMethod finish()
Break circular references.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;
    undef $this->{session};
}

sub _extractPattern {
    my ( $text, $pattern ) = @_;

    # Pattern comes from topic, therefore tainted
    $pattern =
      Foswiki::Sandbox::untaint( $pattern, \&Foswiki::validatePattern );

    my $ok = 0;
    eval {

        # The eval acts as a try block in case there is anything evil in
        # the pattern.
        $ok = 1 if ( $text =~ s/$pattern/$1/is );
    };
    $text = '' unless $ok;

    return $text;
}

# With the same argument as $pattern, returns a number which is the count of
# occurences of the pattern argument.
sub _countPattern {
    my ( $text, $pattern ) = @_;

    $pattern =
      Foswiki::Sandbox::untaint( $pattern, \&Foswiki::validatePattern );

    my $count;
    try {

        # see: perldoc -q count
        $count = () = $text =~ /$pattern/g;
    }
    catch Error::Simple with {
        $count = 0;
    };

    return $count;
}

# get a list of topics to search in the web, filtered by the $topic
# spec
sub _getTopicList {
    my ( $this, $webObject, $options ) = @_;

    # E.g. "Web*, FooBar" ==> "^(Web.*|FooBar)$"
    $options->{excludeTopics} = _makeTopicPattern( $options->{excludeTopics} )
      if ( $options->{excludeTopics} );

    my $topicFilter;
    my $it;
    if ( $options->{includeTopics} ) {

        # E.g. "Bug*, *Patch" ==> "^(Bug.*|.*Patch)$"
        $options->{includeTopics} =
          _makeTopicPattern( $options->{includeTopics} );

        # limit search to topic list
        if ( $options->{includeTopics} =~
            /^\^\([\_\-\+$Foswiki::regex{mixedAlphaNum}\|]+\)\$$/ )
        {

            # topic list without wildcards
            # for speed, do not get all topics in web
            # but convert topic pattern into topic list
            my $topics = $options->{includeTopics};
            $topics =~ s/^\^\(//o;
            $topics =~ s/\)\$//o;

            # build list from topic pattern
            #TODO: erm, what about non-case senstive?
            my @list =
              grep( $this->{session}->topicExists( $webObject->web, $_ ),
                split( /\|/, $topics ) );
            $it = new Foswiki::ListIterator( \@list );
        }
        elsif ( !$options->{casesensitive} ) {
            $topicFilter = qr/$options->{includeTopics}/i;
        }
        else {
            $topicFilter = qr/$options->{includeTopics}/;
        }
    }

    $it = $webObject->eachTopic() unless ( defined($it) );

    my $filterIter = new Foswiki::Iterator::FilterIterator(
        $it,
        sub {
            my $item = shift;

            #my $data = shift;
            return unless !$topicFilter || $item =~ /$topicFilter/;

            # exclude topics, Codev.ExcludeWebTopicsFromSearch
            if ( $options->{casesensitive} && $options->{excludeTopics} ) {
                return if $item =~ /$options->{excludeTopics}/i;
            }
            elsif ( $options->{excludeTopics} ) {
                return if $item =~ /$options->{excludeTopics}/;
            }
            return 1;
        }
    );
    return $filterIter;
}

#convert a comma separated list of webs into the list we'll process
sub _getListOfWebs {
    my ( $this, $webName, $recurse, $searchAllFlag ) = @_;
    my $session = $this->{session};

    my %excludeWeb;
    my @tmpWebs;

    if ($webName) {
        foreach my $web ( split( /[\,\s]+/, $webName ) ) {
            $web =~ s#\.#/#go;

            # the web processing loop filters for valid web names,
            # so don't do it here.
            if ( $web =~ s/^-// ) {
                $excludeWeb{$web} = 1;
            }
            else {
                if (   $web =~ /^(all|on)$/i
                    || $Foswiki::cfg{EnableHierarchicalWebs}
                    && Foswiki::isTrue($recurse) )
                {
                    require Foswiki::WebFilter;
                    my $webObject;
                    my $prefix = "$web/";
                    if ( $web =~ /^(all|on)$/i ) {
                        $webObject = Foswiki::Meta->new($session);
                        $prefix    = '';
                    }
                    else {
                        push( @tmpWebs, $web );
                        $webObject = Foswiki::Meta->new( $session, $web );
                    }
                    my $it = $webObject->eachWeb(1);
                    while ( $it->hasNext() ) {
                        my $w = $prefix . $it->next();
                        next
                          unless $Foswiki::WebFilter::user_allowed->ok(
                            $session, $w );
                        push( @tmpWebs, $w );
                    }
                }
                else {
                    push( @tmpWebs, $web );
                }
            }
        }

    }
    else {

        # default to current web
        push( @tmpWebs, $session->{webName} );
        if ( Foswiki::isTrue($recurse) ) {
            my $webObject = Foswiki::Meta->new( $session, $session->{webName} );
            my $it =
              $webObject->eachWeb( $Foswiki::cfg{EnableHierarchicalWebs} );
            while ( $it->hasNext() ) {
                my $w = $session->{webName} . '/' . $it->next();
                next
                  unless $Foswiki::WebFilter::user_allowed->ok( $session, $w );
                push( @tmpWebs, $w );
            }
        }
    }

    my @webs;
    foreach my $web (@tmpWebs) {
        push( @webs, $web ) unless $excludeWeb{$web};
        $excludeWeb{$web} = 1;    # eliminate duplicates
    }

    return @webs;
}

sub _makeTopicPattern {
    my ($topic) = @_;
    return '' unless ($topic);

    # 'Web*, FooBar' ==> ( 'Web*', 'FooBar' ) ==> ( 'Web.*', "FooBar" )
    my @arr =
      map { s/[^\*\_\-\+$Foswiki::regex{mixedAlphaNum}]//go; s/\*/\.\*/go; $_ }
      split( /(?:,\s*|\|)/, $topic );
    return '' unless (@arr);

    # ( 'Web.*', 'FooBar' ) ==> "^(Web.*|FooBar)$"
    return '^(' . join( '|', @arr ) . ')$';
}

=begin TML

---++ ObjectMethod searchWeb (...)

Search one or more webs according to the parameters.

If =_callback= is set, that means the caller wants results as
soon as they are ready. =_callback_ should be set to a reference
to a function which takes =_cbdata= as the first parameter and
remaining parameters the same as 'print'.

If =_callback= is set, the result is always undef. Otherwise the
result is a string containing the rendered search results.

If =inline= is set, then the results are *not* decorated with
the search template head and tail blocks.

The function will throw Error::Simple if it encounters any problems with the
syntax of the search string.

Note: If =format= is set, =template= will be ignored.

Note: For legacy, if =regex= is defined, it will force type='regex'

If =type="word"= it will be changed to =type="keyword"= with =wordboundaries=1=. This will be used for searching with scope="text" only, because scope="topic" will do a Perl search on topic names.

SMELL: If =template= is defined =bookview= will not work

SMELL: it seems that if you define =_callback= or =inline= then you are
	responsible for converting the TML to HTML yourself!

FIXME: =callback= cannot work with format parameter (consider format='| $topic |'

=cut

sub searchWeb {
    my $this    = shift;
    my $session = $this->{session};
    ASSERT( defined $session->{webName} ) if DEBUG;
    my %params = @_;

    my $inline = $params{inline};

#TODO: SMELL: work out the $inline bit - its set to 0 in the search cgi, see Item2342 (turn on ASSERT..)
    my $baseWebObject =
      Foswiki::Meta->new( $session, $session->{webName},
        $inline ? undef : $session->{topicName} );

	my ($callback, $cbdata) = setup_callback(\%params, $baseWebObject);

    my $baseTopic = $params{basetopic} || $session->{topicName};
    my $baseWeb   = $params{baseweb}   || $session->{webName};
    $params{casesensitive} = Foswiki::isTrue( $params{casesensitive} );
    $params{excludeTopics} = $params{excludetopic} || '';
    my $formatDefined = $params{formatdefined} = defined $params{format};
    my $format = $params{format};

    $params{multiple} = Foswiki::isTrue( $params{multiple} );
    $params{nonoise}  = Foswiki::isTrue( $params{nonoise} );
    $params{noempty}  = Foswiki::isTrue( $params{noempty}, $params{nonoise} );
    $params{zeroresults} =
      1 - Foswiki::isTrue( ( $params{zeroresults} || 'on' ), $params{nonoise} );

#paging - this code should be hidden in the InfoCache iterator, but atm, that won't let me do multi-web
    my $pagesize =
         $params{pagesize}
      || $Foswiki::cfg{Search}{DefaultPageSize}
      || 25;
    my $showpage = $params{showpage}
      || undef;    # 1-based system; 0 is not a valid page number
    if ( defined($showpage) ) {
        $params{pager_skip_results_from} = $pagesize * ( $showpage - 1 );
        $params{pager_show_results_to} = $pagesize;
    }

    #TODO: refactorme
    my $header  = $params{header};
    my $footer  = $params{footer};
    my $noTotal = Foswiki::isTrue( $params{nototal}, $params{nonoise} );

    my $noEmpty = Foswiki::isTrue( $params{noempty}, $params{nonoise} );

    # Note: a defined header/footer overrides noheader/nofooter
    # To maintain Cairo compatibility we ommit default header/footer if the
    # now deprecated option 'inline' is used combined with 'format'
    my $noHeader =
      !defined($header)
      && Foswiki::isTrue( $params{noheader}, $params{nonoise} )
      || ( !$header && $formatDefined && $inline );

    my $noFooter =
      !defined($footer)
      && Foswiki::isTrue( $params{nofooter}, $params{nonoise} )
      || ( !$footer && $formatDefined && $inline );

    my $noSummary = Foswiki::isTrue( $params{nosummary}, $params{nonoise} );
    my $zeroResults =
      1 - Foswiki::isTrue( ( $params{zeroresults} || 'on' ), $params{nonoise} );

    #END TODO
	
    my $doBookView = Foswiki::isTrue( $params{bookview} );
    my $nonoise    = Foswiki::isTrue( $params{nonoise} );
    my $noSearch   = Foswiki::isTrue( $params{nosearch}, $nonoise );
    
    
    my $sortOrder = $params{order} || '';
    my $revSort = Foswiki::isTrue( $params{reverse} );
    $params{scope} = $params{scope} || '';
    my $searchString = defined $params{search} ? $params{search} : '';

    $params{includeTopics} = $params{topic} || '';
    $params{type}          = $params{type}  || '';

    $params{wordboundaries} = 0;
    if ( $params{type} eq 'word' ) {

        # 'word' is exactly the same as 'keyword', except we will be searching
        # with word boundaries
        $params{type}           = 'keyword';
        $params{wordboundaries} = 1;
    }

    my $webName = $params{web}       || '';
    my $date    = $params{date}      || '';
    my $recurse = $params{'recurse'} || '';
    my $finalTerm = $inline ? ( $params{nofinalnewline} || 0 ) : 0;

    $baseWeb =~ s/\./\//go;

    $params{type} = 'regex' if ( $params{regex} );

    my $mixedAlpha = $Foswiki::regex{mixedAlpha};
    my $separator  = $params{separator};
    if ( defined($separator) ) {
        $separator =~ s/\$n\(\)/\n/gos;    # expand "$n()" to new line
        $separator =~ s/\$n([^$mixedAlpha]|$)/\n$1/gos;
    }
    $params{separator} = $separator;
    my $newLine = $params{newline} || '';
    if ($newLine) {
        $newLine =~ s/\$n\(\)/\n/gos;                # expand "$n()" to new line
        $newLine =~ s/\$n([^$mixedAlpha]|$)/\n$1/gos;
    }

    # A value of 'all' or 'on' by itself gets all webs,
    # otherwise ignored (unless there is a web called 'All'.)
    my $searchAllFlag = ( $webName =~ /(^|[\,\s])(all|on)([\,\s]|$)/i );

    my @webs = $this->_getListOfWebs( $webName, $recurse, $searchAllFlag );

    #to help later processing (formatResults)
    $params{numberOfWebs} = scalar(@webs);

    # Write log entry
    # FIXME: Move log entry further down to log actual webs searched
    if ( !$inline ) {
        my $t = join( ' ', @webs );
        $session->logEvent( 'search', $t, $searchString );
    }

    my $query;

    if ( length($searchString) == 0 ) {

        #default search should return no results
        $searchString = '1 = 2';

    #shortcircuit the search
    #FIXME: this breaks the per-web summary output that is hidden in the foreach
        @webs = ();
    }

    my $theParser;
    if ( $params{type} eq 'query' ) {
        unless ( defined($queryParser) ) {
            require Foswiki::Query::Parser;
            $queryParser = new Foswiki::Query::Parser();
        }
        $theParser = $queryParser;
    }
    else {
        unless ( defined($searchParser) ) {
            require Foswiki::Search::Parser;
            $searchParser = new Foswiki::Search::Parser($session);
        }
        $theParser = $searchParser;
    }
    try {
        $query = $theParser->parse( $searchString, \%params );
    }
    catch Foswiki::Infix::Error with {

        # Pass the error on to the caller
        throw Error::Simple( shift->stringify() );
    };

#TODO: redo with a $query->isEmpty() or something generic, and then push into the foreach?
    unless ( $params{type} eq 'query' ) {

    #shorcircuit the search foreach below for a zero result search
    #FIXME: this breaks the per-web summary output that is hidden in the foreach
        @webs = () unless scalar( @{ $query->{tokens} } );    #default
    }

	my ($tmplHead, $tmplSearch, $tmplTail) = $this->loadTemplates(\%params, $baseWebObject, 
						$formatDefined, $doBookView, $noHeader, $noSummary, $noTotal, $noFooter);


    # If not inline search, also expand tags in head and tail sections
    unless ($inline) {
        $tmplHead = $baseWebObject->expandMacros($tmplHead);

        &$callback( $cbdata, $tmplHead );
    }

    # Generate 'Search:' part showing actual search string used
    unless ($noSearch) {
        my $searchStr = $searchString;
        $searchStr =~ s/&/&amp;/go;
        $searchStr =~ s/</&lt;/go;
        $searchStr =~ s/>/&gt;/go;
        $searchStr =~ s/^\.\*$/Index/go;

        # Expand tags in template sections
        $tmplSearch = $baseWebObject->expandMacros($tmplSearch);
        $tmplSearch =~ s/%SEARCHSTRING%/$searchStr/go;
        &$callback( $cbdata, $tmplSearch );
    }

    # Loop through webs
    my $isAdmin = $session->{users}->isAdmin( $session->{user} );
    my $ttopics = 0;
    my $prefs   = $session->{prefs};
    foreach my $web (@webs) {

        $web = Foswiki::Sandbox::untaint( $web,
            \&Foswiki::Sandbox::validateWebName );

        # can't process what ain't thar
        next unless $session->webExists($web);

        my $webObject = Foswiki::Meta->new( $session, $web );
        my $thisWebNoSearchAll = $webObject->getPreference('NOSEARCHALL') || '';

        # make sure we can report this web on an 'all' search
        # DON'T filter out unless it's part of an 'all' search.
        next
          if ( $searchAllFlag
            && !$isAdmin
            && ( $thisWebNoSearchAll =~ /on/i || $web =~ /^[\.\_]/ )
            && $web ne $session->{webName} );

        # Run the search on topics in this web
        my $inputTopicSet = _getTopicList( $this, $webObject, \%params );

        next
          if ( $params{noempty} && !$inputTopicSet->hasNext() )
          ;    # Nothing to show for this web

        my $infoCache = $webObject->query( $query, $inputTopicSet, \%params );
        $infoCache->sortResults( $web, \%params );

        # add dependencies
        my $cache = $session->{cache};
        if ($cache) {

            #TODO: ouch - this forces pre-evaluation of results,
            # and assumes we need or care to evaluate all of them :/
            # I wonder if this makes paging head processing heavy
            foreach my $topic ( $infoCache->{list} ) {
                $cache->addDependency( $web, $topic );
            }
        }

     # add legacy SEARCH separator - see Item1773 (TODO: find a better approach)
        &$callback( $cbdata, $separator )
          if ( ( $ttopics > 0 ) and $noFooter and $noSummary and $separator );

        my ( $web_ttopics, $web_searchResult );
        ( $web_ttopics, $web_searchResult ) =
          $this->formatResults( $webObject, $query, $searchString, $infoCache,
            \%params );

        $ttopics += $web_ttopics;

        #paging
        if ( defined($showpage) and $params{pager_show_results_to} > 0 ) {
            $params{pager_show_results_to} -= $web_ttopics;
            last if ( $params{pager_show_results_to} <= 0 );
        }
    }    # end of: foreach my $web ( @webs )
    return '' if ( $ttopics == 0 && $params{zeroresults} );

    unless ($inline) {
        $tmplTail = $baseWebObject->expandMacros($tmplTail);

        &$callback( $cbdata, $tmplTail );
    }

    return if ( defined $params{_callback} );

    my $searchResult = join( '', @{ $params{_cbdata} } );
    if ( $formatDefined && !$finalTerm ) {
        if ($separator) {
            $separator = quotemeta($separator);
            $searchResult =~ s/$separator$//s;    # remove separator at end
        }
        else {
            $searchResult =~ s/\n$//os;           # remove trailing new line
        }
    }

    return $searchResult if $inline;

    $searchResult = $baseWebObject->expandMacros($searchResult);
    $searchResult = $baseWebObject->renderTML($searchResult);

    return $searchResult;
}

sub loadTemplates {
	my ($this, $params, $baseWebObject, $formatDefined, $doBookView, $noHeader, $noSummary, $noTotal, $noFooter) = @_;
	
	my $session            = $this->{session};

    #tmpl loading code.
    my $tmpl = '';

    my $template = $params->{template} || '';
    if ($formatDefined) {
        $template = 'searchformat';
    }
    elsif ($template) {

        # template definition overrides book and rename views
    }
    elsif ($doBookView) {
        $template = 'searchbookview';
    }
    else {
        $template = 'search';
    }
    $tmpl = $session->templates->readTemplate($template);

    # SMELL: the only META tags in a template will be METASEARCH
    # Why the heck are they being filtered????
    $tmpl =~ s/\%META{.*?}\%//go;    # remove %META{'parent'}%

    # Split template into 5 sections
    my ( $tmplHead, $tmplSearch, $tmplTable, $tmplNumber, $tmplTail ) =
      split( /%SPLIT%/, $tmpl );

    # Invalid template?
    #TODO: replace with an exception.
    if ( !defined($tmplTail) ) {
        my $mess =
            'Foswiki Installation Error: '
          . 'Incorrect format of '
          . $template
          . ' template (missing sections? There should be 4 %SPLIT% tags)';
        throw Error::Simple( $mess );
    }

    {

        # header and footer of $web
        my ( $beforeText, $repeatText, $afterText ) =
          split( /%REPEAT%/, $tmplTable );

        unless ($noHeader) {
            $params->{header} = $beforeText unless defined $params->{header};
        }

        #nosummary="on" nosearch="on" noheader="on" nototal="on"
        if ($noSummary) {
            $repeatText =~ s/%TEXTHEAD%//go;
            $repeatText =~ s/&nbsp;//go;
        }
        else {
            $repeatText =~ s/%TEXTHEAD%/\$summary/go;
        }
        $params->{format} |= $repeatText;
        unless ($noFooter) {
            $params->{footer} |= $afterText;
        }
        unless ($noTotal) {
            $params->{footercounter} |= $baseWebObject->expandMacros($tmplNumber);
            $params->{footer} .= $params->{footercounter};
        }
        else {

            #print STDERR "}}}".$params{format}."{{{";
        }
    }
    return ($tmplHead, $tmplSearch, $tmplTail);
}

=begin TML
---++ formatResults

the implementation of %FORMAT{}%

TODO: rewrite to take a resultset, a set of params? and a hash of sub's to
enable evaluations of things like '$include(blah)' in format strings.

have a default set of replacements like $lt, $nop, $percnt, $dollar etc, and then
the hash of subs can take care of %MACRO{}% specific complex to evaluate replacements..

(that way we don't pre-evaluate and then subst)

=cut

sub formatResults {
    my ( $this, $webObject, $query, $searchString, $infoCache, $params ) = @_;
    my $session            = $this->{session};
    my $users              = $session->{users};
    my $web                = $webObject->web;
    my $thisWebNoSearchAll = $webObject->getPreference('NOSEARCHALL') || '';


	my ($callback, $cbdata) = setup_callback($params);

    my $baseTopic = $params->{basetopic} || $session->{topicName};
    my $baseWeb   = $params->{baseweb}   || $session->{webName};
    my $doBookView    = Foswiki::isTrue( $params->{bookview} );
    my $caseSensitive = Foswiki::isTrue( $params->{casesensitive} );
    my $doExpandVars  = Foswiki::isTrue( $params->{expandvariables} );
    my $nonoise       = Foswiki::isTrue( $params->{nonoise} );
    my $noSearch      = Foswiki::isTrue( $params->{nosearch}, $nonoise );
    my $formatDefined = defined $params->{format};
    my $format        = $params->{format} || '';
    my $header        = $params->{header} || '';
    my $footer        = $params->{footer} || '';
    my $inline        = $params->{inline};
    my $limit         = $params->{limit} || '';

# Limit search results
#TODO: I _think_ that limit should be able to be deprecated and replaced by pagesize..
    if ( $limit =~ /(^\d+$)/o ) {

        # only digits, all else is the same as
        # an empty string.  "+10" won't work.
        $limit = $1;
    }
    else {

        # change 'all' to 0, then to big number
        $limit = 0;
    }
    $limit = 32000 unless ($limit);
    if ( defined( $params->{pager_show_results_to} )
        and $params->{pager_show_results_to} > 0 )
    {
        $limit = $params->{pager_show_results_to};
    }

    #TODO: multiple is an attribute of the ResultSet
    my $doMultiple = Foswiki::isTrue( $params->{multiple} );
    my $noEmpty = Foswiki::isTrue( $params->{noempty}, $nonoise );

    # Note: a defined header/footer overrides noheader/nofooter
    # To maintain Cairo compatibility we ommit default header/footer if the
    # now deprecated option 'inline' is used combined with 'format'
    my $noHeader =
      !defined($header) && Foswiki::isTrue( $params->{noheader}, $nonoise )
      || ( !$header && $formatDefined && $inline );

    my $noFooter =
      !defined($footer) && Foswiki::isTrue( $params->{nofooter}, $nonoise )
      || ( !$footer && $formatDefined && $inline );

    my $noSummary = Foswiki::isTrue( $params->{nosummary}, $nonoise );
    my $zeroResults =
      1 - Foswiki::isTrue( ( $params->{zeroresults} || 'on' ), $nonoise );
    my $noTotal = Foswiki::isTrue( $params->{nototal}, $nonoise );
    my $newLine   = $params->{newline} || '';
    my $separator = $params->{separator};
    my $type      = $params->{type} || '';

    if ( defined $header ) {
        $header = Foswiki::expandStandardEscapes($header);
        $header =~ s/\$web/$web/gos;      # expand name of web
        $header =~ s/([^\n])$/$1\n/os;    # add new line at end
    }

    if ( defined $footer ) {
        $footer = Foswiki::expandStandardEscapes($footer);
        $footer =~ s/\$web/$web/gos;      # expand name of web
        $footer =~ s/([^\n])$/$1\n/os;    # add new line at end
    }

    # output the list of topics in $web
    my $ntopics    = 0;         # number of topics in current web
    my $nhits      = 0;         # number of hits (if multiple=on) in current web
    my $headerDone = $noHeader;

    while ( $infoCache->hasNext() ) {
        my $topic = $infoCache->next();

        #pager..
        if ( defined( $params->{pager_skip_results_from} )
            and $params->{pager_skip_results_from} > 0 )
        {
            $params->{pager_skip_results_from}--;
            next;
        }

        my $info = $infoCache->get($topic);
        my $text;    #current hits' text

# Check security (don't show topics the current user does not have permission to view)
        next unless $info->{allowView};

        # Special handling for format='...'
        if ($formatDefined) {
            $text = $info->{tom}->text();

            if ($doExpandVars) {
                if ( $web eq $baseWeb && $topic eq $baseTopic ) {

                    # primitive way to prevent recursion
                    $text =~ s/%SEARCH/%<nop>SEARCH/g;
                }
                $text = $info->{tom}->expandMacros($text);
            }
        }

        #TODO: should extract this somehow
        my @multipleHitLines = ();
        if ( $doMultiple && $query->{tokens} ) {

            #TODO: i wonder if this shoudl be a HoistRE..
            my @tokens  = @{ $query->{tokens} };
            my $pattern = $tokens[$#tokens];       # last token in an AND search
            $pattern = quotemeta($pattern) if ( $type ne 'regex' );
            unless ($text) {
                $text = $info->{tom}->text();
            }
            if ($caseSensitive) {
                @multipleHitLines =
                  reverse grep { /$pattern/ } split( /[\n\r]+/, $text );
            }
            else {
                @multipleHitLines =
                  reverse grep { /$pattern/i } split( /[\n\r]+/, $text );
            }
        }

        my $epochSecs = $info->{modified};
        require Foswiki::Time;
        my $revDate = Foswiki::Time::formatTime($epochSecs);
        my $isoDate = Foswiki::Time::formatTime( $epochSecs, '$iso', 'gmtime' );

        my $ru     = $info->{editby} || 'UnknownUser';
        my $revNum = $info->{revNum} || 0;

        $ntopics += 1;
        do {    # multiple=on loop

            $nhits += 1;
            my $out = '';

            $text = pop(@multipleHitLines) if ( scalar(@multipleHitLines) );

            if ($formatDefined) {
                $out = $format;
                $out =~ s/\$web/$web/gs;

                #TODO: move the breakName etc into Render::renderRevisionInfo
                $out =~ s/\$topic\(([^\)]*)\)/
                  Foswiki::Render::breakName( $topic, $1 )/ges;
                $out =~ s/\$topic/$topic/gs;
                $out =~ s/\$date/$revDate/gs;
                $out =~ s/\$isodate/$isoDate/gs;
                $out =~ s/\$rev/$revNum/gs;
                $out =~ s/\$ntopics/$ntopics/gs;
                $out =~ s/\$nhits/$nhits/gs;

                #TODO: replace this with a single call to renderRevisionInfo
                if ( $out =~ /\$(wikiusername|wikiname|username)/ ) {
                    $out =
                      $session->renderer->renderRevisionInfo( $info->{tom},
                        $revNum, $out );
                }

  #TODO: move the $create* formats into Render::renderRevisionInfo..
  #which implies moving the infocache's pre-extracted data into the tom obj too.
                $out =~ s/\$create(date|username|wikiname|wikiusername)/
                  $infoCache->getRev1Info( $topic, "create$1" )/ges;

                if ( $out =~ m/\$text/ ) {
                    unless ($text) {
                        $text = $info->{tom}->text();
                    }
                    if ( $topic eq $session->{topicName} ) {

                        # defuse SEARCH in current topic to prevent loop
                        $text =~ s/%SEARCH{.*?}%/SEARCH{...}/go;
                    }
                    $out =~ s/\$text/$text/gos;
                }
            }
            else {
                die "no such thing? ($format)";

                #$out = $repeatText;
            }
            $out =~ s/%WEB%/$web/go;
            $out =~ s/%TOPICNAME%/$topic/go;
            $out =~ s/%TIME%/$revDate/o;

            my $srev = 'r' . $revNum;
            if ( $revNum eq '0' || $revNum eq '1' ) {
                $srev = CGI::span( { class => 'foswikiNew' },
                    ( $session->i18n->maketext('NEW') ) );
            }
            $out =~ s/%REVISION%/$srev/o;
            $out =~ s/%AUTHOR%/$session->renderer->renderRevisionInfo( 
                                                     $info->{tom}, $revNum, '$wikiusername' )/e;

            if ($doBookView) {

                # BookView
                unless ($text) {
                    $text = $info->{tom}->text();
                }
                if ( $web eq $baseWeb && $topic eq $baseTopic ) {

                    # primitive way to prevent recursion
                    $text =~ s/%SEARCH/%<nop>SEARCH/g;
                }
                $text = $info->{tom}->expandMacros($text);
                $text = $info->{tom}->renderTML($text);

                $out =~ s/%TEXTHEAD%/$text/go;

            }
            elsif ($formatDefined) {
                $out =~ s/\$summary(?:\(([^\)]*)\))?/
                  $info->{tom}->summariseText( $1, $text )/ges;
                $out =~ s/\$changes(?:\(([^\)]*)\))?/
                  $info->{tom}->summariseChanges($1, $revNum)/ges;
                $out =~ s/\$formfield\(\s*([^\)]*)\s*\)/
                  displayFormField( $info->{tom}, $1 )/ges;
                $out =~ s/\$parent\(([^\)]*)\)/
                  Foswiki::Render::breakName(
                      $info->{tom}->getParent(), $1 )/ges;
                $out =~ s/\$parent/$info->{tom}->getParent()/ges;
                $out =~ s/\$formname/$info->{tom}->getFormName()/ges;
                $out =~
                  s/\$count\((.*?\s*\.\*)\)/_countPattern( $text, $1 )/ges;

   # FIXME: Allow all regex characters but escape them
   # Note: The RE requires a .* at the end of a pattern to avoid false positives
   # in pattern matching
                $out =~
                  s/\$pattern\((.*?\s*\.\*)\)/_extractPattern( $text, $1 )/ges;
                $out =~ s/\r?\n/$newLine/gos if ($newLine);
                if ( !defined($separator) ) {

# add new line at end if needed
# SMELL: why?
#TODO: god, this needs to be made SEARCH legacy somehow (it has impact when format="asdf$n", rather than format="asdf\n")
#SMELL: I wonder if this can't be wrapped into the summarizeText code
                    unless ( $noTotal && !$params->{formatdefined} ) {
                        $out =~ s/([^\n])$/$1\n/s;
                    }
                }

                $out = Foswiki::expandStandardEscapes($out);

            }
            elsif ($noSummary) {
                die "no such thing? (noSummary)";
                $out =~ s/%TEXTHEAD%//go;
                $out =~ s/&nbsp;//go;

            }
            else {
                die "no such thing? (ke)";

                # regular search view
                $text = $info->{tom}->summariseText( '', $text );
                $out =~ s/%TEXTHEAD%/$text/go;
            }

            # lazy output of header (only if needed for the first time)
            unless ($headerDone) {
                $headerDone = 1;
                my $thisWebBGColor = $webObject->getPreference('WEBBGCOLOR')
                  || '\#FF00FF';
                $header =~ s/%WEBBGCOLOR%/$thisWebBGColor/go;
                $header =~ s/%WEB%/$web/go;
                $header =~ s/\$ntopics/0/gs;
                $header =~ s/\$nhits/0/gs;
                $header = $webObject->expandMacros($header);
                &$callback( $cbdata, $header );
            }

            # don't expand if a format is specified - it breaks tables and stuff
            unless ($formatDefined) {
                $out = $webObject->renderTML($out);
            }

            &$callback( $cbdata, $separator )
              if ( defined($separator) and $nhits > 1 );
            &$callback( $cbdata, $out );
        } while (@multipleHitLines);    # multiple=on loop

        last if ( $ntopics >= $limit );
    }    # end topic loop

    # output footer only if hits in web
    if ($ntopics) {

        # output footer of $web
        $footer =~ s/\$ntopics/$ntopics/gs;
        $footer =~ s/\$nhits/$nhits/gs;

        #legacy SEARCH counter support
        $footer =~ s/%NTOPICS%/$ntopics/go;

        $footer = $webObject->expandMacros($footer);
        if ( $inline || $formatDefined ) {
            $footer =~ s/\n$//os;    # remove trailing new line
        }

        if ( defined($separator) ) {

 #	$header = $header.$separator if (defined($params->{header}));
 #TODO: see Item1773 for discussion (foswiki 1.0 compatibility removes the if..)
            &$callback( $cbdata, $separator )
              if ( defined( $params->{footer} ) );
        }
        else {

#TODO: legacy from SEARCH - we want to remove this oddness
#    	&$callback( $cbdata, $separator ) if (defined($params->{footer}) && $footer ne '<nop>');
        }

        &$callback( $cbdata, $footer );
    }

    return ( $ntopics,
        ( ( not defined( $params->{_callback} ) ) and ( $nhits >= 0 ) )
        ? join( '', @$cbdata )
        : '' );
}

=begin TML

---++ StaticMethod displayFormField( $meta, $args ) -> $text

Parse the arguments to a $formfield specification and extract
the relevant formfield from the given meta data.

   * =args= string containing name of form field

In addition to the name of a field =args= can be appended with a commas
followed by a string format (\d+)([,\s*]\.\.\.)?). This supports the formatted
search function $formfield and is used to shorten the returned string or a
hyphenated string.

=cut

sub displayFormField {
    my ( $meta, $args ) = @_;

    my $name      = $args;
    my $breakArgs = '';
    my @params    = split( /\,\s*/, $args, 2 );
    if ( @params > 1 ) {
        $name      = $params[0] || '';
        $breakArgs = $params[1] || 1;
    }

    return $meta->renderFormFieldForDisplay( $name, '$value',
        { break => $breakArgs, protectdollar => 1, showhidden => 1 } );
}


#my ($callback, $cbdata) = setup_callback(\%params, $baseWebObject);
sub setup_callback {
	my ($params, $webObj) = @_;
	
    my $callback = $params->{_callback};
    my $cbdata   = $params->{_cbdata};

    #add in the rendering..
    if ( defined( $params->{_callback} ) ) {
        $callback = sub {
            my $cbdata      = shift;
            my $text        = shift;
            my $oldcallback = $params->{_callback};

            $text = $webObj->renderTML($text) if defined($webObj);
            $text =~ s|</*nop/*>||goi;    # remove <nop> tag
            &$oldcallback( $cbdata, $text );
        };
    }
    else {
        $cbdata = $params->{_cbdata} = [] unless ( defined($cbdata) );
        $callback = \&_collate_to_list;
    }
    return ($callback, $cbdata);
}

# callback for search function to collate
# results
sub _collate {
    my $ref = shift;

    $$ref .= join( ' ', @_ );
}

# callback for search function to collate to list
sub _collate_to_list {
    my $ref = shift;

    push( @$ref, @_ );
}

=begin TML

---++ ObjectMethod searchMetaData($params) -> $text

Search meta-data associated with topics. Parameters are passed in the $params hash,
which may contain:
| =type= | =topicmoved=, =parent= or =field= |
| =topic= | topic to search for, for =topicmoved= and =parent= |
| =name= | form field to search, for =field= type searches. May be a regex. |
| =value= | form field value. May be a regex. |
| =title= | Title prepended to the returned search results |
| =default= | default value if there are no results |
| =web= | web to search in, default is all webs |
| =format= | string for custom formatting results |
The idea is that people can search for meta-data values without having to be
aware of how or where meta-data is stored.

SMELL: should be replaced with a proper SQL-like search, c.f. Plugins.DBCacheContrib.

=cut

sub searchMetaData {
    my ( $this, $params ) = @_;

    my $attrType  = $params->{type}  || 'FIELD';
    my $attrWeb   = $params->{web}   || $this->{session}->{webName};
    my $attrTopic = $params->{topic} || $this->{session}->{topicName};

    my $searchVal = 'XXX';

    if ( $attrType eq 'parent' ) {
        $searchVal =
          "%META:TOPICPARENT[{].*name=\\\"($attrWeb\\.)?$attrTopic\\\".*[}]%";
    }
    elsif ( $attrType eq 'topicmoved' ) {
        $searchVal =
          "%META:TOPICMOVED[{].*from=\\\"$attrWeb\.$attrTopic\\\".*[}]%";
    }
    else {
        $searchVal = "%META:" . uc($attrType) . "[{].*";
        $searchVal .= "name=\\\"$params->{name}\\\".*"
          if ( defined $params->{name} );
        $searchVal .= "value=\\\"$params->{value}\\\".*"
          if ( defined $params->{value} );
        $searchVal .= "[}]%";
    }

    my $text = '';
    if ( $params->{format} ) {
        $text = $this->searchWeb(
            format    => $params->{format},
            search    => $searchVal,
            web       => $attrWeb,
            type      => 'regex',
            nosummary => 'on',
            nosearch  => 'on',
            noheader  => 'on',
            nototal   => 'on',
            noempty   => 'on',
            template  => 'searchmeta',
            inline    => 1,
        );
    }
    else {
        $this->searchWeb(
            _callback => \&_collate,
            _cbdata   => \$text,
            ,
            search    => $searchVal,
            web       => $attrWeb,
            type      => 'regex',
            nosummary => 'on',
            nosearch  => 'on',
            noheader  => 'on',
            nototal   => 'on',
            noempty   => 'on',
            template  => 'searchmeta',
            inline    => 1,
        );
    }
    my $attrTitle = $params->{title} || '';
    if ($text) {
        $text = $attrTitle . $text;
    }
    else {
        my $attrDefault = $params->{default} || '';
        $text = $attrTitle . $attrDefault;
    }

    return $text;
}

1;
__DATA__
# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2009 Foswiki Contributors. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2000-2007 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
