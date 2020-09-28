/*
 * jQuery Observer
 *
 * Copyright (c) 2020 Michael Daum https://michaeldaumconsulting.com
 *
 * Licensed under the GPL licenses http://www.gnu.org/licenses/gpl.html
 *
 */

"use strict";
(function($) {

  var MutationObserver = window.MutationObserver || window.WebKitMutationObserver || window.MozMutationObserver;

  function JQObserver(target) {
    var self = this;

    self.target = target || window.document;
    self.queries = {};
    self.counter = 0;
    self.timer = null; 
    self.paused = false;

    // create a worker
    self.worker = new MutationObserver(function() {

      //console.log("triggered worker");
      if (self.paused) {
        //console.log("observer is paused");
      } else {
        self.schedule();
      }
    });
   
    // start it
    self.worker.observe(self.target, {
      childList: true,
      subtree: true
    });
  }

  JQObserver.prototype.watch = function(query, callback) {
    var self = this,
        selector;

    //console.log("query=",query);
    if (typeof(query) === 'string') {
      selector = query;
    } else {
      selector = query.selector;
    }

    //console.log("watch selector=", selector);
    query = {
      "id": ++self.counter,
      "selector": selector,
      "callback": callback
    };

    // 1. run directly
    self.run(query);

    // 2. remember for later
    self.queries[selector] = query;
  };

  JQObserver.prototype.forget = function(query) {
    var self = this,
        selector = typeof(query) === 'string' ? query : query.selector;

    delete self.queries[selector];
  };

  JQObserver.prototype.pause = function() {
    this.paused = true;
  };

  JQObserver.prototype.play = function() {
    this.paused = false;
  };

  JQObserver.prototype.schedule = function() {
    var self = this;

    if (self.timer) {
      //console.log("cleared timer");
      window.clearTimeout(self.timer);
    }

    self.timer = window.setTimeout(function() {
      self.runAll();
    }, 20);
  };

  JQObserver.prototype.runAll = function() {
    var self = this;

    $.each(self.queries, function(selector, query) {
      self.run(query);
    });
  };

  JQObserver.prototype.run = function(query) {
    //var self = this;
    var key = "__observed_"+query.id;

    //console.log("called run, key=",key);
    $(query.selector)
      .not(function() {
        return $(this).data(key);
      }) 
      .each(query.callback)
      .each(function() {
        $(this).data(key, true);
      });
  };

  // create singleton observer
  window.JQObserver = window.JQObserver || new JQObserver();

  // add dom functions
  $.fn.observe = function(callback) {
    window.JQObserver.watch(this, callback);
    return this;
  };

  $.fn.unobserve = function() {
    window.JQObserver.forget(this);
    return this;
  };

  // compatibility with livequery
  if (!$.fn.livequery)  {
    $.fn.livequery = $.fn.observe;
    $.fn.expire = $.fn.unobserve;
  }

})(jQuery);
