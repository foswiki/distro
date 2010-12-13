/* 
 * jquery.focus: 
 *   This sets the focus on a form input field
 *   or textarea of a form when the page is loade
 * 
 */
jQuery(function($) {
  $(".jqFocus").livequery(function() {
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
