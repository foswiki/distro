// initializer for the ui-autocomplete plugin;
// adds limited backwards compatibility to old jquery.autocomplete
"use strict";
jQuery(function($) {

  var defaults = {
    cache: true // SMELL: note, if you disable caching, extraParams won't be processed either
  };

  $("input[autocomplete]:not([autocomplete=off]):not([autocomplete=new-password]):not(.jqInitedAutocomplete, .jqTextboxList), .jqUIAutocomplete").livequery(function() {
    var $this = $(this), 
        cache = {}, lastXhr,
        src = $this.attr('autocomplete'),
        opts = $.extend({ source: src }, defaults, $this.data()); 

    if (typeof(opts.source) === 'string') {
      if (opts.cache && (opts.source.startsWith("/") || opts.source.startsWith("http"))) {
        // wrap source url into a cache 
        opts._source = opts.source;

        opts.source = function(request, response) {
          var term = request.term, cacheKey = term;

          // add extra parameters similar to the old jquery.autocomplete
          if (typeof(opts.extraParams) != 'undefined') {
            $.each(opts.extraParams, function(key, param) {
              var val = typeof param == "function" ? param($this) : param;
              request[key] = val;
              cacheKey += ';' + key + '=' + val;
            });
          }

          // check cache
          if (cacheKey in cache) {
            response(cache[cacheKey]);
            return;
          }

          // get result from backend
          lastXhr = $.ajax({
            url: opts._source, 
            dataType: 'json',
            data: request, 
            success: function(data, status, xhr) {
              cache[cacheKey] = data;

              // throw away response if there already was a newer one
              if (xhr === lastXhr) {
                response(data);
              }
            },
            error: function(xhr, status, error) {
              alert("Error: "+status);
              response();
            }
          });
        };
      } else if (typeof(window[opts.source]) !== 'undefined') {
        opts.source = window[opts.source];
      }
    }

    $this.removeClass("jqUIAutocomplete").autocomplete(opts);
  });

});
