/*
 * jQuery fluid font plugin 1.0
 *
 * Copyright (c) 2009-2010 Michael Daum http://michaeldaumconsulting.com
 *
 * inspired by TextZooming by James Newbery http://www.tinnedfruit.com/sandbox/textzoom.html
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 *
 * Revision: $Id$
 *
 */

/***************************************************************************
 * plugin definition 
 */
;(function($) {

  $.fluidfont = {
      
    /***********************************************************************
     * constructor
     */
    build: function(options) {
      $.log("called fluidfont.build()");
     
      var $this = $(this);
      var opts = $.extend({}, $.fluidfont.defaults, options);

      function getRatio(size) {
        if (size.match(/px/)) {
          return parseFloat(size) / opts.width;
        } 

        if (size.match(/em/)) {
          return parseFloat(size);
        } 

        if (size.match(/%/)) {
          return parseFloat(size) / 100;
        }
       
        return size; 
      }

      function resize() {
        var width = $this.width();
        var fontSize = fontRatio * width;

        if (typeof(opts.max) == 'number' && fontSize > opts.max) {
          fontSize = opts.max;
        }

        if (typeof(opts.min) == 'number' && fontSize < opts.min) {
          fontSize = opts.min;
        }

        var lineHeight = fontSize * lineRatio;

        $.log("width="+width+" font-size="+fontSize+" line-height="+lineHeight+" lineRatio="+lineRatio);
        $this.css({'font-size': fontSize+"px", 'line-height': lineHeight+"px"});
      
        window.setTimeout(function() {
          $(window).one("resize.fluidfont", resize);
        }, 100); 
      }

      var fontRatio = getRatio($this.css('font-size'));
      var lineRatio = getRatio($this.css('line-height'));
      lineRatio = lineRatio / fontRatio;
    
      resize();

      return $this;
    },

    /***************************************************************************
     * recompute the font-size of the given element
     */


    /***************************************************************************
     * plugin defaults
     */
    defaults: {
      width: 1024, // screen width for original font-size
      min: 10, // minimum text size in px
      max: 15 // maximum text size in px
    }
  }

  /* register by extending jquery */
  $.fn.fluidfont = $.fluidfont.build;

  /* initialisation */
  $(function() {
    $(".jqFluidFont").not(".jqInitedFluidFont").each(function() {
      var $this = $(this);
      var opts = $.extend({}, $this.metadata());
      $this.addClass("jqInitedFluidFont");
      $this.fluidfont(opts);
    });
  });

})(jQuery);
