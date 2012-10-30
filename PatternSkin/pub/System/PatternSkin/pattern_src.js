var pattern;
if (!pattern) {
	pattern = {};
}

pattern.base = (function ($) {

	"use strict";
	
	return {
		
		removeYellowFromInputs: function() {
			if (navigator.userAgent.toLowerCase().indexOf('chrome') >= 0) {
				var chromechk_watchdog = 0,
					chromechk;
				chromechk = setInterval(function() {
					if ($('input:-webkit-autofill').length > 0) {
						clearInterval(chromechk);
						$('input:-webkit-autofill').each(function () {
							var value = $(this).val(),
								name = $(this).attr('name');
							$(this).after(this.outerHTML).remove();
							$('input[name=' + name + ']').val(value);
						});
					} else if (chromechk_watchdog > 20) {
						clearInterval(chromechk);
					}
					chromechk_watchdog++;
				}, 50);
			}
		}

	};
}(jQuery));

jQuery(document).ready(function ($) {

    "use strict";
    
	pattern.base.removeYellowFromInputs();

	// add focus to elements with class foswikiFocus
	$('input.foswikiFocus').each(function () {
		$(this).focus();
	});
	
	// Search page handling
	var searchResultsCount = 0;
	$('.foswikiSearchResultCount span').livequery(function () {
		searchResultsCount += parseInt($(this).html(), 10);
	});

	if (searchResultsCount > 0) {
		$('#foswikiNumberOfResultsContainer').livequery(function () {
			// write result count
			$(this).html(' ' + foswiki.getMetaTag('TEXT_NUM_TOPICS') + ' <b>' + searchResultsCount + ' </b>');
		});
	}

	$('input.foswikiFocus').livequery(function () {
		$(this).focus();
	});

	$('input.foswikiChangeFormButton').on('click', function () {
		if (foswiki.Edit) {
			foswiki.Edit.validateSuppressed = true;
		}
	});

	$('body.patternEditPage input').on('keydown', function (event) {
		if (event.keyCode === 13) {
			return false;
		}
	});
});
