
#---++ Registration
# **BOOLEAN**
# by turning this option off, you can temporarily disable new user registration.
# it will have no effect on existing users.
$TWiki::cfg{Register}{EnableNewUserRegistration} = $TRUE;

# **BOOLEAN EXPERT**
# Hide password in registration email to the *user*
# Note that TWiki sends admins a separate confirmation.
$TWiki::cfg{Register}{HidePasswd} = $TRUE;

# **BOOLEAN**
# Whether registrations must be verified by the user following
# a link sent in an email to the user's registered email address
$TWiki::cfg{Register}{NeedVerification} = $FALSE;

# **STRING 20 EXPERT**
# The internal user that creates user topics on new registrations. You are recommended not to change this.
$TWiki::cfg{Register}{RegistrationAgentWikiName} = 'RegistrationAgent';