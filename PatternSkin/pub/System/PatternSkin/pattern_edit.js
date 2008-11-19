
var Pattern;
if (!Pattern) Pattern = {};

Pattern.Edit = {

	EDIT_PREF_NAME:"Edit",
	EDITBOX_PREF_FONTSTYLE_ID:"TextareaFontStyle",
	EDITBOX_FONTSTYLE_MONO:"mono",
	EDITBOX_FONTSTYLE_PROPORTIONAL:"proportional",
	EDITBOX_FONTSTYLE_MONO_CLASSNAME:"patternButtonFontSelectorMonospace",
	EDITBOX_FONTSTYLE_PROPORTIONAL_CLASSNAME:"patternButtonFontSelectorProportional",
	
	buttons:{"font":null,"enlarge":null, "shrink":null},
	
	setFontStyleState:function(el, inShouldUpdateEditBox, inButtonState) {			
		var pref  = twiki.Pref.getPref(Pattern.Edit.EDIT_PREF_NAME + Pattern.Edit.EDITBOX_PREF_FONTSTYLE_ID);

		if (!pref || (pref != Pattern.Edit.EDITBOX_FONTSTYLE_PROPORTIONAL && pref != Pattern.Edit.EDITBOX_FONTSTYLE_MONO)) pref = Pattern.Edit.EDITBOX_FONTSTYLE_PROPORTIONAL;
	
		// toggle
		var newPref = (pref == Pattern.Edit.EDITBOX_FONTSTYLE_PROPORTIONAL) ? Pattern.Edit.EDITBOX_FONTSTYLE_MONO : Pattern.Edit.EDITBOX_FONTSTYLE_PROPORTIONAL;
		

		
		var prefCssClassName = (pref == Pattern.Edit.EDITBOX_FONTSTYLE_MONO) ? Pattern.Edit.EDITBOX_FONTSTYLE_MONO_CLASSNAME : Pattern.Edit.EDITBOX_FONTSTYLE_PROPORTIONAL_CLASSNAME;
		
		var toggleCssClassName = (newPref == Pattern.Edit.EDITBOX_FONTSTYLE_MONO) ? Pattern.Edit.EDITBOX_FONTSTYLE_MONO_CLASSNAME : Pattern.Edit.EDITBOX_FONTSTYLE_PROPORTIONAL_CLASSNAME;		
			
		if (inButtonState && inButtonState == 'over') {
			if (twiki.CSS.hasClass(el, prefCssClassName)) twiki.CSS.removeClass(el, prefCssClassName);
			if (!twiki.CSS.hasClass(el, toggleCssClassName)) twiki.CSS.addClass(el, toggleCssClassName);
		} else if (inButtonState && inButtonState == 'out') {
			if (twiki.CSS.hasClass(el, toggleCssClassName)) twiki.CSS.removeClass(el, toggleCssClassName);
			if (!twiki.CSS.hasClass(el, prefCssClassName)) twiki.CSS.addClass(el, prefCssClassName);
		}
		
		if (inShouldUpdateEditBox) {
			Pattern.Edit.setEditBoxFontStyle(newPref);
		}
		
		return false;
	},
	
	setEditBoxFontStyle:function(inFontStyle) {
		if (inFontStyle == Pattern.Edit.EDITBOX_FONTSTYLE_MONO) {
			twiki.CSS.replaceClass(document.getElementById(EDITBOX_ID), EDITBOX_FONTSTYLE_PROPORTIONAL_STYLE, EDITBOX_FONTSTYLE_MONO_STYLE);
			twiki.Pref.setPref(PREF_NAME + Pattern.Edit.EDITBOX_PREF_FONTSTYLE_ID, inFontStyle);
			return;
		}
		if (inFontStyle == Pattern.Edit.EDITBOX_FONTSTYLE_PROPORTIONAL) {
			twiki.CSS.replaceClass(document.getElementById(EDITBOX_ID), EDITBOX_FONTSTYLE_MONO_STYLE, EDITBOX_FONTSTYLE_PROPORTIONAL_STYLE);
			twiki.Pref.setPref(PREF_NAME + Pattern.Edit.EDITBOX_PREF_FONTSTYLE_ID, inFontStyle);
			return;
		}
	},
	
	initTextAreaStyles:function (inNames) {
		var i, ilen=inNames.length;
		for (i=0; i<ilen; ++i) {
			var button = Pattern.Edit.buttons[inNames[i]];
			if (button != null) {
				Pattern.Edit.buttons[inNames[i]].style.display = 'inline';
			}
		}
	}

}

var patternEditPageRules = {
	'.patternButtonFontSelector' : function(el) {
		el.style.display = 'none';
		Pattern.Edit.buttons["font"] = el;
		Pattern.Edit.setFontStyleState(el, false, 'out');
		el.onclick = function(){
			return Pattern.Edit.setFontStyleState(el, true);
		}
		el.onmouseover = function() {
			return Pattern.Edit.setFontStyleState(el, false, 'over');
		}
		el.onmouseout = function() {
			return Pattern.Edit.setFontStyleState(el, false, 'out');
		}
	},
	'.patternButtonEnlarge' : function(el) {
		el.style.display = 'none';
		Pattern.Edit.buttons["enlarge"] = el;
		el.onclick = function(){
			return changeEditBox(1);
		}
	},
	'.patternButtonShrink' : function(el) {
		el.style.display = 'none';
		Pattern.Edit.buttons["shrink"] = el;
		el.onclick = function(){
			return changeEditBox(-1);
		}
	}
};
Behaviour.register(patternEditPageRules);

function patternInitTextArea() {
	initTextArea();
	Pattern.Edit.initTextAreaStyles(["font", "enlarge", "shrink"]);
}

twiki.Event.addLoadEvent(patternInitTextArea, false);
