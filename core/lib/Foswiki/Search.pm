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

 Note to developers; please undef *all* fields in the object explicitly,
 whether they are references or not. That way this method is "golden
 documentation" of the live fields in the object.

=cut

sub finish {
    my $this = shift;
    undef $this->{session};

# these may well be function objects, but if (a setting changes, it needs to be picked up again.
    if ( defined( $this->{queryParser} ) ) {
        $this->{queryParser}->finish();
        undef $this->{queryParser};
    }
    if ( defined( $this->{searchParser} ) ) {
        $this->{searchParser}->finish();
        undef $this->{searchParser};
    }
}

=begin TML

---++ ObjectMethod parseSearch($searchString, $params) -> Foswiki::*::Node 

parses the search string and builds the appropriate nodes (uses $param->{type} to work out which parser 

TODO: make parser register themselves with their type, so that we could plug in anything.

=cut

sub parseSearch {
    my $this         = shift;
    my $searchString = shift;
    my $params       = shift;

    my $query;
    my $theParser;
    if ( $params->{type} eq 'query' ) {
        unless ( defined( $this->{queryParser} ) ) {
            require Foswiki::Query::Parser;
            $this->{queryParser} = new Foswiki::Query::Parser();
        }
        $theParser = $this->{queryParser};
    }
    else {
        unless ( defined( $this->{searchParser} ) ) {
            require Foswiki::Search::Parser;
            $this->{searchParser} =
              new Foswiki::Search::Parser( $this->{session} );
        }
        $theParser = $this->{searchParser};
    }
    try {
        $query = $theParser->parse( $searchString, $params );
    }
    catch Foswiki::Infix::Error with {

        # Pass the error on to the caller
        throw Error::Simple( shift->stringify() );
    };
    return $query;
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

=begin TML

---++ ObjectMethod searchWeb (...)

Search one or more webs according to the parameters.

If =_callback= is set, that means the caller wants results as
soon as they are ready. =_callback_ should be set to a reference
to a function which takes =_cbdata= as the first parameter and
remaining parameters the same as 'print'.

If =_callback= is set, the result is always undef. Otherwise the
result is a string containing the rendered search results.

The function will throw Error::Simple if it encounters any problems with the
syntax of the search string.

Note: If =format= is set, =template= will be ignored.

Note: For legacy, if =regex= is defined, it will force type='regex'

If =type="word"= it will be changed to =type="keyword"= with =wordboundaries=1=. This will be used for searching with scope="text" only, because scope="topic" will do a Perl search on topic names.

SMELL: If =template= is defined =bookview= will not work

SMELL: it seems that if you define =_callback= then you are
	responsible for converting the TML to HTML yourself!

FIXME: =callback= cannot work with format parameter (consider format='| $topic |'

=cut

sub searchWeb {
    my $this    = shift;
    my $session = $this->{session};
    ASSERT( defined $session->{webName} ) if DEBUG;
    my %params = @_;

    my $baseWebObject = Foswiki::Meta->new( $session, $session->{webName} );

    my ( $callback, $cbdata ) = setup_callback( \%params, $baseWebObject );

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
#TODO: or... I may wrap an AggregateIterator in a PagingIterator which then is evaluated by a Formattingiterator.
    my $pagesize =
         $params{pagesize}
      || $Foswiki::cfg{Search}{DefaultPageSize}
      || 25;

    require Digest::MD5;
    my $string_id = $params{_RAW} || 'we had better not go there';
    my $paging_ID = 'SEARCH' . Digest::MD5::md5_hex($string_id);
    $params{pager_urlparam_id} = $paging_ID;

    # 1-based system; 0 is not a valid page number
    my $showpage = $session->{request}->param($paging_ID) || $params{showpage};

    if ( defined( $params{pagesize} ) or defined($showpage) ) {
        $params{pager_skip_results_from} = $pagesize * ( $showpage - 1 );
        $params{pager_show_results_to} = $pagesize;
        if ( !defined($showpage) ) {
            $showpage = 1;
        }
    }

    #TODO: refactorme
    my $header  = $params{header};
    my $footer  = $params{footer};
    my $noTotal = Foswiki::isTrue( $params{nototal}, $params{nonoise} );

    my $noEmpty = Foswiki::isTrue( $params{noempty}, $params{nonoise} );

    # Note: a defined header/footer overrides noheader/nofooter
    # To maintain Cairo compatibility we ommit default header/footer if the
    my $noHeader =
      !defined($header)
      && Foswiki::isTrue( $params{noheader}, $params{nonoise} )
      || ( !$header && $formatDefined );

    my $noFooter =
      !defined($footer)
      && Foswiki::isTrue( $params{nofooter}, $params{nonoise} )
      || ( !$footer && $formatDefined );

    my $noSummary = Foswiki::isTrue( $params{nosummary}, $params{nonoise} );
    my $zeroResults =
      1 - Foswiki::isTrue( ( $params{zeroresults} || 'on' ), $params{nonoise} );

    #END TODO

    my $doBookView = Foswiki::isTrue( $params{bookview} );
    my $nonoise    = Foswiki::isTrue( $params{nonoise} );
    my $noSearch   = Foswiki::isTrue( $params{nosearch}, $nonoise );

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

    my $webNames  = $params{web}            || '';
    my $date      = $params{date}           || '';
    my $recurse   = $params{'recurse'}      || '';
    my $finalTerm = $params{nofinalnewline} || 0;

    $baseWeb =~ s/\./\//go;

    $params{type} = 'regex' if ( $params{regex} );

###################the search
    my $query = $this->parseSearch( $searchString, \%params );

#setting the inputTopicSet to be undef allows the search/query algo to use
#the topic="" and excludetopic="" params and web Obj to get a new list of topics.
#this allows the algo's to customise and optimise the getting of this list themselves.
    my $infoCache = Foswiki::Meta::query( $query, undef, \%params );

###################the rendering

    my ( $tmplHead, $tmplSearch, $tmplTail ) =
      $this->loadTemplates( \%params, $baseWebObject, $formatDefined,
        $doBookView, $noHeader, $noSummary, $noTotal, $noFooter );

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

    my $prefs = $session->{prefs};

#TODO: quick hackjob - see what the feature proposal gives before it becomes public
    $params{partition_output} = 'web';

    my ( $numberOfResults, $web_searchResult ) =
      $this->formatResults( $query, $infoCache, \%params );

    return if ( defined $params{_callback} );

#TODO: this code ($separator and $newLine) used to be a long way higher, and the processing might still be needed?
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

    my $searchResult = join( '', @{ $params{_cbdata} } );
    if ( $formatDefined && !$finalTerm ) {
        if ($separator) {
            $separator = quotemeta($separator);
            $searchResult =~ s/$separator$//s;       # remove separator at end
        }
        else {
            $searchResult =~ s/\n$//os;              # remove trailing new line
        }
    }

    return $searchResult;
}

=begin TML

---++ ObjectMethod loadTemplates (...)

this code was extracted from searchWeb, and should probably be private.

=cut

sub loadTemplates {
    my (
        $this,          $params,     $baseWebObject,
        $formatDefined, $doBookView, $noHeader,
        $noSummary,     $noTotal,    $noFooter
    ) = @_;

    my $session = $this->{session};

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

    #print STDERR "}}} $tmpl {{{\n";
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
        throw Error::Simple($mess);
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
            $repeatText =~ s/%TEXTHEAD%/\$summary(searchcontext)/go;
        }
        $params->{format} |= $repeatText;
        unless ($noFooter) {
            $params->{footer} |= $afterText;
        }
        unless ($noTotal) {
            $params->{footercounter} |=
              $baseWebObject->expandMacros($tmplNumber);
            $params->{footer} .= $params->{footercounter};
        }
        else {

            #print STDERR "}}}".$params{format}."{{{";
        }
    }
    return ( $tmplHead, $tmplSearch, $tmplTail );
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
    my ( $this, $query, $infoCache, $params ) = @_;
    my $session = $this->{session};
    my $users   = $session->{users};

    my ( $callback, $cbdata ) = setup_callback($params);

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

    #pager formatting
    my %pager_formatting;
    if ( defined( $params->{pager_show_results_to} )
        and $params->{pager_show_results_to} > 0 )
    {
        $limit = $params->{pager_show_results_to};

#paging - this code should be hidden in the InfoCache iterator, but atm, that won't let me do multi-web
        my $pagesize =
             $params->{pagesize}
          || $Foswiki::cfg{Search}{DefaultPageSize}
          || 25;

        #TODO: paging only implemented for SEARCH atm :/
        my $paging_ID = $params->{pager_urlparam_id};

        # 1-based system; 0 is not a valid page number
        my $showpage =
             $session->{request}->param($paging_ID)
          || $params->{showpage}
          || 1;
        if ( defined( $params->{pagesize} ) or defined($showpage) ) {
            if ( !defined($showpage) ) {
                $showpage = 1;
            }
        }

        #TODO: need to ask the result set
        my $numberofpages = 666;
        my $sep           = ' ';

        my $nextidx     = $showpage + 1;
        my $previousidx = $showpage - 1;

        my %new_params;

        #kill me please, i can't find a way to just load up the hash :(
        foreach my $key ( $session->{request}->param ) {
            $new_params{$key} = $session->{request}->param($key);
        }

        $session->templates->readTemplate('searchformat');

        my $previouspagebutton = '';
        my $previouspageurl    = '';
        if ( $previousidx >= 1 ) {
            $new_params{$paging_ID} = $previousidx;
            $previouspageurl =
              Foswiki::Func::getScriptUrl( $baseWeb, $baseTopic, 'view',
                %new_params );
            $previouspagebutton =
              $session->templates->expandTemplate('SEARCH:pager_previous');
        }
        my $nextpagebutton = '';
        my $nextpageurl    = '';
        if ( $nextidx <= $numberofpages ) {
            $new_params{$paging_ID} = $nextidx;
            $nextpageurl =
              Foswiki::Func::getScriptUrl( $baseWeb, $baseTopic, 'view',
                %new_params );
            $nextpagebutton =
              $session->templates->expandTemplate('SEARCH:pager_next');
        }
        %pager_formatting = (
            '\$previouspage'  => sub { return $previousidx },
            '\$currentpage'   => sub { return $showpage },
            '\$nextpage'      => sub { return $showpage + 1 },
            '\$numberofpages' => sub { return 666 },
            '\$pagesize'      => sub { return $pagesize },
            '\$previousurl'   => sub { return $previouspageurl },
            '\$nexturl'       => sub { return $nextpageurl },
            '\$sep'           => sub { return $sep; }
        );

        $previouspagebutton =
          $this->formatCommon( $previouspagebutton, \%pager_formatting );
        $pager_formatting{'\$previousbutton'} =
          sub { return $previouspagebutton };

        $nextpagebutton =
          $this->formatCommon( $nextpagebutton, \%pager_formatting );
        $pager_formatting{'\$nextbutton'} = sub { return $nextpagebutton };

        my $pager_control = $session->templates->expandTemplate('SEARCH:pager');
        $pager_control =
          $this->formatCommon( $pager_control, \%pager_formatting );
        $pager_formatting{'\$pager'} = sub { return $pager_control; };
    }

    #TODO: multiple is an attribute of the ResultSet
    my $doMultiple = Foswiki::isTrue( $params->{multiple} );
    my $noEmpty = Foswiki::isTrue( $params->{noempty}, $nonoise );

    # Note: a defined header/footer overrides noheader/nofooter
    # To maintain Cairo compatibility we ommit default header/footer if the
    my $noHeader =
      !defined($header) && Foswiki::isTrue( $params->{noheader}, $nonoise )
      || ( !$header && $formatDefined );

    my $noFooter =
      !defined($footer) && Foswiki::isTrue( $params->{nofooter}, $nonoise )
      || ( !$footer && $formatDefined );

    my $noSummary = Foswiki::isTrue( $params->{nosummary}, $nonoise );
    my $zeroResults =
      1 - Foswiki::isTrue( ( $params->{zeroresults} || 'on' ), $nonoise );
    my $noTotal = Foswiki::isTrue( $params->{nototal}, $nonoise );
    my $newLine   = $params->{newline} || '';
    my $separator = $params->{separator};
    my $type      = $params->{type} || '';

    # output the list of topics in $web
    my $ntopics    = 0;         # number of topics in current web
    my $nhits      = 0;         # number of hits (if multiple=on) in current web
    my $headerDone = $noHeader;

    my $web;
    my $webObject;
    my $lastWebProcessed = '';
    my $ttopics          = 0;
    my $thits            = 0;

    while ( $infoCache->hasNext() ) {
        my $webtopic = $infoCache->next();
        my $topic;
        ( $web, $topic ) =
          Foswiki::Func::normalizeWebTopicName( $web, $webtopic );

        #pager..
        if ( defined( $params->{pager_skip_results_from} )
            and $params->{pager_skip_results_from} > 0 )
        {
            $params->{pager_skip_results_from}--;
            next;
        }

# add dependencies (TODO: unclear if this should be before the paging, or after the allowView - sadly, it can't be _in_ the infoCache)
        if ( my $cache = $session->{cache} ) {
            $cache->addDependency( $web, $topic );
        }

        my $info = $this->get( $web, $topic );
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
            #TODO: well, um, and how does this work for query search?
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

        my $ru     = $info->{editby} || 'UnknownUser';
        my $revNum = $info->{revNum} || 0;

        $ntopics += 1;
        $ttopics += 1;
        do {    # multiple=on loop

            $nhits += 1;
            $thits += 1;
            my $out = '';

            $text = pop(@multipleHitLines) if ( scalar(@multipleHitLines) );

            if ( $formatDefined and ( $format ne '' ) ) {

      #TODO: hack to convert a bad SEARCH format to the one used by getRevInfo..
                $format =~ s/\$createdate/\$createlongdate/gs;

       #it looks like $isodate in format is equive to $iso in renderRevisionInfo
       #TODO: clean these 3 hacks up
                $format =~ s/\$isodate/\$iso/gs;
                $format =~ s/\%TIME\%/\$date/gs;
                $format =~ s/\$date/\$longdate/gs;

                #other tmpl based renderings
                $format =~ s/%WEB%/\$web/go;
                $format =~ s/%TOPICNAME%/\$topic/go;
                $format =~ s/%AUTHOR%/\$wikiusername/g;

                # pass search options to summary parser
                my $searchOptions = {
                    type           => $params->{type},
                    wordboundaries => $params->{wordboundaries},
                    casesensitive  => $caseSensitive,
                    tokens         => $query->{tokens}
                };

#TODO: why is this not part of the callback? at least the non-result element format strings can be common here.
#or do i need a formatCommon sub that formatResult can also call.. (which then goes into the callback?
                $out = $this->formatResult(
                    $format,
                    $info->{tom},
                    $text,
                    $searchOptions,
                    {
                        '\$ntopics' => sub { return $ntopics },
                        '\$nhits'   => sub { return $nhits },

                        %pager_formatting,

  #rev1 info
  #TODO: move the $create* formats into Render::renderRevisionInfo..
  #which implies moving the infocache's pre-extracted data into the tom obj too.
  #    $out =~ s/\$create(longdate|username|wikiname|wikiusername)/
  #      $infoCache->getRev1Info( $topic, "create$1" )/ges;
                        '\$createlongdate' => sub {
                            return $this->get( $web, $topic )->{tom}
                              ->getRev1Info("createlongdate");
                        },
                        '\$createusername' => sub {
                            return $this->get( $web, $topic )->{tom}
                              ->getRev1Info("createusername");
                        },
                        '\$createwikiname' => sub {
                            return $this->get( $web, $topic )->{tom}
                              ->getRev1Info("createwikiname");
                        },
                        '\$createwikiusername' => sub {
                            return $this->get( $web, $topic )->{tom}
                              ->getRev1Info("createwikiusername");
                        },

                   #TODO: hacky bits that need to be moved out of formatResult()
                        '$revNum'     => sub { return $revNum; },
                        '$doBookView' => sub { return $doBookView; },
                        '$baseWeb'    => sub { return $baseWeb; },
                        '$baseTopic'  => sub { return $baseTopic; },
                        '$newLine'    => sub { return $newLine; },
                        '$separator'  => sub { return $separator; },
                        '$noTotal'    => sub { return $noTotal; },
                        '$paramsHash' => sub { return $params; },
                    }
                );
            }
            else {
                $out = '';
            }

            my $justdidHeaderOrFooter = 0;
            if (    ( defined( $params->{partition_output} ) )
                and ( $params->{partition_output} eq 'web' ) )
            {
                if ( $lastWebProcessed ne $web ) {

                    #output the footer for the previous webtopic
                    if ( $lastWebProcessed ne '' ) {

                        #c&p from below
                        #TODO: needs refactoring.
                        if ( defined($footer) and ( $footer ne '' ) ) {
                            my $processedfooter =
                              Foswiki::expandStandardEscapes($footer);
                            $processedfooter =~ s/\$web/$lastWebProcessed/gos
                              ;    # expand name of web
                            $processedfooter =~
                              s/([^\n])$/$1\n/os;    # add new line at end
                                                     # output footer of $web
                            $ntopics--;
                            $nhits--;
                            $processedfooter =~ s/\$ntopics/$ntopics/gs;
                            $processedfooter =~ s/\$nhits/$nhits/gs;

                            #legacy SEARCH counter support
                            $processedfooter =~ s/%NTOPICS%/$ntopics/go;

                            $ntopics = 1;
                            $nhits   = 1;

                            $processedfooter =
                              $this->formatCommon( $processedfooter,
                                \%pager_formatting );
                            $processedfooter =
                              $webObject->expandMacros($processedfooter);
                            $processedfooter =~
                              s/\n$//os;    # remove trailing new line

                            if ( defined($separator) ) {

 #	$header = $header.$separator if (defined($params->{header}));
 #TODO: see Item1773 for discussion (foswiki 1.0 compatibility removes the if..)
                                if ( defined( $params->{footer} ) ) {
                                    &$callback( $cbdata, $separator );
                                }
                            }
                            else {

#TODO: legacy from SEARCH - we want to remove this oddness
#    	&$callback( $cbdata, $separator ) if (defined($params->{footer}) && $processedfooter ne '<nop>');
                            }

                            $justdidHeaderOrFooter = 1;
                            &$callback( $cbdata, $processedfooter );
                        }
                    }

                    #trigger a header for this new web
                    $headerDone = undef;
                }
            }

            if ( $lastWebProcessed ne $web ) {
                $webObject = new Foswiki::Meta( $session, $web );
                $lastWebProcessed = $web;
            }

            # lazy output of header (only if needed for the first time)
            if (    ( !$headerDone and ( defined($header) ) )
                and ( $header ne '' ) )
            {

     # add legacy SEARCH separator - see Item1773 (TODO: find a better approach)
                if (    ( $ttopics > 1 )
                    and $noFooter
                    and $noSummary
                    and $separator )
                {
                    &$callback( $cbdata, $separator );
                }
                my $processedheader = Foswiki::expandStandardEscapes($header);
                $processedheader =~ s/\$web/$web/gos;      # expand name of web
                $processedheader =~ s/([^\n])$/$1\n/os;    # add new line at end

                $headerDone = 1;
                my $thisWebBGColor = $webObject->getPreference('WEBBGCOLOR')
                  || '\#FF00FF';
                $processedheader =~ s/%WEBBGCOLOR%/$thisWebBGColor/go;
                $processedheader =~ s/%WEB%/$web/go;
                $processedheader =~ s/\$ntopics/0/gs;
                $processedheader =~ s/\$nhits/0/gs;
                $processedheader =
                  $this->formatCommon( $processedheader, \%pager_formatting );
                $processedheader = $webObject->expandMacros($processedheader);
                &$callback( $cbdata, $processedheader );
                $justdidHeaderOrFooter = 1;
            }

            if (    defined($separator)
                and ( $thits > 1 )
                and ( $justdidHeaderOrFooter != 1 ) )
            {
                &$callback( $cbdata, $separator );
            }

            &$callback( $cbdata, $out );
        } while (@multipleHitLines);    # multiple=on loop

        last if ( $ttopics >= $limit );
    }    # end topic loop

    # output footer only if hits in web
    if ($ntopics) {
        if ( ( defined( $params->{pager} ) ) and ( $params->{pager} eq 'on' ) )
        {
            $footer .= '$pager';
        }
        if ( defined $footer ) {
            $footer = Foswiki::expandStandardEscapes($footer);
            $footer =~ s/\$web/$web/gos;      # expand name of web
            $footer =~ s/([^\n])$/$1\n/os;    # add new line at end
        }

        # output footer of $web
        $footer =~ s/\$ntopics/$ntopics/gs;
        $footer =~ s/\$nhits/$nhits/gs;

        #legacy SEARCH counter support
        $footer =~ s/%NTOPICS%/$ntopics/go;

        $footer = $this->formatCommon( $footer, \%pager_formatting );
        $footer = $webObject->expandMacros($footer);
        $footer =~ s/\n$//os;                 # remove trailing new line

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

sub formatCommon {
    my ( $this, $out, $customKeys ) = @_;

    my $session = $this->{session};

    foreach my $key ( keys(%$customKeys) ) {
        $out =~ s/$key/&{$customKeys->{$key}}()/ges;
    }
    return $out;
}

=begin TML

---++ ObjectMethod formatResult
   * $text can be undefined.
   * $searchOptions is an options hash to pass on to the summary parser
   * customKeys is a hash of {'$key' => sub {my $item = shift; return value;} }
     where $item is a tom object (initially a Foswiki::Meta, but I'd like to be more generic)
     
TODO: i don't really know what we'll need to do about order of processing.
TODO: at minimum, the keys need to be sorted by length so that $datatime is processed before $date
TODO: need to cater for $summary(params) style too

=cut

sub formatResult {
    my ( $this, $out, $topicObject, $text, $searchOptions, $customKeys ) = @_;

    my $session = $this->{session};

    my $web   = $topicObject->web();
    my $topic = $topicObject->topic();

    #TODO: these need to go away.
    my $revNum     = &{ $customKeys->{'$revNum'} }();
    my $doBookView = &{ $customKeys->{'$doBookView'} }();
    my $baseWeb    = &{ $customKeys->{'$baseWeb'} }();
    my $baseTopic  = &{ $customKeys->{'$baseTopic'} }();
    my $newLine    = &{ $customKeys->{'$newLine'} }();
    my $separator  = &{ $customKeys->{'$separator'} }();
    my $noTotal    = &{ $customKeys->{'$noTotal'} }();
    my $params     = &{ $customKeys->{'$paramsHash'} }();
    foreach my $key (
        '$revNum',  '$doBookView', '$baseWeb', '$baseTopic',
        '$newLine', '$separator',  '$noTotal', '$paramsHash'
      )
    {
        delete $customKeys->{$key};
    }

    foreach my $key ( keys(%$customKeys) ) {
        $out =~ s/$key/&{$customKeys->{$key}}()/ges;
    }

    $out =
      $session->renderer->renderRevisionInfo( $topicObject, $revNum, $out );

    if ( $out =~ m/\$text/ ) {
        unless ($text) {
            $text = $topicObject->text();
        }
        if ( $topic eq $session->{topicName} ) {

#TODO: extract the diffusion and generalise to whatever MACRO we are processing - anything with a format can loop

            # defuse SEARCH in current topic to prevent loop
            $text =~ s/%SEARCH{.*?}%/SEARCH{...}/go;
        }
        $out =~ s/\$text/$text/gos;
    }

    #TODO: extract the rev
    my $srev = 'r' . $revNum;
    if ( $revNum eq '0' || $revNum eq '1' ) {
        $srev = CGI::span( { class => 'foswikiNew' },
            ( $session->i18n->maketext('NEW') ) );
    }
    $out =~ s/%REVISION%/$srev/o;

    if ($doBookView) {

        # BookView
        unless ($text) {
            $text = $topicObject->text();
        }
        if ( $web eq $baseWeb && $topic eq $baseTopic ) {

            # primitive way to prevent recursion
            $text =~ s/%SEARCH/%<nop>SEARCH/g;
        }
        $text = $topicObject->expandMacros($text);
        $text = $topicObject->renderTML($text);

        $out =~ s/%TEXTHEAD%/$text/go;

    }
    else {
        $out =~ s/\$summary(?:\(([^\)]*)\))?/
	  $topicObject->summariseText( $1, $text, $searchOptions )/ges;
        $out =~ s/\$changes(?:\(([^\)]*)\))?/
	  $topicObject->summariseChanges($1, $revNum)/ges;
        $out =~ s/\$formfield\(\s*([^\)]*)\s*\)/
	  displayFormField( $topicObject, $1 )/ges;
        $out =~ s/\$parent\(([^\)]*)\)/
	  Foswiki::Render::breakName(
	      $topicObject->getParent(), $1 )/ges;
        $out =~ s/\$parent/$topicObject->getParent()/ges;
        $out =~ s/\$formname/$topicObject->getFormName()/ges;
        $out =~ s/\$count\((.*?\s*\.\*)\)/_countPattern( $text, $1 )/ges;

   # FIXME: Allow all regex characters but escape them
   # Note: The RE requires a .* at the end of a pattern to avoid false positives
   # in pattern matching
        $out =~ s/\$pattern\((.*?\s*\.\*)\)/_extractPattern( $text, $1 )/ges;
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

#see http://foswiki.org/Tasks/Item2371 - needs unit test exploration
#the problem is that when I separated the formating from the searching, I set the format string to what is in the template,
#and thus here, format is always set.
#		elsif ($noSummary) {
#		    #TODO: i think that means I've broken SEARCH{nosummary=on" with no format specified
#		    $out =~ s/%TEXTHEAD%//go;
#		    $out =~ s/&nbsp;//go;
#		}
#		else {
#		    #SEARCH with no format and nonoise="off" or nosummary="off"
#		    #TODO: BROKEN, need to fix the meaning of nosummary and nonoise in SEARCH
#		    # regular search view
#		    $text = $info->{tom}->summariseText( '', $text );
#		    $out =~ s/%TEXTHEAD%/$text/go;
#		}
    return $out;
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
    my ( $params, $webObj ) = @_;

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
    return ( $callback, $cbdata );
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

#TODO: this is a bad copy&extract from infocache
#i am pretty sure I'll move this and its cousin into either
#Foswiki::Meta::Cache, as it is a cache of meta obj's (which the search algo's have to access? ouch.)
#Foswiki::Store::Cache (so that it can be shared both with the internal to Store search algo's, and by Meta..
#errr, bugger, can't put anything into Foswiki::Store:: as the unit tests arse-hume that any .pm file there is a Store impl.
#um, yes, totally broken abstractions :/
#but it does mean that there needs to be a concept of readonly Meta objects vs the few taht will be modified.
#give us a way to get topics without re-re-reloading themselves
sub get {
    my ( $this, $web, $topic, $meta ) = @_;

    unless ( $this->{$web} ) {
        $this->{$web} = {};
    }

    unless ( $this->{$web}->{$topic} ) {
        $this->{$web}->{$topic} = {};
        $this->{$web}->{$topic}->{tom} = $meta
          || Foswiki::Meta->load( $this->{session}, $web, $topic );

        # Extract sort fields
        my $ri = $this->{$web}->{$topic}->{tom}->getRevisionInfo();

        # Rename fields to match sorting criteria
        $this->{$web}->{$topic}->{editby}   = $ri->{author} || '';
        $this->{$web}->{$topic}->{modified} = $ri->{date};
        $this->{$web}->{$topic}->{revNum}   = $ri->{version};

        $this->{$web}->{$topic}->{allowView} =
          $this->{$web}->{$topic}->{tom}->haveAccess('VIEW');
    }

    return $this->{$web}->{$topic};
}

1;
__DATA__
# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2000-2007 TWiki Contributors. 
# All Rights Reserved. TWiki Contributors
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
