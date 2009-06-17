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
                    if ( $web =~ /^(all|on)$/i ) {
                        $webObject = Foswiki::Meta->new($session);
                    }
                    else {
                        push( @tmpWebs, $web );
                        $webObject = Foswiki::Meta->new( $session, $web );
                    }
                    my $it = $webObject->eachWeb(1);
                    while ( $it->hasNext() ) {
                        my $w = $it->next();
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
                my $w = $it->next();
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
      split( /,\s*/, $topic );
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
    my %params    = @_;
    my $callback  = $params{_callback};
    my $cbdata    = $params{_cbdata};
    my $baseTopic = $params{basetopic} || $session->{topicName};
    my $baseWeb   = $params{baseweb} || $session->{webName};
    $params{casesensitive} = Foswiki::isTrue( $params{casesensitive} );
    $params{excludeTopics} = $params{excludetopic} || '';
    my $formatDefined = defined $params{format};
    my $format        = $params{format};
    my $inline        = $params{inline};
    $params{multiple} = Foswiki::isTrue( $params{multiple} );
    $params{nonoise}  = Foswiki::isTrue( $params{nonoise} );
    $params{noempty}  = Foswiki::isTrue( $params{noempty}, $params{nonoise} );
    $params{zeroresults} =
      1 - Foswiki::isTrue( ( $params{zeroresults} || 'on' ), $params{nonoise} );

    my $newLine   = $params{newline} || '';
    my $sortOrder = $params{order}   || '';
    my $revSort   = Foswiki::isTrue( $params{reverse} );
    $params{scope} = $params{scope} || '';
    my $searchString = defined $params{search} ? $params{search} : '';
    my $separator = $params{separator};
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
    if ( defined($separator) ) {
        $separator =~ s/\$n\(\)/\n/gos;    # expand "$n()" to new line
        $separator =~ s/\$n([^$mixedAlpha]|$)/\n$1/gos;
    }
    if ($newLine) {
        $newLine =~ s/\$n\(\)/\n/gos;                # expand "$n()" to new line
        $newLine =~ s/\$n([^$mixedAlpha]|$)/\n$1/gos;
    }

    my $searchResult = '';

    # A value of 'all' or 'on' by itself gets all webs,
    # otherwise ignored (unless there is a web called 'All'.)
    my $searchAllFlag = ( $webName =~ /(^|[\,\s])(all|on)([\,\s]|$)/i );

    my @webs = $this->_getListOfWebs( $webName, $recurse, $searchAllFlag );

    #to help later processing (formatResults)
    $params{numberOfWebs} = scalar(@webs);

    my $output = '';

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
    my $error = '';
    try {
        $query = $theParser->parse( $searchString, \%params );
    }
    catch Foswiki::Infix::Error with {

        # Pass the error on to the caller
        throw Error::Simple( shift->stringify() );
    };
    return $error unless $query;

#TODO: redo with a $query->isEmpty() or something generic, and then push into the foreach?
    unless ( $params{type} eq 'query' ) {

    #shorcircuit the search foreach below for a zero result search
    #FIXME: this breaks the per-web summary output that is hidden in the foreach
        @webs = () unless scalar( @{ $query->{tokens} } );    #default
    }

    #TODO: work out how to remove this formatting value..
    my $tmplTail;

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
        $this->sortResults( $web, $infoCache, %params );

        # add dependencies
        my $cache = $session->{cache};
        if ($cache) {
            foreach my $topic ( $infoCache->{list} ) {
                $cache->addDependency( $web, $topic );
            }
        }

        my ( $web_ttopics, $web_searchResult );
        ( $web_ttopics, $web_searchResult, $tmplTail ) =
          $this->formatResults( $webObject, $query, $searchString, $infoCache,
            \%params );
        $ttopics += $web_ttopics;
        $searchResult .= $web_searchResult;
    }    # end of: foreach my $web ( @webs )
    return '' if ( $ttopics == 0 && $params{zeroresults} );

    if ( $formatDefined && !$finalTerm ) {
        if ($separator) {
            $separator = quotemeta($separator);
            $searchResult =~ s/$separator$//s;    # remove separator at end
        }
        else {
            $searchResult =~ s/\n$//os;           # remove trailing new line
        }
    }

   #this should really be the object used to render things. (ie, move to format)
    my $baseWebObject = Foswiki::Meta->new( $session, $session->{webName} );

    unless ($inline) {
        $tmplTail = $baseWebObject->expandMacros($tmplTail);

        if ( defined $callback ) {
            $tmplTail = $baseWebObject->renderTML($tmplTail);
            $tmplTail =~ s|</*nop/*>||goi;        # remove <nop> tag
            &$callback( $cbdata, $tmplTail );
        }
        else {
            $searchResult .= $tmplTail;
        }
    }

    return if ( defined $callback );
    return $searchResult if $inline;

    $searchResult = $baseWebObject->expandMacros($searchResult);
    $searchResult = $baseWebObject->renderTML($searchResult);

    return $searchResult;
}

=begin TML
---++ sortResults

the implementation of %SORT{"" limit="" order="" reverse="" date=""}%

=cut

sub sortResults {
    my ( $this, $web, $infoCache, %params ) = @_;
    my $session = $this->{session};

    my $sortOrder = $params{order} || '';
    my $revSort   = Foswiki::isTrue( $params{reverse} );
    my $date      = $params{date} || '';
    my $limit     = $params{limit} || '';

    #SMELL: duplicated code - removeme
    # Limit search results
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

    # sort the topic list by date, author or topic name, and cache the
    # info extracted to do the sorting
    if ( $sortOrder eq 'modified' ) {

        # For performance:
        #   * sort by approx time (to get a rough list)
        #   * shorten list to the limit + some slack
        #   * sort by rev date on shortened list to get the accurate list
        # SMELL: Cairo had efficient two stage handling of modified sort.
        # SMELL: In Dakar this seems to be pointless since latest rev
        # time is taken from topic instead of dir list.
        my $slack = 10;
        if ( $limit + 2 * $slack < scalar( @{ $infoCache->{list} } ) ) {

            # sort by approx latest rev time
            my @tmpList =
              map  { $_->[1] }
              sort { $a->[0] <=> $b->[0] }
              map  { [ $session->getApproxRevTime( $web, $_ ), $_ ] }
              @{ $infoCache->{list} };
            @tmpList = reverse(@tmpList) if ($revSort);

            # then shorten list and build the hashes for date and author
            my $idx = $limit + $slack;
            @{ $infoCache->{list} } = ();
            foreach (@tmpList) {
                push( @{ $infoCache->{list} }, $_ );
                $idx -= 1;
                last if $idx <= 0;
            }
        }

        $infoCache->sortTopics( $sortOrder, !$revSort );
    }
    elsif (
        $sortOrder =~ /^creat/ ||    # topic creation time
        $sortOrder eq 'editby' ||    # author
        $sortOrder =~ s/^formfield\((.*)\)$/$1/    # form field
      )
    {
        $infoCache->sortTopics( $sortOrder, !$revSort );
    }
    else {

        # simple sort, see Codev.SchwartzianTransformMisused
        # note no extraction of topic info here, as not needed
        # for the sort. Instead it will be read lazily, later on.
        if ($revSort) {
            @{ $infoCache->{list} } =
              sort { $b cmp $a } @{ $infoCache->{list} };
        }
        else {
            @{ $infoCache->{list} } =
              sort { $a cmp $b } @{ $infoCache->{list} };
        }
    }

    if ($date) {
        require Foswiki::Time;
        my @ends       = Foswiki::Time::parseInterval($date);
        my @resultList = ();
        foreach my $topic ( @{ $infoCache->{list} } ) {

            # if date falls out of interval: exclude topic from result
            my $topicdate = $session->getApproxRevTime( $web, $topic );
            push( @resultList, $topic )
              unless ( $topicdate < $ends[0] || $topicdate > $ends[1] );
        }
        @{ $infoCache->{list} } = @resultList;
    }
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

    my $callback      = $params->{_callback};
    my $cbdata        = $params->{_cbdata};
    my $baseTopic     = $params->{basetopic} || $session->{topicName};
    my $baseWeb       = $params->{baseweb} || $session->{webName};
    my $doBookView    = Foswiki::isTrue( $params->{bookview} );
    my $caseSensitive = Foswiki::isTrue( $params->{casesensitive} );
    my $doExpandVars  = Foswiki::isTrue( $params->{expandvariables} );
    my $nonoise       = Foswiki::isTrue( $params->{nonoise} );
    my $noSearch      = Foswiki::isTrue( $params->{nosearch}, $nonoise );
    my $formatDefined = defined $params->{format};
    my $format        = $params->{format} || '';
    my $header        = $params->{header};
    my $footer        = $params->{footer};
    my $inline        = $params->{inline};
    my $limit         = $params->{limit} || '';

    my $searchResult = '';

    #tmpl loading code.
    my $tmpl = '';

    my $originalSearch = $searchString;
    my $spacedTopic;

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
    if ( !$tmplTail ) {
        my $mess =
            CGI::h1('Foswiki Installation Error')
          . 'Incorrect format of '
          . $template
          . ' template (missing sections? There should be 4 %SPLIT% tags)';
        if ( defined $callback ) {
            &$callback( $cbdata, $mess );
            return;
        }
        else {
            return $mess;
        }
    }

    # Expand tags in template sections
    my $baseWebObject = Foswiki::Meta->new( $session, $session->{webName} );
    $tmplSearch = $baseWebObject->expandMacros($tmplSearch);
    $tmplNumber = $baseWebObject->expandMacros($tmplNumber);

    # If not inline search, also expand tags in head and tail sections
    unless ($inline) {
        $tmplHead = $baseWebObject->expandMacros($tmplHead);

        if ( defined $callback ) {
            $tmplHead = $baseWebObject->renderTML($tmplHead);
            $tmplHead =~ s|</*nop/*>||goi;    # remove <nop> tags
            &$callback( $cbdata, $tmplHead );
        }
        else {

            # don't render; this will be done by a single
            # call at the end.
            $searchResult .= $tmplHead;
        }
    }

    # Generate 'Search:' part showing actual search string used
    unless ($noSearch) {
        my $searchStr = $searchString;
        $searchStr  =~ s/&/&amp;/go;
        $searchStr  =~ s/</&lt;/go;
        $searchStr  =~ s/>/&gt;/go;
        $searchStr  =~ s/^\.\*$/Index/go;
        $tmplSearch =~ s/%SEARCHSTRING%/$searchStr/go;
        if ( defined $callback ) {
            $tmplSearch = $baseWebObject->renderTML($tmplSearch);
            $tmplSearch =~ s|</*nop/*>||goi;    # remove <nop> tag
            &$callback( $cbdata, $tmplSearch );
        }
        else {

            # don't render; will be done later
            $searchResult .= $tmplSearch;
        }
    }

    # Limit search results
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
    my $sortOrder = $params->{order}   || '';
    my $revSort   = Foswiki::isTrue( $params->{reverse} );
    my $scope     = $params->{scope}   || '';
    my $separator = $params->{separator};
    my $topic     = $params->{topic}   || '';
    my $type      = $params->{type}    || '';

    my $ttopics = 0;

    # header and footer of $web
    my ( $beforeText, $repeatText, $afterText ) =
      split( /%REPEAT%/, $tmplTable );

    if ( defined $header ) {
        $beforeText = Foswiki::expandStandardEscapes($header);
        $beforeText =~ s/\$web/$web/gos;      # expand name of web
        $beforeText =~ s/([^\n])$/$1\n/os;    # add new line at end
    }

    if ( defined $footer ) {
        $afterText = Foswiki::expandStandardEscapes($footer);
        $afterText =~ s/\$web/$web/gos;       # expand name of web
        $afterText =~ s/([^\n])$/$1\n/os;     # add new line at end
    }

    # output the list of topics in $web
    my $ntopics    = 0;         # number of topics in current web
    my $nhits      = 0;         # number of hits (if multiple=on) in current web
    my $headerDone = $noHeader;
    while ( $infoCache->hasNext() ) {
        my $topic = $infoCache->next();

        my $forceRendering = 0;
        my $info           = $infoCache->get($topic);

        my $epochSecs = $info->{modified};
        require Foswiki::Time;
        my $revDate = Foswiki::Time::formatTime($epochSecs);
        my $isoDate = Foswiki::Time::formatTime( $epochSecs, '$iso', 'gmtime' );

        my $ru     = $info->{editby} || 'UnknownUser';
        my $revNum = $info->{revNum} || 0;

        my $cUID = $users->getCanonicalUserID($ru);
        if ( !$cUID ) {

            # Not a login name or a wiki name. Is it a valid cUID?
            my $ln = $users->getLoginName($ru);
            $cUID = $ru if defined $ln && $ln ne 'unknown';
        }

        # Check security
        my $allowView = $info->{allowView};
        next unless $allowView;

        my ( $meta, $text );

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

        my @multipleHitLines = ();
        if ($doMultiple) {

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

        $ntopics += 1;
        $ttopics += 1;

        do {    # multiple=on loop

            $nhits += 1;
            my $out = '';

            $text = pop(@multipleHitLines) if ( scalar(@multipleHitLines) );

            my $wikiusername = $users->webDotWikiName($cUID);
            $wikiusername = "$Foswiki::cfg{UsersWebName}.UnknownUser"
              unless defined $wikiusername;

            if ($formatDefined) {
                $out = $format;
                $out =~ s/\$web/$web/gs;
                $out =~ s/\$topic\(([^\)]*)\)/
                  Foswiki::Render::breakName( $topic, $1 )/ges;
                $out =~ s/\$topic/$topic/gs;
                $out =~ s/\$date/$revDate/gs;
                $out =~ s/\$isodate/$isoDate/gs;
                $out =~ s/\$rev/$revNum/gs;
                $out =~ s/\$wikiusername/$wikiusername/ges;
                $out =~ s/\$ntopics/$ntopics/gs;
                $out =~ s/\$nhits/$nhits/gs;

                my $wikiname = $users->getWikiName($cUID);
                $wikiname = 'UnknownUser' unless defined $wikiname;
                $out =~ s/\$wikiname/$wikiname/ges;

                my $username = $users->getLoginName($cUID);
                $username = 'unknown' unless defined $username;
                $out =~ s/\$username/$username/ges;

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
                    $forceRendering = 1 unless ($doMultiple);
                }
            }
            else {
                $out = $repeatText;
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
            $out =~ s/%AUTHOR%/$wikiusername/e;

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
                if ( defined($separator) ) {
                    $out .= $separator;
                }
                else {

                    # add new line at end if needed
                    # SMELL: why?
                    $out =~ s/([^\n])$/$1\n/s;
                }

                $out = Foswiki::expandStandardEscapes($out);

            }
            elsif ($noSummary) {
                $out =~ s/%TEXTHEAD%//go;
                $out =~ s/&nbsp;//go;

            }
            else {

                # regular search view
                $text = $info->{tom}->summariseText( '', $text );
                $out =~ s/%TEXTHEAD%/$text/go;
            }

            # lazy output of header (only if needed for the first time)
            unless ($headerDone) {
                $headerDone = 1;
                my $thisWebBGColor = $webObject->getPreference('WEBBGCOLOR')
                  || '\#FF00FF';
                $beforeText =~ s/%WEBBGCOLOR%/$thisWebBGColor/go;
                $beforeText =~ s/%WEB%/$web/go;
                $beforeText =~ s/\$ntopics/0/gs;
                $beforeText =~ s/\$nhits/0/gs;
                $beforeText = $webObject->expandMacros($beforeText);
                if ( defined $callback ) {
                    $beforeText = $webObject->renderTML($beforeText);
                    $beforeText =~ s|</*nop/*>||goi;    # remove <nop> tag
                    &$callback( $cbdata, $beforeText );
                }
                else {
                    $searchResult .= $beforeText;
                }
            }

            # don't expand if a format is specified - it breaks tables and stuff
            unless ($formatDefined) {
                $out = $webObject->renderTML($out);
            }

            # output topic (or line if multiple=on)
            if ( defined $callback ) {
                $out =~ s|</*nop/*>||goi;    # remove <nop> tag
                &$callback( $cbdata, $out );
            }
            else {
                $searchResult .= $out;
            }

        } while (@multipleHitLines);    # multiple=on loop

        last if ( $ntopics >= $limit );
    }    # end topic loop

    #TODO: SMELL: huh, why do we need another webObject?
    my $webWebObject = Foswiki::Meta->new( $session, $web );

    # output footer only if hits in web
    if ($ntopics) {

        # output footer of $web
        $afterText =~ s/\$ntopics/$ntopics/gs;
        $afterText =~ s/\$nhits/$nhits/gs;
        $afterText = $webWebObject->expandMacros($afterText);
        if ( $inline || $formatDefined ) {
            $afterText =~ s/\n$//os;    # remove trailing new line
        }

        if ( defined $callback ) {
            $afterText = $webWebObject->renderTML($afterText);
            $afterText =~ s|</*nop/*>||goi;    # remove <nop> tag
            &$callback( $cbdata, $afterText );
        }
        else {
            $searchResult .= $afterText;
        }
    }

    # output number of topics (only if hits in web or if
    # only searching one web)
    if ( $ntopics || $params->{numberOfWebs} < 2 ) {
        unless ($noTotal) {
            my $thisNumber = $tmplNumber;
            $thisNumber =~ s/%NTOPICS%/$ntopics/go;
            if ( defined $callback ) {
                $thisNumber = $webWebObject->renderTML($thisNumber);
                $thisNumber =~ s|</*nop/*>||goi;    # remove <nop> tag
                &$callback( $cbdata, $thisNumber );
            }
            else {
                $searchResult .= $thisNumber;
            }
        }
    }
    return ( $ttopics, $searchResult, $tmplTail );
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

# callback for search function to collate
# results
sub _collate {
    my $ref = shift;

    $$ref .= join( ' ', @_ );
}

=begin twiki

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
