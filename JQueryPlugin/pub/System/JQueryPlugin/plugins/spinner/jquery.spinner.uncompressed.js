/*
 * Simple jQuery spinner.
 * Based on: http://jquery.com/plugins/Authoring/
 * Original work from http://www.command-tab.com/2007/05/07/jquery-spinner-plugin/
 * Rewritten by Stéphane Lenclud to support multiple spinner per page and nicer API
 *
 * @version   20080225
 * @since     2008-02-25
 * @copyright Copyright (c) 2007 www.command-tab.com, Copyright (c) 2008 Stéphane Lenclud.
 * @author    Stéphane Lenclud <jquery@lenclud.com>
 * @license   GPL
 * @requires  >= jQuery 1.2.3
 */


//
// create closure
//
(function($) {
	
	
	//Prevent compilation error in case jquery.debug.js is not loaded
	function log(msg)
		{
		if ($.log)
			{
			$.log(msg);				
			}	
		}
	
  //
  // plugin definition
  //
  $.fn.spinner = function(options) {
	  
	//debug(this);
	// build main options before element iteration
	var opts = $.extend({}, $.fn.spinner.defaults, options);
	// iterate and reformat each matched element
	return this.each(function() {
	//Stop it first, to prevent double start
	//$.fn.spinner.stop();	
	
	$this = $(this);
	
	//check if we get a command option 
	if (typeof options == "string") {
		if (options == "stop")
			{
 			//
			var o = $.data(this,"spinner"); //restore
			if(o.intervalId) 
				{
				log("stop " + this.id);
				clearInterval(o.intervalId);
				o.intervalId=undefined;			 					
				$.data(this,"spinner",o); //store
				}
			return;
			}
		else if (options == "redraw")
			{
 			//Do redraw
			var o = $.data(this,"spinner");			
			log("redraw " + this.id);
			log(o);
			//log("frame" + o.frame);
			//if(o.intervalId) clearInterval(o.intervalId); 					
		
			//alert(o.frame);
			
	  		// If we've reached the last frame, loop back around
			if(o.frame >= o.frames) {
				o.frame = 1;
			}
		
			// Set the background-position for this frame
			pos = "-"+(o.frame*o.width)+"px 0px";
			$this.css("background-position",pos);
		
			// Increment the frame count
			o.frame=o.frame+1;
			$.data(this,"spinner",o);
	 				
			return;				
			}
		}
	
	//Normal contructor/starter		    
    // build element specific options
    var o = $.extend({}, opts, $.data(this,"spinner"));
    
    log("dump " + this.id);		
	log(o); //dump
	if (o.intervalId)
		{
		//Make sure we stop before starting again
		$this.spinner('stop');	
		}	
	
	
	// Set the height
	if(o.height) {
		$this.height(o.height);
	}
	
	// Set the width	
	if(o.width) {
		$this.width(o.width);
	}
	
	// Set or get the spinner image
	//if(o.image) {
		$this.css("background-image","url("+o.image+")");
		$this.css("background-position","0px 0px");
		$this.css("background-repeat","no-repeat");
	//} else {
	//	o.image = $this.css("background-image");
	//}
	
	// Store our data
	//$.data(this,"spinner",o);
	
	// Determine how many frames exist
	img = new Image();
	img.src = o.image;
	img.onload = function() {
		//var o = $.data(this,"spinner"); //restore
		log("image.onload " + this.id);		
		o.frames = img.width/o.width;
		log(o);
		$.data(this,"spinner",o); //store
	};
	
	// Set the frame speed
	if(!o.speed) {
		o.speed = 25;
	}
	
	
	log("start " + this.id);
	
	o.frame=0;
	
	//o.intervalId=setInterval("$.fn.spinner.redraw(this)",o.speed);
	
	// Kick off the animation
	o.intervalId=setInterval("$('#" + this.id +"').spinner('redraw')",o.speed);

	// Store our data
	$.data(this,"spinner",o);
	//var spinnerAnimation = setInterval(spinnerRedraw,options.speed);
  		
	});
  };
  
  
  //
  // plugin defaults
  //
  $.fn.spinner.defaults = {
	height: 32,
	width: 32,
	speed: 50,
	frame: 0,
	frames: 31,
	intervalId: 0
  };
  

  
//
// end of closure
//
})(jQuery);


