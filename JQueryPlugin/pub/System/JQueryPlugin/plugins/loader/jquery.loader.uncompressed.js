/*
 * jQuery Loader plugin 3.01
 *
 * Copyright (c) 2011-2019 Foswiki Contributors http://foswiki.org
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 *
 */
"use strict";
jQuery(function($) {

  // global defaults
  var defaults = {
    mode: 'auto', // auto, manual
    placeholder: "<img src='"+foswiki.getPreference("PUBURLPATH")+"/System/JQueryPlugin/images/spinner.gif' width='16' height='16' />",
    url: undefined,
    params: undefined,
    topic: undefined,
    section: undefined,
    skin: 'text',
    select: undefined,
    minHeight: 0,
    hideEffect: 'fadeOut', 
    showEffect: 'fadeIn', 
    reloadAfter: 0,
    delay: 0,
    onload: function() {},
    finished: function() {},
    beforeload: function() {}
  };

  // constructor
  function JQLoader(elem, opts) {
    var self = this;

    self.element = elem;
    self.opts = $.extend({}, defaults, opts);

    self.init();

    if (self.opts.mode === 'auto') {
      self.loadAfter();
    }
  }

  // init method
  JQLoader.prototype.init = function() {
    var self = this,
        $elem = $(self.element);

    // add refresh listener
    $elem.on("refresh.jqloader", function(e, opts) {
      $.extend(self.opts, opts);
      self.loadAfter();
    });

    // add onload listener 
    if (typeof(self.opts.onload) === 'function') {
      $elem.bind("onload.jqloader", function() {
        self.opts.onload.call(self);
      });
    }
    
    // add beforeload listener 
    if (typeof(self.opts.beforeload) === 'function') {
      $elem.bind("beforeload.jqloader", function() {
        self.opts.beforeload.call(self);
      });
    }
    
    // add finished listener 
    if (typeof(self.opts.finished) === 'function') {
      $elem.bind("finished.jqLoader", function() {
        self.opts.finished.call(self);
      });
    }

    // add auto-reloader
    if (self.opts.reloadAfter) {
      $elem.bind("finished.jqLoader", function() {
        self.loadAfter(self.opts.reloadAfter);
      });
    }

    self.prepareContainer();
  };

  // delayed loading 
  JQLoader.prototype.loadAfter = function(delay) {
    var self = this;

    delay = delay || self.opts.delay;

    if (typeof(self.timer) !== 'undefined') {
      window.clearTimeout(self.timer);
      self.timer = undefined;
    }

    if (delay) {
      self.timer = window.setTimeout(function() {
        self.load();
      }, delay);
    } else {
      self.load();
    }
  };

  // prepares the container
  JQLoader.prototype.prepareContainer = function() {
    var self = this,
        $elem = $(self.element),
        $placeholder;


    if (typeof(self.opts.placeholder) !== 'undefined' && self.opts.placeholder !== '') {
      $placeholder = $(decodeURI(self.opts.placeholder)).hide();
      $placeholder.insertBefore($elem);

      // listen to beforeload event to show the placeholder
      $elem.bind("beforeload.jqloader", function() {
        $placeholder.show();
      });

      // listen to onload event to hide the placeholder
      $elem.bind("onload.jqloader", function() {
        $placeholder.hide();
      });

      // add clickhandler to placeholder when not in auto mode
      if (self.opts.mode !== 'auto') {
        $placeholder.click(function() {
          $elem.trigger("refresh.jqloader", self);
        });
      }
    } 
  };

  // load method
  JQLoader.prototype.load = function() {
    var self = this,
        $elem = $(self.element),
        web = self.opts.web || foswiki.getPreference("WEB"),
        topic = self.opts.topic || foswiki.getPreference("TOPIC"),
        params = $.extend({}, self.opts.params);

    // construct url
    if (typeof(self.opts.url) === 'undefined') {
      self.opts.url = foswiki.getScriptUrl("view", web, topic);
    }

    if (typeof(self.opts.section) !== 'undefined') {
      params.section = self.opts.section;
    }

    if (typeof(self.opts.skin) !== 'undefined' && self.opts.skin) {
      params.skin = self.opts.skin;
    }

    // trigger beforeload
    $elem.trigger("beforeload.jqloader", self);

    if (self.opts.url) {

      if (typeof(self.container) === 'undefined') {
        self.container = $("<div class='jqLoaderContainer' />").insertAfter($elem);

        // apply min height
        if (self.opts.minHeight) {
          self.container.css("min-height", self.opts.minHeight);
          $(window).trigger("resize");
        }
      }

      var doit = function() {
        $.get(
          self.opts.url,
          params,
          function(data) {
            if (typeof(self.opts.select) !== 'undefined') {
              data = $(data).find(self.opts.select);
            }

            self.container.remove();
            self.container = $("<div class='jqLoaderContainer' />").insertAfter($elem);

            // apply min height
            if (self.opts.minHeight) {
              self.container.css("min-height", self.opts.minHeight);
              $(window).trigger("resize");
            }

            // insert data
            self.container.append(data);

            $elem.trigger("onload.jqloader", self);

            // show effect
            var effect = self.opts.effect || self.opts.showEffect;
            if (typeof(effect) !== 'undefined') {
              self.container.animateCSS({
                effect: effect
              }).on("stop.animate", function() {
                $elem.trigger("finished.jqLoader", self);
              });
            } else {
              // trigger finished
              $elem.trigger("finished.jqLoader", self);
            }

          }, 'html');
      };

      // hide effect
      if (typeof(self.opts.hideEffect) !== 'undefined') {
        self.container.animateCSS({
          effect: self.opts.hideEffect
        })/*.on("stop.animate", function() {
          self.container.css("visibility", "hidden");
          doit();
        })*/;
        doit();
      } else {
        doit();
      }

    } else {
      throw("error: no url");
    }
  };

  // register plugin to jquery core
  $.fn.jqLoader = function(opts) {
    return this.each(function() {
      if (!$.data(this, 'plugin_jqLoader')) {
        $.data(this, 'plugin_jqLoader',
          new JQLoader(this, opts)
        );
      }
    });
  };

  // register css class 
  $(".jqLoader:not(.jqLoaderInited)").livequery(function() {
    var $this = $(this),
        opts = $.extend({}, $this.data(), $this.metadata());
    $this.addClass("jqLoaderInited").jqLoader(opts);
  });
});
