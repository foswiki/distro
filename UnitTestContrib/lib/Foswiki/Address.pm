# See bottom of file for license and copyright information

package Foswiki::Address;

=begin TML

---+ package Foswiki::Address

This class is used to handle pointers to Foswiki 'resources', which might be
webs, topics or parts of topics (such as attachments or metadata), optionally
of a specific revision.

The primary goal is to end the tyranny of arbitrary
=(web, topic, attachment, rev...)= tuples. Users of =Foswiki::Address= should
be able to enjoy programmatically updating, stringifying, parsing, validating,
comparing and passing around of _address objects_ that might eventually be
understood by the wider Foswiki universe, without having to maintain proprietary
parse/stringify/validate/comparison handling code that must always be
considerate of the recipient for such tuples.

This class does not offer any interaction with resources themselves; rather,
functionality is provided to create, hold, manipulate, test
__and de/serialise addresses__

Fundamentally, =Foswiki::Address= can be thought of as an interface to a hash of
the components necessary to address a specific Foswiki resource.

<verbatim>
my $addr = {
    web        => 'Web/SubWeb',
    topic      => 'Topic',
    attachment => 'Attachment.pdf',
    rev => 3
};
</verbatim>

<blockquote class="foswikiHelp">%X% __Unresolved issues__
   * Is this class necessary, or should we make a cleaner, lighter
   =Foswiki::Meta2= - where 'unloaded' objects are no heavier than
   =Foswiki::Address= and provide the same functionality?
   * Should the physical file attachment be treated separately to the metadata
   view of the file attachment(s)? Desirables:
      * ability to unambiguously create pointers to an attachment's data (file)
      * ability for Foswiki core to calculate an http URL for it
      * ability to create pointers to properties (metadata) of the attachment
         * _These questions are slightly loaded in favour of distinguishing
      between the datastream and metadata about the attachment. In an ideal
      world a file attachment would be a first-class citizen to topics: rather
      than topic text, we have the iostream; attachments would have their own
      user metadata, dataforms..._
   * Duplicating %SYSTEMWEB%.QuerySearch parser functionality. 80% of the code
   in this class is related to parsing "string forms" of addresses of Foswiki
   resources... querysearch parser needs some refactoring so we can delete the
   parser code here.
   * API usability - can we stop passing around (web, topic, attachment, rev)
   tuples - will the =->new()= constructor make sense to plugin authors, core
   hackers? __FEEDBACK WELCOME__, please comment at
   Foswiki:Development.TopicAddressing
</blockquote>

=cut

use strict;
use warnings;

use Assert;
use Foswiki::Func();
use Foswiki::Meta();

#use Data::Dumper;
use constant TRACE       => 0;    # Don't forget to uncomment dumper
use constant TRACE2      => 0;
use constant TRACEVALID  => 0;
use constant TRACEATTACH => 0;

#our @THESE;

my %atomiseAs = (
    root       => \&_atomiseAsRoot,
    web        => \&_atomiseAsWeb,
    topic      => \&_atomiseAsTopic,
    attachment => \&_atomiseAsAttachment,
    META       => \&_atomiseAsTOM,
    meta       => \&_atomiseAsTOM,
    SECTION    => \&_atomiseAsTOM,
    text       => \&_atomiseAsTOM,
    '*'        => \&_atomiseAsTOM
);

# The question is: what do we have? The hash is accessed as follows:
# $pathtypes{ $tompath[0] }->{ scalar(@tompath) }
my %pathtypes = (
    attachment => { 1 => 'attachments', 2 => 'attachment' },
    META => { 1 => 'meta', 2 => 'metatype', 3 => 'metamember', 4 => 'metakey' },
    SECTION => { 1 => 'sections', 2 => 'section' },
    text    => { 1 => 'text' }
);

# I tried to create a logical parser, but it kept ending up as spaghetti.
# So we use a lookup table instead... (probably?) easier to follow, faster.
my %plausibletable = (

    # root keys represent the path separator signature of the form:
    # combinations of s, S, d, D - where:
    #   s = <part>/<part> - sequence of two parts separated by '/'
    #   d = <part>.<part> - sequence of two parts separated by '.'
    #   S = <part>/<part>/<part>[/]... - sequence > 2 parts separated by '/'
    #   D = <part>.<part>.<part>[.]... - sequence > 2 parts separated by '.'
    #
    # sub keys are the type considered; values of the sub keys indicate
    # the plausibility that the given form could be the type indicated:
    #   0/undef - not plausible
    #         1 - plausible without using any context
    #         2 - normal ("unambiguous") form
    # 'webpath' - plausible if given webpath context
    #   'topic' - plausible if given webpath & topic context
    #
    # Foo
    '' => { webpath => 1, topic => 'webpath', attachment => 'topic' },

    # Foo.Bar
    'd' => { webpath => 1, topic => 2, attachment => 'topic' },

    # Foo/Bar
    's' => { webpath => 1, topic => 1, attachment => 'webpath' },

    # Foo/Bar.Dog
    'sd' => { webpath => 0, topic => 2, attachment => 'webpath' },

    # Foo.Bar/Dog
    'ds' => { webpath => 0, topic => 1, attachment => 2 },

    # Foo/Bar/Dog
    'S' => { webpath => 1, topic => 1, attachment => 1 },

    # Foo.Bar.Dog
    'D' => { webpath => 1, topic => 1, attachment => 'topic' },

    # Foo.Bar/Cat/Dog
    'dS' => { webpath => 0, topic => 1, attachment => 1 },

    # Foo/Bar.Cat.Dog
    'sD' => { webpath => 0, topic => 0, attachment => 'webpath' },

    # Foo/Bar/Dog.Cat
    'Sd' => { webpath => 0, topic => 2, attachment => 1 },

    # Foo.Bar.Dog/Cat
    'Ds' => { webpath => 0, topic => 1, attachment => 1 },

    # Foo.Bar.Dog/Cat/Bat
    'DS' => { webpath => 0, topic => 0, attachment => 1 },

    # Foo/Bar/Dog.Cat.Bat
    'SD' => { webpath => 0, topic => 0, attachment => 1 },

    # Foo/Bar.Dog/Cat
    'sds' => { webpath => 0, topic => 0, attachment => 2 },

    # Foo/Bar/Dog.Cat/Bat
    'Sds' => { webpath => 0, topic => 0, attachment => 2 },

    # Foo.Bar/Dog.Cat
    'dsd' => { webpath => 0, topic => 0, attachment => 2 },

    # Foo.Bar.Dog/Cat.Bat
    'Dsd' => { webpath => 0, topic => 0, attachment => 1 },

    # Foo.Bar/Dog.Cat.Bat
    'dsD' => { webpath => 0, topic => 0, attachment => 2 },

    # Foo/Bar.Dog/Cat.Bat
    'sdsd' => { webpath => 0, topic => 0, attachment => 2 },

    # Foo/Bar.Dog/Cat.B.a.t
    'sdsD' => { webpath => 0, topic => 0, attachment => 2 },

    # Foo/Bar/Dog.Cat/B.at
    'Sdsd' => { webpath => 0, topic => 0, attachment => 2 },

    # Foo/Bar/Dog.Cat/B.a.t
    'SdsD' => { webpath => 0, topic => 0, attachment => 2 }
);
my %sepidentchars =
  ( 0 => { '.' => 'd', '/' => 's' }, 1 => { '.' => 'D', '/' => 'S' } );

=begin TML

---++ ClassMethod new( %constructor ) => $addrObj

Create a =Foswiki::Address= instance

The constructor takes two main forms:

