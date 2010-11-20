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
