(function($) {
  $(function() {
    $(".jqTooltip [title]").each(function() {
      var options = {
        delay:350,
        track:true,
        showURL:false,
        showBody:':',
        extraClass:'foswiki'
      };
      $.extend(options, $(this).metadata());
      $(this).tooltip(options);
    });
  });
})(jQuery);
