(function($) {
  var xhr, requestIndex = 0;

  /***************************************************************************
   * initializes the insert link dialog
   */
  $.natedit.initInsertLink = function(nateditor) {
    var $inserter = $("#natEditInsertLink");

    $inserter.find(".empty").val('');
    $inserter.find(".baseweb").each(function() {
      var val = $(this).val();
      if (!val) {
        $(this).val(foswiki.getPreference('WEB'));
      }
    });

    $("#natEditInsertLinkWeb").autocomplete({
      source: foswiki.getPreference("SCRIPTURLPATH")+"/view/"+foswiki.getPreference("SYSTEMWEB")+"/JQueryAjaxHelper?section=web&skin=text"
    });

    $("#natEditInsertLinkTopic").autocomplete({
      source: function( request, response ) {
        if (xhr) {
          xhr.abort();
        }
        xhr = $.ajax({
          url: foswiki.getPreference("SCRIPTURLPATH")+"/view/"+foswiki.getPreference("SYSTEMWEB")+"/JQueryAjaxHelper?section=topic&skin=text",
          data: $.extend(request, {
            baseweb: $('#natEditInsertLinkWeb').val()
          }),
          dataType: "json",
          autocompleteRequest: ++requestIndex,
          success: function(data, status) {
            if (this.autocompleteRequest === requestIndex) {
              response(data);
            }
          },
          error: function(xhr, status) {
            if (this.autocompleteRequest === requestIndex) {
              response([]);
            }
          }
        });
      }
    });

  };

  /***************************************************************************
   * handles the submit action for the insert link dialog
   */
  $.natedit.handleInsertLink = function(nateditor) {
    //var [startPos, endPos] = nateditor.getSelectionRange(nateditor);
    var flag = $("#natEditInsertLinkFlag").val(), 
        markup,
        baseWeb = foswiki.getPreference('WEB'),
        web = $("#natEditInsertLinkWeb").val(),
        topic = $("#natEditInsertLinkTopic").val(),
        linktext = $("#natEditInsertLinkTextTopic").val(),
        url = $("#natEditInsertLinkUrl").val();

    if (flag == "topic") {
      if (linktext) {
        if (web == baseWeb) {
          markup = "[["+topic+"]["+linktext+"]]";
        } else {
          markup = "[["+web+"."+topic+"]["+linktext+"]]";
        }
      } else if (web == baseWeb) {
        markup = "[["+topic+"]]";
      } else {
        markup = "[["+web+"."+topic+"]]";
      }
    } else {
      linktext = $("#natEditInsertLinkTextExternal").val();

      if (linktext) {
	markup = "[["+url+"]["+linktext+"]]";
      } else {
	markup = "[["+url+"]]";
      }
    }
    nateditor.remove();
    nateditor.insertTag(['', markup, '']);
  };
})(jQuery);
