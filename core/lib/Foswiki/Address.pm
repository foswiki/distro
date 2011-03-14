# See bottom of file for license and copyright information

package Foswiki::Address;

=begin TML

---+ package Foswiki::Address

Instances represent a pointer (address) to a web, topic or attachment (and
other topic atoms), optionally of a specific revision.

A primary goal of =Foswiki::Address= is to make instantiation cheap (compared to
=Foswiki::Meta=).

Fundamentally, the concept of a =Foswiki::Address= instance is centred on a hash
of the components required to address a specific Foswiki resource. Hashes such
as the following may be replaced with =Foswiki::Address= objects:

<verbatim>
my $addr = {
    webs => [qw(Web SubWeb)],
    topic => 'Topic',
    attachment => 'Attachment',
    rev => 3
};
</verbatim>

This class provides functionality necessary to hold, manipulate, test, and
de/serialise addresses only. It will not have any interaction with the store or
=Foswiki::Meta= (except to obtain hints if parsing ambiguous address strings).

=cut

use strict;
use warnings;

use Assert;
use Foswiki::Func();
use Foswiki::Meta();

#use Data::Dumper;
use constant TRACE => 0;    # Don't forget to uncomment dumper

my @addressparts;
my $naddressparts;
my %plausibletable;
my %sepidentchars;
my %formregexes;
my %atommap;

