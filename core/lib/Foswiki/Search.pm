# See bottom of file for license and copyright information
package Foswiki::Search;

=begin TML

---+ package Foswiki::Search

This module implements all the search functionality.

=cut

use strict;
use Assert;
use Error qw( :try );

require Foswiki;
require Foswiki::Sandbox;
require Foswiki::Render;    # SMELL: expensive

my $queryParser;

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
    $pattern = Foswiki::Sandbox::untaint($pattern, \&Foswiki::validatePattern);

    my $ok = 0;
    eval {
        # The eval acts as a try block in case there is anything evil in
        # the pattern.
        $ok = 1 if ($text =~ s/$pattern/$1/is);
    };
    $text = '' unless $ok;

    return $text;
}

# With the same argument as $pattern, returns a number which is the count of
# occurences of the pattern argument.
sub _countPattern {
    my ( $text, $pattern ) = @_;

    $pattern = Foswiki::Sandbox::untaint($pattern, \&Foswiki::validatePattern);

    my $count;
    try {
        # see: perldoc -q count
        $count = () = $text =~ /$pattern/g;
    } catch Error::Simple with {
        $count = 0;
    };

    return $count;
}

# Split the search string into tokens depending on type of search.
# Search is an 'AND' of all tokens - various syntaxes implemented
# by this routine.
sub _tokensFromSearchString {
    my ( $this, $searchString, $type ) = @_;

    my @tokens = ();
    if ( $type eq 'regex' ) {

        # Regular expression search Example: soap;wsdl;web service;!shampoo
        @tokens = split( /;/, $searchString );

    }
    elsif ( $type eq 'literal' || $type eq 'query' ) {

        if ( $searchString eq '' ) {

            # Legacy: empty search returns nothing
        }
        else {

            # Literal search (old style) or query
            $tokens[0] = $searchString;
        }

    }
    else {

        # Keyword search (Google-style) - implemented by converting
        # to regex format. Example: soap +wsdl +"web service" -shampoo

        # Prevent tokenizing on spaces in "literal string"
        $searchString =~ s/(\".*?)\"/&_translateSpace($1)/geo;
        $searchString =~ s/[\+\-]\s+//go;

        # Build pattern of stop words
        my $prefs = $this->{session}->{prefs};
        my $stopWords = $prefs->getPreferencesValue('SEARCHSTOPWORDS') || '';
        $stopWords =~ s/[\s\,]+/\|/go;
        $stopWords =~ s/[\(\)]//go;

        # Tokenize string taking account of literal strings, then remove
        # stop words and convert '+' and '-' syntax.
        @tokens = map {
            s/^\+//o;
            s/^\-/\!/o;
            s/^"//o;
            $_
          }    # remove +, change - to !, remove "
          grep { !/^($stopWords)$/i }    # remove stopwords
          map { s/$Foswiki::TranslationToken/ /go; $_ }    # restore space
          split( /[\s]+/, $searchString );               # split on spaces
    }

    return @tokens;
}

# Convert spaces into translation token characters (typically NULs),
# preventing tokenization.
#
# FIXME: Terminology confusing here!
sub _translateSpace {
    my $text = shift;
    $text =~ s/\s+/$Foswiki::TranslationToken/go;
    return $text;
}

# get a list of topics to search in the web, filtered by the $topic
# spec
sub _getTopicList {
    my ( $this, $web, $topic, $options ) = @_;

    my @topicList = ();
    my $store     = $this->{session}->{store};
    if ($topic) {

        # limit search to topic list
        if ( $topic =~ /^\^\([\_\-\+$Foswiki::regex{mixedAlphaNum}\|]+\)\$$/ ) {

            # topic list without wildcards
            # for speed, do not get all topics in web
            # but convert topic pattern into topic list
            my $topics = $topic;
            $topics =~ s/^\^\(//o;
            $topics =~ s/\)\$//o;

            # build list from topic pattern
            @topicList =
              grep( $store->topicExists( $web, $_ ), split( /\|/, $topics ) );
        }
        else {

            # topic list with wildcards
            @topicList = $store->getTopicNames($web);
            if ( $options->{caseSensitive} ) {

                # limit by topic name,
                @topicList = grep( /$topic/, @topicList );
            }
            else {

                # Codev.SearchTopicNameAndTopicText
                @topicList = grep( /$topic/i, @topicList );
            }
        }
    }
    else {
        @topicList = $store->getTopicNames($web);
    }
    return @topicList;
}

# Run a query over a list of topics
sub _queryTopics {
    my ( $this, $web, $query, @topicList ) = @_;

    my $store = $this->{session}->{store};
    my $matches = $store->searchInWebMetaData( $query, $web, \@topicList );

    return keys %$matches;
}

# Run a search over a list of topics - @tokens is a list of
# search terms to be ANDed together
sub _searchTopics {
    my ( $this, $web, $scope, $type, $options, $tokens, @topicList ) = @_;

    my $store = $this->{session}->{store};

    # default scope is 'text'
    $scope = 'text' unless ( $scope =~ /^(topic|all)$/ );

    # AND search - search once for each token, ANDing result together
    foreach my $token (@$tokens) {

        my $invertSearch = 0;

        $invertSearch = ( $token =~ s/^\!//o );

        # flag for AND NOT search
        my @scopeTextList  = ();
        my @scopeTopicList = ();

        # scope can be 'topic' (default), 'text' or "all"
        # scope='text', e.g. Perl search on topic name:
        unless ( $scope eq 'text' ) {
            my $qtoken = $token;

            # FIXME I18N
            $qtoken = quotemeta($qtoken) if ( $type ne 'regex' );
            if ( $options->{'caseSensitive'} ) {

                # fix for Codev.SearchWithNoPipe
                @scopeTopicList = grep( /$qtoken/, @topicList );
            }
            else {
                @scopeTopicList = grep( /$qtoken/i, @topicList );
            }
        }

        # scope='text', e.g. grep search on topic text:
        unless ( $scope eq 'topic' ) {
            my $matches = $store->searchInWebContent(
                $token, $web,
                \@topicList,
                {
                    type                => $type,
                    scope               => $scope,
                    casesensitive       => $options->{'caseSensitive'},
                    wordboundaries      => $options->{'wordBoundaries'},
                    files_without_match => 1
                }
            );
            @scopeTextList = keys %$matches;
        }

        if ( @scopeTextList && @scopeTopicList ) {

            # join 'topic' and 'text' lists
            push( @scopeTextList, @scopeTopicList );
            my %seen = ();

            # make topics unique
            @scopeTextList = sort grep { !$seen{$_}++ } @scopeTextList;
        }
        elsif (@scopeTopicList) {
            @scopeTextList = @scopeTopicList;
        }

        if ($invertSearch) {

            # do AND NOT search
            my %seen = ();
            foreach my $topic (@scopeTextList) {
                $seen{$topic} = 1;
            }
            @scopeTextList = ();
            foreach my $topic (@topicList) {
                push( @scopeTextList, $topic ) unless ( $seen{$topic} );
            }
        }

        # reduced topic list for next token
        @topicList = @scopeTextList;
    }
    return @topicList;
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

If =type="word"= it will be changed to =type="keyword"= with =wordBoundaries=1=. This will be used for searching with scope="text" only, because scope="topic" will do a Perl search on topic names.

SMELL: If =template= is defined =bookview= will not work

SMELL: it seems that if you define =_callback= or =inline= then you are
	responsible for converting the TML to HTML yourself!
	
FIXME: =callback= cannot work with format parameter (consider format='| $topic |'

=cut

sub searchWeb {
    my $this          = shift;
    my %params        = @_;
    my $callback      = $params{_callback};
    my $cbdata        = $params{_cbdata};
    my $baseTopic     = $params{basetopic} || $this->{session}->{topicName};
    my $baseWeb       = $params{baseweb} || $this->{session}->{webName};
    my $doBookView    = Foswiki::isTrue( $params{bookview} );
    my $caseSensitive = Foswiki::isTrue( $params{casesensitive} );
    my $excludeTopic  = $params{excludetopic} || '';
    my $doExpandVars  = Foswiki::isTrue( $params{expandvariables} );
    my $formatDefined = defined $params{format};
    my $format        = $params{format};
    my $header        = $params{header};
    my $footer        = $params{footer};
    my $inline        = $params{inline};
    my $limit         = $params{limit} || '';
    my $doMultiple    = Foswiki::isTrue( $params{multiple} );
    my $nonoise       = Foswiki::isTrue( $params{nonoise} );
    my $noEmpty       = Foswiki::isTrue( $params{noempty}, $nonoise );

    # Note: a defined header/footer overrides noheader/nofooter
    # To maintain Cairo compatibility we ommit default header/footer if the
    # now deprecated option 'inline' is used combined with 'format'
    my $noHeader = !defined($header)
      && Foswiki::isTrue( $params{noheader}, $nonoise )
      || ( !$header && $formatDefined && $inline );
      
    my $noFooter = !defined($footer)
      && Foswiki::isTrue( $params{nofooter}, $nonoise )
      || ( !$footer && $formatDefined && $inline );

    my $noSearch  = Foswiki::isTrue( $params{nosearch},  $nonoise );
    my $noSummary = Foswiki::isTrue( $params{nosummary}, $nonoise );
    my $zeroResults =
      1 - Foswiki::isTrue( ( $params{zeroresults} || 'on' ), $nonoise );
    my $noTotal = Foswiki::isTrue( $params{nototal}, $nonoise );
    my $newLine      = $params{newline}  || '';
    my $sortOrder    = $params{order}    || '';
    my $revSort      = Foswiki::isTrue( $params{reverse} );
    my $scope        = $params{scope}    || '';
    my $searchString = defined $params{search} ? $params{search} : '';
    my $separator    = $params{separator};
    my $template     = $params{template} || '';
    my $topic        = $params{topic}    || '';
    my $type         = $params{type}     || '';

    my $wordBoundaries = 0;
    if ( $type eq 'word' ) {

        # 'word' is exactly the same as 'keyword', except we will be searching
        # with word boundaries
        $type           = 'keyword';
        $wordBoundaries = 1;
    }

    my $webName = $params{web}       || '';
    my $date    = $params{date}      || '';
    my $recurse = $params{'recurse'} || '';
    my $finalTerm = $inline ? ( $params{nofinalnewline} || 0 ) : 0;
    my $users = $this->{session}->{users};

    $baseWeb =~ s/\./\//go;

    my $session  = $this->{session};
    my $renderer = $session->renderer;

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

    $type = 'regex' if ( $params{regex} );

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
    my $homeWeb      = $session->{webName};
    my $homeTopic    = $Foswiki::cfg{HomeTopicName};
    my $store        = $session->{store};

    my %excludeWeb;
    my @tmpWebs;

    # A value of 'all' or 'on' by itself gets all webs,
    # otherwise ignored (unless there is a web called 'All'.)
    my $searchAllFlag = ( $webName =~ /(^|[\,\s])(all|on)([\,\s]|$)/i );

    if ($webName) {
        foreach my $web ( split( /[\,\s]+/, $webName ) ) {
            $web =~ s#\.#/#go;

            # the web processing loop filters for valid web names,
            # so don't do it here.
            if ( $web =~ s/^-// ) {
                $excludeWeb{$web} = 1;
            }
            else {
                push( @tmpWebs, $web );
                if ( Foswiki::isTrue($recurse) || $web =~ /^(all|on)$/i ) {
                    my $webarg = ( $web =~ /^(all|on)$/i ) ? undef : $web;
                    push( @tmpWebs,
                        $store->getListOfWebs( 'user,allowed', $webarg ) );
                }
            }
        }

    }
    else {

        # default to current web
        push( @tmpWebs, $session->{webName} );
        if ( Foswiki::isTrue($recurse) ) {
            push( @tmpWebs,
                $store->getListOfWebs( 'user,allowed', $session->{webName} ) );
        }
    }

    my @webs;
    foreach my $web (@tmpWebs) {
        push( @webs, $web ) unless $excludeWeb{$web};
        $excludeWeb{$web} = 1;
    }

    # E.g. "Bug*, *Patch" ==> "^(Bug.*|.*Patch)$"
    $topic = _makeTopicPattern($topic);

    # E.g. "Web*, FooBar" ==> "^(Web.*|FooBar)$"
    $excludeTopic = _makeTopicPattern($excludeTopic);

    my $output = '';
    my $tmpl   = '';

    my $originalSearch = $searchString;
    my $spacedTopic;

    if ( $formatDefined ) {
        $template = 'searchformat';
    }
    elsif ( $template ) {

        # template definition overrides book and rename views
    }
    elsif ( $doBookView ) {
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
            return undef;
        }
        else {
            return $mess;
        }
    }

    # Expand tags in template sections
    $tmplSearch =
      $session->handleCommonTags( $tmplSearch, $homeWeb, $homeTopic );
    $tmplNumber =
      $session->handleCommonTags( $tmplNumber, $homeWeb, $homeTopic );

    # If not inline search, also expand tags in head and tail sections
    unless ($inline) {
        $tmplHead =
          $session->handleCommonTags( $tmplHead, $homeWeb, $homeTopic );

        if ( defined $callback ) {
            $tmplHead =
              $renderer->getRenderedVersion( $tmplHead, $homeWeb, $homeTopic );
            $tmplHead =~ s|</*nop/*>||goi;    # remove <nop> tags
            &$callback( $cbdata, $tmplHead );
        }
        else {

            # don't getRenderedVersion; this will be done by a single
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
            $tmplSearch =
              $renderer->getRenderedVersion( $tmplSearch, $homeWeb,
                $homeTopic );
            $tmplSearch =~ s|</*nop/*>||goi;    # remove <nop> tag
            &$callback( $cbdata, $tmplSearch );
        }
        else {

            # don't getRenderedVersion; will be done later
            $searchResult .= $tmplSearch;
        }
    }

    # Write log entry
    # FIXME: Move log entry further down to log actual webs searched
    if ( ( $Foswiki::cfg{Log}{search} ) && ( !$inline ) ) {
        my $t = join( ' ', @webs );
        $session->logEvent('search', $t, $searchString );
    }

    my $query;
    my @tokens;

    if ( $type eq 'query' ) {
        if (length($searchString) == 0) {
            #default search should return no results
            $searchString = '1 = 2';
            #shortcircuit the search
            #FIXME: this breaks the per-web summary output that is hidden in the foreach
            @webs = ();
        }
        unless ( defined($queryParser) ) {
            require Foswiki::Query::Parser;
            $queryParser = new Foswiki::Query::Parser();
        }
        my $error = '';
        try {
            $query = $queryParser->parse($searchString);
        }
        catch Foswiki::Infix::Error with {

            # Pass the error on to the caller
            throw Error::Simple( shift->stringify() );
        };
        return $error unless $query;
    }
    else {

        # Split the search string into tokens depending on type of search -
        # each token is ANDed together by actual search
        @tokens = _tokensFromSearchString( $this, $searchString, $type );
        #shorcircuit the search foreach below for a zero result search
        #FIXME: this breaks the per-web summary output that is hidden in the foreach
        @webs = () unless scalar(@tokens); #default
    }

    # Loop through webs
    my $isAdmin = $session->{users}->isAdmin( $session->{user} );
    my $ttopics = 0;
    my $prefs   = $session->{prefs};
    foreach my $web (@webs) {

        $web = Foswiki::Sandbox::untaint(
            $web, \&Foswiki::Sandbox::validateWebName);
        next unless defined $web;
        next unless $store->webExists($web);

        my $thisWebNoSearchAll =
          $prefs->getWebPreferencesValue( 'NOSEARCHALL', $web ) || '';

        # make sure we can report this web on an 'all' search
        # DON'T filter out unless it's part of an 'all' search.
        next
          if ( $searchAllFlag
            && !$isAdmin
            && ( $thisWebNoSearchAll =~ /on/i || $web =~ /^[\.\_]/ )
            && $web ne $session->{webName} );

        my $options = {
            caseSensitive  => $caseSensitive,
            wordBoundaries => $wordBoundaries,
        };

        # Run the search on topics in this web
        my @topicList = _getTopicList( $this, $web, $topic, $options );

        # exclude topics, Codev.ExcludeWebTopicsFromSearch
        if ( $caseSensitive && $excludeTopic ) {
            @topicList = grep( !/$excludeTopic/, @topicList );
        }
        elsif ($excludeTopic) {
            @topicList = grep( !/$excludeTopic/i, @topicList );
        }
        next if ( $noEmpty && !@topicList );    # Nothing to show for this web

        if ( $type eq 'query' ) {
            @topicList = _queryTopics( $this, $web, $query, @topicList );
        }
        else {
            @topicList =
              _searchTopics( $this, $web, $scope, $type, $options, \@tokens,
                @topicList );
        }

        my $topicInfo = {};

        # sort the topic list by date, author or topic name, and cache the
        # info extracted to do the sorting
        if ( $sortOrder eq 'modified' ) {
            # For performance:
            #   * sort by approx time (to get a rough list)
            #   * shorten list to the limit + some slack
            #   * sort by rev date on shortened list to get the accurate list
            # SMELL: Ciaro had efficient two stage handling of modified sort.
            # SMELL: In Dakar this seems to be pointless since latest rev
            # time is taken from topic instead of dir list.
            my $slack = 10;
            if ( $limit + 2 * $slack < scalar(@topicList) ) {

                # sort by approx latest rev time
                my @tmpList =
                  map  { $_->[1] }
                  sort { $a->[0] <=> $b->[0] }
                  map  { [ $store->getTopicLatestRevTime( $web, $_ ), $_ ] }
                  @topicList;
                @tmpList = reverse(@tmpList) if ($revSort);

                # then shorten list and build the hashes for date and author
                my $idx = $limit + $slack;
                @topicList = ();
                foreach (@tmpList) {
                    push( @topicList, $_ );
                    $idx -= 1;
                    last if $idx <= 0;
                }
            }

            $topicInfo =
              _sortTopics( $this, $web, \@topicList, $sortOrder, !$revSort );
        }
        elsif (
            $sortOrder =~ /^creat/ ||    # topic creation time
            $sortOrder eq 'editby' ||    # author
            $sortOrder =~ s/^formfield\((.*)\)$/$1/    # form field
          )
        {

            $topicInfo =
              _sortTopics( $this, $web, \@topicList, $sortOrder, !$revSort );

        }
        else {

            # simple sort, see Codev.SchwartzianTransformMisused
            # note no extraction of topic info here, as not needed
            # for the sort. Instead it will be read lazily, later on.
            if ($revSort) {
                @topicList = sort { $b cmp $a } @topicList;
            }
            else {
                @topicList = sort { $a cmp $b } @topicList;
            }
        }

        if ($date) {
            require Foswiki::Time;
            my @ends       = Foswiki::Time::parseInterval($date);
            my @resultList = ();
            foreach my $topic (@topicList) {

                # if date falls out of interval: exclude topic from result
                my $topicdate = $store->getTopicLatestRevTime( $web, $topic );
                push( @resultList, $topic )
                  unless ( $topicdate < $ends[0] || $topicdate > $ends[1] );
            }
            @topicList = @resultList;
        }

        # header and footer of $web
        my ( $beforeText, $repeatText, $afterText ) =
          split( /%REPEAT%/, $tmplTable );

        if ( defined $header ) {
            $beforeText = Foswiki::expandStandardEscapes($header);
            $beforeText =~ s/\$web/$web/gos;    # expand name of web
            $beforeText =~ s/([^\n])$/$1\n/os;  # add new line at end
        }

        if ( defined $footer ) {
            $afterText = Foswiki::expandStandardEscapes($footer);
            $afterText =~ s/\$web/$web/gos;    # expand name of web
            $afterText =~ s/([^\n])$/$1\n/os;  # add new line at end
        }

        # output the list of topics in $web
        my $ntopics    = 0; # number of topics in current web
        my $nhits      = 0; # number of hits (if multiple=on) in current web
        my $headerDone = $noHeader;
        foreach my $topic (@topicList) {
            my $forceRendering = 0;
            unless ( exists( $topicInfo->{$topic} ) ) {

                # not previously cached
                $topicInfo->{$topic} =
                  _extractTopicInfo( $this, $web, $topic, 0, undef );
            }
            my $epochSecs = $topicInfo->{$topic}->{modified};
            require Foswiki::Time;
            my $revDate = Foswiki::Time::formatTime($epochSecs);
            my $isoDate =
              Foswiki::Time::formatTime( $epochSecs, '$iso', 'gmtime' );

            my $ru     = $topicInfo->{$topic}->{editby} || 'UnknownUser';
            my $revNum = $topicInfo->{$topic}->{revNum} || 0;

            # Check security
            my $allowView = $topicInfo->{$topic}->{allowView};
            next unless $allowView;

            my ( $meta, $text );

            # Special handling for format='...'
            if ( $formatDefined ) {
                ( $meta, $text ) =
                  _getTextAndMeta( $this, $topicInfo, $web, $topic );

                if ($doExpandVars) {
                    if ( $web eq $baseWeb && $topic eq $baseTopic ) {

                        # primitive way to prevent recursion
                        $text =~ s/%SEARCH/%<nop>SEARCH/g;
                    }
                    $text =
                      $session->handleCommonTags( $text, $web, $topic, $meta );
                }
            }

            my @multipleHitLines = ();
            if ($doMultiple) {
                my $pattern = $tokens[$#tokens];   # last token in an AND search
                $pattern = quotemeta($pattern) if ( $type ne 'regex' );
                ( $meta, $text ) =
                  _getTextAndMeta( $this, $topicInfo, $web, $topic )
                  unless $text;
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

                if ( $formatDefined ) {
                    $out = $format;
                    $out =~ s/\$web/$web/gs;
                    $out =~ s/\$topic\(([^\)]*)\)/Foswiki::Render::breakName( 
                                                  $topic, $1 )/ges;
                    $out =~ s/\$topic/$topic/gs;
                    $out =~ s/\$date/$revDate/gs;
                    $out =~ s/\$isodate/$isoDate/gs;
                    $out =~ s/\$rev/$revNum/gs;
                    $out =~ s/\$ntopics/$ntopics/gs;
                    $out =~ s/\$nhits/$nhits/gs;

                    #TODO: replace this with a single call to renderRevisionInfo
                    $out =~ s/(\$wikiusername|\$wikiname|\$username)/$session->renderer->renderRevisionInfo( 
                                                        $web, $topic, $meta, $revNum, $1 )/ges;

                    my $r1info = {};
                    $out =~ s/\$createdate/_getRev1Info(
                            $this, $web, $topic, 'date', $r1info )/ges;
                    $out =~ s/\$createusername/_getRev1Info(
                            $this, $web, $topic, 'username', $r1info )/ges;
                    $out =~ s/\$createwikiname/_getRev1Info(
                            $this, $web, $topic, 'wikiname', $r1info )/ges;
                    $out =~ s/\$createwikiusername/_getRev1Info(
                            $this, $web, $topic, 'wikiusername', $r1info )/ges;

                    if ( $out =~ m/\$text/ ) {
                        ( $meta, $text ) =
                          _getTextAndMeta( $this, $topicInfo, $web, $topic )
                          unless $text;
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
                        ( $this->{session}->i18n->maketext('NEW') ) );
                }
                $out =~ s/%REVISION%/$srev/o;
                $out =~ s/%AUTHOR%/$session->renderer->renderRevisionInfo( 
                                                        $web, $topic, $meta, $revNum, '$wikiusername' )/e;

                if ($doBookView) {

                    # BookView
                    ( $meta, $text ) =
                      _getTextAndMeta( $this, $topicInfo, $web, $topic )
                      unless $text;
                    if ( $web eq $baseWeb && $topic eq $baseTopic ) {

                        # primitive way to prevent recursion
                        $text =~ s/%SEARCH/%<nop>SEARCH/g;
                    }
                    $text =
                      $session->handleCommonTags( $text, $web, $topic, $meta );
                    $text =
                      $session->renderer->getRenderedVersion( $text, $web,
                        $topic );

                    # FIXME: What about meta data rendering?
                    $out =~ s/%TEXTHEAD%/$text/go;

                }
                elsif ( $formatDefined ) {
                    $out =~
s/\$summary(?:\(([^\)]*)\))?/$renderer->makeTopicSummary( $text, $topic, $web, $1 )/ges;

                    $out =~
s/\$changes(?:\(([^\)]*)\))?/$renderer->summariseChanges($session->{user},$web,$topic,$1,$revNum)/ges;
                    $out =~
s/\$formfield\(\s*([^\)]*)\s*\)/displayFormField( $meta, $1 )/ges;
                    $out =~
s/\$parent\(([^\)]*)\)/Foswiki::Render::breakName( $meta->getParent(), $1 )/ges;
                    $out =~ s/\$parent/$meta->getParent()/ges;
                    $out =~ s/\$formname/$meta->getFormName()/ges;
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
                    ( $meta, $text ) =
                      _getTextAndMeta( $this, $topicInfo, $web, $topic )
                      unless $text;
                    $text = $renderer->makeTopicSummary( $text, $topic, $web );
                    $out =~ s/%TEXTHEAD%/$text/go;
                }

                # lazy output of header (only if needed for the first time)
                unless ($headerDone) {
                    $headerDone = 1;
                    my $prefs = $session->{prefs};
                    my $thisWebBGColor =
                      $prefs->getWebPreferencesValue( 'WEBBGCOLOR', $web )
                      || '\#FF00FF';
                    $beforeText =~ s/%WEBBGCOLOR%/$thisWebBGColor/go;
                    $beforeText =~ s/%WEB%/$web/go;
                    $beforeText =~ s/\$ntopics/0/gs;
                    $beforeText =~ s/\$nhits/0/gs;
                    $beforeText =
                      $session->handleCommonTags( $beforeText, $web, $topic );
                    if ( defined $callback ) {
                        $beforeText =
                          $renderer->getRenderedVersion( $beforeText, $web,
                            $topic );
                        $beforeText =~ s|</*nop/*>||goi;    # remove <nop> tag
                        &$callback( $cbdata, $beforeText );
                    }
                    else {
                        $searchResult .= $beforeText;
                    }
                }

                # don't expand if a format is specified - it breaks tables and stuff
                unless ( $formatDefined ) {
                    $out = $renderer->getRenderedVersion( $out, $web, $topic );
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

            # delete topic info to clear any cached data
            undef $topicInfo->{$topic};

            last if ( $ntopics >= $limit );
        }    # end topic loop

        # output footer only if hits in web
        if ($ntopics) {

            # output footer of $web
            $afterText =~ s/\$ntopics/$ntopics/gs;
            $afterText =~ s/\$nhits/$nhits/gs;
            $afterText =
              $session->handleCommonTags( $afterText, $web, $homeTopic );
            if ( $inline || $formatDefined ) {
                $afterText =~ s/\n$//os;    # remove trailing new line
            }

            if ( defined $callback ) {
                $afterText =
                  $renderer->getRenderedVersion( $afterText, $web, $homeTopic );
                $afterText =~ s|</*nop/*>||goi;    # remove <nop> tag
                &$callback( $cbdata, $afterText );
            }
            else {
                $searchResult .= $afterText;
            }
        }

        # output number of topics (only if hits in web or if
        # only searching one web)
        if ( $ntopics || scalar(@webs) < 2 ) {
            unless ($noTotal) {
                my $thisNumber = $tmplNumber;
                $thisNumber =~ s/%NTOPICS%/$ntopics/go;
                if ( defined $callback ) {
                    $thisNumber =
                      $renderer->getRenderedVersion( $thisNumber, $web,
                        $homeTopic );
                    $thisNumber =~ s|</*nop/*>||goi;    # remove <nop> tag
                    &$callback( $cbdata, $thisNumber );
                }
                else {
                    $searchResult .= $thisNumber;
                }
            }
        }
    }    # end of: foreach my $web ( @webs )
    return '' if ( $ttopics == 0 && $zeroResults );

    if ( $formatDefined && !$finalTerm ) {
        if ($separator) {
            $separator = quotemeta($separator);
            $searchResult =~ s/$separator$//s;    # remove separator at end
        }
        else {
            $searchResult =~ s/\n$//os;           # remove trailing new line
        }
    }

    unless ($inline) {
        $tmplTail =
          $session->handleCommonTags( $tmplTail, $homeWeb, $homeTopic );

        if ( defined $callback ) {
            $tmplTail =
              $renderer->getRenderedVersion( $tmplTail, $homeWeb, $homeTopic );
            $tmplTail =~ s|</*nop/*>||goi;        # remove <nop> tag
            &$callback( $cbdata, $tmplTail );
        }
        else {
            $searchResult .= $tmplTail;
        }
    }

    return undef if ( defined $callback );
    return $searchResult if $inline;

    $searchResult =
      $session->handleCommonTags( $searchResult, $homeWeb, $homeTopic );
    $searchResult =
      $renderer->getRenderedVersion( $searchResult, $homeWeb, $homeTopic );

    return $searchResult;
}

# extract topic info required for sorting and sort.
sub _sortTopics {
    my ( $this, $web, $topics, $sortfield, $revSort ) = @_;

    my $users     = $this->{session}->{users};
    my $topicInfo = {};
    foreach my $topic (@$topics) {
        $topicInfo->{$topic} =
          _extractTopicInfo( $this, $web, $topic, $sortfield );
        $topicInfo->{$topic}->{editby} =
          $users->getWikiName( $topicInfo->{$topic}->{editby} );
    }
    if ($revSort) {
        @$topics = map { $_->[1] }
          sort { _compare( $b->[0], $a->[0] ) }
          map { [ $topicInfo->{$_}->{$sortfield}, $_ ] } @$topics;
    }
    else {
        @$topics = map { $_->[1] }
          sort { _compare( $a->[0], $b->[0] ) }
          map { [ $topicInfo->{$_}->{$sortfield}, $_ ] } @$topics;
    }

    return $topicInfo;
}

# RE for a full-spec floating-point number
my $number = qr/^[-+]?[0-9]+(\.[0-9]*)?([Ee][-+]?[0-9]+)?$/s;

sub _compare {
    if ( $_[0] =~ /$number/o && $_[1] =~ /$number/o ) {

        # when sorting numbers do it largest first; this is just because
        # this is what date comparisons need.
        return $_[1] <=> $_[0];
    }
    else {
        return $_[1] cmp $_[0];
    }
}

# extract topic info
sub _extractTopicInfo {
    my ( $this, $web, $topic, $sortfield ) = @_;
    my $info    = {};
    my $session = $this->{session};
    my $store   = $session->{store};
    my $users   = $this->{session}->{users};

    my ( $meta, $text ) = _getTextAndMeta( $this, undef, $web, $topic );

    $info->{text} = $text;
    $info->{meta} = $meta;

    my ( $revdate, $revuser, $revnum ) = $meta->getRevisionInfo();
    $info->{editby}   = $revuser || '';
    $info->{modified} = $revdate;
    $info->{revNum}   = $revnum;

    $info->{allowView} =
      $session->security->checkAccessPermission( 'VIEW', $session->{user},
        $text, $meta, $topic, $web );

    return $info unless $sortfield;

    if ( $sortfield =~ /^creat/ ) {
        ( $info->{$sortfield} ) = $meta->getRevisionInfo(1);
    }
    elsif ( !defined( $info->{$sortfield} ) ) {
        $info->{$sortfield} = displayFormField( $meta, $sortfield );
    }

    return $info;
}

# get the text and meta for a topic
sub _getTextAndMeta {
    my ( $this, $topicInfo, $web, $topic ) = @_;
    my ( $meta, $text );
    my $store = $this->{session}->{store};

    # read from cache if it's there
    if ($topicInfo) {
        $text = $topicInfo->{$topic}->{text};
        $meta = $topicInfo->{$topic}->{meta};
    }

    unless ( defined $text ) {
        ( $meta, $text ) = $store->readTopic( undef, $web, $topic, undef );
        $text =~ s/%WEB%/$web/gos;
        $text =~ s/%TOPIC%/$topic/gos;
    }
    return ( $meta, $text );
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

# Returns the topic revision info of the base version,
# attributes are 'date', 'username', 'wikiname',
# 'wikiusername'. Revision info is cached in the search
# object for speed.
sub _getRev1Info {
    my ( $this, $web, $topic, $attr, $info ) = @_;
    my $key   = $web . '.' . $topic;
    my $store = $this->{session}->{store};
    my $users = $this->{session}->{users};

    unless ( $info->{webTopic} && $info->{webTopic} eq $key ) {
        require Foswiki::Meta;
        my $meta = new Foswiki::Meta( $this->{session}, $web, $topic );
        my ( $d, $u ) = $meta->getRevisionInfo(1);
        $info->{date}     = $d;
        $info->{user}     = $u;
        $info->{webTopic} = $key;
    }
    if ( $attr eq 'username' ) {
        return $users->getLoginName( $info->{user} );
    }
    if ( $attr eq 'wikiname' ) {
        return $users->getWikiName( $info->{user} );
    }
    if ( $attr eq 'wikiusername' ) {
        return $users->webDotWikiName( $info->{user} );
    }
    if ( $attr eq 'date' ) {
        require Foswiki::Time;
        return Foswiki::Time::formatTime( $info->{date} );
    }

    return 1;
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
