# See bottom of file for license and copyright information

package Foswiki::Macros;
use v5.14;

use Foswiki qw(%regex expandStandardEscapes);
use Foswiki::Attrs ();

use Moo;
use namespace::clean;
extends qw(Foswiki::Object);
with qw(Foswiki::AppObject);

use Assert;

=begin TML

---++!! Class Foswiki::Macros

Macro handling and expansion class.

=cut

# Registered macros.
has registered => (
    is      => 'rw',
    lazy    => 1,
    builder => '_registerDefaultMacros',
    isa     => Foswiki::Object::isaHASH( 'registered', noUndef => 1, ),
);
has contextFreeSyntax => (
    is      => 'rw',
    lazy    => 1,
    default => sub { {} },
    isa     => Foswiki::Object::isaHASH( 'contextFreeSyntax', noUndef => 1, ),
);

# Container for macro objects.
has _macros => (
    is      => 'rw',
    lazy    => 1,
    default => sub { {} },
);

sub BUILD {
    my $this = shift;

    $this->contextFreeSyntax->{IF} = 1;
}

=begin TML

---++ ObjectMethod registerTagHandler( $tag, $handler, $syntax )

STATIC Add a tag handler to the function tag handlers.
   * =$tag= name of the tag e.g. MYTAG
   * =$handler= Reference to a sub or object with Foswiki::Macro role. See below on more details.
   * =$syntax= somewhat legacy - 'classic' or 'context-free' (context-free may be removed in future)
   
=$handler= parameter:
   * If it is a sub then it will be passed ($app, \%params, $web, $topic ).
   * If it is an object then method =expand()= will be called with arguments (\%params, $topicObject)

=$syntax= parameter:
Way back in prehistory, back when the dinosaur still roamed the earth, 
Crawford tried to extend the tag syntax of macros such that they could be processed 
by a context-free parser (hence the "context-free") 
and bring them into line with HTML. 
This work was banjaxed by one particular tyrranosaur, 
who felt that the existing syntax was perfect. 
However by that time Crawford had used it in a couple of places - most notable in the action tracker. 