BEGIN {

    # NOTE: equiv() assumes web is the first element!
    @addressparts =
      qw(webs topic attachment rev meta metamember metamemberkey metakey);
    $naddressparts = scalar(@addressparts);
    %atommap       = (
        web           => \&_atomiseAsWeb,
        topic         => \&_atomiseAsTopic,
        attachment    => \&_atomiseAsAttachment,
        meta          => \&_atomiseAsMeta,
        metamember    => \&_atomiseAsMeta,
        metamemberkey => \&_atomiseAsMeta,
        metakey       => \&_atomiseAsMeta
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
        '' => { webs => 1, topic => 'webs', attachment => 'topic' },

        # Foo.Bar
        'd' => { webs => 1, topic => 2, attachment => 'topic' },

        # Foo/Bar
        's' => { webs => 1, topic => 1, attachment => 'webs' },

        # Foo/Bar.Dog
        'sd' => { webs => 0, topic => 2, attachment => 'webs' },

        # Foo.Bar/Dog
        'ds' => { webs => 0, topic => 1, attachment => 2 },

        # Foo/Bar/Dog
        'S' => { webs => 1, topic => 1, attachment => 1 },

        # Foo.Bar.Dog
        'D' => { webs => 1, topic => 1, attachment => 'topic' },

        # Foo.Bar/Cat/Dog
        'dS' => { webs => 0, topic => 1, attachment => 1 },

        # Foo/Bar.Cat.Dog
        'sD' => { webs => 0, topic => 0, attachment => 'webs' },

        # Foo/Bar/Dog.Cat
        'Sd' => { webs => 0, topic => 2, attachment => 1 },

        # Foo.Bar.Dog/Cat
        'Ds' => { webs => 0, topic => 1, attachment => 1 },

        # Foo.Bar.Dog/Cat/Bat
        'DS' => { webs => 0, topic => 0, attachment => 1 },

        # Foo/Bar/Dog.Cat.Bat
        'SD' => { webs => 0, topic => 0, attachment => 1 },

        # Foo/Bar.Dog/Cat
        'sds' => { webs => 0, topic => 0, attachment => 2 },

        # Foo/Bar/Dog.Cat/Bat
        'Sds' => { webs => 0, topic => 0, attachment => 2 },

        # Foo.Bar/Dog.Cat
        'dsd' => { webs => 0, topic => 0, attachment => 2 },

        # Foo.Bar.Dog/Cat.Bat
        'Dsd' => { webs => 0, topic => 0, attachment => 1 },

        # Foo.Bar/Dog.Cat.Bat
        'dsD' => { webs => 0, topic => 0, attachment => 2 },

        # Foo/Bar.Dog/Cat.Bat
        'sdsd' => { webs => 0, topic => 0, attachment => 2 },

        # Foo/Bar.Dog/Cat.B.a.t
        'sdsD' => { webs => 0, topic => 0, attachment => 2 },

        # Foo/Bar/Dog.Cat/B.at
        'Sdsd' => { webs => 0, topic => 0, attachment => 2 },

        # Foo/Bar/Dog.Cat/B.a.t
        'SdsD' => { webs => 0, topic => 0, attachment => 2 }
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
    attachment => 'Attachment',
    rev => 3
);</verbatim>

*Options:*
| *Param*         | *Description* | *Notes* |
| =web=           | =$string= of web path, %BR% used if =webs= is empty/null | |
| =webs=          | =\@arrayref= of web path, root web first | |
| =topic=         | =$string= topic name | |
| =attachment=    | =$string= attachment name | |
| =rev=           | =$integer= revision number | |
| =meta=      | =$string= META type, Eg. =FIELD= | |
| =metamember=     | =$integer= (array index) or =$value= (key-value lookup) selector | For array META types. See =Foswiki::Func::registerMETA(... many => 1)= |
| =metamemberkey=  | =$string= key name for key-value META selection | Defaults to 'name' for non-numeric =metamember= |
| =metakey=       | =$string= key name, Eg. =value= | on an individual META member |

*Example:* Point to the value of a formfield =LastName= in =Web/SubWeb.Topic=,
<verbatim>
my $addrObj = Foswiki::Address->new(
  webs => [qw(Web SubWeb)],
  topic => 'Topic',
  attachment => 'Attachment',
  meta => 'FIELD',
  metamember => 'LastName',
  metamemberkey => 'name',
  metakey => 'value'
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
    string => 'Web/SubWeb.Topic/Attachment@3',
    %opts
);</verbatim>

<blockquote class="foswikiHelp">%X% String form instantiation requires parsing
of the address string which comes with many options and caveats - refer to the
documentation for =parse()=.</blockquote>

=cut

sub new {
    my ( $class, %opts ) = @_;
    my $this;

    # 'Web/SubWeb' vs [qw(Web SubWeb)] (supplied as web vs webs): if the latter
    # is absent, derive it from the former (supplied as web vs webs)
    if ( not $opts{webs} and $opts{web} ) {
        $opts{webs} = [ split( /[\/\.]/, $opts{web} ) ];

        # The final element is empty if we have 'Web/'
        if ( not $opts{webs}->[-1] ) {
            pop( @{ $opts{webs} } );
        }
    }
    if ( $opts{string} ) {
        ASSERT( not $opts{topic} or ( $opts{webs} and $opts{topic} ) ) if DEBUG;
        $this->{parseopts} = {
            web           => $opts{web},
            webs          => $opts{webs},
            topic         => $opts{topic},
            attachment    => $opts{attachment},
            rev           => $opts{rev},
            meta          => $opts{meta},
            metamember    => $opts{metamember},
            metamemberkey => $opts{metamemberkey},
            metakey       => $opts{metakey},
            isA           => $opts{isA},
            existAs       => undef,
            catchAs       => $opts{catchAs},
            existHints    => $opts{existHints},
            string        => $opts{string}
        };

        # transpose the existAs array into hash keys
        if ( $opts{existAs} ) {
            ASSERT( ref( $opts{existAs} ) eq 'ARRAY' ) if DEBUG;
            ASSERT( scalar( @{ $opts{existAs} } ) ) if DEBUG;
            $this->{parseopts}->{existAsList} = $opts{existAs};
            %{ $this->{parseopts}->{existAs} } =
              map { $_ => 1 } @{ $opts{existAs} };
        }
        elsif ( not $opts{isA} ) {
            $this->{parseopts}->{existAsList} = [qw(attachment topic)];
            $this->{parseopts}->{existAs} = { attachment => 1, topic => 1 };
        }
        if ( not defined $this->{parseopts}->{existHints} ) {
            $this->{parseopts}->{existHints} = 1;
        }
        $this = bless( $this, $class );
        $this->parse( $opts{string} );
    }
    else {
        $this = {
            webs          => $opts{webs},
            topic         => $opts{topic},
            attachment    => $opts{attachment},
            rev           => $opts{rev},
            meta          => $opts{meta},
            metamember    => $opts{metamember},
            metamemberkey => $opts{metamemberkey},
            metakey       => $opts{metakey}
        };
        $this = bless( $this, $class );
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
    $this->{attachment}          = undef;
    $this->{rev}                 = undef;
    $this->{meta}                = undef;
    $this->{metamember}          = undef;
    $this->{metamemberkey}       = undef;
    $this->{metakey}             = undef;
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
 'attachment' | parse =string= to resolve to the specified type; exist hinting\
 is skipped |
| =catchAs= | default resource type | =$type= - 'web', 'topic', 'attachment', 'none' |\
 if =string= is ambiguous AND (exist hinting fails OR is disabled), THEN\
 assume =string= to be (web, topic, attachment or unparseable) |
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
   * Separate topics from webs with '.'
   * Separate attachments from topics with '/'
Examples:
   * =Web/SubWeb/=, =Web/=
   * =Web/SubWeb.Topic=
   * =Web.Topic/Attachment= 
   * =Web/SubWeb.Topic/Attachment=

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

    $this->_invalidate();
    %opts = ( %{ $this->{parseopts} }, %opts );
    $path =~ s/(\@([-\+]?\d+))$//;
    $this->{rev} = $2;
    ASSERT( defined $opts{existHints} ) if DEBUG;
    ASSERT( defined $opts{existAs} )    if DEBUG;

    # if necessary, populate webs from web parameter
    if ( not $opts{webs} and $opts{web} ) {
        $opts{webs} = [ split( /[\/\.]/, $opts{web} ) ];

        # Because of the way we split, 'Foo/' causes final element to be empty
        if ( not $opts{webs}->[-1] ) {
            pop( @{ $opts{webs} } );
        }
    }

    # pre-compute web's string form (avoid unnecessary join()s)
    if ( not $opts{web} and $opts{webs} ) {
        $opts{web} = join( '/', @{ $opts{webs} } );
    }

    # Is the path explicit?
    if ( not $opts{isA} ) {
        if ( $opts{existAs}->{web} and substr( $path, -1, 1 ) eq '/' ) {
            $opts{isA} = 'web';
        }
        elsif (
            (
                   $opts{existAs}->{meta}
                or $opts{existAs}->{metamember}
                or $opts{existAs}->{metakey}
            )
            and ( substr( $path, 0, 1 ) eq '\'' or $path =~ /.+\[.+\]/ )
          )
        {
            $opts{isA} = 'meta';
        }
    }

    # Here we go... short-circuit testing if we already have an isA spec
    if ( $opts{isA} ) {
        $this->_atomiseAs( $this, $path, $opts{isA}, \%opts );
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
        $plaus = $plausibletable{$sepident};
        print "Identity\t$sepident calculated for $path, plaustable: "
          . Dumper($plaus)
          if TRACE;

        # Is the identity known?
        if ($plaus) {

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
                    if ( $plaus->{$type} == 2 ) {
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
            # the most (out of web, topic, attachment) wins. The former should
            # naturally fall out of the latter, unless the existAs list is not
            # ordered smallestthing-first (Eg. attachment, topic, web).
            if ( $opts{existHints} ) {
                my $i        = 0;
                my $ntrylist = scalar(@trylist);
                my $besttype;

                # If a complete hit is detected, we set $besttype & exit early
                while ( $ntrylist > $i and not $besttype ) {
                    my $score;
                    my $type = $trylist[$i];

                    $i += 1;
                    $typeatoms{$type} =
                      $this->_atomiseAs( {}, $path, $type, \%opts );
                    print "Atomised $path as $type, result: "
                      . Dumper( $typeatoms{$type} )
                      if TRACE;
                    ( $besttype, $score ) =
                      $this->_existScore( $typeatoms{$type}, $type );
                    print "existScore: $score, besttype: $besttype\n" if TRACE;
                    if ( $score and not defined $typescores{$score} ) {
                        $typescores{$score} = $type;
                    }
                }

                # Unless we already got a perfect hit; find the type for this
                # path that gives the highest score
                if ( not $besttype ) {
                    my $bestscore = 3;

                    while ( 0 < $bestscore and not $typescores{$bestscore} ) {
                        $bestscore -= 1;
                    }
                    $besttype = $typescores{$bestscore};
                }

                # Copy the atoms from the best hit into our instance.
                if ($besttype) {
                    my $rev = $this->{rev};

                    foreach my $part (@addressparts) {
                        $this->{$part} = $typeatoms{$besttype}->{$part};
                    }
                    $this->{rev} = $rev;
                    $parsed = 1;
                }
            }
        }
        if ( not $parsed ) {
            my $type = $normalform || $opts{catchAs};

            if ($type) {
                $this->_atomiseAs( $this, $path, $type, \%opts );
            }
        }
    }

    return $this->isValid();
}

sub _atomiseAs {
    my ( $this, $that, $path, $type, $opts ) = @_;

    ASSERT($path)             if DEBUG;
    ASSERT($type)             if DEBUG;
    ASSERT( $atommap{$type} ) if DEBUG;
    $atommap{$type}->( $this, $that, $path, $opts );

    return $that;
}

sub _atomiseAsWeb {
    my ( $this, $that, $path, $opts ) = @_;
    my $rev = $that->{rev};

    $that->{web} = $path;
    $that->{webs} = [ split( /[\.\/]/, $path ) ];

    # If we had a path that looks like 'Foo/'
    if ( not $that->{webs}->[-1] ) {
        pop( @{ $that->{webs} } );
        chop( $that->{web} );
    }
    foreach my $part ( @addressparts[ 1 .. ( $naddressparts - 1 ) ] ) {
        $that->{$part} = undef;
    }
    $that->{rev} = $rev;

    return $that;
}

sub _atomiseAsTopic {
    my ( $this, $that, $path, $opts ) = @_;
    my @parts  = split( /[\.\/]/, $path );
    my $nparts = scalar(@parts);
    my $rev    = $that->{rev};

    ASSERT($path) if DEBUG;
    if ( $nparts == 1 ) {
        if ( $opts->{webs} ) {
            $that->{web}   = $opts->{web};
            $that->{webs}  = $opts->{webs};
            $that->{topic} = $path;
        }
    }
    else {
        $that->{webs} = [ @parts[ 0 .. ( $nparts - 2 ) ] ];
        $that->{web} = join( '/', @{ $that->{webs} } );
        $that->{topic} = $parts[-1];
    }
    foreach my $part ( @addressparts[ 2 .. ( $naddressparts - 1 ) ] ) {
        $that->{$part} = undef;
    }
    $that->{rev} = $rev;
    ASSERT( $that->{webs} and $that->{web} ) if DEBUG;

    return $that;
}

sub _atomiseAsAttachment {
    my ( $this, $that, $path, $opts ) = @_;
    my $rev = $that->{rev};

    if ( my ( $lhs, $attachment ) = ( $path =~ /^(.*?)\/([^\/]+)$/ ) ) {
        $that = $this->_atomiseAsTopic( $that, $lhs, $opts );
        $that->{attachment} = $attachment;
    }
    else {
        if ( $opts->{webs} and $opts->{topic} ) {
            $that->{web}        = $opts->{web};
            $that->{webs}       = $opts->{webs};
            $that->{topic}      = $opts->{topic};
            $that->{attachment} = $path;
        }
    }
    foreach my $part ( @addressparts[ 3 .. ( $naddressparts - 1 ) ] ) {
        $that->{$part} = undef;
    }
    $that->{rev} = $rev;

    return $that;
}

=begin TML

---++ PRIVATE ClassMethod _atomiseAsMeta ( $that, $path, $opts ) => $that

Parse a small subset ('static' meta path forms) of QuerySearch (VarQUERY)
compatible expressions.

=$opts= is a hashref holding default context

'topic'/ ref part is optional; =_atomiseAsMeta()= falls-back to default topic
context supplied in =$opts= otherwise. In other words, both of these forms are
supported:
   * ='Web/SubWeb.Topic@3'/META:FIELD[name='Colour'].value=
   * =META:FIELD[name='Colour'].value=

| *Form* | *Type* |
| =META:FIELD= | meta |
| =META:FIELD[name='Colour']= | metamember & metamemberkey='name' |
| =META:FIELD[3]= | metamember |
| =META:FIELD[name='Colour'].value= | metakey |
| =META:FIELD[3].value= | metakey |
| =fields= | meta |
| =fields[name='Colour']= | metamember & metamemberkey='name' |
| =fields[3]= | metamember |
| =fields[name='Colour'].value= | metakey |
| =Colour= | metakey <blockquote class="foswikiHelp">%X% \
  Shortcut to ==META:FIELD[name='Colour'].value== - which \
  is *not* necessarily the same result which Foswiki's \
  =QueryAlgorithm->getField()= would produce! =Foswiki::Address= does not \
  support accessing fields via their form name.</verbatim> |
=cut

sub _atomiseAsMeta {
    my ( $this, $that, $path, $opts ) = @_;

    # QuerySearch meta path?
    if (
        $path =~ /^
        (                              #  1
            '([^']+)'                  #  2 'Web.Topic@123'
            \s*\/\s*
        )?
        (                              #  3
            (                          #  4
                (META:)?               #  5
                ([^\.\[]+?)\s*         #  6 FIELD, fields, etc.
                (                      #  7
                    (\[\s*             #  8
                        (              #  
                            [-\+]?\d+  #  9 [n], or
                            |([^=\s]+) # 10 [name
                            \s*=\s*    #    =
                            '([^']+)'  # 11 'foo']
                        )
                    \s*\])
                    (\s*\.\s*          # 12
                        (\w+)          # 13 .value
                    )?
                )?
            )
            | (\w+)                   # 14 Eg., ColourField
        )?$/x
      )
    {
        my $topic;
        my $metaindex;

        if ($14) {
            (
                $topic, $that->{meta}, $metaindex, $that->{metamemberkey},
                $that->{metamember}, $that->{metakey}
            ) = ( $2, 'FIELD', undef, 'name', $14, 'value' );
        }
        elsif ($3) {
            (
                $topic, $that->{meta}, $metaindex, $that->{metamemberkey},
                $that->{metamember}, $that->{metakey}
            ) = ( $2, $6, $9, $10, $11, $13 );
            if ( not $5 ) {
                if ( $Foswiki::Meta::aliases{ $that->{meta} } ) {
                    $that->{meta} = $Foswiki::Meta::aliases{ $that->{meta} };

                    # $that->{meta} =~ s/^META://;
                    $that->{meta} = substr( $that->{meta}, 5 );
                }
                else {
                    $that->{meta}          = 'FIELD';
                    $that->{metamember}    = $6;
                    $that->{metamemberkey} = 'name';
                    $that->{metakey}       = 'value';
                }
            }
            if ( not $that->{metamember} ) {
                $that->{metamember} = $metaindex;
            }
        }
        if ($topic) {
            my $refAddr = Foswiki::Address->new(
                string  => $topic,
                isA     => 'topic',
                existAs => ['topic'],
                webs    => $opts->{webs},
                web     => $opts->{web}
            );

            $that->{web}   = $refAddr->{web};
            $that->{webs}  = $refAddr->{webs};
            $that->{topic} = $refAddr->{topic};
            $that->{rev}   = $refAddr->{rev};
        }
        else {
            $that->{webs}  = $opts->{webs};
            $that->{topic} = $opts->{topic};
        }
    }

    return $that;
}

