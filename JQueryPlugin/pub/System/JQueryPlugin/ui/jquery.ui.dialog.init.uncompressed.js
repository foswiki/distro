// initializer for the ui-dialog plugin
jQuery(function($) {

  var dialogDefaults = {
    width: 300,
    autoOpen:false,
    show:'fade',
    open:function() {
      var $container = $(this).parent();

      // remove focus marker from first button
      $container.find(".ui-dialog-buttonpane .ui-state-focus").removeClass("ui-state-focus");

      // support icons for buttons
      $container.find(".ui-dialog-buttonpane button[icon]").each(function() {
        var $btn = $(this), icon = $btn.attr("icon");
        $btn
        .removeAttr("icon")
        .removeClass('ui-button-text-only')
        .addClass('ui-button-text-icon-primary ui-button-text-icon')
        .prepend('<span class="ui-button-icon-primary ui-icon '+icon+'"></span>');
      });
    }
  };

  // dialog
  $(".jqUIDialog").livequery(function() {
    var $this = $(this), 
        opts = $.extend({}, dialogDefaults, $this.metadata()),
        buttons = opts.buttons;
    $this.removeClass("jqUIDialog").dialog(opts);
  });

  // dialog link
  $(".jqUIDialogLink").livequery(function() {
    var $this = $(this), dialog = $this.attr("href");

    $this.removeClass("jqUIDialogLink").click(function() {
      $(dialog).dialog("open");
      return false;
    });
  });

});

