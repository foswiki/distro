/**
* https://gist.github.com/823300
* based on
* http://www.hagenburger.net/BLOG/HTML5-Input-Placeholder-Fix-With-jQuery.html
* 
* Adapted for Foswiki by Arthur Clemens
* 
* Usage:
*
*  <input type="text" class="foswikiInputField" placeholder="Fill me ...">
*
*/
(function($) {
  var defaults = {
    css_class: 'placeholder'
  };

  $.fn.placeholder = function(options) {
    var opts = $.extend({}, defaults, options);

    $('[placeholder]').focus(function() {
      var input = $(this);
      if (input.hasClass(opts.css_class)) {
        input.val('');
        input.removeClass(opts.css_class);
      }
    }).blur(function() {
      var input = $(this);
      if (input.val() === '') {
        input.addClass(opts.css_class);
        input.val(input.attr('placeholder'));
      }
    }).blur().parents('form').submit(function() {
      $(this).find('[placeholder]').each(function() {
        var input = $(this);
        if (input.hasClass(opts.css_class)) {
          input.val('');
        }
      });
    });
  };

  $(function() {
    var test = document.createElement('input');
    $.support.placeholder = ('placeholder' in test);

    if (!$.support.placeholder) {
      $('[placeholder]').livequery(function() {
          $(this).placeholder();
      }); 
    }
  });

})(jQuery);