sub _existScore {
    my ( $this, $atoms, $type ) = @_;
    my $score;
    my $perfecttype;

    if (
        $atoms->{attachment}
        and Foswiki::Func::attachmentExists(
            $atoms->{web}, $atoms->{topic}, $atoms->{attachment}
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
            if ( $this->{attachment} ) {
                $this->{stringified} .= '/' . $this->{attachment};
            }
            if ( $this->{rev} ) {
                $this->{stringified} .= '@' . $this->{rev};
            }
            if ( $this->{meta} ) {
                $this->{stringified} =
                  '\'' . $this->{stringified} . '\'/META:' . $this->{meta};
                if ( $this->{metamemberkey} ) {
                    $this->{stringified} .= '['
                      . $this->{metamemberkey} . '=\''
                      . $this->{metamember} . '\']';
                }
                elsif ( $this->{metamember} ) {
                    $this->{stringified} .= '[' . $this->{metamember} . ']';
                }
                if ( $this->{metakey} ) {
                    $this->{stringified} .= '.' . $this->{metakey};
                }
            }
        }
        else {
            ASSERT( $this->{webs} );
            $this->{stringified} .= $this->{stringifiedwebsep};
        }
    }

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
    }
    else {
        $this->isValid();
    }

    return $this->{topic};
}

