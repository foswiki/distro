/*
 * jQuery Loader plugin 4.00
 *
 * Copyright (c) 2011-2019 Foswiki Contributors http://foswiki.org
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 *
 */
"use strict";
(function($) {

  // global defaults
  var defaults = {
    mode: 'manual', // auto, manual
    url: undefined,
    params: {},
    topic: undefined,
    section: undefined,
    skin: 'text',
    select: undefined,
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

    self.elem = $(elem);
    self.container = self.elem.contents().wrapAll("<div class='jqLoaderContainer'></div>");
    self.opts = $.extend({}, defaults, opts);

    self.init();

    if (self.opts.mode === 'auto') {
      self.loadAfter();
    } else {
      if (self.opts.reloadAfter) {
        self.loadAfter(self.opts.reloadAfter);
      }
    }
  }

  // init method
  JQLoader.prototype.init = function() {
    var self = this;

    // add refresh listener
    self.elem.on("refresh.jqloader", function(e, opts) {
      $.extend(self.opts, opts);
      self.loadAfter(0);
    });

    // add onload listener 
    if (typeof(self.opts.onload) === 'function') {
      self.elem.on("onload.jqloader", function() {
        self.opts.onload.call(self);
      });
    }
    
    // add beforeload listener 
    if (typeof(self.opts.beforeload) === 'function') {
      self.elem.on("beforeload.jqloader", function() {
        self.opts.beforeload.call(self);
      });
    }
    
    // add finished listener 
    if (typeof(self.opts.finished) === 'function') {
      self.elem.on("finished.jqLoader", function() {
        self.opts.finished.call(self);
      });
    }

    // add auto-reloader
    if (self.opts.reloadAfter) {
      self.elem.on("finished.jqLoader", function() {
        self.loadAfter(self.opts.reloadAfter);
      });
    }
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

  // load method
  JQLoader.prototype.load = function() {
    var self = this,
        web = self.opts.web || foswiki.getPreference("WEB"),
        topic = self.opts.topic || foswiki.getPreference("TOPIC"),
        params = $.extend({}, self.opts.params),
        url = self.opts.url;

    // construct url and params
    if (typeof(url) === 'undefined') {
      url = foswiki.getScriptUrl("view", web, topic);
    }

    if (typeof(self.opts.section) !== 'undefined') {
      params.section = self.opts.section;
    }

    if (typeof(self.opts.skin) !== 'undefined' && self.opts.skin) {
      params.skin = self.opts.skin;
    }

    // hide effect
    if (self.opts.hideEffect) {
      self.container.animateCSS({
        effect: self.opts.hideEffect
      });
    } 

    // trigger beforeload
    self.elem.trigger("beforeload.jqloader", self);

    $.get(
      url,
      params,
      function(data) {
        if (typeof(self.opts.select) !== 'undefined') {
          data = $(data).find(self.opts.select);
        }

        // insert data
        self.elem.empty();
        self.container = $("<div class='jqLoaderContainer' />").appendTo(self.elem);
        self.container.append(data);

        // trigger onload
        self.elem.trigger("onload.jqloader", self);

        // show effect
        var effect = self.opts.effect || self.opts.showEffect;
        if (effect) {
          self.container.animateCSS({
            effect: effect
          }).on("stop.animate", function() {

          // trigger finished
            self.elem.trigger("finished.jqLoader", self);
          });
        } else {
          // trigger finished
          self.elem.trigger("finished.jqLoader", self);
        }

      }, 'html');
  };

  // register plugin to jquery core
  $.fn.jqLoader = function(opts) {
    return this.each(function() {
      if (!$.data(this, 'jqLoader')) {
        $.data(this, 'jqLoader',
          new JQLoader(this, opts)
        );
      }
    });
  };

  // register css class 
  $(".jqLoader").livequery(function() {
    var $this = $(this), 
        opts = $.extend({}, $this.data(), $this.metadata());

    $this.jqLoader(opts);
  });
})(jQuery);
