// initializer for the ui-spinner plugin
"use strict";
jQuery(function($) {
  $(".jqUISpinner").livequery(function() {
    var $this = $(this), 
        value = $this.val(),
        opts = $.extend({}, $this.data(), $this.metadata());
    $this.spinner(opts);    
  });

});

