/*
 * jQuery Empty plugin 1.0
 *
 * Copyright (c) 20xx Your Name http://...
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 *
 * How to proceed:
 *    1 copy this file into a file named jquery.plugin-name.js
 *    2 replace the strings "EmptyPlugin" with the name of your plugin in this file
 *    3 edit the global defaults
 *    4 refine the init method
 *
 */

"use strict";
(function($) {

  // Create the defaults once
  var defaults = {};

  // The actual plugin constructor
  function EmptyPlugin(elem, opts) {
    var self = this;

    self.$elem = $(elem);

    // gather options by merging global defaults, plugin defaults and element defaults
    self.opts = $.extend({}, defaults, self.$elem.data(), opts);
    self.init();
  }

  EmptyPlugin.prototype.init = function () {
    var self = this;

    // Place initialization logic here
    // You already have access to the DOM element and
    // the options via the instance, e.g. this.element
    // and this.opts
  };

  // A plugin wrapper around the constructor,
  // preventing against multiple instantiations
  $.fn.emptyPlugin = function (opts) {
    return this.each(function () {
      if (!$.data(this, "EmptyPlugin")) {
        $.data(this, "EmptyPlugin", new EmptyPlugin(this, opts));
      }
    });
  };

  // Enable declarative widget instanziation
  $(function() {
    $(".jqEmptyPlugin:not(.jqEmptyPluginInited)").livequery(function() {
      $(this).addClass("jqEmptyPluginInited").emptyPlugin();
    });
  });

})(jQuery);

