# ---+ Extensions
# ---++ CommentPlugin
# **SELECT CHANGE,COMMENT **
# Access control permissions that are required to be able to add a comment
# to a topic. CHANGE is the default, the same as for an adit, but you can
# also select COMMENT which will check e.g. ALLOWTOPICCOMMENT. This lets you
# grant users COMMENT access without giving them open access to edit the
# topic. <strong>Note</strong>Foswiki 1.1 and later only. This feature is
# not supported when the plugin is installed in earlier releases. These
# releases require CHANGE permission on all writable topics.
$Foswiki::cfg{Plugins}{CommentPlugin}{RequiredForSave} = 'CHANGE';
# **BOOLEAN LABEL="Enable Anonymous Commenting"**
# If this option is disabled, the guest user will not be offered the
# comment prompt *even if access controls permit them to save*. Note that
# even if this option is true, access controls will still be checked when
# a comment is saved.
$Foswiki::cfg{Plugins}{CommentPlugin}{GuestCanComment} = 1;
1;
