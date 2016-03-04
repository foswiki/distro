// initializer for the ui-button plugin
jQuery(function($) {
'use strict';
  
  // button
  $(".jqUIButton").livequery(function() {
    var $this = $(this), 
        opts = $.extend({}, $this.data(), $this.metadata());
    $this.removeClass("jqUIButton").button(opts);    
  });
  
  // button set
  $(".jqUIButtonset").livequery(function() {
    var $this = $(this), 
        opts = $.extend({}, $this.data(), $this.metadata());

    $this.removeClass("jqUIButtonset").buttonset(opts);    
  });
});
