/*
To compress this file you can use Dojo ShrinkSafe compressor at
http://alex.dojotoolkit.org/shrinksafe/
*/

/**
Singleton class.
*/
var foswiki; if (!foswiki) foswiki = {};
foswiki.JQueryTwistyPlugin = new function () {

	var self = this;

	/**
	Retrieves the name of the twisty from an HTML element id. For example 'demotoggle' will return 'demo'.
	@param inId : (String) HTML element id
	@return String
	@privileged
	*/
	this._getName = function (e) {
		var re = new RegExp("(.*)(hide|show|toggle)", "g");
                var inId = $(e).attr('id');
		var m = re.exec(inId);
		var name = (m && m[1]) ? m[1] : "";
    	return name;
	}
	
	/**
	Retrieves the type of the twisty from an HTML element id. For example 'demotoggle' will return 'toggle'.
	@param inId : (String) HTML element id
	@return String
	@privileged
	*/
	this._getType = function (inId) {
		var re = new RegExp("(.*)(hide|show|toggle)", "g");
		var m = re.exec(inId);
    	var type = (m && m[2]) ? m[2] : "";
    	return type;
	}
	
	/**
	Toggles the collapsed state. Calls _update().
	@privileged
	*/
	this._toggleTwisty = function (ref) {
		if (!ref) return;
		ref.state = (ref.state == foswiki.JQueryTwistyPlugin.CONTENT_HIDDEN) ? foswiki.JQueryTwistyPlugin.CONTENT_SHOWN : foswiki.JQueryTwistyPlugin.CONTENT_HIDDEN;
		self._update(ref, true);
	}
	
	/**
	Updates the states of UI trinity 'show', 'hide' and 'content'.
	Saves new state in a cookie if one of the elements has CSS class 'twistyRememberSetting'.
	@param ref : (Object) foswiki.JQueryTwistyPlugin.Storage object
	@privileged
	*/
	this._update = function (ref, inMaySave) {
		var showControl = ref.show;
		var hideControl = ref.hide;
		var contentElem = ref.toggle;
		if (ref.state == foswiki.JQueryTwistyPlugin.CONTENT_SHOWN) {
			// show content
                        if (inMaySave) {
                          $(contentElem).slideDown({easing:'easeInOutQuad', duration:300});
                        } else {
                          $(contentElem).show();

                        }
                        $(showControl).addClass("twistyHidden");
                        $(hideControl).removeClass("twistyHidden");
                        $(contentElem).removeClass("twistyHidden");
		} else {
			// hide content
                        if (inMaySave) {
                          $(contentElem).slideUp({easing:'easeInOutQuad', duration:300});
                        } else {
                          $(contentElem).hide();
                        }
                        $(showControl).removeClass("twistyHidden");
                        $(hideControl).addClass("twistyHidden");
                        $(contentElem).addClass("twistyHidden");
		}
		if (inMaySave && ref.saveSetting) {
	        foswiki.Pref.setPref(foswiki.JQueryTwistyPlugin.COOKIE_PREFIX + ref.name, ref.state);
		}
		if (ref.clearSetting) {
	        foswiki.Pref.setPref(foswiki.JQueryTwistyPlugin.COOKIE_PREFIX + ref.name, "");
		}
	}
	
	/**
	Stores a twisty HTML element (either show control, hide control or content 'toggle').
	@param e : (Object) HTMLElement
	@privileged
	*/
	this._register = function (e) {
		if (!e) return;
		var name = self._getName(e);
		var ref = self._storage[name];
		if (!ref) {
			ref = new foswiki.JQueryTwistyPlugin.Storage();
		}
                var classValue = $(e).attr('class');
		if (classValue.match(/\btwistyRememberSetting\b/)) 
                  ref.saveSetting = true;
		if (classValue.match(/\btwistyForgetSetting\b/)) 
                  ref.clearSetting = true;
		if (classValue.match(/\btwistyStartShow\b/)) 
                  ref.startShown = true;
		if (classValue.match(/\btwistyStartHide\b/)) 
                  ref.startHidden = true;
		if (classValue.match(/\btwistyFirstStartShow\b/)) 
                  ref.firstStartShown = true;
		if (classValue.match(/\btwistyFirstStartHide\b/)) 
                  ref.firstStartHidden = true;

		ref.name = name;
		var type = self._getType(e.id);
		ref[type] = e;
		self._storage[name] = ref;
		switch (type) {
			case 'show': // fall through
			case 'hide':
				e.onclick = function() {
					self._toggleTwisty(ref);
					return false;
				}
				break;
		}
		return ref;
	}
	
	/**
	Key-value set of foswiki.JQueryTwistyPlugin.Storage objects. The value is accessed by twisty id identifier name.
	@example var ref = self._storage["demo"];
	@privileged
	*/
	this._storage = {};
};

