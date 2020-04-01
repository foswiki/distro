// initializer for the ui-datepicker plugin
"use strict";
jQuery(function($) {
  
  var datepickerDefaults = {
    dateFormat:'yy/mm/dd',
    firstDay: 1,
    showOn: 'button',
    buttonText: "<i class='fa fa-calendar'></i>"
  };

  $(".jqUIDatepicker").livequery(function() {
    var $this = $(this), 
        lang = $this.data("lang") || '',
        opts = $.extend({}, $.datepicker.regional[lang], datepickerDefaults, $this.data(), $this.metadata()),
        maxZIndex = 100, val = $this.val();

    $this.parents().each(function() {
      var zIndex = parseInt($(this).css("z-index"), 10);
      if (zIndex > maxZIndex) {
        maxZIndex = zIndex;
      }
    });

    $this.css({
      "position": "relative",
      "z-index": maxZIndex + 1
    });

    $this.datepicker(opts);    

    if (val !== '') {
      var orig = val;
      try {
        if (typeof(val) === 'number') {
          // init from epoch seconds
          val = new Date(val*1000);
        } else if (typeof(val) === 'string' && val.match(/^[+-]?\d+$/)) {
          // init from epoch seconds string
          val = new Date(parseInt(val, 10)*1000);
        } else {
          // init from format
          val = $.datepicker.parseDate(opts.dateFormat, val);
        }
      } catch(error) {
        val = orig;
      }
      $this.datepicker("setDate", val);
    }

  });
});
