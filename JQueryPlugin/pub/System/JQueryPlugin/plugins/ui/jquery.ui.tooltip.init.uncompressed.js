jQuery(function($) {
  var defaults = {
      delay:1000,
      duration:200,
      showEffect:"fadeIn",
      hideEffect:"fadeOut",
      track:true,
      tooltipClass:'default',

      /* work around https://bugs.jqueryui.com/ticket/10689 */
      close: function () { 
	$(".ui-helper-hidden-accessible > *:not(:last)").remove(); 
      }
    },
    defaultPosition = {
      my: "left+15 top+15",
      at: "left bottom",
      collision: "flipfit flip"
    };

  function addFeedbackClass(coords, feedback) {
    var $modal = $(this),
        horiz = feedback.horizontal,
        vert = feedback.vertical,
        className;


    /* map it to the correct position name */
    switch (vert) {
      case "bottom": vert = "top"; break;
      case "top": vert = "bottom"; break;
    }
    switch (horiz) {
      case "left": horiz = "right"; break;
      case "right": horiz = "left"; break;
    }

    className = "position-" + horiz + ' position-' + vert;

    $modal.removeClass(function (index, css) {
      return (css.match (/\position-\w+/g) || []).join(' ');
    });

    $modal.addClass(className);
    $modal.css(coords);
  }

  $(".jqUITooltip:not(.inited)").livequery(function() {
    var $this = $(this),
        opts = $.extend({}, defaults , $this.data());

    $this.addClass("inited");

    opts.show = $.extend(opts.show, {
      effect: opts.showEffect,
      delay: opts.delay,
      duration:opts.duration
    });
    opts.hide = $.extend(opts.hide, {
      effect: opts.hideEffect,
      delay: opts.delay,
      duration:opts.duration
    });

    if (typeof(opts.theme) !== 'undefined') {
      opts.tooltipClass = opts.theme;
    }

    if (typeof(opts.position) === 'string') {
      switch(opts.position) {
        case "bottom":
          opts.position = {"my":"center top", "at":"center bottom+13"};
          opts.track = false;
          break;
        case "top":
          opts.position = {"my":"center bottom", "at":"center top-13"};
          opts.track = false;
          break;
        case "right":
          opts.position = {"my":"left middle", "at":"right+13 middle"};
          opts.track = false;
          break;
        case "left":
          opts.position = {"my":"right middle", "at":"left-13 middle"};
          opts.track = false;
          break;
        case "top left":
        case "left top":
          opts.position = {"my":"right bottom", "at":"left-5 top-5"};
          opts.track = false;
          opts.arrow = false;
          break;
        case "top right":
        case "right top":
          opts.position = {"my":"left bottom", "at":"right+5 top-5"};
          opts.track = false;
          opts.arrow = false;
          break;
        case "bottom left":
        case "left bottom":
          opts.position = {"my":"right top", "at":"left-5 bottom+5"};
          opts.track = false;
          opts.arrow = false;
          break;
        case "bottom right":
        case "right bottom":
          opts.position = {"my":"left top", "at":"right+5 bottom+5"};
          opts.track = false;
          opts.arrow = false;
          break;
        default:
          opts.position = $.extend({}, defaultPosition);
      }
    } 
    
    if (typeof(opts.position) === 'object') {
      opts.position.using = addFeedbackClass;
    }

    if (opts.ajax) {
      opts.content = function(callback) {
        var $this = $(this);

        if ($this.data("content")) {
          return $this.data("content");
        }

        $.get(opts.ajax).then(function(data) {
          $this.data("content", data);
          callback(data);
        });
      };

      opts.items = $this;
    }

    $this.tooltip(opts).on("tooltipopen", function(ev, ui) {
      if (opts.arrow) {
        ui.tooltip.prepend("<div class='ui-arrow'></div>");
      }
    });
  });
});

