# ---+ Extensions
# ---++ CompareRevisionsAddOn
# **PERL H**
# This setting is required to enable executing the compare script from the bin directory
$Foswiki::cfg{SwitchBoard}{compare} = [
          'Foswiki::Contrib::CompareRevisionsAddOn::Compare',
          'compare',
          {
            'comparing' => 1
          }
        ];
1;
