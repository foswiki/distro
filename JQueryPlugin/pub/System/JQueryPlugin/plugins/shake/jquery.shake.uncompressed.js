(function($) {
  $.fn.shake = function(
    intShakes /*Amount of shakes*/, 
    intDistance /*Shake distance*/, 
    intDuration /*Time duration*/) {  

    this.each(function() {  
      var $this = $(this), origLeft = parseInt($this.css('left'), 10);
      $this.css({position:'relative'});  

      for (var x=1; x<=intShakes; x++) {  
        $this
          .animate({left:(origLeft-intDistance)}, (((intDuration/intShakes)/4)))  
          .animate({left:(origLeft+intDistance)}, ((intDuration/intShakes)/2))  
          .animate({left:origLeft}, (((intDuration/intShakes)/4)));  
      }  
    });  

    return this;  
  }; 
})(jQuery);
