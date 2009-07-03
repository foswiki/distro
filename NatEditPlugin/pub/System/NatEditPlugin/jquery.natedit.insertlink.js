(function($) {
  /***************************************************************************
   * initializes the insert link dialog
   */
  $.natedit.initInsertLink = function(nateditor) {
    $("#natEditInsertLink input[type=text]").not(".selection").val('');

    $("#natEditInsertLinkWeb").autocomplete(
      foswiki.scriptUrl+"/view/"+foswiki.systemWebName+"/JQueryAjaxHelper?section=web;contenttype=text/plain;skin=text", {
        matchCase: true
    });

    $("#natEditInsertLinkTopic").autocomplete(
      foswiki.scriptUrl+"/view/"+foswiki.systemWebName+"/JQueryAjaxHelper?section=topic;contenttype=text/plain;skin=text", {
        matchCase: true,
        extraParams: {
          baseweb: function() { 
            return $('#natEditInsertLinkWeb').val();
          }
        }
    });

  };

  /***************************************************************************
   * handles the submit action for the insert link dialog
   */
  $.natedit.handleInsertLink = function(nateditor) {
    //var [startPos, endPos] = nateditor.getSelectionRange(nateditor);
    var flag = $("#natEditInsertLinkFlag").val();
    var markup;
    if (flag == "topic") {
      var web = $("#natEditInsertLinkWeb").val();
      var topic = $("#natEditInsertLinkTopic").val();
      var linktext = $("#natEditInsertLinkTextTopic").val() || topic;
      markup = "[["+web+"."+topic+"]["+linktext+"]]";
    } else {
      var url = $("#natEditInsertLinkUrl").val();
      var linktext = $("#natEditInsertLinkTextExternal").val();
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
