// initializer for the ui-resizable plugin
"use strict";
jQuery(function($) {

  $(".jqUIResizable").livequery(function() {
    var $this = $(this), 
        opts = $.extend({}, $this.data(), $this.metadata());

    $this.removeClass("jqUIResizable").resizable(opts);
  });
});
