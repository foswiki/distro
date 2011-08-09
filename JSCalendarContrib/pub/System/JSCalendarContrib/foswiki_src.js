function initCalendar(format) {
	"use strict";
	if (_dynarch_popupCalendar !== null) {
		_dynarch_popupCalendar.hide();
	} else {
		var cal = new Calendar(1, null, function (cal, date) {
				cal.sel.value = date;
				if (typeof(cal.sel.onchange) === 'function') {
					cal.sel.onchange();
				}
				if (cal.dateClicked) {
					cal.callCloseHandler();
				}
			}, function (cal) {
				cal.hide();
				_dynarch_popupCalendar = null;
			});
		if (format && format.search(/%H|%I|%k|%l|%M|%p|%P/) !== -1) {
			cal.showsTime = true;
		} else {
			cal.showsTime = false;
		}
		cal.showsOtherMonths = true;
		_dynarch_popupCalendar = cal;
		cal.setRange(1900, 2070);
		cal.create();
	}
}

// Reuses the same "calendar" object for all date-type fields on the page
function showCalendar(id, format) {
	"use strict";
	if (format === undefined) {
		format = jQuery('#' + id).data('jscalendar-format');
	}
	if (format === undefined) {
		alert("no format passed to calendar with id:" + id);
		return;
	}
	initCalendar(format);
	if (format) {
		_dynarch_popupCalendar.setDateFormat(format);
	}
	var el = document.getElementById(id);
	_dynarch_popupCalendar.parseDate(el.value);
	_dynarch_popupCalendar.sel = el;
	_dynarch_popupCalendar.showAtElement(el, "Br");
	return false;
}

function formatValue(id, format) {
	"use strict";
	if (format === undefined || format === '') {
		alert("JSCalendarContrib error: No format passed to calendar with id:" + id);
		return;
	}
	initCalendar(format);
	if (format) {
		_dynarch_popupCalendar.setDateFormat(format);
	}
	var el = document.getElementById(id);
	_dynarch_popupCalendar.parseDate(el.value);
	_dynarch_popupCalendar.sel = el;
	_dynarch_popupCalendar.callHandler();
	
	// store format in attribute so it can be used
	// when the calendar is invoked with showCalendar()
	jQuery(function() {
		jQuery('#' + id).data('jscalendar-format', format);
	});
}
