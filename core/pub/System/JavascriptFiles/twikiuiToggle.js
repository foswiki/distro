/**
Required javascript:
- behaviour.js
- twikiFunction.js

ui.Toggle element switches between 2 states: on and off. This might be useful to show 2 alternating buttons, for instance: "Show left bar" "Hide left bar".

ui.Toggle HTML will look like this;

<pre>
<div id="togglePrivate_on" class="toggleTrigger toggleMakeVisible">
  <a href="#">Show private members</a>
</div>
<script type="text/javascript">twiki.ui.Toggle.getInstance().init("togglePrivate_on");</script>
<div id="togglePrivate_off" class="toggleTrigger toggleMakeVisible">
  <a href="#">Hide private members</a>
</div>
<script type="text/javascript">twiki.ui.Toggle.getInstance().init("togglePrivate_off");</script>
</pre>

Line by line:

<pre><div id="togglePrivate_on"</pre><br />
The syntax is: toggle id + "on". The same toggle id is used for all toggled elements.

<pre>class="toggleTrigger toggleMakeVisible"</pre><br />
CSS class "toggleTrigger" is a behaviour class that will init the button at window onload. CSS class "toggleMakeVisible" makes the button invisible when the user does not have javascript enabled.

<pre><a href="#">Show private members</a></pre><br />
The link has an empty url. Rather the click event is caught using a behaviour (see below).

<pre><script type="text/javascript">twiki.ui.Toggle.getInstance().init("togglePrivate_on");</script></pre>
This line is optional, but makes sure the toggle element is initialized as soon as it is rendered on the page and not at onload (after the complete page has been rendered).

<pre><div id="togglePrivate_off"</pre>
The "off" button.

To call a function when the ui.Toggle is clicked, use a Behaviour:
<pre>
var ToggleUIbehaviour = {	
	'#togglePrivate_on' : function(e) {
		onclick = function (e) {
			// your function call
			return false;
		}
	},
	'#togglePrivate_off' : function(e) {
		onclick = function (e) {
			// your function call
			return false;
		}
	}
};
Behaviour.register(ToggleUIbehaviour);
</pre>

Other settings:
- toggleRememberSetting
- toggleForgetSetting
- toggleStartHide
- toggleStartShow
- toggleFirstStartShow
- toggleFirstStartHide

See TwistyPlugin for examples.



CSS classes

Include these styles:

.toggleHidden { display:none; }
.toggleMakeHidden {}
.toggleMakeVisible { display:none; }
.toggleRememberSetting {}
.toggleForgetSetting {}
.toggleStartHide {}
.toggleStartShow {}
.toggleFirstStartShow {}
.toggleFirstStartHide {}

*/

