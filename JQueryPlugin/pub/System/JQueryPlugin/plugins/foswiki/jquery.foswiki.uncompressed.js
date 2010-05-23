/**
 * foswiki setups wrt jQuery
 *
 * $Rev$
*/
var foswiki;
if (typeof(foswiki) === "undefined") {
  foswiki = {};
}

(function($) {

  /********************************************************
   * dummy to be overridden by jquery.debug 
   */
  $.log = function(message){};
  $.fn.debug = function() {};

  /*******************************************************
   * generates an unique ID. 
   */
  foswiki.getUniqueID = function() {
    var uid = new Date().getTime().toString(32), i;

    for (i = 0; i < 5; i++) {
      uid += Math.floor(Math.random() * 65535).toString(32);
    }

    return uid;
  };

  // The following vars were defined in an older release of the plugin.
  // Only systemWebName and pubUrlPath were ever used, and the calls have
  // been changed to foswiki.getPreference calls.
  // <meta name="foswiki.web" content="%WEB%" />
  // <meta name="foswiki.topic" content="%TOPIC%" />
  // <meta name="foswiki.scriptUrl" content="%SCRIPTURL%" />
  // <meta name="foswiki.scriptUrlPath" content="%SCRIPTURLPATH%" />
  // <meta name="foswiki.scriptSuffix" content="%SCRIPTSUFFIX%" />
  // <meta name="foswiki.pubUrl" content="%PUBURL%" />
  // <meta name="foswiki.pubUrlPath" content="%PUBURLPATH%" />
  // <meta name="foswiki.systemWebName" content="%SYSTEMWEB%" />
  // <meta name="foswiki.usersWebName" content="%USERSWEB%" />
  // <meta name="foswiki.wikiName" content="%WIKINAME%" />
  // <meta name="foswiki.loginName" content="%USERNAME%" />
  // <meta name="foswiki.wikiUserName" content="%WIKIUSERNAME%" />
  // <meta name="foswiki.serverTime" content="%SERVERTIME%" />

  /********************************************************
   * helper function to recursively create a nested object
   * based on the keys descriptor. 
   */
  foswiki.createMember = function(obj, keys, val) {
    var key = keys.shift();
    if (keys.length > 0) {
      // this is a nested obj
      if (typeof(obj[key]) == 'undefined') {
        obj[key] = {}; // create it if it does not exist yet
      }
      // recurse
      foswiki.createMember(obj[key], keys, val);
    } else {
      // store value
      obj[key] = val;
    }
  }

})(jQuery);
