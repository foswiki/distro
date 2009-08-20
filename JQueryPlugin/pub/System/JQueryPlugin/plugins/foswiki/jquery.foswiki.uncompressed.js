/**
 * foswiki setups wrt jQuery
 *
 * $Rev$
*/
var foswiki;
if (typeof(foswiki) == "undefined") {
  foswiki = {};
}

(function($) {
  /********************************************************
  /* dummy to be overridden by jquery.debug */
  $.log = function(message){};
  $.fn.debug = function() {};

  /********************************************************
   * hepler function to recursively create a nested object
   * based on the keys descriptor. 
   */
  function createMember(obj, keys, val) {
    var key = keys.shift();
    if (keys.length > 0) {
      // this is a nested obj
      if (typeof(obj[key]) == 'undefined') {
        obj[key] = {}; // create it if it does not exist yet
      }
      // recurse
      createMember(obj[key], keys, val);
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
      var val = this.content;
      if (val == "false") {
        val = false; // convert to Boolean
      } else if (val == "true") {
        val = true; // convert to Boolean
      } else if (val.match(/^{.*}$/)) {
        val = eval("("+val+")"); // convert to object
      } else if (val.match(/^function/)) {
        val = eval("("+val+")"); // convert to Function
      }
      var keys = this.name.split(/\./);
      keys.shift(); // take out the first one
      createMember(foswiki, keys, val);
    });
  });

})(jQuery);
