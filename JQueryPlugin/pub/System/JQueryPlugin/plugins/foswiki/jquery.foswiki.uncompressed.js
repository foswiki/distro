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
   * populate foswiki obj with meta data
   */
  $("head meta[name^='foswiki.']").each(function() {
    var val = this.content;
    if (val == "false") {
      val = false;
    } else if (val == "true") {
      val = true;
    }
    foswiki[this.name.substr(8)]=val;
  });

  /********************************************************
  /* dummy to be overridden by jquery.debug */
  $.log = function(message){};
  $.fn.debug = function() {};

})(jQuery);
