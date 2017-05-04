/*
 * jquery.updates plugin 0.30
 *
 * Copyright (c) 2011-2015 Foswiki Contributors http://foswiki.org
 *
 * http://www.gnu.org/licenses/gpl.html
 *
 */
(function($) {

  // global defaults
  var defaults = {
    configureUrl: undefined, 
    endpointUrl: undefined,
    debug: false,
    delay: 1000, // number of seconds to delay contacting f.o.
    timeout: 5000, // number of seconds a jsonp call is considered failure
    cookieName: "FOSWIKI_UPDATESPLUGIN", // name of the cookie
    cookieExpires: 7, // number of days the cookie takes to expire
    cookieSecure: '0', // If secure cookies are needed (https)
    cookieDomain: ''   // Override domain if requested.

  }, foswikiUpdates; // singleton

  // class constructor
  function FoswikiUpdates(options) {
    var self = this;
    self.options = $.extend({}, defaults, options);

    if (self.options.debug) {
      console.log("called new FoswikiUpdates");
    }

    self.init();
    self.loadPluginInfo(0);

    return self;
  };

  // init method
  FoswikiUpdates.prototype.init = function() {
    var self = this;
    //console.log("init FoswikiUpdates");

    if (typeof(self.options.configureUrl) === 'undefined') {
      self.options.configureUrl = foswiki.getPreference("UPDATESPLUGIN::CONFIGUREURL");
    }

    if (typeof(self.options.endpointUrl) === 'undefined') {
      self.options.endpointUrl = foswiki.getScriptUrl("rest", "UpdatesPlugin", "check");
    }

    self.options.cookieDomain = foswiki.getPreference('COOKIEREALM'); // Allow domain override
    self.options.cookieSecure = foswiki.getPreference('URLHOST').startsWith('https://');

    // events
    $(document).bind("refresh.foswikiUpdates", function() {
      //console.log("BIND refresh.foswikiUpdates calling loadPluginInfo.");
      self.loadPluginInfo(0);
    });

    $(document).bind("forceRefresh.foswikiUpdates", function() {
      //console.log("BIND forceRefresh.foswikiUpdates calling loadPluginInfo.");
      $.cookie(self.options.cookieName, null, {
        expires: -1,
        path:'/',
        domain:self.options.cookieDomain,
        secure:self.options.cookieSecure
      });
      self.loadPluginInfo(1);
    });

    $(document).bind("display.foswikiUpdates", function() {
      //console.log("BIND display.foswikiUpdates calling loadPluginInfo.");
      self.displayPluginInfo(0);
    });

    $(document).on("click", "#foswikiUpdatesIgnore", function() {
      // setting the cookie to zero...means ignore and don't search again
      //console.log("BIND click entered ");
      $.cookie(self.options.cookieName, 0, {
        expires: self.options.cookieExpires, 
        path: "/",
        domain:self.options.cookieDomain,
        secure:self.options.cookieSecure
      });
      $(".foswikiUpdatesMessage").fadeOut();
      return false;
    });
  };

  // pull info from f.o and refresh internal state
  FoswikiUpdates.prototype.loadPluginInfo = function(forced) {
    var self = this, key, version;

    //console.log("called loadPluginInfo forced: " + forced );
    self.numberOutdatedPlugins = $.cookie(self.options.cookieName);

    if (typeof(self.numberOutdatedPlugins) === 'undefined') {

      // collect remote info
      window.setTimeout(function() {
        //console.log("...loading");
        $.ajax({
          type:"get",
          url: self.options.endpointUrl,
          dataType: "json",
          timeout: self.options.timeout,
          success: function(data, status, xhr) {
            //console.log("success: data=",data);
            self.numberOutdatedPlugins = data.length;
            self.pluginList = data.sort();
            // remember findings: sets cookie to the number of outdated plugins. setting it to
            // zero explicitly can either mean: everything up-to-date or ignore pending updates
            $.cookie(self.options.cookieName, self.numberOutdatedPlugins, {
              expires: self.options.cookieExpires, 
              path: "/",
              domain:self.options.cookieDomain,
              secure:self.options.cookieSecure
            });

            //console.log("Forced: " + forced);
            if (self.numberOutdatedPlugins > 0 || forced) {
                $(document).trigger("display.foswikiUpdates");
            }
          },
          error: function(xhr, msg, status) {
            //console.log("got an error: status=",status,"msg=",msg)
            // remember the error state
            $.cookie(self.options.cookieName, -1, {
              expires: self.options.cookieExpires, 
              path: "/",
              domain:self.options.cookieDomain,
              secure:self.options.cookieSecure
            });
          }
        });
      }, self.options.delay);
    } else if (self.numberOutdatedPlugins > 0) {
      // we already know. so only trigger the display again
      $(document).trigger("display.foswikiUpdates");
    } 
  };

  // displays internal state using a nice info box at the top of the page
  FoswikiUpdates.prototype.displayPluginInfo = function() {
    var self = this, elem;

    $(".foswikiUpdateMessage").remove(); // ... the old one if there

    // ... and add a new one
    elem = $("#foswikiUpdatesTmpl").render([{
      nrPlugins:self.numberOutdatedPlugins,
      pluginList:self.pluginList,
      cookieExpires:self.options.cookieExpires,
      configureUrl:self.options.configureUrl
    }]);

    $(elem).prependTo("body").fadeIn();
  };

  // document ready things
  $(function() {
    foswikiUpdates = foswikiUpdates || new FoswikiUpdates();
  });

})(jQuery);
