/* simple jQuery logger */
(function($) {
  function log() {
    var args = arguments;
    console.log.apply(console, args);
  }
  
  /* export */
  $.log = foswiki.log = log;
  $.fn.debug = function() {
    return this.each(function(){
      $.log(this);
    });
  };

})(jQuery);
