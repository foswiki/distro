# See bottom of file for license and copyright information

package Foswiki::Address;

=begin TML

---+ package Foswiki::Address

Instances represent a pointer (address) to a web, topic (or parts thereof) or
file, optionally of a specific revision. This class does not offer any interface
to interact with Foswiki resources; rather, it provides the functionality
necessary to hold, manipulate, test and de/serialise addresses only.

Fundamentally, =Foswiki::Address= can be thought of as an interface to a hash of
the components necessary to address a specific Foswiki resource.

<verbatim>
my $addr = {
    webs     => [qw(Web SubWeb)],
    topic    => 'Topic',
    part     => 'FILE', # As in attachments; not to be confused with
                        # attachments metadata
             # part types: META, FILE, SECTION, text
    subpart  => 'Attachment.pdf',
    rev => 3
};
</verbatim>

=cut

use strict;
use warnings;

use Assert;
use Foswiki::Func();
use Foswiki::Meta();

use Data::Dumper;
use constant TRACE  => 0;    # Don't forget to uncomment dumper
use constant TRACE2 => 0;

my %plausibletable;
my %sepidentchars;
my %atomiseAs;
my %parttypes;

BEGIN {

    %atomiseAs = (
        web     => \&_atomiseAsWeb,
        topic   => \&_atomiseAsTopic,
        file    => \&_atomiseAsFILE,
        FILE    => \&_atomiseAsFILE,
        META    => \&_atomiseAsTOM,
        meta    => \&_atomiseAsTOM,
        SECTION => \&_atomiseAsTOM,
        text    => \&_atomiseAsTOM,
        '*'     => \&_atomiseAsTOM
    );

# The question is: what do we have? The hash is accessed as follows:
# $parttypes{ $part }->{ defined $subpart? (ref($subpart) eq 'ARRAY'? scalar(@{$subpart}) : 1) : 0 }
    %parttypes = (
        FILE => { 0 => 'files', 1 => 'file' },
        META =>
          { 0 => 'meta', 1 => 'metatype', 2 => 'metamember', 3 => 'metakey' },
        SECTION => { 0 => 'sections', 1 => 'section' },
        text    => { 0 => 'text' }
    );

    # I tried to create a logical parser, but it kept ending up as spaghetti.
    # So we use a lookup table instead... (probably?) easier to follow, faster.
    %plausibletable = (

        # root keys represent the path separator signature of the form:
        # combinations of s, S, d, D - where:
        #   s = <part>/<part> - sequence of two parts separated by '/'
        #   d = <part>.<part> - sequence of two parts separated by '.'
        #   S = <part>/<part>/<part>[/]... - sequence > 2 parts separated by '/'
        #   D = <part>.<part>.<part>[.]... - sequence > 2 parts separated by '.'
        #
        # sub keys are the type considered; values of the sub keys indicate
        # the plausibility that the given form could be the type indicated:
        # 0/undef - not plausible
        #       1 - plausible without using any context
        #       2 - normal ("unambiguous") form
        #  'webs' - plausible if given webs context
        # 'topic' - plausible if given webs & topic context
        #
        # Foo
        '' => { webs => 1, topic => 'webs', file => 'topic' },

        # Foo.Bar
        'd' => { webs => 1, topic => 2, file => 'topic' },

        # Foo/Bar
        's' => { webs => 1, topic => 1, file => 'webs' },

        # Foo/Bar.Dog
        'sd' => { webs => 0, topic => 2, file => 'webs' },

        # Foo.Bar/Dog
        'ds' => { webs => 0, topic => 1, file => 2 },

        # Foo/Bar/Dog
        'S' => { webs => 1, topic => 1, file => 1 },

        # Foo.Bar.Dog
        'D' => { webs => 1, topic => 1, file => 'topic' },

        # Foo.Bar/Cat/Dog
        'dS' => { webs => 0, topic => 1, file => 1 },

        # Foo/Bar.Cat.Dog
        'sD' => { webs => 0, topic => 0, file => 'webs' },

        # Foo/Bar/Dog.Cat
        'Sd' => { webs => 0, topic => 2, file => 1 },

        # Foo.Bar.Dog/Cat
        'Ds' => { webs => 0, topic => 1, file => 1 },

        # Foo.Bar.Dog/Cat/Bat
        'DS' => { webs => 0, topic => 0, file => 1 },

        # Foo/Bar/Dog.Cat.Bat
        'SD' => { webs => 0, topic => 0, file => 1 },

        # Foo/Bar.Dog/Cat
        'sds' => { webs => 0, topic => 0, file => 2 },

        # Foo/Bar/Dog.Cat/Bat
        'Sds' => { webs => 0, topic => 0, file => 2 },

        # Foo.Bar/Dog.Cat
        'dsd' => { webs => 0, topic => 0, file => 2 },

        # Foo.Bar.Dog/Cat.Bat
        'Dsd' => { webs => 0, topic => 0, file => 1 },

        # Foo.Bar/Dog.Cat.Bat
        'dsD' => { webs => 0, topic => 0, file => 2 },

        # Foo/Bar.Dog/Cat.Bat
        'sdsd' => { webs => 0, topic => 0, file => 2 },

        # Foo/Bar.Dog/Cat.B.a.t
        'sdsD' => { webs => 0, topic => 0, file => 2 },

        # Foo/Bar/Dog.Cat/B.at
        'Sdsd' => { webs => 0, topic => 0, file => 2 },

        # Foo/Bar/Dog.Cat/B.a.t
        'SdsD' => { webs => 0, topic => 0, file => 2 }
    );
    %sepidentchars =
      ( 0 => { '.' => 'd', '/' => 's' }, 1 => { '.' => 'D', '/' => 'S' } );
}