=begin TML

---++ ClassMethod attachment( [$name] ) => $name

   * =$name= - optional, set a new attachment name

Get/set the attachment name

=cut

sub attachment {
    my ( $this, $attachment ) = @_;

    if ( scalar(@_) == 2 ) {
        $this->{attachment} = $attachment;
        $this->_invalidate();
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
    }
    else {
        $this->isValid();
    }

    return $this->{rev};
}

=begin TML

---++ ClassMethod meta( [$name] ) => $name

   * =$name= - optional, set meta type name, Eg. =FIELD=

Get/set the meta type name

=cut

sub meta {
    my ( $this, $name ) = @_;

    if ( scalar(@_) == 2 ) {
        $this->{meta} = $name;
        $this->_invalidate();
    }
    else {
        $this->isValid();
    }

    return $this->{meta};
}

=begin TML

---++ ClassMethod metamember( [$index] ) => $index

   * =$index= - optional, selector value to select a single member from a META
   type supporting multiple occurances. May be an integer index or key value.

Get/set the metamember

=cut

sub metamember {
    my ( $this, $index ) = @_;

    if ( scalar(@_) == 2 ) {
        $this->{metamember} = $index;
        $this->_invalidate();
    }
    else {
        $this->isValid();
    }

    return $this->{metamember};
}