The syntax isn't vastly different from what's there; the differences are: 
   1 Use either type of quote for parameters 
   2 Optional quotes on parameter values e.g. recurse=on 
   3 Standardised use of \ for escapes 
   4 Boolean (valueless) options (i.e. recurse instead of recurse="on" 


=cut

sub registerTagHandler {
    my $this = shift;
    my ( $tag, $handler, $syntax ) = @_;

    $this->app->logger->log( 'warning', "Re-registering existing tag " . $tag, )
      if exists $this->registered->{$tag};

    Foswiki::Exception::Fatal->throw(
        text => "Tag handler object doesn't do Foswiki::Macro role" )
      unless ref($handler) eq 'CODE' || $handler->does('Foswiki::Macro');

    $this->registered->{$tag} = $handler;
    if ( $syntax && $syntax eq 'context-free' ) {
        $this->contextFreeSyntax->{$tag} = 1;
    }
}

=begin TML

---++ ObjectMethod expandMacros( $text, $topicObject ) -> $text

Processes %<nop>VARIABLE%, and %<nop>TOC% syntax; also includes
'commonTagsHandler' plugin hook.

Returns the text of the topic, after file inclusion, variable substitution,
table-of-contents generation, and any plugin changes from commonTagsHandler.

$topicObject may be undef when, for example, expanding templates, or one-off
strings at a time when meta isn't available.

DO NOT CALL THIS DIRECTLY; use $topicObject->expandMacros instead.

=cut

sub expandMacros {
    my ( $this, $text, $topicObject ) = @_;

    return '' unless defined $text;

    my $app = $this->app;
    my $req = $app->request;

    # Plugin Hook
    $app->plugins->dispatch( 'beforeCommonTagsHandler', $text,
        $topicObject->topic, $topicObject->web, $topicObject );

    #use a "global var", so included topics can extract and putback
    #their verbatim blocks safetly.
    my $verbatim = {};
    $text = Foswiki::takeOutBlocks( $text, 'verbatim', $verbatim );

    # take out dirty areas
    my $dirtyAreas = {};
    $text = Foswiki::takeOutBlocks( $text, 'dirtyarea', $dirtyAreas )
      if $topicObject->isCacheable();

    # Require defaults for plugin handlers :-(
    my $webContext   = $topicObject->web   || $req->web;
    my $topicContext = $topicObject->topic || $req->topic;

    my $memW = $app->prefs->getPreference('INCLUDINGWEB');
    my $memT = $app->prefs->getPreference('INCLUDINGTOPIC');
    $app->prefs->setInternalPreferences(
        INCLUDINGWEB   => $webContext,
        INCLUDINGTOPIC => $topicContext
    );

    $this->innerExpandMacros( \$text, $topicObject );

    $text = Foswiki::takeOutBlocks( $text, 'verbatim', $verbatim );

    # Plugin Hook
    $app->plugins->dispatch( 'commonTagsHandler', $text, $topicContext,
        $webContext, 0, $topicObject );

    # process tags again because plugin hook may have added more in
    $this->innerExpandMacros( \$text, $topicObject );

    $app->prefs->setInternalPreferences(
        INCLUDINGWEB   => $memW,
        INCLUDINGTOPIC => $memT
    );

    # 'Special plugin tag' TOC hack, must be done after all other expansions
    # are complete, and has to reprocess the entire topic.

    if ( $text =~ m/%TOC(?:\{.*\})?%/ ) {
        Foswiki::load_package('Foswiki::Macros::TOC');
        my $tocInstance = 1;
        $text =~
s/%TOC(?:\{(.*?)\})?%/$this->TOC($text, $topicObject, $1, $tocInstance++)/ge;
    }

    # Codev.FormattedSearchWithConditionalOutput: remove <nop> lines,
    # possibly introduced by SEARCHes with conditional CALC. This needs
    # to be done after CALC and before table rendering in order to join
    # table rows properly
    $text =~ s/^<nop>\r?\n//gm;

    # restore dirty areas
    Foswiki::putBackBlocks( \$text, $dirtyAreas, 'dirtyarea' )
      if $topicObject->isCacheable();

    Foswiki::putBackBlocks( \$text, $verbatim, 'verbatim' );

    # Foswiki Plugin Hook (for cache Plugins only)
    $app->plugins->dispatch( 'afterCommonTagsHandler', $text, $topicContext,
        $webContext, $topicObject );

    return $text;
}

=begin TML

---++ ObjectMethod expandMacrosOnTopicCreation ( $topicObject )

   * =$topicObject= - the topic

Expand only that subset of Foswiki variables that are
expanded during topic creation, in the body text and
PREFERENCE meta only. The expansion is in-place inside
the topic object.

# SMELL: no plugin handler

=cut

sub expandMacrosOnTopicCreation {
    my ( $this, $topicObject ) = @_;

    # SMELL Is it really required with the App model?
    local $Foswiki::app = $this->app;

    my $text = $topicObject->text();
    if ($text) {

        # Chop out templateonly sections
        my ( $ntext, $sections ) = $this->parseSections($text);
        if ( scalar(@$sections) ) {

            # Note that if named templateonly sections overlap,
            # the behaviour is undefined.

            # First excise all templateonly sections by replacing
            # with nulls of the same length. This keeps the string
            # length the same so offsets remain current.
            foreach my $s ( reverse @$sections ) {
                next unless ( $s->{type} eq 'templateonly' );
                my $r = "\0" x ( $s->{end} - $s->{start} );
                substr( $ntext, $s->{start}, $s->{end} - $s->{start}, $r );
            }

            # Now restore the macros for other sections.
            foreach my $s ( reverse @$sections ) {
                next if ( $s->{type} eq 'templateonly' );

                my $start = $s->remove('start');
                my $end   = $s->remove('end');
                $ntext =
                    substr( $ntext, 0, $start )
                  . '%STARTSECTION{'
                  . $s->{_RAW} . '}%'
                  . substr( $ntext, $start, $end - $start )
                  . '%ENDSECTION{'
                  . $s->{_RAW} . '}%'
                  . substr( $ntext, $end, length($ntext) );
            }

            # Chop the nulls
            $ntext =~ s/\0*//g;
            $text = $ntext;
        }

        $text = $this->_processMacros( $text, \&_expandMacroOnTopicCreation,
            $topicObject, 16 );

        # expand all variables for type="expandvariables" sections
        ( $ntext, $sections ) = $this->parseSections($text);
        if ( scalar(@$sections) ) {
            foreach my $s ( reverse @$sections ) {
                if ( $s->{type} eq 'expandvariables' ) {
                    my $etext =
                      substr( $ntext, $s->{start}, $s->{end} - $s->{start} );
                    $this->innerExpandMacros( \$etext, $topicObject );
                    $ntext =
                        substr( $ntext, 0, $s->{start} )
                      . $etext
                      . substr( $ntext, $s->{end}, length($ntext) );
                }
                else {

                    # put back non-expandvariables sections
                    my $start = $s->remove('start');
                    my $end   = $s->remove('end');
                    $ntext =
                        substr( $ntext, 0, $start )
                      . '%STARTSECTION{'
                      . $s->{_RAW} . '}%'
                      . substr( $ntext, $start, $end - $start )
                      . '%ENDSECTION{'
                      . $s->{_RAW} . '}%'
                      . substr( $ntext, $end, length($ntext) );
                }
            }
            $text = $ntext;
        }

        # kill markers used to prevent variable expansion
        $text =~ s/%NOP%//g;
        $topicObject->text($text);
    }

    # Expand preferences
    my @prefs = $topicObject->find('PREFERENCE');
    foreach my $p (@prefs) {
        $p->{value} =
          $this->_processMacros( $p->{value}, \&_expandMacroOnTopicCreation,
            $topicObject, 16 );

        # kill markers used to prevent variable expansion
        $p->{value} =~ s/%NOP%//g;
    }
}

=begin TML
---++ ObjectMethod exists($macro) -> boolean

Returns true if =$macro= is a registered macro.

=cut

sub exists {
    my $this = shift;
    my ($macro) = @_;
    return defined $this->registered->{$macro};
}

=begin TML

---++ ObjectMethod innerExpandMacros(\$text, $topicObject)
Expands variables by replacing the variables with their
values. Some example variables: %<nop>TOPIC%, %<nop>SCRIPTURL%,
%<nop>WIKINAME%, etc.
$web and $incs are passed in for recursive include expansion. They can
safely be undef.
The rules for tag expansion are:
   1 Tags are expanded left to right, in the order they are encountered.
   1 Tags are recursively expanded as soon as they are encountered -
     the algorithm is inherently single-pass
   1 A tag is not "encountered" until the matching }% has been seen, by
     which time all tags in parameters will have been expanded
   1 Tag expansions that create new tags recursively are limited to a
     set number of hierarchical levels of expansion

