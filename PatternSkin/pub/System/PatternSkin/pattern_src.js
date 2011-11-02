jQuery(document).ready(function ($) {

	"use strict";

	var searchResultsCount = 0;

	/*
	Only for Foswiki 1.0.
	*/
	/*
	// Create an attachment counter in the attachment table twisty.
	$('.foswikiAttachments').livequery(function () {
		var rows, count, countStr;
		rows = $(this).find('table.foswikiTable tr');
		if (!rows) {
			return;
		}
		count = rows.length - 1;
		countStr = " <span class='foswikiSmall'>" + count + "<\/span>";
		$(this).find('.patternAttachmentHeader').livequery(function () {
			$(this).append(countStr);
		});
	});
	*/
	
	// Search page handling
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

	$('input.foswikiChangeFormButton').livequery('click', function () {
		if (foswiki.Edit) {
			foswiki.Edit.validateSuppressed = true;
		}
	});

	$('body.patternEditPage input').livequery('keydown', function (event) {
		if (event.keyCode === 13) {
			return false;
		}
	});

});
