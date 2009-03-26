# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Meta

Objects of this class act as handles onto real store objects. An
object of this class can represent the Foswiki root, a web, or a topic.

Meta objects interact with the store using only the methods of
Foswiki::Store. The rest of the core should interact only with Meta
objects; the only exception to this are the *Exists methods that are
published by the store interface (and facaded by the Foswiki class).

A meta object exists in one of two states; either unloaded, in which case
it is simply a lightweight handle to a store location, and loaded, in
which case it acts as a portal onto the actual store content of a specific
revision of the topic.

An unloaded object is constructed by the =new= constructor on this class,
passing one to three parameters depending on whether the object represents the
root, a web, or a topic.

A loaded object may be constructed by calling the =load= constructor, or
a previously constructed object may be converted to 'loaded' state by
calling =reload=.

Unloaded objects return 0 from =getLoadedRev=, or the loaded revision
otherwise. =reload= allows you to load different revisions of the same
topic.

An unloaded object can be populated through calls to =text($text)=, =put=
and =putKeyed=. Such an object can be saved using =save()= to create a new
revision of the topic.

To the caller, a meta object carries two types of data. The first
is the "plain text" of the topic, which is accessible through the =text()=
method. The object also behaves as a hash of different types of
meta-data (keyed on the type, such as 'FIELD' and 'FILEATTACHMENT').

Each entry in the hash is an array, where each entry in the array
contains another hash of the key=value pairs, corresponding to a
single meta-datum.

If there may be multiple entries of the same top-level type (i.e. for FIELD
and FILEATTACHMENT) then the array has multiple entries. These types
are referred to as "keyed" types. The array entries are keyed with the
attribute 'name' which must be in each entry in the array.

For unkeyed types, the array has only one entry.

Pictorially,
   * TOPICINFO
      * author => '...'
      * date => '...'
      * ...
   * FILEATTACHMENT
      * [0] -> { name => '...' ... }
      * [1] -> { name => '...' ... }
   * FIELD
      * [0] -> { name => '...' ... }
      * [1] -> { name => '...' ... }

This module also include some methods to support embedding meta-data for
topics directly in topic text, a la the traditional Foswiki store
(getEmbeddedStoreForm and setEmbeddedStoreForm)

API version $Date$ (revision $Rev$)

*Since* _date_ indicates where functions or parameters have been added since
the baseline of the API (Foswiki release 4.2.3). The _date_ indicates the
earliest date of a Foswiki release that will support that function or
parameter.

