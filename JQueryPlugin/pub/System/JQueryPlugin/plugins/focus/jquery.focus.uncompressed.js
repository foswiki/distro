/* 
 * jquery.focus: 
 *   This sets the focus on a form input field
 *   or textarea of a form when the page is loaded
 * 
 */
jQuery(function($) {
  $(".jqFocus, .foswikiFocus").livequery(function() {
    var $this = $(this),
        opts = $.extend({}, { timeout: 100 }, $this.data());
    window.setTimeout(function() {
      try {
        $this.trigger("focus");
      } catch (error) {
        // ignore
      };
    }, opts.timeout);
  });
});
