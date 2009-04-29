/*
 * jQuery Tabpane plugin 1.1
 *
 * Copyright (c) 2008-2009 Michael Daum http://michaeldaumconsulting.com
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

    if (typeof(options) == 'undefined') {
      options = {};
    }
   
    // build main options before element iteration
    var opts = $.extend({}, $.fn.tabpane.defaults, options);
   
    // iterate and reformat each matched element
    return this.each(function() {

      var $thisPane = $(this);
 
      // build element specific options. 
      var thisOpts = $.extend({}, opts, $thisPane.metadata());

      // create tab group
      var $tabContainer = $thisPane;
      var $tabGroup = $('<ul class="jqTabGroup"></ul>').prependTo($tabContainer);

      // get all headings and create tabs
      var index = 1;
      var currentTabId;
      $thisPane.children(".jqTab").each(function() {
        var title = $('h2', this).eq(0).remove().text();
        $tabGroup.append('<li'+((index == thisOpts.select || this.id == thisOpts.select)?' class="current"':'')+'><a href="javascript:void(0)" data="'+this.id+'">'+title+'</a></li>');
        if (index == thisOpts.select || this.id == thisOpts.select) {
          currentTabId = this.id;
          $(this).addClass("current");
        } else {
          //writeDebug("hiding "+this.id);
          $(this).removeClass("current");
        }
        index++;
      });
      if (currentTabId) {
        switchTab(currentTabId, currentTabId, thisOpts);
      }

      /* establish auto max expand */
      if (thisOpts.autoMaxExpand) {
        window.setTimeout(autoMaxExpand, 1);
      }

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
    });
  };

  /***************************************************************************
   * switchin from tab1 to tab2
   */
  function switchTab(oldTabId, newTabId, thisOpts) {
    writeDebug("switch from "+oldTabId+" to "+newTabId);

    var $newTab  = $("#"+newTabId);

    if (!thisOpts[newTabId]) {
      thisOpts[newTabId] = $newTab.metadata();
    }
    var data = thisOpts[newTabId];

    // before click handler
    if (typeof(data.beforeHandler) != "undefined") {
      var command = "{ oldTab = '"+oldTabId+"'; newTab = '"+newTabId+"'; "+data.beforeHandler+";}";
      writeDebug("exec "+command);
      var func = new Function(command);
      func();
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
        $container.load(data.url, undefined, func);
      } else {
        $container.load(data.url);
      }
      delete thisOpts[newTabId].url;
    }
  
    // after click handler
    if (typeof(data.afterHandler) != "undefined") {
      var command = "{ oldTab = '"+oldTabId+"'; newTab = '"+newTabId+"'; "+data.afterHandler+";}";
      writeDebug("exec "+command);
      var func = new Function(command);
      func();
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
        alert(msg);
      }
    }
  };


  /*************************************************************************
   * adjust height of pane to window height
   */
  function autoMaxExpand() {
    //writeDebug("called autoMaxExpand");
    fixHeightOfPane();
    window.setTimeout(function() {
      $(window).one("resize", function() {
        autoMaxExpand()
      });
    }, 100); 
  }
  

  /***************************************************************************
   * plugin defaults
   */
  $.fn.tabpane.defaults = {
    debug: false,
    select: 1
  };
})(jQuery);


/* TODO rework */
var bottomBarHeight = -1;
function fixHeightOfPane() {

  var selector = (typeof(newTab) != 'undefined')?"#"+newTab:".jqTab:visible";
  selector += " .jqTabContents";
  //alert("newTab="+newTab+" selector="+selector);
  var $container = $(selector);
  var paneOffset = $container.offset({
    scroll:false,
    border:true,
    padding:true,
    margin:true
  });


  if (typeof(paneOffset) != 'undefined') {

    var paneTop = paneOffset.top;
    if (bottomBarHeight < 0) {
      bottomBarHeight = $('.natEditBottomBar').outerHeight({margin:true});
    }
    //alert("container="+$container.parent().attr('id')+" paneTop="+paneTop+" bottomBarHeight="+bottomBarHeight);

    var windowHeight = $(window).height();
    if (!windowHeight) {
      windowHeight = window.innerHeight; // woops, jquery, whats up, i.e. for konqueror
    }
    var height = windowHeight-paneTop-bottomBarHeight-50;

    var newTabSelector;
    if (typeof(newTab) == 'undefined') {
      newTabSelector = ".jqTab:visible";
    } else {
      newTabSelector = "#"+newTab;
    }

    // add new height to those containers, that don't have an natEditAutoMaxExpand element
    $(newTabSelector+" .jqTabContents").filter(function(index) { 
      return $(".natEditAutoMaxExpand", this).length == 0; 
    }).each(function() {
      $(this).height(height);
    });
  }
}
