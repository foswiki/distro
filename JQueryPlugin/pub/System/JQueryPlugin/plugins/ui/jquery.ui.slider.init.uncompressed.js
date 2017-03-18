// initializer for the ui-slider plugin
jQuery(function($) {

  var sliderDefaults = {
    animate: true
  };

  $(".jqUISlider").livequery(function() {
    var $this = $(this), 
        values = $.map(
          $this.text().split(/\s*,\s*/), 
          function(n) {
            return parseInt(n, 10);
          }
        ),
        opts = {};

    if (values.length > 0) {
      if (values.length == 1) {
        opts.value = values[0];
      } else {
        opts.values = values;
      }
    }

    opts = $.extend({}, sliderDefaults, opts, $this.data(), $this.metadata());
    $this.empty().removeClass("jqUISlider").slider(opts);    
  });
});
