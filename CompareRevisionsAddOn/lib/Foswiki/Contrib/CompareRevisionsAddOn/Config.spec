# ---+ Extensions
# ---++ CompareRevisionsAddOn
# **PERL EXPERT LABEL="SwitchBoard - compare"**
# This setting is required to enable executing the compare script from the bin directory
$Foswiki::cfg{SwitchBoard}{compare} = {
    package  => 'Foswiki::Contrib::CompareRevisionsAddOn::Compare',
    function => 'compare',
    context  => {
        diff      => 1,
        comparing => 1
    }
};

# **PERL EXPERT LABEL="SwitchBoard - compareauth"**
# This setting is required when using ApacheLogin and the user needs to be authenticated when executing the compare script
$Foswiki::cfg{SwitchBoard}{compareauth} = {
    package  => 'Foswiki::Contrib::CompareRevisionsAddOn::Compare',
    function => 'compare',
    context  => {
        diff      => 1,
        comparing => 1
    }
};
1;
