/*
 * jQuery WikiWord plugin 3.10
 *
 * Copyright (c) 2008-2016 Foswiki Contributors http://foswiki.org
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 *
 */

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
        $source = $(thisOpts.source);
      } else {
        $source = thisOpts.source;
      }

      // generate RegExp for filtered chars
      if (typeof(thisOpts.allowedRegex) === 'string') {
        thisOpts.allowedRegex = new RegExp(thisOpts.allowedRegex, "g");
      }
      if (typeof(thisOpts.forbiddenRegex) === 'string') {
        thisOpts.forbiddenRegex = new RegExp(thisOpts.forbiddenRegex, "g");
      }

      $source.change(function() {
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
    var result = []

    // gather all sources
    source.each(function() {
      result.push($(this).is(':input')?$(this).val():$(this).text());
    });
    result = result.join(" ");

    if (result || !opts.initial) {
      result = $.wikiword.wikify(result, opts);

      if (opts.suffix && result.indexOf(opts.suffix, result.length - opts.suffix.length) == -1) {
        result += opts.suffix;
      }
      if (opts.prefix && result.indexOf(opts.prefix) !== 0) {
        result = opts.prefix+result;
      }
    } else {
      result = opts.initial;
    }

    target.each(function() {
      if ($(this).is(':input')) {
        $(this).val(result);
      } else {
        $(this).text(result);
      }
    });
  },

  /***************************************************************************
   * convert a source string to a valid WikiWord
   */
  wikify: function (source, opts) {

    var result = '', c, i;

    opts = opts || $.wikiword.defaults;

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