---+++ Explicit form
*Example:*
<verbatim>
my $addrObj = Foswiki::Address->new(
    web        => 'Web/SubWeb',
    topic      => 'Topic',
    attachment => 'Attachment.pdf',
    rev => 3
);</verbatim>

*Options:*
| *Param*   | *Description* | *Notes* |
| =web=     | =$string= of web path, %BR% used if =webpath= is empty/null | |
| =webpath= | =\@arrayref= of web path, root web first | |
| =topic=   | =$string= topic name | |
| =rev=     | =$integer= revision number. | If the tompath is to a =attachment= datastream, rev applies to that file; topic rev otherwise |
| =tompath= | =\@arrayref= of a "TOM" path, one of:%BR% =META=, =text=, =SECTION=, =attachment=.  | See table below |
| =string=  | string representation of an object | eg. 'Web/SubWeb.Topic/Attachment.pdf@3' |

*path forms:*
| *tompath*                                           | *Description* |
| =['attachment']=                                    | All datastreams attached to a topic |
| =['attachment', 'Attachment.pdf']=                  | Datastream of the file attachment named 'Attachment.pdf' |
| =['META']=                                          | All =META= on a topic |
| =['META', 'FIELD']=                                 | All =META:FIELD= members on a topic |
| =['META', 'FIELD', { name => 'Colour' }]=           | The =META:FIELD= member whose =name='Colour'= |
| =['META', 'FIELD', 3]=                              | The fourth =META:FIELD= member |
| =['META', 'FIELD', { name => 'Colour' }, 'title']=  | The ='title'= attribute on the =META:FIELD= member whose =name='Colour'= |
| =['META', 'FIELD', 3, 'title']=                     | The ='title'= attribute on the fourth =META:FIELD= member |
| =['text']=                                          | The topic text |
| =['SECTION']=                                       | All topic sections as defined by %SYSTEMWEB%.VarSTARTSECTION |
| =['SECTION', {name => 'foo'}]=                      | The topic section named 'foo' |
| =['SECTION', {name => 'foo', type => 'include'}]=   | The topic section named 'foo' of =type='include'= |

*Example:* Point to the value of a formfield =LastName= in =Web/SubWeb.Topic=,
<verbatim>
my $addrObj = Foswiki::Address->new(
  web     => 'Web/SubWeb',
  topic   => 'Topic',
  tompath => ['META', 'FIELD', {name => LastName}, 'value']
);</verbatim>

*Equivalent:* %JQREQUIRE{"chili"}%<verbatim class="tml">
%QUERY{"'Web/SubWeb.Topic'/META:FIELD[name='LastName'].value"}%
or
%QUERY{"'Web/SubWeb.Topic'/LastName"}%
</verbatim>

---+++ String form
*Example:*
<verbatim>
my $addrObj = Foswiki::Address->new(
    string => 'Web/SubWeb.Topic/Attachment.pdf@3',
    %opts
);</verbatim>

<blockquote class="foswikiHelp">%X% String form instantiation requires parsing
of the address string which comes with many options and caveats - refer to the
documentation for =parse()=.</blockquote>

=cut

sub new {
    my ( $class, %opts ) = @_;
    my $this;

    if ( $opts{string} ) {
        #ASSERT( not $opts{topic} or ( $opts{webpath} and $opts{topic} ) )
        #  if DEBUG;

        #        $this->{parseopts} = {
        #            web        => $opts{web},
        #            webpath    => $opts{webpath},
        #            topic      => $opts{topic},
        #            rev        => $opts{rev},
        #            isA        => $opts{isA},
        #            existAs    => undef,
        #            catchAs    => $opts{catchAs},
        #            existHints => $opts{existHints},
        #            string     => $opts{string}
        #        };
        # 15% faster if we do it like this...
        $this->{parseopts} = \%opts;

        if ( not $opts{isA} ) {

            # transpose the existAs array into hash keys
            if ( $opts{existAs} ) {
                ASSERT( ref( $opts{existAs} ) eq 'ARRAY' ) if DEBUG;
                ASSERT( scalar( @{ $opts{existAs} } ) ) if DEBUG;
                $this->{parseopts}->{existAsList} = $opts{existAs};
                $this->{parseopts}->{existAs} =
                  { map { $_ => 1 } @{ $opts{existAs} } };
            }
            else {
                $this->{parseopts}->{existAsList} = [qw(attachment topic)];
                $this->{parseopts}->{existAs} = { attachment => 1, topic => 1 };
            }
        }
        $this = bless( $this, $class );
        $this->parse( $opts{string} );
    }
    else {

  # 'Web/SubWeb' vs [qw(Web SubWeb)] (supplied as web vs webpath): if the latter
  # is absent, derive it from the former (supplied as web vs webpath)
        if ( not $opts{webpath} and $opts{web} ) {
            $opts{webpath} = [ split( /[\/\.]/, $opts{web} ) ];
        }

        #        $this = {
        #            webpath => $opts{webpath},
        #            topic   => $opts{topic},
        #            tompath => $opts{tompath},
        #            rev     => $opts{rev},
        #        };
        print STDERR "\$this: " . Data::Dumper->Dump( [ \%opts ] )
          if TRACEATTACH;
        if ( $opts{attachment} and not $opts{tompath} ) {
            print STDERR "Assigning {tompath} from {attachment}\n"
              if TRACEATTACH;
            $opts{tompath} = [ 'attachment', $opts{attachment} ];
        }
        elsif ( not $opts{attachment}
            and $opts{tompath}
            and ref( $opts{tompath} ) eq 'ARRAY'
            and $opts{tompath}->[0]   eq 'attachment'
            and $opts{tompath}->[1] )
        {
            print STDERR "Assigning {attachment} from {tompath}\n"
              if TRACEATTACH;
            $opts{attachment} = $opts{tompath}->[1];
        }
        if ( DEBUG and $opts{attachment} and $opts{tompath} ) {
            ASSERT(
                ref( $opts{tompath} ) eq 'ARRAY'
                  and $opts{tompath}->[0] ne 'attachment'
                  or (  $opts{tompath}->[1]
                    and $opts{tompath}->[1] eq $opts{attachment} )
            ) if DEBUG;
        }

        #$this->parse( $_[0]->{string} );
        $this = bless( \%opts, $class );
    }

    #push(@THESE, $this);

    return $this;
}

=begin TML

---++ ClassMethod finish( )

Clean up the object, releasing any memory stored in it.

=cut

sub finish {
    my ($this) = @_;

    $this->{root}                = undef;
    $this->{web}                 = undef;
    $this->{webpath}             = undef;
    $this->{topic}               = undef;
    $this->{rev}                 = undef;
    $this->{tompath}             = undef;
    $this->{attachment}          = undef;
    $this->{isA}                 = undef;
    $this->{type}                = undef;
    $this->{parseopts}           = undef;
    $this->{stringified}         = undef;
    $this->{stringifiedwebsep}   = undef;
    $this->{stringifiedtopicsep} = undef;

    return;
}

=begin TML

---++ ClassMethod parse( $string, %opts ) -> $success

Parse the given string (using options provided at instantiation, unless =%opts=
overrides them) and update the instance with the resulting address.

Examples of valid path strings include:

   * =Web/=
   * =Web/SubWeb/=
   * =Web/SubWeb.Topic= or =Web/SubWeb/Topic= or =Web.SubWeb.Topic=
   * =Web/SubWeb.Topic@2= or =Web/SubWeb/Topic@2= or =Web.SubWeb.Topic@2=
   * =Web/SubWeb.Topic/Attachment.pdf= or =Web/SubWeb/Topic/Attachment.pdf= or
     =Web.SubWeb.Topic/Attachment.pdf=
   * =Web/SubWeb.Topic/Attachment.pdf@3= or =Web/SubWeb/Topic/Attachment.pdf@3=
     or =Web.SubWeb.Topic/Attachment.pdf@3=