/**
Public constants.
*/
foswiki.JQueryTwistyPlugin.CONTENT_HIDDEN = 0;
foswiki.JQueryTwistyPlugin.CONTENT_SHOWN = 1;
foswiki.JQueryTwistyPlugin.COOKIE_PREFIX = "JQueryTwistyPlugin_";

/**
The cached full preference cookie string so the data has to be read only once during init.
*/
foswiki.JQueryTwistyPlugin.prefList;

/**
Initializes a twisty HTML element (either show control, hide control or content 'toggle') by registering and setting the visible state.
Calls _register() and _update().
@public
@param inId : (String) id of HTMLElement
@return The stored foswiki.JQueryTwistyPlugin.Storage object.
*/
foswiki.JQueryTwistyPlugin.init = function(e) {
	if (!e) return;

	// check if already inited
        var name = this._getName(e);
	var ref = this._storage[name];
	if (ref && ref.show && ref.hide && ref.toggle) return ref;

	// else register
	ref = this._register(e);
	
	if (ref.show && ref.hide && ref.toggle) {
		// all Twisty elements present

                var classValue = $(e).attr('class');
		if (classValue.match(/\btwistyInited1\b/)) {
			ref.state = foswiki.JQueryTwistyPlugin.CONTENT_SHOWN
			this._update(ref, false);
			return ref;
		}
		if (classValue.match(/\btwistyInited0\b/)) {
			ref.state = foswiki.JQueryTwistyPlugin.CONTENT_HIDDEN
			this._update(ref, false);
			return ref;
		}

		if (foswiki.JQueryTwistyPlugin.prefList == null) {
			// cache complete cookie string
			foswiki.JQueryTwistyPlugin.prefList = foswiki.Pref.getPrefList();
		}
		var cookie = foswiki.Pref.getPrefValueFromPrefList(foswiki.JQueryTwistyPlugin.COOKIE_PREFIX + ref.name, foswiki.JQueryTwistyPlugin.prefList);
		if (ref.firstStartHidden) ref.state = foswiki.JQueryTwistyPlugin.CONTENT_HIDDEN;
		if (ref.firstStartShown) ref.state = foswiki.JQueryTwistyPlugin.CONTENT_SHOWN;
		// cookie setting may override  firstStartHidden and firstStartShown
		if (cookie && cookie == "0") ref.state = foswiki.JQueryTwistyPlugin.CONTENT_HIDDEN;
		if (cookie && cookie == "1") ref.state = foswiki.JQueryTwistyPlugin.CONTENT_SHOWN;
		// startHidden and startShown may override cookie
		if (ref.startHidden) ref.state = foswiki.JQueryTwistyPlugin.CONTENT_HIDDEN;
		if (ref.startShown) ref.state = foswiki.JQueryTwistyPlugin.CONTENT_SHOWN;

		this._update(ref, false);
	}
	return ref;	
}

foswiki.JQueryTwistyPlugin.toggleAll = function(inState) {
	var i;
	for (var i in this._storage) {
		var e = this._storage[i];
		e.state = inState;
		this._update(e, true);
	}
}

/**
Storage container for properties of a twisty HTML element: show control, hide control or toggle content.
*/
foswiki.JQueryTwistyPlugin.Storage = function () {
	this.name;										// String
	this.state = foswiki.JQueryTwistyPlugin.CONTENT_HIDDEN;	// Number
	this.hide;										// HTMLElement
	this.show;										// HTMLElement
	this.toggle;									// HTMLElement (content element)
	this.saveSetting = false;						// Boolean; default not saved
	this.clearSetting = false;						// Boolean; default not cleared
	this.startShown;								// Boolean
	this.startHidden;								// Boolean
	this.firstStartShown;							// Boolean
	this.firstStartHidden;							// Boolean
}

/**
 * jquery init 
 */
$(function() {
  $(".twistyTrigger, .twistyContent").
    removeClass("twistyMakeHidden foswikiMakeHidden foswikiMakeVisible foswikiMakeVisibleBlock foswikiMakeVisibleInline").
    addClass("twistyHidden").
    each(function() {
      foswiki.JQueryTwistyPlugin.init(this);
    });
  $(".twistyExpandAll").click(function() {
    foswiki.JQueryTwistyPlugin.toggleAll(foswiki.JQueryTwistyPlugin.CONTENT_SHOWN);
  });
  $(".twistyCollapseAll").click(function() {
    foswiki.JQueryTwistyPlugin.toggleAll(foswiki.JQueryTwistyPlugin.CONTENT_HIDDEN);
  });
});
