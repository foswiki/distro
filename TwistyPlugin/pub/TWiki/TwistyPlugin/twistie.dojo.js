/*
To compress this file you can use Dojo ShrinkSafe compressor at
http://alex.dojotoolkit.org/shrinksafe/
*/

/**
Singleton class.
*/
var twiki;
if (!twiki) twiki = {};
twiki.TwistyPlugin = new function () {

	var self = this;

	/**
	Retrieves the name of the twisty from an HTML element id. For example 'demotoggle' will return 'demo'.
	@param inId : (String) HTML element id
	@return String
	@privileged
	*/
	this._getName = function (e) {
		var re = new RegExp("(.*)(hide|show|toggle)", "g");
        var inId = dojo.attr(e, 'id');
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
		ref.state = (ref.state == twiki.TwistyPlugin.CONTENT_HIDDEN) ? twiki.TwistyPlugin.CONTENT_SHOWN : twiki.TwistyPlugin.CONTENT_HIDDEN;
		self._update(ref, true);
	}
	
	/**
	Updates the states of UI trinity 'show', 'hide' and 'content'.
	Saves new state in a cookie if one of the elements has CSS class 'twistyRememberSetting'.
	@param ref : (Object) twiki.TwistyPlugin.Storage object
	@privileged
	*/
	this._update = function (ref, inMaySave) {
		var showControl = ref.show;
		var hideControl = ref.hide;
		var contentElem = ref.toggle;
		
		//can implement Micha's animation using
		//dojo.anim("thinger", { width: 500, height: 500 }, 500);
		
		if (ref.state == twiki.TwistyPlugin.CONTENT_SHOWN) {
			// show content
			dojo.addClass(showControl, 'twistyHidden');	// hide 'show'
			dojo.removeClass(hideControl, 'twistyHidden'); // show 'hide'
			dojo.removeClass(contentElem, 'twistyHidden'); // show content
		} else {
			// hide content
			dojo.removeClass(showControl, 'twistyHidden'); // show 'show'	
			dojo.addClass(hideControl, 'twistyHidden'); // hide 'hide'
			dojo.addClass(contentElem, 'twistyHidden'); // hide content
		}
		if (inMaySave && ref.saveSetting) {
	        twiki.Pref.setPref(twiki.TwistyPlugin.COOKIE_PREFIX + ref.name, ref.state);
		}
		if (ref.clearSetting) {
	        twiki.Pref.setPref(twiki.TwistyPlugin.COOKIE_PREFIX + ref.name, "");
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
			ref = new twiki.TwistyPlugin.Storage();
		}
        var classValue = dojo.attr(e, 'class');             //TODO: replace with dojo.hasClass
        ref.saveSetting = dojo.hasClass(e, 'twistyRememberSetting');
        ref.clearSetting = dojo.hasClass(e, 'twistyForgetSetting');
        ref.startShown = dojo.hasClass(e, 'twistyStartShow');
        ref.startHidden = dojo.hasClass(e, 'twistyStartHide');
        ref.firstStartShown = dojo.hasClass(e, 'twistyFirstStartShow');
        ref.firstStartHidden = dojo.hasClass(e, 'twistyFirstStartHide');

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
	Key-value set of twiki.TwistyPlugin.Storage objects. The value is accessed by twisty id identifier name.
	@example var ref = self._storage["demo"];
	@privileged
	*/
	this._storage = {};
};

/**
Public constants.
*/
twiki.TwistyPlugin.CONTENT_HIDDEN = 0;
twiki.TwistyPlugin.CONTENT_SHOWN = 1;
twiki.TwistyPlugin.COOKIE_PREFIX = "TwistyPlugin_";

/**
The cached full TWiki cookie string so the data has to be read only once during init.
*/
twiki.TwistyPlugin.prefList;

/**
Initializes a twisty HTML element (either show control, hide control or content 'toggle') by registering and setting the visible state.
Calls _register() and _update().
@public
@param inId : (String) id of HTMLElement
@return The stored twiki.TwistyPlugin.Storage object.
*/
twiki.TwistyPlugin.init = function(e) {
	if (!e) return;

	// check if already inited
        var name = this._getName(e);
	var ref = this._storage[name];
	if (ref && ref.show && ref.hide && ref.toggle) return ref;

	// else register
	ref = this._register(e);
	
	//twiki.CSS.replaceClass(e, "twistyMakeHidden", "twistyHidden");
	dojo.removeClass(e, "twikiMakeVisible");
	dojo.removeClass(e, "twikiMakeVisibleBlock");
	dojo.removeClass(e, "twikiMakeVisibleInline");
	dojo.removeClass(e, "twikiMakeHidden");

	
	if (ref.show && ref.hide && ref.toggle) {
		// all Twisty elements present

		if (dojo.hasClass(e, 'twistyInited1')) {
			ref.state = twiki.TwistyPlugin.CONTENT_SHOWN
			this._update(ref, false);
			return ref;
		}
		if (dojo.hasClass(e, 'twistyInited0')) {
			ref.state = twiki.TwistyPlugin.CONTENT_HIDDEN
			this._update(ref, false);
			return ref;
		}

		if (twiki.TwistyPlugin.prefList == null) {
			// cache complete cookie string
			twiki.TwistyPlugin.prefList = twiki.Pref.getPrefList();
		}
		var cookie = twiki.Pref.getPrefValueFromPrefList(twiki.TwistyPlugin.COOKIE_PREFIX + ref.name, twiki.TwistyPlugin.prefList);
		if (ref.firstStartHidden) ref.state = twiki.TwistyPlugin.CONTENT_HIDDEN;
		if (ref.firstStartShown) ref.state = twiki.TwistyPlugin.CONTENT_SHOWN;
		// cookie setting may override  firstStartHidden and firstStartShown
		if (cookie && cookie == "0") ref.state = twiki.TwistyPlugin.CONTENT_HIDDEN;
		if (cookie && cookie == "1") ref.state = twiki.TwistyPlugin.CONTENT_SHOWN;
		// startHidden and startShown may override cookie
		if (ref.startHidden) ref.state = twiki.TwistyPlugin.CONTENT_HIDDEN;
		if (ref.startShown) ref.state = twiki.TwistyPlugin.CONTENT_SHOWN;

		this._update(ref, false);
	}
	return ref;	
}

twiki.TwistyPlugin.toggleAll = function(inState) {
	var i;
	for (var i in this._storage) {
		var e = this._storage[i];
		e.state = inState;
		this._update(e, true);
	}
}
twiki.TwistyPlugin.toggleAll_Show = function() {
    twiki.TwistyPlugin.toggleAll(twiki.TwistyPlugin.CONTENT_SHOWN);
}
twiki.TwistyPlugin.toggleAll_Hide = function() {
    twiki.TwistyPlugin.toggleAll(twiki.TwistyPlugin.CONTENT_HIDDEN);
}

/**
Storage container for properties of a twisty HTML element: show control, hide control or toggle content.
*/
twiki.TwistyPlugin.Storage = function () {
	this.name;										// String
	this.state = twiki.TwistyPlugin.CONTENT_HIDDEN;	// Number
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
 * dojo init 
 */
twiki.TwistyPlugin.onLoad = function() {
  dojo.query(".twistyTrigger").forEach("twiki.TwistyPlugin.init(item);");
  dojo.query(".twistyContent").forEach("twiki.TwistyPlugin.init(item);");
  
  dojo.query(".twistyExpandAll").onclick(twiki.TwistyPlugin.toggleAll_Show);
  dojo.query(".twistyCollapseAll").onclick(twiki.TwistyPlugin.toggleAll_Hide);
}

dojo.addOnLoad(twiki.TwistyPlugin.onLoad);

