// initializer for the ui-datepicker plugin
jQuery(function($) {
  
  var datepickerDefaults = {
    dateFormat:'d M yy',
    firstDay: 1
  };

  $(".jqUIDatepicker").livequery(function() {
    var $this = $(this), 
        opts = $.extend({}, datepickerDefaults, $this.data(), $this.metadata()),
        maxZIndex = 1;

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
  });
});