=cut

sub innerExpandMacros {
    my ( $this, $text, $topicObject ) = @_;

    my $app = $this->app;

    # push current context
    my $memTopic = $app->prefs->getPreference('TOPIC');
    my $memWeb   = $app->prefs->getPreference('WEB');

    # Historically this couldn't be called on web objects.
    my $webContext   = $topicObject->web   || $this->webName;
    my $topicContext = $topicObject->topic || $this->topicName;

    $app->prefs->setInternalPreferences(
        TOPIC => $topicContext,
        WEB   => $webContext
    );

    # Escape ' !%VARIABLE%'
    $$text =~ s/(?<=[\s\(\.])!%($regex{tagNameRegex})/&#37;$1/g;

    # SMELL Does it really needed in the App model?
    #local $Foswiki::Plugins::SESSION = $this;
    #local $Foswiki::app = $app;

    # NOTE TO DEBUGGERS
    # The depth parameter in the following call controls the maximum number
    # of levels of expansion. If it is set to 1 then only macros in the
    # topic will be expanded; macros that they in turn generate will be
    # left unexpanded. If it is set to 2 then the expansion will stop after
    # the first recursive inclusion, and so on. This is incredible useful
    # when debugging. The default, 16, was selected empirically.
    $$text = $this->_processMacros( $$text, \&_expandMacroOnTopicRendering,
        $topicObject, 16 );

    # restore previous context
    $app->prefs->setInternalPreferences(
        TOPIC => $memTopic,
        WEB   => $memWeb
    );
}

# Process Foswiki %TAGS{}% by parsing the input tokenised into
# % separated sections. The parser is a simple stack-based parse,
# sufficient to ensure nesting of tags is correct, but no more
# than that.
# $depth limits the number of recursive expansion steps that
# can be performed on expanded tags.
sub _processMacros {
    my ( $this, $text, $tagf, $topicObject, $depth ) = @_;
    my $tell = 0;

    my $app = $this->app;

    return '' if ( ( !defined($text) )
        || ( $text eq '' ) );

    #no tags to process
    return $text unless ( $text =~ m/%/ );

    unless ($depth) {
        my $mess = "Max recursive depth reached: $text";
        $app->logger->log( 'warning', $mess );

        # prevent recursive expansion that just has been detected
        # from happening in the error message
        $text =~ s/%(.*?)%/$1/g;
        return $text;
    }

    my $verbatim = {};
    $text = Foswiki::takeOutBlocks( $text, 'verbatim', $verbatim );

    my $dirtyAreas = {};
    $text = Foswiki::takeOutBlocks( $text, 'dirtyarea', $dirtyAreas )
      if $topicObject->isCacheable();

    my @queue = split( /(%)/, $text );
    my @stack;
    my $stackTop = '';    # the top stack entry. Done this way instead of
         # referring to the top of the stack for efficiency. This var
         # should be considered to be $stack[$#stack]

    while ( scalar(@queue) ) {

        #print STDERR "QUEUE:".join("\n      ", map { "'$_'" } @queue)."\n";
        my $token = shift(@queue);

        #print STDERR ' ' x $tell,"PROCESSING $token \n";

        # each % sign either closes an existing stacked context, or
        # opens a new context.
        if ( $token eq '%' ) {

            #print STDERR ' ' x $tell,"CONSIDER $stackTop\n";
            # If this is a closing }%, try to rejoin the previous
            # tokens until we get to a valid tag construct. This is
            # a bit of a hack, but it's hard to think of a better
            # way to do this without a full parse that takes % signs
            # in tag parameters into account.
            if ( $stackTop =~ m/}$/s ) {
                while ( scalar(@stack)
                    && $stackTop !~ /^%$regex{tagNameRegex}\{.*}$/s )
                {
                    my $top = $stackTop;

                    #print STDERR ' ' x $tell,"COLLAPSE $top \n";
                    $stackTop = pop(@stack) . $top;
                }
            }

            # /s so you can have newlines in parameters
            if ( $stackTop =~ m/^%(($regex{tagNameRegex})(?:{(.*)})?)$/s ) {

                # SMELL: unchecked implicit untaint?
                my ( $expr, $tag, $args ) = ( $1, $2, $3 );

                #Foswiki::Func::writeDebug("POP $tag") if $tracing;
                #Monitor::MARK("Before $tag");
                my $e = &$tagf( $this, $tag, $args, $topicObject );

                #Monitor::MARK("After $tag");

                if ( defined($e) ) {

                  #Foswiki::Func::writeDebug("EXPANDED $tag -> $e") if $tracing;
                    $stackTop = pop(@stack);

                    # Don't bother recursively expanding unless there are
                    # unexpanded tags in the result.
                    unless ( $e =~ m/%$regex{tagNameRegex}(?:{.*})?%/s ) {
                        $stackTop .= $e;
                        next;
                    }

                    # Recursively expand tags in the expansion of $tag
                    $stackTop .=
                      $this->_processMacros( $e, $tagf, $topicObject,
                        $depth - 1 );
                    ASSERT(
                        $stackTop !~ /Foswiki::Macr/,
                        "Foswiki::Macros for $tag"
                    );
                }
                else {

                   #Foswiki::Func::writeDebug("EXPAND $tag FAILED") if $tracing;
                   # To handle %NOP
                   # correctly, we have to handle the %VAR% case differently
                   # to the %VAR{}% case when a variable expansion fails.
                   # This is so that recursively define variables e.g.
                   # %A%B%D% expand correctly, but at the same time we ensure
                   # that a mismatched }% can't accidentally close a context
                   # that was left open when a tag expansion failed.
                   # However TWiki didn't do this, so for compatibility
                   # we have to accept that %NOP can never be fixed. if it
                   # could, then we could uncomment the following:

                    #if( $stackTop =~ m/}$/ ) {
                    #    # %VAR{...}% case
                    #    # We need to push the unexpanded expression back
                    #    # onto the stack, but we don't want it to match the
                    #    # tag expression again. So we protect the %'s
                    #    $stackTop = "&#37;$expr&#37;";
                    #} else
                    #{

                    # %VAR% case.
                    # In this case we *do* want to match the tag expression
                    # again, as an embedded %VAR% may have expanded to
                    # create a valid outer expression. This is directly
                    # at odds with the %VAR{...}% case.
                    push( @stack, $stackTop );
                    $stackTop = '%';    # open new context
                                        #}
                }
            }
            else {
                push( @stack, $stackTop );
                $stackTop = '%';        # push a new context
                                        #$tell++;
            }
        }
        else {
            $stackTop .= $token;
        }
    }

    # Run out of input. Gather up everything in the stack.
    while ( scalar(@stack) ) {
        my $expr = $stackTop;
        $stackTop = pop(@stack);
        $stackTop .= $expr;
    }

    Foswiki::putBackBlocks( \$stackTop, $dirtyAreas, 'dirtyarea' )
      if $topicObject->isCacheable();

    Foswiki::putBackBlocks( \$stackTop, $verbatim, 'verbatim' );

    #print STDERR "FINAL $stackTop\n";

    return $stackTop;
}