"String" addresses are notoriously ambiguous: Foswiki traditionally allows web
& topic separators '.' & '/' to be used interchangably. For example, the
following strings could be topics or attachments (or even webs):
   * =Foo.Bar=
   * =Foo.Bar.Cat.Dog=
   * =Foo/Bar=
   * =Foo/Bar/Cat/Dog=

To resolve the ambiguity, components of ambiguous strings are tested for
existence as webs, topics or attachments and used as hints to help resolve them,
so it follows that:
<blockquote class="foswikiHelp">%X% Ambiguous address strings cannot be
considered stable; exactly which resource they resolve to depends on the
hinting algorithm, the parameters and hints supplied to it, and the existence
(or non-existence) of other resources</blockquote>

*Options:*
| *Param*         | *Description* | *Values* | *Notes* |
| =webpath= or =web= %BR% =topic= | context hints | refer to explicit form |\
 if =string= is ambiguous (and possibly not fully qualified, Eg. topic-only or\
 attachment-only), the hinting algorithm tests =string= against them |
| =isA=     | resource type specification | =$type= - 'web', 'topic',\
 'attachment' | parse =string= to resolve to the specified type; exist hinting\
 is skipped |
| =catchAs= | default resource type | =$type= - 'web', 'topic', 'attachment', 'none' |\
 if =string= is ambiguous AND (exist hinting fails OR is disabled), THEN\
 assume =string= to be (web, topic, file attachment or unparseable) |
| =existAs= | resource types to test | =\@typelist= containing one\
 or more of 'web', 'topic', 'attachment' | if =string= is ambiguous, test (in\
 order) as each of the specified types. Default: =[qw(attachment topic)]= |
| =existHints= | exist hinting enable/disable | =$boolean= |\
 enable/disable hinting through web/topic/attachment existence checks.\
 =string= *is assumed to be using the 'unambiguous' conventions below*; if it\
 isn't, =catchAs= is used |
   
#UnambiguousStrings
---+++ Unambiguous strings

To build less ambiguous address strings, use the following conventions:
   * Terminate web addresses with '/'
   * Separate subwebs in the web path with '/'
   * Separate topic from web path with '.'
   * Separate file attachments from topics with '/'
Examples:
   * =Web/SubWeb/=, =Web/=
   * =Web/SubWeb.Topic=
   * =Web.Topic/Attachment.pdf= 
   * =Web/SubWeb.Topic/Attachment.pdf=

Many strings commonly used in Foswiki will always be ambiguous (such as =Foo=,
=Foo/Bar=, =Foo/Bar/Cat=, =Foo.Bar.Cat=). Supplying an =isA= specification will
prevent the parser from using the (somewhat expensive) exist hinting heuristics.

<blockquote class="foswikiHelp">%I% In order to simplify the algorithm, a
string may only parse out as a web if:
   * It is of the form =Foo/=, or
   * =isA => 'web'= is specified, or
   * No other type is possible, and =catchAs => 'web'= is specified
</blockquote>

The exist hinting algorithm is skipped if:
   * =isA= specified
   * =string= not ambiguous

If =string= is ambiguous, the hinting algorithm works roughly as follows:
   * if exist hinting is disabled
      * and =catchAs= is specified (parse as the =catchAs= type), otherwise
      * the string cannot be parsed
   * if exist hinting is enabled, the string is checked for existence as each of
   the =existAs= types (default is 'attachment', 'topic')
      * if there is an exact match against one of the =existAs= types (finish), otherwise
      * if there were partial matches (select the combination which scores
      highest), otherwise
      * if =catchAs= was specified (parse as that type), otherwise
      * the string cannot be parsed
The following table attempts to explain how ambiguous forms can be interpreted
and resolved.
| *String form*      | *existHints* | *ambiguous* | *web[s]* | *topic* | *possible types* |
| =Foo/=             |              |             |          |         | web              |
| =Foo=              |              | %X%         |          |         | web %BR% needs =isA => 'web'= or =catchAs => 'web'=,%BR% error otherwise |
| =Foo=              |              |             | set      |         | topic |
| =Foo=              |              | 1           | set      | set     | topic, attachment |
| =Foo/Bar/=         |              |             |          |         | web              |
| =Foo/Bar=          |              |             |          |         | topic            |
| =Foo/Bar=          |              | 1           | set      |         | topic, attachment |
| =Foo.Bar=          |              |             |          |         | topic            |
| =Foo.Bar=          |              | 1           | set      | set     | topic, attachment |
| =Foo/Bar/Dog/=     |              |             |          |         | web              |
| =Foo/Bar/Dog=      |              | 1           |          |         | topic, attachment |
| =Foo.Bar/Dog=      | 0            |             |          |         | attachment |
| =Foo.Bar/Dog=      |              | 1           |          |         | topic, attachment |
| =Foo.Bar/D.g=      |              |             |          |         | attachment |
| =Foo/Bar.Dog=      |              |             |          |         | topic |
| =Foo/Bar.Dog=      |              | 1           | set      |         | topic, attachment |
| =Foo.Bar.Dog=      |              |             |          |         | topic |
| =Foo.Bar.Dog=      |              | 1           | set      | set     | topic, attachment |
| =Foo/Bar/Dog/Cat/= |              |             |          |         | web |
| =Foo/Bar.Dog.Cat=  |              |             |          |         | topic |
| =Foo/Bar.Dog.Cat=  |              | 1           | set      |         | topic, attachment |
| =Foo/Bar.Dog/Cat=  |              |             |          |         | attachment |
| =Foo/Bar.Dog/C.t=  |              |             |          |         | attachment |
| =Foo/Bar/Dog.Cat=  | 0            |             |          |         | topic |
| =Foo/Bar/Dog.Cat=  |              | 1           |          |         | topic, attachment |
| =Foo/Bar/Dog/Cat=  |              | 1           |          |         | topic, attachment |
| =Foo/Bar/Dog/C.t=  |              | 1           |          |         | topic, attachment |
| =Foo.Bar.Dog/Cat=  | 0            |             |          |         | attachment |
| =Foo.Bar.Dog/Cat=  |              | 1           |          |         | topic, attachment |
| =Foo.Bar.Dog/C.t=  |              |             |          |         | attachment |

=cut

