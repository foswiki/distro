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

// CAUTION: foswikilib.js is DEPRECATED. it's use potentially breaks 
// other code depending on JQueryPlugin by overriding the foswiki namespace.
// Please use JQUERYPLUGIN::FOSWIKI instead
var foswiki = {

    /**
     * Get the content of a META tag from the HEAD block of the document.
     * The values are cached after reading for fast lookup.
     * @param inKey Name of the meta-tag for which to retrieve the content
     */
    getMetaTag: function(inKey) {
        // NOTE: == and != are used, not === and !==, because null == undefined
        // but does not === it  - see
        // https://developer.mozilla.org/en/Core_JavaScript_1.5_Reference/Operators/Comparison_Operators
        if (foswiki.metaTags == null || foswiki.metaTags.length === 0) {
            // Do this the brute-force way because of the problem
            // seen sporadically on Bugs web where the DOM appears complete, but
            // the META tags are not all found by getElementsByTagName
            var head = document.getElementsByTagName("META");
            head = head[0].parentNode.childNodes;
            foswiki.metaTags = [];
            for (var i = 0; i < head.length; i++) {
                if (head[i].tagName != null &&
                    head[i].tagName.toUpperCase() == 'META') {
                    foswiki.metaTags[head[i].name] = unescape(head[i].content);
                }
            }
        }
        return foswiki.metaTags[inKey]; 
    },
    
    /**
     * Get a Foswiki preference value. Preference values can be obtained
     * in three ways; (1) by reference to the pre-loaded foswiki.preferences
     * hash (2) by looking up meta-data or (3) if useServer is true, by using
     * an HTTP call to the server (a.k.a AJAX).
     * @param key name of preference to retrieve
     * @param useServer Allow the function to refer to the server. If this
     * is false, then no http call will be made even if the preference is
     * not available from the preferences has or META tags.
     * @return value of preference, or null if it cannot be determined
     * TODO: HTTP call not implemented yet.
     * Note the the HTTP call (when it is implemented) will have to pass
     * the TOPIC and WEB preferences to the server, so it can determine
     * the context of the preference.
     */
    getPreference: function(key, useServer) {
        // Check the preloaded foswiki hash. This is populated with the values
        // listed in the %EXPORTEDPREFERENCES% Foswiki preference. See
        // System.DefaultPreferences for guidance on extending this from
        // Plugins.
        if (foswiki.preferences !== undefined) {
            if (foswiki.preferences[key] !== undefined) {
                return foswiki.preferences[key];
            }
        }
        
        // Check for a preference passed in a meta tag (this is the classical
        // method)
        var metaVal = foswiki.getMetaTag(key);
        if (metaVal !== undefined) {
            // Cache it for future reference
            if (foswiki.preferences === undefined) {
                foswiki.preferences = {};
            }
            foswiki.preferences[key] = unescape(metaVal);
            return metaVal;
        }
        
        // Use AJAX to get a preference value from the server. This requires
        // a lot of context information to be passed to the server, and a REST
        // handler on the server, so has not been implemented yet.
        if (useServer) {
            window.alert("Trying to get preference '" + key
                         + "' from server, but " + 
                         "this feature is not implemented yet.");
        }
        return null;
    },
    
    /**
     * Get all elements under root that include the given class.
     * @param inRootElem: HTMLElement to start searching from
     * @param inClassName: CSS class name to find
     * @param inTag: (optional) HTML tag to speed up searching
     * (if not given, a wildcard is used to search all elements)
     * @example:
     * <code>
     * var gallery = document.getElementById('galleryTable');
     * var elems = foswiki.getElementsByClassName(gallery, 'personalPicture');
     * var firstPicture = elems[0];
     * </code>
     */
    getElementsByClassName: function(inRootElem, inClassName, inTag) {
        var tag = inTag || '*';
        var elms = inRootElem.getElementsByTagName(tag);
        var className = inClassName.replace(/\-/g, "\\-");
        var re = new RegExp("\\b" + className + "\\b");
        var el;
        var hits = [];
        for (var i = 0; i < elms.length; i++) {
            el = elms[i];
            if (re.test(el.className)) {
                hits.push(el);
            }
        }
        return hits;
    }
};

(function($) {
    $(document).ready(
        function($) {
            // Controls for the "check all" buttons in the rename screen
            // Formerly in foswikiForm.js
            $(".foswikiCheckAllOn").click(
                function(e) {
                    $(".foswikiGlobalCheckable").attr("checked", "checked");
                });
            $(".foswikiCheckAllOff").click(
                function(e) {
                    $(".foswikiGlobalCheckable").removeAttr("checked");
                });
        });
})(jQuery);
