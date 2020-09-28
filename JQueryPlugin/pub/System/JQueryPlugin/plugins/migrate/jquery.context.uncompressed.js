"use strict";
// bring back context and selector
if (jQuery.fn.jquery[0] >= 3) {

  var oldInit = jQuery.fn.init;

  jQuery.fn.init = function( selector, context, root ) {
          var ret;

          ret = oldInit.apply( this, arguments );

          // Fill in selector and context properties so .live() works
          if ( selector && selector.selector !== undefined ) {
                  // A jQuery object, copy its properties
                  ret.selector = selector.selector;
                  ret.context = selector.context;

          } else {
                  ret.selector = typeof selector === "string" ? selector : "";
                  if ( selector ) {
                          ret.context = selector.nodeType? selector : context || document;
                  }
          }

          return ret;
  };

}
