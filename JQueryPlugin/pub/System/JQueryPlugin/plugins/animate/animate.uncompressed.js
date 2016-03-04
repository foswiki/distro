"use strict";
(function($) {

  $.fn.animateCSS = function (effect) { 
    var dfd = $.Deferred(), $this = $(this);
    
    $this.addClass("animated").addClass(effect).one("animationend webkitAnimationEnd MSAnimationEnd oAnimationEnd", function() {
      //console.log("animation ",effect,"ended");
      $this.removeClass("animated").removeClass(effect);
      dfd.resolve();
    });

    return dfd.promise();
  };
})(jQuery);