=begin TML

---++ ClassMethod new( %constructor ) => $addrObj

Create a =Foswiki::Address= instance

The constructor takes two main forms:

---+++ Explicit form
*Example:*
<verbatim>
my $addrObj = Foswiki::Address->new(
    webs => [qw(Web SubWeb)],
    topic => 'Topic',
    part => 'FILE',
    subpart => 'Attachment.pdf',
    rev => 3
);</verbatim>

*Options:*
| *Param*         | *Description* | *Notes* |
| =web=           | =$string= of web path, %BR% used if =webs= is empty/null | |
| =webs=          | =\@arrayref= of web path, root web first | |
| =topic=         | =$string= topic name | |
| =rev=           | =$integer= revision number. | If the part is an =files= member, rev applies to that file; topic rev otherwise |
| =part=          | =$string= topic root part, one of:%BR% =META=, =text=, =SECTION=, =FILE=.  | See table below |
| =subpart=       | =$scalar= or =\@arrayref= selector to a specific topic part | See table below |

*part forms:*
| *part*      | *subpart*             | *Description* |
| ='FILE'=    |                       | All files attached to a topic |
| ='FILE'=    | ='Attachment.pdf'=    | File named 'Attachment.pdf' |
| ='META'=    |                       | All =META= on a topic |
| ='META'=    | =['FIELD']=           | All =META:FIELD= members on a topic |
| ='META'=    | =['FIELD', { name => 'Colour' }]= | The =META:FIELD= member whose =name='Colour'= |
| ='META'=    | =['FIELD', 3]=        | The fourth =META:FIELD= member |
| ='META'=    | =['FIELD', { name => 'Colour' }, 'title']= | The ='title'= attribute on the =META:FIELD= member whose =name='Colour'= |
| ='META'=    | =['FIELD', 3, 'title']=        | The ='title'= attribute on the fourth =META:FIELD= member |
| ='text'=    | =undef=               | The topic text |
| ='SECTION'= | =undef=               | All topic sections |
| ='SECTION'= | =[{name => 'foo'}]=     | The topic section named 'foo' |
| ='SECTION'= | =[{name => 'foo', type => 'include'}]=  | The topic section named 'foo' of =type='include'= |

*Example:* Point to the value of a formfield =LastName= in =Web/SubWeb.Topic=,
<verbatim>
my $addrObj = Foswiki::Address->new(
  webs => [qw(Web SubWeb)],
  topic => 'Topic',
  part => 'META',
  subpart => ['FIELD', {name => LastName}, 'value'],
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
        ASSERT( not $opts{topic} or ( $opts{webs} and $opts{topic} ) ) if DEBUG;

        #        $this->{parseopts} = {
        #            web        => $opts{web},
        #            webs       => $opts{webs},
        #            topic      => $opts{topic},
        #            rev        => $opts{rev},
        #            part       => $opts{part},
        #            subpart    => $opts{subpart},
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
                $this->{parseopts}->{existAsList} = [qw(file topic)];
                $this->{parseopts}->{existAs} = { file => 1, topic => 1 };
            }
        }
        $this = bless( $this, $class );
        $this->parse( $opts{string} );
    }
    else {

     # 'Web/SubWeb' vs [qw(Web SubWeb)] (supplied as web vs webs): if the latter
     # is absent, derive it from the former (supplied as web vs webs)
        if ( not $opts{webs} and $opts{web} ) {
            $opts{webs} = [ split( /[\/\.]/, $opts{web} ) ];
        }

        #        $this = {
        #            webs    => $opts{webs},
        #            topic   => $opts{topic},
        #            rev     => $opts{rev},
        #            part    => $opts{part},
        #            subpart => $opts{subpart},
        #        };
        $this = bless( \%opts, $class );
    }

    return $this;
}

