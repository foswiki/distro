(function($) {

  // global defaults
  var defaults = {
    configureUrl: undefined, 
    endpointUrl: undefined,
    debug: false,
    delay: 1000, // number of seconds to delay contacting f.o.
    timeout: 5000, // number of seconds a jsonp call is considered failure
    cookieName: "FOSWIKI_UPDATESPLUGIN", // name of the cookie
    cookieExpires: 7 // number of days the cookie takes to expire
  }, foswikiUpdates; // singleton

  // class constructor
  function FoswikiUpdates(options) {
    var self = this;
    self.options = $.extend({}, defaults, options);

    if (self.options.debug) {
      console.log("called new FoswikiUpdates");
    }

    self.init();

    return self;
  };

  // init method
  FoswikiUpdates.prototype.init = function() {
    var self = this;

    if (typeof(self.options.configureUrl) === 'undefined') {
      self.options.configureUrl = foswiki.getPreference("UPDATESPLUGIN::CONFIGUREURL");
    }

    if (typeof(self.options.endpointUrl) === 'undefined') {
      self.options.endpointUrl = foswiki.getPreference("SCRIPTURL") + "/rest" + foswiki.getPreference("SCRIPTSUFFIX") + "/UpdatesPlugin/check";
    }

    // events
    $(document).bind("refresh.foswikiUpdates", function() {
      self.loadPluginInfo();
    });

    $(document).bind("forceRefresh.foswikiUpdates", function() {
      //console.log("called forceRefresh");
      $.cookie(self.options.cookieName, null, {expires: -1, path:'/'});
      self.loadPluginInfo();
    });

    $(document).bind("display.foswikiUpdates", function() {
      self.displayPluginInfo();
    });
      
    // add some click actions to the thing
    $("#foswikiUpdatesPerform").live("click", function() {
      window.location.href = self.options.configureUrl;
      return false;
    });

    $("#foswikiUpdatesIgnore").live("click", function() {
      // setting the cookie to zero...means ignore and don't search again
      $.cookie(self.options.cookieName, 0, {
        expires: self.options.cookieExpires, 
        path: "/"
      });
      $(".foswikiUpdatesMessage").fadeOut();
      return false;
    });
  };

  // pull info from f.o and refresh internal state
  FoswikiUpdates.prototype.loadPluginInfo = function() {
    var self = this, key, version;

    //console.log("called loadPluginInfo");
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
            // remember findings: sets cookie to the number of outdated plugins. setting it to
            // zero explicitly can either mean: everything up-to-date or ignore pending updates
            $.cookie(self.options.cookieName, self.numberOutdatedPlugins, {
              expires: self.options.cookieExpires, 
              path: "/"
            });

            $(document).trigger("display.foswikiUpdates");
          },
          error: function(xhr, msg, status) {
            //console.log("got an error: status=",status,"msg=",msg)
            // remember the error state
            $.cookie(self.options.cookieName, -1, {
              expires: self.options.cookieExpires, 
              path: "/"
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
    var self = this;

    $(".foswikiUpdateMessage").remove(); // ... the old one if there

    // ... and add a new one
    $("#foswikiUpdatesTmpl").tmpl([{
      nrPlugins:self.numberOutdatedPlugins,
      configureUrl:self.options.configureUrl
    }]).prependTo("body").fadeIn();
  };

  // document ready things
  $(function() {
    if (typeof(foswikiUpdates) === 'undefined') {
      foswikiUpdates = new FoswikiUpdates();
      $(document).trigger("refresh.foswikiUpdates");
    }
  });

})(jQuery);
