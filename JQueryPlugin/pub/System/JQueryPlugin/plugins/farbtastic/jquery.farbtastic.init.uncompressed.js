// initializer for foswiki
"use strict";
(function($) {

  // defaults
  var defaults = {
    fade: 250,
    position: 'bottom',
    callback: function (color) { $.log("new color="+color); }
  };

  // helper snarfed from farbtastic
  function unpack(color) {
    var re = /^rgb\((.*?),(.*?),(.*?)\)/;
    if (color.length === 7) {
      return [parseInt('0x' + color.substring(1, 3)) / 255,
        parseInt('0x' + color.substring(3, 5)) / 255,
        parseInt('0x' + color.substring(5, 7)) / 255];
    }
    else if (color.length === 4) {
      return [parseInt('0x' + color.substring(1, 2)) / 15,
        parseInt('0x' + color.substring(2, 3)) / 15,
        parseInt('0x' + color.substring(3, 4)) / 15];
    }
    else if (re.test(color)) {
      return [parseFloat(color.replace(re, "$1") / 255),
        parseFloat(color.replace(re, "$2") / 255),
        parseFloat(color.replace(re, "$3") / 255)];
    }
    else return color;
  }
  function RGBToHSL(rgb) {
    var min, max, delta, h, s, l;
    var r = rgb[0], g = rgb[1], b = rgb[2];
    min = Math.min(r, Math.min(g, b));
    max = Math.max(r, Math.max(g, b));
    delta = max - min;
    l = (min + max) / 2;
    s = 0;
    if (l > 0 && l < 1) {
      s = delta / (l < 0.5 ? (2 * l) : (2 - 2 * l));
    }
    h = 0;
    if (delta > 0) {
      if (max === r && max !== g) h += (g - b) / delta;
      if (max === g && max !== b) h += (2 + (b - r) / delta);
      if (max === b && max !== r) h += (4 + (r - g) / delta);
      h /= 6;
    }
    return [h, s, l];
  }
  function getFgColor(bgColor, dark, light) {
    var color = unpack(bgColor);
    var hsl = RGBToHSL(color);
    return hsl[2] > 0.5 ? dark||'#000' : light||'#FFF';
  }

  function initFarbtastic(colorPicker, elem) {
    var val = elem.val();

    function _colorize(bgColor) {
      var fgColor = getFgColor(bgColor);
      elem.val(bgColor).css({
        "background-color": bgColor,
        "color": fgColor
      });
    }

    if (val) {
      _colorize(val);
    }

    return $.farbtastic(colorPicker).linkTo(_colorize);
  }

  $(function() {
    // create a color picker if it isn't there already
    var colorPicker = $("#colorpicker");
    if (colorPicker.length === 0) {
      colorPicker = $('<div class="ui-component-content ui-widget-content ui-hidden ui-helper-hidden" id="colorpicker"></div>').appendTo("body");
    }
    $(".jqFarbtastic:not(.jqInitedFarbtastic)").livequery(function() {
      var $this = $(this),
          opts = $.extend({}, defaults, $this.data(), $this.metadata()),
          fb;

      $this.addClass("jqInitedFarbtastic");
      fb = initFarbtastic(colorPicker, $this);

      // click
      $this.click(function() {
        var colorPickerPos, computePosInterval;

        // link again
        fb = initFarbtastic(colorPicker, $this);

        // compute color picker position repeatedly in case of a scroll event
        function computePos() {
          var pos;

          if ($this.length === 0 && computePosInterval) {
            window.clearInterval(computePosInterval);
            return;
          }

          pos = $this.offset();

          if (opts.position === 'left')  {
            pos.left += $this.outerWidth();
          }
          if (opts.position === 'bottom') {
            pos.top += $this.outerHeight();
          }

          if (!colorPickerPos || colorPickerPos.top !== pos.top || colorPickerPos.left !== pos.left) {
            colorPickerPos = pos;
            colorPicker.css({top:pos.top, left:pos.left});
          }
        }

        computePos();
        computePosInterval = window.setInterval(computePos, 500);

        // show
        colorPicker.farbtastic().fadeIn(opts.fade);

      }).blur(function() {
        colorPicker.farbtastic().hide();

        // call our own callback
        if (typeof(opts.callback) == 'function') {
          opts.callback.call(fb, fb.color);
        }
      });
    });
  });


  // farbtastic div bg
  $(function() {
    var defaults = {
      dark: '#000',
      light: '#fff'
    };

    $(".jqFarbtasticFG:not(.jqInitedFarbtasticFG)").livequery(function() {
      var $this = $(this),
          opts = $.extend({}, defaults, $this.data(), $this.metadata()),
          bgColor = $this.css('background-color'),
          fgColor = getFgColor(bgColor, opts.dark, opts.light);

      $this.addClass("jqInitedFarbtastic").css({'color': fgColor });
    });
  });
 
})(jQuery);
