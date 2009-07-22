
#---++ Registration
# **BOOLEAN**
# Controls whether new user registration is available.
# It will have no effect on existing users.
$Foswiki::cfg{Register}{EnableNewUserRegistration} = $TRUE;

# **BOOLEAN**
# Whether registrations must be verified by the user, by following
# a link sent in an email to the user's registered email address
$Foswiki::cfg{Register}{NeedVerification} = $FALSE;

# **BOOLEAN EXPERT**
# Hide password in registration email to the <em>user</em>
# Note that Foswiki sends administrators a separate confirmation.
$Foswiki::cfg{Register}{HidePasswd} = $TRUE;

# **STRING 20 EXPERT**
# The internal user that creates user topics on new registrations.
# You are recommended not to change this.
$Foswiki::cfg{Register}{RegistrationAgentWikiName} = 'RegistrationAgent';
