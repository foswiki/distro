jQuery(function($) {
  if (foswiki.jquery && foswiki.jquery.toggle) {
    $.each(foswiki.jquery.toggle, function() {
      var options = this;
      var $this = $("#"+options.id);
      $this.click(function() {
        return options.onclick.call(this);
      });
    });
  }
});



