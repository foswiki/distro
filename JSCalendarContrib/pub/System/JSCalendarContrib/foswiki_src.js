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
	// date.js will perform the calculation
	// this simple file will not interpret other languages than English
	// future enhancement: include language files as well, see http://code.google.com/p/datejs/ 
	
	if (Date.Grammar !== undefined) {
	
		// date.js is loaded

		// convert Foswiki date string dd MMM yyyy to something that date.js underdstands
		var re, m;
		
		// 31 Dec 2001 and 31-Dec-2001
		re = /^\s*(\d+)[\s\-]+([\w]+)[\s\-]+(\d+)(\.*?)$/;
		m = re.exec(value);
		if (m !== null) {
			value = m[1] + '-' + m[2] + '-' + m[3] + ' ' + m[4];
		}
		
		// 2001.12.31.23.59.59
		re = /^\s*(\d{4})\.(\d{2})\.(\d{2})\.*(\d{2})*\.*(\d{2})*\.*(\d{2})*\s*$/;
		m = re.exec(value);
		if (m !== null) {
			value = m[1] + '-' + m[2] + '-' + m[3];
			if (m[4] !== undefined) {
				value += ' ' + m[4];
			}
			if (m[5] !== undefined) {
				value += ':' + m[5];
			}
			if (m[6] !== undefined) {
				value += ':' + m[6];
			}
		}

		// 2001-12-31 - 23:59
		re = /^\s*(\d{4})\-(\d{2})\-(\d{2})*\s*\-*\s*(\d{2})*\:*(\d{2})*\s*$/;
		m = re.exec(value);
		if (m !== null) {
			value = m[1] + '-' + m[2] + '-' + m[3];
			if (m[4] !== undefined) {
				value += ' ' + m[4];
			}
			if (m[5] !== undefined) {
				value += ':' + m[5];
			}
			if (m[6] !== undefined) {
				value += ':' + m[6];
			}
		}
		
		/*
		not supported yet:
		2009-1-12
		2009-1
		2009
		2001-12-31T23:59:59+01:00
		2001-12-31T23:59Z
		*/
		
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