=begin TML

---++ StaticMethod parseSections($text) -> ($string,$sectionlistref)

Generic parser for sections within a topic. Sections are delimited
by STARTSECTION and ENDSECTION, which may be nested, overlapped or
otherwise abused. The parser builds an array of sections, which is
ordered by the order of the STARTSECTION within the topic. It also
removes all the SECTION tags from the text, and returns the text
and the array of sections.

Each section is a =Foswiki::Attrs= object, which contains the attributes
{type, name, start, end}
where start and end are character offsets in the
string *after all section tags have been removed*. All sections
are required to be uniquely named; if a section is unnamed, it
will be given a generated name. Sections may overlap or nest.

See test/unit/Fn_SECTION.pm for detailed testcases that
round out the spec.

=cut

sub parseSections {
    my $this = shift;

    my $text = shift;

    return ( '', [] ) unless defined $text;

    my %sections;
    my @list = ();

    my $seq    = 0;
    my $ntext  = '';
    my $offset = 0;
    foreach
      my $bit ( split( /(%(?:START|STOP|END)SECTION(?:{.*?})?%)/, $text ) )
    {
        if ( $bit =~ m/^%STARTSECTION(?:{(.*)})?%$/ ) {

            # SMELL: unchecked implicit untaint?
            my $attrs = new Foswiki::Attrs($1);
            $attrs->{type} ||= 'section';
            $attrs->{name} =
                 $attrs->{_DEFAULT}
              || $attrs->{name}
              || '_SECTION' . $seq++;
            delete $attrs->{_DEFAULT};
            my $id = $attrs->{type} . ':' . $attrs->{name};
            if ( $sections{$id} ) {

                # error, this named section already defined, ignore
                next;
            }

            # close open unnamed sections of the same type
            foreach my $s (@list) {
                if (   $s->{end} < 0
                    && $s->{type} eq $attrs->{type}
                    && $s->{name} =~ m/^_SECTION\d+$/ )
                {
                    $s->{end} = $offset;
                }
            }
            $attrs->{start} = $offset;
            $attrs->{end}   = -1;        # open section
            $sections{$id}  = $attrs;
            push( @list, $attrs );
        }
        elsif ( $bit =~ m/^%(?:END|STOP)SECTION(?:{(.*)})?%$/ ) {

            # SMELL: unchecked implicit untaint?
            my $attrs = new Foswiki::Attrs($1);
            $attrs->{type} ||= 'section';
            $attrs->{name} = $attrs->{_DEFAULT} || $attrs->{name} || '';
            delete $attrs->{_DEFAULT};
            unless ( $attrs->{name} ) {

                # find the last open unnamed section of this type
                foreach my $s ( reverse @list ) {
                    if (   $s->{end} == -1
                        && $s->{type} eq $attrs->{type}
                        && $s->{name} =~ m/^_SECTION\d+$/ )
                    {
                        $attrs->{name} = $s->{name};
                        last;
                    }
                }

                # ignore it if no matching START found
                next unless $attrs->{name};
            }
            my $id = $attrs->{type} . ':' . $attrs->{name};
            if ( !$sections{$id} || $sections{$id}->{end} >= 0 ) {

                # error, no such open section, ignore
                next;
            }
            $sections{$id}->{end} = $offset;
        }
        else {
            $ntext .= $bit;
            $offset = length($ntext);
        }
    }

    # close open sections
    foreach my $s (@list) {
        $s->{end} = $offset if $s->{end} < 0;
    }

    return ( $ntext, \@list );
}

