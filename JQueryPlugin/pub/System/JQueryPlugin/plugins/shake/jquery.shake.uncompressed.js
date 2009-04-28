/* http://zeroedandnoughted.wordpress.com/2008/05/01/jquery-plugin-to-emulate-shake-on-login-failure-in-osx-login-box/ */
jQuery.fn.shake = function(intShakes /*Amount of shakes*/, intDistance /*Shake distance*/, intDuration /*Time duration*/) {  
  this.each(function() {  
    $(this).css({position:'relative'});  
    for (var x=1; x<=intShakes; x++) {  
      $(this).animate({left:(intDistance*-1)}, (((intDuration/intShakes)/4)))  
      .animate({left:intDistance}, ((intDuration/intShakes)/2))  
      .animate({left:0}, (((intDuration/intShakes)/4)));  
    }  
  });  
  return this;  
}; 
