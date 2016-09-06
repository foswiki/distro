// initializer for the ui-datepicker plugin
jQuery(function($) {
'use strict';
  
  var datepickerDefaults = {
    dateFormat:'yy/mm/dd',
    firstDay: 1,
    showOn: 'button',
    buttonText: "<i class='fa fa-calendar'></i>"
  };

  $(".jqUIDatepicker").livequery(function() {
    var $this = $(this), 
        opts = $.extend({}, datepickerDefaults, $this.data(), $this.metadata()),
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
      $this.datepicker("setDate", new Date(val));
    }

  });
});
