/*
 * jQuery Stars plugin 3.00
 *
 * Copyright (c) 2014-2020 Foswiki Contributors http://foswiki.org
 *
 * Licensed under the GPL licenses http://www.gnu.org/licenses/gpl.html
 *
 */
/* global sprintf:false */
"use strict";
(function($) {


  // Create the defaults once 
  var defaults = {
    split: 1,
    numStars: 5
  };

  // plugin constructor 
  function Stars(elem, opts) {
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
  Stars.prototype._toFixed = function(num) {
    num = Number(num);
    return Number(num.toFixed(this.prec));
  };

  ////////////////////////////////////////////////////////////////////////////////
  // initializer 
  Stars.prototype.init = function() {
    var self = this, key, values;

    self.elem
      .removeClass("jqStars")
      .addClass("jqStarsInput")
      .wrap("<div class='jqStars jqStarsInited' />");

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

      self.opts.numStars = self.opts.values.length - 1;
      self.opts.split = 1;
    } 

    self.prec = 0;
    if (self.opts.split > 1) {
      self.prec++;
    }
    if (self.opts.split > 10) {
      self.prec++;
    }
    if (self.opts.split > 100) {
      self.prec++;
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
        self.elem.trigger("focus");
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

      $(document).on("keydown", function(ev) {
        if (self.container.is(":hover")) {
          var inc = 1 / self.opts.split, found = false;
          //console.log("keycode=",ev.keyCode);
          switch(ev.keyCode) {
            case 38: /* up */
            case 33: /* page up */
              self._tmpIndex = Math.floor(self._tmpIndex + 1);
              found = true;
              break;
            case 40: /* down */
            case 34: /* page down */
              self._tmpIndex = Math.ceil(self._tmpIndex - 1);
              found = true;
              break;
            case 35: /* end */
              self._tmpIndex = self.opts.numStars;
              found = true;
              break;
            case 36: /* pos 1 */
              self._tmpIndex = 0;
              found = true;
              break;
            case 37: /* left */
              self._tmpIndex -= inc;
              found = true;
              break;
            case 39: /* right */
              self._tmpIndex += inc;
              found = true;
              break;
            default:
              found = false;
          }
          if (found) {
            if (self._tmpIndex > self.opts.numStars) {
              self._tmpIndex = self.opts.numStars;
            }
            if (self._tmpIndex < 0) {
              self._tmpIndex = 0;
            }
            self._tmpIndex = self._toFixed(self._tmpIndex);
            self.selectAtIndex(self._tmpIndex);
            return false;
          }
        }
      });
    }

    self.select(self.elem.val());
  };

  ////////////////////////////////////////////////////////////////////////////////
  Stars.prototype.getStoreValue = function(index) {
    var self = this, val;

    index = index || 0;

    val = typeof(self.mapping[index]) === 'undefined' ? self.getDisplayVal(index) : index;

    //console.log("called getStoreValue(",index,") = ",val);

    return val;
  };

  ////////////////////////////////////////////////////////////////////////////////
  Stars.prototype.getDisplayVal = function(index) {
    var self = this, val;

    //console.log("called getDisplayVal(",index,")");
    if (self.opts.values) {
      val = self.opts.values[index];
      //console.log("... val=",val);
      if (typeof(self.mapping[val]) !== 'undefined') {
        val = self.mapping[val];
        //console.log("... mapping to",val);
      }
    } else {
      val = sprintf("%." + self.prec + "f", index);
      //console.log("... numerical value is",val);
    }

    return val;
  };

  ////////////////////////////////////////////////////////////////////////////////
  Stars.prototype.displayAtIndex = function(index) {
    var self = this, width, label;

    if (typeof(index) === 'undefined') {
      index = 0;
    } 

    index = Math.ceil(index * self.opts.split) / self.opts.split;
    index = self._toFixed(index);

    width = self.widthStar * index;
    label = self.getDisplayVal(index);

    if (index === self._tmpIndex) {
      return;
    }

    self.onElem.width(width);
    self.labelElem.html(label);
    self._tmpIndex = index;

    self.elem.trigger("display.stars", index, label);
  };


  ////////////////////////////////////////////////////////////////////////////////
  Stars.prototype.display = function(val) {
    var self = this,
      index;

    if (typeof(val) === 'undefined' || val === '') {
      index = 0;
    } else if (typeof(self.opts.values) !== 'undefined') {
      index = self.opts.values.indexOf(val);
    } else {
      index = val;
    }

    self.displayAtIndex(index);
  };

  ////////////////////////////////////////////////////////////////////////////////
  Stars.prototype.selectAtIndex = function(index) {
    var self = this, val;

    //console.log("called selectAtIndex(",index,")");
    self._tmpIndex = undefined;

    if (typeof(index) === 'undefined') {
      index = 0;
    } 

    if (typeof(self.opts.values) !== 'undefined') {
      val = self.opts.values[index];
    } else {
      val = index;
    }

    self.displayAtIndex(index);
    val = self.getStoreValue(index);
    //console.log("... val=",val);
    self.elem.val(val);
  };

  ////////////////////////////////////////////////////////////////////////////////
  Stars.prototype.select = function(val) {
    var self = this;

    self._tmpIndex = undefined;

    self.display(val);
    self.elem.val(self.getStoreValue(val));
  };

  ////////////////////////////////////////////////////////////////////////////////
  // plugin wrapper around the constructor
  $.fn.stars = function(opts) {
    return this.each(function() {
      if (!$.data(this, 'stars')) {
        $.data(this, 'stars', new Stars(this, opts));
      }
    });
  };

  ////////////////////////////////////////////////////////////////////////////////
  // live query DOM and construct the plugin 
  $(function() {
    $(".jqStars:not(.jqStarsInited)").livequery(function() {
      var $this = $(this),
        opts = $.extend({}, $this.data());
      $this.stars(opts);
    });
  });
})(jQuery);
