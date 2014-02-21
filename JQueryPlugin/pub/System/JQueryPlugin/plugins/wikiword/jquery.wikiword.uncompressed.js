/*
 * jQuery WikiWord plugin 2.1
 *
 * Copyright (c) 2008-2014 Foswiki Contributors http://foswiki.org
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

    downgradeMap: {
      // LATIN
      'À': 'A', 'Á': 'A', 'Â': 'A', 'Ã': 'A', 'Ä': 'Ae', 'Å': 'A', 'Æ': 'AE', 'Ç':
      'C', 'È': 'E', 'É': 'E', 'Ê': 'E', 'Ë': 'E', 'Ì': 'I', 'Í': 'I', 'Î': 'I',
      'Ï': 'I', 'Ð': 'D', 'Ñ': 'N', 'Ò': 'O', 'Ó': 'O', 'Ô': 'O', 'Õ': 'O', 'Ö':
      'Oe', 'Ő': 'O', 'Ø': 'O', 'Ù': 'U', 'Ú': 'U', 'Û': 'U', 'Ü': 'Ue', 'Ű': 'U',
      'Ý': 'Y', 'Þ': 'TH', 'ß': 'ss', 'à':'a', 'á':'a', 'â': 'a', 'ã': 'a', 'ä':
      'ae', 'å': 'a', 'æ': 'ae', 'ç': 'c', 'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
      'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ð': 'd', 'ñ': 'n', 'ò': 'o', 'ó':
      'o', 'ô': 'o', 'õ': 'o', 'ö': 'oe', 'ő': 'o', 'ø': 'o', 'ù': 'u', 'ú': 'u',
      'û': 'u', 'ü': 'ue', 'ű': 'u', 'ý': 'y', 'þ': 'th', 'ÿ': 'y',

      // LATIN_SYMBOLS
      '©':'(c)',

      // GREEK
      'α':'a', 'β':'b', 'γ':'g', 'δ':'d', 'ε':'e', 'ζ':'z', 'η':'h', 'θ':'8',
      'ι':'i', 'κ':'k', 'λ':'l', 'μ':'m', 'ν':'n', 'ξ':'3', 'ο':'o', 'π':'p',
      'ρ':'r', 'σ':'s', 'τ':'t', 'υ':'y', 'φ':'f', 'χ':'x', 'ψ':'ps', 'ω':'w',
      'ά':'a', 'έ':'e', 'ί':'i', 'ό':'o', 'ύ':'y', 'ή':'h', 'ώ':'w', 'ς':'s',
      'ϊ':'i', 'ΰ':'y', 'ϋ':'y', 'ΐ':'i',
      'Α':'A', 'Β':'B', 'Γ':'G', 'Δ':'D', 'Ε':'E', 'Ζ':'Z', 'Η':'H', 'Θ':'8',
      'Ι':'I', 'Κ':'K', 'Λ':'L', 'Μ':'M', 'Ν':'N', 'Ξ':'3', 'Ο':'O', 'Π':'P',
      'Ρ':'R', 'Σ':'S', 'Τ':'T', 'Υ':'Y', 'Φ':'F', 'Χ':'X', 'Ψ':'PS', 'Ω':'W',
      'Ά':'A', 'Έ':'E', 'Ί':'I', 'Ό':'O', 'Ύ':'Y', 'Ή':'H', 'Ώ':'W', 'Ϊ':'I',
      'Ϋ':'Y',

      // TURKISH
      'ş':'s', 'Ş':'S', 'ı':'i', 'İ':'I', 'ç':'c', 'Ç':'C', 'ü':'ue', 'Ü':'Ue',
      'ö':'oe', 'Ö':'Oe', 'ğ':'g', 'Ğ':'G',

      // RUSSIAN
      'а':'a', 'б':'b', 'в':'v', 'г':'g', 'д':'d', 'е':'e', 'ё':'yo', 'ж':'zh',
      'з':'z', 'и':'i', 'й':'j', 'к':'k', 'л':'l', 'м':'m', 'н':'n', 'о':'o',
      'п':'p', 'р':'r', 'с':'s', 'т':'t', 'у':'u', 'ф':'f', 'х':'h', 'ц':'c',
      'ч':'ch', 'ш':'sh', 'щ':'sh', 'ъ':'', 'ы':'y', 'ь':'', 'э':'e', 'ю':'yu',
      'я':'ya',
      'А':'A', 'Б':'B', 'В':'V', 'Г':'G', 'Д':'D', 'Е':'E', 'Ё':'Yo', 'Ж':'Zh',
      'З':'Z', 'И':'I', 'Й':'J', 'К':'K', 'Л':'L', 'М':'M', 'Н':'N', 'О':'O',
      'П':'P', 'Р':'R', 'С':'S', 'Т':'T', 'У':'U', 'Ф':'F', 'Х':'H', 'Ц':'C',
      'Ч':'Ch', 'Ш':'Sh', 'Щ':'Sh', 'Ъ':'', 'Ы':'Y', 'Ь':'', 'Э':'E', 'Ю':'Yu',
      'Я':'Ya',

      // UKRAINIAN
      'Є':'Ye', 'І':'I', 'Ї':'Yi', 'Ґ':'G', 'є':'ye', 'і':'i', 'ї':'yi', 'ґ':'g',

      // CZECH
      'č':'c', 'ď':'d', 'ě':'e', 'ň': 'n', 'ř':'r', 'š':'s', 'ť':'t', 'ů':'u',
      'ž':'z', 'Č':'C', 'Ď':'D', 'Ě':'E', 'Ň': 'N', 'Ř':'R', 'Š':'S', 'Ť':'T',
      'Ů':'U', 'Ž':'Z',

      // POLISH
      'ą':'a', 'ć':'c', 'ę':'e', 'ł':'l', 'ń':'n', 'ó':'o', 'ś':'s', 'ź':'z',
      'ż':'z', 'Ą':'A', 'Ć':'C', 'Ę':'e', 'Ł':'L', 'Ń':'N', 'Ó':'o', 'Ś':'S',
      'Ź':'Z', 'Ż':'Z',

      // LATVIAN
      'ā':'a', 'č':'c', 'ē':'e', 'ģ':'g', 'ī':'i', 'ķ':'k', 'ļ':'l', 'ņ':'n',
      'š':'s', 'ū':'u', 'ž':'z', 'Ā':'A', 'Č':'C', 'Ē':'E', 'Ģ':'G', 'Ī':'i',
      'Ķ':'k', 'Ļ':'L', 'Ņ':'N', 'Š':'S', 'Ū':'u', 'Ž':'Z'
  },

  /***********************************************************************
   * constructor
   */
  build: function(source, options) {
   
    // build main options before element iteration
    var opts = $.extend({}, $.fn.wikiword.defaults, options);

    var $source = $(source);

    // iterate and reformat each matched element
    return this.each(function() {
      var $this = $(this);

      // build element specific options. 
      // note you may want to install the Metadata plugin
      var thisOpts = $.meta ? $.extend({}, opts, $this.data()) : opts;

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
  handleChange: function(source, target, thisOpts) {
    var result = '';
    source.each(function() {
      result += $(this).is(':input')?$(this).val():$(this).text();
    });

    if (result || !thisOpts.initial) {
      result = $.wikiword.wikify(result);

      if (thisOpts.suffix) {
        result += thisOpts.suffix;
      }
      if (thisOpts.prefix) {
        result = thisOpts.prefix+result;
      }
    } else {
      result = thisOpts.initial;
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
  wikify: function (source) {

    var result = '', c;

    // transliterate unicode chars
    for (var i = 0; i < source.length; i++) {
      c = source[i];
      result += $.wikiword.downgradeMap[c] || c;
    }

    // capitalize
    result = result.replace(/[a-zA-Z\d]+/g, function(a) {
        return a.charAt(0).toLocaleUpperCase() + a.substr(1);
    });

    // remove all non-mixedalphanums
    result = result.replace(/[^a-zA-Z\d]/g, "");

    // remove all spaces
    result = result.replace(/\s/g, "");

    return result;
  },

  /***************************************************************************
   * plugin defaults
   */
  defaults: {
    suffix: '',
    prefix: '',
    initial: ''
  }
};

/* register by extending jquery */
$.fn.wikiword = $.wikiword.build;

/* init */
$(function() {
  $(".jqWikiWord:not(.jqInitedWikiWord)").livequery(function() {
    var $this = $(this), options;
    $this.addClass("jqInitedWikiWord");
    options = $.extend({}, $this.metadata());
    $this.wikiword(options.source, options);
  });
});

})(jQuery);