=begin TML

---++ ClassMethod metamemberkey( [$indexkey] ) => $indexkey

   * =$indexkey= - optional, set the lookup key for which =metamember= applies to

Get/set the key name for which =metamember= applies to

=cut

sub metamemberkey {
    my ( $this, $indexkey ) = @_;

    # Can't use "if defined" because sometimes we want to undef...
    if ( scalar(@_) == 2 ) {
        $this->{metamemberkey} = $indexkey;
        $this->_invalidate();
    }
    else {

        # Force metamemberkey = 'name' if metamember is not an integer
        $this->isValid();
    }

    return $this->{metamemberkey};
}

=begin TML

---++ ClassMethod metakey( [$key] ) => $key

   * =$key= - optional, set key name

Get/set the key name

=cut

sub metakey {
    my ( $this, $key ) = @_;

    if ( scalar(@_) == 2 ) {
        $this->{metakey} = $key;
        $this->_invalidate();
    }
    else {
        $this->isValid();
    }

    return $this->{metakey};
}

=begin TML

---++ ClassMethod type() => $resourcetype

Returns the resource type name.

=cut

sub type {
    my ($this) = @_;

    $this->isValid();

    return $this->{type};
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
   * web, Eg. =Web/SubWeb/=
   * topic, Eg. =Web/SubWeb.Topic=
   * attachment, Eg. =Web/SubWeb.Topic/Attachment=
   * meta, Eg. ='Web/SubWeb.Topic'/META:FIELD=
   * metamember, Eg. ='Web/SubWeb.Topic'/META:FIELD[name='Colour']=
   * metakey, Eg. ='Web/SubWeb.Topic'/META:FIELD[name='Colour'].value=

=cut

sub isValid {
    my ($this) = @_;
    my $valid = 1;

    if ( not defined $this->{isA} ) {
        if ( defined $this->{metakey} ) {
            ASSERT(   $this->{webs}
                  and $this->{topic}
                  and $this->{meta}
                  and $this->{metamember}
                  and not $this->{attachment} )
              if DEBUG;
            $this->{type} = 'metakey';
        }
        elsif ( defined $this->{metamember} ) {
            ASSERT(   $this->{webs}
                  and $this->{topic}
                  and $this->{meta}
                  and not $this->{attachment} )
              if DEBUG;

            # TODO: what about singleton (non-many) META types?
            $this->{type} = 'metamember';
        }
        elsif ( $this->{meta} ) {
            ASSERT(   $this->{webs}
                  and $this->{topic}
                  and not $this->{attachment} )
              if DEBUG;
            $this->{type} = 'meta';
        }
        elsif ( $this->{attachment} ) {
            ASSERT( $this->{webs} and $this->{topic} ) if DEBUG;
            $this->{type} = 'attachment';
        }
        elsif ( $this->{topic} ) {
            ASSERT( $this->{webs} ) if DEBUG;
            $this->{type} = 'topic';
        }
        elsif ( $this->{webs} ) {
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
            $valid = 0;
        }
        if (
            defined $this->{metamember}
            and not( $this->{metamemberkey}
                or $this->{metamember} =~ /^[\-\+]?\d+$/ )
          )
        {
            $this->{metamemberkey} = 'name';
        }
    }

    return $valid;
}

# Internally, this is called so that the next isValid() call will re-evaluate
# identity and validity of the instance; also, if any of the setters are used,
# invalidates the cached stringify value
sub _invalidate {
    my ($this) = @_;

    $this->{stringified}         = undef;
    $this->{stringifiedwebsep}   = undef;
    $this->{stringifiedtopicsep} = undef;
    $this->{isA}                 = undef;
    $this->{web}                 = undef;
    $this->{type}                = undef;

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
    my $othertype = $this->type();

    # Same type?
    if ( $thistype and $othertype and $thistype eq $othertype ) {
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
                    }
                    else {
                        $i += 1;
                    }
                }

                # And the non-web components?
                if ($equal) {
                    $i = 1;    # @addressparts starts with 'web', so skip that
                    while ( $equal and $i < $naddressparts ) {
                        my $part = $addressparts[$i];

                        if ( defined $this->{$part} ) {
                            if ( not defined $other->{$part}
                                or $this->{$part} ne $other->{$part} )
                            {
                                $equal = 0;
                            }
                        }
                        elsif ( defined $other->{$part} ) {
                            $equal = 0;
                        }
                        $i += 1;
                    }
                }
            }
        }
    }
    if ( not $equal ) {
        print "equiv(): NOT equal "
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
