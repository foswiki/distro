jQuery(function($) {

  // global defaults
  var defaults = {
    mode: 'auto', // auto, manual
    placeholder: "<img src='"+foswiki.getPreference("PUBURLPATH")+"/System/JQueryPlugin/images/spinner.gif' width='16' height='16' />",
    url: undefined,
    section: undefined,
    effect: 'fade', // show, fade, slide, blind, clip, drop, explode, fold, puff, pulsate, highlight
    effectspeed: 500,
    effectopts: {},
    delay: 0,
    onload: function() {},
    finished: function() {},
    beforeload: function() {
      if (typeof(this.container) !== 'undefined') {
        this.container.css({opacity:0.5});
      }
    }
  };

  // constructor
  function JQLoader(elem, options) {
    var self = this;

    self.element = elem;
    self.options = $.extend({}, defaults, options);

    self.init();
    
    if (self.options.mode === 'auto') {
      if (self.options.delay) {
        // delayed loading 
        window.setTimeout(function() {
          self.load();
        }, self.options.delay);
      } else {
        // immediate loading
        self.load();
      }
    }
  };

  // init method
  JQLoader.prototype.init = function() {
    var self = this,
        $elem = $(self.element);

    $elem.hide();

    // construct load url
    if (typeof(self.options.section) !== 'undefined') {
      self.options.url = 
        foswiki.getPreference("SCRIPTURL")+"/view/" + 
        foswiki.getPreference("WEB") + "/" +
        foswiki.getPreference("TOPIC") + "?skin=text;section=" +
        self.options.section;
    }

    // add refresh listener
    $elem.bind("refresh.jqloader", function(e, opts) {
      $.extend(self.options, opts);
      self.load();
    });

    // add onload listener 
    if (typeof(self.options.onload) === 'function') {
      $elem.bind("onload.jqloader", function() {
        self.options.onload.call(self);
      });
    }
    
    // add beforeload listener 
    if (typeof(self.options.beforeload) === 'function') {
      $elem.bind("beforeload.jqloader", function() {
        self.options.beforeload.call(self);
      });
    }
    
    // add finished listener 
    if (typeof(self.options.finished) === 'function') {
      $elem.bind("finished.jqloader", function() {
        self.options.finished.call(self);
      });
    }

    self.prepareContainer();
  };

  // prepares the container
  JQLoader.prototype.prepareContainer = function() {
    var self = this,
        $elem = $(self.element),
        $placeholder;


    if (typeof(self.options.placeholder) !== 'undefined') {
      $placeholder = $(self.options.placeholder);
      $placeholder.insertBefore($elem);

      // listen to onload event to remove the placeholder
      $elem.bind("onload.jqloader", function() {
        $placeholder.remove();
      });

      // add clickhandler to placeholder when not in auto mode
      if (self.options.mode !== 'auto') {
        $placeholder.click(function() {
          $elem.trigger("refresh.jqloader", self);
        });
      }
    }
  };

  // load method
  JQLoader.prototype.load = function() {
    var self = this,
        pubUrlPath = foswiki.getPreference("PUBURLPATH"),
        $elem = $(self.element);

    // trigger beforeload
    $elem.trigger("beforeload.jqloader", self);

    if (self.options.url) {

      $.get(self.options.url, function(data) {
        if (typeof(self.container) !== 'undefined') {
          self.container.remove();
        }
        self.container = $("<div />").append(data).insertAfter($elem);
    
        $elem.trigger("onload.jqloader", self);

        // effect
        if (typeof(self.options.effect) !== 'undefined' && self.options.effect !== 'show') {
          self.container.hide();
          if (self.options.effect === 'fade') {
            self.container.fadeIn(self.options.effectspeed, function() {
              // trigger finished
              $elem.trigger("finished.jqloader", self);
            });
          } else {
            self.container.show(self.options.effect, self.options.effectopts, self.options.effectspeed, function() {
              // trigger finished
              $elem.trigger("finished.jqloader", self);
            });
          }
        } else {
          // trigger finished
          $elem.trigger("finished.jqloader", self);
        }

      }, 'html');
    } else {
      $elem.html("error: no url");
    }
  };

  // register plugin to jquery core
  $.fn.jqLoader = function(options) {
    return this.each(function() {
      if (!$.data(this, 'plugin_jqLoader')) {
        $.data(this, 'plugin_jqLoader',
          new JQLoader(this, options)
        );
      }
    });
  }

  // register css class 
  $(".jqLoader:not(.jqLoaderInited)").livequery(function() {
    var $this = $(this),
        opts = $.extend({}, $this.metadata());

    $this.addClass("jqLoaderInited").jqLoader(opts);
  });
});
