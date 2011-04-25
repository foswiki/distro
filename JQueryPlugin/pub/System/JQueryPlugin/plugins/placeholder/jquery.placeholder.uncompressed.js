/**
* https://gist.github.com/823300
* based on
* http://www.hagenburger.net/BLOG/HTML5-Input-Placeholder-Fix-With-jQuery.html
* 
* Usage:
*
*  <input type="text" class="foswikiInputField" placeholder="Fill me ...">
*
*/
jQuery.placeholder = function() {
  $('[placeholder]').focus(function() {
    var input = $(this);
    if (input.hasClass('placeholder')) {
      input.val('');
      input.removeClass('placeholder');
      input.removeClass('foswikiInputFieldBeforeFocus');
    }
  }).blur(function() {
    var input = $(this);
    if (input.val() === '') {
      input.addClass('placeholder');
      input.addClass('foswikiInputFieldBeforeFocus');
      input.val(input.attr('placeholder'));
    }
  }).blur().parents('form').submit(function() {
    $(this).find('[placeholder]').each(function() {
      var input = $(this);
      if (input.hasClass('placeholder')) {
        input.val('');
      }
    });
  });
  
  // Clear input on refresh so that the placeholder class gets added back
  $(window).unload(function() {
    $('[placeholder]').val('');
  });
};

$('[placeholder]').livequery(function() {
    $.placeholder($(this));
}); 
