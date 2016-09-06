/*
 * jQuery Stars plugin 2.01
 *
 * Copyright (c) 2014-2016 Foswiki Contributors http://foswiki.org
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 *
 */
(function($) {


  // Create the defaults once 
  var defaults = {
    split: 1,
    numStars: 5
  };

  // plugin constructor 
  function Plugin(elem, opts) {
    var self = this;

    self.elem = $(elem);
    self.opts = $.extend({}, defaults, opts);

    self.init();
  }

  ////////////////////////////////////////////////////////////////////////////////
  // helper
  function _isObject(obj) {
    return obj.constructor === Object;
  }
  function _isArray(arr) {
    return arr.constructor === Array;
  }
  function _isString(str) {
    return str.constructor === String;
  }
  Plugin.prototype._toFixed = function(num) {
    num = Number(num);
    return Number(num.toFixed(this._prec));
  }

  ////////////////////////////////////////////////////////////////////////////////
  // initializer 
  Plugin.prototype.init = function() {
    var self = this, key, values;

    self.mapping = {};

    if (self.opts.values) {
      if (_isString(self.opts.values)) {
        self.opts.values = self.opts.values.split(/\s*,\s*/);
      } else if (_isArray(self.opts.values)) {
        values = [];
        $.each(self.opts.values, function(i, val) {
          if (_isObject(val)) {
            for (key in val) {
              self.mapping[val[key]] = key;
              values.push(val[key]);
            }
          } else {
            values.push(val);
          }
        });
        self.opts.values = values;
      }

      self.opts.numStars = self.opts.values.length;
      self.opts.split = 1;
    } 


    self._prec = 0;
    if (self.opts.split > 1) {
      self._prec++;
    }
    if (self.opts.split > 10) {
      self._prec++;
    }
    if (self.opts.split > 100) {
      self._prec++;
    }

    self.blockMouseMove = false;
    self.timeoutId = undefined;

    self.elem.hide();
    self.container = $("<div />").addClass("jqStarsContainer").insertAfter(self.elem); 
    self.labelElem = $("<span />").addClass("jqStarsLabel").insertAfter(self.container);
    self.onElem = $("<div />").addClass("jqStarsOn").appendTo(self.container);

    self.widthStar = parseInt(self.container.css("background-size"), 10);
    self.width = self.opts.numStars * self.widthStar;

    self.container.width(self.width);

    if (self.elem.is(":disabled")) {
      self.container.addClass("jqStarsReadOnly");
    } else {
      self.deleteElem = $("<div />").addClass("jqStarsDelete").insertAfter(self.elem);

      // event handler
      self.container.on("mousemove", function(ev) {
        if (!self.blockMouseMove) {
          self.displayAtIndex((ev.pageX - self.container.offset().left) / self.widthStar);
        }
      });

      self.container.on("mouseleave", function() {
        if (self.blockMouseMove) {
          if (typeof(self.timeoutId) !== 'undefined') {
            window.clearTimeout(self.timeoutId);
          }
          self.timeoutId = window.setTimeout(function() {
            self.blockMouseMove = false;
            self.timeoutId = undefined;
          }, 1000);
        }
        self.display(self.elem.val());
        self.container.removeClass("jqStarsSelected");
      });

      self.container.on("mouseenter", function() {
        self.blockMouseMove = false;
      });

      self.container.on("click", function(ev) {
        self.displayAtIndex((ev.pageX - self.container.offset().left) / self.widthStar);
        self.container.addClass("jqStarsSelected");
        self.blockMouseMove = true;
        self.selectAtIndex(self._tmpIndex);
        return false;
      });

      self.deleteElem.hover(
        function() { self.display(); }, 
        function() { self.display(self.elem.val()); }
      );
      self.deleteElem.on("click", function() {
        self.select();
        return false;
      });

      self.container.on("mousewheel", function(ev) {
        var inc = 1 / self.opts.split;
        if (ev.deltaY > 0) {
          self._tmpIndex += inc;
          if (self._tmpIndex > self.opts.numStars) {
            self._tmpIndex = self.opts.numStars;
          }
        } else {
          self._tmpIndex -= inc;
          if (self._tmpIndex < 0) {
            self._tmpIndex = 0;
          }
        }
        self._tmpIndex = self._toFixed(self._tmpIndex);
        self.selectAtIndex(self._tmpIndex);
        self.container.addClass("jqStarsSelected");
        self.blockMouseMove = true;
        return false;
      });
    }

    self.select(self.elem.val());
  };

  ////////////////////////////////////////////////////////////////////////////////
  Plugin.prototype.getDisplayVal = function(index) {
    var self = this, val;

    if (self.opts.values) {
      val = self.opts.values[index-1];
      if (typeof(self.mapping[val]) !== 'undefined') {
        val = self.mapping[val];
      }
    } else {
      val = sprintf("%." + self._prec + "f", index);
    }

    return val;
  };

  ////////////////////////////////////////////////////////////////////////////////
  Plugin.prototype.displayAtIndex = function(index) {
    var self = this, width, label;

    if (typeof(index) === 'undefined' || index === 0) {
      width = 0;
      label = '';
    } else {
      index = Math.ceil(index * self.opts.split) / self.opts.split;
      index = self._toFixed(index);

      width = self.widthStar * index;
      label = self.getDisplayVal(index);
    }

    if (index == self._tmpIndex) {
      return;
    }

    self.onElem.width(width);
    self.labelElem.html(label);
    self._tmpIndex = index;

    self.elem.trigger("display.stars", index, label);
  };


  ////////////////////////////////////////////////////////////////////////////////
  Plugin.prototype.display = function(val) {
    var self = this,
      index;

    if (typeof(val) === 'undefined' || val === '' || val == 0) {
      index = undefined;
    } else if (typeof(self.opts.values) !== 'undefined') {
      index = self.opts.values.indexOf(val)+1;
    } else {
      index = val;
    }

    self.displayAtIndex(index);
  };

  ////////////////////////////////////////////////////////////////////////////////
  Plugin.prototype.selectAtIndex = function(index) {
    var self = this, val;

    self._tmpIndex = undefined;

    if (typeof(index) === 'undefined' || index === 0) {
      val = '';
    } else {
      if (typeof(self.opts.values) !== 'undefined') {
        val = self.opts.values[index-1];
      } else {
        val = index;
      }
    }

    self.displayAtIndex(index);

    self.elem.val(val);
  };

  ////////////////////////////////////////////////////////////////////////////////
  Plugin.prototype.select = function(val) {
    var self = this;

    self._tmpIndex = undefined;

    self.display(val);
    self.elem.val(val);
  };

  ////////////////////////////////////////////////////////////////////////////////
  // plugin wrapper around the constructor
  $.fn.stars = function(opts) {
    return this.each(function() {
      if (!$.data(this, '_stars')) {
        $.data(this, '_stars', new Plugin(this, opts));
      }
    });
  };

  ////////////////////////////////////////////////////////////////////////////////
  // live query DOM and construct the plugin 
  $(function() {
    $(".jqStars:not(.jqInitedStars)").livequery(function() {
      var $this = $(this),
        opts = $.extend({}, $this.data(), $this.metadata());
      $this.wrap("<div class='jqStars jqInitedStars' />").removeClass("jqStars").addClass("jqStarsInput").stars(opts);
    });
  });
})(jQuery);
