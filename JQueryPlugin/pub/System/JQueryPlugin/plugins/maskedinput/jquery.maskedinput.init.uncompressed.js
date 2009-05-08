(function($) {
  $(function() {
    $("input[mask]").each(function() {
      $(this).mask($(this).attr('mask'));
    });
  });
})(jQuery);
