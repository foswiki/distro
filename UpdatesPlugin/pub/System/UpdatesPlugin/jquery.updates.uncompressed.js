var foswikiUpdates;

jQuery(function($) {

  // global defaults
  var  defaults = {
    reportUrl: foswiki.getPreference("UPDATESPLUGIN::REPORTURL"),
    configureUrl: foswiki.getPreference("UPDATESPLUGIN::CONFIGUREURL")
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
    var self = this, list = [], key, version;

    for (key in InstalledPlugins) {
      version = InstalledPlugins[key];
      if (!version.match(/%\$VERSION%/)) {
        list.push(key);
      }
    }

    //console.log("list", list);

    $.getJSON(self.options.reportUrl+"?callback=?", {
        skin: 'text',
        contenttype: 'text/javascript',
        list: list.join(",")
      }, 
      function(data) {
        foswikiUpdates.handleResponse(data);
      }
    );
  };

  // handleResponse of asking for plugin versions
  FoswikiUpdates.prototype.handleResponse = function(data) {
    var self = this,
        outdatedPlugins = [];
    
    //console.log("called handleResponse, data=",data);
    
    $.each(data, function(index, elem) {
      var available = elem.version.replace(/^\s*(.*?)?\s*$/, "$1"),
          pluginName = elem.topic,
          installed = InstalledPlugins[pluginName].replace(/^\s*(.*?)?\s*$/, "$1");

      if (available && installed) {
        if (available == installed) {
          //console.log("extension "+pluginName+" '"+installed+"' is up-to-date");
        } else {
          //console.log("extension "+pluginName+" '"+installed+"' can be updated to '"+available+"'");
          outdatedPlugins.push(pluginName);
        }
      }

    });
      
    // testing
    if (1) {
      console.log("adding FooBarPlugin to outdatedPlugins");
      outdatedPlugins.push("FooBarPlugin");
    }

    $.cookie("FOSWIKI_UPDATESPLUGIN", outdatedPlugins.length?true:false, {expires: 7, path: "/"});
    if (outdatedPlugins.length > 0) {
      self.showMessage(outdatedPlugins);
    }
  };

  // shows a warning banner about outdated plugins
  FoswikiUpdates.prototype.showMessage = function(plugins) {
    var self = this;

    $("#updatesPluginMessage").tmpl([{
      nrPlugins:plugins.length,
      configureUrl:self.options.configureUrl
    }]).prependTo("body").fadeIn();
  };

  // document ready things
  foswikiUpdates = new FoswikiUpdates();
});