if (twiki == undefined) var twiki = {};
if (twiki.ui == undefined) twiki.ui = {};
twiki.ui.Toggle = function () {
						
	var self = this;
	
	/**
	Overridable properties.
	*/
	this.BUTTON_ON_NAME = "on";
	this.BUTTON_OFF_NAME = "off";
	this.BUTTON_NAME_OPTIONS = this.BUTTON_ON_NAME + "|"+ this.BUTTON_OFF_NAME;
	this.ELEMENT_OPTIONS = this.BUTTON_NAME_OPTIONS;
	this.DATA_CLASS = twiki.ui.ToggleData;
	this.CSS_CLASS_HIDDEN = 			"toggleHidden";
	this.CSS_CLASS_MAKEHIDDEN =			"toggleMakeHidden";
	this.CSS_CLASS_MAKEVISIBLE =		"toggleMakeVisible";
	this.CSS_CLASS_REMEMBERSETTING =	"toggleRememberSetting";
	this.CSS_CLASS_FORGETSETTING =		"toggleForgetSetting";
	this.CSS_CLASS_STARTHIDE =			"toggleStartHide";
	this.CSS_CLASS_STARTSHOW =			"toggleStartShow";
	this.CSS_CLASS_FIRSTSTARTSHOW =		"toggleFirstStartShow";
	this.CSS_CLASS_FIRSTSTARTHIDE =		"toggleFirstStartHide";

	/**
	Retrieves the name of the twisty from an HTML element id. For example 'demotoggle' will return 'demo'.
	@param inId : (String) HTML element id
	@return String
	@privileged
	*/
	this._getName = function (inId) {
		var re = new RegExp("(.*)(" + this.ELEMENT_OPTIONS + ")", "g");
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
		var re = new RegExp("(.*)(" + this.ELEMENT_OPTIONS + ")", "g");
		var m = re.exec(inId);
		var type = (m && m[2]) ? m[2] : "";
		return type;
	}
	
	/**
	Toggles the collapsed state. Calls _update().
	@param data
	@param inState : (Number) (optional) the state to toggle to: either twiki.ui.Toggle.STATE_ON or twiki.ui.Toggle.STATE_OFF
	@privileged
	*/
	this._toggle = function (data, inState) {
		if (!data) return;
		var state;
		if (inState != undefined) {
			state = inState;
		} else {
			state = (data.state == twiki.ui.Toggle.STATE_OFF) ? twiki.ui.Toggle.STATE_ON : twiki.ui.Toggle.STATE_OFF;
		}
		data.state = state;
		this._update(data, true);
	}
	
	/**
	Updates the states of UI trinity 'show', 'hide' and 'content'.
	Saves new state in a cookie if one of the elements has CSS class 'toggleRememberSetting'.
	@param data : (Object) twiki.ui.ToggleData object
	@privileged
	*/
	this._update = function (data, inMaySave) {
		if (data.state == twiki.ui.Toggle.STATE_ON) {
			this._updateOn(data);
		} else {
			this._updateOff(data);
		}
		if (inMaySave && data.saveSetting) {
			this._updateSave(data, inMaySave);
		}
		if (data.clearSetting) {
			this._updateClear(data);
		}
	}
	
	this._updateOff = function (data) {
		var showControl = data[this.BUTTON_ON_NAME];
		var hideControl = data[this.BUTTON_OFF_NAME];
		twiki.CSS.removeClass(showControl, this.CSS_CLASS_HIDDEN); // show 'show'	
		twiki.CSS.addClass(hideControl, this.CSS_CLASS_HIDDEN); // hide 'hide'
	}
	this._updateOn = function (data) {
		var showControl = data[this.BUTTON_ON_NAME];
		var hideControl = data[this.BUTTON_OFF_NAME];
		twiki.CSS.addClass(showControl, this.CSS_CLASS_HIDDEN);	// hide 'show'
		twiki.CSS.removeClass(hideControl, this.CSS_CLASS_HIDDEN); // show 'hide'
	}
	this._updateSave = function (data, inMaySave) {
		twiki.Pref.setPref(twiki.ui.Toggle.COOKIE_PREFIX + data.name, data.state);
	}
	this._updateClear = function (data) {
		twiki.Pref.setPref(twiki.ui.Toggle.COOKIE_PREFIX + data.name, "");
	}
	
	/**
	Stores a twisty HTML element (either show control, hide control or content 'toggle').
	@param e : (Object) HTMLElement
	@privileged
	*/
	this._register = function (inElement) {
		if (!inElement) return;
		var name = this._getName(inElement.id);
		var data = this._storage[name];
		if (!data) {
			data = new this.DATA_CLASS();
		}
		if (twiki.CSS.hasClass(inElement, this.CSS_CLASS_REMEMBERSETTING))	data.saveSetting = true;
		if (twiki.CSS.hasClass(inElement, this.CSS_CLASS_FORGETSETTING)) 		data.clearSetting = true;
		if (twiki.CSS.hasClass(inElement, this.CSS_CLASS_STARTSHOW)) 			data.startShown = true;
		if (twiki.CSS.hasClass(inElement, this.CSS_CLASS_STARTHIDE)) 			data.startHidden = true;
		if (twiki.CSS.hasClass(inElement, this.CSS_CLASS_FIRSTSTARTSHOW)) 	data.firstStartShown = true;
		if (twiki.CSS.hasClass(inElement, this.CSS_CLASS_FIRSTSTARTHIDE)) 	data.firstStartHidden = true;
		data.name = name;
		var type = this._getType(inElement.id);

		data[type] = inElement;
		this._storage[name] = data;
		
		var re = new RegExp("(" + this.BUTTON_NAME_OPTIONS + ")", "g");
		var m = re.exec(type);
		if (m) {
			inElement.onclick = function() {
				self._toggle(data);
				return false;
			}
		}
		return data;
	}
	
	/**
	Returns true if all toggle elements are stored.
	*/
	this._allElementsInited = function (inData) {
		if (inData && inData.on && inData.off) return inData;
	}
	
	/**
	Key-value set of twiki.ui.ToggleData objects. The value is accessed by twisty id identifier name.
	@example var data = this._storage["demo"];
	@privileged
	*/
	this._storage = {};

};
twiki.ui.Toggle.__instance__ = null; //define the static property
twiki.ui.Toggle.getInstance = function () {
	if (this.__instance__ == null) {
		this.__instance__ = new twiki.ui.Toggle();
	}
	return this.__instance__;
}
	