sub parse {
    my ( $this, $path, %opts ) = @_;

    print STDERR "parse(): parsing '$path'\n" if TRACE2;
    $this->_invalidate();
    if ( not $this->{parseopts} ) {
        $this->{parseopts} = {
            web         => $opts{web},
            webpath     => $opts{webpath},
            topic       => $opts{topic},
            rev         => $opts{rev},
            existAsList => [qw(attachment topic)],
            existAs     => { attachment => 1, topic => 1 }
        };
    }
    %opts = ( %{ $this->{parseopts} }, %opts );
    ASSERT(
        ( !defined $opts{rev} || $opts{rev} =~ /^[-\+]?\d+$/ ),
        "rev: '"
          . ( defined $opts{rev} ? $opts{rev} : 'undef' )
          . "' is numeric"
    ) if DEBUG;
    ASSERT( $opts{isA} or defined $opts{existAs} ) if DEBUG;
    if ( $path =~ s/\@([-\+]?\d+)$// ) {
        $this->{rev} = $1;
    }

    # if necessary, populate webpath from web parameter
    if ( not $opts{webpath} and $opts{web} ) {
        $opts{webpath} = [ split( /[\/\.]/, $opts{web} ) ];
    }

    ASSERT( not $opts{webpath} or ref( $opts{webpath} ) eq 'ARRAY' ) if DEBUG;

    # Because of the way we split, 'Foo/' causes final element to be empty
    if ( $opts{webpath} and not $opts{webpath}->[-1] ) {
        pop( @{ $opts{webpath} } );
    }

    # pre-compute web's string form (avoid unnecessary join()s)
    if ( not $opts{web} and $opts{webpath} ) {
        $opts{web} = join( '/', @{ $opts{webpath} } );
    }

    # Is the path explicit?
    if ( not $opts{isA} ) {
        if ( substr( $path, -1, 1 ) eq '/' ) {
            if ( length($path) > 1 ) {
                $opts{isA} = 'web';
            }
            else {

                # $path eq '/' - the mythical "root" path
                $opts{isA} = 'root';
            }
        }
        elsif ( substr( $path, 0, 1 ) eq '\'' or $path =~ /\[/ ) {
            $opts{isA} = '*';
        }
    }

    # Here we go... short-circuit testing if we already have an isA spec
    if ( $opts{isA} ) {

        print STDERR "parse(): isA: $opts{isA}\n" if TRACE2;
        ASSERT( $atomiseAs{ $opts{isA} } ) if DEBUG;
        $atomiseAs{ $opts{isA} }->( $this, $this, $path, \%opts );
    }
    else {
        my @separators = ( $path =~ m/([\.\/])/g );
        my $sepboost   = 0;
        my $sepident   = '';
        my $lastsep;
        my $plaus;
        my @trylist;
        my $normalform;
        my %typeatoms;
        my %typescores;
        my $parsed;

        ASSERT( ref( $opts{existAsList} ) eq 'ARRAY' ) if DEBUG;

        if ( scalar(@separators) ) {

            # build the separator-based identity of the path string, Eg.
            # Foo/Bar/Dog.Cat/B.a.t = 'SdsD'
            # TemporaryAddressTestsTestWeb/SubWeb/SubSubWeb.Topic/Atta.hme.t
            foreach my $sep (@separators) {
                if ( defined $lastsep ) {
                    if ( $lastsep ne $sep ) {
                        $sepident .= $sepidentchars{$sepboost}->{$lastsep};
                        $lastsep  = $sep;
                        $sepboost = 0;
                    }
                    else {
                        $sepboost = 1;
                    }
                }
                else {
                    $lastsep = $sep;
                }
            }
            $sepident .= $sepidentchars{$sepboost}->{$lastsep};
        }
        $plaus = $plausibletable{$sepident};
        print STDERR "Identity\t$sepident calculated for $path, plaustable: "
          . Data::Dumper->Dump( [$plaus] )
          if TRACE;

        # Is the identity known?
        if ($plaus) {

            # Default to exist hinting enabled
            if ( not defined $opts{existHints} ) {
                $opts{existHints} = 1;
            }

            # (ab)using %opts to match values from the plausible table
            $opts{1} = 1;
            $opts{2} = 1;

            # @trylist is the intersection of existAs list and the plausible
            # list. existAs ordering is used unless string is "unambiguous"
            # form, in which case that type is positioned first.
            foreach my $type ( @{ $opts{existAsList} } ) {

                # If the type is plausible, and the options support it
                if ( $plaus->{$type} and $opts{ $plaus->{$type} } ) {

                    # If an "unambiguous" form, put it first in the @trylist.
                    if ( $plaus->{$type} eq 2 ) {
                        unshift( @trylist, $type );
                        $normalform = $type;

                     # If existHints are allowed, add the plausible type to list
                    }
                    elsif ( $opts{existHints} ) {
                        push( @trylist, $type );
                    }
                }
            }

            # Exist hinting. The first complete hit, or the hit which matches
            # the most (out of the existAsList, Eg.: attachment, topic, web)
            # wins. The former should naturally fall out of the latter, unless
            # the existAs list is not ordered smallestthing-first
            if ( $opts{existHints} ) {
                my $i        = 0;
                my $ntrylist = scalar(@trylist);
                my $besttype;
                my $bestscore;
                my $bestscoredtype;

                # If a complete hit is detected, we set $besttype & exit early
                while ( $ntrylist > $i and not $besttype ) {
                    my $score;
                    my $type = $trylist[$i];

                    $i += 1;
                    print STDERR "Trying to atomise $path as $type...\n"
                      if TRACE;
                    ASSERT( $atomiseAs{$type} ) if DEBUG;
                    $typeatoms{$type} =
                      $atomiseAs{$type}->( $this, {}, $path, \%opts );
                    print STDERR "Atomised $path as $type, result: "
                      . Data::Dumper->Dump( [ $typeatoms{$type} ] )
                      if TRACE;
                    ( $besttype, $score ) =
                      $this->_existScore( $typeatoms{$type}, $type );

                    if (TRACE) {
                        print STDERR 'existScore: '
                          . ( $score || '' )
                          . ' besttype: '
                          . ( $besttype || '' ) . "\n";
                    }

                    if ( $score
                        and ( not defined $bestscore or $bestscore < $score ) )
                    {
                        $bestscoredtype = $type;
                        $bestscore      = $score;
                    }
                }

                # Unless we already got a perfect hit; find the type for this
                # path that gives the highest score
                if ( not $besttype ) {
                    $besttype = $bestscoredtype;
                }

                # Copy the atoms from the best hit into our instance.
                if ($besttype) {
                    $this->{web}        = $typeatoms{$besttype}->{web};
                    $this->{webpath}    = $typeatoms{$besttype}->{webpath};
                    $this->{topic}      = $typeatoms{$besttype}->{topic};
                    $this->{tompath}    = $typeatoms{$besttype}->{tompath};
                    $this->{attachment} = $typeatoms{$besttype}->{attachment};
                    $parsed             = 1;
                }
            }
        }
        if ( not $parsed ) {
            my $type = $normalform || $opts{catchAs};

            if ($type) {
                ASSERT( $atomiseAs{$type} ) if DEBUG;
                $typeatoms{$type} =
                  $atomiseAs{$type}->( $this, $this, $path, \%opts );
            }
        }
    }

    return $this->isValid();
}

#sub _atomiseAs {
#    my ( $this, $that, $path, $type, $opts ) = @_;
#
#    ASSERT($path)             if DEBUG;
#    ASSERT($type)             if DEBUG;
#    ASSERT( $atomiseAs{$type} ) if DEBUG;
#    $atomiseAs{$type}->( $this, $that, $path, $opts );
#
#    return $that;
#}

sub _atomiseAsRoot {
    my ( $this, $that, $path, $opts ) = @_;

    print STDERR "_atomiseAsRoot():\n" if TRACE2;
    ASSERT( $path eq '/' ) if DEBUG;
    $that->{root}       = 1;
    $that->{web}        = undef;
    $that->{webpath}    = undef;
    $that->{topic}      = undef;
    $that->{tompath}    = undef;
    $that->{attachment} = undef;

    return $that;
}

sub _atomiseAsWeb {
    my ( $this, $that, $path, $opts ) = @_;

    print STDERR "_atomiseAsWeb():\n" if TRACE2;
    $that->{web} = $path;
    $that->{webpath} = [ split( /[\.\/]/, $path ) ];
    ASSERT( $that->{web} and ref( $that->{webpath} ) eq 'ARRAY' ) if DEBUG;

    # If we had a path that looks like 'Foo/'
    if ( not $that->{webpath}->[-1] ) {
        pop( @{ $that->{webpath} } );
        chop( $that->{web} );
    }
    $that->{topic}      = undef;
    $that->{tompath}    = undef;
    $that->{attachment} = undef;

    return $that;
}

sub _atomiseAsTopic {
    my ( $this, $that, $path, $opts ) = @_;
    ASSERT($path) if DEBUG;
    my @parts = split( /[\.\/]/, $path );
    my $nparts = scalar(@parts);

    print STDERR "_atomiseAsTopic(): path: $path, nparts: $nparts\n" if TRACE2;
    if ( $nparts == 1 ) {
        if (    $opts->{webpath}
            and ref( $opts->{webpath} ) eq 'ARRAY'
            and scalar( @{ $opts->{webpath} } ) )
        {
            $that->{web}     = $opts->{web};
            $that->{webpath} = $opts->{webpath};
            $that->{topic}   = $path;
        }
    }
    else {
        $that->{webpath} = [ @parts[ 0 .. ( $nparts - 2 ) ] ];
        $that->{web} = undef;

        # $that->{web} = join( '/', @{ $that->{webpath} } );
        $that->{topic} = $parts[-1];
    }
    $that->{tompath}    = undef;
    $that->{attachment} = undef;
    ASSERT( $that->{webpath} or not $that->{topic} ) if DEBUG;

    # ASSERT( $that->{web} ) if DEBUG;

    return $that;
}

sub _atomiseAsAttachment {
    my ( $this, $that, $path, $opts ) = @_;

    print STDERR "_atomiseAsAttachment():\n" if TRACE2;
    ASSERT($path) if DEBUG;
    if ( my ( $lhs, $file ) = ( $path =~ /^(.*?)\/([^\/]+)$/ ) ) {
        $that = $this->_atomiseAsTopic( $that, $lhs, $opts );
        $that->{tompath} = [ 'attachment', $file ];
        $that->{attachment} = $file;
    }
    else {
        if ( $opts->{webpath} and $opts->{topic} ) {
            $that->{webpath}    = $opts->{webpath};
            $that->{web}        = $opts->{web};
            $that->{topic}      = $opts->{topic};
            $that->{tompath}    = [ 'attachment', $path ];
            $that->{attachment} = $path;
        }
    }

    return $that;
}

=begin TML

---++ PRIVATE ClassMethod _atomiseAsTOM ( $that, $path, $opts ) => $that

Parse a small subset ('static' meta path forms) of QuerySearch (VarQUERY)
compatible expressions.

=$opts= is a hashref holding default context

'topic'/ ref part is optional; =_atomiseAsTOM()= falls-back to default topic
context supplied in =$opts= otherwise. In other words, both of these forms are
supported:
   * ='Web/SubWeb.Topic@3'/META:FIELD[name='Colour'].value=
   * =META:FIELD[name='Colour'].value=

| *Form*                            | *tompath*                             | *type* |
| =META=                            | =['META']=                            | meta       |
| =META:FIELD=                      | =['META', 'FIELD']=                     | metatype   |
| =META:FIELD[name='Colour']=       | =['META', 'FIELD', {name => 'Colour'}]= | metamember |
| =META:FIELD[3]=                   | =['META', 'FIELD', 3]=                  | metamember |
| =META:FIELD[name='Colour'].value= | =['META', 'FIELD', {name => 'Colour'}, 'value']= | metakey |
| =META:FIELD[3].value=             | =['META', 'FIELD', 3, 'value']=         | metakey |
| =fields=                          | =['META', 'FIELD']=                     | metatype   |
| =fields[name='Colour']=           | =['META', 'FIELD', {name => 'Colour'}]= | metamember |
| =fields[3]=                       | =['META', 'FIELD', 3]=                  | metamember |
| =fields[name='Colour'].value=     | =['META', 'FIELD', 3, 'value']=         | metakey |
| =MyForm=                          | =['META', 'FIELD', {form => 'MyForm'}]= | metatype |
| =MyForm[name='Colour']=           | =['META', 'FIELD', {form => 'MyForm', name => 'Colour'}]=          | metamember |
| =MyForm[name='Colour'].value=     | =['META', 'FIELD', {form => 'MyForm', name => 'Colour'}, 'value']= | metakey |
| =MyForm.Colour=                   | =['META', 'FIELD', {form => 'MyForm', name => 'Colour'}, 'value']= | metakey |
| =Colour=                          | =['META', 'FIELD', {name => 'Colour'}, 'value']=                   | metakey |
=cut

sub _atomiseAsTOM {
    my ( $this, $that, $path, $opts ) = @_;

    print STDERR "_atomiseAsTOM():\n" if TRACE2;

    # QuerySearch meta path?
    # SMELL: This should be done in the query parser...
    #        ... or at least use Regexp::Grammars
    # TODO: member selectors may only be on 1 or 2 keys, or array index
    if (
        $path =~ /^
            (                      #  1
                '([^']+)'          #  2 'Web.Topic@123'
                \s* \/ \s*
            )?
            (META:)?               #  3 META:
            ([^\[\s\.]+)           #  4 PART, FIELD, alias, MyForm, FieldName
            (\s* \[ \s*            #  5 [............]  
                (                  #  6  n (or)
                    [-\+]?\d+
                    |(             #  7 name='foo'[ AND bar='cat' [ AND dog='bat' ...]]
                        ([^=\s]+)  #  8    name
                        \s* = \s*  #            =
                        '([^']+)'  #  9         'foo'
                        (          # 10 multi-key selector?
                            \s* AND \s*
                            ([^=\s]+) #  11  bar
                            \s* = \s* #         =
                            '([^']+)' #  12      'cat'
                        )?
                    )
                )
            \s* \])?
            (\s* \. \s*            # 13              .
                (\w+?)             # 14               value
            )?
        $/x
      )
    {
        my $webtopicrev = $2;
        my @tompath;
        my $doneselector;
        my $doneaccessor;

        if ($3) {    # META:
            @tompath = ('META');
            push( @tompath, $4 );
            if ( not $5 and $14 ) {    # Eg. META:TOPICINFO.author
                push( @tompath, undef, $14 );
                $doneselector = 1;
                $doneaccessor = 1;
            }
        }
        elsif ( $pathtypes{$4} ) {     # META, attachment, SECTION, text
            @tompath = ($4);
        }
        elsif ( $Foswiki::Meta::aliases{$4} ) {    # fields, attachments, info
            @tompath = ('META');

            # strip off the 'META:' part
            push( @tompath, substr( $Foswiki::Meta::aliases{$4}, 5 ) );
            if ( not $5 and $14 ) {                # Eg. info.author
                push( @tompath, undef, $14 );
                $doneselector = 1;
                $doneaccessor = 1;
            }
        }
        elsif ($4) {    # SomeFormField or SomethingForm
            @tompath = ('META');
            push( @tompath, 'FIELD' );
            if ( not( $14 or $6 ) ) {    # SomeFormField
                    # SMELL: This catches "'Web.Topic@123'/MyForm" & "MyForm"
                push( @tompath, { name => $4 }, 'value' );
                $doneselector = 1;
                $doneaccessor = 1;
            }
            elsif ( substr( $4, -4, 4 ) eq 'Form' ) {    # SomethingForm
                push( @tompath, { form => $4 } );
                if ($8) {                                # SomethingForm[a=b
                    ASSERT( defined $9 ) if DEBUG;
                    $tompath[-1]->{$8} = $9;
                    if ($11) {    # SomethingForm[a=b AND c=d]
                        ASSERT( defined $12 ) if DEBUG;
                        $tompath[-1]->{$11} = $12;
                    }
                    $doneselector = 1;
                }
                elsif ($6) {      # SomethingForm[n]
                    push( @tompath, $6 );
                    $doneselector = 1;
                    ASSERT( $6 =~ /^\d+$/ ) if DEBUG;
                }
                elsif ($14) {
                    $tompath[-1]->{name} = $14;
                    push( @tompath, 'value' );
                    $doneaccessor = 1;
                }
            }
            elsif (DEBUG) {    # form not /Form$/ or alias from disabled plugin
                ASSERT(0);
            }
        }
        elsif (DEBUG) {        # Shouldn't get here
            ASSERT(0);
        }
        if ( not $doneselector and $6 ) {    # SOMETHING[...]
            if ($8) {                        # SOMETHING[a=b
                ASSERT( defined $9 ) if DEBUG;
                push( @tompath, { $8 => $9 } );
                if ($11) {                   # SOMETHING[a=b AND c=d]
                    ASSERT( defined $12 ) if DEBUG;
                    $tompath[-1]->{$11} = $12;
                }
            }
            else {                           # SOMETHING[n]
                ASSERT($6) if DEBUG;
                push( @tompath, $6 );
                ASSERT( $6 =~ /^\d+$/ ) if DEBUG;
            }
            $doneselector = 1;
        }
        if ( not $doneaccessor and $14 ) {
            push( @tompath, $14 );
        }
        $that->{tompath} = \@tompath;
        if ($webtopicrev) {
            my $refAddr = Foswiki::Address->new(
                string  => $webtopicrev,
                isA     => 'topic',
                webpath => $opts->{webpath},
                web     => $opts->{web}
            );

            $that->{web}     = $refAddr->{web};
            $that->{webpath} = $refAddr->{webpath};
            $that->{topic}   = $refAddr->{topic};
            $that->{rev}     = $refAddr->{rev};
            ASSERT(
                ( !defined $that->{rev} || $that->{rev} =~ /^[-\+]?\d+$/ ),
                "rev '"
                  . ( defined $that->{rev} ? $that->{rev} : 'undef' )
                  . "' is numeric"
            ) if DEBUG;
        }
        else {
            $that->{webpath} = $opts->{webpath};
            $that->{topic}   = $opts->{topic};
            $that->{rev}     = undef;
            ASSERT( $that->{webpath} ) if DEBUG;
            ASSERT( $that->{topic} )   if DEBUG;
        }
    }

    return $that;
}

