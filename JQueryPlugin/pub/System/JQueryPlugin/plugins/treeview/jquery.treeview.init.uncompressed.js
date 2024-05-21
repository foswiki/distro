"use strict";

jQuery(function($){
  $(".jqTreeview:not(.inited)").livequery(function() {
    var $this = $(this),
        $ul = $this.find("ul:first"),
        thisClass = $this.attr('class'),
        opts = $.extend({}, $this.data());

    if (typeof(opts.open) !== 'undefined') {
      var maxDepth = parseInt(opts.open);
      $this.find("li").addClass("closed");
      if (maxDepth) {
        $this.find("li").filter(function(i, elem) {
          var depth = $(elem).parentsUntil($ul).length;
          return depth <= maxDepth;
        }).addClass("open").removeClass("closed");
      }
    }

    if (thisClass.match(/\bopen\b/)) {
      opts.collapsed = false;
    }
    if (thisClass.match(/\bclosed?\b/)) {
      opts.collapsed = true;
    }
    if (thisClass.match(/\bunique\b/)) {
      opts.unique = true;
    }
    if (thisClass.match(/\bprerendered\b/)) {
      opts.prerendered = true;
    }
    opts.animated = 'fast';
    if (thisClass.match(/\bspeed_(fast|slow|normal|none|[\d\.]+)\b/)) {
      var speed = RegExp.$1;
      if (speed == "none") {
        delete opts.animated;
      } else {
        opts.animated;
      }
    }

    $this.addClass("inited");
    $ul.treeview(opts);

    // SMELL: fix classes
    $this.find(".open.expandable").removeClass("expandable").addClass("collapsable");
    $this.find(".open.lastExpandable").removeClass("lastExpandable").addClass("lastCollapsable");
    $this.find(".open-hitarea.expandable-hitarea").removeClass("expandable-hitarea").addClass("collapsable-hitarea");
    $this.find(".open-hitarea.lastExpandable-hitarea").removeClass("lastExpandable-hitarea").addClass("lastCollapsable-hitarea");

    $this.css('display', 'block');
  });
});
