/*

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

*/

// Requires JavascriptFiles/foswiki_edit

var EDITBOX_FONTSTYLE_MONO_CLASSNAME =
    "patternButtonFontSelectorMonospace";
var EDITBOX_FONTSTYLE_PROPORTIONAL_CLASSNAME =
    "patternButtonFontSelectorProportional";

// Controls the state of the font change button
(function($) {
    foswiki.Edit.toggleFontStateControl = function(jel, buttonState) {

        var pref = foswiki.Edit.getFontStyle();
        
        var newPref;
        var prefCssClassName;
        var toggleCssClassName;

        if (pref == EDITBOX_FONTSTYLE_PROPORTIONAL) {
            newPref = EDITBOX_FONTSTYLE_MONO;
            prefCssClassName = EDITBOX_FONTSTYLE_PROPORTIONAL_CLASSNAME;
            toggleCssClassName = EDITBOX_FONTSTYLE_MONO_CLASSNAME;
        } else {
            newPref = EDITBOX_FONTSTYLE_PROPORTIONAL;
            prefCssClassName = EDITBOX_FONTSTYLE_MONO_CLASSNAME;
            toggleCssClassName = EDITBOX_FONTSTYLE_PROPORTIONAL_CLASSNAME;		
        }
        
        if (buttonState == 'over') {
            jel.removeClass(prefCssClassName)
            .addClass(toggleCssClassName);
        } else if (buttonState == 'out') {
            jel.removeClass(toggleCssClassName)
            .addClass(prefCssClassName);
        }
        
        return newPref;
    }

    // Not sure the hide() and show() is strictly necessary, but the pre-jq
    // version did it so retained.
    $(document).ready(
        function($) {
            $('span.patternButtonFontSelector')
                .hide()
                .click(
                    function(e) {
                        var newPref = foswiki.Edit.toggleFontStateControl(
                            $(this), '');
                        foswiki.Edit.setFontStyle(newPref);
                        return false;
                    })
                .mouseover(
                    function(e) {
                        foswiki.Edit.toggleFontStateControl($(this), 'over');
                        return false;
                    })
                .mouseout(
                    function (e) {
                        foswiki.Edit.toggleFontStateControl($(this), 'out');
                        return false;
                    })
                .each(
                    function(index, el) {
                        foswiki.Edit.toggleFontStateControl($(el), 'out');
                    });
            
            $('span.patternButtonEnlarge')
                .hide()
                .click(
                    function() {
                        return foswiki.Edit.changeEditBox(1);
                    });
            
            $('span.patternButtonShrink')
                .hide()
                .click(
                    function(){
                        return foswiki.Edit.changeEditBox(-1);
                    });
            
            $('span.patternButtonShrink').show();
            $('span.patternButtonEnlarge').show();
            $('span.patternButtonFontSelector').show();
        });
})(jQuery);
