
#---++ Registration
# **BOOLEAN**
# by turning this option off, you can temporarily disable new user registration.
# it will have no effect on existing users.
$Foswiki::cfg{Register}{EnableNewUserRegistration} = $TRUE;

# **BOOLEAN EXPERT**
# Hide password in registration email to the *user*
# Note that Foswiki sends admins a separate confirmation.
$Foswiki::cfg{Register}{HidePasswd} = $TRUE;

# **BOOLEAN**
# Whether registrations must be verified by the user following
# a link sent in an email to the user's registered email address
$Foswiki::cfg{Register}{NeedVerification} = $FALSE;

# **STRING 20 EXPERT**
# The internal user that creates user topics on new registrations. You are recommended not to change this.
$Foswiki::cfg{Register}{RegistrationAgentWikiName} = 'RegistrationAgent';