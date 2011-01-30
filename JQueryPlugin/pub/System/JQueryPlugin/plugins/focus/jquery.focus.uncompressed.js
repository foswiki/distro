/* 
 * jquery.focus: 
 *   This sets the focus on a form input field
 *   or textarea of a form when the page is loaded
 * 
 */
jQuery(function($) {
  $(".jqFocus,.foswikiFocus").livequery(function() {
    var $this = $(this);
    window.setTimeout(function() {
      try {
        $this.focus();
      } catch (error) {
        // ignore
      };
    }, 100);
  });
});
