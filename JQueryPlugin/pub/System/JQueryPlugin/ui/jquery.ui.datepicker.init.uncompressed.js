// initializer for the ui-datepicker plugin
jQuery(function($) {
  
  var datepickerDefaults = {
    dateFormat:'yy-mm-dd',
    firstDay: 1
  };

  $(".jqUIDatepicker").each(function() {
    var $this = $(this), opts = $.extend({}, datepickerDefaults, $this.metadata());
    $this.removeClass("jqUIDatepicker").datepicker(opts);    
  });
});
