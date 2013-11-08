/* Don't use // style comments, or you'll break the stupid minifier  */

/* EXPERT MODE */

var expertsMode = '';

function toggleExpertsMode( inMode ) {

	if (inMode != undefined) {
		/* convert value to a css value */
		expertsMode = (inMode == 1 ? '' : 'none');
	} else {
		/* toggle */
		expertsMode = (expertsMode == 'none' ? '' : 'none');
	}
	
    var antimode = (expertsMode == 'none' ? '' : 'none');
    

    /* toggle table rows */
    $('tr.configureExpert').each(function() {
    	$(this).css("display", expertsMode);
    });
    $('tr.configureNotExpert').each(function() {
    	$(this).css("display", antimode);
    });
    /* toggle links */
    $('a.configureExpert').each(function() {
    	$(this).css("display", expertsMode);
    });
    $('a.configureNotExpert').each(function() {
    	$(this).css("display", antimode);
    });
}

/* ----------------------------- MENU ----------------------------- */

var tabLinks = {};

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
		if ( $("#WelcomeBody").length ) {
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
var anchorPattern = new RegExp(/^#*(.*?)(\$(.*?))*$/);

function getSectionParts(inAnchor) {
	
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
		var currentMainElement = $("#" + oldMainId + "Body");
		currentMainElement.removeClass("configureShowSection");
	
		/* show new main section */
		var newMainElement = $("#" + mainId + "Body");	
		newMainElement.addClass("configureShowSection");
		
		/* set main menu highlight */	
		if (tabLinks[oldMainId]) {
			$(tabLinks[oldMainId]).removeClass("configureMenuSelected");
		}
		if (tabLinks[mainId]) {
			$(tabLinks[mainId]).addClass("configureMenuSelected");
		}
	}
		
	/* hide current sub section */
	var oldSubId = getSub(oldMainId);
	if (oldSubId) {
		var oldsub = oldSubId;
		oldsub = oldsub.replace(/\$/g, "\\$");
		oldsub = oldsub.replace(/#/g, "\\#");
		var currentSubElement = $("#" + oldsub + "Body");
		currentSubElement.removeClass('configureShowSection');
	}
	
	/* show new sub section */
	if (subId) {
		var sub = subId;
		sub = sub.replace(/\$/g, "\\$");
		sub = sub.replace(/#/g, "\\#");
		var newSubElement = $("#" + sub + "Body");	
		newSubElement.addClass('configureShowSection');
	}
	
	/* set sub menu highlight */
	if (tabLinks[oldSubId]) {
		$(tabLinks[oldSubId]).removeClass("configureMenuSelected");
	}
	if (subId && tabLinks[subId]) {
		$(tabLinks[subId]).addClass("configureMenuSelected");
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

    var body = $("body");
    if (menuState.allOpened == -1) {
    	/* open all sections */
		body.removeClass('configureShowOneSection');
	} else {
		/* hide all sections */
		body.addClass('configureShowOneSection');
		/* open current section */
		var newMain = menuState.main;
		menuState.main = '';
		showSection(newMain);
	}
	
	menuState.allOpened = -menuState.allOpened;
}

/* TOOLTIPS */

function getTip(idx) {
    var div = $("#tt" + idx);
    if (div.length)
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
	if (inLink.type == 'OCTAL') {
		inLink.defaultValue = 0+parseInt(unescape(inLink.title)).toString(8);
	} else {
		inLink.defaultValue = unescape(inLink.title);
	}

	/* set link label states */
	inLink.setDefaultLinkText = 'use default';
	inLink.undoDefaultLinkText = 'use stored value';
	
	/* set defaults */
	inLink.title = '';

    var label = $('.configureDefaultValueLinkLabel', inLink)[0];
    if (label) {
		label.innerHTML = inLink.setDefaultLinkText;
	}
}

function showDefaultLinkToolTip(inLink) {

	var template = $("#configureToolTipTemplate").html();
	template = template.replace(/VALUE/g, createHumanReadableValueString(inLink.type, inLink.defaultValue));
	template = template.replace(/TYPE/g, inLink.type);

	var contents = $('.configureDefaultValueLinkValue', inLink)[0];
	$(contents).html(template);
}

/**
Called from "reset to default" link.
Values are set in UIs/Value.pm
*/
function resetToDefaultValue (inLink, inFormType, inName, inValue) {

	var name = unescape(inName);
	var elem = document.forms.update[name];
	if (!elem) return;
	
	var value = unescape(inValue);
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
		if (inLink.type == 'OCTAL') {
			oldValue = 0+parseInt(elem.value).toString(8);
			elem.value = 0+parseInt(value).toString(8);
		} else {
			oldValue = elem.value;
			elem.value = value;
		}
	}
	
	var label = $('.configureDefaultValueLinkLabel', inLink)[0];
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

/* INFO TEXTS */

var infoMode = '';

function toggleInfoMode() {
    var antimode = infoMode;
    infoMode = (antimode == 'none' ? '' : 'none');
    $('.configureInfoText').each(function() {
    	if (infoMode == 'none') {
        	$(this).addClass('foswikiMakeHidden');
        } else {
        	$(this).removeClass('foswikiMakeHidden');
        }
    });
	$('.configureNotInfoText').each(function() {
        if (antimode == 'none') {
        	$(this).addClass('foswikiMakeHidden');
        } else {
        	$(this).removeClass('foswikiMakeHidden');
        }
    });
}


/**
Opens/closes all info blocks.
*/
function toggleInfo(inId) {
	var twistyElement = $("#info_" + inId);
	if (twistyElement) {
		if (twistyElement.hasClass("foswikiMakeHidden")) {
			twistyElement.removeClass("foswikiMakeHidden");
		} else {
			twistyElement.addClass("foswikiMakeHidden");
		}
	}
	return false;
}

/* SELECTORS */
var enableWhenSomethingChangedElements = new Array();
var showWhenNothingChangedElements = new Array();

/* Value changes. Event when a value is edited; enables the save changes
 * button */
function valueChanged(el) {

    $(el).addClass('foswikiValueChanged');

	$(showWhenNothingChangedElements).each(function() {
		$(this).addClass('foswikiHidden');
	});
	
	$(enableWhenSomethingChangedElements).each(function() {
		var controlTypes = [ 'Submit', 'Button', 'InputField' ];
		$(this).removeClass('foswikiHidden');
		for (var j in controlTypes) {
			var ct = 'foswiki' + controlTypes[j];
			if ($(this).hasClass(ct + 'Disabled')) {
				$(this).removeClass(ct + 'Disabled');
				$(this).addClass(ct);
			}
		}
		$(this).disabled = false;
	});
}

function newHideContent(elts, settings, callback) {
	elts.contentWrapper.hide();
	callback();
}

function loadImage(el) {
    if (!el.title || el.title == '')
        return;
    var url = el.title;
    el.title = 'Click to enlarge';
    
    var img = new Image();
    $(img).load(
        function () {
            var w = this.width;
            var h = this.height;
            /* set the image hidden by default */
            $(img).hide();
            /* Scale to max 64 height, max 150 width */
            var MAX_H = 64;
            var MAX_W = 150;
            if (w * MAX_H / MAX_W > h) {
                this.height = Math.round(h * MAX_W / w);
                this.width = MAX_W;
            } else {
                this.width = Math.round(w * MAX_H / h);
                this.height = MAX_H;
            }
            
            $(el).append(this);
            $(this).wrap("<a href='" + url + "' class='nyroModal'></a>");
			$('.nyroModal').nyroModal({hideContent:newHideContent});
            $(this).fadeIn();
        });
    $(img).attr('src', url);
}

var allImagesLoaded = false;

function imgOnDemand () {
    if (!allImagesLoaded) {
        var p = $(window).height() + $(window).scrollTop();
        $('.loadImage').each(
            function() {
                if ($(this).offset().top < p + 50) {
                    loadImage(this);
                    $(this).removeClass('loadImage');
                }
            });
        allImagesLoaded = (p >= $(document).height());
    }
}

/**
Javascript query string parsing.
Author: djohnson@ibsys.com {{djohnson}} - you may use this file as you wish but please keep this header with it thanks
@use 
Pass location.search to the constructor:
<code>var myPageQuery = new PageQuery(location.search)</code>
Retrieve values
<code>var myValue = myPageQuery.getValue("param1")</code>
*/
var PageQuery;
PageQuery = function (q) {
	if (q.length > 1) {
		this.q = q.substring(1, q.length);
	} else {
		this.q = null;
	}
	this.keyValuePairs = new Array();
	if (q) {
		for(var i=0; i < this.q.split(/[&;]/).length; i++) {
			this.keyValuePairs[i] = this.q.split(/[&;]/)[i];
		}
	}
}
PageQuery.prototype.getKeyValuePairs = function() {
	return this.keyValuePairs;
}
/**
@return The query string value; if not found returns -1.
*/
PageQuery.prototype.getValue = function (s) {
	for(var j=0; j < this.keyValuePairs.length; j++) {
		if(this.keyValuePairs[j].split(/=/)[0] == s)
			return this.keyValuePairs[j].split(/=/)[1];
	}
	return -1;
}
PageQuery.prototype.getParameters = function () {
	var a = new Array(this.getLength());
	for(var j=0; j < this.keyValuePairs.length; j++) {
		a[j] = this.keyValuePairs[j].split(/=/)[0];
	}
	return a;
}
PageQuery.prototype.getLength = function() {
	return this.keyValuePairs.length;
}

function getUrlParam(inName) {
	var myPageQuery = new PageQuery(location.search);
	var param = myPageQuery.getValue(inName);
	return (param == -1 ? undefined : param);
}

/**
 * jquery init 
 */
$(document).ready(function() {
	$(".enableWhenSomethingChanged").each(function() {
		enableWhenSomethingChangedElements.push(this);
		if (this.tagName.toLowerCase() == 'input') {
			/* disable the Save Changes button until a change has been made */
			/* we won't use this until an AJAX call has been implemented to make
			this fault proof
			$(this).attr('disabled', 'disabled');
			$(this).addClass('foswikiSubmitDisabled');
			$(this).removeClass('foswikiSubmit');
			*/
		} else {
			$(this).addClass('foswikiHidden');
		}
	});
	$(".showWhenNothingChanged").each(function() {
		showWhenNothingChangedElements.push(this);
	});
	$(".tabli a").each(function() {
    	var sectionParts = getSectionParts(this.hash);
		this.sectionId = sectionParts.main;
		if (sectionParts.sub) {
			this.sectionId = sectionParts.sub;
			setDefaultSub(sectionParts.main, sectionParts.sub);
		}
		tabLinks[this.sectionId] = $(this).parent().get(0);
  	});
  	$(".tabli a").click(function() {
		return showSection(this.sectionId);
	});
	$("a.configureExpert").click(function() {
		toggleExpertsMode();
		return false;
	});
	$("a.configureNotExpert").click(function() {
		toggleExpertsMode();
		return false;
	});
	$("a.configureInfoText").click(function() {
		toggleInfoMode();
		return false;
	});
	$("a.configureNotInfoText").click(function() {
		toggleInfoMode();
		return false;
	});
	$("a.configureDefaultValueLink").each(function() {
		initDefaultLink(this);
	});
	$("a.configureDefaultValueLink", $("div.configureRootSection")).mouseover(function() {
		showDefaultLinkToolTip(this);
	});
	$(".configureToggleSections a").click(function() {
		toggleSections();
	});
	$("input.foswikiFocus").each(function() {
		this.focus();
	});
	$(".configureRootSection table.configureSectionValues div.configureError").each(function() {
		var row = $(this).parent().parent().get(0);
		if (row) {
			$(row).removeClass('configureExpert');
		}
	});
	$(".configureRootSection table.configureSectionValues div.configureWarn").each(function() {
		var row = $(this).parent().parent().get(0);
		if (row) {
			$(row).removeClass('configureExpert');
		}
	});
	$("#closeMessages").click(function() {
		$("#messages").hide();
		return false;
	});

	toggleExpertsMode( getUrlParam('expert') );
	toggleInfoMode();
	initSection();
    $(window).scroll(function(){ imgOnDemand() });
    imgOnDemand();
});
