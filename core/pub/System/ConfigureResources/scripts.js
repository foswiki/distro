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

/* EXPERT MODE */

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

/* ----------------------------- MENU ----------------------------- */

var tabLinks = {};
var subSectionId;

var menuState = {};
menuState.main = undefined;
menuState.defaultSub = {};
menuState.allOpened = -1;

function setMain(inId) {
	menuState.main = inId;
}
function getMain() {
	return menuState.main;
}
function setSub(inMainId, inSubId) {
	menuState[inMainId] = inSubId;
}
function getSub(inMainId) {
	return menuState[inMainId];
}
function setDefaultSub(inMainId, inSubId) {
	if (menuState.defaultSub[inMainId]) return;
	menuState.defaultSub[inMainId] = inSubId;
}
function getDefaultSub(inMainId) {
	return menuState.defaultSub[inMainId];
}

/*
sub states are stored like this:
var sub = 'Language';
menuState[menuState.main].sub = sub;
*/
function initSection() {

	if (document.location.hash && document.location.hash != '#') {
		showSection(document.location.hash);
	} else {
		if (document.getElementById('WelcomeBody')) {
			showSection('Welcome');
		} else {
			showSection('Introduction');
		}
	}
}

/**
Returns an object with properties:
	main: main section id
	sub: sub section id (if any)
*/
function getSectionParts(inAnchor) {
	
	var anchorPattern = new RegExp(/^#*(.*?)(\$(.*?))*$/);
    var matches = inAnchor.match(anchorPattern);

	var main = '';
    var sub = '';
    if (matches && matches[1]) {
        main = matches[1];
        if (matches[3]) {
        	main = matches[3];
        	sub = matches[1] + '$' + main;
        }
    }
    return {main:main, sub:sub};
}

function showSection(inAnchor) {

	var sectionParts = getSectionParts(inAnchor);
	var mainId = sectionParts.main;
	var subId = sectionParts.sub || getSub(mainId) || getDefaultSub(mainId);
	
	var oldMainId = getMain();
	
	if (oldMainId != mainId) {	
		/* hide current main section */
		var currentMainElement = document.getElementById(oldMainId + 'Body');
		foswiki.CSS.removeClass(currentMainElement, 'configureShowSection');
	
		/* show new main section */
		var newMainElement = document.getElementById(mainId + 'Body');	
		foswiki.CSS.addClass(newMainElement, 'configureShowSection');
		
		/* set main menu highlight */	
		if (tabLinks[oldMainId]) {
			foswiki.CSS.removeClass(tabLinks[oldMainId], 'configureMenuSelected');
		}
		if (tabLinks[mainId]) {
			foswiki.CSS.addClass(tabLinks[mainId], 'configureMenuSelected');
		}
	}
		
	/* hide current sub section */
	var oldSubId = getSub(oldMainId);
	var currentSubElement = document.getElementById(oldSubId + 'Body');
	foswiki.CSS.removeClass(currentSubElement, 'configureShowSection');

	/* show new sub section */
	var newSubElement = document.getElementById(subId + 'Body');	
	foswiki.CSS.addClass(newSubElement, 'configureShowSection');
	
	/* set sub menu highlight */
	if (tabLinks[oldSubId]) {
		foswiki.CSS.removeClass(tabLinks[oldSubId], 'configureMenuSelected');
	}
	if (tabLinks[subId]) {
		foswiki.CSS.addClass(tabLinks[subId], 'configureMenuSelected');
	}
    
	setMain(mainId);
	setSub(mainId, subId);

	if (menuState.allOpened == 1) {
		/* we want to use anchors to jump down */
		return true;
	} else {
		return false;
	}
}

/**
Support for the Expand/Close All button

This is the preferred way to toggle elements. Should be done for Expert settings and Info blocks as well.

*/
function toggleSections() {

    var body = document.getElementsByTagName('BODY')[0];
    if (menuState.allOpened == -1) {
    	/* open all sections */
		foswiki.CSS.removeClass(body, 'configureShowOneSection');
	} else {
		/* hide all sections */
		foswiki.CSS.addClass(body, 'configureShowOneSection');
		/* open current section */
		var newMain = menuState.main;
		menuState.main = '';
		showSection(newMain);
	}
	
	menuState.allOpened = -menuState.allOpened;
}

/* TOOLTIPS */

function getTip(idx) {
    var div = document.getElementById('tt' + idx);
    if (div)
        return div.innerHTML;
    else
        return "Reset to the default value, which is:<br />";
}

/* DEFAULT LINKS */

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

	/* set link label states */
	inLink.setDefaultLinkText = 'use default';
	inLink.undoDefaultLinkText = 'undo';
	
	/* set defaults */
	inLink.title = '';
	/*
	inLink.title = formatLinkValueInTitle(
        inLink.type, inLink.setDefaultTitle, inLink.defaultValue);
    */
    var label = getElementsByClassName(inLink, 'configureDefaultValueLinkLabel')[0];
    if (label) {
		label.innerHTML = inLink.setDefaultLinkText;
	}
}

