(function(){
$(function(){
  /********************************************************
   * treeview stuff
   */
  var $jqTreeviews;
  if (true) {
    $jqTreeviews = $(".jqTreeview");
    $jqTreeviews.children("> ul").each(function(){
      /*$("a,span,input", this).tooltip({
        delay:250,
        track:false,
        showURL:false,
        extraClass:'foswiki',
        showBody:": "
      });*/
      var args = Array();
      var parentClass = $(this).parent().attr('class');
      if (parentClass.match(/\bopen\b/)) {
        args['collapsed'] = false;
      }
      if (parentClass.match(/\bclosed?\b/)) {
        args['collapsed'] = true;
      }
      if (parentClass.match(/\bunique\b/)) {
        args['unique'] = true;
      }
      if (parentClass.match(/\bprerendered\b/)) {
        args['prerendered'] = true;
      }
      args['animated'] = 'fast';
      if (parentClass.match(/\bspeed_(fast|slow|normal|none|[\d\.]+)\b/)) {
        var speed = RegExp.$1;
        if (speed == "none") {
          delete args['animated'];
        } else {
          args['animated'] = speed;
        }
      }
      $(this).treeview(args);
    });
    if ($jqTreeviews) {
      $jqTreeviews.css('display', 'block');
    }
  }

});
})(jQuery);
