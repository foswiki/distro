/* 
 * jquery.focus: 
 *   This sets the focus on a form input field
 *   or textarea of a form when the page is loade
 * 
 */
;(function($) {
  $(function() {
    window.setTimeout(function() {
      try {
        $('.jqFocus:first').focus();
      } catch (error) {
        // ignore
      };
    }, 200);
  });
})(jQuery);
