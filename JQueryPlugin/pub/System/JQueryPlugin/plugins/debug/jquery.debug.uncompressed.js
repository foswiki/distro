/*
 * Simple jQuery logger / debugger.
 * Based on: http://jquery.com/plugins/Authoring/
 * See var DEBUG below for turning debugging/logging on and off.
 * Modified by Stephane Lenclud to support logging key/value object
 *
 * @version   20080225
 * @since     2006-07-10
 * @copyright Copyright (c) 2006 Glyphix Studio, Inc. http://www.glyphix.com, Copyright (c) 2008 Stephane Lenclud.
 * @author    Brad Brizendine <brizbane@gmail.com>
 * @license   MIT http://www.opensource.org/licenses/mit-license.php
 * @requires  >= jQuery 1.0.3
 */
// global debug switch ... add DEBUG = true; somewhere after jquery.debug.js is loaded to turn debugging on
var DEBUG = true;
(function($) {
  
  if (!("console" in window)){
    $(function() {
            var names = ["log", "debug", "info", "warn", "error", "assert", "dir", "dirxml", "group", "groupEnd", "time", "timeEnd", "count", "trace", "profile", "profileEnd"];
            // create the logging div
            var $list = $("<ol></ol>");
            var $debug = $('<div id="DEBUG"></div>').appendTo("body");
            $debug.append($list);
            // attach a function to each of the console methods
            window.console = {};
            for (var i = 0; i < names.length; ++i){
                    window.console[names[i]] = function(msg){ 
                      $list.append( '<li>' + msg + '</li>' ); 
                      $debug.scrollTop($debug[0].scrollHeight); 
                    };
            }
    });
  }

  /*
   * debug
   * Simply loops thru each jquery item and logs it
   */
  $.fn.debug = function() {
          return this.each(function(){
                  $.log(this);
          });
  };

  /*
   * log
   * Send it anything, and it will add a line to the logging console.
   * If a console is defined, it simple send the item to it.
   * If not, it creates a string representation of the html element (if message is an object), or just uses the supplied value (if not an object).
   */
  $.log = function(message){
          // only if debugging is on
          if( window.DEBUG ){
                  // if there's no console, build a debug line from the actual html element if it's an object, or just send the string
                  var str = message;
                  if(!("console" in window)){
                          if( typeof(message) == 'object' ){
                                  if (message.nodeName) {
                                          str = '&lt;';	
                                          str += message.nodeName.toLowerCase();
                                          for( var i = 0; i < message.attributes.length; i++ ){
                                                  str += ' ' + message.attributes[i].nodeName.toLowerCase() + '="' + message.attributes[i].nodeValue + '"';
                                          }
                                          str += '&gt;';
                                  } else {
                                          for(var key in message) { 
                                            str += key + " : " + (message[key]) + ", "; 
                                          }	
                                  }
                                  
                          }
                  }
                  console.log(str);
          }
  };
})(jQuery);