=begin TML

---++ execMacro($macroName, \%attrs, $topicObject) => $string

Executes macro defined by its name $macroName.

   * =%attrs= is a hash of attributes or a =Foswiki::Attrs= instance.
   * =$topicObject= ...

=cut

sub execMacro {
    my $this = shift;
    my ( $macroName, $attrs, $topicObject ) = @_;

    my $rc;

    # vrurg Macro could either be a reference to an object or a sub. Though
    # generally OO is preferred but for plguins registering a handling sub
    # could be of more convenience for a while.
    unless ( defined( $this->registered->{$macroName} ) ) {

        # Demand-load the macro module
        die $macroName unless $macroName =~ m/([A-Z_:]+)/i;
        $macroName = $1;
        my $modName = "Foswiki::Macros::$macroName";
        Foswiki::load_package($modName);
        if ( $modName->can('new') ) {
            $this->registered->{$macroName} = $modName;
        }
        else {
            $this->registered->{$macroName} = eval "\\&$macroName";
        }
    }

    if ( ref( $this->registered->{$macroName} ) eq 'CODE' ) {
        $rc =
          $this->registered->{$macroName}->( $this->app, $attrs, $topicObject );
    }
    else {
        # Create macro object unless it already exists.
        unless ( defined $this->_macros->{$macroName} ) {
            $this->_macros->{$macroName} =
              $this->create( $this->registered->{$macroName} );
            ASSERT( $this->_macros->{$macroName}->does('Foswiki::Macro'),
                    "Invalid macro module "
                  . $this->registered->{$macroName}
                  . "; must do Foswiki::Macro role" )
              if DEBUG;
        }
        $rc = $this->_macros->{$macroName}->expand( $attrs, $topicObject );
    }

    return $rc;
}