=begin TML

---++ ClassMethod finish( )

Clean up the object, releasing any memory stored in it.

=cut

sub finish {
    my ($this) = @_;

    $this->{web}                 = undef;
    $this->{webs}                = undef;
    $this->{topic}               = undef;
    $this->{rev}                 = undef;
    $this->{part}                = undef;
    $this->{subpart}             = undef;
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
| =webs= or =web= %BR% =topic= | context hints | refer to explicit form |\
 if =string= is ambiguous (and possibly not fully qualified, Eg. topic-only or\
 attachment-only), the hinting algorithm tests =string= against them |
| =isA=     | resource type specification | =$type= - 'web', 'topic',\
 'file' | parse =string= to resolve to the specified type; exist hinting\
 is skipped |
| =catchAs= | default resource type | =$type= - 'web', 'topic', 'file', 'none' |\
 if =string= is ambiguous AND (exist hinting fails OR is disabled), THEN\
 assume =string= to be (web, topic, file attachment or unparseable) |
| =existAs= | resource types to test | =\@typelist= containing one\
 or more of 'web', 'topic', 'file' | if =string= is ambiguous, test (in\
 order) as each of the specified types. Default: =[qw(file topic)]= |
| =existHints= | exist hinting enable/disable | =$boolean= |\
 enable/disable hinting through web/topic/file existence checks.\
 =string= *is assumed to be using the 'unambiguous' conventions below*; if it\
 isn't, =catchAs= is used |
   
#UnambiguousStrings
---+++ Unambiguous strings

To build less ambiguous address strings, use the following conventions:
   * Terminate web addresses with '/'
   * Separate topics from webs with '.'
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
   the =existAs= types (default is 'file', 'topic')
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
| =Foo=              |              | 1           | set      | set     | topic, file |
| =Foo/Bar/=         |              |             |          |         | web              |
| =Foo/Bar=          |              |             |          |         | topic            |
| =Foo/Bar=          |              | 1           | set      |         | topic, file |
| =Foo.Bar=          |              |             |          |         | topic            |
| =Foo.Bar=          |              | 1           | set      | set     | topic, file |
| =Foo/Bar/Dog/=     |              |             |          |         | web              |
| =Foo/Bar/Dog=      |              | 1           |          |         | topic, file |
| =Foo.Bar/Dog=      | 0            |             |          |         | file |
| =Foo.Bar/Dog=      |              | 1           |          |         | topic, file |
| =Foo.Bar/D.g=      |              |             |          |         | file |
| =Foo/Bar.Dog=      |              |             |          |         | topic |
| =Foo/Bar.Dog=      |              | 1           | set      |         | topic, file |
| =Foo.Bar.Dog=      |              |             |          |         | topic |
| =Foo.Bar.Dog=      |              | 1           | set      | set     | topic, file |
| =Foo/Bar/Dog/Cat/= |              |             |          |         | web |
| =Foo/Bar.Dog.Cat=  |              |             |          |         | topic |
| =Foo/Bar.Dog.Cat=  |              | 1           | set      |         | topic, file |
| =Foo/Bar.Dog/Cat=  |              |             |          |         | file |
| =Foo/Bar.Dog/C.t=  |              |             |          |         | file |
| =Foo/Bar/Dog.Cat=  | 0            |             |          |         | topic |
| =Foo/Bar/Dog.Cat=  |              | 1           |          |         | topic, file |
| =Foo/Bar/Dog/Cat=  |              | 1           |          |         | topic, file |
| =Foo/Bar/Dog/C.t=  |              | 1           |          |         | topic, file |
| =Foo.Bar.Dog/Cat=  | 0            |             |          |         | file |
| =Foo.Bar.Dog/Cat=  |              | 1           |          |         | topic, file |
| =Foo.Bar.Dog/C.t=  |              |             |          |         | file |

=cut

sub parse {
    my ( $this, $path, %opts ) = @_;

    $this->_invalidate();
    if ( not $this->{parseopts} ) {
        $this->{parseopts} = {
            web         => $opts{web},
            webs        => $opts{webs},
            topic       => $opts{topic},
            rev         => $opts{rev},
            existAsList => [qw(file topic)],
            existAs     => { file => 1, topic => 1 }
        };
    }
    %opts = ( %{ $this->{parseopts} }, %opts );
    ASSERT( $opts{isA} or defined $opts{existAs} ) if DEBUG;
    $path =~ s/(\@([-\+]?\d+))$//;
    $this->{rev} = $2;

    # if necessary, populate webs from web parameter
    if ( not $opts{webs} and $opts{web} ) {
        $opts{webs} = [ split( /[\/\.]/, $opts{web} ) ];
    }

    # Because of the way we split, 'Foo/' causes final element to be empty
    if ( not $opts{webs}->[-1] ) {
        pop( @{ $opts{webs} } );
    }

    # pre-compute web's string form (avoid unnecessary join()s)
    if ( not $opts{web} and $opts{webs} ) {
        $opts{web} = join( '/', @{ $opts{webs} } );
    }

    # Is the path explicit?
    if ( not $opts{isA} ) {
        if ( substr( $path, -1, 1 ) eq '/' ) {
            $opts{isA} = 'web';
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

        ASSERT( $opts{existAsList} ) if DEBUG;

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
          . Dumper($plaus)
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
            # the most (out of the existAsList, Eg.: file, topic, web)
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
                      . Dumper( $typeatoms{$type} )
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
                    $this->{web}     = $typeatoms{$besttype}->{web};
                    $this->{webs}    = $typeatoms{$besttype}->{webs};
                    $this->{topic}   = $typeatoms{$besttype}->{topic};
                    $this->{part}    = $typeatoms{$besttype}->{part};
                    $this->{subpart} = $typeatoms{$besttype}->{subpart};
                    $parsed          = 1;
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

sub _atomiseAsWeb {
    my ( $this, $that, $path, $opts ) = @_;

    print STDERR "_atomiseAsWeb():\n" if TRACE2;
    $that->{web} = $path;
    $that->{webs} = [ split( /[\.\/]/, $path ) ];

    # If we had a path that looks like 'Foo/'
    if ( not $that->{webs}->[-1] ) {
        pop( @{ $that->{webs} } );
        chop( $that->{web} );
    }
    $that->{topic}   = undef;
    $that->{part}    = undef;
    $that->{subpart} = undef;

    return $that;
}

sub _atomiseAsTopic {
    my ( $this, $that, $path, $opts ) = @_;
    my @parts = split( /[\.\/]/, $path );
    my $nparts = scalar(@parts);

    print STDERR "_atomiseAsTopic(): path: $path, nparts: $nparts\n" if TRACE2;
    ASSERT($path) if DEBUG;
    if ( $nparts == 1 ) {
        if (    $opts->{webs}
            and ref( $opts->{webs} ) eq 'ARRAY'
            and scalar( @{ $opts->{webs} } ) )
        {
            $that->{web}   = $opts->{web};
            $that->{webs}  = $opts->{webs};
            $that->{topic} = $path;
        }
    }
    else {
        $that->{webs} = [ @parts[ 0 .. ( $nparts - 2 ) ] ];
        $that->{web} = undef;

        # $that->{web} = join( '/', @{ $that->{webs} } );
        $that->{topic} = $parts[-1];
    }
    $that->{part}    = undef;
    $that->{subpart} = undef;
    ASSERT( $that->{webs} or not $that->{topic} ) if DEBUG;

    # ASSERT( $that->{web} ) if DEBUG;

    return $that;
}

sub _atomiseAsFILE {
    my ( $this, $that, $path, $opts ) = @_;

    print STDERR "_atomiseAsFILE():\n" if TRACE2;
    ASSERT($path) if DEBUG;
    if ( my ( $lhs, $file ) = ( $path =~ /^(.*?)\/([^\/]+)$/ ) ) {
        $that = $this->_atomiseAsTopic( $that, $lhs, $opts );
        $that->{part}    = 'FILE';
        $that->{subpart} = $file;
    }
    else {
        if ( $opts->{webs} and $opts->{topic} ) {
            $that->{webs}    = $opts->{webs};
            $that->{web}     = $opts->{web};
            $that->{topic}   = $opts->{topic};
            $that->{part}    = 'FILE';
            $that->{subpart} = $path;
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

| *Form*                            | *part* | *subpart* | *type* |
| =META=                            | =META= |                               | meta       |
| =META:FIELD=                      | =META= | =['FIELD']=                     | metatype   |
| =META:FIELD[name='Colour']=       | =META= | =['FIELD', {name => 'Colour'}]= | metamember |
| =META:FIELD[3]=                   | =META= | =['FIELD', 3]=                  | metamember |
| =META:FIELD[name='Colour'].value= | =META= | =['FIELD', {name => 'Colour'}, 'value']= | metakey |
| =META:FIELD[3].value=             | =META= | =['FIELD', 3, 'value']=         | metakey |
| =fields=                          | =META= | =['FIELD']=                     | metatype   |
| =fields[name='Colour']=           | =META= | =['FIELD', {name => 'Colour'}]= | metamember |
| =fields[3]=                       | =META= | =['FIELD', 3]=                  | metamember |
| =fields[name='Colour'].value=     | =META= | =['FIELD', 3, 'value']=         | metakey |
| =MyForm=                          | =META= | =['FIELD', {form => 'MyForm'}]= | metatype |
| =MyForm[name='Colour']=           | =META= | =['FIELD', {form => 'MyForm', name => 'Colour'}]= | metamember |
| =MyForm[name='Colour'].value=     | =META= | =['FIELD', {form => 'MyForm', name => 'Colour'}, 'value']= | metakey |
| =MyForm.Colour=                   | =META= | =['FIELD', {form => 'MyForm', name => 'Colour'}, 'value']= | metakey |
| =Colour=                          | =META= | =['FIELD', {name => 'Colour'}, 'value']= | metakey |
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
        my $topic = $2;
        my @subpart;
        my $doneselector;
        my $doneaccessor;

        if ($3) {    # META:
            $that->{part} = 'META';
            push( @subpart, $4 );
            if ( not $5 and $14 ) {    # Eg. META:TOPICINFO.author
                push( @subpart, undef, $14 );
                $doneselector = 1;
                $doneaccessor = 1;
            }
        }
        elsif ( $parttypes{$4} ) {     # META, FILE, SECTION, text
            $that->{part} = $4;
        }
        elsif ( $Foswiki::Meta::aliases{$4} ) {    # fields, attachments, info
            $that->{part} = 'META';

            # strip off the 'META:' part
            push( @subpart, substr( $Foswiki::Meta::aliases{$4}, 5 ) );
            if ( not $5 and $14 ) {                # Eg. info.author
                push( @subpart, undef, $14 );
                $doneselector = 1;
                $doneaccessor = 1;
            }
        }
        elsif ($4) {    # SomeFormField or SomethingForm
            $that->{part} = 'META';
            push( @subpart, 'FIELD' );
            if ( not( $14 or $6 ) ) {    # SomeFormField
                    # SMELL: This catches "'Web.Topic@123'/MyForm" & "MyForm"
                push( @subpart, { name => $4 }, 'value' );
                $doneselector = 1;
                $doneaccessor = 1;
            }
            elsif ( substr( $4, -4, 4 ) eq 'Form' ) {    # SomethingForm
                push( @subpart, { form => $4 } );
                if ($8) {                                # SomethingForm[a=b
                    ASSERT( defined $9 ) if DEBUG;
                    $subpart[-1]->{$8} = $9;
                    if ($11) {    # SomethingForm[a=b AND c=d]
                        ASSERT( defined $12 ) if DEBUG;
                        $subpart[-1]->{$11} = $12;
                    }
                    $doneselector = 1;
                }
                elsif ($6) {      # SomethingForm[n]
                    push( @subpart, $6 );
                    $doneselector = 1;
                    ASSERT( $6 =~ /^\d+$/ ) if DEBUG;
                }
                elsif ($14) {
                    $subpart[-1]->{name} = $14;
                    push( @subpart, 'value' );
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
                push( @subpart, { $8 => $9 } );
                if ($11) {                   # SOMETHING[a=b AND c=d]
                    ASSERT( defined $12 ) if DEBUG;
                    $subpart[-1]->{$11} = $12;
                }
            }
            else {                           # SOMETHING[n]
                ASSERT($6) if DEBUG;
                push( @subpart, $6 );
                ASSERT( $6 =~ /^\d+$/ ) if DEBUG;
            }
            $doneselector = 1;
        }
        if ( not $doneaccessor and $14 ) {
            push( @subpart, $14 );
        }
        if ( scalar(@subpart) ) {
            ASSERT( $that->{part} ) if DEBUG;
            $that->{subpart} = \@subpart;
        }
        if ($topic) {
            my $refAddr = Foswiki::Address->new(
                string => $topic,
                isA    => 'topic',
                webs   => $opts->{webs},
                web    => $opts->{web}
            );

            $that->{web}   = $refAddr->{web};
            $that->{webs}  = $refAddr->{webs};
            $that->{topic} = $refAddr->{topic};
            $that->{rev}   = $refAddr->{rev};
        }
        else {
            $that->{webs}  = $opts->{webs};
            $that->{topic} = $opts->{topic};
            $that->{rev}   = undef;
            ASSERT( $that->{webs} )  if DEBUG;
            ASSERT( $that->{topic} ) if DEBUG;
        }
    }

    return $that;
}

sub _existScore {
    my ( $this, $atoms, $type ) = @_;
    my $score;
    my $perfecttype;

    if (
            $atoms->{part}
        and $atoms->{part} eq 'FILE'
        and Foswiki::Func::attachmentExists(
            $atoms->{web}, $atoms->{topic}, $atoms->{subpart}
        )
      )
    {
        $perfecttype = $type;
        $score       = 2 + scalar( @{ $atoms->{webs} } );
    }
    elsif ( $atoms->{topic}
        and Foswiki::Func::topicExists( $atoms->{web}, $atoms->{topic} ) )
    {
        if ( $type eq 'topic' ) {
            $perfecttype = $type;
        }
        $score = 1 + scalar( @{ $atoms->{webs} } );
    }
    elsif ( $atoms->{web} and Foswiki::Func::webExists( $atoms->{web} ) ) {
        if ( $type eq 'web' ) {
            $perfecttype = $type;
        }
        $score = scalar( @{ $atoms->{webs} } );
    }
    elsif ( $atoms->{webs} ) {
        ASSERT( scalar( @{ $atoms->{webs} } ) ) if DEBUG;
        ASSERT( ref( $atoms->{webs} ) eq 'ARRAY' ) if DEBUG;
        my $i      = scalar( @{ $atoms->{webs} } );
        my $nAtoms = scalar( @{ $atoms->{webs} } );

        while ( $i > 0 and not $score ) {
            $i -= 1;
            if (
                Foswiki::Func::webExists(
                    join( '/', @{ $atoms->{webs} }[ 0 .. $i ] )
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

    # If there's a valid address; and check that we haven't already computed
    # the stringification before with the same opts
    if (
        $this->isValid()
        and (
            not $this->{stringified}
            or (    $opts{webseparator}
                and $opts{webseparator} ne $this->{stringifiedwebsep} )
            or (    $opts{topicseparator}
                and $opts{topicseparator} ne $this->{stringifiedtopicsep} )
        )
      )
    {
        $this->{stringifiedwebsep} = $opts{webseparator}
          || '/';
        $this->{stringifiedtopicsep} = $opts{topicseparator}
          || '.';
        $this->{stringified} =
          join( $this->{stringifiedwebsep}, @{ $this->{webs} } );
        if ( $this->{topic} ) {
            $this->{stringified} .=
              $this->{stringifiedtopicsep} . $this->{topic};
            if ( $this->{part} ) {
                if ( $this->{part} eq 'FILE' and $this->{subpart} ) {
                    ASSERT( $this->{subpart} and not ref( $this->{subpart} ) )
                      if DEBUG;
                    $this->{stringified} .= '/' . $this->{subpart};
                    if ( defined $this->{rev} ) {
                        $this->{stringified} .= '@' . $this->{rev};
                    }
                }
                else {
                    if ( defined $this->{rev} ) {
                        $this->{stringified} .= '@' . $this->{rev};
                    }
                    $this->{stringified} =
                      '\'' . $this->{stringified} . '\'/' . $this->{part};
                    if ( $this->{subpart} ) {
                        my @subpart;

                        if ( ref( $this->{subpart} ) eq 'HASH' ) {
                            @subpart = ( $this->{subpart} );
                        }
                        else {
                            ASSERT( ref( $this->{subpart} ) eq 'ARRAY' )
                              if DEBUG;
                            @subpart = @{ $this->{subpart} };
                        }

                        if ( $this->{part} eq 'META' and scalar(@subpart) ) {
                            $this->{stringified} .= ':' . shift(@subpart);
                        }
                        if ( scalar(@subpart) ) {
                            if ( defined $subpart[0] ) {
                                $this->{stringified} .= '[';
                                if ( ref( $subpart[0] ) eq 'HASH' ) {
                                    my @selectorparts;
                                    while ( my ( $key, $value ) =
                                        each %{ $subpart[0] } )
                                    {
                                        push( @selectorparts,
                                            $key . '=\'' . $value . '\'' );
                                    }
                                    $this->{stringified} .=
                                      join( ' AND ', @selectorparts );
                                    shift(@subpart);
                                }
                                else {
                                    ASSERT( $subpart[0] =~ /^\d+$/ ) if DEBUG;
                                    $this->{stringified} .= shift(@subpart);
                                }
                                $this->{stringified} .= ']';
                            }
                            else {
                                shift @subpart;
                            }
                            if ( scalar(@subpart) ) {
                                ASSERT( scalar(@subpart) == 1 ) if DEBUG;
                                $this->{stringified} .= '.' . shift(@subpart);
                            }
                        }
                        ASSERT( not scalar(@subpart) ) if DEBUG;
                    }
                }
            }
            elsif ( defined $this->{rev} ) {
                $this->{stringified} .= '@' . $this->{rev};
            }
        }
        else {
            ASSERT( $this->{webs} );
            $this->{stringified} .= $this->{stringifiedwebsep};
        }
    }
    print STDERR "stringify(): $this->{stringified}\n" if TRACE2;

    return $this->{stringified};
}

=begin TML

---++ ClassMethod web( [$name] ) => $name

   * =$name= - optional, set a new web name

Get/set by web string

=cut

sub web {
    my ( $this, $web ) = @_;

    if ( scalar(@_) == 2 ) {
        $this->webs( [ split( /[\/\.]/, $web ) ] );
    }
    if ( not $this->{web} ) {
        $this->{web} = join( '/', @{ $this->{webs} } );
    }

    return $this->{web};
}

=begin TML

---++ ClassMethod webs( [\@webs] ) => \@webs

   * =\@webs= - optional, set a new webs arrayref

Get/set the webs arrayref

=cut

sub webs {
    my ( $this, $webs ) = @_;

    if ( scalar(@_) == 2 ) {
        $this->{webs} = $webs;
        $this->_invalidate();
    }

    return $this->{webs};
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

---++ ClassMethod file( [$name] ) => $name

   * =$name= - optional, set a new file name

Get/set the file name

=cut

sub file {
    my ( $this, $file ) = @_;

    if ( scalar(@_) == 2 ) {
        $this->{part}    = 'FILE';
        $this->{subpart} = $file;
        $this->_invalidate();
        ASSERT( $this->isValid() ) if DEBUG;
    }
    else {
        $this->isValid();
    }

    return $this->{subpart};
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

---++ ClassMethod part( [$name] ) => $name

   * =$name= - optional, set the topic part - one of: FILE, META, SECTION, text

Get/set the part name

=cut

sub part {
    my ( $this, $name ) = @_;

    if ( scalar(@_) == 2 ) {
        $this->{part} = $name;
        $this->_invalidate();
    }
    else {
        $this->isValid();
    }

    return $this->{part};
}

=begin TML

---++ ClassMethod subpart( [$subpart] ) => $subpart

   * =$subpart= - optional, =subpart= specification into the containing topic
   =part=.
      * =FILE= parts: =$subpart= is a string, Eg. ='Attachment.pdf'=.
      * =META= parts: =$subpart= is an array reference, Eg.
      =['FIELD', {name => 'Colour'}, 'value']=
      * =SECTION= parts: =$subpart= is a hash reference, Eg.
      =[{name => 'mysection', type => 'include'}]=
      * =text= part: does not support =$subpart= at this time.

Get/set the subpart

=cut

sub subpart {
    my ( $this, $subpart ) = @_;

    if ( scalar(@_) == 2 ) {
        $this->{subpart} = $subpart;
        $this->_invalidate();
        ASSERT(
                 not defined $subpart
              or not ref($subpart)
              or scalar( @{$subpart} )
        ) if DEBUG;
        ASSERT( $this->{part} or not $this->{subpart} ) if DEBUG;
    }
    else {
        $this->isValid();
    }

    return $this->{subpart};
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

---++ ClassMethod isValid() => $boolean

Returns true if the instance addresses a resource which is one of the following
types:
   * webs, Eg. =Web/SubWeb/=
   * topic, Eg. =Web/SubWeb.Topic=
   * file, Eg. =Web/SubWeb.Topic/Attachment.pdf=
   * files, Eg. ='Web/SubWeb.Topic/FILE'=
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
        if ( $this->{topic} ) {
            if ( $this->{webs} ) {
                if ( $this->{part} ) {
                    ASSERT( $parttypes{ $this->{part} } ) if DEBUG;
                    ASSERT(
                             not defined $this->{subpart}
                          or not ref( $this->{subpart} ) eq 'ARRAY'
                          or scalar( @{ $this->{subpart} } )
                    ) if DEBUG;
                    ASSERT(
                             not defined $this->{subpart}
                          or not ref( $this->{subpart} ) eq 'HASH'
                          or scalar( keys %{ $this->{subpart} } )
                    ) if DEBUG;
                    $this->{type} = $parttypes{ $this->{part} }->{
                        defined $this->{subpart}
                        ? (
                            ref( $this->{subpart} ) eq 'ARRAY'
                            ? scalar( @{ $this->{subpart} } )
                            : 1
                          )
                        : 0
                      };
                }
                elsif ( not defined $this->{subpart} ) {
                    $this->{type} = 'topic';
                }
            }
        }
        elsif ( $this->{webs}
            and not( $this->{part} or defined $this->{subpart} ) )
        {
            $this->{type} = 'webs';
        }
        else {
            $this->{type} = undef;
        }
        if ( $this->{type} ) {
            $this->{isA} = { $this->{type} => 1 };
        }
        else {
            $this->{isA} = {};
        }
    }

    return $this->{type};
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
    my $nWebs;
    my $equal     = 0;
    my $thistype  = $this->type();
    my $othertype = $other->type();

    # Same type?
    if ( $thistype and $othertype and $thistype eq $othertype ) {
        ASSERT(
            ( not $this->{part} and not $other->{part} )
              or (  $this->{part}
                and $other->{part}
                and $this->{part} eq $other->{part} )
        ) if DEBUG;
        if ( $this->{webs} ) {
            $nWebs = scalar( @{ $this->{webs} } );

            # Do the web paths have equal number of elements?
            if ( $nWebs == scalar( @{ $other->{webs} } ) ) {
                my $i = 0;
                $equal = 1;

                # Are the web path elements equal?
                while ( $equal and $i < $nWebs ) {
                    ASSERT( $this->{webs}->[$i] and $other->{webs}->[$i] )
                      if DEBUG;
                    if ( $this->{webs}->[$i] ne $other->{webs}->[$i] ) {
                        $equal = 0;
                        print STDERR "equiv(): web paths not equal\n" if TRACE;
                    }
                    else {
                        $i += 1;
                    }
                }

                # And the subparts?
                if ($equal) {
                    if ( ref( $other->{subpart} ) eq ref( $this->{subpart} ) ) {
                        if ( ref( $this->{subpart} ) eq 'ARRAY' ) {
                            my $nsubparts = scalar( @{ $this->{subpart} } );
                            ASSERT( ref( $other->{subpart} ) eq 'ARRAY' )
                              if DEBUG;
                            ASSERT(
                                scalar( @{ $other->{subpart} } ) == $nsubparts )
                              if DEBUG;

                            $i = 0;
                            while ( $equal and $i < $nsubparts ) {
                                if ( ref( $this->{subpart}->[$i] ) eq 'HASH' ) {
                                    my @subkeys =
                                      keys %{ $this->{subpart}->[$i] };
                                    my $nsubkeys = scalar(@subkeys);
                                    my $s        = 0;

                                    while ( $equal and $s < $nsubkeys ) {
                                        if ( $this->{subpart}->[$i]
                                            ->{ $subkeys[$s] } ne
                                            $other->{subpart}->[$i]
                                            ->{ $subkeys[$s] } )
                                        {
                                            $equal = 0;
                                            print STDERR
"equiv(): subpart[$i] as hashref: different $subkeys[$s] keys\n"
                                              if TRACE;
                                        }
                                        $s += 1;
                                    }
                                }
                                else {
                                    if (    $this->{subpart}->[$i]
                                        and $other->{subpart}->[$i]
                                        and $this->{subpart}->[$i] ne
                                        $other->{subpart}->[$i] )
                                    {
                                        $equal = 0;
                                        print STDERR
"equiv(): subpart[$i] different values\n"
                                          if TRACE;
                                    }
                                }
                                $i += 1;
                            }
                        }
                        elsif ( ref( $this->{subpart} ) eq 'HASH' ) {
                            my @subkeys  = keys %{ $this->{subpart} };
                            my $nsubkeys = scalar(@subkeys);
                            my $s        = 0;

                            ASSERT( ref( $other->{subpart} ) eq 'HASH' )
                              if DEBUG;
                            $s = 0;
                            while ( $equal and $s < $nsubkeys ) {
                                if ( $this->{subpart}->{ $subkeys[$s] } ne
                                    $other->{subpart}->{ $subkeys[$s] } )
                                {
                                    $equal = 0;
                                    print STDERR
"equiv(): subpart{$subkeys[$s]} different values\n"
                                      if TRACE;
                                }
                                $s += 1;
                            }
                        }
                        elsif ( defined $this->{subpart} ) {
                            ASSERT( defined $other->{subpart} ) if DEBUG;
                            if ( $this->{subpart} ne $other->{subpart} ) {
                                $equal = 0;
                                print STDERR
                                  "equiv(): subpart different values\n"
                                  if TRACE;
                            }
                        }
                    }
                    else {
                        $equal = 0;
                    }
                }
            }
            elsif (TRACE) {
                print STDERR "equiv(): web paths different sizes\n";
            }
        }
        elsif (TRACE) {
            print STDERR "equiv(): webs empty\n";
        }
    }
    elsif (TRACE) {
        print STDERR "equiv(): types were not equal\n";
    }
    if ( not $equal ) {
        print STDERR "equiv(): NOT equal "
          . Dumper($this) . " vs "
          . Dumper($other) . "\n"
          if TRACE;
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
