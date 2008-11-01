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
 *    1 copy this file into a file named jquery.<plugin-name>.js
 *    2 replace the strings "empty" with <plugin-name> in this file
 *
 */
(function($) {

  /***************************************************************************
   * private function for debugging using the firebug console
   * TODO: move this to $.twiki.writeDebug()
   */
  function writeDebug(msg) {
    if ($.empty.defaults.debug) {
      if (window.console && window.console.log) {
        window.console.log("DEBUG: empty - "+msg);
      } else {
        /* generic debugging. TODO come up with something better */
        //alert("DEBUG: empty - "+msg) 
      }
    }
  };

  /***************************************************************************
   * plugin definition 
   */
  $.empty = {

      
    /***********************************************************************
     * constructor
     */
    build: function(options) {
      writeDebug("called empty()");
     
      // build main options before element iteration
      var opts = $.extend({}, $.fn.empty.defaults, options);
     
      // iterate and reformat each matched element
      return this.each(function() {
        $this = $(this);
        
        // build element specific options. 
        // note you may want to install the Metadata plugin
        var thisOpts = $.meta ? $.extend({}, opts, $this.data()) : opts;

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
      debug: false
    };
  }


  /* register by extending jquery */
  $.fn.empty = build;

})(jQuery);
