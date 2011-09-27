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
		// for simplicity, use included minified version
		return new Date(foswiki.DateFallback.parseDate(value));
	}
}

function initCalendar(format) {
	"use strict";
	if (_dynarch_popupCalendar !== null) {
		_dynarch_popupCalendar.hide();
	} 
	var cal = new Calendar(1, null, function (cal, date) {
		if (jQuery !== undefined) {
			jQuery(cal.sel).val(date).change();
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

foswiki.DateFallback={MONTH_LENGTHS:[31,28,31,30,31,30,31,31,30,31,30,31],MONTH_NUMBERS:{"Jan":1,"Feb":2,"Mar":3,"Apr":4,"May":5,"Jun":6,"Jul":7,"Aug":8,"Sep":9,"Oct":10,"Nov":11,"Dec":12},_daysInYear:function(year){"use strict";if(year%400){return 366;}
if(year%100){return 365;}
if(year%4){return 366;}
return 365;},parseDate:function(dateString,defaultLocal){"use strict";var regex,timeZoneOffsetMsecs=0,D,M,Y,h,m,s,tz,year,month,monthLength,day,hour,min,sec;dateString=dateString.replace(/^\s\s*/,'').replace(/\s\s*$/,'');if(defaultLocal){timeZoneOffsetMsecs=new Date().getTimezoneOffset()*60*1000;}
regex=/(\d+)[\-\s]+([a-z]{3})[\-\s]+(\d+)(?:[\-\s]+(\d+):(\d+))?/i;if(dateString.match(regex)){D=RegExp.$1!==''?parseInt(RegExp.$1,10):1;M=RegExp.$2!==''?foswiki.DateFallback.MONTH_NUMBERS[RegExp.$2]-1:0;Y=RegExp.$3!==''?parseInt(RegExp.$3,10):1;h=RegExp.$4!==''?parseInt(RegExp.$4,10):0;m=RegExp.$5!==''?parseInt(RegExp.$5,10):0;s=RegExp.$6!==''?parseInt(RegExp.$6,10):0;return new Date(Y,M,D,h,m,s).getTime()+timeZoneOffsetMsecs;}
regex=/(\d\d\d\d)(?:-(\d\d)(?:-(\d\d))?)?(?:T(\d\d)(?::(\d\d)(?::(\d\d(?:\.\d+)?))?)?)?(Z|[\-+]\d\d(?::\d\d)?)?/;if(dateString.match(/T/)&&dateString.match(regex)){Y=RegExp.$1;M=RegExp.$2!==''?parseInt(RegExp.$2,10)-1:0;D=RegExp.$3!==''?parseInt(RegExp.$3,10):1;h=RegExp.$4!==''?parseInt(RegExp.$4,10):0;m=RegExp.$5!==''?parseInt(RegExp.$5,10):0;s=RegExp.$6!==''?parseInt(RegExp.$6,10):0;tz=RegExp.$7!==''?RegExp.$7:'';if(tz==='Z'){timeZoneOffsetMsecs=0;}else if(tz.match(/([\-+])(\d\d)(?::(\d\d))?/)){var thr=RegExp.$2!==''?parseInt(RegExp.$2,10):0;var tmin=RegExp.$3!==''?parseInt(RegExp.$3,10):0;var offset=(thr*60+tmin);offset*=RegExp.$1==='-'?1:-1;timeZoneOffsetMsecs=offset*60*1000;}
return new Date(Y,M,D,h,m,s).getTime()+timeZoneOffsetMsecs;}
regex=/^(\d\d+)(?:\s*[\/\s.\-]\s*(\d\d?)(?:\s*[\/\s.\-]\s*(\d\d?)(?:\s*[\/\s.\-]\s*(\d\d?)(?:\s*[:.]\s*(\d\d?)(?:\s*[:.]\s*(\d\d?))?)?)?)?)?$/;if(dateString.match(regex)){year=RegExp.$1;M=RegExp.$2;D=RegExp.$3;h=RegExp.$4;m=RegExp.$5;s=RegExp.$6;if(M!==''&&(M<1||M>12)){return undefined;}
month=M!==''?M-1:0;monthLength=foswiki.DateFallback.MONTH_LENGTHS[month];if(month===1&&foswiki.DateFallback._daysInYear(year)===366){monthLength=29;}
if(D!==''&&(D<0||D>monthLength)){return undefined;}
if(h!==''&&(h<0||h>24)){return undefined;}
if(m!==''&&(m<0||m>60)){return undefined;}
if(s!==''&&(s<0||s>60)){return undefined;}
if(year!==''&&year<60){return undefined;}
day=D!==''?D:1;hour=h!==''?h:0;min=m!==''?m:0;sec=s!==''?s:0;return new Date(year,month,day,hour,min,sec).getTime()+timeZoneOffsetMsecs;}}};;