sub _existScore {
    my ( $this, $atoms, $type ) = @_;
    my $score;
    my $perfecttype;

    ASSERT( not $atoms->{tompath} or ref( $atoms->{tompath} ) eq 'ARRAY' )
      if DEBUG;
    ASSERT( $atoms->{web} or ref( $atoms->{webpath} ) eq 'ARRAY' ) if DEBUG;
    if (
            $atoms->{tompath}
        and scalar( @{ $atoms->{tompath} } ) == 2
        and ( $atoms->{tompath}->[0] eq 'attachment' )
        and Foswiki::Func::attachmentExists(
            $atoms->{web}, $atoms->{topic}, $atoms->{tompath}->[1]
        )
      )
    {
        ASSERT(   $atoms->{attachment}
              and $atoms->{attachment} eq $atoms->{tompath}->[1] )
          if DEBUG;
        $perfecttype = $type;
        $score       = 2 + scalar( @{ $atoms->{webpath} } );
    }
    elsif ( $atoms->{topic}
        and Foswiki::Func::topicExists( $atoms->{web}, $atoms->{topic} ) )
    {
        if ( $type eq 'topic' ) {
            $perfecttype = $type;
        }
        $score = 1 + scalar( @{ $atoms->{webpath} } );
    }
    elsif ( $atoms->{web} and Foswiki::Func::webExists( $atoms->{web} ) ) {
        if ( $type eq 'web' ) {
            $perfecttype = $type;
        }
        $score = scalar( @{ $atoms->{webpath} } );
    }
    elsif ( $atoms->{webpath} ) {
        ASSERT( scalar( @{ $atoms->{webpath} } ) ) if DEBUG;
        ASSERT( ref( $atoms->{webpath} ) eq 'ARRAY' ) if DEBUG;
        my $i      = scalar( @{ $atoms->{webpath} } );
        my $nAtoms = scalar( @{ $atoms->{webpath} } );

        while ( $i > 0 and not $score ) {
            $i -= 1;
            if (
                Foswiki::Func::webExists(
                    join( '/', @{ $atoms->{webpath} }[ 0 .. $i ] )
                )
              )
            {
                $score = $i + 1;
            }
        }
    }

    return ( $perfecttype, $score );
}

