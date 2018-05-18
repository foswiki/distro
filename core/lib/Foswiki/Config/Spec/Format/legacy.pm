# See bottom of file for license and copyright information

# This module would reimplement Configure's LoadSpec module parsing code to keep
# it as compatible with the original code as possible.

package Foswiki::Config::Spec::Format::legacy::SpecItem;

use Foswiki;

use Foswiki::Class -types;
extends qw(Foswiki::Object);

# We took this here because it is expected to be gone from Foswiki::Config as
# obsolete. The legacy format is to be obsoleted, this is why...
our $ITEMREGEX =
  qr/(?:\{(?:'(?:\\.|[^'])+'|"(?:\\.|[^"])+"|[A-Za-z0-9_\.]+)\})+/;

has data => (
    is      => 'ro',
    lazy    => 1,
    clearer => 1,
    builder => 'prepareData',
);

has name => (
    is      => 'rw',
    builder => 'prepareName',
);

has optSpecs => (
    is      => 'ro',
    assert  => HashRef,
    builder => 'prepareOptSpecs',
);

has optionsStr => (
    is      => 'rw',
    builder => 'prepareOptionsStr',
);

has dataIdx => (
    is        => 'ro',
    lazy      => 1,
    clearer   => 1,
    predicate => 1,
    builder   => 'prepareDataIdx',
);

# Hash of arities of item options. Each successor must define this attribute.
has itemOptArities => (
    is      => 'ro',
    builder => 'prepareItemOptArities',
);

sub prepareData {
    my $this = shift;
    return [];
}

sub prepareName {
    return undef;
}

sub prepareOptSpecs {
    return {};
}

sub prepareOptionsStr {
    return '';
}

sub prepareDataIdx {
    my $this = shift;

    # Map list of options into a hash.
    my $data = $this->data;
    return { map { my $idx = $_ * 2; $data->[$idx] => $idx }
          0 .. ( $#{ $this->data } / 2 ) };
}

sub prepareItemOptArities {
    return undef;
}

sub addOpts {
    my $this = shift;

    Foswiki::Exception::Fatal->throw(
        text => "Odd number of elements in options array" )
      unless @_ % 2 == 0;

    push @{ $this->data }, @_;
    $this->clear_dataIdx;
}

# Returns an option value from the data attribute.
sub opt {
    my $this    = shift;
    my $optName = shift;
    my $idx     = $this->dataIdx->{$optName};
    return undef unless defined $idx;
    return $this->data->[ $idx + 1 ];
}

# Adds text to the text option.
sub appendText {
    my $this = shift;

    my $idx = $this->dataIdx->{-text};
    my $text = join( '', @_ );

    if ( defined $idx ) {
        $this->data->[ $idx + 1 ] .= "\n" . $text;
    }
    else {
        $this->addOpts( -text => $text );
    }
}

sub data2spec {
    my $this = shift;

    my @specData;
    my $arities = $this->itemOptArities;

    if ( defined $arities ) {
        my $data = $this->data;
        my @sData;
        foreach my $i ( 0 .. ( @$data / 2 - 1 ) ) {
            my $idx = $i * 2;
            my ( $opt, $val ) = @{$data}[ $idx, $idx + 1 ];
            $opt =~ /^-(?<optName>.+)$/;
            if ( defined $arities->{ $+{optName} }
                && $arities->{ $+{optName} } == 0 )
            {
                $opt =~ s/^-/-no/ unless $val;
                push @sData, $opt;
            }
            else {
                push @sData, $opt, $val;
            }
        }
        push @specData, \@sData;
    }
    else {
        # If class is not defined then use data as-is. Most likely it would
        # produce an acceptable definition for a key.
        push @specData, $this->data;
    }

    return @specData;
}

# Returns a list suitable to be pushed onto the specs list.
sub asSpec {
    my $this = shift;

    $this->parseOptions;

    return ( $this->name, $this->data2spec );
}

sub preParseOptions {
    my $this = shift;
    my ($options) = @_;
    return $options;
}

sub parseOptions {
    my $this = shift;

    my $options = $this->optionsStr;

    return unless defined($options) && length($options);

    my ( $file, $line ) = @{ $this->opt('-source') }{qw(file line)};

    $options = $this->preParseOptions($options);

    my @opts;

    while ( $options =~ s/^\s*(?<keyName>[A-Za-z0-9_]+)// ) {
        my $key       = $+{keyName};
        my $optSpecs  = $this->optSpecs;
        my $boolValue = !( $key =~ s/^NO// );

        # Process aliases. Aliases could be chained.
        while ( $optSpecs->{$key} && !ref( $optSpecs->{$key} ) ) {
            $key = $optSpecs->{$key};
        }

        Foswiki::Exception::Config::Spec::Format::legacy::BadOption->throw(
            text => "Unknown option '$key' in definition of '"
              . $this->name . "'",
            srcFile => $file,
            srcLine => $line,
        ) unless defined $optSpecs->{$key};

        my $optSpec = $optSpecs->{$key};
        my $optVal;

        if ( $options =~ s/^\s*=// ) {
            if (
                $options =~ s{
                    ^\s*
                    (?:
                        (["'])(?<val>.*?[^\\])\1 # =string
                        |
                        (?<val>[A-Z0-9]+) # =keyword or number
                    )
                }
                []x
              )
            {

                $optVal = $+{val};
            }
            else {
                Foswiki::Exception::Config::Spec::Format::legacy::BadOption
                  ->throw(
                    text => "Parse error of option '" . $key . "': bad value",
                    srcFile => $file,
                    srcLine => $line,
                  );
            }
        }
        elsif ( $optSpec->{openclose} ) {
            $options =~ s/^(?<val>.*?)(\/$key|$)//;
            $optVal = $+{val};
        }
        else {
            $optVal = $boolValue;
        }

        if ( $optSpec->{handler} ) {
            my $fn = $optSpec->{handler};

            # See if checker defined by its symbolic name, not code ref.
            unless ( ref($fn) ) {
                $fn = $this->can($fn);
            }

            Foswiki::Exception::Fatal->throw(
                text => "Cannot find handler method for spec option '$key'" )
              unless $fn;

            $optVal = $fn->( $this, $key, $optVal );
        }

        my $optName = '-' . lc($key);
        push @opts, $optName, $optVal;
    }

    Foswiki::Exception::Fatal->throw(
            text => "Incompletely parsed options, left-over string: '"
          . $options
          . "'", )
      if defined($options) && length($options);

    $this->addOpts(@opts);
}

package Foswiki::Config::Spec::Format::legacy::Section;

require Foswiki::Config::Section;

use Foswiki::Class;
extends qw(Foswiki::Config::Spec::Format::legacy::SpecItem);

has level => (
    is       => 'rw',
    required => 1,
);

around asSpec => sub {
    my $orig = shift;
    my $this = shift;

    return ( -section => $orig->( $this, @_ ) );
};

around prepareOptSpecs => sub {
    my $orig = shift;
    my $this = shift;

    return {
        %{ $orig->( $this, @_ ) },
        EXPERT => {},
        SORTED => {},
    };
};

around prepareItemOptArities => sub {
    my %arities = Foswiki::Config::Section->optArities;
    return \%arities;
};

package Foswiki::Config::Spec::Format::legacy::Value;

require Foswiki::Config::Node;
use Foswiki::Config::DataHash;

use Foswiki::Class;
extends qw(Foswiki::Config::Spec::Format::legacy::SpecItem);

around prepareOptSpecs => sub {
    my $orig = shift;
    my $this = shift;

    return {
        %{ $orig->( $this, @_ ) },
        CHECK           => { handler   => '_CHECK' },
        CHECKER         => {},
        CHECK_ON_CHANGE => {},
        DISPLAY_IF      => { openclose => 1 },
        ENABLE_IF       => { openclose => 1 },
        EXPERT          => {},
        FEEDBACK        => { handler   => '_FEEDBACK' },
        HIDDEN          => {},
        MULTIPLE        => {},         # Allow multiple select
        SPELLCHECK      => {},
        LABEL           => {},
        ONSAVE          => {},         # Call Checker->onSave() when set.

        # Rename single character options (legacy)
        H => 'HIDDEN',
        M => { handler => '_MANDATORY' },
    };
};

around prepareItemOptArities => sub {
    my $orig = shift;
    my $this = shift;

    my $type = $this->opt('-type');

    my $nodeClass = Foswiki::Config::DataHash::NODE_CLASS;
    my $itemClass = $nodeClass->type2class($type) // $nodeClass;
    my %arities   = $itemClass->optArities if $itemClass;

    return \%arities;
};

around preParseOptions => sub {
    my $orig = shift;
    my $this = shift;
    my ($options) = $orig->( $this, @_ );

    my $type = $this->opt('-type');

    Foswiki::Exception::Config::Spec::Format::legacy::BadOption->throw(
        text => 'Attempt to parse options on incomplete legacy spec item',
        %{ $this->opt('-source') },
    ) unless $type;

    my $preParser = 'preparse_' . $type;

    if ( $this->can($preParser) ) {
        $options = $this->$preParser($options);
    }

    return $options;
};

my %rename_options = ( nullok => 'undefok' );

# Legal options for a CHECK. The number indicates the number of expected
# parameters; -1 means '0 or more'
my %CHECK_options = (
    also     => -1,    # List of other items to check when this is changed
    authtype => 1,     # for URLs
    filter   => 1,     # filter exclude files when checking file permissions
    iff      => 1,     # perl condition controlling when to check
    max      => 1,     # max value
    min      => 1,     # min value
    trail    => 0,     # ignore trailing / when checking URL
    undefok  => 0,     # is undef OK?
    emptyok  => 0,     # is '' OK?
    parts    => -1,    # for URL
    partsreq => -1,    # for URL
    perms    => -1,    # file permissions
    schemes  => -1,    # for URL
    user     => -1,    # for URL
    pass     => -1,    # for URL
);

# Return a list suitable to be pushed onto the specs list.
around data2spec => sub {
    my $orig = shift;
    my $this = shift;

    my $type = $this->opt('-type') || 'STRING';

    return ( $type, $orig->( $this, @_ ) );
};

sub _CHECK {
    my $this = shift;
    my ( $key, $val ) = @_;

    my $opts = $val;
    $opts =~ s/^(["'])\s*(.*?)\s*\1$/$2/;

    my ( $file, $line ) = @{ $this->opt('-source') }{qw(file line)};

    my %checkOpts;
    while ( $opts =~ s/^\s*(?<name>[a-zA-Z][a-zA-Z0-9]*)// ) {
        my $name = $+{name};
        my $set = !( $name =~ s/^no// );

        $name = $rename_options{$name} if exists $rename_options{$name};
        Foswiki::Exception::Config::Spec::Format::legacy::BadOption->throw(
            text    => "Parse of '$key' failed: unrecognized option '$name'",
            srcFile => $file,
            srcLine => $line,
        ) unless defined $CHECK_options{$name};

        my @opts;
        if ( $opts =~ s/^\s*:\s*// ) {
            do {
                if (
                    $opts =~ s{
                        ^(?:
                          (?<quot>["'])(?<opt>.*?[^\\])\g{quot}
                          |
                          (?<opt>[-+]?\d+)
                          |
                          (?<opt>(?i)[a-z_{}]+)
                        )
                    }
                    []x
                  )
                {
                    push @opts, $+{opt};
                }
                else {
                    Foswiki::Exception::Config::Spec::Format::legacy::BadOption
                      ->throw(
                        text =>
                          "'$key' parse failed: not a list at $opts in $val",
                        srcFile => $file,
                        srcLine => $line,
                      );
                }
            } while ( $opts =~ s/^\s*,\s*// );
        }

        if ( $CHECK_options{$name} >= 0
            && scalar(@opts) != $CHECK_options{$name} )
        {
            Foswiki::Exception::Config::Spec::Format::legacy::BadOption->throw(
                text => "'$key' parse failed: wrong number of params to '"
                  . $name
                  . "' (expected $CHECK_options{$name}, saw "
                  . scalar @opts . ")",
                srcFile => $file,
                srcLine => $line,
            );
        }
        if ( !$set && scalar(@opts) != 0 ) {
            Foswiki::Exception::Config::Spec::Format::legacy::BadOption->throw(
                text    => "'$key' parse failed: 'no$name' is not allowed",
                srcFile => $file,
                srcLine => $line,
            );
        }

        if ( !@opts ) {
            $checkOpts{$name} = $set;
        }
        else {
            $checkOpts{$name} = \@opts;
        }
    }
    Foswiki::Exception::Config::Spec::Format::legacy::BadOption->throw(
        text    => "'$key' parse failed, expected name at '$opts' in $val",
        srcFile => $file,
        srcLine => $line,
    ) if $opts !~ /^\s*$/;

    return \%checkOpts;
}

sub _FEEDBACK {
    my $this = shift;
    my ( $key, $val ) = @_;

    my $opts = $val;

    my %fb;
    while ( $opts =~ s/^\s*(?<attr>[a-z]+)\s*=\s*// ) {

        my $attr = $+{attr};

        if (
            $opts =~ s{
                ^(?:
                  (?<opt>\d+)  # name=number
                  |
                  (?<quot>["'])(?<opt>.*?[^\\])\g{quot} # name=string
                 )
                }
                []x
          )
        {
            $fb{$attr} = $+{opt};
        }

        last unless $opts =~ s/^\s*;//;
    }

    my $srcOpt = $this->opt('-source');
    Foswiki::Exception::Config::Spec::Format::legacy::BadOption->throw(
        text    => "'$key' parse failed, at '$opts' in $val",
        srcFile => $srcOpt->{file},
        srcLine => $srcOpt->{line},
    ) unless $opts =~ m/^\s*$/;

    return \%fb;
}

sub _preparse_length {
    my $this    = shift;
    my $options = shift;

    if ( $options =~ s/^\s*(\d+(?:x\d+)?)// ) {
        $this->addOpts( -size => $1 );
    }
    return $options;
}

sub _preparse_selectlist {
    my $this    = shift;
    my $options = shift;

    my @picks;
    do {
        if ( $options =~ s/^(["'])(.*?)\1// ) {
            push( @picks, $2 );
        }
        elsif ( $options =~ s/^([-A-Za-z0-9:.*]+)// || $options =~ m/(\s)*,/ ) {
            my $v = $1;
            $v = '' unless defined $v;
            if ( $v =~ m/\*/ && $this->opt('-type') eq 'SELECTCLASS' ) {

                # Rely upon the Configure code for a while.
                Foswiki::load_package('Foswiki::Configure::FileUtil');

                # Populate the class list
                push( @picks, Foswiki::Configure::FileUtil::findPackages($v) );
            }
            else {
                push( @picks, $v );
            }
        }
        else {
            Foswiki::Exception::Fatal->throw(
                text => "Illegal .spec at '$options'" );
        }
    } while ( $options =~ s/\s*,\s*// );
    $this->addOpts( -select_from => \@picks );

    return $options;
}

# Setup pre-parse subs for each type corresponding to roles it does. Type
# definitions are taken from node class.
my $nodeClass     = Foswiki::Config::DataHash::NODE_CLASS;
my $roleNS        = $nodeClass->ROLE_NAMESPACE;
my %role2preparse = (
    $roleNS . 'Size'   => \&_preparse_length,
    $roleNS . 'Select' => \&_preparse_selectlist,
);
foreach my $type ( sort $nodeClass->getAllTypes ) {
    my $typeClass = $nodeClass->type2class($type);
    my $preSub;
    foreach my $role ( keys %role2preparse ) {
        if ( $typeClass->does($role) ) {
            $preSub = $role2preparse{$role};
            last;
        }
    }

    if ($preSub) {
        no strict 'refs';
        *{ "preparse_" . $type } = $preSub;
        use strict 'refs';
    }
}

#foreach my $type (
#    qw(COMMAND PASSWORD PATH REGEX STRING NUMBER EMAILADDRESS URL URLPATH PERL))
#{
#    no strict 'refs';
#    *{ "preparse_" . $type } = \&_preparse_length;
#    use strict 'refs';
#}
#
#foreach my $type (qw(SELECT BOOLGROUP SELECTCLASS)) {
#    no strict 'refs';
#    *{ "preparse_" . $type } = \&_preparse_selectlist;
#    use strict 'refs';
#}

# Exception names look scary but this is to keep their uniqueness guaranteed.

# Flow is the base for all parser flow control exceptions.
package Foswiki::Exception::Config::Spec::Format::legacy::Flow;

use Foswiki::Class;
extends qw(Foswiki::Exception::Config);
with qw(Foswiki::Exception::Harmless);

# UpSection is to signal when to cancel processing and return control to the
# upper level stack frame.
package Foswiki::Exception::Config::Spec::Format::legacy::UpSection;

use Foswiki::Class;
extends qw(Foswiki::Exception::Config::Spec::Format::legacy::Flow);

# Repeat is to restart current line loop.
package Foswiki::Exception::Config::Spec::Format::legacy::Repeat;

use Foswiki::Class;
extends qw(Foswiki::Exception::Config::Spec::Format::legacy::Flow);

# Last commands to exit loop.
package Foswiki::Exception::Config::Spec::Format::legacy::Last;

use Foswiki::Class;
extends qw(Foswiki::Exception::Config::Spec::Format::legacy::Flow);

# Unknown option in a spec definition.
package Foswiki::Exception::Config::Spec::Format::legacy::BadOption;

use Foswiki::Class;
extends qw(Foswiki::Exception::Config::BadSpecSrc);

package Foswiki::Config::Spec::Format::legacy;

use Try::Tiny;
use Foswiki qw($TRUE $FALSE);

use Foswiki::Class -app;
extends qw(Foswiki::Object);
with qw(Foswiki::Config::Spec::Parser Foswiki::Config::CfgObject);

has specSrc => (
    is      => 'rw',
    trigger => 1,
    coerce  => sub {
        if ( ref( $_[0] ) eq 'ARRAY' ) {
            return $_[0];
        }
        else {
            return [ split /^/m, $_[0] ];
        }
    },
    trigger => 1,
);
has specLines => (
    is      => 'ro',
    clearer => 1,
    lazy    => 1,
    builder => 'prepareSpecLines',
);
has nextLine => (
    is      => 'rw',
    lazy    => 1,
    clearer => 1,
    builder => 'prepareNextLine',
);
has recordedLine => (
    is        => 'rw',
    clearer   => 1,
    predicate => 1,
);

# Specs file object supplied to the parse() method.
has _specFile => (
    is       => 'rw',
    weak_ref => 1,
);

# Spec defaults hash.
has _specDef => (
    is      => 'rw',
    builder => '_prepareSpecDef',
);

sub readLine {
    my $this     = shift;
    my $nextLine = $this->nextLine;
    return undef if $nextLine >= $this->specLines;
    my $line = $this->specSrc->[$nextLine];
    $this->nextLine( $nextLine + 1 );
    return $line;
}

# Records current line
sub recordLine {
    my $this = shift;

    $this->recordedLine( $this->nextLine );
    return $this->readLine;
}

# Restore last recorded line pos. Used when need to rescan already parsed portion.
sub restoreLine {
    my $this = shift;
    Foswiki::Exception::Fatal->throw( text =>
          "Cannot restore line position: no previously recorded line number!" )
      unless $this->has_recordedLine;
    $this->nextLine( $this->recordedLine );
    $this->clear_recordedLine;
}

sub _makeItem {
    my $this = shift;

    # Class could be empty for SpecItem or short form like Section.
    my $class = shift;

    $class =
      'Foswiki::Config::Spec::Format::legacy::' . ( $class || 'SpecItem' );

    my %profile = @_;

    $profile{data} //= [];

    unshift @{ $profile{data} }, -source => {
        file => $this->_specFile->path,

        # Make it human-readable base-1. For aux items created before any
        # processing started line -1 would mean exactly this.
        line => ( $this->recordedLine // -2 ) + 1,
    };

    my $item = $this->create( $class, %profile, );

    return $item;
}

sub _addItem2Specs {
    my $this   = shift;
    my $status = shift;

    my $specItem  = $status->{specItem};
    my $isSection = $this->_isSectionItem($status);

    push @{ $status->{specs} }, $specItem->asSpec if $specItem;

    $this->_closeItem($status);

    if ($isSection) {

        # We've just pushed a new section to the specs and hit a declaration
        # which belongs to this section.
        $this->restoreLine;

        # The last item of specs array is always section subspecs at this point.
        $this->_sectionParse(
            section => $specItem,
            specs   => $status->{specs}->[-1],
        );
        Foswiki::Exception::Config::Spec::Format::legacy::Repeat->throw;
    }

    if ( $status->{nextSection} ) {

        my $curLevel  = $status->{section}->level;
        my $nextLevel = $status->{nextSection}->level;

        if ( $nextLevel <= $curLevel ) {

            # This is same or upper level section we've reached. Must be
            # processed by higher-level stack frame.
            $this->restoreLine;
            Foswiki::Exception::Config::Spec::Format::legacy::UpSection->throw;
        }

        # There must be no skipped section levels. I.e. it must not be
        # possible to have '---+++' defined right next to '---+'. It
        # would break UI if I get it correctly.
        if ( ( $nextLevel - 1 ) > $curLevel ) {
            Foswiki::Exception::Config::BadSpecSrc->throw(
                srcFile => $this->_specFile,
                srcLine => $this->nextLine,
                text    => "Missing section level "
                  . ( $nextLevel - 1 )
                  . " before level "
                  . $nextLevel
                  . " section `"
                  . $status->{nextSection}->name
                  . "' declaration.",
            );
        }
    }
}

sub _closeItem {
    my $this   = shift;
    my $status = shift;

    undef $status->{specItem};
    undef $status->{isEnhancing};
}

sub _checkItemComplete {
    my $this   = shift;
    my $status = shift;

    if ( $status->{specItem} && !$status->{isEnhancing} ) {
        unless ( $status->{nextSection} || $this->_isSectionItem($status) ) {

            # SMELL or TBD Must be replaced with a non-destructive messaging. A
            # broken spec must not break the app. Though we might consider
            # ignoring the spec as well.
            Foswiki::Exception::Config::BadSpecSrc->throw(
                srcFile => $this->_specFile,
                srcLine => $this->nextLine,
                text    => "Incomplete definition",
            );
        }
    }
    $this->_addItem2Specs($status);
}

sub _isSectionItem {
    my $this   = shift;
    my $status = shift;

    return $status->{specItem}
      && $status->{specItem}
      ->isa('Foswiki::Config::Spec::Format::legacy::Section');
}

# Converts key path in legacy form (which is a list of keys enclosed in curly
# braces) into an arrayref which is the new form.
sub _purifyKeyPath {
    my $this    = shift;
    my $keyPath = shift;

    my ( $h, @keyPath );

    eval "\$h->$keyPath=1";

    while ( ref $h ) {
        my $key = ( keys %$h )[0];
        Foswiki::Exception::Config::BadSpecSrc->throw(
            srcFile => $this->_specFile,
            secLine => $this->nextLine,
            text    => "Key name '$key' cannot contain a dot",
        ) if $key =~ /\./;
        push @keyPath, $key;
        $h = $h->{$key};
    }

    return \@keyPath;
}

sub _sectionParse {
    my $this   = shift;
    my %params = @_;

    my $cfg = $this->cfg;

    my $status = {
        section => $params{section}
          || $this->_makeItem( 'Section', level => 0, name => 'Root', ),
        specs => $params{specs} || $params{section}->data,
        isEnhancing => undef,
        specItem    => undef,
        itemText    => undef,
    };

    my ($specItem);

    my $specDef = $this->_specDef;

    my $exception;

    while ( defined( my $l = $this->recordLine ) ) {

        try {
            chomp $l;

            undef $exception;

            while ( $l =~ s/\\$// ) {
                my $cont = $this->readLine;
                last unless defined $cont;
                chomp $cont;
                $cont =~ s/^#// if ( $l =~ m/^#/ );
                $cont =~ s/^\s+/ /;
                if ( $cont =~ m/^#/ ) {
                    $l .= '\\';
                }
                else {
                    $l .= $cont;
                }
            }

            Foswiki::Exception::Config::Spec::Format::legacy::Last->throw
              if ( $l =~ m/^(1;|__[A-Z]+__)/ );
            Foswiki::Exception::Config::Spec::Format::legacy::Repeat->throw
              if ( $l =~ m/^\s*$/ || $l =~ m/^\s*#!/ );

            if ( $l =~
                m/^#\s*\*\*\s*(?<type>[A-Z]+)\s+(?<options>.*?)\s*\*\*\s*$/ )
            {
                my ( $type, $opts ) = @+{qw(type options)};

                if ( $status->{specItem} && !$status->{isEnhancing} ) {
                    $this->_addItem2Specs($status);
                }

                if ( $type eq 'ENHANCE' ) {

                    # LoadSpec determines if we're really enhancing an already
                    # defined spec by trying to load it. The new paradigm
                    # doesn't allow us to go this way because specs could be
                    # loaded from a single file without accessing others where
                    # the spec could have been defined. It is up to the Config
                    # core to determine if we really deal with enhancing.
                    $status->{specItem} = $this->_makeItem(
                        'Value',
                        name => $opts,
                        data => [ -type => 'VOID', -enhance => 1, ],
                    );
                    $status->{isEnhancing} = $TRUE;

# As ENHANCE receives the only option which is a key name, $opts must be voided.
                    $opts = '';
                }
                else {
                    unless (
                        Foswiki::Config::DataHash->NODE_CLASS->knownType($type)
                      )
                    {
                        Foswiki::Exception::Config::BadSpecSrc->throw(
                            srcFile => $this->_specFile,
                            secLine => $this->nextLine,
                            text    => "Unknown spec type '" . $type . "'",
                        );
                    }

                    $status->{specItem} =
                      $this->_makeItem( 'Value', data => [ -type => $type ] );
                }

                $status->{specItem}->optionsStr($opts);
            }
            elsif ( $l =~
m/^(?<optional>#)?\s*\$(?:(?:Fosw|TW)iki::)?cfg(?<keyPath>[^=\s]*)\s*=\s*(.*?)$/
              )
            {
                my ( $keyPath, $optional ) = @+{qw(keyPath optional)};

                unless ( $keyPath =~ /$ITEMREGEX/ ) {

                    # XXX TODO report error here when bufferized messaging is in
                    # place.
                    $this->_closeItem($status);
                    Foswiki::Exception::Config::Spec::Format::legacy::Repeat
                      ->throw;
                }

                $keyPath = $this->_purifyKeyPath($keyPath);

                # Push section on specs list if we're in section declaration
                # now.
                if ( $this->_isSectionItem($status) ) {
                    $this->_addItem2Specs($status);
                }
                elsif ( !$status->{specItem} ) {
                    $status->{specItem} = $this->_makeItem('Value');
                }

                # XXX LoadSpec checks for entries added by pluggables. Seems
                # like if the keyPath has been added previously then no other
                # processing is done on it. This kind of check is not possible
                # here because pluggables are to be executed by Foswiki::Config.
                # Perhaps they must set a kind of 'immutable' flag on
                # auto-generated items.

                my $specItem = $status->{specItem};

                my ( $subHash, $key );
                try {
                    ( $subHash, $key ) = $cfg->getSubHash(
                        $keyPath,
                        data       => $specDef,
                        autoVivify => 1,
                    );
                }
                catch {
                    my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );

                    Foswiki::Exception::Config::BadSpecSrc->throw(
                        text    => $e->stringifyText,
                        srcFile => $this->_specFile,
                        srcLine => $this->nextLine,
                    );
                };

                my $defaultVal = $subHash->{$key};

                my $itemType = $specItem->opt('-type');

                if ( $itemType && $itemType eq 'REGEX' ) {
                    if ( $defaultVal =~ m/^qr(.)(.*)\1$/
                        || ref($defaultVal) eq 'Regexp' )
                    {
                        # Convert a qr// into a quoted string
                        $defaultVal = ref($defaultVal) ? '' . $defaultVal : $1;

                        # Strip off useless furniture (?^: ... )
                        while ( $defaultVal =~ s/^\(\?\^:(.*)\)$/$1/ ) {
                        }

                        # Convert quoting for a single-quoted string. All we
                        # need to do is protect single quote
                        $defaultVal =~ s/'/\\'/g;
                        $defaultVal = "'" . $defaultVal . "'";
                    }
                    else {
                        $defaultVal =~
                          s/\\'/'/g; # unescape any escaped ' for quoted string.
                    }
                }

                $specItem->addOpts(
                    -default => $defaultVal,
                    ( $optional ? ( -optional => 1 ) : () )
                );
                $specItem->name( $cfg->normalizeKeyPath($keyPath) );

                if ( $status->{isEnhancing} ) {
                    $this->_closeItem($status);
                }
                else {
                    $this->_addItem2Specs($status);
                }
                $status->{isEnhancing} = $FALSE;
            }
            elsif ( $l =~ m/^#\s*\*([A-Z]+)\*/ ) {

                my $name = $1;

                # SMELL LoadSpec does a lot of work on checking on enhancing and
                # section/value checks. Not sure if it could be reproduced here.
                # Not even sure if it makes any sense.

                $this->_checkItemComplete($status);

                # expandable is an alias for pluggable used by LoadSpec.
                push @{ $status->{specs} }, -expandable => $name;
            }
            elsif (
                $l =~ /^\#\s*---(?<subLevel>\++)\s*
                                    (?<section>.*?)
                                    (?:(?:\s+--\s+)(?<options>.*?))?$ /x
              )
            {
                my ( $subLevel, $section, $options ) =
                  @+{qw(subLevel section options)};    # %+
                $subLevel = length($subLevel);

                $status->{nextSection} = $this->_makeItem(
                    'Section',
                    name  => $section,
                    level => $subLevel,
                );

                $this->_checkItemComplete($status);

                $status->{specItem} = $status->{nextSection};
                $status->{specItem}->optionsStr($options)
                  if $options;
                delete $status->{nextSection};

            }
            elsif ( $l =~ m/^#\s?(.*)$/ ) {

                # Bog standard comment
                # Just skip if no specItem yet – this is just file-level
                # comments.
                $status->{specItem}->appendText($1) if $status->{specItem};
            }

        }
        catch {
            my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );

            if (
                $e->isa(
                    'Foswiki::Exception::Config::Spec::Format::legacy::Flow')
              )
            {
                $exception = $e;
            }
            else {
                $e->rethrow;
            }
        };

        if ($exception) {

            # Last and UpSection exception for now do the same. But this may
            # change in the future if post-loop processing will emerge.
            last
              if $exception->isa(
                'Foswiki::Exception::Config::Spec::Format::legacy::Last')
              || $exception->isa(
                'Foswiki::Exception::Config::Spec::Format::legacy::UpSection');
            next
              if $exception->isa(
                'Foswiki::Exception::Config::Spec::Format::legacy::Repeat');
        }
    }
}

sub parse {
    my $this     = shift;
    my $specFile = shift;

    $this->_specFile($specFile);
    $this->specSrc( $specFile->content );

    # Set global %Foswiki::cfg to the data hash we're currently working with.
    # This should avoid use of undefined values by some specs referring the
    # global hash directly.
    local %Foswiki::cfg;
    $specFile->cfg->assignGLOB( $specFile->data );

    # Untaint the code.
    $specFile->content =~ /^(.*)$/s;
    my $specCode = $1;

    my (@specs);

    # Looks like it was initially thought to make some items optional. Though it
    # never made its way into the final implementation (look for $optional use
    # in LoadSpec.pm – it's not been used) but commented out defaults are not
    # ignored. For this purpose we simply remove single comment char in front of
    # $Foswiki::cfg declarations. To make them real comments one must double the
    # sharp symbol.
    $specCode =~ s/^#?\s*\$(?:(?:Fosw|TW)iki::)cfg/\$this->_specDef->/mg;

    eval $specCode;
    die $@ if $@;

    $this->_sectionParse( specs => \@specs );

    return @specs;
}

sub prepareSpecLines {
    return scalar( @{ $_[0]->specSrc } );
}

sub prepareNextLine {
    return 0;
}

sub _prepareSpecDef {
    return {};
}

sub _trigger_specSrc {
    my $this = shift;
    $this->clear_specLines;
    $this->clear_nextLine;
    $this->clear_recordedLine;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2016-2017 Foswiki Contributors. Foswiki Contributors
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
