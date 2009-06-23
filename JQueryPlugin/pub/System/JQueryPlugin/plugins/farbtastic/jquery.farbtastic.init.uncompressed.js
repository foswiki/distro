// initializer for foswiki
(function($) {

  // defaults
  var defaults = {
    fade: 250,
    position: 'bottom',
    callback: function (color) { $.log("new color="+color); }
  };

  $(function() {
    // create a colorpicker if it isn't there already
    var colorpicker = $("#colorpicker");
    if (colorpicker.length == 0) {
      colorpicker = $('<div class="ui-component-content ui-widget-content ui-hidden ui-helper-hidden" id="colorpicker"></div>').appendTo("body");
    }
    $(".jqFarbtastic").each(function() {
      var $this = $(this);
      var fb = $.farbtastic(colorpicker).linkTo(this);

      // read element options
      var opts = $.extend({}, defaults, $this.metadata());

      // click
      $this.click(function() {
        // set up the connection
        fb = $.farbtastic(colorpicker).linkTo(this);
        
        // compute position
        var pos = $this.offset(); 
        if (opts.position == 'left') 
          pos.left += $this.outerWidth();
        if (opts.position == 'bottom') 
          pos.top += $this.outerHeight();
        colorpicker.css({top:pos.top, left:pos.left});

        // show
        var fb = colorpicker.farbtastic();
        fb.debug();
        fb.fadeIn(opts.fade);
      }).
      
      // blur
      blur(function() {
        colorpicker.farbtastic().hide();
        
        // call our own callback
        if (typeof(opts.callback) == 'function') {
          opts.callback.call(fb, fb.color);
        }
      });
    });
  });
})(jQuery);