=begin TML

---++ ClassMethod stringify ( %opts ) => $string

Return a string representation of the address.

=%opts=:
   * =webseparator= - '/' or '.'; default: '/'
   * =topicseparator= - '/' or '.'; default: '.'

The output of =stringify()= is understood by =parse()=, and vice versa.

=cut

sub stringify {
    my ( $this, %opts ) = @_;

    ASSERT( $this->isValid(), 'valid address' ) if DEBUG;

    # If there's a valid address; and check that we haven't already computed
    # the stringification before with the same opts
    if (
        not $this->{stringified}
        or (    $opts{webseparator}
            and $opts{webseparator} ne $this->{stringifiedwebsep} )
        or (    $opts{topicseparator}
            and $opts{topicseparator} ne $this->{stringifiedtopicsep} )
      )
    {
        $this->{stringifiedwebsep} = $opts{webseparator}
          || '/';
        $this->{stringifiedtopicsep} = $opts{topicseparator}
          || '.';
        if ( $this->{webpath} ) {
            $this->{stringified} =
              join( $this->{stringifiedwebsep}, @{ $this->{webpath} } );
            if ( $this->{topic} ) {
                $this->{stringified} .=
                  $this->{stringifiedtopicsep} . $this->{topic};
                if ( $this->{tompath} ) {
                    ASSERT( ref( $this->{tompath} ) eq 'ARRAY'
                          and scalar( @{ $this->{tompath} } ) )
                      if DEBUG;
                    print STDERR 'tompath:    '
                      . Data::Dumper->Dump( [ $this->{tompath} ] )
                      if TRACEATTACH;
                    print STDERR 'attachment: '
                      . Data::Dumper->Dump( [ $this->{attachment} ] )
                      if TRACEATTACH;
                    ASSERT(
                             $this->{tompath}->[0] ne 'attachment'
                          or not $this->{tompath}->[1]
                          or (  $this->{attachment}
                            and $this->{attachment} eq $this->{tompath}->[1] )
                    ) if DEBUG;
                    if ( $this->{tompath}->[0] eq 'attachment'
                        and scalar( @{ $this->{tompath} } ) == 2 )
                    {
                        $this->{stringified} .= '/' . $this->{tompath}->[1];
                        if ( defined $this->{rev} ) {
                            $this->{stringified} .= '@' . $this->{rev};
                        }
                    }
                    else {
                        if ( defined $this->{rev} ) {
                            $this->{stringified} .= '@' . $this->{rev};
                        }
                        $this->{stringified} = '\''
                          . $this->{stringified} . '\'/'
                          . $this->{tompath}->[0];
                        if ( $this->{tompath}->[1] ) {
                            my @path = @{ $this->{tompath} };
                            my $root = shift(@path);

                            if ( $root eq 'META' and scalar(@path) ) {
                                $this->{stringified} .= ':' . shift(@path);
                            }
                            if ( scalar(@path) ) {
                                if ( defined $path[0] ) {
                                    $this->{stringified} .= '[';
                                    if ( ref( $path[0] ) eq 'HASH' ) {
                                        my @selectorparts;
                                        while ( my ( $key, $value ) =
                                            each %{ $path[0] } )
                                        {
                                            push( @selectorparts,
                                                $key . '=\'' . $value . '\'' );
                                        }
                                        $this->{stringified} .=
                                          join( ' AND ', @selectorparts );
                                        shift(@path);
                                    }
                                    else {
                                        ASSERT( $path[0] =~ /^\d+$/ ) if DEBUG;
                                        $this->{stringified} .= shift(@path);
                                    }
                                    $this->{stringified} .= ']';
                                }
                                else {
                                    shift @path;
                                }
                                if ( scalar(@path) ) {
                                    ASSERT( scalar(@path) == 1 ) if DEBUG;
                                    $this->{stringified} .= '.' . shift(@path);
                                }
                            }
                            ASSERT( not scalar(@path) ) if DEBUG;
                        }
                    }
                }
                elsif ( defined $this->{rev} ) {
                    $this->{stringified} .= '@' . $this->{rev};
                }
            }
            else {
                $this->{stringified} .= $this->{stringifiedwebsep};
            }
        }
        else {
            ASSERT( $this->{root} );
            $this->{stringified} = '/';
        }
    }
    print STDERR "stringify(): $this->{stringified}\n"
      if TRACE2 and $this->{stringified};

    return $this->{stringified};
}

