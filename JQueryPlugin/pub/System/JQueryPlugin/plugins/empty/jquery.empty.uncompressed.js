/*
 * jQuery Empty plugin 1.0
 *
 * Copyright (c) 20xxx your name url://... 
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 *
 * Revision: $Id$
 *
 * How to proceed: 
 *    1 copy this file into a file named jquery.plugin-name.js
 *    2 replace the strings "empty" with plugin-name in this file
 *
 */

/***************************************************************************
 * plugin definition 
 */
(function($) {

  $.empty = {

      
    /***********************************************************************
     * constructor
     */
    build: function(options) {
      $.log("called empty()");
     
      // build main options before element iteration
      var opts = $.extend({}, $.empty.defaults, options);
     
      // iterate and reformat each matched element
      return this.each(function() {
        var $this = $(this);
        
        // build element specific options. 
        // note you may want to install the Metadata plugin
        var thisOpts = $.extend(opts, $this.metadata());

        // do it ...
      });
    },

    /***************************************************************************
     * helper function
     */
    helper: function() {
    },

    /***************************************************************************
     * plugin defaults
     */
    defaults: {
      //key: 'value'
    }
  };

  /* register by extending jquery */
  $.fn.empty = $.empty.build;

})(jQuery);
