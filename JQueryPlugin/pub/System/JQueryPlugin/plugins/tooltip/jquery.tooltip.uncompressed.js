/*
 * jQuery Tooltip plugin 1.3_001
 *
 * http://bassistance.de/jquery-plugins/jquery-plugin-tooltip/
 * http://docs.jquery.com/Plugins/Tooltip
 *
 * Copyright (c) 2006 - 2008 Jörn Zaefferer
 *
 * $Id: jquery.tooltip.js 5741 2008-06-21 15:22:16Z joern.zaefferer $
 * 
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 */
 
(function($) {
	
		// the tooltip element
	var helper = {},
		// the current tooltipped element
		current,
		// the title of the current element, used for restoring
		title,
		// timeout id for delayed tooltips
		tID,
                // recent extraClass to remove before switching on the next
                recentExtraClass;
	
	$.tooltip = {
		blocked: false,
		defaults: {
			delay: 200,
			fade: false,
			showURL: true,
			extraClass: "",
			id: "tooltip",
                        top: 0,
                        left: 0
		},
		block: function() {
			$.tooltip.blocked = !$.tooltip.blocked;
		}
	};

	function settings(element) {
		return $.data(element, "tooltip");
	}
	
	function createHelper(settings) {
		// there can be only one tooltip helper
		if( helper.parent ) {
			return;
                }
		// create the helper, h3 for title, div for url
		helper.parent = $('<div id="' + settings.id + '"><h3></h3><div class="body"></div><div class="url"></div></div>')
			// add to document
			.appendTo(document.body)
			// hide it at first
			.hide();
			
		// apply bgiframe if available
		if ( $.fn.bgiframe ) {
			helper.parent.bgiframe();
                }
		
		// save references to title and url elements
		helper.title = $('h3', helper.parent);
		helper.body = $('div.body', helper.parent);
		helper.url = $('div.url', helper.parent);
	}

	function viewport() {
		return {
			x: $(window).scrollLeft(),
			y: $(window).scrollTop(),
			cx: $(window).width(),
			cy: $(window).height()
		};
	}
       

	/**
	 * callback for mousemove
	 * updates the helper position
	 * removes itself when no current element
	 */
	function update(event)	{
		if($.tooltip.blocked) {
			return;
                }
		
		if (event && event.target.tagName == "OPTION") {
			return;
		}
                
		// if no current element is available, remove this listener
		if( current === null ) {
			$(document.body).unbind('mousemove', update);
			return;	
		}
		
                var tsettings = settings(current);
		// stop updating when tracking is disabled and the tooltip is visible
		if ( (!tsettings.track) && helper.parent.is(":visible")) {
			$(document.body).unbind('mousemove', update);
		}
		
		// remove position helper classes
		helper.parent.removeClass("viewport-right viewport-bottom");
		
		var left = helper.parent[0].offsetLeft;
		var top = helper.parent[0].offsetTop;
		if (event) {
                        // position the helper 15 pixel to bottom right, starting from mouse position
                        left = event.pageX + tsettings.left;
                        top = event.pageY + tsettings.top;
			helper.parent.css({
				left: left,
				right: 'auto',
				top: top
			});
		}
		
                var v = viewport(), h = helper.parent[0];
                // check horizontal position
                if (v.x + v.cx < h.offsetLeft + h.offsetWidth) {
                  left -= h.offsetWidth + 20 + tsettings.left;
                  helper.parent.css({left: left + 'px'}).addClass("viewport-right");
                }
                // check vertical position
                if (v.y + v.cy < h.offsetTop + h.offsetHeight) {
                  top -= h.offsetHeight + 20 + tsettings.top;
                  helper.parent.css({top: top + 'px'}).addClass("viewport-bottom");
                }
	}
	

	// delete timeout and show helper
	function show() {
                var tsettings = settings(current);
		tID = null;
		function complete() {
			helper.parent.show().css("opacity", "1.0");
		}
		if (tsettings.fade) {
                        if (helper.parent.is(":animated")) {
                                helper.parent.stop().fadeTo(tsettings.fade, current.tOpacity, complete);
                        } else if (helper.parent.is(':visible')) {
                                helper.parent.stop().fadeTo(tsettings.fade, current.tOpacity, complete);
                        } else {
                                helper.parent.stop().fadeIn(tsettings.fade, complete);
                        }
		} else {
			complete();
		}
		update();
	}
	
        
	// main event handler to start showing tooltips
	function handle(event) {
                var tsettings = settings(this);
		// show helper, either with timeout or on instant
                helper.parent.stop();
		if( tsettings.delay && !helper.parent.is(":animated")) {
			tID = window.setTimeout(show, tsettings.delay);
		} else {
			show();
                }
		
		// if selected, update the helper position when the mouse moves
		$(document.body).bind('mousemove', update);
			
		// update at least once
		update(event);
	}
	
	
	// save elements title before the tooltip is displayed
	function save() {
                var tsettings = settings(this);
		// if this is the current source, or it has no title (occurs with click event), stop
		if ( $.tooltip.blocked || this == current || (!this.tooltipText && !tsettings.bodyHandler) ) {
			return;
                }

		// save current
		current = this;
		title = this.tooltipText;
		
		if ( tsettings.bodyHandler ) {
			helper.title.hide();
			var bodyContent = tsettings.bodyHandler.call(this);
			if (bodyContent.nodeType || bodyContent.jquery) {
				helper.body.empty().append(bodyContent);
			} else {
				helper.body.html( bodyContent );
			}
			helper.body.show();
		} else if ( tsettings.showBody ) {
			var parts = title.split(tsettings.showBody);
                        helper.title.empty();
                        helper.body.empty();
                        if (parts.length > 1) {
                          helper.title.html(parts.shift()).show();
                          for(var i = 0, part; (part = parts[i]); i++) {
				if(i > 0) {
					helper.body.append("<br/>");
                                }
				helper.body.append(part);
                          }
                        } else {
                          helper.body.html(parts.shift()).show();
                        }
			helper.body.hideWhenEmpty();
			helper.title.hideWhenEmpty();
		} else {
			helper.title.html(title).show();
			helper.body.hide();
		}
		
		// if element has href or src, add and show it, otherwise hide it
		if( tsettings.showURL && $(this).url() ) {
			helper.url.html( $(this).url().replace('http://', '') ).show();
		} else {
			helper.url.hide();
                }
		
		// add an optional class for this tip
                if (recentExtraClass && recentExtraClass != tsettings.extraClass) {
                  helper.parent.removeClass(recentExtraClass);
                }
                helper.parent.addClass(tsettings.extraClass);
                recentExtraClass = tsettings.extraClass;

		handle.apply(this, arguments);
	}
	
	// hide helper and restore added classes and the title
	function hide(event) {
		var tsettings = settings(this);

		if($.tooltip.blocked) {
			return;
                }

		// clear timeout if possible
		if(tID) {
			window.clearTimeout(tID);
                }
		// no more current element
		current = null;
		
		function complete() {
			helper.parent.hide().css("opacity", "");
		}

		if (tsettings.fade) {
                        if (helper.parent.is(':animated')) {
                                //helper.parent.stop().fadeTo(tsettings.fade, 0, complete);
                        } else {
                                helper.parent.stop().fadeOut(tsettings.fade, complete);
                        }

		} else {
			complete();
                }
	}


	$.fn.extend({
		tooltip: function(settings) {
                        settings = $.extend({}, $.tooltip.defaults, settings);
			createHelper(settings);
			return this.each(function() {
					$.data(this, "tooltip", settings);
					this.tOpacity = helper.parent.css("opacity");
					// copy tooltip into its own expando and remove the title
					this.tooltipText = this.title;
					$(this).removeAttr("title");
					// also remove alt attribute to prevent default tooltip in IE
					this.alt = "";
				})
				.mouseover(save)
				.mouseout(hide)
				.click(hide)
                                .bind("keypress", hide);
		},
		hideWhenEmpty: function() {
			return this.each(function() {
				$(this)[ $(this).html() ? "show" : "hide" ]();
			});
		},
		url: function() {
			return this.attr('href') || this.attr('src');
		}
	});
	
	
})(jQuery);