# Handle expansion of a tag during topic rendering
# $tag is the tag name
# $args is the bit in the {} (if there are any)
# $topicObject should be passed for dynamic tags (not needed for
# session or constant tags
sub _expandMacroOnTopicRendering {
    my ( $this, $tag, $args, $topicObject ) = @_;

    my $app = $this->app;

    my $e = $app->prefs->getPreference($tag);
    if ( defined $e ) {
        if ( $args && $args =~ m/\S/ ) {
            my $attrs = new Foswiki::Attrs( $args, 0 );

            $e = $this->_processMacros(
                $e,
                sub {
                    # Expand %DEFAULT and any parameter tags
                    my ( $this, $tag, $args, $topicObject ) = @_;
                    my $tattrs = new Foswiki::Attrs($args);

                    if ( $tag eq 'DEFAULT' ) {

                        # Define the %DEFAULT macro to return the value
                        # passed (if any) or the default= parameter (if
                        # present) otherwise.
                        return $attrs->{_DEFAULT} if defined $attrs->{_DEFAULT};
                        return $tattrs->{default} if defined $tattrs->{default};

                        # No default and no value - kill it.
                        return '';
                    }
                    my $val = $attrs->{$tag};
                    $val = $tattrs->{default} unless defined $val;
                    return expandStandardEscapes($val) if defined $val;
                    return undef;
                },
                $topicObject,
                1
            );
        }
    }
    elsif ( exists( $this->registered->{$tag} ) ) {
        my $attrs =
          new Foswiki::Attrs( $args, $this->contextFreeSyntax->{$tag} );

        $e = $this->execMacro( $tag, $attrs, $topicObject );
    }
    elsif ( $args && $args =~ m/\S/ ) {

        # Arbitrary %SOMESTRING{default="xxx"}% will expand to xxx
        # in the absence of any definition.
        my $attrs = new Foswiki::Attrs($args);
        if ( defined $attrs->{default} ) {
            $e = expandStandardEscapes( $attrs->{default} );
        }
    }
    return $e;
}

