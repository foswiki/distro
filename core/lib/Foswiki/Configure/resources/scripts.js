/* Don't use // style comments, or you'll break the stupid minifier  */
function getElementsByClassName(inRootElem, inClassName, inTag) {
	var rootElem = inRootElem || document;
	var tag = inTag || '*';
	var elms = rootElem.getElementsByTagName(tag);
	var className = inClassName.replace(/\-/g, "\\-");
	var re = new RegExp("\\b" + className + "\\b");
	var el;
	var hits = new Array();
	for (var i = 0; i < elms.length; i++) {
		el = elms[i];
		if (re.test(el.className)) {
			hits.push(el);
		}
	}
	return hits;
}

function addLoadEvent (fn, prepend) {
	var oldonload = window.onload;
	if (typeof oldonload != 'function')
		window.onload = function() {
			fn();
		};
	else if (prepend)
        window.onload = function() {
            fn(); oldonload();
        };
    else
        window.onload = function() {
            oldonload(); fn();
        };
}

function initDeltaIndicators() {
	var elems = getElementsByClassName(document.forms.update, 'delta' , 'SPAN');	
	var i, ilen = elems.length;
	for (i=0; i<ilen; ++i) {
		initDelta(elems[i]);
	}
}

function initDelta(inElem) {
	var value = replaceStubChars(inElem.title);
	var type = inElem.className.split(" ")[0];
	var title = formatLinkValueInTitle(type, "default=", value);
	inElem.title = title;
}

function initDefaultLinks() {
	var elems = getElementsByClassName(document.forms.update, 'defaultValueLink' , 'A');	
	var i, ilen = elems.length;
	for (i=0; i<ilen; ++i) {
		initDefaultLink(elems[i]);
	}
}

/**
Initializes the 2 states of "reset to default" links.
State 1: restore to default
State 2: undo restore
*/
function initDefaultLink(inLink) {

	/* extract type */
	var type = inLink.className.split(" ")[0];
	inLink.type = type;
	
	/* retrieve value from title tag */
	inLink.defaultValue = replaceStubChars(inLink.title);
	/* set title states */
	inLink.setDefaultTitle = 'Set to default value:';
	inLink.undoDefaultTitle = 'Undo default and use previous value:';
	/* set link label states */
	inLink.setDefaultLinkText = 'use&nbsp;default';
	inLink.undoDefaultLinkText = 'undo';
	
	/* set defaults */
	inLink.title = formatLinkValueInTitle(
        inLink.type, inLink.setDefaultTitle, inLink.defaultValue);
	inLink.innerHTML = inLink.setDefaultLinkText;
}

/**
Prepend a string to a human readable value string.
*/
function formatLinkValueInTitle (inType, inString, inValue) {
	return (inString + createHumanReadableValueString(inType, inValue));
}

/**
Called from "reset to default" link.
Values are set in UIs/Value.pm
*/
function resetToDefaultValue (inLink, inFormType, inName, inValue) {

	var name = replaceStubChars(inName);
	var elem = document.forms.update[name];
	if (!elem) return;
	
	var value = replaceStubChars(inValue);
	if (inLink.oldValue != null) value = inLink.oldValue;

	var oldValue;
	var type = elem.type;

	if (type == 'checkbox') {
		oldValue = elem.checked;
		elem.checked = value;
	} else if (type == 'select-one') {
		/* find selected element */
		var index;
		for (var i=0; i<elem.options.length; ++i) {
			if (elem.options[i].value == value) {
				index = i;
				break;
			}
		}
		oldValue = elem.options[elem.selectedIndex].value;
		elem.selectedIndex = index;
	} else if (type == 'radio') {
		oldValue = elem.checked;
		elem.checked = value;
	} else {
		/* including type='text'  */
		oldValue = elem.value;
		elem.value = value;
	}
	
	if (inLink.oldValue == null) {
		/* we have just set the default value */
		/* prepare undo link */
		inLink.innerHTML = inLink.undoDefaultLinkText;
		inLink.oldValue = oldValue;
		inLink.title = formatLinkValueInTitle(inLink.type, inLink.undoDefaultTitle, oldValue);
	} else {
		/* we have just set the old value */
		inLink.innerHTML = inLink.setDefaultLinkText;
		inLink.oldValue = null;
		inLink.title = formatLinkValueInTitle(inLink.type, inLink.setDefaultTitle, value);
	}
	return false;
}

/**
Translates a value to a readable string that makes sense in a form.
For instance, 'false' gets translated to 'off' with checkboxes.

Possible types:
URL
PATH
URLPATH
STRING
BOOLEAN
NUMBER
SELECTCLASS
SELECT
REGEX
OCTAL
COMMAND
PASSWORD
PERL (?)
*/
function createHumanReadableValueString (inType, inValue) {
	if (inType == 'NUMBER') {
		/* do not convert numbers */
		return inValue;
	}
	if (inType == 'BOOLEAN') {
		if (isTrue(inValue)) {
			return 'on';
		} else {
			return 'off';
		}
	}
	if (inValue.length == 0) {
		return '""';
	}
	/* all other cases */
	return inValue;
}

/**
Checks if a value can be considered true.
*/
function isTrue (v) {
	if (v == 1 || v == '1' || v == 'on' || v == 'true')
        return 1;
	return 0;
}

/**
Replaces stubs for single and double quotes and newlines with the real characters.
*/
function replaceStubChars(v) {
	var re
	re = new RegExp(/#26;/g);
	v = v.replace(re, "'");
	re = new RegExp(/#22;/g);
	v = v.replace(re, '"');
	re = new RegExp(/#13;/g);
	v = v.replace(re, "\r");
	return v;
}

var expertsMode = 'block';

function toggleExpertsMode() {
    var antimode = expertsMode;
    expertsMode = (antimode == 'block' ? 'none' : 'block');
    var els = getElementsByClassName(document, 'expert');
    for (var i = 0; i < els.length; i++) {
        els[i].style.display = expertsMode;
    }
    els = getElementsByClassName(document, 'notExpert');
    for (var i = 0; i < els.length; i++) {
        els[i].style.display = antimode;
    }
}

function tab(newTab) {
    var body = document.getElementsByTagName('body')[0];
    var curTab = body.className;
    if (!newTab) newTab = curTab;
    body.className = newTab;
    var tab = document.getElementById(curTab + '_body');
    tab.className = 'tabBodyHidden';
    tab = document.getElementById(newTab + '_body');
    tab.className = 'tabBodyVisible';
}

function getTip(idx) {
    var div = document.getElementById('tt' + idx);
    if (div)
        return div.innerHTML;
    else
        return "LOST TIP "+idx;
}

addLoadEvent(initDeltaIndicators);
addLoadEvent(initDefaultLinks);
addLoadEvent(function () { tab(); toggleExpertsMode() });

