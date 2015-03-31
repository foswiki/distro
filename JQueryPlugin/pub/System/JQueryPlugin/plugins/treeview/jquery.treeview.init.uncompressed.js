jQuery(function($){
  $(".jqTreeview:not(.jqInitedTreeview)").livequery(function() {
    var $this = $(this),
        thisClass = $this.attr('class'),
        opts = $.extend({}, $this.data(), $this.metadata());

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

    $this.addClass("jqInitedTreeview");
    $this.find("> ul").treeview(opts);
    $this.css('display', 'block');
  });
});
