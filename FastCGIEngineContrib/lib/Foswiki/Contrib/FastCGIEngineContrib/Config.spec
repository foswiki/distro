# ---+ Extensions
# ---++ FastCGIEngineContrib
# Note that these values only serve as a default and will be superseded by any values in /etc/default/foswiki.
# I.e. you will have to specify the size of the worker pool, that is the number of Foswiki backends spawned.

# **NUMBER LABEL="Maximum Requests" CHECK="undefok"**
# This is the maximum number of requests a backend is allowed to serve. Afterwards it will be killed and replaced
# with a new one. Set to -1 to disable this check.
$Foswiki::cfg{FastCGIContrib}{MaxRequests} = 100;

# **NUMBER LABEL="Maximum Memory" CHECK="undefok"**
# This is the maximum memory a child process is allowed to grow up to. Afterwards it will be killed and replaced
# with a new one. Set to zero to disable this check.
$Foswiki::cfg{FastCGIContrib}{MaxSize} = 0;

# **NUMBER LABEL="Check Size Interval" CHECK="undefok"**
# This is the number of requests after which a size check is performed. Use as hight number as possible as this is 
# potentially costy operation that you don't want to pay on every request. Low values will result in a better
# size control of child processes; high values may give you a slightly better overall performance.
$Foswiki::cfg{FastCGIContrib}{CheckSize} = 10;

# **BOOLEAN LABEL="Enable Check of LSC" CHECK="undefok"**
# Switch on/off checking LocalSite.cfg for changes. Note that you might want to disable this check on sites with 
# a lot of traffic for stability reasons. Instead you'll then have to restart the Foswiki fcgi backend manually as
# required for any configuration change to LocalSite.cfg to take effect.
$Foswiki::cfg{FastCGIContrib}{CheckLocalSiteCfg} = 1;

1;
