// initializer for the ui-accordion plugin
"use strict";
jQuery(function($) {
  $(".jqUIAccordion").livequery(function() {
    var $this = $(this), opts = $.extend({}, $this.data(), $this.metadata());
    $this.removeClass("jqUIAccordion").accordion(opts);    
  });
});
