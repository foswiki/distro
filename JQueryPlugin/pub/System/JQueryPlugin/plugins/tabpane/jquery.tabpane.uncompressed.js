/*
 * jQuery Tabpane plugin 2.11
 *
 * Copyright (c) 2008-2020 Foswiki Contributors http://foswiki.org
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
    remember: false,
    minHeight: 0
  };

  /* plugin constructor *****************************************************/
  function TabPane(elem, opts) {
    var self = this;

    self.elem = $(elem);

    // gather options by merging global defaults, plugin defaults and element defaults
    self.opts = $.extend({}, defaults, self.elem.data(), opts);
    self.init();
  }

  /* init ********************************************************************/
  TabPane.prototype.init = function() {
    var self = this,
        $tabGroup, index;

    self.id = self.getId();

    // create tab group
    self.elem.prepend('<span class="foswikiClear"></span>');
    $tabGroup = $('<ul class="jqTabGroup clearfix"></ul>').prependTo(self.elem);

    // get all headings and create tabs
    index = 1;
    self.elem.find("> .jqTab").each(function() {
      var $this = $(this),
          title = $this.find('.jqTabLabel:first').remove().html();

      $tabGroup.append('<li><a href="#" data-index="'+index+'">'+title+'</a></li>');

      $this.data("index", index);

      index++;
    });

    if (typeof(self.currentIndex) === 'undefined') {
      self.switchTab(1);
    }

    /* establish auto max expand */
    if (self.opts.autoMaxExpand) {
      self.autoMaxExpand();
    }

    /* establish click behaviour */
    self.elem.find(".jqTabGroup > li > a").on("click", function() {
      var $this = $(this), 
          index = $this.data("index");

      $this.trigger("blur");

      if (index !== self.currentIndex) {
        self.switchTab(index);
        if (self.opts.remember) {
          self.setHash(index);
        }
      }

      return false;
    });

    if (self.opts.remember) {
      $(window).on("hashchange", function() {
        self.switchTab(self.getHash() || self.opts.select || 1);
      });

      self.switchTab(self.getHash() || self.opts.select || 1);
    } else {
      self.switchTab(self.opts.select || 1);
    }
  };

  /* read window hash and split it into a meaningfull structure **************/
  TabPane.prototype.parseHash = function() {
    var hash = window.location.hash.replace(/^.*#!/, "").split(";"),
        item,
        params = {}, i, len = hash.length;

    for(i = 0; i < len; i++) {
      item = hash[i].split("=");
      if (item.length == 2) {
        params[item[0]] = parseInt(item[1], 10);
      }
    }

    return params;
  }

  /* get id and make sure it is unique ***************************************/
  TabPane.prototype.getId = function() {
    var self = this,
        id = self.elem.attr("id"),
        tabPanes = $("#"+id+".jqTabPane");

    if (tabPanes.length > 1) {
      id = parseInt(id.replace(/^tabpane/, ""), 10),
      self.elem.prop("id", "tabpane"+(id+1));
      return self.getId();
    }

    return id;
  };

  /* get my hash value for this tabpane **************************************/
  TabPane.prototype.getHash = function() {
    var self = this,
        params = self.parseHash();

    return params[self.id];
  };

  /* set my hash value *******************************************************/
  TabPane.prototype.setHash = function(val) {
    var self = this,
        params = self.parseHash(),
        hash = [],
        oldVal = params[self.id];

    if (val === oldVal) {
      return;
    }
  
    if (typeof(val) !== 'undefined') {
      params[self.id] = val;
    } else {
      delete params[self.id];
    }

    $.each(params, function(key, val) {
      if (Array.isArray(val)) {
        val = join("|", val);
      }
      hash.push(key+="="+val);
    });

    hash = '!' + hash.join(";");
   
    window.location.hash = hash;
  };

  /***************************************************************************
   * get tab specified by "selector"
   * selector can be:
   * - the index of a tab (1-based)
   * - or a jQuery selector expression
   * - or undefined returning the currently selected tab
   */
  TabPane.prototype.getTab = function(selector) {
    var self = this, tab;

    selector = selector || self.currentIndex || self.opts.select;

    if (typeof(selector) === 'object') {
      tab = selector;
    } else if (typeof(selector) === 'number') {
      tab = self.elem.find("> .jqTab").eq(selector-1);
    } else {
      tab = self.elem.find(selector);
    }

    if (typeof(tab) !== 'undefined' && tab.length == 0) {
      tab = undefined;
    }

    return tab;
  };

  /***************************************************************************
   * get the following tab after a selected one
   */
  TabPane.prototype.getNextTab = function(selector) {
    var self = this,
        tab = self.getTab(selector);

    if (tab) {
      return self.getTab(tab.data("index")+1);
    }    
  };

  /***************************************************************************
   * hide tab and select the next one
   */
  TabPane.prototype.hideTab = function(selector) {
    var self = this,
        tab = self.getTab(selector),
        index;

    if (!tab) {
      return;
    }

    index = tab.data("index");
    tab.hide();
    self.getNaviOfTab(index).hide();

    self.switchTab(index+1);
  };

  /***************************************************************************
   * show a hidden tab and select it
   */
  TabPane.prototype.showTab = function(selector) {
    var self = this, 
        tab = self.getTab(index), 
        index;

    if (!tab) {
      return;
    }

    index = tab.data("index");

    self.getNaviOfTab(index).show();
    tab.show();
  };

  /***************************************************************************
   * get list elem of tab
   */
  TabPane.prototype.getNaviOfTab = function(selector) {
    var self = this, 
        tab = self.getTab(selector),
        index;

    if (!tab) {
      return $();
    }

    index = tab.data("index");

    return self.elem.find("> .jqTabGroup li a").eq(index-1);
  };

  /***************************************************************************
   * switching from tab1 to tab2
   */
  TabPane.prototype.switchTab = function(selector) {
    var self = this,
        oldIndex = self.currentIndex,
        $oldTab, $oldContainer, oldHeight,
        newIndex,
        $newTab = self.getTab(selector), 
        $newContainer,
        data, $innerContainer, isInnerContainer;

    if (!$newTab) {
      return;
    }

    if (typeof(oldIndex) !== 'undefined') {
      $oldTab = self.getTab(oldIndex);
      $oldContainer = $oldTab.find('.jqTabContents:first');
      oldIndex = $oldTab.data("index");
      oldHeight = $oldContainer.height();
    }

    newIndex = $newTab.data("index");

    if (oldIndex === newIndex) {
      return;
    }

    if ($oldTab) {
      $oldTab.removeClass("current").hide();
      self.getNaviOfTab(oldIndex).parent().removeClass("current");
    }

    $newTab.addClass("current").show();
    self.getNaviOfTab(newIndex).parent().addClass("current");

    data = $newTab.data();

    // before click handler
    if (typeof(data.beforeHandler) !== "undefined") {
      window[data.beforeHandler].call(self, oldIndex, newIndex);
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
        window[data.afterHandler].call(self, oldIndex, newIndex);
      }

      self.currentIndex = newIndex;
    }

    // async loader
    if (typeof(data.url) != "undefined") {
      $innerContainer.load(data.url, undefined, function() {
        if (typeof(data.afterLoadHandler) !== "undefined") {
          window[data.afterLoadHandler].call(self, oldIndex, newIndex);
        }
        _finally();
      });
      $newTab.removeData("url");
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
        elem = self.elem.find("> .jqTab.current .jqTabContents:first"),
        windowHeight = $(window).height() || window.innerHeight,
        newHeight;

    //$.log("TABPANE: called fixHeight()");

    if (!elem.length || elem.is(".jqTabDisableMaxExpand")) {
      return;
    }

    if (bottomBarHeight <= 0) {
      bottomBarHeight = $(".natEditBottomBar").outerHeight(true) + elem.outerHeight(true) - elem.height();
    }

    newHeight = windowHeight - elem.offset().top - bottomBarHeight - 2;

    if (self.opts && self.opts.minHeight && newHeight < self.opts.minHeight) {
      //$.log("tabpane: minHeight reached");
      newHeight = self.opts.minHeight;
    }

    if (newHeight < 0) {
      return;
    }

    elem.height(newHeight);
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
      $this.tabpane().addClass("jqInitedTabpane");
    });
  });

}(jQuery));
