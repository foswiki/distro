/*
 * jQuery tmpl-loader 1.01
 *
 * loads a jquery.template from an url and compiles it
 *
 * Copyright (C) 2010-2016 Foswiki Contributors. Foswiki Contributors
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 *
 */

(function($) {
"use strict";

  var queue = {};

  function getUniqueTemplateName() {
    var uid = new Date().getTime().toString(32),
      i;

    for (i = 0; i < 5; i++) {
      uid += Math.floor(Math.random() * 65535).toString(32);
    }
    return "tmpl_" + uid;
  }

  $.loadTmpl = function(url, opts) {
    opts = opts || {};

    if (typeof(url) === 'string') {
      opts.url = url;
    } else if (typeof(url) === 'object') {
      opts = url;
    }

    if (typeof(opts.url) === 'undefined') {
      throw "ERROR: no url specified in loadTmpl";
    }

    opts.name = opts.name || opts.url || getUniqueTemplateName();

    // look up queue for requests already loading
    var promise = queue[opts.url];

    if (typeof(promise) === "undefined") {

      // not yet loading, create a new request
      queue[opts.url] = promise = $.Deferred(function(dfd) {

        if (typeof($.template[opts.name]) !== 'undefined' && !opts.force) {

          // already loaded
          dfd.resolve(opts.name);

        } else {

          // not loaded yet

          $.log("loading tmpl from ",opts.url);
          $.ajax({
            url: opts.url
            // TODO: allow to set ajax options
          }).then(
            function(data, status, xhr) {

              // remove from queue
              queue[opts.url] = undefined;

              $.template(opts.name, data);
              dfd.resolve(opts.name);
              return true;
            },

            function(xhr, status, error) {

              // remove from queue
              queue[opts.url] = undefined;

              dfd.reject(xhr);
              return false;
            }

          );
        }

      }).promise();
    }

    return promise;
  };

  $.fn.loadTmpl = function (opts, data) { 
    return this.each(function () { 
      var $elem = $(this);
      $.loadTmpl(opts).done(function(name) {
        $elem.html($.tmpl(name, data));
      })
    }); 
  } 


})(jQuery);