=begin TML

---++ EXPERIMENTAL ClassMethod root( [$boolean] ) => $boolean

   * =$boolean= - optional, set the hypothetical Foswiki 'root'. Since all
   Foswiki resources must exist under the root, a false value here basically
   means the address object is an undefined/invalid state.

Get/set root

<blockquote class="tml">%X% This method (and the =root= attribute generally)
may be removed before we release Foswiki 1.2/2.0. We would rather use web => '/'
</blockquote>

=cut

sub root {
    my ( $this, $root ) = @_;

    if ( scalar(@_) == 2 ) {
        $this->{root} = $root;
        $this->_invalidate();
    }
    else {
        $this->isValid();
    }

    return $this->{root};
}

=begin TML

---++ ClassMethod web( [$name] ) => $name

   * =$name= - optional, set a new web name

Get/set by web string

=cut

sub web {
    my ( $this, $web ) = @_;

    ASSERT(
        scalar(@_) == 2
          or
          ( defined( $this->{webpath} ) and ref( $this->{webpath} ) eq 'ARRAY' )
    ) if DEBUG;
    if ( scalar(@_) == 2 ) {
        $this->webpath( [ split( /[\/\.]/, $web ) ] );
    }
    if ( not $this->{web} and defined( $this->{webpath} ) ) {
        $this->{web} = join( '/', @{ $this->{webpath} } );
    }
    print STDERR "web(): no web part!\n" if TRACE and not $this->{web};

    return $this->{web};
}

=begin TML

---++ ClassMethod webpath( [\@webpath] ) => \@webpath

   * =\@webpath= - optional, set a new webpath arrayref

Get/set the webpath arrayref

=cut

sub webpath {
    my ( $this, $webpath ) = @_;

    if ( scalar(@_) == 2 ) {
        $this->{webpath} = $webpath;
        $this->_invalidate();
    }

    return $this->{webpath};
}

=begin TML

---++ ClassMethod topic( [$name] ) => $name

   * =$name= - optional, set a new topic name

Get/set the topic name

=cut

sub topic {
    my ( $this, $topic ) = @_;

    if ( scalar(@_) == 2 ) {
        $this->{topic} = $topic;
        $this->_invalidate();
        ASSERT( $this->isValid() ) if DEBUG;
    }
    else {
        $this->isValid();
    }

    return $this->{topic};
}

=begin TML

---++ ClassMethod attachment( [$file] ) => $file

   * =$file= - optional, set a new file attachment name

Get/set the file attachment name

=cut

sub attachment {
    my ( $this, $attachment ) = @_;

    if ( scalar(@_) == 2 ) {
        $this->{attachment} = $attachment;
        $this->{tompath} = [ 'attachment', $attachment ];
        $this->_invalidate();
        ASSERT( $this->isValid() ) if DEBUG;
    }
    else {
        $this->isValid();
    }

    return $this->{attachment};
}

=begin TML

---++ ClassMethod rev( [$rev] ) => $rev

   * =$rev= - optional, set rev number

Get/set the rev

=cut

sub rev {
    my ( $this, $rev ) = @_;

    if ( scalar(@_) == 2 ) {
        $this->{rev} = $rev;
        $this->_invalidate();
        ASSERT( $this->isValid() ) if DEBUG;
    }
    else {
        $this->isValid();
    }

    return $this->{rev};
}

=begin TML

---++ ClassMethod tompath( [\@tompath] ) => \@tompath

   * =\@tompath= - optional, =tompath= specification into the containing topic.
   The first =$tompath->[0]= element in the array should be one of the following
      * ='attachment'=: =$tompath->[1]= should be a string, Eg. ='Attachment.pdf'=.
      * ='META'=: =$tompath->[1..3]= identify which =META:&lt;type&gt;= or member
      or member key is being addressed:
         * =$tompath->[1]= contains the =META:&lt;type&gt;=, Eg. ='FIELD'=
         * =$tompath->[2]= contains a selector to identify a member of the type:
            * =undef=, for singleton types (such as ='TOPICINFO'=)
            * integer array index
            * hashref =key => 'value'= pairs, Eg. ={name => 'Colour'}=.
            ={name => 'Colour', form => 'MyForm'}= is also supported.
         * =$tompath->[3]= contains the name of a key on the selected member,
         Eg. ='value'=
      * ='SECTION'=: =$tompath->[1]= should be a hashref, Eg.
      ={name => 'mysection', type => 'include'}=
      * ='text'=: addresses the topic text

Get/set the tompath into a topic

=cut

sub tompath {
    my ( $this, $tompath ) = @_;

    if ( scalar(@_) == 2 ) {
        $this->{tompath} = $tompath;
        $this->_invalidate();
        ASSERT(
            not defined $tompath
              or (  defined $tompath
                and ref($tompath) eq 'ARRAY'
                and scalar( @{$tompath} ) )
        ) if DEBUG;
    }
    else {
        $this->isValid();
    }

    return $this->{tompath};
}

=begin TML

---++ ClassMethod type() => $resourcetype

Returns the resource type name.

=cut

sub type {
    my ($this) = @_;

    return $this->isValid();
}

=begin TML

---++ ClassMethod isA([$resourcetype]) => $boolean

Returns true if the address points to a resource of the specified type.

=cut

sub isA {
    my ( $this, $resourcetype ) = @_;
    my $result;

    if ( $resourcetype and $this->isValid() ) {
        $result = $this->{isA}->{$resourcetype};
    }

    return $result;
}

=begin TML

---++ ClassMethod isValid() => $resourcetype

Returns true if the instance addresses a resource which is one of the following
types:
   * webpath, Eg. =Web/SubWeb/=
   * topic, Eg. =Web/SubWeb.Topic=
   * attachment, Eg. =Web/SubWeb.Topic/Attachment.pdf=
   * attachments , Eg. ='Web/SubWeb.Topic/attachment'=
   * meta, Eg. ='Web/SubWeb.Topic'/META=
   * metatype, Eg. ='Web/SubWeb.Topic'/META:FIELD=
   * metamember, Eg. ='Web/SubWeb.Topic'/META:FIELD[name='Colour']= or ='Web/SubWeb.Topic'/META:FIELD[0]=
   * metakey, Eg. ='Web/SubWeb.Topic'/META:FIELD[name='Colour'].value= or ='Web/SubWeb.Topic'/META:FIELD[0].value=
   * section, Eg. ='Web/SubWeb.Topic'/SECTION[name='something']=
   * sections, Eg. ='Web/SubWeb.Topic'/SECTION=
   * text, Eg. ='Web/SubWeb.Topic'/text=

