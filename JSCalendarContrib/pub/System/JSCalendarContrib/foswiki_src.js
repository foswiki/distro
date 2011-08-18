/*
Store calendar data in hash:
jscalendars[id] {
	format: format string,
	calendar: Calendar object
};
*/
var jscalendars = {};

function storeCalendar(id, cal, format) {
	"use strict";
	jscalendars[id] = {
		format: format,
		calendar: cal
	};
}

function convertExistingDateValue(value) {
	"use strict";
	if (value === undefined || value === '') {
		return;
	}

	// try to parse existing value to something that the calendar code understands
	if (foswiki && foswiki.Date) { 
		return new Date(foswiki.Date.parseDate(value));
	} else {
		return Date.parse(value);
	}
}

function initCalendar(format) {
	"use strict";
	if (_dynarch_popupCalendar !== null) {
		_dynarch_popupCalendar.hide();
	} 
	var cal = new Calendar(1, null, function (cal, date) {
		if (jQuery !== undefined) {
			$(cal.sel).val(date).change();
		} else {
			cal.sel.value = date;
		}
		if (typeof (cal.sel.onchange) === 'function') {
			cal.sel.onchange();
		}
		if (cal.dateClicked) {
			cal.callCloseHandler();
		}
	}, function (cal) {
		cal.hide();
		_dynarch_popupCalendar = null;
	});
	
	if (format) {
		cal.setDateFormat(format);
	}
	// show hour/minute interface?
	cal.showsTime = (format && format.search(/%H|%I|%k|%l|%M|%p|%P/) !== -1) ? true : false;

	// show am/pm interface?
	cal.time24 = (format && format.search(/%I|%l|%p|%P/) !== -1) ? false : true;
	
	// default settings
	cal.showsOtherMonths = true;
	cal.setRange(1900, 2070);
	
	_dynarch_popupCalendar = cal;
	
	cal.create();
	// note: once created, the display properties cannot be changed...
	
	return cal;
}

function showCalendar(id, format) {
	"use strict";
	var el = document.getElementById(id), calData = jscalendars[id], cal, date;
	if (calData !== undefined) {
		cal = calData.calendar;
		if (format === undefined || format === '') {
			// use the previously stored format
			format = calData.format;
		}
	}

	if (format === undefined || format === '') {
		alert("no format passed to calendar with id:" + id);
		return;
	}
	
	if (cal === undefined) {
		// perhaps formatValue was not called before
		cal = initCalendar(format);
		storeCalendar(id, cal, format);
		cal.sel = el;
	}

	date = convertExistingDateValue(el.value);
	if (date !== undefined) {
		cal.setDate(date);
		// update field
		cal.callHandler();
	}

	cal.showAtElement(el, "Br");
	
	return false;
}

function formatValue(id, format) {
	"use strict";
	if (format === undefined || format === '') {
		// formatValue must receive a format param
		alert("JSCalendarContrib error: No format passed to calendar with id:" + id);
		return;
	}
	var cal, el = document.getElementById(id), date;
	if (el.value !== undefined && el.value !== '') {
		date = convertExistingDateValue(el.value);
		if (date !== undefined) {
			cal = initCalendar(format);
			cal.setDate(date);
			cal.sel = el;
			// update field
			cal.callHandler();
		}
	}
	
	// if call is undefined,
	// do nothing, wait until showCalendar is called

	// store calender object for reuse when showCalendar is called
	// if no calendar is created we store the format anyway
	storeCalendar(id, cal, format);
}
