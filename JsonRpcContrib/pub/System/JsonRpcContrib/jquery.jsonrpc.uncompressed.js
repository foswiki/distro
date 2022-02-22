/*
 * JsonRpc for Foswiki
 *
 * Copyright (c) 2011-2022 Michael Daum
 *
 * Licensed under the GPL licenses http://www.gnu.org/licenses/gpl.html
 *
 */

"use strict";

(function($) {

  /* helper function to create a json-rpc request object */
  function createRequest(options) {
    var data = { 
      jsonrpc: "2.0",
      method: options.method
    };
    if (typeof(options.params) !== 'undefined') {
      data.params = options.params;
    }
    if (typeof(options.id) !== 'undefined') {
      data.id = options.id;
    }

    return data;
  }

  /* perform a single json-rpc */
  foswiki.jsonRpc = function(options) {
    return $.jsonRpc(foswiki.getScriptUrl("jsonrpc"), options);
  };

  $.jsonRpc = function(endpoint, options) {
    var data = createRequest(options), 
        url = endpoint,
        async = true;

    if (typeof(options.namespace) !== 'undefined') {
      url += "/"+options.namespace;
    }

    if (typeof(options.async) !== 'undefined') {
      async = options.async;
    }

    return $.ajax({
      type: 'POST',
      dataType: 'json',
      url: url,
      data: JSON.stringify(data),
      contentType: 'application/json',
      processData: false,
      cache: false,
      async: async,
      beforeSend: function(xhr) {
        if (typeof(options.beforeSend) === 'function') {
          options.beforeSend.call(options, xhr);
        }
      },
      error: function(xhr, textStatus, error) {
        if (typeof(options.error) === 'function') {
          var json;
          if (xhr.status == 404) {
            json = {jsonrpc: "2.0", error: { code: xhr.status, message: textStatus }};
          } else {
            json = $.parseJSON(xhr.responseText);
          }
          options.error.call(options, json, textStatus, xhr);
        }
      },
      success: function(json, textStatus, xhr) {
        if (typeof(options.success) === 'function') {
          options.success.call(options, json, textStatus, xhr);
        }
      }
    });
  }

})(jQuery);
