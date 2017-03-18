// initializer for the ui-dialog plugin
"use strict";
jQuery(function($) {

  var dialogDefaults = {
    width: 300,
    autoOpen:false,
    draggable:false,
    resizable:false,
    closeOnEscape:false,
    show:'fade'
  };

  // dialog
  $(".jqUIDialog").livequery(function() {
    var $this = $(this), 
        opts = $.extend({}, dialogDefaults, $this.data(), $this.metadata()),
        buttons = [];

    $this.find(".jqUIDialogButton").each(function() {
      var $button = $(this), 
          button = {},
          href = $button.attr("href");

      button.text = $button.text();

      if (typeof(href) !== 'undefined' && href !== '#') {
        button.click = function() {
          window.location.href = href;
        };
      }

      if ($button.is(".jqUIDialogClose")) {
        button.click = function() {
          $this.dialog("close");
        };
      }

      if ($button.is(".jqUIDialogDestroy")) {
        button.click = function() {
          $this.dialog("destroy");
          $this.remove();
        };
      }

      if ($button.is(".jqUIDialogSubmit")) {
        button.click = function() {
          $this.find("form:first").submit();
        };
      }
      $.extend(button, $button.data(), $button.metadata());

      if (typeof(button.click) === 'undefined') {
        button.click = function() {};
      }

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
    if (opts.alsoResize) {
      $this.dialog("widget").bind("resize", function(ev, ui) {
        var deltaHeight = ui.size.height - ui.originalSize.height || 0,
            deltaWidth = ui.size.width - ui.originalSize.width || 0;
        $this.find(opts.alsoResize).each(function() {
          var elem = $(this),
              elemHeight = elem.data("origHeight"),
              elemWidth = elem.data("origWidth");

          if (typeof(elemHeight) === 'undefined') {
            elemHeight = elem.height();
            elem.data("origHeight",elemHeight);
          }
          if (typeof(elemWidth) === 'undefined') {
            elemWidth = elem.width();
            elem.data("origWidth",elemWidth);
          }
          elem.height(elemHeight+deltaHeight);
          elem.width(elemWidth+deltaWidth);
        });
      });
    }
  });

  // dialog link
  $(document).on("click", ".jqUIDialogLink", function() {
    var $this = $(this), 
        href = $this.attr("href"),
        opts = $.extend({}, $this.data(), $this.metadata());

    if (href.match(/^(https?:)|\//)) {
      // this is a link to remote data
      $.ajax({
        url: href, 
        success: function(content) { 
          var $content = $(content);
          $content.hide();
          $("body").append($content);
          $content.data("autoOpen", true);
        },
        error: function(xhr) {
          throw("ERROR: can't load dialog xhr=",xhr);
        }
      }); 
    } else {
      // this is a selector
      $(href).dialog("open");
    }

    return false;
  });

});

