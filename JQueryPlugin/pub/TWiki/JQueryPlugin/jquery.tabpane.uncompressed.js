/*
 * jQuery Tabpane plugin 1.0
 *
 * Copyright (c) 2008 Michael Daum http://michaeldaumconsulting.com
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 *
 * Revision: $Id$
 *
 */
(function($) {

  /***************************************************************************
   * plugin definition 
   */
  $.fn.tabpane = function(options) {
    writeDebug("called tabpane()");
   
    // build main options before element iteration
    var opts = $.extend({}, $.fn.tabpane.defaults, options);
   
    // iterate and reformat each matched element
    return this.each(function() {

      var $thisPane = $(this);
 
      // build element specific options. 
      var thisOpts = $.extend({}, opts, $thisPane.data());

      // create tab group
      var $tabContainer = $thisPane;
      var $tabGroup = $('<ul class="jqTabGroup"></ul>').prependTo($tabContainer);

      // get all headings and create tabs
      var index = 1;
      var currentTabId;
      $thisPane.children(".jqTab").each(function() {
        var title = $('h2', this).eq(0).remove().text();
        $tabGroup.append('<li'+(index == thisOpts.select?' class="current"':'')+'><a href="javascript:void(0)" data="'+this.id+'">'+title+'</a></li>');
        if (index == thisOpts.select) {
          currentTabId = this.id;
          $(this).addClass("current");
        } else {
          //writeDebug("hiding "+this.id);
          $(this).removeClass("current");
        }
        index++;
      });
      switchTab(currentTabId, currentTabId, thisOpts);

      $(".jqTabGroup li > a", this).click(function() {
        $(this).blur();
        var newTabId = $(this).attr('data');
        if (newTabId != currentTabId) {
          $("#"+currentTabId).removeClass("current");
          $("#"+newTabId).addClass("current");
          $(this).parent().parent().children("li").removeClass("current"); 
          $(this).parent().addClass("current"); 
          switchTab(currentTabId, newTabId, thisOpts);
          currentTabId = newTabId;
        }
        return false;
      });
      $thisPane.css("display", "block"); // show() does not work in some browsers :(
    });
  };

  /***************************************************************************
   * switchin from tab1 to tab2
   */
  function switchTab(oldTabId, newTabId, thisOpts) {
    writeDebug("switch from "+oldTabId+" to "+newTabId);

    var $newTab  = $("#"+newTabId);

    if (!thisOpts[newTabId]) {
      thisOpts[newTabId] = $newTab.data();
    }
    var data = thisOpts[newTabId];

    // before click handler
    if (typeof(data.beforeHandler) != "undefined") {
      var command = "{ oldTab = '"+oldTabId+"'; newTab = '"+newTabId+"'; "+data.beforeHandler+";}";
      writeDebug("exec "+command);
      eval(command);
    }

    // async loader
    if (typeof(data.url) != "undefined") {
      var container = data.container || '.jqTabContents';
      var $container = $newTab.find(container);
      writeDebug("loading "+data.url+" into "+container);
      if (typeof(data.afterLoadHandler) != "undefined") {
        var command = "{ oldTab = '"+oldTabId+"'; newTab = '"+newTabId+"'; "+data.afterLoadHandler+";}";
        writeDebug("after load handler "+command);
        var func = new Function(command);
        $container.load(data.url, {}, func);
      } else {
        $container.load(data.url);
      }
      delete thisOpts[newTabId].url;
    }
  
    // after click handler
    if (typeof(data.afterHandler) != "undefined") {
      var command = "{ oldTab = '"+oldTabId+"'; newTab = '"+newTabId+"'; "+data.afterHandler+";}";
      writeDebug("exec "+command);
      eval(command);
    }

  }

  /***************************************************************************
   * private function for debugging using the firebug console
   */
  function writeDebug(msg) {
    if ($.fn.tabpane.defaults.debug) {
      if (window.console && window.console.log) {
        window.console.log("DEBUG: TabPane - "+msg);
      } else {
        //alert(msg);
      }
    }
  };

  /***************************************************************************
   * plugin defaults
   */
  $.fn.tabpane.defaults = {
    debug: false,
    select: 1
  };
})(jQuery);
