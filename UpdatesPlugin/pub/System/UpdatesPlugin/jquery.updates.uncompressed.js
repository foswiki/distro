jQuery(function($) {

  // global defaults
  var  defaults = {
    url: "http://foswiki.org/Extensions/UpdatesPluginReport"
  };

  // class constructor
  function FoswikiUpdates(options) {
    var self = this;
    self.options = options

    console.log("called new");

    self.init();

    return self;
  };

  // init method
  FoswikiUpdates.prototype.init = function() {
    var self = this;

    console.log("called init");
  };

  // document ready things
  var foswikiUpdates = new FoswikiUpdates();
});
