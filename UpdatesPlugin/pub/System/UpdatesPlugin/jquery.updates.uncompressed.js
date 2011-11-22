// singleton object
var foswikiUpdates;

(function($) {


  // global defaults
  var  defaults = {
    reportUrl: foswiki.getPreference("UPDATESPLUGIN::REPORTURL"),
    configureUrl: foswiki.getPreference("UPDATESPLUGIN::CONFIGUREURL"),
    debug: false,
    delay: 1000, // number of seconds to delay contacting f.o.
    timeout: 5000, // number of seconds a jsonp call is considered failure
    cookieName: "FOSWIKI_UPDATESPLUGIN", // name of the cookie
    cookieExpires: 7 // number of days the cookie takes to expire
  };

  // class constructor
  function FoswikiUpdates(options) {
    var self = this;
    self.options = $.extend({}, defaults, options);

    //console.log("called new");

    self.init();

    return self;
  };

  // init method
  FoswikiUpdates.prototype.init = function() {
    var self = this;

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

    self.installedPlugins = [];
    self.outdatedPlugins = [];
    self.numberOutdatedPlugins = $.cookie(self.options.cookieName);

    // just to make sure we don't run into trouble
    if (typeof(InstalledPlugins) === 'undefined') {
      InstalledPlugins = [];
    }

    if (typeof(self.numberOutdatedPlugins) === 'undefined') {
      // collect local info
      for (key in InstalledPlugins) {
        version = InstalledPlugins[key];
        if (!version.match(/%\$VERSION%/)) {
          self.installedPlugins.push(key);
        }
      }

      // collect remote info
      //console.log("reportUrl=",self.options.reportUrl);
      window.setTimeout(function() {
        //console.log("...loading");
        $.ajax({
          type:"get",
          url: self.options.reportUrl,//+"?callback=?", 
          dataType: "jsonp",
          data: {
            skin: 'text',
            contenttype: 'text/javascript',
            list: self.installedPlugins.join(",")
          },
          
          // SMELL: browsers fail earlier when they can't load a resource
          // due to no-network
          timeout: self.options.timeout,
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

      // continues at handleResponse when getJSON has finised
    } else if (self.numberOutdatedPlugins > 0) {
      // we already know. so only trigger the display again
      $(document).trigger("display.foswikiUpdates");
    } 
  };

  // handles the json response
  FoswikiUpdates.prototype.handleResponse = function(data) {
    var self = this;

    $.each(data, function(index, elem) {
      var available = elem.version.replace(/^\s*(.*?)?\s*$/, "$1"),
          pluginName = elem.topic,
          installed = InstalledPlugins[pluginName].replace(/^\s*(.*?)?\s*$/, "$1");

      if (available && installed) {
        if (available == installed) {
          //console.log("extension "+pluginName+" '"+installed+"' is up-to-date");
        } else {
          //console.log("extension "+pluginName+" '"+installed+"' can be updated to '"+available+"'");
          self.outdatedPlugins.push(pluginName);
        }
      }
    });
  
    // testing by adding some random plugin to be considered outdated
    if (self.options.debug) {
      //console.log("adding FooBarPlugin to outdatedPlugins");
      self.outdatedPlugins.push("FooBarPlugin");
    }

    self.numberOutdatedPlugins = self.outdatedPlugins.length;

    // remember findings: sets cookie to the number of outdated plugins. setting it to
    // zero explicitly can either mean: everything up-to-date or ignore pending updates
    $.cookie(self.options.cookieName, self.numberOutdatedPlugins, {
      expires: self.options.cookieExpires, 
      path: "/"
    });

    // show the info banner
    if (self.outdatedPlugins.length > 0) {
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

