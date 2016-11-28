/*
 * jQuery Tabpane plugin 2.00
 *
 * Copyright (c) 2008-2016 Foswiki Contributors http://foswiki.org
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 *
 */
"use strict";
var bottomBarHeight = -1;
(function($) {

  /* plugin defaults ********************************************************/
  var defaults = {
    select: 1,
    animate: false,
    autoMaxExpand: false,
    minHeight: 230
  };

  /* plugin constructor *****************************************************/
  function TabPane(elem, opts) {
    var self = this;

    self.elem = $(elem);

    // gather options by merging global defaults, plugin defaults and element defaults
    self.opts = $.extend({}, defaults, self.elem.data(), opts);
    self.tabs = {};
    self.init();
  }

  /* init ********************************************************************/
  TabPane.prototype.init = function() {
    var self = this,
        $tabGroup, index;

    // create tab group
    self.elem.prepend('<span class="foswikiClear"></span>');
    $tabGroup = $('<ul class="jqTabGroup"></ul>').prependTo(self.elem);

    // get all headings and create tabs
    index = 1;
    self.elem.find("> .jqTab").each(function() {
      var $this = $(this),
          title = $this.find('.jqTabLabel:first').remove().html();
      $tabGroup.append('<li><a href="#" data-id="'+this.id+'">'+title+'</a></li>');
      $this.data("hash", '!'+this.id);
      if(index === self.opts.select || $(this).hasClass(self.opts.select)) {
        self.switchTab($this);
      }
      index++;
    });


    /* establish auto max expand */
    if (self.opts.autoMaxExpand) {
      self.autoMaxExpand();
    }

    self.elem.find(".jqTabGroup > li > a").click(function() {
      var $this = $(this);

      $this.blur();

      if ($this.data("id") !== self.currentTabId) {
        self.switchTab("#"+$this.data("id"));

        // set hash
/* DISABLED for performance reasons: see http://foswiki.org/Tasks/Item13018
        var newHash = $("#"+newTabId).data("hash"), oldHash = window.location.hash.replace(/^.*#/, "");
        if (newHash != oldHash) {
          window.location.hash = newHash;
        }
*/
      }
      return false;
    });

    self.initCurrentTab();
    $(window).bind("hashchange", function() {
      //$.log("TABPANE: got hashchange event");
      self.initCurrentTab();
    });
  };

  /* switch tab based on location hash****************************************/
  TabPane.prototype.initCurrentTab = function() {
    var self = this,
        currentHash = window.location.hash.replace(/^.*#/, "");

    if (typeof(self.prevHash) !== undefined && self.prevHash === currentHash) {
      return;
    }

    //$.log("TABPANE: initCurrentTab, currentHash="+currentHash+", prevHash="+self.prevHash);
    self.prevHash = currentHash;

    self.elem.find("> .jqTab").filter(function(index) {
      var $this = $(this);
      if (currentHash === '') {
        return (self.opts.select == index+1 || $this.hasClass(self.opts.select));
      } else {
        return ('!'+$this.attr("id") === currentHash);
      }
    }).each(function() {
      self.switchTab($(this));
    });
  };

  /***************************************************************************
   * get next tab
   */
  TabPane.prototype.getNextTab = function(selector) {
    var self = this,
        tabs = self.elem.find("> .jqTab"),
        index = 0;

    if (tabs.length === 1) {
      return;
    }

    selector = selector || "#"+self.currentTabId;
    tabs.each(function(i) {
      var $this = $(this);
      if ($this.is(selector)) {
        index = i;
        return false;
      }
    });
    index++;
    if (index >= tabs.length) {
      index = 0;
    }

    return tabs.eq(index);
  };

  /***************************************************************************
   * hide tab and select the next one
   */
  TabPane.prototype.hideTab = function(selector) {
    var self = this, nextTab;

    selector = selector || "#"+self.currentTabId;
    nextTab = self.getNextTab(selector);

    self.elem.find(selector).hide();
    self.getNaviOfTab(selector).hide();
    self.switchTab(nextTab);
  };

  /***************************************************************************
   * show a hidden tab and select it
   */
  TabPane.prototype.showTab = function(selector) {
    var self = this, tab;

    selector = selector || "#"+self.currentTabId;
    tab = self.elem.find(selector);

    if (tab.length) {
      self.getNaviOfTab(selector).show();
      if (self.currentTabId === tab.attr("id")) {
        tab.show();
      }
    }
  };

  /***************************************************************************
   * get list elem of tab
   */
  TabPane.prototype.getNaviOfTab = function(selectorOrObject) {
    var self = this, result = $(), tabId, selector;

    if (typeof(selectorOrObject) === 'object') {
      tabId = selectorOrObject.attr("id");
    } else {
      selector = selectorOrObject || "#"+self.currentTabId;
      tabId = self.elem.find(selector).attr("id");
    }

    self.elem.find("li a").each(function() {
      var $this = $(this);
      if ($this.data("id") === tabId) {
        result = $this;
        return false;
      }
    });

    return result;
  };

  /***************************************************************************
   * switching from tab1 to tab2
   */
  TabPane.prototype.switchTab = function(selectorOrObject) {
    var self = this,
        oldTabId = self.currentTabId,
        newTabId,
        $newTab, $newContainer,
        $oldTab = $("#"+oldTabId),
        $oldContainer = $oldTab.find('.jqTabContents:first'),
        oldHeight = $oldContainer.height(), // why does the container not work
        data, $innerContainer, isInnerContainer;

    if (typeof(selectorOrObject) === 'string') {
      $newTab= self.elem.find(selectorOrObject);
    } else {
      $newTab = selectorOrObject;
    }

    if ($newTab &&  $newTab.length) {
      newTabId = $newTab.attr("id");
    }

    //console.log("TABPANE: switching from "+oldTabId+" to "+newTabId);


    $oldTab.removeClass("current");
    self.getNaviOfTab($oldTab).parent().removeClass("current");
    if ($newTab) {
      $newTab.addClass("current");
      self.getNaviOfTab($newTab).parent().addClass("current");
    }

    // only switch off the old tab, no new tab there to activate
    if (!$newTab) {
      return;
    }

    if (oldTabId === newTabId) {
      return;
    }

    if (!self.tabs[newTabId]) {
      self.tabs[newTabId] = $newTab.data();
    }
    data = self.tabs[newTabId];

    // before click handler
    if (typeof(data.beforeHandler) !== "undefined") {
      window[data.beforeHandler].call(self, oldTabId, newTabId);
    }

    $newContainer = $newTab.find('.jqTabContents:first');
    if ((self.opts.animate || self.opts.autoMaxExpand) && oldHeight > 0 && !$newContainer.is(".jqTabDisableMaxExpand")) {
      //$.log("TABPANE: setting height to "+oldHeight);
      $newContainer.height(oldHeight);
    }

    $innerContainer = $newContainer;
    isInnerContainer = false;
    if(typeof(data.container) != "undefined") {
      $innerContainer = $newContainer.find(data.container);
      if ($innerContainer.length) {
	isInnerContainer = true;
      } else {
	$innerContainer = $newContainer;
      }
    }

    function _finally () {
      var effect = 'none', newHeight;

      if (oldHeight > 0) {
        effect = 'easeInOutQuad';
      }

      // adjust height of the current tab
      if (self.opts.autoMaxExpand) {
        if(self.opts.animate && effect !== 'none') {
          $innerContainer.css({opacity:0.0}).animate({
            opacity: 1.0
          }, 300);
        }
      } else {
        // animate height
        if (self.opts.animate) {
          if (effect !== 'none') {
            $newContainer.height('auto');
            newHeight = $newContainer.height();
            if (isInnerContainer) {
              $newContainer.height(oldHeight).animate({
                height: newHeight
              }, 300, effect, function() {
                $newContainer.height('auto');
              });
              $innerContainer.css({opacity:0.0}).animate({
                opacity: 1.0
              }, 300, effect);
            } else {
              $newContainer.height(oldHeight).css({opacity:0.0}).animate({
                opacity: 1.0,
                height: newHeight
              }, 300, effect, function() {
                $newContainer.height('auto');
              });
            }
          }
        }
      }
      $(window).trigger("resize");

      // after click handler
      if (typeof(data.afterHandler) !== "undefined") {
        window[data.afterHandler].call(self, oldTabId, newTabId);
      }

      self.currentTabId = newTabId;
    }

    // async loader
    if (typeof(data.url) != "undefined") {
      $innerContainer.load(data.url, undefined, function() {
        if (typeof(data.afterLoadHandler) !== "undefined") {
          window[data.afterLoadHandler].call(self, oldTabId, newTabId);
        }
        _finally();
      });
      delete self.tabs[newTabId].url;
    } else {
      _finally();
    }
  };

  /*************************************************************************
   * handler to listen to window-resize event to fire the fixHeight()
   * method
   */
  TabPane.prototype.autoMaxExpand = function() {
    var self = this;

    window.setTimeout(function() {
      self.fixHeight();
      $(window).one("resize.tabpane", function() {
        self.autoMaxExpand();
      });
    }, 100);
  };

  /*************************************************************************
   * adjust height of pane to window height
   */
  TabPane.prototype.fixHeight = function() {
    var self = this,
        $container = self.elem.find("> .jqTab.current .jqTabContents:first"),
        paneOffset = $container.offset(),
        paneTop, windowHeight, height, $debug;

    //$.log("TABPANE: called fixHeight()");

    if (typeof(paneOffset) === 'undefined' || $container.is(".jqTabDisableMaxExpand")) {
      return;
    }

    paneTop = paneOffset.top; // || $container[0].offsetTop;
    if (bottomBarHeight <= 0) {
      bottomBarHeight = $('.natEditBottomBar').outerHeight(true) + parseInt($container.css('padding-bottom'), 10) *2.5;
    }

    windowHeight = $(window).height();
    if (!windowHeight) {
      windowHeight = window.innerHeight; // woops, jquery, whats up for konqi
    }

    height = windowHeight - paneTop - bottomBarHeight;
    $debug = $("#DEBUG");
    if ($debug.length) {
      height -= $debug.outerHeight(true);
    }
    if (self.opts && self.opts.minHeight && height < self.opts.minHeight) {
      //$.log("tabpane: minHeight reached");
      height = self.opts.minHeight;
    }

    if (height < 0) {
      return;
    }

    $.log("TABPANE: fixHeight height=",height);
    $container.height(height);
  };

  $.fn.tabpane = function (opts) {
    return this.each(function () {
      if (!$.data(this, "tabPane")) {
        $.data(this, "tabPane", new TabPane(this, opts));
      }
    });
  };

  $(function() {
    $(".jqTabPane:not(.jqInitedTabpane)").livequery(function() {
      var $this = $(this);
      $this.addClass("jqInitedTabpane").tabpane();
    });
  });

}(jQuery));
