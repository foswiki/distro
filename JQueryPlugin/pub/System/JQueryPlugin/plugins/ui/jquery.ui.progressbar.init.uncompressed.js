// initializer for the ui-progressbar plugin
"use strict";
jQuery(function($) {
  var defaults = {
    showValue: false
  };
  
  // progressbar
  $(".jqUIProgressBar:not(.jqUIProgressBarInited)").livequery(function() {
    var $this = $(this), 
        value = parseInt($this.text(), 10),
        opts = $.extend({}, defaults, $this.data(), $this.metadata());

    $this.empty();
    if (!isNaN(value)) {
      opts.value = value;
    }

    function updateLabel() {
      $this.find(".ui-progressbar-value").text($this.progressbar("value"));
    }

    if (opts.showValue) {
      opts.change = function() {
        updateLabel();
      }
      opts.create = function() {
        updateLabel();
      }
    }

    $this.addClass("jqUIProgressBarInited").progressbar(opts);    
  });

});
