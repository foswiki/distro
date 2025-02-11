/*
 * i18n - the simplest possible solution 
 *
 * Copyright (c) 2016-2025 Michael Daum http://michaeldaumconsulting.com
 *
 * Licensed under the GPL license http://www.gnu.org/licenses/gpl.html
 *
 */

/*eslint-disable no-console */

"use strict";
(function($) {
  var translator;

  // constructor
  var I18N = function() {
    var self = this;

    self.messageStore = {};
    self.currentLanguage = $("html").attr("lang") || 'en';

    // dynamically load localizations
    $('script[type="application/l10n"]').livequery(function() {
      var $this = $(this),
          opts = $this.data(),
          url = opts.i18nSrc || $this.attr("src"),
          data;

      if (opts.i18nLanguage === self.currentLanguage) {
        // inline
        if (typeof(url) === 'undefined') {
          data = $.parseJSON($this.text());
          self.addResource(data, opts.i18nLanguage, opts.i18nNamespace);
          self.translateAllElements();
        } else {
          self.loadResource(url, opts.i18nLanguage, opts.i18nNamespace);
        }
      }
    });

    // dynamically translate all i18n elements 
    $(".i18n:not(.i18nTranslated)").livequery(function() {
      self.translateElement(this);
    });

    // listen for change event on html element
    $("html").on("change", function() {
      var language = $(this).attr("lang") || 'en';

      if (language !== self.currentLanguage) {
        self.changeLanguage(language);
      }
    });
  };

  // load resource via ajax
  I18N.prototype.loadResource = function(url, language, namespace) {
    var self = this;

    //console.log("loading url='"+url+"'");

    $.getJSON(url).done(function(data) {
      self.addResource(data, language, namespace);
      self.translateAllElements();
    }).fail(function(xhr, textError, error) {
      if (console) {
        console.error("error loading i18n dictionary from url "+url+", error: ",error);
      }
    });
  };

  // add resource to the message store
  I18N.prototype.addResource = function(data, language, namespace) {
    var self = this;

    //console.log("adding resource data=",data);
    language = language || self.currentLanguage;

    function _addStrings(data, ns) {
      ns = namespace || '*';

      if (typeof(self.messageStore[language]) === 'undefined') {
        self.messageStore[language] = {
          "*": {}
        };
      }

      self.messageStore[language][ns] = $.extend(true, self.messageStore[language][ns], data);
    }


    if (data instanceof Array) {
      data.forEach(function(item)  {
        _addStrings(item.data, item.namespace);
      });
    } else {
      _addStrings(data);
    }

    //console.log("messageStore=",self.messageStore);
  };

  // update any dom elements flagged for a specific language to be translated
  I18N.prototype.translateAllElements = function() {
    var self = this;

    $(".i18n:not(.i18nTranslated)").each(function() {
      self.translateElement(this);
    });
  };

  // translate a single dom element
  I18N.prototype.translateElement = function(elem) {
    var self = this,
        $elem = $(elem),
        data = $elem.data(),
        message = data.i18nMessage,
        translation,
        params = {};

    $.each(data, function(key, val) {
      if (key.match(/^i18n(.*)$/) && key !== 'i18nMessage') {
        key = RegExp.$1.toLowerCase();
        params[key] = val;
      }
    });

    if (typeof(message) === 'undefined') {
      message = $elem.text();
    }
    if (typeof(message) !== 'undefined') {
      translation = self.translate(message, params);
      if (translation !== message) {
        $elem.html(translation).addClass("i18nTranslated");

        //console.log("translating ",message,"to",translation);
      }
    }

    return $elem;
  };

  // translate a string
  I18N.prototype.translate = function(string, params) {
    var self = this, 
        result,
        resource = self.messageStore[self.currentLanguage];

    if (typeof(resource) !== 'undefined') {
      result = resource['*'][string];

      if (typeof(result) === 'undefined') {

        $.each(resource, function(namespace, resource) {
          if (namespace !== '*') {
            result = resource[string];
          }
          return (typeof(result) === 'undefined' || result === '');
        });
      }
    }

    // fallback to the string itself
    if (typeof(result) === 'undefined' || result === '') {
      result = string;
    }

    // replace placeholder
    if (typeof(params) !== 'undefined') {
      $.each(params, function(key, val) {
        if (typeof(key) !== 'undefined' && typeof(val) !== 'undefined') {
          result = result.replace("%"+key+"%", val);
        }
      });
    }

    return result;
  };

  // change language
  I18N.prototype.changeLanguage = function(language) {
    var self = this;
  
    self.currentLanguage = language;
    self.translateAllElements();
  };

  // init singleton
  translator = new I18N();

  // translation shortcut
  $.i18n = function(string, params) {
    return translator.translate(string, params);
  };

})(jQuery);
