#---+ Extensions
#---++ DBIStoreContrib
# **STRING 120**
# DBI DSN to use to connect to the database.
$Foswiki::cfg{Extensions}{DBIStoreContrib}{DSN} = 'dbi:SQLite:dbname=$Foswiki::cfg{WorkingDir}/dbcache';
# **STRING 80**
# Username to use to connect to the database.
$Foswiki::cfg{Extensions}{DBIStoreContrib}{Username} = '';
# **STRING 80**
# Password to use to connect to the database.
$Foswiki::cfg{Extensions}{DBIStoreContrib}{Password} = '';
# **STRING 80**
# Plugin module name (required on Foswiki 1.1 and earlier)
$Foswiki::cfg{Plugins}{DBIStorePlugin}{Module} = 'Foswiki::Plugins::DBIStorePlugin';
# **BOOLEAN**
# Plugin enable switch (required on Foswiki 1.1 and earlier)
$Foswiki::cfg{Plugins}{DBIStorePlugin}{Enabled} = 0;
# **STRING 80**
# Where to find the PCRE library for SQLite. Only used by SQLite. It is
# installed on Debian Linux using apt-get install sqlite3-pcre
# (or similar on other systems).
$Foswiki::cfg{Extensions}{DBIStoreContrib}{SQLite}{PCRE} = '/usr/lib/sqlite3/pcre.so';
#  **BOOLEAN**
# Set to true to automatically create new tables when unregistered META is
# encountered in topic text. This should not normally be required, as plugins
# should register all META that they create. Note that only META:NAME where
# NAME matches /^[A-Z][A_Z0-9_]+$/ will be loaded.
$Foswiki::cfg{Extensions}{DBIStoreContrib}{AutoloadUnknownMETA} = 0;
# **PERL**
# If a column isn't found in the schema, it will use the _DEFAULT type.
# You should extend this table as required by extra meta-data found in
# your wiki.
# If an entry for a column is a string starting with an underscore,
# that string will be used as an index to get the 'real' schema for
# the column.
# The pseudo-type _DEFAULT must exist and must be a text type.
# If {index} is true, then an index will be created for that column.
# If {truncate_to} is set to a length, then the value of that field
# stored in the DB will be truncated to that length. This only affects
# searching. If truncate_to is not set, then trying to store a value
# longer than the field accepts will be an error.
$Foswiki::cfg{Extensions}{DBIStoreContrib}{Schema} = {
    _DEFAULT => { type => 'TEXT' },
    _USERNAME => { type => 'VARCHAR(64)', index => 1 },
    _DATE => { type => 'VARCHAR(32)' },
    topic => {
        web  => { type => 'VARCHAR(256)', index => 1 },
        name => { type => 'VARCHAR(128)', index => 1 },
        text => '_DEFAULT',
        raw  => '_DEFAULT'
        },
    metatypes => {
        name => { type => 'VARCHAR(63)', index => 1 },
        },
    TOPICINFO => {
        author => '_USERNAME',
        version => { type => 'VARCHAR(256)' },
        date => '_DATE',
        format => { type => 'VARCHAR(32)' },
        reprev => { type => 'VARCHAR(32)' },
        rev => { type => 'VARCHAR(32)' },
        comment => { type => 'VARCHAR(512)' },
        encoding => { type => 'VARCHAR(32)' },
    },
    TOPICMOVED => {
        from => { type => 'VARCHAR(256)' },
        to => { type => 'VARCHAR(256)' },
        by => { type => 'VARCHAR(256)' },
        date => '_DATE',
    },
    TOPICPARENT => {
        name => { type => 'VARCHAR(256)', index => 1 },
    },
    FILEATTACHMENT => {
        name => { type => 'VARCHAR(256)', index => 1 },
        version => { type => 'VARCHAR(32)' },
        path => { type => 'VARCHAR(256)' },
        size => { type => 'VARCHAR(32)' },
        date => '_DATE',
        user => '_USERNAME',
        comment => { type => 'VARCHAR(512)', truncate_to => 512 },
        attr => { type => 'VARCHAR(32)' },
    },
    FORM => {
        name => { type => 'VARCHAR(256)', index => 1 },
    },
    FIELD => {
        name => { type => 'VARCHAR(128)', index => 1 },
        value => { type => 'VARCHAR(512)', index => 1, truncate_to => 512 },
        title => { type => 'VARCHAR(256)' },
    },
    PREFERENCE => {
        name => { type => 'VARCHAR(64)', index => 1 },
        value => _DEFAULT,
        type => { type => 'VARCHAR(32)' },
    }
};

