# ---+ Extensions
# **ENHANCE {Store}{Implementation}**
# <dl><dt>PlainFile</dt><dd>
# (installed by the PlainFileStoreContrib) is just about the simplest store
# that you can use with Foswiki. it uses simple text files to store
# the history of topics and attachments, and does not require any external
# programs. The use of text files makes it easy to implement 'out of band'
# processing, as well as taking maximum advantage of filestore caching. This
# is the reference implementation of a store.</dd></dl>

# ---+ Extensions
# ---++ PlainFileStoreContrib
# **BOOLEAN LABEL="Check for RCS"**
# Check before every store modification that there are no suspicious
# files left over from RCS. This check should be enabled whenever there
# is a risk that old RCS data has been mixed in to a PlainFileStore.
$Foswiki::cfg{Extensions}{PlainFileStoreContrib}{CheckForRCS} = 1;

# **BOOLEAN EXPERT LABEL="Ignore Out-Of-Band Changes"**
# By activating this flag certain checks of file modifications will be ignored
# that might have occured without using Foswiki directly. These are attributed
# to the "unknown user" by default. However this also masks any revision information
# of the most recent version of a topic not accessible anymore if an OOB change occured.
$Foswiki::cfg{Extensions}{PlainFileStoreContrib}{IngoreOutOfBandChanges} = $FALSE;

1;
