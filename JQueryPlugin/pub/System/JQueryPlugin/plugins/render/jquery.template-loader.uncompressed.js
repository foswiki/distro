/*
 * jQuery template-loader 2.01
 *
 * loads a jquery template from an url and compiles it
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

  $.loadTemplate = function(url, opts) {
    opts = opts || {};

    if (typeof(url) === 'string') {
      opts.url = url;
    } else if (typeof(url) === 'object') {
      opts = url;
    }

    if (typeof(opts.url) === 'undefined') {
      throw "ERROR: no url specified in loadTemplate";
    }

    opts.name = opts.name || opts.url || getUniqueTemplateName();

    // look up queue for requests already loading
    var promise = queue[opts.url];

    if (typeof(promise) === "undefined") {

      // not yet loading, create a new request
      queue[opts.url] = promise = $.Deferred(function(dfd) {
        var template = $.templates[opts.name];

        if (typeof(template) !== 'undefined' && !opts.force) {

          // already loaded
          dfd.resolve(template);

        } else {

          // not loaded yet

          $.log("loading template from ",opts.url);
          $.ajax({
            url: opts.url
            // TODO: allow to set ajax options
          }).then(
            function(data, status, xhr) {

              // remove from queue
              queue[opts.url] = undefined;

              template = $.templates(opts.name, data);
              dfd.resolve(template);
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

  $.fn.loadTemplate = function (opts, data) { 
    return this.each(function () { 
      var $elem = $(this);
      $.loadTemplate(opts).done(function(template) {
        $elem.html(template.render(data));
      })
    }); 
  };


})(jQuery);
