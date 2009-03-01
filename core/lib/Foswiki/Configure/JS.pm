package Foswiki::Configure::JS;

use strict;

use vars qw( $js1 $js2 );

sub js1 {
    local $/ = undef;
    return <DATA>;
}

sub js2 {
    return <<'HERE';
//<!--
document.write("<style type='text/css'>");
document.write(".foldableBlockClosed {display:none;}");
document.write("<\/style>");
//-->
HERE
}

1;
__DATA__
//<!--

var lastOpenBlock = null;
var lastOpenBlockLink = null;
var allBlocks = null; // array of all foldable blocks
var allBlockLinks = null; // array of all foldable block links (headers)

function foldBlock(id) {
    var shouldClose = false;
    var block = null;
    if (lastOpenBlock == null) {
        block = document.getElementById(id);
        if (block.open) {
            shouldClose = true;
        }
    }
    if (shouldClose) {
        closeBlock(id);
    } else {
        var o = openBlock(id);
        if (lastOpenBlock != null) {
            closeBlockElement(lastOpenBlock, lastOpenBlockLink);
        }
    }
    window.location.hash = id + "link";
    
    if (o && o.block) {
        lastOpenBlock = (lastOpenBlock == o.block) ? null : o.block;
    }
    if (o && o.blockLink) {
        lastOpenBlockLink = (lastOpenBlockLink == o.blockLink) ? null : o.blockLink;
    }
}

function openBlock(id) {
    var block = document.getElementById(id);
    var blockLink = document.getElementById('blockLink' + id);
    openBlockElement(block, blockLink);
    return {block:block, blockLink:blockLink};
}

function openBlockElement(block, blockLink) {
	var indicator = getElementsByClassName(blockLink, 'blockLinkIndicator')[0];
	indicator.innerHTML = '&#9660;';
    block.className = 'foldableBlock foldableBlockOpen';
    block.open = true;
    blockLink.className = 'blockLink blockLinkOn';
}

function closeBlock(id) {
    var block = document.getElementById(id);
    var blockLink = document.getElementById('blockLink' + id);
    closeBlockElement(block, blockLink);
    return {block:block, blockLink:blockLink};
}

function closeBlockElement(block, blockLink) {
	var indicator = getElementsByClassName(blockLink, 'blockLinkIndicator')[0];
	indicator.innerHTML = '&#9658;';
    block.className = 'foldableBlock foldableBlockClosed';
    block.open = false;
    blockLink.className = 'blockLink blockLinkOff';
}

function toggleAllOptions(open) {
    if (allBlocks == null) {
        allBlocks = getElementsByClassName(document, 'foldableBlock');
    }
    if (allBlockLinks == null) {
        allBlockLinks = getElementsByClassName(document, 'blockLink');
    }
    var i, ilen=allBlocks.length;
    if (open) {
        for (i=0; i<ilen; ++i) {
            openBlockElement(allBlocks[i], allBlockLinks[i]);
        }
    } else {
        for (i=0; i<ilen; ++i) {
            closeBlockElement(allBlocks[i], allBlockLinks[i]);
        }
    }
    lastOpenBlock = null;
    lastOpenBlockLink = null;
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

function addLoadEvent (inFunction, inDoPrepend) {
	if (typeof(inFunction) != "function") {
		return;
	}
	var oldonload = window.onload;
	if (typeof window.onload != 'function') {
		window.onload = function() {
			inFunction();
		};
	} else {
		var prependFunc = function() {
			inFunction(); oldonload();
		};
		var appendFunc = function() {
			oldonload(); inFunction();
		};
		window.onload = inDoPrepend ? prependFunc : appendFunc;
	}
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

	// extract type
	var type = inLink.className.split(" ")[0];
	inLink.type = type;
	
	// retrieve value from title tag
	inLink.defaultValue = replaceStubChars(inLink.title);
	// set title states
	inLink.setDefaultTitle = 'Set to default value:';
	inLink.undoDefaultTitle = 'Undo default and use previous value:';
	// set link label states
	inLink.setDefaultLinkText = 'use&nbsp;default';
	inLink.undoDefaultLinkText = 'undo';
	
	// set defaults
	inLink.title = formatLinkValueInTitle(inLink.type, inLink.setDefaultTitle, inLink.defaultValue);
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
Values are set in Value.pm
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
		// find selected element
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
		// including type='text' 
		oldValue = elem.value;
		elem.value = value;
	}
	
	if (inLink.oldValue == null) {
		// we have just set the default value
		// prepare undo link
		inLink.innerHTML = inLink.undoDefaultLinkText;
		inLink.oldValue = oldValue;
		inLink.title = formatLinkValueInTitle(inLink.type, inLink.undoDefaultTitle, oldValue);
	} else {
		// we have just set the old value
		inLink.innerHTML = inLink.setDefaultLinkText;
		inLink.oldValue = null;
		inLink.title = formatLinkValueInTitle(inLink.type, inLink.setDefaultTitle, value);
	}
	
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
		// do not convert numbers
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
	// all other cases
	return inValue;
}

/**
Checks if a value can be considered true.
*/
function isTrue (v) {
	if (v == 1 || v == '1' || v == 'on' || v == 'true') return 1;
	return 0;
}

/**
Replaces stubs for single and double quotes and newlines with the real characters.
*/
function replaceStubChars(v) {
	// replace &#26;
	var re
	re = new RegExp(/#26;/g);
	v = v.replace(re, "'");
	// replace &#22;
	re = new RegExp(/#22;/g);
	v = v.replace(re, '"');
	re = new RegExp(/#13;/g);
	v = v.replace(re, "\r");
	return v;
}

addLoadEvent(toggleAllOptions, 0);
addLoadEvent(initDeltaIndicators);
addLoadEvent(initDefaultLinks);

//-->

