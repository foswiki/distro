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
# Note that searching fiels that are created 'on the fly' is potentially
# risky, as if the field is missing from a topic it will not be present
# in the table, so finding topics without that field becomes tricky.
# It is always better to register META.
$Foswiki::cfg{Extensions}{DBIStoreContrib}{AutoloadUnknownMETA} = 0;
# **PERL**
# Specify how to construct the database. Each table is given with a
# list of the columns and their data types.
# If a column isn't found in the schema, it will use the _DEFAULT type.
# You should extend this table as required by extra meta-data found in
# your wiki.
# If an entry for a column is a string starting with an underscore,
# that string will be used as an index to get the 'real' schema for
# the column.
# If {index} is true, then an index will be created for that column.
# If {truncate_to} is set to a length, then the value of that field
# stored in the DB will be truncated to that length. This only affects
# searching. If truncate_to is not set, then trying to store a value
# longer than the field accepts will be an error.
# The pseudo-type _DEFAULT must exist and must be a text type, ideally
# supporting arbitrary length text strings. Possible types are TEXT
# for Postgresql, SQLite and MySQL, and VARCHAR(MAX) for SQL Server.
$Foswiki::cfg{Extensions}{DBIStoreContrib}{Schema} = {
    _DEFAULT => { type => 'TEXT' },
    _USERNAME => { type => 'VARCHAR(64)', index => 1 },
    _DATE => { type => 'VARCHAR(32)' },
    topic => {
        _level => 0,
        tid  => { type => 'INT', primary => 1 }
        web  => { type => 'VARCHAR(256)', index => 1 },
        name => { type => 'VARCHAR(128)', index => 1 },
        text => '_DEFAULT',
        raw  => '_DEFAULT'
        },
    metatypes => {
        _level => 0,
        name => { type => 'VARCHAR(63)', index => 1 },
        },
    TOPICINFO => {
        _level => 1,
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
        _level => 1,
        from => { type => 'VARCHAR(256)' },
        to => { type => 'VARCHAR(256)' },
        by => { type => 'VARCHAR(256)' },
        date => '_DATE',
    },
    TOPICPARENT => {
        _level => 1,
        name => { type => 'VARCHAR(256)', index => 1 },
    },
    FILEATTACHMENT => {
        _level => 1,
        name => { type => 'VARCHAR(256)', index => 1 },
        version => { type => 'VARCHAR(32)' },
        path => { type => 'VARCHAR(256)' },
        size => { type => 'VARCHAR(32)' },
        date => '_DATE',
        user => '_USERNAME',
        comment => { type => 'VARCHAR(512)', truncate_to => 512 },
        attr => { type => 'VARCHAR(32)' }
    },
    FORM => {
        _level => 1,
        name => { type => 'VARCHAR(256)', index => 1 },
    },
    FIELD => {
        _level => 1,
        name => { type => 'VARCHAR(128)', index => 1 },
        value => { type => 'VARCHAR(512)', index => 1, truncate_to => 512 },
        title => { type => 'VARCHAR(256)' },
    },
    PREFERENCE => {
        _level => 1,
        name => { type => 'VARCHAR(64)', index => 1 },
        value => _DEFAULT,
        type => { type => 'VARCHAR(32)' },
    }
};

