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

  /********************************************************
   * hepler function to recursively create a nested object
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

  /********************************************************
   * populate foswiki obj with meta data
   */
  $(function() {
    $("head meta[name^='foswiki.']").each(function() {
      var val = this.content, keys;
      if (val == "false") {
        val = false; // convert to Boolean
      } else if (val == "true") {
        val = true; // convert to Boolean
      } else if (val.match(/^\{.*\}$/)) {
        val = eval("("+val+")"); // convert to object
      } else if (val.match(/^function/)) {
        val = eval("("+val+")"); // convert to Function
      }
      keys = this.name.split(/\./);
      keys.shift(); // take out the first one
      foswiki.createMember(foswiki, keys, val);
    });
  });

})(jQuery);