*Deprecated* _date_ indicates where a function or parameters has been
[[http://en.wikipedia.org/wiki/Deprecation][deprecated]]. Deprecated
functions will still work, though they should
_not_ be called in new plugins and should be replaced in older plugins
as soon as possible. Deprecated parameters are simply ignored in Foswiki
releases after _date_.

*Until* _date_ indicates where a function or parameter has been removed.
The _date_ indicates the latest date at which Foswiki releases still supported
the function or parameter.

=cut

package Foswiki::Meta;

use strict;
use Error qw(:try);
use Assert;

our $reason;
our $VERSION = '$Rev$';

# Version for the embedding format (increment when embedding format changes)
our $EMBEDDING_FORMAT_VERSION = 1.1;

# defaults for trunctation of summary text
our $TMLTRUNC   = 162;
our $PLAINTRUNC = 70;
our $MINTRUNC   = 16;

# max number of lines in a summary (best to keep it even)
our $SUMMARYLINES = 6;

############# GENERIC METHODS #############

=begin TML

---++ ClassMethod new($session, $web, $topic)
   * =$session= - a Foswiki object (e.g. =$Foswiki::Plugins::SESSION=)
   * =$web=, =$topic= - the pathname of the object. If both are undef,
     this object is a handle for the root container. If $topic is undef,
     it is the handle to a web. Otherwise it's a handle to a topic.
   * $text - optional raw text, which may include embedded meta-data. Will
     be passed to =setEmbeddedStoreForm= to initialise the object. Only valid
     if =$web= and =$topic= are defined.
Construct a new, empty object. This method is used to create lightweight
handles for store objects, especially in cases where the full content of
the actual object will *not* be loaded. If you need to interact with the
existing content of the stored object, use the =load= method instead.

=cut

sub new {
    my ( $class, $session, $web, $topic, $text ) = @_;
    ASSERT( $session->isa('Foswiki') ) if DEBUG;
    my $this = bless( { _session => $session }, $class );

    # Normalise web path (replace [./]+ with /)
    $web =~ tr#/.#/#s if $web;

    # Note: internal fields are prepended with _. All uppercase
    # fields will be assumed to be meta-data.

    $this->{_web}   = $web;
    $this->{_topic} = $topic;
    $this->{_text}  = undef;    # topics only
         # Preferences cache object. We store a pointer, rather than looking
         # up the name each time, because we want to be able to invalidate the
         # loaded preferences if this object is reloaded with a different rev
         # (and therefore different prefs). The preferences cache does not take
         # topic revs into account.
    $this->{_preferences} = undef;

    $this->{FILEATTACHMENT} = [];

    if ( defined $text ) {
        ASSERT( defined($web) && defined($topic) ) if DEBUG;
        $this->setEmbeddedStoreForm($text);
    }

    return $this;
}

=begin TML

---++ ObjectMethod finish()
Clean up the object, releasing any memory stored in it.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;
    undef $this->{_web};
    undef $this->{_topic};
    undef $this->{_text};
    undef $this->{_preferences};
    undef $this->{_session};
}

=begin TML

---++ ObjectMethod session()

Get the session associated with the object when it was created.

=cut

sub session {
    return $_[0]->{_session};
}

=begin TML

---++ ObjectMethod web([$name])
   * =$name= - optional, change the web name in the object
      * *Since* 28 Nov 2008
Get/set the web name associated with the object.

=cut

sub web {
    my ( $this, $web ) = @_;
    $this->{_web} = $web if defined $web;
    return $_[0]->{_web};
}

=begin TML

---++ ObjectMethod topic([$name])
   * =$name= - optional, change the topic name in the object
      * *Since* 28 Nov 2008
Get/set the topic name associated with the object.

=cut

sub topic {
    my ( $this, $topic ) = @_;
    $this->{_topic} = $topic if defined $topic;
    return $this->{_topic};
}

=begin TML

---++ ObjectMethod getPath() -> $objectpath

Get the canonical content access path for the object

=cut

sub getPath {
    my $this = shift;
    my $path = $this->{_web};

    return '' unless $path;
    return $path unless $this->{_topic};
    $path .= ".$this->{_topic}";
    return $path;
}

=begin TML

---++ ObjectMethod getPreference( $key ) -> $value

Get a preferences value for a preference defined in the object. Note that
web preferences always inherit from parent webs, but topic preferences
are strictly local to topics.

=cut

sub getPreference {
    my ( $this, $key ) = @_;
    my $scope;

    unless ($this->{_web} || $this->{_topic}) {
        return $this->{_session}->{prefs}->getPreference($key);
    }
    # make sure the preferences are parsed and cached
    unless ( $this->{_preferences} ) {
        $this->{_preferences} =
          $this->{_session}->{prefs}->loadPreferences($this);
    }
    return $this->{_preferences}->get($key);
}

=begin TML

---++ ObjectMethod getContainer() -> $containerObject

Get the container of this object; for example, the web that a topic is within

=cut

sub getContainer {
    my $this = shift;

    if ( $this->{_topic} ) {
        return Foswiki::Meta->new( $this->{_session}, $this->{_web} );
    }
    if ( $this->{_web} ) {
        return Foswiki::Meta->new( $this->{_session} );
    }
    ASSERT(0) if DEBUG;
    return undef;
}

=begin TML

---++ ObjectMethod stringify( $debug ) -> $string

Return a string version of the meta object. $debug adds
extra debug info.

=cut

sub stringify {
    my ( $this, $debug ) = @_;
    my $s = $this->{_web};
    if ( $this->{_topic} ) {
        $s .= ".$this->{_topic} ";
        $s .= $this->{_loadedRev} || '(not loaded)' if $debug;
        $s .= "\n" . $this->getEmbeddedStoreForm();
    }
    return $s;
}

############# WEB METHODS #############

=begin TML

---++ ObjectMethod populateNewWeb( [$baseWeb [, $opts]] )

$baseWeb is the name of an existing web (a template web). If the
base web is a system web, all topics in it
will be copied into this web. If it is a normal web, only topics starting
with 'Web' will be copied. If no base web is specified, an empty web
(with no topics) will be created. If it is specified but does not exist,
an error will be thrown.

$opts is a ref to a hash that contains settings to be modified in
the web preferences topic in the new web.

=cut

sub populateNewWeb {
    my ( $this, $templateWeb, $opts ) = @_;
    ASSERT( $this->{_web} )    if DEBUG;
    ASSERT( !$this->{_topic} ) if DEBUG;

    my $session = $this->{_session};
    if ($templateWeb) {
        unless ( $session->webExists($templateWeb) ) {
            throw Error::Simple(
                'Template web ' . $templateWeb . ' does not exist' );
        }

        my $tWebObject = Foswiki::Meta->new( $session, $templateWeb );
        my $it = $tWebObject->eachTopic();
        while ( $it->hasNext() ) {
            my $topic = $it->next();
            next unless ( $templateWeb =~ /^_/ || $topic =~ /^Web/ );
            my $topicObject = Foswiki::Meta->load(
                $this->{_session}, $templateWeb, $topic );
            $topicObject->saveAs( $this->{_web}, $topic );
        }
    }

    # Make sure there is a preferences topic; this is how we know it's a web
    my $prefsTopicObject;
    if (
        !$session->topicExists(
            $this->{_web}, $Foswiki::cfg{WebPrefsTopicName}
        )
      )
    {
        $prefsTopicObject = Foswiki::Meta->new(
            $this->{_session},                $this->{_web},
            $Foswiki::cfg{WebPrefsTopicName}, 'Preferences'
        );
        $prefsTopicObject->save();
    }

    # patch WebPreferences in new web. We ignore permissions, because
    # we are creating a new web here.
    if ($opts) {
        $prefsTopicObject ||=
          Foswiki::Meta->load( $this->{_session}, $this->{_web},
            $Foswiki::cfg{WebPrefsTopicName} );
        my $text = $prefsTopicObject->text;
        foreach my $key (keys %$opts) {
            $text =~
              s/($Foswiki::regex{setRegex}$key\s*=).*?$/$1 $opts->{$key}/gm;
        }
        $prefsTopicObject->text($text);
        $prefsTopicObject->save();
    }
}

=begin TML

---++ ObjectMethod searchInText($searchString, \@topics, \%options ) -> \%map

Search for a string in the content of a web. The search must be over all
content and all formatted meta-data, though the latter search type is
deprecated (use queries instead).

   * =$searchString= - the search string, in egrep format if regex
   * =\@topics= - reference to a list of names of topics to search, or undef to search all topics in the web
   * =\%options= - reference to an options hash
The =\%options= hash may contain the following options:
   * =type= - if =regex= will perform a egrep-syntax RE search (default '')
   * =casesensitive= - false to ignore case (defaulkt true)
   * =files_without_match= - true to return files only (default false)

The return value is a reference to a hash which maps each matching topic
name to a list of the lines in that topic that matched the search,
as would be returned by 'grep'. If =files_without_match= is specified, it will
return on the first match in each topic (i.e. it will return only one
match per topic, and will not return matching lines).

=cut

sub searchInText {
    my ( $this, $searchString, $topics, $options ) = @_;
    ASSERT( !$this->{_topic} ) if DEBUG;
    unless ($topics) {
        my $it   = $this->eachTopic();
        my @list = $it->all();
        $topics = \@list;
    }
    return $this->{_session}->{store}
      ->searchInWebContent( $searchString, $this->{_web}, $topics, $options );
}

=begin TML

---++ ObjectMethod query($query, \@topics, \%options) -> \%matches

Search for a meta-data expression in the content of a web.
=$query= must be a =Foswiki::Query= object.

Returns a reference to a hash that maps the names of topics that all matched
to the result of the query expression (e.g. if the query expression is
'TOPICPARENT.name' then you will get back a hash that maps topic names
to their parent.

=cut

sub query {
    my ( $this, $query, $topics, $options ) = @_;
    return $this->{_session}->{store}
      ->searchInWebMetaData( $query, $this->{_web}, $topics, $options );
}

=begin TML

---++ ObjectMethod eachWeb( $all ) -> $iterator

Return an iterator over each subweb. If =$all= is set, will return a list of all
web names *under* the current location. Returns web pathnames relative to
$this.

Only valid on webs and the root.

=cut

sub eachWeb {
    my ( $this, $all ) = @_;

    ASSERT( !$this->{_topic} ) if DEBUG;
    return $this->{_session}->{store}->eachWeb( $this, $all );

}

=begin TML

---++ ObjectMethod eachTopic() -> $iterator

Return an iterator over each topic name in the web. Only valid on webs.

=cut

sub eachTopic {
    my ($this) = @_;
    ASSERT( !$this->{_topic} ) if DEBUG;
    ASSERT( $this->{_web} ) if DEBUG;    # no topics allowed in root level
    return $this->{_session}->{store}->eachTopic( $this );
}

=begin TML

---++ ObjectMethod eachAttachment() -> $iterator

Return an iterator over each attachment name in the topic.
Only valid on topics.

The list of the names of attachments stored for the given topic may be a
longer list than the list that comes from the topic meta-data, which may
only lists the attachments that are normally visible to the user.

=cut

sub eachAttachment {
    my ($this) = @_;
    ASSERT( $this->{_topic} ) if DEBUG;
    ASSERT( $this->{_web} ) if DEBUG;
    return $this->{_session}->{store}->eachAttachment( $this );
}

=begin TML

---++ ObjectMethod eachChange( $time ) -> $iterator

Get an iterator over the list of all the changes in the web between
=$time= and now. $time is a time in seconds since 1st Jan 1970, and is not
guaranteed to return any changes that occurred before (now -
{Store}{RememberChangesFor}). Changes are returned in most-recent-first
order.

Only valid for a web.

=cut

sub eachChange {
    my ( $this, $time ) = @_;
    ASSERT( !$this->{_topic} ) if DEBUG;
    ASSERT( $this->{_web} ) if DEBUG;    # not valid at root level
    return $this->{_session}->{store}->eachChange( $this, $time );
}

############# TOPIC METHODS #############

=begin TML

---++ StaticMethod load($session, $web, $topic, $rev) -> $meta

This method will load (or otherwise fetch) the meta-data for a named web/topic.

This method is functionally identical to:
<verbatim>
$this = Foswiki::Meta->new( $session, $web, $topic );
$this->reload( $rev );
</verbatim>

=cut

sub load {
    my ( $class, $session, $web, $topic, $rev ) = @_;
    ASSERT( $session->isa('Foswiki') ) if DEBUG;
    my $this = new( $class, $session, $web, $topic );
    $this->reload($rev);
    return $this;
}

=begin TML

---++ ObjectMethod reload($rev)

Reload the object from the store; perhaps because we haven't loaded it yet,
or we are looking at a different rev. See =getLoadedRev= to determine what
revision is currently being viewed.

=cut

sub reload {
    my ( $this, $rev ) = @_;

    return unless $this->{_topic};
    if ( defined $rev ) {
        $rev = Foswiki::Store::cleanUpRevID($rev);
    }
    else {
        $rev = $this->{_loadedRev};    # if any
    }
    foreach my $field ( keys %$this ) {
        next if $field =~ /^_(web|topic|session)/;
        $this->{$field} = undef;
    }
    $this->{FILEATTACHMENT} = [];
    $this->{_loadedRev} = $this->{_session}->{store}->readTopic( $this, $rev );
    $this->{_preferences} = undef;
}

=begin TML

---++ ObjectMethod text([$text]) -> $text

Get/set the topic body text. If $text is undef, gets the value, if it is
defined, sets the value to that and returns the new text.

=cut

sub text {
    my ( $this, $val ) = @_;
    ASSERT( $this->{_topic} ) if DEBUG;
    if ( defined($val) ) {
        $this->{_text} = $val;
    }
    else {

        # Lazy load
        $this->reload() unless defined( $this->{_text} );
    }
    return $this->{_text};
}

=begin TML

---++ ObjectMethod put($type, \%args)

Put a hash of key=value pairs into the given type set in this meta. This
will *not* replace another value with the same name (for that see =putKeyed=)

For example,
<verbatim>
$meta->put( 'FIELD', { name => 'MaxAge', title => 'Max Age', value =>'103' } );
</verbatim>

=cut

sub put {
    my ( $this, $type, $args ) = @_;

    my $data = $this->{$type};
    if ($data) {

        # overwrite old single value
        $data->[0] = $args;
    }
    else {
        push( @{ $this->{$type} }, $args );
    }
}

=begin TML

---++ ObjectMethod putKeyed($type, \%args)

Put a hash of key=value pairs into the given type set in this meta, replacing
any existing value with the same key.

For example,
<verbatim>
$meta->putKeyed( 'FIELD', { name => 'MaxAge', title => 'Max Age', value =>'103' } );
</verbatim>

=cut

# Note: Array is used instead of a hash to preserve sequence

sub putKeyed {
    my ( $this, $type, $args ) = @_;

    my $data = $this->{$type};
    if ($data) {
        my $keyName = $args->{name};
        ASSERT($keyName) if DEBUG;
        my $i = scalar(@$data);
        while ( $keyName && $i-- ) {
            if ( defined $data->[$i]->{name}
                && $data->[$i]->{name} eq $keyName )
            {
                $data->[$i] = $args;
                return;
            }
        }
        push @$data, $args;
    }
    else {
        push( @{ $this->{$type} }, $args );
    }
}

=begin TML

---++ ObjectMethod putAll

Replaces all the items of a given key with a new array.

For example,
<verbatim>
$meta->putAll( 'FIELD',
     { name => 'MinAge', title => 'Min Age', value =>'50' },
     { name => 'MaxAge', title => 'Max Age', value =>'103' },
     { name => 'HairColour', title => 'Hair Colour', value =>'white' }
 );
</verbatim>

=cut

sub putAll {
    my ( $this, $type, @array ) = @_;

    $this->{$type} = \@array;
}

=begin TML

---++ ObjectMethod get( $type, $key ) -> \%hash

Find the value of a meta-datum in the map. If the type is
keyed (idenitifed by a =name=), the =$key= parameter is required
to say _which_ entry you want. Otherwise you will just get the first value.

If you want all the keys of a given type use the 'find' method.

The result is a reference to the hash for the item.

For example,
<verbatim>
my $ma = $meta->get( 'FIELD', 'MinAge' );
my $topicinfo = $meta->get( 'TOPICINFO' ); # get the TOPICINFO hash
</verbatim>

=cut

sub get {
    my ( $this, $type, $keyValue ) = @_;

    my $data = $this->{$type};
    if ($data) {
        if ( defined $keyValue ) {
            foreach my $item (@$data) {
                return $item
                  if ( $item->{name} and ( $item->{name} eq $keyValue ) );
            }
        }
        else {
            return $data->[0];
        }
    }

    return undef;
}

=begin TML

---++ ObjectMethod find (  $type  ) -> @values

Get all meta data for a specific type.
Returns the array stored for the type. This will be zero length
if there are no entries.

For example,
<verbatim>
my $attachments = $meta->find( 'FILEATTACHMENT' );
</verbatim>

=cut

sub find {
    my ( $this, $type ) = @_;

    my $itemsr = $this->{$type};
    my @items  = ();

    if ($itemsr) {
        @items = @$itemsr;
    }

    return @items;
}

=begin TML

---++ ObjectMethod remove($type, $key)

With no type, will remove all the contents of the object.

With a $type but no $key, will remove _all_ items of that type (so for example if $type were FILEATTACHMENT it would remove all of them)

With a $type and a $key it will remove only the specific item.

=cut

sub remove {
    my ( $this, $type, $keyValue ) = @_;

    if ($keyValue) {
        my $data    = $this->{$type};
        my @newData = ();
        foreach my $item (@$data) {
            if ( $item->{name} && $item->{name} ne $keyValue ) {
                push @newData, $item;
            }
        }
        $this->{$type} = \@newData;
    }
    elsif ($type) {
        delete $this->{$type};
    }
    else {
        foreach my $entry ( keys %$this ) {
            unless ( $entry =~ /^_/ ) {
                $this->remove($entry);
            }
        }
    }
}

=begin TML

---++ ObjectMethod copyFrom( $otherMeta, $type, $nameFilter )

Copy all entries of a type from another meta data set. This
will destroy the old values for that type, unless the
copied object doesn't contain entries for that type, in which
case it will retain the old values.

If $type is undef, will copy ALL TYPES.

If $nameFilter is defined (a perl refular expression), it will copy
only data where ={name}= matches $nameFilter.

Does *not* copy web, topic or text.

=cut

sub copyFrom {
    my ( $this, $otherMeta, $type, $filter ) = @_;
    ASSERT( $otherMeta->isa('Foswiki::Meta') ) if DEBUG;

    if ($type) {
        foreach my $item ( @{ $otherMeta->{$type} } ) {
            if ( !$filter || ( $item->{name} && $item->{name} =~ /$filter/ ) ) {
                my %data = map { $_ => $item->{$_} } keys %$item;
                push( @{ $this->{$type} }, \%data );
            }
        }
    }
    else {
        foreach my $k ( keys %$otherMeta ) {

            # Don't copy the web and topic fields, this may be a new topic
            unless ( $k =~ /^_/ ) {
                $this->copyFrom( $otherMeta, $k );
            }
        }
    }
}

=begin TML

---++ ObjectMethod count($type) -> $integer

Return the number of entries of the given type

=cut

sub count {
    my ( $this, $type ) = @_;
    my $data = $this->{$type};

    return scalar @$data if ( defined($data) );

    return 0;
}

=begin TML

---++ ObjectMethod setRevisionInfo( \%opts )

Set TOPICINFO information on the object, as specified by the parameters.
   * =version= - the revision number
   * =time= - the time stamp
   * =author= - the user id
   * + additional data fields to save e.g. reprev, comment

=cut

sub setRevisionInfo {
    my ( $this, $data ) = @_;

    # compatibility; older versions of the code use
    # RCS rev numbers. Save with them so old code can
    # read these topics
    my %args = %$data;
    $args{version} = 1 if $args{version} < 1;
    $args{version} = '1.' . $args{version};
    $args{format}  = $EMBEDDING_FORMAT_VERSION,

      $this->put( 'TOPICINFO', \%args );
}

=begin TML

---++ ObjectMethod getRevisionInfo($fromrev) -> \%info

   * =$fromrev= revision number. If 0, undef, or out-of-range, will get info about the most recent revision.

Try and get revision info from the meta information, or, if it is not
present, kick down to the Store module for the same information.

Return %info with at least:
| date | in epochSec |
| user | user *object* |
| version | the revision number |
| comment | comment in the VC system, may or may not be the same as the comment in embedded meta-data |

=cut

sub getRevisionInfo {
    my $this = shift;

    my $info;
    my $topicinfo = $this->get('TOPICINFO');
    if ($topicinfo) {
        $info = {
            date    => $topicinfo->{date},
            author  => $topicinfo->{author},
            version => $topicinfo->{version},
        };

        # parse out SVN keywords in doc
        $info->{version} =~ s/^\$Rev(:\s*\d+)?\s*\$$/0/;

        # Chuck away RCS major rev number
        $info->{version} =~ s/^\d+\.//;
    }
    else {

        # Delegate to the store
        $info = $this->{_session}->{store}->getRevisionInfo($this);
    }
    return $info;
}

=begin TML

---++ ObjectMethod merge( $otherMeta, $formDef )

   * =$otherMeta= - a block of meta-data to merge with $this
   * =$formDef= reference to a Foswiki::Form that gives the types of the fields in $this

Merge the data in the other meta block.
   * File attachments that only appear in one set are preserved.
   * Form fields that only appear in one set are preserved.
   * Form field values that are different in each set are text-merged
   * We don't merge for field attributes or title
   * Topic info is not touched
   * The =mergeable= method on the form def is used to determine if that fields is mergeable. if it isn't, the value currently in meta will _not_ be changed.

=cut

sub merge {
    my ( $this, $other, $formDef ) = @_;

    my $data = $other->{FIELD};
    if ($data) {
        foreach my $otherD (@$data) {
            my $thisD = $this->get( 'FIELD', $otherD->{name} );
            if ( $thisD && $thisD->{value} ne $otherD->{value} ) {
                if ( $formDef->isTextMergeable( $thisD->{name} ) ) {
                    require Foswiki::Merge;
                    my $merged = Foswiki::Merge::merge2(
                        'A',
                        $otherD->{value},
                        'B',
                        $thisD->{value},
                        '.*?\s+',
                        $this->{_session},
                        $formDef->getField( $thisD->{name} )
                    );

                    # SMELL: we don't merge attributes or title
                    $thisD->{value} = $merged;
                }
            }
            elsif ( !$thisD ) {
                $this->putKeyed( 'FIELD', $otherD );
            }
        }
    }

    $data = $other->{FILEATTACHMENT};
    if ($data) {
        foreach my $otherD (@$data) {
            my $thisD = $this->get( 'FILEATTACHMENT', $otherD->{name} );
            if ( !$thisD ) {
                $this->putKeyed( 'FILEATTACHMENT', $otherD );
            }
        }
    }
}

=begin TML

---++ ObjectMethod forEachSelectedValue( $types, $keys, \&fn, \%options )

Iterate over the values selected by the regular expressions in $types and
$keys.
   * =$types= - regular expression matching the names of fields to be processed. Will default to qr/^[A-Z]+$/ if undef.
   * =$keys= - regular expression matching the names of keys to be processed.  Will default to qr/^[a-z]+$/ if undef.

Iterates over each value, calling =\&fn= on each, and replacing the value
with the result of \&fn.

\%options will be passed on to $fn, with the following additions:
   * =_type= => the type name (e.g. "FILEATTACHMENT")
   * =_key= => the key name (e.g. "user")

=cut

sub forEachSelectedValue {
    my ( $this, $types, $keys, $fn, $options ) = @_;

    $types ||= qr/^[A-Z]+$/;
    $keys  ||= qr/^[a-z]+$/;

    foreach my $type ( grep { /$types/ } keys %$this ) {
        $options->{_type} = $type;
        my $data = $this->{$type};
        next unless $data;
        foreach my $datum (@$data) {
            foreach my $key ( grep { /$keys/ } keys %$datum ) {
                $options->{_key} = $key;
                $datum->{$key} = &$fn( $datum->{$key}, $options );
            }
        }
    }
}

=begin TML

---++ ObjectMethod getParent() -> $parent

Gets the TOPICPARENT name.

=cut

sub getParent {
    my ($this) = @_;

    my $value  = '';
    my $parent = $this->get('TOPICPARENT');
    $value = $parent->{name} if ($parent);

    # Return empty string (not undef), if TOPICPARENT meta is broken
    $value = '' if ( !defined $value );
    return $value;
}

=begin TML

---++ ObjectMethod getFormName() -> $formname

Returns the name of the FORM, or '' if none.

=cut

sub getFormName {
    my ($this) = @_;

    my $aForm = $this->get('FORM');
    if ($aForm) {
        return $aForm->{name};
    }
    return '';
}

=begin TML

---++ ObjectMethod renderFormForDisplay( $templates ) -> $html

Render the form contained in the meta for display.

=cut

sub renderFormForDisplay {
    my ( $this, $templates ) = @_;

    # NOTE: param $templates is not used

    my $fname = $this->getFormName();

    require Foswiki::Form;
    return '' unless $fname;

    my $form = new Foswiki::Form( $this->{_session}, $this->{_web}, $fname );

    if ($form) {
        return $form->renderForDisplay($this);
    }
    else {

        # Make pseudo-form from field data
        $form =
          new Foswiki::Form( $this->{_session}, $this->{_web}, $fname, $this );
        return CGI::span(
            { class => 'foswikiAlert' },
            "%MAKETEXT{\"Form definition '[_1]' not found\" args=\"$fname\"}%"
        ) . $form->renderForDisplay($this);
    }
}

=begin TML

---++ ObjectMethod renderFormFieldForDisplay($name, $format, $attrs) -> $text

Render a single formfield, using the $format. See
Foswiki::Form::FormField::renderForDisplay for a description of how the value
is rendered.

=cut

sub renderFormFieldForDisplay {
    my ( $this, $name, $format, $attrs ) = @_;

    my $value;
    my $mf = $this->get( 'FIELD', $name );
    unless ($mf) {

        # Not a valid field name, maybe it's a title.
        require Foswiki::Form;
        $name = Foswiki::Form::fieldTitle2FieldName($name);
        $mf = $this->get( 'FIELD', $name );
    }
    return '' unless $mf;    # field not found

    $value = $mf->{value};

    my $fname = $this->getFormName();
    if ($fname) {
        require Foswiki::Form;
        my $form =
          new Foswiki::Form( $this->{_session}, $this->{_web}, $fname );
        if ($form) {
            my $field = $form->getField($name);
            if ($field) {
                return $field->renderForDisplay( $format, $value, $attrs );
            }
        }
    }

    # Form or field wasn't found, do your best!
    my $f = $this->get( 'FIELD', $name );
    if ($f) {
        $format =~ s/\$title/$f->{title}/;
        require Foswiki::Render;
        $value = Foswiki::Render::protectFormFieldValue( $value, $attrs );
        $format =~ s/\$value/$value/;
    }
    return $format;
}

# Enable this for debug. Done as a sub to allow perl to optimise it out.
sub MONITOR_ACLS { 0 }

=begin TML

---++ ObjectMethod haveAccess($mode, $cUID) -> $boolean

   * =$mode=  - 'VIEW', 'CHANGE', 'CREATE', etc.
   * =$cUID=    - Canonical user id (defaults to current user)
Check if the user has the given mode of access to the topic. This call
may result in the topic being read.

=cut

sub haveAccess {
    my ( $this, $mode, $cUID ) = @_;
    $cUID ||= $this->{_session}->{user};
    if ( defined $this->{_topic} && !defined $this->{_text} ) {
        $this->reload();
    }
    my $session = $this->{_session};
    undef $reason;

    print STDERR "Check $mode access $cUID to ".$this->getPath()."\n"
      if MONITOR_ACLS;

    # super admin is always allowed
    if ( $session->{users}->isAdmin($cUID) ) {
        print STDERR "$cUID - ADMIN\n" if MONITOR_ACLS;
        return 1;
    }

    $mode = uc($mode);

    my ( $allowText, $denyText );
    if ( $this->{_topic} ) {

        # extract the * Set (ALLOWTOPIC|DENYTOPIC)$mode
        $allowText = $this->getPreference( 'ALLOWTOPIC' . $mode );
        $denyText  = $this->getPreference( 'DENYTOPIC' . $mode );

        # Check DENYTOPIC
        if ( defined($denyText) ) {
            if ( $denyText =~ /\S$/ ) {
                if ( $session->{users}->isInList( $cUID, $denyText ) ) {
                    $reason =
                      $session->i18n->maketext('access denied on topic');
                    print STDERR $reason, "\n" if MONITOR_ACLS;
                    return 0;
                }
            }
            else {

                # If DENYTOPIC is empty, don't deny _anyone_
                print STDERR "DENYTOPIC is empty\n" if MONITOR_ACLS;
                return 1;
            }
        }

        # Check ALLOWTOPIC. If this is defined the user _must_ be in it
        if ( defined($allowText) && $allowText =~ /\S/ ) {
            if ( $session->{users}->isInList( $cUID, $allowText ) ) {
                print STDERR "in ALLOWTOPIC\n" if MONITOR_ACLS;
                return 1;
            }
            $reason = $session->i18n->maketext('access not allowed on topic');
            print STDERR $reason, "\n" if MONITOR_ACLS;
            return 0;
        }
        $this = $this->getContainer();    # Web
    }

    if ( $this->{_web} ) {

        # Check DENYWEB, but only if DENYTOPIC is not set (even if it
        # is empty - empty means "don't deny anybody")
        unless ( defined($denyText) ) {
            $denyText = $this->getPreference( 'DENYWEB' . $mode );
            if ( defined($denyText)
                && $session->{users}->isInList( $cUID, $denyText ) )
            {
                $reason = $session->i18n->maketext('access denied on web');
                print STDERR $reason, "\n" if MONITOR_ACLS;
                return 0;
            }
        }

        # Check ALLOWWEB. If this is defined and not overridden by
        # ALLOWTOPIC, the user _must_ be in it.
        $allowText = $this->getPreference( 'ALLOWWEB' . $mode );

        if ( defined($allowText) && $allowText =~ /\S/ ) {
            unless ( $session->{users}->isInList( $cUID, $allowText ) ) {
                $reason = $session->i18n->maketext('access not allowed on web');
                print STDERR $reason, "\n" if MONITOR_ACLS;
                return 0;
            }
        }

    }
    else {

        # No web, we are checking at the root. Check DENYROOT and ALLOWROOT.
        $denyText = $this->getPreference( 'DENYROOT' . $mode );

        if ( defined($denyText)
            && $session->{users}->isInList( $cUID, $denyText ) )
        {
            $reason = $session->i18n->maketext('access denied on root');
            print STDERR $reason, "\n" if MONITOR_ACLS;
            return 0;
        }

        $allowText = $this->getPreference( 'ALLOWROOT' . $mode );

        if ( defined($allowText) && $allowText =~ /\S/ ) {
            unless ( $session->{users}->isInList( $cUID, $allowText ) ) {
                $reason =
                  $session->i18n->maketext('access not allowed on root');
                print STDERR $reason, "\n" if MONITOR_ACLS;
                return 0;
            }
        }
    }

    if (MONITOR_ACLS) {
        print STDERR "OK, permitted\n";
        print STDERR "ALLOW: $allowText\n" if defined $allowText;
        print STDERR "DENY: $denyText\n"   if defined $denyText;
    }
    return 1;
}

=begin TML

---++ ObjectMethod save( %options  )

Save the current object, invoking appropriate plugin handlers
   * =%options= - Hash of options, see saveAs for list of keys

=cut

sub save {
    my $this = shift;
    ASSERT( scalar(@_) % 2 == 0 );
    my %opts = @_;

    my $plugins = $this->{_session}->{plugins};

    # Semantics inherited from Cairo. See
    # Foswiki:Codev.BugBeforeSaveHandlerBroken
    if ( $plugins->haveHandlerFor('beforeSaveHandler') ) {
        my $before = '';

        # Break up the tom and write the meta into the topic text.
        # Nasty compatibility requirement.
        my $text = $this->getEmbeddedStoreForm();
        $before = $this->stringify();

        $plugins->dispatch( 'beforeSaveHandler', $text, $this->{_topic},
            $this->{_web}, $this );

        # If there are no changes in the object, assemble a new tom
        # from the text. Nasty compatibility requirement.
        if ( $this->stringify() eq $before ) {

            # reassemble the tom. there may be new meta in the text.
            my $after =
              Foswiki::Meta->new( $this->{_session}, $this->{_web},
                $this->{_topic}, $text );
            $text = $after->text();
            $this = $after;
        }
    }

    my $signal;
    try {
        $this->saveAs( $this->{_web}, $this->{_topic}, %opts );
    }
    catch Error::Simple with {
        $signal = shift;
    };

    # Semantics inherited from Cairo. See
    # TWiki:Codev.BugBeforeSaveHandlerBroken
    if ( $plugins->haveHandlerFor('afterSaveHandler') ) {
        my $text = $this->getEmbeddedStoreForm();
        my $error = $signal ? $signal->{-text} : undef;
        $plugins->dispatch( 'afterSaveHandler', $text, $this->{_topic},
            $this->{_web}, $error, $this );
    }

    throw $signal if $signal;

    if ( !$opts{dontlog} ) {
        $this->{_session}->logEvent(
            'save',
            $this->{_web} . '.' . $this->{_topic},
            $opts{minor} ? 'minor' : '',
            $this->{_session}->{user}
        );
    }
}

=begin TML

---++ ObjectMethod saveAs( $web, $topic, %options  )

Save the current topic to a store location. Only works on topics.
*without* invoking plugins handlers.
   * =$web.$topic= - where to move to
   * =%options= - Hash of options, may include:
      * =forcenewrevision= - force an increment in the revision number,
        even if content doesn't change.
      * =dontlog= - don't log this change in log
      * =comment= - comment for save
      * =minor= - True if this is a minor change (used in log)
      * =savecmd= - Save command (core use only)
      * =forcedate= - force the revision date to be this (core only)
      * =author= - cUID of author of change (core only - default current user)

Note that the %options are passed on verbatim from Foswiki::Func::saveTopic,
so an extension author can in fact use all these options. However those
marked "core only" are for core use only and should *not* be used in
extensions.

=cut

sub saveAs {
    my $this     = shift;
    my $newWeb   = shift;
    my $newTopic = shift;
    ASSERT( scalar(@_) % 2 == 0 ) if DEBUG;
    my %opts = @_;
    my $cUID = $opts{author} || $this->{_session}->{user};

    $this->{_web}   = $newWeb   if $newWeb;
    $this->{_topic} = $newTopic if $newTopic;
    ASSERT( $this->{_web} && $this->{_topic} ) if DEBUG;
    $this->_atomicLock($cUID);
    my $error;
    try {
        $this->{_loadedRev} =
          $this->{_session}->{store}->saveTopic( $this, $cUID, \%opts );
    }
    finally {
        $this->_atomicUnlock($cUID);
    };
}

sub _atomicLock {
    my ($this, $cUID) = @_;
    if ( $this->{_topic} ) {

        # Topic
        $this->{_session}->{store}->lockTopic($this, $cUID);
    }
    else {

        # Web: Recursively lock subwebs and topics
        my $it = $this->eachWeb();
        while ( $it->hasNext() ) {
            my $web = $this->{_web} . '/' . $it->next();
            my $meta = Foswiki::Meta->new( $this->{_session}, $web );
            $meta->_atomicLock($cUID);
        }
        $it = $this->eachTopic();
        while ( $it->hasNext() ) {
            my $meta =
              Foswiki::Meta->new( $this->{_session}, $this->{_web},
                $it->next() );
            $meta->_atomicLock($cUID);
        }
    }
}

sub _atomicUnlock {
    my ($this, $cUID) = @_;
    if ( $this->{_topic} ) {
        $this->{_session}->{store}->unlockTopic($this, $cUID);
    }
    else {
        my $it = $this->eachWeb();
        while ( $it->hasNext() ) {
            my $web = $this->{_web} . '/' . $it->next();
            my $meta = Foswiki::Meta->new( $this->{_session}, $web );
            $meta->_atomicUnlock($cUID);
        }
        $it = $this->eachTopic();
        while ( $it->hasNext() ) {
            my $meta =
              Foswiki::Meta->new( $this->{_session}, $this->{_web},
                $it->next() );
            $meta->_atomicUnlock($cUID);
        }
    }
}

=begin TML

---++ ObjectMethod move($to, %opts)

Move this object (web or topic) to a store location specified by the
object $to. %opts may include:
   * =user= - cUID of the user doing the moving.

=cut

sub move {
    my ( $this, $to, %opts ) = @_;

    my $cUID = $opts{user} || $this->{_session}->{user};

    if ( $this->{_topic} ) {

        # Move topic

        $this->_atomicLock($cUID);
        $to->_atomicLock($cUID);

        # Clear outstanding leases. We assume that the caller has checked
        # that the lease is OK to kill.
        $this->clearLease() if $this->getLease();
        try {
            $this->put(
                'TOPICMOVED',
                {
                    from => $this->getPath(),
                    to   => $to->getPath(),
                    date => time(),
                    by   => $cUID,
                }
            );
            $this->save();    # to save the metadata change
            $this->{_session}->{store}->moveTopic( $this, $to, $cUID );
            $to->reload();
        }
        finally {
            $this->_atomicUnlock($cUID);
            $to->_atomicUnlock($cUID);
        };

    }
    else {

        # Move web
        ASSERT( !$this->{_session}->{store}->webExists( $to->{_web} ),
            $to->{_web} )
          if DEBUG;
        $this->_atomicLock($cUID);
        $this->{_session}->{store}->moveWeb( $this, $to, $cUID );

        # No point in unlocking $this - it's moved!
        $to->_atomicUnlock($cUID);
    }

    # Log rename
    my $old = $this->{_web} . '.' . ( $this->{_topic} || '' );
    my $new = $to->{_web} . '.' .   ( $to->{_topic}   || '' );
    $this->{_session}
      ->logEvent( 'rename', $old, "moved to $new", $this->{_session}->{user} );

    # alert plugins of topic move
    $this->{_session}->{plugins}
      ->dispatch( 'afterRenameHandler', $this->{_web}, $this->{_topic} || '',
        '', $to->{_web}, $to->{_topic} || '', '' );
}

=begin TML

---++ ObjectMethod deleteMostRecentRevision(%opts)
Delete (or elide) the most recent revision of this. Only works on topics.

=%opts= may include
   * =user= - cUID of user doing the unlocking

=cut

sub deleteMostRecentRevision {
    my ($this, %opts) = @_;
    my $rev;
    my $cUID = $opts{user} || $this->{_session}->{user};

    $this->_atomicLock($cUID);
    try {
        $rev = $this->{_session}->{store}->delRev($this, $cUID);
    }
    finally {
        $this->_atomicUnlock($cUID);
    };

    # TODO: delete entry in .changes

    # write log entry
    $this->{_session}->writeLog(
        'cmd',
        $this->{_web} . '.' . $this->{_topic},
        " delRev $rev by " . $this->{_session}->{user}
    );
}

=begin TML

---++ ObjectMethod replaceMostRecentRevision( %opts )
Replace the most recent revision with whatever is in the memory copy.
Only works on topics.

%opts may include:
   * =forcedate= - try and re-use the date of the original check
   * =user= - cUID of the user doing the action

=cut

sub replaceMostRecentRevision {
    my $this = shift;
    my %opts = @_;

    my $cUID = $opts{user} || $this->{_session}->{user};

    $this->_atomicLock($cUID);

    try {
        $this->{_session}->{store}->repRev( $this, $cUID, @_ );
    }
    finally {
        $this->_atomicUnlock($cUID);
    };
    if ( $TWiki::cfg{Log}{save} && !$opts{dontlog} ) {
        my $info = $this->getRevisionInfo();

        # write log entry
        require Foswiki::Time;
        my $extra = "repRev $info->{version} by " . $cUID . ' ';
        $extra .= Foswiki::Time::formatTime( $info->{date}, '$rcs', 'gmtime' );
        $extra .= ' minor' if ( $opts{minor} );
        $this->{_session}->writeLog(
            $opts{forcedate} ? 'cmd' : 'save',
            $this->getPath(),
            $extra, $cUID
        );
    }
}

=begin TML

---++ ObjectMethod getMaxRevNo([$attachment]) -> $integer

Get the revision number of the most recent revision of the topic,
irrespective of which rev is currently loaded.

$attachment is optional, and if provided will get the max rev of an attachment
on the topic.

Only valid on topics.

=cut

sub getMaxRevNo {
    my ( $this, $attachment ) = @_;
    ASSERT( $this->{_topic} ) if DEBUG;
    return $this->{_session}->{store}->getRevisionNumber( $this, $attachment );
}

=begin TML

---++ ObjectMethod getLoadedRev() -> $integer

Get the currently loaded revision. Result will be a revision number or
0 if no revision has been loaded. Only valid on topics.

=cut

sub getLoadedRev {
    my $this = shift;
    ASSERT( $this->{_topic} ) if DEBUG;
    return $this->{_loadedRev} || 0;
}

=begin TML

---++ ObjectMethod removeFromStore( $attachment )
   * =$attachment= - optional, provide to delete an attachment

Use with great care! Removes all trace of the given web, topic
or attachment from the store, possibly including all its history.

=cut

sub removeFromStore {
    my ( $this, $attachment ) = @_;
    my $store = $this->{_session}->{store};
    ASSERT( $this->{_web} ) if DEBUG;
    ASSERT( !$attachment || $this->{_topic} ) if DEBUG;

    if ( !$store->webExists( $this->{_web} ) ) {
        throw Error::Simple( 'No such web ' . $this->{_web} );
    }
    if ( $this->{_topic}
        && !$store->topicExists( $this->{_web}, $this->{_topic} ) )
    {
        throw Error::Simple(
            'No such topic ' . $this->{_web} . '.' . $this->{_topic} );
    }

    if (
        $attachment
        && !$store->attachmentExists(
            $this->{_web}, $this->{_topic}, $attachment
        )
      )
    {
        throw Error::Simple( 'No such attachment '
              . $this->{_web} . '.'
              . $this->{_topic} . '.'
              . $attachment );
    }

    $store->remove($this);
}

=begin TML

---++ ObjectMethod getDifferences( $topicObject, $contextLines ) -> \@diffArray

Return reference to an array of [ diffType, $right, $left ]
   * =$topicObject2= - the tom to diff against (must be the same topic)
   * =$contextLines= - number of lines of context required
Both $this and $topicObject2 must contain loaded revisions of the same topic.

=cut

sub getDifferences {
    my ( $this, $topicObject2, $contextLines ) = @_;
    ASSERT(  $topicObject2->{_web} eq $this->{_web}
          && $topicObject2->{_topic} eq $this->{_topic} )
      if DEBUG;
    ASSERT( $this->{_loadedRev} )         if DEBUG;
    ASSERT( $topicObject2->{_loadedRev} ) if DEBUG;
    return $this->{_session}->{store}
      ->getRevisionDiff( $this, $topicObject2, $contextLines );
}

=begin TML

---++ ObjectMethod getRevisionAtTime( $time ) -> $rev
   * =$time= - time (in epoch secs) for the rev

Get the revision number for a topic at a specific time.
Returns a single-digit rev number or 0 if it couldn't be determined
(either because the topic isn't that old, or there was a problem)

=cut

sub getRevisionAtTime {
    my ( $this, $time ) = @_;
    ASSERT( $this->{_topic} ) if DEBUG;
    return $this->{_session}->{store}->getRevisionAtTime( $this, $time );
}

=begin TML

---++ ObjectMethod setLease( $length )

Take out an lease on the given topic for this user for $length seconds.

See =getLease= for more details about Leases.

=cut

sub setLease {
    my ( $this, $length ) = @_;
    my $t     = time();
    my $lease = {
        user    => $this->{_session}->{user},
        expires => $t + $length,
        taken   => $t
    };
    return $this->{_session}->{store}->setLease( $this, $lease );
}

=begin TML

---++ ObjectMethod getLease() -> $lease

If there is an lease on the topic, return the lease, otherwise undef.
A lease is a block of meta-information about a topic that can be
recovered (this is a hash containing =user=, =taken= and =expires=).
Leases are taken out when a topic is edited. Only one lease
can be active on a topic at a time. Leases are used to warn if
another user is already editing a topic.

=cut

sub getLease {
    my $this = shift;
    return $this->{_session}->{store}->getLease($this);
}

=begin TML

---++ ObjectMethod clearLease()

Cancel the current lease.

See =getLease= for more details about Leases.

=cut

sub clearLease {
    my $this = shift;
    $this->{_session}->{store}->setLease($this);
}

############# ATTACHMENTS ON TOPICS #############

=begin TML

---++ ObjectMethod getAttachmentRevisionInfo($attachment, $rev) -> \%info
   * =$attachment= - attachment name
   * =$rev= - optional integer attachment revision number
Get revision info for an attachment. Only valid on topics.

$info will contain at least: date, author, version, comment

=cut

sub getAttachmentRevisionInfo {
    my ( $this, $attachment, $fromrev ) = @_;

    return $this->{_session}->{store}
      ->getRevisionInfo( $this, $fromrev, $attachment );
}

=begin TML

---++ ObjectMethod attach ( %opts )

   * =%opts= may include:
      * =name= - Name of the attachment
      * =dontlog= - don't log this change in twiki log
      * =comment= - comment for save
      * =hide= - if the attachment is to be hidden in normal topic view
      * =stream= - Stream of file to upload
      * =file= - Name of a file to use for the attachment data. Ignored if
        =stream= is set.
      * =filepath= - Client path to file
      * =filesize= - Size of uploaded data
      * =filedate= - Date
      * =tmpFilename= - Pathname of the server file the stream is
        attached to. Required if =stream= is set.
      * =author= - cUID of author of change

Saves a new revision of the attachment, invoking plugin handlers as
appropriate.

If file is not set, this is a properties-only save.

=cut

sub attach {
    my $this = shift;
    my %opts = @_;
    my $action;
    my $plugins = $this->{_session}->{plugins};

    # update topic
    if ( $opts{file} && !$opts{stream} ) {
        open( $opts{stream}, '<', $opts{file} )
          || throw Error::Simple( 'Could not open ' . $opts{file} );
        binmode( $opts{stream} )
          || throw Error::Simple( $opts{file} . ' binmode failed: ' . $! );
        $opts{tmpFilename} = $opts{file};
    }

    my $attrs;
    if ( $opts{stream} ) {
        $action = 'upload';
        $attrs  = {
            name        => $opts{name},
            attachment  => $opts{name},
            stream      => $opts{stream},
            tmpFilename => $opts{tmpFilename},
            author      => $this->{_session}->{user},
            comment     => $opts{comment} || '',
        };

        if ( $plugins->haveHandlerFor('beforeAttachmentSaveHandler') ) {

            # Because of the way CGI works, the stream is actually attached
            # to a file that is already on disc. So all we need to do
            # is determine that filename, close the stream, process the
            # upload and then reopen the stream on the resultant file.
            close( $opts{stream} );
            if ( !defined( $attrs->{tmpFilename} ) ) {
                throw Error::Simple(
"Cannot call beforeAttachmentSaveHandler; CGI did not provide a temporary file name"
                );
            }
            $plugins->dispatch( 'beforeAttachmentSaveHandler', $attrs,
                $this->{_topic}, $this->{_web} );
            open( $opts{stream}, "<$attrs->{tmpFilename}" );
            binmode( $opts{stream} );
        }

        my $error = '';
        try {

            # Note that we don't update the topic until the attachment is
            # saved, in case of error.
            $this->{_session}->{store}
              ->saveAttachment(
                  $this, $opts{name}, $opts{stream},
                  $opts{author} || $this->{_session}->{user});
        }
        catch Error::Simple with {
            $error = shift;
        };
        my $fileVersion = $this->getMaxRevNo( $opts{name} );
        $attrs->{version} = $fileVersion;
        $attrs->{path}    = $opts{filepath} if ( defined( $opts{filepath} ) );
        $attrs->{size}    = $opts{filesize} if ( defined( $opts{filesize} ) );
        $attrs->{date}    = $opts{filedate} if ( defined( $opts{filedate} ) );

        if ( $plugins->haveHandlerFor('afterAttachmentSaveHandler') ) {
            $plugins->dispatch( 'afterAttachmentSaveHandler', $attrs,
                $this->{_topic}, $this->{_web},
                $error ? $error->{-text} : undef );
        }
        throw $error if $error;
    }
    else {

        # Property change
        $action        = 'save';
        $attrs         = $this->get( 'FILEATTACHMENT', $opts{name} );
        $attrs->{name} = $opts{name};
        $attrs->{comment} = $opts{comment} if ( defined( $opts{comment} ) );
    }
    $attrs->{attr} = ( $opts{hide} ) ? 'h' : '';
    delete $attrs->{stream};
    delete $attrs->{tmpFilename};
    $this->putKeyed( 'FILEATTACHMENT', $attrs );

    if ( $opts{createlink} ) {
        my $text = $this->text();
        $text .=
          $this->{_session}->attach->getAttachmentLink( $this, $opts{name} );
        $this->text($text);
    }

    $this->saveAs();

    if ( !$opts{dontlog} ) {
        $this->{_session}->logEvent(
            $action,     $this->{_web} . '.' . $this->{_topic},
            $opts{name}, $this->{_session}->{user}
        );
    }
}

=begin TML

---++ ObjectMethod hasAttachment( $name ) -> $boolean
Test if the named attachment exists. Only valid on topics.

=cut

sub hasAttachment {
    my ( $this, $name ) = @_;
    return $this->{_session}->{store}
      ->attachmentExists( $this->{_web}, $this->{_topic}, $name );
}

=begin TML

---++ ObjectMethod readAttachment( $name [, $rev] ) -> $data
Read the named attachment (optional rev) and return the content as
a scalar.

=cut

sub readAttachment {
    my ( $this, $name, $rev ) = @_;
    return $this->{_session}->{store}->readAttachment( $this, $name, $rev );
}

=begin TML

---++ ObjectMethod moveAttachment( $name, $to, %opts ) -> $data
Move the named attachment to the topic indicates by $to.
=%opts= may include:
   * =new_name= - new name for the attachment
   * =user= - cUID of user doing the moving

=cut

sub moveAttachment {
    my $this = shift;
    my $name = shift;
    my $to   = shift;
    my %opts = @_;
    my $cUID = $opts{user} || $this->{_session}->{user};

    my $newName = $opts{new_name} || $name;

    $this->_atomicLock($cUID);
    $to->_atomicLock($cUID);

    try {
        $this->{_session}->{store}
          ->moveAttachment( $this, $name, $to, $newName, $cUID);
        $this->reload();
        $to->reload();
    }
    finally {
        $to->_atomicUnlock($cUID);
        $this->_atomicUnlock($cUID);
    };

    # alert plugins of attachment move
    $this->{_session}->{plugins}
      ->dispatch( 'afterRenameHandler', $this->{_web}, $this->{_topic}, $name,
        $to->{_web}, $to->{_topic}, $newName );

    $this->{_session}->logEvent(
        'move',
        $this->{_web} . '.'
          . $this->{_topic} . '.'
          . $name
          . ' moved to '
          . $to->{_web} . '.'
          . $to->{_topic} . '.'
          . $newName,
        $cUID
    );
}

=begin TML

---++ ObjectMethod getAttachmentStream( $attName ) -> \*STREAM

   * =$attName= - Name of the attachment

Open a standard input stream from an attachment. Only valid on topics.

=cut

sub getAttachmentStream {
    my ( $this, $attachment ) = @_;
    return $this->{_session}->{store}
      ->getAttachmentStream( $this, $attachment );
}

=begin TML

---++ ObjectMethod expandNewTopic( $text ) -> $text
Expand only that subset of Foswiki variables that are
expanded during topic creation. Returns the expanded text.
Only valid on topics.

=cut

sub expandNewTopic {
    my ( $this, $text ) = @_;
    return $this->{_session}->expandMacrosOnTopicCreation( $text, $this );
}

=begin TML

---++ ObjectMethod expandMacros( $text ) -> $text
Expand only all Foswiki variables that are
expanded during topic view. Returns the expanded text.
Only valid on topics.

=cut

sub expandMacros {
    my ( $this, $text ) = @_;
    return $this->{_session}->expandMacros( $text, $this );
}

=begin TML

---++ ObjectMethod renderTML( $text ) -> $text
Render all TML constructs in the text into HTML. Returns the rendered text.
Only valid on topics.

=cut

sub renderTML {
    my ( $this, $text ) = @_;
    return $this->{_session}->renderer->getRenderedVersion( $text, $this );
}

=begin TML

---++ ObjectMethod summariseText( $flags [, $text] ) -> $tml

Makes a plain text summary of the topic text by simply trimming a bit
off the top. Truncates to $TMTRUNC chars or, if a number is specified
in $flags, to that length.

If $text is defined, use it in place of the topic text.

=cut

sub summariseText {
    my ( $this, $flags, $text ) = @_;

    $flags ||= '';

    $text = $this->text() unless defined $text;
    my $htext = $this->session->renderer->TML2PlainText( $text, $this, $flags );
    $htext =~ s/\n+/ /g;

    # SMELL: need to avoid splitting within multi-byte characters
    # by encoding bytes as Perl UTF-8 characters.
    # This avoids splitting within a Unicode codepoint (or a UTF-16
    # surrogate pair, which is encoded as a single Perl UTF-8 character),
    # but we ideally need to avoid splitting closely related Unicode
    # codepoints.
    # Specifically, this means Unicode combining character sequences (e.g.
    # letters and accents)
    # Might be better to split on \b if possible.

    # limit to n chars
    my $nchar = $flags;
    unless ( $nchar =~ s/^.*?([0-9]+).*$/$1/ ) {
        $nchar = $TMLTRUNC;
    }
    $nchar = $MINTRUNC if ( $nchar < $MINTRUNC );
    $htext =~
      s/^(.{$nchar}.*?)($Foswiki::regex{mixedAlphaNumRegex}).*$/$1$2 \.\.\./s;

    # We do not want the summary to contain any $variable that formatted
    # searches can interpret to anything (Item3489).
    # Especially new lines (Item2496)
    # To not waste performance we simply replace $ by $<nop>
    $htext =~ s/\$/\$<nop>/g;

    # Escape Interwiki links and other side effects introduced by
    # plugins later in the rendering pipeline (Item4748)
    $htext =~ s/\:/<nop>\:/g;
    $htext =~ s/\s+/ /g;

    return $this->session->renderer->protectPlainText($htext);
}

=begin TML

---++ ObjectMethod summariseChanges( $orev, $nrev, $tml) -> $text

Generate a (max 3 line) summary of the differences between the revs.

   * =$orev= - older rev, if not defined will use ($nrev - 1)
   * =$nrev= - later rev, if not defined defaults to latest
   * =$tml= - if true will generate renderable TML (i.e. HTML with NOPs.
     If false will generate a summary suitable for use in plain text
    (mail, for example)

If there is only one rev, a topic summary will be returned.

If =$tml= is not set, all HTML will be removed.

In non-tml, lines are truncated to 70 characters. Differences are shown using + and - to indicate added and removed text.

=cut

sub summariseChanges {
    my ( $this, $orev, $nrev, $tml ) = @_;
    my $summary  = '';
    my $session  = $this->session();
    my $renderer = $session->renderer();

    $nrev = $this->getMaxRevNo() unless $nrev;

    $orev = $nrev - 1 unless defined($orev);

    ASSERT( $orev >= 0 && $nrev >= $orev ) if DEBUG;

    $this->reload($nrev);

    my $ntext = '';
    if ( $this->haveAccess('VIEW') ) {

        # Only get the text if we have access to nrev
        $ntext = $this->text();
    }

    return '' if ( $orev == $nrev );    # same rev, no differences

    my $metaPick = qr/^[A-Z](?!OPICINFO)/;    # all except TOPICINFO

    $ntext =
        $renderer->TML2PlainText( $ntext, $this, 'nonop' ) . "\n"
      . $this->stringify($metaPick);

    my $oldTopicObject =
      Foswiki::Meta->new( $session, $this->web, $this->topic );
    unless ( $oldTopicObject->haveAccess('VIEW') ) {

        # No access to old rev, make a blank topic object
        $oldTopicObject =
          Foswiki::Meta->new( $session, $this->web, $this->topic, '' );
    }
    my $otext =
      $renderer->TML2PlainText( $oldTopicObject->text(), $oldTopicObject,
        'nonop' )
      . "\n"
      . $oldTopicObject->stringify($metaPick);

    require Foswiki::Merge;
    my $blocks = Foswiki::Merge::simpleMerge( $otext, $ntext, qr/[\r\n]+/ );

    # sort through, keeping one line of context either side of a change
    my @revised;
    my $getnext  = 0;
    my $prev     = '';
    my $ellipsis = $tml ? '&hellip;' : '...';
    my $trunc    = $tml ? $TMLTRUNC : $PLAINTRUNC;
    while ( scalar @$blocks && scalar(@revised) < $SUMMARYLINES ) {
        my $block = shift(@$blocks);
        next unless $block =~ /\S/;
        my $trim = length($block) > $trunc;
        $block =~ s/^(.{$trunc}).*$/$1/ if ($trim);
        if ( $block =~ m/^[-+]/ ) {
            if ($tml) {
                $block =~ s/^-(.*)$/CGI::del( $1 )/se;
                $block =~ s/^\+(.*)$/CGI::ins( $1 )/se;
            }
            elsif ( $session->inContext('rss') ) {
                $block =~ s/^-/REMOVED: /;
                $block =~ s/^\+/INSERTED: /;
            }
            push( @revised, $prev ) if $prev;
            $block .= $ellipsis if $trim;
            push( @revised, $block );
            $getnext = 1;
            $prev    = '';
        }
        else {
            if ($getnext) {
                $block .= $ellipsis if $trim;
                push( @revised, $block );
                $getnext = 0;
                $prev    = '';
            }
            else {
                $prev = $block;
            }
        }
    }
    if ($tml) {
        $summary = join( CGI::br(), @revised );
    }
    else {
        $summary = join( "\n", @revised );
    }

    unless ($summary) {
        $summary = $this->summariseText( '', $ntext );
    }

    if ( !$tml ) {
        $summary = $renderer->protectPlainText($summary);
    }
    return $summary;
}

=begin TML

---++ ObjectMethod getEmbeddedStoreForm() -> $text

Generate the embedded store form of the topic. The embedded store
form has meta-data values embedded using %META: lines. The text
stored in the meta is taken as the topic text.

=cut

sub getEmbeddedStoreForm {
    my $this = shift;
    $this->{_text} ||= '';

    require Foswiki::Store;    # for encoding

    my $text = $this->_writeTypes( 'TOPICINFO', 'TOPICPARENT' );
    $text .= $this->{_text};
    my $end =
      $this->_writeTypes( 'FORM', 'FIELD', 'FILEATTACHMENT', 'TOPICMOVED' )
      . $this->_writeTypes(
        'not',   'TOPICINFO',      'TOPICPARENT', 'FORM',
        'FIELD', 'FILEATTACHMENT', 'TOPICMOVED'
      );
    $text .= "\n" if $end;
    return $text . $end;
}

# PRIVATE STATIC Write a meta-data key=value pair
# The encoding is reversed in _readKeyValues
sub _writeKeyValue {
    my ( $key, $value ) = @_;

    if ( defined($value) ) {
        $value = dataEncode($value);
    }
    else {
        $value = '';
    }

    return $key . '="' . $value . '"';
}

# PRIVATE STATIC: Write all the key=value pairs for the types listed
sub _writeTypes {
    my ( $this, @types ) = @_;

    my $text = '';

    if ( $types[0] eq 'not' ) {

        # write all types that are not in the list
        my %seen;
        @seen{@types} = ();
        @types = ();    # empty "not in list"
        foreach my $key ( keys %$this ) {
            push( @types, $key )
              unless ( exists $seen{$key} || $key =~ /^_/ );
        }
    }

    foreach my $type (@types) {
        my $data = $this->{$type};
        foreach my $item (@$data) {
            my $sep = '';
            $text .= '%META:' . $type . '{';
            my $name = $item->{name};
            if ($name) {

      # If there's a name field, put first to make regexp based searching easier
                $text .= _writeKeyValue( 'name', $item->{name} );
                $sep = ' ';
            }
            foreach my $key ( sort keys %$item ) {
                if ( $key ne 'name' ) {
                    $text .= $sep;
                    $text .= _writeKeyValue( $key, $item->{$key} );
                    $sep = ' ';
                }
            }
            $text .= '}%' . "\n";
        }
    }

    return $text;
}

=begin TML

---++ ObjectMethod setEmbeddedStoreForm( $text )

Populate this object with embedded meta-data from $text. This method
is a utility provided for use with stores that store data embedded in
topic text. Only valid on topics.

Note: line endings must be normalised to \n *before* calling this method.

=cut

sub setEmbeddedStoreForm {
    my ( $this, $text ) = @_;

    my $format = $EMBEDDING_FORMAT_VERSION;

    # head meta-data
    $text =~ s/^%META:TOPICINFO{(.*)}%\n/
      $this->put( 'TOPICINFO', _readKeyValues( $1 ));''/gem;

    my $ti = $this->get('TOPICINFO');
    if ($ti) {
        $format = $ti->{format} || 0;

        # Make sure we update the topic format for when we save
        $ti->{format} = $EMBEDDING_FORMAT_VERSION;

        # add the rev derived from version=''
        if ( $ti->{version} ) {
            $ti->{version} =~ /\d*\.(\d*)/;
            $ti->{rev} = $1;
        }
        else {
            $ti->{version} = $ti->{rev} = 0;
        }
    }

    # Other meta-data
    my $endMeta = 0;
    if ( $format < 1.1 ) {
        require Foswiki::Compatibility;
        if (
            $text =~ s/^%META:([^{]+){(.*)}%\n/
              Foswiki::Compatibility::readSymmetricallyEncodedMETA(
                  $this, $1, $2 ); ''/gem
          )
        {
            $endMeta = 1;
        }
    }
    else {
        if (
            $text =~ s/^%META:([^{]+){(.*)}%\n/
              $this->_readMETA($1, $2, $format); ''/gem
          )
        {
            $endMeta = 1;
        }
    }

    # eat the extra newline put in to separate text from tail meta-data
    $text =~ s/\n$//s if $endMeta;

    # If there is no meta data then convert from old format
    if ( !$this->count('TOPICINFO') ) {
        if ( $text =~ /<!--FoswikiAttachment-->/ ) {
            require Foswiki::Compatibility;
            $text = Foswiki::Compatibility::migrateToFileAttachmentMacro(
                $this->{_session}, $this, $text );
        }

        if ( $text =~ /<!--FoswikiCat-->/ ) {
            require Foswiki::Compatibility;
            $text =
              Foswiki::Compatibility::upgradeCategoryTable( $this->{_session},
                $this->{_web}, $this->{_topic}, $this, $text );
        }
    }
    elsif ( $format eq '1.0beta' ) {
        require Foswiki::Compatibility;

        # This format used live at DrKW for a few months
        if ( $text =~ /<!--FoswikiCat-->/ ) {
            $text =
              Foswiki::Compatibility::upgradeCategoryTable( $this->{_session},
                $this->{_web}, $this->{_topic}, $this, $text );
        }
        Foswiki::Compatibility::upgradeFrom1v0beta( $this->{_session}, $this );
        if ( $this->count('TOPICMOVED') ) {
            my $moved = $this->get('TOPICMOVED');
            $this->put( 'TOPICMOVED', $moved );
        }
    }

    if ( $format < 1.1 ) {

        # compatibility; topics version 1.0 and earlier equivalenced tab
        # with three spaces. Respect that.
        $text =~ s/\t/   /g;
    }

    $this->{_text} = $text;
}

sub _readMETA {
    my ( $this, $type, $args, $format ) = @_;

    my $keys = _readKeyValues($args);
    if ( defined( $keys->{name} ) ) {

        # save it keyed if it has a name
        $this->putKeyed( $type, $keys );
    }
    else {
        $this->put( $type, $keys );
    }
    return 1;
}

# STATIC Build a hash by parsing name=value comma separated pairs
# SMELL: duplication of Foswiki::Attrs, using a different
# system of escapes :-(
sub _readKeyValues {
    my ($args) = @_;
    my %res;

    # Format of data is name='value' name1='value1' [...]
    $args =~ s/\s*([^=]+)="([^"]*)"/
      $res{$1} = dataDecode( $2 ), ''/ge;

    return \%res;
}

=begin TML

---++ StaticMethod dataEncode( $uncoded ) -> $coded

Encode meta-data field values, escaping out selected characters.
The encoding is chosen to avoid problems with parsing the attribute
values in embedded meta-data, while minimising the number of
characters encoded so searches can still work (fairly) sensibly.

The encoding has to be exported because Foswiki (and plugins) use
encoded field data in other places e.g. RDiff, mainly as a shorthand
for the properly parsed meta object. Some day we may be able to
eliminate that....

=cut

sub dataEncode {
    my $datum = shift;

    $datum =~ s/([%"\r\n{}])/'%'.sprintf('%02x',ord($1))/ge;
    return $datum;
}

=begin TML

---++ StaticMethod dataDecode( $encoded ) -> $decoded

Decode escapes in a string that was encoded using dataEncode

The encoding has to be exported because Foswiki (and plugins) use
encoded field data in other places e.g. RDiff, mainly as a shorthand
for the properly parsed meta object. Some day we may be able to
eliminate that....

=cut

sub dataDecode {
    my $datum = shift;

    $datum =~ s/%([\da-f]{2})/chr(hex($1))/gei;
    return $datum;
}

1;

__DATA__

Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/, http://Foswiki.org/

Copyright (C) 2008-2009 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2001-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
