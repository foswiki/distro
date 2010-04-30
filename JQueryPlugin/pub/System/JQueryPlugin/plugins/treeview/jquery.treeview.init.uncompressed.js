jQuery(function($){
  $(".jqTreeview:not(.jqInitedTreeview)").livequery(function() {
    var $this = $(this);
    $this.addClass("jqInitedTreeview");
    var parentClass = $this.attr('class');
    $this.find("> ul").each(function(){
      var args = {};
      if (parentClass.match(/\bopen\b/)) {
        args.collapsed = false;
      }
      if (parentClass.match(/\bclosed?\b/)) {
        args.collapsed = true;
      }
      if (parentClass.match(/\bunique\b/)) {
        args.unique = true;
      }
      if (parentClass.match(/\bprerendered\b/)) {
        args.prerendered = true;
      }
      args.animated = 'fast';
      if (parentClass.match(/\bspeed_(fast|slow|normal|none|[\d\.]+)\b/)) {
        var speed = RegExp.$1;
        if (speed == "none") {
          delete args.animated;
        } else {
          args.animated;
        }
      }
      $(this).treeview(args);
    });
    $this.css('display', 'block');
  });
});
