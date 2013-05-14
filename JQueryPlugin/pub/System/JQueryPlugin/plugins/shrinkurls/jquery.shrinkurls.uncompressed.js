/*
 * jQuery Shrinkurls plugin 1.1
 *
 * Copyright (c) 2007-2013 Foswiki Contributors http://foswiki.org
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 *
 */

/**
 * shrinks all urls in a given container whose link text exceeds
 * a given size and have no white spaces in it, that is don't
 * wrap around nicely. If the text is skrunk, the original text
 * is appended to the title attribute of the anchor.
 *
 * Usage
 *  $("#container a").shrinkUrls({
 *    size:<number>,           // max size (default 25)
 *    include:'<regex>'       // regular expression a link text must 
 *                            // match to be considered
 *    exclude:'<regex>'       // regular expression a link text must 
 *                            // not match to be considered
 *    whitespace:<boolean>,   // true: even shrink if there's whitespace
 *                            // in the link text (default false)
 *    trunc:<head|middle|tail> // position where to insert the ellipsis
 *  });
 *
 */

(function($) {
$.fn.extend({
  shrinkUrls: function(settings) {
    settings = $.extend({
      whitespace:false,
      trunc:'tail'
    }, settings || {});

    return this.each(function() {
      var text = $(this).text();
      var txtlength = text.length;
      if ((txtlength > settings.size) && 
          (!settings.include || text.match(settings.include)) &&
          (!settings.exclude || !text.match(settings.exclude)) &&
          (settings.whitespace || !text.match(/\s/))) {
        var firstPart = "";
        var lastPart = "";
        var middlePart = "";
        //$.log("length="+txtlength+", text="+text);
        switch (settings.trunc) {
          case 'head':
            lastPart = text.substring(txtlength-settings.size+1,txtlength);
            break;
          case 'middle':
            firstPart = text.substring(0,settings.size/2);
            lastPart = text.substring(txtlength-settings.size/2+1,txtlength);
            break;
          default:
          case 'tail':
            firstPart = text.substring(0,settings.size-1);
            break;
        }
        var origText = text;
        text = firstPart + "&hellip;" + lastPart;
        var title = $(this).attr('title');
        if (!title) {
          title = origText;
        }
        $(this).html(text).attr('title',title);
      }

    });
  }
});
})(jQuery);
