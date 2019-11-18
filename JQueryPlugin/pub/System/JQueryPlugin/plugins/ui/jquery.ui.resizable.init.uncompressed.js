// initializer for the ui-resizable plugin
"use strict";
jQuery(function($) {

  $(".jqUIResizable").livequery(function() {
    var $this = $(this), 
        opts = $.extend({}, $this.data(), $this.metadata());

    if (opts.debug && console) {
      console.log("opts=",opts);
    }

    $this.removeClass("jqUIResizable").resizable(opts);
  });
});
