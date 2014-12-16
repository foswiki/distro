jQuery(function($) {
  $("#navigate").change(function(e) {
    var url = this.options[this.selectedIndex].value;
    if (url) {
      window.location.href = url;
    }
  });
});