/**
Public constants.
*/
twiki.ui.Toggle.STATE_OFF = 0;
twiki.ui.Toggle.STATE_ON = 1;
twiki.ui.Toggle.COOKIE_PREFIX = "TWiki_HTML_ToggleButton_";

/**
The cached full twiki cookie string so the data has to be read only once during init.
*/
twiki.ui.Toggle.prefList;

/**
Initializes a twisty HTML element (either show control, hide control or content 'toggle') by registering and setting the visible state.
Calls _register() and _update().
@public
@param inId : (String) id of HTMLElement
@return The stored twiki.ui.ToggleData object.
*/
twiki.ui.Toggle.prototype.init = function(inId) {

	var e = document.getElementById(inId);
	if (!e) return;

	// check if already inited
	var name = this._getName(inId);
	var data = this._storage[name];

	if (this._allElementsInited(data)) return data;

	// else register
	data = this._register(e);

	if (twiki.CSS.hasClass(e, this.CSS_CLASS_MAKEHIDDEN)) twiki.CSS.replaceClass(e, this.CSS_CLASS_MAKEHIDDEN, this.CSS_CLASS_HIDDEN);
	if (twiki.CSS.hasClass(e, this.CSS_CLASS_MAKEVISIBLE)) twiki.CSS.removeClass(e, this.CSS_CLASS_MAKEVISIBLE);
	
	if (this._allElementsInited(data)) {
		// all ui.Toggle elements present
		if (twiki.ui.Toggle.prefList == null) {
			// cache complete cookie string
			twiki.ui.Toggle.prefList = twiki.Pref.getPrefList();
		}
		var cookie = twiki.Pref.getPrefValueFromPrefList(twiki.ui.Toggle.COOKIE_PREFIX + data.name, twiki.ui.Toggle.prefList);
		if (data.firstStartHidden) data.state = twiki.ui.Toggle.STATE_OFF;
		if (data.firstStartShown) data.state = twiki.ui.Toggle.STATE_ON;
		// cookie setting may override  firstStartHidden and firstStartShown
		if (cookie && cookie == "0") data.state = twiki.ui.Toggle.STATE_OFF;
		if (cookie && cookie == "1") data.state = twiki.ui.Toggle.STATE_ON;
		// startHidden and startShown may override cookie
		if (data.startHidden) data.state = twiki.ui.Toggle.STATE_OFF;
		if (data.startShown) data.state = twiki.ui.Toggle.STATE_ON;
		this._update(data, false);
	}
	return data;	
}

/**
Sets the toggle to inState. If no state is passed, the toggle is set from its current state.
@param inId : (String) (required) id of on of the ui.Toggle elements
@param inState : (Number) (optional) the state to toggle to: either twiki.ui.Toggle.STATE_ON or twiki.ui.Toggle.STATE_OFF
*/
twiki.ui.Toggle.prototype.toggle = function(inId, inState) {
	var name = this._getName(inId);
	var data = this._storage[name];
	this._toggle(data, inState);
}

/**
Returns the ui.Toggle state.
@param inId : (String) (required) id of one of the Toggled elements
*/
twiki.ui.Toggle.prototype.getState = function(inId) {
	var name = this._getName(inId);
	var data = this._storage[name];
	return data.state;
}

/**
Toggles all elements on the page to inState.
@param inState : (Number) (required) the state to toggle to: either twiki.ui.Toggle.STATE_ON or twiki.ui.Toggle.STATE_OFF
*/
twiki.ui.Toggle.prototype.toggleAll = function(inState) {
	for (var name in this._storage) {
		var e = this._storage[name];
		e.state = inState;
		this._update(e, true);
	}
}

/**
Data container for properties of a ui.Toggle element.
*/
twiki.ui.ToggleData = function () {
	this.name;									// String
	this.state = twiki.ui.Toggle.STATE_OFF;		// Number
	this.off;									// HTMLElement
	this.on;									// HTMLElement
	this.saveSetting = false;					// Boolean; default not saved
	this.clearSetting = false;					// Boolean; default not cleared
	this.startShown;							// Boolean
	this.startHidden;							// Boolean
	this.firstStartShown;						// Boolean
	this.firstStartHidden;						// Boolean
}

/**
UI element behaviour; inits HTML element if no javascript 'trigger' tags has been inserted right after in the HTML
*/
var UIbehaviour = {	
	/**
	Show control, hide control
	*/
	'.toggleTrigger' : function(e) {
		twiki.ui.Toggle.getInstance().init(e.id);
	}
};
Behaviour.register(UIbehaviour);
