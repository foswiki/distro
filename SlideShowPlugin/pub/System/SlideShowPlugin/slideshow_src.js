/*
 * jQuery hashchange event - v1.3 - 7/21/2010
 * http://benalman.com/projects/jquery-hashchange-plugin/
 * 
 * Copyright (c) 2010 "Cowboy" Ben Alman
 * Dual licensed under the MIT and GPL licenses.
 * http://benalman.com/about/license/
 */
(function($,e,b){var c="hashchange",h=document,f,g=$.event.special,i=h.documentMode,d="on"+c in e&&(i===b||i>7);function a(j){j=j||location.href;return"#"+j.replace(/^[^#]*#?(.*)$/,"$1")}$.fn[c]=function(j){return j?this.bind(c,j):this.trigger(c)};$.fn[c].delay=50;g[c]=$.extend(g[c],{setup:function(){if(d){return false}$(f.start)},teardown:function(){if(d){return false}$(f.stop)}});f=(function(){var j={},p,m=a(),k=function(q){return q},l=k,o=k;j.start=function(){p||n()};j.stop=function(){p&&clearTimeout(p);p=b};function n(){var r=a(),q=o(m);if(r!==m){l(m=r,q);$(e).trigger(c)}else{if(q!==m){location.href=location.href.replace(/#.*/,'')+q}}p=setTimeout(n,$.fn[c].delay)}$.browser.msie&&!d&&(function(){var q,r;j.start=function(){if(!q){r=$.fn[c].src;r=r&&r+a();q=$('<iframe tabindex="-1" title="empty"/>').hide().one("load",function(){r||l(a());n()}).attr("src",r||"javascript:0").insertAfter("body")[0].contentWindow;h.onpropertychange=function(){try{if(event.propertyName==="title"){q.document.title=h.title}}catch(s){}}}};j.stop=k;o=function(){return a(q.location.href)};l=function(v,s){var u=q.document,t=$.fn[c].domain;if(v!==s){u.title=h.title;u.open();t&&u.write('<script>document.domain="'+t+'"<\/script>');u.close();q.location.hash=v}}})();return j})()})(jQuery,this);

jQuery(document).ready(
    function ($) {
		var index = 0, hash = window.location.hash;
		var startingSlide = -1;
		var endSlide = 0;
		
		/*
		Retrieves (1-based) slide number from the hash and returns it as zero-based.
		Corrects for negative values; changed to 0.
		*/
		function slideNumFromHash(hash) {
			index = /\d+/.exec(hash)[0];
			var slideNum = (parseInt(index) || 1) - 1; // slides are zero-based
			if (slideNum < 0) slideNum = 0;
			return slideNum
		}
		
		/*
		If the url contains a hash, use that to retrieve the starting slide from.
		Otherwise start at slide 0.
		*/
		if (hash) {
			startingSlide = slideNumFromHash(hash);
		} else {
			startingSlide = 0;
		}
		
		if (startingSlide != -1) {
			$('.slideshow').hide();
		}
		
		/*
		Updates the jump field with the slide number.
		*/
		function updateJumpInputField(slideNum) {
			// translate to 1-based index
			slideNum++;
			$('.slideshowJumpInputField').val(slideNum);
		}
		
		/*
		Go to next slide (current slide derived from hash).
		*/
		function goToNextSlide() {
			var hash = window.location.hash;
			var slideNum = slideNumFromHash(hash) + 1;
			if (slideNum > endSlide) slideNum = endSlide;
			$('.slideshow').cycle( slideNum );
		}
		
		/*
		Go to previous slide (current slide derived from hash).
		*/
		function goToPreviousSlide() {
			var hash = window.location.hash;
			var slideNum = slideNumFromHash(hash) - 1;
			if (slideNum < 0) slideNum = 0;
			$('.slideshow').cycle( slideNum );
		}
		
		/*
		Set up cycle plugin.
		*/
		$('.slideshow').cycle({
			height:'100%',
			width:'100%',
			containerResize:0,
			fx:'fade',
			startingSlide:startingSlide,
			timeout:0,
			speed:300,
			before:function(curr,next,opts) {
				endSlide = opts.slideCount - 1;
				updateJumpInputField(opts.nextSlide);
			},
			after:function(curr,next,opts) {
				window.location.hash = opts.currSlide + 1;
				updateJumpInputField(opts.currSlide);
			}
		}).show();
		
		/*
		Behaviour for links in the slide TOC. The links should contain a hash with slide number.
		*/
		$('.slideshowToc a').click(
			function() { 
				var hash = this.hash;
				var slideNum = slideNumFromHash(hash);
				$(this).parents('.slideshow:first').cycle(slideNum);
				return false;  
			}
		);
		
		/*
		Next button moves one slide forward. Same as clicking on the slide, but only if we are showing the controls at the top.
		*/
		$('a.slideshowBtnNext,.slideshowHasTopControls').click(
			function() {
				goToNextSlide();
				return false;  
			}
		);
		$('a.slideshowBtnPrevious').click(
			function() {
				goToPreviousSlide();
				return false;  
			}
		);
		$('a.slideshowBtnFirst').click(
			function() {
				$('.slideshow').cycle( 0 );
				return false;  
			}
		);
		$('a.slideshowBtnLast').click(
			function() {
				$('.slideshow').cycle( endSlide );
				return false;  
			}
		);
	
		/*
		Bind to hash changes.	
		*/
		$(window).hashchange(
			function() {
				var hash = window.location.hash;
				var slideNum = slideNumFromHash(hash);
				$('.slideshow').cycle(slideNum);
				updateJumpInputField(slideNum);
			}
		);
		
		/*
		Catch keypress in the jump field.
		Enter will "submit" the number.
		Do not allow non-numbers.
		*/
		$('.slideshowJumpInputField').keypress(
			function(e) {
				if (e.which == 13) {
					var slideNum = parseInt(this.value);
					if (slideNum != undefined) {
						slideNum--; // zero based index
						if (slideNum > endSlide) slideNum = endSlide;
						if (slideNum < 0) slideNum = 0;
						$('.slideshow').cycle(slideNum);
						this.blur();
						return false;
					}
				} else {
					return ( e.which!=8 && e.which!=0 && e.which!=46 && (e.which<48 || e.which>57)) ? false : true ;
				}
			}
		);
		
		/*
		On focus select the entire jump field.
		*/
		$('.slideshowJumpInputField').focus(
			function() {
				this.select();
			}
		);
		/*
		The same, for Chrome.
		*/
		$('.slideshowJumpInputField').live('focus mouseup',
			function(e) {
				if (e.type == 'focusin') {
					this.select();
				}
				if (e.type == 'mouseup') {
					return false;
				}
				if (e.type == 'keypress') {
					this.blur();
				}
			}
		);
		
		$(document).keydown(
			function (e) {
				var keyCode = e.keyCode || e.which,
				  arrow = {left: 37, up: 38, right: 39, down: 40 };
				switch (keyCode) {
					case arrow.left:
						goToPreviousSlide();
						break;
					case arrow.up:
						//..
						break;
					case arrow.right:
						goToNextSlide();
						break;
					case arrow.down:
						//..
						break;
				}
			}
		);
		
		/*
		Set slideshowPrevNext pos to fixed pixels, to prevent shifting on pages with scrollbar. On window resize this function will be called as well, so the controls will stay centered (more or less).
		*/
		function centerSlideshowPrevNext() {
			$('.slideshowPrevNext').livequery(
				function () {
					var WIDTH = 143; // we should calculate this
					var x = ($(window).width() - WIDTH) / 2;
					$(this).css('left', x + 'px');
				}
			);
		}
		
		$(window).bind('resize', centerSlideshowPrevNext);
		centerSlideshowPrevNext();
});
