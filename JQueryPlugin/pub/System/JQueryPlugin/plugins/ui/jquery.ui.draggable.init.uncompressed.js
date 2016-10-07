// initializer for the ui-draggable plugin
"use strict";
jQuery(function($) {

  $(".jqUIDraggable:not(.jqUIDraggableInited)").livequery(function() {
    var $this = $(this), 
        opts = $.extend({}, $this.data(), $this.metadata());

    $this.addClass("jqUIDraggableInited").draggable(opts);
  });
});