# Handle expansion of a tag during new topic creation. When creating a
# new topic from a template we only expand a subset of the available legal
# tags, and we expand %NOP% differently.
sub _expandMacroOnTopicCreation {
    my $this = shift;

    # my( $tag, $args, $topicObject ) = @_;

    # Required for Cairo compatibility. Ignore %NOP{...}%
    # %NOP% is *not* ignored until all variable expansion is complete,
    # otherwise them inside-out rule would remove it too early e.g.
    # %GM%NOP%TIME -> %GMTIME -> 12:00. So we ignore it here and scrape it
    # out later. We *have* to remove %NOP{...}% because it can foul up
    # brace-matching.
    return '' if $_[0] eq 'NOP' && defined $_[1];

    # Only expand a subset of legal tags. Warning: $this->user may be
    # overridden during this call, when a new user topic is being created.
    # This is what we want to make sure new user templates are populated
    # correctly, but you need to think about this if you extend the set of
    # tags expanded here.
    return
      unless $_[0] =~
m/^(URLPARAM|DATE|(SERVER|GM)TIME|(USER|WIKI)NAME|WIKIUSERNAME|USERINFO)$/;

    return $this->_expandMacroOnTopicRendering(@_);
}

sub _registerDefaultMacros {
    my $this = shift;
    my $cfg  = $this->app->cfg;

    return {
        ADDTOHEAD => undef,

        # deprecated, use ADDTOZONE instead
        ADDTOZONE     => undef,
        ALLVARIABLES  => sub { $_[0]->prefs->stringify() },
        ATTACHURL     => undef,
        ATTACHURLPATH => undef,
        CHARSET       => sub { 'utf-8' },
        DATE          => sub {
            Foswiki::Time::formatTime(
                time(),
                $cfg->data->{DefaultDateFormat},
                $cfg->data->{DisplayTimeValues}
            );
        },
        DISPLAYTIME => sub {
            Foswiki::Time::formatTime(
                time(),
                $_[1]->{_DEFAULT} || '',
                $cfg->data->{DisplayTimeValues}
            );
        },
        ENCODE            => undef,
        ENV               => undef,
        EXPAND            => undef,
        FORMAT            => undef,
        FORMFIELD         => undef,
        FOSWIKI_BROADCAST => sub {
            $_[0]->systemMessage || $Foswiki::system_message || '';
        },
        GMTIME => sub {
            Foswiki::Time::formatTime( time(), $_[1]->{_DEFAULT} || '',
                'gmtime' );
        },
        GROUPINFO => undef,
        GROUPS    => undef,
        HTTP_HOST =>

          #deprecated functionality, now implemented using %ENV%
          sub { $_[0]->request->header('Host') || '' },
        HTTP         => undef,
        HTTPS        => undef,
        ICON         => undef,
        ICONURL      => undef,
        ICONURLPATH  => undef,
        IF           => undef,
        INCLUDE      => undef,
        INTURLENCODE => undef,
        LANG         => sub {
            my $lang = 'en';    # the default
            if (   $cfg->data->{UseLocale}
                && $cfg->data->{Site}{Locale} =~ m/^([a-z]+)(?:_([a-z]+))?/i )
            {

# Locale identifiers use _ as the separator in the language, but a minus sign is required
# for HTML (see http://www.ietf.org/rfc/rfc1766.txt)
                $lang = $1 . ( $2 ? "-$2" : '' );
            }
            return $lang;
        },
        LANGUAGE  => sub { $_[0]->i18n->language(); },
        LANGUAGES => undef,
        MAKETEXT  => undef,
        META      => undef, # deprecated
        METASEARCH           => undef,    # deprecated
        NONCE                => undef,
        PERLDEPENDENCYREPORT => undef,
        NOP =>

          # Remove NOP tag in template topics but show content.
          # Used in template _topics_ (not templates, per se, but
          # topics used as templates for new topics)
          sub { $_[1]->{_RAW} ? $_[1]->{_RAW} : '<nop>' },
        PLUGINVERSION => sub {
            $_[0]->plugins->getPluginVersion( $_[1]->{_DEFAULT} );
        },
        PUBURL      => undef,
        PUBURLPATH  => undef,
        QUERY       => undef,
        QUERYPARAMS => undef,
        QUERYSTRING => sub {
            my $s = $_[0]->request->queryString();

            # Aggressively encode QUERYSTRING (even more than the
            # default) because it might be leveraged for XSS
            $s =~ s/(['\/])/'%'.sprintf('%02x', ord($1))/ge;
            return $s;
        },
        RELATIVETOPICPATH => undef,
        REMOTE_ADDR =>

          # DEPRECATED, now implemented using %ENV%
          #move to compatibility plugin in Foswiki 2.0
          sub { $_[0]->request->remoteAddress() || ''; },
        REMOTE_PORT =>

          # DEPRECATED
          # CGI/1.1 (RFC 3875) doesn't specify REMOTE_PORT,
          # but some webservers implement it. However, since
          # it's not RFC compliant, Foswiki should not rely on
          # it. So we get more portability.
          sub { '' },
        REMOTE_USER =>

          # DEPRECATED
          sub { $_[0]->request->remoteUser() || '' },
        RENDERZONE    => undef,
        REVINFO       => undef,
        REVTITLE      => undef,
        REVARG        => undef,
        SCRIPTNAME    => sub { $_[0]->request->action() },
        SCRIPTURL     => undef,
        SCRIPTURLPATH => undef,
        SEARCH        => undef,
        SEP =>

          # Shortcut to %TMPL:P{"sep"}%
          sub { $_[0]->templates->expandTemplate('sep') },
        SERVERTIME => sub {
            Foswiki::Time::formatTime( time(), $_[1]->{_DEFAULT} || '',
                'servertime' );
        },
        SERVERINFORMATION   => undef,
        SET                 => undef,
        SHOWPREFERENCE      => undef,
        SPACEDTOPIC         => undef,
        SPACEOUT            => undef,
        'TMPL:P'            => sub { $_[0]->templates->tmplP( $_[1] ) },
        TOPICLIST           => undef,
        URLENCODE           => undef,
        URLPARAM            => undef,
        USERINFO            => undef,
        USERNAME            => undef,
        VAR                 => undef,
        WEBLIST             => undef,
        WIKINAME            => undef,
        WIKIUSERNAME        => undef,
        DISPLAYDEPENDENCIES => undef,

        # Constant tag strings _not_ dependent on config. These get nicely
        # optimised by the compiler.
        STOPSECTION  => sub { '' },
        ENDSECTION   => sub { '' },
        WIKIVERSION  => sub { $Foswiki::VERSION },
        WIKIRELEASE  => sub { $Foswiki::RELEASE },
        STARTSECTION => sub { '' },
        STARTINCLUDE => sub { '' },
        STOPINCLUDE  => sub { '' },
        ENDINCLUDE   => sub { '' },

        # Constant tags dependent on the config
        ALLOWLOGINNAME => sub { $cfg->data->{Register}{AllowLoginName} || 0 },
        AUTHREALM      => sub { $cfg->data->{AuthRealm} },
        DEFAULTURLHOST => sub { $cfg->data->{DefaultUrlHost} },
        HOMETOPIC      => sub { $cfg->data->{HomeTopicName} },
        LOCALSITEPREFS => sub { $cfg->data->{LocalSitePreferences} },
        NOFOLLOW =>
          sub { $cfg->data->{NoFollow} ? 'rel=' . $cfg->data->{NoFollow} : '' },
        NOTIFYTOPIC       => sub { $cfg->data->{NotifyTopicName} },
        SCRIPTSUFFIX      => sub { $cfg->data->{ScriptSuffix} },
        STATISTICSTOPIC   => sub { $cfg->data->{Stats}{TopicName} },
        SYSTEMWEB         => sub { $cfg->data->{SystemWebName} },
        TRASHWEB          => sub { $cfg->data->{TrashWebName} },
        SANDBOXWEB        => sub { $cfg->data->{SandboxWebName} },
        WIKIADMINLOGIN    => sub { $cfg->data->{AdminUserLogin} },
        USERSWEB          => sub { $cfg->data->{UsersWebName} },
        WEBPREFSTOPIC     => sub { $cfg->data->{WebPrefsTopicName} },
        WIKIPREFSTOPIC    => sub { $cfg->data->{SitePrefsTopicName} },
        WIKIUSERSTOPIC    => sub { $cfg->data->{UsersTopicName} },
        WIKIWEBMASTER     => sub { $cfg->data->{WebMasterEmail} },
        WIKIWEBMASTERNAME => sub { $cfg->data->{WebMasterName} },
    };
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2016 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.
Based on parts of Ward Cunninghams original Wiki and JosWiki.
Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
