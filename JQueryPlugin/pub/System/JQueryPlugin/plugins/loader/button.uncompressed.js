/*
 * jQuery Loader Button plugin 1.00
 *
 * Copyright (c) 2025 Foswiki Contributors http://foswiki.org
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 *
 */
"use strict";
(function($) {

  var defaults = {
    target: null,
    iconClass: "fa",
    spinClass: "fa-spin",
  };

  function JQLoaderButton(elem, opts) {
    var self = this;

    self.elem = $(elem);
    self.opts = $.extend({}, defaults, self.elem.data());
    self.init();
  }

  JQLoaderButton.prototype.init = function() {
    var self = this;

    self.icon = self.elem.find("." + self.opts.iconClass);

    if (typeof self.opts.target === "string") {
      self.target = $(self.opts.target);
    } else if (self.opts.target && typeof self.opts.target === "object") {
      self.target = self.opts.target;
    } else {
      self.target = self.elem.next();
    }

    self.target.on("beforeload.jqloader", function() {
      self.icon.addClass(self.opts.spinClass);
    }).on("onload.jqloader", function() {
      self.icon.removeClass(self.opts.spinClass);
    });

    self.elem.on("click", function() {
      self.target.trigger('refresh');
      return false;
    });
  };

  // register plugin to jquery core
  $.fn.jqLoaderButton = function(opts) {
    return this.each(function() {
      if (!$.data(this, 'jqLoaderButton')) {
        $.data(this, 'jqLoaderButton',
          new JQLoaderButton(this, opts)
        );
      }
    });
  };

  // register css class 
  $(".jqLoaderButton").livequery(function() {
    $(this).jqLoaderButton();
  });

})(jQuery);
