// initializer for the ui-dialog plugin
jQuery(function($) {

  var dialogDefaults = {
    width: 300,
    autoOpen:false,
    draggable:false,
    resizable:false,
    closeOnEscape:false,
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
  }, 

  dialogLinkDefaults = {
    cache: true
  };

  // dialog
  $(".jqUIDialog").livequery(function() {
    var $this = $(this), 
        opts = $.extend({}, dialogDefaults, $this.metadata()),
        buttons = [];

    if ($this.data("autoOpen")) {
      opts.autoOpen = true;
    }

    $this.find(".jqUIDialogButton").each(function() {
      var $button = $(this), 
          button = $.extend({ text: $button.text() }, $button.metadata());
      buttons.push(button);
    }).remove();

    if (buttons.length) {
      opts.buttons = buttons;
    }

    if(opts.autoCenter) {
      $(window).bind("resize", function() {
        $this.dialog("option", "position", "center");
      });
      opts.draggable = false;
    }

    $this.removeClass("jqUIDialog").dialog(opts);

  });

  // dialog link
  $(".jqUIDialogLink").livequery(function() {
    $(this).removeClass("jqUIDialogLink").click(function() {
      var $this = $(this), 
          href = $this.attr("href"),
          opts = $.extend({}, dialogLinkDefaults, $this.metadata());

      if (href.match(/^https?:/)) {
        // this is a link to remote data
        $.get(href, function(content) { 
          var $content = $(content),
              id = $content.attr('id');
          if (!id) {
            id = 'dialog-'+foswiki.getUniqueID();
            $content.attr('id', id);
          }
          if (opts.cache) {
            $this.attr("href", "#"+id);
          } 
          $content.hide();
          $("body").append($content);
          $content.data("autoOpen", true);
        }); 
      } else {
        // this is a selector
        $(href).dialog("open");
      }

      return false;
    });
  });

});

