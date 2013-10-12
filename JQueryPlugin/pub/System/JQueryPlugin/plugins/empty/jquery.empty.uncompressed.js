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
 *    2 replace the strings "Empty" with "pluginName" in this file
 *    3 edit the global defaults
 *    4 refine the init method
 *
 */

;(function($, window, document) {

  // Create the defaults once
  var pluginName = "Empty",
      defaults = {
        foo: "bar"
      };

  // The actual plugin constructor 
  function Empty(elem, options) { 
    var self = this;

    self.$elem = $(elem); 

    // gather options by merging global defaults, plugin defaults and element defaults
    self.options = $.extend({}, defaults, options, self.$elem.data()); 
    self.init(); 
  } 

  Empty.prototype.init = function () { 
    var self = this;
    // Place initialization logic here 
    // You already have access to the DOM element and 
    // the options via the instance, e.g. this.element 
    // and this.options 
  }; 

  // A plugin wrapper around the constructor, 
  // preventing against multiple instantiations 
  $.fn[pluginName] = function (options) { 
    return this.each(function () { 
      if (!$.data(this, pluginName)) { 
        $.data(this, pluginName, new Empty(this, options)); 
      } 
    }); 
  } 

  // Enable declarative widget instanziation 
  $(".jq"+pluginName).livequery(function() {
  });

})(jQuery, window, document);

