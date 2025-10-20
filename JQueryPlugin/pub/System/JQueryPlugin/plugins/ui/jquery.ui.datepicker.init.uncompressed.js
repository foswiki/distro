// initializer for the ui-datepicker plugin
"use strict";
jQuery(function($) {
  
  var datepickerDefaults = {
    dateFormat:'yy/mm/dd',
    firstDay: 1,
    showOn: 'button',
    buttonText: "",
    doWeekends: true,
  };

  function getDate(val, tzOffset) {
    tzOffset = tzOffset || 0;
    val += tzOffset;
    return new Date(val * 1000);
  }


  $(".jqUIDatepicker").livequery(function() {
    var $this = $(this), 
        lang = $this.data("lang") || '',
        opts = $.extend({}, $.datepicker.regional[lang], datepickerDefaults, $this.data()),
        val = $this.val(),
        trigger;


    if (!opts.doWeekends) {
      opts.beforeShowDay = $.datepicker.noWeekends
    }

    trigger = $this.datepicker(opts).next();
    if (trigger.is(".ui-datepicker-trigger")) {
      trigger.prop("tabindex", -1);
    }

    if (val !== '') {
      var orig = val;
      try {
        if (typeof(val) === 'number') {
          // init from epoch seconds
          val = getDate(val, opts.tzOffset);
        } else if (typeof(val) === 'string' && val.match(/^[+-]?\d+$/)) {
          // init from epoch seconds string
          val = getDate(parseInt(val, 10), opts.tzOffset);
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
