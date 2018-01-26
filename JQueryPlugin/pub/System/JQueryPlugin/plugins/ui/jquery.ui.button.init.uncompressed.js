// initializer for the ui-button plugin
"use strict";
jQuery(function($) {

  var defaults = {
    onlyVisible: false
  };
  
  // button
  $(".jqUIButton").livequery(function() {
    var $this = $(this), 
        opts = $.extend({}, defaults, $this.data(), $this.metadata());
    $this.removeClass("jqUIButton").button(opts);    
  });
  
  // button set
  $(".jqUIButtonset").livequery(function() {
    var $this = $(this), 
        opts = $.extend({}, defaults, $this.data(), $this.metadata());

    $this.removeClass("jqUIButtonset").buttonset(opts);    
  });
});
