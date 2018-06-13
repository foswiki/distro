/*
 * jQuery WikiWord plugin 3.30
 *
 * Copyright (c) 2008-2018 Foswiki Contributors http://foswiki.org
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 *
 */
"use strict";

/***************************************************************************
 * plugin definition 
 */
(function($) {
$.wikiword = {

  downgradeMap: {},

  /***********************************************************************
   * constructor
   */
  build: function(options) {
    var opts;

    // call build either with an options object or with a source string
    if (typeof(options) === 'string') {
      options = {
        source: options
      };
    }
   
    // build main options before element iteration
    opts = $.extend({}, $.wikiword.defaults, options);

    // iterate and reformat each matched element
    return this.each(function() {
      var $this = $(this),
          thisOpts = $.extend({}, opts, $this.data(), $this.metadata()),
          $source;

      // either a string or a jQuery object
      if (typeof(thisOpts.source) === 'string') {
        // first try to find the source within the same form
        $source = $this.parents("form:first").find(thisOpts.source);
        // if that fails, try in a global scope
        if ($source.length === 0) {
          $source = $(thisOpts.source);
        }
      } else {
        $source = thisOpts.source;
      }

      $source.on("change", function() {
        $.wikiword.handleChange($source, $this, thisOpts);
      }).keyup(function() {
        $.wikiword.handleChange($source, $this, thisOpts);
      }).change();
    });
  },

  /***************************************************************************
   * handler for source changes
   */
  handleChange: function(source, target, opts) {
    var result = [];

    // gather all sources
    source.each(function() {
      result.push($(this).is(':input')?$(this).val():$(this).text());
    });
    result = result.join(" ");

    if (result || !opts.initial) {
      result = $.wikiword.wikify(result, opts);
    } else {
      result = opts.initial;
    }

    target.each(function() {
      if ($(this).is(':input')) {
        $(this).val(result);
      } else {
        $(this).text(result);
      }
    }).trigger("change");
  },

  /***************************************************************************
   * convert a source string to a valid WikiWord
   */
  wikify: function (source, opts) {
    var result = '', c, i;

    opts = $.extend({}, $.wikiword.defaults, opts);

    // generate RegExp for filtered chars
    if (typeof(opts.allowedRegex) === 'string') {
      opts.allowedRegex = new RegExp(opts.allowedRegex, "g");
    }
    if (typeof(opts.forbiddenRegex) === 'string') {
      opts.forbiddenRegex = new RegExp(opts.forbiddenRegex, "g");
    }

    // transliterate unicode chars
    if (opts.transliterate) {
      for (i = 0; i < source.length; i++) {
        c = source[i];
        result += $.wikiword.downgradeMap[c] || c;
      }
    } else {
      result = source;
    }

    // capitalize each individual word
    result = result.replace(opts.allowedRegex, function(a) {
        return a.charAt(0).toLocaleUpperCase() + a.substr(1);
    });

    // remove all forbidden chars
    result = result.replace(opts.forbiddenRegex, "");

    if (opts.suffix && result.indexOf(opts.suffix, result.length - opts.suffix.length) === -1) {
      result += opts.suffix;
    }
    if (opts.prefix && result.indexOf(opts.prefix) !== 0) {
      result = opts.prefix+result;
    }

    return result;
  },

  /***************************************************************************
   * plugin defaults
   */
  defaults: {
    suffix: '',
    prefix: '',
    initial: '',
    transliterate: false,
    allowedRegex: '[' + foswiki.RE.alnum + ']+',
    forbiddenRegex: '[^' + foswiki.RE.alnum + ']+'
  }
};

/* register by extending jquery */
$.fn.wikiword = $.wikiword.build;

/* init */
$(function() {
  $(".jqWikiWord:not(.jqInitedWikiWord)").livequery(function() {
    $(this).addClass("jqInitedWikiWord").wikiword();
  });
});

})(jQuery);
