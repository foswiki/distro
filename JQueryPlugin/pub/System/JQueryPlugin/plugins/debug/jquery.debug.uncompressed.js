/* simple jQuery logger */
(function($) {
  var $container, 
      $list,
      userAgent = navigator.userAgent.toLowerCase(),
      isIE = /msie/.test(userAgent) && !/opera/.test(userAgent); 

  function log() {
    var args = arguments, msg;

    if (isIE) {
      if (typeof($container) === 'undefined') {
        $container = $('<div id="DEBUG"></div>').appendTo("body");
        $list = $("<ol></ol>").appendTo($container);
      }
      
      msg = Array.prototype.slice.call(args);
      if (msg.length == 1 && typeof(msg[0]) === 'string') {
        msg = msg[0];
      } else {
        msg = msg.join(" ");
      }
      $list.append( '<li>' + msg + '</li>' ); 
      $container.scrollTop($container[0].scrollHeight); 
    } else {
      console.log.apply(console, args);
    }
  }
  
  /* export */
  $.log = log;
  $.fn.debug = function() {
    return this.each(function(){
      $.log(this);
    });
  };

})(jQuery);
