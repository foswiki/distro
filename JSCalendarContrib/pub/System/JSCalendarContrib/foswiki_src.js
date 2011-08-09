function initCalendar(format) {
	"use strict";
	if (_dynarch_popupCalendar !== null) {
		_dynarch_popupCalendar.hide();
	} 
	var cal = new Calendar(1, null, function (cal, date) {
			cal.sel.value = date;
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
	cal.showsOtherMonths = true;
	_dynarch_popupCalendar = cal;
	cal.setRange(1900, 2070);
	cal.create();
	return cal;
}

function showCalendar(id, format) {
	"use strict";
	if (format === undefined || format === '') {
		format = jQuery('#' + id).data('jscalendar-format');
	}
	if (format === undefined) {
		alert("no format passed to calendar with id:" + id);
		return;
	}
	var cal = initCalendar(format), el = document.getElementById(id);
	cal.parseDate(el.value);
	cal.sel = el;
	cal.showAtElement(el, "Br");
	return false;
}

function formatValue(id, format) {
	"use strict";
	if (format === undefined || format === '') {
		alert("JSCalendarContrib error: No format passed to calendar with id:" + id);
		return;
	}
	var cal = initCalendar(format), el = document.getElementById(id);
	cal.sel = el;
	cal.callHandler();
	
	// store format in attribute so it can be used
	// when the calendar is invoked with showCalendar()
	jQuery(function () {
		jQuery('#' + id).data('jscalendar-format', format);
	});
}
