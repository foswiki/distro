/*
 * jQuery Tabpane plugin 1.1
 *
 * Copyright (c) 2008-2010 Michael Daum http://michaeldaumconsulting.com
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 *
 * Revision: $Id$
 *
 */
var bottomBarHeight = -1;
(function($) {

$.tabpane = {

  /***************************************************************************
   * plugin definition 
   */
  build: function(options) {
    //$.log("called tabpane()");

    if (typeof(options) == 'undefined') {
      options = {};
    }
   
    // build main options before element iteration
    var opts = $.extend({}, $.tabpane.defaults, options);
   
    // iterate and reformat each matched element
    return this.each(function() {

      var $thisPane = $(this);
      var thisOpts = $.extend({}, opts, $thisPane.metadata());
      if ($.browser.msie) {
        thisOpts.animate = false; // force animation off on all msies because that fucks up font aliasing
      }

      if (!$thisPane.is(".jqTabPaneInitialized")) {

        $thisPane.addClass("jqTabPaneInitialized");
        $("<span class='foswikiClear'></span>").prependTo($thisPane);
   
        // create tab group
        var $tabContainer = $thisPane;
        var $tabGroup = $('<ul class="jqTabGroup"></ul>').prependTo($thisPane);

        // get all headings and create tabs
        var index = 1;
        $thisPane.find("> .jqTab").each(function() {
          var $this = $(this);
          var title = $this.find('h2:first').remove().text();
          $tabGroup.append('<li><a href="#" data="'+this.id+'">'+title+'</a></li>');
          if (index == thisOpts.select || $this.hasClass(thisOpts.select)) {
            thisOpts.currentTabId = this.id;
          }
          index++;
        });
        if (thisOpts.currentTabId) {
          $.tabpane.switchTab($thisPane, thisOpts, thisOpts.currentTabId);
        }

        /* establish auto max expand */
        if (thisOpts.autoMaxExpand) {
          $.tabpane.autoMaxExpand($thisPane, thisOpts);
        }

        $thisPane.find(".jqTabGroup > li > a").click(function() {
          $(this).blur();
          var newTabId = $(this).attr('data');
          if (newTabId != thisOpts.currentTabId) {
            $.tabpane.switchTab($thisPane, thisOpts, newTabId);
          }
          return false;
        });

      }

    });
  },

  /***************************************************************************
   * switching from tab1 to tab2
   */
  switchTab: function($thisPane, thisOpts, newTabId) {

    var oldTabId = thisOpts.currentTabId;

    //$.log("switching from "+oldTabId+" to "+newTabId);

    var $newTab  = jQuery("#"+newTabId);
    var $oldTab = jQuery("#"+oldTabId);
    var $newContainer = $newTab.find('.jqTabContents');
    var $oldContainer = $oldTab.find('.jqTabContents');
    var oldHeight = $oldContainer.height(); // why does the container not work

    $oldTab.removeClass("current");
    $newTab.addClass("current");
    $thisPane.find("li a[data="+oldTabId+"]").parent().removeClass("current"); 
    $thisPane.find("li a[data="+newTabId+"]").parent().addClass("current"); 

    if (!thisOpts[newTabId]) {
      thisOpts[newTabId] = $newTab.metadata();
    }
    var data = thisOpts[newTabId];

    // before click handler
    if (typeof(data.beforeHandler) == "function") {
      data.beforeHandler.call(this, oldTabId, newTabId);
    }

    if ((thisOpts.animate || thisOpts.autoMaxExpand) && oldHeight > 0) {
      $newContainer.height(oldHeight);
    }

    function _finally () {
      
      var effect = 'none';
      if (oldHeight > 0) {
        effect = 'easeInOutQuad';
      }

      // adjust height of the current tab
      if (thisOpts.autoMaxExpand) {
        if(thisOpts.animate && effect != 'none') {
          $newContainer.css({opacity:0.0}).animate({
            opacity: 1.0
          }, 300);
        }
        $(window).trigger("resize");
      } else {
        // animate height
        if (thisOpts.animate) {
          $newContainer.height('auto');
          var newHeight = $newContainer.height();
          if (effect != 'none') {
            $newContainer.height(oldHeight).css({opacity:0.0}).animate({
              opacity: 1.0,
              height: newHeight
            }, 300, effect, function() {
              $newContainer.height('auto');
            });
          } else {
            $newContainer.height('auto');
          }
        }
      }
      
      // after click handler
      if (typeof(data.afterHandler) == "function") {
        //jQuery.log("exec "+data.afterHandler);
        data.afterHandler.call(this, oldTabId, newTabId);
      }

      thisOpts.currentTabId = newTabId;
    }

    // async loader
    if (typeof(data.url) != "undefined") {
        
      $newContainer.load(data.url, undefined, function() {
        if (typeof(data.afterLoadHandler) == "function") {
          //jQuery.log("after load handler "+command);
          data.afterLoadHandler.call(this, oldTabId, newTabId);
        }
        _finally();
      });
      delete thisOpts[newTabId].url;
    } else {
      _finally();
    }
    

  },

  /*************************************************************************
   * handler to listen to window-resize event to fire the fixHeight()
   * method
   */
  autoMaxExpand: function($thisPane, opts) {
    window.setTimeout(function() {
      jQuery.tabpane.fixHeight($thisPane, opts);
      jQuery(window).one("resize", function() {
        $.tabpane.autoMaxExpand($thisPane, opts);
      });
    }, 100);
  },

  /*************************************************************************
   * adjust height of pane to window height
   */
  fixHeight: function($thisPane, opts) {

    //jQuery.log("tabpane: called fixHeight()");

    var $container = $thisPane.find("> .jqTab.current .jqTabContents");

    var paneOffset = $container.offset();

    if (typeof(paneOffset) == 'undefined') {
      return;
    }

    var paneTop = paneOffset.top; // || $container[0].offsetTop;
    if (bottomBarHeight <= 0) {
      bottomBarHeight = jQuery('.natEditBottomBar').outerHeight(true);
    }

    var windowHeight = jQuery(window).height();
    if (!windowHeight) {
      windowHeight = window.innerHeight; // woops, jquery, whats up for konqi
    }

    var height = windowHeight-paneTop-2*bottomBarHeight;
    var $debug = $("#DEBUG");
    if ($debug) {
      height -= $debug.outerHeight(true);
    }

    //jQuery.log("tabpane: container="+$container.parent().attr('id')+" paneTop="+paneTop+" bottomBarHeight="+bottomBarHeight+" height="+height+" minHeight="+opts.minHeight);

    if (opts && opts.minHeight && height < opts.minHeight) {
      //jQuery.log("tabpane: minHeight reached");
      height = opts.minHeight;
    }

    if (height < 0) {
      return;
    }

    $container.height(height);
  },

  /***************************************************************************
   * plugin defaults
   */
  defaults: {
    select: 1,
    animate: false,
    autoMaxExpand: false,
    minHeight: 230
  }

};

$.fn.tabpane = $.tabpane.build;

})(jQuery);
