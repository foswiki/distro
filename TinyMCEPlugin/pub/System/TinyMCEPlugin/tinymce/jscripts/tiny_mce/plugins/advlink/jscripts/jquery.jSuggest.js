/* Copyright (c) 2008 Kean Loong Tan http://www.gimiti.com/kltan
 * Licensed under the MIT (http://www.opensource.org/licenses/mit-license.php)
 * Copyright notice and license must remain intact for legal use
 * jSuggest
 * Version: 1.0 (May 26, 2008)
 * Requires: jQuery 1.2.6+
 */
(function($) {
		  
	$.fn.jSuggest = function(options) {
		// merge users option with default options
		var opts = $.extend({}, $.fn.jSuggest.defaults, options);		
		var jH = ".jSuggestHover";
		var jsH = "jSuggestHover";
		var iniVal = this.value;
		var textBox = this;
		var textVal = this.value;	
		var jC = "#jSuggestContainer";
		var defaultData = opts.data;
		
		$("body").append('<div id="jSuggestContainer"></div>');
		$(jC).hide();
		$(this).bind("keyup click", function(e){
			textBox = this;
			textVal = this.value;
			if (this.value.length >= opts.minchar && $.trim(this.value)!="Search Terms") {
				var offSet = $(this).offset();
				
				$(jC).css({
					position: "absolute",
					top: offSet.top + $(this).outerHeight() + "px",
					left: offSet.left,
					width: $(this).outerWidth()-2 + "px",
					opacity: opts.opacity,
					zIndex: opts.zindex
				}).show();
				
				// if escape key
				if (e.keyCode == 27 ) {
					$(jC).hide();
				}
				
				// if enter key
				else if (e.keyCode == 13 ) {
					if ($(jH).length == 1)
						$(textBox).val($(jH).text());
						$(jC).hide();
						iniVal = textBox.value;
				}
				// if down arrow
				else if (e.keyCode == 40) {
					// if any suggestion is highlighted
					if ($(jH).length == 1) {
						if (!$(jH).next().length == 0) {
							$(jH).next().addClass(jsH);
							$(".jSuggestHover:eq(0)").removeClass(jsH);
							if (opts.autoChange)
								$(textBox).val($(jH).text());
						}
					}
					else {
						$("#jSuggestContainer ul li:first-child").addClass(jsH);
						if (opts.autoChange)
							$(textBox).val($(jH).text());
					}
					
				}
				
				// if up arrow
				else if (e.keyCode == 38) {
					// if any suggestion is highlighted
					if ($(jH).length == 1 ) {
						if (!$(jH).prev().length == 0) {
							$(jH).prev().addClass(jsH);
							$(".jSuggestHover:eq(1)").removeClass(jsH);
							if (opts.autoChange)
								$(textBox).val($(jH).text());
						}
						// if is first child
						else {
							$(jH).removeClass(jsH);
							$(textBox).val(iniVal);
						}
					}
				}
				// new query detected
				else if (textBox.value != iniVal){
					iniVal = textBox.value;
					if ($(".jSuggestLoading").length==0)
						$('<div class="jSuggestLoading"><img src="'+opts.loadingImg+'" align="bottom" /> '+ opts.loadingText+'</div>').prependTo("#jSuggestContainer");
					
					$(".jSuggestLoading").show();
					$(jC).find('ul').remove();
					
					if (opts.data == '')
						opts.data = $(this).serialize();
					else 
						//opts.data = opts.data + "=" + $(this).val();
						opts.data = defaultData + "=" + $(this).val();
					// optimize server performance by loading at intervals
					setTimeout(function () {
						$.ajax({
							type: opts.type,
							url: opts.url,
							data: opts.data,
							success: function(msg){
								$(jC).find('ul').remove();
								$(jC).append(msg);
								$("#jSuggestContainer ul li").bind("mouseover",	function(){
										$(jH).removeClass(jsH);
										$(this).addClass(jsH);
										textVal = $(this).text();
										if (opts.autoChange)
											$(textBox).val($(jH).text());
								});
								$("#jSuggestContainer ul li").click(function(){
									$(this).addClass(jsH);
									$(textBox).val(textVal);
								});
								$(".jSuggestLoading").hide();
							}
						});
					}, opts.delay);
				}
			}
			// if text is too short do nothing and hide everything
			else {
				$(jH).removeClass(jsH);
				$(jC).hide();
			}
			
			// no bubbling, click is binded to textBox to prevent document bind from firing
			return false;
		});
		
		// why no use $(this).blur ?, because jSuggest box is hidden before click fires so this is the only way to do it
		// alternate way is to say that text blur will fire before$("#jSuggestContainer ul li") click.
		$(document).bind("click", function(){
			$(jC).hide();
			iniVal = textBox.value;
		});

	};
	
	$.fn.jSuggest.defaults = {
		minchar: 3,
		opacity: 1.0,
		zindex: 20000,
		delay: 2500,
		loadingImg: 'ajax-loader.gif',
		loadingText: 'Loading...',
		autoChange: false,
		url: "",
		type: "GET",
		data: ""
	};
		
	
		  

})(jQuery);