=cut

sub isValid {
    my ($this) = @_;

    if ( not defined $this->{isA} ) {
        print STDERR "isValid(): we don't know what we are (yet)\n"
          if TRACEVALID;
        if ( $this->{topic} ) {
            $this->_trace_have_valid('topic') if TRACEVALID;
            ASSERT( $this->{topic} !~ /[\/\.]/,
                "topic '$this->{topic}' contains no path separators" )
              if DEBUG;
            if ( $this->{webpath} ) {
                $this->_trace_have_valid('webpath') if TRACEVALID;
                if ( $this->{attachment} ) {
                    $this->_trace_is_valid('attachment') if TRACEVALID;
                    $this->{type} = 'attachment';
                }
                elsif ( $this->{tompath} ) {
                    ASSERT( ref( $this->{tompath} ) eq 'ARRAY'
                          and scalar( @{ $this->{tompath} } ) )
                      if DEBUG;
                    ASSERT(
                        not(    $this->{topmath}->[0]
                            and $this->{topmath}->[0] eq 'attachment' )
                    ) if DEBUG;
                    ASSERT( $pathtypes{ $this->{tompath}->[0] } ) if DEBUG;
                    $this->{type} =
                      $pathtypes{ $this->{tompath}->[0] }
                      ->{ scalar( @{ $this->{tompath} } ) };
                    $this->_trace_is_valid( $this->{type} ) if TRACEVALID;
                }
                else {
                    ASSERT( not defined $this->{tompath} ) if DEBUG;
                    $this->_trace_is_valid('topic') if TRACEVALID;
                    $this->{type} = 'topic';
                }
            }
        }
        elsif ( $this->{webpath}
            and not defined $this->{tompath} )
        {
            $this->_trace_is_valid('webpath') if TRACEVALID;
            $this->{type} = 'webpath';
        }
        elsif ( $this->{root} ) {
            $this->_trace_is_valid('root') if TRACEVALID;
            $this->{type} = 'root';
        }
        else {
            $this->{type} = undef;
        }
        if ( $this->{type} ) {
            $this->{isA} = { $this->{type} => 1 };
            $this->{root} = 1;
        }
        else {
            print STDERR "isValid(): INVALID: " . $this->_trace_stringify($this)
              if TRACEVALID;
            $this->{isA} = {};
        }
        ASSERT(
            ( !defined $this->{rev} || $this->{rev} =~ /^[-\+]?\d+$/ ),
            "rev '"
              . ( defined $this->{rev} ? $this->{rev} : 'undef' )
              . "' is numeric"
        ) if DEBUG;
    }
    print STDERR "isValid(): final type is: $this->{type}\n" if TRACEVALID;

    return $this->{type};
}

sub _trace_stringify {
    my ( $this, $thing ) = @_;

    if ( ref($thing) ) {
        require Data::Dumper;
        $thing = Data::Dumper->Dump( [$thing] );
    }

    return $thing;
}

sub _trace_have_valid {
    my ( $this, $what ) = @_;

    print STDERR "isValid(): have $what => '"
      . $this->_trace_stringify( $this->{$what} ) . "'\n"
      if TRACEVALID;

    return;
}

sub _trace_is_valid {
    my ( $this, $what ) = @_;

    print STDERR "isValid(): type is $what => '"
      . $this->_trace_stringify( $this->{$what} ) . "'\n"
      if TRACEVALID;

    return;
}

# Internally, this is called so that the next isValid() call will re-evaluate
# identity and validity of the instance; also, if any of the setters are used,
# invalidates the cached stringify value
sub _invalidate {
    my ($this) = @_;

    $this->{stringified} = undef;
    $this->{isA}         = undef;

    return;
}

=begin TML

---++ ClassMethod equiv ( $otherAddr ) => $boolean

Return true if this address resolves to the same resource as =$otherAddr=

=cut

sub equiv {
    my ( $this, $other ) = @_;
    my $nwebpath;
    my $equal     = 0;
    my $thistype  = $this->type();
    my $othertype = $other->type();

    # Same type?
    if ( $thistype and $othertype and $thistype eq $othertype ) {

        # Confirm the ->type() is sane
        ASSERT(
            ( not defined $this->{tompath} and not defined $other->{tompath} )
              or (  defined $this->{tompath}
                and defined $other->{tompath}
                and ref( $this->{tompath} )  eq 'ARRAY'
                and ref( $other->{tompath} ) eq 'ARRAY'
                and scalar( @{ $this->{tompath} } )
                and scalar( @{ $other->{tompath} } )
                and scalar( @{ $this->{tompath} } ) ==
                scalar( @{ $other->{tompath} } ) )
        ) if DEBUG;
        ASSERT(
            ( not defined $this->{tompath} and not defined $other->{tompath} )
              or (  defined $this->{tompath}
                and defined $other->{tompath}
                and $this->{tompath}->[0] eq $other->{tompath}->[0] )
        ) if DEBUG;
        if ( $this->{webpath} ) {
            if ( $this->_eq( $this->{webpath}, $other->{webpath} ) ) {
                if ( $this->_eq( $this->{topic}, $other->{topic} ) ) {
                    if ( $this->_eq( $this->{tompath}, $other->{tompath} ) ) {
                        $equal = 1;
                    }
                    elsif (TRACE) {
                        print STDERR "equiv(): tompaths weren't equal\n";
                    }
                }
                elsif (TRACE) {
                    print STDERR "equiv(): topics weren't equal\n";
                }
            }
            elsif (TRACE) {
                print STDERR "equiv(): webpath wasn't equal\n";
            }
        }
        elsif ( $this->{root} ) {
            if ( $other->{root} ) {
                $equal = 1;
            }
            elsif (TRACE) {
                print STDERR "equiv(): roots weren't equal\n";
            }
        }
    }
    elsif (TRACE) {
        print STDERR "equiv(): types weren't equal\n";
    }
    if ( not $equal ) {
        print STDERR "equiv(): NOT equal "
          . Data::Dumper->Dump( [$this] ) . " vs "
          . Data::Dumper->Dump( [$other] ) . "\n"
          if TRACE;
    }

    return $equal;
}

sub _eq {
    my ( $this, $a, $b ) = @_;
    my $equal = 1;
    my $refA  = ref($a);
    my $refB  = ref($b);

    if ($refA) {
        if ( $refB and $refA eq $refB ) {
            if ( $refA eq 'ARRAY' ) {
                my $n = scalar( @{$a} );

                if ( $n == scalar( @{$b} ) ) {
                    my $i = 0;

                    while ( $equal and $i < $n ) {
                        $equal = $this->_eq( $a->[$i], $b->[$i] );
                        $i += 1;
                    }
                }
                else {
                    $equal = 0;
                }
            }
            elsif ( $refB eq 'HASH' ) {
                my @keys = keys %{$a};
                my $n    = scalar(@keys);

                if ( $n == scalar( keys %{$b} ) ) {
                    my $i = 0;

                    while ( $equal and $i < $n ) {
                        if ( exists $b->{ $keys[$i] } ) {
                            $equal =
                              $this->_eq( $a->{ $keys[$i] },
                                $b->{ $keys[$i] } );
                            $i += 1;
                        }
                        else {
                            $equal = 0;
                        }
                    }
                }
            }
        }
    }
    elsif ($refB
        or ( defined $a and not defined $b or not defined $a and defined $b )
        or ( defined $a and defined $b and $a ne $b ) )
    {
        $equal = 0;
    }

    return $equal;
}

1;
__END__
Author: Paul.W.Harvey@csiro.au

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2011 Foswiki Contributors. Foswiki Contributors
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