function showDefaultLinkToolTip(inLink) {

	var template = document.getElementById('configureToolTipTemplate').innerHTML;
	
	template = template.replace(/VALUE/g, createHumanReadableValueString(inLink.type, inLink.defaultValue));
	template = template.replace(/TYPE/g, inLink.type);
	
	var contents = getElementsByClassName(inLink, 'configureDefaultValueLinkValue')[0];
	contents.innerHTML = template;
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
	
	var label = getElementsByClassName(inLink, 'configureDefaultValueLinkLabel')[0];
	if (inLink.oldValue == null) {
		/* we have just set the default value */
		/* prepare undo link */
		label.innerHTML = inLink.undoDefaultLinkText;
		inLink.oldValue = oldValue;
	} else {
		/* we have just set the old value */
		label.innerHTML = inLink.setDefaultLinkText;
		inLink.oldValue = null;
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
	var value = inValue;
	value = value.replace(/\\&quot;/g, '');
	return value;
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

/* INFO TEXTS */

var infoMode = '';

function toggleInfoMode() {
    var antimode = infoMode;
    infoMode = (antimode == 'none' ? '' : 'none');
    var els = getElementsByClassName(document, 'configureInfoText');
    for (var i = 0; i < els.length; i++) {
        /*els[i].style.display = infoMode;*/
        if (infoMode == 'none') {
        	foswiki.CSS.addClass(els[i], 'foswikiMakeHidden');
        } else {
        	foswiki.CSS.removeClass(els[i], 'foswikiMakeHidden');
        }
    }
    els = getElementsByClassName(document, 'configureNotInfoText');
    for (var i = 0; i < els.length; i++) {
        /*els[i].style.display = antimode;*/
        if (antimode == 'none') {
        	foswiki.CSS.addClass(els[i], 'foswikiMakeHidden');
        } else {
        	foswiki.CSS.removeClass(els[i], 'foswikiMakeHidden');
        }
    }
}


/**
Opens/closes all info blocks.
*/
function toggleInfo(inId) {
	var twistyElement = document.getElementById('info_' + inId);
	if (twistyElement) {
		if (foswiki.CSS.hasClass(twistyElement, 'foswikiMakeHidden')) {
			foswiki.CSS.removeClass(twistyElement, 'foswikiMakeHidden');
		} else {
			foswiki.CSS.addClass(twistyElement, 'foswikiMakeHidden');
		}
	}
	return false;
}

/* SELECTORS */

var rules = {
	'.tabli a' : function(el) {
		var sectionParts = getSectionParts(el.hash);
		var id = sectionParts.main;
		if (sectionParts.sub) {
			id = sectionParts.sub;
			setDefaultSub(sectionParts.main, sectionParts.sub);
		}
		tabLinks[id] = el.parentNode;
		el.onclick = function() {
			return showSection(id);
		}
	},
	'a.configureExpert' : function(el) {
		el.onclick = function() {
			toggleExpertsMode();
			return false;
		}
	},
	'a.configureNotExpert' : function(el) {
		el.onclick = function() {
			toggleExpertsMode();
			return false;
		}
	},
	'a.configureInfoText' : function(el) {
		el.onclick = function() {
			toggleInfoMode();
			return false;
		}
	},
	'a.configureNotInfoText' : function(el) {
		el.onclick = function() {
			toggleInfoMode();
			return false;
		}
	},
	'a.configureDefaultValueLink' : function(el) {
		initDefaultLink(el);
		el.onmouseover = function() {
			showDefaultLinkToolTip(el);
		}
	},
	'.configureEllipsis a' : function(el) {
		el.onclick = function() {
			var ellipsis = el.parentNode;
			foswiki.CSS.addClass(ellipsis, 'foswikiMakeHidden');
			var id = getSectionParts(el.hash).main;
			foswiki.CSS.removeClass(document.getElementById(id), 'foswikiMakeHidden');
			return false;
		}
	},
	'.configureToggleSections a' : function(el) {
		el.onclick = function() {
			toggleSections();
		}
	},
	/* open the 'Set password' section on the authorization screen */
	'#twisty_setPassword' : function(el) {
		el.onclick = function() {
			var re = new RegExp("^twisty\_(.*)$");
			var match = el.id.match(re)[1];
			var twistyElement = document.getElementById(match);
			if (twistyElement) {				
				if (foswiki.CSS.hasClass(twistyElement, 'foswikiHidden')) {
					foswiki.CSS.removeClass(twistyElement, 'foswikiHidden');
				} else {
					foswiki.CSS.addClass(twistyElement, 'foswikiHidden');
				}
				return false;
			}
			return true;
		}
	}
};
Behaviour.register(rules);

addLoadEvent(toggleExpertsMode);
addLoadEvent(toggleInfoMode);
addLoadEvent(initSection);
