/**
 * Foswiki setups wrt jQuery
 *
 */

/*global XMLHttpRequest:false, StrikeOne:false */
var foswiki = foswiki || {
  preferences: {}
};

(function($) {

  /**
   * dummy to be overridden by jquery.debug
   */
  $.log = function(message) {};
  $.fn.debug = function() {};

  /**
   * generates an unique ID.
   */
  foswiki.getUniqueID = function() {
    var uid = new Date().getTime().toString(32),
      i;
    for (i = 0; i < 5; i++) {
      uid += Math.floor(Math.random() * 65535).toString(32);
    }
    return uid;
  };

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
   * Note the the HTTP call (when it is implemented) will have to pass
   * the TOPIC and WEB preferences to the server, so it can determine
   * the context of the preference.
   *
   * See System.DefaultPreferences for guidance on extending the content
   * of the preloaded preferences hash under the control of Foswiki plugins.
   */
  foswiki.getPreference = function(key, useServer) {
    var metaVal;

    // Check the preloaded foswiki hash. This is populated with the values
    // listed in the %EXPORTEDPREFERENCES% foswiki preference
    if (typeof(foswiki.preferences[key]) !== 'undefined') {
      return foswiki.preferences[key];
    }

    // Check for a preference passed in a meta tag (this is the classical method)
    metaVal = $("meta[name=\"foswiki." + key + "\"]").attr("content");
    if (typeof(metaVal) !== 'undefined') {
      metaVal = unescape(metaVal);
      // Cache it for future reference
      foswiki.preferences[key] = metaVal;
      return metaVal;
    }

    // Use AJAX to get a preference value from the server. This requires
    // a lot of context information to be passed to the server, and a REST
    // handler on the server, so has not been implemented yet.
    if (useServer) {

      $.ajax({
        url: foswiki.getScriptUrl(1, "view", foswiki.getPreference("SYSTEMWEB"), "JQueryAjaxHelper"),
        data: {
          skin: 'text',
          section: 'expand',
          expression: key
        },
        async: false,
        dataType: 'text',
        success: function(data, status, xhr) {
          foswiki.preferences[key] = data;
        }
      });

      return foswiki.preferences[key];
    }

    foswiki.preferences[key] = null;
    return null;
  };

  /**
   * Get pub url path for a specific file
   */
  function _getPubUrl(absolute, web, topic, file, params) {
    var prefName = (absolute?"PUBURL":"PUBURLPATH"),
        url, arr = [];

    url = foswiki.getPreference(prefName) || '/';

    if (typeof(web) !== 'undefined') {
      url += "/"+web;
    }

    if (typeof(topic) !== 'undefined') {
      url += "/"+topic;
    }

    if (typeof(file) !== 'undefined') {
      url += "/"+file;
    }

    if (typeof(params) !== 'undefined') {
      $.each(params, function(key, val) {
        arr.push(key+"="+val);
      });

      url += (arr.length?"?"+arr.join("&"):"");
    }

    return url;
  }
  foswiki.getPubUrl = function(web, topic, file, params) {
    return _getPubUrl(1, web, topic, file, params);
  };
  foswiki.getPubUrlPath = function(web, topic, params) {
    return _getScriptUrl(0, script, web, topic, params);
  };

  /**
   * Get url path for a specific script
   */
  function _getScriptUrl(absolute, script, web, topic, params) {
    var prefName = (absolute?"SCRIPTURL":"SCRIPTURLPATH"),
        suffix = foswiki.getPreference("SCRIPTSUFFIX") || "",
        url, arr = [];

    script = script || '';

    url = foswiki.getPreference(prefName+"_"+script.toUpperCase());

    if (!url) {
      url = foswiki.getPreference(prefName) + "/" + script + suffix;
    }

    if (typeof(web) !== 'undefined') {
      url += "/"+web;
    }

    if (typeof(topic) !== 'undefined') {
      url += "/"+topic;
    }

    if (typeof(params) !== 'undefined') {
      $.each(params, function(key, val) {
        arr.push(key+"="+val);
      });

      url += (arr.length?"?"+arr.join("&"):"");
    }

    return url;
  }

  foswiki.getScriptUrl = function(script, web, topic, params) {
    return _getScriptUrl(1, script, web, topic, params);
  };
  foswiki.getScriptUrlPath = function(script, web, topic, params) {
    return _getScriptUrl(0, script, web, topic, params);
  };


  /**
   * Get the content of a META tag from the HEAD block of the document.
   * @param inKey Name of the meta-tag for which to retrieve the content
   *
   * WARNING: this function is DEPRECATED; please use the given jQuery expression directly
   */
  foswiki.getMetaTag = function(inKey) {
    return $("meta[name=" + inKey + "]").attr("content");
  };

  /**
   * Get all elements under root that include the given class.
   * @param inRootElem: HTMLElement to start searching from
   * @param inClassName: CSS class name to find
   * @param inTag: (optional) HTML tag to speed up searching (if not given, a wildcard is used to search all elements)
   * @example:
   * <code>
   * var gallery = document.getElementById('galleryTable');
   * var elems = foswiki.getElementsByClassName(gallery, 'personalPicture');
   * var firstPicture = elems[0];
   * </code>
   *
   * WARNING: this function is DEPRECATED; please use an appropriate jQuery expression directly.
   * The above code can be simplified to
   * <code>
   * var firstPicture = $('#galleryTable .personalPicture')[0];
   * </code>
   */
  foswiki.getElementsByClassName = function(inRootElem, inClassName, inTag) {
    var tag = inTag || '';
    return $(inRootElem).find(tag + "." + inClassName).get();
  };

  /**
   * document ready handler
   */
  $(function() {
    /* Remove 'has no javascript' class from body element (written in template). */
    $('body').removeClass('foswikiNoJs').addClass("foswikiJs");
  });
}(jQuery));
