/* Don't use // style comments, or you'll break the stupid minifier  */

var foswiki; if (foswiki == undefined) foswiki = {};
foswiki.CSS = {

	/**
	Remove the given class from an element, if it is there.
	@param el : (HTMLElement) element to remove the class of
	@param inClassName : (String) CSS class name to remove
	*/
	removeClass:function(el, inClassName) {
		if (!el) return;
		var classes = foswiki.CSS.getClassList(el);
		if (!classes) return;
		var index = foswiki.CSS._indexOf(classes, inClassName);
		if (index >= 0) {
			classes.splice(index,1);
			foswiki.CSS.setClassList(el, classes);
		}
	},
	
	/**
	Add the given class to the element, unless it is already there.
	@param el : (HTMLElement) element to add the class to
	@param inClassName : (String) CSS class name to add
	*/
	addClass:function(el, inClassName) {
		if (!el) return;
		var classes = foswiki.CSS.getClassList(el);
		if (!classes) return;
		if (foswiki.CSS._indexOf(classes, inClassName) < 0) {
			classes[classes.length] = inClassName;
			foswiki.CSS.setClassList(el,classes);
		}
	},
	
	/**
	Replace the given class with a different class on the element.
	The new class is added even if the old class is not present.
	@param el : (HTMLElement) element to replace the class of
	@param inOldClass : (String) CSS class name to remove
	@param inNewClass : (String) CSS class name to add
	*/
	replaceClass:function(el, inOldClass, inNewClass) {
		if (!el) return;
		foswiki.CSS.removeClass(el, inOldClass);
		foswiki.CSS.addClass(el, inNewClass);
	},
	
	/**
	Get an array of the classes on the object.
	@param el : (HTMLElement) element to get the class list from
	*/
	getClassList:function(el) {
		if (!el) return;
		if (el.className && el.className != "") {
			return el.className.split(' ');
		}
		return [];
	},
	
	/**
	Set the classes on an element from an array of class names.
	@param el : (HTMLElement) element to set the class list to
	@param inClassList : (Array) list of CSS class names
	*/
	setClassList:function(el, inClassList) {
		if (!el) return;
		el.className = inClassList.join(' ');
	},
	
	/**
	Determine if the element has the given class string somewhere in it's
	className attribute.
	@param el : (HTMLElement) element to check the class occurrence of
	@param inClassName : (String) CSS class name
	*/
	hasClass:function(el, inClassName) {
		if (!el) return;
		if (el.className) {
			var classes = foswiki.CSS.getClassList(el);
			if (classes) return (foswiki.CSS._indexOf(classes, inClassName) >= 0);
			return false;
		}
	},
	
	/* PRIVILIGED METHODS */
	
	/**
	See: foswiki.Array.indexOf
	Function copied here to prevent extra dependency on foswiki.Array.
	*/
	_indexOf:function(inArray, el) {
		if (!inArray || inArray.length == undefined) return null;
		var i, ilen = inArray.length;
		for (i=0; i<ilen; ++i) {
			if (inArray[i] == el) return i;
		}
		return -1;
	}

}

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
	var elems = getElementsByClassName(document.forms.update, 'delta' , 'A');	
	var i, ilen = elems.length;
	for (i = 0; i < ilen; ++i) {
        var inElem = elems[i];
        var value = decode(inElem.title);
        var type = inElem.className.split(" ")[0];
        var title = formatLinkValueInTitle(type, "default=", value);
        inElem.title = title;
    }
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
	inLink.defaultValue = decode(inLink.title);
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

	var name = decode(inName);
	var elem = document.forms.update[name];
	if (!elem) return;
	
	var value = decode(inValue);
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
Replaces encoded characters with the real characters.
*/
function decode(v) {
	var re = new RegExp(/#(\d\d)/g);
	return v.replace(re,
                     function (str, p1) {
                         return String.fromCharCode(parseInt(p1));
                     });
}

var expertsMode = '';

function toggleExpertsMode() {
    var antimode = expertsMode;
    expertsMode = (antimode == 'none' ? '' : 'none');
    var els = getElementsByClassName(document, 'configureExpert');
    for (var i = 0; i < els.length; i++) {
        els[i].style.display = expertsMode;
    }
    els = getElementsByClassName(document, 'configureNotExpert');
    for (var i = 0; i < els.length; i++) {
        els[i].style.display = antimode;
    }
}

function tab(newTab) {
    var body = document.getElementsByTagName('body')[0];
    var curTab = body.className;    
    if (!newTab) {
    	var anchorPattern = new RegExp(/#(.*)$/);
		var matches = window.location.href.match(anchorPattern);
		if (matches[1]) {
			newTab = matches[1];
		} else {
	    	newTab = curTab;
	    }
    }
    body.className = newTab;
    var currentTabBody = document.getElementById(curTab + '_body');    
    foswiki.CSS.addClass(currentTabBody, 'foswikiMakeHidden');
    var newTabBody = document.getElementById(newTab + '_body');
    foswiki.CSS.removeClass(newTabBody, 'foswikiMakeHidden');
}

function getTip(idx) {
    var div = document.getElementById('tt' + idx);
    if (div)
        return div.innerHTML;
    else
        return "LOST TIP "+idx;
}

var tabIdPattern = new RegExp(/\btabId_(.*?)\b/);

var rules = {
	'.tabli' : function(el) {

		/*
		Get the id the link is pointing to; this is encrypted in the classname:
		
		tabId_Introduction
		
		... points to id Introduction.
		The new property 'pointer' is set to that id.
		*/
		var matches = el.className.match(tabIdPattern);
		if (matches[1]) {
			el.pointer = matches[1];
		}
		
		el.onclick = function() {
			tab(el.pointer);
		}
	}
};
Behaviour.register(rules);

addLoadEvent(tab);
addLoadEvent(toggleExpertsMode);
addLoadEvent(initDeltaIndicators);
addLoadEvent(initDefaultLinks);


